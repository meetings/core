package OpenInteract2::Action::DicoleBlogsCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use HTML::Entities;
use Dicole::Utils::User;
use URI;

sub _generic_entries {
    my ( $self, %p ) = @_;
    
    my $where = 'dicole_blogs_entry.group_id = ?';
    $where .= ' AND dicole_blogs_entry.seed_id = ?' if $p{seed_id};
    $where .= ' AND ' . Dicole::Utils::SQL->column_in(
        'dicole_blogs_entry.user_id', $p{user_ids}
    ) if $p{user_ids};
    $where .= ' AND ' . $p{where} if $p{where};
    my $value = [ $p{group_id}, $p{seed_id} || (), $p{value} ? @{$p{value}} : () ];

    my $tags = ( $p{tags} && ref( $p{tags} ) eq 'ARRAY' ) ? $p{tags} : [];
    push @$tags, $p{tag} if $p{tag};

    my $entries = scalar( @$tags ) ?
        CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group', {
            object_class => CTX->lookup_object('blogs_entry'),
            tags => $tags,
            where => $where,
            value => $value,
            order => $p{order},
            limit => $p{limit},
        } ) || []
        :
        CTX->lookup_object('blogs_entry')->fetch_group( {
            where => $where,
            value => $value,
            order => $p{order},
            limit => $p{limit},
        } ) || [];

    return $entries;
}

sub _entry_data_to_rss_params {
    my ( $self, $data ) = @_;
    my $surl = $self->param('server_url') || Dicole::URL->get_server_url;

    my $params = {
        link => $surl . $data->{show_url},
        title => $data->{post}->title,
        description => $data->{post}->content,
        pubDate => $data->{post}->date,
        author => $data->{author_name},
        guid => $surl . $data->{show_url},
        category =>  $data->{tags},
    };
    return $params;
}

sub _visualize_entry_list {
    my ( $self, $entries, $seed, $paritial ) = @_;
    
    my @visuals = map { $self->_visualize_message( $_, $seed, { include_source => 1 } ) } @$entries;
    my $time = time;
    
    # guess that there are more if 10 was rendered ;)
    if ( scalar( @$entries ) > 9 ) {
        my $button_container = Dicole::Widget::Container->new(
            class => 'blogs_more_container blogs_more_button_id_' . $time . '_container',
            id => 'blogs_more_container_' . $time,
            contents => [
                Dicole::Widget::LinkButton->new(
                    text => $self->_msg( 'Show more posts' ),
                    class => 'blogs_more_button blogs_more_button_id_' . $time,
                    id => 'blogs_more_button_' . $time,
                    link => $self->derive_url(
                        action => 'blogs_json',
                    ),
                ),
            ],
        );
        push @visuals, $button_container;
    }
    
    my $list = Dicole::Widget::Vertical->new(
        contents => \@visuals,
        class => $paritial ? undef : 'blogs_post_listing',
        id => $paritial ? undef : 'blogs_post_listing_' . $time,
    );

    return $list;
}

sub _process_post_content_for_output {
    my ( $self, $content ) = @_;

    eval {
        $content = CTX->lookup_action('tinymce_api')->filter_outgoing_embedded_html( $content );
    };
    if ( my $msg = $@ ) {
        get_logger( LOG_APP )->error( "Error filtering embedded HTMLs: " . $msg );
    }

    return $content;
}

sub _fetch_post_for_entry {
    my ( $self, $entry ) = @_;
    
    $entry = CTX->lookup_object('blogs_entry')->fetch( $entry )
        unless ref( $entry );
    unless ( ref $entry ) {
        use Carp;
        Carp::confess;
    }
    
    my $post = CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
    
    if ( ! $post ) {
        # delete post??
        die;
    }
    
    return $post;
}

sub _fetch_entries_for_post_id {
    my ( $self, $post_id, $group_id ) = @_;
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'post_id = ?' .
            ( $group_id ? ' AND group_id = ?' : '' ),
        value => [ $post_id, $group_id ? $group_id : () ],
    } );
    
    return $entries;
}

sub _fetch_entries_for_ids {
    my ( $self, $eids ) = @_;
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( entry_id => $eids ),
    } );
    
    return $entries;
}

sub _fetch_valid_seed {
    my ( $self ) = @_;
    
    return undef unless $self->param('seed_id');
    my $seed = eval { CTX->lookup_object('blogs_seed')->fetch( $self->param('seed_id') ) };
    return undef unless $seed && $seed->group_id == $self->param('target_group_id');
    return $seed;
}

