package OpenInteract2::Action::DicoleNetworking;
use strict;
use base qw( OpenInteract2::Action::DicoleNetworkCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::MessageHandler qw( :message );
use Dicole::Widget::KVListing;
use Dicole::Widget::FancyContainer;
use HTML::Entities;
use List::Util;

$OpenInteract2::Action::DicoleNetworking::VERSION = sprintf("%d.%02d", q$Revision: 1.41 $ =~ /(\d+)\.(\d+)/);

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });
    $self->tool->Container->column_width( '280px', 1 );
    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/dicole_networking.css' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Raw->new( raw => '<!--[if lt IE 7]><link rel="stylesheet" href="/css/dicole_networking_ie6.css" media="all" type="text/css" /><![endif]-->' . "\n" ),
    );
    $self->tool->add_head_widgets( Dicole::Widget::Javascript->new(
        code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $params{globals} ) . ');'
    ) ) if $params{globals};

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.networking");' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");' ),
    );

    if ( $self->task =~ /^(explore|browse)$/ ) {
        my @ab = ();
        
        push @ab, {
            name => $self->_msg('Mail members'),
            class => 'networking_mail_members_action',
            url => $self->derive_url( action => 'mail_members', task => 'send' ),
        } if $self->mchk_y( 'OpenInteract2::Action::DicoleGroupAwareness', 'mail_members' );
 
        if ( $self->mchk_y( 'OpenInteract2::Action::DicoleInvite', 'invite' ) ) {
            my $g = $self->param('target_group');
            $self->tool->add_js_variables( {
                invite_dialog_data_url => $self->derive_url(
                    action => 'invite_json', task => 'dialog_data', additional => []
                ),
                invite_levels_dialog_data_url => $self->derive_url(
                    action => 'invite_json', task => 'levels_dialog_data', additional => []
                ),
                invite_submit_url => $self->derive_url(
                    action => 'invite_json', task => 'invite', additional => []
                ),
                invite_default_subject => $g ? $self->_msg('You have been invited to [_1]', $g->name ) : '',
            } );
            push @ab, {
                name => $self->_msg('Invite'),
                class => 'networking_invite_action js_hook_open_invite',
                url => $self->derive_url( action => 'invite', task => 'invite' ),
            };
        }

        push @ab, {
            name => $self->_msg('Manage users (action)'),
            class => 'networking_manage_users_action',
            url => $self->derive_url( action => 'groups_admin', task => 'users2' ),
        } if $self->mchk_y( 'OpenInteract2::Action::Groups', 'users' );

        $self->tool->action_buttons( [ @ab ] );
    }
}

