package Dicole::LDAPUser;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::LDAPConnection;
use Dicole::LDAPAdmin;
use Dicole::Utils::Text;

use Net::LDAP;
use Net::LDAP::Entry;
use Net::LDAP::Filter;

=pod

=head1 NAME

Represents user object in LDAP database

=head1 SYNOPSIS

    use Dicole::LDAPUser;

    my $lu = new Dicole::LDAPUser({ldap_server_name => 'foo',
                                   login_name       => 'jsmith',
                                   password         => 'secret'});

    # authenticate against LDAP database
    my $login_ok = $lu->check_password;

    # get Net::LDAP::Entry object for user
    my $ldap_entry = $lu->entry;

    # set field to new value
    $lu->field('givenName', $new_name);

    # update changes to ldap database, like SPOPS objects
    $lu->update;

    # get value of last name (LDAP field sn)
    my $last_name = $lu->field('sn');

=head1 DESCRIPTION

LDAPUser class is for representing user object in an LDAP database. It
supports manipulation of stored values and changing user
password. Also supported is mapping of field names to LDAP fields. The
object can connect to LDAP database in two ways: direct bind and
searching of a specified subtree. The latter is accomplished using
Dicole::LDAPAdmin.

=head1 METHODS

=head2 new( HASHREF )

Creates and returns a new LDAPUser object.

Requires hashref as an argument to the constructor, containing values
for 'ldap_server_name', 'login_name' and optionally 'password'.

=cut

sub new {
    my ($class, $args) = @_;

    # the data this object will store
    my $self = {
        _login_name       => $args->{login_name},
        _password         => $args->{password},
        _ldap_server_name => $args->{ldap_server_name},
        _fields           => $args->{fields},
        _connection       => $args->{connection},
        _entry            => $args->{entry},
        _log              => $args->{log}
    };
    
    $self->{_login_name} = Dicole::Utils::Text->ensure_utf8(
        $self->{_login_name}
    );
    $self->{_password} = Dicole::Utils::Text->ensure_utf8(
        $self->{_password}
    );
    
    bless ($self, $class);

    return $self->_init;
}

=head2 check_password( )

Checks supplied password against entry in LDAP database. This is done
using a LDAP bind. Returns Net::LDAP::Entry object for the user if bind is
successful, undef otherwise.

=cut

sub config {
    my $self = shift;

    return $self->_config;
}

sub is_filled {
    my ( $self ) = @_;
    
    return 1 if $self->field( $self->config->{ldap_attribute_email} );

    if ( my $filter = $self->field( $self->config->{ldap_filter} ) ) {
        $self->_log->warn("LDAP user [$filter] has no email!");
        return 1;
    }
    
    return 0;
}

sub check_password {
    my $self = shift;

    unless($self->_config) {
	return undef;
    }
    # check if able to bind to DN as the user
    my $bind = $self->_connection->connection->bind(
        $self->_entry->dn,
        password => $self->{_password}
    );
    unless ($bind->{resultCode} == 0) {
        $self->_log->warn("LDAP Password check for [$self->{_login_name}] failed");
        return undef;
    }

    # bind succeeded
    return $self->_entry;
}

=head2 entry( )

Returns Net::LDAP::Entry of the user.

=cut

sub entry {
    my ($self, $entry) = @_;

    return $self->_entry($entry);
}

=head2 update( )

Updates the LDAP entry to LDAP database.

=cut

sub update {
    my $self = shift;

    return $self->_sync_to_ldap;
}

=head2 password( [STRING] )

Updates password in LDAP entry using crypt() . Call update() after
setting the password to store the change permanently to LDAP database.

=cut

sub password {
    my ($self, $new_password) = @_;
    
    $new_password = Dicole::Utils::Text->ensure_utf8( $new_password );

    # NOTE: setting an empty password is ok, when called as $obj->password('');
    defined($new_password) || return undef;

    # XXX: NOTE: crypt() uses DES 56bits, which is insecure
    # salt generation from perldoc perlfunc
    my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
    my $pass_str = '{CRYPT}' . crypt($new_password, $salt);

    # NOTE: 'password' field mapping is mandatory
    if ($self->_entry->replace($self->_fields->{password} => $pass_str)) {
        return $pass_str; # return crypt():ed value to caller
    } else {
        return undef;
    }
}

=head2 field( STRING, [STRING] )

Returns LDAP attribute field. If supplied value, changes field value
to new value, returning old value.

=cut

sub field {
    my ($self, $field, $value) = @_;

    return $self->_field($field, $value);
}

