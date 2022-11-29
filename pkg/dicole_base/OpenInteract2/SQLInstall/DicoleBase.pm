package OpenInteract2::SQLInstall::DicoleBase;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_summary_layout.sqlite.sql',
                        'dicole_theme.sqlite.sql',
                        'dicole_tool_settings.sqlite.sql',
                        'dicole_tool.sqlite.sql',
                        'dicole_user_tool.sqlite.sql',
                        'dicole_wizard_data.sqlite.sql',
                        'dicole_wizard.sqlite.sql',
                        'lang.sqlite.sql'
                      ],
          'default' => [
                         'dicole_digest_source.sql',
                         'dicole_summary_layout.sql',
                         'dicole_theme.sql',
                         'dicole_tool_settings.sql',
                         'dicole_tool.sql',
                         'dicole_url_alias.sql',
                         'dicole_user_tool.sql',
                         'dicole_wizard_data.sql',
                         'dicole_wizard.sql',
                         'lang.sql'
                       ]
);

sub get_structure_set {
    return [
          'dicole_theme',
          'lang',
          'dicole_wizard',
          'dicole_wizard_data',
          'groups',
          'tool',
          'dicole_tool_settings',
          'dicole_summary_layout',
          'digest_source',
          'url_alias'
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
          'install_lang.dat'
    ];
}

1;
