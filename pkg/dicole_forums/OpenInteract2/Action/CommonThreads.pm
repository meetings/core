package OpenInteract2::Action::CommonThreads;

use strict;

use base qw( Class::Accessor );

use OpenInteract2::Context   qw( CTX );
use Dicole::URL;
use Dicole::Generictool::Data;
use Dicole::Content::Controlbuttons;
use Dicole::MessageHandler qw( :message );

__PACKAGE__->mk_accessors( qw(
    thread
) );

sub threads {
    my ( $self ) = @_;

    my $forum_id = CTX->request->param( 'id' );
    return unless
        $self->_check_if_forum_exists( $forum_id );

    $self->_init_tool(
        object => CTX->lookup_object('forums_threads'),
        tab_override => 'forums'
    );
    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'List of topics' ) );
    $self->_author_dropdown;
    $self->_type_dropdown(
        $self->gtool->get_field( 'type' ),
        $self->forum->data->{message_typeset}
    );

    $self->gtool->get_field( 'title' )->link( Dicole::URL->create_from_current(
        task => 'messages',
        other => [ $forum_id, 'IDVALUE' ]
    ) );

    $self->gtool->Data->query_params( {
        where => 'forum_id = ? AND groups_id = ?',
        value => [ $forum_id, CTX->request->target_group_id ]
    } );
    
    my $unread = [];
    if ( CTX->request->auth_user_id ) {
        $unread = CTX->lookup_object('forums_messages_unread')->fetch_group({
            where => 'user_id = ? AND forum_id = ?',
            value => [CTX->request->auth_user_id, $forum_id],
        }) || [];
    }
    
    my %unread_by_thread_id = ();
    for my $unread_item ( @$unread ) {
        push @{$unread_by_thread_id{$unread_item->thread_id}}, $unread_item;
    };

    my $data = $self->gtool->Data->data_group || [];
    for my $thread ( @$data ) {
        if (my $array = $unread_by_thread_id{$thread->id}) {
            $thread->{unread} = scalar(@$array);
        }
    }

    my $content = $self->gtool->get_list(
        objects => $data,
    );

    my $buttons = Dicole::Content::Controlbuttons->new;
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Add topic' ),
        link  => Dicole::URL->create_from_current(
            task => 'add_thread',
            params => { id => $forum_id }
        )
    } ) if $self->chk_y( 'threads' );
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Show forums' ),
        link  => Dicole::URL->create_from_current(
            task => 'forums'
        )
    } );
    unshift @{ $content }, $buttons;

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'List of topics' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content );

    return $self->generate_tool_content;
}

