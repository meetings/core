package OpenInteract2::Action::DicoleMeetingsNavigation;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub render {
    my ( $self ) = @_;

    my $params = {};
    my $globals = {};

    my $ia = CTX->controller->initial_action;
    my $tz_info = Dicole::Utils::Date->timezone_info( $self->_determine_timezone );

    my $uid = CTX->request->auth_user_id;
    my $user_is_temporary = $uid ? CTX->request->auth_user->email ? 0 : 1 : 1;

    $globals = {
        %$globals,
        meetings_user_id => $uid,
        meetings_auth_token => $uid ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
        meetings_user_email => $uid ? CTX->request->auth_user->email || '' : '',
        meetings_user_meetme_fragment => $uid ? $self->_fetch_user_matchmaker_fragment( CTX->request->auth_user ) || '' : '',
        meetings_page_load_time => time(),
        meetings_user_is_temporary => $user_is_temporary ? 1 : 0,
        meetings_user_timezone_name => $tz_info->{name},
        meetings_user_timezone_offset_string => $tz_info->{offset_string},
        meetings_user_timezone_offset_value => $tz_info->{offset_value},
        meetings_check_promo_code_url => $self->derive_url(action => "meetings_paypaljson", task => "valid_promo"),
        meetings_start_basic_purchase_url => $self->derive_url(action => "meetings_paypal", task => "start_basic_purchase"),
        meetings_change_timezone_url => $self->derive_url(
            action => 'meetings_json', task => 'change_timezone', target => 0, additional => []
        ),
        meetings_month_names => [ qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/ ],
        meetings_weekday_names => [ qw/Sun Mon Tue Wed Thu Fri Sat/ ]
    };


    $params = {
        %$params,
        user_info => $uid ? $self->_gather_user_info( $uid, 36 ) : {},
        user_is_temporary => $user_is_temporary,
        action_name => $ia->name,
        task_name => $ia->task,
        starting_url => $self->derive_url( action => 'meetings_global', task => 'detect', target => 0, additional => [] ),
        timezone_data_url => $self->derive_url(
            action => 'meetings_json', task => 'timezone_data', target => 0, additional => []
        ),
    };

    if ( my $uid = CTX->request->auth_user_id ) {
        my $pro = $self->_user_is_pro(CTX->request->auth_user);
        my $base_gid = $self->_determine_user_base_group( $uid );
        my $total_invites = $self->_get_note_for_user( 'meetings_total_beta_invites' );
        my $accounts_return_url = $ia->derive_url( action => 'meetings_raw', task => 'cookie_forward', additional => [], params => { to => $ia->derive_url( params => { open_admin => 'accounts' } ) } );

        $params->{logout_url} = $self->_create_user_logout_url( CTX->request->auth_user );

        $params->{my_profile_url} = $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] );

        $globals->{meetings_user_is_pro} = $pro ? 1 : 0;

         $globals->{meetings_request_notification_url} = $ia->derive_url( action => 'meetings_json', task => 'request_notification', additional => [] );

        $globals->{meetings_edit_my_profile_data_url} = $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] );
        $globals->{meetings_edit_my_profile_url} = $ia->derive_url( action => 'meetings_json', task => 'edit_my_profile', additional => [] );
