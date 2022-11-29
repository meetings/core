package OpenInteract2::SQLInstall::DicolePresentations;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_presentations_prese_rating.sql',
                         'dicole_presentations_prese.sql'
                       ]
);

sub get_structure_set {
    return [
          'presentations_prese_rating',
          'presentations_prese'
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
