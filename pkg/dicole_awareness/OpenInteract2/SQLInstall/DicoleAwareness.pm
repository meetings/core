package OpenInteract2::SQLInstall::DicoleAwareness;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_logged_action.sqlite.sql'
                      ],
          'default' => [
                         'dicole_logged_action.sql',
                         'dicole_logged_usage_daily.sql',
                         'dicole_logged_usage_user.sql',
                         'dicole_logged_usage_weekly.sql',
                         'dicole_object_activity.sql',
                         'dicole_statistics_action.sql'
                       ]
);

sub get_structure_set {
    return [
          'logged_action',
          'logged_usage_weekly',
          'logged_usage_user',
          'logged_usage_daily',
          'statistics_action',
          'object_activity'
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
