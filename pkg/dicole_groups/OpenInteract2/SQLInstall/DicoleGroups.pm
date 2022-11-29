package OpenInteract2::SQLInstall::DicoleGroups;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_recent_groups.sqlite.sql',
                        'dicole_groups.sqlite.sql',
                        'dicole_group_tool.sqlite.sql',
                        'dicole_group_user.sqlite.sql'
                      ],
          'default' => [
                         'dicole_recent_groups.sql',
                         'dicole_groups.sql',
                         'dicole_group_tool.sql',
                         'dicole_group_user.sql'
                       ]
);

sub get_structure_set {
    return [
          'dicole_recent_groups',
          'groups'
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
