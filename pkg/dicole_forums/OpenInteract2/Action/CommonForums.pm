package OpenInteract2::Action::CommonForums;

use strict;

use base qw( Class::Accessor );
use OpenInteract2::Context   qw( CTX );
use Dicole::URL;
use Dicole::Generictool::Data;
use Dicole::MessageHandler qw( :message );
use Dicole::Content::Controlbuttons;

__PACKAGE__->mk_accessors( qw(
    forum
) );

sub forums {
    my ( $self ) = @_;

    $self->_init_tool( object => CTX->lookup_object('forums') );

    $self->_category_dropdown;
    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'threads',
        params => { id => 'IDVALUE' }
    ) );

    $self->gtool->Data->query_params( {
        where => 'groups_id = ?',
        order => 'title ASC',
        value => [ CTX->request->target_group_id ]
    } );

    my $unread = [];
    if ( CTX->request->auth_user_id ) {
        $unread = CTX->lookup_object('forums_messages_unread')->fetch_group({
            where => 'user_id = ? AND groups_id = ?',
            value => [CTX->request->auth_user_id, CTX->request->target_group_id],
        }) || [];
    }
    
    my %unread_by_forum_id = ();
    for my $unread_item ( @$unread ) {
        push @{$unread_by_forum_id{$unread_item->forum_id}}, $unread_item;
    };

    my $data = $self->gtool->Data->data_group || [];
    for my $forum ( @$data ) {
        if (my $array = $unread_by_forum_id{$forum->id}) {
            $forum->{unread} = scalar(@$array);
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of forums' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list(
            objects => $data,
        )
    );

    return $self->generate_tool_content;
}

# FIXME: test if this really checks if a forum exists
sub _check_if_forum_exists {
    my ( $self, $forum_id, $task ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums') );
    $data->query_params( {
        where => 'forum_id = ? and groups_id = ?',
        value => [ $forum_id, CTX->request->target_group_id ]
    } );
    $data->data_group;

    $data->data( $data->data->[0] );
    if ( !ref( $data->data) || ref( $data->data ) eq 'ARRAY' ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Forum with id [_1] does not exist.', $forum_id )
        );
        my $redirect = Dicole::URL->create_from_current(
            task => $task || 'forums'
        );
        CTX->response->redirect( $redirect );
        return undef;
    }
    $self->forum( $data );
    return $data;
}

sub manage_forums {
    my ( $self ) = @_;

    $self->_init_tool(
        view => 'forums',
        object => CTX->lookup_object('forums')
    );

    $self->_category_dropdown;

    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'show_forum',
        params => { id => 'IDVALUE' }
    ) );

    $self->gtool->Data->query_params( {
        where => 'groups_id = ?',
        order => 'title ASC',
        value => [ CTX->request->target_group_id ]
    } );

    my $content = $self->gtool->get_list;

    my $buttons = Dicole::Content::Controlbuttons->new;
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Add forum' ),
        link  => Dicole::URL->create_from_current( task => 'add_forum' )
    } );
    unshift @{ $content }, $buttons;

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of forums' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content );

    return $self->generate_tool_content;
}

sub _category_dropdown {
    my ( $self ) = @_;
    $self->gtool->get_field( 'category' )->mk_dropdown_options(
        class => CTX->lookup_object('forums'),
        params => {
            where => 'groups_id = ?',
            value => [ CTX->request->target_group_id ],
            order => 'category'
        },
        content_field => 'category',
        value_field => 'category',
        distinct => 1
    );
}

sub add_forum {
    my ( $self ) = @_;

    $self->_init_tool(
        tab_override => 'manage_forums',
        object => CTX->lookup_object('forums')
    );
    $self->tool->Path->add( name => $self->_msg( 'Add forum' ) );

    $self->_category_dropdown;
    foreach my $field_id ( qw( message_typeset ) ) {
        $self->_typeset_dropdown( $self->gtool->get_field( $field_id ) );
    }

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' )
    );
    $self->gtool->add_bottom_button(
        name  => 'save_new',
        value => $self->_msg( 'Save and add new' )
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show forum management' ),
        link  => Dicole::URL->create_from_current( task => 'manage_forums' )
    );

    if ( CTX->request->param( 'save' )
        || CTX->request->param( 'save_new' )
    ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );

        if ( $code ) {
            $self->_create_new_forum;
            $self->gtool->Data->clear_data_fields;
            $message = $self->_msg( "Forum has been saved." );
        } else {
            $message = $self->_msg( "Failed adding forum: [_1]", $message );
        }

        $self->tool->add_message( $code, $message );
        if ( CTX->request->param( 'save' ) && $code ) {
            my $redirect = Dicole::URL->create_from_current(
                task => 'manage_forums'
            );
            return CTX->response->redirect( $redirect );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'New forum details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub _create_new_forum {
    my ( $self, $forum_data ) = @_;
    $forum_data ||= $self->gtool->Data;
    my $object = $forum_data->data;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_metadata') );
    my $metadata = $data->data_new;
    $metadata->{type} = $object->{type};
    $data->data_save;

    $object->{user_id} = CTX->request->auth_user_id;
    $object->{groups_id} = CTX->request->target_group_id;

    # This is here until we have implemented the
    # message part type selection, if ever..
    $object->{message_part_typeset} = $object->{message_typeset};

    $object->{date} = time;
    $object->{metadata_id} = $metadata->id;

    $forum_data->data_save;

    $self->forum( $forum_data );
}

