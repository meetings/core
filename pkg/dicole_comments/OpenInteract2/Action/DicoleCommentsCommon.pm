package OpenInteract2::Action::DicoleCommentsCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Tree::Creator::Hash;

sub DEFAULT_DISCUSSION_SIZE { 7 }

sub _generate_script_data_json {
    my ( $self, $gid, $info ) = @_;

    my $script_data = {
        skip_data => Dicole::Utils::JSON->encode( $info->{skip} || {} ),
        more_url => Dicole::URL->from_parts(
            action => 'group_comments_json', task => 'more_discussions', target => $gid,
        ),
    };

    return Dicole::Utils::JSON->encode( $script_data );
}

sub _fetch_rolling_list_info {
    my ( $self, $gid, $size, $skip_data ) = @_;

    $skip_data ||= {};
    $skip_data->{start_time} = time() unless defined $skip_data->{start_time};

    my $start_time = $skip_data->{start_time};

    my $rolling_data = {};
    my $rolling_list = [];

    my $disabled_seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND exclude_from_summary = ?',
        value => [ $gid, 1 ],
    } ) || [];

    my @disabled_seed_ids = map { $_->id => 1 } @$disabled_seeds;

    my $blog_key = ref( CTX->lookup_object('blogs_entry')->new );
    my $blogs = CTX->lookup_object('blogs_entry')->fetch_group({
        where => 'group_id = ?' . 
            ' AND date < ?' .
            ' AND ' . Dicole::Utils::SQL->column_not_in( seed_id => \@disabled_seed_ids ) .
            ' AND ' . Dicole::Utils::SQL->column_not_in( entry_id => $skip_data->{ $blog_key } || [] ),
        value => [ $gid, $start_time ],
        order => 'date desc',
        limit => $size,
    });


    $rolling_data->{ $blog_key }->{ $_->id } = $_ for @$blogs;

    for my $blog ( sort { $b->{date} <=> $a->{date} } @$blogs ) {
        $self->_insert_rolling_list_entry(
            $rolling_list, $size + 1,
            { date => $blog->date, type => $blog_key, id => $blog->id }
        );
    }

# NOTE: Show wiki pages only if they have been commented.
# NOTE: Store this code here if we want to change this in the future
#     my $wiki_key = ref( CTX->lookup_object('wiki_page')->new );
#     my $wikis = CTX->lookup_object('wiki_page')->fetch_group({
#         where => 'groups_id = ?' .
#             ' AND last_modified_time < ?' .
#             ' AND ' . Dicole::Utils::SQL->column_not_in( page_id => $skip_data->{ $wiki_key } || [] ),
#         value => [ $gid, $start_time ],
#         order => 'last_modified_time desc',
#         limit => $size,
#     });
# 
#     $rolling_data->{ $wiki_key }->{ $_->id } = $_ for @$wikis;
# 
# 
#     for my $wiki ( sort { $b->{last_modified_time} <=> $a->{last_modified_time} } @$wikis ) {
#         $self->_insert_rolling_list_entry(
#             $rolling_list, $size,
#             { date => $wiki->last_modified_time, type =>  $wiki_key, id => $wiki->id }
#         );
#     }

