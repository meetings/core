package OpenInteract2::Action::DicoleMeetings;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use Text::Markdown           qw();

sub login {
    my ( $self ) = @_;

    my $ual = CTX->request->param('url_after_login');

    if ( CTX->request->auth_user_id ) {
        if ( $ual ) {
            return $self->redirect( $ual );
        }
        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect', params => $self->_get_current_utm_params ) );
    }

    $self->_redirect_unless_https;

    my $globals = {
        meetings_login_link_email_url => $self->derive_url( action => 'meetings_json', task => 'send_login_email', additional => [] ),
        meetings_facebook_email_url => $self->derive_url( action => 'meetings_json', task => 'send_facebook_login_email', additional => [] ),
        meetings_login_url => $self->derive_url( action => 'meetings_json', task => 'login', additional => [] ),
        meetings_login_error_message => CTX->request->param('error_message'),
    };

    my $params = {
        url_after_login => $ual || $self->derive_url( action => 'meetings_global', task => 'detect' ),
        google_start_url => $self->derive_url( action => 'meetings_global', task => 'google_start_2', params => { return_url => $ual } ),
    };

    if ( my $lang = CTX->request->param('lang') ) {
        $self->language( $lang );
    }

    my $partner = $self->param('partner');
    if ( $partner && ! CTX->request->param('skip_saml2') ) {
        my $provider = $self->_get_note( saml2_provider => $partner );
        if ( $provider ) {
            my $ip_limit_list = $self->_get_note( saml2_limit_ip_list => $partner );
            if ( ! $ip_limit_list || $self->_check_if_request_ip_matches_provided_limit_list( $ip_limit_list ) ) {
                my $start_authn_url = $self->derive_url(
                    action => 'meetings_global', task => 'start_saml2_login', target => 0, additional => [ $provider ],
                    params => { url_after_login => $ual }
                );
                return $self->redirect( $start_authn_url );
            }
        }
    }

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Login' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_login' } );
}

sub pick {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $quickmeet = $self->_fetch_valid_quickmeet( $self->param('quickmeet_key') );

    return $self->_render_404 unless $quickmeet;

    my $meeting_user = $self->_fetch_user_for_email( $self->_get_note( email => $quickmeet ) );

    if ( CTX->request->auth_user_id ) {
        unless ( $meeting_user && CTX->request->auth_user_id == $meeting_user->id ) {
            return $self->redirect( $self->derive_url( action => 'xlogout', task => '', additional => [], params => { url_after_logout => $self->derive_full_url } ) );
        }
    }

    my $meeted_user = Dicole::Utils::User->ensure_object( $quickmeet->creator_id );
    my $user_fragment = $self->_fetch_user_matchmaker_fragment( $meeted_user, $domain_id );
    my $mmr = $self->_ensure_matchmaker_object( $quickmeet->matchmaker_id );

    my $quickmeet_params = { key => $quickmeet->url_key, %{ $self->_get_note( extra_params => $quickmeet ) || {} } };

    $self->_redirect_for_mobile_with_params( { user_fragment => $user_fragment, matchmaker_fragment => $mmr->vanity_url_path || 'default', open_calendar => 1, quickmeet_key => $self->param('quickmeet_key'), ensure_user_id => $meeting_user ? $meeting_user->id : 0 } );

    return $self->redirect( $self->derive_url(
            task => 'meet',
            additional => [ $user_fragment, $mmr->vanity_url_path || 'default', 'calendar' ],
            params => { quickmeet => Dicole::Utils::JSON->encode( $quickmeet_params ) },
    ) );
}

sub meet {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $user_fragment = $self->param('user_fragment') || '';
    my $mmr_fragment = $self->param('matchmaker_fragment') || '';
    my $calendar_fragment = $self->param('calendar_fragment') || '';

    # NOTE: i don't think this is used anymore as preview is a calendar mode, which is one of the last parameters
    if ( lc( $user_fragment ) eq 'preview' ) {
        $user_fragment = $self->param('matchmaker_fragment') || '';
        $mmr_fragment = $self->param('calendar_fragment') || '';
        $calendar_fragment = $self->param('additional_fragment') || '';
    }

    my $target_user = $self->_resolve_matchmaker_url_user( $user_fragment );

    if ( ! $target_user ) {
        return $self->redirect('http://www.meetin.gs/not-found/');
    }

    if ( ! CTX->request->auth_user_id ) {
        $self->language( $target_user->language );
    }

    my $mmr = $mmr_fragment ? $self->_fetch_user_matchmaker_with_path( $target_user, $mmr_fragment ) : undef;
    if ( $mmr ) {
        Dicole::Utils::Gearman->dispatch_versioned_task( prime_matchmaker_upcoming_meeting_suggestions => { matchmaker_id => $mmr->id } );
    }
    else {
        my $mmrs = $self->_fetch_user_matchmakers( $target_user );
        for my $this_mmr ( @$mmrs ) {
            Dicole::Utils::Gearman->dispatch_versioned_task( prime_matchmaker_upcoming_meeting_suggestions => { matchmaker_id => $this_mmr->id } );
        }
    }

    $self->_redirect_for_mobile_with_params( { user_fragment => $user_fragment, matchmaker_fragment => $mmr_fragment, open_calendar => ( $calendar_fragment eq 'calendar' ) ? 1 : 0 } );

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    my $globals = {
        meetings_auth_user_id => ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? 1 : 0,
        meetings_auth_token => CTX->request->auth_user_id ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
        meetings_time_zone_data => {
            choices => $timezone_choices,
            data => $timezone_data,
        },
    };

    my $params = {};

    my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
    my $user_info = $self->_gather_user_info( $target_user, 200, $domain_id );

    my $target_user_name = Dicole::Utils::User->name( $target_user );
    my $target_user_image = $user_info->{image} ? $domain_host . $user_info->{image} : '';

    my $meet_me_url = $self->_generate_user_meet_me_url(  $target_user, $domain_id, $domain_host, $user_fragment );
    my $meet_me_description = $self->_get_note_for_user( 'meetme_description', $target_user, $domain_id ) || '';

    if ( $mmr ) {
        $meet_me_url = $self->_generate_matchmaker_meet_me_url( $mmr, $target_user, $domain_host, $user_fragment );
        $meet_me_description = $mmr->description || '';

        if ( my $mm_event_id = $mmr->matchmaking_event_id ) {
            my $mm_event = $self->_ensure_matchmaking_event_object( $mm_event_id );
            if ( my $mm_event_language = $self->_get_note( default_language => $mm_event ) ) {
                $self->language( $mm_event_language );
            }
        }
    }
    else {
        my $background_theme_for_lecagy_check = $self->_get_note_for_user( 'meetme_background_theme', $target_user, $domain_id ) // '';
        if ( $background_theme_for_lecagy_check eq '' ) {
            if ( my $default_mmr = $self->_fetch_user_matchmaker_with_path( $target_user, '' ) ) {
                $meet_me_description = $default_mmr->description || '';
            }
        }
    }

    my @raw_tags = (
        '<meta name="twitter:card" content="summary"/>',
        '<meta name="twitter:url" content="'. Dicole::Utils::HTML->encode_entities( $meet_me_url ) .'"/>',
        '<meta name="twitter:title" content="'. Dicole::Utils::HTML->encode_entities( $self->_nmsg('Schedule a meeting with %1$s', [ $target_user_name ] ) ) .'"/>',

        '<meta name="twitter:description" content="'. Dicole::Utils::HTML->encode_entities( $meet_me_description ) .'"/>',
        '<meta name="twitter:image" content="'. Dicole::Utils::HTML->encode_entities( $target_user_image ) .'"/>',
        '<meta name="twitter:site" content="meetin_gs"/>',

        '<meta property="og:title" content="'. Dicole::Utils::HTML->encode_entities( $self->_nmsg('Schedule a meeting with %1$s', [ $target_user_name ] ) ) .'"/>',
        '<meta property="og:description" content="'. Dicole::Utils::HTML->encode_entities( $meet_me_description ) .'"/>',
        '<meta property="og:url" content="'. Dicole::Utils::HTML->encode_entities( $meet_me_url ) .'">',
        '<meta property="og:site_name" content="'. Dicole::Utils::HTML->encode_entities( $self->_nmsg('Meetin.gs - Meet %1$s', [ $target_user_name ] ) ) .'"/>',
        '<meta property="og:type" content="website"/>',
        '<meta property="og:image" content="'. Dicole::Utils::HTML->encode_entities( $target_user_image ) .'"/> ',
    );

    my $head_widgets = [ Dicole::Widget::Raw->new( raw => join "", @raw_tags ) ];

    $self->_set_controller_variables( $globals, $self->_nmsg('Schedule a meeting with %1$s', [ $target_user_name ] ), undef, undef, $head_widgets );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub meetme_share {
    return _meetme_skeleton( $_[0], $_[0]->_nmsg( 'Share your Meet Me url' ) );
}

sub meetme_claim {
    return _meetme_skeleton( $_[0], $_[0]->_nmsg( 'Claim your Meet Me url' ) );
}

sub meetme_config {
    return _meetme_skeleton( $_[0], $_[0]->_nmsg( 'Meet me configuration' ) );
}

sub _meetme_skeleton {
    my ( $self, $title ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    if ( $self->task eq 'meetme_share' ) {
        my $mmrs = $self->_fetch_user_matchmakers( CTX->request->auth_user );
        my $public_found = 0;

        for my $mmr ( @$mmrs ) {
            next if $public_found;
            my $last_active_epoch = $self->_resolve_matchmaker_last_active_epoch( $mmr );

            next if $last_active_epoch && time > $last_active_epoch;
            if ( $self->_get_note( meetme_visible => $mmr ) || $self->_get_note( meetme_hidden => $mmr ) ) {
                $public_found = $self->_get_note( meetme_hidden => $mmr ) ? 0 : 1;
            }
            else { # Legacy
                $public_found = $mmr->matchmaking_event_id ? 0 : 1;
            }
        }

        # if no public matchmakers
        die $self->redirect( $self->derive_full_url( task => 'meetme_config', add_params => { sharing_failed => 1 } ) ) unless $public_found;
    }

    return $self->_full_cookie_forward if CTX->request->param( 'sharing_failed' );
    return $self->_full_cookie_forward if CTX->request->param( 'select_new_calendars' );
    return $self->_full_cookie_forward if CTX->request->param( 'init_from_localstorage' );

    my $return_url = URI::URL->new( $self->derive_url );
    $return_url->query_form({  init_from_localstorage => 1, select_new_calendars => 1 });
    my $return_url_string = "" . $return_url;
    $return_url->query_form({  init_from_localstorage => 1 });
    my $cancel_url_string = "" . $return_url;

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    my $globals = {
        meetings_page_load_time => time(),
        meetings_google_connected => $self->_user_has_connected_google( CTX->request->auth_user ) ? 1 : 0,
        meetings_google_connect_url => $self->derive_url(
            action => 'meetings_global', task => 'google_start_2', params => {
                expect_refresh_token => 1,
                return_url => $return_url_string,
                cancel_url => $cancel_url_string,
            }
        ),
        meetings_init_from_localstorage => $self->_expire_cookie_parameter_and_return_value( 'init_from_localstorage' ) ? 1 : 0,
        meetings_select_new_calendars => $self->_expire_cookie_parameter_and_return_value( 'select_new_calendars' ) ? 1 : 0,
        meetings_sharing_failed => $self->_expire_cookie_parameter_and_return_value( 'sharing_failed' ) ? 1 : 0,
        meetings_time_zone_data => {
            choices => $timezone_choices,
            data => $timezone_data,
        },
        meetings_auth_user_id => ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? 1 : 0,
        meetings_auth_token => CTX->request->auth_user_id ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
    };

    my $params = {};

    my $platform_domain = CTX->server_config->{dicole}{development_mode} ? 'platform-dev.meetin.gs' : 'platform.meetin.gs';

    my @raw_tags = (
<<CODE
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
<script src="//platform.linkedin.com/in.js" type="text/javascript">lang: en_US</script>
<script src="//$platform_domain/mtn.js" type="text/javascript"></script>
<script type="text/javascript">(function() {var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;po.src = 'https://apis.google.com/js/plusone.js';var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);})();</script>
CODE
    );

    my $head_widgets = [ Dicole::Widget::Raw->new( raw => join "", @raw_tags ) ];

    $self->_set_controller_variables( $globals, $title, undef, undef, $head_widgets );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

# TODO: does not work without a partner
sub ext_login {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $email = CTX->request->param('email');

    if ( ! $email ) {
        return $self->redirect( $self->derive_url( action => 'meetings', task => 'login' ) );
    }

    my $target_user = $self->_fetch_user_for_email( $email );

    if ( ! $target_user ) {
        return $self->redirect( $self->derive_url( action => 'meetings', task => 'login' ) );
    }

    my $partner = $self->param('partner') || $self->PARTNERS_BY_ID->{ CTX->request->param('partner_id') };

    if ( ! $partner ) {
        # TODO: not implemented yet
        return $self->redirect( $self->derive_url( action => 'meetings', task => 'login' ) );
    }

    my $preserve_partner_domain = $self->_get_note( preserve_domain => $partner ) ? 1 : 0;
    my $host = $preserve_partner_domain ? $self->_get_host_for_partner( $partner, 443 ) : $self->_get_host_for_domain( $domain_id, 443 );

    if ( CTX->request->auth_user_id && CTX->request->auth_user_id == $target_user->id && $preserve_partner_domain ) {
        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) );
    }

    my $partner_can_log_in = $self->_partner_can_log_user_in( $partner, $target_user );
    my $pcs_is_valid = $self->_authenticate_partner_for_user( $partner, $target_user, CTX->request->param('pcs') );

    if ( $partner_can_log_in && $pcs_is_valid ) {
        return $self->redirect( $host . $self->derive_url( action => 'meetings_global', task => 'detect', params => {
                    dic => Dicole::Utils::User->temporary_authorization_key( $target_user )
                } ) );
    }

    unless ( $preserve_partner_domain || CTX->request->param('partner_id') ) {
        return $self->redirect( $host . $self->derive_full_url( add_params => { partner_id => $partner->id } ) );
    }

    my $authorize_url = $self->_generate_authorized_uri_for_user(
        $host . $self->derive_url( task => 'authorize_partner', additional => [], params => {
                user_id => $target_user->id,
                partner_id => $partner->id,
                key => $self->_create_partner_authorization_key_for_user( $partner, $target_user ),
                return_url => $self->derive_url( action => 'meetings_global', task => 'detect' ),
            } ),
        $target_user,
        $domain_id,
    );

    my $login_url = $self->_generate_authorized_uri_for_user(
        $host . $self->derive_url( action => 'meetings_global', task => 'detect' ),
        $target_user,
        $domain_id
    );

    $self->_send_themed_mail(
        user => $target_user,
        partner_id => $partner->id,
        domain_id => $domain_id,

        template_key_base => 'meetings_authorize_partner',
        template_params => {
            user_name => Dicole::Utils::User->name( $target_user ),
            partner_name => $partner->name,
            login_url => $login_url,
            authorize_url => $authorize_url,
        },
    );

    my $params = { target_email => $target_user->email };

    $self->_set_controller_variables( {}, $self->_nmsg( 'Check your email to log in' ) );
    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_ext_login' } );
}

