package OpenInteract2::SQLInstall::DicoleChatUserplane;

# Sample of SQL installation class. This uses your package name as the
# base and assumes you want to create a separate table for Oracle
# users and include a sequence for Oracle and PostgreSQL users.

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
   pg      => [],
   default => ['dicole_vc_chatlog.sql',
	       'dicole_vc_rooms.sql',
	       'dicole_vc_presence.sql',
	       'dicole_vc_connection.sql'],
);

sub get_structure_set {
    return [
	    'dicole_vc_chatlog',
	    'dicole_vc_rooms',
	    'dicole_vc_presence',
	    'dicole_vc_connection'
	    ];
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

