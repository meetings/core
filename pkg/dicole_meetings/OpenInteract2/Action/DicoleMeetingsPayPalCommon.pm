package OpenInteract2::Action::DicoleMeetingsPayPalCommon;

use 5.010;
use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Business::PayPal::NVP;
use DateTime;
use DateTime::Format::CLDR;
use Encode qw/encode_utf8/;
use IPC::Run qw/run/;
use Data::Dump qw/dump dd/;

sub _is_success {
    my ($self, %result) = @_;

    return $result{result} =~ /success/i;
}

sub _paypal_datetime_parser {
    my $self = shift;

    $self->{_paypal_datetime_format_parser} ||= $self->_build_paypal_datetime_parser;
}

sub _build_paypal_datetime_parser {
    my $self = shift;

    return DateTime::Format::CLDR->new(
        pattern => 'HH:mm:ss MMM dd, yyyy zzz',
        locale  => 'en_US'
    );
}

sub _paypal_business_id { CTX->server_config->{dicole}{paypal_business_id} || 'info@dicole.com' }
# NOTE: certificate and certificate_id do not have anything to do with each other. cert id is the paypal's generated unique id for our cert.
sub _paypal_certificate_id { CTX->server_config->{dicole}{paypal_certificate_id} || 'MPVTRDZMF2Y2Y' }
sub _paypal_private_key { CTX->server_config->{dicole}{paypal_private_key} }
sub _paypal_public_key { CTX->server_config->{dicole}{paypal_public_key} }
sub _paypal_certificate { CTX->server_config->{dicole}{paypal_certificate} }

sub _client {
    my $self = shift;

    return $self->{_client} ||= $self->_build_client;
}

sub _build_client {
    my $self = shift;

    my $branch = CTX->server_config->{dicole}{paypal_nvp_branch} || 'test';

    return Business::PayPal::NVP->new(
        test => {
            user => 'info_api1.dev.meetin.gs',
            pwd => '86FML3BPDLDYB44M',
            sig => 'AkANzlMjWI.mh5ok7XVgrdqtY-jKAZaGJJx-RfQpTqWzAh1QterxAto3',
            version => '74.0',
        },
        live => {
            user => CTX->server_config->{dicole}{paypal_nvp_user},
            pwd => CTX->server_config->{dicole}{paypal_nvp_pwd},
            sig => CTX->server_config->{dicole}{paypal_nvp_sig},
            version => '74.0',
        },
        branch => $branch,
    );
}




sub _encrypt_paypal_button {
    my ($self, %p) = @_;

    $p{cert_id} = $self->_paypal_certificate_id;

    my $data = $self->_hash_to_binary_string(%p);

    my @cmd_sign = (openssl => smime =>
        -sign,
        -signer  => $self->_paypal_public_key,
        -inkey   => $self->_paypal_private_key,
        -outform => 'der',
        -nodetach,
        -binary
    );

    my @cmd_encrypt = (openssl => smime =>
        -encrypt,
        -des3,
        -binary,
        -outform => 'pem',
        $self->_paypal_certificate
    );

    my $encrypted;
    my $err_output;

    run \@cmd_sign, \$data, '2>', \$err_output, '|', \@cmd_encrypt, '>', \$encrypted;

    get_logger(LOG_APP)->error("[crypt error] $err_output") if $err_output;

    return $encrypted;

}

sub _hash_to_binary_string {
    my ($self, %p) = @_;

    return join "\n", map { encode_utf8("$_=$p{$_}") } keys %p;
}

sub _validate_promotion_code {
    my ( $self, $promo, $code, $domain_id ) = @_;

    return 0 if $promo->start_date && $promo->start_date > time;
    return 0 if $promo->end_date && $promo->end_date < time;

    if ( ! $promo->promotion_code ) {
        $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

        my $code_object = CTX->lookup_object('meetings_promotion_code')->fetch_group({
            where => 'domain_id = ? AND promotion_code = ?',
            value => [ $domain_id, $code ],    
        });

        my $code = shift @$code_object;

        return 0 unless $code;
        return 0 if $code->consumed_date;
    }

    return 1;
}

