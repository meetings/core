package OpenInteract2::Action::DicoleComments;

use strict;
use base qw( OpenInteract2::Action::DicoleCommentsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Tree::Creator::Hash;
use Dicole::Widget::Comment;
use Dicole::Widget::Raw;
use Dicole::Utils::HTML;
use Dicole::Utils::User;
use Storable;
use Digest::MD5 qw();
use List::Util;

use Data::Dumper;
# $self->log('error', Data::Dumper::Dumper($thread));

$OpenInteract2::Action::DicoleComments::VERSION = sprintf("%d.%02d", q$Revision: 1.32 $ =~ /(\d+)\.(\d+)/);

sub comment_count {
    my ( $self ) = @_;
    
    my $gid = $self->param('group_id');
    my $uid = $self->param('user_id');
    
    my $count = CTX->lookup_object('comments_post')->fetch_count( {
        from => [ 'dicole_comments_post', 'dicole_comments_thread' ],
        where => 'dicole_comments_post.thread_id = dicole_comments_thread.thread_id AND ' . 
            'dicole_comments_post.user_id = ? AND dicole_comments_thread.group_id = ? AND ' .
            'dicole_comments_post.removed = 0 AND dicole_comments_post.published != 0',
        value => [ $uid, $gid ],
    } ) || 0;
    
    return $count;
}

sub add_comment {
    my ( $self ) = @_;
    
    my $thread = $self->add_comment_and_return_thread;
    
    my $messages_widget = $self->_get_messages_widget( $thread );
    return { messages_html => $messages_widget->generate_content };
}

sub add_comment_and_return_info {
    my ( $self ) = @_;
    
    my $thread = $self->add_comment_and_return_thread;

    return $self->_thread_comment_info_array(
        $thread, $self->param('group_id'), $self->param('size'), $self->param('domain_id')
    );
}

sub add_comment_and_return_thread {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_add_comment_and_return_both;

    return $thread;
}

sub add_comment_and_return_post {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_add_comment_and_return_both;

    return $post;
}

sub _add_comment_and_return_both {
    my ( $self ) = @_;
    
    # calls populate_params
    my $thread = $self->_get_or_create_thread_object_using_params;
   
    return 0 unless $thread;
    
    my $post_object = CTX->lookup_object('comments_post');
    
    my $secondary_source = CTX->request || $self;

    my $publish = $self->param('requires_approval') ? 0 : 1;
    $publish ||= $self->param('right_to_publish_comments') ? 1 : 0;

    my $content = $self->param('content') || $secondary_source->param('content');
    $content ||= ( defined $self->param('content_text') || defined $secondary_source->param('content_text') ) ? Dicole::Utils::HTML->text_to_phtml( $self->param('content_text') ? $self->param('content_text') : $secondary_source->param('content_text') ) : '';
    
    my $post = $post_object->new();
    $post->{thread_id} = $thread->id;
    $post->{user_id} = $self->param('requesting_user_id') || 0;
    $post->{date} = $self->param('date') || time;
    $post->{published} = $publish ? $self->param('date') || time : 0;
    $post->{published_by} = 0;
    $post->{content} = $content;
    $post->{edited} = 0;
    $post->{edited_by} = 0;
    $post->{removed} = 0;
    $post->{removed_by} = 0;
    $post->{anon_name} = $self->param('anon_name') || $secondary_source->param('anon_name');
    $post->{anon_email} = $self->param('anon_email') || $secondary_source->param('anon_email');
    $post->{anon_url} = $self->param('anon_url') || $secondary_source->param('anon_url');

    if ( $self->param('enable_private_comments') ) {
        $post->{is_private} = ( $self->param('submit_privately') || $secondary_source->param('submit_privately') ) ? 1 : 0;
    }

    my $parent_post =  $self->param('parent_post_id') ? eval { $post_object->fetch(
        $self->param('parent_post_id') || $secondary_source->param('parent_post_id')
    ) } : undef;
    
    $post->{parent_post_id} = $parent_post ? $parent_post->id : 0;
    $post->save;
    
    $self->_refresh_thread_message_caches( $thread, $post );

    #CTX->lookup_action('search_api')->execute(process => {object => $post, domain_id => $self->_current_domain_id});
    eval { $self->_store_creation_event( $post, $thread ); };
    if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }

    if ( $publish ) {
        eval { $self->_send_object_watcher_emails( $post, $thread ); };
        if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }
    }
    else {
        eval { $self->_send_comment_approver_emails( $post, $thread ); };
        if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }        
    }

    if ( $self->param('requesting_user_id') && eval { CTX->lookup_action('bookmarks_api') } ) {
        my $bookmarking_action = CTX->lookup_action('bookmarks_api')->e( get_user_bookmark_action_for_object => {
            creator_id => $self->param('requesting_user_id'),
            group_id => $thread->group_id,
            object_id => $thread->object_id,
            object_type => $thread->object_type,
        } );

        if ( $bookmarking_action eq 'add' ) {
            # Add bookmark only if this was the first post from the user
            my $posts = CTX->lookup_object('comments_post')->fetch_group({
                where => 'thread_id = ? AND user_id = ?',
                value => [ $thread->id,  $self->param('requesting_user_id') ],
            }) || [];

            if ( scalar( @$posts ) == 1 ) {
                CTX->lookup_action('bookmarks_api')->e( add_user_bookmark_for_object => {
                    creator_id => $self->param('requesting_user_id'),
                    group_id => $thread->group_id,
                    object_id => $thread->object_id,
                    object_type => $thread->object_type,
                } );
            }
        }
    }

    return ( $thread, $post );
}

sub publish_comment {
    my ( $self ) = @_;
    
    my $thread = $self->publish_comment_and_return_thread;
    
    my $messages_widget = $self->_get_messages_widget( $thread );
    return { messages_html => $messages_widget->generate_content };
}

sub publish_comment_and_return_thread {
    my ( $self ) = @_;
    
    # calls populate_params
    my $thread = $self->_get_thread_object_using_params;
    
    my $secondary_source = CTX->request || $self;
    
    my $post = eval { CTX->lookup_object('comments_post')->fetch(
         $self->param('post_id') || $secondary_source->param('post_id')
    ) };
    
    my $uid = $self->param('requesting_user_id') || CTX->request->auth_user_id;
    
    if ( $post && $post->published == 0 && $thread && $post->thread_id == $thread->id ) {
        if ( $self->param('right_to_publish_comments') ) {
            $post->published( $self->param('date') || time );
            $post->published_by( $self->param('requesting_user_id') || 0 );
            $post->save;
            eval { $self->_store_publishing_event( $post, $thread ); };
            if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }

            eval { $self->_send_object_watcher_emails( $post, $thread ); };
            if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }            
            $self->_refresh_thread_message_caches( $thread, $post );
        }
    }
    
    return $thread;

}

sub edit_comment_and_return_thread {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_edit_comment_and_return_both;

    return $thread;
}

sub edit_comment_and_return_post {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_edit_comment_and_return_both;

    return $post;
}

