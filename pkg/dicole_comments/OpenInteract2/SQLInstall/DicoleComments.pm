package OpenInteract2::SQLInstall::DicoleComments;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_comments_post.sql',
                         'dicole_comments_thread.sql'
                       ]
);

sub get_structure_set {
    return [
          'comments_post',
          'comments_thread'
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
