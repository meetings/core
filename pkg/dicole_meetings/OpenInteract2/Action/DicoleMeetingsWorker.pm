package OpenInteract2::Action::DicoleMeetingsWorker;

use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Utils::Gearman;
use Dicole::Utils::Mail;
use Dicole::Utils::Text;
use Time::HiRes;
use Geo::IP;
use WWW::Pusher;
use List::Util;
use URI::Encode qw();
use Digest::MD5;

# TODO: refactor functions to base classes which just get loaded and SUPER searched for hashes..
# NOTE: if function name ends with _\d+ it is stripped and used as timeout
# NOTE: so if you want to end your function with a number and don't want timeout, use _0 ;)
# NOTE: gearman has a maximum of 255 timeout.

sub FG_FUNCTIONS { {
    test_fg_gearman_1 => sub {
        return { success => 1 };
    },
    add_trail_1 => sub {
        my ( $self, $params ) = @_;

        return { sent => 1 };

        my $session_id = $params->{session_id};
        my $user_id = $params->{user_id};

        my $extra_params = $params->{extra_params} || {};

        my $trail_data = {
            event => $params->{event},
            epoch => $params->{epoch},
            ip => $params->{ip} || '',
            title => $params->{title} || '',
            location => $params->{location} || '',
            referrer => $params->{referrer} || '',
            initial_referrer => $params->{initial_referrer} || '',
            user_agent => $params->{user_agent} || '',
            extra_params => $extra_params,
        };

        my $sent = 0;
        if ( $user_id ) {
            my $user = Dicole::Utils::User->ensure_object( $user_id );
            $user = $self->_fetch_user_for_email( $user->email, $params->{domain_id}, $user );

            $trail_data->{current_user_name} = Dicole::Utils::User->name( $user );

            if ( $user && $user->email ) {
                Dicole::Utils::Gearman->dispatch_task( send_trail_for_user => {
                        user_id => $user->id,
                        data => Dicole::Utils::JSON->encode( $trail_data ),
                        session_id => $session_id,
                    } );

                # cache is used for throttling
                Dicole::Cache->fetch_or_store( 'flushed_pending_trails_for_' . $session_id, sub {
                        Dicole::Utils::Gearman->dispatch_task( flush_pending_trails_for_session => {
                                session_id => $session_id,
                                user_id => $user->id,
                            } );
                        return 1;
                    }, { domain_id => $params->{domain_id}, no_group_id => 1, expires => 60*5 } );

                # cache is used for throttling
                Dicole::Cache->fetch_or_store( 'updated_user_data_in_trackers_' . $user->id, sub {
                        Dicole::Utils::Gearman->dispatch_task( update_user_data_in_trackers => {
                                user_id => $user->id,
                                ip => $params->{ip},
                                initial_referrer => $params->{initial_referrer},
                            } );
                        return 1;
                    }, { domain_id => $params->{domain_id}, no_group_id => 1, expires => 60*5 } );

                $sent = 1;
            }
        }

        unless ( $sent ) {
            CTX->lookup_object('meetings_pending_trail')->new({
                session_id => $session_id,
                user_id => $user_id,
                payload => Dicole::Utils::JSON->encode( $trail_data || {} ),
            })->save;
        }

        return { sent => $sent }
    },
    meetme_list_5 => sub {
        my ( $self, $params ) = @_;

        my $app = $self->_application_for_api_key( $params->{app_id}, $params->{domain_id} );
        my $domain_host = $app->{partner_id} ? $self->_get_host_for_partner( $app->{partner_id}, 443 ) : $self->_get_host_for_domain( $params->{domain_id}, 443 );
        return '400' unless $app;

        my $list = $self->_application_csv_as_hash_list( $app );
        my $match_string = $params->{match} || '';

        my ( $match_key, $match_value ) = split( '=', $match_string, 2 );
        $match_value =~ s/^\s*(.*?)\s*$/$1/ if $match_value;

        my $valid_list = [];

        for my $entry ( @$list ) {
            if ( $match_key ) {
                my $value = $entry->{ $match_key } || '';
                $value =~ s/^\s*(.*?)\s*$/$1/;
                next unless lc( $value || '' ) eq lc( $match_value || '' );
            }
            push @$valid_list, $entry;

            my $email = delete $entry->{EMAIL};
            next unless $email;

            my $user = $self->_fetch_user_for_email( $email, $params->{domain_id} );
            next unless $user;

            $self->_fill_application_entry_for_user( $app, $entry, $user, $params->{image_size}, $domain_host );
        }

        return $valid_list;
    },
    meetme_url_for_token_2 => sub {
        my ( $self, $params ) = @_;

        my $app = $self->_application_for_api_key( $params->{app_id}, $params->{domain_id} );
        my $domain_host = $app->{partner_id} ? $self->_get_host_for_partner( $app->{partner_id} ) : $self->_get_host_for_domain( $params->{domain_id}, 443 );
        return '400' unless $app;

        my $list = [];
        if ( $app->{csv_url} ) {
            $list = $self->_application_csv_as_hash_list( $app );
        }
        elsif ( $app->{token_api_url} ) {
            my $url = URI::URL->new( $app->{token_api_url} );
            $url->query_form( { $url->query_form, token => $params->{user_token} } );
            my $data_json = Dicole::Utils::HTTP->get( $url->as_string );
            my $data = eval { Dicole::Utils::JSON->decode( $data_json ) };
            get_logger(LOG_APP)->error( $@ ) if $@;
            return '500' unless $data;
            $list = [ $data ];
        }
        else {
            return '500';
        }

        for my $entry ( @$list ) {
            next unless $entry->{TOKEN} && $entry->{TOKEN} eq $params->{user_token};
            my $email = delete $entry->{EMAIL};
            return $entry unless $email;
            my $user = $self->_fetch_user_for_email( $email, $params->{domain_id} );
            return $entry unless $user;
            $self->_fill_application_entry_for_user( $app, $entry, $user, $params->{image_size}, $domain_host );

            return $entry;
        }
        return '404';
    },
    spops_fetch_group => sub {
        my ( $self, $params ) = @_;
        my $object_type = $params->{object_type};

        my $sql = $params->{sql};
        my $from = $params->{from};
        my $where = $params->{where};
        my $value = $params->{value};
        my $order = $params->{order};
        my $limit = $params->{limit};

        my $object_info = $self->_resolve_spops_object_type_info( $object_type );

        my $objects = $object_info->{class}->fetch_group( {
            sql => $sql,
            from => $from,
            where => $where,
            value => $value,
            order => $order,
            limit => $limit,
        } );

        return { result => [ map { $self->_spops_object_to_json_data( $_, $object_info ) } @$objects ] };
    },
    spops_fetch => sub {
        my ( $self, $params ) = @_;

        my $object_type = $params->{object_type};
        my $object_id = $params->{object_id};

        my $object_info = $self->_resolve_spops_object_type_info( $object_type );
        my $object = $object_info->{class}->fetch( $object_id );

        return { result => $self->_spops_object_to_json_data( $object, $object_info ) };
    },
    # THESE ARE UNTESTED
    oauth2_auth => sub {
        my ( $self, $params ) = @_;

        my $client_id = $params->{client_id};
        my $redirect_uri = $params->{redirect_uri};
        my $response_type = $params->{response_type};
        my $scope = $params->{scope};
        my $state = $params->{state};
        my $force_confirm = $params->{force_confirm};
        my $email_hint = $params->{email_hint};

        my $app = $self->_ensure_application_object( $client_id );
        return { error => { code => 1, message => 'Unknown application ID' } } unless $app;

        # TODO: verify that redirect_url found in app

        my @chars = ('a'..'z','A'..'Z','0'..'9','_','-');
        my $code = join( "", map( { $chars[rand @chars] } (1..16)));

        my $oauth2_code = CTX->lookup_object('meetings_oauth2_code')->new({
            code => $code,
            client_id => $client_id,
            redirect_uri => $redirect_uri,
            scope => $scope,
            state => $state,
            force_confirm => $force_confirm,
            email_hint => $email_hint,
        });

        $oauth2_code->save;

        return { result => { code => $oauth2_code->code, confirm_url => 'https://meetin.gs/oauth2/confirm?code=' . URI::Encode::uri_encode( $oauth2_code->code ) } };
    },
    oauth2_confirm => sub {
        my ( $self, $params ) = @_;

        my $code = $params->{code};
        my $user_id = $params->{user_id};
        my $oauth2_code = CTX->lookup_object('meetings_oauth2_code')->fetch_group( { where => 'code = ?', value => [ $code ] } )->[0];
        my $user = Dicole::Utils::User->ensure_object( $user_id );

        $oauth2_code->user_id( $user->id );
        $oauth2_code->confirmed_date( time );
        $oauth2_code->save;

        my $query_param_uri = URI::URL->new( $oauth2_code->redirect_uri );
        my $original_query = $query_param_uri->query_form || {};
        $query_param_uri->query_form( { %$original_query, code => $oauth2_code->code, state => $oauth2_code->state } );
        $query_param_uri = $query_param_uri->as_string;

        my $fragment_param_uri = $oauth2_code->redirect_uri;
        $fragment_param_uri .= '#code=' . URI::Encode::uri_encode( $oauth2_code->code ) . '&state=' .  URI::Encode::uri_encode( $oauth2_code->state );

        return { result => {
            redirect_uri => $oauth2_code->redirect_uri,
            code => $oauth2_code->code,
            state => $oauth2_code->state,
            query_param_uri => $query_param_uri,
            fragment_param_uri => $fragment_param_uri,
        } }
    },
    oauth2_token => sub {
        my ( $self, $params ) = @_;

        my $client_id = $params->{client_id};
        my $client_secret = $params->{client_secret};
        my $redirect_uri = $params->{redirect_uri};
        my $grant_type = $params->{grant_type}; # NOTE: this is just ignored as type is inferred from other params

        # These are the different ways an user can get a token
        my $code = $params->{code};

        my $refresh_token = $params->{refresh_token};

        my $email = $params->{email};
        my $pin = $params->{pin};
        my $password = $params->{password};

        my $oauth2_refresh_token = undef;

        if ( $code ) {
            my $app = $self->_ensure_application_object( $client_id );
            return { error => { code => 1, message => 'Invalid client secret' } } unless $app->secret eq $client_secret;

            my $oauth2_code = CTX->lookup_object('meetings_oauth2_code')->fetch_group( { where => 'code = ?', value => [ $code ] } )->[0];
            return { error => { code => 2, message => 'Code client_id mismatch' } } unless $oauth2_code->client_id eq $client_id;
            return { error => { code => 3, message => 'Code redirect_uri mismatch' } } unless $oauth2_code->redirect_uri eq $redirect_uri;

            # TODO: create refresh and access tokens + return
            my $user = Dicole::Utils::User->ensure_object( $oauth2_code->user_id );
            $oauth2_refresh_token = $self->_fetch_or_create_oauth2_refresh_token( $user, $oauth2_code->scope, $oauth2_code->client_id );
        }
        elsif ( $email ) {
            my $user = $self->_fetch_user_for_email( $email, $params->{domain_id} );
            my $scope = 'full';
            my $client_id = 0;

            if ( $pin ) {
                # TODO: check the pin
                return { error => { code => 11, message => 'invalid pin' } };
            }
            elsif ( $password ) {
                my $password_pair = CTX->lookup_action('user_manager_api')->e( create_plaintext_and_crypted_password => {
                    password => $password
                } );
                return { error => { code => 11, message => 'invalid password' } } unless $password_pair->[1] eq $user->password;
            }
            else {
                # TODO application specific limited autotokens
                my $app = $self->_ensure_application_object( $client_id );
                return { error => { code => 1, message => 'Invalid client secret' } } unless $app->secret eq $client_secret;
                return { error => { code => 99, message => 'Your app does not have the right to access these rights for this user' } };
                $scope = $app->granted_scope;
                $client_id = $app->client_id;
            }

            $oauth2_refresh_token = $self->_fetch_or_create_oauth2_refresh_token( $user, $scope, $client_id );
        }
        elsif ( $refresh_token ) {
            $oauth2_refresh_token = CTX->lookup_object('meetings_oauth2_refresh')->fetch_group( { where => 'token = ?', value => [ $refresh_token ] } )->[0];
            return { error => { code => 2, message => 'Refresh token client_id mismatch' } }
                if $oauth2_refresh_token->client_id && $oauth2_refresh_token->client_id ne $client_id;
        }

        if ( $oauth2_refresh_token ) {
            $self->_return_oauth_credentials_for_refresh_token( $oauth2_refresh_token );
        }
        else {
            return { error => { code => 112, message => 'None of the valid codes, tokens or credentials were provided' } };
        }
    },
    public_job_check_lt_full_sync_10 => sub {
        my ( $self, $params ) = @_;
        my $dev = ( $params->{domain_id} == 76 ) ? '-dev' : '';
        my $domain = 'lahixcustxz' . $dev . '.meetin.gs';
        my $partner = $self->PARTNERS_BY_DOMAIN_ALIAS->{ $domain };

        my $window = (24+6)*60*60;
        my $latest = $self->_get_note( latest_agent_sync => $partner );

        if ( ! $latest ) {
            return { error => { code => 2, retry => 0, message => "No latest sync found at all" } };
        }

        my $passed = time - $latest;
        $passed = int( $passed / 60 / 60 * 100 ) / 100;

        if ( $latest + $window < time ) {
            return { error => { code => 1, retry => 0, message => "Latest sync was " . $passed . " hours ago" } };
        }

        return { result => "ok: " . $passed . " hours passed since last sync" };
    },
    request_login_email_5 => sub {
        my ( $self, $params ) = @_;

        my $host = $params->{return_host};
        my $type = $params->{redirect_type} || 'web';

        my $url = Dicole::URL->from_parts(
            domain_id => $params->{domain_id},
            partner_id => 0,
            action => 'meetings_global',
            task => 'mobile_redirect',
            target => 0,
            params => { redirect_type => $type, redirect_host => $host, meeting_id => 0 },
        );

        my $email = $params->{email};

        my $existing_user = $self->_fetch_user_for_email( $email, $params->{domain_id} );

        my $user = $existing_user;

        if ( ! $existing_user && $params->{allow_register} ) {
            $user = eval { $self->_fetch_or_create_user_for_email( $email, $params->{domain_id}, { language => $params->{lang}, timezone => $params->{time_zone} } ) };
            get_logger(LOG_APP)->error( $@ ) if $@;
            return { error => { code => 400, message => 'malformed email address' } } unless $user;
        }
        elsif ( ! $existing_user ) {
            return { error => { code => 2, message => 'could not find email!' } };
        }

        my $pin = '';
        if ( $user && $params->{include_pin} ) {
            $pin = $self->_generate_and_return_pin_code_for_user( $user, $params->{ip}, $params->{domain_id} );
        }

        eval {
            $self->_send_login_email(
                url => $url,
                email => $params->{email},
                pin_requested => $params->{include_pin} ? 1 : 0,
                pin => $pin,
                domain_id => $params->{domain_id},
                partner_id => 0,
            );
        };
        get_logger(LOG_APP)->error( $@ ) if $@;

        if ( $@ ) {
            if ( $existing_user || $params->{allow_register} ) {
                return { error => { code => 1, message => 'error while sending email!' } };
            }
            else {
                return { error => { code => 2, message => 'could not find email!' } };
            }
        }

        return { error => { code => 3, message => 'Could not request PIN. Please log in through the sent email link!' } } if $params->{include_pin} && ! $pin;

        return { result => 1 };
    },
    request_login_sms_5 => sub {
        my ( $self, $params ) = @_;

        my $host = $params->{return_host};
        my $type = $params->{redirect_type} || 'web';

        my $phone = $params->{phone};

        my $existing_user = eval{ $self->_fetch_user_for_phone( $phone, $params->{domain_id} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        my $user = $existing_user;

        if ( ! $existing_user && $params->{allow_register} ) {
            $user = eval { $self->_fetch_or_create_user_for_phone_and_name( $phone, '', $params->{domain_id}, { language => $params->{lang}, timezone => $params->{time_zone} } ) };
            get_logger(LOG_APP)->error( $@ ) if $@;
            return { error => { code => 400, message => 'malformed phone number' } } unless $user;
        }

        unless ( $user ) {
            return { error => { code => 2, message => 'Could not find user for ' . $phone . ' and allow_register is not specified' } };
        }

        my $pin = '';
        if ( $user && $params->{include_pin} ) {
            $pin = $self->_generate_and_return_pin_code_for_user( $user, $params->{ip}, $params->{domain_id} );
        }
        if ( ! $pin ) {
            return { error => { code => 3, message => 'Could not request PIN. Try again later.' } } if $params->{include_pin};
            return { error => { code => 10, message => 'SMS login requires include_pin' } };
        }

        $self->_queue_user_segment_event( $user, 'PIN SMS sent', { phone => $user->phone } );

        return { result => 10 } if $phone =~ /\#\#\#/;

        my $service_name = 'Meetin.gs';
        if ( $params->{app_version} && $params->{app_version} =~ /cmeet/i ) {
            $service_name = 'cMeet';
        }
        if ( $params->{app_version} && $params->{app_version} =~ /swipetomeet/i ) {
            $service_name = 'SwipeToMeet';
        }

        my $sms_content = join "\n\n", (
            $self->_ncmsg('%2$s PIN: %1$s', { user => $user }, [ $pin, $service_name ] ),
            $self->_ncmsg('This is a one time verification PIN for secure login to %1$s.', { user => $user }, [ $service_name ] )
        );

        $self->_send_user_sms( $user, $sms_content, { domain_id => $params->{domain_id}, log_data => { type => 'login_pin' } } );

        return { result => 1 };
    },
    login_with_google_code_5 => sub {
        my ( $self, $params ) = @_;

        my $domain_id = $params->{domain_id};

        my ( $at, $rt ) = eval { $self->_google_code_to_access_and_refresh_tokens( $params->{code}, $params->{redirect_uri} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        # TODO: handle error better
        return { error => { code => 1, message => 'Code verifying failed' } } unless $at;
        return { error => { code => 2, message => 'Refresh token not returned' } } unless $rt;
        my $data = eval { $self->_google_info_for_access_token( $at ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        # TODO: handle error better
        return { error => { code => 3, message => 'Information fetching failed' } } unless $data && $data->{id};

        my $existing =$self->_get_user_with_verified_service_account( 'google', $data->{id}, $domain_id );
        my $user = $existing ? Dicole::Utils::User->ensure_object( $existing->user_id ) : undef;

        if ( ! $user ) {
            $user = $self->_create_temporary_user( $domain_id );
            $user->timezone( $params->{time_zone} ) if $params->{time_zone};

            $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $rt, $user, $domain_id, { skip_save => 1 } );

            $user->first_name( $data->{given_name} );
            $user->last_name( $data->{family_name} );
            $user->save;

            $self->_add_user_service_account( $user, $domain_id, 'google', $data->{id}, 1 );
            $self->_add_user_service_account( $user, $domain_id, 'google_email', $data->{email}, $data->{verified_email} ? 1 : 0 ) if $data->{email};

            if ( my $pic = $data->{picture} ) {
                CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_url => {
                    user_id => $user->id,
                    domain_id => $domain_id,
                    url => $pic,
                } );
            }
        }

        return {
            user_id => $user->id,
            email_confirmed => $user->email ? 1 : 0,
            token => Dicole::Utils::User->permanent_authorization_key( $user ),
            tos_accepted => $self->_user_has_accepted_tos( $user, $domain_id ) ? 1 : 0,
        };
    },
    user_connect_google_code_5 => sub {
        my ( $self, $params ) = @_;

        my $domain_id = $params->{domain_id};

        my ( $at, $rt ) = eval { $self->_google_code_to_access_and_refresh_tokens( $params->{code}, $params->{redirect_uri} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        # TODO: handle error better
        return { error => { code => 1, message => 'Code verifying failed' } } unless $at;
        return { error => { code => 2, message => 'Refresh token not returned' } } unless $rt;

        my $data = eval { $self->_google_info_for_access_token( $at ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        # TODO: handle error better
        return { error => { code => 3, message => 'Information fetching failed' } } unless $data && $data->{id};

        my $existing = $self->_get_user_with_verified_service_account( 'google', $data->{id}, $domain_id );
        return { error => { code => 4, message => 'Google account already connected to a Meetin.gs user' } } if $existing;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        return { error => { code => 404, message => 'No such user' } } unless $user;

        $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $rt, $user, $domain_id );
        $self->_add_user_service_account( $user, $domain_id, 'google', $data->{id}, 1 );
        $self->_add_user_service_account( $user, $domain_id, 'google_email', $data->{email}, $data->{verified_email} ? 1 : 0 ) if $data->{email};

        return { result => 1 };
    },
    user_confirm_email_30 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $email = $params->{email};

        my $old_user = $self->_fetch_user_for_email( $email, $domain_id );
        if ( ! $old_user ) {
            my $verified_emails = $self->_fetch_user_verified_email_list( $user, $domain_id );
            for my $verified_email ( @$verified_emails ) {
                next unless lc( $verified_email ) eq $email;
                $self->_set_note_for_user( 'meetings_email_confirmed_by_google', time, $user, $domain_id, { skip_save => 1 } );

                $user->email( $verified_email );
                $user->save;

                return {
                    result => 1,
                };
            }
        }

        my $url = '';

        if ( ! $params->{include_pin} ) {
            return { error => { code => 555, message => 'not implemented yet without include_pin' } };
        }

        my $pin = '';
        if ( $params->{include_pin} ) {
            if ( $old_user ) {
                $pin = $self->_generate_and_return_pin_code_for_user( $old_user, $params->{ip}, $domain_id, { merge_user_id => $user->id } );
            }
            else {
                $pin = $self->_generate_and_return_pin_code_for_user( $user, $params->{ip}, $domain_id, { confirm_email => $email } );
            }
        }

        eval {
            $self->_send_login_email(
                url => $url,
                email => $email,
                user => $old_user || $user,
                pin_requested => $params->{include_pin} ? 1 : 0,
                pin => $pin,
                domain_id => $domain_id,
                partner_id => 0,
            );
        };
        if ( $@ ) {
            print "\n" . $@ . "\n"
        }

        return { error => { code => 1, message => 'PIN verification required. Sent email to user.' } } if $params->{include_pin};
        return { error => { code => 2, message => 'Email verification required. Sent email to user.' } };
    },
    user_confirm_phone_30 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $phone = $params->{phone};

        my $old_user = $self->_fetch_user_for_phone( $phone, $domain_id );

        my $url = '';

        if ( ! $params->{include_pin} ) {
            return { error => { code => 555, message => 'not implemented without include_pin' } };
        }

        my $pin = '';
        if ( $params->{include_pin} ) {
            if ( $old_user ) {
                $pin = $self->_generate_and_return_pin_code_for_user( $old_user, $params->{ip}, $domain_id, { merge_user_id => $user->id } );
                $user = $old_user;
            }
            else {
                $pin = $self->_generate_and_return_pin_code_for_user( $user, $params->{ip}, $domain_id, { confirm_phone => $phone } );
            }
        }

        $self->_queue_user_segment_event( $user, 'PIN SMS sent', { phone => $phone } );

        return { error => { code => 1, message => 'PIN verification required. SMS NOT SENT TO DEMO USER.' } } if $phone =~ /\#\#\#/;

        my $service_name = 'Meetin.gs';
        if ( $params->{app_version} && $params->{app_version} =~ /cmeet/i ) {
            $service_name = 'cMeet';
        }
        if ( $params->{app_version} && $params->{app_version} =~ /swipetomeet/i ) {
            $service_name = 'SwipeToMeet';
        }

        my $sms_content = join "\n\n", (
            $self->_ncmsg('%2$s PIN: %1$s', { user => $user }, [ $pin, $service_name ] ),
            $self->_ncmsg('This is a one time verification PIN for %1$s.', { user => $user }, [ $service_name ] )
        );

        $phone =~ s/\#.*//;

        $self->_send_sms( $phone, $sms_content, { log_data => { type => 'phone_confirm_pin' }, user => $user } );

        return { error => { code => 1, message => 'PIN verification required. Sent SMS to user.' } };
    },
    user_send_app_sms_20 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => { code => 1, message => 'user needs to have a phone number' } } unless $user && $user->phone;

        my $url = $self->_get_new_mobile_redirect_url_for_user(
            { redirect_to_app_store => 1, utm_source => 'app_download_sms' },
            $user, $domain_id
        );
        my $app_link = $self->_create_shortened_url( $url, $user, { type => 'app_download_sms' } );

        $self->_send_user_sms( $user, 'Install SwipeToMeet: ' . "\n\n" . $app_link, { domain_id => $domain_id, log_data => { type => 'app_link_sms' } } );

        return { result => 1 };
    },
    # I have no idea what legacy endpoint this is and if anyone uses it.. if ignores the passed in "code"..
    user_start_trial_20 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        $self->_create_free_trial_subscription( user => $user, promo_code => 'free_trial_30', domain_id => $domain_id, duration_days => 30 );

        return { result => 1 };
    },
    user_start_free_trial_20 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => { code => 1, message => 'Free trial has already expired' } } if $self->_user_free_trial_has_expired( $user, $domain_id );

        $self->_create_free_trial_subscription( user => $user, promo_code => 'free_trial_30', domain_id => $domain_id, duration_days => 30 );

        return { result => { success => 1 } };
    },
    send_pro_features_email_5 => sub {
        my ( $self, $params ) = @_;
        my $domain_id = $params->{domain_id};
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );
        my $upgrade_url = Dicole::URL->from_parts(
            domain_id => $params->{user_id}, target_id => 0,
            action => 'meetings', task => 'upgrade',
        );
        $upgrade_url = $self->_generate_authorized_uri_for_user( $domain_host . $upgrade_url, $user, $params->{domain_id} );

        $self->_send_partner_themed_mail(
            user => $user,
            domain_id => $params->{domain_id},
            partner_id => 0,
            group_id => 0,

            template_key_base => 'meetings_mobile_pro_reminder_request',
            template_params => {
                upgrade_url => $upgrade_url,
            },
        );

        return { result => { success => 1 } };
    },
    verify_token_for_user_3 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->fetch_by_authorization_key_in_domain(
            $params->{token}, $params->{domain_id}
        );

        return { result => ( $user && $user->id == $params->{user_id} ) ? 1 : 0 };
    },
    verify_pin_for_user_30 => sub {
        my ( $self, $params ) = @_;

        my $user = $params->{phone} ? eval { $self->_fetch_user_for_phone( $params->{phone}, $params->{domain_id} ) } : undef;
        get_logger(LOG_APP)->error( $@ ) if $@;
        $user ||= $params->{email} ? eval { $self->_fetch_user_for_email( $params->{email}, $params->{domain_id} ) } : undef;
        get_logger(LOG_APP)->error( $@ ) if $@;
        $user ||= $params->{user_id} ? Dicole::Utils::User->ensure_object( $params->{user_id} ) : undef;

        return { error => { code => 2, message => 'no such user' } } unless $user;

        my $demo_user = ( ( ( $user->phone || '') =~ /\#\#\#/ ) || ( lc( $user->email || '' ) =~ /demo\@meetin\.gs$/ ) ) ? 1 : 0;

        my $fail_count = $self->_get_note_for_user( meetings_pin_failure_count => $user, $params->{domain_id} );
        my $fail_epoch = $self->_get_note_for_user( meetings_pin_failure_epoch => $user, $params->{domain_id} );
        my $fail_pin = $self->_get_note_for_user( meetings_pin_failure_pin => $user, $params->{domain_id} );

        if ( $fail_count && ! $demo_user ) {
            $fail_count = 5 if $fail_count > 5;
            my $quarantine = 5 ** $fail_count;
            if ( $fail_epoch + $quarantine > time ) {
                return { error => { code => 3, message => 'too many recent pin failures' } };
            }
        }

        my $valid_pin_object = $self->_check_and_use_pin_code_for_user( $params->{pin}, $user, $params->{domain_id} );

        if ( ! $valid_pin_object ) {
            if ( $params->{pin} eq '1234' && $demo_user ) {
                return { result => {
                    user_id => $user->id,
                    email_confirmed => $user->email ? 1 : 0,
                    phone_confirmed => $user->phone ? 1 : 0,
                    token => Dicole::Utils::User->permanent_authorization_key( $user ),
                    tos_accepted => $self->_user_has_accepted_tos( $user, $params->{domain_id} ) ? 1 : 0,
                } };
            }

            if ( $self->_check_if_pin_just_expired_or_used_for_user( $params->{pin}, $user, $params->{domain_id} ) ) {
                return { error => { code => 4, message => 'pin has either already been used or expired' } };
            }

            $fail_count += 1 if $params->{pin} ne $fail_pin;
            $self->_set_note_for_user( meetings_pin_failure_count => $fail_count, $user, $params->{domain_id}, { skip_save => 1 } );
            $self->_set_note_for_user( meetings_pin_failure_epoch => time, $user, $params->{domain_id}, { skip_save => 1 } );
            $self->_set_note_for_user( meetings_pin_failure_pin => $params->{pin}, $user, $params->{domain_id} );

            return { error => { code => 1, message => 'wrong pin' } };
        }

        if ( my $email = $self->_get_note( confirm_email => $valid_pin_object ) ) {
            $self->_set_note_for_user( meetings_email_confirmed_by_pin => time, $user, $params->{domain_id}, { skip_save => 1 } );
            $user->email( $email );
        }
        if ( my $phone = $self->_get_note( confirm_phone => $valid_pin_object ) ) {
            $self->_set_note_for_user( meetings_phone_confirmed_by_pin => time, $user, $params->{domain_id}, { skip_save => 1 } );
            $user->phone( $phone );
        }
        elsif ( my $merge_user_id = $self->_get_note( merge_user_id => $valid_pin_object ) ) {
            my $from_user = Dicole::Utils::User->ensure_object( $merge_user_id );
            $user = $self->_merge_temp_user_to_user( $from_user, $user, $params->{domain_id} );
        }

        $self->_set_note_for_user( meetings_pin_failure_count => undef, $user, $params->{domain_id}, { skip_save => 1 } );
        $self->_set_note_for_user( meetings_pin_failure_epoch => undef, $user, $params->{domain_id}, { skip_save => 1 } );
        $self->_set_note_for_user( meetings_pin_failure_pin => undef, $user, $params->{domain_id} );

        $self->_ensure_first_app_login_recorded_for_user( $user, $params );

        return { result => {
            user_id => $user->id,
            email_confirmed => $user->email ? 1 : 0,
            phone_confirmed => $user->phone ? 1 : 0,
            token => Dicole::Utils::User->permanent_authorization_key( $user ),
            tos_accepted => $self->_user_has_accepted_tos( $user, $params->{domain_id} ) ? 1 : 0,
        } };
    },
    verify_facebook_code_3 => sub {
        my ( $self, $params ) = @_;

        my $code = $params->{code};
        my $redirect_uri = $params->{redirect_uri};
        my $data = undef;
        eval {
            my $at = $self->_facebook_code_to_access_token( $code, $redirect_uri );
            my $data = $self->_facebook_info_for_access_token( $at );
        };
        get_logger(LOG_APP)->error( $@ ) if $@;
        return { error => { code => 10, message => 'invalid code' } } unless $data && $data->{id};

        my $user = eval { Dicole::Utils::User->fetch_user_by_facebook_uid_in_domain( $data->{id}, $params->{domain_id} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { result => { facebook_uid => $data->{id} } } unless $user;

        return { result => {
            user_id => $user->id,
            email_confirmed => $user->email ? 1 : 0,
            token => Dicole::Utils::User->permanent_authorization_key( $user ),
            tos_accepted => $self->_user_has_accepted_tos( $user, $params->{domain_id} ) ? 1 : 0,
        } };
    },
    remove_user_account_15 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $user_data = $self->_gather_user_info( $user, -1, $params->{domain_id} );

        $self->_set_note_for_user( deleted_user => time, $user, $params->{domain_id}, { skip_save => 1 } );
        $self->_set_note_for_user( deleted_user_object_phone => $user->phone, $user, $params->{domain_id}, { skip_save => 1 } );

        for my $field ( qw( name email facebook_user_id organization organization_title phone skype linkedin image_attachment_id ) ) {
            $self->_set_note_for_user( "deleted_user_$field" => $user_data->{$field}, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        $user->middle_name( '' );
        $user->login_name( '' );
        $user->email( 'deleted' );
        $user->phone( 'deleted' );
        $user->facebook_user_id( '' );

        my $attributes = {
            first_name => 'Deleted',
            last_name => 'Account',
            organization => '',
            organization_title => '',
            phone => '',
            skype => '',
            linkedin => '',
            draft_id => -1,
        };

        $self->_fill_profile_info_from_params( $user, $params->{domain_id}, $attributes, 1 );

        if ( my $old_url = $self->_fetch_user_matchmaker_fragment_object( $user ) ) {
            $old_url->disabled_date( time );
            $old_url->save;
        }

        $user->inv_secret( 'deleted' );

        # THIS ALSO DISABLES ALL EMAILS
        $user->login_disabled( time );
        $user->save;

        my $user_emails = CTX->lookup_object('meetings_user_email')->fetch_group({
            where => 'user_id = ? AND domain_id = ?',
            value => [ $user->id, $params->{domain_id} ],
        });

        my @emails = ();

        for my $eo ( @$user_emails ) {
            push @emails, $eo->email;
            $eo->remove;
        }

        $self->_set_note_for_user( deleted_user_emails => \@emails, $user, $params->{domain_id} ) if @emails;

        $self->_clear_user_google_tokens( $user, $params->{domain_id} );

        if ( $self->_get_user_current_subscription( $user, $params->{domain_id} ) ) {
            my $result = Dicole::Utils::Gearman->do_task( cancel_user_stripe_subscription => { auth_user_id => $user->id, user_id => $user->id, domain_id => $params->{domain_id} } );
            $self->_set_note_for_user( deleted_user_subscription_cancel_result => Data::Dumper::Dumper( $result ), $user, $params->{domain_id} );
        }

        return { result => 1 };
    },
    update_user_info_30 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        if ( $params->{language} ) {
            $user->language( $params->{language} );
        }

        if ( $params->{time_zone} ) {
            $user->timezone( $params->{time_zone} );
        }

        if ( $params->{time_display} ) {
            $self->_set_note_for_user( time_display => $params->{time_display}, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        if ( $params->{name} && ! ( $params->{name} =~ /\@/ ) && ! $params->{first_name} && ! $params->{last_name} ) {
            my ( $f, $l ) = split /\s+/, $params->{name}, 2;
            $params->{first_name} = $f;
            $params->{last_name} = $l;
        }

        my $attributes = {
            first_name => $params->{first_name},
            last_name => $params->{last_name},
            organization => $params->{organization},
            organization_title => $params->{organization_title} || $params->{title},
            phone => $params->{phone},
            skype => $params->{skype},
            linkedin => $params->{linkedin},
            draft_id => $params->{upload_id},
            timezone => $params->{time_zone} || $params->{timezone},
        };

        $self->_fill_profile_info_from_params( $user, $params->{domain_id}, $attributes, $params->{patch} ? 0 : 1 );

        if ( $params->{tos_accepted} && ! $self->_user_has_accepted_tos( $user, $params->{domain_id} ) ) {
            $self->_set_note_for_user( worker_tos_accepted => time, $user, $params->{domain_id}, { skip_save => 1 } );
            $self->_user_accept_tos( $user, $params->{domain_id} );

            $self->_queue_user_segment_event( $user, 'TOS Accepted' );
        }

        if ( $params->{google_code} && $params->{google_redirect_uri} ) {
            my ( $at, $rt ) = $self->_google_code_to_access_and_refresh_tokens( $params->{google_code}, $params->{google_redirect_uri} );
            if ( $rt ) {
                $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', $rt, $user, $params->{domain_id} );
                $self->_ensure_imported_user_upcoming_meeting_suggestions( $user, $params->{domain_id}, 1 );
                $self->_fetch_or_cache_user_google_contacts( $user, $params->{domain_id} );
            }
        }

        if ( my $source_settings = $params->{source_settings} ) {
            if ( ref( $source_settings ) eq 'HASH' ) {
                $self->_set_note_for_user( meetings_source_settings => $source_settings, $user, $params->{domain_id}, { skip_save => 1 } );
            }
        }

        # This is legacy stuff..
        if ( my $sources = $params->{hidden_sources} ) {
            if ( ref( $sources ) eq 'ARRAY' ) {
                my $source_settings = $self->_get_note_for_user( meetings_source_settings => $user, $params->{domain_id} ) || {};

                my $do_save = 0;

                for my $source ( @$sources ) {
                    next if $source_settings->{enabled}->{ $source };
                    next if $source_settings->{disabled}->{ $source };
                    $source_settings->{disabled}->{ $source } = 1;
                    delete $source_settings->{enabled}->{ $source };
                    $do_save = 1;
                }

                if ( $do_save ) {
                    $self->_set_note_for_user( meetings_source_settings => $source_settings, $user, $params->{domain_id}, { skip_save => 1 } );
                    $self->_set_note_for_user( meetings_hidden_sources => [], $user, $params->{domain_id}, { skip_save => 1 } );
                }
            }
        }
        if ( my $meetme_order = $params->{meetme_order} ) {
            if ( ref( $meetme_order ) eq 'ARRAY' ) {
                $self->_set_note_for_user( meetme_order => $meetme_order, $user, $params->{domain_id}, { skip_save => 1 } );
            }
        }
        if ( my $dismissed_news = $params->{dismissed_news} ) {
            if ( ref( $dismissed_news ) eq 'ARRAY' ) {
                $self->_set_note_for_user( dismissed_news => $dismissed_news, $user, $params->{domain_id}, { skip_save => 1 } );
            }
        }
        if ( my $feature_requests = $params->{feature_requests} ) {
            if ( ref( $feature_requests ) eq 'HASH' ) {
                $self->_set_note_for_user( feature_requests => $feature_requests, $user, $params->{domain_id}, { skip_save => 1 } );
            }
        }

        if ( my $mmr_fragment = $params->{matchmaker_fragment} || $params->{meetme_fragment} ) {
            my $old_url = $self->_fetch_user_matchmaker_fragment_object( $user );
            if ( ! $old_url || ( lc( $old_url->url_fragment ) ne lc( $mmr_fragment ) ) ) {
                $self->_set_user_matchmaker_url( $user, $params->{domain_id}, $mmr_fragment, $old_url );
            }
        }

        if ( defined( $params->{meetme_description} ) ) {
            $self->_set_note_for_user( meetme_description => $params->{meetme_description}, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        if ( $params->{upload_id} ) { # INVESTIGATE: why is this done here in addition to fill_profile?
            CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_draft => {
                user_id => $user->id,
                domain_id => $params->{domain_id},
                draft_id => $params->{upload_id},
            } );
        }

        if ( my $upload_id = $params->{meetme_background_upload_id} ) {
            my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $upload_id,
                object => $user,
                group_id => 0,
                user_id => 0,
                domain_id => $params->{domain_id},
            } ) || '';

            $self->_set_note_for_user( meetme_background_attachment_id => $id, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        $self->_set_note_for_user( meetme_background_image_url => $params->{meetme_background_image_url}, $user, $params->{domain_id}, { skip_save => 1 } ) if defined $params->{meetme_background_theme} && $params->{meetme_background_theme} eq 'u';
        $self->_set_note_for_user( meetme_background_theme => $params->{meetme_background_theme}, $user, $params->{domain_id}, { skip_save => 1 } ) if defined $params->{meetme_background_theme};

        if ( my $bg_upload_id = $params->{custom_background_upload_id} ) {
            my $id = ( $bg_upload_id eq '-1' ) ? '' : CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $bg_upload_id,
                object => $user,
                group_id => 0,
                user_id => 0,
                domain_id => $params->{domain_id},
            } ) || '';

            $self->_set_note_for_user( pro_theme_background_image => $id, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        if ( my $header_upload_id = $params->{custom_header_upload_id} ) {
            my $id = ( $header_upload_id eq '-1' ) ? '' : CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $header_upload_id,
                object => $user,
                group_id => 0,
                user_id => 0,
                domain_id => $params->{domain_id},
            } ) || '';

            $self->_set_note_for_user( pro_theme_header_image => $id, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        $self->_set_note_for_user( pro_theme => $params->{custom_theme}, $user, $params->{domain_id}, { skip_save => 1 } ) if defined $params->{custom_theme};

        if ( my $password = $params->{password} ) {
            my $password_pair = CTX->lookup_action('user_manager_api')->e( create_plaintext_and_crypted_password => {
                password => $password
            } );
            $user->password( $password_pair->[1] );
        }

        if ( my $new_epoch = $params->{ongoing_scheduling_stored_epoch} ) {
            my $old_epoch = $self->_get_note_for_user( ongoing_scheduling_stored_epoch => $user, $params->{domain_id} );
            if ( $new_epoch > $old_epoch ) {
                $self->_set_note_for_user( ongoing_scheduling_stored_epoch => $new_epoch, $user, $params->{domain_id}, { skip_save => 1 } );
                $self->_set_note_for_user( ongoing_scheduling_id => $params->{ongoing_scheduling_id}, $user, $params->{domain_id}, { skip_save => 1 } );
            }
        }

        $user->save;

        if ( ! $user->email && $params->{primary_email} ) {
            my $existing_user = $self->_fetch_user_for_email( $params->{primary_email}, $params->{domain_id} );
            if ( $existing_user ) {
                return {
                    error => { code => 503, message => 'A user with this email already exists' }
                };
            }
            else {
                $user->email( $params->{primary_email} );
                $user->save;
                # TODO: mark this user email as not yet confirmed
                $self->_send_user_future_meeting_ical_request_emails( $user, $params->{domain_id} );
            }
        }
        elsif ( ! $user->phone && $params->{primary_phone} ) {
            my $existing_user = $self->_fetch_user_for_phone( $params->{primary_phone}, $params->{domain_id} );
            if ( $existing_user ) {
                return {
                    error => { code => 504, message => 'A user with this number already exists' }
                };
            }
            else {
                $user->phone( $params->{primary_phone} );
                $user->save;
                # TODO: mark this user phone as not yet confirmed
            }
        }
        my $user_info = $self->_fetch_sanitized_user_data( $user, $params->{image_size} || 50, $params->{domain_id}, $params->{for_self}, $self->_gather_lc_opts_from_params( $params ) );

        return { user_info => $user_info };
    },
    create_user_for_matchmaker_lock => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{matchmaker_lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "missing lock" unless $lock;
        die "user already created for lock" if $self->_get_note( created_user_id => $lock );

        my $existing_user = $self->_fetch_user_for_email( $params->{primary_email}, $params->{domain_id} );
        return { user_info => { id => $existing_user->id } } if $existing_user;

        my $mmr = $self->_ensure_matchmaker_object( $lock->matchmaker_id );

        my $language = $params->{language};

        if ( $language !~ /^(fi|en|sv|fr|nl)$/) {
            my $creator_user = Dicole::Utils::User->ensure_object( $mmr->creator_id );
            $language = $creator_user->language;
        }

        my $user = eval { $self->_fetch_or_create_user_for_email( $params->{primary_email}, $params->{domain_id}, { language => $language } ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        return { error => { code => 400, message => 'malformed email address' } } unless $user;

        $self->_set_note_for_user( created_through_matchmaker_id => $mmr->id, $user, $mmr->domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( created_by_partner => $mmr->partner_id, $user, $mmr->domain_id, { skip_save => 1 } ) if $mmr->partner_id;

        $self->_set_note( created_user_id => $user->id, $lock );

        if ( $params->{name} && ! ( $params->{name} =~ /\@/ ) && ! $params->{first_name} && ! $params->{last_name} ) {
            my ( $f, $l ) = split /\s+/, $params->{name}, 2;
            $params->{first_name} = $f;
            $params->{last_name} = $l;
        }

        my $attributes = {
            first_name => $params->{first_name},
            last_name => $params->{last_name},
            organization => $params->{organization},
            organization_title => $params->{organization_title} || $params->{title},
            phone => $params->{phone},
            skype => $params->{skype},
            linkedin => $params->{linkedin},
            draft_id => $params->{upload_id},
            timezone => $params->{time_zone} || $params->{timezone},
        };

        $self->_user_accept_tos( $user, $params->{domain_id}, 'skip_save' );
        $self->_fill_profile_info_from_params( $user, $params->{domain_id}, $attributes, 1 );

        return { user_info => { id => $user->id } };
    },
    fetch_user_info_using_matchmaker_fragment_2 => sub {
        my ( $self, $params ) = @_;

        my $user = $self->_resolve_matchmaker_url_user( $params->{user_fragment}, $params->{domain_id} );
        return { error => 1 } unless $user;

        my $user_info = $self->_fetch_sanitized_user_data( $user->id, $params->{image_size} || 50, $params->{domain_id}, 0, $self->_gather_lc_opts_from_params( $params ) );

        return { user_info => $user_info };
    },
    fetch_user_info_using_email_or_phone_2 => sub {
        my ( $self, $params ) = @_;

        my $user = $params->{email} ?
            $self->_fetch_user_for_email( $params->{email}, $params->{domain_id} ) :
            $self->_fetch_user_for_phone( $params->{phone}, $params->{domain_id}, undef, { creator_user => $params->{auth_user_id} } );

        return { error => 1 } unless $user;

        my $user_info = $self->_fetch_sanitized_user_data( $user->id, $params->{image_size} || 50, $params->{domain_id}, 0, $self->_gather_lc_opts_from_params( $params ) );

        return { user_info => $user_info };
    },
    # This is probably deprecated over the previous
    fetch_user_info_using_email_2 => sub {
        my ( $self, $params ) = @_;

        my $user = $self->_fetch_user_for_email( $params->{email}, $params->{domain_id} );

        return { error => 1 } unless $user;

        my $user_info = $self->_fetch_sanitized_user_data( $user->id, $params->{image_size} || 50, $params->{domain_id}, 0, $self->_gather_lc_opts_from_params( $params ) );

        return { user_info => $user_info };
    },
    fetch_user_info_2 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => 1 } unless $user;

        my $user_info = $self->_fetch_sanitized_user_data( $user->id, $params->{image_size} || 50, $params->{domain_id}, $params->{for_self}, $self->_gather_lc_opts_from_params( $params ) );

        return { user_info => $user_info };
    },
    fetch_matchmakers_filtered_by_fragments_5 => sub {
        my ( $self, $params ) = @_;

        my $user = $self->_resolve_matchmaker_url_user( $params->{user_fragment}, $params->{domain_id} );

        return { error => { code => 404 } } unless $user;

        if ( $params->{matchmaker_fragment} ) {
            my $mmr = $self->_fetch_user_matchmaker_with_path( $user, $params->{matchmaker_fragment} );
            if ( $mmr ) {
                my $mmrs = [ $mmr ];
                if ( my $mmr_ids = $self->_get_note( additional_direct_matchmakers => $mmr ) ) {
                    for my $mmr_id ( @$mmr_ids ) {
                        push @$mmrs, eval { $self->_ensure_matchmaker_object( $mmr_id ) } || ();
                    }
                }
                return { matchmakers => [ map { $self->_return_sanitized_matchmaker_data( $_ ) } @$mmrs ] };
            }
            else {
                return { matchmakers => [] };
            }
        }
        else {
            my $mmrs = $self->_fetch_user_matchmakers_in_order( $user, $params->{domain_id} );

            my $data = [ map { $self->_return_sanitized_matchmaker_data( $_ ) } @$mmrs ];

            $data = [ map { $_->{meetme_hidden} ? () : $_ } @$data ];

            return { matchmakers => $data };
        }
    },
    fetch_user_matchmakers_10 => sub {
        my ( $self, $params ) = @_;

        my $mmrs = $self->_fetch_user_matchmakers_in_order( $params->{user_id}, $params->{domain_id} );

        my $data = [ map { $self->_return_sanitized_matchmaker_data( $_ ) } @$mmrs ];

        return { matchmakers => $data };
    },
    fetch_matchmaker_4 => sub {
        my ( $self, $params ) = @_;

        my $mmr = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 404 } } if $mmr->disabled_date;

        my $data = $self->_return_sanitized_matchmaker_data( $mmr );

        return { matchmaker => $data };
    },
    fetch_matchmaking_event_4 => sub {
        my ( $self, $params ) = @_;

        my $mm_event = $self->_ensure_matchmaking_event_object( $params->{event_id} );

        my $data = $self->_return_sanitized_matchmaking_event_data( $mm_event );

        return { matchmaking_event => $data };
    },
    fetch_matchmaking_event_registration_infos_map_6 => sub {
        my ( $self, $params ) = @_;

        my $event = $self->_ensure_matchmaking_event_object( $params->{event_id} );
        my $data = $self->_get_matchmaking_event_google_docs_company_data( $event );

        my $alternative_keys = $self->_get_note( alternative_profile_data_keys => $event ) || {};
        my $require_matching_keys = $self->_get_note( require_matching_profile_data_keys => $event ) || {};
        my $profile_data_filters = $self->_get_note( profile_data_filters => $event ) || [];

        my $sanitized_data = {};
        for my $id ( keys %$data ) {
            my $sanitized_row = {};

            for my $key ( qw ( email title image description website firstname lastname country ) ) {
                $sanitized_row->{ $key } = $data->{$id}->{ $alternative_keys->{$key} || $key };
            }

            my $valid = 1;

            for my $key ( keys %$require_matching_keys ) {
                $valid = 0 if lc( $data->{$id}->{ $key } || '' ) ne lc( $require_matching_keys->{ $key } || '' );
            }

            next unless $valid;

            $sanitized_row->{contact_name} = join (' ', $sanitized_row->{firstname} || (), $sanitized_row->{lastname} || () );

            for my $key ( qw ( firstname lastname ) ) {
                delete $sanitized_row->{ $key };
            }

            for my $filter ( @$profile_data_filters ) {
                $sanitized_row->{ $filter->{key} } = $data->{$id}->{ $filter->{key} };
            }

            $sanitized_data->{$id} = $sanitized_row;
        }

        return { infos_map => $sanitized_data };
    },
    fetch_matchmaking_event_registration_matchmakers_map_5 => sub {
        my ( $self, $params ) = @_;

        my $event = $self->_ensure_matchmaking_event_object( $params->{event_id} );
        my $infos = $self->_get_matchmaking_event_matchmaker_data( $event, $params->{image_size} );

        return { links_map => $infos };
    },
    fetch_user_matchmaking_event_reservations_2 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $mm_event = $self->_ensure_matchmaking_event_object( $params->{event_id} );
        my $mmrs = $self->_get_user_created_meetings_for_matchmaking_event( $user, $mm_event );


    },
    check_common_lock_2 => sub {
        return 1;
    },
    check_common_meeting_2 => sub {
        return 1;
    },
    register_meeting_hangout_data_2 => sub {
        my ( $self, $params ) = @_;
        # TODO: check user_id and token so that they match to meeting_id
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );

        my $old_info = $self->_gather_meeting_event_info( $meeting );

        my $data = $self->_get_note( online_conferencing_data => $meeting ) || {};

        my $old_uri = $data->{hangout_uri} || '';

        $data->{hangout_uri} = $params->{hangout_uri} || '';
        $data->{hangout_user_count} = $params->{user_count};
        $data->{hangout_refreshed_epoch} = time;

        $self->_set_note( online_conferencing_data => $data => $meeting );

        if ( $old_uri ne $data->{hangout_uri} ) {
            my $new_info = $self->_gather_meeting_event_info( $meeting );

            $self->_store_meeting_event( $meeting, {
                event_type => 'meetings_meeting_changed',
                classes => [ 'meetings_meeting' ],
                data => { old_info => $old_info, new_info => $new_info },
            } );
        }

        return { success => 1 };
    },
    fetch_agent_booking_data_60 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );


        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => 2 } unless $user;

        my $partner_id = $self->_get_note_for_user( meetings_agent_booking_partner => $user, $params->{domain_id} );

        return { error => 'no agent booking partner_id specified for user' } unless $partner_id;

        my $partner = $self->PARTNERS_BY_ID->{ $partner_id };
        return { error => 'incorrect partner_id' } unless $partner;

        my $area = $params->{area};
        my $rights = $self->_get_note_for_user( 'meetings_agent_booking_rights' => $user, $params->{domain_id}, { skip_save => 1 } );

        if ( $rights ) {
            if ( $rights eq '_all' ) {
                $area ||= 'pks';
            }
            else {
                $area = $rights;
            }
        }
        else {
            return { error => 'insufficient rights' };
        }

        my $stash = { partner_id => $partner_id, domain_id => $params->{domain_id} };
        $self->_fill_agent_object_stash_from_db( $stash, 'current', $area, { skip_translations => 1 } );

        my $areas = [];
        for my $a ( @{ $stash->{all_areas} } ) {
            push @$areas, $a if $a->{id} eq $rights || $rights eq '_all';
        }

        my $types = $self->_get_partner_agent_booking_types( $partner_id );
        my $types_by_id = { map { $_->{id} => $_ } @$types };

        my $emails = [ map { $_->{user_email} } values %{ $stash->{calendars} } ];

        my $user_objects_map = $self->_fetch_user_objects_map_by_emails( $emails, $params->{domain_id} );

        my $mmrs = $self->_fetch_matchmakers_for_users( [ values %$user_objects_map ] );
        my $sources = $self->_fetch_suggestion_sources_for_users( [ values %$user_objects_map ] );

        my $return = [];
        for my $calendar ( values %{ $stash->{calendars} } ) {
            my $data_user = $user_objects_map->{ lc( $calendar->{user_email} ) };
            next unless $data_user;

            my $office = $stash->{offices}->{ $calendar->{office_full_name} };
            next unless $office;

            my $rep = $stash->{users}->{ $calendar->{user_email} };
            next unless $rep;

            if ( my $date = $calendar->{last_reservable_day} ) {
                my $day_start = Dicole::Utils::Date->ymd_to_day_start_epoch( $date, $user->timezone );
                next if time > $day_start + 24*60*60;
            }

            if ( ! $calendar->{disable_calendar_sync} ) {
                my $fresh_source_found = 0;
                for my $source ( @$sources ) {
                    next unless $source->user_id == $data_user->id;
                    next unless $source->provider_type;
                    next unless $source->provider_type eq 'client_sync';
                    next unless $source->verified_date > time - 24*60*60;
                    $fresh_source_found = 1;
                }
                if ( ! $fresh_source_found ) {
                    next unless $params->{domain_id} == 76;
                }
            }

            my $user_data = {
                name => $rep->{name},
                email => $calendar->{user_email},
                suomi => $calendar->{languages_map}->{fi} || '',
                svenska => $calendar->{languages_map}->{sv} || '',
                english => $calendar->{languages_map}->{en} || '',
                'etutaso0-1' => $calendar->{service_levels_map}->{'etutaso0-1'} || '',
                'etutaso2-4' => $calendar->{service_levels_map}->{'etutaso2-4'} || '',
                phone => $rep->{phone} || '',
                title => $rep->{title} || '',
                website => $office->{website_fi} || $office->{website_en} || '',
                area => $stash->{areas_by_id}->{ $calendar->{area} }->{name} || '',
                office => $office->{name} || '',
                extra_meeting_email => $calendar->{extra_meeting_email} || '',
            };

            # to be legacy soonish (?):
            $user_data->{verkkosivu} = $user_data->{website};
            $user_data->{alue} = $user_data->{area};
            $user_data->{toimisto} = $user_data->{office};
            $user_data->{verkkotapaamisenosoite} = $user_data->{extra_meeting_email};

            my $user_matchmakers = [ map { $_->creator_id == $data_user->id ? $_ : () } @$mmrs ];
            my $mmrs_by_path = { map { $_->vanity_url_path => $_ } @$user_matchmakers };

            for my $type_id ( @{ $calendar->{meeting_types} } ) {
                my $type = $types_by_id->{ $type_id };

                if ( ! $type ) {
                    get_logger(LOG_APP)->error("unknown type_id for user_id: " . $type_id . ', ' . $data_user->id );
                    next;
                }

                $user_data->{ $type->{id} } = 'x';

                for my $lang ( keys %{ $calendar->{languages_long_map} } ) {
                    next unless $calendar->{languages_long_map}->{ $lang };
                    for my $level ( 'etutaso0-1', 'etutaso2-4' ) {
                        my $path_office_name = lc( $calendar->{office_full_name} );
                        $path_office_name =~ s/[^a-z]//g;

                        my $expected_path = join( "-", $level, $type->{path}, $path_office_name, $lang );
                        my $mmr = $mmrs_by_path->{ $expected_path };

                        next unless $mmr;
                        $user_data->{ join("-", $level, $type->{id}, $lang ) } = $mmr->id;
                    }
                }
            }

            push @$return, $user_data;
        }

        return { types => $types, users => $return, areas => $areas, settings => $stash->{settings}->{general}, selected_area => $area };
    },
    create_user_matchmaker_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $user_previous_matchmakers = $self->_fetch_user_matchmakers( $params->{user_id}, $params->{domain_id} );
        my $valid_params = $self->_get_validated_params_for_matchmaking_event( $params, $params->{matchmaking_event_id} );

        my $new_path = lc( $valid_params->{vanity_url_path} || 'default' );

        for my $round ( 1..10 ) {
            my $round_path = $new_path;
            $round_path .= '_' . $round if $round != 1;

            my $mmr_with_round_path = $self->_fetch_user_matchmaker_with_path( $user, $round_path );

            if ( ! $mmr_with_round_path ) {
                $new_path = $round_path;
                last;
            }
            else {
                if ( $valid_params->{matchmaking_event_id} ) {
                    if ( $mmr_with_round_path->matchmaking_event_id == $valid_params->{matchmaking_event_id} ) {
                        return { error => { code => 5, message => 'matchmaker already exists for event' } };
                    }
                    if ( $round > 9 ) {
                        return { error => { code => 6, message => 'all path variations for event taken' } };
                    }
                }
                else {
                    if ( $round > 9 ) {
                        return { error => { code => 6, message => 'all path variations for event taken' } };
                    }
                }
            }
        }

        $new_path = '' if $new_path eq 'default';

        my $mmr = CTX->lookup_object('meetings_matchmaker')->new( {
            domain_id => $params->{domain_id},
            partner_id => $valid_params->{partner_id} || 0,
            creator_id => $user->id,
            matchmaking_event_id => $valid_params->{matchmaking_event_id} || 0,
            logo_attachment_id => 0,
            allow_multiple => 0,
            created_date => time,
            validated_date => time,
            disabled_date => 0,
            vanity_url_path => $new_path,
            name => $valid_params->{name},
            description => $valid_params->{description},
            website => '',
        } );

        my $slots = $valid_params->{slots};
        $slots = Dicole::Utils::JSON->decode( $slots ) if ref( $slots ) ne 'ARRAY';

        $self->_set_note( background_theme => $valid_params->{background_theme}, $mmr, { skip_save => 1 } );
        $self->_set_note( time_zone => $valid_params->{time_zone} || $user->timezone, $mmr, { skip_save => 1 } );
        $self->_set_note( duration => $valid_params->{duration}, $mmr, { skip_save => 1 } );
        $self->_set_note( buffer => $valid_params->{buffer}, $mmr, { skip_save => 1 } );
        $self->_set_note( location => $valid_params->{location}, $mmr, { skip_save => 1 } );
        $self->_set_note( available_timespans => $valid_params->{available_timespans}, $mmr, { skip_save => 1 } );
        $self->_set_note( source_settings => $valid_params->{source_settings}, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_option => $valid_params->{online_conferencing_option}, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_data => $valid_params->{online_conferencing_data}, $mmr, { skip_save => 1 } );
        $self->_set_note( planning_buffer => $valid_params->{planning_buffer}, $mmr, { skip_save => 1 } );
        $self->_set_note( require_verified_user => $valid_params->{require_verified_user}, $mmr, { skip_save => 1 } );
        $self->_set_note( preset_title => $valid_params->{preset_title}, $mmr, { skip_save => 1 } );
        $self->_set_note( preset_agenda => $valid_params->{preset_agenda}, $mmr, { skip_save => 1 } );
        $self->_set_note( suggested_reason => $valid_params->{suggested_reason}, $mmr, { skip_save => 1 } );
        $self->_set_note( ask_reason => $valid_params->{ask_reason}, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_ask_reason => $valid_params->{ask_reason} ? 0 : 1, $mmr, { skip_save => 1 } );
        $self->_set_note( confirm_automatically => $valid_params->{confirm_automatically}, $mmr, { skip_save => 1 } );

        $self->_set_note( meeting_type => $valid_params->{meeting_type}, $mmr, { skip_save => 1 } );

        $self->_set_note( direct_link_enabled => $valid_params->{direct_link_enabled} ? 1 : 0, $mmr, { skip_save => 1 } );
        $self->_set_note( direct_link_disabled => $valid_params->{direct_link_enabled} ? 0 : 1, $mmr, { skip_save => 1 } );

        $self->_set_note( meetme_visible => $valid_params->{meetme_hidden} ? 0 : 1, $mmr, { skip_save => 1 } );
        $self->_set_note( meetme_hidden => $valid_params->{meetme_hidden} ? 1 : 0, $mmr, { skip_save => 1 } );

        $self->_set_note( background_image_url => $valid_params->{background_image_url}, $mmr, { skip_save => 1 } ) if $valid_params->{background_theme} eq 'u';

        $self->_set_note( youtube_url => $valid_params->{youtube_url}, $mmr, { skip_save => 1 } );

        $self->_set_note( slots => $slots, $mmr );

        my $mmr_with_path = $self->_fetch_user_matchmaker_with_path( $user, $mmr->vanity_url_path );

        return { error => { code => 2, message => 'saving failed mysteriously' } } unless $mmr_with_path;

        unless ( $mmr_with_path->id == $mmr->id ) {
            $mmr->remove;
            return { error => { code => 1, message => 'path taken' } };
        }

        if ( $valid_params->{preset_materials} ) {
            $self->_set_note( preset_materials => $self->_merge_matchmaker_preset_materials( $mmr, $valid_params->{preset_materials} ), $mmr );
        }

        if ( my $upload_id = $valid_params->{background_upload_id} ) {
            my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $upload_id,
                object => $mmr,
                group_id => 0,
                user_id => 0,
                domain_id => $params->{domain_id},
            } ) || '';

            $self->_set_note( background_attachment_id => $id, $mmr );
        }

        my $domain_host = $valid_params->{partner_id} ?
            $self->_get_host_for_partner( $valid_params->{partner_id}, 443 ) :
            $self->_get_host_for_domain( $params->{domain_id}, 443 );

        my $config_url = $self->_get_meet_me_config_abs( undef, {}, $params->{domain_id} );
        $config_url = $self->_generate_authorized_uri_for_user( $domain_host . $config_url, $user, $params->{domain_id} );

        my $shift2016_location_type = $params->{shift2016_activity} || '';
        if ( $valid_params->{matchmaking_event_id} && ! $params->{shift2016_activity} ) {
            if ( $valid_params->{vanity_url_path} eq 'shift2016' ) {
                my $mmr_relaxing_result = Dicole::Utils::Gearman->do_task( create_user_matchmaker => { %$params, shift2016_activity => 'relaxing' } );
                my $mmr_extreme_result = Dicole::Utils::Gearman->do_task( create_user_matchmaker => { %$params, shift2016_activity => 'extreme' } );
                my $mmr_ids = [
                    $mmr_relaxing_result->{matchmaker}->{id},
                    $mmr_extreme_result->{matchmaker}->{id},
                ];
                $self->_set_note( additional_direct_matchmakers => $mmr_ids, $mmr );
                $shift2016_location_type = 'creative';
            }
            # HACK: wait for a sec so that the user alias is stored before generating url
            sleep 1;
            my $user_event_meetme_url = $self->_generate_matchmaker_meet_me_url( $mmr, $user, $domain_host );
            my $mm_event = $self->_ensure_matchmaking_event_object( $valid_params->{matchmaking_event_id} );
            my $event_config_url = $self->_get_meet_me_config_abs( $valid_params->{matchmaking_event_id}, {}, $params->{domain_id} );
            $event_config_url = $self->_generate_authorized_uri_for_user( $domain_host . $event_config_url, $user, $params->{domain_id} );

            # While in event, we want the personal use link to point to base meetin.gs instead:
            $config_url = $self->_generate_authorized_uri_for_user( $self->_get_host_for_domain( $params->{domain_id}, 443 ) . $self->_get_meet_me_config_abs( undef, {}, $params->{domain_id}), $user, $params->{domain_id} );

            my $template_key_base = $self->_get_note('custom_welcome_template', $mm_event ) || 'meetings_matchmaker_attendee_meetme_created';

            $self->_send_partner_themed_mail(
                user => $user,
                domain_id => $params->{domain_id},
                partner_id => $valid_params->{partner_id} || 0,
                group_id => 0,
                log_data => { matchmaking_event_id => $mm_event->id },

                template_key_base => $template_key_base,
                template_params => {
                    user_name => Dicole::Utils::User->name( $user ),
                    user_email => $user->email,
                    user_event_meetme_url => $user_event_meetme_url,
                    matchmaking_event => $mm_event->custom_name,
                    event_meetme_config_url => $event_config_url,
                    meetme_config_url => $config_url,
                },
            );
        }
        elsif ( ! scalar( @$user_previous_matchmakers ) )  {
            my $login_url = Dicole::URL->from_parts( domain_id => $params->{domain_id}, action => 'meetings_global', task => 'detect' );
            $login_url = $self->_generate_authorized_uri_for_user( $domain_host . $login_url, $user, $params->{domain_id} );

            $self->_send_partner_themed_mail(
                user => $user,
                domain_id => $params->{domain_id},
                partner_id => $valid_params->{partner_id} || 0,
                group_id => 0,

                template_key_base => 'meetings_signup_welcome',
                template_params => {
                    user_name => Dicole::Utils::User->name( $user ),
                    user_email => $user->email,
                    login_url => $login_url,
                    meetme_config_url => $config_url,
                },
            );

            $self->_set_note_for_user('meetings_signup_welcome_email_sent', time, $user, $params->{domain_id} );
        }

        if ( $shift2016_location_type ) {
            $self->_set_note( location_selection_logic => 'random', $mmr, { skip_save => 1 } );
            $self->_set_note( limit_locations_to_event_type => $shift2016_location_type, $mmr );
        }

        $self->_correct_matchmaker_location_from_event( $mmr, $user );

        return { matchmaker => $self->_return_sanitized_matchmaker_data( $mmr ) };
    },
    update_user_matchmaker_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $mmr = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 404 } } unless $mmr && $mmr->creator_id == $user->id;
        return { error => { code => 404 } } if $mmr->disabled_date;

        my $valid_params = $self->_get_validated_params_for_matchmaking_event( $params, $mmr->matchmaking_event_id );

        $mmr->name( $valid_params->{name} );

        my $new_path = lc( $valid_params->{vanity_url_path} || '' );
        $new_path = '' if $new_path eq 'default';

        my $mmr_with_path = $self->_fetch_user_matchmaker_with_path( $user, $new_path );
        return { error => { code => 1, message => 'path taken' } } unless $mmr_with_path->id == $mmr->id;

        my $old_path = $mmr->vanity_url_path;
        $mmr->vality_url_path( $new_path );
        $mmr->save;

        # In case somebody else managed to steal it first :P
        $mmr_with_path = $self->_fetch_user_matchmaker_with_path( $user, $new_path );
        unless ( $mmr_with_path->id == $mmr->id ) {
            $mmr->vality_url_path( $old_path );
            $mmr->save;
            return { error => { code => 1, message => 'path taken' } };
        }

        $mmr->description( $valid_params->{description} );

        if ( $valid_params->{preset_materials} ) {
            $self->_set_note( preset_materials => $self->_merge_matchmaker_preset_materials( $mmr, $valid_params->{preset_materials} ), $mmr );
        }

        if ( my $upload_id = $valid_params->{background_upload_id} ) {
            my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $upload_id,
                object => $mmr,
                group_id => 0,
                user_id => 0,
                domain_id => $params->{domain_id},
            } ) || '';

            $self->_set_note( background_attachment_id => $id, $mmr, { skip_save => 1 } );
        }

        my $slots = $params->{slots};
        $slots = Dicole::Utils::JSON->decode( $slots ) if ref( $slots ) ne 'ARRAY';

        $self->_set_note( background_theme => $valid_params->{background_theme}, $mmr, { skip_save => 1 } );
        $self->_set_note( time_zone => $valid_params->{time_zone} || $user->timezone, $mmr, { skip_save => 1 } );
        $self->_set_note( duration => $valid_params->{duration}, $mmr, { skip_save => 1 } );
        $self->_set_note( buffer => $valid_params->{buffer}, $mmr, { skip_save => 1 } );
        $self->_set_note( location => $valid_params->{location}, $mmr, { skip_save => 1 } );
        $self->_set_note( available_timespans => $valid_params->{available_timespans}, $mmr, { skip_save => 1 } );
        $self->_set_note( source_settings => $valid_params->{source_settings}, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_option => $valid_params->{online_conferencing_option}, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_data => $valid_params->{online_conferencing_data}, $mmr, { skip_save => 1 } );
        $self->_set_note( planning_buffer => $valid_params->{planning_buffer}, $mmr, { skip_save => 1 } );
        $self->_set_note( require_verified_user => $valid_params->{require_verified_user}, $mmr, { skip_save => 1 } );
        $self->_set_note( preset_title => $valid_params->{preset_title}, $mmr, { skip_save => 1 } );
        $self->_set_note( preset_agenda => $valid_params->{preset_agenda}, $mmr, { skip_save => 1 } );
        $self->_set_note( suggested_reason => $valid_params->{suggested_reason}, $mmr, { skip_save => 1 } );
        $self->_set_note( ask_reason => $valid_params->{ask_reason}, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_ask_reason => $valid_params->{ask_reason} ? 0 : 1, $mmr, { skip_save => 1 } );
        $self->_set_note( confirm_automatically => $valid_params->{confirm_automatically}, $mmr, { skip_save => 1 } );

        $self->_set_note( meeting_type => $valid_params->{meeting_type}, $mmr, { skip_save => 1 } );

        $self->_set_note( direct_link_enabled => $valid_params->{direct_link_enabled} ? 1 : 0, $mmr, { skip_save => 1 } );
        $self->_set_note( direct_link_disabled => $valid_params->{direct_link_enabled} ? 0 : 1, $mmr, { skip_save => 1 } );

        $self->_set_note( meetme_visible => $valid_params->{meetme_hidden} ? 0 : 1, $mmr, { skip_save => 1 } );
        $self->_set_note( meetme_hidden => $valid_params->{meetme_hidden} ? 1 : 0, $mmr, { skip_save => 1 } );

        $self->_set_note( background_image_url => $valid_params->{background_image_url}, $mmr, { skip_save => 1 } ) if $valid_params->{background_theme} eq 'u';

        $self->_set_note( youtube_url => $valid_params->{youtube_url}, $mmr, { skip_save => 1 } );

        $self->_set_note( slots => $slots, $mmr );

        $self->_correct_matchmaker_location_from_event( $mmr, $user );

        return { matchmaker => $self->_return_sanitized_matchmaker_data( $mmr ) };
    },
    delete_matchmaker_3 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $mmr = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 404 } } unless $mmr && $mmr->creator_id == $user->id;

        $mmr->disabled_date( time );
        $mmr->save;

        return { result => 1 };
    },
    fetch_matchmaker_options_10 => sub {
        my ( $self, $params ) = @_;

        my $mmr = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );
        return { error => { code => 404 } } if $mmr->disabled_date;

        my $begin_epoch = $params->{begin_epoch};

        # Chooses the first full half an hour after planning_buffer seconds from current time
        my $planning_buffer = $self->_get_note( planning_buffer => $mmr ) || 30*60;
        if ( $begin_epoch < time + $planning_buffer ) {
            my $dt = Dicole::Utils::Date->epoch_to_datetime( time + $planning_buffer + 30*60 - 1 );
            $dt->set( minute => 30 * int( $dt->minute / 30 ), second => 0 );
            $begin_epoch = $dt->epoch;
        }

        # allow fetching only a maximum of 2 weeks at a time
        my $max_range_end_epoch = $begin_epoch + 2 * 7 * 24*60*60;

        my $end_epoch = $params->{end_epoch} || $max_range_end_epoch;

        $end_epoch = $max_range_end_epoch if $end_epoch > $max_range_end_epoch;

        # allow fetching options only 12 weeks (minus a 12 hour sync window) in the future
        my $max_total_end_epoch = time + 12 * 7 * 24*60*60 - 12*60*60;
        $end_epoch = $max_total_end_epoch if $end_epoch > $max_total_end_epoch;

        my $available_spans = $self->_get_matchmaker_available_option_spanset( $mmr, {
            begin_epoch => $begin_epoch,
            end_epoch => $end_epoch,
        } );

        return { options => $self->_spanset_to_matchmaker_options( $mmr, $available_spans, $self->_get_note( time_zone => $mmr ) ) }
    },
    preview_matchmaker_options_10 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $slots = $params->{slots} || [];
        $slots = Dicole::Utils::JSON->decode( $slots ) if ref( $slots ) ne 'ARRAY';

        my $tz = $params->{time_zone} || $user->timezone;

        my $begin = $params->{begin_epoch};
        my $end = $params->{end_epoch};
        $begin = time if $begin < time;
        $end = time if $end < time;

        my $planning_buffer = $params->{planning_buffer} || 30*60;
        if ( $begin < time + $planning_buffer ) {
            my $dt = Dicole::Utils::Date->epoch_to_datetime( time + $planning_buffer + 30*60 - 1 );
            $dt->set( minute => 30 * int( $dt->minute / 30 ), second => 0 );
            $begin = $dt->epoch;
        }

        my $base_spanset = $self->_matchmaker_slots_to_spanset_within_epochs(
            $slots, $begin, $end, $tz
        );

        $self->_ensure_imported_user_upcoming_meeting_suggestions_for_enabled_google_sources(
            $user, $params->{domain_id}, $params->{source_settings}
        );

        my $reserved_spanset = $self->_get_user_reservation_spanset_within_timespan_in_domain(
            $user, $base_spanset->is_empty_set ? undef : $base_spanset->span, $params->{domain_id}, { buffer => $params->{buffer}, source_settings => $params->{source_settings} }
        );

        my $result_spanset = $base_spanset->complement( $reserved_spanset );

        $result_spanset = $self->_limit_spanset_to_available_timespans( $result_spanset, $params->{available_timespans}, $tz );

        # NOTE: this purposefully does not filter locations based on location event type
        my $locations = $params->{matchmaking_event_id} ? CTX->lookup_object('meetings_matchmaking_location')->fetch_group({
                where => 'matchmaking_event_id = ?',
                value => [ $params->{matchmaking_event_id} ],
            }) : [];

        if ( @$locations ) {
            my $availability_data_to_spanset_cache = {};
            my $any_location_spanset = DateTime::SpanSet->from_spans( spans => [] );

            for my $location ( @$locations ) {
                my $cached_spanset = $availability_data_to_spanset_cache->{ $location->availability_data } ||= $self->_get_location_option_spanset_within_epochs( $location, $begin, $end );
                my $spanset = $cached_spanset->clone;
                $any_location_spanset = Dicole::Utils::Date->join_spansets( $any_location_spanset, $spanset );
            }

            $result_spanset = $result_spanset->intersection( $any_location_spanset );
        }

        return { options => $self->_spanset_to_matchmaker_options( undef, $result_spanset, $tz ) };
    },
    get_matchmaker_lock => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "unauthorized" unless $lock;

        my $user_id = $params->{user_id} || 0;
        die "unauthorized" if $lock->user_id && $lock->user_id != $user_id;

        return $self->_return_sanitized_matchmaker_lock_data( $lock );
    },
    create_matchmaker_lock => sub {
        my ( $self, $params ) = @_;
        my $mmr = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 404 } } if ! $mmr || $mmr->disabled_date;

        my $start_epoch = $params->{start_epoch};
        my $end_epoch = $params->{end_epoch};
        my $user_id = $params->{user_id};

        if ( ! $self->_check_matchmaker_lock_availability( $mmr, $start_epoch, $end_epoch ) ) {
            return { error => { message => $self->_ncmsg( 'Someone else just reserved this time before you. Please refresh the page to see the current situation in this scheduler.', { user_id => $params->{user_id} } ) . (1) } };
        }

        my $lock = undef;
        my $selected_location = undef;
        my $lock_minutes = $params->{extended_lock} ? 60 : 15;

        my $locations = $self->_matchmaker_locations( $mmr );

        if ( @$locations ) {
            ( $lock, $selected_location ) = $self->_create_matchmaker_lock_with_location( $mmr, $start_epoch, $end_epoch, $user_id, $locations, $lock_minutes );
        }
        else {
            $lock = $self->_create_matchmaker_lock_without_location( $mmr, $start_epoch, $end_epoch, $user_id, $lock_minutes );
        }

        return { error => { message => $self->_ncmsg( 'Someone else just reserved this time before you. Please refresh the page to see the current situation in this scheduler.', { user_id => $params->{user_id} } ) . '(2)' } } unless $lock;

        # TODO: maybe have some kind of security, or checking on which mmr locks location can be specified
        $self->_set_note( location => $params->{location}, $lock, { skip_save => 1 } ) if $params->{location};
        # TODO: this is not actually used yet... maybe in the future?
        $self->_set_note( rescheduled_meeting_id => $params->{rescheduled_meeting_id}, $lock, { skip_save => 1 } ) if $params->{rescheduled_meeting_id};

        $lock->save;

        $self->_store_matchmaker_lock_event( $mmr, $lock, 'created', { author => $params->{user_id} || 0 } );

        return $self->_return_sanitized_matchmaker_lock_data( $lock, $mmr, $selected_location );
    },
    extend_matchmaker_lock => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "unauthorized" unless $lock;
        die "lock expired" if $lock->expire_date && $lock->expire_date < time;

        my $agenda = $params->{agenda} || '';

        $lock->agenda( $agenda );
        $self->_set_note( location => $params->{location}, $lock, { skip_save => } );
        $lock->expire_date( time + 24*60*60 );
        $lock->save;

        return $self->_return_sanitized_matchmaker_lock_data( $lock );
    },
    cancel_matchmaker_lock => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "unauthorized" unless $lock;

        my $user_id = $params->{user_id} || 0;
        die "unauthorized" if $lock->user_id && $lock->user_id != $user_id;

        $lock->cancel_date( time );
        $lock->save;

        my $mmr = $self->_ensure_matchmaker_object( $lock->matchmaker_id );

        $self->_store_matchmaker_lock_event( $mmr, $lock, 'canceled', { author => $params->{user_id} || 0 } );

        return $self->_return_sanitized_matchmaker_lock_data( $lock );
    },
    confirm_matchmaker_lock => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "unauthorized" unless $lock;
        die "lock expired" if $lock->expire_date && $lock->expire_date < time;

        my $user_id = $params->{user_id} || 0;

        die "unauthorized" unless $user_id;
        die "unauthorized" if $lock->user_id && $lock->user_id != $user_id;
        die "unauthorized" if $lock->expected_confirmer_id && $lock->expected_confirmer_id != $user_id;

        $self->_set_note( quickmeet_key => $params->{quickmeet_key}, $lock, { skip_save => 1 } ) if $params->{quickmeet_key};

        my $agenda = $params->{agenda} || '';
        $lock->agenda( $agenda );
        $self->_set_note( location => $params->{location}, $lock, { skip_save => } );

        my $mmr = $self->_ensure_matchmaker_object( $lock->matchmaker_id );
        $lock = $self->_confirm_matchmaker_lock_for_user( $lock, $user_id, $mmr );

        return $self->_return_sanitized_matchmaker_lock_data( $lock, $mmr );
    },
    send_matchmaker_lock_confirm_email => sub {
        my ( $self, $params ) = @_;

        my $lock_id = $params->{lock_id};
        my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

        die "unauthorized" unless $lock;
        die "lock expired" if $lock->expire_date && $lock->expire_date < time;

        my $mmr = $self->_ensure_matchmaker_object( $lock->matchmaker_id );
        my $domain_id = $mmr->domain_id;
        my $partner_id = $mmr->partner_id;

        my $expected_confirmer_id = $params->{expected_confirmer_id} || 0;
        my $user = eval { Dicole::Utils::User->ensure_object( $expected_confirmer_id ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
        my $creator_user = Dicole::Utils::User->ensure_object( $mmr->creator_id );

        my $agenda = $params->{agenda} || '';

        $lock->agenda( $agenda );
        $self->_set_note( location => $params->{location}, $lock, { skip_save => } );

        if ( $params->{quickmeet_key} ) {
            $self->_set_note( quickmeet_key => $params->{quickmeet_key}, $lock, { skip_save => 1 } );
            $lock = $self->_confirm_matchmaker_lock_for_user( $lock, undef, $mmr );
            return $self->_return_sanitized_matchmaker_lock_data( $lock, $mmr );
        }

        $lock->expected_confirmer_id( $expected_confirmer_id );

        if ( ! $self->_get_note( require_verified_user => $mmr ) ) {
            $lock = $self->_confirm_matchmaker_lock_for_user( $lock, $user, $mmr, $params->{extra_data}, $params->{auth_user_id} );
            return $self->_return_sanitized_matchmaker_lock_data( $lock, $mmr );
        }

        $lock->expire_date( time + 24*60*60 );

        my $generated_title = $self->_generate_lock_title( $lock, $mmr, undef, undef, $creator_user, $user );
        $lock->title( $generated_title );

        $lock->save;

        my $creator_info = $self->_gather_user_info( $creator_user, -1, $mmr->domain_id );

        my $host = $partner_id ? $self->_get_host_for_partner( $partner_id, 443 ) : '';

        my $validate_url = $self->_generate_authorized_uri_for_user(
            $host . $self->derive_url( action => 'meetings', task => 'matchmaking_success', additional => [ $lock->id ] ),
            $user,
            $domain_id,
        );

        my $new_user = $self->_user_is_new_user( $user, $domain_id );

        $self->_send_partner_themed_mail(
            user => $user,
            domain_id => $domain_id,
            partner_id => $partner_id,
            group_id => 0,

            template_key_base => $new_user ? 'meetings_matchmaker_choose_registration' : 'meetings_matchmaker_choose_merge',
            template_params => {
                user_name => Dicole::Utils::User->name( $user ),
                user_email => $user->email,
                matchmaker_name => Dicole::Utils::User->name( $creator_user ),
                matchmaker_email => $creator_user->email,
                matchmaker_company => $creator_info->{organization} || '',
                verify_url => $validate_url,
            },
        );

        return $self->_return_sanitized_matchmaker_lock_data( $lock, $mmr );
    },
    create_matchmaker_quickmeet_3 => sub {
        my ( $self, $params ) = @_;

        my $matchmaker = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 500, message => 'could not find matchmaker' } } unless $matchmaker;

        my $quickmeet;
        for (1..10) {
            last if $quickmeet;

            my $name = lc( $params->{name} || $params->{email} || $params->{phone} );
            $name =~ s/\@.*//;
            $name =~ s/\s//g;
            $name = Dicole::Utils::Text->utf8_to_url_readable( $name );

            my @chars = split //, "abcdefghjkmnpqrstxz23456789";
            my $random = join "", map { $chars[rand @chars] } 1 .. 5;
            my $key = join( "-", $random, $name );

            $quickmeet = CTX->lookup_object('meetings_quickmeet')->new({
                matchmaker_id => $matchmaker->id,
                creator_id => $matchmaker->creator_id,
                domain_id => $matchmaker->domain_id,
                partner_id => 0,
                created_date => time,
                updated_date => time,
                removed_date => 0,
                expires_date => 0,
                url_key => $key,
            });

            $quickmeet->save;

            my $quickmeets = CTX->lookup_object('meetings_quickmeet')->fetch_group( {
                where => 'url_key = ?',
                value => [ $key ],
                order => 'id asc',
            } );

            if ( $quickmeets->[0] && $quickmeets->[0]->id != $quickmeet->id ) {
                $quickmeet->remove;
                $quickmeet = undef;
            }
        }

        return { error => { code => 112 } } unless $quickmeet;

        $self->_set_note( email => $params->{email} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( phone => $params->{phone} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( name => $params->{name} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( organization => $params->{organization} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( title => $params->{title} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( message => $params->{message} || '', $quickmeet, { skip_save => 1 } );
        $self->_set_note( meeting_title => $params->{meeting_title} || '', $quickmeet, { skip_save => 1 } );

        $quickmeet->save;

        return { quickmeet => $self->_sanitize_quickmeet_object( $quickmeet ) };
    },
    send_matchmaker_quickmeet_5 => sub {
        my ( $self, $params ) = @_;

        my $matchmaker = $self->_ensure_matchmaker_object( $params->{matchmaker_id} );

        return { error => { code => 500, message => 'could not find matchmaker' } } unless $matchmaker;

        my $quickmeet = $self->_ensure_object_of_type( meetings_quickmeet => $params->{quickmeet_id} );

        return { error => { code => 500, message => 'could not find matchmaker' } } unless $quickmeet;

        my $email = $self->_get_note( email => $quickmeet );
        my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
        my $user = $self->_fetch_user_for_email( $email, $params->{domain_id} );

        if ( ! $user ) {
            $user = $self->_fetch_or_create_user_for_email( $email, $params->{domain_id} );
            $user->language( $creator_user->language );
            $user->timezone( $creator_user->timezone );
            $self->_set_note_for_user( created_for_quickmeet_email => time , $user, $params->{domain_id}, { skip_save => 1 } );
            $self->_set_note_for_user( created_from_quickmeet_id => $quickmeet->id, $user, $params->{domain_id} );
        }

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

        my $pick_url = Dicole::URL->from_parts(
            action => 'meetings',
            task => 'pick',
            domain_id => $params->{domain_id},
            additional => [ $quickmeet->url_key ],
        );

        $pick_url = $self->_generate_authorized_uri_for_user( $domain_host . $pick_url, $user, $params->{domain_id} );

        my $user_name = Dicole::Utils::User->name( $user );
        $user_name = $self->_get_note( name => $quickmeet ) if $user_name eq $user->email;

        my $message = $self->_get_note( message => $quickmeet );

        $self->_send_partner_themed_mail(
            user => $user,
            partner_id => 0,
            group_id => 0,
            domain_id => $params->{domain_id},

            template_key_base => 'meetings_quickmeet_invitation',
            template_params => {
                creator_user_name => Dicole::Utils::User->name( $creator_user ),
                message_text => $message || '',
                message_html => $message ? Dicole::Utils::HTML->text_to_html( $message ) : '',
                user_name => $user_name,
                pick_url => $pick_url,
            },
        );

        $self->_set_note( email_sent => time, $quickmeet );

        return { result => 1 };
    },
    get_matchmaker_quickmeets_1 => sub {
        my ( $self, $params ) = @_;

        my $quickmeets = CTX->lookup_object('meetings_quickmeet')->fetch_group( {
            where => 'matchmaker_id = ? AND removed_date = 0',
            value => [ $params->{matchmaker_id} ],
        } );

        return { quickmeets => [ map { $self->_sanitize_quickmeet_object( $_ ) } @$quickmeets ] };
    },
    check_user_meeting_membership_1 => sub {
        my ( $self, $params ) = @_;
        my $user_id = $params->{user_id};
        my $meeting_id = $params->{meeting_id};
        return { result => 0 } unless $user_id && $meeting_id;
        return { result => $self->_get_user_meeting_participation_object( $user_id, $meeting_id ) ? 1 : 0 };
    },
    check_user_matchmaker_ownership_1 => sub {
        my ( $self, $params ) = @_;
        my $user_id = $params->{user_id};
        my $matchmaker_id = $params->{matchmaker_id};
        my $mmr = $self->_ensure_matchmaker_object( $matchmaker_id );

        return { result => 0 } unless $user_id && $mmr && $mmr->creator_id == $user_id;
        return { result => 1 };
    },
    set_facebook_uid_for_user_1 => sub {
        my ( $self, $params ) = @_;
        my $user_id = $params->{user_id};
        my $uid = $params->{uid} || '';
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        return { error => 1 } if ! $user;

        $user->facebook_user_id( $uid );
        $user->save;

        return { result => { facebook_user_id => $uid } };
    },
    fetch_auth_data_1 => sub {
        my ( $self, $params ) = @_;

        return { user_id => $params->{user_id}, scope => 'todo:all' }
    },
    create_meeting_10 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $begin_epoch = $params->{begin_epoch} || 0;
       $begin_epoch ||= Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{begin_date}, $params->{begin_time}, $user->timezone, $user->language ) if $params->{begin_date} && $params->{begin_time};

        my $end_epoch = $params->{end_epoch} || 0;
        $end_epoch ||= Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{end_date}, $params->{end_time}, $user->timezone, $user->language ) if $params->{end_date} && $params->{end_time};

        my $meeting = CTX->lookup_action('meetings_api')->e( create => {
            creator => $user,
            domain_id => $params->{domain_id},

            location => $params->{location},
            title => $params->{title},
            online_conferencing_option => $params->{online_conferencing_option},
            online_conferencing_data => $params->{online_conferencing_data},
            skype_account => $params->{skype_account},
            initial_agenda => $params->{initial_agenda},
            begin_epoch => $begin_epoch,
            end_epoch => $end_epoch,

            disable_create_email => 1,
            disable_helpers => 1,

            background_theme => $params->{background_theme},
            background_image_url => $params->{background_image_url},
            background_upload_id => $params->{background_upload_id},
            meeting_type => $params->{meeting_type},
        } );

        return $self->_return_meeting_basic_data( $meeting, $user );
    },
    activate_suggestion_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $params->{suggestion_id} );

        die "cound not find suggestion" unless $suggestion && $suggestion->user_id == $user->id;

        my $meeting = CTX->lookup_action('meetings_api')->e( activate_suggestion => {
            suggestion => $suggestion,
            disable_create_email => 1,
        });

        return $self->_return_meeting_basic_data( $meeting, $user );
    },
    update_meeting_5 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $begin_epoch = $params->{begin_epoch} || 0;
       $begin_epoch ||= Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{begin_date}, $params->{begin_time}, $user->timezone, $user->language ) if $params->{begin_date} && $params->{begin_time};

        my $end_epoch = $params->{end_epoch} || 0;
        $end_epoch ||= Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{end_date}, $params->{end_time}, $user->timezone, $user->language ) if $params->{end_date} && $params->{end_time};

        CTX->lookup_action('meetings_api')->e( update => {
            meeting => $meeting,
            author => $user,

            location => $params->{location},
            title => $params->{title},
            online_conferencing_option => $params->{online_conferencing_option},
            online_conferencing_data => $params->{online_conferencing_data},
            skype_account => $params->{skype_account},
            begin_epoch => $begin_epoch,
            end_epoch => $end_epoch,
            matchmaking_accepted => $params->{matchmaking_accepted},
            require_rsvp_again => $params->{require_rsvp_again},

            background_theme => $params->{background_theme},
            background_image_url => $params->{background_image_url},
            background_upload_id => $params->{background_upload_id},
            meeting_type => $params->{meeting_type},
        } );

        if ( $params->{settings} ) {
            $self->_store_meeting_settings( $meeting, $params->{settings} );
        }

        return $self->_return_meeting_basic_data( $meeting, $user );
    },
    delete_meeting_5 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => { code => 1, message => 'invalid user' } }
            unless $user->id == $meeting->creator_id;

        eval { CTX->lookup_action('meetings_api')->e( remove => { meeting => $meeting, user_id => $user->id } ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { result => $@ ? 0 : 1 };
    },
    cancel_meeting_5 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        return { error => { code => 400, message => 'could not find user'} } unless $user;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        return { error => { code => 400, message => 'could not find meeting'} } unless $meeting;

        my $user_is_participant = $self->_get_user_meeting_participation_object( $user, $meeting );
        return { error => { code => 400, message => 'could not find meeting'} } unless $user_is_participant;

        return { error => { code => 403, message => 'meeting is not cancellable' } } unless $self->_get_note( 'allow_meeting_cancel' => $meeting );

        $self->_cancel_meeting( $meeting, $params->{cancel_message}, $user );

        return { result => 1 };
    },
    decline_meeting_5 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { error => { code => 1, message => 'invalid user' } }
            unless $user->id == $meeting->creator_id;

        $self->_send_decline_meeting_email_to_reserving_user( $meeting, $params->{decline_message}, $user );

        eval { CTX->lookup_action('meetings_api')->e( remove => { meeting => $meeting, user_id => $user->id } ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { result => $@ ? 0 : 1 };
    },
    add_meeting_participant_3 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $by_user = Dicole::Utils::User->ensure_object( $params->{by_user_id} );
        my $image_size = $params->{image_size} || 50;

        if ( $self->_meeting_is_draft( $meeting ) ) {
            my $draft_participant = undef;

            if ( $params->{user_id} ) {
                my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

                # TODO: check that this is in the adding users address book

                return { error => { code => 404, message => 'no such user' } } unless $user;

                # TODO: what if new phone or email is provided here?

                my $user_data = $self->_gather_user_info( $user, $image_size, $params->{domain_id} );
                $draft_participant = $self->_add_meeting_draft_participant( $meeting, $user_data, $by_user );
            }
            elsif ( $params->{phone} ) {
                $draft_participant = $self->_add_meeting_draft_participant_by_phone_and_name( $meeting, $params->{phone}, $params->{name}, $by_user );
            }
            elsif ( $params->{email} ) {
                my $ao = Dicole::Utils::Mail->address_object_from_email_and_name( $params->{email}, $params->{name} );
                $draft_participant = $self->_add_meeting_draft_participant_by_email_object( $meeting, $ao, $by_user );
            }

            if ( $self->_clean_up_duplicate_draft_participant( $meeting, $draft_participant ) ) {
                return { error => { code => 1, message => 'similar participant already existed' } };
            }

            $self->_store_draft_participant_event( $meeting, $draft_participant, 'created', { author => $by_user } );

            return $self->_return_meeting_participant_object_data( $meeting, $draft_participant, $image_size, $self->_gather_lc_opts_from_params( $params ) );
        }
        else {
            my $user = undef;
            if ( $params->{user_id} ) {
                $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

                # TODO: check that this is in the adding users address book

                return { error => { code => 404, message => 'no such user' } } unless $user;
            }
            elsif ( $params->{phone} ) {
                $user = $self->_fetch_or_create_user_for_phone_and_name(
                    $params->{phone}, $params->{name},
                    $params->{domain_id},
                    { language => $params->{lang}, timezone => $by_user->timezone, creator_user => $by_user }
                );
            }
            elsif ( $params->{email} ) {
                my $ao = Dicole::Utils::Mail->address_object_from_email_and_name( $params->{email}, $params->{name} );
                if ( ! $ao ) {
                    return { error => { code => 422, message => 'invalid email address' } };
                }
                $user = $self->_fetch_or_create_user_for_address_object( $ao, $params->{domain_id} );
            }

            my $participant = $self->_add_user_to_meeting_unless_already_exists(
                user => $user,
                meeting => $meeting,
                by_user => $by_user,
                require_rsvp => $params->{require_rsvp},
                scheduling_disabled => $params->{scheduling_disabled},
                skip_event => $self->_get_note( current_scheduling_id => $meeting ) ? 1 : 0,
                greeting_message => $params->{greeting_message}, # legacy
                greeting_subject => $params->{greeting_subject}, # legacy
            );

            return { error => { code => 2, message => 'participant already existed' } } unless $participant;

            if ( my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) ) {
                Dicole::Utils::Gearman->dispatch_task( request_answers_from_scheduling_participant => { scheduling_id => $scheduling_id, user_id => $user->id } );
            }

            return $self->_return_meeting_participant_object_data( $meeting, $participant, $image_size, $self->_gather_lc_opts_from_params( $params ) );
        }
    },
    resend_meeting_participant_invitation_15 => sub {
        my ( $self, $params ) = @_;

        my $id = $params->{id} || '';

        my $object = $self->_get_any_participation_object_by_id( $id );
        my $meeting = $self->_ensure_meeting_object( ( split( ":", $id ) )[0] );

        my $user = Dicole::Utils::User->ensure_object( $object->user_id );
        my $by_user = Dicole::Utils::User->ensure_object( $params->{auth_user_id} );

        my $scheduling_invite_sent = 0;

        if ( my $scheduling_id = $self->_get_note_for_meeting( current_scheduling_id => $meeting ) ) {
            # TODO: check that user is part of scheduling
            if ( 1 || $self->_user_part_of_scheduling( $user, $scheduling_id ) ) {
                Dicole::Utils::Gearman->do_task( request_answers_from_scheduling_participant => { scheduling_id => $scheduling_id, user_id => $user->id, reinvite => 1 } );
                $scheduling_invite_sent = 1;
                Dicole::Utils::Gearman->dispatch_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling_id } );
            }
        }

        unless ( $scheduling_invite_sent ) {
            $self->_send_meeting_invite_mail_to_user(
                user => $user,
                meeting => $meeting,
            );
        }

        return { result => { sent => 1, type => $scheduling_invite_sent ? 'scheduling_invite' : 'normal_invite' } }
    },
    disable_meeting_participant_scheduling_15 => sub {
        my ( $self, $params ) = @_;

        my $id = $params->{id} || '';

        my $object = $self->_get_any_participation_object_by_id( $id );
        my $meeting = $self->_ensure_meeting_object( ( split( ":", $id ) )[0] );

        my $user = Dicole::Utils::User->ensure_object( $object->user_id );

        return { error => { code => 1, message => 'Creator can not leave scheduling' } } if $meeting->creator_id == $user->id;

        $self->_set_note_for_meeting_user( scheduling_disabled => time, $meeting, $user->user_id, $object, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( scheduling_disabled_by_user_id => $params->{auth_user_id}, $meeting, $user->user_id, $object );

        if ( my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) ) {
            $self->_record_scheduling_log_entry_for_user( user_removed => $scheduling_id, $params->{auth_user_id}, { user_id => $object->user_id } );
            $self->_ensure_user_scheduling_state( $object->user_id, $scheduling_id, 'removed' );
            Dicole::Utils::Gearman->dispatch_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling_id } );
        }

        return { result => { disabled => 1 } };
    },
    enable_meeting_participant_scheduling_15 => sub {
        my ( $self, $params ) = @_;

        my $id = $params->{id} || '';

        my $object = $self->_get_any_participation_object_by_id( $id );
        my $meeting = $self->_ensure_meeting_object( ( split( ":", $id ) )[0] );

        my $user = Dicole::Utils::User->ensure_object( $object->user_id );

        $self->_set_note_for_meeting_user( scheduling_disabled => 0, $meeting, $user->user_id );

        if ( my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) ) {
            $self->_record_scheduling_log_entry_for_user( user_added => $scheduling_id, $params->{auth_user_id}, { user_id => $object->user_id } );
            Dicole::Utils::Gearman->dispatch_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling_id } );
        }

        return { result => { enabled => 1 } };
    },
    # TODO: security checking
    delete_meeting_participant_5 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $by_user = Dicole::Utils::User->ensure_object( $params->{by_user_id} );
        my ( $meeting_id, $type, $type_id ) = split ":", $params->{participant_id};

        my $removed = undef;

        if ( $type eq "draft" ) {
            my $objects = $self->_fetch_meeting_draft_participation_objects( $meeting );

            my %lookup = map { $_->id => $_ } @$objects;
            my $object = $lookup{ $type_id };

            if ( $object ) {
                $removed = $object->user_id ? Dicole::Utils::User->name( $object->user_id ) : $self->_get_note( name => $object );

                $self->_remove_meeting_draft_participant( $meeting, $object, $by_user );
                $self->_store_draft_participant_event( $meeting, $object, 'removed', { author => $by_user } );
            }
        }
        else {
            my $eus = $self->_fetch_meeting_participation_objects( $meeting );
            my %lookup = map { $_->id => $_ } @$eus;

            my $rsvp = $lookup{ $type_id };
            if ( $rsvp && $meeting->creator_id != $rsvp->user_id ) {
                my $user = Dicole::Utils::User->ensure_object( $rsvp->user_id );
                $removed = Dicole::Utils::User->name( $user );

                $self->_store_participant_event( $meeting, $rsvp, 'removed', { author => $by_user } );
                $self->_remove_user_from_meeting( $user, $meeting );
            }

            if ( my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) ) {
                Dicole::Utils::Gearman->dispatch_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling_id } );
            }
        }

        return { result => $removed ? { success => 1 } : 404 };
    },
    send_draft_participant_invites_30 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $by_user = Dicole::Utils::User->ensure_object( $params->{by_user_id} );
        my $image_size = $params->{image_size} || 50;

        return { error => { code => 1, message => 'not a draft meeting' } } unless $self->_meeting_is_draft( $meeting );

        if ( $params->{title} && $params->{title} =~ /[^\s]/ ) {
            CTX->lookup_action('meetings_api')->e( update => {
                meeting => $meeting,
                author => $by_user,
                title => $params->{title},
            } ) unless $params->{title} eq $meeting->title;
        }

        if ( $params->{agenda} && $params->{agenda} =~ /[^\s]/ ) {
            my $agenda_html = $params->{agenda};
            if ( my $object = $self->_fetch_meeting_agenda_page( $meeting ) ) {
                my $content = $object->last_content_id_wiki_content->content;

                unless ( $content && $agenda_html && $content eq $agenda_html ) {
                    my $response = CTX->lookup_action('wiki_api')->e( store_raw_edit => {
                            editing_user => $by_user,
                            page => $object,
                            new_html => $agenda_html,
                            old_html => $content,
                            lock_id => 0,
                            target_group_id => $object->groups_id,
                            domain_id => $meeting->domain_id,
                        } );

                    if ( $response->{result}->{success} ) {
                        $self->_store_material_event( $meeting, $object, 'edited', { author => $by_user } );
                    }
                    else {
                        get_logger(LOG_APP)->error( "Failed to set agenda while confirming because edit failed for meeting " . $meeting->id );
                    }
                }
            }
            else {
                get_logger(LOG_APP)->error( "Failed to set agenda while confirming because could not find agenda for meeting " . $meeting->id );
            }
        }

        my $new_participants = [];
        my $draft_participant_objects = $self->_fetch_meeting_draft_participant_objects( $meeting );
        for my $draft_participant_object ( @$draft_participant_objects ) {
            my $user = undef;
            if ( $draft_participant_object->user_id ) {
                $user = Dicole::Utils::User->ensure_object( $draft_participant_object->user_id );
            }
            elsif ( $self->_get_note( phone => $draft_participant_object ) ) {
                $user = $self->_fetch_or_create_user_for_phone_and_name(
                    $self->_get_note( phone => $draft_participant_object ),
                    $self->_get_note( name => $draft_participant_object ),
                    $params->{domain_id},
                    { language => $params->{lang}, timezone => $by_user->timezone, creator_user => $by_user } );
            }
            else {
                my $ao = Dicole::Utils::Mail->address_object_from_email_and_name(
                    $self->_get_note( email => $draft_participant_object ),
                    $self->_get_note( name => $draft_participant_object ),
                );
                $user = $self->_fetch_or_create_user_for_address_object( $ao, $params->{domain_id}, { language => $params->{lang}, timezone => $by_user->timezone } );
            }

            my $participant = $self->_add_user_to_meeting_unless_already_exists(
                user => $user,
                meeting => $meeting,
                by_user => $by_user,
                require_rsvp => $params->{require_rsvp},
                skip_calculate_is_pro => 1,
                is_hidden => $self->_get_note( is_hidden => $draft_participant_object ) ? 1 : 0,
                is_planner => $self->_get_note( is_planner => $draft_participant_object ) ? 1 : 0,
                greeting_message => $params->{greeting_message}, # legacy
                greeting_subject => $params->{greeting_subject}, # legacy
            );

            $draft_participant_object->remove;

            if ( $participant && ! $self->_get_note( is_hidden => $draft_participant_object ) ) {
                push @$new_participants, $self->_return_meeting_participant_object_data( $meeting, $participant, $image_size, $self->_gather_lc_opts_from_params( $params ) );
            }
        }

        $self->_calculate_meeting_is_pro( $meeting );

        if ( scalar( @$new_participants ) ) {
            $self->_send_meeting_ical_request_mail( $meeting, $by_user, { type => 'confirm' } );
            $self->_set_note_for_meeting( draft_ready => time, $meeting );
        }

        return $new_participants;
    },
    user_meeting_contacts_30 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $domain_id = $params->{domain_id};
        my $meetings = $self->_get_user_meetings_in_domain( $user, $domain_id );
        my $participations = $self->_fetch_participant_objects_for_meeting_list( $meetings );
        my $user_id_map = { map { $_->user_id => } @$participations };
        my $users = Dicole::Utils::User->ensure_object_list( [ keys %$user_id_map ] );
        my $users_data = $self->_gather_users_info( $users, 50, $domain_id, 'skip forwarded and empty' );
        my $users_data_map = { map { $_->{user_id} => $_ } @$users_data };
        my $result = [];

        for my $user ( @$users ) {
            my $p = $users_data_map->{ $user->id };

            push @$result, {
                name => Dicole::Utils::User->name( $user ),
                email => $user->email,
                phone => ( $p ? $p->{phone} : '' ) || $user->phone,
            };
        }

        return $result;
    },
    # Deprecated in favor of the two following ones
    fetch_meeting_data_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $pos = $meeting->begin_date ? [] :  $self->_fetch_meeting_proposals( $meeting );
        my $proposals = $meeting->begin_date ? [] : $self->_gather_data_for_proposals( $pos, $user );

        my $data = $self->_return_meeting_basic_data( $meeting, $user );

        my $invite_greetings = $self->_determine_meeting_invite_greeting_default_parameters_for_user( $meeting, $user, undef, $pos );

        return {
            %$data,
            proposals => $proposals,
            invite_greetings => $invite_greetings,
        };
    },
    fetch_meeting_basic_data_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );

        return $self->_return_meeting_basic_data( $meeting, $params->{user_id} );
    },
    fetch_meeting_listing_data_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $pos = $meeting->begin_date ? [] :  $self->_fetch_meeting_proposals( $meeting );
        my $proposals = $meeting->begin_date ? [] : $self->_gather_data_for_proposals( $pos, $user );

        return {
            proposals => $proposals,
        };
    },
    fetch_meeting_extra_data_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $pos = $meeting->begin_date ? [] :  $self->_fetch_meeting_proposals( $meeting );
        my $proposals = $meeting->begin_date ? [] : $self->_gather_data_for_proposals( $pos, $user );
        my $invite_greetings = $self->_determine_meeting_invite_greeting_default_parameters_for_user( $meeting, $user, undef, $pos );

        my $suggested_agenda = '';
        my $agenda_html = '';
        my $action_points_html = '';

        if ( my $a_page = $self->_fetch_meeting_agenda_page( $meeting ) ) {
            $agenda_html = eval { $a_page->last_content_id_wiki_content->content } || '';
            get_logger(LOG_APP)->error( $@ ) if $@;
        }
        if ( my $ap_page = $self->_fetch_meeting_action_points_page( $meeting ) ) {
            $action_points_html = eval { $ap_page->last_content_id_wiki_content->content } || '';
            get_logger(LOG_APP)->error( $@ ) if $@;
        }

        if ( $self->_meeting_is_draft( $meeting ) ) {
            $suggested_agenda = $agenda_html;
        }

        my $schedulings = CTX->lookup_object('meetings_scheduling')->fetch_group( {
            where => 'meeting_id = ?',
            value => [ $meeting->id ],
        } );

        return {
            suggested_agenda => $suggested_agenda,
            agenda_html => $agenda_html,
            action_points_html => $action_points_html,
            proposals => $proposals,
            invite_greetings => $invite_greetings,
            scheduling_ids => [ map { $_->id } @$schedulings ],
        };
    },
    choose_proposal_5 => sub {
        my ( $self, $params ) = @_;
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $proposal_id = $params->{proposal_id};

        my $success = $self->_choose_proposal_for_meeting( $meeting, $proposal_id, {
            require_rsvp => $params->{require_rsvp},
            set_by_user_id => $user->id,
        } );

        return {
            success => 1
        } if $success;

        return { error => { message => 'proposal not found' } }
    },
    fetch_possibly_highlighted_meeting_list_6 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $a_day_before = time - 24*60*60;
        my $three_months_ago = time - 60*60*24*90;
        my $where = "(begin_date = 0 AND dicole_events_event.created_date > $three_months_ago) OR end_date > $a_day_before";
        my $order = 'event_id asc';

        my $meetings = $self->_get_user_meetings_in_domain(
            $user, $params->{domain_id}, $where, $order
        );

        my $result = [];
        for my $meeting ( @$meetings ) {
            next if $self->_meeting_is_cancelled( $meeting );
            push @$result, $self->_return_meeting_basic_data( $meeting, $user );
        }

        return { meetings => $result };
    },
    fetch_meeting_highlight_data_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $data = $self->_get_meeting_highlight_data_for_user( $meeting, $user );
        return $data if $data;
        return { type => 'none' };
    },
    check_client_sync_credentials_5 => sub {
        my ( $self, $params ) = @_;
        my $app = $self->_application_for_api_key( $params->{api_key}, $params->{domain_id} );
        return 0 unless $app && $params->{api_secret};
        return ( lc( $app->{api_secret} || '' ) eq lc( $params->{api_secret} ) ) ? 1 : 0;
    },
    store_client_sync_log_2 => sub {
        # For now we jsut record these to the worker logs..
        return { result => 1 };
    },
    fetch_client_sync_settings_30 => sub {
        my ( $self, $params ) = @_;
        my $app = $self->_application_for_api_key( $params->{api_key}, $params->{domain_id} );
        return {} unless $app;

        my $stash = CTX->lookup_action('meetings_api')->e( sync_get_current_stash => { domain_id => $app->{domain_id}, partner_id => $app->{partner_id} } );

        my $emails_map = {};
        for my $calhash ( values %{ $stash->{calendars_by_area} } ) {
            for my $cal ( values %$calhash ) {
                next if $cal->{disable_calendar_sync};
                next unless $stash->{users_by_area}->{ $cal->{area} }->{ $cal->{user_email} };
                next unless $stash->{offices_by_area}->{ $cal->{area} }->{ $cal->{office_full_name} };

                $emails_map->{ lc( $cal->{user_email} ) }++;
            }
        }

        my $key = Dicole::Utils::HTTP->get( 'https://versions.meetin.gs/client_sync/refresh_key');
        chomp $key;

        return { users => [ sort keys %$emails_map ], refresh_key => $key };
    },
    fetch_client_sync_user_and_source_info_5 => sub {
        my ( $self, $params ) = @_;
        my $app = $self->_application_for_api_key( $params->{api_key}, $params->{domain_id} );
        return {} unless $app;

        my $user = $self->_fetch_user_for_email( $params->{email}, $params->{domain_id} );
        return { error => { message => 'unknown user'} } unless $user;

        my $stash = CTX->lookup_action('meetings_api')->e( sync_get_current_stash => { domain_id => $app->{domain_id}, partner_id => $app->{partner_id} } );

        my $emails_map = {};
        for my $calhash ( values %{ $stash->{calendars_by_area} } ) {
            for my $cal ( values %$calhash ) {
                next if $cal->{disable_calendar_sync};
                next unless $stash->{users_by_area}->{ $cal->{area} }->{ $cal->{user_email} };
                next unless $stash->{offices_by_area}->{ $cal->{area} }->{ $cal->{office_full_name} };

                $emails_map->{ lc( $cal->{user_email} ) }++;
            }
        }

        return { error => { message => 'invalid user'} } unless $emails_map->{ lc( $user->email ) };

        return {
            user_id => $user->id,
            source_container_id => $params->{api_key},
            source_container_type => 'client_sync',
            source_container_name => $app->{calendar_container_name} || 'Company calendars',
        };
    },
    fetch_active_meeting_suggestion_list_15 => sub {
        my ( $self, $params ) = @_;
        my $user_id = $params->{user_id};
        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        return { suggestions => [] } if $self->_get_note_for_user( disable_suggestions => $user, $params->{domain_id} );

        my @where = ( 'begin_date > 0' );
        if ( my $max = $params->{start_max} ) {
            push @where, "begin_date <= $max";
        }
        if ( my $min = $params->{start_min} ) {
            push @where, "begin_date >= $min";
        }

        my $where = "(" . join( ") AND (", @where ) . ")";

        my $sort = $params->{sort} && $params->{sort} =~ /^a(sc(ending)?)?$/ ? 'asc' : 'desc';
        my $order = 'begin_date ' . $sort;

        $self->_ensure_imported_user_upcoming_meeting_suggestions( $user_id, $params->{domain_id}, $params->{force_reload} );

        my $meetings = $self->_get_upcoming_user_meetings_in_domain(
            $params->{user_id}, $params->{domain_id}, $where, $order
        );

        my %meetings_by_begin = ();
        my %meeting_by_uid = ();
        my %meeting_by_suggestion = ();

        for my $m ( @$meetings ) {
            if ( my $uid = $self->_get_meeting_uid( $m ) ) {
                $meeting_by_uid{ $uid } = $m;
            }
            if ( my $begin = $m->begin_date ) {
                my $list = $meetings_by_begin{ $begin } ||= [];
                push @$list, $m;
            }
            if ( my $from_suggestion = $self->_get_note_for_meeting( created_from_suggestion => $m ) ) {
                $meeting_by_suggestion{ $from_suggestion } = $m;
            }
        }

        my $sources = $self->_get_user_existing_suggestion_sources( $user, $params->{domain_id} );

        my $source_settings = $self->_get_note_for_user( meetings_source_settings => $user, $params->{domain_id} ) || {};
        $source_settings->{enabled} ||= {};
        $source_settings->{disabled} ||= {};

        my $hidden_sources = $self->_get_note_for_user( meetings_hidden_sources => $user, $params->{domain_id} ) || [];
        my %hidden_sources_map = map { $_ => 1 } @$hidden_sources;

        my %enabled_source_by_id = ();
        for my $source ( @$sources ) {
            next if $hidden_sources_map{ $source->uid };
            next if $source_settings->{disabled}->{ $source->uid };
            next unless $source_settings->{enabled}->{ $source->uid } ||  $self->_get_note( google_calendar_is_primary => $source ) || $self->_get_note( is_primary => $source );
            next if $source->provider_type eq 'client_sync';
            $enabled_source_by_id{ $source->uid } = 1;
        }

        push @where, Dicole::Utils::SQL->column_in_strings( source => [ keys %enabled_source_by_id ] );

        my $suggestion_where = "(" . join( ") AND (", @where ) . ")";

        my $suggestions = $self->_get_upcoming_active_user_meeting_suggestions(
            $user, $params->{domain_id}, $suggestion_where, $order
        );

        my $limit = $params->{limit} || 10;
        my $offset = $params->{offset} || 0;
        my $result = [];

        my $count = 0;
        for my $suggestion ( @$suggestions ) {
            next if $meeting_by_suggestion{ $suggestion->id };
            next if $suggestion->uid && $meeting_by_uid{ $suggestion->uid };
            if ( my $possibly_matching_meetings = $meetings_by_begin{ $suggestion->begin_date } ) {
                my $found = 0;
                for my $meeting ( @$possibly_matching_meetings ) {
                    $found = 1 if lc( $suggestion->title ) eq lc( $meeting->title );
                }
                next if $found;
            }
            $count++;
            next unless $count > $offset;
            next unless $count <= $offset + $limit;
            push @$result, $self->_return_suggestion_data( $suggestion, $params->{user_id} );
            last if $count == $offset + $limit;
        }

        return { suggestions => $result };
    },
    fetch_suggestion_participants_2 => sub {
        my ( $self, $params ) = @_;

        my $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $params->{suggestion_id} );
        my $owner = Dicole::Utils::User->ensure_object( $suggestion->user_id );

        my $address_objects = Dicole::Utils::Mail->string_to_address_objects(
            join ",", ( $owner->email, $suggestion->participant_list || () )
        );

        my $participants = [];
        my $processed_emails = {};
        my $processed_uids = {};

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

        for my $ao ( @$address_objects ) {
            my $email = Dicole::Utils::Text->internal_to_utf8( $ao->address );
            next if $processed_emails->{ $email }++;

            # This is cached for just 5 seconds so that same request does not fetch multiple times
            my $participant_info = Dicole::Cache->fetch_or_store( 'suggestion_participant_info_' . $email, sub {
                    my $user = $self->_fetch_user_for_email( $email, $params->{domain_id} );

                    if ( $user ) {
                        return $self->_gather_user_info( $user, $params->{image_size} || 30, $params->{domain_id} );
                    }
                    else {
                        my $name = Dicole::Utils::Text->internal_to_utf8( $ao->phrase || $ao->address );
                        my $initials = Dicole::Utils::User->form_user_initials_for_name( $name );
                        return {
                            name => $name,
                            initials => $initials,
                            image => '',
                        };
                    }
            }, { domain_id => $params->{domain_id}, expires => 5, no_group_id => 1 } );

            next unless $participant_info->{name};
            next if $participant_info->{user_id} && $processed_uids->{ $participant_info->{user_id} }++;

            $self->_sanitize_meeting_participant_info( undef, $participant_info, $params->{domain_id}, $domain_host, $self->_gather_lc_opts_from_params( $params ) );
            push @$participants, $participant_info;
        }

        return { participants => $participants };
    },
    ensure_meeting_suggestion_exists_5 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $suggestion_data = {
            domain_id => $params->{domain_id},
            user_id => $user->id,

            begin_date => $params->{begin_epoch},
            end_date => $params->{end_epoch},
        };

        for my $key ( qw( uid title description location source participant_list organizer source_uid source_name source_notes source_provider_id source_provider_type source_provider_name ) ) {
            $suggestion_data->{ $key } = $params->{ $key } || '';
        }

        my $suggestion = $self->_ensure_user_calendar_suggestion_exists( $user, $params->{domain_id}, $suggestion_data );

        return { result => $suggestion ? 1 : 0 };
    },
    fetch_or_create_meeting_suggestion_5 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $source = $params->{source_container_type};
        if ( $source ne 'google' ) {
            $source .= ":" . $params->{source_container_id};
        }
        $source .= ':' . $params->{source_id_inside_container};

        my $suggestion_data = {
            domain_id => $params->{domain_id},
            user_id => $user->id,

            begin_date => $params->{begin_epoch},
            end_date => $params->{end_epoch},

            source => $source,

            notes => {
                freebusy_description => $params->{freebusy_description} || undef,
                freebusy_value => $params->{freebusy_value} || undef,
                source_uid => $source,
                source_name => $params->{source_name} || '',

                source_provider_id => $params->{source_container_id} || '',
                source_provider_type => $params->{source_container_type} || '',
                source_provider_name => $params->{source_container_name} || '',

                source_notes => {
                    is_primary => $params->{source_is_primary} ? 1 : 0,
                    id_inside_container => $params->{source_id_inside_container} || '',
                },
            },
        };

        for my $key ( qw( uid title description location participant_list organizer ) ) {
            $suggestion_data->{ $key } = $params->{ $key } || '';
        }

        if ( $suggestion_data->{participant_list} && ref( $suggestion_data->{participant_list} ) eq 'ARRAY' ) {
            $suggestion_data->{participant_list} = join ",", @{ $suggestion_data->{participant_list} };
        }

        my $suggestion = $self->_ensure_user_calendar_suggestion_exists( $user, $params->{domain_id}, $suggestion_data );

        return { error => { code => 1, message => 'Could not create suggestion' } } unless $suggestion;

        return { suggestion => $self->_return_suggestion_data( $suggestion, $user ) };
    },
    trim_user_meeting_suggestions_for_source_timespan_200 => sub {
        my ( $self, $params ) = @_;

        return { result => 'skipped due to empty timespan' } unless $params->{timespan_begin_epoch} && $params->{timespan_end_epoch} && $params->{timespan_begin_epoch} < $params->{timespan_end_epoch};

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $source = $params->{source_container_type};
        if ( $source ne 'google' ) {
            $source .= ":" . $params->{source_container_id};
        }
        $source .= ':' . $params->{source_id_inside_container};

        $self->_vanish_user_calendar_suggestions_within_dates_which_are_missing_from_id_list(
            $user, $params->{domain_id}, $source, $params->{timespan_begin_epoch}, $params->{timespan_end_epoch}, $params->{suggestion_id_list}
        );

        my $sources = $self->_get_user_existing_suggestion_sources( $user, $params->{domain_id} );

        for my $s ( @$sources ) {
            next unless $s->uid eq $source;
            my $last_update = $self->_get_note( updated_date => $s );
            next if $last_update && $last_update > time - 5;
            $self->_set_note( updated_date => time, $s );
        }

        return { result => 1 };
    },
    disable_meeting_suggestion_2 => sub {
        my ( $self, $params ) = @_;

        my $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $params->{suggestion_id} );

        die "can not remove other people's suggestions"
            unless $suggestion && $params->{auth_user_id} && $params->{auth_user_id} == $suggestion->user_id;

        $suggestion->disabled_date( time );
        $suggestion->save;

        return { success => 1 };
    },
    fetch_user_suggestion_sources_30 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        $self->_ensure_user_google_calendars_are_imported( $user, $params->{domain_id} );
        my $sources = $self->_get_user_existing_suggestion_sources( $user, $params->{domain_id} );

        my $sanitized_sources = [ map { $self->_return_sanitized_suggestion_source_info( $_ ) } @$sources ];

        return { suggestion_sources => $sanitized_sources };
    },
    ensure_suggestion_source_exists_2 => sub { # deprecated?
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $suggestion_source_data = {
            uid => $params->{uid},
            name => $params->{name},
            provider_id => $params->{provider_id},
            provider_type => $params->{provider_type},
            provider_name => $params->{provider_name},
            notes => $params->{notes},
        };

        my $suggestion_source = $self->_ensure_user_suggestion_source_exists( $user, $params->{domain_id}, $suggestion_source_data );

        return { result => $suggestion_source ? 1 : 0 };
    },
    set_suggestion_sources_for_provider_5 => sub { # deprecated?
        my ( $self, $params ) = @_;

        return $self->_set_user_suggestion_sources_for_provider(
            $params->{user_id}, $params->{domain_id}, $params->{sources_list},
            $params->{provider_id}, $params->{provider_type}, $params->{provider_name},
        );
    },
    set_user_suggestion_sources_for_container_15 => sub {
        my ( $self, $params ) = @_;

        my $sources = [];
        for my $source ( @{ $params->{sources}  } ) {
            push @$sources, {
                name => $source->{name},
                notes => {
                    id_inside_container => $source->{id_inside_container},
                    is_primary => $source->{is_primary},
                },
            };
        }
        $self->_set_user_suggestion_sources_for_provider(
            $params->{user_id}, $params->{domain_id}, $sources,
            $params->{container_id}, $params->{container_type}, $params->{container_name},
        );

        return { result => 1 };
    },
    fetch_quickbar_meeting_list_15 => sub {
        my ( $self, $params ) = @_;

        return { quickbar_meetings => $self->_gather_quickbar_meetings_for_user_api( $params->{user_id}, $params->{domain_id} ) }
    },
    fetch_unscheduled_meeting_list_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $sort = $params->{sort} && $params->{sort} =~ /^a(sc(ending)?)?$/ ? 'asc' : 'desc';
        my $order = 'created_date ' . $sort;
        my $where = 'begin_date = 0';

        if ( ! $params->{include_draft} ) {
            $where .= " AND ( dicole_events_event.attend_info LIKE '%\"draft_ready\":\"1%' OR dicole_events_event.attend_info LIKE '%\"draft_ready\":1%')";
        }

        my $meetings = $self->_get_user_meetings_in_domain(
            $user, $params->{domain_id}, $where, $order
        );

        my $po_hash = $self->_fetch_proposal_hash_for_meetings( $meetings );

        my $result = [];
        for my $meeting ( @$meetings ) {
            my $data = $self->_return_meeting_basic_data( $meeting, $user );

            push @$result, {
                %$data,
                proposals => $self->_gather_data_for_proposals( $po_hash->{ $meeting->id }, $user ),
            }
        }

        return { meetings => $result };
    },
    fetch_dated_meeting_list_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $meetings = $self->_fetch_dated_meeting_list( $params );

        my $result = [];
        for my $meeting ( @$meetings ) {
            push @$result, $self->_return_meeting_basic_data( $meeting, $params->{user_id} );
        }

        return { meetings => $result };
    },
    fetch_light_dated_meeting_list_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $meetings = $self->_fetch_dated_meeting_list( $params );

        return { meetings => [ map { { id => $_->id, no_basic_data => 1 } } @$meetings ] };
    },
    fetch_meeting_participants_5 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $real_participants = $self->_gather_meeting_users_info( $meeting, $params->{image_size} || 30, $params->{domain_id}, undef, undef, undef, $self->_gather_lc_opts_from_params( $params ) );
        my $draft_participants = $self->_gather_meeting_draft_participants_info( $meeting, $params->{image_size} || 30, undef, undef, $self->_gather_lc_opts_from_params( $params ) );
        my @participants = ( @$real_participants, @$draft_participants );

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

        my $valid_participants = [];
        for my $p ( @participants ) {
            next if $p->{is_hidden} && ! ( $p->{user_id} && $p->{user_id} == $params->{user_id} );
            $self->_sanitize_meeting_participant_info( $meeting, $p, $params->{domain_id}, $domain_host, $self->_gather_lc_opts_from_params( $params ) );
            push @$valid_participants, $p;
        }

        return { participants => $self->_sort_participant_info_list( $valid_participants ) };
    },
    fetch_meeting_participant_data_1 => sub { # deprecated
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );

        # NOTE: not using common lc_opts because user_id is not the requesting user
        return $self->_return_meeting_participant_data( $meeting, $params->{user_id}, $params->{image_size}, undef, { lang => $params->{lang} } );
    },
    fetch_meeting_participant_object_data_1 => sub {
        my ( $self, $params ) = @_;

        my $id = $params->{id} || '';

        my $object = $self->_get_any_participation_object_by_id( $id );
        my $meeting = $self->_ensure_meeting_object( ( split( ":", $id ) )[0] );

        return $self->_return_meeting_participant_object_data( $meeting, $object, $params->{image_size}, $self->_gather_lc_opts_from_params( $params ) );
    },
    store_meeting_participant_data_7 => sub { # deprecated
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $proposals = $self->_fetch_meeting_proposals( $meeting );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $po = $self->_get_user_meeting_participation_object( $user, $meeting );

        return { error => { message => 'participant not found!' } } unless $user && $po;

        if ( my $proposal_answers = $params->{proposal_answers} ) {
            $self->_answer_meeting_proposals_for_user( $meeting, $proposal_answers, $user, { pos => $proposals } );
        }

        if ( my $rsvp_response = $params->{rsvp} ) {
             my $old_answer = $self->_get_note_for_meeting_user( 'rsvp', $meeting, $user, $po ) || '';

             $rsvp_response = '' unless grep { $rsvp_response eq $_ } ( qw( yes no maybe ) );
             $self->_set_note_for_meeting_user( 'rsvp', $rsvp_response, $meeting, $user, $po, { skip_save => 1 } );
             $self->_set_note_for_meeting_user( 'last_rsvp_replied', time, $meeting, $user, $po );
             $self->_store_participant_event( $meeting, $po, 'rsvp_changed' );
             if ( $rsvp_response eq 'yes' && $old_answer ne 'yes' ) {
                 $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'rsvp' } );
             }
        }

        # NOTE: not using common lc_opts because user_id is not the requesting user
        return $self->_return_meeting_participant_data( $meeting, $user, $params->{image_size}, $po, { lang => $params->{lang} } );
    },
    store_meeting_participant_object_data_7 => sub {
        my ( $self, $params ) = @_;

        my $id = $params->{id} || '';

        my $object = $self->_get_any_participation_object_by_id( $id );
        my $meeting = $self->_ensure_meeting_object( ( split( ":", $id ) )[0] );

        my $proposals = $self->_fetch_meeting_proposals( $meeting );
        my $user = $object->user_id ? Dicole::Utils::User->ensure_object( $object->user_id ) : undef;

        return { error => { message => 'participant not found!' } } unless $object;

        my $draft = ( $id =~ /draft/i ) ? 1 : 0;

        if ( my $proposal_answers = $params->{proposal_answers} ) {
            if ( $draft ) {
                if ( keys %$proposal_answers ) {
                    return { error => { message => 'draft participant proposal answering not implemented yet!' } };
                }
            }
            else {
                $self->_answer_meeting_proposals_for_user(
                    $meeting, $proposal_answers, $user, { pos => $proposals, euos => [ $object ] }
                );
            }
        }

        if ( my $rsvp_response = $params->{rsvp} ) {
             my $old_answer = $self->_get_note( 'rsvp', $object ) || '';

             $rsvp_response = '' unless grep { $rsvp_response eq $_ } ( qw( yes no maybe ) );
             $self->_set_note( 'rsvp', $rsvp_response, $object, { skip_save => 1 } );
             $self->_set_note( 'last_rsvp_replied', time, $object );

             if ( $draft ) {
                 $self->_store_draft_participant_event( $meeting, $object, 'rsvp_changed' );
             }
             else {
                 $self->_store_participant_event( $meeting, $object, 'rsvp_changed' );
             }

             if ( $rsvp_response eq 'yes' && $old_answer ne 'yes' && ! $draft ) {
                 $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'rsvp' } );
             }
        }

        return $self->_return_meeting_participant_object_data( $meeting, $object, $params->{image_size}, $self->_gather_lc_opts_from_params( $params ) );
    },
    add_meeting_material_30 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $material_name = $params->{material_name};
        my $draft_id = $params->{upload_id};
        my $user_id = $params->{user_id};

        my $prese = $self->_add_material_to_meeting_from_draft( $meeting, $draft_id, $user_id, $material_name );

        return { result => 1, material_id =>  join( ':', $meeting->id, 'media', $prese->{prese_id} ) };
    },
    fetch_meeting_materials_1 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $result = $self->_gather_material_data_params( $meeting, $self->_gather_lc_opts_from_params( $params ) );
        for my $m ( @{ $result->{materials} || [] } ) {
            $self->_sanitize_meeting_material( $meeting, $m );
        }
        return $result;
    },
    delete_meeting_material_7 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $result = $self->_gather_material_data_params( $meeting );
        for my $m ( @{ $result->{materials} || [] } ) {
            next unless $m && $m->{material_id} eq $params->{material_id};
            my $object = $self->_get_object_for_material_id( $params->{material_id} );

            return { error => { code => 1, message => 'invalid user' } }
                unless $params->{user_id} == $object->creator_id ||
                    $self->_user_can_manage_meeting( $user, $meeting );

            if ( ref( $object ) =~ /wiki/i ) {
                CTX->lookup_action('wiki_api')->e( remove_page => {
                    page_id => $object->id,
                    domain_id => $params->{domain_id},
                    user_id => $params->{user_id},
                } );
                return { result => 1 };
            }
            elsif ( ref( $object ) =~ /prese/i ) {
                CTX->lookup_action('presentations_api')->e( remove_object => {
                    prese_id => $object->id,
                    domain_id => $params->{domain_id},
                    user_id => $params->{user_id},
                } );
                return { result => 1 };
            }
        }

        return { result => 0 };
    },
    delete_meeting_material_comment_7 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        return { result => 404 } unless $meeting && $object;

        my $comment = eval {
            CTX->lookup_action('comments_api')->e( delete_comment_and_return_post => {
                object => $object,
                domain_id => $params->{domain_id},
                user_id => 0,
                group_id => $meeting->group_id,
                post_id => $params->{comment_id},
                right_to_remove_comments => $self->_user_can_manage_meeting( $params->{user_id}, $meeting ) ? 1 : 0,
                requesting_user_id => $params->{user_id},
                display_type => 'ampm',
            } );
        };

        if ( $@ ) {
            get_logger(LOG_APP)->error( "Error while removing comment: $@");
            return { result => 500 };
        }

        if ( $comment ) {
            $self->_store_comment_event( $meeting, $comment, $object, 'removed', { author => $params->{user_id} } );
            return { result => { success => 1 } };
        }
        else {
            return { result => 404 };
        }
    },
    fetch_meeting_material_data_2 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $result = $self->_gather_material_data_params( $meeting, $self->_gather_lc_opts_from_params( $params ) );
        for my $m ( @{ $result->{materials} || [] } ) {
            next unless $m && $m->{material_id} eq $params->{material_id};
            $self->_sanitize_meeting_material( $meeting, $m );

            my $object = $self->_get_object_for_material_id( $params->{material_id} );

            if ( ref( $object ) =~ /wiki/i ) {
                $m->{content} = $self->_fetch_meeting_page_content_bits( $meeting, $object );
            }
            elsif ( ref( $object ) =~ /prese/i ) {
#                my $info = CTX->lookup_action('presentations_api')->e( object_info => { prese => $object, domain_id => $params->{domain_id} } );
                my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

                $m->{download_url} = $domain_host . Dicole::URL->from_parts(
                    domain_id => $params->{domain_id}, target => 0,
                    action => 'meetings_raw', task => 'prese_download',
                    additional => [ $meeting->id, $object->id, $self->_generate_meeting_material_digest_for_user( $meeting, $object, $params->{user_id} ) ],
                );
                $m->{open_url} = $domain_host . Dicole::URL->from_parts(
                    domain_id => $params->{domain_id}, target => 0,
                    action => 'meetings_raw', task => 'prese_open',
                    additional => [ $meeting->id, $object->id, $self->_generate_meeting_material_digest_for_user( $meeting, $object, $params->{user_id} ) ],
                );
                my $prese_image_url = $object->image || '';
                my $prese_filename = 'file';

                if ( $prese_image_url =~ /^\d+$/ ) {
                    $prese_image_url = $domain_host . Dicole::URL->from_parts(
                        domain_id => $params->{domain_id}, target => 0,
                        action => 'meetings_raw', task => 'prese_image',
                        additional => [ $meeting->id, $object->id, $self->_generate_meeting_material_digest_for_user( $meeting, $object, $params->{user_id} ) ],
                    );
                }
                else {
                    unless ( $prese_image_url =~ /http.*scribd/ ) {
                        my $a = eval { CTX->lookup_object('attachment')->fetch( $object->attachment_id ) };
                        get_logger(LOG_APP)->error( $@ ) if $@;
                        if ( $a && $a->mime && $a->mime =~ /image|video/ ) {
                            $prese_image_url = $domain_host . Dicole::URL->from_parts(
                                domain_id => $params->{domain_id}, target => 0,
                                action => 'meetings_raw', task => 'prese_image',
                                additional => [ $meeting->id, $object->id, $self->_generate_meeting_material_digest_for_user( $meeting, $object, $params->{user_id} ) ],
                            );
                        }
                        elsif ( $a ) {
                            $prese_image_url = '';
                            my $filename = Dicole::Utils::HTML->encode_entities( $a->filename );
                            $prese_filename = Dicole::Utils::Text->shorten( $filename, 35 );
                        }
                    }
                }

                $m->{thumbnail_url} = $prese_image_url;

                $m->{content} = '<a href="'.$m->{open_url}.'">';
                if ( $m->{thumbnail_url} ) {
                    $m->{content} .= '<img src="'.$m->{thumbnail_url}.'" >';
                }
                else {
                    $m->{content} .= 'Download ' . $prese_filename;
                }
                $m->{content} .= '</a>';
            }
            else {
                $m->{content} = '';
            }

            return $m;
        }
        return { error => { code => 1, message => 'material not found' } };
    },
    fetch_meeting_material_comments_2 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );
        my $comments = CTX->lookup_action('comments_api')->e( get_comments_info => {
                object => $object,
                user_id => 0,
                group_id => $meeting->group_id,
                domain_id => $meeting->domain_id,
                size => $params->{image_size} || 30,
                no_default => 1,
                display_type => 'ampm',
                lang => 'en', # Not relevant
                timezone => $params->{timezone} || 'UTC',
            } );

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

        for my $comment ( @$comments ) {
            $self->_sanitize_comment( $comment, $domain_host );
        }
        return { comments => $comments };
    },
    fetch_single_meeting_material_comment_2 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );
        my $comments = CTX->lookup_action('comments_api')->e( get_comments_info => {
                object => $object,
                user_id => 0,
                group_id => $meeting->group_id,
                domain_id => $meeting->domain_id,
                size => $params->{image_size} || 30,
                no_default => 1,
                display_type => 'ampm',
                lang => 'en', # Not relevant
                timezone => $params->{timezone} || 'UTC',
            } );

        my $domain_host = $self->_get_host_for_domain( $params->{domain_id}, 443 );

        my $return_comment = 404;
        for my $comment ( @$comments ) {
            next unless $comment->{id} == $params->{comment_id};
            $return_comment = $comment;
            $self->_sanitize_comment( $return_comment, $domain_host );
            last;
        }
        return $return_comment;
    },
    add_meeting_material_comment_5 => sub {
        my ( $self, $params ) = @_;
        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        my $post = CTX->lookup_action('comments_api')->e( add_comment_and_return_post => {
            object => $object,
            user_id => 0,
            group_id => $meeting->group_id,
            domain_id => $meeting->domain_id,
            content => Dicole::Utils::HTML->text_to_html( $params->{content} ),
            parent_post_id => 0,
            requesting_user_id => $params->{user_id},
            requires_approval => 0,
            display_type => 'ampm',
        } );

        if ( $post ) {
            $self->_store_comment_event( $meeting, $post, $object, 'created', { author => $params->{user_id} } );
        }

        return $post ? { comment_id => $post->id } : { result => 500 };
    },
    start_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        my $result = CTX->lookup_action('wiki_api')->e( start_raw_edit => { editing_user => $user, page => $object, domain_id => $params->{domain_id} } );

        unless ( $result->{result} && $result->{result}{lock_id} ) {
            return { error => { code => 1, message => 'could not retrieve lock' } };
        }

        return $self->_return_sanitized_meeting_page_lock_data( $meeting, $object, $result->{result}{lock_id} );
    },
    continue_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        my $result = CTX->lookup_action('wiki_api')->e( start_raw_edit => { editing_user => $user, page => $object, domain_id => $params->{domain_id}, continue_edit => 1 } );

        unless ( $result->{result} && $result->{result}{lock_id} ) {
            return { error => { code => 1, message => 'could not retrieve lock' } };
        }

        return $self->_return_sanitized_meeting_page_lock_data( $meeting, $object, $result->{result}{lock_id} );
    },
    refresh_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $lock_id = $params->{lock_id};
        my $page = $self->_ensure_wiki_page_object( $params->{page_id} );

        my $response = CTX->lookup_action('wiki_api')->e( renew_full_lock => { editing_user => $user, page => $page, lock_id => $lock_id, domain_id => $params->{domain_id}, autosave_content => $params->{content} } );

        unless ( $response->{result} && $response->{result}{renew_succesfull} ) {
            return { error => { code => 1, message => 'could not renew lock' } };
        }

        return $self->_return_sanitized_meeting_page_lock_data( $meeting, $page, $lock_id );
    },
    cancel_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $lock_id = $params->{lock_id};
        my $page = $self->_ensure_wiki_page_object( $params->{page_id} );

        my $response = CTX->lookup_action('wiki_api')->e( cancel_raw_edit => { editing_user => $user, page => $page, lock_id => $lock_id, domain_id => $params->{domain_id} } );

        return { success => 1 };
    },
    get_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        return [] unless $params->{material_id} =~ /page/i;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        my $lock = CTX->lookup_action('wiki_api')->e(get_full_lock => { page_id => $object->id });
        return [] unless $lock && $lock->{lock_id};

        return [ $self->_return_sanitized_meeting_page_lock_data( $meeting, $object, $lock->{lock_id} ) ];
    },
    store_wiki_edit_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        my $lock_id = [ split ":", $params->{edit_id} ]->[ 2 ];

        my $response = CTX->lookup_action('wiki_api')->e( store_raw_edit => {
            editing_user => $user,
            page => $object,
            new_html => $params->{content},
            old_html => $params->{old_content},
            lock_id => $lock_id,
            target_group_id => $object->groups_id,
            domain_id => $meeting->domain_id,
        } );

        if ( $response->{result}->{success} ) {
            $self->_store_material_event( $meeting, $object, 'edited', { author => $user } );
            return $response;
        }
        else {
            return $response;
        }
    },
    rename_material_2 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $object = $self->_get_object_for_material_id( $params->{material_id} );

        if ( ref( $object ) =~ /wiki/i ) {
            $self->_rename_meeting_page( $meeting, $object, $params->{title} );
        }
        else {
            $self->_rename_meeting_media( $meeting, $object, $params->{title} );
        }

        return { success => 1 };
    },
    fetch_user_notification_2 => sub {
        my ( $self, $params ) = @_;

        my $notification = CTX->lookup_object('meetings_user_notification')->fetch( $params->{notification_id} );

        return { error => 404 } unless $notification && $notification->user_id == $params->{user_id};

        return { notification => $self->_sanitize_notification( $notification ) };
    },
    fetch_user_notifications_3 => sub {
        my ( $self, $params ) = @_;

        my $notifications = CTX->lookup_object('meetings_user_notification')->fetch_group( {
            where => 'user_id = ? AND removed_date = 0',
            value => [ $params->{user_id} ],
            order => 'created_date desc',
            limit => CTX->server_config->{dicole}{development_mode} ? 10 : 25,
        } );

        my @notifications = map { $self->_sanitize_notification( $_ ) } @$notifications;

        return { notifications => \@notifications };
    },
    mark_many_user_notifications_seen_5 => sub {
        my ( $self, $params ) = @_;

        my $now = time;

        my $notifications = CTX->lookup_object('meetings_user_notification')->fetch_group( {
            where => 'user_id = ? AND removed_date = 0',
            value => [ $params->{user_id} ],
            order => 'created_date desc',
            limit => 50,
        } );

        my %lookup = map { $_ => 1 } @{ $params->{id_list} || [] };

        for my $n ( @$notifications ) {
            next unless $lookup{ $n->id };
            next if $n->seen_date;
            $n->seen_date( $now );
            $n->save;
        }

        my @notifications = map { $self->_sanitize_notification( $_ ) } @$notifications;

        return { result => \@notifications };
    },
    mark_user_notification_read_3 => sub {
        my ( $self, $params ) = @_;

        my $now = time;

        my $n = $self->_ensure_object_of_type( meetings_user_notification => $params->{notification_id} );
        return { result => 404 } unless $n && $n->user_id == $params->{user_id};

        $n->read_date( $now );
        $n->seen_date( $now ) unless $n->seen_date;
        $n->save;

        return { result => $self->_sanitize_notification( $n ) };
    },
    fetch_user_notification_settings_2 => sub {
        my ( $self, $params ) = @_;

        my $settings = $self->_user_notification_settings_with_current_values( $params->{user_id}, $params->{domain_id}, $params->{lang } );

        return { settings => $settings };
    },
    set_user_notification_setting_value_10 => sub {
        my ( $self, $params ) = @_;

        my $value = $params->{value} ? 1 : 0;

        my $settings = $self->_notification_settings_list( $params->{lang} );
        my $setting = undef;
        for my $s ( @$settings ) {
            next unless $params->{setting_id} eq $s->{id};
            $setting = $s;
            last;
        }

        return { setting => 404 } unless $setting;

        # Until we have a good race condition logic, let's just hope this is enough for a very RC prone step
        for my $count ( 1..5 ) {
            my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
            my $values = $self->_get_note_for_user( notification_settings => $user, $params->{domain_id} ) || {};
            unless ( defined( $values->{ $setting->{id} } ) && $values->{ $setting->{id} } == $value ) {
                $values->{ $setting->{id} } = $value;
                $self->_set_note_for_user( notification_settings => $values, $user, $params->{domain_id} );
            }

            Time::HiRes::sleep( 0.1 + rand() );
        }

        $setting->{value} = $value;

        return { setting => $setting };
    },
    validate_reverse_tax_vat_15 => sub {
        my ( $self, $params ) = @_;
        my $error = $self->_check_vat_error( $params->{vat_id} );
        return $error ? "false" : "true";
    },
    create_stripe_subscription_for_user_or_email_30 => sub {
        my ( $self, $params ) = @_;

        my $user = eval {
            if ( $params->{user_id} ) {
                return Dicole::Utils::User->ensure_object( $params->{user_id} );
            }
            elsif ( $params->{email} ) {
                return $self->_fetch_or_create_user_for_email( $params->{email}, $params->{domain_id}, { language => $params->{lang}, timezone => $params->{time_zone} } );
            }
        };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { error => { code => 1, message => 'Could not find or create user' } } unless $user;

        my $current_subscription = $self->_get_user_current_subscription( $user, $params->{domain_id} );
        if ( $current_subscription ) {
            if ( ! $self->_get_note( valid_until_timestamp => $current_subscription ) ) {
                return { error => { code => 2, message => 'User already has a subscription!' } };
            }
        }

        my $type = lc( $params->{type} || '' );

        return { error => { code => 3, message => 'Unknown subscription type' } } unless ( $type eq 'monthly' ) || ( $type eq 'yearly' );

        my $token = $params->{token};

        return { error => { code => 4, message => 'Missing token' } } unless $token;

        my $coupon = $params->{coupon};

        my $company = $params->{company};
        my $country = uc( $params->{country} );
        my $vat_id = $params->{vat_id};

        my $plan = $type;

        my $european_union_countries = ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'GR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'];
        my %in_eu = map { $_ => 1 } @$european_union_countries;

        my $vat_percentage = 0;

        my $vat_error = $self->_check_vat_error( $vat_id );

        if ( ! $vat_error ) {
            $plan .= '_no_vat';
        }
        elsif ( $country && $in_eu{ $country } ) {
            return { error => { code => 99, message => 'Purchasing disabled for this country without a valid VAT ID' } } unless $country eq 'FI';
            $plan .= '_vat';
            $vat_percentage = 24;
        }
        else {
            $plan .= '_non_eu';
        }

        my $customer_id;
        my $subscription_id;
        my $paid_from;
        my $current_period_end;
        my $data;

        if ( $current_subscription && $self->_get_note( stripe_customer_id => $current_subscription ) ) {
            # NOTE: this might not be the right behaviour if plans at some point will hold more than one user count
            $paid_from = $self->_get_note( valid_until_timestamp => $current_subscription ) || 0;
            $paid_from = 0 if $paid_from < time + 60;
            $customer_id = $self->_get_note( stripe_customer_id => $current_subscription );

            my $subscription_params = {
                card => $token,
                plan => $plan,
                $paid_from ? ( trial_end => $paid_from ) : (),
                $coupon ? ( coupon => $coupon ) : (),
            };

            my ( $error, $data ) = $self->_stripe_request( post => "/v1/customers/$customer_id/subscriptions", { form => $subscription_params } );

            $error ||= 'Missing id' unless $data && $data->{id};
            if ( $error ) {
                get_logger(LOG_APP)->error( "Previous error ( $error ) had params: " . Data::Dumper::Dumper( $subscription_params ) );
                return { error => { code => 7, message => 'Failed to create subscription' } };
            }

            $subscription_id = $data->{id};
            $current_period_end = $data->{current_period_end};
        }
        else {
            $paid_from = $self->_user_trial_end_epoch( $user, $params->{domain_id} ) || 0;
            if ( $current_subscription ) {
                $paid_from = $self->_get_note( valid_until_timestamp => $current_subscription ) || 0;
            }
            $paid_from = 0 if $paid_from < time + 60;

            my $customer_params = {
                card => $token,
                plan => $plan,
                $paid_from ? ( trial_end => $paid_from ) : (),
                $coupon ? ( coupon => $coupon ) : (),

                email => $user->email,
                description => $user->id . ' ' . $user->first_name . ' ' . $user->last_name,
            };

            my $error;

            ( $error, $data ) = $self->_stripe_request( post => '/v1/customers', { form => $customer_params } );

            $error ||= 'Missing id' unless $data && $data->{id};
            $error ||= 'Missing subscription id' unless eval { $data->{subscriptions}{data}[0]{id} };

            if ( $error ) {
                get_logger(LOG_APP)->error( "Previous error ( $error ) had params: " . Data::Dumper::Dumper( $customer_params ) );
                return { error => { code => 8, message => 'Failed to create customer' } };
            }

            $customer_id = $data->{id};
            $subscription_id = $data->{subscriptions}{data}[0]{id};
            $current_period_end = $data->{subscriptions}{data}[0]{current_period_end};
        }

        my $sub = CTX->lookup_object('meetings_subscription')->new( {
                domain_id => $params->{domain_id},
                user_id => $user->id,
                subscription_id => $subscription_id,
                subscription_date => time
            } );

        $self->_set_note( plan_type => $type, $sub, { skip_save => 1 } );
        $self->_set_note( current_period_end => $current_period_end, $sub, { skip_save => 1 } );
        $self->_set_note( paid_from_timestamp => $paid_from, $sub, { skip_save => 1 } );
        $self->_set_note( customer_vat_percentage => $vat_percentage, $sub, { skip_save => 1 } );
        $self->_set_note( customer_country => $country, $sub, { skip_save => 1 } );
        $self->_set_note( customer_company => $company, $sub, { skip_save => 1 } );
        $self->_set_note( customer_vat_id => $vat_id, $sub, { skip_save => 1 } );
        $self->_set_note( stripe_plan => $plan, $sub, { skip_save => 1 } );
        $self->_set_note( stripe_customer_id => $customer_id, $sub, { skip_save => 1 } );
        $self->_set_note( stripe_subscription_id => $subscription_id, $sub, { skip_save => 1 } );
        $self->_set_note( stripe_full_data => $data, $sub );

        Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => { user_id => $user->id } );

        $self->_send_account_upgraded_mail_to_user(
            user => $user,
            domain_id => $params->{domain_id}
        );

        return {
            success => 1,
            transaction_id => $subscription_id,
        };
    },
    cancel_user_stripe_subscription_30 => sub {
        my ( $self, $params ) = @_;
        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        return { error => { code => 1, message => 'Could not find user' } } unless $user;

        my $domain_id = $params->{domain_id};

        my $subscription = $self->_get_user_current_subscription( $user, $domain_id );

        return { error => { code => 2, message => 'Could not find a subscription for the user' } } unless $subscription;

        my $cust_id = $self->_get_note( stripe_customer_id => $subscription );
        my $sub_id = $self->_get_note( stripe_subscription_id => $subscription );

        return { error => { code => 3, message => 'User subscription is not a cancellable subscription' } } unless $cust_id && $sub_id;

        my ( $error, $data ) = $self->_stripe_request( 'delete' => "/v1/customers/$cust_id/subscriptions/$sub_id?at_period_end=true" );

        $error ||= 'Missing id' unless $data && $data->{id};

        if ( $error ) {
            get_logger(LOG_APP)->error( "Previous error was: $error" );
            return { error => { code => 4, message => 'Failed to cancel subscription' } };
        }

        $self->_set_note( valid_until_timestamp => $data->{current_period_end} || time - 1, $subscription );

        Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => { user_id => $user->id } );

        return { success => 1 };
    },
    fetch_user_subscription_transactions_5 => sub {
        my ( $self, $params ) = @_;

        my $transactions = CTX->lookup_object('meetings_paypal_transaction')->fetch_group({
            where => 'user_id = ? and domain_id = ?',
            value => [ $params->{user_id}, $params->{domain_id} ],
            order => 'payment_date desc',
        });

        my $return = [];
        for my $transaction ( @$transactions ) {
            push @$return, {
                id => $transaction->id,
                amount => $self->_get_note( amount => $transaction ),
                currency => $self->_get_note( currency_code => $transaction ),
                payment_date_epoch => $transaction->payment_date,
            };
        }

        return { transactions => $return };
    },
    send_user_subscription_transaction_receipt_5 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $transaction = CTX->lookup_object('meetings_paypal_transaction')->fetch( $params->{transaction_id} );

        return { error => { code => 1 , message => "invalid user for transaction" } } unless $transaction->user_id == $user->id;

        my $timestamp = Dicole::Utils::Date->epoch_to_date_and_time_strings($transaction->{payment_date}, $user->timezone, $user->lang );
        my $timezone = Dicole::Utils::Date->timezone_info($user->timezone)->{offset_string};

        my $time_string = "$timestamp->[0] $timestamp->[1] $timezone";

        my $vat_included = 1;
        if ( $self->_get_note( payment_type => $transaction ) && ! $self->_get_note( payment_vat => $transaction ) ) {
            $vat_included = 0;
        }

        my $from_eu = 0;
        if ( $self->_get_note( payment_type => $transaction ) && $self->_get_note( payment_eu => $transaction ) ) {
            $from_eu = 1;
        }

        my $plan = $self->_get_note( payment_plan => $transaction ) || '';
        my $item_name = $self->_ncmsg( 'Meetin.gs subscription', { user => $user } );
        $item_name = $self->_ncmsg( 'Meetin.gs monthly subscription', { user => $user } ) if $plan eq 'monthly';
        $item_name = $self->_ncmsg( 'Meetin.gs yearly subscription', { user => $user } ) if $plan eq 'yearly';

        $self->_send_themed_mail(
            user      => $user,
            domain_id => $params->{domain_id},

            template_key_base => 'meetings_paypal_receipt',
            template_params   => {
                user_name    => Dicole::Utils::User->name($user),
                payment_date => $time_string,
                user_login   => $user->email,
                amount       => $self->_get_note( currency_code => $transaction ) . ' ' . $self->_get_note( amount => $transaction ),
                item_name    => $item_name,
                vat_included => $vat_included,
                from_eu => $from_eu,
            }
        );

        return { success => 1 };
    },
    disconnect_user_service_account_5 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $service = $params->{service};

        if ( $service eq 'google' ) {
            $self->_clear_user_google_tokens( $user, $params->{domain_id} );
            $self->_set_user_suggestion_sources_for_provider(
                $user, $params->{domain_id}, [], 'google', 'google', 'Google Calendar'
            );
        }
        elsif ( $service eq 'facebook' ) {
            $user->facebook_user_id( '' );
            $user->save;
        }
        else {
            return { error => { code => 1, message => 'unknown service parameter' } };
        }

        return { success => 1 };
    },
    check_latest_stripe_events_30 => sub {
        my ( $self, $params ) = @_;
        my ( $error, $data ) = $self->_stripe_request( get => "/v1/events?limit=100" );

        $error ||= 'Missing data' unless $data && $data->{data};

        return { error => $error } if $error;

        for my $event ( @{ $data->{data} } ) {
            Dicole::Utils::Gearman->dispatch_task( stripe_webhook => { event_id => $event->{id}, verified_event_data => $event } );
        }

        return { success => 1 }
    },
    fetch_stripe_coupons_11 => sub {
        my ( $self, $params ) = @_;

        my ( $error, $data ) = $self->_stripe_request( get => "/v1/coupons?limit=100" );
        my $coupons = eval { $data->{data} };
        $error ||= $@;

        if ( $error ) {
            get_logger(LOG_APP)->error( "could not get coupons: $error" );
            return { error => 'Failed to get coupon data' };
        }

        my $result = {};
        for my $coupon ( @$coupons ) {
            my $percentoff = $coupon->{percent_off};
            next unless $percentoff && $percentoff =~ /^\d+$/;

            my $id = $coupon->{id};
            my $md5 = lc( Digest::MD5::md5_hex( $id ) );
            my ( $type ) = $id =~ /(.)$/;

            my $base_monthly = 12;
            my $base_yearly = 129;

            if ( lc($type) eq 'b' || lc($type) eq 'm' ) {
                my $price = ( $base_monthly * ( 100 - $percentoff ) / 100 );
                $result->{monthly}->{ $md5 } = {
                    price => '$' . int( ( $price * 100 ) + 0.5 ) / 100,
                    price_reverse => '$' . int( 100 * ( $price / 1.24 ) + 0.5 ) / 100,
                    tax => '$' . int( 100 * ( $price - ( $price / 1.24 ) ) + 0.5 ) / 100,
                };
            }
            if ( lc($type) eq 'b' || lc($type) eq 'y' ) {
                my $price = ( $base_yearly * ( 100 - $percentoff ) / 100 );
                $result->{yearly}->{ $md5 } = {
                    price => '$' . int( ( $price * 100 ) + 0.5 ) / 100,
                    price_reverse => '$' . int( 100 * ( $price / 1.24 ) + 0.5 ) / 100,
                    tax => '$' . int( 100 * ( $price - ( $price / 1.24 ) ) + 0.5 ) / 100,
                };
            }
        }

        return $result;
    },
    fetch_latest_system_schedulings_20 => sub {
        my ( $self, $params ) = @_;

        my $schedulings = CTX->lookup_object('meetings_scheduling')->fetch_group( {
            order => 'created_date desc',
            limit => $params->{limit} || '10',
        } );

        return [ map { $self->_return_sanitized_scheduling_object( $_ ) } @$schedulings ];
    },
    fetch_scheduling_log_entries_20 => sub {
        my ( $self, $params ) = @_;

        my $entries = CTX->lookup_object('meetings_scheduling_log_entry')->fetch_group( {
            where => 'meeting_id = ? AND scheduling_id = ?',
            value => [ $params->{meeting_id}, $params->{scheduling_id} ],
            order => 'created_date asc',
        } );

        my $euos = $self->_fetch_meeting_participant_objects( $params->{meeting_id} );

        return [ map { $self->_return_sanitized_scheduling_log_entry( $_, $euos ) } @$entries ];
    },
    create_meeting_scheduling_20 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );

        # TODO: is user can not edit meeting, return error

        # TODO: if previous scheduling objects are found, a parameter should exist to copy answers from them
        # TODO: if some of the previous scheduling objects were active, disable them!? or return error?

        # TODO: should we have some special notification for this?
        # TODO: event should be fired
        if ( $meeting->begin_date ) {
            $meeting->begin_date( 0 );
            $meeting->end_date( 0 );
        }

        my $scheduling = CTX->lookup_object('meetings_scheduling')->new( {
                domain_id => $params->{domain_id},
                partner_id => $params->{partner_id} || 0,
                creator_id => $params->{auth_user_id},
                meeting_id => $meeting->id,
                created_date => time,
                cancelled_date => 0,
                completed_date => 0,
                removed_date => 0,
                notes => '',
            } );

        my @keys = qw(
            from_matchmaker_id
            duration
            planning_buffer
            confirm_automatically
            buffer
            time_zone
            available_timespans
            source_settings
            slots
            online_conferencing_option
            online_conferencing_data
            organizer_swiping_required
        );

        $self->_set_notes( { map { $_ => $params->{ $_ } } @keys }, $scheduling );

        $scheduling->save;

        my $draft_participant_objects = $self->_fetch_meeting_draft_participant_objects( $meeting );

        for my $draft_participant_object ( @$draft_participant_objects ) {
            my $user = undef;
            if ( $draft_participant_object->user_id ) {
                $user = Dicole::Utils::User->ensure_object( $draft_participant_object->user_id );
            }
            elsif ( $self->_get_note( phone => $draft_participant_object ) ) {
                $user = $self->_fetch_or_create_user_for_phone_and_name(
                    $self->_get_note( phone => $draft_participant_object ),
                    $self->_get_note( name => $draft_participant_object ),
                    $params->{domain_id},
                    { language => $params->{lang}, timezone => $params->{time_zone}, creator_user => $params->{auth_user_id} ? Dicole::Utils::User->ensure_object( $params->{auth_user_id} ) : undef } );
            }
            else {
                my $ao = Dicole::Utils::Mail->address_object_from_email_and_name(
                    $self->_get_note( email => $draft_participant_object ),
                    $self->_get_note( name => $draft_participant_object ),
                );
                $user = $self->_fetch_or_create_user_for_address_object( $ao, $params->{domain_id}, { language => $params->{lang}, timezone => $params->{time_zone} } );
            }

            my $participant = $self->_add_user_to_meeting_unless_already_exists(
                user => $user,
                meeting => $meeting,
                by_user => $params->{auth_user_id},
                require_rsvp => 0,
                skip_calculate_is_pro => 1,
                skip_event => 1,
                is_hidden => $self->_get_note( is_hidden => $draft_participant_object ) ? 1 : 0,
                is_planner => $self->_get_note( is_planner => $draft_participant_object ) ? 1 : 0,
            );

            $draft_participant_object->remove;
        }

        if ( @$draft_participant_objects ) {
            $self->_calculate_meeting_is_pro( $meeting );
            $self->_set_note_for_meeting( draft_ready => time, $meeting, { skip_save => 1 } );
        }

        $self->_set_meeting_current_scheduling( $meeting, $scheduling );
        $self->_record_scheduling_log_entry_for_user( 'scheduling_created', $scheduling, $scheduling->creator_id );

        Dicole::Utils::Gearman->dispatch_task( start_scheduling => { scheduling_id => $scheduling->id } );

        $self->_dispatch_ensure_fresh_segment_identify_for_user( $scheduling->creator_id );

        return $self->_return_sanitized_scheduling_object( $scheduling );
    },
    create_meeting_scheduling_answer_20 => sub {
        my ( $self, $params ) = @_;

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
        my $option = $self->_ensure_object_of_type( meetings_scheduling_option => $params->{option_id} );

        my $answer = CTX->lookup_object('meetings_scheduling_answer')->new( {
                domain_id => $params->{domain_id},
                meeting_id => $scheduling->meeting_id,
                scheduling_id => $scheduling->id,
                option_id => $option->id,
                created_date => time,
                removed_date => 0,
                creator_id => $params->{auth_user_id},
                user_id => $params->{auth_user_id},
                answer => $params->{answer},
                notes => ''
            } );

        $answer->save;

        my $euo = $self->_get_user_meeting_participation_object( $params->{auth_user_id}, $scheduling->meeting_id );
        $self->_set_note( scheduling_answered => time, $euo );

        my $log_type = ( $params->{answer} eq 'yes' ) ? "suggestion_accepted" : "suggestion_declined";
        $self->_record_scheduling_log_entry_for_user( $log_type, $scheduling, $params->{auth_user_id}, { suggestion_epoch => $option->begin_date } );

        Dicole::Utils::Gearman->dispatch_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling->id, skip_user_id => ( $params->{answer} eq 'no' ) ? $params->{auth_user_id} : 0 } );

        return { result => 1 }
    },
    fetch_meeting_current_scheduling_5 => sub {
        my ( $self, $params ) = @_;

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );
        my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting );

        my $return = {};

        if ( my $scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) ) {
            $return->{current_scheduling} = $self->_return_sanitized_scheduling_object( $scheduling_id );
        }

        if ( my $scheduling_id = $self->_get_note( previous_scheduling_id => $meeting ) ) {
            $return->{previous_scheduling} = $self->_return_sanitized_scheduling_object( $scheduling_id );
        }

        return $return;
    },
    fetch_scheduling_data_5 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_scheduling_id( $params );

        Dicole::Utils::Gearman->dispatch_task( ensure_user_first_scheduling_fetch_exists => { scheduling_id => $params->{scheduling_id}, user_id => $params->{user_id} } ) if $params->{direct_api_fetch};

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

        return $self->_return_sanitized_scheduling_object( $scheduling );
    },
    fetch_scheduling_answers_10 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_scheduling_id( $params );

        my $user_answers = CTX->lookup_object('meetings_scheduling_answer')->fetch_group( {
            where => 'scheduling_id = ?',
            value => [ $params->{scheduling_id} ],
            order => 'id asc',
        } );

        return { answers => [ map { $self->_return_sanitized_scheduling_answer_object( $_ ) } @$user_answers ] };
    },
    fetch_scheduling_options_10 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_scheduling_id( $params );

        my $options = CTX->lookup_object('meetings_scheduling_option')->fetch_group( {
            where => 'scheduling_id = ?',
            value => [ $params->{scheduling_id} ],
            order => 'id asc',
        } );

        return { options => [ map { $self->_return_sanitized_scheduling_option_object( $_ ) } @$options ] };
    },
    provide_next_meeting_scheduling_options_20 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_scheduling_id( $params );

        my $meeting = $self->_ensure_meeting_object( $params->{meeting_id} );

        return { error => { code => 1, message => 'This scheduling is not running' } } unless $self->_get_note( current_scheduling_id => $meeting ) == $params->{scheduling_id};

        my $user = Dicole::Utils::User->ensure_object( $params->{auth_user_id} );
        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

        my $euo = $self->_get_user_meeting_participation_object( $user, $meeting );

        if ( ! $params->{parent_option_id} ) {
            $self->_set_note( scheduling_opened => time, $euo );
            $self->_set_note_for_user( ongoing_scheduling_stored_epoch => time, $user, $params->{domain_id}, { skip_save => 1 } );
            $self->_set_note_for_user( ongoing_scheduling_id => $scheduling->id, $user, $params->{domain_id} );
            $self->_record_scheduling_log_entry_for_user( 'scheduling_opened', $scheduling, $user->id );

            # NOTE: this makes sure there is someone to wake the person up again if they fail to asnwer after opening scheduling
            Dicole::Utils::Gearman->do_delayed_task( check_if_scheduling_needs_alerts => {
                scheduling_id => $scheduling->id,
                limit_to_user_id => $user->id
            }, 10*60 );
        }

        my $prefills = {};

        my $open_options = $self->_fetch_valid_but_unanswered_scheduling_options_for_user_in_order( $scheduling, $user, $prefills );

        my $option = undef;
        my $yes_option = undef;
        my $no_option = undef;

        if ( $params->{option_id} ) {
            $option = $self->_ensure_object_of_type( meetings_scheduling_option => $params->{option_id} );
            if ( ! $option ) {
                return { error => { code => 2, message => 'Could not find option' } };
            }
        }
        else {
            $option = $open_options->[0];
            $option ||= $self->_create_a_new_scheduling_option_with_additional_answer( $scheduling, undef, $user->id, $prefills );

            if ( ! $option ) {
                return { option => { no_suggestions_left => 1 } };
            }
        }

        for my $open_option ( @$open_options ) {
            next if $open_option->id == $option->id;
            next if $params->{parent_option_id} && $open_option->id == $params->{parent_option_id};

            $yes_option = $no_option = $open_option;
            last;
        }

        if ( ! $yes_option ) {
            my $yes_answers = [ { option_id => $option->id, answer => 'yes', user_id => $params->{auth_user_id} } ];
            my $no_answers = [ { option_id => $option->id, answer => 'no', user_id => $params->{auth_user_id} } ];

            if ( $params->{parent_option_id} && $params->{parent_option_answer} ) {
                for my $answers ( $yes_answers, $no_answers ) {
                    push @$answers, { option_id => $params->{parent_option_id}, answer => $params->{parent_option_answer}, user_id => $params->{auth_user_id} };
                }
            }

            $yes_option = $self->_create_a_new_scheduling_option_with_additional_answer( $scheduling, $yes_answers, $user->id, $prefills );
            $no_option = $self->_create_a_new_scheduling_option_with_additional_answer( $scheduling, $no_answers, $user->id, $prefills );
        }

        return {
            option => $self->_return_sanitized_scheduling_option_object( $option ),
            yes_option => $self->_return_sanitized_scheduling_option_object( $yes_option ),
            no_option => $self->_return_sanitized_scheduling_option_object( $no_option ),
        };
    },
    get_user_calendar_for_timespan_30 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $sources = $self->_get_user_existing_suggestion_sources( $user, $params->{domain_id} );

        return { success => 1 } unless @$sources;

        my $begin_date = $params->{begin_epoch};
        my $end_date = $params->{end_epoch};

        my $meetings = $self->_get_user_meetings_within_epochs_in_domain( $user, $begin_date, $end_date, $params->{domain_id} );
        my $suggestions = $self->_get_nonvanished_user_suggestions_within_epochs_in_domain( $user, $begin_date, $end_date, $params->{domain_id} );

        my %meetings_by_begin = ();
        my %meeting_by_uid = ();
        my %meeting_by_suggestion = ();

        my $calendar_entries = [];

        for my $m ( @$meetings ) {
            if ( my $uid = $self->_get_meeting_uid( $m ) ) {
                $meeting_by_uid{ $uid } = $m;
            }
            if ( my $begin = $m->begin_date ) {
                my $list = $meetings_by_begin{ $begin } ||= [];
                push @$list, $m;
            }
            if ( my $from_suggestion = $self->_get_note_for_meeting( created_from_suggestion => $m ) ) {
                $meeting_by_suggestion{ $from_suggestion } = $m;
            }

            push @$calendar_entries, {
                title => $self->_meeting_title_string( $m ),
                location => $self->_meeting_location_string( $m ),
                begin_epoch => $m->begin_date,
                end_epoch => $m->end_date,
            };
        }

        my $enabled_sources = $self->_fetch_user_swiping_enabled_source_map( $user, $params->{domain_id}, $sources );

        for my $s ( @$suggestions ) {
            next unless $enabled_sources->{ $s->source };
            next if $meeting_by_suggestion{ $s->id };
            next if $s->uid && $meeting_by_uid{ $s->uid };
            if ( my $possibly_matching_meetings = $meetings_by_begin{ $s->begin_date } ) {
                my $found = 0;
                for my $meeting ( @$possibly_matching_meetings ) {
                    $found = 1 if lc( $s->title || '' ) eq lc( $meeting->title || '' );
                }
                next if $found;
            }
            push @$calendar_entries, {
                title => $s->title,
                location => $s->location || '',
                begin_epoch => $s->begin_date,
                end_epoch => $s->end_date,
            };
        }

        return { calendar_entries => [ sort { $a->{begin_epoch} <=> $b->{begin_epoch} } @$calendar_entries ] };
    },
    send_user_test_push_notification_20 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $prefix = $self->_determine_app_note_prefix( $params );
        my $push_prefix = $prefix || 'live';
        my $device_token = $params->{registration_id} || $params->{device_id};

        return { error => { code => 1, message => 'registration_id required' } } unless $device_token;

        my $available_note = join( "_", ( $prefix || () ), $params->{device_type} . '_device_available' );

        if ( ! $self->_get_note_for_user( $available_note => $user, $params->{domain_id} ) ) {
            $self->_set_note_for_user( $available_note => time, $user, $params->{domain_id} );
            $self->_queue_user_segment_event( $user, 'Push enabled iOS device registered' ) if $params->{device_type} eq 'ios';
            $self->_queue_user_segment_event( $user, 'Push enabled Android device registered' ) if $params->{device_type} eq 'android';
        }

        my $registration_id = $params->{registration_id} || $self->_determine_user_device_token_from_urbanairship( $user, $params->{domain_id}, $prefix, $params->{device_id} );

        my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $params->{domain_id} ) || { $push_prefix => {} };

        if ( $registration_id ) {
            delete $device_data->{ $push_prefix }->{ $params->{device_type} }->{available};
            $self->_set_note_for_user( device_full_push_status_map => $device_data, $user, $params->{domain_id} );

            my $notes = {
                prefix => $push_prefix,
                device_type => $params->{device_type},
                user_agent => $params->{user_agent},
                app_version => $params->{app_version},
            };

            my $stamp = Dicole::Utils::Data->signature_hex( [ $user->id, $registration_id, $notes ] );
            my $device_logs = CTX->lookup_object('meetings_push_device')->fetch_group({
                where => 'stamp = ?',
                value => [ $stamp ],
                order => 'id asc',
            });

            if ( ! @$device_logs ) {
                my $device_log = CTX->lookup_object('meetings_push_device')->new({
                    created_date => time,
                    domain_id => $params->{domain_id},
                    user_id => $user->id,
                    push_address => $registration_id,
                    stamp => $stamp,
                });

                $self->_set_notes( $notes, $device_log );

                my $new_device_logs = CTX->lookup_object('meetings_push_device')->fetch_group({
                    where => 'stamp = ?',
                    value => [ $stamp ],
                    order => 'id asc',
                });

                shift @$new_device_logs;
                $_->remove for @$new_device_logs;
            }
        }

        Dicole::Utils::Gearman->do_task( dispatch_push_notification => { limit_push => { device_type => $params->{device_type}, device_token => $params->{registration_id}, legacy_device_id => $params->{device_id}, app_prefix => $prefix || '' }, push_extra_payload => { push_test => 1 }, user_id => $params->{user_id} } );

        return { success => 1 };
    },
    set_user_device_push_status_10 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $prefix = $self->_determine_app_note_prefix( $params );
        my $push_prefix = $prefix || 'live';

        return { error => { code => 1, message => 'registration_id required' } } unless $params->{registration_id} || $params->{device_id};
        return { error => 1 } unless $params->{device_type};
        return { success => 1 } unless $params->{device_type} eq 'ios' || $params->{device_type} eq 'android';

        my $full_device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $params->{domain_id} ) || { $push_prefix => {} };

        my $registration_id = $params->{registration_id} || $self->_determine_user_device_token_from_urbanairship( $user, $params->{domain_id}, $prefix, $params->{device_id} );

        return { error => 10 } unless $registration_id;

        if ( $params->{enabled} ) {
            $full_device_data->{ $push_prefix }->{ $params->{device_type} }->{enabled}->{ $registration_id } = time;
            delete $full_device_data->{ $push_prefix }->{ $params->{device_type} }->{disabled}->{ $registration_id };
        }
        else {
            $full_device_data->{ $push_prefix }->{ $params->{device_type} }->{disabled}->{ $registration_id } = time;
            delete $full_device_data->{ $push_prefix }->{ $params->{device_type} }->{enabled}->{ $registration_id };
        }

        $self->_set_note_for_user( device_full_push_status_map => $full_device_data, $user, $params->{domain_id} );

        $self->_disable_push_token_from_other_users( $prefix, $registration_id, $params->{device_type}, $user, $params->{domain_id} ) if $params->{enabled};

        my $device_data = $self->_get_note_for_user( device_push_status_map => $user, $params->{domain_id} ) || { $prefix => {} };

        my $latest = { enabled => 0, disabled => 0 };
        for my $ed ( keys %$latest ) {
            for my $key ( keys %{ $device_data->{ $prefix }->{ $ed } || {} } ) {
                $latest->{ $ed } = List::Util::max( $latest->{ $ed }, $device_data->{ $prefix }->{ $ed }->{$key} );
            }
            for my $key ( keys %{ $full_device_data->{ $prefix }->{ $params->{device_type} }->{ $ed } || {} } ) {
                $latest->{ $ed } = List::Util::max( $latest->{ $ed }, $full_device_data->{ $prefix }->{ $params->{device_type} }->{ $ed }->{$key} );
            }
        }

        my $enabled_note = join( "_", ( $prefix || () ), $params->{device_type} . '_device_enabled' );

        # NOTE: expire enabled devices after a month BUT ONLY if other device has been disabled after that
        if ( $latest->{enabled} > $latest->{disabled} || $latest->{enabled} > time - 30*24*60*60 || ( $latest->{enabled} && ! $latest->{disabled} ) ) {
            $self->_set_note_for_user( $enabled_note => time, $user, $params->{domain_id}, { skip_save => 1 } )
                unless $self->_get_note_for_user( $enabled_note, $user, $params->{domain_id} );
        }
        else {
            $self->_set_note_for_user( $enabled_note => 0, $user, $params->{domain_id}, { skip_save => 1 } );
        }

        $user->save;

        return { success => 1 };
    },
} }