sub _edit_comment_and_return_both {
    my ( $self ) = @_;
    
    # calls populate_params
    my $thread = $self->_get_or_create_thread_object_using_params;
   
    return 0 unless $thread;

    my $secondary_source = CTX->request || $self;
    
    my $post = eval { CTX->lookup_object('comments_post')->fetch(
        $self->param('post_id') || $secondary_source->param('post_id')
    ) };
   
    my $uid = $self->param('requesting_user_id') || CTX->request->auth_user_id;
    
    die "security error" unless $post && ( $post->user_id == $uid || $self->param('right_to_edit_comments') );


    if ( $post && $thread && $post->thread_id == $thread->id ) {
        $post->edited( $self->param('date') || time );
        $post->edited_by( $self->param('requesting_user_id') || eval{ CTX->request->auth_user_id } || 0 );
        $post->content( $self->param('content') || $secondary_source->param('content') );
        $post->save;

        eval { $self->_store_editing_event( $post, $thread ); };
        if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }

        $self->_refresh_thread_message_caches( $thread, $post );
    }
    
    return ( $thread, $post );
}

sub init_store_creation_event {
    my ( $self ) = @_;

    return $self->_store_creation_event(
        $self->param('post'),
        $self->param('thread'),
        $self->param('domain_id'),
    );
}

sub _store_creation_event {
    my ( $self, $post, $thread, $domain_id ) = @_;

    return $self->_store_custom_event( $post, $thread, $domain_id, 'created');
}

sub _store_publishing_event {
    my ( $self, $post, $thread, $domain_id ) = @_;

    return $self->_store_custom_event( $post, $thread, $domain_id, 'published');
}

sub _store_editing_event {
    my ( $self, $post, $thread, $domain_id ) = @_;

    return $self->_store_custom_event( $post, $thread, $domain_id, 'edited');
}

sub _store_deletion_event {
    my ( $self, $post, $thread, $domain_id ) = @_;

    return $self->_store_custom_event( $post, $thread, $domain_id, 'deleted');
}

sub _store_custom_event {
    my ( $self, $post, $thread, $domain_id, $type ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );
    return unless $thread;

    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    # This is pretty much a hack. There should be a way for packages to register
    # object data generator actions for certain objects
    # for now they should just all be added to these gather functions.

    my $data = $self->_gather_object_data( $post, $thread, undef, $domain_id );
    return unless $data->{object_url};

    my %display_data = map { $_ => $data->{$_} }
        qw/ object_id object_tags /;

    $display_data{thread_id} = $thread->id;
    $display_data{comment_id} = $post->id;

    my $secure = Dicole::Security->serialize_secure( $data->{secure_string}, {
        user_id => $thread->{user_id},
        group_id => $thread->{group_id},
        domain_id => $domain_id,
    } );

    my $timestamp = time;
    $timestamp = $post->date if $type eq 'created';
    $timestamp = $post->edited if $type eq 'edited';
    $timestamp = $post->published if $type eq 'published';
    $timestamp = $post->removed if $type eq 'deleted';

    eval {
        my $a = CTX->lookup_action('event_source_api');
        eval {
            $a->e( add_event => {
                event_type => $data->{event_type} . '_' . $type,
                author => $data->{sender_user} ? $data->{sender_user}->id : 0,
                target_user => $thread->{user_id},
                target_group => $thread->{group_id},
                target_domain => $domain_id,
                timestamp => $timestamp,
                coordinates => [],
                classes => $data->{classes},
                interested => $data->{interested_users},
                tags => $data->{object_tags},
                topics => $data->{topics},
                secure_tree => $secure,
                data => \%display_data,
            } )
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error( $@ );
        }
    };
}

sub _send_comment_approver_emails {
    my ( $self, $post, $thread, $domain_id ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );
    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    # This is pretty much a hack. There should be a way for packages to register
    # object data generator actions for certain objects
    # for now they should just all be added to these gather functions.

    my $data = $self->_gather_object_data( $post, $thread, undef, $domain_id );
    return unless $data->{object_url};

    my $mail_params = {
        %$data,
    };

    my $comment_approvers = Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'comment_approver_users',
        group_id => $thread->group_id,
    );

    for my $id ( split /\s*,\s*/, $comment_approvers ) {
        my $user = CTX->lookup_object('user')->fetch( $id );
        next unless $user;
        
        $mail_params->{object_name} = Dicole::Utils::Localization->translate( 
            { lang => $user->language }, $mail_params->{foreign_object_name_key}, $mail_params->{raw_object_name}
        );

        # $self->_msg('comment_approval_email_subject_template');
        # $self->_msg('comment_approval_email_text_template');
        # $self->_msg('comment_approval_email_html_template');

        eval {
            Dicole::Utils::Mail->send_localized_template_mail(
                user => $user,
                lang => $user->language,
                template_key_base => 'comment_approval_email',
                template_params => $mail_params,
            );
        };
        if ( $@ ) {
            $self->log( 'error', "Cannot send comment approval email! $@" );
        }
    }
}

sub _send_object_watcher_emails {
    my ( $self, $post, $thread, $domain_id ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );
    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    return if Dicole::Utils::Domain->setting( $domain_id, 'disable_notifications' );

    my $no_groups_json = Dicole::Utils::Domain->setting( $domain_id, 'disable_notifications_for_groups' );
    my $no_groups = $no_groups_json ? eval { Dicole::Utils::JSON->decode( $no_groups_json ) } || [] : [];

    for my $no_group ( @$no_groups ) {
        return if $thread->group_id == $no_group;
    }

    # This is pretty much a hack. There should be a way for packages to register
    # object data generator actions for certain objects
    # for now they should just all be added to these gather functions.

    my $data = $self->_gather_object_data( $post, $thread, undef, $domain_id );
    return unless $data->{object_url};

    my $mail_params = {
        %$data,
        object_name => '', # filled with algorithm
    };

    my $conf = $self->_domain_specific_mail_template_source_hash(
        'dicole_comments::comment_watcher_mail', $domain_id
    );

    for my $id ( @{ $data->{interested_users} || [] } ) {
        my $user = CTX->lookup_object('user')->fetch( $id );
        next unless $user;
        
        my $key = $user->id == $data->{owner_uid} ?
            $mail_params->{own_object_name_key} : $mail_params->{foreign_object_name_key};

        $mail_params->{object_name} = Dicole::Utils::Localization->translate( 
            { lang => $user->language }, $key, $mail_params->{raw_object_name}
        );
        
        eval {
            Dicole::Utils::Mail->send_to_user(
                user => $user,
                domain_id => $domain_id,
                %{ $self->_generate_domain_specific_mail_params_with_source_hash( $conf->{ $user->language }, $mail_params ) }
            );
        };
        if ( $@ ) {
            $self->log( 'error', "Cannot send comment notify email! $@" );
        }
    }
}