sub beta_signup {
    my ( $self ) = @_;
    return $self->redirect( $self->derive_full_url( task => 'signup_page' ) );
}

sub signup_page {
    my ( $self ) = @_;

    my $globals = { meetings_invite_beta_free_url => $self->derive_url( action => 'meetings_json', task => 'signup' ) };

    my $params = { meetings_invite_beta_free_url => $self->derive_url( action => 'meetings_json', task => 'signup' ) };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Sign up' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_signup' } );
}

sub matchmaking_admin_editor {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;
    my $user_is_developer = $self->_get_note_for_user( developer => $user, $domain_id );

    die "security error" unless $user;

    my $mm_id = $self->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;
    die "security error" unless $matchmaker->creator_id == $user->id || $user_is_developer;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $deck_name = '';
    if ( my $deck_a_id = $self->_get_note( deck_attachment_id => $matchmaker ) ) {
        my $a = CTX->lookup_action('attachments_api')->e( get_object => {
            attachment_id => $deck_a_id,
        } );

        $deck_name = $a ? $a->filename : '';
    }

    my $image_url = $matchmaker->logo_attachment_id ? $self->derive_url( action => 'meetings_raw', task => 'matchmaker_image', additional => [ $matchmaker->id ] ) : '';

    my $globals = {
        meetings_show_matchmaking_admin_editor => 1,
        meetings_matchmaking_admin_editor_params => {
            matchmaker_id => $matchmaker->id,
            registration_organization => $matchmaker->name,
            description => $matchmaker->description,
            website => $matchmaker->website,
            is_disabled => $matchmaker->disabled_date ? 1 : 0,
            user_is_developer => $user_is_developer ? 1 : 0,
            image_url => $image_url,
            deck_name => $deck_name,
            $mm_event ? ( developer_back_link => $self->derive_url( task => 'matchmaking_list', additional => [ $mm_event->id ] ) ) : (),
            selected_market_list => $self->_get_note( market_list => $matchmaker ) || [],
            market_list => $self->_matchmaking_event_market_list( $mm_event ),
            selected_track => $self->_get_note( track => $matchmaker ) || '',
            track_list => $self->_matchmaking_event_track_list( $mm_event ),
        },
        meetings_matchmaking_admin_editor_url => $self->derive_url( action => 'meetings_json', task => 'matchmaking_admin_editor_edit', additional => [] ),
    };

    my $params = { };

    # NOTE: this goes to origin because we don't want matchmakers to go to the list
    $self->_override_matchmaking_logo_url( $mm_event, 'go_to_origin' );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_registration {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id && ! CTX->request->auth_user->email ) {
        CTX->lookup_session_config->{class}->delete_session( CTX->request->session );
        return $self->redirect( $self->derive_full_url );
    }

    my $mm_event_id = $self->param('matchmaking_event_id');
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    die "missing event" unless $mm_event;

    my $globals = {
        meetings_show_matchmaking_register => 1,
        meetings_auth_user_id => ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? 1 : 0,
        meetings_create_matchmaker_url => $self->derive_url( action => 'meetings_json', task => 'create_matchmaker' ),
        meetings_matchmaking_event_id => $self->param('matchmaking_event_id'),
        meetings_matchmaking_registration_params => {
            event_id => $mm_event->id,
            market_list => $self->_matchmaking_event_market_list( $mm_event ),
            track_list => $self->_matchmaking_event_track_list( $mm_event ),
        },
    };

    my $params = { };

    $self->_override_matchmaking_logo_url( $mm_event, 'go_to_origin' );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_list {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id && ! CTX->request->auth_user->email ) {
        CTX->lookup_session_config->{class}->delete_session( CTX->request->session );
        return $self->redirect( $self->derive_full_url( params => { email => CTX->request->param('email') } ) );
    }

    $self->_redirect_to_hide_url_authentication;

    my $mm_event_id = $self->param('matchmaking_event_id');
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    die "missing event" unless $mm_event;

    if ( my $epoch = $self->_get_note( disable_listing_epoch => $mm_event ) ) {
        if ( time > $epoch ) {
            return $self->redirect( $self->_get_note( disable_listing_redirect_url => $mm_event ) );
        }
    }

    my $event_mmr_found = 0;
    if ( CTX->request->auth_user_id ) {
        my $user_mmrs = $self->_fetch_user_matchmakers( CTX->request->auth_user );
        for my $mmr ( @$user_mmrs ) {
            $event_mmr_found = 1 if $mmr->matchmaking_event_id == $mm_event_id;
        }
    }

    my $user_email = ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? CTX->request->auth_user->email : CTX->request->param('email');

    my $globals = {
        meetings_show_matchmaking_list => 1,
        meetings_auth_user_id => ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? 1 : 0,
        meetings_matchmaking_event_id => $mm_event_id,
        meetings_matchmaking_event_list_unregistered_profiles => $self->_get_note( list_unregistered_profiles => $mm_event ),
        meetings_event_matchmaker_found_for_user => $event_mmr_found ? 1 : 0,
        meetings_event_listing_registration_url => ( $user_email ) ? $self->derive_url( task => 'wizard', additional => [ $mm_event_id ], params => { email => $user_email } ) : '',
    };

    my $params = { };

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_calendar {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id && ! CTX->request->auth_user->email ) {
        CTX->lookup_session_config->{class}->delete_session( CTX->request->session );
        return $self->redirect( $self->derive_full_url );
    }

    my $mm_id = $self->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $globals = {
        meetings_show_matchmaking_calendar => 1,
        meetings_matchmaker_matchmaking_event_id => $matchmaker->matchmaking_event_id,
        meetings_auth_user_id => ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? 1 : 0,
        meetings_matchmaking_calendar_data_url => $self->derive_url( action => 'meetings_json', task => 'matchmaker_calendar_data', additional => [ $matchmaker->id ] ),
        meetings_matchmaking_create_lock_url => $self->derive_url( action => 'meetings_json', task => 'matchmaker_create_lock', additional => [ $matchmaker->id ] ),
        meetings_matchmaking_confirm_url => $self->derive_url( action => 'meetings_json', task => 'matchmaker_confirm', additional => [ $matchmaker->id ] ),
        meetings_matchmaking_cancel_lock_url => $self->derive_url( action => 'meetings_json', task => 'matchmaker_cancel_lock', additional => [ $matchmaker->id ] ),
        meetings_matchmaking_confirm_register_url => $self->derive_url( action => 'meetings_json', task => 'matchmaker_confirm_register', additional => [ $matchmaker->id ] ),
        meetings_matchmaking_back_link => $self->derive_url( action => 'meetings', task => 'matchmaking_list', additional => [ $matchmaker->matchmaking_event_id || 0 ] ),
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_user_register_success {
    my ( $self ) = @_;

    my $lock_id = $self->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    die "umm.. no lock?" unless $lock;

    my $mm_id = $lock->matchmaker_id;
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "no matchmaker found" unless $matchmaker;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
    my $expected_user = Dicole::Utils::User->ensure_object( $lock->expected_confirmer_id );

    $self->language( $expected_user->language );

    my $global_params = {
        user_email => CTX->request->param('email'),
    };

    my $globals = {
        meetings_show_matchmaking_user_register_success => 1,
        meetings_matchmaking_user_register_success_params => $global_params,
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_register_success {
    my ( $self ) = @_;

    my $mm_id = $self->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;


    my $globals = {
        meetings_show_matchmaking_register_success => 1,
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event, 'go_to_origin' );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_limit_reached {
    my ( $self ) = @_;

    my $mm_id = $self->param('matchmaker_id');
    my $mm = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $mm;

    my $mm_event_id = $mm->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    $self->_redirect_for_mobile_with_params( { limit_reached_for_matchmaking_event_id => $mm_event_id } );

    my $globals = {
        meetings_show_matchmaking_limit_reached => 1,
        meetings_matchmaking_limit_reached_params => {},
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_lock_expired {
    my ( $self ) = @_;

    my $lock_id = $self->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    $self->_redirect_for_mobile_with_params( { expired_matchmaker_lock_id => $lock_id } );

    die "umm.. no lock?" unless $lock;
    die "security error" if $lock->creator_id && CTX->request->auth_user_id != $lock->creator_id;

    my $mm_id = $lock->matchmaker_id;
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "no matchmaker found" unless $matchmaker;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $back_link = $mm_event ? $self->_get_note( organizer_list_url => $mm_event ) || $self->derive_url( action => 'meetings', task => 'matchmaking_list', additional => [ $matchmaker->matchmaking_event_id || 0 ] ) : $self->_generate_matchmaker_meet_me_url( $matchmaker );

    my $globals = {
        meetings_show_matchmaking_lock_expired => 1,
        meetings_matchmaking_lock_expired_params => {
            back_link => $back_link,
        },
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, 'Matchmaking' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub matchmaking_success {
    my ( $self ) = @_;

    my $lock_id = $self->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    die "umm.. no lock?" unless $lock;

    my $mm_id = $lock->matchmaker_id;
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "no matchmaker found" unless $matchmaker;

    if ( $lock->created_meeting_id && CTX->request->auth_user_id && $self->_get_user_meeting_participation_object( CTX->request->auth_user_id, $lock->created_meeting_id ) ) {
        my $who = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('%1$s has accepted your request', [ Dicole::Utils::User->name( $who ) ] ) );
        return $self->redirect( $self->_get_meeting_abs( $lock->created_meeting_id ) );
    }

    eval { $self->_confirm_matchmaker_lock_for_user( $lock, CTX->request->auth_user_id, $matchmaker ); };

    if ( my $err = $@ ) {
        return $self->redirect( $self->derive_url( task => 'matchmaking_lock_expired', additional => [ $lock->id ] ) ) if $err =~ /^lock expired/;
        return $self->redirect( $self->derive_url( task => 'matchmaking_limit_reached', additional => [ $lock->matchmaker_id ] ) ) if $err =~ /^matchmaking event limit reached/;
        die $err unless $err =~ /^meeting already created for lock/;
    }

    $self->_redirect_for_mobile_with_params( { confirmed_matchmaker_lock_id => $lock->id } );

    $self->_redirect_to_hide_url_authentication;

    my $domain_id = $matchmaker->domain_id;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
    my $requester_user = undef;

    if ( $lock->expected_confirmer_id ) {
        $requester_user = Dicole::Utils::User->ensure_object( $lock->expected_confirmer_id );
        $self->language( $requester_user->language );
    }
    else {
        $self->language( $creator_user->language );
    }

    my $begin_date = $lock->locked_slot_begin_date;
    my $end_date = $lock->locked_slot_end_date;
    my $used_time_zone = $self->_get_note( user_time_zone => $lock ) || $self->_get_note( time_zone => $matchmaker );
    my $time_string = $self->_form_timespan_string_from_epochs_tz_and_lang( $begin_date, $end_date, $used_time_zone, $self->language );

    my $location_name = $self->_generate_matchmaker_lock_location_string( $lock, $matchmaker );

    my $creator_name = Dicole::Utils::User->name( $creator_user );
    my $creator_email = $creator_user->email;

    $creator_name .= ' ('.$creator_email.')' unless $creator_name eq $creator_email;

    my $description = "This meeting is tentative. Wait for $creator_name to confirm the meeting.";

    my $gcal_url = $self->_generate_google_publish_url( $lock->title . ' (tentative)', $begin_date, $end_date, $location_name, $description );

    my $calendar_url = '';
    if ( $requester_user ) {
        my $ical_checksum = $self->_generate_meeting_ics_digest_for_user( $lock->id, $requester_user );
        $calendar_url = $self->derive_url( action => 'meetings_raw', task => 'matchmaker_lock_ics', additional => [ $lock->id, $requester_user->id, $ical_checksum, 'event.ics' ] );
    };

    my $quickmeet_key = $self->_get_note( quickmeet_key => $lock );
    my $quickmeet = $quickmeet_key ? $self->_fetch_valid_quickmeet( $quickmeet_key, time - 15*60 ) : undef;

    my $creator_info = $self->_gather_user_info( $creator_user, 50, $domain_id );

    my $global_params = {
        quickmeet => $self->_get_note( quickmeet_key => $lock ) ? 1 : 0,
        image => $creator_info->{image} || '',
        name => Dicole::Utils::User->name( $creator_user ),
        email => $creator_user->email,
        title => $lock->title,
        matchmaking_event => $mm_event ? $mm_event->custom_name : '',
        time => $time_string,
        location => $location_name,
        gcal_url => $gcal_url,
        calendar_url => $calendar_url,
        matchmaking_list_url => $mm_event ? $self->_get_note( organizer_list_url => $mm_event ) || $self->derive_url( task => 'matchmaking_list', additional => [ $matchmaker->matchmaking_event_id ] ) : '',
    };

    my $globals = {
        meetings_show_matchmaking_success => 1,
        meetings_matchmaking_success_params => $global_params,
        meetings_requested_meeting_id => $lock->created_meeting_id,
    };

    my $params = {};

    $self->_override_matchmaking_logo_url( $mm_event );
    $self->_set_controller_variables( $globals, $self->_nmsg( 'Meeting request has been sent' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_matchmaking' } );
}

sub _override_matchmaking_logo_url {
    my ( $self, $mm_event, $send_to_origin ) = @_;

    return if ! $mm_event;

    my $url = $send_to_origin ?
        $mm_event->organizer_url
        :
        $self->_get_note( organizer_list_url => $mm_event ) || $self->derive_url( task => 'matchmaking_list', target => 0, additional => [ $mm_event->id ] );

    $self->param( 'override_logo_link', $url );
}

sub connect_service_account {
    my ( $self ) = @_;

    my $globals = {};
    my $params = {};
    my $title = $self->_nmsg( 'Connecting accounts' );

    for my $attr ( qw( service_user_id email url_after_action state ) ) {
        $params->{ $attr } = CTX->request->param( $attr );
    }

    if ( CTX->request->param('service_type') eq 'google' ) {
        $title = $self->_nmsg( 'Connecting Google and Meetin.gs accounts' );
        $globals->{ meetings_connect_service_account_url } = $self->derive_url( action => 'meetings_json', task => 'send_google_login_email', target => 0 ) };

    $self->_set_controller_variables( $globals, $title );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_connect_service_account' } );
}

sub wizard {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $meet_me_url = CTX->request->param('meet_me_url');
    my $email = CTX->request->param('email');
    my $event_id = $self->param('matchmaking_event_id');
    my $event = $event_id ? $self->_ensure_matchmaking_event_object( $event_id ) : undef;
    my $partner = $self->param('partner');

    my $language = CTX->request->param('lang') || CTX->request->param('language');
    $language ||= $event ? $self->_get_note( default_language => $event ) || '' : '';
    $language ||= $partner ? $self->_get_note( default_language => $partner ) || '' : '';

    # Clear cahce
    $self->_get_matchmaking_event_google_docs_user_data( $event, 1 );

    if ( ! CTX->request->param('no_mobile_forwards') ) {
        my $under_construction_back_url = Dicole::URL->get_server_url( 443 ) . $self->derive_full_url( add_params => { no_mobile_forwards => 1 } );
        my $message = '';
        if ( $event ) {
            $message = "Unfortunately " . $event->custom_name . " registration is not yet fully compliant with mobile devices. We advice you to register on a desktop computer. Once the registration is completed, everything should work on a mobile device as well. Thank you for your patience.";
        }

        $self->_redirect_for_mobile_with_params( { under_construction_url => $under_construction_back_url, under_construction_message => $message } );
    }

    if ( CTX->request->auth_user_id && $event && $self->_get_note( prefill_profile_data_csv_url => $event ) ) {
        if ( CTX->request->auth_user->email ) {
            if ( ( ! $email ) || ( lc( $email ) eq lc( CTX->request->auth_user->email ) ) ) {
                my $data = $self->_get_matchmaking_event_google_docs_user_data( $event );
                my $profile_values = $data->{ lc( CTX->request->auth_user->email ) };
                if ( $profile_values ) {
                    # TODO: profile values could somehow be filled here..
                    return $self->redirect( $self->_get_meet_me_config_abs( $event_id ) );
                }
            }
        }

        # TODO: derive_full_url is buggy and does not apply event param to additional correctly. that's why i force it here
        return $self->redirect( $self->derive_url( action => "xlogout", task => "logout", additional => [], params => { url_after_logout => $self->derive_full_url( additional => [ $event_id ? ( $event_id ) : () ] ) } ) );
    }

    if ( CTX->request->auth_user_id && CTX->request->auth_user->email ) {
        if ( $meet_me_url ) {
            my $old_url = $self->_fetch_user_matchmaker_fragment_object( CTX->request->auth_user );
            if ( ! $old_url ) {
                $self->_set_user_matchmaker_url( CTX->request->auth_user, $domain_id, $meet_me_url );
            }
            else {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_nmsg('You already have an active meet me url and it was not changed.') );
            }
        }

        return $self->redirect( $self->_get_meet_me_config_abs( $event_id ) );
    }
    else {
        my $user = CTX->request->auth_user_id ? CTX->request->auth_user : $self->_create_temporary_user( $domain_id, $language );

        if ( CTX->request->auth_user_id && $language ) {
            $user->language( $language );
        }

        $self->_set_note_for_user( created_for_matchmaking_event_id => $event_id, $user, $domain_id, { skip_save => 1 } ) if $event_id;
        $self->_set_note_for_user( created_by_partner => $self->param('partner_id'), $user, $domain_id, { skip_save => 1 } ) if $self->param('partner_id');
        # $self->_user_accept_tos( $user, $domain_id, 'skip_save' );
        $user->save;

        $self->_set_user_matchmaker_url( $user, $domain_id, $meet_me_url );

        return $self->redirect( $self->derive_url( task => 'wizard_profile', additional => [ $event_id || () ], params => {
            ( CTX->request->auth_user_id ? () : ( dic => Dicole::Utils::User->temporary_authorization_key( $user ) ) ),
            ( CTX->request->param('email') ? ( email => CTX->request->param('email') ) : () ),
        } ) );
    }
}

sub wizard_profile {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    $self->_redirect_to_hide_url_authentication;

    my $event_id = $self->param('matchmaking_event_id');
    my $event = $event_id ? $self->_ensure_matchmaking_event_object( $event_id ) : undef;

    if ( CTX->request->param( 'email' ) && $event && $self->_get_note( prefill_profile_data_csv_url => $event ) ) {
        my $data = $self->_get_matchmaking_event_google_docs_user_data( $event );

        my $profile_values = CTX->request->param( 'email' ) ? $data->{ lc( CTX->request->param( 'email' ) ) } : undef;

        if ( ! $profile_values ) {
            $globals->{meetings_email_not_found_params} = {
                user_email => CTX->request->param( 'email' ),
                contact_email => $event->organizer_email,
                event_name => $event->custom_name,
                event_website => $event->organizer_url,
            };

            $self->_set_controller_variables( $globals, 'Confirming attendance' );
            return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
        }
    }

    return $self->_full_cookie_forward if CTX->request->param( 'open_profile' );
    return $self->_full_cookie_forward if CTX->request->param( 'email' );

    my $email = $self->_expire_cookie_parameter_and_return_value( 'email' );
    my $open_profile = $self->_expire_cookie_parameter_and_return_value( 'open_profile' );

    if ( CTX->request->auth_user->email ) {
        return $self->redirect( $self->_get_meet_me_config_abs( $event_id ) );
    }

    my $profile_values = {};

    if ( $event && $self->_get_note( prefill_profile_data_csv_url => $event ) ) {
        my $data = $self->_get_matchmaking_event_google_docs_user_data( $event );
        $profile_values = $data->{ lc( $email ) };
        if ( ! $profile_values ) {
            $globals->{meetings_email_not_found_params} = {
                user_email => $email,
                contact_email => $event->organizer_email,
                event_name => $event->custom_name,
                event_website => $event->organizer_url,
            };
        }
        else {
            $open_profile = 1;
        }
    }

    if ( $email ) {
        $profile_values->{email} = $email;
    }

    my $google_return_url = $self->derive_url( params => { open_profile => 1, email => $email || '' } );
    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    $globals = {
        %$globals,
        meetings_time_zone_data => {
            choices => $timezone_choices,
            data => $timezone_data,
        },
        meetings_open_profile => $open_profile ? 1 : 0,
        meetings_suggest_profile_values => $profile_values,
        meetings_force_email => ( $event && $self->_get_note( prefill_profile_data_csv_url => $event ) ) ? $email : '',
        meetings_event_id => $event_id || 0,
        meetings_page_load_time => time(),
        meetings_save_profile_url => $self->derive_url(
            action => 'meetings_json', task => 'confirm_new_user_meet_me_profile', target => 0, additional => []
        ),
        meetings_google_connect_url => $self->derive_url(
            action => 'meetings_global', task => 'google_start_2', params => {
                return_url => $google_return_url,
                require_refresh_token => 1
            }
        ),
    };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Provide your details' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub wizard_apps {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
    };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Get our apps' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub upgrade {
    my ( $self ) = @_;

    $self->_redirect_unless_https;

    my $globals = {};
    my $params = {};

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
        meetings_time_zone_data => {
            choices => $timezone_choices,
            data => $timezone_data,
        },
    };

    if ( my $lang = CTX->request->param('lang') ) {
        $self->language( $lang );
    }

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Buy Meetin.gs PRO' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}


sub user {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
        meetings_time_zone_data => {
            choices => $timezone_choices,
            data => $timezone_data,
        },
    };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'User settings' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub thank_you {
    my ( $self ) = @_;
    my $globals = {};
    my $params = {
        create => CTX->request->param('create') ? 1 : 0,
        email => CTX->request->param('email'),
    };

    if ( CTX->request->param('mobile') ) {
        my $u = URI->new('http://m.meetin.gs/thank_you.html');
        $u->query_form( %$params );
        return $self->redirect( $u->as_string );
    }

    $self->_redirect_unless_http;

    $self->_set_controller_variables( $globals,  CTX->request->param('create') ?
        $self->_nmsg( 'Please check your email to continue' ) :
        $self->_nmsg( 'Thank you for signing up' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_thank_you' } );
}

sub already_a_user {
    my ( $self ) = @_;

    my $email = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );
    my $base_group_id = $self->_determine_user_base_group( $user );

    my $url = CTX->request->param('signup') ?
        Dicole::URL->get_domain_url( $domain_id, 443 ) . Dicole::URL->from_parts(
            action => 'meetings_global', task => 'detect', domain_id => $domain_id, target => $base_group_id,
        )
        :
        Dicole::URL->get_domain_url( $domain_id, 443 ) . Dicole::URL->from_parts(
            action => 'meetings', task => 'new_meeting', domain_id => $domain_id, target => $base_group_id,
        );

    $self->_send_secure_login_link( $url, $user );

    my $globals = {};

    my $params = {
        email => $email,
    };

    if ( CTX->request->param('mobile') ) {
        my $u = URI->new('http://m.meetin.gs/already_a_user.html');
        $u->query_form( %$params );
        return $self->redirect( $u->as_string );
    }

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Welcome back' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_already_a_user' } );
}

sub new_invited_user {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $event = $self->_get_valid_event;

    my $po = $self->_fetch_meeting_participant_object_for_user( $event, $user );
    my $inviter_id = $po->creator_id || $event->creator_id || $user->id;
    my $inviting_user = Dicole::Utils::User->ensure_object( $inviter_id );
    my $inviting_user_info = $self->_gather_user_info( $inviting_user );

    my $globals = {
        meetings_invite_transfer_url => $self->derive_url( action => 'meetings_json', task => 'invite_transfer' ),
    };
    my $params = {
        proceed_to_meeting => 1,
        invited => 1,
        invited_by_name => $inviting_user_info->{name},
        invited_by_image => $inviting_user_info->{image},
        meeting_title => $self->_meeting_title_string( $event ),
        user_email => $user->email,

        url_after_save => $self->derive_full_url( task => 'meeting', additional => [ $event->id ] ),
    };

    return $self->_new_user( $globals, $params, $event );
}

sub new_user {
    my ( $self ) = @_;

    my $event_id = $self->param('event_id');
    my $event = $event_id ? $self->_get_valid_event : undef;

    my $globals = {};
    my $params = {
        proceed_to_meeting => $event ? 1 : 0,
        url_after_save => $event ? $self->derive_full_url( task => 'meeting', additional => [ $event->id ] ) : $self->derive_url( action => 'meetings_global', task => 'detect', additional => [] ),
    };

    return $self->_new_user( $globals, $params, $event );
}

sub _new_user {
    my ( $self, $globals, $params, $event ) = @_;

    my $creator_user = ( $event && $event->creator_id ) ? Dicole::Utils::User->ensure_object( $event->creator_id ) : undef;

    my $tz_info = Dicole::Utils::Date->timezone_info( $self->_determine_timezone );

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    $globals = {
        %$globals,
        meetings_new_user_url => $self->derive_url( action => 'meetings_json', task => 'edit_my_profile', additional => [] ),
        meetings_page_load_time => time(),
        meetings_user_timezone_fallback_name => $tz_info->{name},
        meetings_user_timezone_offset_value => $tz_info->{offset_value},
        meetings_weekday_names => [ qw/Sun Mon Tue Wed Thu Fri Sat/ ],
        meetings_timezone_choices => $timezone_choices,
        meetings_timezone_data => $timezone_data,
    };

    my $user = CTX->request->auth_user;
    my $old_attributes = CTX->lookup_action('networking_api')->e(user_profile_attributes => {
        user_id => $user->id,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        attributes => {
            contact_skype => undef,
            contact_phone => undef,
            contact_organization => undef,
            contact_title => undef,
            personal_linkedin => undef,
        }
    });

    my $creating_partners = $self->_fetch_allowed_partners_for_user( $user );
    my @partner_names = map { $_->name } @$creating_partners;
    my $partner_name = join " and ", @partner_names;

    $params = {
        %$params,
        first_name => $user->first_name,
        last_name => $user->last_name,
        ask_for_tos => $self->_user_has_accepted_tos( $user ) ? 0 : 1,
        confirm_partner_right_to_log_in => $partner_name,

        skype => $old_attributes->{contact_skype},
        phone => $old_attributes->{contact_phone},
        organization => $old_attributes->{contact_organization},
        organization_title =>  $old_attributes->{contact_title},
        linkedin => $old_attributes->{personal_linkedin},
    };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Welcome to Meetin.gs' ), $event, $creator_user );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_new_user' } );
}

sub privacy_policy {
    my ( $self ) = @_;
    return $self->redirect('http://www.meetin.gs/privacy/');
}

sub terms_of_service {
    my ( $self ) = @_;
    return $self->redirect('http://www.meetin.gs/terms-of-service/');
}

sub takedown_policy {
    my ( $self ) = @_;
    return $self->redirect('http://www.meetin.gs/takedown-policy/');
}

sub user_new_meeting {
    my ( $self ) = @_;
    return $self->_new_meeting;
}

sub new_meeting {
    my ( $self ) = @_;
    return $self->_new_meeting;
}

sub _new_meeting {
    my ( $self ) = @_;

    $self->_redirect_to_hide_url_authentication;

    my $uid = CTX->request->auth_user_id;

    return $self->redirect( $self->derive_url( task => 'create', additional => [], params => { title => CTX->request->param('topic'), %{ $self->_get_current_utm_params } } ) ) if $uid;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( my $email = CTX->request->param('email') ) {
        my $user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );
        if ( $user && $self->_user_has_accepted_tos( $user, $domain_id ) ) {
            return $self->redirect( $self->derive_url( action => 'meetings', task => 'already_a_user', additional => [], params => { email => $email, mobile => CTX->request->param('mobile') } ) );
        }
        elsif ( CTX->request->param('mobile') ) {
            my $u = URI->new('http://m.meetin.gs/create.html');
            $u->query_form( email => $email );
            return $self->redirect( $u->as_string );
        }
    }

    die "security error";
}

sub analytics {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    my $params = {};

    my $globals = {
        meetings_stats =>$self->_fetch_or_calculate_user_analytics( $user, $domain_id )
    };

    for my $notification ( keys %{ $self->NOTIFICATION_MAP } ) {
        $params->{ $notification . '_requested' } = $self->_notification_requested_for_user( $notification, CTX->request->auth_user ) ? 1 : 0;
    }

    my $base_group_id = $self->_determine_user_base_group( $user->id );

	if ( $base_group_id ) {

        $self->_set_controller_variables( $globals, $self->_nmsg( 'Analytics' ) );

    	return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_analytics' } );
	}
	else {
		 die "security error";
	}
}



sub logout {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id ) {
        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) );
    }

    if ( my $p = $self->param('partner') ) {
        if ( my $custom_logout_url = $self->_get_note( custom_logout_url => $p ) ) {
            die $self->redirect( $custom_logout_url );
        }
    }

    my $globals = {};
    my $params = {};

    if ( my $lang = CTX->request->param('lang') ) {
        $self->language( $lang );
    }

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Logout' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_logout' } );
}

