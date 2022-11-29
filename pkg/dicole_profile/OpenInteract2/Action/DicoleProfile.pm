package OpenInteract2::Action::DicoleProfile;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Generictool;
use Dicole::Generictool::Data;
use Dicole::Content::Text;
use Dicole::Content::Button;
use DateTime::TimeZone;
use Geography::Countries;
use Dicole::Pathutils;
use Dicole::URL;
use Image::Magick;
use Dicole::Pathutils;
use Dicole::MessageHandler qw( :message );
use Dicole::Files::Filesystem;
use Dicole::Box;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.67 $ =~ /(\d+)\.(\d+)/);

use constant MAX_IMAGE_SIZE => 240;
use constant MAX_THUMB_SIZE => 64;

sub summary {
    my ( $self ) = @_;
    my $box = Dicole::Box->new();
    $box->name( $self->_msg( 'Welcome!' ) );

    my $welcome = Dicole::Content::Text->new;
    $welcome->no_filter( 1 );
    my $user = CTX->request->auth_user;

    my $name = '<b>' . "$user->{first_name} $user->{last_name}" . '</b>';
    my $date = '<i>' . Dicole::DateTime->long_date_format( time ) . '</i>';
    my $time = '<i>' . Dicole::DateTime->long_time_format( time ) . '</i>';

    $welcome->text(
        $self->_msg( "Welcome [_1]! Today is [_2] and the time is [_3].", $name, $date, $time )
    );

    $box->content( $welcome );

    return $box->output;
}

# A task for displaying user objects
sub professional {
    my ( $self ) = @_;

    $self->_init_tool( cols => 2, rows => 4 );

    my $profile = $self->_get_profile;

    # Tell gtool to skip construction of fields that are empty.
    # We limit the ammount of fields displayed in the profile
    # pages by this way.
    $self->gtool->Construct->undef_if_empty( 1 );

    # Basic information
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Basic information' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Organization
    $self->gtool->current_view( 'professional_organization' );
    $self->init_fields( view => 'professional_organization' );
    $self->_generate_countries( 'country' );
    $self->tool->Container->box_at( 1, 1 )->name(
        $self->_msg( 'Organization' )
    );
    $self->tool->Container->box_at( 1, 1 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Professional history
    $self->gtool->current_view( 'professional_history' );
    $self->init_fields( view => 'professional_history' );
    $self->tool->Container->box_at( 1, 2 )->name(
        $self->_msg( 'Professional history' )
    );
    $self->tool->Container->box_at( 1, 2 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Professional description
    $self->gtool->current_view( 'professional_description' );
    $self->init_fields( view => 'professional_description' );
    $self->tool->Container->box_at( 1, 3 )->name(
        $self->_msg( 'Professional description' )
    );
    # Profile editing button
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_professional'
        )
    ) if $self->chk_y( 'write' );
    $self->tool->Container->box_at( 1, 3 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    $self->gtool->Construct->undef_if_empty( 0 );

    $self->gtool->current_view( 'image_profile' );
    # Intialize fields from fields.ini
    $self->gtool->clear_fields;
    $self->init_fields;

    $self->gtool->get_field( 'image' )->object_field( 'pro_image' );

    # Portrait
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Professional portrait' )
    );
    # Profile editing button
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Upload image' ),
        link  => Dicole::URL->create_from_current(
            task => 'upload_image',
            other => [ 'pro' ]
        )
    ) if $self->chk_y( 'write' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( object => $profile, no_keys => 1 )
    );

    return $self->generate_tool_content;
}

