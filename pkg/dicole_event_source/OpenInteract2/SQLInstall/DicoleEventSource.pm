package OpenInteract2::SQLInstall::DicoleEventSource;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_event_source_event.sql',
                         'dicole_event_source_gateway.sql',
                         'dicole_event_source_sync_subscription.sql'
                       ]
);

sub get_structure_set {
    return [
          'event_source_event',
          'event_source_sync_subscription',
          'event_source_gateway'
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