sub explore {
    my ( $self ) = @_;

    if ( CTX->request->param('find') ) {
        my $ns = CTX->request->param('new_search');
        my @p = $ns ? ( search => $ns ) : ();
        $self->redirect( $self->derive_url(
            task => 'browse',
            additional => [],
            params => { @p }
        ) );
    }

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $params = {};

    my $user_id_list = CTX->lookup_action('domains_api')->e( users_by_group => {
        group_id => $gid, domain_id => $domain_id
    } ) || [];

    my $wtags = CTX->lookup_action('tagging')->execute( get_query_limited_weighted_tags => {
        group_id => 0,
        user_id => 0,
        domain_id => $domain_id,
        object_class => CTX->lookup_object('networking_profile'),
        where => 'dicole_networking_profile.domain_id = ?' . 
            ' AND ' . Dicole::Utils::SQL->column_in( 'dicole_networking_profile.user_id' => $user_id_list ),
        value => [ $domain_id ],
    } );

    my $widget = Dicole::Widget::TagCloud->new(
        prefix => $self->derive_url( task => 'browse', additional => [] ),
        limit => 60,
    );
    $widget->add_weighted_tags_array( $wtags );
    $params->{links} = $widget->template_params->{links};

    my $exclude_users_string = Dicole::Settings->fetch_single_setting(
        group_id => $gid, tool => 'networking', attribute => 'exclude_users',
    ) || '';

    my @exclude_users = $exclude_users_string ? ( split /\s*,\s*/, $exclude_users_string ) : ();

    my $most_active_users = CTX->lookup_action('statistics')->execute( get_most_active_users => {
        domain_id => $domain_id,
        group_id => $gid,
        exclude_users => \@exclude_users,
        limit => 12,
    } ) || [];

    $params->{most_active_users} = Dicole::Utils::User->icon_hash_list( $most_active_users, 55, $gid, $domain_id );

    my $last_active_users = CTX->lookup_action('awareness')->execute( last_active_users => {
        domain_id => $domain_id,
        group_id => $gid,
        exclude_users => [ @exclude_users, CTX->request->auth_user_id ],
        limit => 5,
    } ) || [];

    $params->{last_active_users} = Dicole::Utils::User->icon_hash_list( $last_active_users, 90, $gid, $domain_id );

    my $admin_collection_id = Dicole::Security->collection_id_by_idstring( 'group_admin' );

    my $sec_objs = CTX->lookup_object('dicole_security')->fetch_group({
        where => 'target_group_id = ? AND collection_id = ?',
        value => [ $gid, $admin_collection_id ],
    });

    my %admin_ids = map { $_->receiver_user_id => 1 } @$sec_objs;
    my $admin_ids = [ map { $_ || () } keys %admin_ids ];

    $params->{admins} = Dicole::Utils::User->icon_hash_list( $admin_ids, 55, $gid, $domain_id );

    $params->{show_all_url} = $self->derive_url( task => 'browse', additional => [] );

    my $globals = {
        invite_url => $self->derive_url( action => 'invite_json', task => 'invite', additional => [] ),
    };

    $self->_default_tool_init( globals => $globals );

#     $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'New members' ) );
#     $self->tool->Container->box_at( 0, 0 )->class( 'networking_left_new' );
#     $self->tool->Container->box_at( 0, 0 )->add_content(
#         [ Dicole::Widget::Raw->new(
#             raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_new' } )
#         ) ]
#     );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Search by name' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'networking_left_search_by_name' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_search_by_name' } )
        ) ]
    );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg( 'Most active members' ) );
    $self->tool->Container->box_at( 0, 1 )->class( 'networking_left_most_active' );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_most_active' } )
        ) ]
    );

    if ( scalar( @$admin_ids ) ) {
        $self->tool->Container->box_at( 0, 2 )->name( $self->_msg( 'Admins' ) );
        $self->tool->Container->box_at( 0, 2 )->class( 'networking_left_admins' );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_admin' } )
            ) ]
        );
    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Last visitors' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'networking_explore_right' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_explore_right' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub browse {
    my ( $self ) = @_;

   if ( CTX->request->param('find') ) {
        my $ns = CTX->request->param('new_search');
        my @p = $ns ? ( search => $ns ) : ();
        $self->redirect( $self->derive_url(
            task => 'browse',
            additional => [],
            params => { @p }
        ) );
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $gid = $self->param('target_group_id');
    my $tag = $self->param('tag');

    my $state = { tags => $tag ? [ $tag ] : [], search => CTX->request->param('search') || '' };
    my $info = $self->_fetch_profile_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    $state = $info->{state};
    my $links = $self->_fetch_profile_filter_links( $gid, $domain_id, 50, $state );

    my $params = {
        keywords => [ map { { name => $_ } } @{ $state->{tags} || [] } ],
        suggestions => $links,
        profiles => $info->{object_info_list},
        result_count => $info->{count},
        end_of_pages => $info->{end_of_pages},
        current_search => CTX->request->param('search') || '',
    };

    my $exclude_users_string = Dicole::Settings->fetch_single_setting(
        group_id => $gid, tool => 'networking', attribute => 'exclude_users',
    ) || '';

    my @exclude_users = $exclude_users_string ? ( split /\s*,\s*/, $exclude_users_string ) : ();

    my $most_active_users = CTX->lookup_action('statistics')->execute( get_most_active_users => {
        domain_id => $domain_id,
        group_id => $gid,
        exclude_users => \@exclude_users,
        limit => 12,
    } ) || [];

    $params->{most_active_users} = Dicole::Utils::User->icon_hash_list( $most_active_users, 55, $gid, $domain_id );

    my $admin_collection_id = Dicole::Security->collection_id_by_idstring( 'group_admin' );

    my $sec_objs = CTX->lookup_object('dicole_security')->fetch_group({
        where => 'target_group_id = ? AND collection_id = ?',
        value => [ $gid, $admin_collection_id ],
    });

    my %admin_ids = map { $_->receiver_user_id => 1 } @$sec_objs;
    my $admin_ids = [ map { $_ || () } keys %admin_ids ];

    $params->{admins} = Dicole::Utils::User->icon_hash_list( $admin_ids, 55, $gid, $domain_id );

    $params->{explore_url} = $self->derive_url( task => 'explore', additional => [] );

    my $globals = {
        networking_profiles_state => Dicole::Utils::JSON->encode( $state ),
        networking_keyword_change_url => $self->derive_url(
            action => 'networking_jsong', task => 'keyword_change', additional => []
        ),
        networking_more_profiles_url => $self->derive_url(
            action => 'networking_jsong', task => 'more_profiles2', additional => []
        ),
        networking_end_of_pages => $info->{end_of_pages},
        invite_url => $self->derive_url( action => 'invite_json', task => 'invite', additional => [] ),
    };

    $self->_default_tool_init( globals => $globals );

#    $self->tool->Container->box_at( 0, 0 )->name();
    $self->tool->Container->box_at( 0, 0 )->class( 'networking_browse_left_navi' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_browse_left_navi' } )
        ) ]
    );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg( 'Search by name' ) );
    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg( 'New search by name' ) ) if CTX->request->param('search');
    $self->tool->Container->box_at( 0, 1 )->class( 'networking_left_search_by_name' );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_search_by_name' } )
        ) ]
    );

    $self->tool->Container->box_at( 0, 2 )->name( $self->_msg( 'Most active members' ) );
    $self->tool->Container->box_at( 0, 2 )->class( 'networking_left_most_active' );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_most_active' } )
        ) ]
    );

    if ( scalar( @$admin_ids ) ) {
        $self->tool->Container->box_at( 0, 3 )->name( $self->_msg( 'Admins' ) );
        $self->tool->Container->box_at( 0, 3 )->class( 'networking_left_admins' );
        $self->tool->Container->box_at( 0, 3 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $params, { name => 'dicole_networking::component_left_admin' } )
            ) ]
        );
    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( '' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'networking_explore_right' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_browse_right' } )
        ) ]
    );

#     eval {
#         my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
#             object_class => CTX->lookup_object('networking_profile'),
#             from => [ 'dicole_group_user' ],
#             where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
#                 'dicole_group_user.groups_id = ? AND ' . 
#                 'dicole_networking_profile.user_id != ? AND ' .
#                 'dicole_networking_profile.domain_id = ?',
#             value => [ $gid, 1, $domain_id ],
#             group_id => 0,
#             user_id => 0,
#         } );
# 
#         $self->tool->Container->box_at( 0, 1 )->name(
#             $self->_msg( 'Personal tags' )
#         );
# 
#         $self->tool->Container->box_at( 0, 1 )->add_content(
#             [ $self->_fake_tag_cloud_widget(
#                 $self->derive_url( task => 'browse', additional => [] ),
#                 $tags
#             ) ]
#         );
#     };

    return $self->generate_tool_content;
}