sub upload_image {
    my ( $self ) = @_;

    my $return_task = 'personal';
    my $image_url_field = 'personal_image';
    my $path = Dicole::Pathutils->new;
    $path->url_base_path( CTX->request->target_id );
    if ( $path->current_path_segments->[0] eq 'pro' ) {
        $return_task = 'professional';
        $image_url_field = 'pro_image';
    }

    $self->_init_tool( rows => 1, upload => 1, tab_override => $return_task );

    my $profile = $self->_get_profile;

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'upload_image' }
        )
    ] );

    # Basic information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Image to upload in GIF or JPG format' )
    );

    # Defines submit buttons for our tool
    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' )
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show profile' ),
        link  => Dicole::URL->create_from_current(
            task => $return_task
        )
    );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );
        if ( $return_code ) {
            my $upload_obj = CTX->request->upload( 'upload_image' );
            if ( ref( $upload_obj ) ) {

                my $fh = $upload_obj->filehandle;
                my $files = Dicole::Files::Filesystem->new;
                my $new_filename = CTX->request->auth_user_id
                    . '_' . $return_task . '_original';
                $files->mkfile(
                    $new_filename,
                    $fh, 1,
                    CTX->lookup_directory( 'dicole_profilepics' )
                );

                # Write image in the users profile picture directory
                # along with a thumbnail
                my $image = $self->_create_profile_images(
                    CTX->lookup_directory( 'dicole_profilepics' ) . '/' . $new_filename,
                    $return_task
                );
                if ( $image ) {
                    # Create web page URL
                    my $html = CTX->lookup_directory( 'html' );
                    my $path = CTX->lookup_directory( 'dicole_profilepics' );
                    $path =~ s/^$html//;

                    # Save URL in the profile
                    $profile->{$image_url_field} = $path . '/' . $image;
                    $profile->save;

                    $self->tool->add_message( MESSAGE_SUCCESS,
                        $self->_msg( "Image uploaded." )
                    );
                    return CTX->response->redirect(
                        Dicole::URL->create_from_current(
                            task => $return_task
                        )
                    );
                }
                else {
                    $self->tool->add_message( MESSAGE_ERROR,
                        $self->_msg( "Error while converting image." )
                    );
                }
            }
            else {
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg( "Error while uploading file. Upload does not exist." )
                );
            }
        } else {
            $return = $self->_msg( "Upload failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub _create_profile_images {
    my ( $self, $src, $type ) = @_;

    my $path = CTX->lookup_directory( 'dicole_profilepics' );

    my $image = Image::Magick->new;
    my $resized_image = $image->Read( $src );
    return undef if $self->_check_magick_error( $resized_image );
    my $i_width = $image->Get( 'width' );
    my $i_height = $image->Get( 'height' );

    if ($i_width > MAX_IMAGE_SIZE ) {
        $i_height = int( $i_height * MAX_IMAGE_SIZE / $i_width );
        $i_width = MAX_IMAGE_SIZE;
    }
    if ( $i_height > MAX_IMAGE_SIZE ) {
        $i_width = int( $i_width * MAX_IMAGE_SIZE / $i_height );
        $i_height = MAX_IMAGE_SIZE;
    }
    $resized_image = $image->Scale( width => $i_width, height => $i_height );
    return undef if $self->_check_magick_error( $resized_image );
    my $filename = CTX->request->auth_user_id . '_' . $type . '.jpg';

    # TODO:: Cross-platform?
    if ( -e $path . '/' . $filename ) {
        unlink( $path . '/' . $filename );
    }

    $resized_image = $image->Write( $path . '/' . $filename );
    return undef if $self->_check_magick_error( $resized_image );

    if ($i_width > MAX_THUMB_SIZE ) {
        $i_height = int( $i_height * MAX_THUMB_SIZE / $i_width );
        $i_width = MAX_THUMB_SIZE;
    }
    if ( $i_height > MAX_THUMB_SIZE ) {
        $i_width = int( $i_width * MAX_THUMB_SIZE / $i_height );
        $i_height = MAX_THUMB_SIZE;
    }
    $resized_image = $image->Scale( width => $i_width, height => $i_height );
    return undef if $self->_check_magick_error($resized_image);
    my $t_filename = CTX->request->auth_user_id . '_' . $type . '_t.jpg';
    # TODO:: Cross-platform?
    if ( -e $path . '/' . $t_filename ) {
        unlink( $path . '/' . $t_filename );
    }
    $resized_image = $image->Write( $path . '/' . $t_filename );
    return undef if $self->_check_magick_error( $resized_image );

    return $filename;
}

sub _check_magick_error {
    my ( $self, $error ) = @_;
    return undef unless $error;
    $error =~ /(\d+)/;
    # Status code less than 400 is a warning
    $self->log( 'error',
        "Image::Magick returned status $error while resizing profile image"
    );
    if ( $1 >= 400 ) {
        return 1;
    }
    return undef;
}

sub personal {
    my ( $self ) = @_;

    $self->_init_tool( cols => 2, rows => 3 );

    my $profile = $self->_get_profile;

    # Tell gtool to skip construction of fields that are empty.
    # We limit the ammount of fields displayed in the profile
    # pages by this way.
    $self->gtool->Construct->undef_if_empty( 1 );

    # Basic information
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Basic information' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Personal education
    $self->gtool->current_view( 'personal_education' );
    $self->init_fields( view => 'personal_education' );
    $self->tool->Container->box_at( 1, 1 )->name(
        $self->_msg( 'Education' )
    );
    $self->tool->Container->box_at( 1, 1 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Personal description
    $self->gtool->current_view( 'personal_description' );
    $self->init_fields( view => 'personal_description' );
    # Profile editing button
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_personal'
        )
    ) if $self->chk_y( 'write' );
    $self->tool->Container->box_at( 1, 2 )->name(
        $self->_msg( 'Personal description' )
    );
    $self->tool->Container->box_at( 1, 2 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    $self->gtool->Construct->undef_if_empty( 0 );

    $self->gtool->current_view( 'image_profile' );
    # Intialize fields from fields.ini
    $self->gtool->clear_fields;
    $self->init_fields;

    $self->gtool->get_field( 'image' )->object_field( 'personal_image' );

    # Portrait
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Personal portrait' )
    );
    # Profile editing button
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Upload image' ),
        link  => Dicole::URL->create_from_current(
            task => 'upload_image',
            other => [ 'personal' ]
        )
    ) if $self->chk_y( 'write' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( object => $profile, no_keys => 1 )
    );

    return $self->generate_tool_content;
}

