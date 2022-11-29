package OpenInteract2::Action::DicoleFilesDelete;

# $Id: DicoleFilesDelete.pm,v 1.3 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub del {
    my ( $self, $paths ) = @_;

    unless ( ref( $paths ) eq 'ARRAY' ) {
        $paths ||= [ $self->files->Pathutils->get_current_path ];
        unless ( $self->_check_location_security( 'delete' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Security violation. No rights to delete location [_1]',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
    }

    # check security for paths, discard paths for which the user
    # has no delete access rights
    $paths = [
        grep { $self->_check_location_security( 'delete', $_ ) } @{ $paths }
    ];

    $self->_del_paths( $paths );

    $self->_return_msg( [ 1, $self->_msg( "Selected files and directories deleted." ) ] );
}

sub _del_paths {
    my ( $self, $paths ) = @_;
    foreach my $path ( @{ $paths } ) {
        if ( !$path || $path eq '/' || $path eq '.' ) {
            $self->_return_msg( [ 0,
                $self->_msg( "Root directory cannot be deleted." )
            ], 1 );
        }
        my $objects = $self->_get_object_by_path( $path, 1, 1 );
        while ( $objects->has_next() ) {
            my $object = $objects->get_next;
            if ( ref $object ) {
                eval { $object->remove; };
                if ( $@ ) {
                    $self->log( 'error', 'Cannot remove '
                        . ref( $object ) . ' object:' . $@
                    );
                }
            }
        }
    }

    my $trashed = [];
    ( $paths, $trashed ) = $self->files->validate_paths( $paths );

    foreach my $path ( @{ $paths } ) {
        $self->files->delete_path( $path );
    }

}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesDelete - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