sub show_profile {
    my ( $self ) = @_;

    $self->_default_tool_init;
    $self->tool->add_comments_widgets;
    
    my $user = CTX->lookup_object('user')->fetch( $self->param('user_id') );
    my $profile = $self->_get_profile_object( $user->id );

    my $params = $self->_gather_profile_params( $user, $profile );

    $params->{user_about_me} = Dicole::Utils::HTML->text_to_html( $params->{user_about_me} || '' );
    $params->{user_about_me} = Dicole::Utils::HTML->link_plaintext_urls( $params->{user_about_me} || '' );

    $params->{user_is_logged_in} = CTX->request->auth_user_id || 0;

    $self->_complete_external_service_links( $params );

    my $search = CTX->request->param('search');
    $params->{show_all_url} = $self->derive_url( task => 'browse', additional => [], $search ? ( params => { search => $search } ) : () );
    $params->{user_edit_url} = $self->derive_url( task => 'edit_profile' )
        if CTX->request->auth_user_id == $user->id || $self->chk_y( 'manage_profile', $user->id );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->class( 'networking_show_profile_left' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_show_profile_left' } )
        ) ]
    );

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = $self->param('target_group_id');


    my $bookmarked_page_data = CTX->lookup_action('wiki_api')->e( user_bookmarked_pages_data => {
        domain_id => $domain_id,
        group_id => $group_id,
        creator_id => $user->id,
    } );

    if ( scalar( @$bookmarked_page_data ) ) {
        my $bookmarked_params = {
            type => 'pages',
            objects => $bookmarked_page_data,
        };

        $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Bookmarked pages') );
        $self->tool->Container->box_at( 0, 1 )->class( 'networking_show_profile_left_pages' );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $bookmarked_params, { name => 'dicole_networking::component_show_profile_left_list' } )
            ) ]
        );
    }
    
    my $bookmarked_prese_data = CTX->lookup_action('presentations_api')->e( user_bookmarked_presentations_data => {
        domain_id => $domain_id,
        group_id => $group_id,
        creator_id => $user->id,
    } );

    if ( scalar( @$bookmarked_prese_data ) ) {
        my $bookmarked_params = {
            type => 'media',
            objects => $bookmarked_prese_data,
        };

        $self->tool->Container->box_at( 0, 2 )->name( $self->_msg('Bookmarked media') );
        $self->tool->Container->box_at( 0, 2 )->class( 'networking_show_profile_left_media' );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $bookmarked_params, { name => 'dicole_networking::component_show_profile_left_list' } )
            ) ]
        );
    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Show profile information' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'networking_show_profile_right' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_show_profile_right' } )
        ) ]
    );

    my $comments = Dicole::Widget::Container->new(
        id => 'comments',
        class => 'presentations_prese_comments',
        contents => [
            CTX->lookup_action('commenting')->execute( get_comment_tree_widget => {
                object => $profile,
                display_type => 'chat',
                comments_action => 'networking_jsong',
                input_anchor => 'networking_comments_' . $profile->id,
                input_hidden => 0,
                submit_comment_string => $self->_msg('Send message'),
                right_to_remove_comments => CTX->request->auth_user_id == $user->id ? 1 : 0,
                
                disable_commenting => CTX->request->auth_user_id ? 0 : 1,
                requesting_user_id => CTX->request->auth_user_id,
                enable_private_comments => 1,
                show_private_comments => CTX->request->auth_user_id == $user->id ? 1 : 0,
                private_check_string => $self->_msg('Check to send privately'),
            } ),
        ]
    );

    $self->tool->Container->box_at( 1, 1 )->name( $self->_msg('Leave a message') );
    $self->tool->Container->box_at( 1, 1 )->class('networking_comments_box');
    $self->tool->Container->box_at( 1, 1 )->add_content(
        [ $comments ]
    );

    return $self->generate_tool_content;
}

sub edit_profile {
    my ( $self ) = @_;

    $self->_default_tool_init;
    my $user = CTX->lookup_object('user')->fetch( $self->param('user_id') );
    my $profile = $self->_get_profile_object( $user->id );

    if ( CTX->request->param('save') ) {
        $self->_store_profile_params( $user, $profile );
        $self->redirect( $self->derive_url( task => 'show_profile' ) );
    }

    my $params = $self->_gather_profile_params( $user, $profile );

    $params->{tags} = [];
    $params->{tags_json} = Dicole::Utils::JSON->encode( $params->{tags_names} );
    $params->{tags_old_json} = Dicole::Utils::JSON->encode( $params->{tags_names} );

    $params->{cancel_url} = $self->derive_url( task => 'show_profile' );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->class( 'networking_edit_profile_left' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_edit_profile_left' } )
        ) ]
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Edit profile information' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'networking_edit_profile_right' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_networking::component_edit_profile_right' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _gather_profile_params {
    my ( $self, $user, $profile ) = @_;

    my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
        object => $profile,
        group_id => 0,
        user_id => 0,
    } );

    my $params = {
        user_first_name => $user->first_name,
        user_last_name => $user->last_name,
        user_role => $profile->contact_title,
        user_organization => $profile->contact_organization,
        user_location => join( ', ', ( $profile->contact_address_1 || (), $profile->contact_address_2 || () ) ),

        user_image => $self->_get_portrait( $profile, 1 ),

        user_email => $profile->contact_email,
        user_phone => $profile->contact_phone,
        user_skype => $profile->contact_skype,
        user_facebook => $profile->personal_facebook,
        user_twitter => $profile->personal_twitter,
        user_linkedin => $profile->personal_linkedin,
        user_webpage => $profile->personal_blog,
        user_about_me => $profile->about_me,
        tags_names => $tags,
        tags => [ map { {
            name => $_,
            url => $self->derive_url( action => 'networking', task => 'browse', additional => [ $_ ] )
        } } @$tags ],
    };

    return $params;
}

sub _store_profile_params {
    my ( $self, $user, $profile ) = @_;

    $user->first_name( CTX->request->param('user_first_name') );
    $user->last_name( CTX->request->param('user_last_name') );
    $user->save;

    $profile->contact_organization( CTX->request->param( 'user_organization' ) );
    $profile->contact_title( CTX->request->param( 'user_role' ) );
    $profile->contact_email( CTX->request->param( 'user_email' ) );
    $profile->contact_phone( CTX->request->param( 'user_phone' ) );
    $profile->contact_skype( CTX->request->param( 'user_skype' ) );
    $profile->personal_facebook( CTX->request->param( 'user_facebook' ) );
    $profile->personal_twitter( CTX->request->param( 'user_twitter' ) );
    $profile->personal_linkedin( CTX->request->param( 'user_linkedin' ) );
    $profile->personal_blog( CTX->request->param( 'user_webpage' ) );
    $profile->about_me( CTX->request->param( 'user_about_me' ) );

    $profile->contact_address_1( CTX->request->param( 'user_location' ) );
    $profile->contact_address_2( '' );

    $profile->save;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_draft => {
        draft_id => CTX->request->param('user_photo_draft_id') || '0',
        user_id => $user->id,
        domain_id => $domain_id,
    } );

    my $tags = eval {
        CTX->lookup_action('tags_api')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    CTX->lookup_action('networking_api')->e( update_tags_for_user_profile_from_json => {
        domain_id => $domain_id,
        user_id => $user->id,
        json => $tags,
        json_old => CTX->request->param('tags_old') || '[]',
    } );
}

