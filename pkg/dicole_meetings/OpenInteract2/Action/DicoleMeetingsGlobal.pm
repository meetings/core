package OpenInteract2::Action::DicoleMeetingsGlobal;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use File::Temp qw();
use URI;
use URI::URL;

sub logout {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $ual = CTX->request->param('url_after_logout');
    my $partner = CTX->request->param('partner');

    # I think this is pretty much legacy stuff..
    if ( ! $ual && $partner ) {
        if ( $self->_get_note( logout_to_appdirect_marketplace => $partner ) ) {
            my $base_url = $self->_get_note( appdirect_base_url => $partner );
            $base_url .= '/' unless $base_url =~ /\/$/;
            $ual = $base_url . 'applogout';
        }
    }

    if ( ! $ual && ! CTX->request->param('partner') && CTX->request->auth_user_id ) {
        my $user_subs = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
                where => 'user_id = ?',
                value => [ CTX->request->auth_user_id ],
            } );

        for my $user_sub ( @$user_subs ) {
            my $sub = $self->_ensure_object_of_type( meetings_company_subscription => $user_sub->subscription_id );
            next unless $sub;
            next if $sub->removed_date;
            next if $sub->cancelled_date;
            next if $sub->expires_date && $sub->expires_date < time;

            my $base_url = $self->_get_note( appdirect_base_url => $sub );

            next unless $base_url;

            $base_url .= '/' unless $base_url =~ /\/$/;
            $ual = $base_url . 'applogout';

            last;
        }
    }

    $ual ||= $self->derive_url( action => 'meetings', task => 'logout', additional => [], CTX->request->auth_user_id ? ( params => { lang => CTX->request->auth_user->language } ) : () );

    return $self->redirect( $self->derive_url( action => 'xlogout', params => { url_after_logout => $ual } ) );
}

sub switch_account {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $account = CTX->request->param('account');

    my $user_shared_account_data = $self->_get_note_for_user( 'meetings_shared_account_data', $user, $domain_id ) || [];
    my $usadmap = { map { lc( $_->{email} ) => 1 } @$user_shared_account_data };

    my $partner_shared_accounts = $self->_get_note( shared_admin_accounts => $partner );
    my $psamap = { map { lc( $_ ) => 1 } @$partner_shared_accounts };

    unless ( $account && $usadmap->{ lc( $account ) } && $psamap->{ lc( $account ) } ) {
        die "security error";
    }

    my $account_user = $self->_fetch_user_for_email( $account, $domain_id );

    my $admin_partner_domain = $self->_get_note( admin_partner_domain => $partner );
    my $admin_partner = $self->PARTNERS_BY_DOMAIN_ALIAS->{ $admin_partner_domain };
    my $full_login_url = $self->_get_host_for_partner( $admin_partner, 443 ) . $self->derive_url( action => 'meetings', task => 'login' );
    my $auth_url = $self->_generate_authorized_uri_for_user( $full_login_url, $account_user, $domain_id );

    return $self->redirect( $auth_url );
}

sub detect {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    return $self->redirect( '/' ) unless $uid;

    my $user = CTX->request->auth_user;
    my $target_user = $user->email ? $self->_fetch_or_create_user_for_email( $user->email ) : $user;

    if ( $target_user->email ne $user->email ) {
        return $self->redirect( $self->derive_url( action => 'meetings', task => 'account_forwarded' ) );
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $redirect_partner_id = $self->_get_note_for_user( meetings_forward_login_to_partner => $user, $domain_id );
    my $redirect_partner = $redirect_partner_id ? $self->PARTNERS_BY_ID->{ $redirect_partner_id } : ();
    if ( $redirect_partner && ( ! $partner || $partner->id != $redirect_partner->id ) ) {
        # NOTE: logout from this domain so that the redirecting login does not stay lingering

        my $full_login_url = $self->_get_host_for_partner( $redirect_partner, 443 ) . $self->derive_full_url;
        my $auth_url = $self->_generate_authorized_uri_for_user( $full_login_url, $user, $domain_id );
        my $redirected_auth_url = $self->derive_url( action => 'xlogout', task => '', params => { url_after_logout => $auth_url } );
        return $self->redirect( $redirected_auth_url );
    }

    if ( $self->_user_is_partner_booker( $user ) ) {
        return $self->redirect( $self->derive_full_url( action => 'meetings', task => 'agent_booking', target => 0, additional => [], params => {} ) );
    }

    my $gid = $self->_determine_user_base_group( $uid );

    return $self->redirect( $self->derive_full_url( action => 'meetings', task => 'summary', target => $gid || 0 ) );
}

sub verify_facebook {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    return $self->redirect( '/' ) unless $uid;

    my $user = CTX->request->auth_user;
    return $self->redirect( '/' ) unless $user;

    $user->facebook_user_id( CTX->request->param('facebook_user_id') );
    $user->save;

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('Facebook connected succesfully!') );

    return $self->redirect( CTX->request->param('url_after_action') || '/' );
}

sub verify_google {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    return $self->redirect( '/' ) unless $uid;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $id = CTX->request->param('google_user_id');

    $self->_add_user_service_account( $user, $domain_id, 'google', $id, 1 );

    my $request_token = $self->_get_note_for_user( "meetings_temp_google_request_token_for_$id", $user, $domain_id );
    if ( $request_token ) {
       $self->_set_note_for_user( "meetings_temp_google_request_token_for_$id", undef, $user, $domain_id, { skip_save => 1 } );
       $self->_set_note_for_user( "meetings_google_oauth2_refresh_token", $request_token, $user, $domain_id );
    }

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('Google connected succesfully!') );

    return $self->redirect( CTX->request->param('url_after_action') || '/' );
}

