package OpenInteract2::Action::DicoleNetworkingJSON;
use strict;
use base qw( OpenInteract2::Action::DicoleNetworkCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::DicoleNetworking::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub more_profiles {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $skip_data_json = CTX->request->param('skip_data') || '{}';
    my $skip_data = Dicole::Utils::JSON->decode( $skip_data_json );

    my $info = $self->_fetch_profile_list_info( $gid, $self->DEFAULT_PROFILE_LIST_SIZE, $skip_data );

    my $params = {
        entries => $info->{object_info_list},
        script_data_json => $self->_generate_profile_list_script_data_json( $gid, $info ),
    };

    my $content = $self->generate_content( $params, { name => 'dicole_networking::special_browse_list' } );

    return { result => { html => $content, end_of_pages => $info->{end_of_pages} } };
}

sub add_contact {
    my ( $self ) = @_;
    
    die 'security error' unless CTX->lookup_object('user')->fetch(
        $self->param('contacted_user_id')
    );
    
    $self->_add_contact(
        $self->param('target_user_id'),
        $self->param('contacted_user_id')
    );
    
    return $self->_return_new_widget( $self->param('group_id') );
}

sub remove_contact {
    my ( $self ) = @_;
    
    $self->_remove_contact(
        $self->param('target_user_id'),
        $self->param('contacted_user_id')
    );
    
   return $self->_return_new_widget( $self->param('group_id') );
}

sub _return_new_widget {
    my ( $self, $gid ) = @_;
    my $widget = $self->_get_add_remove_contact_widget_without_container(
        $self->param('contacted_user_id'), undef, undef, $gid
    );
    return { new_html => $widget->generate_content };
}

sub user_portrait_thumb_url {
    my ( $self ) = @_;

    my $size = $self->param('size');
    $size = 50 unless $size;
    $size = 10 if $size < 10;
    $size = 400 if $size > 400;

    my $domain_id = $self->param('domain_id');

    my $profile = $self->_get_profile_object( $self->param('user_id'), $domain_id );
    my $url = $self->_get_portrait_thumb( $profile, $size, $self->param('no_default') );
    return $self->param('with_host') ? Dicole::URL->get_domain_url( $domain_id ) . $url : $url;
}

sub tag_cloud {
    my ( $self ) = @_;

    return Dicole::Utils::JSON->decode( CTX->request->param('return') );
}

sub keyword_change {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = { tags => eval{ Dicole::Utils::JSON->decode( CTX->request->param('selected_keywords') ) } || [] };

    if ( my $old_state = CTX->request->param('state') ) {
        eval {
            my $old_data = Dicole::Utils::JSON->decode( $old_state );
            if ( $old_data->{search} ) {
                $state->{search} = $old_data->{search};
            }
        };
    }

    my $info = $self->_fetch_profile_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    $state = $info->{state};
    my $links = $self->_fetch_profile_filter_links( $gid, $domain_id, 50, $state );

    return {
        selected_tags_html => $self->generate_content(
            { links => [ map { { name => $_ } } @{ $state->{tags} || [] } ] },
            { name => 'dicole_networking::component_browse_right_taglist' } 
        ),
        tags_html => $self->generate_content(
            { links => $links },
            { name => 'dicole_networking::component_browse_right_tagcloud' } 
        ),
        profiles_html => $self->generate_content(
            { profiles => $info->{object_info_list} },
            { name => 'dicole_networking::component_browse_right_profiles' }
        ),
        results_html => $self->generate_content(
            { profiles => $info->{object_info_list} },
            { name => 'dicole_networking::component_browse_right_profiles' }
        ),
        result_count => $info->{count},
        result_count_html =>  $info->{count} == 1 ? $self->_msg("1 person") : $self->_msg( "[_1] people", $info->{count} ),
        state => Dicole::Utils::JSON->encode( $state ),
        end_of_pages => $info->{end_of_pages},
    };
}

sub more_profiles2 {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = eval{ Dicole::Utils::JSON->decode( CTX->request->param('state') ) } || {};
    my $info = $self->_fetch_profile_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    return {
        profiles_html => $self->generate_content(
            { profiles => $info->{object_info_list} },
            { name => 'dicole_networking::component_browse_right_profiles' }
        ),
        results_html => $self->generate_content(
            { profiles => $info->{object_info_list} },
            { name => 'dicole_networking::component_browse_right_profiles' }
        ),
        state => Dicole::Utils::JSON->encode( $info->{state} ),
        end_of_pages => $info->{end_of_pages},
    };
}

sub profiles {
    my ( $self ) = @_;

    return Dicole::Utils::JSON->decode( CTX->request->param('return') );
}


sub add_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );
 
    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    # TODO: add some viable security

    my $response = eval {
        CTX->lookup_action('commenting')->execute('add_comment', {
            thread_id => $thread->id,
            display_type => 'chat',
            content => CTX->request->param('content'),
            parent_post_id => CTX->request->param('parent_post_id'),
            right_to_remove_comments => $thread->{object_id} == CTX->request->auth_user_id ? 1 : 0,
            requesting_user_id => CTX->request->auth_user_id,
            enable_private_comments => 1,
            show_private_comments => $self->_get_profile_user_from_thread( $thread ) == CTX->request->auth_user_id ? 1 : 0,
        } );
    };
    
    return $response || 0;
}

sub get_comments_html {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    # TODO: add some viable security
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('get_comments_html', {
            thread_id => $thread->id,
            display_type => 'chat',
            right_to_remove_comments => $thread->{object_id} == CTX->request->auth_user_id ? 1 : 0,
            requesting_user_id => CTX->request->auth_user_id,
            enable_private_comments => 1,
            show_private_comments => $self->_get_profile_user_from_thread( $thread ) == CTX->request->auth_user_id ? 1 : 0,
        } );
    };
    
    return $response || 0;
}

sub delete_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    # TODO: add some viable security
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('delete_comment', {
            thread_id => $thread->id,
            display_type => 'chat',
            post_id => CTX->request->param('post_id'),
            right_to_remove_comments => $thread->{object_id} == CTX->request->auth_user_id ? 1 : 0,
            requesting_user_id => CTX->request->auth_user_id,
            enable_private_comments => 1,
            show_private_comments => $self->_get_profile_user_from_thread( $thread ) == CTX->request->auth_user_id ? 1 : 0,
        } );
    };
    
    return $response || 0;
}

sub _get_profile_user_from_thread {
    my ( $self, $thread ) = @_;

    my $profile = CTX->lookup_object('networking_profile')->fetch( $thread->object_id );
    return 0 unless ref( $profile ) eq $thread->object_type;
    return $profile->user_id;
}

1; 
