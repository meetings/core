package OpenInteract2::Action::DicoleMeetingsAppDirect;

use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Net::OAuth;
#use LWPx::ParanoidAgent; # This makes discover fail in certain situations
use Net::OpenID::Consumer;

sub login {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $openid = CTX->request->param('openid');
    my $sub_id = CTX->request->param('accountId');

    my $csr = Net::OpenID::Consumer->new(
#        ua => LWPx::ParanoidAgent->new,
        consumer_secret => 'secret',
        cache => Cache::Memcached->new({
            namespace => 'openid',
            servers => CTX->server_config->{dicole}->{memcached_server},
            compress_threshold => 10_000,
        }),
        required_root => Dicole::URL->get_server_url( 443 ),
    );

    my $claimed_identity = $csr->claimed_identity( $openid );
    if ( ! $claimed_identity ) {
        die "not actually an openid? ($openid)  " . $csr->err;
    }

    $claimed_identity->set_extension_args( "http://openid.net/srv/ax/1.0", {
        'mode' => 'fetch_request',
        'type.email' => 'http://axschema.org/contact/email',
        'type.firstname' => 'http://axschema.org/namePerson/first',
        'type.lastname' => 'http://axschema.org/namePerson/last',
        'type.language' => 'http://axschema.org/pref/language',
        'type.organization' => 'http://axschema.org/company/name',
        'type.title' => 'http://axschema.org/company/title',
        'type.useruuid' => 'https://www.appdirect.com/schema/user/uuid',
        'required' => 'email',
    } );

    my $check_url = $claimed_identity->check_url(
        return_to => Dicole::URL->get_server_url( 443 ) . $self->derive_url( task => 'login_forward', params => { subscription_id => $sub_id } ),
        trust_root => Dicole::URL->get_server_url( 443 ),
        delayed_return => 1
    );

    return $self->redirect( $check_url );
}

sub login_forward {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $csr = Net::OpenID::Consumer->new(
        args => CTX->request->cgi,
        consumer_secret => 'secret',
        cache => Cache::Memcached->new({
            namespace => 'openid',
            servers => CTX->server_config->{dicole}->{memcached_server},
            compress_threshold => 10_000,
        }),
    );

    $csr->handle_server_response(
        verified => sub {
            my ( $verified_identity ) = @_;

            my $email = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.email");
            my $fn = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.firstname");
            my $ln = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.lastname");
            my $lang = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.language");
            my $organization = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.organization");
            my $title = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.title");
            my $useruuid = $csr->message->get_ext("http://openid.net/srv/ax/1.0", "value.useruuid");

            my $user = $self->_fetch_user_for_email( $email );
            my $subscription_id = CTX->request->param('subscription_id');
            my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

            die "Could not log in user without a subscription" unless $subscription;

            my $base_url = $self->_get_note( appdirect_base_url => $subscription );

            die "Verified identity not under subscription base_url" unless $base_url && index( $verified_identity->url, $base_url ) == 0;

            my $partner = $self->_ensure_partner_object( $subscription->partner_id );

            my $user_save = 0;

            if ( $fn && ! $user->first_name ) {
                $user->first_name( $fn );
                $user_save = 1;
            }

            if ( $ln && ! $user->last_name ) {
                $user->last_name( $ln );
                $user_save = 1;
            }

            $user->save if $user_save;

            # TODO SECURITY: verify that verified identity is found under partner app marketplace domain???

            my $pcs = $self->_create_partner_authentication_checksum_for_user( $partner, $user );

            return $self->redirect( $self->_get_host_for_domain( $domain_id, 443 ) . $self->derive_url(
                action => 'meetings', task => 'enter_summary', additional => [], params => {
                    login_email => $user->email,
                    partner_id => $partner->id,
                    pcs => $pcs || '',
                }
            ) );
        },
        cancelled => sub {
            die $self->redirect( $self->derive_url( action => 'meetings', task => 'login', additional => []  ) );
        },
        not_openid => sub {
            die "unexpected not_openid";
        },
        error => sub {
            my ($errcode, $errmsg) = @_;
            die "unexpected error: " . $errcode . " -- " . $errmsg ;
        },
        setup_needed => sub {
            die "unexpected setup_needed";
        },
    );
}