sub list {
    my ( $self ) = @_;
    
    my $gid = $self->param('target_group_id');
    my $tag = $self->param('tag');
    
    $self->_init_tool( cols => 2, rows => 10 );
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );
    
    my $uids = [];
    if ( $tag ) {
        my $profiles = CTX->lookup_action('tagging')->execute( tag_limited_fetch_group => {
            object_class => CTX->lookup_object('networking_profile'),
            user_id => 0,
            group_id => 0,
            from => [ 'dicole_group_user' ],
            where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
                'dicole_group_user.groups_id = ? AND dicole_networking_profile.domain_id = ?',
            value => [ $gid, $self->_current_domain_id ],
            tags => [ $tag ],
        } ) || [];
        
        $uids = [ map { $_->user_id < 2 ? () : $_->user_id } @$profiles ];
    }

    my $users = $tag ?
        CTX->lookup_object( 'user' )->fetch_group( {
            where => Dicole::Utils::SQL->column_in( 'sys_user.user_id', $uids ),
        } ) || []
        :
        CTX->lookup_object( 'user' )->fetch_group( {
            from => [ 'sys_user', 'dicole_group_user' ],
            where => 'dicole_group_user.user_id = sys_user.user_id AND ' . 
                'sys_user.user_id != 1 AND dicole_group_user.groups_id = ?',
            value => [ $gid ],
    #        limit => 20,
        } ) || [];
    
    my $content = scalar( @$users ) ?
        $self->_get_profile_card_list_widget( $gid, $users )
        :
        Dicole::Widget::Text->new(
            class => 'networking_explore_not_found listing_not_found',
            text => $self->_msg('No people found.'),
        );
    
    $self->tool->Container->box_at( 1, 0 )->name(
        $tag ? $self->_msg( $tag )
            : $self->_msg( 'People' )
    );
    
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $content ]
    );
    
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('networking_profile'),
            from => [ 'dicole_group_user' ],
            where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
                'dicole_group_user.groups_id = ? AND ' . 
                'dicole_networking_profile.user_id != ? AND ' .
                'dicole_networking_profile.domain_id = ?',
            value => [ $gid, 1, $self->_current_domain_id ],
            group_id => 0,
            user_id => 0,
        } );

        $self->tool->Container->box_at( 0, 1 )->name(
            $self->_msg( 'Personal tags' )
        );

        $self->tool->Container->box_at( 0, 1 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( task => 'list', additional => [] ),
                $tags
            ) ]
        );
    };
    
    return $self->generate_tool_content;
}