sub _init {
    my $self = shift;

    # establish connection to LDAP server
    $self->_connection;
    return undef unless $self->_config;

    # fetch user object from ldap database
    my ($user_dn, $entry);
    if ($self->_config->{bind_method} =~ /search/i) {
        my $la = new Dicole::LDAPAdmin($self->{_ldap_server_name});
        $entry = $la->search_utf8_user($self->{_login_name});
    } else {
        $user_dn = $self->_config->{ldap_filter} 
             . "=" . "$self->{_login_name}," 
             . $self->_config->{ldap_search_base};
             
        my $bind = $self->_connection->connection->bind($user_dn, 
            password => $self->{_password});
            
        unless($bind) {
            $self->_log->warn("Can't connect to LDAP database as user $self->{_login_name}");
        } else {
            my $f_str  = $self->_config->{ldap_filter} . "=" . $self->{_login_name};
            my $filter = Net::LDAP::Filter->new($f_str);
            $entry = $self->_connection->connection->search(
                base      => $self->_config->{ldap_search_base},
                filter    => $filter->as_string,
                sizelimit => 1
            )->pop_entry;
        }
    }

    if ($entry) {
        $self->_entry($entry);
    } else {
        # store empty Net::LDAP::Entry
        $self->_entry(Net::LDAP::Entry->new);
        # $self->_entry->changetype = 'modify'); # XXX: ?
    }

    # Dicole user data mappings to inetOrgPerson schema (RFC 2798)
    # can be overridden in server.ini
    my $fields = {};

    $fields->{password} =
        ($self->_config->{ldap_attribute_password} || 'userPassword');
    $fields->{last_and_first_name} = 
        ($self->_config->{ldap_attribute_last_and_firstname});
    $fields->{first_name} = 
        ($self->_config->{ldap_attribute_firstname});
    $fields->{last_name} =
        ($self->_config->{ldap_attribute_lastname});
    $fields->{email} =
        ($self->_config->{ldap_attribute_email} || 'mail');
    # XXX: 'o' conflicts with security attribute?
    $fields->{organization} =
        ($self->_config->{ldap_attribute_organization} || 'o');
    $fields->{language} = 
	($self->_config->{ldap_attribute_language} || 'preferredLanguage');

    $self->_fields($fields);

    return $self;
}

sub _connection {
    my $self = shift;

    $self->{_connection} && return $self->{_connection};
    return ($self->{_connection} = new
	    Dicole::LDAPConnection($self->{_ldap_server_name}));
}

sub _log {
    my $self = shift;
    $self->{_log} ||= get_logger( LOG_AUTH );
    return $self->{_log};
}

sub _entry {
    my ($self, $entry) = @_;    
    $entry && ($self->{_entry} = $entry);
    return $self->{_entry};
}

sub _fields {
    my ($self, $fields) = @_;
    $fields && ($self->{_fields} = $fields);
    return $self->{_fields};
}

sub _field {
    my ($self, $field, $value) = @_;

    return undef unless $self->_entry && $field;

    my $real_field = $self->_translate_field_mapping( $field );

    # We presume that either last_name and first_name mappings OR
    # last_and_first_name mapping are defined
    if ( ! $real_field ) {
        if ( $field eq 'first_name' || $field eq 'last_name' ) {
            die "Insufficient LDAP name configuration!" unless
                $self->_translate_field_mapping( 'last_and_first_name' );
            if ( $value ) {
                my $l = ( $field eq 'last_name' ) ?
                    $value : $self->_field( 'last_name' );
                my $f = ( $field eq 'first_name' ) ?
                    $value : $self->_field( 'first_name' );
                $self->_field( 'last_and_first_name', $l . ' ' . $f );
            }
            return $self->_name_from_combined( $field );
        }
        elsif ( $field eq 'last_and_first_name' ) {
            die "Insufficient LDAP name configuration!" unless
                $self->_translate_field_mapping( 'last_name' ) &&
                $self->_translate_field_mapping( 'first_name' );

            if ( $value ) {
                my ( $l, $f ) = split /\s+/, $value, 2;
                $self->_field( 'last_name', $l );
                $self->_field( 'first_name', $f );
            }
            return $self->_combined_from_names;
        }
        else {
            die "No mapping defined for LDAP entry: $field";
        }
    }
    
    if ( defined( $value ) ) {
        $value = Dicole::Utils::Text->ensure_utf8( $value );
        $self->_entry->replace( $real_field, $value );
    }
    
    my $return = $self->_entry->get_value( $real_field );
    
    if ( ! $return ) {
        if ( $field eq 'last_name' || $field eq 'first_name' ) {
            return $self->_name_from_combined( $field );
        }
        elsif ( $field eq 'last_and_first_name' ) {
            return $self->_combined_from_names;
        }
    }
    
    return $return;
}

sub _name_from_combined {
    my ( $self, $field ) = @_;
    
    return '' unless
        $self->_translate_field_mapping( 'last_and_first_name' );
    
    my $lf = $self->_field( 'last_and_first_name' );
    my ( $l, $f ) = split /\s+/, $lf, 2;
    
    return $l if $field eq 'last_name';
    return $f if $field eq 'first_name';
}

sub _combined_from_names {
    my ( $self ) = @_;
    
    my $f = $self->_translate_field_mapping( 'first_name' ) ?
        $self->_field( 'first_name' ) : '';
    my $l = $self->_translate_field_mapping( 'last_name' ) ?
        $self->_field( 'last_name' ) : '';
    
    return $l . ' ' . $f;
}

sub _translate_field_mapping {
    my ($self, $field) = @_;

    if ( my $f = $self->_fields->{$field} ) {
        return $f eq 'NULL' ? undef : $f;
    } else {
        return $field;
    }
}

sub _sync_from_ldap {
    my $self = shift;

    # XXX: not implemented

    return $self->{_entry};
}

sub _config {
    my ($self, $config) = @_;

    $self->_connection ? return $self->_connection->config : return undef;
}

sub _sync_to_ldap {
    my $self = shift;

    unless($self->_entry) {
	return undef;
    }

    if ($self->_config->{bind_method} =~ /search/i) {
	# admin bind
	my $la = new Dicole::LDAPAdmin($self->{_ldap_server_name});
	return $la->update_user($self->_entry);
    } else {
        # user bind
        # XXX: previous bind() assumed, does this need changing?
        return 1 unless Dicole::LDAPAdmin->updates_allowed;
        $self->_entry->update($self->_connection->connection)->{resultCode} ?
        return undef : return 1;
    }
}

1;
