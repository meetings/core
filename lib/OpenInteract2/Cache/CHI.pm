package OpenInteract2::Cache::CHI;

use warnings;
use strict;
use CHI;
use CHI::Driver::Memcached::libmemcached;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use base 'OpenInteract2::Cache';

my $namespace      = 'dicole';
my $debug          = 0;
my $default_expire = '1 day';

sub initialize { 
    my ($self, $conf) = @_;

    use Data::Dumper qw/Dumper/;

    defined $conf->{$_} or die "Parameter '$_' required: ".Dumper($conf) for qw(servers driver);

    CHI->new(
        servers    => $conf->{servers},
        driver     => $conf->{driver},
        namespace  => $conf->{namespace}      || $namespace,
        debug      => $conf->{debug}          || $debug,
        expires_in => $conf->{default_expire} || $default_expire
    )
}

sub get_data {
    my ($self, $cache, $key) = @_;

    get_logger(LOG_CACHE)->error("Get key '$key'");

	my $value = $cache->get($key);

	get_logger(LOG_ERROR)->error("");

    return 
}

sub set_data {
    my ($self, $cache, $key, $data, $expires) = @_;

    get_logger(LOG_CACHE)->error("Set key '$key' to expire in '$expires'");

    $cache->set($key, $data, $expires);
}

sub clear_data {
    my ($self, $cache, $key) = @_;

    get_logger(LOG_CACHE)->error("Remove key '$key'");

    return $cache->remove($key);
}

sub purge_all {
    my ($self, $cache) = @_;

    return;
}

1;