sub dropbox_start {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_host = $self->_get_host_for_user( $user, undef, 443 );
    my $callback = $domain_host . $self->derive_url( action => 'meetings_global', task => 'dropbox_connect', target => 0, additional => [], params => { return_url => CTX->request->param('return_url') } );

    my $o = $self->_dropbox_client( $user, undef, { new_request => 1 } );

    my $url = $o->get_authorization_url( oauth_callback => $callback );

    $self->_set_note_for_user( 'meetings_dropbox_request_token', $o->request_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_dropbox_request_token_secret', $o->request_token_secret, $user );

    return $self->redirect( "" . $url );
}

sub dropbox_connect {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;

    my $o = $self->_dropbox_client;

    $o->request_access_token();

    $self->_set_note_for_user( 'meetings_dropbox_access_token', $o->access_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_dropbox_access_token_secret', $o->access_token_secret, $user );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg( "Dropbox connected succesfully! Your files will start to sync in the background momentarily." ) );
    my $return_url = CTX->request->param('return_url');
    if( $return_url ){
        $self->redirect( $return_url );
    }
    else{
        $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', additional => [] ) );
    }
}

sub google_start_2 {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
    my $params = { return_host => CTX->request->server_name };

    for my $attr ( qw( return_url cancel_url meeting_id return_cookie_param cancel_cookie_param require_refresh_token expect_refresh_token ) ) {
        my $val = CTX->request->param( $attr );
        if ( $attr =~ /url/ ) {
            $val =~ s/\&amp\;(\w+=)/\&$1/g;
        }
        $params->{ $attr } = $val if $val;
    }

    my $callback = URI::URL->new( $domain_host . $self->derive_url( action => 'meetings_global', task => 'google_connect_2', target => 0, additional => [] ) );

    my $google_url = URI::URL->new( 'https://accounts.google.com/o/oauth2/auth' );
    $google_url->query_form( {
        scope => 'https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.google.com/calendar/feeds/ https://www.google.com/m8/feeds',
        redirect_uri => $callback->as_string,
        response_type => 'code',
        client_id => '584216729178.apps.googleusercontent.com',
        state => Dicole::Utils::JSON->encode( $params ),
        access_type => 'offline',
        ( $params->{require_refresh_token} ? ( approval_prompt => 'force' ) : () ),
    } );

    return $self->redirect( "" . $google_url->as_string );
}

sub google_start {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : $self->_create_temporary_user( $domain_id );

    my $domain_host = $self->_get_host_for_user( $user, $domain_id, 443 );
    my $params = {
        return_url => CTX->request->param('return_url'),
        cancel_url => CTX->request->param('cancel_url'),

        meeting_id => CTX->request->param('meeting_id'),
        return_cookie_param => CTX->request->param('return_cookie_param'),
        cancel_cookie_param => CTX->request->param('cancel_cookie_param'),
    };

    $params->{dic} = Dicole::Utils::User->permanent_authorization_key( $user ) unless CTX->request->auth_user_id;

    # NOTE: this is done separately because oi2 does not escape & correctly
    my $callback = URI::URL->new( $domain_host . $self->derive_url( action => 'meetings_global', task => 'google_connect', target => 0, additional => [] ) );
    $callback->query_form( $params );
    $callback = $callback->as_string;


    my $o = $self->_google_client( $user, undef, { new_request => 1 } );

    my $url = $o->get_authorization_url( callback => $callback, extra_params => { scope => 'https://www.google.com/calendar/feeds/ https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.google.com/m8/feeds' } );

    $self->_set_note_for_user( 'meetings_google_request_token', $o->request_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_google_request_token_secret', $o->request_token_secret, $user );

    return $self->redirect( "" . $url );
}

sub google_connect {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    my $profile_data = eval {
        if ( my $oauth_verifier = CTX->request->param('oauth_verifier') ) {
            my $o = $self->_google_client;
            $o->request_access_token( verifier => $oauth_verifier );

            $self->_set_note_for_user( 'meetings_google_access_token', $o->access_token, $user, $domain_id, 'no_save' );
            $self->_set_note_for_user( 'meetings_google_access_token_secret', $o->access_token_secret, $user, $domain_id );
        }

        return $self->_fetch_user_info_from_google( $user, $domain_id );
    } || {};

    my $params = {};
    for my $attr ( qw( return_url cancel_url meeting_id return_cookie_param cancel_cookie_param require_refresh_token ) ) {
        $params->{ $attr } = CTX->request->param( $attr );
    }

    return $self->_google_connect( $profile_data, $params );
}

sub google_connect_2 {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $profile_data = {};
    my $params = {};
    my $refresh_token = undef;

    if ( my $code = CTX->request->param('code') ) {
        $params = Dicole::Utils::JSON->decode( CTX->request->param('state' ) );
        unless ( CTX->request->server_name eq $params->{return_host} ) {
            return $self->redirect( Dicole::URL->get_domain_name_url( $params->{return_host}, 443 ) . $self->derive_full_url );
        }

        my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
        my $callback = URI::URL->new( $domain_host . $self->derive_url( action => 'meetings_global', task => 'google_connect_2', target => 0, additional => [] ) );

        my $result = Dicole::Utils::HTTP->post( 'https://accounts.google.com/o/oauth2/token', {
                code => $code,
                client_id => '584216729178.apps.googleusercontent.com',
                client_secret => 'x',
                redirect_uri => $callback->as_string,
                grant_type => 'authorization_code',
            } );

        my $result_data = Dicole::Utils::JSON->decode( $result );

        $refresh_token = $result_data->{refresh_token};
        if ( $params->{expect_refresh_token} && ! $refresh_token ) {
            $params->{require_refresh_token} = 1;
            return $self->redirect( $self->derive_url( task => 'google_start_2', params => $params ) );
        }

        $profile_data = eval {
            my $google_url = URI::URL->new( 'https://www.googleapis.com/oauth2/v1/userinfo' );

            $google_url->query_form( {
                    access_token => $result_data->{access_token},
                } );

            my $response = Dicole::Utils::HTTP->get( $google_url->as_string );

            return Dicole::Utils::JSON->decode( $response );
        } || {};
    }
    elsif ( $user ) {
        $refresh_token = $self->_get_note_for_user( meetings_google_oauth2_refresh_token => $user, $domain_id );

        return $self->redirect( $self->derive_url( task => 'google_start_2', params => $params ) )
            unless $refresh_token;

        $profile_data = eval {
            $self->_go2_call_api( $user, $domain_id, 'https://www.googleapis.com/oauth2/v1/userinfo' )
        } || {};

        for my $attr ( qw( return_url cancel_url meeting_id return_cookie_param cancel_cookie_param require_refresh_token ) ) {
            $params->{ $attr } = CTX->request->param( $attr );
        }
    }

    return $self->_google_connect( $profile_data, $params, $refresh_token );
}

sub _google_connect {
    my ( $self, $profile_data, $params, $refresh_token ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;
    my $id = $profile_data->{id};

    if ( $@ || ! $id ) {
        return $self->redirect( $self->_form_cancel_url_using_connect_params( $params ) );
    }

    unless ( $user && $user->email ) {
        my $existing_users = CTX->lookup_object('meetings_user_service_account')->fetch_group({
                where => 'service_type = ? AND service_uid = ? AND domain_id = ? AND verified_date > ?',
                value => [ 'google', $id, $domain_id, 0 ],
            }) || [];

        for my $eu ( @$existing_users ) {
            my $existing_user = eval { Dicole::Utils::User->ensure_object( $eu->user_id ) };
            if ( $user && $existing_user && $existing_user->email ) {
                my $return_url = $self->_form_url_using_connect_param_values( $params->{return_url} );

                if ( my $meeting_id = CTX->request->param('meeting_id') ) {
                    my $new_meeting = $self->_transfer_meeting_from_temp_user_to_user(
                        $meeting_id, $user, $existing_user
                    );

                    # Form the real return url for the migrated meeting as group might have changed
                    $return_url = $self->_form_url_using_connect_param_values(
                        $params->{return_url},
                        $new_meeting->id,
                        $params->{return_cookie_param},
                    );
                }

                $self->_merge_temp_user_to_user( $user, $existing_user, $domain_id );

                # Make sure the next pass with the logged in user gets through with fresh access tokens:

                for my $note ( qw ( meetings_google_access_token meetings_google_access_token_secret meetings_google_oauth2_refresh_token ) ) {
                    my $value = $self->_get_note_for_user( $note, $user, $domain_id );
                    $self->_set_note_for_user( $note, $value, $existing_user, $domain_id, { skip_save => 1 } ) if $value;
                }

                $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $refresh_token, $existing_user, $domain_id, { skip_save => 1} ) if $refresh_token;

                $existing_user->save;

                return $self->redirect( $self->_generate_authorized_uri_for_user(
                    $self->derive_url( params => { return_url => $return_url } ), $existing_user, $domain_id
                ) );
            }
            elsif ( $existing_user && $existing_user->email ) {
                $refresh_token ||= $self->_get_note_for_user( 'meetings_google_oauth2_refresh_token', $existing_user, $domain_id );

                if ( $refresh_token ) {
                    $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $refresh_token, $existing_user, $domain_id );

                    my $url = $self->_form_return_url_using_connect_params( $params );
                    return $self->redirect( $self->_generate_authorized_uri_for_user(
                        $self->derive_url( params => { return_url => $url } ), $existing_user, $domain_id
                    ) );
                }
                else {
                    $params->{require_refresh_token} = 1;
                    return $self->redirect( $self->derive_url( task => 'google_start_2', params => $params ) );
                }
            }
        }
    }

    if ( $user ) {
        if ( $refresh_token ) {
            $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $refresh_token, $user, $domain_id );
        }
    }
    else {
        if ( ! $refresh_token ) {
            $params->{require_refresh_token} = 1;
            return $self->redirect( $self->derive_url( task => 'google_start_2', params => $params ) );
        }

        my $return_url = $self->_form_return_url_using_connect_params( $params );

        return $self->redirect( $self->derive_url(
            action => 'meetings',
            task => 'connect_service_account',
            params => {
                email => $profile_data->{email},
                service_type => 'google',
                service_user_id => $id,
                url_after_action => $self->derive_url( task => 'google_start_2', params => { return_url => $return_url } ),
                state => $refresh_token,
            },
        ) );
    }

    $user->first_name( $profile_data->{given_name} ) unless $user->first_name;
    $user->last_name( $profile_data->{family_name} ) unless $user->last_name;
    $user->save;

    $self->_add_user_service_account( $user, $domain_id, 'google', $id, 1 );
    $self->_add_user_service_account( $user, $domain_id, 'google_email', $profile_data->{email}, $profile_data->{verified_email} ? 1 : 0 ) if $profile_data->{email};

    if ( my $pic = $profile_data->{picture} ) {
        my $existing_portrait = CTX->lookup_action('networking_api')->e( user_portrait => {
            user_id => $user->id,
            domain_id => $domain_id,
            no_default => 1,
        } );

        CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_url => {
            user_id => $user->id,
            domain_id => $domain_id,
            url => $pic,
        } ) unless $existing_portrait;
    }

    return $self->redirect( $self->_form_return_url_using_connect_params( $params ) );
}