# NOTE: Show media objects only if they have been commented.
# NOTE: Store this code here if we want to change this in the future
#     my $prese_key = ref( CTX->lookup_object('presentations_prese')->new );
#     my $preses = CTX->lookup_object('presentations_prese')->fetch_group({
#         where => 'group_id = ?' .
#             ' AND creation_date < ?' .
#             ' AND ' . Dicole::Utils::SQL->column_not_in( prese_id => $skip_data->{ $prese_key } || [] ),
#         value => [ $gid, $start_time ],
#         order => 'creation_date desc',
#         limit => $size,
#     });
# 
#     $rolling_data->{ $prese_key }->{ $_->id } = $_ for @$preses;
# 
#     for my $prese ( sort { $b->{creation_date} <=> $a->{creation_date} } @$preses ) {
#         $self->_insert_rolling_list_entry(
#             $rolling_list, $size + 1,
#             { date => $prese->creation_date, type => $prese_key, id => $prese->id }
#         );
#     }

    my $skip_data_lookup = {};
    for my $key ( keys %$skip_data ) {
        if ( ref( $skip_data->{ $key } ) eq 'ARRAY' ) {
            $skip_data_lookup->{ $key } = { map { $_ => 1 } @{ $skip_data->{ $key } } };
        }
    }

    $skip_data->{comment} ||= [];

    my $comments = [];
    my $continue = 1;

    my $skip_comments_by_object = {};
    my @current_skip_comments = ();
    do {
        $comments = CTX->lookup_object('comments_post')->fetch_group( {
            from => [ 'dicole_comments_post', 'dicole_comments_thread' ],
            where => 'dicole_comments_post.thread_id = dicole_comments_thread.thread_id' .
                ' AND dicole_comments_post.published > 0' .
                ' AND dicole_comments_post.removed = 0' .
                ' AND dicole_comments_thread.group_id = ?' .
                ' AND dicole_comments_post.date < ?' .
                ' AND ' . Dicole::Utils::SQL->column_not_in( 'dicole_comments_post.post_id' => [ @{ $skip_data->{comment} || [] }, @current_skip_comments ] ),
            value => [ $gid, $start_time ],
            order => 'dicole_comments_post.date desc',
            limit => 30,
        } );


        my $threads = CTX->lookup_object('comments_thread')->fetch_group( {
            where => Dicole::Utils::SQL->column_in( thread_id => [ map { $_->thread_id } @$comments ] ) . 
                ' AND ' . Dicole::Utils::SQL->column_not_in( thread_id => [ keys %{ $rolling_data->{ 'thread' } } ] ),
        } );

        $rolling_data->{ 'thread' }->{ $_->id } = $_ for @$threads;

        for my $comment ( @$comments ) {
            # returns undef if entry is skipped
            my $data = eval { $self->_rolling_list_data_for_comment( $comment, $rolling_data, $skip_data_lookup ) };

            if ( $data ) {
                my $success = $self->_insert_rolling_list_entry( $rolling_list, $size + 1, $data );
                unless ( $success  ) {
                    $continue = 0;
                    last;
                }
                $skip_comments_by_object->{ $data->{type} }->{ $data->{id} } ||= [];
                push @{ $skip_comments_by_object->{ $data->{type} }->{ $data->{id} } }, $comment;

                push @current_skip_comments, $comment->id;
            }
            else {
                push @{ $skip_data->{comment} }, $comment->id;
            }

            $skip_comments_by_object->{ $data->{type} }->{ $data->{id} } ||= [];
            push @{ $skip_comments_by_object->{ $data->{type} }->{ $data->{id} } }, $comment;
        }
    } until ( ! $continue || ! scalar( @$comments ) );

    my $object_info_list = [];

    for my $data ( @$rolling_list ) {
        last if scalar( @$object_info_list ) >= $size;

        push @{ $skip_data->{ $data->{type} } }, $data->{id};
        for my $comment ( @{ $skip_comments_by_object->{ $data->{type} }->{ $data->{id} } || [] } ) {
            push @{ $skip_data->{comment} }, $comment->id;
        }

        my $object = $rolling_data->{ $data->{type} }{ $data->{id} };
        next unless $object;

        if ( $data->{type} eq 'OpenInteract2::BlogsEntry' ) {
            push @$object_info_list, $self->_gather_blog_data( $object, $data->{date}, $start_time );
        }
        elsif ( $data->{type} eq 'OpenInteract2::PresentationsPrese' ) {
            push @$object_info_list, $self->_gather_prese_data( $object, $data->{date}, $start_time );
        }
        elsif ( $data->{type} eq 'OpenInteract2::WikiPage' ) {
            push @$object_info_list, $self->_gather_wiki_data( $object, $data->{date}, $start_time );
        }
        else {
            next;
        }
    }

    return {
        object_info_list => $object_info_list,
        skip => $skip_data,
        empty => ( scalar( @$rolling_list ) ) ? 0 : 1,
        end_of_pages => ( scalar( @$rolling_list ) > $size ? 0 : 1 ),
    };
}

sub _gather_blog_data {
    my ( $self, $object, $date, $start_time ) = @_;

    my $data = pop @{ CTX->lookup_action('blogs_api')->e(
        data_for_entries => { entries => [ $object ], ids => [ $object->id ] }
    ) || [] };

    my $oi = {
        title => $data->{post}->title,
        author => $data->{author_name},
        author_image => CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $data->{user}->id,
            domain_id => Dicole::Utils::Domain->guess_current_id,
            size => 40,
            no_default => 1,
        } ),
        author_link => CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $data->{user}->id, domain_id => Dicole::Utils::Domain->guess_current_id, group_id => $object->group_id,
        } ),
        link => $data->{show_url},
        date => $self->_generate_time_string( $date, $start_time ),
        number_of_comments => CTX->lookup_action('comments_api')->e( get_comment_count => {
            object => $object,
            group_id => $object->group_id,
        } ),
        commenters => $self->_gather_commenter_data_for_object( $object, $object->group_id ),
        type => 'blog',
    };

    return $oi;
}

