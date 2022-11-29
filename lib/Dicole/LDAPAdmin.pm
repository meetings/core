package Dicole::LDAPAdmin;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::LDAPConnection;

use Net::LDAP::Filter;

=pod

=head1 NAME

Represents administrative interface to LDAP database

=head1 SYNOPSIS

    use Dicole::LDAPAdmin;
    my $la = new Dicole::LDAPAdmin('foo');
    my $ldap_user = $la->search_user($login_name);

=head1 DESCRIPTION

LDAPAdmin class is for LDAP database administrative
functions. Currently implemented is searching for users in LDAP
database.

=head1 METHODS

=head2 new( STRING )

Creates and returns a new LDAPAdmin object.

Requires server name ( defined in server.ini: [login
host_{server_name}]) as a parameter for the constructor.

=cut

sub new {
    my ($class, $server)  = @_;

    my $self = {
        _server => $server
    };

    bless ($self, $class);

    return $self->_init;
}

=head2 search_user( STRING )

Searches for a user object in LDAP database.

Requires login name as a parameter for the search. Other LDAP
configuration (including the attribute which stores username in LDAP
db) is read from LDAPConnection object. If user is found, returns
Net::LDAP::Entry object.

=cut

sub search_user {
    my ($self, $login_name) = @_;
    
    $login_name = Dicole::Utils::Text->ensure_utf8( $login_name );
    
    return $self->search_utf8_user( $login_name );
}

sub search_utf8_user {
    my ($self, $login_name) = @_;

    unless ($self->_connection) {
        return undef;
    }
    my $filter_str = $self->_config->{ldap_filter} . "=" . $login_name;
    my $filter = Net::LDAP::Filter->new($filter_str)->as_string;

    # search for entry in LDAP database, store in this object
    my $entry = $self->_connection->connection->search(
        base => $self->_config->{ldap_search_base},
        filter => $filter,
    )->pop_entry;
    # check sanity of entry
    eval {
        # this should always succeed after successful bind
        $entry->get_value($self->_config->{ldap_filter});
    };

    $@ ? return undef : return $entry;
}

=head2 create_user ( HASHREF )

Creates user in LDAP database. Currently handles only inetOrgPerson schema.

=cut

sub create_user {
    my ($self, $entry) = @_;

    return $entry unless Dicole::LDAPAdmin->updates_allowed;

    $entry || return undef;
    (ref($entry) eq 'Dicole::LDAPUser') && ($entry = $entry->entry);

    $entry->changetype('add');
    $entry->get_value('objectClass') ||
	$entry->add(objectClass => ['top', 'person', 'organizationalPerson', 'inetOrgPerson']);
    $entry->dn ||
	$entry->dn($self->_create_dn($entry->get_value($self->_config->{ldap_filter})));

    my $ret = $entry->update($self->_connection->connection);
    
    if ($ret->{resultCode}) {
        my $user = $entry->dn;
        $self->_log->warn(
            "Failed to create user [$user] to LDAP database: " .
            $ret->error
        );
        return undef;
    }
    
    return $entry;

}

=head2 delete_user ( STRING )

Deletes user from LDAP database. Needs Dicole::LDAPUser or
Net::LDAP::Entry as an argument.

=cut

sub delete_user {
    my ($self, $entry) = @_;

    return $entry unless Dicole::LDAPAdmin->updates_allowed;

    $entry || return undef;
    (ref($entry) eq 'Dicole::LDAPUser') && ($entry = $entry->entry);

    # remove entry from LDAP database
    eval {
	$self->_connection->connection->delete($entry);
    };

    $@ ? return undef : return $entry;
}

=head2 update_user( Net::LDAP::Entry )

Updates LDAP entry in database, using the supplied Net::LDAP::Entry
object.

=cut

sub update_user {
    my ($self, $entry) = @_;

    return $entry unless Dicole::LDAPAdmin->updates_allowed;

    $entry || return undef;
    (ref($entry) eq 'Dicole::LDAPUser') && ($entry = $entry->entry);

    my $ret = $entry->update($self->_connection->connection);

    # resultCode 0 == success
    if ($ret->{resultCode}) {
        my $user = $entry->dn;
	    $self->_log->warn(
            "Failed to update user [$user] to LDAP database: " .
            $ret->error
        );
	    return undef;
    }
    return $entry;
}
    
=head2 update_user_password ( Net::LDAP::Entry, STRING )

Updates LDAP entry password, using supplied Net::LDAP::Entry or
Dicole::LDAPUser and string password. Returns encrypted password if
update was successful, undef otherwise.

=cut

sub update_user_password {
    my ($self, $entry, $new_password) = @_;

    $new_password = Dicole::Utils::Text->ensure_utf8( $new_password );
    
    $entry || return undef;
    (ref($entry) eq 'Dicole::LDAPUser') && ($entry = $entry->entry);
    # NOTE: setting an empty password is ok, when called as 
    #       $obj->update_user_password($user, '');
    defined($new_password) || return undef;

    # XXX: NOTE: crypt() uses DES 56bits, which is insecure
    # salt generation from perldoc perlfunc
    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    my $pass_str = '{CRYPT}' . crypt($new_password, $salt);

    return $pass_str unless Dicole::LDAPAdmin->updates_allowed;

    # fall back to userPassword (as per inetOrgPerson schema)
    $pw_field = ($self->_config->{ldap_attribute_password} || 'userPassword');

    $entry->replace($pw_field => $pass_str);

    $self->update_user($entry) ? return $pass_str : return undef;
}

sub _init {
    my $self = shift;

    $self->_connection;

    return $self;
}

sub _log {
    my $self = shift;
    $self->{_log} ||= get_logger( LOG_AUTH );
    return $self->{_log};
}

sub _connection {
    my $self = shift;

    $self->{_connection} && return $self->{_connection};

    unless($self->{_server}) {
	return undef;
    }

    my $c = new Dicole::LDAPConnection($self->{_server});

    # bind to LDAP server as administrative user
    my $bind;
    eval {
	$bind = $c->connection->bind($c->config->{ldap_dn},
				     password => $c->config->{ldap_password});
    };
    if ($@) {
	$self->_log->warn("Failed to bind to LDAP server as administrative user.");
	return undef;
    }
    unless($bind) {
	$self->_log->warn("Failed to bind to LDAP server as administrative user.");
	return undef;
    }

    return ($self->{_connection} = $c);
}

sub _config {
    my $self = shift;

    # return configuration data from Dicole::LDAPConnection object
    my $c = $self->_connection;
    $c ? return $c->config : return undef;
}

sub _create_dn {
    my ($self, $value) = @_;

    $value || return undef;

    my $lsb = $self->_config->{ldap_create_base} || return undef;
    my $dn = $self->_config->{ldap_filter} . '=' . $value .',' . $lsb;

    return $dn;
}

sub updates_allowed {
    my ($class) = @_;

    my $config = CTX->server_config->{login}{disable_ldap_modifications};
    my $disabled = undef;

    eval {
        my $d = CTX->lookup_action('dicole_domains')->get_current_domain;
        $disabled = $config->{ $d->domain_name };
    };

    $disabled = $config->{default} unless defined( $disabled );
    return $disabled ? 0 : 1;
}

1;