sub create {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $partner = $self->param('partner');
    $partner ||= $self->_fetch_or_create_partner_from_appdirect_data( $data, $domain_id );

    my $company_external_id = $data->{payload}{company}{uuid};

    my $previous_subscriptions = CTX->lookup_object('meetings_company_subscription')->fetch_group( {
        where =>'removed_date = 0 AND cancelled_date = 0 AND domain_id = ? AND external_company_id = ?',
        value => [ $domain_id, $company_external_id ],
        order => 'id asc',
    } );

    return $self->_create_xml_error_message( UNKNOWN_ERROR => 'An existing subscription already exists for your company' ) if @$previous_subscriptions;

    my $creator_user = $self->_fetch_user_for_email( $data->{creator}{email} );
    $creator_user ||= $self->_create_user_from_appdirect_data( $data->{creator}, $domain_id, $partner );

    # TODO: create subscription,store external_company_id
    my $subscription = CTX->lookup_object('meetings_company_subscription')->new( {
        domain_id => $domain_id,
        partner_id => $partner ? $partner->id : 0,
        created_date => time,
        creator_id => $creator_user->id,
        admin_id => $creator_user->id,
        removed_date => 0,
        remover_id => 0,
        expires_date => 0,
        cancelled_date => 0,
        updated_date => time,
        company_name => $data->{payload}{company}{name} || '',
        external_company_id => $company_external_id || '',
        user_amount => 0,
        is_trial => 0,
        is_pro => 0,

        notes => '',
    } );

    $self->_set_note( company_phone => $data->{payload}{company}{phoneNumber} || '', $subscription, { skip_save => 1 } );
    $self->_set_note( company_website => $data->{payload}{company}{website} || '', $subscription, { skip_save => 1 } );
    $self->_set_note( appdirect_base_url => $data->{marketplace}{baseUrl} || '', $subscription, { skip_save => 1 } );
    $self->_set_note( appdirect_partner => $data->{marketplace}{partner} || '', $subscription, { skip_save => 1 } );

    $subscription->save;

    my $current_subscriptions = CTX->lookup_object('meetings_company_subscription')->fetch_group( {
        where =>'removed_date = 0 AND cancelled_date = 0 AND domain_id = ? AND external_company_id = ?',
        value => [ $domain_id, $company_external_id ],
        order => 'id asc',
    } );

    unless ( $current_subscriptions->[0] && $current_subscriptions->[0]->id == $subscription->id ) {
        $subscription->remove;
        return $self->_create_xml_error_message( UNKNOWN_ERROR => 'Subscription already exists' );
    }

    $self->_set_subscription_status_using_event_data( $subscription, $data );

    my $uuid = $data->{creator}{uuid};

    $self->_assing_user_to_company_subscription( $creator_user, $subscription, $creator_user, { is_admin => 1, external_user_id => $uuid } );

    return $self->_create_xml_success_message('Success', $subscription->id );
}

sub change {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $subscription_id = $data->{payload}{account}{accountIdentifier};
    my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

    if ( ! $subscription ) {
        return $self->_create_xml_error_message( ACCOUNT_NOT_FOUND => '' );
    }

    $self->_set_subscription_status_using_event_data( $subscription, $data );

    return $self->_create_xml_success_message;
}

sub cancel {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $subscription_id = $data->{payload}{account}{accountIdentifier};
    my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

    if ( ! $subscription ) {
        return $self->_create_xml_error_message( ACCOUNT_NOT_FOUND => '' );
    }
    $self->_set_subscription_status_using_event_data( $subscription, $data );

    return $self->_create_xml_success_message;
}

sub status {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $subscription_id = $data->{payload}{account}{accountIdentifier};
    my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

    if ( ! $subscription ) {
        return $self->_create_xml_error_message( ACCOUNT_NOT_FOUND => '' );
    }

    $self->_set_subscription_status_using_event_data( $subscription, $data );

    return $self->_create_xml_success_message;
}