#        $globals->{meetings_admin_password_url} =
#            $self->_session_is_secure
#                ? $ia->derive_url( action => 'meetings_json', task => 'admin_password', additional => [] )
#                : undef;

        $globals->{meetings_admin_password_url} =  $ia->derive_url( action => 'meetings_json', task => 'admin_password', additional => [] );

        $globals->{meetings_admin_accounts_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_facebook', additional => [] );
        $globals->{meetings_admin_language_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_language', additional => [] );
        $globals->{meetings_admin_accounts_data_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_accounts', additional => [], params => { return_url => $accounts_return_url } );
        $globals->{meetings_invite_beta_url} = $ia->derive_url( action => 'meetings_json', task => 'invite_beta' );
        $globals->{meetings_cancel_invite_url} = $ia->derive_url( action => 'meetings_json', task => 'cancel_invite');
        $globals->{meetings_quickbar_get_url} = $ia->derive_url( action => 'meetings_json', task => 'quickbar');
        $globals->{meetings_create_url} = $base_gid ? $ia->derive_url( action => 'meetings_json', task => 'create', target => $base_gid, additional => [ CTX->request->param('v') || () ] ) : '';
        $globals->{meetings_create_popup_url} = $base_gid ? $ia->derive_url( action => 'meetings_json', task => 'create', target => $base_gid, additional => [ CTX->request->param('v') || () ] ) : '';

        # TODO: don't give some of these for non-pro users
        $globals->{meetings_admin_appearance_url} = $ia->derive_url( action => 'meetings_json', task => 'save_appearance_data', target_id => 0, additional => [] );
        $globals->{meetings_draft_theme_header_image_url} = $ia->derive_url( action => 'meetings', task => 'draft_theme_header_image', target_id => 0, additional => [] ),
        $globals->{meetings_draft_theme_background_image_url} = $ia->derive_url( action => 'meetings', task => 'draft_theme_background_image', target_id => 0, additional => [] ),
        $globals->{meetings_disconnect_dropbox_url} = $ia->derive_url( action => 'meetings_json', task => 'dropbox_disconnect', target_id => 0, additional => [] );

        # Urls for killing social media connections
        $globals->{meetings_disconnect_urls} = {
            facebook => $ia->derive_url( action => 'meetings_json', task => 'disconnect_facebook', additional => [] ),
            google => $ia->derive_url( action => 'meetings_json', task => 'disconnect_google', additional => [] ),
            linkedin => $ia->derive_url( action => 'meetings_json', task => 'disconnect_linkedin', additional => [] ),
        };

        if ( my $open_section = CTX->request->cookie('cookie_parameter_open_admin') ) {
            $globals->{meetings_open_admin} = $open_section;
            OpenInteract2::Cookie->create( {
                    name => 'cookie_parameter_open_admin',
                    path => '/',
                    value => 'expired_by_date',
                    expires => '-3M',
                    HEADER => 'YES',
                } );
        }

        $globals->{meetings_admin_urls} = {
            profile_url => $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] ),
            accounts_url => $ia->derive_url( action => 'meetings_json', task => 'admin_accounts', additional => [], params => { return_url => $accounts_return_url} ),
            password_url => $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] ),
            language_url => $ia->derive_url( action => 'meetings_json', task => 'language_data', additional => [] ),
            invites_url => $ia->derive_url( action => 'meetings_json', task => 'admin_invites', additional => [] ),
            timezone_url => $ia->derive_url( action => 'meetings_json', task => 'timezone_data', additional => [] ),
            $pro ? (
            dropbox_url => $ia->derive_url( action => 'meetings_json', task => 'dropbox_data', additional => [] ),
#            bringio_url => $ia->derive_url( action => 'meetings_json', task => 'bringio_data', additional => [] ),
            appearance_url => $ia->derive_url( action => 'meetings_json', task => 'appearance_data', additional => [] ),
            ) : (),
            calendar_url => $ia->derive_url( action => 'meetings_json', task => 'calendar_data', additional => [] ),
        };

        $globals->{meetings_admin_urls}{subscription_url} = $ia->derive_url( action => 'meetings_json', task => 'subscription_data', additional => [] )
            if $pro;
        $params->{pro_user} = $pro ? 1 : 0;
        $params->{go_pro} = $pro ? 0 : 1;

        if ( $base_gid ) {
            $params->{admin_invites_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_invites', target => $base_gid );
            $params->{meeting_summary_url} = $ia->derive_url( action => 'meetings', task => 'summary', target => $base_gid );
            $params->{meeting_analytics_url} = $ia->derive_url( action => 'meetings', task => 'analytics', target => $base_gid );
        }
    }

    my $messages = Dicole::MessageHandler->get_messages;

    my %types = (
        MESSAGE_ERROR() => 'error',
        MESSAGE_SUCCESS() => 'message',
        MESSAGE_WARNING() => 'warning',
    );

    $params->{messages} = [ map { {
        text => $_->{content}, type => $types{ $_->{code} },
    } } @$messages ];

    Dicole::MessageHandler->clear_messages;

    if ( Dicole::URL->get_server_url( 443 ) =~ /ts(.dev)?.meetin.gs/ ) {
        $globals->{meetings_admin_urls}{invites_url} = '';
        $params->{admin_invites_url} = '';
    }

    $self->param( 'head_widgets', [
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.meetings_navigation")' ),
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
        ),
    ] );

    return $self->generate_content( $params, { name => 'dicole_meetings::special_meetings_navigation'} );
}

sub render_external {
    my ( $self ) = @_;

    my $params = {};

    $params = {
        %$params,
        action_name => CTX->controller->initial_action->name,
        task_name => CTX->controller->initial_action->task,
    };

    my $globals = {
        meetings_user_id => CTX->request->auth_user_id,
    };

    $self->param( 'head_widgets', [
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.meetings_navigation")' ),
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
        ),
    ] );

    return $self->generate_content( $params, { name => 'dicole_meetings::special_meetings_external_navigation'} );
}

