package OpenInteract2::Action::DicoleEmailsAPI;

use strict;
use warnings;

use base qw( OpenInteract2::Action::DicoleEmailsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# By convention use user_id or 0 the first parameter

sub get_validated_email {
    my ( $self ) = @_;

    my $short_action = $self->_rdispatch( $self->param('action') );
    die unless $short_action;

    my $params = $self->param('params');
    my $user = $self->param('user');
    my $domain_id = $self->param('domain_id');

    my $hash = $self->_get_user_hash( $short_action, $params, $user );

    # TODO: configure email gateway by domain.
    my $dn = CTX->server_config->{dicole}{default_email_gateway};
    return join("-", $short_action, @$params, $hash) . '@' . $dn;
}

sub get_shortened_email {
    my ( $self ) = @_;

    my $action = $self->param('action');
    my $params = $self->param('params');
    my $domain_id = $self->param('domain_id');

    my $local = $self->_store_shortened_params( $action, $params );

    # TODO: configure email gateway by domain_id

    my $dn = CTX->server_config->{dicole}{default_email_gateway};
    return $local ? "$local\@$dn" : ();
}

1;