sub _set_subscription_status_using_event_data {
    my ( $self, $subscription, $data ) = @_;

    my $recalculate = 0;

    if ( uc( $data->{type} ) eq 'SUBSCRIPTION_ORDER' || uc( $data->{type} ) eq 'SUBSCRIPTION_CHANGE' ) {
        $self->_set_note( edition_code => $data->{payload}{order}{editionCode} || '', $subscription, { skip_save => 1 } );

        my $item_data = $data->{payload}{order}{item};
        my @items = ( ref( $item_data ) eq 'ARRAY' ) ? @$item_data : ( $item_data || () );

        my $user_quantity = 0;
        for my $item ( @items ) {
            next unless uc( $item->{unit} ) eq 'USER';
                $user_quantity = $item->{quantity};
        }

        $subscription->user_amount( $user_quantity );
        $subscription->is_pro( uc( $data->{payload}{order}{editionCode} ) eq 'FREE' ? 0 : 1 );
        $subscription->is_trial( uc( $data->{payload}{order}{editionCode} ) eq 'TRIAL' ? 1 : 0 );

        # TODO: make sure that new user_amount is adequate for current users and fail if not

        $recalculate = 1;
    }
    elsif ( uc( $data->{type} ) eq 'SUBSCRIPTION_NOTICE' ) {
        if ( uc ( $data->{payload}{notice}{type} ) eq 'DEACTIVATED' ) {
            $subscription->expires_date( time );
        }
        elsif ( uc ( $data->{payload}{notice}{type} ) eq 'CLOSED' ) {
            $subscription->cancelled_date( time );
            $subscription->expires_date( time );
        }
        elsif ( uc ( $data->{payload}{notice}{type} ) eq 'REACTIVATED' ) {
            $subscription->expires_date( 0 );
        }

        $recalculate = 1;
    }
    elsif ( uc( $data->{type} ) eq 'SUBSCRIPTION_CANCEL' ) {
        $subscription->cancelled_date( time );
        $subscription->expires_date( time );

        $recalculate = 1;
    }

    if ( $recalculate ) {
        $subscription->updated_date( time );
        $subscription->save;

        Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_company_subscription_pro => {
            subscription_id => $subscription->id,
        } );
    }
}

sub assign {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $subscription_id = $data->{payload}{account}{accountIdentifier};
    my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

    if ( ! $subscription ) {
        return $self->_create_xml_error_message( ACCOUNT_NOT_FOUND => '' );
    }

    my $partner = $self->_ensure_partner_object( $subscription->partner_id );
    my $by_user_email = $data->{creator}{email};
    my $by_user = $self->_fetch_user_for_email( $by_user_email );

    my $existing_target_user = $self->_fetch_user_for_email( $data->{payload}{user}{email} );
    my $target_user = $existing_target_user || $self->_create_user_from_appdirect_data( $data->{payload}{user}, $domain_id, $partner );

    if ( my $lang = $data->{payload}{user}{language} ) {
        if ( $lang =~ /(?:se|sv|sw)/i ) {
            if ( ! $existing_target_user ) {
                $target_user->language( 'sv' );
            }
        }
        elsif ( $lang =~ /(?:fi)/i ) {
            if ( ! $existing_target_user ) {
                $target_user->language( 'fi' );
            }
        }

        $self->_set_note_for_user( preferred_appdirect_language => $lang, $target_user, $domain_id );
    }

    my $uuid = $data->{payload}{user}{uuid};

    # TODO :
#<result>
#    <success>false</success>
#    <errorCode>MAX_USERS_REACHED</errorCode>
#    <message>Optional message about the max users being reached</message>
#</result>

    $self->_assing_user_to_company_subscription( $target_user, $subscription, $by_user, { external_user_id => $uuid } );

    return $self->_create_xml_success_message;
}

sub _fetch_or_create_partner_from_appdirect_data {
    my ( $self, $data, $domain_id ) = @_;

    my $base_url = $data->{marketplace}{baseUrl};
    my $partner_name = $data->{marketplace}{partner} || '';

    if ( ! $base_url ) {
        die "Appdirect event data was missing marketplace information";
    }

    my $partner = $self->PARTNERS_BY_APPDIRECT_BASE_URL->{ $base_url };
    if ( ! $partner ) {
        my @chars = split //, "abcdefghjkmnpqrstxz23456789";
        my $key = join "", map { $chars[rand @chars] } 1 .. 16;

        $partner = CTX->lookup_object('meetings_partner')->new( {
            domain_id => $domain_id,
            creator_id => 0,
            creation_date => time,
            api_key => $key,
            domain_alias => '',
            localization_namespace => '',
            name => $partner_name,
            notes => '',
        } );

        $self->_set_note( appdirect_base_url => $base_url, $partner );

        $self->clear_partner_cache;

        # Refetch in order to prevent two being created (and used) for same url
        return $self->_fetch_or_create_partner_from_appdirect_data( $data, $domain_id );
    }

    return $partner;
}


