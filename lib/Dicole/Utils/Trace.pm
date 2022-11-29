package Dicole::Utils::Trace;

use strict;
use warnings;

use OpenInteract2::Context   qw( CTX );

sub initialize_trace {
    my ($class) = @_;

    CTX->response->initialize_trace if CTX->response;
}

sub start_trace {
    my ($class, $trace) = @_;

    CTX->response->start_trace($trace) if CTX->response;
}

sub end_trace {
    my ($class, $trace) = @_;

    CTX->response->end_trace($trace) if CTX->response and $trace;
}

sub get_trace {
    my ($class) = @_;

    CTX->response->get_trace if CTX->response;
}

1;