sub _create_a_new_scheduling_option_with_additional_answer {
    my ( $self, $scheduling, $additional_answers, $created_by_user_id, $prefills ) = @_;

    $additional_answers ||= [];
    $prefills ||= {};

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    my $existing_options_meta = $self->_gather_scheduling_state_metadata( $scheduling, $prefills )->{existing_options};
    my $options_by_id = { map { $_->{id} => $_->{option} } @$existing_options_meta };
    my $options_by_epochs_stamp = { map { $_->{stamp} => $_->{option} } @$existing_options_meta };

    my $tz = $self->_get_note( time_zone => $scheduling );
    my $dur = $self->_get_note( duration => $scheduling ) * 60;

    my $set = [];
    for my $option_meta ( @$existing_options_meta ) {
        next unless $option_meta->{answered_users_count};
        my $option = $option_meta->{option};
        push @$set, Dicole::Utils::Date->epochs_to_span( $option->begin_date, $option->end_date, $tz );
    }

    for my $additional_answer ( @$additional_answers ) {
        if ( my $option = $options_by_id->{ $additional_answer->{option_id} } ) {
            push @$set, Dicole::Utils::Date->epochs_to_span( $option->begin_date, $option->end_date, $tz );
        }
    }

    my $options_spanset = DateTime::SpanSet->from_spans( spans => $set );

    my $planning_buffer = $self->_get_note( planning_buffer => $scheduling ) || 30*60;
    my $week_begin_dt = Dicole::Utils::Date->epoch_to_datetime( time + $planning_buffer + 30*60 - 1 );
    $week_begin_dt->set( minute => 30 * int( $week_begin_dt->minute / 30 ), second => 0 );

    my $week_begin = $week_begin_dt->epoch;

    my $max_week_end = time + 12*7*24*60*60;

    for my $iteration ( 1..12 ) {
        my $week_end = $week_begin + 7*24*60*60 + $dur;
        $week_end = $max_week_end if $week_end > $max_week_end;
        next if $week_end < $week_begin;

        my $result_spanset = $self->_resolve_free_scheduling_spanset_within_epochs( $scheduling, $week_begin, $week_end, $options_spanset, $prefills );

        my $iter = $result_spanset->iterator;
        while ( my $span = $iter->next ) {
            next if $span->start->epoch + $dur > $span->end->epoch;

            # TODO: eliminate slot if user has answered yes for a slot just before this
            my $start_epoch = $span->start->epoch;
            my $end_epoch = $start_epoch + $dur;

            my $option = $options_by_epochs_stamp->{ $start_epoch . '-' . $end_epoch };

            if ( ! $option ) {
                $option = CTX->lookup_object('meetings_scheduling_option')->new( {
                    domain_id => $scheduling->domain_id,
                    meeting_id => $scheduling->meeting_id,
                    scheduling_id => $scheduling->id,
                    created_date => time,
                    removed_date => 0,
                    begin_date => $start_epoch,
                    end_date => $end_epoch,
                    creator_id => $created_by_user_id,
                    notes => ''
                } );

                $option->save;

                my $other_options = CTX->lookup_object('meetings_scheduling_option')->fetch_group( {
                    where => 'scheduling_id = ? AND begin_date = ? AND end_date = ?',
                    value => [ $scheduling->id, $start_epoch, $end_epoch ],
                    order => 'id asc',
                } );

                my $first = shift @$other_options;
                if ( $first->id != $option->id ) {
                    $option = $first;
                }

                eval { $_->remove for @$other_options };
                get_logger(LOG_APP)->error( $@ ) if $@;

                push @{ $prefills->{existing_options} }, $option if $prefills->{existing_options};
            }

            return $option;
        }

        $week_begin = $week_end - $dur;
    }

    return undef;
}

