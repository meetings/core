package OpenInteract2::Action::DicoleFilesArchive;

# $Id: DicoleFilesArchive.pm,v 1.2 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Files::Archive;
use Dicole::Utility;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub uncompress {
    my ( $self ) = @_;

    unless ( $self->_check_existence ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Location [_1] does not exist.',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    unless ( $self->_check_location_security( 'write' ) ) {
        return $self->_return_msg( [ 0,
            $self->_msg( 'Security violation. No rights to write to location [_1]', $self->files->Pathutils->get_current_path )
        ] );
    }
    my $archive = Dicole::Files::Archive->new;
    $archive->Files( $self->files );
    $self->_return_msg( $archive->uncompress );
}

sub zip {
    my ( $self, $paths ) = @_;

    my $filename = undef;
    unless ( ref( $paths ) eq 'ARRAY' ) {
        unless ( $self->_check_existence ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Location [_1] does not exist.',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        unless ( $self->_check_location_security( 'read' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Security violation. No rights to read location [_1]',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        $paths = [ $self->files->Pathutils->get_current_path ];
        $filename = $self->files->Pathutils->get_current_filename;
    }

    # check security for paths, discard paths for which the user
    # has no read access rights
    $paths = [
        grep { $self->_check_location_security( 'read', $_ ) } @{ $paths }
    ];

    my $strip_base_path = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->param( 'tree_id' ), 'base_path'
    ) || $self->param( 'base_path' );

    my $archive = Dicole::Files::Archive->new;
    $archive->Files( $self->files );

    return $archive->zip_files( $paths, $strip_base_path, $filename );
}

sub tar {
    my ( $self, $paths ) = @_;


    my $filename = undef;

    unless ( ref( $paths ) eq 'ARRAY' ) {
        unless ( $self->_check_existence ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Location [_1] does not exist.',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        unless ( $self->_check_location_security( 'read' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Security violation. No rights to read location [_1]',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        $paths = [ $self->files->Pathutils->get_current_path ];
        $filename = $self->files->Pathutils->get_current_filename;
    }

    # check security for paths, discard paths for which the user
    # has no read access rights
    $paths = [
        grep { $self->_check_location_security( 'read', $_ ) } @{ $paths }
    ];

    my $strip_base_path = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->param( 'tree_id' ), 'base_path'
    ) || $self->param( 'base_path' );

    my $archive = Dicole::Files::Archive->new;
    $archive->Files( $self->files );

    return $archive->tar_files( $paths, $strip_base_path, $filename );
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesArchive - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
