package OpenInteract2::Action::DicoleMeetingsPayPalJSON;

use 5.010;
use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsPayPalCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

use Business::PayPal::NVP;
use DateTime;
use Data::Dump qw/dump/;
use URI;
use LWP;

sub start {
    my ($self) = @_;

    my $return = $self->_start_subscription;

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg("Congratulations! You are now using Meetin.gs PRO.") ) unless $return->{form};

    return $return;
}

sub ipn {
    my ($self) = @_;

    get_logger(LOG_APP)->error("IPN");

    my $check_url = CTX->server_config->{dicole}{paypal_gateway_url};

    my @params = CTX->request->cgi->param;

    my $ua = LWP::UserAgent->new;

    my @param_pairs = (cmd => "_notify-validate", map { $_ => CTX->request->cgi->param($_) } @params);

    # Not related to paypal, just for personal use
    if (CTX->request->param('DEBUGIPN') eq 'supersecretfoobar') {
        return $self->_process_ipn_message;
    }

    my $response = $ua->post($check_url, [ @param_pairs ]);

    if ($response->is_success) {
        if ($response->decoded_content =~ /^VERIFIED/) {
            $self->_process_ipn_message;
        } else {
            # ignore forged messages
            get_logger(LOG_APP)->error("ipn: forgery");
        }
    } else {
        # TODO error
        get_logger(LOG_APP)->error("ipn: error: fofo " . $response->headers_as_string);
    }
}

sub _process_ipn_message {
    my ($self) = @_;

    get_logger(LOG_APP)->error("IPN: processing");

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $params = CTX->request->param;

    get_logger(LOG_APP)->error("IPN Params: " . dump($params));

    my $given = CTX->request->param('txn_type');
    if ( 1 ) {
        if ( $given eq 'subscr_signup') {
            $self->_process_signup( $params, $domain_id );
        }
        elsif ( $given eq 'subscr_payment') {
            $self->_process_payment( $params, $domain_id );
        }
        elsif ( $given eq 'subscr_cancel') {
            $self->_process_cancellation;
        }
        else {
            get_logger(LOG_APP)->error("Unknown IPN message type: $given");
        }
    }

}

sub _process_signup {
    my ($self, $params, $domain_id ) = @_;

    get_logger(LOG_APP)->error("IPN: signup");

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my %transaction = $self->_normalize_ipn_transaction(%$params);

    get_logger(LOG_APP)->error("Transaction: " . dump(\%transaction));

    my ($email, $user_id, $subscription_type) = split /,/, $transaction{custom};

    get_logger(LOG_APP)->error("email = $email, user_id = $user_id");

    my $user = eval { $self->_fetch_user_for_email( $email, $domain_id ) }
        or return;

    my $subscription_date = $self->_paypal_datetime_parser->parse_datetime($transaction{subscription_date});

    my $notes = Dicole::Utils::JSON->encode(\%transaction);

    my $subscription = CTX->lookup_object('meetings_subscription')->new({
        user_id           => $user->id,
        domain_id         => $domain_id,
        subscription_id   => $transaction{subscription_id},
        subscription_date => $subscription_date->epoch,
        notes             => $notes
    });

    $subscription->save;

    if (defined $transaction{trial_amount}) {
        my ($duration, $unit) = split " ", $transaction{trial_period};

        my $duration_in_days = $self->_duration_from_paypal_period($transaction{trial_period});

        $unit = { M => 'months', Y => 'years', D => 'days' }->{$unit};

        my $trial = CTX->lookup_object('meetings_trial')->new({
            user_id       => $user->id,
            domain_id     => $domain_id,
            creator_id    => $user->id,
            creation_date => $subscription_date->epoch,
            start_date    => $subscription_date->epoch,
            trial_type    => $subscription_type,
            duration_days => $duration_in_days,
            notes         => $notes
        });

        $trial->save;
    }

    $self->_calculate_user_is_pro($user, $domain_id);
}

