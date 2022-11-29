package OpenInteract2::Observer::RemoveGroupSecurity;
use strict;
use OpenInteract2::Context   qw( CTX );

sub update {
    my ( $class, $action, $type, $object ) = @_;
    return unless ( $type eq 'pre remove' && ref $object eq 'OpenInteract2::Groups' );

    my $secs = CTX->lookup_object('dicole_security')->fetch_group({
        where => 'target_group_id = ? OR receiver_group_id = ?',
        value => [ $object->id, $object->id ],
    }) || [];
    
    $_->remove for @$secs;
}

1;
