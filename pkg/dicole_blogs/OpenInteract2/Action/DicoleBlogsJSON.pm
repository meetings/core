package OpenInteract2::Action::DicoleBlogsJSON;

use strict;
use base qw( OpenInteract2::Action::DicoleBlogsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub object_info {
    my ( $self ) = @_;

    my $data = eval {
        $self->_entry_data( $self->param('entry_id'), 0 );
    };

    die "entry not found" unless $data;

    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "entry not found" unless $group_id && $data->{entry}{group_id} == $group_id;

    my $info = {
        title => $data->{post}->title,
        date => $data->{entry}->date,
        date_ago => Dicole::Utils::Date->localized_ago( epoch => $data->{entry}->date ),
        content => $self->_process_post_content_for_output( $data->{post}->content ),
        tags => $data->{tags},
        author_name => $data->{author_name},
        author_url => Dicole::Utils::User->url( $data->{user}, $group_id ),
        author_image => Dicole::Utils::User->image( $data->{user}, CTX->request->param('author_size') || 64 ),
        comments => CTX->lookup_action('comments_api')->e( get_comments_info => {
            object => $data->{entry},
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            size => CTX->request->param('commenter_size') || 60,
        } ),
        show_url => $data->{show_url},
    };

    return { result => $info };
}

sub store_draft {
    my ( $self ) = @_;

    my $draft = $self->_get_or_create_draft;
    die "security error" unless $draft;

    $draft->title( CTX->request->param('title') );
    $draft->content( CTX->request->param('content') );

    $draft->save;

    my $post_tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    eval {
        my $tags = CTX->lookup_action('tagging');
        eval {
            $tags->execute( 'attach_tags_from_json', {
                object => $draft,
                json => $post_tags,
                user_id => $draft->user_id,
                group_id => 0,
            } );
        };
        $self->log('error', $@ ) if $@;
    };

    return { success => 1 };
}

sub draft_attachment_list {
    my ( $self ) = @_;

    my $draft = $self->_get_or_create_draft;
    die "security error" unless $draft;

   my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    my $html = $self->_draft_attachment_list_html( $draft, $as );

    return { content => $html };
}

sub attachment_list {
    my ( $self ) = @_;

    my $entry_id = $self->param('entry_id');
    return undef unless $entry_id;

    my $entry = CTX->lookup_object('blogs_entry')->fetch( $entry_id );
    die "security error" unless $entry;

    my $post = $self->_fetch_post_for_entry( $entry );
    die "security error" unless $post;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $post,
    } );

    my $html = $self->_attachment_list_html( $entry, $as );

    return { content => $html };
}

sub draft_attachment_list_data {
    my ( $self ) = @_;

    my $draft = $self->_get_draft;
    die "security error" unless $draft;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    return $self->_draft_attachment_list_data( $draft, $as );
}

sub attachment_list_data {
    my ( $self ) = @_;

    my $entry_id = $self->param('entry_id');
    return undef unless $entry_id;

    my $entry = CTX->lookup_object('blogs_entry')->fetch( $entry_id );
    die "security error" unless $entry;

    my $post = $self->_fetch_post_for_entry( $entry );
    die "security error" unless $post;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $post,
    } );

    return $self->_attachment_list_data( $entry, $as );
}

sub draft_attachment_post {
    my ( $self ) = @_;

    my $draft_id = $self->param('draft_id');
    return undef unless $draft_id;

    my $draft = CTX->lookup_object('blogs_draft_entry')->fetch( $draft_id );
    die "security error" unless $draft;

    eval {
        CTX->lookup_action('attachment')->execute( store_from_request_upload => {
            upload_name => 'Filedata',
            object => $draft,
            group_id => 0,
            user_id => $draft->user_id,
        } );
    };

    return CTX->request->param('i_am_flash') ? 'status=success' : '<textarea>status=success</textarea>';
}

sub attachment_post {
    my ( $self ) = @_;

    my $entry_id = $self->param('entry_id');
    return undef unless $entry_id;

    my $entry = CTX->lookup_object('blogs_entry')->fetch( $entry_id );
    die "security error" unless $entry;

    my $post = $self->_fetch_post_for_entry( $entry );
    die "security error" unless $post;


    eval {
        CTX->lookup_action('attachment')->execute( store_from_request_upload => {
            upload_name => 'Filedata',
            object => $post,
        } );
    };

    return CTX->request->param('i_am_flash') ? 'status=success' : '<textarea>status=success</textarea>';
}