sub _gather_object_data {
    my ( $self, $post, $thread, $obj, $domain_id ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );
    $domain_id = $self->_current_domain_id unless defined( $domain_id );

    my ( $object, $uid, $gid ) = $self->_gather_object_owner_and_group( $post, $thread, $obj );
    return {} unless $object;

    my $data = {};

    if ( $thread->object_type eq 'OpenInteract2::BlogsEntry' ) {
        my $title = CTX->lookup_action('blogs_api')->execute( entry_title => { entry => $object } );
        my $urltitle = CTX->lookup_action('blogs_api')->execute( entry_urltitle => { entry => $object } );
        my %show_parts = (
            action => 'blogs',
            task => 'show',
            target => $gid,
            additional => [ $object->seed_id, $object->id, $urltitle ],
            domain_id => $domain_id,
        );

        $data = {
            event_type => 'blog_comment',
            classes => [ 'comment', 'blog_comment' ],
            topics => [ 'comment_thread:' . $thread->id, 'blog_entry:' . $object->id ],
            raw_object_name => $title,
            own_object_name_key => 'your post "[_1]"',
            foreign_object_name_key => 'blog post "[_1]"',
            object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_message_' . $thread->id . '_' . $post->id,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_input_container_' . $thread->id,
            ),
            secure_string => 'OpenInteract2::Action::DicoleBlogs::read',
        };
    }
    elsif ( $thread->object_type eq 'OpenInteract2::PresentationsPrese' ) {
        my %show_parts = (
            action => 'presentations',
            task => 'show',
            target => $gid,
            additional => [ $object->id ],
            domain_id => $domain_id,
        );

        $data = {
            event_type => 'media_comment',
            classes => [ 'comment', 'media_comment' ],
            topics => [ 'comment_thread:' . $thread->id, 'media_object:' . $object->id ],
            raw_object_name => $object->name,
            own_object_name_key => 'your media object "[_1]"',
            foreign_object_name_key => 'media object "[_1]"',
             object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_message_' . $thread->id . '_' . $post->id,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_input_container_' . $thread->id,
            ),
            secure_string => 'OpenInteract2::Action::DicolePresentations::view',
        };
    }
    elsif ($thread->object_type eq 'OpenInteract2::WikiPage') {
        my $title = $object->title;
        my %show_parts = (
            action => 'wiki',
            task => 'show',
            target => $gid,
            additional => [ $title ],
            domain_id => $domain_id,
        );

        $data = {
            event_type => 'wiki_comment',
            classes => [ 'comment', 'wiki_comment' ],
            topics => [ 'comment_thread:' . $thread->id, 'wiki_page:' . $object->id ],
            raw_object_name => $title,
            foreign_object_name_key => 'page "[_1]"',
            object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_message_' . $thread->id . '_' . $post->id,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'comments_input_container_' . $thread->id,
            ),
            secure_string => 'OpenInteract2::Action::DicoleWiki::read',
        };
    }
    elsif ($thread->object_type eq 'OpenInteract2::WikiAnnotation') {
        my $page = CTX->lookup_object('wiki_page')->fetch( $object->page_id );
        my $title = $page->title;
        my %show_parts = (
            action => 'wiki',
            task => 'show',
            target => $gid,
            additional => [ $title ],
            domain_id => $domain_id,
        );

        $data = {
            event_type => 'wiki_annotation',
            classes => [ 'comment', 'wiki_comment', 'wiki_annotation' ],
            topics => [ 'comment_thread:' . $thread->id, 'wiki_page:' . $page->id, 'annotation:' . $object->id ],
            raw_object_name => $title,
            foreign_object_name_key => 'page "[_1]"',
            object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'wiki_anno_comment_link_' . $object->id,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
                anchor => 'wiki_anno_comment_link_' . $object->id,
            ),
            secure_string => 'OpenInteract2::Action::DicoleWiki::read',
        };
    }
    elsif ($thread->object_type eq 'OpenInteract2::EventsEvent') {
        my %show_parts = (
            action => 'events',
            task => 'show',
            target => $gid,
            additional => [ $object->id ],
            domain_id => $domain_id,
        );

        $data = {
            event_type => 'event_comment',
            classes => [ 'comment', 'event_comment' ],
            topics => [ 'comment_thread:' . $thread->id, 'events_event:' . $object->id ],
            raw_object_name => $object->title,
            foreign_object_name_key => 'event "[_1]"',
            object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
#                anchor => 'wiki_anno_comment_link_' . $object->id,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
#                anchor => 'wiki_anno_comment_link_' . $object->id,
            ),
            secure_string => 'OpenInteract2::Action::DicoleEvents::view',
        };
    }
    elsif ($thread->object_type eq 'OpenInteract2::NetworkingProfile') {
        my %show_parts = (
            action => 'networking',
            task => 'show_profile',
            target => $thread->group_id,
            additional => [ $object->user_id ],
            domain_id => $domain_id,
        );

        # $self->_msg('your profile[_1]');
        $data = {
            event_type => 'networking_profile_comment',
            classes => [ 'comment', 'networking_profile_comment' ],
            topics => [ 'comment_thread:' . $thread->id, 'networking_profile_event:' . $object->id, 'networking_user_event:' . $object->user_id ],
            raw_object_name => '',
            foreign_object_name_key => 'your profile[_1]',
            own_object_name_key => 'your profile[_1]',
            object_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            comment_action_url => Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
                %show_parts,
            ),
            secure_string => 'OpenInteract2::Action::DicoleNetworking::view',
        };
    }

    $data->{object_tags} = eval { CTX->lookup_action('tags_api')->execute( get_tags => {
        object => $object,
        user_id => $thread->user_id,
        group_id => $thread->group_id,
        domain_id => $domain_id,
    } ) } || [];

    if ( $@ ) {
        get_logger(LOG_APP)->error( $@ );
    }

    $data->{object_type} = $thread->{object_type};
    $data->{object} = $object;
    $data->{object_id} = $object->id;
    $data->{object_name} = $self->_msg( $data->{foreign_object_name_key}, $data->{raw_object_name} );
    $data->{foreign_object_name} = $self->_msg( $data->{fereign_object_name_key}, $data->{raw_object_name} );
    $data->{own_object_name} = $self->_msg( $data->{own_object_name_key}, $data->{raw_object_name} ) if $data->{own_object_name_key};
    $data->{owner_uid} = $uid;
    $data->{group_id} = $gid;
    $data->{interested_users} = $self->_gather_interested_users( $post, $thread, $object );

    my $sender_user = $post->user_id ? CTX->lookup_object('user')->fetch( $post->user_id ) : undef;

    $data->{sender_user} = $sender_user;
    $data->{sender_name} = $sender_user ? Dicole::Utils::User->full_name( $sender_user ) : $post->anon_name;
    $data->{sender_first_name} = $sender_user ? $sender_user->first_name : $post->anon_name;

    $data->{comment_content_html} = $post->content;
    $data->{comment_content_text} = Dicole::Utils::HTML->html_to_text( $post->content );

    if ( $data->{group_id} ) {
        eval {
            my $group = CTX->lookup_object('groups')->fetch( $data->{group_id} );
            $data->{group_name} = $group->name;
        };
    }

    $data->{domain_url} = Dicole::URL->get_domain_url( $domain_id );

    my $server_name = $data->{domain_url};
    $server_name =~ s/^https?\:\/\///;
    $data->{server_name} = $server_name;

    return $data;
}

sub _gather_object_owner_and_group {
    my ( $self, $post, $thread, $object ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );

    if ( $thread->object_type eq 'OpenInteract2::BlogsEntry' ) {
        $object ||= CTX->lookup_object('blogs_entry')->fetch( $thread->object_id );

        return $object ? ( $object, $object->user_id, $object->group_id ) : ();
    }
    elsif ( $thread->object_type eq 'OpenInteract2::PresentationsPrese' ) {
        $object ||= CTX->lookup_object('presentations_prese')->fetch( $thread->object_id );

        return $object ? ( $object, $object->creator_id, $object->group_id ) : ();
    }
    elsif ($thread->object_type eq 'OpenInteract2::WikiPage') {
        $object ||= CTX->lookup_object('wiki_page')->fetch( $thread->object_id );

        return $object ? ( $object, 0, $object->groups_id ) : ();
    }
    elsif ($thread->object_type eq 'OpenInteract2::WikiAnnotation') {
        $object ||= CTX->lookup_object('wiki_annotation')->fetch( $thread->object_id );

        return $object ? ( $object, 0, $object->group_id ) : ();
    }
    elsif ($thread->object_type eq 'OpenInteract2::EventsEvent') {
        $object ||= CTX->lookup_object('events_event')->fetch( $thread->object_id );

        return $object ? ( $object, 0, $object->group_id ) : ();
    }
    elsif ($thread->object_type eq 'OpenInteract2::NetworkingProfile') {
        $object ||= CTX->lookup_object('networking_profile')->fetch( $thread->object_id );

        return $object ? ( $object, $object->user_id, $thread->group_id ) : ();
    }

    return ( $object, 0, 0 );
}

