package OpenInteract2::SQLInstall::DicoleFiles;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'files.sqlite.sql'
                      ],
          'default' => [
                         'files.sql'
                       ]
);

sub get_structure_set {
    return [
          'files'
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