sub profile {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_full_url( task => 'show_profile' ) );

    my ( $gid, $uid, $user, $profile ) = $self->_determine_targets_with_profile;
    
    $self->_init_tool( cols => 2, rows => 10 );
    
    my $portrait_box = Dicole::Widget::Vertical->new(
        id => 'networking_profile_portrait_container',
        contents => [
            Dicole::Widget::Container->new(
                class => 'networking_profile_portrait_border',
                contents => [ Dicole::Widget::Image->new(
                    src => $self->_get_portrait( $profile ),
                ) ],
            ),
            $self->chk_y('manage_profile', $uid ) ? Dicole::Widget::LinkBar->new(
                link => $self->derive_url( task => 'upload_portrait' ),
                content => $self->_msg( 'Upload portrait' ),
            ) : (),
        ],
    );
    
    $self->tool->Container->box_at( 0, 0 )->class('profile_image_container');
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( $user->first_name . ' ' . $user->last_name )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $portrait_box ]
    );
    
    my $contact_map = $self->_get_contact_id_map;
    
    my @add_remove_contact = ();

    if ( $self->chk_y('manage_contacts', CTX->request->auth_user_id ) ) {
        @add_remove_contact = $self->_get_add_remove_contact_widget(
            $user->id, $contact_map
        );
    }
    
    my $contact_left = CTX->request->auth_user_id ?
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_left_contact',
            contents => [
                @add_remove_contact,
                Dicole::Widget::Text->new(
                    class => 'networking_profile_user_name',
                    text => $user->first_name . ' ' . $user->last_name,
                ),
                Dicole::Widget::Text->new(
                    class => 'networking_profile_position',
                    text => join( ', ',
                        $profile->contact_title || (),
                        $profile->contact_organization || ()
                    ),
                ),
                Dicole::Widget::Text->new(
                    class => 'networking_profile_motto',
                    text => $profile->personal_motto,
                ),
            ]
        ) :
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_left_contact',
            contents => [
                Dicole::Widget::Text->new(
                    class => 'networking_profile_user_name',
                    text => $user->first_name . ' ' . $user->last_name,
                ),
            ]
        );
    
    my $blog_url = $profile->personal_blog || '';
    my $blog_text = $profile->personal_blog || '';
    if ( $blog_url ) {
        $blog_url = 'http://' . $blog_url unless $blog_url =~ /^http/;
        $blog_text =~ s/^https?:\/\///;
        $blog_text =~ s/\/$//;
        $blog_text = Dicole::Utils::Text->shorten( $blog_text, 30 );
    }
    my $edited_email = $profile->contact_email;
    my ($start, $middle, $end ) = $edited_email =~ /(.*)\@(.*)\.(\w+)/;
    $start = '<wbr>'.Dicole::Utils::HTML->encode_entities($start).'@</wbr>';
    $middle = '<wbr>'.Dicole::Utils::HTML->encode_entities($middle).'</wbr>';
    $end = '<wbr>.'.Dicole::Utils::HTML->encode_entities($end).'</wbr>';
    $edited_email = Dicole::Widget::Raw->new( raw =>  $start.$middle.$end );


    my $contact_right = Dicole::Widget::Vertical->new(
        class => 'networking_profile_right_contact',
        contents => [
            $profile->contact_address_1 || (),
            $profile->contact_address_2 || (),
            $profile->contact_email ? Dicole::Widget::Hyperlink->new(
                link => 'mailto:' . $profile->contact_email,
                content => $edited_email,
            ) : (),
            ($blog_url && $blog_text) ? Dicole::Widget::Container->new( contents => [
                $self->_msg( 'Blog: ' ),
                Dicole::Widget::Hyperlink->new(
                    link => $blog_url,
                    content => $blog_text,
                ),
            ] ) : (),
            $profile->contact_skype ? Dicole::Widget::Container->new( contents => [
                $self->_msg( 'Skype: ' ),
                $profile->contact_skype,
            ] ) : (),
            $profile->contact_phone ? $self->_msg( 'Phone: ' ) . $profile->contact_phone : (),
        ]
    );
    my $facebook_url = $profile->personal_facebook;
    my $twitter_url = $profile->personal_twitter;
    $twitter_url =~ s/^\s*//;
    $twitter_url = 'http://twitter.com/' . $twitter_url unless $twitter_url =~ /^http:/;

    my $linkedin_url = $profile->personal_linkedin;
    my $vcard_url = $self->derive_url(
                        action => 'networking_raw',
                        task => 'get_information_as_vcard',
                        target => $gid,
                        additional => [$uid, $user->first_name.$user->last_name.'.vcf'],
                    );
    
    for my $url ( $facebook_url, $twitter_url, $linkedin_url ) {
        $url =~ s/^/http:\/\// unless ! $url || $url =~ /^http/;
    }
    
    my $contact_center = Dicole::Widget::Vertical->new(
        class => 'networking_profile_center_contact',
        contents => [
            $profile->personal_facebook ? Dicole::Widget::LinkBar->new(
                class => 'profile_facebook_link',
                link => $facebook_url,
                content => Dicole::Widget::Text->new(
                    class => 'profile_facebook_text',
                    text => 'Facebook',
                ),
            ) : (),
            $profile->personal_twitter ? Dicole::Widget::LinkBar->new(
                class => 'profile_twitter_link',
                link => $twitter_url,
                content => Dicole::Widget::Text->new(
                    class => 'profile_twitter_text',
                    text => 'Twitter',
                ),
            ) : (),
            $profile->personal_linkedin ? Dicole::Widget::LinkBar->new(
                class => 'profile_linkedin_link',
                link => $linkedin_url,
                content => Dicole::Widget::Text->new(
                    class => 'profile_linkedin_text',
                    text => 'LinkedIn',
                ),
            ) : (),
            Dicole::Widget::LinkBar->new(
                class => 'profile_vcard_link',
                link => $vcard_url,
                content => Dicole::Widget::Text->new(
                    class => 'profile_vcard_text',
                    text => 'Vcard',
                ),
            ),
        ],
   );
