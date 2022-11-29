package OpenInteract2::Action::DicoleMetadataEditor;

# $Id: DicoleMetadataEditor.pm,v 1.13 2009-01-07 14:42:33 amv Exp $

use strict;

use base ( 'Dicole::Action' );

use Dicole::Generictool;
use Dicole::Tool;
use Dicole::URL;
use Dicole::MessageHandler qw( :message );
use Dicole::Content::Controlbuttons;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

sub _init_tool {

    my $self = shift;

    $self->init_tool( { @_ } );

    my $p = {@_};

    $p->{view} ||= ( split '::', ( caller(1) )[3] )[-1];

    $self->gtool(
        Dicole::Generictool->new(
            object => $p->{object},
            skip_security => 1,
            current_view => $p->{view},
        )
    );

    $self->tool->add_tinymce_widgets;

    $self->init_fields( view => $p->{view} );
}

sub metadata_sets {
    my ( $self ) = @_;

    $self->_init_tool( object => CTX->lookup_object('metadata') );

    $self->tool->Path->add( name => $self->_msg( 'Show metadata sets' ) );

    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'metadata_fields',
        params => { id => 'IDVALUE' }
    ) );

    $self->gtool->Data->query_params( {
        where => 'groups_id = ? OR groups_id = ?',
        value => [ 0, $self->active_group ]
    } );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of global metadata sets' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

sub metadata_fields {
    my ( $self ) = @_;

    return unless $self->_check_if_metadata_exists(
        CTX->request->param( 'id' )
    );

    $self->_init_tool( object => CTX->lookup_object('metadata_fields') );

    $self->tool->Path->add( name => $self->_msg( 'Show metadata fields' ) );

    $self->gtool->Data->query_params( {
        where => 'metadata_id = ?',
        value => [ CTX->request->param( 'id' ) ]
    } );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of metadata fields' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

sub _check_if_metadata_exists {
    my ( $self, $metadata_id ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('metadata') );
    $data->query_params( {
        where => 'metadata_id = ? AND ( groups_id = ? OR groups_id = ? )',
        value => [ $metadata_id, $self->active_group, 0 ]
    } );
    $data->data_group;
    $data->data( $data->data->[0] );

    unless ( ref $data->data ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Metadata with id [_1] does not exist.', $metadata_id )
        );
        my $redirect = Dicole::URL->create_from_current(
            task => 'metadata_sets'
        );
        CTX->response->redirect( $redirect );
        return undef;
    }
    return $data;
}

sub _check_if_typeset_exists {
    my ( $self, $metadata_id ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('typesets') );
    $data->query_params( {
        where => 'typeset_id = ? AND ( groups_id = ? OR groups_id = ? )',
        value => [ $metadata_id, $self->active_group, 0 ]
    } );
    $data->data_group;
    $data->data( $data->data->[0] );

    unless ( ref $data->data ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Typeset with id [_1] does not exist.', $metadata_id )
        );
        my $redirect = Dicole::URL->create_from_current(
            task => 'type_sets'
        );
        CTX->response->redirect( $redirect );
        return undef;
    }
    return $data;
}

sub _redirect_to_main {
    my ( $self ) = @_;
    my $redirect = Dicole::URL->create_from_current(
        task => 'type_sets'
    );
    return CTX->response->redirect( $redirect );
}

sub type_sets {
    my ( $self ) = @_;

    $self->_init_tool(
        object => CTX->lookup_object('typesets'),
        rows => 2
    );

    $self->tool->Path->add( name => $self->_msg( 'Show type sets' ) );

    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'show_type_set',
        params => { id => 'IDVALUE' }
    ) );

    $self->gtool->Data->query_params( {
        where => 'groups_id = ?',
        value => [ 0 ]
    } );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of global type sets' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    if ( CTX->request->param( 'sel' ) ) {
        my ( $code, $message ) = $self->gtool->Data->remove_group( 'sel' );
        if ( $code ) {
            $message = $self->_msg( "Selected type sets removed." );
        }
        else {
            $message = $self->_msg( "Error during delete: [_1]", $message );
        }
        $self->tool->add_message( $code, $message );
    }

    $self->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->_msg( 'Remove selected type sets' ),
        confirm_box => {
            title => $self->_msg( 'Confirmation' ),
            name => 'sel',
            msg => $self->_msg( 'Are you sure you want to remove the selected type sets?' )
        }
    );

    $self->gtool->Data->query_params( {
        where => 'groups_id = ?',
        value => [ $self->active_group ]
    } );

    my $content = $self->gtool->get_sel( checkbox_id => 'sel' );

    my $buttons = Dicole::Content::Controlbuttons->new;
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Add type set' ),
        link  => Dicole::URL->create_from_current( task => 'add_type_set' )
    } );
    unshift @{ $content }, $buttons;

    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'List of custom type sets' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $content
    );

    return $self->generate_tool_content;
}

