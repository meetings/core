package OpenInteract2::SQLInstall::DicoleTag;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_tag_attached.sql',
                         'dicole_tag_collection.sql',
                         'dicole_tag_index.sql',
                         'dicole_tag.sql'
                       ]
);

sub get_structure_set {
    return [
          'tag',
          'tag_attached',
          'tag_index',
          'tag_collection'
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
