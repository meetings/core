package OpenInteract2::SQLInstall::DicoleFeedreader;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_feeds_items.sqlite.sql',
                        'dicole_feeds_items_users.sqlite.sql',
                        'dicole_feeds.sqlite.sql',
                        'dicole_feeds_users.sqlite.sql',
                        'dicole_feeds_users_summary.sqlite.sql'
                      ],
          'default' => [
                         'dicole_feeds_items.sql',
                         'dicole_feeds_items_users.sql',
                         'dicole_feeds.sql',
                         'dicole_feeds_users.sql',
                         'dicole_feeds_users_summary.sql'
                       ]
);

sub get_structure_set {
    return [
          'feeds',
          'feeds_items',
          'feeds_items_users',
          'feeds_users',
          'feeds_users_summary'
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
