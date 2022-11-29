package OpenInteract2::SQLInstall::Weblog;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_weblog_comments.sqlite.sql',
                        'dicole_weblog_posts.sqlite.sql',
                        'dicole_weblog_topics_link.sqlite.sql',
                        'dicole_weblog_topics.sqlite.sql'
                      ],
          'default' => [
                         'dicole_weblog_comments.sql',
                         'dicole_weblog_posts.sql',
                         'dicole_weblog_topics_link.sql',
                         'dicole_weblog_topics.sql',
                         'dicole_weblog_trackbacks.sql'
                       ]
);

sub get_structure_set {
    return [
          'weblog_posts',
          'weblog_comments',
          'weblog_topics',
          'weblog_trackbacks'
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