sub signup {
    my ( $self ) = @_;


    # "This is not supposed to be used anymore";
    return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) );

    if ( CTX->request->param('dic') ) {
        return $self->redirect( Dicole::URL->strip_auth_from_current );
    }

    my $uid = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "security error" unless $uid;

    if ( $self->_determine_user_base_group( $uid ) ) {
        return $self->redirect( $self->derive_url( task => 'summary') );
    }

    my $invited = $self->_get_note_for_user( 'meetings_invited_to_beta_by' );

    die "security error" unless $invited && scalar( @$invited );

    if ( CTX->request->param('accept') ) {
        my $group = CTX->lookup_action('groups_api')->e( add_group => {
            name => Dicole::Utils::User->name( CTX->request->auth_user ),
            creator_id => $uid,
        } );

        $self->_set_note_for_user( 'meetings_base_group_id', $group->id );
        $self->_set_note_for_user( 'meetings_total_beta_invites', 3 );

        $self->_send_themed_mail(
            user => $user,
            domain_id => $domain_id,

            template_key_base => 'meetings_beta_notify',
            template_params => {
                login_url => $self->_form_user_create_meetings_url( $user, $domain_id ),
                user_name => Dicole::Utils::User->first_name( $user ),
                sent_to_email => $user->email,
            },
        );

        return $self->redirect( $self->derive_url( task => 'summary', params => { welcome => 1 } ) );
    }

    my $globals = {};
    my $params = {};

    my $inviter = CTX->request->param('invited_by');
    my %valid_inviter_map = map { $_ => 1 } @$invited;
    if ( ! $valid_inviter_map{ $inviter } ) {
        $inviter = pop @$invited;
    }
    my $inviter_user = ( $inviter > 0 ) ? eval { Dicole::Utils::User->ensure_object( $inviter ) } : undef;
    $params->{invited_by} = Dicole::Utils::User->name( $inviter_user ) if $inviter_user;

    if ( $user && ! $self->_user_profile_is_filled( $user ) ) {
        $globals = {
            %{ $globals },
            meetings_invite_transfer_url => $self->derive_url( action => 'meetings_json', task => 'invite_beta_transfer' ),
            meetings_accept_beta_url => CTX->controller->initial_action->derive_url( action => 'meetings_json', task => 'edit_my_profile', additional => [] ),
            meetings_accept_beta_url_after_post => $self->derive_url( params => { 'accept' => 1 } ),
        };
        $params->{accept_beta_data_url} = $self->derive_url( action => 'meetings_json', task => 'get_my_profile' );
    }
    else {
        $params->{accept_beta_url} =  $self->derive_url( params => { 'accept' => 1 } );
    }

    $self->_set_controller_variables( $globals, 'Beta signup' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_signup' } );
}