sub add_type_set {
    my ( $self ) = @_;

    $self->_init_tool(
        object => CTX->lookup_object('typesets'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Add type set' ) );

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );

    $self->gtool->add_bottom_button(
        name  => 'save_new',
        value => $self->_msg( 'Save and add new' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        link  => Dicole::URL->create_from_current( task => 'type_sets' ),
        value => $self->_msg( 'Show typesets' ),
    );

    if ( CTX->request->param( 'save' ) || CTX->request->param( 'save_new' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );

        if ( $code ) {
            my $data = $self->gtool->Data->data;
            $data->{machine_name} = $data->{title};
            $data->{machine_name} =~ tr/a-zA-Z0-9//cd;
            $data->{groups_id} = $self->active_group;
            $self->gtool->Data->data_save;
            $self->gtool->Data->clear_data_fields;
            $self->tool->add_message( $code,
                $self->_msg( "Type set has been saved." )
            );
            unless ( CTX->request->param( 'save_new' ) ) {
                my $redirect = Dicole::URL->create_from_current(
                    task => 'type_sets'
                );
                return CTX->response->redirect( $redirect );
            }
        }
        else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed adding type set: [_1]", $message )
            );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'New type set details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub show_type_set {
    my ( $self ) = @_;

    $self->_init_tool(
        object => CTX->lookup_object('typesets'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Show type set' ) );

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('typesets') );
    $data->data_single( CTX->request->param( 'id' ) );

    if ( $data->data->{groups_id} eq $self->active_group ) {
        $self->gtool->add_bottom_button(
            type  => 'link',
            value => $self->_msg( 'Edit' ),
            link  => Dicole::URL->create_from_current(
                task => 'edit_type_set',
                params => { id => 'IDVALUE' }
            )
        );
    }

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show types' ),
        link  => Dicole::URL->create_from_current(
            task => 'typeset_types',
            params => { id => 'IDVALUE' }
        )
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show type sets' ),
        link  => Dicole::URL->create_from_current(
            task => 'type_sets'
        )
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Type set details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( object => $data->data )
    );

    return $self->generate_tool_content;
}

sub edit_type_set {
    my ( $self ) = @_;

    my $typeset = $self->_check_if_typeset_exists( CTX->request->param( 'id' ) );
    return unless $typeset;

    return $self->_redirect_to_main unless $typeset->data->{groups_id};

    $self->_init_tool(
        object => CTX->lookup_object('typesets'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Edit type set' ) );

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        link  => Dicole::URL->create_from_current(
            task => 'show_type_set',
            params => { id => 'IDVALUE' }
        ),
        value => $self->_msg( 'Show type set details' ),
    );

    if ( CTX->request->param( 'save' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                object_id => CTX->request->param( 'id' ),
                no_save => 1
            }
        );
        if ( $code ) {
            my $data = $self->gtool->Data->data;
            $data->{machine_name} = $data->{title};
            $data->{machine_name} =~ tr/a-zA-Z0-9//cd;
            $self->gtool->Data->data_save;
            my $id = $self->gtool->Data->data->id;
            $self->gtool->Data->clear_data_fields;
            $self->tool->add_message( $code,
                $self->_msg( "Changes were saved." )
            );
            my $redirect = Dicole::URL->create_from_current(
                task => 'show_type_set',
                params => { id => $id }
            );
            return CTX->response->redirect( $redirect );
        }
        else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed editing type set: [_1]", $message )
            );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Edit type set details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( id => CTX->request->param( 'id' ) )
    );

    return $self->generate_tool_content;
}

sub typeset_types {
    my ( $self ) = @_;

    my $typeset = $self->_check_if_typeset_exists( CTX->request->param( 'id' ) );
    return unless $typeset;

    $self->_init_tool(
        object => CTX->lookup_object('typeset_types'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Show types' ) );

    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'show_type',
        params => { id => 'IDVALUE', tid => CTX->request->param( 'id' ) }
    ) );

    $self->gtool->Data->query_params( {
        where => 'typeset_id = ?',
        value => [ CTX->request->param( 'id' ) ]
    } );

    if ( $typeset->data->{groups_id} && CTX->request->param( 'sel' ) ) {
        my ( $code, $message ) = $self->gtool->Data->remove_group( 'sel' );
        if ( $code ) {
            $message = $self->_msg( "Selected types removed." );
        }
        else {
            $message = $self->_msg( "Error during delete: [_1]", $message );
        }
        $self->tool->add_message( $code, $message );
    }

    if ( $typeset->data->{groups_id} ) {
        $self->gtool->add_bottom_button(
            type  => 'confirm_submit',
            value => $self->_msg( 'Remove selected types' ),
            confirm_box => {
                title => $self->_msg( 'Confirmation' ),
                name => 'sel',
                msg => $self->_msg( 'Are you sure you want to remove the selected types?' )
            }
        );
    }

    my $content = $typeset->data->{groups_id}
        ? $self->gtool->get_sel( checkbox_id => 'sel' )
        : $self->gtool->get_list;

    my $buttons = Dicole::Content::Controlbuttons->new;
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Show type set details' ),
        link  => Dicole::URL->create_from_current(
            task => 'show_type_set',
            params => { id => CTX->request->param( 'id' ) }
        )
    } );

    if ( $typeset->data->{groups_id} ) {
        $buttons->add_buttons( {
            type  => 'link',
            value => $self->_msg( 'Add type' ),
            link  => Dicole::URL->create_from_current(
                task => 'add_type',
                params => { id => CTX->request->param( 'id' ) }
            )
        } );
    }
    unshift @{ $content }, $buttons;

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of types' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content );

    return $self->generate_tool_content;
}

