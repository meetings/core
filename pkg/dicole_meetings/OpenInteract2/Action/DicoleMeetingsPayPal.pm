package OpenInteract2::Action::DicoleMeetingsPayPal;

use 5.010;
use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsPayPalCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Business::PayPal::NVP;
use DateTime;

sub start_basic_purchase {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    die "You must be logged in" unless CTX->request->auth_user_id && CTX->request->auth_user->email;

    my $subscription_type = 'BASICOFFER';
    my $host = $self->_get_host_for_user( $user, 443 );

    my $return_url = $host . $self->derive_url(
        action => 'meetings_paypal',
        task   => 'complete_basic',
        params => {
            email   => $user->email,
            user_id => $user->id,
            type    => $subscription_type,
        },
        do_not_escape => 1
    );

    my $promo = $self->_fetch_promotion_for_code( $subscription_type, $domain_id );

    $self->_set_note_for_user(started_paypal_flow_time => time, $user, $domain_id);

    my $encrypted_form = $self->_encrypt_paypal_button(
        $self->_build_form(
            promo             => $promo,
            email             => $user->email,
            user_id           => $user->id,
            subscription_type => $subscription_type,
            return_url        => $return_url,
            host              => $host
        )
    );

    my $redirect_url = URI::URL->new( CTX->server_config->{dicole}{paypal_gateway_url} );
    $redirect_url->query_form( { cmd => "_s-xclick", encrypted => $encrypted_form } );

    return $self->redirect( $redirect_url->as_string );
}

sub complete_basic {
    my ($self) = @_;
    return $self->_complete( 'thanks_basic');
}

sub complete {
    my ($self) = @_;
    return $self->_complete( 'thanks');
}

sub _complete {
    my ($self, $task ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $email = CTX->request->param('email');

    my $user = CTX->request->auth_user_id && CTX->request->auth_user || $self->_fetch_user_for_email(CTX->request->param('email'))
        or die "No such user";

    $self->_set_note_for_user(paypal_pending_subscription_timestamp => time, $user);

    $self->_send_account_upgraded_mail_to_user(
        user => $user,
        domain_id => $domain_id,
    );

    $self->_calculate_user_is_pro($user, $domain_id);

    return $self->redirect($self->derive_url(task => $task ));
}

sub error {
    my ($self) = @_;

    return $self->generate_content({}, { name => 'dicole_meetings::main_meetings_paypal_error' });
}

sub thanks_basic {
    my ($self) = @_;

    $self->_set_controller_variables({}, 'Thank you');

    return $self->generate_content( {}, { name => 'dicole_meetings::main_meetings_paypal_thanks_basic' } );
}

sub thanks {
    my ($self) = @_;

    $self->_set_controller_variables({}, 'Thank you');

    return $self->generate_content( {
        is_logged_in => CTX->request->auth_user_id
    }, { name => 'dicole_meetings::main_meetings_paypal_thanks' } );
}

sub thanks_free {
    my ($self) = @_;

    $self->_set_controller_variables({}, 'Thank you');

    return $self->generate_content( {
        free_trial => 1,
        is_logged_in => CTX->request->auth_user_id
    }, { name => 'dicole_meetings::main_meetings_paypal_thanks' } );
}


sub cancel {
    my ($self) = @_;

    return $self->redirect($self->derive_url(action => 'meetings', task => 'summary'));

    $self->_set_controller_variables({}, 'Cancelled');

    return $self->generate_content( {}, { name => 'dicole_meetings::main_meetings_paypal_cancel' } );
}

1;
