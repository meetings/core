
# This OpenInteract2 file was generated
#   by:    /usr/local/bin/oi2_manage create_package --package=dicole_domains
#   on:    Fri Mar 17 01:19:56 2006
#   from:  SQLInstall.pm
#   using: OpenInteract2 version 1.99_07

package OpenInteract2::SQLInstall::DicoleDomains;

# Sample of SQL installation class. This uses your package name as the
# base and assumes you want to create a separate table for Oracle
# users and include a sequence for Oracle and PostgreSQL users.

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
#   pg      => [ 'dicole_domains.sql',
#                'dicole_domains_sequence.sql' ],
   default => [ 'dicole_domain.sql', 'dicole_domain_user.sql', 'dicole_domain_group.sql', 'dicole_domain_admin.sql' ],
);

sub get_structure_set {
    return [ 'dicole_domain', 'dicole_domain_user', 'dicole_domain_group', 'dicole_domain_admin' ];
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{default};
}

# Uncomment this if you're passing along initial data

#sub get_data_file {
#    return 'initial_data.dat';
#}

# Uncomment this if you're using security

#sub get_security_file {
#    return 'install_security.dat';
#}

1;

