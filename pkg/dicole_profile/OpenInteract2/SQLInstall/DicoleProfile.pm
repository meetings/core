package OpenInteract2::SQLInstall::DicoleProfile;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'sqlite' => [
                        'dicole_profile_comments_link.sqlite.sql',
                        'dicole_profile_comments.sqlite.sql',
                        'dicole_profile_friends_link.sqlite.sql',
                        'dicole_profile_friends.sqlite.sql',
                        'dicole_profile.sqlite.sql'
                      ],
          'default' => [
                         'dicole_profile_comments_link.sql',
                         'dicole_profile_comments.sql',
                         'dicole_profile_friends_link.sql',
                         'dicole_profile_friends.sql',
                         'dicole_profile.sql'
                       ]
);

sub get_structure_set {
    return [
          'profile',
          'profile_comments',
          'profile_friends'
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
