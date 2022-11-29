package Dicole::Cache;

use 5.010;

use strict;
use warnings;

use Cache::Memcached;
use Time::HiRes qw(sleep);
use Data::UUID ();
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Utils::JSON;

our $DEFAULT_TIMEOUT      = 10;  # seconds
our $SLEEP_PERIOD = 0.1; # seconds

#close STDERR;
#open STDERR, '>', '/usr/local/dicole/logs/stderr.log' or die $!;

my $nonrequest_cache = {};
sub in_request_fetch_or_store {
    my ( $self, $key, $lazy_value ) = @_;

    my $cache_variable = CTX->request ? CTX->request->request_cache : $nonrequest_cache;
    return $cache_variable->{ $key } if defined $cache_variable->{ $key };
    return $cache_variable->{ $key } = $lazy_value->();
}


my $cache;

sub _cache { 
    $cache //= Cache::Memcached->new({
        servers => CTX->server_config->{dicole}->{memcached_server},
        compress_threshold => 10_000,
    })
}

my $uuid_gen = Data::UUID->new;

sub _uuid_gen { $uuid_gen }

sub fetch_or_store {
    my ($self, $key, $lazy_value, $params) = @_;

    $params //= {};

    if ( $params->{skip_cache} ) {
        my $rlog_name = 'Cache skip generate: ' . $key;
        my $trace = Dicole::Utils::Trace->start_trace($rlog_name);
        my $return = eval { $lazy_value->() };
        Dicole::Utils::Trace->end_trace($trace);
        return $return;
    }

    get_logger(LOG_APP)->debug("fetch_or_store '$key'"); 

    my $actual_key = $self->_generate_actual_key($key, $params);

    my $fetched = $self->_fetch_value_after_current_lock_is_released($actual_key);

    get_logger(LOG_APP)->debug(defined $fetched ? "got '$fetched' from fetch" : "fetch did not return a value");

    return $fetched
        // $self->_store_value_or_wait_until_current_lock_is_released($actual_key, $lazy_value, $params);
}

sub fetch {
    my ($self, $key, $params) = @_;

    $params //= {};
    return if $params->{skip_cache};

    get_logger(LOG_APP)->debug("fetch '$key'"); 

    return Dicole::Utils::JSON->decode($self->_cache->get($self->_generate_actual_key($key, $params))||'[]')->[0];
}

sub remove {
    my ( $self, $key, $params ) = @_;

    $params //= {};
    return if $params->{skip_cache};

    return $self->_cache->delete($self->_generate_actual_key($key, $params));
}

sub update {
    my ($self, $user_key, $lazy_value, $params) = @_;

    $params //= {};
    if ( $params->{skip_cache} ) {
        my $rlog_name = 'Cache skip generate: ' . $user_key;
        my $trace = Dicole::Utils::Trace->start_trace($rlog_name);
        my $return = eval { $lazy_value->() };
        Dicole::Utils::Trace->end_trace($trace);
        return $return;
    }

#    $self->remove( $user_key, $params );

    get_logger(LOG_APP)->debug("update '$user_key'"); 

    my $key = $self->_generate_actual_key($user_key, $params);

    my $owner = $self->_fetch_current_lock_owner($key);

    if ($owner) {
        while (1) {
            sleep $SLEEP_PERIOD;

            my $new_owner = $self->_fetch_current_lock_owner($key)
                // last;

            return $self->_fetch_value_after_current_lock_is_released($key, $new_owner) 
                if $new_owner ne $owner;
        }
    }

    return $self->_store_value_or_wait_until_current_lock_is_released($key, $lazy_value, $params);
}

sub _fetch_current_lock_owner {
    my ($self, $key) = @_;

    return $self->_cache->get("lock:$key");
}

sub _generate_actual_key {
    my ($self, $user_key, $params) = @_;

    my $domain_id = $params->{no_domain_id} ? '' : $params->{domain_id}
        || CTX->controller->initial_action->param('domain_id');

    my $group_id  = $params->{no_group_id}  ? '' : $params->{group_id}
        || CTX->controller->initial_action->param('target_group_id');

    return CTX->server_config->{dicole}{static_file_version} . "-$domain_id-$group_id-$user_key";
}

sub _store_value_or_wait_until_current_lock_is_released {
    my ($self, $key, $lazy_value, $params) = @_;
    $params //= {};

    get_logger(LOG_APP)->debug("_store_value_or... '$key'");

    my $rlog_name = 'Cache lock: ' . $key;
    my $trace = Dicole::Utils::Trace->start_trace($rlog_name);

    if ($self->_lock($key, $params->{lock_timeout} )) {
        Dicole::Utils::Trace->end_trace($trace);
        get_logger(LOG_APP)->debug("got lock");
        my $old_value = Dicole::Utils::JSON->decode($self->_cache->get($key) // '[]')->[0];

        my $rlog2_name = 'Cache generate: ' . $key;
        my $trace2 = Dicole::Utils::Trace->start_trace($rlog2_name);

        my $value = Dicole::Utils::JSON->encode([ eval { $lazy_value->($old_value // ()) } ]);

        Dicole::Utils::Trace->end_trace($trace2);

        my $success = $self->_cache->set($key, $value, $params->{expires});
        $self->_unlock($key);
        get_logger(LOG_APP)->debug( $success ? "set '$key'" : "failed to set '$key'");
#        return $value;
    }
    else {
        Dicole::Utils::Trace->end_trace($trace);
        get_logger(LOG_APP)->debug("didn't get lock");
    }

    return $self->_fetch_value_after_current_lock_is_released($key) // eval { $lazy_value->() };
}

sub _fetch_value_after_current_lock_is_released {
    my ($self, $key, $wait_for) = @_;

    get_logger(LOG_APP)->debug("_fetch_value... '$key' '" . ($wait_for // '<none>') . "'");

    my $rlog_name = 'Cache wait: ' . $key;
    my $trace = Dicole::Utils::Trace->start_trace($rlog_name);

    $wait_for //= $self->_fetch_current_lock_owner($key);

    my $current_owner = $self->_fetch_current_lock_owner($key);

    while (defined $wait_for and defined $current_owner and $current_owner eq $wait_for) {
        sleep $SLEEP_PERIOD;
        $current_owner = $self->_fetch_current_lock_owner($key); 
    }

    Dicole::Utils::Trace->end_trace($trace);

    return Dicole::Utils::JSON->decode($self->_cache->get($key)||'[]')->[0];
}

sub _is_locked {
    my ($self, $key) = @_;

    return defined $self->_fetch_current_lock_owner($key)
}

sub _lock {
    my ($self, $key, $timeout ) = @_;

    $timeout ||= $DEFAULT_TIMEOUT;

    my $uid = $self->_generate_uid();

    $self->_cache->add("lock:$key" => $uid, $timeout );

    my $owner = $self->_cache->get("lock:$key") // "<undef>";

    get_logger(LOG_APP)->debug("owner now '$owner'");

    return $owner eq $uid;
}

sub _generate_uid {
    my ($self) = @_;

    return $self->_uuid_gen->create_str;
}

sub _unlock { 
    my ($self, $key) = @_;

    return $self->_cache->delete("lock:$key");
}

1;