sub _entries_to_entry_datas {
    my ( $self, $entries, $seed, $domain_id ) = @_;

    return [ map { $self->_entry_data( $_, $seed, $domain_id ) } @$entries ];
}

sub _entry_data {
    my ( $self, $entry, $seed, $domain_id ) = @_;
    
    $entry = CTX->lookup_object('blogs_entry')->fetch( $entry )
        unless ref( $entry );
    die unless $entry;
    
    my $post = $self->_fetch_post_for_entry( $entry );
    
    my $tags = eval {
        CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
            object => $entry,
            user_id => 0,
            group_id => $entry->group_id,
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        } );
    };
    
    my $attachments = eval {
        CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
            object => $post,
            user_id => 0,
            group_id => $entry->group_id,
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        } );
    };

    my $comment_count = eval {
        CTX->lookup_action('commenting')->execute( get_comment_count => {
            object => $entry,
            user_id => 0,
            group_id => $entry->group_id,
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        } );
    };
    
    my $sources = CTX->lookup_object('blogs_reposted_link')->fetch_group( {
        where => 'entry_id = ?',
        value => [ $entry->id ]
    } ) || [];
    my $source = pop @$sources || undef;

    my $user = CTX->lookup_object('user')->fetch( $entry->user_id );
    my $name = Dicole::Utils::User->name( $user, $self->_msg('Unknown user') );
    my $short_name = Dicole::Utils::User->short_name( $user, $self->_msg('Unknown') );
    
    my $urltitle = $self->_entry_url_title( $entry, $post, $user );
    
    my $sid = $seed ? ref( $seed ) ? $seed->id : $entry->seed_id : 0;
    
    return {
        entry => $entry,
        post => $post,
        user => $user,
        source => $source,
        tags => $tags,
        comment_count => $comment_count || 0,
        attachments => $attachments,
        author_name => $name,
        short_author_name => $short_name,
        edit_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'edit_post',
            target => $entry->group_id,
            additional => [ $sid, $entry->user_id, $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        show_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'show',
            target => $entry->group_id,
            additional => [ $sid, $entry->id, $urltitle ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        show_comments_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'show',
            target => $entry->group_id,
            additional => [ $sid, $entry->id, $urltitle ],
            anchor => 'comments',
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        delete_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'confirm_delete',
            target => $entry->group_id,
            additional => [ $sid, $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        feature_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'feature',
            target => $entry->group_id,
            additional => [ $sid, $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        unfeature_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'unfeature',
            target => $entry->group_id,
            additional => [ $sid, $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        reseed_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'reseed_post',
            target => $entry->group_id,
            additional => [ $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
        add_tags_url => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'add_tags',
            target => $entry->group_id,
            additional => [ $sid, $entry->id ],
            ( $domain_id ) ? ( domain_id => $domain_id ) : ()
        ),
    };
}

sub _entry_url_title {
    my ( $self, $entry, $post, $user ) = @_;
    
    $post ||= CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
    $user ||= CTX->lookup_object('user')->fetch( $entry->user_id );
    
    my $urltitle = Dicole::Utils::Text->utf8_to_url_readable(
        $post->title
    );
    
    return $urltitle;
}

sub _seed_image_url {
    my ( $self, $seed ) = @_;

    return '/images/theme/default/seed-default.png'
        unless $seed && defined $seed->image;

    if ( $seed->image && $seed->image =~ /^\d+$/ ) {
        return Dicole::URL->from_parts(
            action => 'blogs',
            task   => 'image',
            target => $seed->group_id,
            additional => [ $seed->id ]
        );
    }
    elsif ( $seed->image ) {
        my $i = $seed->image;
        $i = 'http://' . $i unless $i =~ /^https?:\/\// || $i =~ /^\//;
        return $i;
    }
}

sub _promoting_enabled_for_seed {
    my ( $self, $seed ) = @_;
    
    return ( ( $seed && $seed->enable_promoting ) ? 1 : 0 );
}

sub _rating_enabled_for_seed {
    my ( $self, $seed ) = @_;
    
    return ( ( ( $seed && $seed->enable_rating ) || ! $seed ) ? 1 : 0 );
}

sub _commenting_requires_approval {
    my ( $self ) = @_;

    return Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'commenting_requires_approval',
        group_id => CTX->controller->initial_action->param('target_group_id'),
    ) ? 1 : 0;
}

sub _visualize_full_message {
    my ( $self, $entry, $seed ) = @_;
    return $self->_visualize_message( $entry, $seed, {
        full_text => 1,
        no_comment_action => 1,
        no_comment_count => 1,
        hide_title => 1,
        include_source => 1,
    } );
}

sub _visualize_message {
    my ( $self, $entry, $seed, $conf ) = @_;
    
    # backwards compatibility
    if ( !ref( $conf ) && $conf == 1 ) { return $self->_visualize_full_message( $entry, $seed ); }
    
    $conf ||= {};
    
    my $data = eval { $self->_entry_data( $entry, $seed ); };
    if ( $@ ) {
        return ();
    }
    my $user = $data->{user};
    my $post = $data->{post};
    my $tags = $data->{tags};
    
    $entry = $data->{entry};
    
    my $content = $self->_process_post_content_for_output( $post->content );
    
    my $read_more = undef;
    my $title = undef;
    
    unless ( $conf->{full_text} ) {
        my $content_shortened = Dicole::Utils::HTML->shorten( $content, 500 );
        my $content_shortened_test_case = Dicole::Utils::HTML->shorten( $content, 500000000000 );
        if ( $content_shortened_test_case ne $content_shortened ){
            $read_more = Dicole::Widget::Hyperlink->new(
                link => $data->{show_url},
                content => $self->_msg('Read more')
            );
            $content = $content_shortened;
        }
    }
    unless ( $conf->{hide_title} ) {
        $title = Dicole::Widget::Hyperlink->new(
            link => $data->{show_url}, content => $post->{title}
        );
    }
    
    $content = Dicole::Utils::HTML->break_long_strings( $content, 60 );

    my $author = Dicole::Widget::Hyperlink->new(
        link => Dicole::URL->from_parts(
            action => 'networking',
            task => 'profile',
            target => $entry->{group_id},
            additional => [ $user->id ],
        ),
        content => $data->{author_name},
    );
    my $date = Dicole::DateTime->medium_datetime_format( $entry->date );

    my $control_widgets = [];
    
    unless ( $conf->{no_control} ) {
        my $reseed_possible = 0;
        if ( $self->schk_y('OpenInteract2::Action::DicoleBlogs::reseed') ) {
            my $seeds_exist = $seed ? 1 : scalar( @{ CTX->lookup_object('blogs_seed')->fetch_group( {
                where => 'group_id = ?',
                value => [ $self->param('target_group_id') ],
                limit => 1,
            } ) || [] } ) ? 1 : 0;
            
            $reseed_possible = $seeds_exist;
        }
        elsif ( CTX->request && CTX->request->auth_user_id == $entry->user_id && ! $entry->seed_id ) {
            my $open_seeds_exist = scalar( @{ CTX->lookup_object('blogs_seed')->fetch_group( {
                where => 'group_id = ? AND closed_date = ?',
                value => [ $self->param('target_group_id'), 0 ],
                limit => 1,
            } ) || [] } ) ? 1 : 0;
            
            $reseed_possible = $open_seeds_exist;
        }
        
        push @$control_widgets,  Dicole::Widget::Hyperlink->new (
            link => $data->{reseed_url},
            class =>'blogPostReseed blogs_entry_reseed',
            title => $self->_msg('Move to an another topic'),
        ) if $reseed_possible;
    
        push @$control_widgets,  Dicole::Widget::Hyperlink->new (
            link => $data->{delete_url},
            class =>'blogPostDelete blogs_entry_delete',
            id => 'blogs_entry_delete_' . $entry->id,
            title => $self->_msg('Remove'),
       ) if $self->schk_y( 'OpenInteract2::Action::Weblog::user_delete', $user->id );
        
        if ( $self->schk_y( 'OpenInteract2::Action::DicoleBlogs::feature' ) ) {
            if ( $entry->featured ) {
                push @$control_widgets,  Dicole::Widget::Hyperlink->new (
                    link => $data->{unfeature_url},
                    class =>'blogPostUnFeature',
                    title => $self->_msg('Unfeature'),
                );
            }
            else {
                push @$control_widgets,  Dicole::Widget::Hyperlink->new (
                    link => $data->{feature_url},
                    class =>'blogPostFeature',
                    title => $self->_msg('Feature'),
                );
            }
        }
        
        push @$control_widgets,  Dicole::Widget::Hyperlink->new (
            link => $data->{edit_url},
            class =>'blogPostEdit',
            title => $self->_msg('Edit'),
        ) if $self->schk_y( 'OpenInteract2::Action::Weblog::user_edit', $user->id );

    }
    
    my $action_widgets = [];
    unless ( $conf->{no_action} ) {
        my $promote_widget = ();
        
        if ( $self->_promoting_enabled_for_seed( $seed ) && $self->schk_y( 'OpenInteract2::Action::DicoleBlogs::promote' ) ) {
            $promote_widget = CTX->lookup_action('blogs_voting')->execute('promote_widget', {
                entry => $entry,
                target_group_id => $self->param('target_group_id'),
                user_id => CTX->request->auth_user_id,
            } ) || ();
        }
        
        my $promote_container = Dicole::Widget::Container->new(
            class => 'blogs_promote_container' .
                ' blogs_promote_promote_id_' . $entry->id . '_container' .
                ' blogs_promote_demote_id_' . $entry->id . '_container',
            id => 'blogs_promote_container_' . $entry->id,
            contents => [ $promote_widget ],
        );
        
        push @$action_widgets, $promote_container;
        
        eval {
            die if $conf->{no_comment_action};
            
            CTX->lookup_action('commenting');
            
            push @$action_widgets, Dicole::Widget::Hyperlink->new(
                link => $data->{show_comments_url},
                class=>'blogPostDiscuss',
                content => $self->_msg( 'Discuss' ),
            );
        };
    }
    
    my $meta_widgets = [];
    unless ( $conf->{no_meta} ) {
        unless ( $conf->{no_rating} ) {
            my $rate_widget = ();
            if ( $self->_rating_enabled_for_seed( $seed ) ) {
                $rate_widget = CTX->lookup_action('blogs_voting')->execute('rate_widget', {
                    entry => $entry,
                    target_group_id => $self->param('target_group_id'),
                    user_id => CTX->request->auth_user_id,
                    rating_disabled => $self->schk_y( 'OpenInteract2::Action::DicoleBlogs::rate' ) ? 0 : 1,
                } ) || ();
            }
            
            my $rate_container = Dicole::Widget::Container->new(
                class => 'blogs_rate_container',
                id => 'blogs_rate_container_' . $entry->id,
                contents => [ $rate_widget ],
            );
            
            push @$meta_widgets, $rate_container;
        }
        
        my $points_classes = 'blogs_promote_promote_id_' . $entry->id . '_points_container' .
            ' blogs_promote_demote_id_' . $entry->id . '_points_container';
        my $points = $conf->{no_points} ? () : Dicole::Widget::Raw->new( raw =>
            '<span id="blogs_points_container_'.$entry->id.'" class="'. $points_classes .'">'.
            $entry->points.'</span> points'
        );
        
        eval {
            die if $conf->{no_comment_count};
            
            my $comment_count = CTX->lookup_action('commenting')->execute( 'get_comment_count', {
                object => $entry
            } ) || 0;
            
            push @$meta_widgets, Dicole::Widget::Container->new(
                contents => [
                    $points,
                    ', ',
                    Dicole::Widget::Hyperlink->new(
                        link => $data->{show_comments_url},
                        content => $self->_msg('[_1] Comments', $comment_count ),
                    )
                ],
                class => 'blogPostComments',
            );
        };
        if ( $@ ) {
            push @$meta_widgets, Dicole::Widget::Container->new(
                contents => [ $points ],
                class => 'blogPostComments',
            );
        }
        
        if ( $tags && ! $conf->{no_tags} ) {
            my $tage = join ', ', @$tags;
            $tage = Dicole::Utils::HTML->encode_entities($tage);
            my $html = '<div class="blogPostTags">' . $tage;
            if ( $self->schk_y( 'OpenInteract2::Action::DicoleBlogs::add_tags' ) && ! $conf->{no_add_tags} ) {
                $html .= ( scalar(@$tags) ? ', ' :'' ) .'<a href="' . $data->{add_tags_url} . '">' .
                    $self->_msg('Add missing tags') .'</a>';
            }
            $html .= '</div>';
            push @$meta_widgets, Dicole::Widget::Raw->new( raw => $html );
        }
    }

    my $source_widget = undef;
    if ( $conf->{include_source} ) {
        my $source = $data->{source};
        if ( $source && $source->show_source ) {
            my $inline = Dicole::Widget::Inline->new(
                contents => [
                    $self->_msg( 'Source:' ), ' ',
                    Dicole::Widget::Hyperlink->new(
                        link => $source->original_link || $source->source_link || '#',
                        class=>'blogPostSourceLink',
                        content => $source->reposter_name || $source->source_name || $source->original_name || '?',
                    )
                ],
            );
            $source_widget = Dicole::Widget::Container->new(
                contents => [ $inline ],
                class => 'blogPostSource',
            );
        }
    }

    return Dicole::Widget::BlogPost->new(
        id => 'blogs_entry_container_' . $entry->id,
        $title ? ( title => $title ) : (),
        preview => $content,
        date => $date,
        author => $author,
        meta_widgets => $meta_widgets,
        control_widgets => $control_widgets,
        action_widgets => $action_widgets,
        $source_widget ? ( source => $source_widget ) : (),
        $read_more ? ( read_more => $read_more ) : (),
    );

}

sub _attachment_list_html {
    my ( $self, $object, $as ) = @_;

    return $self->_generic_attachment_list_html( $object, $as, 0 );
}

sub _draft_attachment_list_html {
    my ( $self, $object, $as ) = @_;

    return $self->_generic_attachment_list_html( $object, $as, 1 );
}

sub _generic_attachment_list_html {
    my ( $self, $object, $attachments, $draft ) = @_;

    return CTX->lookup_action('attachment')->execute( get_attachment_list_html_for_object => {
        action => $self, action_name => 'blogs', delete_action_name => 'blogs_json',
        attachments => $attachments, object => $object,
        task_name => $draft ? 'draft_attachment' : 'attachment',
    } );
}

sub _attachment_list_data {
    my ( $self, $object, $as ) = @_;

    return $self->_generic_attachment_list_data( $object, $as, 0 );
}

sub _draft_attachment_list_data {
    my ( $self, $object, $as ) = @_;

    return $self->_generic_attachment_list_data( $object, $as, 1 );
}

sub _generic_attachment_list_data {
    my ( $self, $object, $attachments, $draft ) = @_;

    return CTX->lookup_action('attachment')->execute( get_attachment_list_data_for_object => {
        action => $self, action_name => 'blogs', delete_action_name => 'blogs_json',
        attachments => $attachments, object => $object,
        task_name => $draft ? 'draft_attachment' : 'attachment',
        delete_task_name => $draft ? 'draft_attachment_remove_data' : 'attachment_remove_data',
        delete_all_right => 1,
    } );
}

sub _attachment_listing_widget {
    my ( $self, $entry, $attachments ) = @_;

    my $listing = Dicole::Widget::Listing->new;
    for my $a ( @$attachments ) {
        $listing->add_row(
            { content => Dicole::Widget::Hyperlink->new(
                content => $a->filename,
                'link' => $self->derive_url(
                    action => 'blogs',
                    task => 'attachment',
                    additional => [ $entry->id, $a->id, $a->filename ],
                ),
            ) },
            { content => ( $a->mime =~ /image/ ) ?
                ( Dicole::Widget::Hyperlink->new(
                    content => Dicole::Widget::Image->new(
                        title => $a->filename,
                        'src' => $self->derive_url(
                            action => 'blogs',
                            task => 'attachment',
                            additional => [ $entry->id, $a->id, $a->filename ],
                            params => { thumbnail => 1 },
                        ),
                    ),
                    'link' => $self->derive_url(
                        action => 'blogs',
                        task => 'attachment',
                        additional => [ $entry->id, $a->id, $a->filename ],
                    ),
                ) )
                :
                ()
            },
            { content => Dicole::Widget::Hyperlink->new(
                content => Dicole::Widget::Text->new(
                    text => $self->_msg( 'Remove' ),
                    class => 'blogs_attachment_remove_text'
                ),
                'link' => $self->derive_url(
                    action => 'blogs_json',
                    task => 'attachment_remove',
                    additional => [ $entry->id, $a->id ],
                ),
                class => 'blogs_attachment_remove_link',
            ) }
        );
    }

    return $listing;
}

sub _remove_by_post {
    my ( $self, $post_id, $domain_id ) = @_;
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'post_id = ?',
        value => [ $post_id ],
    } ) || [];
    
    $self->_remove_entry( $_, $domain_id ) for @$entries;
    
    my $pubs = CTX->lookup_object('blogs_published')->fetch_group( {
        where => 'post_id = ?',
        value => [ $post_id ],
    } ) || [];
    
    eval { $_->remove } for @$pubs;
}

sub _remove_entry {
    my ( $self, $entry, $domain_id ) = @_;

    CTX->lookup_action('blogs_api')->execute( 'init_store_delete_event', {
        entry => $entry,
        domain_id => $domain_id,
        user_id => CTX->request ? CTX->request->auth_user_id : 0,
    } );

    eval {
        CTX->lookup_action('tagging')->execute( 'remove_tags', {
            object => $entry,
            group_id => $entry->group_id,
            user_id => 0,
            domain_id => $domain_id,
        } );
        CTX->lookup_action('tagging')->execute( 'remove_tags', {
            object => $entry,
            group_id => $entry->group_id,
            user_id => $entry->user_id,
            domain_id => $domain_id,
        } );
    };
    
    my $seed_id = $entry->seed_id;
    
    my $deleted_entry = CTX->lookup_object('blogs_deleted_entry')->new;
    $deleted_entry->deleted_date( time );
    $deleted_entry->entry_id( $entry->id );
    $deleted_entry->set( $_,  $entry->get( $_ ) ) for ( qw(
        group_id
        seed_id
        post_id
        user_id
        date
        last_updated
    ) );
    
    $deleted_entry->save;
    
    #CTX->lookup_action('search_api')->execute(remove => {object => $entry});
    $entry->remove;
    
    my $seed = eval { CTX->lookup_object('blogs_seed')->fetch( $seed_id ); };
    
    if ( $seed ) {
        $self->_update_seed_stats( $seed );
    }
}

sub _update_seed_stats {
    my ( $self, $seed_or_seed_id ) = @_;
    
    return 1 unless $seed_or_seed_id;
    
    my $seed = ref( $seed_or_seed_id ) ? $seed_or_seed_id :
        eval{ CTX->lookup_object('blogs_seed')->fetch( $seed_or_seed_id ) };
    
    return 0 unless ref( $seed );
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'seed_id = ?',
        value => [ $seed->id ],
    } ) || [];
    
    $self->_update_seed_active_date( $seed, $entries );
    $self->_update_seed_post_count( $seed, $entries );
}