sub _gather_wiki_data {
    my ( $self, $object, $date, $start_time ) = @_;

    my $data = pop @{ CTX->lookup_action('wiki_api')->e(
        data_for_pages => { pages => [ $object ], ids => [ $object->id ] }
    ) || [] };

    my $oi = {
        title => $data->{readable_title},
        author => $data->{readable_title},
        author_image => '',
        author_link => $data->{show_url},
        link => $data->{show_url},
        date => $self->_generate_time_string( $date, $start_time ),
        number_of_comments => CTX->lookup_action('comments_api')->e( get_comment_count => {
            object => $object,
            group_id => $object->group_id,
        } ),
        commenters => $self->_gather_commenter_data_for_object( $object, $object->group_id ),
        type => 'wiki',
    };
    return $oi;
}

sub _gather_prese_data {
    my ( $self, $object, $date, $start_time ) = @_;

    my $data = pop @{ CTX->lookup_action('presentations_api')->e(
        data_for_objects => { objects => [ $object ], ids => [ $object->id ] }
    ) || [] };

    my $show_url = Dicole::URL->create_from_parts(
        action => 'presentations',
        task => 'show',
        target => $object->group_id,
        additional => [ $object->id ],
    );

    my $oi = {
        title => $data->{name},
        author => $data->{name},
        author_image => CTX->lookup_action('thumbnails_api')->e( create => {
            url => $data->{image}, width => 40, height => 40,
        } ),
        author_link => $show_url,
        link => $show_url,
        date => $self->_generate_time_string( $date, $start_time ),
        number_of_comments => CTX->lookup_action('comments_api')->e( get_comment_count => {
            object => $object,
            group_id => $object->group_id,
        } ),
        commenters => $self->_gather_commenter_data_for_object( $object, $object->group_id ),
        type => 'media',
    };

    return $oi;
}

sub _generate_time_string {
    my ( $self, $epoch, $now ) = @_;

    return Dicole::Utils::Date->localized_about_when( epoch => $epoch, now => $now );
}

sub _gather_commenter_data_for_object {
    my ( $self, $object, $group_id ) = @_;

    my $commenters = CTX->lookup_action('comments_api')->e( get_latest_commenters => {
        object => $object,
        group_id => $group_id,
        limit => 5,
    } );

    my @return = ();
    for my $c ( @$commenters ) {
        my $image = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $c,
            domain_id => Dicole::Utils::Domain->guess_current_id,
            size => 30,
            no_default => 1,
        } );
        push @return, { image => $image };
    }
    return \@return;
}

# this function returns 0 if the entry corresponding to the rolling list did not fit into the list
sub _insert_rolling_list_entry {
    my ( $self, $list, $size, $data ) = @_;

    my $inserted = 0;

    for ( my $i = 0; $i < @$list; $i++ ) {
        if ( ! $inserted && $data->{date} > $list->[$i]->{date} ) {
            splice( @$list, $i, 0, $data );
            $inserted = 1;
            $i++;
        }
        if ( $data->{id} == $list->[$i]->{id} && $data->{type} eq $list->[$i]->{type} ) {
            if ( $inserted ) {
                splice( @$list, $i, 1 );
            }
            return 1;
        }
    }

    if ( $inserted ) {
        splice( @$list, $size );
        return 1;
    }
    else {
        return 0 unless scalar( @$list ) < $size;
        push @$list, $data;
        return 1;
    }
}

sub _rolling_list_data_for_comment {
    my ( $self, $comment, $rolling_data, $skip_data_lookup ) = @_;

    my $thread = $rolling_data->{ 'thread' }->{ $comment->thread_id };
    return undef unless $thread;

    my $type = $thread->object_type;
    my $id = $thread->object_id;

    return undef if exists $skip_data_lookup->{ $type } && exists $skip_data_lookup->{ $type }->{ $id };
    if ( $type eq 'OpenInteract2::BlogsEntry' ) {
        $rolling_data->{ $type }{ $id } ||= CTX->lookup_object( 'blogs_entry' )->fetch( $id );
    }
    elsif ( $type eq 'OpenInteract2::PresentationsPrese' ) {
        $rolling_data->{ $type }{ $id } ||= CTX->lookup_object( 'presentations_prese' )->fetch( $id );
    }
    elsif ( $type eq 'OpenInteract2::WikiPage' ) {
        $rolling_data->{ $type }{ $id } ||= CTX->lookup_object( 'wiki_page' )->fetch( $id );
    }
    elsif ( $type eq 'OpenInteract2::WikiAnnotation' ) {
        $rolling_data->{ $type }{ $id } ||= CTX->lookup_object( 'wiki_annotation' )->fetch( $id );
        $id = $rolling_data->{ $type }{ $id }->page_id;
        $type = 'OpenInteract2::WikiPage';
        $rolling_data->{ $type }{ $id } ||= CTX->lookup_object( 'wiki_page' )->fetch( $id );
    }
    else {
        return undef;
    }

    return undef unless $rolling_data->{ $type }{ $id };

    return { date => $comment->date, id => $id, type => $type };
}

1;