sub _gather_interested_users {
    my ( $self, $post, $thread, $object, $owner_id, $group_id ) = @_;

    $thread ||= $self->_get_thread_for_post( $post );

    unless ( defined( $owner_id ) && defined( $group_id ) ) {
        my ( $object, $uid, $gid ) = $self->_gather_object_owner_and_group( $post, $thread, $object );
        $owner_id = $uid;
        $group_id = $gid;
    }

    my %iusers = ();

    if ( $owner_id ) {
        $iusers{ $owner_id } = 1;
    }

    if ($thread->object_type eq 'OpenInteract2::WikiPage') {
        my $users = $self->_gather_interested_wiki_page_users( $object );
        $iusers{ $_ } = 1 for @$users;
    }
    elsif ($thread->object_type eq 'OpenInteract2::WikiAnnotation') {
        my $page = CTX->lookup_object('wiki_page')->fetch( $object->page_id );
        my $users = $self->_gather_interested_wiki_page_users( $page );
        $iusers{ $_ } = 1 for @$users;
    }
    elsif ( $thread->object_type eq 'OpenInteract2::NetworkingProfile') {
        # No intereseted users
    }
    else {
        my $comments = $self->_get_comments_for_thread( $thread );
        for my $comment ( @$comments ) {
            next unless $comment->user_id;
            $iusers{ $comment->user_id } = 1;
        }
    }

    if ( $thread->object_type eq 'OpenInteract2::EventsEvent') {
        my $eusers = CTX->lookup_object('events_user')->fetch_group( {
            where => 'event_id = ? AND is_planner = ?',
            value => [ $object->id, 1 ]
        } ) || [];

        $iusers{ $_->user_id } = 1 for @$eusers;
    }

    delete $iusers{ $post->user_id } if $post->user_id;

    # remove users who are not part of the group anymore
    if ( $group_id ) {
        for my $user_id ( keys %iusers ) {
            $iusers{ $user_id } = Dicole::Utils::User->belongs_to_group( $user_id, $group_id ) ? 1 : 0;
        }
    }

    my @users = map { $iusers{$_} ? $_ : () } keys %iusers;

    return \@users;
}

sub _gather_interested_wiki_page_users {
    my ( $self, $page ) = @_;

    my $gid = $page->groups_id;
    my $users = [];

    my $versions = CTX->lookup_object('wiki_version')->fetch_group({
        where => 'dicole_wiki_version.page_id = ?',
        value => [ $page->id ]
    }) || [];

    push @$users, $_->creator_id ? $_->creator_id : () for @$versions;

    my $page_comments = $self->_get_comments( {
        object_id => $page->id,
        object_type => ref( $page ),
        group_id => $gid,
        user_id => 0,
    } ) || [];

    push @$users, $_->user_id ? $_->user_id : () for @$page_comments;

    my $annos = CTX->lookup_object('wiki_annotation')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
    } );

    for my $anno ( @$annos ) {
        my $anno_comments = $self->_get_comments( {
            object_id => $anno->id,
            object_type => ref( $anno ),
            group_id => $gid,
            user_id => 0,
        } ) || [];

        push @$users, $_->user_id ? $_->user_id : () for @$anno_comments;
    }

    return $users;
}

sub _generate_domain_specific_mail_params {
    my ( $self, $default_base, $domain_id, $params ) = @_;

    return $self->_generate_domain_specific_mail_params_with_source_hash(
        $self->_domain_specific_mail_template_source_hash( $default_base, $domain_id ), $params
    );
}

sub _generate_domain_specific_mail_params_with_source_hash {
    my ( $self, $conf_hash, $params ) = @_;

    return {
        subject => $self->_generate_content_using_source( $conf_hash->{subject}, $params ),
        text => $self->_generate_content_using_source( $conf_hash->{text}, $params ),
        html => $self->_generate_content_using_source( $conf_hash->{html}, $params ),
    };
}

sub _generate_content_using_source {
    my ( $self, $conf, $params ) = @_;

    return $self->generate_content( $params, $conf );
}

sub _domain_specific_mail_template_source_hash {
    my ( $self, $default_base, $domain_id ) = @_;

    my $hash = {};

    my $domain_settings = Dicole::Settings->new_fetched_from_params(
        user_id => 0,
        group_id => 0,
        tool => $domain_id ? 'domain_user_manager_' . $domain_id : 'user_manager',
    );

    my $languages = CTX->lookup_object( 'lang' )->fetch_group;
    my @available_languages = map { $_->lang_code } @$languages;

    for my $lang ( @available_languages ) {
        for my $target ( qw( subject text html ) ) {
            $hash->{ $lang }{ $target } = $self->_customized_template_source(
                $default_base . '_' . $target, $lang, 0, $domain_id, undef, $domain_settings
            );
        }
    }

    return $hash;
}

sub _customized_template_source {
    my ( $self, $template, $lang, $group_id, $domain_id, $group_settings, $domain_settings ) = @_;

    $domain_settings ||= Dicole::Settings->new_fetched_from_params(
        user_id => 0,
        group_id => 0,
        tool => $domain_id ? 'domain_user_manager_' . $domain_id : 'user_manager',
    );

    if ( $group_id ) {
        $group_settings ||= Dicole::Settings->new_fetched_from_params(
            user_id => 0,
            group_id => $group_id,
            tool => 'group_manager',
        );
    }

    my $attr = 'custom_' . $template;
    $attr =~ s/\:\:/_/g;

    my $lang_prefix = ( $lang eq 'en' ) ? '' : '_' . $lang;

    if ( $lang_prefix ) {
        if ( $group_id ) {
            if ( my $t = $group_settings->setting( $attr . $lang_prefix ) ) {
                return { text => $t };
            }
        }
        if ( my $t = $domain_settings->setting( $attr . $lang_prefix ) ) {
            return { text => $t };
        }
    }

    if ( $group_id ) {
        if ( my $t = $group_settings->setting( $attr ) ) {
            return { text => $t };
        }
    }
    if ( my $t = $domain_settings->setting( $attr ) ) {
        return { text => $t };
    }

    if ( $lang_prefix && 1 ) { # TODO: make sure custom lang template exists here!
        return { name => $template . $lang_prefix };
    }
    else {
        return { name => $template };
    }
}

sub delete_comment {
    my ( $self ) = @_;
    
    my $thread = $self->delete_comment_and_return_thread;
    my $messages_widget = $self->_get_messages_widget( $thread );
    return { messages_html => $messages_widget->generate_content };
}
sub delete_comment_and_return_thread {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_delete_comment_and_return_both;

    return $thread;
}

sub delete_comment_and_return_post {
    my ( $self ) = @_;

    my ( $thread, $post ) = $self->_delete_comment_and_return_both;

    return $post;
}