sub contact {
    my ( $self ) = @_;

    $self->_init_tool( rows => 4 );

    my $profile = $self->_get_profile;

    # Fill timezone dropdown with items
    $self->_generate_timezones;

    # Tell gtool to skip construction of fields that are empty.
    # We limit the ammount of fields displayed in the profile
    # pages by this way.
    $self->gtool->Construct->undef_if_empty( 1 );

    # Basic contact information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Basic contact information' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Phone contact information
    $self->gtool->current_view( 'contact_phone' );
    $self->init_fields( view => 'contact_phone' );
    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Phone' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    # Address information
    $self->gtool->current_view( 'contact_address' );
    $self->init_fields( view => 'contact_address' );
    $self->_generate_countries( 'home_country' );
    # Editing button
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_contact'
        )
    ) if $self->chk_y( 'write' );
    $self->tool->Container->box_at( 0, 2 )->name(
        $self->_msg( 'Address' )
    );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        $self->_check_avail( $self->gtool->get_show( object => $profile ) )
    );

    $self->_add_user_groups( 0, 3 );

    return $self->generate_tool_content;
}

sub edit_personal {
    my ( $self ) = @_;

    $self->_init_tool(
        tab_override => 'personal',
        view => 'personal',
        rows => 3
    );

    my $profile = $self->_get_profile;

    # Basic information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Basic information' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Personal education
    $self->gtool->current_view( 'personal_education' );
    $self->init_fields( view => 'personal_education' );
    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Education' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Personal description
    $self->gtool->current_view( 'personal_description' );
    $self->init_fields( view => 'personal_description' );
    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current( task => 'personal' )
    );
    $self->tool->Container->box_at( 0, 2 )->name(
        $self->_msg( 'Personal description' )
    );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    $self->gtool->set_fields_to_views;

    # If save button is pressed...
    if ( CTX->request->param( 'save' ) ) {
        # Check validity of fields. If ok, save to $profile object.
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $profile }
        );
        # Add status message and redirect to appropriate location
        if ( $code ) {
            $self->tool->add_message( $code, $self->_msg( "Changes were saved." ) );
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'personal'
                )
            );
        } else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed modifying profile: [_1]", $message )
            );
        }
    }

    return $self->generate_tool_content;
}

