package OpenInteract2::SQLInstall::DicoleSecurity;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_security_collection.sqlite.sql',
                        'dicole_security_col_lev.sqlite.sql',
                        'dicole_security_level.sqlite.sql',
                        'dicole_security_meta.sqlite.sql',
                        'dicole_security.sqlite.sql'
                      ],
          'default' => [
                         'dicole_security_collection.sql',
                         'dicole_security_col_lev.sql',
                         'dicole_security_level.sql',
                         'dicole_security_meta.sql',
                         'dicole_security.sql'
                       ]
);

sub get_structure_set {
    return [
          'dicole_security_level',
          'dicole_security_meta',
          'dicole_security_collection',
          'dicole_security',
          'dicole_security_col_lev'
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
