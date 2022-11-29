package Dicole::Controller::JSON;

# $Id: JSON.pm,v 1.7 2010-05-06 16:30:22 amv Exp $

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );
use Time::HiRes              qw( time );
use Dicole::Utils::JSON;
use Dicole::Utils::Trace;
use Digest::SHA;
use Storable qw();

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
        get_logger( LOG_REQUEST )->error("$@");
        get_logger( LOG_REQUEST )->error( $error . ' -- ' . $self->common_action_error_logstring( $error ) );

        $content = { error => (
           (ref $error eq 'HASH' and exists $error->{code}) ? $error : "$error"
        ) };
    }

    if ( ref ($content) eq 'HASH' && defined $content->{result} ) {
        local $Storable::canonical = 1;
        $content->{result_hash} = Digest::SHA::sha1_base64( Storable::freeze( [ $content->{result} ] ) );
    }

    if ( ref ($content) eq 'HASH' && Dicole::Utils::User->is_developer ) {
        $content->{_trace} = Dicole::Utils::Trace->get_trace;
    }

    $output = Dicole::Utils::JSON->encode( $content );

    $self->clean_used_htmltrees;

    CTX->response->content_type( 'application/json' );
    CTX->response->charset( 'utf-8' );
    CTX->response->header( 'Content-Length', length( $output ) );
    CTX->response->content( \$output );
}

1;