sub _update_seed_active_date {
    my ( $self, $seed, $entries ) = @_;
    
    $entries ||= CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'seed_id = ?',
        value => [ $seed->id ],
    } ) || [];
    
    my $save = 0;
    for my $entry ( @$entries ) {
        if ( $entry->date > ( $seed->active_date || 0 ) ) {
            $seed->active_date( $entry->date );
            $save = 1;
        }
    }
    $seed->save if $save;
}

sub _update_seed_post_count {
    my ( $self, $seed, $entries ) = @_;
    
    my $count = $entries ? scalar( @$entries ) : CTX->lookup_object('blogs_entry')->fetch_count( {
        where => 'seed_id = ?',
        value => [ $seed->id ],
    } ) || 0;
    
    if ( $count != $seed->post_count ) {
        $seed->post_count( $count );
        $seed->save;
    }
}

sub _get_draft {
    my ( $self, $uid, $gid ) = @_;

    $uid ||= ( CTX->request ? CTX->request->auth_user_id : undef ) || $self->param('user_id');
    $gid ||= ( CTX->request ? $self->param('target_group_id') : undef ) || $self->param('group_id');

    my $draft_id = ( CTX->request ? CTX->request->param('draft_id') : undef ) || $self->param('draft_id');
    return undef unless $draft_id;

    my $draft = CTX->lookup_object('blogs_draft_entry')->fetch( $draft_id );

    undef $draft if $draft && ( $draft->user_id != $uid || $draft->group_id != $gid );

    return $draft;
}