sub verify_email {
    my ( $self ) = @_;

    # Logout and pass email address to template

    my $globals = {};
    my $params = {
        join_accounts => CTX->request->param('join_accounts') || '',
        meet_me => CTX->request->param('meet_me') || '',
        email => CTX->request->param('email') || '',
    };
    $self->_set_controller_variables( $globals, $self->_nmsg( 'Check your inbox' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_verify_email' } );
}

sub validate_event_matchmaker {
    my ( $self ) = @_;

    my $globals = {
        meetings_show_matchmaking_validate => 1,
        meetings_user_email => CTX->request->param('email')
    };

    my $params = {};

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Check your inbox' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_validate_event_matchmaker' } );
}

sub event_matchmaker_validated {
    my ( $self ) = @_;

    my $matchmaker_id = $self->param('matchmaker_id');

    my $mmr = CTX->lookup_object('meetings_matchmaker')->fetch( $matchmaker_id );

    my $mm_event_id = $mmr->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    if ( $mmr && $mmr->creator_id == CTX->request->auth_user_id && ! $mmr->validated_date ) {
        $mmr->validated_date( time );
        $mmr->save;

        my $user = CTX->request->auth_user;
        my $domain_id = Dicole::Utils::Domain->guess_current_id;

        my $name = $mm_event ? $mm_event->custom_name : '';
        $name ||= 'matchmaking';

        my $partner = $self->param('partner');
        my $host = $partner ? $self->_get_host_for_partner( $partner, 443 ) : $self->_get_host_for_user( $user, $domain_id, 443 );
        my $edit_url = $self->_generate_authorized_uri_for_user(
            $host . $self->derive_url( action => 'meetings', task => 'matchmaking_admin_editor', additional => [ $mmr->id ] ),
            $user,
            $domain_id
        );

        $self->_send_partner_themed_mail(
            user => $user,
            domain_id => Dicole::Utils::Domain->guess_current_id,
            partner_id => $self->param('partner_id'),
            group_id => 0,

            template_key_base => 'meetings_event_matchmaker_confirmed',
            template_params => {
                user_name => Dicole::Utils::User->name( $user ),
                event_name => $name,
                organizer_email => $mm_event ? $mm_event->organizer_email : 'info@meetin.gs',
                matchmaker_company => $mmr->name,
                matchmaker_description => $mmr->description,
                edit_matchmaking_info_url => $edit_url,
            },
        );
    }
    elsif ( ! $mmr || $mmr->creator_id != CTX->request->auth_user_id ) {
        die "security error";
    }

    my $globals = {
        meetings_show_matchmaking_register_success => 1,
        meetings_organizer_url => $mm_event ? $mm_event->organizer_url : '/',
        meetings_organizer_email => $mm_event ? $mm_event->organizer_email : 'info@meetin.gs',
    };

    my $params = {};

    $self->_set_controller_variables( $globals, 'Thank you for registering' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_event_matchmaker_validated' } );
}

sub account_forwarded {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $user = CTX->request->auth_user;
    my $target_user = $self->_fetch_or_create_user_for_email( $user->email );

    if ( $user->email eq $target_user->email ) {
        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) );
    }

    if ( CTX->request->param('recover') ) {
        $self->_remove_email_from_user( $user->email, $target_user );
        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) );
    }

    my $globals = {};
    my $params = {
        name => Dicole::Utils::User->name( $user ),
        target_email => $target_user->email,
        recover_url => $self->derive_url( params => { 'recover' => 1 } ),
    };
    $self->_set_controller_variables( $globals, $self->_nmsg( 'Account forwarded' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_account_forwarded' } );
}

sub agent_booking {
    my ( $self ) = @_;

    Dicole::MessageHandler->add_message( MESSAGE_ERROR, "Järjestelmä on irtisanottu ja suljetaan asiakkailta 24.01.2020. Lähixcustxzn sisäiset ominaisuudet on suljettu pois käytöstä." );

    return $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', target => 0, additional => [] ) );

    $self->_redirect_unless_https;
    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    my $types = $self->_get_partner_agent_booking_types( $self->param('partner_id') );

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
        meetings_agent_matchmaker_types => $types,
    };

    $self->_set_controller_variables( $globals, 'Varauskalenteri' || 'localize' || $self->_nmsg( 'Agent Booking' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub agent_absences {
    my ( $self ) = @_;

    Dicole::MessageHandler->add_message( MESSAGE_ERROR, "Järjestelmä on irtisanottu ja suljetaan asiakkailta 24.01.2020. Lähixcustxzn sisäiset ominaisuudet on suljettu pois käytöstä." );

    return $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', target => 0, additional => [] ) );
    return $self->_render_404;

    $self->_redirect_unless_https;
    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
    };

    $self->_set_controller_variables( $globals, 'Poissaolot' || 'localize' ||$self->_nmsg( 'Agent Absences' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub agent_manage {
    my ( $self ) = @_;

    Dicole::MessageHandler->add_message( MESSAGE_ERROR, "Järjestelmä on irtisanottu ja suljetaan asiakkailta 24.01.2020. Lähixcustxzn sisäiset ominaisuudet on suljettu pois käytöstä." );

    return $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', target => 0, additional => [] ) );
    return $self->_render_404;

    $self->_redirect_unless_https;
    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
    };

    $self->_set_controller_variables( $globals, 'Tapaamisten hallinta' || 'localize' ||$self->_nmsg( 'Meeting management' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub agent_admin {
    my ( $self ) = @_;

    Dicole::MessageHandler->add_message( MESSAGE_ERROR, "Järjestelmä on irtisanottu ja suljetaan asiakkailta 24.01.2020. Lähixcustxzn sisäiset ominaisuudet on suljettu pois käytöstä." );

    return $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', target => 0, additional => [] ) );
    return $self->_render_404;

    $self->_redirect_unless_https;
    die "security error" unless CTX->request->auth_user_id;

    my $globals = {};
    my $params = {};

    $globals = {
        %$globals,
        meetings_page_load_time => time(),
    };

    $self->_set_controller_variables( $globals, 'Käyttäjähallinta' || 'localize' ||$self->_nmsg( 'Agent administration' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_backbone_skeleton' } );
}

sub summary {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    if ( ! $user->email ) {
        my $meetings = $self->_get_user_meetings_in_domain( $user, $domain_id );
        if ( ! @$meetings ) {
            return $self->redirect( $self->derive_url( action => "xlogout", task => "logout", additional => [], params => { url_after_logout => '/meetings/wizard/' } ) );
        }
        else {
            my $meeting = pop @$meetings;
            return $self->redirect( $self->derive_url( task => 'meeting', additional => [ $meeting->id ], target => $meeting->group_id ) );
        }
    }

    my @pass_params = ( qw(
        open_language_selector
        open_promo_subscribe
        show_calendar_connect
    ) );

    for my $pass_param ( @pass_params ) {
        if ( CTX->request->param( $pass_param ) ) {
            return $self->_full_cookie_forward;
        }
    }

    $self->_redirect_to_auth_path_for_mobile;
    $self->_redirect_to_hide_url_authentication;
    $self->_redirect_unless_https;

    my $base_group_id = $self->_determine_user_base_group;

    if ( $base_group_id ) {
        unless ( $self->param('target_group_id') == $base_group_id ) {
            return $self->redirect( $self->derive_url( target => $base_group_id, additional => [] ) );
        }
    }


    if ( $user && ! $self->_user_has_accepted_tos( $user, $domain_id ) ) {
        return $self->redirect( $self->derive_url( task => 'new_user' ) );
    }

    Dicole::Utils::Gearman->dispatch_versioned_task( prime_user_upcoming_meeting_suggestions => { user_id => $user->id } );

    my $pro = $self->_user_is_pro( $user );

    my $globals = {};
    my $params = {};

    my $bookmarklet_url = $self->_get_host_for_user( CTX->request->auth_user, $domain_id, 443 ) . $self->derive_url(
        action => 'meetings', task => 'new_meeting', target => 0, additional => [ Dicole::Utils::User->identification_key( CTX->request->auth_user ) ],
    );

    my $invited = $base_group_id ? undef : $self->_get_note_for_user( 'meetings_invited_to_beta_by' );

    my $google_return_url = $self->derive_url( params => { show_calendar_connect => 1 } );

    $globals = {
        %$globals,
        meetings_google_connected => $self->_user_has_connected_google( CTX->request->auth_user ) ? 1 : 0,
        meetings_google_connect_url => $self->derive_url( action => 'meetings_global', task => 'google_start_2', params => { return_url => $google_return_url, require_refresh_token => 1 } ),

        meetings_resend_invite_url => $self->derive_url( action => 'meetings_json', task => 'resend_invite', additional => [] ),
        meetings_remove_participant_url => $self->derive_url( action => 'meetings_json', task => 'remove_participant', additional => [] ),
        meetings_get_info_url => $self->derive_url( action => 'meetings_json', task => 'get_meeting_info' ),
        meetings_show_new_meeting => $base_group_id ? 1 : 0,
        meetings_initial_title_value => CTX->request->param('title') || '',
            meetings_current_user_login_link_email_url => $self->derive_url( action => 'meetings_json', task => 'email_current_user_login_link' ),
    };

    my $refresh_params = {};

    for my $cp ( @pass_params ) {
        if ( my $value = $self->_expire_cookie_parameter_and_return_value( $cp ) ) {
            $refresh_params->{$cp} = $value;
            $globals->{ "meetings_" . $cp } = $value;

        }
        else {
            delete $globals->{ "meetings_" . $cp };
        }
    }

    $globals->{meetings_timezone_data_url} = $self->derive_url( action => 'meetings_json', task => 'timezone_data'),;
    $globals->{meetings_timezone_confirm_url} = $self->derive_url( action => 'meetings_json', task => 'confirm_timezone'),;
    $globals->{meetings_timezone_confirm_redirect} = $self->_get_cookie_param_abs( $self->derive_full_url( add_params => $refresh_params ) );
    $globals->{meetings_dismissed_timezones} = $self->_user_dismissed_timezones_list( $user, $domain_id );

    $params = {
        %$params,
        ical_url => $self->derive_url( action => 'meetings_json', task => 'calendar_data', additional => [] ),
        bookmarklet_url => $base_group_id ? $bookmarklet_url . '/' : '',
        beta_invite_url => $base_group_id ? $self->derive_url( action => 'meetings_json', task => 'admin_invites', additional => [] ) : '',
        accept_beta_url => ( $invited && scalar ( @$invited ) ) ? $self->derive_url( task => 'signup' ) : '',
    };

    $self->_set_controller_variables( $globals, $self->_nmsg( 'Timeline' ) );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_summary' } );
}

sub create {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $partner = $self->param('partner');
    my $partner_id = ( $partner && $self->_user_can_create_meeting_for_partner( $user, $partner ) ) ? $partner->id : 0;

    my $initial_agenda = Dicole::Utils::HTML->text_to_phtml( CTX->request->param('initial_agenda') );

    my $event = CTX->lookup_action('meetings_api')->e( create => {
        creator => $user,
        partner_id => $partner_id,
        title => CTX->request->param('title'),
        location => CTX->request->param('location'),
        begin_epoch => CTX->request->param('begin_epoch'),
        end_epoch => CTX->request->param('end_epoch'),
        initial_agenda => $initial_agenda,
        initial_participants => CTX->request->param('initial_participants'),
        disable_create_email => 1,
    });

    $self->_set_note_for_meeting( meeting_helpers_shown => 1, $event ) if CTX->request->param('disable_helpers');

    return $self->redirect( $self->_get_meeting_abs( $event, $self->_get_current_utm_params ) );
}

sub activate_suggestion {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $self->param('suggestion_id') );
    die "cound not find suggestion" unless $suggestion && $suggestion->user_id == $user->id;

    my $partner = $self->param('partner');
    my $partner_id = ( $partner && $self->_user_can_create_meeting_for_partner( $user, $partner ) ) ? $partner->id : 0;

    my $meeting = CTX->lookup_action('meetings_api')->e( activate_suggestion => {
        suggestion => $suggestion,
        partner_id => $partner_id,
        disable_create_email => 1,
    });


    return $self->redirect( $self->_get_meeting_abs( $meeting, $self->_get_current_utm_params ) );
}

sub create_followup {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $old_meeting = eval { $self->_get_valid_event };

    my $partner = $self->param('partner');
    my $partner_id = ( $partner && $self->_user_can_create_meeting_for_partner( $user, $partner ) ) ? $partner->id : 0;

    my $old_pages ||= $self->_events_api( gather_pages_data => { event => $old_meeting } );

    my $agenda = '';
    my $agenda_page = $self->_fetch_meeting_agenda_page( $old_meeting, $old_pages );
    my $agenda_content = eval { $agenda_page->last_content_id_wiki_content->content };

    my $action_points_page = $self->_fetch_meeting_action_points_page( $old_meeting, $old_pages );
    my $action_points_content = eval { $action_points_page->last_content_id_wiki_content->content };

    if ( $agenda_content ) {
        $agenda = 'Here are the contents of the previous agenda for you to edit.';
        $agenda .= ' Previous action points can be found from the materials.';
        $agenda = '<p>' . $agenda . '</p>' . $agenda_content;
    }

    my $meeting = CTX->lookup_action('meetings_api')->e( create => {
        creator => $user,
        partner_id => $partner_id,
        online_conferencing_option => $self->_get_note( online_conferencing_option => $old_meeting ),
        online_conferencing_data => $self->_get_note( online_conferencing_data => $old_meeting ),
        skype_account => $self->_get_note( skype_account => $old_meeting ),
        title => $old_meeting->title ? ( $old_meeting->title . ' (follow-up)' ) : '',
        location => $old_meeting->location_name,
        initial_agenda => $agenda,
        disable_create_email => 1,

        disable_helpers => 1,
    });

    $self->_set_note_for_meeting( 'followup_meeting_id', $meeting->id, $old_meeting );

    $self->_set_note_for_meeting( show_followup_helpers => 1, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( 'previous_meeting_id', $old_meeting->id, $meeting );

    my $old_event_pos = $self->_fetch_meeting_participation_objects( $old_meeting );
    for my $po ( @$old_event_pos ) {
        next if $po->user_id == $user->id;
        my $dpo = $self->_add_meeting_draft_participant( $meeting, { user_id => $po->user_id, is_hidden => $self->_get_note( is_hidden => $po ) }, $user );
    }

    if ( $action_points_content ) {
        $self->_copy_material_from_meeting_to_meeting_by_user(
            $action_points_page->id, 'page', $old_meeting, $meeting, $user,
            { skip_event => 1, override_name => 'Previous Action Points', override_created_date => time + 2 }
        );
    }

    my $material_data_params = $self->_gather_material_data_params( $old_meeting );

    my $material_time_index = 3;

    for my $data ( @{ $material_data_params->{materials} } ) {
        my $type = $data->{fetch_type};
        my $id = $data->{page_id} || $data->{prese_id};

        if ( lc( $type ) eq 'page' ) {
            next if $agenda_page && $agenda_page->id == $id;
            next if $action_points_page && $action_points_page->id == $id;
            next if $data->{title} && $data->{title} =~ /Previous Action Points/i;
        }

        $self->_copy_material_from_meeting_to_meeting_by_user(
            $id, $type, $old_meeting, $meeting, $user,
            { skip_event => 1, override_created_date => time + $material_time_index++ }
        );
    }

    return $self->redirect( $self->_get_meeting_abs( $meeting, $self->_get_current_utm_params ) );
}

sub meeting {
    my ( $self ) = @_;

    my $event = eval { $self->_get_valid_event };

    if ( $@ || ! $event ) {
        return if $@ =~ /redirect/;

        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_nmsg('The requested meeting could not be found. It might have been removed.') );

        return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect', target => 0, additional => [] ) );
    }

    if ( CTX->request->param('selected_material_url') ) {
        OpenInteract2::Cookie->create( {
            name => 'meetings_selected_material_url',
            path => '/',
            value => CTX->request->param('selected_material_url'),
            HEADER => 'YES',
        } );

        return $self->redirect( Dicole::URL->strip_param_from_current( 'selected_material_url' ) );
    }

    if ( my $msg = CTX->request->param('message_success') ) {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $msg );
    }

    my $is_secure = $self->_meeting_is_sponsored( $event );

    $self->_redirect_unless_https;

    die "security error" unless $self->_events_api( current_user_can_see_event => { event => $event } );

    my $uid = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $base_gid = $self->_determine_user_base_group( $uid );
    my $pro = $user ? $self->_user_is_pro( $user ) : 0;

    my $eus =  $self->_events_api( event_users_link_list => { event => $event } );
    my %lookup = map { $_->user_id => $_ } @$eus;
    my $rsvp = $lookup{ CTX->request->auth_user_id };

    die "security error" unless $rsvp;

    if ( my $rsvp_response = CTX->request->param('rsvp') ) {
        my $old = $self->_get_note_for_meeting_user( 'rsvp', $event, $user, $rsvp ) || '';

        $rsvp_response = '' unless grep { $rsvp_response eq $_ } ( qw( yes no maybe ) );
        $self->_set_note_for_meeting_user( 'rsvp', $rsvp_response, $event, $user, $rsvp, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( 'last_rsvp_replied', time, $event, $user, $rsvp );
        $self->_store_participant_event( $event, $rsvp, 'rsvp_changed' );

        if ( $rsvp_response eq 'yes' && $old ne 'yes' ) {
            $self->_send_meeting_ical_request_mail( $event, $user, { type => 'rsvp' } );
        }

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $rsvp_response eq 'no' ?
            $self->_nmsg('You are now "Not Attending".' )
            :
            $self->_nmsg('You are now "Attending".' )
        ) if $rsvp_response;

        return $self->redirect( Dicole::URL->strip_param_from_current( 'rsvp' ) );
    }


    my $is_admin = $self->_user_can_manage_meeting( $user, $event );
    my $creator_user = $event->creator_id ? Dicole::Utils::User->ensure_object( $event->creator_id ) : undef;

    if ( my $email = CTX->request->param('invite_email') ) {
        if ( $is_admin ) {
            my $email_user = $self->_fetch_or_create_user_for_email( $email, $event->domain_id );
            my $po = $self->_add_user_to_meeting( $email_user, $event, $user, 0 );

            $self->_store_participant_event( $event, $po, 'created', { author => $user ? $user->id : 0 } );
            $self->_send_meeting_invite_mail_to_user(
                from_user => $user,
                user => $email_user,
                event => $event,
            );

            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('%1$s invited succesfully', [ Dicole::Utils::User->name( $email_user ) ] ) );
        }
        return $self->redirect( Dicole::URL->strip_param_from_current( 'invite_email' ) );
    }

    $self->_redirect_to_auth_path_for_mobile( $event );

    if ( my $meeting_cancel_request = CTX->request->param('meeting_cancel_request') ) {
        my $meeting_has_ended = ( $event->begin_date && $event->end_date && time > $event->end_date ) ? 1 : 0;

        if ( $meeting_has_ended ) {
            if ( $self->_get_note( allow_meeting_reschedule => $event ) ) {
                return $self->_full_cookie_forward( { meeting_reschedule_open => 1 } );
            }
            # TODO: maybe change this some day when both are supported
            if ( $self->_get_note( allow_meeting_cancel => $event ) ) {
                return $self->_full_cookie_forward( { meeting_reschedule_open => 1 } );
            }
        }
    }

    if ( my $matchmaking_response = CTX->request->param('matchmaking_response') ) {
        if ( $matchmaking_response eq 'accept' ) {
            return $self->_full_cookie_forward( { matchmaking_accept_open => 1 }, { matchmaking_response => 1 } );
        }
        elsif ( $matchmaking_response eq 'decline' ) {
            return $self->_full_cookie_forward( { matchmaking_decline_open => 1 }, { matchmaking_response => 1 } );
        }
        return $self->redirect( Dicole::URL->strip_param_from_current( 'matchmaking_response' ) );
    }

    $self->_redirect_to_hide_url_authentication;

    $self->_set_note_for_meeting_user( 'last_page_loaded', time, $event, $user, $rsvp );

    if ( $user && ! $self->_user_has_accepted_tos( $user, $domain_id ) ) {
        my $invited = ( $rsvp->creator_id && $rsvp->creator_id != $uid ) ? 1 : 0;
        return $self->redirect( $self->derive_full_url( task => $invited ? 'new_invited_user' : 'new_user' ) );
    }

    my $globals = {};

    my $template_chooser_shown = $self->_get_note_for_meeting( meeting_helpers_shown => $event );
    $globals->{meetings_template_chooser_url} = $self->derive_url(action => 'meetings_json', task => 'set_meeting_helpers_shown') unless $template_chooser_shown;

    if ( $self->_get_note_for_meeting( show_followup_helpers => $event ) ) {
        $self->_set_note_for_meeting( show_followup_helpers => undef, $event );
        $globals->{meetings_show_followup_helpers} = 1;
     }

    my $refresh_params = {};

    for my $cp ( qw(
        open_meeting_chooser
        open_addressbook
        open_addressbook_with_guiders
        open_scheduler
        meeting_cancel_open
        meeting_reschedule_open
        matchmaking_decline_open
        matchmaking_accept_open
    ) ) {
        if ( my $value = $self->_expire_cookie_parameter_and_return_value( $cp ) ) {
            $globals->{ "meetings_" . $cp } = 1;
            $refresh_params->{ $cp } = $value;
        }
    }

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
            object => $event,
            group_id => $event->group_id,
            user_id => 0,
        } );

    my @dismiss_globals_urls = ();
    if ( $event->creator_id == CTX->request->auth_user_id ) {
        if ( ! $self->_get_note_for_user( 'meetings_admin_guide_dismissed' ) ) {
            push @dismiss_globals_urls, ( 'meetings_dismiss_admin_guide_url' => $self->derive_url(
                    action => 'meetings_json', task => 'dismiss_guide',
                    additional => [ 'admin_guide' ]
                ) );
        }
    }
    else{
        if ( ! $self->_get_note_for_user( 'meetings_new_user_guide_dismissed' ) ) {
            push @dismiss_globals_urls, ( 'meetings_dismiss_new_user_guide_url' => $self->derive_url(
                    action => 'meetings_json', task => 'dismiss_guide',
                    additional => [ 'new_user_guide' ]
                ) );
        }
    }

    my $open_suggestion_picker = $self->_get_note_for_meeting( open_suggestion_picker => $event );
    $self->_set_note_for_meeting( open_suggestion_picker => 0, $event ) if $open_suggestion_picker;

    my $email = $self->_get_meeting_email( $event, $domain_id );


    my $user_meetings_count = $self->_count_user_meetings_in_domain( $user );
    my $user_created_meetings_count = $self->_count_user_created_meetings_in_domain( $user );

    my $pos = $self->_fetch_meeting_proposals( $event );
    my $user_open_proposals = $self->_fetch_open_meeting_proposals_for_user( $event, $user, $rsvp, $pos );

    my $all_answered = 1;
    for my $euo ( @$eus ) {
        my $open = $self->_fetch_open_meeting_proposals_for_user( $event, $euo->user_id, $euo, $pos );
        $all_answered = 0 if scalar( @$open );
    }

    $globals->{meetings_open_scheduler} = 1 if scalar( @$user_open_proposals ) || ( $is_admin && scalar( @$pos ) && $all_answered );

    $globals->{meetings_timezone_data_url} = $self->derive_url( action => 'meetings_json', task => 'timezone_data'),;
    $globals->{meetings_timezone_confirm_url} = $self->derive_url( action => 'meetings_json', task => 'confirm_timezone');
    $globals->{meetings_timezone_confirm_redirect} = $self->_get_cookie_param_abs( $self->derive_full_url( add_params => $refresh_params ) );
    $globals->{meetings_dismissed_timezones} = $self->_user_dismissed_timezones_list( $user, $domain_id );

    my $live_conf_params = $self->_gather_meeting_live_conferencing_params( $event, $user );
    my %live_conf_globals = map { 'meetings_' . $_ => $live_conf_params->{$_} } keys %$live_conf_params;

    my $allow_followup = 1;
    if ( $self->_get_note_for_meeting( disable_followups => $event ) ) {
        $allow_followup = 0;
    }

    $globals = {
        %$globals,

        %live_conf_globals,

        # Urls for connecting social media accounts from addressbook
        meetings_connect_urls =>{
            ab_facebook => $self->derive_url( action => 'meetings_global', task => 'facebook_start',  target => 0, additional => [], params => { meeting_id => $event->id, return_cookie_param => 'open_addressbook', cancel_cookie_param => 'open_addressbook' } ),
            ab_google => $self->derive_url( action => 'meetings_global', task => 'google_start_2', target => 0, additional => [], params => { meeting_id => $event->id, return_cookie_param => 'open_addressbook', cancel_cookie_param => 'open_addressbook', require_refresh_token => 1 } ),
            ab_google_guiders => $self->derive_url( action => 'meetings_global', task => 'google_start_2', target => 0, additional => [], params => { meeting_id => $event->id, return_cookie_param => 'open_addressbook_with_guiders', cancel_cookie_param => 'open_addressbook_with_guiders', require_refresh_token => 1  } ),
            ab_linkedin => $self->derive_url( action => 'meetings_global', task => 'linkedin_start',  target => 0, additional => [], params => { meeting_id => $event->id, return_cookie_param => 'open_addressbook', cancel_cookie_param => 'open_addressbook' } ),
            mc_google => $self->derive_url( action => 'meetings_global', task => 'google_start_2', target => 0, additional => [], params => { meeting_id => $event->id, return_cookie_param => 'open_meeting_chooser', cancel_cookie_param => '', require_refresh_token => 1  } ),
        },
        $is_admin ? (
            $user->email ? ( meetings_draft_ready_data_url => $self->derive_url( action => 'meetings_json', task => 'draft_ready' ) ) :
                    ( meetings_temp_draft_ready_data_url => $self->derive_url( action => 'meetings_json', task => 'temp_draft_ready' ) ),
        ) : (),
        meetings_meeting_id => $event->id,
        meetings_meeting_matchmaker_id => eval { $self->_get_meeting_matchmaker( $event )->id } || 0,
        meetings_meeting_title => $self->_meeting_title_string( $event ),
        meetings_get_user_meetings_url => $self->derive_url( action => 'meetings_json', task => 'get_user_meetings', target => 0, additional => [] ),
        meetings_location_autocomplete_url => $self->derive_url( action => 'meetings_json', task => 'location_autocomplete_data'),

        meetings_set_meeting_helpers_shown_url => $self->derive_url( action => 'meetings_json', task => 'set_meeting_helpers_shown'),

        meetings_scheduler_comment_state_url => $self->derive_url( action => 'meetings_json', task => 'comment_state'),
        meetings_scheduler_comment_info_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_info'),
        meetings_scheduler_comment_add_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_add'),
        meetings_scheduler_comment_delete_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_delete'),
        meetings_scheduler_comment_edit_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_edit'),
        meetings_scheduler_comment_thread_id => $thread->id,

        meetings_scheduler_url => $self->derive_url( action => 'meetings_json', task => 'get_scheduling_info' ),
        meetings_scheduler_refresh_url => $self->derive_url( action => 'meetings_raw', task => 'cookie_forward', additional => [], params => { to => $self->derive_url( action => 'meetings', task => 'meeting', params => { open_scheduler => 1 } ) } ),

        meetings_scheduler_picker_url => $self->derive_url( action => 'meetings_json', task => 'save_proposals' ),
        meetings_scheduler_peek_url => $self->derive_url( action => 'meetings_json', task => 'scheduler_peek' ),
        meetings_scheduler_cancel_url => $self->derive_url( action => 'meetings_json', task => 'cancel_scheduling' ),
        meetings_check_proposals_url => $self->derive_url( action => 'meetings_json', task => 'check_proposals' ),
        meetings_save_proposals_url => $self->derive_url( action => 'meetings_json', task => 'save_proposals' ),
        meetings_answer_proposals_url => $self->derive_url( action => 'meetings_json', task => 'answer_proposals' ),
        meetings_choose_proposal_url => $self->derive_url( action => 'meetings_json', task => 'choose_proposal' ),
        meetings_choose_proposal_data_url => $self->derive_url( action => 'meetings_json', task => 'get_meeting_info' ),
        meetings_scheduler_cal_url => $self->derive_url( action => 'meetings_json', task => 'scheduler_cal'),
        meetings_scheduler_chat_url => $self->derive_url( action => 'meetings_json', task => 'chat_object_info'),
        meetings_add_material_from_draft_url => $self->derive_url( action => 'meetings_json', task => 'add_material_from_draft' ),
        meetings_add_material_embed_url => $self->derive_url( action => 'meetings_json', task => 'add_material_embed' ),
        meetings_add_material_wiki_url => $self->derive_url( action => 'meetings_json', task => 'add_material_wiki' ),
        meetings_add_material_previous_url => $self->derive_url( action => 'meetings_json', task => 'add_material_previous' ),
        meetings_get_material_list_url => $self->derive_url( action => 'meetings_json', task => 'meeting_material_data' ),
        meetings_edit_media_embed_url => $self->derive_url( action => 'meetings_json', task => 'edit_media_embed' ),
        meetings_rename_media_url => $self->derive_url( action => 'meetings_json', task => 'rename_media' ),
        meetings_replace_media_url => $self->derive_url( action => 'meetings_json', task => 'replace_media' ),
        meetings_rename_page_url => $self->derive_url( action => 'meetings_json', task => 'rename_page' ),
        meetings_remove_page_url => $self->derive_url( action => 'meetings_json', task => 'remove_page' ),
        meetings_remove_media_url => $self->derive_url( action => 'meetings_json', task => 'remove_media' ),
        meetings_remove_meeting_url => $self->derive_url( action => 'meetings_json', task => 'remove_meeting' ),
        meetings_manage_virtual_url => $self->derive_url( action => 'meetings_json', task => 'manage_virtual' ),
        meetings_summary_url => $self->derive_url( action => 'meetings', task => 'summary' ),

        meetings_update_url => $self->derive_url( action => 'meetings_json', task => 'update' ),

        meetings_manage_conferencing_url => $self->derive_url( action => 'meetings_json', task => 'save_conferencing_data' ),
        meetings_manage_email_url => $self->derive_url( action => 'meetings_json', task => 'save_email_settings_data' ),
        meetings_manage_password_url => $self->derive_url( action => 'meetings_json', task => 'save_password_settings_data' ),
        meetings_manage_participant_rights_url => $self->derive_url( action => 'meetings_json', task => 'save_participant_rights_data' ),
        meetings_set_date_url => $self->derive_url( action => 'meetings_json', task => 'set_date' ),
        meetings_set_date_data_url => $self->derive_url( action => 'meetings_json', task => 'get_basic' ),
        meetings_set_location_url => $self->derive_url( action => 'meetings_json', task => 'set_location' ),
        meetings_set_location_data_url => $self->derive_url( action => 'meetings_json', task => 'get_location' ),
        meetings_manage_basic_data_url => $self->derive_url( action => 'meetings_json', task => 'get_basic' ),
        meetings_set_title_url => $self->derive_url( action => 'meetings_json', task => 'set_title' ),
        meetings_set_title_data_url => $self->derive_url( action => 'meetings_json', task => 'get_basic' ),
        meetings_get_info_url => $self->derive_url( action => 'meetings_json', task => 'get_meeting_info' ),
        meetings_get_participants_url => $self->derive_url( action => 'meetings_json', task => 'get_participants' ),
        meetings_invite_participants_url => $self->derive_url( action => 'meetings_json', task => 'add_participants' ),
        meetings_invite_customize_message_url => $self->derive_url( action => 'meetings_json', task => 'invite' ),
        meetings_invite_customize_message_data_url => $self->derive_url( action => 'meetings_json', task => 'draft_ready' ),
        meetings_invite_participants_data_url => $self->derive_url( action => 'meetings_json', task => 'invite_participants_data' ),
        meetings_removed_from_meeting_url => $self->derive_url( action => 'meetings_global', task => 'removed_from_meeting', params => { removed_from => $self->_meeting_title_string( $event ) } ),
        meetings_get_autosave_content_url => $self->derive_url(action => 'meetings_json', task => 'get_wiki_page_autosave_content'),
        meetings_remove_self_from_meeting_url => $self->derive_url(action => 'meetings_json', task => 'remove_self_from_meeting'),
        meetings_set_user_rsvp_url => $self->derive_url(action => 'meetings_json', task => 'set_rsvp_status'),
        meetings_set_draft_user_rsvp_url => $self->derive_url(action => 'meetings_json', task => 'set_draft_rsvp_status'),
        meetings_get_gcal_meetings => $self->derive_url( action => 'meetings_json', task => 'get_gcal_events_for_user' ),

        meetings_in_quickbar_change_url => $self->derive_url( action => 'meetings_json', task => 'change_in_quickbar' ),
        meetings_send_emails_change_url => $self->derive_url( action => 'meetings_json', task => 'change_send_emails' ),

        meetings_invite_transfer_url => $self->derive_url( action => 'meetings_json', task => 'invite_transfer' ),
        meetings_resend_invite_url => $self->derive_url( action => 'meetings_json', task => 'resend_invite' ),
        meetings_remove_participant_url => $self->derive_url( action => 'meetings_json', task => 'remove_participant' ),
        meetings_begin_date_epoch => $event->begin_date,
        meetings_server_time_epoch => time,
        meetings_duration => $event->end_date ? $event->end_date - $event->begin_date : 0,
        meetings_is_admin => $is_admin,
        meetings_is_creator => ( CTX->request->auth_user_id == $event->creator_id ) ? 1 : 0,
        meetings_short_email => $email,
        meetings_user_can_add_material => $self->_user_can_add_material( $user, $event, $rsvp ),
        meetings_user_created_meetings => $user_created_meetings_count,
        meetings_user_meetings => $user_meetings_count,
        meetings_user_ispro => $pro,
        meetings_get_my_profile_url => $self->derive_url( action => 'meetings_json', task => 'get_my_profile' ),
        meetings_edit_my_profile_new_user_url => $self->derive_url( action => 'meetings_json', task => 'confirm_new_user_profile' ),

        meetings_google_connected => $self->_user_has_connected_google( CTX->request->auth_user ) ? 1 : 0,
        meetings_make_meeting_secure_url => $self->derive_url(action => 'meetings_json', task => 'make_meeting_secure'),
        meetings_draft_ready_url => $self->derive_url(action => 'meetings_json', task => 'draft_ready' ),

        $open_suggestion_picker ? ( meetings_open_suggestion_picker => 1 ) : (),
        CTX->request->param('send_now') ? ( meetings_open_customize_message_data_url => $self->derive_url(action => 'meetings_json', task => 'draft_ready' ) ) : (),
        CTX->request->param('set_location') ? ( meetings_open_set_location_data_url => $self->derive_url(action => 'meetings_json', task => 'get_location' ) ) : (),

        meetings_s2m_query_url => $self->derive_url(action => 'meetings_json', task => 's2m_query', additional => [ $event->id ] ),
        meetings_s2m_autocomplete_url => $self->derive_url(action => 'meetings_json', task => 's2m_autocomplete', additional => [ $event->id ] ),

        meetings_manage_urls => {
            basic_url => $self->derive_url( action => 'meetings_json', task => 'get_meeting_info' ),
            $pro ? (
            participant_rights_url => $self->derive_url( action => 'meetings_json', task => 'participant_rights_data' ),
            security_url => $self->derive_url( action => 'meetings_json', task => 'security_data' ),
            ) : (),
            conferencing_url => $self->derive_url( action => 'meetings_json', task => 'conferencing_data' ),
            remove_url => $self->derive_url( action => 'meetings_json', task => 'get_meeting_info' ),
            email_url => $self->derive_url( action => 'meetings_json', task => 'email_settings_data' ),
#            password_url => $self->derive_url( action => 'meetings_json', task => 'password_settings_data' ),
        },

        meetings_fill_skype_url => $self->derive_url( action => 'meetings_json', task => 'fill_skype' ),
        meetings_meeting_cancel_url => $self->derive_url( action => 'meetings_json', task => 'cancel_meeting' ),
        meetings_meeting_cancel_or_reschedule_url => $self->derive_url( action => 'meetings_json', task => 'reschedule_meeting' ),
        meetings_matchmaking_decline_url => $self->derive_url( action => 'meetings_json', task => 'decline_matchmaking_request' ),
        meetings_matchmaking_accept_url => $self->derive_url( action => 'meetings_json', task => 'accept_matchmaking_request' ),
        meetings_create_followup_url => $allow_followup ? $self->derive_url( action => 'meetings', task => 'create_followup' ) : '',

        @dismiss_globals_urls,
    };

    my $params = {};
    my @raw_tags = (
<<CODE
<script>
      window.___gcfg = {
        lang: 'en-US'
      };

      (function() {
        var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
        po.src = 'https://apis.google.com/js/plusone.js';
        var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
      })();
    </script>
CODE
    );

    my $head_widgets = [ Dicole::Widget::Raw->new( raw => join "", @raw_tags ) ];

    $self->_set_controller_variables( $globals, $self->_meeting_title_string( $event ), $event, $creator_user, $head_widgets );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_meeting' } );
}

sub enter_summary {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    $partner ||= $self->_ensure_partner_object( CTX->request->param('partner_id') );

    my $auth_user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $target_email = CTX->request->param('login_email');

    my $target_user = $target_email ? eval { $self->_fetch_user_for_email( $target_email ) } : undef;

    if ( ! $target_email ) {
        return $self->redirect( $self->derive_url( task => 'login', additional => [] ) );
    }

    if ( ! $target_user ) {
        # TODO: create user (and log in?)
        return "No user found for email " . $target_email;
    }

    my $params = {
        target_email => $target_user ? $target_user->email : $target_email,
    };

    if ( $auth_user ) {
        if ( $target_user->id == $auth_user->id ) {
            return $self->redirect( $self->derive_url( task => 'login', additional => [] ) );
        }
    }

    if ( $partner ) {
        my $preserve_partner_domain = $self->_get_note( preserve_domain => $partner );
        my $host = $preserve_partner_domain ? $self->_get_host_for_partner( $partner, 443 ) : $self->_get_host_for_domain( $domain_id, 443 );

        my $partner_can_log_in = $self->_partner_can_log_user_in( $partner, $target_user );
        my $pcs_is_valid = $self->_authenticate_partner_for_user( $partner, $target_user, CTX->request->param('pcs') );

        if ( $partner_can_log_in && $pcs_is_valid ) {
            return $self->redirect( $host . $self->derive_url( task => 'login', additional => [], params => {
                        dic => Dicole::Utils::User->permanent_authorization_key( $target_user )
                    } ) );
        }

        my $authorize_url = $self->_generate_authorized_uri_for_user(
            $host . $self->derive_url( task => 'authorize_partner', additional => [], params => {
                    user_id => $target_user->id,
                    partner_id => $partner->id,
                    key => $self->_create_partner_authorization_key_for_user( $partner, $target_user ),
                    return_url => $self->derive_url( task => 'login', additional => [] ),
                } ),
            $target_user,
            $partner->domain_id,
        );

        my $login_url = $self->_generate_authorized_uri_for_user(
            $host . $self->derive_url( task => 'login', additional => [] ),
            $target_user,
            $partner->domain_id
        );

        $self->_send_themed_mail(
            user => $target_user,
            partner_id => $partner->id,
            domain_id => $partner->domain_id,

            template_key_base => 'meetings_authorize_partner',
            template_params => {
                user_name => Dicole::Utils::User->name( $target_user ),
                partner_name => $partner->name,
                login_url => $login_url,
                authorize_url => $authorize_url,
            },
        );

        $params->{partner_name} = $partner->name;
        $params->{email_sent} = 1;
    }
    else {
        my $host = $self->_get_host( 443 );

        my $login_url = $self->_send_login_email(
            url => $host . $self->derive_url( task => 'login', additional => [] ),
            email => $target_user->email,
        );

        $params->{email_sent} = 1;
    }

    $params = {
        %$params,
        dump => Data::Dumper::Dumper( $params ),
    };

    $self->_set_controller_variables( {}, $self->_nmsg( 'You need to log in to access Meetin.gs' ) );
    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_enter_summary' } );
}

sub enter_meeting {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_cloaked_event;

    die "security error" unless $meeting;

    if ( $meeting->removed_date ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_nmsg('The requested meeting could not be found. It might have been removed.') );
        return $self->redirect('/');
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    $partner ||= $self->_ensure_partner_object( CTX->request->param('partner_id') );

    my $auth_user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $target_email = CTX->request->param('login_email');

    my $target_user = $target_email ? eval { $self->_fetch_user_for_email( $target_email ) } : undef;
    my $target_user_po = $target_user ? $self->_fetch_meeting_participant_object_for_user( $meeting, $target_user ) : undef;
    my $auth_user_po = $auth_user ? $self->_fetch_meeting_participant_object_for_user( $meeting, $auth_user ) : undef;

    my $params = {
        target_email => $target_user ? $target_user->email : $target_email,
    };

    if ( $auth_user && ( ( ! $target_email ) || ( $target_user && $auth_user->id == $target_user->id ) ) ) {
        if ( $auth_user_po ) {
            # TODO: is this a secure session escalation problem?
            return $self->redirect( $self->derive_url( task => 'meeting', additional => [ $meeting->id ], params => {
                dic => Dicole::Utils::User->permanent_authorization_key( $auth_user )
            } ) );
        }
        else {
            $params->{auth_user_not_a_participant} = 1;
        }
    }
    elsif ( $target_user && $target_user_po ) {
        if ( $partner ) {
            # NOTE: for now we ignore preserve_domain in enter_meeting as no integrations use it
            # my $preserve_partner_domain = $self->_get_note( preserve_domain => $partner );
            # my $host = $preserve_partner_domain ? $self->_get_host_for_partner( $partner, 443 ) : $self->_get_host_for_domain( $domain_id, 443 );

            my $host = $self->_get_host_for_partner( $partner, 443 );

            my $partner_can_log_in = $self->_partner_can_log_user_in( $partner, $target_user );
            my $pcs_is_valid = $self->_authenticate_partner_for_user( $partner, $target_user, CTX->request->param('pcs') );

            if ( $partner_can_log_in && $pcs_is_valid ) {
                return $self->redirect( $host . $self->derive_url( task => 'meeting', additional => [ $meeting->id ], params => {
                            dic => Dicole::Utils::User->permanent_authorization_key( $target_user )
                        } ) );
            }

            my $authorize_url = $self->_generate_authorized_uri_for_user(
                $host . $self->derive_url( task => 'authorize_partner', additional => [], params => {
                    user_id => $target_user->id,
                    partner_id => $partner->id,
                    key => $self->_create_partner_authorization_key_for_user( $partner, $target_user ),
                    return_url => $self->derive_url( task => 'meeting', additional => [ $meeting->id ] ),
                } ),
                $target_user,
                $meeting->domain_id,
            );

            my $login_url = $self->_generate_authorized_uri_for_user(
                $host . $self->derive_url( task => 'meeting', additional => [ $meeting->id ] ),
                $target_user,
                $meeting->domain_id
            );

            $self->_send_themed_mail(
                user => $target_user,
                partner_id => $partner->id,
                domain_id => $meeting->domain_id,

                template_key_base => 'meetings_authorize_partner',
                template_params => {
                    user_name => Dicole::Utils::User->name( $target_user ),
                    partner_name => $partner->name,
                    login_url => $login_url,
                    authorize_url => $authorize_url,
                },
            );

            $params->{email_sent} = 1;
        }
        else {
            my $host = $self->_get_host_for_meeting( $meeting, 443 );

            my $login_url = $self->_send_login_email(
                url => $host . $self->derive_url( task => 'meeting', additional => [ $meeting->id ] ),
                email => $target_user->email,
            );

            $params->{email_sent} = 1;
        }
    }
    elsif ( $auth_user && $auth_user_po ) {
        return $self->redirect( $self->derive_url( task => 'meeting', additional => [ $meeting->id ], params => {
                    dic => Dicole::Utils::User->permanent_authorization_key( $auth_user )
                } ) );
    }
    elsif ( $target_email ) {
        $params->{target_user_not_a_participant} = 1;
    }
    else {
        $params->{ask_for_email} = 1;
    }

    # TODO ponder situations where logged in participant tries to log in with differing email address but fails

    my $users = $self->_fetch_meeting_participant_users( $meeting );
    my $user_infos = $self->_gather_users_info( $users, 36, $meeting->domain_id );
    $params->{participant_infos} = [ map { {
        email => $_->{email},
        image => $_->{image},
        url => $self->derive_url( params => {
            login_email => $_->{email},
            return_url => $self->derive_url( task => 'meeting', additional => [ $meeting->id ] ),
        } )
    } } @$user_infos ];

    $params->{meeting_title} = $self->_meeting_title_string( $meeting );
    $params->{meeting_location} = $self->_meeting_location_string( $meeting );
    #$params->{meeting_time} = $meeting->

    $self->_set_controller_variables( {}, $self->_nmsg( 'You need to log in to access this meeting' ) );
    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_enter_meeting' } );
}

sub authorize_partner {
    my ( $self ) = @_;

    my $partner = $self->param('partner');
    $partner ||= $self->_ensure_partner_object( CTX->request->param('partner_id') );
    my $user = CTX->request->auth_user;

    return $self->redirect( $self->derive_url( action => 'meetings_global', task => 'detect' ) ) unless $partner;

    my $target_user = Dicole::Utils::User->ensure_object( CTX->request->param('user_id') );
    die unless $target_user;

    my $key = $self->_create_partner_authorization_key_for_user( $partner, $target_user );

    if ( $partner && $user && $user->id == $target_user->id && $key eq CTX->request->param('key') ) {
        $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => time, $user, $partner->domain_id );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('%1$s is now succesfully authorized to log you in!', [ $partner->name ] ) );

        my $return_url = CTX->request->param('return_url') || $self->derive_url( action => 'meetings_global', task => 'detect' );

        return $self->redirect( $return_url );
    }

    die "security error";
}

sub _authenticate_partner_for_user {
    my ( $self, $partner, $user, $pcs ) = @_;

    return 0 unless $partner && $pcs && $user;

    return ( ( $pcs eq $self->_create_partner_authentication_checksum_for_user( $partner, $user ) ) ? 1 : 0 );
}

sub _render_404 {
    my ( $self ) = @_;

    return $self->redirect( 'https://www.meetin.gs/404.html' ) unless CTX->request->auth_user_id;

    $self->_set_controller_variables( {}, 'Not found' );

    return $self->generate_content( {}, { name => 'dicole_meetings::main_meetings_404' } );
}

sub verify_temp_meeting_transfer {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $meeting_id = $self->param('meeting_id');
    my $from_user_id = $self->param('user_id');
    my $send_now = $self->param('send_now');

    my $meeting = $self->_ensure_meeting_object( $meeting_id );
    my $from_user = Dicole::Utils::User->ensure_object( $from_user_id );

    my $checksum = $self->_create_temp_meeting_verification_checksum_for_user( $meeting, $from_user );
    die "security error" unless $self->param('checksum') eq $checksum;

    $self->_transfer_meeting_from_temp_user_to_user( $meeting, $from_user, CTX->request->auth_user );
    $self->_merge_temp_user_to_user( $from_user, CTX->request->auth_user, $meeting->domain_id );

    return $self->redirect(
        $self->derive_url( task => 'meeting', target => $meeting->group_id, additional => [ $meeting_id ], params => { $send_now ? ( send_now => $send_now ) : () } )
    );
}

sub verify_temp_account_transfer {
    my ( $self ) = @_;

    my $to_user_id = $self->param('to_user_id');
    my $from_user_id = $self->param('from_user_id');
    my $event_id = $self->param('event_id');

    die "security error" unless CTX->request->auth_user_id && CTX->request->auth_user_id == $to_user_id;

    my $to_user = CTX->request->auth_user;
    my $from_user = Dicole::Utils::User->ensure_object( $from_user_id );

    my $checksum = $self->_create_temp_account_email_verification_checksum_for_user( $to_user->id, $from_user );
    die "security error" unless $self->param('checksum') eq $checksum;

    my $old_fragment = $self->_fetch_user_matchmaker_fragment( $to_user );
    my $new_fragment = $self->_fetch_user_matchmaker_fragment( $from_user );

    if ( $old_fragment && $new_fragment ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_nmsg('You already have an active meet me url. Please change the url again to verify the change') );
    }

    $self->_merge_temp_user_to_user( $from_user, $to_user, Dicole::Utils::Domain->guess_current_id ) unless $from_user->id == $to_user->id;

    return $self->redirect(
        $self->_get_meet_me_config_abs( $event_id )
    );
}

sub verify_temp_account_email {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id');
    my $user_email_id = $self->param('user_email_id');
    my $meeting_id = $self->param('meeting_id');
    my $send_now = $self->param('send_now');
    my $event_id = $self->param('event_id');

    my $user = Dicole::Utils::User->ensure_object( $user_id );

    my $checksum = $self->_create_temp_account_email_verification_checksum_for_user( $user_email_id, $user );

    die "security error" unless $self->param('checksum') eq $checksum;

    my $user_email_object = CTX->lookup_object('meetings_user_email')->fetch( $user_email_id );
    $user_email_object->verified_date( time );
    $user_email_object->save;

    $user->email( $user_email_object->email );
    $user->save;

    eval { CTX->lookup_action('meetings_api')->e( check_user_startup_status => {
        user => $user,
        domain_id => Dicole::Utils::Domain->guess_current_id,
    } ) };

    if ( $meeting_id ) {
        my $meeting = $self->_ensure_meeting_object( $meeting_id );

        return $self->redirect(
            $self->derive_url( task => 'meeting', target => $meeting->group_id, additional => [ $meeting_id ], params => { $send_now ? ( send_now => $send_now ) : () } )
        );
    }
    else {
        return $self->redirect(
            $self->_get_meet_me_config_abs( $event_id, { new_user => 1 } )
        );
    }
}

sub disable_meeting_emails {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $self->_events_api( current_user_can_see_event => { event => $event } );

    my $eus =  $self->_events_api( event_users_link_list => { event => $event } );
    my %lookup = map { $_->user_id => $_ } @$eus;
    my $rsvp = $lookup{ $uid };

    $self->_set_note_for_meeting_user(
        'disable_emails', time(), $event, $rsvp->user_id, $rsvp
    ) if $rsvp;

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('Automatic emails disabled for this meeting') );

    return $self->redirect( $self->derive_url( task => 'meeting' ) );
}