sub _delete_comment_and_return_both {
    my ( $self ) = @_;
    
    # calls populate_params
    my $thread = $self->_get_thread_object_using_params;
    
    my $secondary_source = CTX->request || $self;
    
    my $post = eval { CTX->lookup_object('comments_post')->fetch(
        $self->param('post_id') || $secondary_source->param('post_id')
    ) };
    
    my $uid = $self->param('requesting_user_id') || CTX->request->auth_user_id;
    
    if ( $post && $thread && $post->thread_id == $thread->id ) {
        if ( $self->param('right_to_remove_comments') || ( $uid && $uid == $post->user_id ) ) {
            $post->removed( time );
            $post->removed_by( $self->param('requesting_user_id') );
            $post->save;
            eval { $self->_store_deletion_event( $post, $thread ); };
            if ( $@ ) { get_logger(LOG_APP)->error( $@ ); }
            $self->_refresh_thread_message_caches( $thread, $post );
        }
    }

    #CTX->lookup_action('search_api')->execute(remove => {object => $post});
    return ( $thread, $post );
}

sub get_comment_tree_widget {
    my ( $self ) = @_;

    return Dicole::Widget::Container->new(
        id => 'comments',
        contents => [ $self->get_unwrapped_comment_tree_widget ]
    );
}

sub get_unwrapped_comment_tree_widget {
    my ( $self ) = @_;

    # calls populate_params
    my $thread = $self->_get_or_create_thread_object_using_params;
    
    my $post_action = Dicole::URL->create_from_parts(
        action => $self->param('comments_action'),
        task => 'add_comment',
        target => $self->param('target_id'),
    );
    
    my $get_action = Dicole::URL->create_from_parts(
    	action => $self->param('comments_action'),
    	task => 'get_comments_html',
    	target => $self->param('target_id'),
    );
    
    my $list = Dicole::Widget::Vertical->new(
        class => 'comments_container',
        id => 'comments_container_' . $thread->id,
        title => $get_action,
        contents => [],
    );

    my $messages_container = Dicole::Widget::Container->new(
        class => 'comments_messages_container',
        id => 'comments_messages_container_' . $thread->id,
        contents => [ $self->_get_messages_widget( $thread ) ],
    );

    if ( $self->param('display_type') && $self->param('display_type') eq 'chat' ) {
        if ( ! $self->param('commenting_closed') && ! $self->param( 'disable_commenting' ) ) {
            my $input_container = Dicole::Widget::Horizontal->new(
                id => 'comments_input_container_' . $thread->id,
                class => 'comments_input_container',
            );

            $input_container->add_content( Dicole::Widget::FormControl::TextField->new(
                name => 'comments_text_content_' . $thread->id,
                id => 'comments_text_content_' . $thread->id,
                class => 'comments_content_textfield',
                value => '',                
            ) );
        
            $input_container->add_content( Dicole::Widget::Horizontal->new(
                contents => [
                    Dicole::Widget::Hyperlink->new(
                        class => 'comments_text_submit',
                        id => 'comments_submit_' . $thread->id,
                        link => $post_action,
                        content => $self->param('submit_comment_string') || $self->_msg('Submit comment'),
                        disable_click => 1,
                    ),
                    $self->param('enable_private_comments') ? (
                        Dicole::Widget::FormControl::Checkbox->new(
                            id => 'comments_submit_' . $thread->id . '_privately',
                            name => 'comments_submit_' . $thread->id . '_privately',
                            value => '1',
                        ),
                        ' ',
                        $self->param('private_check_string') || $self->_msg('Check to send privately'),
                    ) : (),
                ]
            ) );

            $list->add_content( $input_container );
        }

        $list->add_content( $messages_container );
        return $list;
    }

    $list->add_content( $messages_container );

    if ( ! $self->param('commenting_closed') && ! $self->param( 'disable_commenting' ) ) {
        my $input_container = Dicole::Widget::Vertical->new(
            id => 'comments_input_container_' . $thread->id,
            class => 'comments_input_container' . ( $self->param('input_hidden') ? ' hiddenBlock' : '' ),
        );

        if ( ! $self->param( 'disable_anonymous_commenting' ) &&
                CTX->request && ! CTX->request->auth_user_id ) {
            $input_container->add_content( Dicole::Widget::Text->new(
                text => $self->_msg( 'Name' ), class => 'definitionHeader'
            ) );
            $input_container->add_content( Dicole::Widget::FormControl::TextField->new(
                name => 'comments_anon_name_' . $thread->id,
                id => 'comments_anon_name_' . $thread->id,
                class => 'comments_anon_name_textfield',
            ) );
#             $input_container->add_content( Dicole::Widget::Text->new(
#                 text => $self->_msg( 'Email' ), class => 'definitionHeader'
#             ) );
#             $input_container->add_content( Dicole::Widget::FormControl::TextField->new(
#                 name => 'comments_anon_email_' . $thread->id,
#                 id => 'comments_anon_email' . $thread->id,
#                 class => 'comments_anon_email_textfield',
#             ) );
            $input_container->add_content( Dicole::Widget::Text->new(
                text => $self->_msg( 'Website' ), class => 'definitionHeader'
            ) );
            $input_container->add_content( Dicole::Widget::FormControl::TextField->new(
                name => 'comments_anon_url_' . $thread->id,
                id => 'comments_anon_url_' . $thread->id,
                class => 'comments_anon_url_textfield',
            ) );
            $input_container->add_content( Dicole::Widget::Text->new(
                text => $self->_msg( 'Comment content' ), class => 'definitionHeader'
            ) );
        }
        else {
            $input_container->add_content( Dicole::Widget::Text->new(
                text => $self->_msg( 'Write your comment:' ), class => 'definitionHeader'
            ) );
        }
        
        $input_container->add_content( Dicole::Widget::FormControl::TextArea->new(
            name => 'comments_content_' . $thread->id,
            id => 'comments_content_' . $thread->id,
            class => 'comments_content_textarea',
            value => '<p></p>',
            rows => 10,
            html_editor => 1,
        ) );
        
        $input_container->add_content( Dicole::Widget::Horizontal->new(
            contents => [
                Dicole::Widget::Hyperlink->new(
                    class => 'comments_submit',
                    id => 'comments_submit_' . $thread->id,
                    link => $post_action,
                    content => $self->param('submit_comment_string') || $self->_msg('Submit comment'),
                    disable_click => 1,
                ),
                # NOTE: needs styling is enabled:
#                $self->param('enable_private_comments') ? (
#                    Dicole::Widget::FormControl::Checkbox->new(
#                        id => 'comments_submit_' . $thread->id . '_privately',
#                        name => 'comments_submit_' . $thread->id . '_privately',
#                        value => '1',
#                    ),
#                    ' ',
#                    $self->param('private_check_string') || $self->_msg('Check to send privately'),
#                ) : (),
            ]
        ) );

        $list->add_content( $input_container );
    }
    elsif ( $self->param('commenting_closed') ) {
        my $closed_container = Dicole::Widget::Container->new(
            class => 'comments_closed_container',
        );

        $closed_container->add_content( Dicole::Widget::Text->new(
            text => $self->_msg( 'Commenting is closed.' ),
            class => 'comments_closed_text'
        ) );

        $list->add_content( $closed_container );
    }
    elsif ( CTX->request && ! CTX->request->auth_user_id )  {
        my $login_guide = Dicole::Widget::Container->new(
            class => 'login_to_comment_container',
        );

        my $register_possible = eval { CTX->lookup_action('user_manager_api')->e(
            current_domain_registration_allowed => { group_id => eval { CTX->controller->initial_action->param('target_group_id') } || 0 }
        ) };

        my $login_html = '<a href="#" class="js_hook_show_login">' . Dicole::Utils::HTML->encode_entities( $self->_msg('log in (within sentence)') ) . '</a>';

        if ( $register_possible ) {
            my $register_html = '<a href="#" class="js_open_register_dialog">' . Dicole::Utils::HTML->encode_entities( $self->_msg('register (within sentence)') ) . '</a>';
            $login_guide->add_content( Dicole::Widget::Raw->new(
                raw => $self->_msg('Please [_1] or [_2] to leave comments', $login_html, $register_html ),
            ) );
        }
        else {
            $login_guide->add_content( Dicole::Widget::Raw->new(
                raw => $self->_msg('Please [_1] to leave comments', $login_html ),
            ) );
        }

        $list->add_content( $login_guide );
    }

    return $list;
}