sub _gather_scheduling_state_metadata {
    my ( $self, $scheduling, $prefills ) = @_;

    my ( $existing_options, $user_answers, $users ) = $self->_scheduling_options_and_answers_and_users( $scheduling, $prefills );

    my $user_map = { map { $_->id => $_ } @$users };

    my $existing_options_meta = [];

    for my $option ( @$existing_options ) {
        my $option_meta = {
            id => $option->id,
            option => $option,
            begin_data => $option->begin_date,
            end_date => $option->end_date,
            answered_users => {},
            answered_users_count => 0,
            no_answer_count => 0,
            yes_answer_count => 0,
            stamp => $option->begin_date . '-' . $option->end_date,
        };

        for my $answer ( @$user_answers ) {
            next unless $user_map->{ $answer->user_id };
            next unless $answer->option_id == $option->id;
            $option_meta->{answered_users_count}++ unless $option_meta->{answered_users}->{ $answer->user_id };
            $option_meta->{answered_users}->{ $answer->user_id } = $answer->answer;
        }
        push @$existing_options_meta, $option_meta;
    }

    # NOTE: Needs a second pass to make sure edited answers are counted correctly

    for my $option_meta ( @$existing_options_meta ) {
        for my $user_id ( keys %{ $option_meta->{answered_users} } ) {
            my $answer = $option_meta->{answered_users}->{ $user_id };
            $option_meta->{no_answer_count}++ if $answer eq 'no';
            $option_meta->{yes_answer_count}++ if $answer eq 'yes';
        }
    }

    return {
        existing_options => $existing_options_meta,
    };
}

