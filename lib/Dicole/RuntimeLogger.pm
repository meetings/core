package Dicole::RuntimeLogger;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use Time::HiRes;

my $timestamp_cache = {};
my @stack = ();
my %open = ();

my $logger = get_logger( 'OI2.RUNTIME' );

sub rlog_flush {
    ( $self, $name ) = @_;
    $self->flush_timestamps;
}
sub rlog_open {
    my ( $self, $name ) = @_;
}

sub rlog_close {
    my ( $self, $name ) = @_;
}

sub rlog_begin {
    my ( $self, $name ) = @_;

    next unless $name;
    next if $open{ $name };
    $open{ $name } = 1;
    push @stack, $name;
    $self->start_timestamp( $name );
}

sub rlog_end {
    my ( $self, $name ) = @_;

    unless ( $open{ $name } ) {
        $logger->error( $name );
        return;
    };

    while( @stack ) {
        my $last = pop @stack;
        $self->stop_timestamp( $last );
        $open{ $last } = 0;
        last if $name eq $last;
    }
}

sub rlog {
    my ( $self, $name ) = @_;

    if ( ! $name ) {
        $self->rlog_end( $stack[-1] );
        return;
    }

    if ( $open{ $name } ) {
        $self->rlog_end( $name );
    }
    else {
        $self->rlog_begin( $name );
    }
}

sub is_rlog { return $logger->is_debug;}

sub start_timestamp {
    my ( $class, $id ) = @_;
    $logger->debug( "Starting $id" );
    my $now = [ Time::HiRes::gettimeofday ];
    $timestamp_cache->{started}->{ $id } = $now;
    $timestamp_cache->{level}++;
}

sub specify_timestamp {
    my ( $class, $id, $data ) = @_;
    return unless CTX && CTX->request;
    $logger->debug( "Specifying $id : $data" );
    if ( $timestamp_cache->{started}->{ $id } ) {
        $timestamp_cache->{specified}->{ $id } = $data;
    }
}

sub stop_timestamp {
    my ( $class, $id ) = @_;

    $logger->debug( "Stopping $id" );
    if ( my $start = $timestamp_cache->{started}->{ $id } ) {
        delete $timestamp_cache->{started}->{ $id };
        my $now = [ Time::HiRes::gettimeofday ];
        my $duration = Time::HiRes::tv_interval( $start, $now );
        my $spec = $id;
        if ( my $data = $timestamp_cache->{specified}->{ $id } ) {
            delete $timestamp_cache->{specified}->{ $id };
            $data =~ s/\n/ /g;
            $data =~ s/ +/ /g;
            $spec .= ' ( ' . $data . ' )';
        }

        $timestamp_cache->{stopped} ||= [];

        push @{ $timestamp_cache->{stopped} }, [
            $timestamp_cache->{level},
            $duration,
            $spec
        ];
        $logger->info( "$duration : $spec" );

        $timestamp_cache->{level}--;
    }
}

sub flush_timestamps {
    my ( $class, $return_log ) = @_;

    my $stopped = $timestamp_cache->{stopped};

    $timestamp_cache = {};
    @stack = ();
    %open = ();

    return '' unless $return_log && ref( $stopped ) eq 'ARRAY';
    my @rows = ();
    for my $row ( @$stopped ) {
        my $level = $row->[0];
        $level = 0 unless $level =~ /^\d+$/;
#        next if $row->[1] < 0.5;
        push @rows, ('    ' x $level) . $row->[1] . ' : ' . $row->[2];
    }
    return scalar( @rows ) ? join( "\n", @rows ) . "\n" : '';
}

1;