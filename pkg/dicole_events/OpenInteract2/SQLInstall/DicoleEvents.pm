package OpenInteract2::SQLInstall::DicoleEvents;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_events_event.sql',
                         'dicole_events_invite.sql',
                         'dicole_events_user.sql'
                       ]
);

sub get_structure_set {
    return [
          'events_invite',
          'events_user'
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