#     get_logger(LOG_APP)->error(Data::Dumper::Dumper($self->tool->Container->box_at( 0, 0 )));
    my @edit_contact = $self->chk_y('manage_profile', $uid) ?
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url(
                task => 'edit_personal',
                params => { id => $profile->id },
            ),
            content => $self->_msg( 'Edit contact & personal information' ),
        ) : ();
        
    my $contact_box = Dicole::Widget::Vertical->new(
        id => 'networking_profile_contact_container',
        contents => [
            Dicole::Widget::FancyContainer->new(
                class => 'networking_profile_contact_fancycontainer',
                contents => [ Dicole::Widget::Columns->new(
                    left => $contact_left,
                    center => $contact_center,
                    right => $contact_right,
                    left_width => '40%',
                    center_width => '20%',
                    right_width => '40%',
                    center_overflow => 'visible',
                ) ],
            ),
            @edit_contact,
        ],
    );
    
    my $employer_left = Dicole::Widget::Vertical->new(
        class => 'networking_profile_left_employer',
        contents => [
            $profile->employer_title || (),
            Dicole::Widget::Text->new(
                class => 'networking_profile_user_name',
                text => $profile->employer_name,
            ),
            
            $profile->employer_address_1 || (),
            $profile->employer_address_2 || (),
            $profile->employer_phone || (),
        ]
    );

    my $employer_right = $profile->prof_description ?
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_right_employer',
            contents => [
                Dicole::Widget::Text->new(
                    class => 'networking_profile_prof_description_title',
                    text => $self->_msg( 'Professional description' ),
                ),
                Dicole::Widget::Text->new(
                    class => 'networking_profile_prof_description',
                    text => $profile->prof_description,
                ),
            ],
        ) :
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_right_employer',
            contents => [],
        );
    
    my @edit_employer = $self->chk_y('manage_profile', $uid) ?
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url(
                task => 'edit_professional',
                params => { id => $profile->id },
            ),
            content => $self->_msg( 'Edit employer information' ),
        ) : ();
    
    my $employer_box = Dicole::Widget::Vertical->new(
        id => 'networking_profile_contact_container',
        contents => [
            Dicole::Widget::Container->new(
                contents => [ Dicole::Widget::Columns->new(
                    left => Dicole::Widget::FancyContainer->new(
                        class => 'networking_profile_left_employer_fancycontainer',
                        contents => [ $employer_left, ]
                    ),
                    right => $employer_right,
                    left_width => '50%',
                    right_width => '50%'
                ) ],
            ),
            @edit_employer,
        ],
    );
    
    my $education_left = Dicole::Widget::Vertical->new(
        class => 'networking_profile_left_education',
        contents => [
            Dicole::Widget::KVListing->new(
                rows => [
                    $profile->educ_school ? { key => { content => $self->_msg( 'School' ) },
                        value => { content => $profile->educ_school } } : (),
                    $profile->educ_degree ? { key => { content => $self->_msg( 'Degree' ) },
                        value => { content => $profile->educ_degree } } : (),
                    $profile->educ_other_degree ? { key => { content => $self->_msg( 'Other degree' ) },
                        value => { content => $profile->educ_other_degree } } : (),
                    $profile->educ_target_degree ? { key => { content => $self->_msg( 'Target degree' ) },
                        value => { content => $profile->educ_target_degree } } : (),
                ]
            ),
        ]
    );

    my $education_right = $profile->educ_skill_profile ?
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_right_education',
            contents => [
                Dicole::Widget::Text->new(
                    class => 'networking_profile_skill_profile_title',
                    text => $self->_msg( 'Skill profile' ),
                ),
                Dicole::Widget::Text->new(
                    class => 'networking_profile_skill_profile',
                    text => $profile->educ_skill_profile,
                ),
            ],
        ) :
        Dicole::Widget::Vertical->new(
            class => 'networking_profile_right_education',
            contents => [],
        );

    my @edit_education = $self->chk_y('manage_profile', $uid) ?
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url(
                task => 'edit_educational',
                params => { id => $profile->id },
            ),
            content => $self->_msg( 'Edit education information' ),
        ) : ();

    my $education_box = Dicole::Widget::Vertical->new(
        id => 'networking_profile_contact_container',
        contents => [
            Dicole::Widget::Container->new(
                contents => [ Dicole::Widget::Columns->new(
                    left => $education_left,
                    right => $education_right,
                    left_width => '50%',
                    right_width => '50%'
                ) ],
            ),
            @edit_education,
        ],
    );
    
    my $interests_box = Dicole::Widget::Vertical->new(
        class => 'networking_profile_interests_box',
    );
    
    eval {
        # hack weighted tags for only one object
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('networking_profile'),
            group_id => 0,
            user_id => 0,
            where => 'dicole_networking_profile.user_id = ?',
            value => [ $uid ],
        } );
        
        $interests_box->add_content(
            $self->_fake_tag_cloud_widget(
                "/networking/explore/$gid/",
                $tags
            ),
        );
    };

    $interests_box->add_content(
        Dicole::Widget::LinkBar->new(
            link => Dicole::URL->from_parts(
                action => 'networking',
                task => 'edit_interests',
                target => $gid,
                additional => [ $uid ],
            ),
            content => $self->_msg( 'Edit personal tags' ),
        ),
    ) if $self->chk_y('manage_profile', $uid);
    
    my $contacts_box = Dicole::Widget::Vertical->new(
        class => 'networking_profile_right_contacts',
    );
    my $contact_ids = $self->_get_contact_id_list( $uid );
    my @randomized_contact_ids = List::Util::shuffle( @$contact_ids );
    my @random_ids = splice( @randomized_contact_ids, 0, 5 );
    my $profile_hash = $self->_get_profile_objects_hash( \@random_ids );
    my $contact_row = Dicole::Widget::Horizontal->new(
        class => 'networking_profile_contacts_row',
    );
    for my $id ( @random_ids ) {
        my $usr = CTX->lookup_object('user')->fetch( $id );
        next unless $usr;
        $contact_row->add_content(
            Dicole::Widget::LinkImage->new(
                alt => $usr->first_name . ' ' . $usr->last_name,
                src => $self->_get_portrait_thumb( $profile_hash->{ $id } ),
                width => '30px',
                height => '30px',
                'link' => $self->derive_url(
                    additional => [ $id ],
                ),
            ),
        );
    }
    $contacts_box->add_content(
        $contact_row,
        Dicole::Widget::LinkBar->new(
            link => $self->derive_url( 
                task => 'contacts',
            ),
            content => $self->_msg( 'Show all contacts' ),
        ),
    );
    
    my $personal_tags_box = Dicole::Widget::Vertical->new(
        class => 'networking_profile_right_tags',
    );
    
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('blogs_entry'),
            group_id => $gid,
            user_id => 0,
            where => 'dicole_blogs_entry.group_id = ? AND dicole_blogs_entry.user_id = ?',
            value => [ $gid, $uid ],
        } );
        
        $personal_tags_box->add_content(
            $self->_fake_tag_cloud_widget(
                "/blogs/my/$gid/0/$uid/",
                $tags
            ),
        );
    };

    $personal_tags_box->add_content(
        Dicole::Widget::LinkBar->new(
            link => Dicole::URL->from_parts(
                action => 'blogs',
                task => 'my',
                target => $gid,
                additional => [ 0, $uid ],
            ),
            content => $self->_msg( 'Show all posts' ),
        ),
    );

    my $statistics_box = Dicole::Widget::Container->new(
        class => 'networking_profile_right_statistics',
    );
    
    my $last_online = $self->_msg( 'Never' );
    eval {
        $last_online = CTX->lookup_action('awareness')->execute(
            'when_online_string_by_user_id', { user_id => $uid  }
        );
    };

    my $total_posts = 0;
    eval {
        $total_posts = CTX->lookup_action('blogging')->execute(
            'post_count', { user_id => $uid, group_id => $gid }
        );
    };
    $total_posts = $@ if $@;
    
    my $total_comments = 0;
    eval {
        $total_comments = CTX->lookup_action('commenting')->execute(
            'comment_count', { user_id => $uid, group_id => $gid }
        );
    };
    $total_comments = $@ if $@;
    
    my $group_points = eval {
        CTX->lookup_action('statistics')->execute(
            get_user_points => { user_id => $uid, group_id => $gid }
        );
    };
    
    my $group_ranking = eval {
        CTX->lookup_action('statistics')->execute(
            get_user_ranking => { group_id => $gid, user_points => $group_points || 0 }
        );
    };
    
    $statistics_box->add_content(
        Dicole::Widget::KVListing->new(
            widths => ['40%', '60%'],
            rows => [
                defined $last_online ? { key => { content => $self->_msg( 'Online' ) },
                    value => { content => $last_online } } : (),
                defined $total_posts ? { key => { content => $self->_msg( 'Posts' ) },
                    value => { content => $total_posts } } : (),
                defined $total_comments ? { key => { content => $self->_msg( 'Comments' ) },
                    value => { content => $total_comments } } : (),
                defined $group_points ? { key => { content => 'Rating' },
                    value => { content => $group_points } } : (),
                defined $group_ranking ? { key => { content => 'Ranking' },
                    value => { content => $group_ranking } } : (),
            ]
        ),
    );


    if ( CTX->request->auth_user_id ) {
        $self->tool->Container->box_at( 1, 0 )->class('profile_contact_personal_info_container');
        $self->tool->Container->box_at( 1, 0 )->name(
             $self->_msg( 'Contact & personal information' )
        );

        $self->tool->Container->box_at( 1, 0 )->add_content(
            [ $contact_box ]
        );
        $self->tool->Container->box_at( 1, 1 )->class('profile_employer_container');
        $self->tool->Container->box_at( 1, 1 )->name(
            $self->_msg( 'Employer' )
        );
        $self->tool->Container->box_at( 1, 1 )->add_content(
            [ $employer_box ]
        );
        $self->tool->Container->box_at( 1, 2 )->class('profile_education_container');
        $self->tool->Container->box_at( 1, 2 )->name(
            $self->_msg( 'Education' )
        );
        $self->tool->Container->box_at( 1, 2 )->add_content(
            [ $education_box ]
        );
        $self->tool->Container->box_at( 1, 3 )->class('profile_tags_container');
        $self->tool->Container->box_at( 1, 3 )->name(
            $self->_msg( 'Personal tags' )
        );
        $self->tool->Container->box_at( 1, 3 )->add_content(
            [ $interests_box ]
        );
        $self->tool->Container->box_at( 0, 1 )->class('profile_interest_tags_container');
        $self->tool->Container->box_at( 0, 1 )->name(
            $self->_msg( 'Tags of interest' )
        );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            [ $personal_tags_box ]
        );
        $self->tool->Container->box_at( 0, 2 )->class('profile_contacts_container');
        $self->tool->Container->box_at( 0, 2 )->name(
            $self->_msg( 'Sampling of contacts' )
        );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            [ $contacts_box ]
        );
        $self->tool->Container->box_at( 0, 3 )->class('profile_statistics_container');
        $self->tool->Container->box_at( 0, 3 )->name(
            $self->_msg( 'Statistics' )
        );
        $self->tool->Container->box_at( 0, 3 )->add_content(
            [ $statistics_box ]
        );
    }
    $self->tool->tool_title_suffix( $self->_msg($user->first_name . ' ' . $user->last_name) );
    return $self->generate_tool_content;
}