sub add_thread {
    my ( $self ) = @_;

    my $forum_id = CTX->request->param( 'id' );
    return unless
        $self->_check_if_forum_exists( $forum_id );

    $self->_init_tool(
        tab_override => 'forums',
        object => CTX->lookup_object('forums_messages'),
    );

    $self->tool->add_tinymce_widgets;

    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Add new topic' ) );

    $self->_type_dropdown(
        $self->gtool->get_field( 'type' ),
        $self->forum->data->{message_typeset}
    );

    if ( CTX->request->param( 'force_title' ) ) {
        my $title = $self->gtool->get_field( 'title' );
        $title->use_field_value( 1 );
        $title->options( { readonly => 1 } );
        $title->value( CTX->request->param( 'force_title' ) );
        CTX->request->param( 'title', CTX->request->param( 'force_title' ) );
    }

    if ( CTX->request->param( 'save' ) ) {

        # A hack to prevent empty messages being posted.
        # HTMLarea adds an unnecessary <br> in end of each
        # message. This <br> is later removed, resulting
        # in an empty message.
        my $content = CTX->request->param( 'content_0' );
        $content =~ s/((<br\s*\/?>)|\r|\n)+$//sgi;
        CTX->request->param( 'content_0', $content );

        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                no_save => 1
            }
        );

        if ( $code ) {

            # Create threads object and copy title and type fields from
            # the messages object into it
            my $data = Dicole::Generictool::Data->new;
            $data->object( CTX->lookup_object('forums_threads') );
            $data->data_new( 1 );
            foreach my $field ( qw( type title ) ) {
                $data->data->{$field} = $self->gtool->Data->data->{$field};
            }

            # Create thread object. This is used to list threads
            $self->_create_new_thread( $data );

            # Create message object. This also creates some entries into
            # versions table and parts table
            $self->_create_new_message;

            my $thread_id = $self->thread->data->id;
            my $msg_id = $self->message->data->id;
            $self->gtool->Data->clear_data_fields;
            $message = $self->_msg( "Message has been saved." );
            $self->tool->add_message( $code, $message );
            my $redirect = Dicole::URL->create_from_current(
                task => 'messages',
                other => [ $forum_id, $thread_id, $msg_id ]
            );
            return CTX->response->redirect( $redirect );
        } else {
            $message = $self->_msg( "Failed adding message: [_1]", $message );
            $self->tool->add_message( $code, $message );
        }
    }
    elsif ( CTX->request->param( 'content' ) ) {
        my $title = $self->gtool->get_field( 'content_0' );
        $title->use_field_value( 1 );
        $title->value( CTX->request->param( 'content' ) );
    }

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' )
    );

    $self->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->_msg( 'Cancel' ),
        confirm_box => {
            title => $self->_msg( 'Confirmation' ),
            name => $forum_id,
            msg   => $self->_msg(
                'Warning: all data you have currently written will be lost. '
                    . 'Are you sure you want to cancel?'
            ),
            href  => Dicole::URL->create_from_current(
                task => 'threads',
                params => { id => $forum_id }
            )
        }
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'New message details' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub remove_thread {
    my ( $self ) = @_;

    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id ) = @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );

    my $name = $self->thread->data->{title};
    $self->thread->remove_object( $self->thread->data->forums_metadata );
    unless ( $self->thread->remove_object( $self->thread->data ) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error removing topic [_1].', $name )
        );
    }
    else {

        # Clear the object because _update_thread_message_count()
        # otherwise saves it again ;)
        $self->thread( undef );

        # Remove the messages
        my $data = Dicole::Generictool::Data->new;
        $data->object( CTX->lookup_object('forums_messages') );
        $data->query_params( {
            where => 'thread_id = ?',
            value => [ $thread_id ]
        } );
        $data->remove_group( undef, $data->data_group( 1 ) );

        # Remove the different message versions
        $data->object( CTX->lookup_object('forums_versions') );
        $data->query_params( {
            where => 'thread_id = ?',
            value => [ $thread_id ]
        } );
        foreach my $version_object ( @{ $data->data_group( 1 ) } ) {

            # Remove the version metadata
            $data->remove_object( $version_object->forums_metadata );
            # Remove the version
            $data->remove_object( $version_object );
        }

        # Remove the different parts
        my $part_data = Dicole::Generictool::Data->new;
        $part_data->object( CTX->lookup_object('forums_parts') );
        $part_data->query_params( {
            where => 'thread_id = ?',
            value => [ $thread_id ]
        } );
        foreach my $part_object ( @{ $part_data->data_group( 1 ) } ) {
            # Remove the part metadata
            $part_data->remove_object( $part_object->forums_metadata );
            # Remove the part
            $part_data->remove_object( $part_object );
        }

        $self->_update_forum_thread_count( $self->forum );
        $self->_update_thread_message_count( $self->forum );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Topic [_1] successfully removed.', $name )
        );
    }

    my $redirect = Dicole::URL->create_from_current(
            task => 'threads',
            params => { id => $forum_id }
    );
    return CTX->response->redirect( $redirect );
}

sub _create_new_thread {
    my ( $self, $thread_data ) = @_;
    $thread_data ||= $self->gtool->Data;

    my $object = $thread_data->data;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_metadata') );
    my $metadata = $data->data_new;

    my $type = Dicole::Generictool::Data->new;
    $type->object( CTX->lookup_object('typeset_types') );
    $type->data_single( $object->{type} );
    $metadata->{type} = $type->data->{type_id_string};
    $data->data_save;

    $object->{user_id} = CTX->request->auth_user_id;
    $object->{groups_id} = CTX->request->target_group_id;
    $object->{forum_id} = $self->forum->data->id;
    $object->{date} = time;
    $object->{metadata_id} = $metadata->id;
    $object->{updated} = 0;

    $thread_data->data_save;

    $self->thread( $thread_data );

    $self->forum->data->{updated} = time;
    $self->_update_forum_thread_count;

}

sub _update_thread_message_count {
    my ( $self, $forum, $thread ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_messages') );
    $data->query_params( {
        where => "forum_id = ? AND active = 1",
        value => [ $forum->data->id ]
    } );
    $forum->data->{posts} = $data->total_count( 1 );
    $forum->data_save;
    if ( ref $thread ) {
        $data->query_params( {
            where => "thread_id = ? AND active = 1",
            value => [ $thread->data->id ]
        } );
        $thread->data->{posts} = $data->total_count( 1 );
        $thread->data_save;
    }
}

sub _check_if_thread_exists {
    my ( $self, $thread_id ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_threads') );
    $data->query_params( {
        where => 'groups_id = ? and thread_id = ?',
        value => [ CTX->request->target_group_id, $thread_id ]
    } );
    $data->data_group;
    $data->data( $data->data->[0] );

    if ( !ref( $data->data) || ref( $data->data ) eq 'ARRAY' ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Thread with id [_1] does not exist.', $thread_id )
        );
        my $redirect = Dicole::URL->create_from_current(
            task => 'threads',
            params => { id => $self->forum->data->id }
        );
        CTX->response->redirect( $redirect );
        return undef;
    }
    $self->thread( $data );
    return $data;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleForums - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
