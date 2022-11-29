package Dicole::Response;

# $Id: Response.pm,v 1.2 2009-01-07 14:42:32 amv Exp $

use strict;
use base qw( OpenInteract2::Response );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use List::Util qw(sum);
use Time::HiRes qw/time/;
use Dicole::Utils::User;
use Dicole::Utils::Trace;
use Sys::Hostname;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/ );

our $IN_TRACE = 0;

my ( $log );

# Register our own apache handler

OpenInteract2::Response->register_factory_type(
      dicole_apache => 'Dicole::Response::Apache2'
);

__PACKAGE__->mk_accessors(qw/traces current_trace/);

sub initialize_trace {
    my ($self) = @_;

    $self->traces({
        id => 'root',
        start => scalar time,
        children => [],
        hostname => hostname
    });

    $self->current_trace($self->traces);
}

sub start_trace {
    my ($self, $id) = @_;

    return if $IN_TRACE;

    {
        local $IN_TRACE = 1;

        return unless $id and ( Dicole::Utils::User->is_developer || CTX->server_config->{dicole}{development_mode} );
    }

    my $current_trace = $self->current_trace;

    my $trace = { id => $id, start => scalar time, parent => $current_trace, children => [] };

    push @{ $current_trace->{children} }, $trace;

    $self->current_trace($trace);

    return $trace;
}

sub end_trace {
    my ($self, $trace) = @_;

    return if $IN_TRACE;

    {
        local $IN_TRACE = 1;

        return unless $trace and ( Dicole::Utils::User->is_developer || CTX->server_config->{dicole}{development_mode} );
    }

    if ($trace->{end}) {
        get_logger(LOG_APP)->error("Trace $trace->{id} already ended");
        return
    }

    $trace->{end} = time;
    $trace->{total} = $trace->{end} - $trace->{start};
    $trace->{children} = [ sort { $b->{total} <=> $a->{total} } @{ $trace->{children} || [] } ];
    $trace->{exclusive} = $trace->{total} - sum(map { $_->{total} } @{ $trace->{children} });

    if ($trace->{parent}) {
        $self->current_trace($trace->{parent});
        delete $trace->{parent};
    }
}

sub get_trace {
    my ($self) = @_;

    return if $IN_TRACE;

    {
        local $IN_TRACE = 1;

        return {} unless Dicole::Utils::User->is_developer || CTX->server_config->{dicole}{development_mode};
    }

    $self->end_trace($self->current_trace);

    #while (1) {
        #my $current = $self->current_trace;
        #my $parent = $current->{parent};

        #$self->end_trace($current);

        #$current = $parent or last;
    #}

    return $self->traces;
}

1;