sub _fetch_promotion_for_code {
    my ( $self, $code, $domain_id ) = @_;

    return unless $code;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $promos = CTX->lookup_object('meetings_promotion')->fetch_group();

    for my $promo ( @$promos ) {
        next unless uc( $code) eq uc( $promo->promotion_code );
        return $promo;
    }

    my $promo_codes = CTX->lookup_object('meetings_promotion_code')->fetch_group( {
        where => 'domain_id = ? AND promotion_code = ?',
        value => [ $domain_id, $code ],
    } );

    if ( my $code = shift @$promo_codes ) {
        my %promo_by_id = map { $_->id => $_ } @$promos;
        return $promo_by_id{ $code->promotion_id };
    }

    return;
}

sub _start_subscription {
    my ($self) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $subscription_type = CTX->request->param('type');

    my $user_id = CTX->request->auth_user_id;
    my $user    = CTX->request->auth_user;

    my $email = $user_id && $user->email
                || CTX->request->param('email') eq CTX->request->param('email_confirmation') && CTX->request->param('email')
                || die {
                    code => 666,
                    message => "email and email_confirmation do not match"
                };
    my $host = $self->_get_host_for_user( $user, 443 );

    my $email_user = $self->_fetch_user_for_email($email);

    if (!$email_user) {
        $user = $email_user = $self->_fetch_or_create_user_for_email($email, $domain_id);
    } else {
        $user = $email_user;
    }

    $user_id = $user->id;

    get_logger(LOG_APP)->error("Starting subscription process for user '$user_id', '" . $user->login_name . "'");

    my $return_url = $host . $self->derive_url(
        action => 'meetings_paypal',
        task   => 'complete',
        params => {
            email   => $email,
            user_id => $user_id,
            type    => $subscription_type
        },
        do_not_escape => 1
    );

    my $subscribed_to_promotions = CTX->request->param('subscribe_promo');
    my $subscribed_to_info = CTX->request->param('subscribe_info');

    $self->_set_note_for_user(emails_requested_for_offers => time, $user) if $subscribed_to_promotions;
    $self->_set_note_for_user(emails_requested_for_info   => time, $user) if $subscribed_to_info;
    $self->_user_accept_tos($user, $domain_id) if CTX->request->param('tos');

    my $promo = $self->_fetch_promotion_for_code( $subscription_type, $domain_id );

    if ( $promo && ! $self->_validate_promotion_code( $promo, $subscription_type, $domain_id ) ) {
        return {
            error => { message => "Unfortunately the code you provided is no longer valid." }
        };
    }

    if ( $promo and ! $promo->dollar_price ) {
        if ( @{ $self->_user_trials($user) } ) {
            return {
                error => { message => "User has used trial(s), new free trials not allowed. If you think this is a mistake, please email us at info\@meetin.gs ."  }
            };            
        }

        $self->_send_account_upgraded_mail_to_user(
            user => $user,
            domain_id => $domain_id
        );

        my $ret = $self->_create_free_trial_subscription(
            user       =>  $user,
            promo      =>  $promo,
            promo_code =>  uc $subscription_type,
            domain_id  => $domain_id,
        );

        $self->_calculate_user_is_pro($user, $domain_id);

        return $ret;
    }

    $self->_set_note_for_user(started_paypal_flow_time => time, $user, $domain_id) if $user_id;

    my $encrypted_form = $self->_encrypt_paypal_button(
        $self->_build_form(
            promo             => $promo,
            email             => $email,
            user_id           => $user_id,
            subscription_type => $subscription_type,
            return_url        => $return_url,
            host              => $host
        )
    );

    return {
        result => {
            url  => CTX->server_config->{dicole}{paypal_gateway_url},
            form => {
                cmd       => "_s-xclick",
                encrypted => $encrypted_form
            }
        }
    };
}

