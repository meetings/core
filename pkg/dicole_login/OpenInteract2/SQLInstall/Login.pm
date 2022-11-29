package OpenInteract2::SQLInstall::Login;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = ('sqlite'  => ['account_recovery_key.sqlite.sql'],
	     'default' => ['account_recovery_key.sql']);

sub get_structure_set {
    return ['account_recovery_key'];
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{sqlite} if ( $type eq 'SQLite' );
    return $FILES{default};
}

sub get_data_file {
    return [];
}

1;
