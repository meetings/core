package OpenInteract2::SQLInstall::DicoleForums;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_forums_messages_unread.sqlite.sql',
                        'dicole_forums_messages.sqlite.sql',
                        'dicole_forums_metadata.sqlite.sql',
                        'dicole_forums_parts.sqlite.sql',
                        'dicole_forums.sqlite.sql',
                        'dicole_forums_threads_read.sqlite.sql',
                        'dicole_forums_threads.sqlite.sql',
                        'dicole_forums_versions.sqlite.sql'
                      ],
          'default' => [
                         'dicole_forums_messages_unread.sql',
                         'dicole_forums_messages.sql',
                         'dicole_forums_metadata.sql',
                         'dicole_forums_parts.sql',
                         'dicole_forums.sql',
                         'dicole_forums_threads_read.sql',
                         'dicole_forums_threads.sql',
                         'dicole_forums_versions.sql'
                       ]
);

sub get_structure_set {
    return [
          'forums_metadata',
          'forums',
          'forums_threads',
          'forums_threads_read',
          'forums_messages',
          'forums_messages_unread',
          'forums_versions',
          'forums_parts'
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
