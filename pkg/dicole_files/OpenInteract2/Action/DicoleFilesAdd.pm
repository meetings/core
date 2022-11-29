package OpenInteract2::Action::DicoleFilesAdd;

# $Id: DicoleFilesAdd.pm,v 1.3 2009-01-07 14:42:33 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Generictool::FakeObject;
use Dicole::Generictool;
use Dicole::URL;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

sub upload {
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
    $self->init_tool( {
        tab_override => 'tree',
        upload => 1
    } );

    $self->tool->Path->add( name => $self->_msg( 'Upload new file' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'file_name' }
        )
    ] );
    $self->gtool->add_field(
        id  => 'file_name', type => 'file',
        required => 1, desc => $self->_msg( 'File to upload' )
    );
    $self->gtool->add_field(
        id  => 'edit_metadata', type => 'checkbox',
        desc => $self->_msg( 'Edit metadata after upload' )
    );

    # Set views
    $self->gtool->current_view( 'upload_file' );

    # Set fields to views
    $self->gtool->set_fields_to_views;

    # Defines submit buttons for our tool
    $self->gtool->bottom_buttons( [ {
            name  => 'upload',
            value => $self->_msg( 'Upload' ),
        }, {
            type  => 'link',
            value => $self->_msg( 'Show file view' ),
            link  => $self->files->Pathutils->form_url( 'tree' )
    } ] );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );
        if ( $return_code ) {
            my $msg = $self->files->upload_file( 'file_name' );
            if ( $msg->[0] ) {
                my $new_path = $self->_rewrite_relative_path(
                    CTX->request->upload( 'file_name' )->filename
                );
                $self->_create_default_object( $new_path );
                if ( CTX->request->param('edit_metadata') ) {
                    return $self->_return_msg( $msg, undef, 'edit_dc' );
                }
            }
            $self->_return_msg( $msg );
        } else {
            $return = $self->_msg( "Upload failed: [_1]", $return );
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

sub _rewrite_relative_path {
    my ( $self, $path_last ) = @_;
    my $new_path = $self->files->Pathutils->get_current_path . '/' . $path_last;
    CTX->request->url_relative( Dicole::URL->create_from_current(
        other => [ ( split '/', $new_path ) ]
    ) );
    return $new_path;
}

sub _create_default_object {
    my ( $self, $path, $is_folder ) = @_;

    my $object = CTX->lookup_object( 'files' )->new;

    $object->{path} = $path || $self->files->Pathutils->get_current_path;
    if ( $path ) {
        $object->{title} = ( split '/', $path )[-1];
    }
    else {
        my ( undef, undef, $level_name ) = $self->_get_sec_based_on_path(
            $object->{path}
        );
        $object->{title} = $level_name || $self->files->Pathutils->get_current_filename;
    }
    my ( $size ) = $self->files->Fileops->size( $path );
    $object->{size} = $size;

    $object->{is_folder} = $is_folder || $self->files->Fileops->if_dir;
    $object->{is_folder} = 0 unless $object->{is_folder};

    my @stat = $self->files->Fileops->stat( $path );
    $object->{created} = $stat[9];
    $object->{modified} = $stat[9];
    $object->{date} = $stat[9];

    $object->{creator} = CTX->request->auth_user->{first_name}
        . ' ' . CTX->request->auth_user->{last_name};

    $object->{user_id} = CTX->request->auth_user_id;

    my $mime = $self->files->mime_type_file(
        $path || $self->files->Pathutils->get_current_path, 1
    );
    $object->{format} = $mime;

    # Guess DCMI type by mime type
    if ( $mime =~ /^image/ ) {
        $object->{type} = 'Image';
    }
    elsif ( $mime eq 'application/x-gzip'
        || $mime eq 'application/x-tar'
        || $mime =~ /compressed/ ) {
        $object->{type} = 'Collection';
    }
    elsif ( $mime =~ /^application/ ) {
        $object->{type} = 'Software';
    }
    elsif ( $mime =~ /^audio/ ) {
        $object->{type} = 'Sound';
    }
    elsif ( $mime =~ /^video/ ) {
        $object->{type} = 'MovingImage';
    }
    elsif ( $mime =~ /^multipart/ ) {
        $object->{type} = 'Dataset';
    }

    my $url = $self->files->Pathutils->get_server_url
        . Dicole::URL->create_from_current(
              task => 'view',
              other => [ split '/',
                  $path || $self->files->Pathutils->get_current_path
              ],
          );

    $object->{identifier} = $url;
    $object->{source} = $url;

    $object->save;

    return $object;
}

sub new_folder {
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
    $self->init_tool( {
        tab_override => 'tree',
    } );

    $self->tool->Path->add( name => $self->_msg( 'Add new folder' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'folder_name' }
        )
    ] );
    $self->gtool->add_field( id => 'folder_name', type => 'textfield',
        required => 1, desc => $self->_msg( 'Folder name' ) );

    $self->gtool->add_field(
        id  => 'edit_metadata', type => 'checkbox',
        desc => $self->_msg( 'Edit metadata after save' )
    );

    # Set fields to views
    $self->gtool->set_fields_to_views( views => ['new_folder'] );

    $self->gtool->current_view( 'new_folder' );

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
            my $msg = $self->files->create_new_dir(
                CTX->request->param( 'folder_name' )
            );
            if ( $msg->[0] ) {
                my $new_path = $self->_rewrite_relative_path(
                    CTX->request->param( 'folder_name' )
                );
                $self->_create_default_object( $new_path, 1 );
                if ( CTX->request->param('edit_metadata') ) {
                    return $self->_return_msg( $msg, undef, 'edit_dc' );
                }
            }
            $self->_return_msg( $msg );
        } else {
            $return = $self->_msg( "Adding folder failed: [_1]", $return );
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

sub new_doc {
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
    $self->init_tool( {
        tab_override => 'tree',
    } );

    $self->tool->add_tinymce_widgets;

    $self->tool->Path->add( name => $self->_msg( 'Add new document' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'doc_name' }
        )
    ] );
    $self->gtool->add_field( id => 'doc_name', type => 'textfield', required => 1,
        desc => $self->_msg( 'Document name' ),
    );
    CTX->controller->add_content_param( 'htmlarea', 1 );
    $self->gtool->add_field( id => 'doc_content', type => 'textarea',
        desc => $self->_msg( 'Document content' ), options => {
            attributes => { rows => 25, cols => 80 },
            htmlarea => 1, htmlarea_fullpage => 1 }
    );
    $self->gtool->add_field(
        id  => 'edit_metadata', type => 'checkbox',
         desc => $self->_msg( 'Edit metadata after save' )
    );

    $self->gtool->current_view( 'new_doc' );

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
            my $msg = $self->files->create_new_doc(
                CTX->request->param( 'doc_name' ),
                CTX->request->param( 'doc_content' )
            );
            if ( $msg->[0] ) {
               my $new_path = $self->_rewrite_relative_path(
                    CTX->request->param( 'doc_name' )
                );
                $self->_create_default_object( $new_path );
                if ( CTX->request->param('edit_metadata') ) {
                    return $self->_return_msg( $msg, undef, 'edit_dc' );
                }
            }
            $self->_return_msg( $msg );
        } else {
            $return = $self->_msg( "Adding document failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Location: [_1]', $self->_get_path )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    $self->generate_tool_content;
}

sub new_url {
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
    $self->init_tool( {
        tab_override => 'tree',
    } );

    $self->tool->Path->add( name => $self->_msg( 'Add new hyperlink' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    my $fake_obj = Dicole::Generictool::FakeObject->new( { id => 'url_name' } );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [ $fake_obj ] );
    $self->gtool->add_field( id => 'url_name', type => 'textfield', required => 1,
        desc => $self->_msg( 'Hyperlink name' ),
    );
    $self->gtool->add_field( id => 'url_content', type => 'textfield', required => 1,
        desc => $self->_msg( 'Hyperlink location' ),
    );
    $self->gtool->add_field(
        id  => 'edit_metadata', type => 'checkbox',
        desc => $self->_msg( 'Edit metadata after save' )
    );

    $fake_obj->{url_content} ||= 'http://';

    # Set views
    $self->gtool->current_view( 'new_url' );

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
            my $msg = $self->files->create_new_doc(
                CTX->request->param( 'url_name' ) . '.url',
                CTX->request->param( 'url_content' )
            );
            if ( $msg->[0] ) {
               my $new_path = $self->_rewrite_relative_path(
                    CTX->request->param( 'url_name' ) . '.url'
                );
                $self->_create_default_object( $new_path );
                if ( CTX->request->param('edit_metadata') ) {
                    return $self->_return_msg( $msg, undef, 'edit_dc' );
                }
            }
            $self->_return_msg( $msg );
        } else {
            $return = $self->_msg( "Adding hyperlink failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Location: [_1]', $self->_get_path
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

OpenInteract2::Action::DicoleFilesAdd - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
