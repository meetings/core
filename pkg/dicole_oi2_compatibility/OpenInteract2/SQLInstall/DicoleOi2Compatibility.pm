package OpenInteract2::SQLInstall::DicoleOi2Compatibility;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'sys_user.sql',
                         'sys_user_language.sql',
                         'sys_group.sql',
                         'theme.sql',
                         'theme_prop.sql'
                       ]
);

sub get_structure_set {
    return [
          'user',
          'group',
          'theme',
          'themeprop'
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