sub edit_personal {
    my ( $self ) = @_;
    
    my $task = OpenInteract2::Action::DicoleNetworking::Edit->new( $self, {
        box_title => $self->_msg('Contact & personal information'),
        class => 'networking_profile',
        skip_security => 1,
        view => 'edit_personal',
        id_param => 'id',
        save_redirect => $self->derive_url( task => 'profile' ),
    } );
    $task->_tool_config( 'tool_args', { no_tool_tabs => 1 } );
    
    return $task->execute;
}

sub edit_professional {
    my ( $self ) = @_;
    
    my $task = OpenInteract2::Action::DicoleNetworking::Edit->new( $self, {
        box_title => $self->_msg('Professional information'),
        class => 'networking_profile',
        skip_security => 1,
        view => 'edit_professional',
        id_param => 'id',
        save_redirect => $self->derive_url( task => 'profile' ),
    } );
    $task->_tool_config( 'tool_args', { no_tool_tabs => 1 } );
    
    return $task->execute;
}

sub edit_educational {
    my ( $self ) = @_;
    
    my $task = OpenInteract2::Action::DicoleNetworking::Edit->new( $self, {
        box_title => $self->_msg('Educational information'),
        class => 'networking_profile',
        skip_security => 1,
        view => 'edit_educational',
        id_param => 'id',
        save_redirect => $self->derive_url( task => 'profile' ),
    } );
    $task->_tool_config( 'tool_args', { no_tool_tabs => 1 } );
    
    return $task->execute;
}

sub edit_interests {
    my ( $self ) = @_;
    
    my ( $gid, $uid, $user, $profile ) = $self->_determine_targets_with_profile;
    
    $self->_init_tool( cols => 2, rows => 2 );
    
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");' ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );
    
    if ( CTX->request->param('save') ) {
        my $tags_old = CTX->request->param('tags_old');
        my $tags_value = eval {
            CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                input => CTX->request->param('tags_add_tags_input_field'),
                json => CTX->request->param('tags'),
            } );
        };
        
        eval {
            my $tags = CTX->lookup_action('tagging');
            eval {
                $tags->execute( 'update_tags_from_json', {
                    object => $profile,
                    group_id => 0,
                    user_id => 0,
                    json => $tags_value,
                    json_old => $tags_old,
                } );
            };
            $self->log('error', $@ ) if $@;
        };
        
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Personal tags updated.') );
    }
    
    if ( CTX->request->param('save') || CTX->request->param('cancel') ) {
        return $self->redirect( $self->derive_url( task => 'profile' ) );
    }
    
    
    my $weighted_suggestions = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
        object_class => CTX->lookup_object('networking_profile'),
        from => [ 'dicole_group_user' ],
        where => 'dicole_networking_profile.user_id = dicole_group_user.user_id AND ' .
            'dicole_group_user.groups_id = ? AND dicole_networking_profile.domain_id = ?',
        value => [ $gid, $self->_current_domain_id ],
        group_id => 0,
        user_id => 0,
    } );
    
    my $suggestion_cloud = Dicole::Widget::TagCloudSuggestions->new(
        target_id => 'tags',
    );
    $suggestion_cloud->add_weighted_tags_array( $weighted_suggestions );
    
    my $old_tags = CTX->lookup_action('tagging')->execute( 'get_tags_for_object_as_json', {
        object => $profile,
        group_id => 0,
        user_id => 0,
    } );

    my @widgets = (
        Dicole::Widget::Text->new(
            class => 'definitionHeader',
            text => $self->_msg( 'Personal tags' ),
        ),
        Dicole::Widget::FormControl::Tags->new(
            id => 'tags',
            name => 'tags',
            value => $old_tags,
            old_value => $old_tags,
            add_tag_text => $self->_msg('Add tag'),
        ),
        scalar( @$weighted_suggestions ) ? (
            Dicole::Widget::Text->new(
                class => 'definitionHeader',
                text => $self->_msg( 'Click to add popular tags' ),
            ),
            $suggestion_cloud,
        )
        :
        (),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Save changes'),
                name => 'save',
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Cancel'),
                name => 'cancel',
            ),
        ] ),
    );
    
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Add personal tags' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ @widgets ]
    );
    
    return $self->generate_tool_content;
}