sub _create_user_from_appdirect_data {
    my ( $self, $data, $domain_id, $partner ) = @_;

    my $user = $self->_fetch_or_create_user_for_email( $data->{email} );
    $user->first_name( $data->{firstName} );
    $user->last_name( $data->{lastName} );

    if ( $partner ) {
        $self->_set_note_for_user( created_from_appdirect_partner => $partner->id, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( "login_allowed_for_partner_" . $partner->id, time, $user, $domain_id, { skip_save => 1 } );
        if ( my $tz = $self->_get_note( default_time_zone => $partner ) ) {
            $user->timezone( $tz );
        }
    }
    $self->_set_note_for_user( created_from_appdirect => time, $user, $domain_id );

    return $user;
}

sub unassign {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $data = $self->_fetch_and_record_validated_notification_data;
    return $data unless ref( $data );

    my $subscription_id = $data->{payload}{account}{accountIdentifier};
    my $subscription = $self->_ensure_object_of_type( meetings_company_subscription => $subscription_id );

    if ( ! $subscription ) {
        return $self->_create_xml_error_message( ACCOUNT_NOT_FOUND => '' );
    }

    my $by_user_email = $data->{creator}{email};
    my $by_user = $self->_fetch_user_for_email( $by_user_email );

    my $target_user_email = $data->{payload}{user}{email};
    my $target_user = $self->_fetch_user_for_email( $target_user_email );

    my $uuid = $data->{payload}{user}{uuid};

    my $success = $self->_unassing_user_from_company_subscription( $target_user, $subscription, $by_user );
    $success = $self->_unassing_user_from_company_subscription_by_external_user_id( $uuid, $subscription, $by_user ) || $success;

    if ( ! $success) {
        return $self->_create_xml_error_message( USER_NOT_FOUND => '' );
    }

    return $self->_create_xml_success_message;
}

sub _unassing_user_from_company_subscription {
    my ( $self, $target_user, $subscription, $by_user ) = @_;

    my $assignments = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
        where =>'removed_date = 0 AND subscription_id = ? AND user_id = ?',
        value => [ $subscription->id, $target_user->id ],
        order => 'id asc',
    } );

    for my $a ( @$assignments ) {
        $a->removed_date( time );
        $a->remover_id( $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : 0 );
        $a->save;

        my $trials = CTX->lookup_object('meetings_trial')->fetch_group({
            where => 'user_id = ?',
            value => [ $a->user_id ],
        });

        for my $trial ( @$trials ) {
            my $trial_subscription_id = $self->_get_note( appdirect_subscription_id => $trial );
            next unless $trial_subscription_id && $trial_subscription_id == $subscription->id;
            $trial->remove;
        }

        Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_user_pro => {
            user_id => $a->user_id,
        } );
    }

    return scalar( @$assignments );
}

sub _unassing_user_from_company_subscription_by_external_user_id {
    my ( $self, $uuid, $subscription, $by_user ) = @_;

    my $assignments = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
        where =>'removed_date = 0 AND subscription_id = ? AND external_user_id = ?',
        value => [ $subscription->id, $uuid ],
        order => 'id asc',
    } );

    for my $a ( @$assignments ) {
        $a->removed_date( time );
        $a->remover_id( $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : 0 );
        $a->save;

        # NOTE: this is legacy stuff as trials are not created anymore, but does not harm either
        my $trials = CTX->lookup_object('meetings_trial')->fetch_group({
            where => 'user_id = ?',
            value => [ $a->user_id ],
        });

        for my $trial ( @$trials ) {
            my $trial_subscription_id = $self->_get_note( appdirect_subscription_id => $trial );
            next unless $trial_subscription_id && $trial_subscription_id == $subscription->id;
            $trial->remove;
        }

        Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_user_pro => {
            user_id => $a->user_id,
        } );
    }

    return scalar( @$assignments );
}