sub _form_return_url_using_connect_params {
    my ( $self, $params ) = @_;

    return $self->_form_url_using_connect_param_values( map { $params->{$_} || undef } qw( return_url meeting_id return_cookie_param ) );
}

sub _form_cancel_url_using_connect_params {
    my ( $self, $params ) = @_;

    return $self->_form_url_using_connect_param_values( map { $params->{$_} || undef } qw( cancel_url meeting_id cancel_cookie_param ) );
}

sub _form_url_using_connect_param_values {
    my ( $self, $force_url, $meeting_id, $cookie_param ) = @_;

    return $force_url if $force_url;

    if ( $meeting_id ) {
        if ( $cookie_param ) {
            return $self->_get_cookie_param_abs( $self->_get_meeting_abs( $meeting_id, { $cookie_param => 1 } ) );
        }
        else {
            return $self->_get_meeting_abs( $meeting_id );
        }
    }
    else {
        return $self->derive_url( action => 'meetings_global', task => 'detect', additional => [] );
    }
}

sub redirect_mobile {
    my ( $self ) = @_;

    my $code = CTX->request->param('code');
    my $state_json = CTX->request->param('state');
    my $state = Dicole::Utils::JSON->decode( $state_json );

    my $to = delete $state->{to};

    die unless $to =~ /^(http...(?:localhost|[^\/]+\.dev\/)|https...([^\/]+\.|)meetin\.gs|meetings|steroids)/;

    my $to_uri = URI->new( $to );
    my %query = $to_uri->query_form;
    $to_uri->query_form( { %query, %$state, code => $code } );

    # For some reason iOS 8+ cordova bugs out so that a simple redirect confuses location.href and fails script loading
    if ( CTX->request->user_agent =~ /steroids/i ) {
        return '<html><body><script>location.href="'. $to_uri .'";</script></body></html>';
    }

    return $self->redirect( "" . $to_uri );
}