sub get_thread {
    my ( $self ) = @_;

    return $self->_get_or_create_thread_object_using_params;
}

sub get_comments_info {
    my ( $self ) = @_;

    $self->_populate_params;
    my $thread = $self->_get_or_create_thread_object( $self->_hash_from_params );
    return $self->_thread_comment_info_array(
        $thread, $self->param('group_id'), $self->param('size'), $self->param('domain_id')
    );
}

sub get_state {
    my ( $self ) = @_;

    $self->_populate_params;
    my $thread = $self->_get_or_create_thread_object( $self->_hash_from_params );
    my $info_array = $self->_thread_comment_info_array(
        $thread, $self->param('group_id'), $self->param('size'), $self->param('domain_id')
    );

    return [ reverse( map { { id => $_->{post_id}, ts => $_->{last_changed} } } @$info_array ) ];
}

sub get_info_hash_for_id_list {
    my ( $self ) = @_;

    $self->_populate_params;
    my $thread = $self->_get_or_create_thread_object( $self->_hash_from_params );
    my $info_array = $self->_thread_comment_info_array(
        $thread, $self->param('group_id'), $self->param('size'), $self->param('domain_id'), 'no_default'
    );

    my $id_list = $self->param('id_list');
    my %info_by_id = map { $_->{post_id} => $_ } @$info_array;

    my $comments = { map { $_ => $info_by_id{ $_ } } @$id_list };

    return $comments;
}

sub get_comments {
    my ( $self ) = @_;
    
    $self->_populate_params;
    return $self->_get_comments( $self->_hash_from_params );
}

sub get_comments_html {
    my ( $self ) = @_;
    
    my $thread = $self->_get_or_create_thread_object_using_params;
    
    my $messages_widget = $self->_get_messages_widget( $thread );
    return { messages_html => $messages_widget->generate_content };
}

sub get_comment_count {
    my ( $self ) = @_;

    $self->_populate_params;
    return $self->_get_comment_count( $self->_hash_from_params );
}

sub get_latest_commenters {
    my ( $self ) = @_;

    $self->_populate_params;
    return $self->_get_latest_commenters( $self->_hash_from_params, $self->param('limit') );
}

sub get_latest_commenters_data {
    my ( $self ) = @_;

    $self->_populate_params;
    return $self->_get_latest_commenters_data( $self->_hash_from_params, $self->param('limit') );
}

sub remove_comments {
    my ( $self ) = @_;
    
    $self->_populate_params;
    return $self->_remove_comments( $self->_hash_from_params );
}

sub _remove_comments {
    my ( $self, $params ) = @_;

    my $thread = $self->_get_thread_object( $params );
    my $comments = $self->_get_comments_for_thread( $thread );
    
    for my $comment ( @$comments ) {
        $comment->remove;
    }
    
    $thread->remove;
    
    return 1;
}

sub _get_messages_widget {
    my ( $self, $thread ) = @_;
    
    my $info_array = $self->_thread_comment_info_array(
        $thread, $thread->group_id
    );

    unless ( $self->param('display_type') && $self->param('display_type') eq 'chat' ) {
        $info_array = [ reverse @$info_array ];
    }
    
    my @base_comment_widgets = map {
        $_->{depth} == 0 ? $self->_visualize_single_post( $_ ) || () : ()
    } @$info_array;

    return Dicole::Widget::Vertical->new(
        class => 'comments_messages',
        id => 'comments_messages_' . $thread->id,
        contents => [ scalar( @base_comment_widgets ) ?
            ( @base_comment_widgets )
            :
            ( Dicole::Widget::Container->new(
                class => 'comments_no_comments',
                contents => [
                    $self->param('commenting_closed') ? '' :
                        $self->param('no_comments_string') ||
                        eval{ CTX->controller->initial_action->_msg('Be the first to comment!') } ||
                        ''
                ],
            ) )
        ],
    );
}

sub _visualize_single_post {
    my ( $self, $info ) = @_;
    
    my $uid = CTX->request->auth_user_id;
    my $can_publish_comments = ( $uid && ( $self->param('right_to_publish_comments') ) ) ? 1 : 0;
    return '' unless $info->{published} || $can_publish_comments || $uid == $info->{user_id};

    if ( $self->param('enable_private_comments') && ! $self->param('show_private_comments') ) {
        return '' if $info->{is_private} && $uid != $info->{user_id};
    }

    my $can_delete_comments = ($uid && ( $self->param('right_to_remove_comments') || $uid == $info->{user_id}));

    my $short_content = Dicole::Utils::HTML->shorten( $info->{content}, 1000 );
    my $long_content = Dicole::Utils::HTML->shorten( $info->{content}, 1000000 );

    my %params = (
		date => $info->{date},
        content => Dicole::Utils::HTML->break_long_strings( $long_content, 55 ),
        short_content => ( $short_content eq $long_content ) ? '' : Dicole::Utils::HTML->break_long_strings( $short_content, 55 ),
        user_name => $info->{user_name},
        user_link => $info->{user_link},
		user_avatar => $info->{user_avatar},
        thread_id => $info->{thread_id},
        post_id => $info->{post_id},
        can_delete_comments => $can_delete_comments,
		delete_link => $can_delete_comments ? Dicole::URL->create_from_parts(action => $self->param('comments_action'), task => 'delete_comment', target => $self->param('target_id'),) : '',
        published => $info->{published},
        is_private => $info->{is_private},
        can_publish_comments => $can_publish_comments,
		publish_link => $can_publish_comments ? Dicole::URL->create_from_parts(action => $self->param('comments_action'), task => 'publish_comment', target => $self->param('target_id'),) : '',
    );

    my $content = $self->generate_content(\%params, {name => 'dicole_comments::comment'});

    return Dicole::Widget::Raw->new(raw => $content);
}