sub render_clean {
   my ( $self ) = @_;

    my $params = {};

    $params = {
        %$params,
        action_name => CTX->controller->initial_action->name,
        task_name => CTX->controller->initial_action->task,
    };

    my $uid = CTX->request->auth_user_id;
    my $pro = $uid ? $self->_user_is_pro( CTX->request->auth_user ) : 0;

    my $globals = {
        meetings_user_id => $uid,
        meetings_user_is_pro => $pro ? 1 : 0,
        meetings_auth_token => $uid ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
        meetings_user_email => $uid ? CTX->request->auth_user->email || '' : '',
        meetings_user_meetme_fragment => $uid ? $self->_fetch_user_matchmaker_fragment( CTX->request->auth_user ) || '' : '',
    };

    $self->param( 'head_widgets', [
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.meetings_navigation")' ),
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
        ),
    ] );

    return $self->generate_content( $params, { name => 'dicole_meetings::special_meetings_clean_navigation'} );
}

sub _create_user_logout_url {
    my ( $self, $user ) = @_;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( my $partner = CTX->controller->initial_action->param('partner') ) {
        if ( $self->_get_note( logout_to_appdirect_marketplace => $partner ) ) {

            my $user_subs = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
                where => 'user_id = ? AND removed_date = 0',
                value => [ $user->id ],
            } );

            for my $user_sub ( @$user_subs ) {
                my $subscription = eval { $self->_ensure_object_of_type( meetings_company_subscription => $user_sub->subscription_id ) };
                next unless $subscription;
                next unless $subscription->partner_id == $partner->id;
                if ( my $url = $self->_get_note( appdirect_base_url => $subscription ) ) {
                    $url .= '/' unless $url =~ /\/$/;
                    $url .= 'applogout';
                    return Dicole::URL->from_parts( action => 'xlogout', domain_id => $domain_id, params => { url_after_logout => $url } );
                }
            }
        }
    }

    return Dicole::URL->from_parts( action => 'xlogout', domain_id => $domain_id, params => { url_after_logout => '/meetings/logout' } ),
}