sub _resolve_free_scheduling_spanset_within_epochs {
    my ( $self, $scheduling, $begin, $end, $invalid_spanset, $prefills ) = @_;

    $prefills ||= {};

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    my $existing_options_meta = $self->_gather_scheduling_state_metadata( $scheduling, $prefills )->{existing_options};

    my $tz = $self->_get_note( time_zone => $scheduling );

    my $set = [];
    for my $option_meta ( @$existing_options_meta ) {
        next unless $option_meta->{no_answer_count};
        push @$set, Dicole::Utils::Date->epochs_to_span( $option_meta->{option}->begin_date, $option_meta->{option}->end_date, $tz );
    }

    my $options_spanset = DateTime::SpanSet->from_spans( spans => $set );

    $invalid_spanset = $invalid_spanset ? Dicole::Utils::Date->join_spansets( $options_spanset,$invalid_spanset) : $options_spanset;

    return $self->_resolve_free_scheduling_spanset_within_epochs_when_ignoring_answers(
        $scheduling, $begin, $end, $invalid_spanset, $prefills
    )
}

sub _resolve_free_scheduling_spanset_within_epochs_when_ignoring_answers {
    my ( $self, $scheduling, $begin, $end, $invalid_spanset, $prefills ) = @_;

    $prefills ||= {};

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    my $users = $prefills->{users} ||= $self->_fetch_meeting_participant_users( $scheduling->meeting_id );

    my $tz = $self->_get_note( time_zone => $scheduling );

    my $base_spanset = $self->_matchmaker_slots_to_spanset_within_epochs( $self->_get_note( slots => $scheduling ), $begin, $end, $tz );
    $base_spanset = $self->_limit_spanset_to_available_timespans( $base_spanset, $self->_get_note( available_timespans => $scheduling ), $tz );

    my $unanswered_spanset = $invalid_spanset ? $base_spanset->complement( $invalid_spanset ) : $base_spanset;

    my $creator_reserved_spanset = $self->_get_user_reservation_spanset_within_timespan_in_domain(
        $scheduling->creator_id,
        $unanswered_spanset->is_empty_set ? undef : $unanswered_spanset->span,
        $scheduling->domain_id,
        { buffer => $self->_get_note( buffer => $scheduling ), source_settings => $self->_get_note( source_settings => $scheduling ), disable_legacy_source_settings => 1 }
    );

    my $other_reserved_spanset = $self->_get_multiple_user_calendar_spanset_within_timespan_in_domain(
        [ map { $_->id == $scheduling->creator_id ? () : $_ } @$users ],
        $unanswered_spanset->is_empty_set ? undef : $unanswered_spanset->span,
        $scheduling->domain_id
    );

    return $unanswered_spanset->complement( $creator_reserved_spanset )->complement( $other_reserved_spanset );
}