sub _thread_comment_info_array {
    my ( $self, $thread, $group_id, $size, $domain_id, $no_default ) = @_;

    $size = $self->param('size') unless defined $size;
    $no_default = $self->param('no_default') unless defined $no_default;
    $group_id = $self->param('group_id') unless defined $group_id;
    $domain_id = $self->param('domain_id') unless defined $domain_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $cache_key = join( "_", ( $thread->id, $group_id, $size, $domain_id, $no_default ) );
    my $info_cache = Dicole::Cache->fetch_or_store( 'comments_info_array_for_thread_' . $cache_key, sub {
        my $comments = $self->_get_comments_data_for_thread( $thread );
        my $infos = $self->_gather_comments_info(
            $comments, $group_id, $size, $domain_id, $no_default
        );
        return { stamps => $self->_generate_stamps( $comments ), infos => $self->_order_infos( $infos ) };
    }, { expires => 60*10, no_domain_id => 1, no_group_id => 1, skip_cache => 1 } ); 

    my $comments = $self->_get_comments_data_for_thread( $thread );
    my $stamps = $self->_generate_stamps( $comments );
    my $changed = [];
    
    for my $comment ( @$comments ) {
        push @$changed, $comment unless $info_cache->{stamps}->{ $comment->{post_id} } &&
            $stamps->{ $comment->{post_id} } &&
            $stamps->{ $comment->{post_id} } eq $info_cache->{stamps}->{ $comment->{post_id} };
    }

    if ( scalar( @$changed ) || scalar( keys %$stamps ) != scalar( keys %{ $info_cache->{stamps} } ) ) {
        $info_cache = Dicole::Cache->update( 'comments_info_array_for_thread_' . $cache_key, sub {
            my $changed_infos = $self->_gather_comments_info(
                $changed, $group_id, $size, $domain_id, $no_default
            );
            my %infos = map { $_->{post_id} => $_ } ( @{ $info_cache->{infos} }, @$changed_infos ); 
            my $new_infos = [];
            for my $comment ( @$comments ) {
                push @$new_infos, $infos{ $comment->{post_id} };
            }
            return { stamps => $stamps, infos => $self->_order_infos( $new_infos ) };
        }, { expires => 60*10, no_domain_id => 1, no_group_id => 1, skip_cache => 1 } );
    }

    # Add the localized parts which can not be cached
    for my $info ( @{ $info_cache->{infos} } ) {
        $info->{date_ago} = Dicole::Utils::Date->localized_ago( epoch => $info->{date_epoch} );
        $info->{date} = Dicole::DateTime->long_datetime_format( $info->{date_epoch} );
        $info->{datetimestamp} = Dicole::Utils::Date->localized_datetimestamp(
            epoch => $info->{date_epoch},
            display_type => $self->param('display_type'),
            lang => $self->param('lang'),
            timezone => $self->param('timezone'),
        );
    }

    return $info_cache->{infos};
}

sub _generate_stamps {
    my ( $self, $comments ) = @_;

    my $stamps = {};
    for my $comment ( @$comments ) {
        $Storable::canonical = 1;
        $stamps->{ $comment->{post_id} } = Digest::MD5::md5_hex( Storable::freeze( $comment ) );
    }

    return $stamps;
}

sub _order_infos {
    my ( $self, $infos ) = @_;

    my $creator = Dicole::Tree::Creator::Hash->new(
        id_key => 'post_id',
        parent_id_key => 'parent_post_id',
        order_key => 'order',
        parent_key => 0,
        depth_key => 'depth',
        sub_elements_key => 'sub_elements',
    );
    
    $creator->add_element_array( $infos );

    return $creator->ordered_element_array;
}

sub _gather_comments_info {
    my ( $self, $comments, $group_id, $size, $domain_id, $no_default ) = @_;

    my @uids = map { $_->{user_id} || () } @$comments;

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( 'user_id', \@uids ),
    } ) || [];

    my %user_hash = map { $_->id => $_ } @$users;

    my $user_profiles = CTX->lookup_action('networking_api')->e( user_profile_object_map => {
        domain_id    => $domain_id,
        user_id_list => [ keys %user_hash ],
    });

    my $infos = [];
    for my $comment ( @$comments ) {
        my $info = {};
        $info->{$_} = $comment->{$_} for ( qw(
            post_id thread_id parent_post_id user_id content published is_private edited edited_by
        ) );

        $info->{id} = $info->{post_id};
        $info->{content_raw} = $info->{content};
        $info->{content_plaintext} = Dicole::Utils::HTML->html_to_text( $info->{content} );
        
        $info->{content} = Dicole::Utils::HTML->sanitize_attributes( $info->{content} );
        $info->{content} = Dicole::Utils::HTML->link_plaintext_urls( $info->{content} );

        $info->{content_stripped} = Dicole::Utils::Mail->strip_quotes_and_sigs_from_br_html( $info->{content} );

        eval {
            my $tapi = CTX->lookup_action('tinymce_api');
            eval {
                $info->{content} = $tapi->e( filter_outgoing_html => { html => $info->{content} } );
            };
            if ( $@ ) {
                get_logger(LOG_APP)->error("Error filtering html: $@");
            }
        };
        my $user = $user_hash{ $comment->{user_id} };
        $info->{user_name} = $user ? Dicole::Utils::User->name( $user ) :
            $comment->{anon_name} || $comment->{anon_email} || $self->_msg('Anonymous');
        $info->{user_initials} = $user ? Dicole::Utils::User->initials( $user ) : '';
        $info->{user_link} = $user ? Dicole::URL->from_parts(
            action => 'networking', task => 'profile',
            target => $group_id, domain_id => $domain_id, additional => [ $user->id ]
        ) : $comment->{anon_url};

        my $portrait = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
                user_id => $comment->{user_id},
                domain_id => $domain_id,
                profile_object => $user_profiles->{ $comment->{user_id} },
                size => $size || 48, no_default => $no_default
            });

        $info->{user_avatar} = $portrait;
        $info->{user_image} = $portrait;

        $info->{user_organization} = $info->{user_id} ? CTX->lookup_action('networking_api')->e( user_profile_attribute => {
                user_id => $info->{user_id},
                domain_id => $domain_id,
                profile_object => $user_profiles->{ $info->{user_id} },
                name => 'contact_organization',
            } ) : '';

        $info->{order} = $comment->{date};
        $info->{date_epoch} = $comment->{date};

        $info->{last_changed} = List::Util::max( $info->{date}, $info->{edited}, $info->{published} );
        $info->{ts} = $info->{last_changed};

        push @$infos, $info;
    }
    return $infos;
}

sub _get_comments {
    my ( $self, $params ) = @_;
    
    my $thread = $self->_get_or_create_thread_object( $params );
    
    return $self->_get_comments_for_thread( $thread );
}

sub _get_comments_data {
    my ( $self, $params ) = @_;
    
    my $thread = $self->_get_or_create_thread_object( $params );
    
    return $self->_get_comments_data_for_thread( $thread );
}

sub _get_comments_for_thread {
    my ( $self, $thread ) = @_;
    
    return [] unless $thread;

    return CTX->lookup_object( 'comments_post' )->fetch_group( {
        where => 'thread_id = ? AND removed = 0',
        value => [ $thread->id ],
        order => 'date desc'
    } ) || [];
}

sub _get_comments_data_for_thread {
    my ( $self, $thread ) = @_;
    
    return [] unless $thread;

    my $comments_cache = $self->_get_thread_comments_cache( $thread );

    my $datas = $comments_cache->{data};
    return [ map { $_->{removed} ? () : $_ } @$datas ];
}


sub _refresh_thread_message_caches {
    my ( $self, $thread, $post ) = @_;

    my $comments_cache = $self->_get_thread_comments_cache( $thread );

    # All this trouble just so that we don't have to refresh the
    # whole message cache when something changes..
    # This seems to be important when the thread is above 200 messages
    # and the SPOPS object retrieval overhead takes it's toll..
    Dicole::Cache->update( 'comments_data_for_thread_' . $thread->id, sub {

        # 60 second safeguard since the last refresh timestamp ;)
        my $time = $comments_cache->{generated} - 60;
        my $refreshed_objects = CTX->lookup_object( 'comments_post' )->fetch_group( {
            where => 'thread_id = ? AND ( date > ? OR removed > ? OR published > ? OR edited > ? )',
            value => [ $thread->id, $time, $time, $time, $time ],
            order => 'date desc'
        } ) || [];

        my $cached = $comments_cache->{data};
        my $refreshed = [ map { { %$_ } } @$refreshed_objects ];

        my $data = [];
        my ( $c, $r );
        while ( $c || $r || scalar( @$cached ) || scalar( @$refreshed ) ) {
            $c ||= shift @$cached;
            $r ||= shift @$refreshed;
            if ( ! $r ) {
                push @$data, $c;
                undef $c;
            }
            elsif ( ! $c ) {
                push @$data, $r;
                undef $r;
            }
            elsif ( $c->{post_id} == $r->{post_id} ) {
                push @$data, $r;
                undef $c;
                undef $r;
            }
            elsif ( $c->{date} > $r->{date} ) {
                push @$data, $c;
                undef $c;
            }
            else {
                push @$data, $r;
                undef $r;
            }
        }

        $comments_cache->{generated} = time;
        $comments_cache->{data} = $data;

        return $comments_cache;
    }, { expires => 60*60*2, no_group_id => 1, no_domain_id => 1, skip_cache => 1 } );
}

