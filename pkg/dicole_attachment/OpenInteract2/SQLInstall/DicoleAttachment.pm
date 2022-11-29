package OpenInteract2::SQLInstall::DicoleAttachment;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_attachment.sql',
                         'dicole_draft_container.sql'
                       ]
);

sub get_structure_set {
    return [
          'attachment',
          'draft_container'
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