sub _process_payment {
    my ($self, $params, $domain_id ) = @_;

    get_logger(LOG_APP)->error("IPN: payment");

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my %transaction = $self->_normalize_ipn_transaction(%$params);

    get_logger(LOG_APP)->error("IPN Normalized params: " . dump(\%transaction));

    $transaction{payment_date} = $self->_paypal_datetime_parser->parse_datetime($transaction{payment_date} || $transaction{subscription_date})->epoch;

    my ($email, $user_id, $subscription_type) = split /,/, $transaction{custom};

    my $user = eval { Dicole::Utils::User->ensure_object($user_id) }
        or return;

    my $notes = Dicole::Utils::JSON->encode(\%transaction);

    CTX->lookup_object('meetings_paypal_transaction')->new({
        user_id        => $user->id,
        domain_id      => $domain_id,
        received_date  => time,
        payment_date   => $transaction{payment_date},
        transaction_id => $transaction{transaction_id},
        notes          => $notes
    })->save;

    $self->_send_transaction_receipt(
        user        => $user,
        transaction => \%transaction,
        domain_id => $domain_id,
    );
}

sub _process_cancellation {
    my ($self) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $subscription_id = CTX->request->param('subscr_id');
    my $custom = CTX->request->param('custom');

    my ($email, $user_id, $subscription_type) = split /,/, $custom;

    get_logger(LOG_APP)->error("Cancel subscription for '$email'");

    my $user = eval { Dicole::Utils::User->ensure_object($user_id) } or do {
        get_logger(LOG_APP)->error("While trying to cancel subscription ID '$subscription_id', user ID '$user_id' was not found");
        return;
    };

    my $subscriptions = CTX->lookup_object('meetings_subscription')->fetch_group({
        where => 'subscription_id = ?',
        value => [ $subscription_id ]
    });

    unless (@$subscriptions) {
        get_logger(LOG_APP)->error("Tried to cancel subscription with ID '$subscription_id', which doesn't exist");
        return;
    }

    get_logger(LOG_APP)->error("User has " . @$subscriptions . " subscriptions");

    my $subscription = $subscriptions->[0];

    my $subscription_date = DateTime->from_epoch(epoch => $subscription->subscription_date);

    get_logger(LOG_APP)->error("Subscription '" . $subscription->id . "' date: $subscription_date");

    my $subscription_end_date = $self->_calculate_subscription_end_date($subscription);

    get_logger(LOG_APP)->error("Subscription '" . $subscription->id . "' ends at $subscription_end_date");

    $self->_set_note(valid_until_timestamp => $subscription_end_date->epoch, $subscription, { skip_save => 1});
    $self->_set_note(cancelled_timestamp   => time,                          $subscription);

    $subscription->save;

    get_logger(LOG_APP)->error("Marked subscription '" . $subscription->id . "' as cancelled");
}

sub _calculate_subscription_end_date {
    my ($self, $subscription) = @_;

    my $transactions = $self->_get_subscription_transactions($subscription);

    my $last_transaction = (sort { $a->payment_date <=> $b->payment_date } @$transactions)[-1];

    return DateTime->from_epoch(epoch => $last_transaction->payment_date)
        + $self->_duration_from_paypal_period($self->_get_note(period => $subscription));
}

# XXX: for testing purposes - should be moved to globals?
sub remove_my_subscriptions {
    my ($self) = @_;

    my $user = CTX->request->auth_user_id && CTX->request->auth_user
        or return { error => 'no user' };

    my $subscriptions = $self->_user_subscriptions($user);

    get_logger(LOG_APP)->error("Removing " . @$subscriptions . " subscriptions for user ID " . $user->id);

    for my $subscription (@$subscriptions) {
        $subscription->remove;
    }

    $self->_calculate_user_is_pro($user);

    return { result => "Removed " . @$subscriptions . " subscriptions" }
}

sub _duration_from_paypal_period {
    my ($self, $period) = @_;

    my ($duration, $unit) = split " ", $period;

    return DateTime::Duration->new(days => { D => 1, M => 31, Y => 365 }->{$unit});
}

sub send_receipt {
    my ($self) = @_;

    my $transaction_id = CTX->request->param('transaction_id')
        or die {
            code => 42,
            message => "transaction_id required"
        };

    my $user = CTX->request->auth_user_id && CTX->request->auth_user
        or die {
            code => 41,
            message => "no user"
        };

    my $transaction = CTX->lookup_object('meetings_paypal_transaction')->fetch($transaction_id)
        or die {
            code => 40,
            message => "No such transaction"
        };

    $self->_send_transaction_receipt(
        user        => $user,
        transaction => $transaction
    );

    return {
        result => "ok"
    }
}

sub valid_promo { shift->_valid_promo }

1;