sub _build_form {
    my ($self, %p) = @_;

    my $id = join ",", $p{email}, $p{user_id}, $p{subscription_type} || ();

    my %subscription;

    my $promo = $p{promo};

    if (defined $promo or $p{subscription_type} =~ /^monthly/) {
        %subscription = (
            a3 => '12.00',
            p3 => '1',
            t3 => 'M'
        )
    } else {
        %subscription = (
            a3 => '129.00',
            p3 => '1',
            t3 => 'Y'
        )
    }

    my %promo_params;

    if (defined $promo) {
        %promo_params = (
            a1 => $promo->dollar_price,
            p1 => $promo->duration,
            t1 => $promo->duration_unit,
        );

        if (defined $promo->dollar_price and ! $promo->dollar_price ) {
            get_logger(LOG_APP)->error("Tried to create PayPal subscription for a free trial");
            return;
        }
    }

    return (
        cmd           => "_xclick-subscriptions",
        business      => $self->_paypal_business_id,
        item_name     => "Meetin.gs subscription",
        currency_code => "USD",
        custom        => $id,
        rm            => 2,

        %subscription,

        %promo_params,

        src           => 1,
        no_note       => 1,
        no_shipping   => 1,
        return        => $p{return_url},
        cancel_return => $p{cancel_url} || ( $p{host} . $self->derive_url(action => 'meetings_paypal', task => 'cancel') )
    );
}

sub _consume_promo_code {
    my ( $self, $promo_code, $user, $domain_id ) = @_;

    my $promo_code_object = CTX->lookup_object('meetings_promotion_code')->fetch_group({
        where => 'domain_id = ? AND promotion_code = ?',
        value => [ $domain_id, $promo_code ],
    });

    for my $code ( @$promo_code_object ) {
        $code->consumed_date( time );
        $code->consumer_id( $user->id );
        $code->save;
    }
}

sub _create_free_trial_subscription {
    my ($self, %params) = @_;

    my $user = $params{user};
    my $promo = $params{promo};

    if ( $promo ) {
        $self->_consume_promo_code( $params{promo_code}, $user, $params{domain_id} );
    }

    get_logger(LOG_APP)->error("Creating trial for user '" . $user->login_name . "'");

    my $now = time;

    my $trial = CTX->lookup_object('meetings_trial')->new({
        user_id       => $user->id,
        creator_id    => 0,
        domain_id     => Dicole::Utils::Domain->guess_current_id,
        creation_date => $now,
        start_date    => $now,
        duration_days => $self->_promo_duration_in_days($promo),
        trial_type    => $params{promo_code},
        notes         => Dicole::Utils::JSON->encode({})
    });

    $trial->save;

    return {
        result => {
            url => CTX->request->param('current_url') || $self->_get_host_for_domain( $params{domain_id}, 443 ) . $self->derive_url( action => 'meetings_paypal', task => 'thanks_free' ),
        }
    };
}

sub _promo_duration_in_days {
    my ($self, $promo) = @_;

    return $promo->duration * { M => 31, Y => 365 }->{ $promo->duration_unit };
}

sub _valid_promo {
    my ($self) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $code = CTX->request->param('promo_code');
    my $promo = $self->_fetch_promotion_for_code( $code, $domain_id );

    if ($promo) {

        if ( ! $self->_validate_promotion_code( $promo, $code, $domain_id ) ) {
            die {
                code => 42,
                message => "Unfortunately the code you provided is no longer valid."
            };    
        }

        my $description = $self->_get_note( description => $promo );

        if ( ! $description ) {
            my $duration = $promo->duration;
            my $price = $promo->dollar_price;

            my $period = $promo->duration_unit eq 'M' ? 'month' : 'year';
            my $period_unit = $period;

            $period .= 's' if $duration > 1;

            if ( ! $price ) {
                $description = "$duration free $period";
            }
            else {
                $description = "Pay \$$price per $period_unit for the first $duration $period + \$12 per month afterwards";
            }
        }

        return {
            result => [ {
                description => $description,
                value => $code
            } ]
        }
    } else {
        die {
            code => 42,
            message => "No such promotion"
        };
    }
}