sub new {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_blogs_entry.date desc',
    );
}

sub rated {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_blogs_entry.rating desc, dicole_blogs_entry.date desc',
    );
}

sub promoted {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_blogs_entry.points desc, dicole_blogs_entry.date desc',
    );
}

sub featured {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_blogs_entry.featured desc',
        undef,
        'dicole_blogs_entry.featured > 0'
    );
}

sub my {
    my ( $self ) = @_;
    my $uid = $self->param('user_id');
    return $self->_generic_listing(
        'dicole_blogs_entry.date desc', [ $uid ]
    );
}

sub contacts {
    my ( $self ) = @_;
    
    my $uid = $self->param('user_id');
    
    # TODO: move this to contacts package
    my $objects = CTX->lookup_object('networking_contact')->fetch_group( {
        where => 'user_id = ?',
        value => [ $uid ],
    } );
    
    my $ids = [ sort map { $_->contacted_user_id } @$objects ];
    
    return $self->_generic_listing(
        'dicole_blogs_entry.date desc', $ids
    );
}

sub _generic_listing {
    my ( $self, $order, $ids, $where ) = @_;

    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    my $page_load = CTX->request->param('page_load');
    my $shown_ids_json = CTX->request->param('shown_entry_ids');
    my $shown_ids = eval { $shown_ids_json ? JSON->new->jsonToObj( $shown_ids_json ) : [] };
    $shown_ids = [] unless ref( $shown_ids ) eq 'ARRAY';

    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        seed_id => $sid,
        user_ids => $ids,
        order => $order,
        where => 'dicole_blogs_entry.date < ? AND ' . Dicole::Utils::SQL->column_not_in(
            'dicole_blogs_entry.entry_id' => $shown_ids,
        ) . ( $where ? ' AND ' . $where : '' ),
        value => [ $page_load ],
        limit => 10,
    );

    my $widget = $self->_visualize_entry_list( $entries, $seed, 1 );
    my $html = $widget->generate_content;

    return { messages_html => $html }
}

sub attachment_remove_data {
    my ( $self ) = @_;
    
    my $data = eval {
        $self->_entry_data( $self->param('entry_id') );
    };
    
    if ( $@ ) {
        die( $self->_msg('The message you requested does not exist.') );
    }
    my %a_by_id = map { $_->id => $_ } @{ $data->{attachments} || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };
    
    unless ( $a ) {
        die( $self->_msg('The file you requested does not exist.') );
    }
    
    my $post = $data->{post};
    die "security error" unless $post && $self->schk_y(
        'OpenInteract2::Action::Weblog::user_edit', $post->user_id
    );
    
    CTX->lookup_action('attachment')->execute( remove => {
        attachment => $a,
    } );
    
    # Refresh attachments ;)
    $data = eval {
        $self->_entry_data( $self->param('entry_id') );
    };

    return $self->_generic_attachment_list_data( $data->{entry}, $data->{attachments} );
}

sub draft_attachment_remove_data {
    my ( $self ) = @_;

    my $draft = $self->_get_draft;
    die "security error" unless $draft;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    my %a_by_id = map { $_->id => $_ } @{ $as || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };

    unless ( $a ) {
        die( $self->_msg('The file you requested does not exist.') );
    }

    CTX->lookup_action('attachment')->execute( remove => {
        attachment => $a,
    } );

    # Refresh attachments ;)

    $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    return $self->_generic_attachment_list_data( $draft, $as, 1 );
}

sub attachment_remove {
    my ( $self ) = @_;
    
    my $data = eval {
        $self->_entry_data( $self->param('entry_id') );
    };
    
    if ( $@ ) {
        die( $self->_msg('The message you requested does not exist.') );
    }
    my %a_by_id = map { $_->id => $_ } @{ $data->{attachments} || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };
    
    unless ( $a ) {
        die( $self->_msg('The file you requested does not exist.') );
    }
    
    my $post = $data->{post};
    die "security error" unless $post && $self->schk_y(
        'OpenInteract2::Action::Weblog::user_edit', $post->user_id
    );
    
    CTX->lookup_action('attachment')->execute( remove => {
        attachment => $a,
    } );
    
    # Refresh attachments ;)
    $data = eval {
        $self->_entry_data( $self->param('entry_id') );
    };

    my $widget = $self->_attachment_listing_widget( $data->{entry}, $data->{attachments} );
    my $html = $widget->generate_content;

    return { messages_html => $html };
}