sub edit_professional {
    my ( $self ) = @_;

    my $profile = $self->_get_profile;

    $self->_init_tool(
        tab_override => 'professional',
        view => 'professional',
        rows => 4
    );

    # Basic information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Basic information' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Professional organization
    $self->gtool->current_view( 'professional_organization' );
    $self->init_fields( view => 'professional_organization' );
    $self->_generate_countries( 'country' );
    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Organization' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Professional history
    $self->gtool->current_view( 'professional_history' );
    $self->init_fields( view => 'professional_history' );
    $self->tool->Container->box_at( 0, 2 )->name(
        $self->_msg( 'Professional history' )
    );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Professional description
    $self->gtool->current_view( 'professional_description' );
    $self->init_fields( view => 'professional_description' );
    $self->tool->Container->box_at( 0, 3 )->name(
        $self->_msg( 'Professional description' )
    );
    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current( task => 'professional' )
    );
    $self->tool->Container->box_at( 0, 3 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    $self->gtool->set_fields_to_views;

    # If save button is pressed...
    if ( CTX->request->param( 'save' ) ) {
        # Check validity of fields. Save if ok.
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $profile }
        );
        # Set status message and redirect to appropriate location
        if ( $code ) {
            $self->tool->add_message( $code, $self->_msg( "Changes were saved." ) );
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'professional'
                )
            );
        } else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed modifying profile: [_1]", $message )
            );
        }
    }

    return $self->generate_tool_content;
}

sub edit_contact {
    my ( $self ) = @_;

    $self->_init_tool(
        tab_override => 'contact',
        view => 'contact',
        rows => 3
    );

    my $profile = $self->_get_profile;

    # Fill timezone dropdown with items
    $self->_generate_timezones;

    # Basic contact information
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Basic contact information' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Phone contact information
    $self->gtool->current_view( 'contact_phone' );
    $self->init_fields( view => 'contact_phone' );
    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Phone' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    # Address information
    $self->gtool->current_view( 'contact_address' );
    $self->init_fields( view => 'contact_address' );
    $self->_generate_countries( 'home_country' );
    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current( task => 'contact' )
    );
    $self->tool->Container->box_at( 0, 2 )->name(
        $self->_msg( 'Address' )
    );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        $self->gtool->get_edit( object => $profile )
    );

    $self->gtool->set_fields_to_views;

    # if save button is pressed...
    if ( CTX->request->param( 'save' ) ) {
        # Check validity of fields. Save if ok.
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $profile }
        );
        # Set status message and redirect to appropriate location
        if ( $code ) {
            $self->tool->add_message( $code, $self->_msg( "Changes were saved." ) );
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'contact'
                )
            );
        } else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed modifying profile: [_1]", $message )
            );
        }
    }

    return $self->generate_tool_content;
}

# Initialize tool
sub _init_tool {
    my $self = shift;
    my $p = { @_ };
    $self->init_tool( $p );
    # determine current view
    my $view = $p->{view} || ( split '::', ( caller(1) )[3] )[-1];
    # Initialize generictool
    my $generictool = $p->{gtool} || Dicole::Generictool->new(
        object => CTX->lookup_object('profile'),
        skip_security => 1,
        current_view => $view,
    );
    $self->gtool( $generictool );
    # Intialize fields from fields.ini
    $self->init_fields;

    $self->_set_tool_name;
}