sub _fetch_valid_but_unanswered_scheduling_options_for_user_in_order {
    my ( $self, $scheduling, $user, $prefills ) = @_;

    $prefills ||= {};
    my $existing_options_meta = $self->_gather_scheduling_state_metadata( $scheduling, $prefills )->{existing_options};

    my @valid_options_meta = map { $_->{no_answer_count} > 0 ? () : $_ } @$existing_options_meta;
    my @unanswered_options_meta = map { exists $_->{answered_users}->{ $user->id } ? () : $_ } @valid_options_meta;

    my @day_ordered_meta = sort { $a->{option}->begin_date <=> $b->{option}->end_date } @unanswered_options_meta;
    my @ordered_meta = sort { $b->{answered_users_count} <=> $a->{answered_users_count} } @day_ordered_meta;
    my @answered_meta = map { $_->{answered_users_count} ? $_ : () } @ordered_meta;

    my $planning_buffer = $self->_get_note( planning_buffer => $scheduling ) || 30*60;
    my $latest_start = time + $planning_buffer;

    my @still_valid_answered_meta = map { ( $_->{option}->begin_date > $latest_start ) ? $_ : () } @answered_meta;

    return [ map { $_->{option} } @still_valid_answered_meta ];
}

sub _scheduling_options_and_answers_and_users {
    my ( $self, $scheduling, $prefills ) = @_;

    return (
        $self->_fetch_scheduling_options( $scheduling, $prefills ),
        $self->_fetch_scheduling_answers( $scheduling, $prefills ),
        $self->_fetch_scheduling_users( $scheduling, $prefills ),
    );
}