sub _fetch_and_record_validated_notification_data {
    my ( $self ) = @_;

    my $notification_xml = eval { $self->_fetch_validated_notification_xml };

    my $error = $@;

    CTX->lookup_object('meetings_appdirect_notification')->new( {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        partner_id => $self->param('partner_id') || 0,
        created_date => time,
        payload => $notification_xml ? $notification_xml : 'ERROR: ' . $error,
        event_url => CTX->request->param('url') || '',
    } )->save;

    if ( $error ) {
        return $self->_create_xml_error_message( UNKNOWN_ERROR => $error );
    }

    my $data = eval { XML::Simple->new->XMLin( $notification_xml ) };
    if ( $@ || ! ref( $data ) ) {
        get_logger(LOG_APP)->error( $@ ) if $@;
        return $self->_create_xml_error_message( INVALID_RESPONSE => "Failed parsing XML of event: $@" );
    }

    if ( $data->{flag} && $data->{flag} eq 'STATELESS' ) {
        return $self->_create_xml_error_message( UNKNOWN_ERROR => "Not acting on a STATELESS event" );
    }

    return $data;
}

sub _fetch_validated_notification_xml {
    my ( $self ) = @_;

    my $url = CTX->request->param('url');

    die 'Missing notification URL' unless $url;
    my $verified = eval { $self->_verify_notification_request() };
    if ( $@ || ! $verified ) {
        get_logger(LOG_APP)->error( $@ ) if $@;
        die 'OAuth verification failed:' . $@;
    }

    my $notification_xml = eval { $self->_fetch_notification_xml( $url ) };
    if ( $@ || ! $notification_xml ) {
        get_logger(LOG_APP)->error( $@ ) if $@;
        die 'Failed fetching XML of event: ' . $@;
    }

    return $notification_xml;
}

sub _create_xml_error_message {
    my ( $self, $code, $message ) = @_;

    get_logger(LOG_APP)->error( $self->task . ' -> '. $code . ': ' . $message );

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'."\n".'<result>'."\n".'    <success>false</success>'."\n".'    <errorCode>' .$code. '</errorCode>'."\n".'    <message>' .$message. '</message>'."\n".'</result>'."\n";
}

sub _create_xml_success_message {
    my ( $self, $message, $account_identifier ) = @_;

    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'."\n".'<result>'."\n".'    <success>true</success>'."\n". ( $message ? '    <message>' .$message. '</message>' . "\n" : '' ) . ( $account_identifier ? '    <accountIdentifier>'. $account_identifier .'</accountIdentifier>'. "\n" : '' ) .'</result>'."\n";
}

sub _get_oauth_consumer_key {
    my ( $self ) = @_;

    return CTX->server_config->{dicole}->{appdirect_oauth_consumer_key} || 'meetings-dev-6177';
}

sub _get_oauth_consumer_secret {
    my ( $self ) = @_;

    return CTX->server_config->{dicole}->{appdirect_oauth_consumer_secret} || 'VeDo4mEDDWxQuxwx';
}

sub _fetch_notification_xml {
    my ( $self, $url ) = @_;

    my $request = Net::OAuth->request('consumer')->from_hash( {},
        request_method => 'GET',
        request_url => $url,
        signature_method => 'HMAC-SHA1',
        timestamp => time,
        nonce => rand() * 100000000,
        consumer_key => $self->_get_oauth_consumer_key,
        consumer_secret => $self->_get_oauth_consumer_secret,
    );

    $request->sign;

    return Dicole::Utils::HTTP->get( $request->to_url )
}

sub _verify_notification_request {
    my ( $self ) = @_;

    my $vars = {};
    $vars->{url} = CTX->request->param('url');

    my $request = Net::OAuth->request("consumer")->from_authorization_header( CTX->request->cgi->http('authorization'),
        request_url => join( '/', 'https:/', CTX->request->server_name, $self->name , $self->task ),
        request_method => CTX->request->cgi->request_method,
        consumer_key => $self->_get_oauth_consumer_key,
        consumer_secret => $self->_get_oauth_consumer_secret,
        extra_params => $vars,
    );

    return $request->verify();
}

#    my $data = eval { XML::Simple->new->XMLin( $xml ) };


1;
