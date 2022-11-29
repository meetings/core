package OpenInteract2::SQLInstall::DicoleMetadata;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_dcmi_metadata.sqlite.sql',
                        'dicole_metadata_fields.sqlite.sql',
                        'dicole_metadata.sqlite.sql',
                        'dicole_typesets.sqlite.sql',
                        'dicole_typeset_types_link.sqlite.sql',
                        'dicole_typeset_types.sqlite.sql'
                      ],
          'default' => [
                         'dicole_dcmi_metadata.sql',
                         'dicole_metadata_fields.sql',
                         'dicole_metadata.sql',
                         'dicole_typesets.sql',
                         'dicole_typeset_types_link.sql',
                         'dicole_typeset_types.sql'
                       ]
);

sub get_structure_set {
    return [
          'typeset_types_link',
          'metadata',
          'metadata_fields',
          'dcmi_metadata',
          'typesets',
          'typeset_types'
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
          'install_metadata.dat',
          'install_metadata_fields.dat',
          'install_typesets.dat',
          'install_typeset_types.dat',
          'install_typeset_types_link.dat'
    ];
}

1;