sub _fetch_scheduling_options {
    my ( $self, $scheduling, $prefills ) = @_;

    $prefills ||= {};
    my $scheduling_id = $self->_ensure_object_id( $scheduling );
    return $prefills->{existing_options} || CTX->lookup_object('meetings_scheduling_option')->fetch_group( {
            where => 'scheduling_id = ?',
            value => [ $scheduling_id ],
            order => 'id asc',
        } );
}

sub _fetch_scheduling_answers {
    my ( $self, $scheduling, $prefills ) = @_;

    $prefills ||= {};
    my $scheduling_id = $self->_ensure_object_id( $scheduling );
    return $prefills->{user_answers} || CTX->lookup_object('meetings_scheduling_answer')->fetch_group( {
            where => 'scheduling_id = ?',
            value => [ $scheduling_id ],
            order => 'id asc',
        } );
}

sub _fetch_scheduling_users {
    my ( $self, $scheduling, $prefills ) = @_;

    $prefills ||= {};
    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    return $prefills->{users} if $prefills->{users};

    my $euos = $prefills->{meeting_euos} ||= $self->_fetch_meeting_scheduling_participant_objects( $scheduling->meeting_id );
    my $users = $prefills->{meeting_users} ||= $self->_fetch_meeting_participant_users( $scheduling->meeting_id, $euos );

    my $disabled_users = { map { $self->_get_note( scheduling_disabled => $_ ) ? ( $_->user_id => 1 ) : () } @$euos };

    return $prefills->{users} = [ map { $disabled_users->{ $_->id } ? () : $_ } @$users ];
}

sub BG_FUNCTIONS { {
    test_bg_gearman_1 => sub {
        return { success => 1 };
    },
    prime_ip_location_data_15 => sub {
        my ( $self, $params ) = @_;
        $self->_get_location_data_for_ip( $params->{ip} );
        return { success => 1 };
    },
    prime_user_google_contacts_255 => sub {
        my ( $self, $params ) = @_;
        $self->_fetch_or_cache_user_google_contacts( $params->{user_id}, $params->{domain_id}, $params->{force_reload} );
        return { success => 1 };
    },
    prime_calculate_user_analytics_255 => sub {
        my ( $self, $params ) = @_;

        return { disabled => 1 };

        $self->_fetch_or_calculate_user_analytics( $params->{user_id}, $params->{domain_id} );
        return { success => 1 };
    },
    prime_user_upcoming_meeting_suggestions_for_google_calendar_15 => sub {
        my ( $self, $params ) = @_;
        $self->_ensure_imported_user_upcoming_google_calendar_meeting_suggestions( $params->{user_id}, $params->{domain_id}, $params->{calendar_id}, $params->{force_reload} );
        return { success => 1 };
    },
    flush_pending_trails_for_session_255 => sub {
        my ( $self, $params ) = @_;

        my $session_id = $params->{session_id};
        my $user_id = $params->{user_id};

        my $pending_trails = CTX->lookup_object('meetings_pending_trail')->fetch_group({
                where => 'session_id = ?',
                value => [ $session_id ],
        });

        my @trails = ();
        for my $trail ( @$pending_trails ) {
            my $trail_user_id = $user_id || $trail->user_id || 0;

            my $service_status = $self->_ship_trail_to_services( $trail_user_id, $trail->payload, $trail->service_status );

            if ( $service_status && $service_status->{all} ) {
                $trail->remove;
            }
            elsif ( $service_status ) {
                $trail->service_status( Dicole::Utils::JSON->encode( $service_status ) );
                $trail->save;
            }
        }

        return { success => 1 };
    },
    update_user_data_in_trackers_255 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        my $last_update = $self->_get_note_for_user('meetings_mixpanel_user_data_updated', $user, $params->{domain_id} );

        my $token = CTX->server_config->{dicole}->{meetings_mixpanel_token} || '8ae9e1d2de8656929a3d221a2b77b8ec';

        my ( $initial_referrer_domain ) = $params->{initial_referrer} =~ /^\w+\:\/\/(?:\w*\:\w*\@)?([^\/]+)/;

        my $mixpanel_data = {
            '$set' => {
                '$first_name' => $user->first_name,
                '$last_name' => $user->last_name,
            },
            '$token' => $token,
            '$distinct_id' => $user->id,
            '$ip' => $params->{ip} || '0',
            '$initial_referrer' => $params->{initial_referrer} || '',
            '$initial_referring_domain' => $initial_referrer_domain || '',
        };

        my $response = Dicole::Utils::HTTP->post( 'http://api.mixpanel.com/engage?verbose=1', {
                data => Dicole::Utils::Data->single_line_base64_json( $mixpanel_data )
            } );

        if ( $response ) {
            my $response_data = Dicole::Utils::JSON->decode( $response );

            if( $response_data->{status} eq '1' ) {
                $self->_set_note_for_user('meetings_mixpanel_user_data_updated', time, $user, $params->{domain_id} );
            }
            else {
                get_logger(LOG_APP)->error( $response_data->{error} );
            }
        }
        return { success => 1 };
    },
    send_trail_for_user_10 => sub {
        my ( $self, $params ) = @_;
        my $user_id = $params->{user_id} || 0;
        my $data_json = $params->{data};
        my $session_id = $params->{session_id};

        my $service_update_status = $self->_ship_trail_to_services( $user_id, $data_json );

        unless ( $service_update_status && $service_update_status->{all} ) {
            CTX->lookup_object('meetings_pending_trail')->new({
                session_id => $session_id,
                user_id => $user_id,
                payload => $data_json,
                service_status => Dicole::Utils::JSON->encode( $service_update_status || {} ),
            })->save;
        }

        return { success => 1 };
    },
    dispatch_pusher_event_30 => sub {
        my ( $self, $params ) = @_;

        my $pusher = WWW::Pusher->new(
            auth_key => CTX->server_config->{dicole}{pusher_auth_key} || 'acc4855651c9884f9717',
            secret => CTX->server_config->{dicole}{pusher_secret} || 'x',
            app_id => CTX->server_config->{dicole}{pusher_app_id} || '79408',
        );

        $pusher->trigger( channel => $params->{channel}, event => $params->{event}, data => $params->{data} );

        return { success => 1 };
    },
    check_if_scheduling_needs_alerts_20 => sub {
        my ( $self, $params ) = @_;

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

        return { error => 1 } unless $scheduling;

        $self->_record_scheduling_log_entry( 'scheduling_alert_check', $scheduling->id, {} );

        return { success => 1 } if $scheduling->completed_date || $scheduling->removed_date || $scheduling->cancelled_date;

        my $meeting = $self->_ensure_meeting_object( $scheduling->meeting_id );

        return { success => 10 } if $meeting->removed_date;

        my $prefills = {};

        my $max_week_end = time + 12*7*24*60*60;

        my $valid_spanset = $self->_resolve_free_scheduling_spanset_within_epochs( $scheduling, time, $max_week_end, undef, $prefills );

        # NOTE: first we fail schedulings where everyone has left or if we are at a dead end

        my $users = $self->_fetch_scheduling_users( $scheduling, $prefills );
        my $user_count = scalar( @$users );
        my $required_duration = $self->_get_note( duration => $scheduling ) * 60;

        if ( $user_count < 2 || ! Dicole::Utils::Date->spanset_contains_duration( $valid_spanset, $required_duration ) ) {
            $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

            return { success => 100 } if $scheduling->completed_date || $scheduling->removed_date || $scheduling->cancelled_date || $self->_get_note( failed_epoch => $scheduling );

            #$scheduling->cancelled_date( time );
            $self->_set_note( failed_epoch => time, $scheduling );

            if ( $user_count < 2 ) {
                $self->_ensure_scheduling_instruction( $scheduling, 'everyone_left' );
            }
            else {
                $self->_ensure_scheduling_instruction( $scheduling, 'too_busy_people' );
            }

            #$self->_set_meeting_current_scheduling( $meeting, 0 );

            # TODO: a special notification for a situation where everyone leaves?
            $self->_record_notification(
                user_id => $scheduling->creator_id,
                date => time,
                type => 'scheduling_date_not_found',
                data => {
                    meeting_id => $meeting->id,
                    scheduling_id => $scheduling->id,
                },
            );

            for my $user ( @$users ) {
                $self->_dispatch_user_pusher_event( $user->id, 'scheduling_time_not_found', { scheduling_id => $scheduling->id } );
            }

            if ( $scheduling->created_date + 7*24*60*60 < time ) {
                if ( $scheduling->created_date + 25*60*60 < time ) {
                    $self->_ensure_scheduling_organizer_escalation_performed_for_scheduling( $scheduling );
                }
            }

            return { success => 1000 };
        }
        elsif ( $self->_get_note( failed_epoch => $scheduling ) ) {
            $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
            $self->_set_note( failed_epoch => 0, $scheduling ) if $self->_get_note( failed_epoch => $scheduling );
        }

        # NOTE: Then we check if the scheduling has succeeded

        my $existing_options_meta = $self->_gather_scheduling_state_metadata( $scheduling, $prefills )->{existing_options};
        my $organizer_swiping_required = $self->_get_note( organizer_swiping_required => $scheduling );

        for my $option_meta ( sort { $a->{begin_date} <=> $b->{begin_date} } @$existing_options_meta ) {
            my $required_yes_answers = $user_count;
            $required_yes_answers -= 1 unless $organizer_swiping_required || $option_meta->{answered_users}->{ $scheduling->creator_id };

            if ( $organizer_swiping_required && $option_meta->{yes_answer_count} == $required_yes_answers - 1 && ! $option_meta->{answered_users}->{ $scheduling->creator_id } ) {
                $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
                my $organizer_swiping_request_sent = $self->_get_note( organizer_swiping_request_sent => $scheduling );

                # TODO: change so that it takes into account user answers and resends if answers since last send
                $self->_record_notification(
                    user_id => $scheduling->creator_id,
                    date => time,
                    type => 'organizer_scheduling_answers_needed',
                    data => {
                        author_id => $scheduling->creator_id,
                        meeting_id => $scheduling->meeting_id,
                        scheduling_id => $scheduling->id,
                    },
                ) unless $organizer_swiping_request_sent;

                $self->_set_note( organizer_swiping_request_sent => time, $scheduling ) unless $organizer_swiping_request_sent;
            }

            next unless $option_meta->{yes_answer_count} >= $required_yes_answers;

            my $option = $option_meta->{option};

            # NOTE: here we still have to make sure that some calendars have not updated and disabled this option

            if ( Dicole::Utils::Date->spanset_contains_epochs( $valid_spanset, $option->begin_date, $option->end_date ) ) {
                # REASON: before locking is available, this tries to minimize duplicate times being found
                my $fresh_scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
                last if $fresh_scheduling->completed_date || $fresh_scheduling->cancelled_date;

                $self->_record_scheduling_log_entry( 'time_found', $scheduling->id, { begin_epoch => $option->begin_date } );

                $self->_set_date_for_meeting( $meeting, $option->begin_date, $option->end_date, { euos => $prefills->{meeting_euos} , set_by_user_id => $meeting->creator_id, require_rsvp_again => 0, set_from_scheduling_id => $scheduling->id } );

                return { success => 10000 };
            }
        }

        # NOTE: then we check if any of the users need to be notified
        my $most_stalled_user = 0;

        for my $user ( @$users ) {
            next if $user->id == $scheduling->creator_id;
            next if $params->{limit_to_user_id} && $params->{limit_to_user_id} != $user->id;

            my $answer_count = 0;
            my $valid_yes_answers = 0;
            for my $option_meta ( @$existing_options_meta ) {
                my $answer = $option_meta->{answered_users}->{ $user->id };
                next unless $answer;
                $answer_count++;
                next if $option_meta->{no_answer_count};
                $valid_yes_answers++;
            }

            if ( ! $valid_yes_answers ) {
                $self->_ensure_user_scheduling_state( $user->id, $scheduling, $answer_count ? 'availability_needed' : 'invited' );

                Dicole::Utils::Gearman->do_task( request_answers_from_scheduling_participant => {
                        scheduling_id => $scheduling->id,
                        user_id => $user->id,
                        request_timestamp => time,
                        more_needed => 1,
                    } ) unless $params->{skip_user_id} && $params->{skip_user_id} == $user->id;

                my $euo = $self->_fetch_meeting_participant_object_for_user( $meeting, $user->id );
                if ( my $last_request = $self->_get_note( scheduling_answers_requested => $euo ) ) {
                    $most_stalled_user ||= $last_request;
                    $most_stalled_user = List::Util::min( $most_stalled_user, $last_request );
                }
            }
            else {
                $self->_ensure_user_scheduling_state( $user->id, $scheduling, 'common_time_found' );
            }
        }

        my $missing_notification_sent = $self->_get_note( last_missing_answers_organizer_notification => $scheduling );
        if ( $missing_notification_sent && $most_stalled_user && $missing_notification_sent > $most_stalled_user ) {
            $self->_ensure_scheduling_instruction( $scheduling, 'needs_activation' );
        }
        else {
            $self->_ensure_scheduling_instruction( $scheduling, 'all_good' );
        }

        return { success => 100000 };
    },
    ensure_user_first_scheduling_fetch_exists_12 => sub {
        my ( $self, $params ) = @_;
        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
        my $euo = $self->_get_user_meeting_participation_object( $params->{user_id}, $scheduling->meeting_id );

        # Some people wills till look for notifications even though they have left the meeting
        return { success => 10 } unless $euo;

        my $last_scheduling_fetched = $self->_get_note( last_fetched_scheduling => $euo );

        return { success => 1 } if $last_scheduling_fetched && $last_scheduling_fetched == $scheduling->id;

        $self->_set_note( last_fetched_scheduling => $scheduling->id, $euo, { skip_save => 1 } );
        $self->_set_note( last_scheduling_first_fetched => time, $euo );

        $self->_record_scheduling_log_entry_for_user( 'first_scheduling_fetch', $params->{scheduling_id}, $params->{user_id}, {} );

        return { success => 10 };
    },
    start_scheduling_50 => sub {
        my ( $self, $params ) = @_;

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

        my $required_duration = $self->_get_note( duration => $scheduling ) * 60;
        my $max_week_end = time + 12*7*24*60*60;

        my $valid_spanset = $self->_resolve_free_scheduling_spanset_within_epochs( $scheduling, time, $max_week_end );

        if ( ! Dicole::Utils::Date->spanset_contains_duration( $valid_spanset, $required_duration ) ) {
            $scheduling->cancelled_date( time );
            $self->_set_note( failed_epoch => time, $scheduling );

            my $meeting = $self->_ensure_meeting_object( $scheduling->meeting_id );
            $self->_set_meeting_current_scheduling( $meeting, 0 );

            return { success => 1 }
        }

        $self->_set_note( started_epoch => time, $scheduling );
        $self->_ensure_scheduling_instruction( $scheduling, 'sending_invitations' );

        # NOTE: make sure status is checked after 25 hours to make sure we didn't fail before
        Dicole::Utils::Gearman->do_delayed_task( check_if_scheduling_needs_alerts => { scheduling_id => $scheduling->id }, 60*60*25+60 );

        Dicole::Utils::Gearman->dispatch_task( request_answers_from_scheduling_participants => { scheduling_id => $scheduling->id, ignore_user_id => $scheduling->creator_id, initial_request => 1 } );

        return { success => 1 };
    },
    request_answers_from_scheduling_participants_20 => sub {
        my ( $self, $params ) = @_;

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );
        my $meeting = $self->_ensure_meeting_object( $scheduling->meeting_id );
        my $euos = $self->_fetch_meeting_scheduling_participant_objects( $meeting );
        my $users = $self->_fetch_meeting_participant_users( $meeting, $euos );
        my $user_map = { map { $_->id => $_ } @$users };

        for my $euo ( @$euos ) {
            next if $euo->user_id == $params->{ignore_user_id};
            my $user = $user_map->{ $euo->user_id };
            next unless $user;

            Dicole::Utils::Gearman->do_task( request_answers_from_scheduling_participant => { scheduling_id => $scheduling->id, user_id => $user->id, initial_request => $params->{initial_request} } );
        }

        if ( $params->{initial_request} ) {
            $self->_ensure_scheduling_instruction( $scheduling, 'all_good' );
        }

        return { success => 1 };
    },
    request_answers_from_scheduling_participant_20 => sub {
        my ( $self, $params ) = @_;

        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling_id} );

        return { success => 1 } if $scheduling->completed_date || $scheduling->removed_date || $scheduling->cancelled_date || $self->_get_note( failed_epoch => $scheduling );

        my $meeting = $self->_ensure_meeting_object( $scheduling->meeting_id );

        return { success => 1 } if $meeting->removed_date;

        my $user = eval { Dicole::Utils::User->ensure_object( $params->{user_id} ) };
        return { error => 1 } unless $user;

        my $organizer_user = eval { Dicole::Utils::User->ensure_object( $scheduling->creator_id ) };
        return { error => 1 } unless $organizer_user;

        my $euo = $self->_get_user_meeting_participation_object( $user, $meeting );
        return { error => 1 } unless $euo;

        # TODO: grab a request lock for user in this scheduling
        my $ts = $params->{request_timestamp} || time;
        my $last_request = $self->_get_note( scheduling_answers_requested => $euo );

        if ( $params->{more_needed} && $last_request ) {
            my $last_opened = $self->_get_note( scheduling_opened => $euo );
            my $last_answer = $self->_get_note( scheduling_answered => $euo );

            if ( ! $last_opened && ! $last_answer ) {
                return { success => 1 };
            }
            my $last_action = $last_opened || $last_answer;
            $last_action = $last_answer if $last_answer && $last_answer > $last_action;

            return { success => 1 } if $last_action < $last_request;

            my $delay = $last_action - time + 10 * 60;

            if ( $delay > 0 ) {
                Dicole::Utils::Gearman->do_delayed_task( check_if_scheduling_needs_alerts => {
                    scheduling_id => $scheduling->id,
                    limit_to_user_id => $user->id
                }, $delay );

                return { delayed_execution => $delay };
            }
        }

        $self->_set_note( scheduling_answers_requested => time, $euo );

        $self->_record_notification(
            user_id => $user->id,
            date => time,
            type => $params->{more_needed} ? 'more_scheduling_answers_needed' : 'new_scheduling_answers_needed',
            data => {
                author_id => $scheduling->creator_id,
                meeting_id => $meeting->id,
                scheduling_id => $scheduling->id,
                $params->{reinvite} ? ( reinvite => 1 ) : (),
            },
        );

        $self->_ensure_user_scheduling_state( $user, $scheduling, $params->{more_needed} ? 'availability_needed' : 'invited' )
            unless $params->{reinvite};

        return { success => 1 }
    },
    record_user_contact_log_10 => sub {
        my ( $self, $params ) = @_;

        my $time = $params->{created_date} || time;
        my $success_date => $params->{success_date} || 0;
        my $user_id = Dicole::Utils::User->ensure_id( $params->{user_id} ||$params->{user} || 0 );
        my $meeting_id = $self->_ensure_object_id( $params->{meeting_id} || $params->{meeting} || 0 );
        my $scheduling_id = $self->_ensure_object_id( $params->{scheduling_id} || $params->{scheduling} || 0 );
        my $destination = $params->{contact_destination} || $params->{destination};
        my $origin = $params->{contact_origin} || $params->{origin};
        my $method = $params->{contact_method} || $params->{method};
        my $type = $params->{contact_type} || $params->{type};
        my $snippet = $params->{snippet};

        if ( $scheduling_id && ! $meeting_id ) {
            my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{scheduling} || $params->{scheduling_id} );
            $meeting_id = $scheduling->meeting_id;
        }

        my $log = CTX->lookup_object('meetings_user_contact_log')->new( {
            domain_id => $params->{domain_id},
            user_id => $user_id || 0,
            meeting_id => $meeting_id || 0,
            scheduling_id => $scheduling_id || 0,
            created_date => $time,
            success_date => $success_date || 0,
            contact_destination => $destination || '',
            contact_origin => $origin || '',
            contact_method => $method || '',
            contact_type => $type || '',
            snippet => $snippet || '',
        } );

        $self->_set_notes( $params->{data} || {}, $log );

        return { success => 1 }
    },
    record_notification_action_click_20 => sub {
        my ( $self, $params ) = @_;

        my $now = time;

        my $n = $self->_ensure_object_of_type( meetings_user_notification => $params->{notification_id} );
        my $data = $self->_get_note( data => $n );

        if ( $data && $data->{scheduling_id} && $data->{meeting_id} ) {
            my $user_id = $n->user_id;

            my $log_name = $self->_get_notification_escalation_log_entry_name_for_method( $n, $params->{notification_method} );
            $self->_record_scheduling_log_entry_for_user( $log_name . '_clicked', $data->{scheduling_id}, $user_id, { notification_id => $n->id, user_agent => $params->{user_agent} || '' } ) if $log_name;
        }

        $n->read_date( $now ) unless $n->read_date;
        $n->seen_date( $now ) unless $n->seen_date;
        $n->save;

        return { success => 1 };
    },
    send_segment_event_30 => sub {
        my ( $self, $params ) = @_;

        my $success = eval { $self->_send_segment_event( $params->{event_name}, $params->{properties} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { success => $success || '-1' };
    },
    send_segment_identify_30 => sub {
        my ( $self, $params ) = @_;

        my $success = eval { $self->_send_segment_identify( $params->{user_id}, $params->{properties} ) };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { success => $success || '-1' };
    },
    ensure_fresh_segment_identify_for_user_30 => sub {
        my ( $self, $params ) = @_;

        my $schedulings = CTX->lookup_object('meetings_scheduling')->fetch_group({
            where => 'creator_id = ?',
            value => [ $params->{user_id} ],
        });

        my $created_schedulings = scalar( @$schedulings ) || 0;
        my $completed_schedulings = 0;
        for my $s ( @$schedulings ) {
            $completed_schedulings += 1 if $s->completed_date;
        }

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $traits = {
            'Schedulings created' => $created_schedulings,
            'Schedulings completed' => $completed_schedulings,
            'Device calendar connected' => $self->_user_has_connected_device_calendar( $user, $params->{domain_id} ) ? 1 : 0,
        };

        my $stamp = Dicole::Utils::Data->signature( $traits );
        my $old_stamp = $self->_get_note_for_user( meetings_stored_segment_traits => $user, $params->{domain_id} );

        return { success => 10 } if $stamp eq $old_stamp;

        $self->_queue_user_segment_identify( $user, $traits );

        $self->_set_note_for_user( meetings_stored_segment_traits => $stamp, $user, $params->{domain_id} );

        return { success => 1 }
    },
    dispatch_push_notification_10 => sub {
        my ( $self, $params ) = @_;

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );

        my $notifications = CTX->lookup_object('meetings_user_notification')->fetch_group( {
            where => 'user_id = ? AND removed_date = 0',
            value => [ $user->id ],
            order => 'created_date desc',
            limit => CTX->server_config->{dicole}{development_mode} ? 10 : 25,
        } );

        my $notification = undef;
        my $badge = 0;

        for my $n ( @$notifications ) {
            $notification = $n if $params->{notification_id} && $n->id == $params->{notification_id};
            $badge++ unless $n->seen_date;
        }

        return { success => 100 } if $params->{notification_id} && ! $notification;

        my $notification_params = $notification ? $self->_get_notification_params_for_class( $notification, 'push', $user ) || {} : {};
        my $alert = $notification_params->{string};

        my $push_params = {
            alert => $alert || '',
            badge => $badge,
            category => $notification_params->{category},
            extra => $notification ? { nid => $notification->id } : $params->{push_extra_payload} || {},
        };

        for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet') {
            my $push_prefix = $prefix || 'live';

            if ( $params->{limit_push} && defined( $params->{limit_push}->{app_prefix} ) ) {
                next unless $params->{limit_push}->{app_prefix} eq $prefix;
            }

            if ( $prefix !~ 'swipe' && $prefix !~ 'cmeet' ) {
                next if $notification && $notification->notification_type =~ /^(.*scheduling_answers_needed|scheduling_date_found)$/
            }

            my $datas = [];
            my $results = [];
            my $sent_for_device_type = {};

            for my $device_type ( qw( ios android ) ) {
                if ( $params->{limit_push} && $params->{limit_push}->{device_type} ) {
                    next unless $params->{limit_push}->{device_type} eq $device_type;
                }

                my $tokens = $self->_fetch_enabled_user_push_tokens_of_type( $user, $params->{domain_id}, $prefix, $device_type ) || [];

                if ( $params->{limit_push} && ( $params->{limit_push}->{device_token} || $params->{limit_push}->{legacy_device_id} ) ) {
                    my $token = $params->{limit_push}->{device_token};
                    $token ||= $self->_determine_user_device_token_from_urbanairship( $user, $params->{domain_id}, $prefix, $params->{limit_push}->{legacy_device_id}, $device_type );
                    $tokens = [ $token || () ];
                }

                next unless @$tokens;

                $sent_for_device_type->{ $device_type } = 1;

                my $function = 'send_'. $device_type .'_push_notification';
                for my $token ( @$tokens ) {
                    my $push_data = { %$push_params, app_target => $prefix, token => $token };
                    push @$datas, $push_data;
                    push @$results, Dicole::Utils::Gearman->do_task( $function => $push_data );
                }
            }

            next unless @$results;

            my $segment_event = $notification ? 'Push sent' : 'Detect push sent';

            # NOTE: these might sometimes retun stuff that was not JSON serializable
            my $data_strings = [];
            for my $data ( @$datas ) {
                push @$data_strings, eval { Dicole::Utils::JSON->encode( $data ) } || Data::Dumper::Dumper( $data );
            }

            my $result_strings = [];
            for my $result ( @$results ) {
                push @$result_strings, eval { Dicole::Utils::JSON->encode( $result ) } || Data::Dumper::Dumper( $result );
            }

            $self->_queue_user_segment_event( $user, $segment_event, { data => join( ",", @$data_strings), ios => $sent_for_device_type->{ios} ? 1 : 0, android => $sent_for_device_type->{android} ? 1 : 0, prefix => $push_prefix, result => join( ",", @$result_strings ) } );

            my $log_data = $params->{log_data} || {};
            $log_data = { %$log_data, raw_payload => $data_strings, raw_response => $result_strings };
            if ( $notification ) {
                $log_data->{round} = $params->{round};
                $log_data->{notification_id} = $notification->id;
                $log_data->{type} = $notification->notification_type;
                if ( my $data = $self->_get_note( data => $notification ) ) {
                    $log_data = { %$data, %$log_data };
                }
            }
            else {
                $log_data->{type} = 'push_detect';
            }

            $log_data->{snippet} = '['.$badge.']';
            $log_data->{snippet} .= " " . [split "\n", $alert]->[0] if $alert;

            $self->_record_user_contact_log( $user, 'push', 'ua_ios', $push_prefix, $log_data ) if $sent_for_device_type->{ios};
            $self->_record_user_contact_log( $user, 'push', 'ua_android', $push_prefix, $log_data ) if $sent_for_device_type->{android};

            my $notes = { $push_prefix . '_push_sent' => time };
            $notes->{ "ios_$push_prefix" . '_push_sent'} = time if $sent_for_device_type->{ios};
            $notes->{ "android_$push_prefix" . '_push_sent'} = time if $sent_for_device_type->{android};
            $notes->{ $push_prefix . '_push_result_ok' } = $result_strings;

            $self->_set_notes( $notes, $notification ) if $notification;
        }

        return { success => 1000 };
    },
    schedule_notification_escalation_10 => sub {
        my ( $self, $params ) = @_;

        my $n = $self->_ensure_object_of_type( meetings_user_notification => $params->{notification_id} );

        # TODO lock this escalation checking

        return { error => 1 } unless $n;

        my $retry_policy = $self->_get_notification_escalation_policy( $n );

        return { success => 1 } unless $retry_policy;
        return { success => 10 } if $retry_policy->{disband_check} && $retry_policy->{disband_check}->();

        my $act_log = {
            last_act => 0,
            push_count => 0,
            email_count => 0,
            sms_count => 0,
            organizer_count => 0,
        };

        my $act_keys = {
            'P' => { sent_note => 'push_sent', type => 'push' },
            'E' => { sent_note => 'escalation_email_sent', type => 'email' },
            'I' => { sent_note => 'escalation_ical_sent', type => 'ical' },
            'S' => { sent_note => 'escalation_sms_sent', type => 'sms' },
            'O' => { sent_note => 'organizer_notification_sent', type => 'organizer' },
        };

        # NOTE: depending on user and notification type, here are some examples:
        # NOTE: P,15,S,30,P,30,S,120,O
        # NOTE: E,120,E,2400,E,120,O

        for my $act ( split /\s*\,\s*/, $retry_policy->{actions} ) {
            if ( $act =~ /^(E|I|P|S|O)$/ ) {
                my $sent_note = $act_keys->{$act}->{sent_note};

                my $type = $act_keys->{$act}->{type};
                my $type_count = $type . '_count';

                $sent_note .= '_' . $act_log->{$type_count} if $act_log->{$type_count};

                if ( my $sent = $self->_get_note( $sent_note, $n ) ) {
                    $act_log->{last_act} = $sent;
                }
                else {
                    Dicole::Utils::Gearman->dispatch_task( escalate_notification => { notification_id => $n->id, escalation_method => $type, method_round => $act_log->{$type_count} } );
                    $act_log->{last_act} = time;
                }
                $act_log->{$type_count}++;
            }
            elsif ( $act =~ /^\d+$/ ) {
                my $next_act = $act*60 + $act_log->{last_act};
                if ( time < $next_act ) {
                    Dicole::Utils::Gearman->do_delayed_task( schedule_notification_escalation => { notification_id => $n->id }, $next_act - time );
                    return { success => 1000 };
                }
            }
            else {
                get_logger(LOG_APP)->error("unknown retry policy token");
            }
        }

        return { success => 10000 };
    },
    escalate_notification_10 => sub {
        my ( $self, $params ) = @_;

        my $n = $self->_ensure_object_of_type( meetings_user_notification => $params->{notification_id} );

        return { error => 1 } unless $n;

        my $type = $n->notification_type;
        my $method = $params->{escalation_method};
        my $round = $params->{method_round};

        my $sent_note = {
            push => 'push_sent',
            email => 'escalation_email_sent',
            ical => 'escalation_ical_sent',
            sms => 'escalation_sms_sent',
            organizer => 'organizer_notification_sent',
        }->{ $method };

        $sent_note .= '_' . $round if $sent_note && $round;
        return { success => 1 } if $sent_note && $self->_get_note( $sent_note => $n );

        my $user = Dicole::Utils::User->ensure_object( $n->user_id );

        my $retry_policy = $self->_get_notification_escalation_policy( $n, $user );

        return { success => 10 } unless $retry_policy;
        return { success => 100 } if $retry_policy->{disband_check} && $retry_policy->{disband_check}->();

        # NOTE: this is refreshed to have less race conditions, locking would help too
        $n = $self->_ensure_object_of_type( meetings_user_notification => $params->{notification_id} );

        return { success => 1 } if $sent_note && $self->_get_note( $sent_note => $n );
        $self->_set_note( $sent_note => time, $n ) if $sent_note;

        my $data = $self->_get_note( data => $n );

        my $segment_data = {
            sms => [ 'Notification SMS sent', { phone => $user->phone, type => $type } ],
            email => [ 'Notification Email sent', { email => $user->email, type => $type } ],
            ical => [ 'Notification Ical sent', { email => $self->_get_note_for_user( ics_email => $user, $n->domain_id) || $user->email, type => $type } ],
        }->{$method};

        my $scheduling = $data->{scheduling_id} ? $self->_ensure_object_of_type( meetings_scheduling => $data->{scheduling_id} ) : undef;
        if ( $scheduling ) {
            $self->_queue_user_scheduling_segment_event( $user, $scheduling, @$segment_data ) if $segment_data;

            my $log_entry = $self->_get_notification_escalation_log_entry_name_for_method( $n, $method );

            $self->_record_scheduling_log_entry( $log_entry, $scheduling, { user_id => $user->id } ) if $log_entry;
        }

        my $notification_params = $self->_get_notification_params_for_class( $n, $method, $user );

        if ( ! $notification_params && $method ne 'organizer' ) {
            get_logger(LOG_APP)->error( "could not find $method notification params for $type when escalating " . $n->id );
            Dicole::Utils::Gearman->do_delayed_task( schedule_notification_escalation => { notification_id => $n->id }, 0 );
            return { error => 1 };
        }

        my $log_data = { %$data, round => $round, notification_id => $n->id, type => $type };

        if ( $method eq 'sms' ) {
            $self->_send_user_sms( $user, $notification_params->{string}, { domain_id => $n->domain_id, log_data => $log_data } );
        }
        elsif ( $method eq 'email' ) {
            $self->_send_partner_themed_mail( %$notification_params, log_data => $log_data );
        }
        elsif ( $method eq 'ical' ) {
            # TODO: refactor later
        }
        elsif ( $method eq 'push' ) {
            Dicole::Utils::Gearman->do_task( dispatch_push_notification => { notification_id => $n->id, user_id => $user->id, round => $round } );
        }
        elsif ( $method eq 'organizer' ) {
            $self->_ensure_scheduling_organizer_escalation_performed_for_notification( $n, $scheduling );
        }

        return { success => 10 };
    },
    recalculate_user_pro_255 => sub {
        my ( $self, $params ) = @_;

        return { error => 1 } unless $self->_validate_params_user_id( $params );

        my $user = Dicole::Utils::User->ensure_object( $params->{user_id} );
        $self->_calculate_user_is_pro( $user, $params->{domain_id} );

        return { success => 1 };
    },
    record_notification_for_user_10 => sub {
        my ( $self, $params ) = @_;

        my $date = $params->{date} || time;
        my $type = $params->{type} || die "No type specified for notification";

        my $notification = CTX->lookup_object('meetings_user_notification')->new( {
            domain_id => $params->{domain_id},
            user_id => $params->{record_for_user_id},
            created_date => $date,
            removed_date => 0,
            seen_date => 0,
            read_date => 0,
            is_important => 0,
            notification_type => $type,
        } );

        $self->_set_note( data => $params->{data}, $notification, { skip_save => 1 } );
        $notification->save;

        if ( $type =~ /.*scheduling_answers_needed$/ ) {
            eval {
                my $po = $self->_get_user_meeting_participation_object( $params->{record_for_user_id}, $params->{data}->{meeting_id} );
                $self->_set_note( latest_scheduling_invite_notification_id => $notification->id, $po );
            };

            get_logger(LOG_APP)->error( $@ ) if $@;
        }

        Dicole::Utils::Gearman->do_delayed_task( schedule_notification_escalation => {
            notification_id => $notification->id
        }, 2 );

        return { success => 1 };
    },
    record_scheduling_log_entry_5 => sub {
        my ( $self, $params ) = @_;

        my $time = $params->{created_date} || time;

        my $entry = CTX->lookup_object('meetings_scheduling_log_entry')->new({
            domain_id => $params->{domain_id},
            meeting_id => $params->{meeting_id},
            scheduling_id => $params->{scheduling_id},
            author_id => $params->{author_id} || 0,
            created_date => $time,
            entry_date => $params->{entry_date} || $time,
            entry_type => $params->{entry_type} || '',
        });

        my $data = $params->{data} || {};

        $self->_set_note( data => $params->{data} || {}, $entry );

        $self->_dispatch_meeting_pusher_event( $params->{meeting_id}, 'new_scheduling_log_entries', { scheduling_id => $params->{scheduling_id}, entry_id => $entry->id } );

        return { success => 1 };
    },
    record_user_activity_5 => sub {
        my ( $self, $params ) = @_;

        my $dt = Dicole::Utils::Date->epoch_to_datetime( $params->{date}, 'UTC', 'en' );

        my $original_minute = $dt->minute;

        $dt->set_minute( 0 );
        $dt->set_second( 0 );

        my $floored_epoch = $dt->epoch;
        my $last_floored_epoch = $floored_epoch;

        if ( $original_minute == 0 ) {
            $dt->subtract( hours => 1 );
            $last_floored_epoch = $dt->epoch;
        }

        my $data = {
            user_id => $params->{user_id},
            floored_date => $floored_epoch,
            unmanned => $params->{unmanned} ? 1 : 0,
            user_agent => $params->{user_agent} || '',
            app_version => $params->{app_version} || '',
            ip => $params->{ip},
        };

        # Remove the weird changing number from the Appgyver user agents
        $data->{user_agent} =~ s/\(\d+\)\s*$//;

        my $stamp = Dicole::Utils::Data->signature_hex( $data );

        return { success => 1 } if Dicole::Cache->_is_locked( $stamp );

        my $last_stamp = ( $floored_epoch == $last_floored_epoch ) ? $stamp : Dicole::Utils::Data->signature_hex( { %$data, floored_date => $last_floored_epoch } );

        unless ( $floored_epoch == $last_floored_epoch ) {
            return { success => 1 } if Dicole::Cache->_is_locked( $last_stamp );
        }

        # TODO: if server could not be reached, this should still pass
        return { success => 1 } unless Dicole::Cache->_lock( $stamp );

        my $records = CTX->lookup_object('meetings_user_activity')->fetch_group( {
            where => 'stamp = ? OR stamp = ?',
            value => [ $stamp, $last_stamp ],
        } );

        return { success => 1 } if @$records;

        $data->{stamp} = $stamp;

        my $record = CTX->lookup_object('meetings_user_activity')->new( $data );
        $record->save;

        my $current_records = CTX->lookup_object('meetings_user_activity')->fetch_group( {
            where => 'stamp = ?',
            value => [ $stamp ],
            order => 'id asc',
        } );

        my $first_record = shift @$current_records;
        if ( $first_record->id == $record->id ) {
            Dicole::Utils::Gearman->dispatch_task( fill_user_activity_record => {
                id => $record->id,
            } );
        }
        else {
            $_->remove for @$records;
        }

        return { success => 1 };
    },
    fill_user_activity_record_100 => sub {
        my ( $self, $params ) = @_;
        my $record = CTX->lookup_object('meetings_user_activity')->fetch( $params->{id} );
        return { success => 0 } unless $record;

        eval {
            return unless $record->ip;
            my $country = Geo::IP->new()->country_code_by_addr( $record->ip );
            return unless $country;
            return if $record->country && $country && $record->country eq $country;

            $record->country( $country );
            $record->save;

            return unless $record->user_id;

            my $user = Dicole::Utils::User->ensure_object( $record->user_id );
            my $old_code = $self->_get_note_for_user( 'meetings_presumed_country_code', $user, $params->{domain_id} ) || '';
            if ( ! $old_code || ( $old_code ne $country ) ) {
                my $records = CTX->lookup_object('meetings_user_activity')->fetch_group( {
                    where => 'user_id = ? and floored_date > ?',
                    value => [ $user->id, time - 2*31*24*60*60 ],
                    order => 'id asc',
                } );

                my $code_counts = {};
                for my $record ( @$records ) {
                    next unless $record->country;
                    next if $record->unmanned;
                    $code_counts->{ $record->country } += 1;
                }

                my $selected_code = '';
                my $selected_count = 0;
                for my $code ( keys %{ $code_counts } ) {
                    next if $code_counts->{ $code } <= $selected_count;
                    $selected_count = $code_counts->{ $code };
                    $selected_code = $code;
                }

                if ( $selected_code && ( $selected_code ne $old_code ) ) {
                    my $fresh_user = CTX->lookup_object('user')->fetch( $user->id );
                    $self->_set_note_for_user( 'meetings_presumed_country_code', $selected_code, $fresh_user, $params->{domain_id} );
                }
            }
        };
        get_logger(LOG_APP)->error( $@ ) if $@;

        return { success => 1 };
    },
    stripe_webhook_20 => sub {
        my ( $self, $params ) = @_;

        my $event_id = $params->{event_id};

        my $existing_events = CTX->lookup_object('meetings_stripe_event')->fetch_group( {
            where => 'event_id = ?',
            value => [ $event_id ],
        } );

        if ( @$existing_events ) {
            return { success => 1 } unless $params->{reprocess};
        }

        my $error;
        my $data = $params->{verified_event_data};

        if ( ! $data ) {
            ( $error, $data ) = $self->_stripe_request('get', "/v1/events/$event_id")
        }

        $error ||= 'Missing id' unless $data && $data->{id};

        if ( $error ) {
            get_logger(LOG_APP)->error( "Previous error was ( $error ) for event $event_id: " . Dicole::Utils::JSON->encode( $data ) );
            return 500;
        }

        $existing_events = CTX->lookup_object('meetings_stripe_event')->fetch_group( {
            where => 'event_id = ?',
            value => [ $event_id ],
        } );

        if ( @$existing_events ) {
            return { success => 1 } unless $params->{reprocess};
        }
        else {
            my $stored_event= CTX->lookup_object('meetings_stripe_event')->new( {
                    domain_id => $params->{domain_id},
                    event_id => $params->{event_id},
                    stored_date => time,
                    created_date => $data->{created},
                    payload => Dicole::Utils::JSON->encode( $data ),
                } );

            $stored_event->save;

            $existing_events = CTX->lookup_object('meetings_stripe_event')->fetch_group( {
                    where => 'event_id = ?',
                    value => [ $event_id ],
                    order => 'id asc',
                } );

            if ( $stored_event->id != $existing_events->[0]->id ) {
                $stored_event->remove;
                return { success => 1 };
            }
        }

        if ( $data->{type} eq 'charge.succeeded' ) {
            my $charge = $data->{data}->{object};

            my $customer_id = $charge->{customer};
            my ( $error, $customer_data ) = $self->_stripe_request( get => "/v1/customers/$customer_id" );

            $customer_data ||= {};
            my $customer_email = $customer_data->{email};
            $error ||= 'No email found for customer' unless $customer_email;

            my $user = $customer_email ? $self->_fetch_user_for_email( $customer_email, $params->{domain_id} ) : undef;
            if ( $error || ! $user ) {
                get_logger(LOG_APP)->error("Failed to find user for charge " . $event_id . " : $error" );
                return { success => 1 };
            }

            my $type = $charge->{statement_description};

            my ( $vat ) = $type =~ /vat(\d+)/;
            $vat ||= 0;

            my $eu = ( $type =~ /f/ ) ? 0 : 1;

            my $plan = 'monthly';
            $plan = 'yearly' if $type =~ /y/;

            my $notes = {
                currency_code => uc( $charge->{currency} ),
                amount => sprintf( "%.2f", $charge->{amount} / 100 ),
                payment_date => $charge->{created},
                payment_type => $type,
                payment_plan => $plan,
                payment_vat => $vat,
                payment_eu => $eu,
            };

            my $transaction = CTX->lookup_object('meetings_paypal_transaction')->new({
                user_id => $user->id,
                domain_id => $params->{domain_id},
                received_date => time,
                payment_date => $charge->{created},
                transaction_id => $charge->{id},
                notes => Dicole::Utils::JSON->encode( $notes ),
            });

            $transaction->save;

            Dicole::Utils::Gearman->dispatch_task( send_user_subscription_transaction_receipt => {
                user_id => $user->id,
                transaction_id => $transaction->id,
            } );
        }
        elsif ( $data->{type} eq 'customer.subscription.deleted' ) {
            my $stripe_sub = $data->{data}->{object};
            my $subscription_id = $stripe_sub->{id};

            my $subscriptions = CTX->lookup_object('meetings_subscription')->fetch_group( {
                where => 'subscription_id = ?',
                value => [ $subscription_id ],
                order => 'id asc',
            } );

            my $subscription = shift @$subscriptions;
            if ( ! $subscription ) {
                get_logger(LOG_APP)->error("Failed to subscription to cancel for event " . $event_id );
                return { success => 1 };
            }
            $self->_set_note( valid_until_timestamp => $stripe_sub->{current_period_end}, $subscription );

            Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => {
                user_id => $subscription->user_id,
            } );
        }
        elsif ( $data->{type} eq 'customer.subscription.updated' ) {
            my $stripe_sub = $data->{data}->{object};
            my $subscription_id = $stripe_sub->{id};

            my $subscriptions = CTX->lookup_object('meetings_subscription')->fetch_group( {
                where => 'subscription_id = ?',
                value => [ $subscription_id ],
                order => 'id asc',
            } );

            my $subscription = shift @$subscriptions;
            if ( ! $subscription ) {
                get_logger(LOG_APP)->error("Failed to subscription to update for event " . $event_id );
                return { success => 1 };
            }
            $self->_set_note( current_period_end => $stripe_sub->{current_period_end}, $subscription );

            Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => {
                user_id => $subscription->user_id,
            } );
        }
    },

    # NOTE: These are actually presentations core, but it doesn't have workers "yet"
    retrieve_new_box_image_for_prese_30 => sub {
        my ( $self, $params ) = @_;

        return CTX->lookup_action('presentations_api')->e( retrieve_new_box_image_for_prese => {
            prese_id => $params->{prese_id},
            round => $params->{round} || 1,
        } );
    },
    upload_new_box_file_222 => sub {
        my ( $self, $params ) = @_;

        return CTX->lookup_action('presentations_api')->e( upload_new_box_file => {
            prese_id => $params->{prese_id},
        } );
    },
} }

