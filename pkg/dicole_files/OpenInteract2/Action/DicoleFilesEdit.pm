package OpenInteract2::Action::DicoleFilesEdit;

# $Id: DicoleFilesEdit.pm,v 1.3 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::URL;
use Dicole::Generictool::FakeObject;
use Dicole::Generictool;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub edit_dc {
    my ( $self ) = @_;

    unless ( $self->_check_existence ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Location [_1] does not exist.',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    unless ( defined $self->_check_location_security( 'write' ) ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Security violation. No rights to write to location [_1]',
            $self->files->Pathutils->get_current_path
        ) ] );
    }

    $self->init_tool( {
        tab_override => 'tree',
        upload       => 1
    } );

    $self->tool->Path->add( name => $self->_msg( 'Edit Dublin Core metadata' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'files' ),
        current_view => 'dc_fields'
    ) );

    # Initializes fields for our generictool object
    $self->init_fields( package => 'dicole_files' );

    # Defines submit buttons for our tool
    $self->gtool->bottom_buttons( [ {
            name  => 'save',
            value => $self->_msg( 'Save' ),
        }, {
            type  => 'link',
            value => $self->_msg( 'Cancel' ),
            link  => $self->files->Pathutils->form_url( 'properties' )
    } ] );

    my $object = $self->_get_object_by_path;

    if ( CTX->request->param( 'save' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $object }
        );
        if ( $return_code ) {
            $self->tool->add_message( $return_code, $self->_msg( 'Changes saved.' ) );
            my $redirect = Dicole::URL->create_full_from_current(
                task => 'properties',
            );
            return CTX->response->redirect( $redirect );
        } else {
            $return = $self->_msg( "Saving changes failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Location: [_1]',
        $self->_get_path
    ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $object )
    );

    $self->generate_tool_content;
}

sub edit {
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

    $self->tool->Path->add( name => $self->_msg( 'Edit file' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new( {
            id => 'new_content',
            new_content => $self->files->get_file_contents
        } )
    ] );

    my $ctype = $self->files->mime_type_file;

    if ( $ctype eq 'wwwserver/redirection' ) {
        $self->gtool->add_field( id => 'new_content', type => 'textfield',
            desc => $self->_msg( 'Hyperlink location' ),
        );
    }
    else {

        $self->tool->add_tinymce_widgets;

        CTX->controller->add_content_param( 'htmlarea', 1 );
        $self->gtool->add_field(
            id => 'new_content',
            type => 'textarea',
            desc => $self->_msg( 'Edit content' ),
            options => {
                attributes => { rows => 25, cols => 80 },
                htmlarea => 1,
                htmlarea_fullpage => 1
            }
        );
    }

    # Set views
    $self->gtool->current_view( 'edit' );

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

            my $return = $self->files->set_file_contents(
                CTX->request->param( 'new_content' ),
            );
            if ( $ctype eq 'wwwserver/redirection' ) {
                $self->_return_msg( $return );
            }
            else {
                $self->tool->add_message( @{ $return } );
            }
        } else {
            $return = $self->_msg( "Modifying file failed: [_1]", $return );
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

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesEdit - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