sub sync {
    my ( $self ) = @_;
    # TODO: create the blogs_api_key db
#     die;
#     my $api_key = CTX->request->param('api_key');
#     die "no api key" unless $api_key;
#     my $keys = CTX->lookup_object('blogs_api_key')->fetch_group({
#         where => 'api_key = ?',
#         value => [ $api_key ],
#         limit => 1,
#     }) || [];
#     my $key = pop @$keys;
#     die "invalid api key" unless $key;
    die 'invalid api key' unless ( CTX->request->param('api_key') eq CTX->server_config->{dicole}{temp_blogs_api_key} );

    my $gid = $self->param('target_group_id');
    my $sid = $self->param('seed_id');
    
#     die unless $gid == $key->group_id;
#     die unless $sid == $key->seed_id;
    die 'security error' unless $gid == 385 && $sid == 99;
    
    my $date = CTX->request->param('data_since') || 0;
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'last_updated >= ? AND group_id = ?' .
            ( $sid ? ' AND seed_id = ?' : ''),
        value => [ $date, $gid, $sid || () ],
    } );
    
    my $deleted_entries = CTX->lookup_object('blogs_deleted_entry')->fetch_group( {
        where => 'deleted_date >= ? AND group_id = ?' .
            ( $sid ? ' AND seed_id = ?' : ''),
        value => [ $date, $gid, $sid || () ],
    } );
    
    my @eids = ( map { $_->entry_id } ( @$entries, @$deleted_entries ) );
    my $uids = CTX->lookup_object('blogs_entry_uid')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( entry_id => \@eids ),
    } );
    my %uid_by_id = map { $_->entry_id => $_->uid } @$uids;
    
    my $timed_data = [];
    for my $entry ( @$entries ) {
        my $data = $self->_entry_data( $entry );
        my $media = [];
        for my $attachment ( @{ $data->{attachments} } ) {
        
            my $link = Dicole::URL->from_parts(
                action => 'blogs',
                task => 'attachment',
                additional => [ $entry->id, $attachment->id, $attachment->filename ],
            );
            
            my $host = Dicole::URL->get_server_url;
            my $shost = $host;
            $shost =~ s/^https?/https/;
            my $nhost = $host;
            $nhost =~ s/^https?/http/;
            
            my $data = CTX->lookup_action('attachment')->execute( file_as_base64 => {
                attachment => $attachment
            } );
            
            push @$media, {
                created_time => $attachment->{creation_time},
                edited_time => $attachment->{creation_time},
                filename => $attachment->{filename},
                links_in_content => [
                    $shost . $link,
                    $nhost . $link,
                ],
                base64_data => $data,
            };
            
            if ( $attachment->mime =~ /image/ ) {
                my $tlink = Dicole::URL->from_parts(
                    action => 'blogs',
                    task => 'attachment',
                    additional => [ $entry->id, $attachment->id, $attachment->filename ],
                    params => { thumbnail => 1 },
                );
                
                my $tdata = CTX->lookup_action('attachment')->execute( thumbnail_as_base64 => {
                    attachment => $attachment,
                    max_width => 400,
                } );
                
                push @$media, {
                    created_time => $attachment->{creation_time},
                    edited_time => $attachment->{creation_time},
                    filename => $attachment->{filename} . '.dicole.thumbnail.jpg',
                    links_in_content => [
                        $shost . $tlink,
                        $nhost . $tlink,
                    ],
                    base64_data => $tdata,
                };
            }
        }
        
        push @$timed_data, [
            $data->{post}->edited_date,
            {
                type => 'post',
                uid => $uid_by_id{ $entry->id },
                created_time => $data->{post}->date,
                edited_time => $data->{post}->edited_date,
                title => $data->{post}->title,
                creator_email => $data->{user}->email,
                # TODO: does this need preprocessing??
                content => $data->{post}->{content},
                tags => $data->{tags},
                url => $data->{show_url},
                
                media => $media,
            }
        ],
    }
    
    for my $entry ( @$deleted_entries ) {
        push @$timed_data, [
            $entry->deleted_date,
            {
                type => 'post',
                uid => $uid_by_id{ $entry->uid },
                removed_time => $entry->deleted_date,
            }
        ],
    }
    
    return [ map { $_->[1] } sort( { $a->[0] <=> $b->[0] } @$timed_data ) ];
}
1;