package OpenInteract2::SQLInstall::GroupPages;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_group_pages_content.sqlite.sql',
                        'dicole_group_pages_link.sqlite.sql',
                        'dicole_group_pages.sqlite.sql',
                        'dicole_group_pages_vn_content.sqlite.sql',
                        'dicole_group_pages_vn_link.sqlite.sql',
                        'dicole_group_pages_vn.sqlite.sql'
                      ],
          'default' => [
                         'dicole_group_pages_content.sql',
                         'dicole_group_pages_link.sql',
                         'dicole_group_pages.sql',
                         'dicole_group_pages_vn_content.sql',
                         'dicole_group_pages_vn_link.sql',
                         'dicole_group_pages_vn.sql'
                       ]
);

sub get_structure_set {
    return [
          'group_pages',
          'group_pages_content',
          'group_pages_version',
          'group_pages_version_content',
          'group_pages_link'
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
