package OpenInteract2::Action::DicoleFilesView;

# $Id: DicoleFilesView.pm,v 1.10 2008-08-25 00:34:11 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );
use Dicole::Generictool;
use Dicole::Utility;
use Dicole::Viewer;
use Dicole::Content::Button;
use Unicode::MapUTF8;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

sub download {
    my ( $self ) = @_;
    unless ( $self->_check_existence ) {
#         return $self->_return_msg( [ 0, $self->_msg(
#             'Location [_1] does not exist.',
#             $self->files->Pathutils->get_current_path
#         ) ] );
        die 'security error';
    }
    unless ( $self->_check_location_security( 'read' ) ) {
        die 'security error';
    }
    return $self->files->download_file;
}

sub view {
    my ( $self ) = @_;
    unless ( $self->_check_existence ) {
#         return $self->_return_msg( [ 0, $self->_msg(
#             'Location [_1] does not exist.',
#             $self->files->Pathutils->get_current_path
#         ) ] );
        die 'security error';
    }
    my $file_ext = $self->files->Pathutils->get_current_filename;
    $file_ext =~ /.(\w+)$/;
    $file_ext = lc( $1 );
    my $extensions = Dicole::Utility->make_array(
        CTX->server_config->{dicole}{public_stream_extensions}
    );
    if ( !grep( { $_ eq $file_ext } @{ $extensions } ) && !$self->_check_location_security( 'read' ) ) {
        die 'security error';
    }
    return $self->files->download_file( 'mime' );
}

sub properties {
    my ( $self ) = @_;

    unless ( $self->_check_existence ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Location [_1] does not exist.',
            $self->files->Pathutils->get_current_path
        ) ] );
    }
    $self->init_tool( {
        tab_override => 'tree',
        rows         => 2
    } );

    my ( $sec_id, $sec_prefix, $level_name ) = $self->_get_sec_based_on_path(
        $self->files->Pathutils->get_current_path
    );
    unless ( $self->_check_location_security( 'read' ) ) {
        return $self->_return_msg( [ 0, $self->_msg(
            'Security violation. No rights to read location [_1]',
            $self->files->Pathutils->get_current_path
        ) ] );
    }

    $self->tool->Path->add( name => $self->_msg( 'Properties' ) );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'files' )
    ) );

    my $object = $self->_get_object_by_path;

    my @stat = $self->files->Fileops->stat;

    $self->init_fields( package => 'dicole_files', view => 'dc_fields' );

    # Set fields to views
    $self->gtool->set_fields_to_views(
        views => [qw( properties metadata )]
    );

    my $fields = [
        qw( file_name size loc_modified loc_format user_id )
    ];

    $self->gtool->add_field( id => 'file_name', type => 'text', desc => $self->_msg( 'Name' ),
        use_field_value => 1, value => $level_name || $self->files->Pathutils->get_current_filename
    );

    my ( $size, $count ) = $self->files->Fileops->size;

    if ( $count ) {
        $self->gtool->add_field( id => 'no_files', value => $count, type => 'text',
            desc => $self->_msg( 'Number of files' ), use_field_value => 1
        );
        push @{ $fields }, 'no_files';
    }

    $self->gtool->add_field( id => 'size', type => 'text', desc => $self->_msg( 'Size' ),
        use_field_value => 1, value => $self->files->human_readable( $size )
    );

    $self->gtool->add_field( id => 'loc_modified', type => 'date', desc => $self->_msg( 'Modified' ),
        date_format => 'epoch', use_field_value => 1, value => $stat[9], options => { show_time => 1 }
    );

    $self->gtool->add_field( id => 'loc_format', type => 'text',
        desc => $self->_msg( 'Type' ), use_field_value => 1,
        value => Dicole::Utils::Text->ensure_utf8( $self->files->mime_desc_file )
    );

    $self->gtool->add_field( id => 'user_id', type => 'text', desc => $self->_msg( 'Uploaded by' ),
        relation => 'user', relation_fields => [ 'first_name', 'last_name' ]
    );

    my $buttons = [];

    $self->gtool->visible_fields( 'properties', $fields );

    push @{ $buttons }, {
        type  => 'link',
        value => $self->_msg( 'Show file view' ),
        link  => $self->files->Pathutils->form_url( 'tree' )
    };

    unless ( $count ) {
        push @{ $buttons }, {
            type  => 'link',
            value => $self->_msg( 'Download' ),
            link  => $self->files->Pathutils->form_url( 'download' )
        };
        push @{ $buttons }, {
            type  => 'link',
            value => $self->_msg( 'Open' ),
            link  => $self->files->Pathutils->form_url( 'view' )
        };
        push @{ $buttons }, {
            type  => 'link',
            value => $self->_msg( 'View' ),
            link  => $self->files->Pathutils->form_url( 'viewer' )
        };
        push @{ $buttons }, {
            type  => 'link',
            value => $self->_msg( 'Rename' ),
            link  => $self->files->Pathutils->form_url( 'ren' )
        } if $self->mchk_y( 'OpenInteract2::Action::DicoleFiles', $sec_prefix . '_write', $sec_id );
    }

    $self->gtool->current_view( 'properties' );

    # Defines submit buttons for our tool
    $self->gtool->bottom_buttons( $buttons );

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Location: [_1]',
        $self->_get_path
    ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( object => $object )
    );

    $self->gtool->current_view( 'metadata' );

    # Metadata editing link
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit metadata' ),
        link  => $self->files->Pathutils->form_url( 'edit_dc' )
    ) if $self->mchk_y( 'OpenInteract2::Action::DicoleFiles', $sec_prefix . '_write', $sec_id );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Download RDF/XML metadata' ),
        link  => $self->files->Pathutils->form_url( 'view_dc' ) . '.rdf'
    );

    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Dublin Core metadata' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->gtool->get_show( object => $object )
    );

    #$self->gtool->current_view( 'license' );

    #$self->init_fields( package => 'dicole_files' );

    #$self->gtool->bottom_buttons( [ {
    #    type => 'link',
    #    value => $self->_msg( 'Select license' ),
    #    link => $self->files->Pathutils->form_url( 'edit_license' )
    #} ] );

    #$self->tool->Container->box_at( 0, 2 )->name( $self->_msg( 'License' ) );
    #$self->tool->Container->box_at( 0, 2 )->add_content(
    #    $self->gtool->get_show( object => $object )
    #);

    $self->generate_tool_content;
}

sub view_dc {
    my ( $self ) = @_;

    my $path = $self->files->Pathutils->get_current_path;
    $path =~ s/\.rdf$//;
    $self->files->path( $path );

    unless ( $self->_check_existence(
        $self->files->Pathutils->clean_path_name
    ) ) {
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

    my $object = $self->_get_object_by_path( $path );

    return $self->files->get_dc( $object );
}

sub viewer {
    my ( $self ) = @_;

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
    $self->init_tool( {
        tab_override => 'tree',
    } );

    $self->tool->Path->add( name => $self->_msg( 'View file' ) );

    my $content_array = Dicole::Viewer->viewer( $self->files );
    push @{ $content_array }, Dicole::Content::Button->new(
        type => 'link',
        value => $self->_msg( 'Show file view' ),
        link => $self->files->Pathutils->form_url( 'tree' )
    );

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Location: [_1]',
        $self->_get_path
    ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content_array );

    $self->generate_tool_content;

}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesView - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
