package Dicole::Controller::JSONP;

# $Id: JSON.pm,v 1.7 2010-05-06 16:30:22 amv Exp $

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use Dicole::Utils::JSON;

sub init {
    my ( $self ) = @_;

    $self->common_set_language;

    $self->SUPER::init;
}

sub execute {
    my ( $self ) = @_;

    my $action = $self->initial_action;
    my $output = {};
    my $content = eval { $action->execute } || {};
    my $error = $@;

    if ( $error ) {
        get_logger( LOG_REQUEST )->error( $error . ' -- ' . $self->common_action_error_logstring( $error ) );
        $output = Dicole::Utils::JSON->encode({
            error => (
                (ref $error eq 'HASH' and exists $error->{code})
                    ? $error
                    : "$error"
            )

        });
    }
    else {
        $output = Dicole::Utils::JSON->encode( $content );
    }

    $self->clean_used_htmltrees;

    my $callback = CTX->request->param('callback') || CTX->request->param('jsonp_callback') || CTX->request->param('jsonp');
    $output = $callback.'('. $output .');';

    CTX->response->content_type( 'text/javascript' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $output ) );
    CTX->response->content( \$output );
}

1;