sub upload_portrait {
    my ( $self ) = @_;

    my ( $gid, $uid, $user, $profile ) = $self->_determine_targets_with_profile;
    die 'security error' if ! $self->chk_y('manage_profile', $uid);

    $self->_init_tool( upload => 1 );
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object('networking_profile'),
        skip_security => 1,
        current_view => 'upload_portrait',
    ) );
    $self->init_fields;

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'upload_image' }
        )
    ] );

    # Basic information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Image to upload in GIF or JPG format' )
    );

    # Defines submit buttons for our tool
    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' )
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show profile' ),
        link  => Dicole::URL->create_from_current(
            task => 'profile',
        )
    );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );
        if ( $return_code ) {
            my $success = $self->_update_portrait_from_upload( $profile, 'upload_image' );
            if ( $success ) {
                $self->tool->add_message( MESSAGE_SUCCESS,
                    $self->_msg( "Image uploaded." )
                );
                return CTX->response->redirect(
                    $self->derive_url(
                        task => 'profile',
                    )
                );
            }
            else {
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg( "Error while converting image." )
                );
            }
        } else {
            $return = $self->_msg( "Upload failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub my_profile {
    my ( $self ) = @_;
    
    $self->redirect( $self->derive_url(
        task => 'profile',
        additional => [ CTX->request->auth_user_id ],
    ) );
}

sub my_contacts {
    my ( $self ) = @_;
    
    $self->redirect( $self->derive_url(
        task => 'contacts',
        additional => [ CTX->request->auth_user_id ],
    ) );
}

sub my_contact_contacts {
    my ( $self ) = @_;
    
    $self->redirect( $self->derive_url(
        task => 'contact_contacts',
        additional => [ CTX->request->auth_user_id ],
    ) );
}

sub contacts {
    my ( $self ) = @_;

    my ( $gid, $uid, $user ) = $self->_determine_targets;

    $self->_init_tool(
        cols => 2, rows => 10,
        tab_override => 'my_contacts'
    );
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );
    
    my $ids = $self->_get_contact_id_list( $uid );
    
    my $users = $self->param('target_type') eq 'group' ?
        CTX->lookup_object( 'user' )->fetch_group( {
            from => [ 'sys_user', 'dicole_group_user' ],
            where => 'dicole_group_user.user_id = sys_user.user_id AND ' . 
                'sys_user.user_id != 1 AND dicole_group_user.groups_id = ? AND ' .
                Dicole::Utils::SQL->column_in( 'sys_user.user_id', $ids ),
            value => [ $gid ],
    #        limit => 20,
        } ) || []
        :
        CTX->lookup_object( 'user' )->fetch_group( {
            where => 'sys_user.user_id != 1 AND ' .
                Dicole::Utils::SQL->column_in( 'sys_user.user_id', $ids ),
        } ) || [];
      
    my $list = $self->_get_profile_card_list_widget(
        $gid, $users, $uid, $ids
    );
    
    my $title = $self->_msg('My contacts');
    unless ( CTX->request->auth_user_id == $uid ) {
        my $uname = $user->first_name . ' ' . $user->last_name;
        $title = $self->_msg( 'Contacts of [_1]', $uname );
    }
    
    $self->tool->Container->box_at( 1, 0 )->name( $title );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );
   
    return $self->generate_tool_content;
}

sub contact_contacts {
    my ( $self ) = @_;
    
    my ( $gid, $uid, $user ) = $self->_determine_targets;
    
    $self->_init_tool( cols => 2, rows => 10 );
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );

    my $ids = $self->_get_contact_id_list( $uid );
    my $all_ids = $self->_get_contact_id_list_for_users( $ids );

    my $users = $self->param('target_type') eq 'group' ?
        CTX->lookup_object( 'user' )->fetch_group( {
            from => [ 'sys_user', 'dicole_group_user' ],
            where => 'dicole_group_user.user_id = sys_user.user_id AND ' . 
                'sys_user.user_id != 1 AND dicole_group_user.groups_id = ? AND ' .
                Dicole::Utils::SQL->column_in( 'sys_user.user_id', $all_ids ),
            value => [ $gid ],
    #        limit => 20,
        } ) || []
        :
        CTX->lookup_object( 'user' )->fetch_group( {
            where => 'sys_user.user_id != 1 AND ' .
                Dicole::Utils::SQL->column_in( 'user_id', $all_ids ),
        } ) || [];
    
    my $list = $self->_get_profile_card_list_widget( $gid, $users );
    
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'People' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );

    return $self->generate_tool_content;
}

sub _fake_tag_cloud_widget {
    my ($self, $prefix, $tags, $limit ) = @_;
    
    return Dicole::Widget::Text->new( text => $self->_msg('No tags.') ) unless @$tags;
    
    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => $prefix,
        limit => $limit,
    );
    $cloud->add_weighted_tags_array( $tags );
    return $cloud;
}

1;

package OpenInteract2::Action::DicoleNetworking::Edit;

use base 'Dicole::Task::GTEdit';
use OpenInteract2::Context   qw( CTX );

sub _init {
    my ( $self, $id ) = @_;

    my $object = CTX->lookup_object('networking_profile')->fetch( $id );
    die 'security error' unless
        $object && $object->user_id == $self->action->param('user_id') &&
        $self->action->schk_y( 'OpenInteract2::Action::DicoleNetworking::manage_profile', $object->user_id );

    return $self->SUPER::_init( $id );
}

1;

