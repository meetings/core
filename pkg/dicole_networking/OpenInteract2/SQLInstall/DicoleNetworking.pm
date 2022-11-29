package OpenInteract2::SQLInstall::DicoleNetworking;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_networking_contact.sql',
                         'dicole_networking_profile.sql'
                       ]
);

sub get_structure_set {
    return [
          'networking_profile',
          'networking_contact'
    ];
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{sqlite} if ( $type eq 'SQLite' );
    return $FILES{default};
}

sub get_data_file {
    return [

    ];
}

1;
