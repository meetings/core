# This OpenInteract2 file was generated
#   by:    /usr/local/bin/oi2_manage create_package --website_dir=/usr/local/src/dicole-crmjournal/ --package=dicole_thumbnails
#   on:    Tue Apr 28 18:51:08 2009
#   from:  SQLInstall.pm
#   using: OpenInteract2 version 1.99_07

package OpenInteract2::SQLInstall::DicoleThumbnails;

# Sample of SQL installation class. This uses your package name as the
# base and assumes you want to create a separate table for Oracle
# users and include a sequence for Oracle and PostgreSQL users.

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   pg      => [ 'dicole_thumbnails.sql',
                'dicole_thumbnails_sequence.sql' ],
   default => [ 'dicole_thumbnails.sql' ],
);

sub get_structure_set {
    return 'dicole_thumbnails';
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

