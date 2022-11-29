package OpenInteract2::SQLInstall::DicoleEmails;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_emails_dispatch.sql',
                         'dicole_sent_email.sql'
                       ]
);

sub get_structure_set {
    return [
          'emails_dispatch',
          'sent_email'
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
