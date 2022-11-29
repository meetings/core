package Dicole::Controller::JSONRPC;

# $Id: JSONRPC.pm,v 1.7 2008-08-25 00:34:11 amv Exp $

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

    my $js = eval {
        JSON->new->jsonToObj( CTX->request->post_body );
    };

    return $self->_send_error( "Malformed request: $@" ) if $@;

    my $method = $js->{method} || '';
    my $params = $js->{params} || [];
    my $id = $js->{id};

    return $self->_send_error( "Malformed request: No ID") if !$id;

    my $action = $self->initial_action;

    $action->task($method);
    $action->param('params', $params );

    # If the first param is a hash, map keys of this hash
    # as action params.
    if ( ref $params eq 'ARRAY' && ref($params->[0]) eq 'HASH' ) {
        for my $key ( keys %{$params->[0]} ) {
            next if ref $key;
            $action->param( $key, $params->[0]->{$key} );
        }
    }

    my $content = eval { $action->execute; };

    if ( $@ ) {
        return $self->_send_error( "Error: $@" , $id, $method, $params);
    }

    $self->clean_used_htmltrees;

    return $self->_send_response( $content, $id );
}

sub _send_error {
    my ( $self, $content, $id, $method ) = @_;
    $id ||=0;

    $log ||= get_logger(LOG_ACTION);

    my $info = 'url_absolute was: [' .
        CTX->request->url_absolute . ']. ';
    my $info .= "method was: [ $method ]. ";

    if ( my $user = CTX->request->auth_user ) {
        $info .= 'Requesting user was: ';
        $info .= $user->first_name . ' ' . $user->last_name;
        $info .= '(' . $user->id . ')';
    }
    else {
        $info .= 'User was not logged in.';
    }

    if ( $id && $content !~ /security error/ ) {
        $log->is_error && $log->error('Sent error for JSON-RPC call: ' .
            $content . ' -- '  . $info );
    }
    else {
        $log->is_info && $log->info('Sent error for JSON-RPC call: ' .
            $content . ' -- '  . $info );
    }

    $self->_send( JSON->new->objToJson( {
        result => undef,
        error => $content,
        id => $id,
    }));
}

sub _send_response {
    my ( $self, $content, $id ) = @_;
    $id ||=0;

    $self->_send( JSON->new->objToJson( {
        result => $content,
        error => undef,
        id => $id,
    }));
}

sub _send {
    my ( $self, $json ) = @_;

    CTX->response->content_type( 'text/json' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $json ) );
    CTX->response->content( \$json );
}

1;