# Retrieves users profile object or creates
# a one if it does not exist.
sub _get_profile {
    my ( $self, $user_id ) = @_;
    $user_id ||= CTX->request->target_user_id;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('profile') );
    $data->query_params( {
        where => 'user_id = ?',
        value => [ $user_id ]
    } );
    $data->data_group;
    $data->data( $data->data->[0] );
    if ( !ref( $data->data) || ref( $data->data ) eq 'ARRAY' ) {
        $data->data_new( 1 );
        $data->data->{user_id} = $user_id;
        $data->data_save if $user_id && $user_id =~ /^\d+$/;
    }
    return $data->data;
}

sub _set_tool_name {
    my ( $self, $user_id ) = @_;
    $user_id ||= CTX->request->target_user_id;
    my $user = CTX->lookup_object('user')->fetch( $user_id );
    if ( $user ) {
        my $name = $self->tool->tool_name;
        $self->tool->tool_name(
            $name . ' - ' . $user->first_name . ' ' .$user->last_name
        );
    }
}

sub _add_user_groups {
    my ( $self, $x, $y ) = @_;

    my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
        from => [ qw(dicole_groups dicole_group_user) ],
        where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
            . 'AND dicole_group_user.user_id = ?',
        value => [ $self->param('target_user_id') ],
        order => 'dicole_groups.name'
    } ) || [];

    my @domain_groups = ();

    eval {
        my $ids = CTX->lookup_action( 'dicole_domains' )
            ->execute( 'groups_by_domain' );
        my %idcheck = map { $_ => 1 } @$ids;
        for ( @$groups ) {
            push @domain_groups, $_ if $idcheck{ $_->id };
        }
    };

    if ( $@ ) {
        @domain_groups = @$groups;
    }

    my @visible_groups = ();

    # this needs to be fixed to hide groups below hidden groups
    for (@domain_groups) {
        push @visible_groups, $_ if $self->mchk_y(
            'OpenInteract2::Action::Groups',
            'show_info',
            $_->id,
        );
    }

    my $old_gtool = $self->gtool;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'groups' ),
        current_view => 'user_groups',
    ) );
    $self->init_fields;

    $self->tool->Container->box_at( $x, $y )->name(
        $self->_msg( 'Groups user belongs to' )
    );
    $self->tool->Container->box_at( $x, $y )->add_content(
        $self->gtool->get_list( objects => \@visible_groups )
    );

    $self->gtool( $old_gtool );
}

# Checks if a container contains any filled fields.
# If not, replace with "not available" text.
sub _check_avail {
    my ( $self, $content ) = @_;

    # If list contains no elements, replace the list content
    # object with a text element
    unless ( $content->[0]->get_content_count ) {
        $content->[0] = Dicole::Content::Text->new(
            text => $self->_msg( 'Not available.' )
        );
    }

    return $content;
}

# Generates timezone selection dropdown
sub _generate_timezones {
    my ( $self ) = @_;
    my $timezone = $self->gtool->get_field( 'timezone' );
    $timezone->add_dropdown_item( '', $self->_msg( '-- Select --' ) );
    foreach my $zone ( @{ DateTime::TimeZone->all_names } ) {
        $timezone->add_dropdown_item( $zone, $zone );
    }
}

# Generates countries selection dropdown
sub _generate_countries {
    my ( $self, $field ) = @_;
    my $country = $self->gtool->get_field( $field );
    my @countries = Geography::Countries::countries;
    $country->add_dropdown_item( '', $self->_msg( '-- Select --' ) );
    foreach my $c ( @countries ) {
        my @result = Geography::Countries::country( $c );
        $country->add_dropdown_item( $result[1], $c );
    }
}

=pod

=head1 NAME

Personal profile

=head1 DESCRIPTION

No description.

=head1 BUGS

None known.

=head1 AUTHORS

Teemu Arina

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;