# XXX: These are currently not used but might provide to be valuable when
# preparing for problems or handling them programmatically
sub _normalize_api_transaction_details_result {
    my ($self, %transaction) = @_;

    return $self->_normalize_transaction({
         AMT            => 'amount',
         COUNTRYCODE    => 'country',
         CURRENCYCODE   => 'currency_code',
         CUSTOM         => 'custom',
         EMAIL          => 'payer_email',
         FEEAMT         => 'fee_amount',
         FIRSTNAME      => 'first_name',
         LASTNAME       => 'last_name',
         NAME           => 'item_name',
         ORDERTIME      => 'transaction_date',
         PAYERID        => 'payer_id',
         PAYERSTATUS    => 'payer_status',
         PAYMENTTYPE    => 'payment_type',
         RECEIVEREMAIL  => 'receiver_email',
         RECEIVERID     => 'receiver_id',
         SUBSCRIPTIONID => 'subscription_id',
         TRANSACTIONID  => 'transaction_id',
         TRANSACTIONTYPE=> 'transaction_type',
    }, \%transaction);
}

sub _normalize_api_search_transaction_result {
    my ($self, %transaction) = @_;

    return $self->_normalize_transaction({
        TYPE          => 'transaction_type',
        TRANSACTIONID => 'transaction_id',
    }, \%transaction);
}

sub _normalize_ipn_transaction {
    my ($self, %transaction) = @_;

    return $self->_normalize_transaction({
        amount1           => 'trial_amount',
        amount3           => 'amount',
        payment_gross     => 'amount',
        business          => 'receiver_email',
        custom            => 'custom',
        first_name        => 'first_name',
        item_name         => 'item_name',
        last_name         => 'last_name',
        mc_currency       => 'currency_code',
        payer_email       => 'payer_email',
        payer_id          => 'payer_id',
        payer_status      => 'payer_status',
        payment_type      => 'payment_type',
        period1           => 'trial_period',
        period3           => 'period',
        reattempt         => 'reattempt',
        receiver_id       => 'receiver_id',
        recurring         => 'is_recurring',
        residence_country => 'country',
        subscr_date       => 'subscription_date',
        subscr_id         => 'subscription_id',
        test_ipn          => 'is_ipn_test',
        txn_id            => 'transaction_id',
        txn_type          => 'transaction_type',
    }, \%transaction, $transaction{charset} );
}

sub _normalize_transaction {
    my ($self, $map, $transaction, $decode_charset ) = @_;

    if ( $decode_charset ) {
        for my $key ( keys %$transaction ) {
            my $internal_value = Encode::decode( $decode_charset, $transaction->{ $key } );
            $transaction->{ $key } = Encode::encode_utf8( $internal_value );
        }
    }

    return map { ($map->{$_} // $_) => $transaction->{$_} } keys %$transaction;
}

sub _send_transaction_receipt {
    my ($self, %params) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $params{domain_id} );

    my $user        = $params{user};
    my $transaction = $params{transaction};

    get_logger(LOG_APP)->debug("Sending receipt to " . $user->login_name);

    my $timestamp = Dicole::Utils::Date->epoch_to_date_and_time_strings($transaction->{payment_date}, $user->timezone, 'en', 'ampm');
    my $timezone = Dicole::Utils::Date->timezone_info($user->timezone)->{offset_string};

    my $time_string = "$timestamp->[0] $timestamp->[1] $timezone";

    $self->_send_themed_mail(
        user      => $user,
        domain_id => $domain_id,

        template_key_base => 'meetings_paypal_receipt',
        template_params   => {
            user_name    => Dicole::Utils::User->name($user),
            payment_date => $time_string,
            user_login   => $user->login_name,
            amount       => '$' . $transaction->{amount},
            item_name    => 'Meetin.gs subscription'
        }
    );
}

sub _get_subscription_transactions {
    my ($self, $subscription) = @_;

    my $user_subscriptions = CTX->lookup_object('meetings_paypal_transaction')->fetch_group({
            where => 'user_id = ? and domain_id = ?',
            value => [ $subscription->user_id, $subscription->domain_id ]
    });

    # TODO DB index
    return [ grep {
        $self->_get_note(subscription_id => $_) eq $subscription->subscription_id
    } @$user_subscriptions ];
}

1;
