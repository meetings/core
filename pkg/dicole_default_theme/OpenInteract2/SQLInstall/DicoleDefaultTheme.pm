package OpenInteract2::SQLInstall::DicoleDefaultTheme;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (

);

sub get_structure_set {
    return [

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
          'install_theme.dat'
    ];
}

1;
