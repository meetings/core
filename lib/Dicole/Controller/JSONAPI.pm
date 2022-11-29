package Dicole::Controller::JSONAPI;

# $Id: JSONAPI.pm,v 1.4 2009-11-20 04:17:37 amv Exp $

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use JSON;

my $log;

sub init {
    my ( $self ) = @_;

    Dicole::Security->init;
}

sub execute {
    my ( $self ) = @_;

    my $params = eval { Dicole::Utils::JSON->decode( CTX->request->param('params') || '{}' ) };

#     get_logger(LOG_APP)->error( CTX->request->param('params') );
#     get_logger(LOG_APP)->error( Data::Dumper::Dumper( $params ) );

    return $self->_send_error( "Malformed request when parsing the JSON of the params -parameter: $@" ) if $@;

    my $action = $self->initial_action;

    for my $key ( keys %$params ) {
        $action->param($key , $params->{ $key } );
    }

    my $content = eval { $action->execute; };

    if ( $@ ) {
        return $self->_send_error( "Error: $@" );
    }

    $self->clean_used_htmltrees;

    return $self->_send_response( $content );
}

sub _send_error {
    my ( $self, $content ) = @_;

    $log ||= get_logger(LOG_ACTION);

    my $info = 'url_absolute was: [' .
        CTX->request->url_absolute . ']. ';

    if ( my $user = CTX->request->auth_user ) {
        $info .= 'Requesting user was: ';
        $info .= $user->first_name . ' ' . $user->last_name;
        $info .= '(' . $user->id . ')';
    }
    else {
        $info .= 'User was not logged in.';
    }

    if ( $content !~ /security error/ ) {
        $log->is_error && $log->error('Sent error for JSONAPI call: ' .
            $content . ' -- '  . $info );
    }
    else {
        $log->is_info && $log->info('Sent error for JSONAPI call: ' .
            $content . ' -- '  . $info );
    }

    $self->_send( Dicole::Utils::JSON->encode( {
        error => { message => $content, code => 1 }
    } ) );
}

sub _send_response {
    my ( $self, $content ) = @_;

    unless ( ref( $content ) eq 'HASH' && ( exists $content->{result} || exists $content->{error} )) {
        $content = { result => $content };
    }

    my $jsonstring = eval { Dicole::Utils::JSON->encode( $content ) };
    if ( $@ ) {
        $self->_send_error( $@ );
    }
    else  {
        $self->_send( $jsonstring );
    }
}

sub _send {
    my ( $self, $json ) = @_;

    CTX->response->content_type( 'text/json' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $json ) );
    CTX->response->content( \$json );
}

1;