sub _get_or_create_draft {
    my ( $self, $seed_id ) = @_;

    my $uid = ( CTX->request ? CTX->request->auth_user_id : undef ) || $self->param('user_id');
    my $gid = ( CTX->request ? $self->param('target_group_id') : undef ) || $self->param('group_id');

    my $draft = $self->_get_draft( $uid, $gid );

    unless ( $draft ) {
        my $sid = $seed_id || ( CTX->request ? CTX->request->param('seed_id') : undef ) || $self->param('seed_id') || 0;

        $draft = CTX->lookup_object('blogs_draft_entry')->new;
        $draft->user_id( $uid );
        $draft->group_id( $gid );
        $draft->seed_id( $sid );
        $draft->save;
    }

    return $draft;
}

sub _clean_draft {
    my ( $self, $draft ) = @_;

    CTX->lookup_action('attachment')->execute( purge_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    CTX->lookup_action('tagging')->execute( remove_tags => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    $draft->remove;
}

sub _process_published_content {
    my ( $self, $entry, $content ) = @_;

    my $tree = Dicole::Utils::HTML->safe_tree( $content );
    my @atags = $tree->look_down( _tag => 'a' );
    my @imgtags = $tree->look_down( _tag => 'img' );

    $_->attr('href', $self->_process_published_url( $entry, $_->attr('href') ) ) for @atags;
    $_->attr('title', $self->_process_published_url( $entry, $_->attr('title') ) ) for @atags;

    $_->attr('src', $self->_process_published_url( $entry, $_->attr('src') ) ) for @imgtags;
    $_->attr('alt', $self->_process_published_url( $entry, $_->attr('alt') ) ) for @imgtags;
    $_->attr('title', $self->_process_published_url( $entry, $_->attr('title') ) ) for @imgtags;

    return Dicole::Utils::HTML->tree_guts_as_xml( $tree );
}

sub _process_published_url {
    my ( $self, $entry, $string ) = @_;

    my @parts = ();
    for my $part ( split / /, $string ) {
        my ( $host, $abs ) = $part =~ /^(https?\:\/\/.*?)?(\/.*)$/;
        # TODO: make sure it is really our domain.. though it's highly unlikely
        # TODO: that some other domain would parse as blogs draft attachment url ;)
        if ( $abs ) {
            my $action = OpenInteract2::ActionResolver::Dicole->resolve( undef, $abs );
            if ( $action && $action->name eq 'blogs' && $action->task =~ /^(draft|temp)_attachment$/ ) {
                if ( $action->param('attachment_id') ) {
                    my $url = $action->derive_url( task => 'attachment', additional => [
                        $entry->id,
                        scalar( $action->param('attachment_id') ),
                        scalar( $action->param('filename') ),
                    ] );

                    my $uri = eval { URI->new( $url ) };
                    if ( $uri ) {
                        my %keys = $uri->query_form;
                        if ( $keys{login_login_name} || $keys{login_password} ) {
                            my @query = $uri->query_form;
                            my @new_query = ();
                            while ( scalar( @query ) )  {
                                my $key = shift @query;
                                my $value = shift @query;
                                next if $key eq 'login_login_name' || $key eq 'login_password';
                                push @new_query, ( $key, $value );
                            }
                            $uri->query_form( \@new_query );
                            $url = $uri->as_string;
                        }
                    }

                    $abs = $url;

                    if ( $action->task =~ /^temp_attachment$/ ) {
                        my $post = $self->_fetch_post_for_entry( $entry );
                        CTX->lookup_action('attachment')->execute( reattach => {
                            attachment_id => scalar( $action->param('attachment_id') ),
                            object => $post,
                            user_id => 0,
                            group_id => scalar( $action->param('target_group_id') ),
                        } );
                    }
                }
            }
        }
        push @parts, ( $abs ? $host . $abs : $part );
    }

    return join( ' ', @parts );
}

sub _entry_for_post_id {
    my ( $self, $post_id ) = @_;

    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'post_id = ?',
        value => [ $post_id ],
    } ) || [];

    return shift @$entries;
}