sub _typeset_dropdown {
    my ( $self, $field ) = @_;
    $field->mk_dropdown_options(
        class => CTX->lookup_object('typesets'),
        params => {
            where => "groups_id = ? OR groups_id = ?",
            value => [ 0, CTX->request->target_group_id ],
            order => 'typeset_id'
        },
        value_field => 'typeset_id',
        content_field => 'title',
        localize => 1
    );
}

sub remove_forum {
    my ( $self ) = @_;

    return unless CTX->request->param( 'id' );
    return unless
        $self->_check_if_forum_exists( CTX->request->param( 'id' ) );

    my $name = $self->forum->data->title;
    unless ( $self->forum->remove_object ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error removing forum [_1].', $name )
        );
    }
    else {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Forum [_1] successfully removed.', $name )
        );
    }

    my $redirect = Dicole::URL->create_from_current(
        task => 'manage_forums'
    );
    return CTX->response->redirect( $redirect );
}

sub show_forum {

    my ( $self ) = @_;

    $self->_init_tool(
        tab_override => 'manage_forums',
        object => CTX->lookup_object('forums')
    );
    return unless
        $self->_check_if_forum_exists(
            CTX->request->param( 'id' ), 'manage_forums'
        );
    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Display forum details' ) );

    $self->_category_dropdown;
    foreach my $field_id ( qw( message_typeset ) ) {
        $self->_typeset_dropdown( $self->gtool->get_field( $field_id ) );
    }

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_forum',
            params => { id => 'IDVALUE' }
        )
    );
    $self->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->_msg( 'Remove' ),
        confirm_box => {
            title => $self->_msg( 'Remove forum' ),
            name => 'IDVALUE',
            msg   => $self->_msg( 'Are you sure you want to remove this forum?' ),
            href  => Dicole::URL->create_from_current(
                task => 'remove_forum',
                params => { id => 'IDVALUE' }
            )
        }
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show forum management' ),
        link  => Dicole::URL->create_from_current( task => 'manage_forums' )
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Forum details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show( id => CTX->request->param( 'id' ) )
    );

    return $self->generate_tool_content;
}

sub edit_forum {
    my ( $self ) = @_;

    $self->_init_tool(
        tab_override => 'manage_forums',
        view => 'add_forum',
        object => CTX->lookup_object('forums')
    );
    return unless
        $self->_check_if_forum_exists(
            CTX->request->param( 'id' ), 'manage_forums'
        );
    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Edit forum' ) );

    $self->_category_dropdown;
    foreach my $field_id ( qw( message_typeset ) ) {
        $self->_typeset_dropdown( $self->gtool->get_field( $field_id ) );
    }

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' )
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show' ),
        link  => Dicole::URL->create_from_current(
            task => 'show_forum',
            params => { id => 'IDVALUE' }
        )
    );
    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show forum management' ),
        link  => Dicole::URL->create_from_current( task => 'manage_forums' )
    );

    if ( CTX->request->param( 'save' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object_id => CTX->request->param( 'id' ) }
        );
        if ( $code ) {
            $message = $self->_msg( "Changes were saved." );
        } else {
            $message = $self->_msg( "Failed modifying forum: [_1]", $message );
        }
        $self->tool->add_message( $code, $message );
    }
    else {
        $self->tool->add_message( 2,
            $self->_msg( 'Changing type sets of a live discussion forum is not a good idea.' )
        );
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Modify forum details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( id => CTX->request->param( 'id' ) )
    );

    return $self->generate_tool_content;
}

sub _update_forum_thread_count {
    my ( $self ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_threads') );
    $data->query_params( {
        where => "forum_id = ?",
        value => [ $self->forum->data->id ]
    } );
    $self->forum->data->{topics} = $data->total_count( 1 );
    $self->forum->data_save;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleForums::Forums - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
