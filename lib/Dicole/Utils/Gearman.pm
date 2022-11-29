package Dicole::Utils::Gearman;

use 5.010;

use strict;
use warnings;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::Utils::JSON;
use Gearman::Worker;
use Gearman::Client;
use Sys::SigAction;

my $singletons = {};
my $counters = {};

sub _bg_client { return _round_robin_singleton( 'Gearman::Client', 'bg_gearman' ); }
sub _fg_client { return _round_robin_singleton( 'Gearman::Client', 'fg_gearman' ); }
sub _bg_worker { return _singleton( 'Gearman::Worker', 'bg_gearman' ); }
sub _fg_worker { return _singleton( 'Gearman::Worker', 'fg_gearman' ); }
sub _ag_worker { return _singleton( 'Gearman::Worker', 'ag_gearman' ); }

sub _singleton {
    my ( $class, $type ) = @_;

    return $singletons->{ $class . $type } //= _new_object( $class, scalar( CTX->server_config->{dicole}->{$type} ) );
}

sub _round_robin_singleton {
    my ( $class, $type ) = @_;

    $counters->{ $class } ||= 0;
    $counters->{ $class } = ( $counters->{ $class } + 1 ) % 30030; # 2*3*5*7*11*13 - divisible until 16

    $singletons->{ $class . $type } //= [ map { _new_object( $class, [ $_ ] ) } @{ CTX->server_config->{dicole}->{$type} } ];

    return $singletons->{ $class . $type }[ int( $counters->{ $class } % ( scalar( @{ $singletons->{ $class . $type } } ) ) ) ];
}

sub _new_object {
    my ( $class, $servers ) = @_;

    return $class->new(
        job_servers => $servers,
    );
}

sub register_fg_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    $subref = $self->_return_subref_with_timeout( $subref, $timeout, $funcname );
    return $self->_fg_worker->register_function( $funcname, $timeout, $subref );
}

sub register_versioned_fg_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    my $v = CTX->server_config->{dicole}->{static_file_version};

    return $self->register_fg_function( "v$v-$funcname", $timeout, $subref );
}

sub register_bg_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    $subref = $self->_return_subref_with_timeout( $subref, $timeout, $funcname );
    return $self->_bg_worker->register_function( $funcname, $timeout, $subref );
}

sub register_versioned_bg_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    my $v = CTX->server_config->{dicole}->{static_file_version};

    return $self->register_bg_function( "v$v-$funcname", $timeout, $subref );
}

sub register_ag_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    $subref = $self->_return_subref_with_timeout( $subref, $timeout, $funcname );
    return $self->_ag_worker->register_function( $funcname, $timeout, $subref );
}

sub register_versioned_ag_function {
    my ( $self, $funcname, $timeout, $subref ) = @_;

    my $v = CTX->server_config->{dicole}->{static_file_version};

    return $self->register_ag_function( "v$v-$funcname", $timeout, $subref );
}

sub work_fg {
    my ( $self, %opts ) = @_;

    return $self->_fg_worker->work( %opts );
}

sub work_bg {
    my ( $self, %opts ) = @_;

    return $self->_bg_worker->work( %opts );
}

sub work_ag {
    my ( $self, %opts ) = @_;

    return $self->_ag_worker->work( %opts );
}

sub do_task {
    my ( $self, $funcname, $argstring, %opts ) = @_;

    $argstring = $self->_ensure_proper_json_hash_string( $argstring );
    for ( my $i = 0; $i < scalar( @{ CTX->server_config->{dicole}->{fg_gearman} } ) * 2; $i++ ) {
         my $reply = $self->_fg_client->do_task( $funcname, $argstring, %opts );
         next unless defined $reply;
         if ( $$reply && $$reply =~ /^[\{\[]/ ) {
             return Dicole::Utils::JSON->decode( $$reply );
         }
         return $$reply;
    }

    die "could not do task on any of the job servers -- $funcname, $argstring";
}

sub do_delayed_task {
    my ( $self, $funcname, $args, $delay_seconds, %opts ) = @_;

    $args = $self->_ensure_proper_json_hash_string( $args );
    my $sloth_json = Dicole::Utils::JSON->encode( {
        after => $delay_seconds || 0,
        func_name => $funcname,
        payload => $args,
    } );

    return $self->do_task( submitJobDelayed => $sloth_json, %opts );
}

sub dispatch_versioned_task {
    my ( $self, $funcname, $argstring, %opts ) = @_;

    my $v = CTX->server_config->{dicole}->{static_file_version};

    return $self->dispatch_task( "v$v-$funcname", $argstring, %opts );
}

sub dispatch_task {
    my ( $self, $funcname, $argstring, %opts ) = @_;

    $argstring = $self->_ensure_proper_json_hash_string( $argstring );

    for ( my $i = 0; $i < scalar( @{ CTX->server_config->{dicole}->{bg_gearman} } ) * 2; $i++ ) {
        my $handle = $self->_bg_client->dispatch_background( $funcname, $argstring, %opts );
        return $handle if $handle;
    }

    die "could not dispatch task to any of the job servers -- $funcname, $argstring";
}


sub _ensure_proper_json_hash_string {
    my ( $self, $datastring ) = @_;

    my $data = $self->_ensure_proper_hash( $datastring );

    return Dicole::Utils::JSON->encode( $data );
}

sub _ensure_proper_hash {
    my ( $self, $datastring ) = @_;

    my $data = ( ref( $datastring ) eq 'HASH' ) ? $datastring : eval { Dicole::Utils::JSON->decode( $datastring ) } || {};

    if ( ! defined $data->{domain_id} && CTX && CTX->controller && CTX->controller->initial_action ) {
        $data->{domain_id} = Dicole::Utils::Domain->guess_current_id;
    }

    return $data;
}

sub _return_subref_with_timeout {
    my ( $self, $subref, $timeout, $debug_name ) = @_;

    $timeout ||= 60;
    return sub {
        my @params = @_;
        my $return = undef;
        my $sub = sub {
            $return = eval { $subref->( @params ) };
            if ( my $err = $@ ) {
                get_logger(LOG_APP)->error( $debug_name . ' -> ' . $err );
                $return = { error => { message => 'unexpected error' } };
            }
        };
        if ( Sys::SigAction::timeout_call( $timeout, $sub ) ) {
            return Dicole::Utils::JSON->encode( { error => { message => 'timeout' } } );
        }
        else {
            return $return;
        }
    };
}

1;
