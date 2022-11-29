package Dicole::Controller::IframeJSON;

# $Id: IframeJSON.pm,v 1.1 2009-05-18 02:03:45 amv Exp $

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use Dicole::Utils::JSON;

sub init {
    my ( $self ) = @_;

    Dicole::Security->init;
}

sub execute {
    my ( $self ) = @_;

    my $action = $self->initial_action;
    my $output = {};
    my $content = eval { $action->execute } || {};
    if ( my $error = $@ ) {
        get_logger( LOG_REQUEST )->error( $error . ' -- ' . $self->common_action_error_logstring( $error ) );
        $output = Dicole::Utils::JSON->encode( { error => $error . '' } );
    }
    else {
        $output = Dicole::Utils::JSON->encode( $content );
    }

    $self->clean_used_htmltrees;

#    $output =~ s/$_/\\$_/gs for ( '\\\\', '"' );
#    $output =~ s/\n/\\n/gs;

    $output = '<html><body><textarea>' . Dicole::Utils::HTML->encode_entities($output) . '</textarea></body></html>';

    CTX->response->content_type( 'text/html' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $output ) );
    CTX->response->content( \$output );
}

1;
