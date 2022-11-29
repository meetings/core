package Dicole::Controller::JSWrite;

# $Id: JSWrite.pm,v 1.3 2008-08-25 00:34:11 amv Exp $

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

sub init {
    my ( $self ) = @_;

    Dicole::Security->init;
}

sub execute {
    my ( $self ) = @_;

    my $action = $self->initial_action;
    my $content = eval { $action->execute; };
    $content =~ s/$_/\\$_/gs for ( '\\\\', '"' );
    $content =~ s/\n/\\n/gs;

    my $output = 'document.write("' . $content . '");';

    $self->clean_used_htmltrees;

    CTX->response->content_type( 'text/javascript' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $output ) );
    CTX->response->content( \$output );
}

1;