sub render_matchmaking {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $ia = CTX->controller->initial_action;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $base_gid = $self->_determine_user_base_group( $uid );

    my $pro = CTX->request->auth_user_id ? $self->_user_is_pro( CTX->request->auth_user ) : 0;
    my $tz_info = Dicole::Utils::Date->timezone_info( $self->_determine_timezone );

    my $globals = {
        meetings_user_id => $uid,
        meetings_auth_token => $uid ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
        meetings_user_email => $uid ? CTX->request->auth_user->email || '' : '',
        meetings_user_meetme_fragment => $uid ? $self->_fetch_user_matchmaker_fragment( CTX->request->auth_user ) || '' : '',
        meetings_page_load_time => time(),
        meetings_user_timezone_name => $tz_info->{name},
        meetings_user_timezone_offset_string => $tz_info->{offset_string},
        meetings_user_timezone_offset_value => $tz_info->{offset_value},
        meetings_change_timezone_url => $self->derive_url(
            action => 'meetings_json', task => 'change_timezone', target => 0, additional => []
        ),
        meetings_month_names => [ qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/ ],
        meetings_weekday_names => [ qw/Sun Mon Tue Wed Thu Fri Sat/ ],
        meetings_logo_link => $ia->param('override_logo_link') || '',
        meetings_create_url => $base_gid ? $ia->derive_url( action => 'meetings_json', task => 'create', target => $base_gid, additional => [ CTX->request->param('v') || () ] ) : '',
    };

    my $params = {
        user_info => {},
        action_name => $ia->name,
        task_name => $ia->task,
        logo_link => $ia->param('override_logo_link') || '',
    };

    if ( $uid ) {
        $params = {
            %$params,
            user_info => $self->_gather_user_info( $uid, 36 ),
            logout_url =>  Dicole::URL->from_parts( action => 'xlogout', domain_id => $domain_id, params => { url_after_logout => $ia->derive_url, } ),
            my_profile_url => $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] ),
        };

        my $accounts_return_url = $ia->derive_url( action => 'meetings_raw', task => 'cookie_forward', additional => [], params => { to => $ia->derive_url( params => { open_admin => 'accounts' } ) } );

        $globals->{meetings_edit_my_profile_data_url} = $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] );
        $globals->{meetings_edit_my_profile_url} = $ia->derive_url( action => 'meetings_json', task => 'edit_my_profile', additional => [] );
        $globals->{meetings_admin_password_url} =  $ia->derive_url( action => 'meetings_json', task => 'admin_password', additional => [] );
        $globals->{meetings_admin_accounts_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_facebook', additional => [] );
        $globals->{meetings_admin_language_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_language', additional => [] );

        $globals->{meetings_admin_accounts_data_url} = $ia->derive_url( action => 'meetings_json', task => 'admin_accounts', additional => [], params => { return_url => $accounts_return_url } );

        $globals->{meetings_admin_urls} = {
            profile_url => $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] ),
            accounts_url => $ia->derive_url( action => 'meetings_json', task => 'admin_accounts', additional => [], params => { return_url => $accounts_return_url} ),
            password_url => $ia->derive_url( action => 'meetings_json', task => 'get_my_profile', additional => [] ),
            invites_url => $ia->derive_url( action => 'meetings_json', task => 'admin_invites', additional => [] ),
            timezone_url => $ia->derive_url( action => 'meetings_json', task => 'timezone_data', additional => [] ),
            language_url => $ia->derive_url( action => 'meetings_json', task => 'language_data', additional => [] ),
            $pro ? (
            dropbox_url => $ia->derive_url( action => 'meetings_json', task => 'dropbox_data', additional => [] ),
#            bringio_url => $ia->derive_url( action => 'meetings_json', task => 'bringio_data', additional => [] ),
            appearance_url => $ia->derive_url( action => 'meetings_json', task => 'appearance_data', additional => [] ),
            ) : (),
            calendar_url => $ia->derive_url( action => 'meetings_json', task => 'calendar_data', additional => [] ),
        };

        $globals->{meetings_admin_urls}{subscription_url} = $ia->derive_url( action => 'meetings_json', task => 'subscription_data', additional => [] )
            if $pro;

        # TODO: don't give some of these for non-pro users
        $globals->{meetings_admin_appearance_url} = $ia->derive_url( action => 'meetings_json', task => 'save_appearance_data', target_id => 0, additional => [] );
        $globals->{meetings_draft_theme_header_image_url} = $ia->derive_url( action => 'meetings', task => 'draft_theme_header_image', target_id => 0, additional => [] ),
        $globals->{meetings_draft_theme_background_image_url} = $ia->derive_url( action => 'meetings', task => 'draft_theme_background_image', target_id => 0, additional => [] ),
        $globals->{meetings_disconnect_dropbox_url} = $ia->derive_url( action => 'meetings_json', task => 'dropbox_disconnect', target_id => 0, additional => [] );

        # Urls for killing social media connections
        $globals->{meetings_disconnect_urls} = {
            facebook => $ia->derive_url( action => 'meetings_json', task => 'disconnect_facebook', additional => [] ),
            google => $ia->derive_url( action => 'meetings_json', task => 'disconnect_google', additional => [] ),
            linkedin => $ia->derive_url( action => 'meetings_json', task => 'disconnect_linkedin', additional => [] ),
        };

        if ( my $open_section = CTX->request->cookie('cookie_parameter_open_admin') ) {
            $globals->{meetings_open_admin} = $open_section;
            OpenInteract2::Cookie->create( {
                    name => 'cookie_parameter_open_admin',
                    path => '/',
                    value => 'expired_by_date',
                    expires => '-3M',
                    HEADER => 'YES',
                } );
        }

    }
    else {
        $params = {
            %$params,
            matchmaking_login_url => Dicole::URL->from_parts( action => 'meetings', task => 'login', domain_id => $domain_id, params => { url_after_login => $ia->derive_url, } ),
        };
    }

    my $messages = Dicole::MessageHandler->get_messages;

    my %types = (
        MESSAGE_ERROR() => 'error',
        MESSAGE_SUCCESS() => 'message',
        MESSAGE_WARNING() => 'warning',
    );

    $params->{messages} = [ map { {
        text => $_->{content}, type => $types{ $_->{code} },
    } } @$messages ];

    Dicole::MessageHandler->clear_messages;

    if ( Dicole::URL->get_server_url( 443 ) =~ /ts(.dev)?.meetin.gs/ ) {
        $globals->{meetings_admin_urls}{invites_url} = '';
        $params->{admin_invites_url} = '';
    }

    $self->param( 'head_widgets', [
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.meetings_navigation")' ),
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
        ),
    ] );

    return $self->generate_content( $params, { name => 'dicole_meetings::special_meetings_navigation'} );
}

sub render_no {
    my ( $self ) = @_;

    my $params = {};

    $params = {
        %$params,
        action_name => CTX->controller->initial_action->name,
        task_name => CTX->controller->initial_action->task,
    };

    my $uid = CTX->request->auth_user_id;
    my $pro = $uid ? $self->_user_is_pro( CTX->request->auth_user ) : 0;

    my $globals = {
        meetings_user_id => $uid,
        meetings_auth_token => $uid ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
        meetings_user_email => $uid ? CTX->request->auth_user->email || '' : '',
        meetings_user_meetme_fragment => $uid ? $self->_fetch_user_matchmaker_fragment( CTX->request->auth_user ) || '' : '',
        meetings_user_is_pro => $pro ? 1 : 0,
    };

    $self->param( 'head_widgets', [
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.meetings_navigation")' ),
        Dicole::Widget::Javascript->new(
            code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
        ),
    ] );

    return $self->generate_content( $params, { name => 'dicole_meetings::special_meetings_no_navigation'} );
}

1;

