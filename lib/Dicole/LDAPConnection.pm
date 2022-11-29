package Dicole::LDAPConnection;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Net::LDAP;

=pod

=head1 NAME

Represent connection to LDAP database

=head1 SYNOPSIS

    use Dicole::LDAPConnection;
    my $conn_obj = Dicole::LDAPConnection->new($server_name);
    my $conn     = $connection_object->connection;

=head1 DESCRIPTION

LDAPConnection class represents an active connection to LDAP
database. The consctructor needs the name of the LDAP server, as
specified in server.ini [login host_{server_name}].
The parameters for the connection are parsed
from server.ini based on this. Note that this class doesn't "bind" to
the LDAP server, this is handled elsewhere.

=head1 METHODS

=head2 new( STRING )

Creates and returns a new LDAPConnection object.

Requires server name ( defined in server.ini: [login
host_{server_name}]) as a parameter for the constructor.

=cut

sub new {
    my ($class, $server) = @_;

    unless($server) {
	return undef;
    }

    my $self = {
	_server => $server,
	_connection  => undef,
	_config      => undef
	};
    bless ($self, $class);

    return $self->_init;
}

=pod

=head2 config

Returns a hasref containing the LDAP connection information parsed
from server.ini .

=cut

sub config {
    my $self = shift;

    return $self->_config;
}

=pod

=head2 connection

Returns the initialized LDAP connection.

=cut

sub connection {
    my $self = shift;

    return $self->_connection;
}

sub _init {
    my $self = shift;

    $self->_config;
    $self->_connection;

    return $self;
}

sub _log {
    my $self = shift;
    $self->{_log} ||= get_logger(LOG_AUTH);
    return $self->{_log};
}

sub _config {
    my $self = shift;

    $self->{_config} && return $self->{_config};

    my $login_config = CTX->lookup_login_config;
    my $ldap_server_name = "host_" . $self->{_server};
    
    my $c = $login_config->{$ldap_server_name};
    
    $c->{$_} = Dicole::Utils::Text->ensure_utf8( $c->{$_} ) for ( qw/
        ldap_search_base
        ldap_create_base
        ldap_filter
        ldap_dn
        ldap_attribute_firstname
        ldap_attribute_lastname
        ldap_attribute_last_and_firstname
        ldap_attribute_email
        ldap_attribute_password
    / );

    return ($self->{_config} = $c);
}

sub _connection {
    my ($self, $args) = @_;

    $self->{_connection} && return $self->{_connection};

    unless($self->_config) {
	return undef;
    }

    my $ldap_data = {};
    my ($ldap, $ldap_retries, $ldap_timeout);

    # default to retries = 1, timeout = one second
    $self->_config->{ldap_retries} ||= 1;
    $self->_config->{ldap_timeout} ||= 1;

    # try to connect to server, controlled by ldap_retries & ldap_timeout
    for (my $i = 0; $i <= $self->_config->{ldap_retries}; $i++) {
	$ldap = Net::LDAP->new($self->_config->{ldap_server});
	last if $ldap;
	sleep $self->_config->{ldap_timeout};
    }

    unless ($ldap) {
	$self->_log->warn("LDAP server is not responding");
	return undef;
    }

    return ($self->{_connection} = $ldap);
}

1;
