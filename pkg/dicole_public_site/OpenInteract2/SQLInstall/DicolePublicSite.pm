package OpenInteract2::SQLInstall::DicolePublicSite;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_ps_box.sqlite.sql',
                        'dicole_ps_page_box.sqlite.sql',
                        'dicole_ps_page.sqlite.sql'
                      ],
          'default' => [
                         'dicole_ps_box.sql',
                         'dicole_ps_page_box.sql',
                         'dicole_ps_page.sql'
                       ]
);

sub get_structure_set {
    return [
          'ps_page',
          'ps_box',
          'ps_page_box'
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
