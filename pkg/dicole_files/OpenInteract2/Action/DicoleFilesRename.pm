package OpenInteract2::Action::DicoleFilesRename;

# $Id: DicoleFilesRename.pm,v 1.3 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Generictool::FakeObject;
use Dicole::Generictool;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub ren {
    my ( $self ) = @_;

    unless ( $self->_check_existence ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Location [_1] does not exist.',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    unless ( $self->_check_location_security( 'write' ) ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Security violation. No rights to write to location [_1]',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    $self->init_tool( {
        tab_override => 'tree',
    } );

    $self->tool->Path->add( name => $self->_msg( 'Rename location' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new( {
            id => 'new_name',
            new_name => $self->files->Pathutils->get_current_filename
        } )
    ] );
    $self->gtool->add_field( id => 'new_name', type => 'textfield', required => 1,
        desc => $self->_msg( 'Rename location' ),
    );

    # Set views
    $self->gtool->current_view( 'rename' );

    # Set fields to views
    $self->gtool->set_fields_to_views;

    # Defines submit buttons for our tool
    $self->gtool->bottom_buttons( [ {
            name  => 'save',
            value => $self->_msg( 'Save' ),
        }, {
            type  => 'link',
            value => $self->_msg( 'Show file view' ),
            link  => $self->files->Pathutils->form_url( 'tree' )
    } ] );

    if ( CTX->request->param( 'save' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );
        if ( $return_code ) {
            my $error = $self->_rename_location(
                CTX->request->param( 'new_name' ),
                undef,
                1
            );
            $self->_return_msg( $error );
        } else {
            $return = $self->_msg( "Renaming location failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Location: [_1]',
        $self->_get_path
    ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    $self->generate_tool_content;

}

sub _rename_location {
    my ( $self, $new_name, $old_path, $use_new_path ) = @_;

    # If called directly from another action, we have to init the
    # files object

    $self->custom_init;

    my $path = $self->files->Pathutils->path;
    $self->files->Pathutils->path( $old_path ) if $old_path;

    my $error = $self->files->rename_location( $new_name );

    if ( $error->[0] ) {
        my $current_path = $self->files->Pathutils->get_current_path;
        my $segments = $self->files->Pathutils->current_path_segments;
        $segments->[-1] = $self->files->Pathutils->clean_filename( $new_name );
        my $new_path = join '/', @{ $segments };
        my $objects = $self->_get_object_by_path( $current_path, 1, 1 );
        while ( $objects->has_next() ) {
            my $object = $objects->get_next;
            my $path = $object->{path};
            $path =~ s/$current_path/$new_path/;
            $object->{path} = $path;
            $object->save;
        }
        CTX->request->url_relative( '/' . join '/', (
            CTX->request->action_name,
            CTX->request->task_name,
            CTX->request->target_id,
            $new_path
        ) ) if $use_new_path;
    }
    $self->files->Pathutils->path( $path ) if $old_path;
    return $error;
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFiles - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