sub twitter_start {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_host = $self->_get_host_for_user( $user, undef, 443 );
    my $callback = $domain_host . $self->derive_url( action => 'meetings_global', task => 'twitter_connect', target => 0, additional => [], params => { return_url => CTX->request->param('return_url') } );

    my $o = $self->_twitter_client( $user, undef, { new_request => 1 } );

    my $url = $o->get_authorization_url( callback => $callback );

    $self->_set_note_for_user( 'meetings_twitter_request_token', $o->request_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_twitter_request_token_secret', $o->request_token_secret, $user );

    return $self->redirect( "" . $url );
}

sub twitter_connect {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;

    my $o = $self->_twitter_client;
    $o->request_access_token( verifier => CTX->request->param('oauth_verifier') );

    $self->_set_note_for_user( 'meetings_twitter_access_token', $o->access_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_twitter_access_token_secret', $o->access_token_secret, $user );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg( "Twitter connected succesfully!" ) );

    my $return_url = CTX->request->param('return_url');
    if( $return_url ){
        $self->redirect( $return_url );
    }
    else{
        $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', additional => [] ) );
    }
}

sub linkedin_start {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_host = $self->_get_host_for_user( $user, undef, 443 );

    my $callback = $domain_host . $self->derive_url( action => 'meetings_global', task => 'linkedin_connect', target => 0, additional => [], params => { return_url => CTX->request->param('return_url') } );

    my $o = $self->_linkedin_client( $user, undef, { new_request => 1 } );

    my $url = $o->get_authorization_url( callback => $callback );

    $self->_set_note_for_user( 'meetings_linkedin_request_token', $o->request_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_linkedin_request_token_secret', $o->request_token_secret, $user );

    return $self->redirect( "" . $url );
}

sub linkedin_connect {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;

    my $o = $self->_linkedin_client;
    $o->request_access_token( verifier => CTX->request->param('oauth_verifier') );

    $self->_set_note_for_user( 'meetings_linkedin_access_token', $o->access_token, $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_linkedin_access_token_secret', $o->access_token_secret, $user );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg( "LinkedIn connected succesfully!" ) );

    my $return_url = CTX->request->param('return_url');
    if( $return_url ){
        $self->redirect( $return_url );
    }
    else{
        $self->redirect( $self->derive_url( action => 'meetings', task => 'summary', additional => [] ) );
    }
    #$self->redirect( $self->derive_url( action => 'meetings', task => 'wizard', additional => [], params => { step => 'linkedin_done' } ) );
}

sub facebook_start {
    my ( $self ) = @_;

    die "this endpoints needs the user to be logged in" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
    my $params = { return_host => CTX->request->server_name };

    for my $attr ( qw( return_url cancel_url ) ) {
        my $val = CTX->request->param( $attr );
        if ( $attr =~ /url/ ) {
            $val =~ s/\&amp\;(\w+=)/\&$1/g;
        }
        $params->{ $attr } = $val if $val;
    }

    my $callback = URI::URL->new( $domain_host . $self->derive_url( action => 'meetings_global', task => 'facebook_connect', target => 0, additional => [] ) );
    my $google_url = URI::URL->new( 'https://www.facebook.com/dialog/oauth' );
    $google_url->query_form( {
        redirect_uri => $callback->as_string,
        response_type => 'code',
        client_id => $self->SOCIAL_APP_KEYS->{facebook_key},
        state => Dicole::Utils::JSON->encode( $params ),
    } );

    return $self->redirect( "" . $google_url->as_string );
}

sub facebook_connect {
    my ( $self ) = @_;

    die "this endpoints needs the user to be logged in" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( my $code = CTX->request->param('code') ) {
        my $params = Dicole::Utils::JSON->decode( CTX->request->param('state' ) );
        unless ( CTX->request->server_name eq $params->{return_host} ) {
            return $self->redirect( Dicole::URL->get_domain_name_url( $params->{return_host}, 443 ) . $self->derive_full_url );
        }

        my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
        my $callback = URI::URL->new( $domain_host . $self->derive_url( action => 'meetings_global', task => 'facebook_connect', target => 0, additional => [] ) );

        my $result = Dicole::Utils::HTTP->post( 'https://graph.facebook.com/oauth/access_token', {
                code => $code,
                client_id => $self->SOCIAL_APP_KEYS->{facebook_key},
                client_secret => $self->SOCIAL_APP_KEYS->{facebook_secret},
                redirect_uri => $callback->as_string,
            } );

        my $data = eval {
            my $uri = URI->new("", "http");
            $uri->query( $result );
            my %params = $uri->query_form;
            my $result_data = { %params };

            my $me_url = URI::URL->new( 'https://graph.facebook.com/me' );

            $me_url->query_form( {
                    access_token => $result_data->{access_token},
                } );

            my $response = Dicole::Utils::HTTP->get( $me_url->as_string );

            return Dicole::Utils::JSON->decode( $response );
        };

        if ( $data && $data->{id} ) {
            $user->facebook_user_id( $data->{id} );
            $user->save;
            return $self->redirect( $params->{return_url} || '/meetings/login/' );
        }
        else {
            get_logger(LOG_APP)->error( "error while connecting to FB: $@ - $result" );
            return $self->redirect( $params->{cancel_url} || '/meetings/login/' );
        }
    }
    else {
        get_logger(LOG_APP)->error( "error getting code while connecting to FB" );
        return $self->redirect( '/meetings/login/' );
    }
}

sub facebook_redirect {
    my ( $self ) = @_;

    my $state_json = CTX->request->param('state');
    my $state = Dicole::Utils::JSON->decode( $state_json );
    my $to = $state->{to};
    my $redirect_uri = $state->{redirect_uri};

    die unless $to =~ /^(http...localhost|https...(.+\.|)meetin\.gs)/;

    my $code = CTX->request->param('code');

    my $to_uri = URI->new( $to );
    my %query = $to_uri->query_form;
    $to_uri->query_form( { %query, code => $code, redirect_uri => $redirect_uri } );

    return $self->redirect( "" . $to_uri );
}

sub generate_message {
    my ( $self ) = @_;

    my %types = ( success => MESSAGE_SUCCESS, error => MESSAGE_ERROR, warning => MESSAGE_WARNING );
    if ( defined $types{ CTX->request->param('type') } ) {
        Dicole::MessageHandler->add_message( $types{ CTX->request->param('type') }, CTX->request->param('text') );

        return "added " .CTX->request->param('type') .'('. $types{ CTX->request->param('type') } . ') : '. CTX->request->param('text');
    }
    else {
        return "USAGE: ?type=error|message|warning&text=something";
    }
}

sub sass {
    my ( $self ) = @_;

    my $file = CTX->request->param('path');

    die "security error" unless $file =~ /^\/css\//;
    die "security error" if $file =~ /\.\./;

    my $in = CTX->lookup_directory('html') . $file;

    my $out = File::Temp->new->filename;

    my $return = `/var/lib/gems/1.8/bin/sass $in $out 2>&1`;

    CTX->response->content_type( 'text/css; charset=utf8' );

    open F, "<$out" or die;
    my @lines = <F>;
    close F;

    unlink $out;

    return "/** sass $in $out **/\n/**\n$return\n**/\n\n" . join "", @lines;
}

sub simsalabim {
    my ( $self ) = @_;

    my $address = CTX->request->param('email');
    my $total = CTX->request->param('total');

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = Dicole::Utils::User->fetch_user_by_login_in_domain( $address, $domain_id );

    $self->_set_note_for_user( 'meetings_total_beta_invites', $total, $user );

    return "Set beta invite total to $total for " . Dicole::Utils::User->name( $user );
}

sub reset_guide {
    my ( $self ) = @_;

    my $guide = CTX->request->param('guide');
    die "security error" unless $guide;

    $self->_set_note_for_user( 'meetings_' . $guide . '_dismissed', 0 );

    return "$guide reset for current user";
}

sub reset_rudolf {
    my ( $self ) = @_;

    $self->_set_note_for_user( 'rudolf_greeting_dismissed', 0 );

    return "Rudolf reset for " . Dicole::Utils::User->name( CTX->request->auth_user );
}

sub removed_from_meeting {
    my ($self) = @_;

    my $meeting_name = CTX->request->param('removed_from');

    Dicole::MessageHandler->add_message(MESSAGE_ERROR, $self->_nmsg('You were removed from meeting %1$s', [ $meeting_name ]));

    return $self->redirect( $self->derive_url( action => 'meetings', task => 'summary' ) );
}

sub invalidate_user_auth_tokens {
    my ($self) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    die "No such user:" . $address unless $user;

    Dicole::Utils::User->invalidate_user_authorization_keys( $user );

    return "Auth tokens invalidated for " . Dicole::Utils::User->name( $user );
}

sub remove_tos_accept {
    my ($self) = @_;

    my $address = CTX->request->param('email');

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "Could not find user for email $address" unless $user;

    $self->_set_note_for_user( 'tos_accepted' => undef, $user, $domain_id );

    return "Removed TOS accept for " . Dicole::Utils::User->name( $user );
}

sub disable_mailing_list {
    my ($self) = @_;

    my $address = CTX->request->param('email');

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "Could not find user for email $address" unless $user;

    $self->_set_note_for_user( 'meetings_mailing_list_disabled', time, $user );
    $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', CTX->request->param('reason'), $user ) if CTX->request->param('reason');

    return "Disabled mailing list for " . Dicole::Utils::User->name( $user );
}

sub enable_mailing_list {
    my ($self) = @_;

    my $address = CTX->request->param('email');

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "Could not find user for email $address" unless $user;

    $self->_set_note_for_user( 'meetings_mailing_list_disabled', undef, $user );
    $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', undef, $user );

    return "Enabled mailing list for " . Dicole::Utils::User->name( $user );
}

sub unsubscribe_from_promo_list {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    $self->_set_note_for_user( 'meetings_mailing_list_disabled', time, $user );
    $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', CTX->request->param('reason'), $user ) if CTX->request->param('reason');

    Dicole::MessageHandler->add_message(MESSAGE_SUCCESS, $self->_nmsg("You have been removed from the mailing list!"));

    return $self->redirect( $self->derive_url( task => 'detect' ) );
}

sub enable_ical_emails {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    $self->_set_note_for_user( 'meetings_disable_ical_emails', undef, $user );

    Dicole::MessageHandler->add_message(MESSAGE_SUCCESS, $self->_nmsg("You will again receive iCal emails!"));

    return $self->redirect( $self->derive_url( task => 'detect' ) );
}

sub disable_ical_emails {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    $self->_set_note_for_user( 'meetings_disable_ical_emails', time, $user );

    Dicole::MessageHandler->add_message(MESSAGE_SUCCESS, $self->_nmsg("You will no longer receive iCal emails!"));

    return $self->redirect( $self->derive_url( task => 'detect' ) );
}

sub disable_email_upload_notifications {
    my ($self) = @_;

    my $user = CTX->request->auth_user_id && CTX->request->auth_user
        or die "security error";

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    $self->_set_note_for_user(denied_email_notifications_of_received_emails => 1, $user, $domain_id);

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('Disabled email processing notifications.') );

    return $self->redirect( $self->derive_url( task => 'detect' ) );
}

sub toggle_ical_emails {
    my ($self) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $new = $self->_get_note_for_user( meetings_disable_ical_emails => $user, $domain_id ) ? 0 : time;
    $self->_set_note_for_user( meetings_disable_ical_emails => $new, $user, $domain_id );

    return "Ical emails for user " . Dicole::Utils::User->name( $user ) . " are now " . ( $new ? 'DISABLED' : 'ENABLED' );
}

sub make_user_developer {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $new = $self->_get_note_for_user( developer => $user, $domain_id ) ? 0 : 1;
    $self->_set_note_for_user( developer => $new, $user, $domain_id );

    return "Set user developer status to $new for " . Dicole::Utils::User->name( $user );
}

sub log_in_as {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    die "could not find user with address $address" unless $user;
    die "you are not a developer" unless $self->_get_note_for_user( developer => CTX->request->auth_user, $domain_id );

    return $self->redirect( $self->derive_url(
        task => 'detect', target => 0, additional => [],
        params => { dic => Dicole::Utils::User->temporary_authorization_key( $user ) }
    ) );
}

sub mobile_redirect {
    my ( $self ) = @_;

    my $type = CTX->request->param('redirect_type');

    if ( ! CTX->request->param('disable_desktop') && ! ( CTX->request->user_agent =~ /iPhone|iPad|Android|Lumia/i ) ) {
         return $self->redirect(
            $self->derive_url( action => 'meetings_raw', task => 'offer_desktop', params => {
                redirect_type =>  CTX->request->param('redirect_type'),
                redirect_host =>  CTX->request->param('redirect_host'),
                meeting_id => CTX->request->param('meeting_id') || 0,
            } )
        );
    }

    if ( $type eq 'web' ) {
        my $host = CTX->request->param('redirect_host');
        my $uri = URI::URL->new( $host );
        $uri->query_form( { dic => CTX->request->param('dic'), redirect_to_meeting => CTX->request->param('meeting_id') || 0, user_id => CTX->request->auth_user_id } );

        return $self->redirect( $uri->as_string );
    }
    elsif ( $type eq 'app' ) {
        my $uri = URI->new( 'meetings://' );
        $uri->query_form( { dic => CTX->request->param('dic'), redirect_to_meeting => CTX->request->param('meeting_id') || 0, user_id => CTX->request->auth_user_id } );
        return $self->redirect( $uri->as_string );
    }
    else {
        die "unknown mobile type";
    }
}

sub force_user_ip {
    my ($self) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $ip = CTX->request->param('ip');

    $self->_set_note_for_user( meetings_force_ip => $ip, $user, $domain_id );

    return "IP is now set to resolve as ". ($ip || "the real ip" ) ." for further requests of user " . Dicole::Utils::User->name( $user );
}

sub toggle_beta_pro {
    my ($self) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $old = $self->_get_note_for_user( 'meetings_beta_pro', $user );
    $self->_set_note_for_user( 'meetings_beta_pro', $old ? 0 : 1, $user );

    $self->_calculate_user_is_pro( $user, $domain_id );

    return "Beta Pro status " . ( $old ? 'disabled' : 'enabled' ) . " for user " . Dicole::Utils::User->name( $user );
}

sub reset_accept_button {
    my ($self) = @_;

    my $meeting = $self->_ensure_meeting_object( CTX->request->param('meeting_id') );
    $self->_set_note_for_meeting( 'matchmaking_accept_dismissed', 0, $meeting );

    return "yay";
}

sub toggle_partner_authorization {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;
    my $partner = $self->param('partner');

    my $old = $self->_get_note_for_user( 'login_allowed_for_partner_' . $partner->id, $user, $partner->domain_id );

    $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => $old ? 0 : time, $user, $partner->domain_id );

    return $partner->name . " partner authorization status " . ( $old ? 'disabled' : 'enabled' ) . " for user " . Dicole::Utils::User->name( $user );
}

sub set_theme_params {
    my ($self) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $save = 0;
    my @done = ();

    my @keys = qw(
        theme
        theme_footer
        theme_header
        theme_header_image
        theme_background_image
        theme_background_color
        theme_background_position
    );

    for my $key ( @keys ) {
        my $value = CTX->request->param( $key );
        next unless defined( $value );

        $self->_set_note_for_user( 'pro_' . $key => $value, $user, $domain_id, { skip_save => 1 } );
        push @done, "$key => $value";
        $save = 1;
    }

    if ( $save ) {
        $user->save;
        return "set these values for " . Dicole::Utils::User->name( $user ) . ': ' . join( ", ", @done );
    }
    else {
        return "You need to set up at least one of these values: " . join ( ", ", @keys );
    }
}

sub clear_free_trials {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $trials = CTX->lookup_object('meetings_trial')->fetch_group( {
        where => 'user_id = ?',
        value => [ $user->id ]
    } );

    for my $trial ( @$trials ) {
        next unless $trial->trial_type eq 'free_trial_30';
        $trial->remove;
    }

    $self->_calculate_user_is_pro( $user, $domain_id );

    return "Cleared free trials for " . Dicole::Utils::User->name( $user );
}

sub expire_free_trials {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $trials = CTX->lookup_object('meetings_trial')->fetch_group( {
        where => 'user_id = ?',
        value => [ $user->id ]
    } );

    for my $trial ( @$trials ) {
        next unless $trial->trial_type eq 'free_trial_30';
        $trial->start_date( 0 );
        $trial->save;
    }

    $self->_calculate_user_is_pro( $user, $domain_id );

    return "Expired free trials for " . Dicole::Utils::User->name( $user );
}

sub extend_user_free_trial {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $days = CTX->request->param('days') || 30;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $trials = CTX->lookup_object('meetings_trial')->fetch_group( {
        where => 'user_id = ?',
        value => [ $user->id ]
    } );

    my $until = '';

    for my $trial ( @$trials ) {
        next unless $trial->trial_type eq 'free_trial_30';
        my $start_seconds_ago = time - $trial->start_date;
        if ( CTX->request->param('from_previous') ) {
            $trial->duration_days( $trial->duration_days + $days );
            $until = "$days days later than before"
        }
        else {
            my $start_days_ago = int( $start_seconds_ago / 60 / 60 / 24 ) + 1;
            $trial->duration_days( $start_days_ago + $days );
            $until = "in $days days";
        }

        $self->_set_note( trial_manually_extended_date => time, $trial, { skip_save => 1 } );
        $self->_set_note( trial_manually_extended_by => CTX->request->auth_user_id, $trial );

        $self->_calculate_user_is_pro( $user, $domain_id );

        last;
    }

    return "Could not find a trial for " . Dicole::Utils::User->name( $user ) unless $until;

    return "Extended free trial for " . Dicole::Utils::User->name( $user ) . " to end $until";
}

sub force_user_email_change {
    my ($self) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $new_email = CTX->request->param('new_email');
    return "This endpoint requires a new_email parameter!" unless $new_email;

    if ( $self->_fetch_user_for_email( $new_email, $domain_id ) ) {
        return "ERROR: could not change user $address email because the new_email is already taken: $new_email";
    }

    $address ||= $user->email;

    $user->login_name( $new_email ) if $user->login_name eq $user->email;
    $user->email( $new_email );
    $user->save;

    return "Changed user $address to email $new_email";
}

sub update_dropbox {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user =  CTX->request->auth_user;

    return CTX->lookup_action('meetings_api')->e( sync_user_meetings_with_dropbox => { user => $user, domain_id => $domain_id } );
}

sub mock_endpoint {
    my ( $self ) = @_;

    return CTX->request->param('message');
}

sub flush_user_rsvp_reminders {
    my ( $self ) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $logs = CTX->lookup_action('meetings_api')->e( send_pending_rsvp_reminder_emails => {
            domain_id => $domain_id,
            limit_to_users => [ $user->id ],
            wait_seconds => 1,
    } );

    push @$logs, '( for ' . $user->email .')';

    return Dicole::Utils::HTML->text_to_html( join "\n", @$logs );
}

sub flush_user_scheduling_reminders {
    my ( $self ) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $logs = CTX->lookup_action('meetings_api')->e( send_pending_scheduling_reminder_emails => {
            domain_id => $domain_id,
            limit_to_users => [ $user->id ],
            wait_seconds => 1,
    } );

    push @$logs, '( for ' . $user->email .')';

    return Dicole::Utils::HTML->text_to_html( join "\n", @$logs );
}

sub flush_startup_domains_cache {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    CTX->lookup_action('meetings_api')->e( check_startup_statuses => { domain_id => $domain_id } );

    my $users = CTX->lookup_object('user')->fetch_group({
        where => 'notes like "%startup_pro_enabled%"',
    });

    $users = Dicole::Utils::User->filter_list_to_domain_users( $users, $domain_id );

    my @user_info_list = ();
    for my $user ( @$users ) {
        next unless $self->_get_note_for_user( startup_pro_enabled => $user, $domain_id );
        push @user_info_list, Dicole::Utils::User->email_with_name( $user );
    }

    my $output = '' .
        "---- Startup domains:\n\n" .
        join( "\n", @{ $self->_get_startup_domains } ) .
        "\n\n---- Users who have received startup pro:\n\n" .
        join( "\n", @user_info_list );

    return "<pre>" . Dicole::Utils::HTML->encode_entities( $output ) . "</pre>";
}

sub undisable_meeting_suggestions {
    my ( $self ) = @_;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $address ? $self->_fetch_user_for_email( $address, $domain_id ) : CTX->request->auth_user;

    my $suggestions = $self->_get_user_meeting_suggestions( $user, $domain_id );

    for my $sugg ( @$suggestions ) {
        $sugg->disabled_date(0);
        $sugg->save;
    }

    return "Undisabled meeting suggestions for " . Dicole::Utils::User->name( $user );
}

sub compile_emails {
    my ( $self ) = @_;

    $self->_limit_to_us;

    my $return = `sudo /usr/local/src/dicole-crmjournal/bin/compile_meetings_emails`;
    # This can not be part of the previous one as backticks wait for all child processes to finish
    # and we need the server to stay alive long enough for the response to be served
    system "sudo /usr/local/src/dicole-crmjournal/bin/delayed_restart";

    CTX->response->content_type( 'text/plain; charset=utf8' );

    return "$return";
}

sub unsubscribe_user_from_all_current_meetings {
    my ( $self ) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "No such user found: $address" unless $user;

    my $meetings = [];

    my $pos = $self->_get_user_meeting_participation_objects_in_domain( $user, $domain_id );
    for my $po ( @$pos ) {
        next if $self->_get_note_for_meeting_user( 'disable_emails', $po->event_id, $po->user_id, $po);

        $self->_set_note_for_meeting_user( 'disable_emails', time, $po->event_id, $po->user_id, $po, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( 'disable_emails_foced_by', CTX->request->auth_user_id, $po->event_id, $po->user_id, $po );

        push @$meetings, $self->_ensure_meeting_object( $po->event_id );
    }

    my @names = map { $self->_meeting_title_string( $_ ) } @$meetings;
    return "Unsubscribed user $address from the following meetings: " . join( ", ", @names );
}

sub undo_unsubscribe_user_from_all_current_meetings {
    my ( $self ) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "No such user found: $address" unless $user;

    my $meetings = [];

    my $pos = $self->_get_user_meeting_participation_objects_in_domain( $user, $domain_id );
    for my $po ( @$pos ) {
        next unless $self->_get_note_for_meeting_user( 'disable_emails_foced_by', $po->event_id, $po->user_id, $po);

        $self->_set_note_for_meeting_user( 'disable_emails', 0, $po->event_id, $po->user_id, $po, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( 'disable_emails_foced_by', undef, $po->event_id, $po->user_id, $po );

        push @$meetings, $self->_ensure_meeting_object( $po->event_id );
    }

    my @names = map { $self->_meeting_title_string( $_ ) } @$meetings;

    return "Undoed unsubscribe for user $address in the following meetings: " . join( ", ", @names );
}

sub send_test_agenda_reminder {
    my ( $self ) = @_;

    $self->_limit_to_us;

    return "You need to provide a meeting_id parameter" unless CTX->request->param('meeting_id');

    CTX->lookup_action('meetings_api')->e( send_pending_before_emails => {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        dry_test => 1,
        limit_to_meetings => [ CTX->request->param('meeting_id') ],
    } );

    return "Sent agenda reminder to meeting_id " . CTX->request->param('meeting_id') . " IF it was within 7 days, did not belong to an event, was not a draft AND the agenda was empty";
}

sub send_test_action_points_reminder {
    my ( $self ) = @_;

    $self->_limit_to_us;

    return "You need to provide a meeting_id parameter" unless CTX->request->param('meeting_id');

    CTX->lookup_action('meetings_api')->e( send_pending_action_points_incomplete_emails => {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        dry_test => 1,
        limit_to_meetings => [ CTX->request->param('meeting_id') ],
    } );

    return "Sent action points reminder to meeting_id " . CTX->request->param('meeting_id') . " IF it had ended, was not a draft AND the action points was empty";
}

sub send_test_digest {
    my ( $self ) = @_;

    $self->_limit_to_us;

    my $address = CTX->request->param('email');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = $self->_fetch_user_for_email( $address, $domain_id );

    return "No such user found: $address" unless $user;

    return "You need to provide a meeting_id parameter" unless CTX->request->param('meeting_id');

    CTX->lookup_action('meetings_api')->e( send_pending_digest_emails => {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        dry_test => 1,
        skip_stacking => 1,
        limit_to_meetings => [ CTX->request->param('meeting_id') ],
        limit_to_users => [ $user->id ],
    } );

    return "Sent digest of meeting_id " . CTX->request->param('meeting_id') . " to user " . $user->email . " IF there was something to send (own actions are never sent!)";
}

sub start_saml2_login {
    my ( $self ) = @_;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $provider = $self->param( 'provider' ) || 'lahixcustxz';
    $provider =~ s/\.xml$//;

    my $ual = CTX->request->param('url_after_login');
    my $relay_state = $ual ? { url_after_login => $ual } : undef;

    my $response = eval { Dicole::Utils::Gearman->do_task( saml2_get_login_url => {
        domain => CTX->request->server_name,
        provider => $provider,
        relay_state => $relay_state ? Dicole::Utils::JSON->encode( $relay_state ) : '',
    } ) };

    my $url = $response->{result};

    if ( $url && $url =~ /^https/ ) {
        return $self->redirect( $url );
    }
    else {
        get_logger(LOG_APP)->error("Failed to initiate saml login for $provider. Error was '$@' and the response was: " . Data::Dumper::Dumper( $response ));
        my $login_url = $self->derive_url(
            action => 'meetings', task => 'login', target => 0, additional => [],
            params => { url_after_login => $ual, skip_saml2 => 1 }
        );
        return $self->redirect( $login_url );
    }
}

sub saml2ac {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $provider = $self->param( 'provider' ) || 'lahixcustxz';
    $provider =~ s/\.xml$//;

    my $data = {};
    if ( CTX->request->param('SAMLResponse') ) {
        $data->{SAMLResponse} = CTX->request->param('SAMLResponse');
    }
    if ( CTX->request->param('SAMLRequest') ) {
        $data->{SAMLRequest} = CTX->request->param('SAMLRequest');
    }

    my $response = eval { Dicole::Utils::Gearman->do_task( saml2_assert_body => {
        domain => CTX->request->server_name,
        provider => $provider,
        request_data => $data,
    } ) };

    if ( $@ ) {
        get_logger(LOG_APP)->error('Error while doing saml2 assert body task: ' . $@ );
        undef $response;
    }
    elsif ( $response->{error} ){
        get_logger(LOG_APP)->error('Error while doing asserting saml2 body: ' . Dicole::Utils::JSON->encode_pretty( $response->{error} ) );
        undef $response;
    }
    else {
        $response = $response->{result};
    }

    if ( ! $response ) {
        return "Valitettavasti sisäänkirjautumisessa on väliaikainen häiriö. Ole hyvä ja yritä hetken kuluttua uudelleen. Mikäli ongelma jatkuu pidempään kuin 15 minuuttia, ota yhteyttä tukeen.";
    }

    if ( $response->{type} eq 'authn_response' ) {
        my $email = $response->{user}->{name_id};
        my $user = eval { $self->_fetch_user_for_email( $email, $domain_id ) };
        my $relay_state = CTX->request->param('RelayState');
        my $ual = '';
        if ( $relay_state ) {
            $ual = eval { Dicole::Utils::JSON->decode( $relay_state )->{url_after_login} };
        }

        if ( $user && $self->_get_note_for_user( meetings_saml2_provider => $user, $domain_id ) eq $provider ) {
            my $login_url = $self->derive_url(
                action => 'meetings', task => 'login', target => 0, additional => [],
                params => {
                    url_after_login => $ual,
                    dic => Dicole::Utils::User->temporary_authorization_key( $user )
                }
            );
            return $self->redirect( $login_url );

        }
        else {
            my $message = 'Valitettavasti käyttäjää "'.$email.'" ei ole rekisteröity palveluun. Ota yhteyttä esimieheesi.';

            my $login_url = $self->derive_url(
                action => 'meetings', task => 'login', target => 0, additional => [],
                params => { url_after_login => $ual, skip_saml2 => $user ? 1 : 2, error_message => $message }
            );
            return $self->redirect( $login_url );
        }
    }
    else {
        return "Unhandled type: " . $response->{type};
    }
}

sub _limit_to_us {
    my $die = CTX->request->auth_user_id ? 0 : 1;
    $die ||= CTX->request->auth_user->email =~ /\@(meetin\.gs|dicole\.com)$/ ? 0 : 1;
    $die ||= CTX->request->auth_user->email =~ /demo\@meetin\.gs$/ ? 1 : 0;
    $die = 0 if CTX->request->auth_user->email =~ /^ext.antti.vahakotamaki.lahixcustxz.fi$/i;

    die 'you are not authorized to do this. contact antti@meetin.gs to know why' if $die;
}

1;
