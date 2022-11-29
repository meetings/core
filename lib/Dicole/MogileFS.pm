package Dicole::MogileFS;
BEGIN {
  $Dicole::MogileFS::VERSION = '0.01';
}
# ABSTRACT: Access attachments in MogileFS.

use feature qw(switch);

use Moose                   1.08;
use MooseX::Has::Sugar      0.0405;
use MooseX::Types::Moose    0.22    qw(Int Str ArrayRef);
use IO::All                 0.39;
use MogileFS::Client        1.11;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

has client => ro, lazy_build;

has domain => (
    isa     => Str, ro,
    required => 1,
);

has servers => (
    isa     => ArrayRef[Str], ro,
    default => sub { CTX->server_config->{dicole}->{mogilefs_server} },
    lazy => 1,
);

has class => (
    isa     => Str, ro,
    required => 1,
);

has log => (
    rw,
    default => sub { Log::Log4perl->get_logger(__PACKAGE__) }
);

sub store_file {
    my ($self, $key, $filename) = @_;

    $self->log->debug("Store file '$key' => '$filename'");

    return $self->store_fh($key, io($filename));
}

sub store_fh {
    my ($self, $key, $infh) = @_;

    # MogileFS::Client has a utility function C<store_file> that does
    # essentially the same thing as the following code, but it fails without a
    # clear error message for me.

    $self->log->debug("Store fh '$key'");

    return $self->_write_file(
        key   => $key,
        class => $self->class,
        fh    => $infh
    );
}

sub _write_file {
    my ($self, %params) = @_;

    my $infh  = $params{fh}    or die "Required param 'fh' missing.";
    my $class = $params{class} or die "Required param 'class' missing.";
    my $key   = $params{key}   or die "Required param 'key' missing.";

    my $outfh = $self->client->new_file($key, $class)
        or die "Failed to create new mogile file for '$key', class '$class': " .
            $self->client->errstr;

    my $bytes = 0;

    #my $chunk;

    while (my $len = $infh->read(my $chunk, 8192)) { # eval { $infh->read($chunk, 8192) }) {
        #if ($@ and $@ =~ /closed/) {
        #    # TODO Test this works
        #    $self->client->reload(
        #        domain => $self->domain, 
        #        hosts => $self->servers
        #    );

        #    return $self->_write_file(%params);
        #}

        $outfh->print($chunk);
        $bytes += $len;
    }

    $self->log->warn("Wrote a 0 byte file with key '$key'")
        unless $bytes;

    $outfh->close or die "Unable to close Mogile handle: $!";

    $self->log->debug("Stored $key");

    return $bytes;
}

sub _key {
    my ($self, $filename) = @_;

    $filename
}

sub get_urls {
    my ($self, $key, $recursion) = @_;

    $recursion = 0 unless defined $recursion;

    $self->log->debug("Get urls '$key'");

    my @urls = eval { $self->client->get_paths($key) };

    $self->log->debug("Got urls: @urls") if @urls;

    return @urls if @urls;

    unless ($@) {
        $self->log->error("Not found: '$key'");
        return;
    }

    $self->log->error("Error: $@");

    if ($recursion > 5) {
        $self->log->error("get_paths failed too many times, bailing out.");
        return;
    }

    $self->log->error("Trying to recover...");

    $self->client->reload(
        domain => $self->domain,
        hosts => $self->servers
    );

    return $self->get_urls($key, $recursion + 1);
}

sub _build_client {
    my $self = shift;

    $self->log->debug(
        "Connecting MogileFS client to domain '" . $self->domain .
                                     "', hosts " . join(", ", @{$self->servers})
    );

    MogileFS::Client->new(
        domain  => $self->domain,
        hosts   => $self->servers,
        timeout => 5
    )
}

1;

__END__
=pod

=head1 NAME

Dicole::MogileFS - Access attachments in MogileFS.

=head1 VERSION

version 0.01

=head1 AUTHOR

  Ilmari Vacklin <ilmari.vacklin@cs.helsinki.fi>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Dicole Ltd

All rights reserved.

=cut