sub secure_login_info {
    my ($self) = @_;

    $self->_redirect_unless_https;

    my $globals = {
        meetings_login_url => $self->derive_url( action => 'meetings_json', task => 'login', additional => [] ),
    };

    my $params = {
        url_after_login => $self->derive_url( action => 'meetings', task => 'meeting' )
    };

    $self->_set_controller_variables( $globals, 'Secure login required' );

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_secure_login_info' } );
}

sub api_documentation {
    my ( $self ) = @_;

    my $file = CTX->repository->find_file(dicole_meetings => 'template/api_documentation.markdown');

    return Text::Markdown::markdown(do { local $/; open my $mkd, '<', $file or die $!; <$mkd> });
}

sub edit_partner {
    my ( $self ) = @_;

    # TODO: security check

    my $domain = $self->param('domain');
    my $partner_id = $self->param('target_partner_id');
    my $partner = $self->PARTNERS_BY_ID->{ $partner_id };

    return "No such partner" unless $partner;

    my @template_parts = ( qw(
        meetings_meeting_created_subject_template
        meetings_meeting_created_html_template
        meetings_meeting_created_text_template
    ) );

    my $default_lexicon = CTX->lookup_action('localization_api')->e( lexicon => {
        filter_to_string => \@template_parts,
        domain => $domain,
        group_id => 0,
        lang => 'en', # Fixed
    } );

    my $partner_lexicon = CTX->lookup_action('localization_api')->e( lexicon => {
        filter_to_string => \@template_parts,
        domain => $domain,
        partner => $partner,
        group_id => 0,
        lang => 'en', # Fixed
    } );

    if ( CTX->request->param('save') ) {
        $partner->name( CTX->request->param('name') );

        my $namespace = $partner->localization_namespace;

        unless ( $namespace ) {
            $namespace = $partner->domain_alias;
            $partner->localization_namespace( $namespace );
        }

        my $object = CTX->lookup_object('custom_localization');

        for my $key ( @template_parts ) {
            my $value = CTX->request->param( $key );

            my ( $sv ) = $value =~ /^\s*(.*?)\s*$/s;
            my ( $pv ) = $partner_lexicon->{ $key} =~ /^\s*(.*?)\s*$/s;
            my ( $dv ) = $default_lexicon->{ $key } =~ /^\s*(.*?)\s*$/s;

            next if $sv eq $pv;
            $value = '' if $sv eq $dv;

            # at the same time remove all entries with empty keys as they are just used for cache clearing and are not needed anymore
            my $old_objects = $object->fetch_group({
                where => 'namespace_key = ? AND namespace_area = ? AND namespace_lang = ? AND ( localization_key = ? OR localization_key = ? )',
                value => [ $namespace, 0, 'en', $key, '' ],
            }) || [];
            $_->remove for @$old_objects;

            # if there is no value, just add an empty key entry to for cache clearing
            my $t = $object->new( {
                creation_date => time(),
                namespace_key => $namespace,
                namespace_area => 0,
                namespace_lang => 'en',
                localization_key => $value ? $key : '',
                localization_value => $value,
            } );

            $t->save;
        }

        $self->_set_note( from_email => CTX->request->param('from_email'), $partner, { skip_save => 1 } );
        $partner->save;
    }

    $partner_lexicon = CTX->lookup_action('localization_api')->e( lexicon => {
        filter_to_string => \@template_parts,
        domain => $domain,
        partner => $partner,
        group_id => 0,
        lang => 'en', # Fixed
    } );

    my $params = {
        name => $partner->name,
        partner_lexicon => $partner_lexicon,
        from_email => $self->_get_note( from_email => $partner ),
    };

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_edit_partner' } );
}

