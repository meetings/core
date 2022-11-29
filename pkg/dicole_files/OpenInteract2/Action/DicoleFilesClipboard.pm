package OpenInteract2::Action::DicoleFilesClipboard;

# $Id: DicoleFilesClipboard.pm,v 1.2 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub copy {
    my ( $self, $paths ) = @_;

    unless ( ref( $paths ) eq 'ARRAY' ) {
        unless ( $self->_check_existence ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Location [_1] does not exist.',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        $paths = [ $self->files->Pathutils->get_current_path ];
        unless ( $self->_check_location_security( 'read' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Security violation. No rights to read location [_1]',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
    }

    # check security for paths, discard paths for which the user
    # has no read access rights
    $paths = [
        grep { $self->_check_location_security( 'read', $_ ) } @{ $paths }
    ];

    CTX->request->session->{clipboard}{content} = $paths;
    CTX->request->session->{session}{clipboard}{mode} = 'copy';

    $self->_return_msg( [ 1,
        $self->_msg( "Selected files and directories copied to clipboard." )
    ] );
}

sub cut {
    my ( $self, $paths ) = @_;

    unless ( ref( $paths ) eq 'ARRAY' ) {
        unless ( $self->_check_existence ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Location [_1] does not exist.',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        $paths = [ $self->files->Pathutils->get_current_path ];
        unless ( $self->_check_location_security( 'delete' ) ) {
            return $self->_return_msg( [ 0,
                $self->_msg( 'Security violation. No rights to delete location [_1]', $self->files->Pathutils->get_current_path )
            ] );
        }
    }

    # check security for paths, discard paths for which the user
    # has no delete access rights
    $paths = [
        grep { $self->_check_location_security( 'delete', $_ ) } @{ $paths }
    ];

    CTX->request->session->{clipboard}{content} = $paths;
    CTX->request->session->{clipboard}{mode} = 'cut';

    $self->_return_msg( [ 1,
        $self->_msg( "Selected files and directories moved to clipboard." )
    ] );
}

sub paste {
    my ( $self ) = @_;

    unless ( $self->_check_existence ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Location [_1] does not exist.',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    unless ( defined $self->_check_location_security( 'add' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
            'Security violation. No rights to write to location [_1]',
            $self->files->Pathutils->get_current_path
        ) ] );
    }

    my $mode = CTX->request->session->{clipboard}{mode};
    my $paths = CTX->request->session->{clipboard}{content};

    if ( ref( $paths ) eq 'ARRAY' ) {
        my $current_path = $self->files->Pathutils->get_current_path;
        foreach my $path ( @{ $paths } ) {
            my $objects = $self->_get_object_by_path( $path, 1, 1 );
            my @full = split '/', $path;
            my $name = pop @full;
            while ( $objects->has_next() ) {
                my $object = $objects->get_next;
                my $new_path = $name;
                if ( $current_path ) {
                    $new_path = "$current_path/$name";
                }
                $object->{path} =~ s/$path/$new_path/;
                if ( $mode eq 'cut' ) {
                    $object->save;
                }
                else {
                    my $new_object = $object->clone;
                    $new_object->save;
                }
            }
        }

        if ( $mode eq 'cut' ) {
            # Empty clipboard
            delete CTX->request->session->{clipboard};
            $self->files->move_files( $paths );
        } else {
            $self->files->copy_files( $paths );
        }
    }
    else {
        $self->_return_msg( [ 0, $self->_msg( "Clipboard is empty." ) ] );
    }

    $self->_return_msg( [ 1, $self->_msg( "Pasted the contents of clipboard." ) ] );
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesClipboard - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