sub _update_reposter {
    my ( $self, $reposter, $first_fetch ) = @_;

    my $time = time;

    my $feed = eval {
        Dicole::Feed->fetch( $reposter->url, undef, $reposter->username, $reposter->password );
    };

    if ( $@ ) {
        $reposter->fetch_error( $@ );
        $reposter->error_count( $reposter->error_count + 1 );
        $reposter->next_update( $time + $reposter->fetch_delay * $reposter->error_count );
        $reposter->save;
        return 0;
    }

    $first_fetch ||= $reposter->last_update ? 0 : 1;

    $reposter->error_count( 0 );
    $reposter->fetch_error( '' );
    $reposter->last_update( $time );
    $reposter->next_update( $time + $reposter->fetch_delay );

    $reposter->save;

    my @append_tags = split /\s*\,\s*/, $reposter->append_tags;
    my @filter_tags = split /\s*\,\s*/, $reposter->filter_tags;

    for my $feed_entry ( $feed->entries ) {
        # if this fails t some point, just report it - don't die.
        eval {
            my @cats = $feed_entry->category;

            if ( scalar( @filter_tags ) ) {
                my $found = 0;
                for my $tag ( @filter_tags ) {
                    $found++ if grep { lc( Dicole::Utils::Text->ensure_internal( $tag ) ) eq lc( Dicole::Utils::Text->ensure_internal( $_ ) ) } @cats;
                }
                next if $found < scalar( @filter_tags );
            }

            if ( ! $reposter->apply_tags ) {
                @cats = ();
            }

            push @cats, @append_tags;
            my $cats = [ map { Dicole::Utils::Text->ensure_utf8( $_ ) } @cats ];

            my $date = $feed_entry->issued ? $feed_entry->issued->epoch : 0;

            my $create_entry_if_needed = 1;
            $create_entry_if_needed = 0 if $first_fetch && ! $date;
            $create_entry_if_needed = 0 if $date && $reposter->max_age && $date < $time - $reposter->max_age;

            # ignore timestamps more than an hour in the future after factoring the max age
            $date = 0 if $date > $time + 3600;

            my $title = Dicole::Utils::Text->ensure_utf8( $feed_entry->title );
            my $shown_title = ( $reposter->title && $reposter->append_title ) ?
                $title . ' (' . $reposter->title . ')' : $title;

            my $content = Dicole::Utils::Text->ensure_utf8( $feed_entry->content->body );

            my $raw_digest = Digest::SHA1::sha1_hex( Storable::freeze( $feed_entry ) );
            my $id_digest = Digest::SHA1::sha1_hex( Storable::freeze( [ $feed_entry->id ] ) );
            my $tc_digest = Digest::SHA1::sha1_hex( Storable::freeze( [ $title, $content ] ) );

            my $datas = CTX->lookup_object( 'blogs_reposted_data' )->fetch_group( {
                where => 'reposter_id = ? AND ( raw_digest = ? OR id_digest = ? OR tc_digest = ? )',
                value => [ $reposter->id, $raw_digest, $id_digest, $tc_digest ],
            } ) || [];

            my @raw_datas = grep { $_->{raw_digest} eq $raw_digest } @$datas;
            next if scalar( @raw_datas );

            my @id_datas = grep { $_->{id_digest} eq $id_digest } @$datas;
            my @tc_datas = grep { $_->{tc_digest} eq $tc_digest } @$datas;
            my $data = scalar( @id_datas ) ? shift @id_datas : shift @tc_datas;

            my $entry_id = $data ? $data->posted_as_entry : 0;

            if ( $data ) {
                if ( $data->posted_as_entry ) {
                    # Just let this die if the entry has been removed
                    CTX->lookup_action('blogs_api')->execute( update_entry => {
                        entry_not_found_ok => 1,
                        domain_id => $reposter->domain_id,
                        entry_id => $entry_id,
                        title => $shown_title,
                        content => $content,
                        tags => $cats,
                        source_name => $feed->title,
                        source_link => $feed->link,
                        original_name => $title,
                        original_link => $feed_entry->link,
                        original_date => $date,
                        reposter_id => $reposter->id,
                        reposter_name => $reposter->title,
                        show_source => $reposter->show_source,
                        ( $date ? ( date => $date ) : ()  ),
                    } );
                }
            }
            else {
                $data = CTX->lookup_object('blogs_reposted_data' )->new;
                $data->domain_id( $reposter->domain_id );
                $data->reposter_id( $reposter->id );

                if ( $create_entry_if_needed ) {
                    my $entry = CTX->lookup_action('blogs_api')->execute( create_entry => {
#                        unique_id => Dicole::Utils::Text->ensure_utf8( $feed_entry->id ),
                        user_id => $reposter->user_id,
                        group_id => $reposter->group_id,
                        seed_id => $reposter->seed_id,
                        domain_id => $reposter->domain_id,
                        title => $shown_title,
                        content => $content,
                        tags => $cats,
                        source_name => $feed->title,
                        source_link => $feed->link,
                        original_name => $title,
                        original_link => $feed_entry->link,
                        original_date => $date,
                        reposter_id => $reposter->id,
                        reposter_name => $reposter->title,
                        show_source => $reposter->show_source,
                         ( $date ? ( creation_date => $date ) : ()  ),
                    } );

                    $data->posted_as_entry( $entry->id );
                }
                else {
                    $data->posted_as_entry( 0 );
                }
            }

            # make sure the entry contains the right digests and is saved
            unless (
                $data->{raw_digest} eq $raw_digest &&
                $data->{id_digest} eq $id_digest &&
                $data->{tc_digest} eq $tc_digest
            ) {
                $data->raw_digest( $raw_digest || '' );
                $data->id_digest( $id_digest || '' );
                $data->tc_digest( $tc_digest || '' );
                $data->save;
            }
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error('Failed to update entry ['. $feed_entry->id .'] from reposter '.$reposter->id.': ' . $@);
        }
    }
}

1;