sub _get_thread_comments_cache {
    my ( $self, $thread ) = @_;

    return Dicole::Cache->fetch_or_store( 'comments_data_for_thread_' . $thread->id, sub {
        return $self->_regenerate_thread_comments_data_cache( $thread );
    }, { expires => 60*60*24*15, no_group_id => 1, no_domain_id => 1, skip_cache => 1 } ); 
}

sub _regenerate_thread_comments_data_cache {
    my ( $self, $thread ) = @_;

    my $comments = CTX->lookup_object( 'comments_post' )->fetch_group( {
        where => 'thread_id = ?',
        value => [ $thread->id ],
        order => 'date desc'
    } );
    my @data = map { { %$_ } } @$comments;
    return { generated => time, data => \@data };
}

sub get_comment_counts {
    my ($self, $params) = @_;

    my $objects = $self->param('objects');

    my %objects = map { $_->id => $_ } @$objects;

    my $threads = CTX->lookup_object('comments_thread')->fetch_group({
        where => Dicole::Utils::SQL->column_in(object_id => [ map { $_->id } @$objects ])
    });

    my @filtered_threads = grep {
        my $object = $objects{$_->object_id};

        $object and $_->object_type eq ref $object;
    } @$threads;

    my $query = Dicole::Utils::SQL->column_in(thread_id => [ map { $_->thread_id } @filtered_threads ]) . " and removed = 0 and published != 0";

    my $comments = CTX->lookup_object('comments_post')->fetch_group({
        where => $query
    });

    my %thread_comment_counts;

    $thread_comment_counts{$_->thread_id}++ for @$comments;

    my %object_comment_counts = map { $_->object_id => $thread_comment_counts{$_->thread_id} } @filtered_threads;

    return \%object_comment_counts;
}

sub _get_comment_count {
    my ( $self, $params ) = @_;
    
    my $cobject = $self->_get_thread_object( $params );
    
    return 0 unless $cobject;
    
    return CTX->lookup_object( 'comments_post' )->fetch_count( {
        where => 'thread_id = ? AND removed = 0 AND published != 0',
        value => [ $cobject->id ],
    } ) || 0;
}

sub _get_latest_commenters_data {
    my ( $self, $params, $limit ) = @_;
    
    my $comments = $self->_get_comments_data( $params );

    my %uids = ();
    my @uids = ();

    for my $comment ( reverse @$comments ) {
        next if $limit && scalar( @uids ) >= $limit;
        next if $comment->{removed} || ! $comment->{published};
        next unless $comment->{user_id};
        next if $uids{ $comment->{user_id} }++;
        push @uids, { user_id => $comment->{user_id}, timestamp => $comment->{date} };
    }

    return \@uids;
}

sub _get_latest_commenters {
    my ( $self, $params, $limit ) = @_;
    
    my $comments = $self->_get_latest_commenters_data( $params, $limit );

    return [ map { $_->{user_id} } @$comments ];
}

sub _get_thread_object_using_params {
    my ( $self ) = @_;
    
    $self->_populate_params;
    return $self->_get_thread_object( $self->_hash_from_params );
}

sub _get_thread_for_post {
    my ( $self, $post ) = @_;

    return $post->{thread_id} ? $self->_get_thread_object( thread_id => $post->{thread_id} ) : undef;
}

sub _get_thread_object {
    my ( $self, $params ) = @_;

    if ( $params->{thread} ) {
        return $params->{thread};
    }

    if ( $params->{thread_id} ) {
        return CTX->lookup_object( 'comments_thread' )->fetch(
            $params->{thread_id}
        );
    }

    my $objs = CTX->lookup_object( 'comments_thread' )->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND '.
            'object_id = ? AND object_type = ?',
        value => [
            $params->{user_id}, $params->{group_id},
            $params->{object_id}, $params->{object_type},
        ]
    } ) || [];
    
    return $objs->[0];    
}

sub _get_or_create_thread_object_using_params {
    my ( $self ) = @_;
    
    $self->_populate_params;
    return $self->_get_or_create_thread_object( $self->_hash_from_params );
}

sub _get_or_create_thread_object {
    my ( $self, $params ) = @_;

    my $cobj = $self->_get_thread_object( $params );
    
    if ( ! $cobj ) {
        $cobj = CTX->lookup_object( 'comments_thread' )->new;
        $cobj->{user_id} = $params->{user_id} || 0;
        $cobj->{group_id} = $params->{group_id} || 0;
        $cobj->{object_id} = $params->{object_id};
        $cobj->{object_type} = $params->{object_type};
        $cobj->save;
    }
    
    return $cobj;
}

sub _populate_params {
    my ( $self ) = @_;
    
    $self->_populate_object_params( 'object' );
    $self->_populate_id_params;
    $self->_populate_action_name;
}

sub _populate_id_params {
    my ( $self ) = @_;
    
    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $self->param( 'user_id', $ia->param('target_type') eq 'user' ? $ia->param('target_user_id') : 0 )
            unless defined $self->param( 'user_id' );
        $self->param( 'group_id', $ia->param('target_type') eq 'group' ? $ia->param('target_group_id') : 0 )
            unless defined $self->param( 'group_id' );
            
        $self->param( 'target_id', $ia->param('target_type') eq 'group' ?
            $ia->param('target_group_id') :$ia->param('target_user_id')
        ) unless  defined $self->param( 'target_id' );;
    }
    
    if ( CTX->request && CTX->request->auth_user_id ) {
        $self->param( 'requesting_user_id', CTX->request->auth_user_id ) unless defined $self->param( 'requesting_user_id' );
    }
}

sub _populate_object_params {
    my ( $self, $param ) = @_;
    
    if ( my $object = $self->param( $param ) ) {
        $self->param( $param . '_id', $object->id )
            unless defined $self->param( $param . '_id' );
        $self->param( $param . '_type', ref( $object ) )
            unless defined $self->param( $param . '_type' );
    }
}

sub _populate_action_name {
    my ( $self ) = @_;

    $self->param( 'comments_action', CTX->controller->initial_action->name )
        unless defined $self->param( 'comments_action' ) || ! CTX->controller || ! CTX->controller->initial_action;
}

sub _hash_from_params {
    my ( $self ) = @_;

    return {
        thread => $self->param('thread'),
        thread_id => $self->param('thread_id'),
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        group_id => $self->param('group_id') || 0,
        user_id => $self->param('user_id') || 0,
    };
}

sub _current_domain_id {
    my ( $self ) = @_;

    return $self->param('domain_id') || eval { CTX->controller->initial_action->param('domain_id') } || undef;
}

1;

