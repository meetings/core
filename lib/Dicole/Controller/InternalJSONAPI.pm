package Dicole::Controller::InternalJSONAPI;

use strict;
use base qw( Dicole::Controller::JSONAPI );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

sub init {}

sub execute {
    my ( $self, @args ) = @_;

    my $secret = CTX->server_config->{dicole}{internal_api_secret};

    die "No internal api secret specified. Set internal_api_secret at server.ini under [dicole]" unless $secret;

    die "Invalid secret" unless CTX->request->param('secret') eq $secret;

    $self->SUPER::execute( @args );
}

1;