sub add_type {
    my ( $self ) = @_;

    my $typeset = $self->_check_if_typeset_exists( CTX->request->param( 'id' ) );
    return unless $typeset;

    return $self->_redirect_to_main unless $typeset->data->{groups_id};

    $self->_init_tool(
        object => CTX->lookup_object('typeset_types'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Add type' ) );

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );

    $self->gtool->add_bottom_button(
        name  => 'save_new',
        value => $self->_msg( 'Save and add new' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        link  => Dicole::URL->create_from_current(
            task => 'typeset_types',
            params => { id => CTX->request->param( 'id' ) }
        ),
        value => $self->_msg( 'Show types' ),
    );

    if ( CTX->request->param( 'save' ) || CTX->request->param( 'save_new' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );
        if ( $code ) {
            my $data = $self->gtool->Data->data;
            $data->{typeset_id} = CTX->request->param( 'id' );
            $data->{type_id_string} = $data->{title};
            $data->{type_id_string} =~ tr/a-zA-Z0-9//cd;
            $self->gtool->Data->data_save;
            $self->gtool->Data->clear_data_fields;
            $self->tool->add_message( $code,
                $self->_msg( "Type has been saved." )
            );
            unless ( CTX->request->param( 'save_new' ) ) {
                my $redirect = Dicole::URL->create_from_current(
                    task => 'typeset_types',
                    params => { id => CTX->request->param( 'id' ) }
                );
                return CTX->response->redirect( $redirect );
            }
        }
        else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed adding type: [_1]", $message )
            );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'New type details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub show_type {
    my ( $self ) = @_;

    my $typeset = $self->_check_if_typeset_exists( CTX->request->param( 'tid' ) );
    return unless $typeset;

    $self->_init_tool(
        object => CTX->lookup_object('typeset_types'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Show type' ) );

    if ( $typeset->data->{groups_id} eq $self->active_group ) {
        $self->gtool->add_bottom_button(
            type  => 'link',
            value => $self->_msg( 'Edit' ),
            link  => Dicole::URL->create_from_current(
                task => 'edit_type',
                params => { id => 'IDVALUE', tid => CTX->request->param( 'tid' ) }
            )
        );
    }

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show types' ),
        link  => Dicole::URL->create_from_current(
            task => 'typeset_types',
            params => { id => CTX->request->param( 'tid' ) }
        )
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Type details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( id => CTX->request->param( 'id' ) )
    );

    return $self->generate_tool_content;
}

sub edit_type {
    my ( $self ) = @_;

    my $typeset = $self->_check_if_typeset_exists( CTX->request->param( 'tid' ) );
    return unless $typeset;

    return $self->_redirect_to_main unless $typeset->data->{groups_id};

    $self->_init_tool(
        object => CTX->lookup_object('typeset_types'),
        tab_override => 'type_sets'
    );

    $self->tool->Path->add( name => $self->_msg( 'Edit type' ) );

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        link  => Dicole::URL->create_from_current(
            task => 'show_type',
            params => { id => 'IDVALUE', tid => CTX->request->param( 'tid' ) }
        ),
        value => $self->_msg( 'Show type details' ),
    );

    if ( CTX->request->param( 'save' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                object_id => CTX->request->param( 'id' ),
                no_save => 1
            }
        );
        if ( $code ) {
            my $data = $self->gtool->Data->data;
            $data->{type_id_string} = $data->{title};
            $data->{type_id_string} =~ tr/a-zA-Z0-9//cd;
            $self->gtool->Data->data_save;
            my $id = $self->gtool->Data->data->id;
            $self->gtool->Data->clear_data_fields;
            $self->tool->add_message( $code,
                $self->_msg( "Changes were saved." )
            );
            my $redirect = Dicole::URL->create_from_current(
                task => 'show_type',
                params => { id => $id, tid => CTX->request->param( 'tid' ) }
            );
            return CTX->response->redirect( $redirect );
        }
        else {
            $self->tool->add_message( $code,
                $self->_msg( "Failed editing type: [_1]", $message )
            );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Edit type details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( id => CTX->request->param( 'id' ) )
    );

    return $self->generate_tool_content;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleUserManager - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
