package OpenInteract2::SQLInstall::Navigation;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'navigation_item.sqlite.sql'
                      ],
          'default' => [
                         'dicole_area_visit.sql',
                         'navigation_item.sql'
                       ]
);

sub get_structure_set {
    return [
          'navigation_item',
          'area_visit'
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
