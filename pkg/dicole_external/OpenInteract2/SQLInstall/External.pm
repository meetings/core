package OpenInteract2::SQLInstall::External;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
#   oracle  => [ 'skeleton_oracle.sql',
#                'skeleton_sequence.sql' ],
#   pg      => [ 'skeleton.sql',
#                'skeleton_sequence.sql' ],
   default => [ 'externalsource.sql' ],
);

sub get_structure_set {
    return 'externalsource';
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{oracle} if ( $type eq 'oracle' );
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{default};
}


1;