sub AG_FUNCTIONS { {
    test_ag_gearman_1 => sub {
        return { success => 1 };
    },
    recalculate_company_subscription_pro_255 => sub {
        my ( $self, $params ) = @_;

        my $assignments = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
            where =>'removed_date = 0 AND subscription_id = ?',
            value => [ $params->{subscription_id} ],
            order => 'id asc',
        } );

        for my $a ( @$assignments ) {
            Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => {
                user_id => $a->user_id,
            } );
        }
    },
    prime_user_upcoming_meeting_suggestions_17 => sub {
        my ( $self, $params ) = @_;
        $self->_ensure_imported_user_upcoming_meeting_suggestions( $params->{user_id}, $params->{domain_id}, $params->{force_reload} );
        return { result => 1 };
    },
    prime_matchmaker_upcoming_meeting_suggestions_17 => sub {
        my ( $self, $params ) = @_;
        $self->_ensure_imported_upcoming_meeting_suggestions_for_matchmaker( $params->{matchmaker_id}, $params->{force_reload} );
        return { result => 1 };
    },
    record_notification_for_relevant_users_10 => sub {
        my ( $self, $params ) = @_;
        if ( $params->{data} && $params->{data}->{meeting_id} ) {
            my $euos = $self->_fetch_meeting_participant_objects( $params->{data}->{meeting_id} );
            for my $euo ( @$euos ) {
                next if $params->{data}->{author_id} && $params->{data}->{author_id} == $euo->user_id;
                next if $params->{skip_user_id} && $params->{skip_user_id} == $euo->user_id;
                $self->_record_notification_for_user( $params, $euo->user_id );
            }
        }
    },
} }

sub _ship_trail_to_services {
    my ( $self, $user_id, $payload_json, $service_status_json ) = @_;

    my $payload = Dicole::Utils::JSON->decode( $payload_json || '{}' );
    my $status_data = Dicole::Utils::JSON->decode( $service_status_json || '{}' );

    unless ( $status_data->{mixpanel} ) {
        eval {
            # default to dev token
            my $token = CTX->server_config->{dicole}->{meetings_mixpanel_token} || '8ae9e1d2de8656929a3d221a2b77b8ec';

            $payload->{location} ||= '';
            $payload->{referrer} ||= '';
            $payload->{initial_referrer} ||= '';
            my ( $location_domain ) = $payload->{location} =~ /^\w+\:\/\/(?:\w*\:\w*\@)?([^\/]+)/;
            my ( $referrer_domain ) = $payload->{referrer} =~ /^\w+\:\/\/(?:\w*\:\w*\@)?([^\/]+)/;
            my ( $initial_referrer_domain ) = $payload->{initial_referrer} =~ /^\w+\:\/\/(?:\w*\:\w*\@)?([^\/]+)/;

            my $mixpanel_data = {
                event => $payload->{event},
                properties => {
                    token => $token,
                    distinct_id => $user_id,
                    ip => $payload->{ip},
                    'time' => $payload->{epoch},
                    'User Agent' => $payload->{user_agent} || '',
                    'Page' => $payload->{location} || '',
                    'Page Domain' => $location_domain || '',
                    'Page Title' => $payload->{title} || '',
                    '$referrer' => $payload->{referrer} || '',
                    '$referring_domain' => $referrer_domain || '',
                    '$initial_referrer' => $payload->{initial_referrer} || '',
                    '$initial_referring_domain' => $initial_referrer_domain || '',
                    'mp_name_tag' => $payload->{current_user_name} || '',
                    'mp_note' => 'Viewing: ' . $payload->{title} . ' ('.$payload->{location}.')',

                    %{ $payload->{extra_params} || {} },
                },
            };

            if ( $payload->{event} eq 'load' ) {
                $mixpanel_data->{event} = 'mp_page_view';
                $mixpanel_data->{properties} = {
                    %{ $mixpanel_data->{properties} },
                    mp_page => $payload->{location} || '',
                    mp_referrer => $payload->{referrer} || '',
                };
            }

            my $response = Dicole::Utils::HTTP->post( 'http://api.mixpanel.com/track?verbose=1', {
                    data => Dicole::Utils::Data->single_line_base64_json( $mixpanel_data )
            } );

            if ( $response ) {
                my $response_data = Dicole::Utils::JSON->decode( $response );

                if( $response_data->{status} eq '1' ) {
                    $status_data->{mixpanel} = 1;
                }
                else {
                    $status_data->{mixpanel_error} .= $response_data->{error};
                }
            }
        };
        if ( $@ ) {
            $status_data->{mixpanel_error} .= ";error=$@";
        }
    }

    $status_data->{all} = 1;
    for my $service ( qw( mixpanel ) ) {
        $status_data->{all} = 0 unless $status_data->{ $service };
    }

    return $status_data;
}

sub _check_vat_error {
    my ( $self, $vat_id ) = @_;

    return { error => { code => 1, message => 'Empty vat_id is not valid' } } unless $vat_id;

    my ( $vat_country, $vat_number ) = $vat_id =~ /^(\D\D)(..+)$/;

    return { error => { code => 2, message => 'invalid VAT number format' } } unless $vat_country && $vat_number;
    return { error => { code => 3, message => 'FI does not qualify for reverse tax' } } if uc( $vat_country ) eq 'FI';

    my $round = 1;
    my $result = 0;

    while ( $round < 2 && ! $result ) {
        sleep 1 unless $round == 1;
        $result = Dicole::Utils::Gearman->do_task( check_vat_validity => { country_code => $vat_country, vat_number => $vat_number } );
        $result = ( ref( $result ) eq 'HASH' ) ? $result->{result} : 0;
        $round++;
    }

    return { error => { code => 4, message => 'ID does not qualify for reverse tax' } } unless $result;

    return 0;
}

sub _return_meeting_participant_object_data {
    my ( $self, $meeting, $object, $image_size, $lc_opts ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    my $p = undef;

    if ( $object && ref( $object ) =~ /draft/i ) {
        $meeting ||= $self->_ensure_meeting_object( $object->meeting_id );
        $p = $self->_gather_meeting_draft_participant_info( $meeting, $image_size, $object, undef, $lc_opts );
    }
    elsif ( $object ) {
        $meeting ||= $self->_ensure_meeting_object( $object->event_id );
        $p = $self->_gather_meeting_user_info( $meeting, $object->user_id, $image_size, $object, $lc_opts );
    }

    return { error => { code => 1, message => 'participant not found!' } } unless $p;

    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    $self->_sanitize_meeting_participant_info( $meeting, $p, $meeting->domain_id, $domain_host, $lc_opts );

    return $p;
}

sub _return_meeting_participant_data {
    my ( $self, $meeting, $user, $image_size, $po, $lc_opts ) = @_;

    $po ||= $self->_fetch_meeting_participant_object_for_user( $meeting, $user );

    return $self->_return_meeting_participant_object_data( $meeting, $po, $image_size, $lc_opts );
}

sub _gather_lc_opts_from_params {
    my ( $self, $params ) = @_;

    return { lang => $params->{lang}, user_id => $params->{auth_user_id} || $params->{user_id} };
}

sub _return_sanitized_suggestion_source_info {
    my ( $self, $source ) = @_;

    my $data = {
        id => $source->id,

        uid => $source->uid,
        id_inside_container => $self->_get_note( google_calendar_id => $source ) || $self->_get_note( id_inside_container => $source ),
        is_primary => $self->_get_note( google_calendar_is_primary => $source ) ? 1 : $self->_get_note( is_primary => $source ) ? 1 : 0,
        name => $source->name,

        last_update_epoch => $self->_get_note( updated_date => $source ) || 0,

        container_type => $source->provider_type,
        container_name => $source->provider_name,
        container_id => $source->provider_id,

        type => $source->provider_type,
        provider => $source->provider_name,
        selected_by_default => $self->_get_note( google_calendar_is_primary => $source ) ? 1 : $self->_get_note( is_primary => $source ) ? 1 : 0,
    };

    return $data;
}

sub _return_suggestion_data {
    my ( $self, $suggestion, $user ) = @_;

    my ( $date, $times, $timezone_string ) = $self->_form_timespan_parts_from_epochs_for_user( $suggestion->begin_date, $suggestion->end_date, $user );

    my $data = {
        begin_epoch => $suggestion->begin_date,
        end_epoch => $suggestion->end_date,
        time_string => $times || '',
        date_string => $date || '',
        timezone_string => $timezone_string,
        is_suggested_meeting => 1,

        enter_url => $self->_get_suggestion_enter_abs( $suggestion ),
    };

    for my $key ( qw(
        id
        title
        location
        source
    ) ) {
        $data->{ $key } = $suggestion->get( $key );
    }

    $data->{title_value} = $data->{title};

    $data->{location} ||= $self->_ncmsg( 'Location not known', { user => $user } );

    $data->{source_name} = $self->_get_note( source_name => $suggestion ) || '';
    $data->{source_container_type} = $self->_get_note( source_provider_type => $suggestion ) || '';
    $data->{source_container_name} = $self->_get_note( source_provider_name => $suggestion ) || '';

    return $data;
}

sub _return_meeting_basic_data {
    my ( $self, $meeting, $user ) = @_;

    $user = $user ? Dicole::Utils::User->ensure_object( $user ) : undef;

    my $timezone = $user ? $user->timezone : 'UTC';
    my $lang = $user ? $user->language : 'en';

    my ( $date, $times, $timezone_string ) = $self->_form_timespan_parts_from_epochs_tz_and_lang( $meeting->begin_date, $meeting->end_date, $timezone, $lang );
    my ( $created_date_string ) = $self->_form_timespan_parts_from_epochs_tz_and_lang( $meeting->created_date, $meeting->created_date, $timezone, $lang );
    my ( $begin_date_string ) = $self->_form_timespan_parts_from_epochs_tz_and_lang( $meeting->begin_date, $meeting->begin_date, $timezone, $lang );

    my $meeting_live_params = $user ? $self->_gather_meeting_live_conferencing_params( $meeting, $user ) : {};

    my $begin_dnt = Dicole::Utils::Date->epoch_to_date_and_time_strings( $meeting->begin_date, $timezone, $lang, '24' );
    my $end_dnt = Dicole::Utils::Date->epoch_to_date_and_time_strings( $meeting->end_date, $timezone, $lang, '24' );

    my $ocd = $self->_get_note_for_meeting( online_conferencing_data => $meeting );

    if ( $ocd && $ocd->{lync_uri} ) {
        $ocd->{lync_copypaste} = $ocd->{lync_uri};
        delete $ocd->{lync_uri};
    }

    my $requester_user = eval { $self->_get_meeting_matchmaking_requester_user( $meeting ) };
    my $requester_user_data = $requester_user ? $self->_gather_user_info( $requester_user, -1, $meeting->domain_id ) : {};
    my $requester_comment = $self->_get_note( matchmaking_requester_comment => $meeting ) || '';
    $requester_comment = Dicole::Utils::HTML->text_to_html( $requester_comment ) if $requester_comment;

    my $is_draft = $self->_meeting_is_draft( $meeting ) ? 1 : 0;
    my $current_scheduling_id = 0;

    if ( ! $meeting->begin_date && ! $is_draft ) {
        $current_scheduling_id = $self->_get_note( current_scheduling_id => $meeting ) || 0;
    }

    my $meeting_background_params = {};

    if ( my $theme = $self->_get_note( background_theme => $meeting ) ) {
        $meeting_background_params->{background_theme} = $theme;
        if ( $theme eq 'u' ) {
            $meeting_background_params->{background_image_url} = $self->_get_note( background_image_url => $meeting );
        }
        elsif ( $theme eq 'c' ) {
            if ( my $baid = $self->_get_note( background_attachment_id => $meeting ) ) {
                my $domain_host = $self->_get_host_for_domain( $meeting->domain_id, 443 );

                my $checksum = 'DclHD8yfpoisv9YxYQSDkYNhp3A'; # :P
                $meeting_background_params->{background_image_url} = $domain_host . Dicole::URL->from_parts(
                    domain_id => $meeting->domain_id, target => 0,
                    action => 'meetings_raw', task => 'meeting_background_image',
                    additional => [ $meeting->id, $baid, $checksum, 'background.jpg' ],
                );
            }
        }
    }

    my $skype_account = $ocd ? $ocd->{skype_account} || '' : '';

    my $meeting_has_ended = ( $meeting->begin_date && $meeting->end_date && time > $meeting->end_date ) ? 1 : 0;

    return {
        id => $meeting->id,
        is_draft => $is_draft,
        creator_id => $meeting->creator_id,
        current_scheduling_id => $current_scheduling_id,
        previous_scheduling_id => $self->_get_note( previous_scheduling_id => $meeting ) || 0,
        created_from_matchmaker_id => $self->_get_note( created_from_matchmaker_id => $meeting ) || 0,
        allow_meeting_cancel => ( $self->_get_note( allow_meeting_cancel => $meeting ) && ! $meeting_has_ended ) ? 1 : 0,
        allow_meeting_reschedule => ( $self->_get_note( allow_meeting_reschedule => $meeting ) && ! $meeting_has_ended ) ? 1 : 0,
        express_manager_set_date => ( $self->_get_note( express_manager_set_date => $meeting ) ) ? 1 : 0,
        matchmaking_accepted => $self->_meeting_is_matchmaking_accepted( $meeting ),
        matchmaking_requester_name => $requester_user ? Dicole::Utils::User->name( $requester_user ) : '',
        matchmaking_requester_company => $requester_user_data->{organization} || '',
        matchmaking_requester_comment => $requester_comment,
        matchmaking_event_name => eval { $self->_get_meeting_matchmaking_event_name( $meeting ) } || '',
        created_epoch => $meeting->created_date || 0,
        removed_epoch => $meeting->removed_date || 0,
        cancelled_epoch => $self->_get_note( cancelled_date => $meeting ) || $meeting->cancelled_date || 0,
        created_date_string => $created_date_string,
        begin_date_string => $begin_date_string,
        begin_epoch => $meeting->begin_date,
        begin_date => $meeting->begin_date ? $begin_dnt->[0] : '',
        begin_time => $meeting->begin_date ? $begin_dnt->[1] : '',
        end_epoch => $meeting->end_date,
        end_date => $meeting->end_date ? $end_dnt->[0] : '',
        end_time => $meeting->end_date ? $end_dnt->[1] : '',
        title_value => $meeting->title, # transitional until title is this
        title => $self->_meeting_title_string( $meeting ), # transitional until other codes changed
        title_string => $self->_meeting_title_string( $meeting ),
        location_value => $meeting->location_name, # transitional until location is this
        location => $self->_meeting_location_string( $meeting ), # transitional until other codes changed
        location_string => $self->_meeting_location_string( $meeting ),

        physical_location_string => $self->_meeting_physical_location_string($meeting),
        virtual_location_string => $self->_meeting_virtual_location_string($meeting),
        virtual_location_set => $self->_meeting_virtual_location_string_without_default($meeting) ? 1 : 0,

        time_string => $times || '',
        date_string => $date || '',
        timezone_string => $timezone_string,

        online_conferencing_option => $self->_get_note_for_meeting( online_conferencing_option => $meeting),
        online_conferencing_data => $ocd,
        skype_account => $skype_account || $self->_get_note_for_meeting( skype_account => $meeting ),

        # these two are for backwards compatibility
        skype_url => $meeting_live_params->{skype_uri},
        teleconf_url => $meeting_live_params->{teleconf_uri},

        # these are the right ones
        %$meeting_live_params,
        %$meeting_background_params,

        meeting_type => $self->_get_note_for_meeting( meeting_type => $meeting ),

        enter_url => $self->_get_meeting_enter_abs( $meeting ),

        desktop_calendar => $user ? $self->_calendar_params_for_epoch_and_user( $meeting->begin_date, $meeting->end_date, time, $user ) : '',
        ics_url => ( $user && $meeting->begin_date ) ? $self->_meeting_ics_url_for_user( $meeting, $user ) : '',

        settings => $self->_determine_meeting_settings( $meeting ),
    };
}

sub _gather_data_for_proposals {
    my ( $self, $pos, $user ) = @_;

    return [] unless $pos;
    my $proposals = [];

    for my $po ( @$pos ) {
        my ( $date, $times, $timezone_string ) = $self->_timespan_parts_for_proposal( $po, $user );
        push @$proposals, {
            id => $po->id,
            begin_epoch => $po->begin_date,
            end_epoch => $po->end_date,
            time_string => $times || '',
            date_string => $date || '',
            timezone_string => $timezone_string,
        };
    }

    return $proposals;
}

sub _sanitize_meeting_material {
    my ( $self, $meeting, $m ) = @_;

    $m->{id} ||= $m->{material_id};
    $m->{author_name} ||= '';
    $m->{time_ago} ||= '';
    $m->{meeting_id} ||= $meeting->id;

    for my $key ( qw(
            url data_url page_id prese_id presenter thumbnail author_url attachment_id
            short_author_name from_url edit_url author_image anon_email
        ) ) {
        delete( $m->{ $key } );
    }
}

sub _sanitize_quickmeet_object {
    my ( $self, $q, $domain_host ) = @_;

    my $r = { id => $q->id };

    for my $attr ( qw ( url_key created_date updated_date expires_date creator_id matchmaker_id ) ) {
        $r->{ $attr } = $q->get( $attr );
    }
    for my $note ( qw ( email name phone organization title sent_date message meeting_title ) ) {
        $r->{ $note } = $self->_get_note( $note, $q );
    }

    $domain_host ||= $self->_get_host_for_domain( $q->domain_id, 443 );

    $r->{full_url} = $domain_host . Dicole::URL->from_parts( action => 'meetings', task => 'pick', additional => [ $q->url_key ] );

    return $r;
}

sub _sanitize_meeting_participant_info {
    my ( $self, $meeting, $p, $domain_id, $domain_host, $lc_opts ) = @_;

    $self->_sanitize_user_info( $p, 0, $lc_opts );

    my $meeting_id = $meeting ? $meeting->id : 0;

    $p->{meeting_id} = $meeting_id;

    if ( $p->{draft_object_id} ) {
        $p->{id} = join( ":", $meeting_id, 'draft', $p->{draft_object_id} );
        if ( $meeting ) {
            $p->{desktop_data_url} =  Dicole::URL->from_parts( action => 'meetings_json', task => 'draft_participant_info', target => $meeting->group_id, additional => [ $meeting->event_id, $p->{draft_object_id} ], domain_id => $meeting->domain_id, partner_id => $meeting->partner_id );
        }
    }
    elsif ( $p->{participant_object_id} ) {
        $p->{id} = join( ":", $meeting_id, 'participant', $p->{participant_object_id} );
        if ( $meeting ) {
            $p->{desktop_data_url} =  Dicole::URL->from_parts( action => 'meetings_json', task => 'user_info', target => $meeting->group_id, additional => [ $meeting->event_id,  $p->{user_id} ], domain_id => $meeting->domain_id, partner_id => $meeting->partner_id );
        }
    }

    for my $key ( qw( change_manager_status_url ) ) {
        delete( $p->{ $key } );
    }

    $p->{image} = $p->{image} ? $domain_host . $p->{image} : '';
}

sub _sanitize_notification {
    my ( $self, $notification ) = @_;

    return {
        id => $notification->id,
        created_at => $notification->created_date,
        created_epoch => $notification->created_date,
        is_seen => $notification->seen_date ? 1 : 0,
        is_read => $notification->read_date ? 1 : 0,
        type => $notification->notification_type,
        data => $self->_get_note( data => $notification ),
    }
}

sub _fetch_sanitized_user_data {
    my ( $self, $user, $image_size, $domain_id, $for_self, $lc_opts ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $user_info = $self->_gather_user_info( $user, $image_size || -1, $domain_id );
    $self->_sanitize_user_info( $user_info, $for_self, $lc_opts );

    $user_info->{meetme_description} = $self->_get_note_for_user( 'meetme_description', $user, $domain_id ) || '';
    $user_info->{meetme_order} = $self->_get_note_for_user( 'meetme_order', $user, $domain_id ) || [];
    $user_info->{meetme_background_theme} = $self->_get_note_for_user( 'meetme_background_theme', $user, $domain_id ) // '';

    my $user_matchmaker_fragment = $self->_fetch_user_matchmaker_fragment( $user );

    if ( $for_self ) {
        $user_info->{presumed_country_code} = $self->_get_note_for_user( 'meetings_presumed_country_code', $user, $domain_id ) || '';
        $user_info->{tos_accepted} = $self->_user_has_accepted_tos( $user, $domain_id ) ? 1 : 0;
        $user_info->{login_allowed_for_partners} = [];
        for my $p ( @{ $self->_fetch_allowed_partners_for_user( $user ) } ) {
            push @{ $user_info->{login_allowed_for_partners} }, { id => $p->{id}, name => $p->{name} };
        }
        $user_info->{google_connected} = $self->_user_has_connected_google( $user, $domain_id ) ? 1 : 0;
        $user_info->{device_calendar_connected} = $self->_user_has_connected_device_calendar( $user, $domain_id ) ? 1 : 0;
        $user_info->{hidden_sources} = $self->_get_note_for_user( 'meetings_hidden_sources', $user, $domain_id ) || [];
        $user_info->{source_settings} = $self->_get_note_for_user( 'meetings_source_settings', $user, $domain_id ) || {};
        $user_info->{source_settings}{enabled} ||= {};
        $user_info->{source_settings}{disabled} ||= {};

        $user_info->{dismissed_news} = $self->_get_note_for_user( 'dismissed_news', $user, $domain_id ) || [];
        $user_info->{feature_requests} = $self->_get_note_for_user( 'feature_requests', $user, $domain_id ) || {};

        my $latest_stored = $self->_get_note_for_user( ongoing_scheduling_stored_epoch => $user, $domain_id );
        if ( $latest_stored && $latest_stored > time - 60*60*2 ) {
            my $scheduling_id = $self->_get_note_for_user( ongoing_scheduling_id => $user, $domain_id );
            my $scheduling = eval { $self->_ensure_object_of_type( meetings_scheduling => $scheduling_id ) };
            get_logger(LOG_APP)->error( $@ ) if $@;

            unless ( ! $scheduling || $scheduling->completed_date || $scheduling->removed_date || $scheduling->cancelled_date || $self->_get_note( failed_epoch => $scheduling ) ) {
                $user_info->{ongoing_scheduling_stored_epoch} = $latest_stored;
                $user_info->{ongoing_scheduling_id} = $scheduling_id;
            }
        }

        $user_info->{matchmaker_fragment} = $user_matchmaker_fragment || '';
        $user_info->{meetme_fragment} = $user_info->{matchmaker_fragment};
        $user_info->{time_zone} = $user->timezone || '';
        $user_info->{time_display} = $self->_get_note_for_user( time_display => $user, $domain_id ) || '24h';
        $user_info->{language} = $user->language || 'en';
        $user_info->{is_pro} = $self->_user_is_pro( $user, $domain_id ) || '';
        $user_info->{is_trial_pro} = $self->_user_is_trial_pro( $user, $domain_id ) || '';
        $user_info->{is_free_trial_expired} = $self->_user_free_trial_has_expired( $user, $domain_id ) || '';

        my $tzinfo = Dicole::Utils::Date->timezone_info( $user->timezone );
        $user_info->{time_zone_offset} = $tzinfo->{offset_value} || 0;
        $user_info->{time_zone_dst_change_epoch} = $tzinfo->{dst_change_epoch} || 0;
        $user_info->{time_zone_dst_offset} = $tzinfo->{changed_offset_value} || 0;

        if ( $user->email ) {
            $user_info->{email_confirmed} = 1;
        }
        else {
            $user_info->{email_confirmed} = 0;
        }

        if ( ! $user_info->{email} ) {
            my $list = $self->_fetch_user_verified_email_list( $user, $domain_id );
            $user_info->{email} = shift( @$list ) || '';
        }

        if ( $user->phone ) {
            $user_info->{phone_confirmed} = 1;
        }
        else {
            $user_info->{phone_confirmed} = 0;
        }

        $user_info->{available_themes} = $self->THEME_NAMES;
        $user_info->{custom_theme} = $self->_get_note_for_user( 'pro_theme', $user, $domain_id ) || '';
        $user_info->{custom_background_image_url} = $self->_get_note_for_user( 'pro_theme_background_image', $user, $domain_id ) || '';
        $user_info->{custom_header_image_url} = $self->_get_note_for_user( 'pro_theme_header_image', $user, $domain_id ) || '';

        for my $type ( qw( custom_background_image_url custom_header_image_url ) ) {
            if ( $user_info->{ $type } && $user_info->{ $type } =~ /^\d+$/ ) {
                $user_info->{ $type } = Dicole::URL->from_parts(
                    action => 'meetings', domain_id => $domain_id,
                    task => ( $type =~ /header/ ) ? 'own_theme_header_image' : 'own_theme_background_image',
                );
            }
        }

        my $key = Dicole::Utils::User->identification_key( $user, 0, $domain_id );

        $user_info->{external_ics_url} = $self->_get_host_for_user( $user, $domain_id, 443 ) .  Dicole::URL->from_parts( domain_id => $domain_id, action => 'meetings_raw', task => 'ics_list', target => 0, additional => [ $key, 'meetings.ics' ] );

        $user_info->{subscription_type} = '';

        if ( $self->_user_is_real_pro( $user, $domain_id ) ) {
            if ( $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id ) ) {
                $user_info->{subscription_type} = 'sponsored';
            }
            elsif ( my $company_subscription = $self->_get_user_current_company_subscription($user, $domain_id) ) {
                $user_info->{subscription_type} = 'company';
                $user_info->{subscription_company_name} = $company_subscription->company_name;
                if ( $user->id == $company_subscription->admin_id ) {
                    if ( my $base_url = $self->_get_note(appdirect_base_url => $company_subscription ) ) {
                        $user_info->{subscription_company_admin_url} = $base_url . '/account/users';
                    }
                    elsif ( $self->_get_note( aps_provisioned => $company_subscription ) ) {
                        # TODO: when we have more options than KPN, this should be changed:
                        $user_info->{subscription_company_admin_url} = 'https://cp.allisp.eu/';
                    }
                }
                else {
                    $user_info->{subscription_company_admin_name} = $company_subscription->admin_id ? Dicole::Utils::User->name( $company_subscription->admin_id ) : '';
                }
            }
            elsif ( my $subscription = $self->_get_user_current_subscription($user, $domain_id) ) {
                $user_info->{subscription_type} = 'user';
                $user_info->{subscription_user_expires_epoch} = $self->_get_note( valid_until_timestamp => $subscription ) || 0;
                $user_info->{subscription_user_plan} = $self->_get_note( plan_type => $subscription ) || 0;
                $user_info->{subscription_user_next_payment_epoch} = $self->_get_note( current_period_end => $subscription ) || 0;

                if ( ! $self->_get_note( stripe_customer_id => $subscription ) ) {
                    $user_info->{subscription_user_admin_url} = 'http://www.paypal.com/history';
                }
                else {
                    $user_info->{subscription_user_admin_url} = '';
                }
            }
            else {
                # TODO: fall back to this for legacy users like Cees
                $user_info->{subscription_type} = 'sponsored';
                # get_logger(LOG_APP)->error("PLEASE INSPECT this mysterious pro status for user " . $user->id );
            }
        }
        elsif ( $self->_user_is_trial_pro( $user, $domain_id ) && ! $user_info->{is_free_trial_expired} ) {
            $user_info->{subscription_type} = 'trial';
            $user_info->{subscription_trial_expires_epoch} = $self->_get_note_for_user( 'meetings_free_trial_expires', $user, $domain_id );
        }
    }
    else {
        $user_info->{email} = '';
    }

    my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );
    $user_info->{image} = $user_info->{image} ? $domain_host . $user_info->{image} : '';

    if ( $user_info->{meetme_background_theme} && $user_info->{meetme_background_theme} eq 'u' ) {
        $user_info->{meetme_background_image_url} = $self->_get_note_for_user( meetme_background_image_url => $user, $domain_id );
    }
    elsif ( $user_info->{meetme_background_theme} && $user_info->{meetme_background_theme} eq 'c' ) {
        if ( my $baid = $self->_get_note_for_user( meetme_background_attachment_id => $user, $domain_id ) ) {

            my $checksum = 'DclHD8yfpoisv9YxYQSDkYNhp3A'; # :P
            $user_info->{meetme_background_image_url} = $domain_host . Dicole::URL->from_parts(
                domain_id => $domain_id, target => 0,
                action => 'meetings_raw', task => 'user_meetme_background_image',
                additional => [ $user->id, $baid, $checksum, 'background.jpg' ],
            );
        }
    }

    # Backwards compatibility: if not saved, use default mmr bg and description
    my $bg_theme = $user_info->{meetme_background_theme} // '';
    if ( $user_matchmaker_fragment && $bg_theme eq '' ) {
        if ( my $default_mmr = $self->_fetch_user_matchmaker_with_path( $user, '' ) ) {
            $user_info->{meetme_description} = $default_mmr->description || '';
            $user_info->{meetme_background_theme} = $self->_get_note( background_theme => $default_mmr ) // '';

            if (  $user_info->{meetme_background_theme} && $user_info->{meetme_background_theme} eq 'u') {
                $user_info->{meetme_background_image_url} = $self->_get_note( background_image_url => $default_mmr );
            }
            elsif ( $user_info->{meetme_background_theme} && $user_info->{meetme_background_theme} eq 'c' ) {
                if ( my $baid = $self->_get_note( background_attachment_id => $default_mmr ) ) {

                    my $checksum = 'DclHD8yfpoisv9YxYQSDkYNhp3A'; # :P
                    $user_info->{meetme_background_image_url} = $domain_host . Dicole::URL->from_parts(
                        domain_id => $domain_id, target => 0,
                        action => 'meetings_raw', task => 'matchmaker_background_image',
                        additional => [ $default_mmr->id, $baid, $checksum, 'background.jpg' ],
                    );
                }
            }
        }
    }
    $user_info->{id} = $user_info->{user_id};

    return $user_info;
}