sub _process_invite_consume {
    my ( $self, $invite, $user, $gid ) = @_;

    if ( $gid && ! Dicole::Utils::User->belongs_to_group( $user, $gid ) ) {
        CTX->lookup_action('groups_api')->e( add_user_to_group => {
            user_id => Dicole::Utils::User->ensure_id( $user ), group_id => $gid,
        } );
    }

    $self->_events_api( consume_invite => { invite => $invite, user => $user } );

    return $self->redirect( $self->derive_url );
}

sub _serve_meeting_theme_image {
    my ( $self, $piece, $meeting ) = @_;

    $meeting ||= $self->_get_valid_event;

    return $self->_serve_user_theme_image( $piece, Dicole::Utils::User->ensure_object( $meeting->creator_id ) );
}

sub _serve_user_theme_image {
    my ( $self, $piece, $user ) = @_;

    $user ||= CTX->request->auth_user;

    my $aid = $self->_get_note_for_user( 'pro_theme_' . $piece . '_image', $user );

    return $self->_serve_theme_attachment( $piece, $aid );
}

sub _serve_draft_theme_image {
    my ( $self, $piece ) = @_;

    my $draft_id = CTX->request->param('draft_id');
    my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
        draft_id => $draft_id,
    } );

    return $self->_serve_theme_attachment( $piece, $a );
}

sub _serve_theme_attachment {
    my ( $self, $piece, $a ) = @_;

    CTX->lookup_action('attachments_api')->e( serve => {
        attachment_id => ref( $a ) ? undef : $a,
        attachment => ref( $a ) ? $a : undef,
        ( $piece eq 'header' ) ? (
            thumbnail => 1,
            max_width => 180,
            max_height => 40,
        ) : (),
    } );
}

sub own_theme_header_image { return $_[0]->_serve_user_theme_image( 'header' ); }

sub own_theme_background_image { return $_[0]->_serve_user_theme_image( 'background' ); }

sub draft_theme_header_image { return $_[0]->_serve_draft_theme_image( 'header' ); }

sub draft_theme_background_image { return $_[0]->_serve_draft_theme_image( 'background' ); }

sub meeting_theme_header_image { return $_[0]->_serve_meeting_theme_image( 'header' ); }

sub meeting_theme_background_image { return $_[0]->_serve_meeting_theme_image( 'background' ); }



1;