sub _fetch_dated_meeting_list {
    my ( $self, $params ) = @_;

    my $user_id = $params->{user_id};

    my @where = ( 'begin_date > 0' );
    if ( my $max = $params->{start_max} ) {
        push @where, "begin_date <= $max";
    }
    if ( my $min = $params->{start_min} ) {
        push @where, "begin_date >= $min";
    }
    if ( ! $params->{include_draft} ) {
        push @where, "( dicole_events_event.attend_info LIKE '%\"draft_ready\":\"1%' OR dicole_events_event.attend_info LIKE '%\"draft_ready\":1%')";
    }
    if ( ! $params->{include_cancelled} ) {
        push @where, "( dicole_events_event.attend_info NOT LIKE '%\"cancelled_date\":%' OR
        dicole_events_event.attend_info LIKE '%\"cancelled_date\":0%' )";
    }
    my $where = "(" . join( ") AND (", @where ) . ")";

    my $sort = ( $params->{sort} && $params->{sort} =~ /^a(sc(ending)?)?$/ ) ? 'asc' : 'desc';
    my $order = 'begin_date ' . $sort;

    my $limit = $params->{limit} ||= 20;
    $limit = $params->{offset} ? $params->{offset} .','. $limit : $limit;

    return $self->_get_user_meetings_in_domain(
        $params->{user_id}, $params->{domain_id}, $where, $order, $limit
    );
}

sub _fill_application_entry_for_user {
    my ( $self, $app, $entry, $user, $image_size, $domain_host ) = @_;

    my $url = '';

    if ( $app->{vanity_url_path} ) {
        if (  my $mmr = $self->_fetch_user_matchmaker_with_path( $user, $app->{vanity_url_path} ) ) {
            $url = $self->_generate_matchmaker_meet_me_url( $mmr, $user, $domain_host );
        }
    }
    else {
        $url = $self->_generate_user_meet_me_url( $user, $app->{domain_id}, $domain_host );
    }

    my $user_data = $self->_gather_user_info( $user, $image_size || 80, $app->{domain_id} );

    $entry->{'Meet Me URL'} = $url;
    $entry->{'Image URL'} = $domain_host . $user_data->{image} if $user_data->{image};
    $entry->{'First name'} = $user_data->{first_name} if $user_data->{first_name};
    $entry->{'Last name'} = $user_data->{last_name} if $user_data->{last_name};
    $entry->{'Organization'} = $user_data->{organization} if $user_data->{organization};
    $entry->{'Title'} = $user_data->{organization_title} if $user_data->{organization_title};

    return $entry;
}

sub _sanitize_user_info {
    my ( $self, $u, $for_self, $lc_opts ) = @_;

    my @for = qw( image_attachment_id data_url private_email vcard_url );
    push @for, qw( facebook_user_id alternative_emails ) unless $for_self;

    for my $key ( @for ) {
        delete( $u->{ $key } );
    }

    my @ensure_keys = qw( email linkedin skype phone organization organization_title name );

    $u->{ $_ } ||= '' for @ensure_keys;

    if ( $u->{name} eq 'Deleted Account' ) {
        $u->{name} = $self->_ncmsg( 'Deleted Account', $lc_opts );
    }
}

sub _sanitize_comment {
    my ( $self, $c, $domain_host ) = @_;

    $c->{user_image} = $c->{user_image} ? $domain_host . $c->{user_image} : '';

    $c->{user} = {
        id => $c->{user_id},
        user_id => $c->{user_id},
        user_id_md5 =>  Digest::MD5::md5_hex( $c->{user_id} ),
        image => $c->{user_image},
        initials => $c->{user_initials},
        name => $c->{user_name},
        organization => $c->{user_organization},
    };

    my @for = qw( user_avatar user_link );

    for my $key ( @for ) {
        delete( $c->{ $key } );
    }
}

sub _return_sanitized_matchmaker_lock_data {
    my ( $self, $lock, $mmr, $selected_location ) = @_;

    $mmr ||= $self->_ensure_matchmaker_object( $lock->matchmaker_id );

    my $accepter_user = Dicole::Utils::User->ensure_object( $mmr->creator_id );
    my $requester_id =  $lock->creator_id || $lock->expected_confirmer_id;
    my $requester_user = $requester_id ? Dicole::Utils::User->ensure_object( $requester_id ) : undef;

    my $accepted_meeting_id = 0;
    if (  $lock->created_meeting_id ) {
        if ( my $meeting = eval { $self->_ensure_meeting_object( $lock->created_meeting_id ) } ) {
            if ( $requester_user && $self->_get_user_meeting_participation_object( $requester_user, $meeting ) ) {
                $accepted_meeting_id = $meeting->id;
            }
        }
    }

    my $time_zone = $self->_get_note( time_zone => $mmr ) || 'UTC';

    my $times_string = $self->_form_times_string_for_epochs( $lock->locked_slot_begin_date, $lock->locked_slot_end_date, $time_zone, $accepter_user->language );

    my $location_name = $self->_generate_matchmaker_lock_location_string( $lock, $mmr );

    my $accepter_name = Dicole::Utils::User->name( $accepter_user );
    my $accepter_email = $accepter_user->email;
    $accepter_name .= ' ('.$accepter_email.')' unless $accepter_name eq $accepter_email;

    my $description = $self->_ncmsg( 'This meeting is tentative. Wait for %1$s to confirm the meeting.', { user => $requester_user || $accepter_user }, [ $accepter_name ] );

    my $tentative_gcal_url = $self->_generate_google_publish_url( $lock->title . ' (tentative)', $lock->locked_slot_begin_date, $lock->locked_slot_end_date, $location_name, $description );

    my $tentative_calendar_url = '';
    if ( $requester_user ) {
        my $ical_checksum = $self->_generate_meeting_ics_digest_for_user( $lock->id, $requester_user );
        $tentative_calendar_url = $self->derive_url( action => 'meetings_raw', task => 'matchmaker_lock_ics', additional => [ $lock->id, $requester_user->id, $ical_checksum, 'event.ics' ] );
    };

    my $matchmaking_list_url = '';
    if ( $mmr->matchmaking_event_id ) {
        my $mm_event = eval { $self->_ensure_object_of_type( meetings_matchmaking_event => $mmr->matchmaking_event_id ) };

        if ( $mm_event ) {
            $matchmaking_list_url = $self->_get_note( organizer_list_url => $mm_event );
            $matchmaking_list_url ||= Dicole::URL->from_parts(
                domain_id => $mmr->domain_id, target => 0,
                action => 'meetings', task => 'matchmaking_list',
                additional => [ $mmr->matchmaking_event_id ]
            );
        }
    }

    return {
        id => $lock->id,
        matchmaker_id => $mmr->id,
        matchmaking_event_id => $mmr->matchmaking_event_id || 0,

        start_epoch => $lock->locked_slot_begin_date,
        end_epoch => $lock->locked_slot_end_date,
        times_string => $times_string,

        agenda => $lock->agenda,
        expected_confirmer_id => $lock->expected_confirmer_id,

        title => $lock->title,
        creator_id => $lock->creator_id,
        location_id => 0,
        location_string => $location_name,
        creation_epoch => $lock->creation_date,
        expire_epoch => $lock->expire_date,
        cancel_epoch => $lock->cancel_date,

        quickmeet_key => $self->_get_note( quickmeet_key => $lock ) || '',
        request_sent => $lock->created_meeting_id ? 1 : 0,
        accepted_meeting_id => $accepted_meeting_id || 0,
        desktop_accepted_meeting_url => $accepted_meeting_id ? $self->_get_meeting_abs( $accepted_meeting_id ) : '',
        accepter_name => Dicole::Utils::User->name( $accepter_user ),

        tentative_gcal_url => $tentative_gcal_url,
        tentative_calendar_url => $tentative_calendar_url,

        matchmaking_list_url => $matchmaking_list_url,
    };
}

sub _return_sanitized_scheduling_log_entry {
    my ( $self, $s, $pos ) = @_;

    my $params = {
        id => $s->id,
        author_id => $s->author_id,
        created_epoch => $s->created_date,
        entry_epoch => $s->entry_date,
        meeting_id => $s->meeting_id,
        scheduling_id => $s->scheduling_id,
        entry_type => $s->entry_type,
    };

    for my $key ( qw(
        data
    ) ) {
        $params->{ $key } = $self->_get_note( $key, $s );
    }

    if ( $s->meeting_id && $params->{data} && $params->{data}->{user_id} ) {
        $pos ||= $self->_fetch_meeting_participant_objects( $s->meeting_id );
        my %po_by_user_id = map { $_->user_id => $_ } @$pos;
        my $po = $po_by_user_id{ $params->{data}->{user_id} };
        $params->{data}->{participant_id} = $self->_get_id_for_any_participation_object( $po ) if $po;
    }

    return $params;
}

sub _return_sanitized_scheduling_object {
    my ( $self, $s ) = @_;

    $s = $self->_ensure_object_of_type( meetings_scheduling => $s );

    my $params = {
        id => $s->id,
        creator_id => $s->creator_id,
        created_epoch => $s->created_date,
        completed_epoch => $s->completed_date,
        cancelled_epoch => $s->cancelled_date,
        meeting_id => $s->meeting_id,
    };

    for my $key ( qw(
        from_matchmaker_id
        duration
        planning_buffer
        confirm_automatically
        buffer
        time_zone
        available_timespans
        source_settings
        slots
        online_conferencing_option
        online_conferencing_data
        organizer_swiping_required
    ) ) {
        $params->{ $key } = $self->_get_note( $key, $s );
    }

    for my $key ( qw( started_epoch failed_epoch ) ) {
        $params->{ $key } = $self->_get_note( $key, $s ) || 0;
    }

    if ( $params->{failed_epoch} ) {
        $params->{failed_message} = 'All possible times were disqualified';
    }

    return $params;
}

sub _return_sanitized_scheduling_option_object {
    my ( $self, $o ) = @_;

    return {
        no_suggestions_left => 1
    } unless $o;

    $o = $self->_ensure_object_of_type( meetings_scheduling_option => $o );

    return {
        id => $o->id,
        begin_epoch => $o->begin_date,
        end_epoch => $o->end_date,
        time_string => $self->_form_timespan_string_from_epochs_tz_and_lang( $o->begin_date, $o->end_date, 'Europe/Helsinki', 'en' ),
    };
}

sub _return_sanitized_scheduling_answer_object {
    my ( $self, $o ) = @_;

    return {} unless $o;

    return {
        user_id => $_->user_id,
        option_id => $_->option_id,
        answer => $_->answer,
        created_epoch => $_->created_date,
    };
}

sub _return_sanitized_matchmaker_data {
    my ( $self, $mmr ) = @_;

    my $params = {
        id => $mmr->id,
        name => $mmr->name,
        user_id => $mmr->creator_id,
        partner_id => $mmr->partner_id,
        matchmaking_event_id => $mmr->matchmaking_event_id,
        youtube_url => $self->_get_note( youtube_url => $mmr ),
        description => $mmr->description,
        vanity_url_path => $mmr->vanity_url_path || 'default',
        disable_title_edit => $self->_get_note( disable_title_edit => $mmr ) || 0,
        disable_location_edit => $self->_get_note( disable_location_edit => $mmr ) || 0,
        disable_duration_edit => $self->_get_note( disable_duration_edit => $mmr ) || 0,
        disable_tool_edit => $self->_get_note( disable_tool_edit => $mmr ) || 0,
        disable_time_zone_edit => $self->_get_note( disable_time_zone_edit => $mmr ) || 0,
        disable_available_timespans_edit => $self->_get_note( disable_available_timespans_edit => $mmr ) || 0,
        desktop_create_lock_url => Dicole::URL->from_parts( action => 'meetings_json', task => 'matchmaker_create_lock', target => 0, additional => [ $mmr->id ], domain_id => $mmr->domain_id, partner_id => $mmr->partner_id ),
        desktop_cancel_lock_url => Dicole::URL->from_parts( action => 'meetings_json', task => 'matchmaker_cancel_lock', target => 0, additional => [ $mmr->id ], domain_id => $mmr->domain_id, partner_id => $mmr->partner_id ),
        desktop_confirm_url => Dicole::URL->from_parts( action => 'meetings_json', task => 'matchmaker_confirm', target => 0, additional => [ $mmr->id ], domain_id => $mmr->domain_id, partner_id => $mmr->partner_id ),
        desktop_confirm_register_url => Dicole::URL->from_parts( action => 'meetings_json', task => 'matchmaker_confirm_register', target => 0, additional => [ $mmr->id ], domain_id => $mmr->domain_id, partner_id => $mmr->partner_id ),
    };

    for my $attr ( qw(
        time_zone
        duration
        buffer
        location
        slots
        background_theme
        available_timespans
        source_settings
        meeting_type
        online_conferencing_option
        online_conferencing_data
        planning_buffer
        require_verified_user
        preset_agenda
        suggested_reason
        ask_reason
        confirm_automatically
        preset_title
        preset_materials
        additional_direct_matchmakers
    ) ) {
        $params->{$attr} = $self->_get_note( $attr => $mmr );
    }

    $params->{planning_buffer} ||= 30*60;

    my $ocd = $params->{online_conferencing_data};
    if ( $ocd && $ocd->{lync_uri} ) {
        $ocd->{lync_copypaste} = $ocd->{lync_uri};
        delete $ocd->{lync_uri};
        $params->{online_conferencing_data} = $ocd;
    }

    if ( $self->_get_note( direct_link_enabled => $mmr ) || $self->_get_note( direct_link_disabled => $mmr ) ) {
        $params->{direct_link_enabled} = $self->_get_note( direct_link_enabled => $mmr );
    }
    else { # Legacy
        $params->{direct_link_enabled} = $mmr->matchmaking_event_id ? 1 : 0;
    }
    if ( $self->_get_note( meetme_visible => $mmr ) || $self->_get_note( meetme_hidden => $mmr ) ) {
        $params->{meetme_hidden} = $self->_get_note( meetme_hidden => $mmr );
    }
    else { # Legacy
        $params->{meetme_hidden} = $mmr->matchmaking_event_id ? 1 : 0;
    }

    if ( ! $self->_get_note( ask_reason => $mmr ) && ! $self->_get_note( disable_ask_reason => $mmr ) ) {
        $params->{ask_reason} = 1;
    }

    $params->{source_settings} ||= $self->_form_legacy_source_settings( $mmr->creator_id, $mmr->domain_id );
    $params->{source_settings} ||= {};
    $params->{source_settings}{enabled} ||= {};
    $params->{source_settings}{disabled} ||= {};

    $params->{time_zone} ||= $self->_get_note( 'timezone' => $mmr ) || 'UTC';

    my $tzinfo = Dicole::Utils::Date->timezone_info( $params->{time_zone} );
    $params->{time_zone_offset} = $tzinfo->{offset_value} || 0;
    $params->{time_zone_string} = $tzinfo->{readable_name} || '';

    if ( $params->{background_theme} && $params->{background_theme} eq 'u' ) {
        $params->{background_image_url} = $self->_get_note( background_image_url => $mmr );
    }
    elsif ( $params->{background_theme} && $params->{background_theme} eq 'c' ) {
        if ( my $baid = $self->_get_note( background_attachment_id => $mmr ) ) {
            my $domain_host = $self->_get_host_for_domain( $mmr->domain_id, 443 );

            my $checksum = 'DclHD8yfpoisv9YxYQSDkYNhp3A'; # :P
            $params->{background_image_url} = $domain_host . Dicole::URL->from_parts(
                domain_id => $mmr->domain_id, target => 0,
                action => 'meetings_raw', task => 'matchmaker_background_image',
                additional => [ $mmr->id, $baid, $checksum, 'background.jpg' ],
            );
        }
    }

    if ( $mmr->matchmaking_event_id ) {
        my $mm_event = $self->_ensure_matchmaking_event_object( $mmr->matchmaking_event_id );
        if ( $mm_event->end_date && $mm_event->end_date < time ) {
            return ();
        }
        $params->{event_data} = $self->_return_sanitized_matchmaking_event_data( $mm_event );
    }
    else {
        $params->{event_data} = {};
    }

    $params->{last_active_epoch} = $self->_resolve_matchmaker_last_active_epoch( $mmr );

    return $params;
}

sub _return_sanitized_matchmaking_event_data {
    my ( $self, $event ) = @_;

    my $params = {
        id => $event->id,
        name => $event->custom_name,
        organizer_name => $event->organizer_name,
        organizer_url => $event->organizer_url,
    };

    for my $attr ( qw(
        default_description
        default_background_image_url
        default_agenda
        suggested_reason
        force_vanity_url_path
        force_background_image_url
        force_time_zone
        force_available_timespans
        force_online_conferencing_option
        force_online_conferencing_data
        force_duration
        force_buffer
        force_location
        locations_description
        track_list market_list
        reserve_limit
        organizer_return_url
        extra_user_matchmaker_html_url_base
        show_youtube_url
        profile_data_filters
    ) ) {
        $params->{$attr} = $self->_get_note( $attr => $event );
    }

    return $params;
}

sub _return_sanitized_meeting_page_lock_data {
    my ( $self, $meeting, $page, $lock ) = @_;

    $lock = $self->_ensure_wiki_lock_object( $lock );

    my $id = join ":", $meeting->id, $page->id, $lock->id;
    my $material_id = join ":", $meeting->id, 'page', $page->id;

    my $creator_user = Dicole::Utils::User->ensure_object( $lock->user_id );

    return {
        id => $id,
        material_id => $material_id,
        creator_id => $creator_user->user_id,
        creator_name => Dicole::Utils::User->name( $creator_user ),
        content => $lock->autosave_content,
        created_date => $lock->lock_created,
        renewed_date => $lock->lock_renewed,
    };
}

sub _get_validated_params_for_matchmaking_event {
    my ( $self, $params, $mm_event ) = @_;

    my $valid_params = $params;

    return $valid_params unless $mm_event;

    if ( $mm_event = $self->_ensure_matchmaking_event_object( $mm_event ) ) {
        if ( my $value = $self->_get_note( force_background_image_url => $mm_event ) ) {
            $valid_params->{ background_theme } = 'u';
            $valid_params->{ background_upload_id } = '';
            $valid_params->{ background_image_url } = $value;
        }

        if ( my $value = $mm_event->partner_id ) {
            $valid_params->{ partner_id } = $value;
        }

        for my $field ( qw(
            time_zone
            duration
            buffer
            location
            vanity_url_path
            available_timespans
            online_conferencing_option
            online_conferencing_data
            meeting_type
        ) ) {
            if ( my $value = $self->_get_note( "force_" . $field => $mm_event ) ) {
                $valid_params->{ $field } = $value;
            }
        }
        if ( $self->_get_note( "force_vanity_url_path" => $mm_event ) eq 'shift2016' ) {
            $valid_params->{vanity_url_path} = 'shift2016_' . lc( $params->{shift2016_activity} )
                if $params->{shift2016_activity};
            $valid_params->{name} = 'SHIFT 2016 ' . ucfirst( $params->{shift2016_activity} || 'creative' );
        }
    }
    else {
        $params->{matchmaking_event_id} = 0;
    }

    return $valid_params;
}

# TODO: maybe fork at some point even before getting to these functions..

sub work_on_ag {
    my ( $self ) = @_;

    #print "\nStarting asynchronous task registering..\n\n";
    $self->_register_functions( $self->AG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_ag_function( @_ ); } );

    #print "\nStarting versioned asynchronous task registering..\n\n";
    $self->_register_functions( $self->AG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_versioned_ag_function( @_ ); } );

    #print "\nStarting asynchronous task working..\n\n";

    $self->_work_until_timeout( sub { Dicole::Utils::Gearman->work_ag( @_ ) }, 'ag' );
}

sub work_on_fg {
    my ( $self ) = @_;

    #print "\nStarting foreground task registering..\n\n";
    $self->_register_functions( $self->FG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_fg_function( @_ ); } );

    #print "\nStarting versioned foreground task registering..\n\n";
    $self->_register_functions( $self->FG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_versioned_fg_function( @_ ); } );

    #print "\nStarting foreground task working..\n\n";

    $self->_work_until_timeout( sub { Dicole::Utils::Gearman->work_fg( @_ ) }, 'fg' );
}

sub work_on_bg {
    my ( $self ) = @_;

    #print "\nStarting background task registering..\n\n";
    $self->_register_functions( $self->BG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_bg_function( @_ ); } );

    #print "\nStarting versioned background task registering..\n\n";
    $self->_register_functions( $self->BG_FUNCTIONS, sub { Dicole::Utils::Gearman->register_versioned_bg_function( @_ ); } );

    #print "\nStarting background task working..\n\n";

    $self->_work_until_timeout( sub { Dicole::Utils::Gearman->work_bg( @_ ) }, 'bg' );
}

sub test_worker {
    my ( $self ) = @_;

    my $funchash = {};

    my $register = sub {
        my ( $funcname, $timeout, $func ) = @_;

        $funchash->{ $funcname } = $func;
    };

    $self->_register_functions( $self->AG_FUNCTIONS, $register );
    $self->_register_functions( $self->BG_FUNCTIONS, $register );
    $self->_register_functions( $self->FG_FUNCTIONS, $register );

    my $p = $self->param('p') || $self->param('parameters');
    my $pj = $self->param('pj') || $self->param('parameters_json');

    my $job = {
        arg => $p ? Dicole::Utils::JSON->encode( $p ) : $pj
    };

    bless $job, "Dicole::FakeJobForWorkerTesting";

    my $fn = $self->param('fn') || $self->param('function_name');

    $funchash->{ $fn }( $job );
}

sub _work_until_timeout {
    my ( $self, $work_function, $type ) = @_;

    $| = 1;

    my $work_until = $self->param('run_for_seconds');

    if ( $self->param('randomize_shutdown_timeout') ) {
        my $min = $self->param('randomize_shutdown_timeout_min') || 60*15;
        my $max = $self->param('randomize_shutdown_timeout_max') || 60*30;
        $work_until = ( rand() * ($max - $min) ) + $min;
    }

    $work_until += time if $work_until;

    my $version = $self->param('override_version') || CTX->server_config->{dicole}->{static_file_version};
    my $require_version_file = $self->param('require_version_file') // '/tmp/required_meetings_worker_version_' . $type;

    if ( $require_version_file && $self->param('require_my_version_on_startup') ) {
        `echo $version > $require_version_file`;
    }

    while ( ! $self->_stop_if( $work_until, $version, $require_version_file ) ) {
        eval { $work_function->( stop_if => sub { return $self->_stop_if( $work_until, $version, $require_version_file ) } ) };
        get_logger(LOG_APP)->error( $@ ) if $@;
    }
}

my $require_version_file_checked = 0;

sub _stop_if {
    my ( $self, $work_until, $version, $require_version_file ) = @_;

    my $now = time;

    return 1 if $work_until && $now > $work_until;

    if ( $require_version_file ) {
        unless ( $require_version_file_checked && $require_version_file_checked + 2 > $now ) {
            if ( -f $require_version_file && (stat($require_version_file))[9] + 10*60 > time ) {
                my $required_version = `cat $require_version_file 2>/dev/null`;
                chomp $required_version;
                return 1 unless $required_version eq $version;
            }
            $require_version_file_checked = $now;
        }
    }

    return 0;
}

sub _register_functions {
    my ( $self, $hash, $register_function ) = @_;

    for my $funcname ( sort { $a cmp $b } keys %$hash ) {
        $register_function->( $self->_register_params( $funcname, $hash ) );
    }
}

sub _register_params {
    my ( $self, $fn, $function_hash ) = @_;

    my ( $funcname, $timeout ) = $fn =~ /^(.*?)(?:_(\d+))?$/;
    $timeout = undef if ! $timeout || $timeout < 1 || $timeout > 255;

    # This should not go to stdout, which is access log. If this is needed, find some debug log for it.
    #print "Registering task $funcname " . ( $timeout ? "with timeout $timeout.." : "without timeout.." ) . "\n";

    return ( $funcname, $timeout, $self->_prime_function( $function_hash->{ $fn }, $funcname ) );
}

sub _prime_function {
    my ( $self, $function, $name ) = @_;

    my $default_domain_id = $self->param('domain_id');

    return sub {
        my ( $job ) = @_;

        my $params = $job->arg ? eval { Dicole::Utils::JSON->decode( $job->arg ) } || {} : {};
        $params->{domain_id} //= $default_domain_id;

        if ( my $lang = $params->{lang} ) {
            CTX->{current_job_language} = $lang;
        }

        if ( my $auth_user_id = $params->{auth_user_id} ) {
            CTX->{current_job_auth_user_id} = $auth_user_id;
        }

        my $start_time = Time::HiRes::time;

        my $return = eval { $function->( $self, $params ) };
        my $error = $@;

        CTX->{current_job_language} = '';
        CTX->{current_job_auth_user_id} = '';

        if ( $error ) {
            $error = $error . " " . Data::Dumper::Dumper( $error ) if ref( $error );

            get_logger(LOG_APP)->error(
                "\n$name " . $self->_return_as_json( $params ).": \n$error\n"
            );
        }

        my $result = $self->_return_as_json(
            $error ? { error => { code => 503, message => $error } } : $return
        );

        print DateTime->now->ymd . ' ' . DateTime->now->hms . ' ' if CTX->server_config->{dicole}{development_mode};

        $self->_log_to_stdout( $error ? 'ERROR' : 'OK', $name, length( $result ), $params, $start_time, $result );

        print  "\n" . " ---> " . $result . "\n\n\n" if CTX->server_config->{dicole}{development_mode};

        return $result;
    };
}

sub _log_to_stdout() {
    my ( $self, $type, $name, $size, $params, $start_time, $result ) = @_;

    return if $name eq 'fetch_or_create_meeting_suggestion';
    return if $name eq 'trim_user_meeting_suggestions_for_source_timespan';

    my $elapsed_time = Time::HiRes::time - $start_time;

    # We are interested only in the relative start order within this machine at this level
    $start_time =~ s/.*(\d\d\.)/$1/;
    $start_time =~ s/(.*\.\d\d?\d?).*/$1/;

    my $auth_user_id = delete $params->{auth_user_id} // '-';
    my $meeting_id = $params->{meeting_id} // '-';
    my $request_id = delete $params->{request_id} // 'none';

    delete $params->{domain_id};

    print join ' ',
        $start_time, $type, sprintf( '%.3f', $elapsed_time ),
        $name, $auth_user_id,
        $self->_return_as_json($params), $size, $request_id;

    if ( ! CTX->server_config->{dicole}{development_mode} ) {
        my $r = $result;
        # NOTE: we don't want full dumps to access logs so we truncate
        $r =~ s/^(.{512}).*/$1...TRUNCATED.../s;
        print  " ---> " . $r;
    }

    print "\n";
}

sub _return_as_json {
    my ( $self, $value ) = @_;
    my $return_string = ( ref $value ) ? Dicole::Utils::JSON->encode( $value ) : $value;
    return $return_string;
}

sub _validate_params_scheduling_id {
    my ( $self, $params ) = @_;

    return 1 if $params->{scheduling_id} && $params->{scheduling_id} =~ /^[123456789]\d*$/;
    get_logger(LOG_APP)->error( $self->_error_with_params( 'malformed scheduling_id in params', $params ) );
    return 0;
}

sub _validate_params_user_id {
    my ( $self, $params ) = @_;

    return 1 if $params->{user_id} && $params->{user_id} =~ /^[123456789]\d*$/;
    get_logger(LOG_APP)->error( $self->_error_with_params( 'malformed user_id in params', $params ) );
    return 0;
}

sub _error_with_params {
    my ( $self, $error, $params ) = @_;

    return $error . ': ' . $self->_return_as_json( $params );
}

1;

package Dicole::FakeJobForWorkerTesting;

sub arg { return $_[0]->{arg} };

1;
                                                                                                          
