package OpenInteract2::Action::CommonMessages::Construct;

use strict;
use base qw( Dicole::Generictool::Field::Construct );

sub construct_textquoted {
    my $self = shift;

    if ( $self->get_field_value eq ''
        || !defined $self->get_field_value
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    return Dicole::Content::Text->new(
        text => $self->get_field_value,
        no_filter => $attributes->{no_filter},
        ( $self->object->{origin_part_id} )
            ? ( attributes => { class => 'textQuotedList' } )
            : ()
    );
}

1;

package OpenInteract2::Action::CommonMessages;

use strict;
use base qw( Class::Accessor );

use OpenInteract2::Context   qw( CTX );
use Dicole::URL;
use Dicole::Content::Message;
use Dicole::Content::Controlbuttons;
use Dicole::Generictool::Data;
use Dicole::MessageHandler qw( :message );
use Dicole::Pathutils;
use Dicole::Utility;
use Dicole::Content::Text;
use Dicole::Navigation::Tree;
use Dicole::Navigation::Tree::Element;

__PACKAGE__->mk_accessors( qw(
    message
) );

# FIXME: use a real wizard here
sub select_parts {
    my ( $self ) = @_;

    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id, $msg_id ) = @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );
    return unless
        $self->_check_if_message_exists( $thread_id, $msg_id );

    if ( CTX->request->param( 'next' ) ) {
        my $selected = Dicole::Utility->checked_from_apache( 'sel' );
        my $other = [ $forum_id, $thread_id, $msg_id ];
        push @{ $other }, sort keys %{ $selected } if scalar keys %{ $selected };
        my $redirect = Dicole::URL->create_from_current(
            task => 'write_reply',
            other => $other
        );
        return CTX->response->redirect( $redirect );
    }

    $self->_init_tool(
        tab_override => 'forums',
        object => CTX->lookup_object('forums_parts'),
        cols => 2
    );
    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->thread->data->{title} );
    $self->tool->Path->add( name => $self->message->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Select paragraphs to quote' ) );

    my $content_field = $self->gtool->get_field( 'content' );

    $self->gtool->Construct( OpenInteract2::Action::CommonMessages::Construct->new );

    $self->gtool->Data->query_params( {
        where => 'version_id = ?',
        value => [ $self->message->data->{version_id} ],
        order => 'part_id',
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current(
            task => 'messages',
            other => [ $forum_id, $thread_id, $msg_id ]
        )
    );

    $self->gtool->add_bottom_button(
        name => 'next',
        value => $self->_msg( 'Next' ),
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Select paragraphs to quote in your message' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_sel
    );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('forums_messages'),
            skip_security => 1,
            current_view => 'original_message',
        )
    );
    $self->init_fields;
    $self->_author_dropdown;
    $self->_type_dropdown(
        $self->gtool->get_field( 'type' ),
        $self->forum->data->{message_typeset}
    );

    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Message information' )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_show( object => $self->message->data )
    );

    return $self->generate_tool_content;
}

sub write_reply {
    my ( $self ) = @_;

    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id, $msg_id, @parts ) = @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );
    return unless
        $self->_check_if_message_exists( $thread_id, $msg_id );

    $self->_init_tool(
        tab_override => 'forums',
        object => CTX->lookup_object('forums_messages'),
    );

    $self->tool->add_tinymce_widgets;

    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->thread->data->{title} );
    $self->tool->Path->add( name => $self->message->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Reply to message' ) );

    $self->_type_dropdown(
        $self->gtool->get_field( 'type' ),
        $self->forum->data->{message_typeset}
    );

    unless ( CTX->request->param( 'save' ) ) {
        my $title = $self->gtool->get_field( 'title' );
        $title->value( 'Re: ' . $self->message->data->{'title'} );
        $title->use_field_value( 1 );

        my $content = $self->gtool->get_field( 'content_0' );
        my $parts_data = Dicole::Generictool::Data->new;
        $parts_data->object( CTX->lookup_object('forums_parts') );
        $content->value( '<br /><br />' ) if @parts > 0;
        for ( my $i = 0; $i < @parts; $i++ ) {
            my $part = $parts_data->data_single( $parts[$i], 1 );
            $content->value( $content->value
                . '<!-- origin_id:' . $part->id . ' -->'
                . '<span class="textQuoted">'
                . $part->{content}
                . '</span>'
                . '<!-- origin_id_end -->'
                . '<br /><br /><br /><br />'
            );
        }
        $content->use_field_value( 1 );
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
            $self->_create_new_message(
                reply_to => $self->message
            );
            $msg_id = $self->gtool->Data->data->id;
            $self->gtool->Data->clear_data_fields;
            $message = $self->_msg( "Message has been saved." );
        } else {
            $message = $self->_msg( "Failed adding message: [_1]", $message );
        }

        $self->tool->add_message( $code, $message );

        if ( CTX->request->param( 'save' ) && $code ) {
            my $redirect = Dicole::URL->create_from_current(
                task => 'messages',
                other => [ $forum_id, $thread_id, $msg_id ]
            );
            return CTX->response->redirect( $redirect );
        }
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
            name => $msg_id,
            msg   => $self->_msg( 'Warning: all data you have currently written will be lost. Are you sure you want to cancel?' ),
            href  => Dicole::URL->create_from_current(
                task => 'messages',
                other => [ $forum_id, $thread_id, $msg_id ]
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

sub edit_message {
    my ( $self ) = @_;

    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id, $msg_id ) =
        @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );
    return unless
        $self->_check_if_message_exists( $thread_id, $msg_id );

    $self->_init_tool(
        tab_override => 'forums',
        object => CTX->lookup_object('forums_messages'),
    );

    $self->tool->add_tinymce_widgets;

    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->thread->data->{title} );
    $self->tool->Path->add( name => $self->message->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Edit message' ) );

    $self->_type_dropdown(
        $self->gtool->get_field( 'type' ),
        $self->forum->data->{message_typeset}
    );

    unless ( CTX->request->param( 'save' ) ) {
        my $title = $self->gtool->get_field( 'title' );
        $title->value( $self->message->data->{'title'} );
        $title->use_field_value( 1 );

        my $type = $self->gtool->get_field( 'type' );
        $type->value( $self->message->data->{'type'} );
        $type->use_field_value( 1 );

        my $content = $self->gtool->get_field( 'content_0' );

        # Fetch parts of the message being edited
        my $version_id = $self->message->data->forums_versions->id;
        my $parts_data = Dicole::Generictool::Data->new;
        $parts_data->object( CTX->lookup_object('forums_parts') );
        $parts_data->query_params( {
            where => 'version_id = ?',
            order => 'part_id',
            value => [ $version_id ]
        } );
        $parts_data->data_group;

        # Construct message out of parts
        my $message_to_edit = '<br /><br />';
        foreach my $part ( @{ $parts_data->data } ) {
            if ( $part->{origin_part_id} ) {
                $message_to_edit .= '<!-- origin_id:' . $part->id . ' -->'
                    . '<span class="textQuoted">'
                    . $part->{content}
                    . '</span>'
                    . '<!-- origin_id_end -->';
            } else {
                $message_to_edit .= $part->{content};
            }
            $message_to_edit .= '<br /><br />';
        }
        $content->value( $message_to_edit );
        $content->use_field_value( 1 );
    }
    else {

        # A hack to prevent empty messages being posted.
        # HTMLarea adds an unnecessary <br> in end of each
        # message. This <br> is later removed, resulting
        # in an empty message.
        my $content = CTX->request->param( 'content_0' );
        $content =~ s/((<br\s*\/?>)|\r|\n)+$//sgi;
        CTX->request->param( 'content_0', $content );

        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                object => $self->message->data,
                no_save => 1
            }
        );

        if ( $code ) {
            $self->_create_new_message(
                edit => 1
            );
            $message = $self->_msg( "Message has been saved." );
        } else {
            $message = $self->_msg( "Failed adding message: [_1]", $message );
        }

        $self->tool->add_message( $code, $message );

        if ( CTX->request->param( 'save' ) && $code ) {
            my $redirect = Dicole::URL->create_from_current(
                task => 'messages',
                other => [ $forum_id, $thread_id, $msg_id ]
            );
            return CTX->response->redirect( $redirect );
        }
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
            name => $msg_id,
            msg   => $self->_msg( 'Warning: all data you have currently '
                . 'written will be lost. Are you sure you want to cancel?' ),
            href  => Dicole::URL->create_from_current(
                task => 'messages',
                other => [ $forum_id, $thread_id, $msg_id ]
            )
        }
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Edit message' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $self->message->data )
    );

    return $self->generate_tool_content;
}

sub messages {
    my ( $self ) = @_;
    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id, $msg_id ) = @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );
    return unless
        $self->_check_if_message_exists( $thread_id, $msg_id );

    $msg_id = $self->message->data->id unless $msg_id;

    # Increment the number of times the messages has been read
    $self->message->data->{readcount} += 1;
    $self->message->data_save;
    
    my $unread = [];
    if ( CTX->request->auth_user_id ) {
        $unread = CTX->lookup_object('forums_messages_unread')->fetch_group({
            where => 'user_id = ? AND thread_id = ?',
            value => [CTX->request->auth_user_id, $thread_id],
        }) || [];
    }

    my %unread_by_msg_id;
    push @{ $unread_by_msg_id{ $_->msg_id } }, $_ for @$unread;
    
    # Set message as read: Remove unread tags
    if ( my $array = $unread_by_msg_id{ $msg_id } ) {
        $_->remove for @$array;
        delete $unread_by_msg_id{ $msg_id };
    }
    

    $self->_init_tool(
        tab_override => 'forums',
        object => CTX->lookup_object('forums_messages'),
        $self->param( 'msg_tree_in_left' ) ? ( cols => 2 ) : ( rows => 2 )
    );
    $self->tool->Path->add( name => $self->forum->data->{title} );
    $self->tool->Path->add( name => $self->thread->data->{title} );
    $self->tool->Path->add( name => $self->_msg( 'Display message' ) );

    my $msg_buttons = Dicole::Content::Controlbuttons->new;
    $msg_buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Quote and reply' ),
        link  => Dicole::URL->create_from_current(
            task => 'select_parts',
            other => [ $forum_id, $thread_id, $msg_id ]
        )
    } ) if $self->chk_y( 'write' );

    $msg_buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Reply' ),
        link  => Dicole::URL->create_from_current(
            task => 'write_reply',
            other => [ $forum_id, $thread_id, $msg_id ]
        )
    } ) if $self->chk_y( 'write' );

    if ( $self->chk_y( 'edit_others' ) || ( $self->chk_y( 'edit' )
        && $self->message->data->{user_id} == CTX->request->auth_user_id ) ) {

        $msg_buttons->add_buttons( {
            type  => 'link',
            value => $self->_msg( 'Edit' ),
            link  => Dicole::URL->create_from_current(
                task => 'edit_message',
                other => [ $forum_id, $thread_id, $msg_id ]
            )
        } );
    }

    if ( $self->chk_y( 'remove_others' ) && $self->message->data->{parent_id} )
{
        $msg_buttons->add_buttons( {
            type  => 'confirm_submit',
            value => $self->_msg( 'Remove' ),
            confirm_box => {
                title => $self->_msg( 'Remove message' ),
                name => $msg_id,
                msg   => $self->_msg( 'This message and all replies below this message will be removed. Are you sure you want to remove this message?' ),
                href  => Dicole::URL->create_from_current(
                    task => 'remove_message',
                    other => [ $forum_id, $thread_id, $msg_id ]
                )
            }
        } );
    }
    elsif ( $self->chk_y( 'remove_others' ) ) {
        $msg_buttons->add_buttons( {
            type  => 'confirm_submit',
            value => $self->_msg( 'Remove' ),
            confirm_box => {
                title => $self->_msg( 'Remove topic' ),
                name => $msg_id,
                msg   => $self->_msg( 'This is the first post to a topic and removing it will remove the topic including all messages posted into it. Are you sure you want to remove this topic?' ),
                href  => Dicole::URL->create_from_current(
                    task => 'remove_thread',
                    other => [ $forum_id, $thread_id ]
                )
            }
        } );
    }

    # Create paths to type set icons as a hashref
    my $type_icons = {};
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('typeset_types') );
    $data->data_group;
    foreach my $type ( @{ $data->data } ) {
        $type_icons->{$type->id} = $type->{icon};
    }

    my $message = $self->_show_message( $type_icons );

    my @message_box_at = ( 0, 0 );

    if ( $self->param( 'msg_tree_in_left' ) ) {
        @message_box_at = ( 1, 0 );
        $self->tool->Container->column_width( '300' );
    }
    $self->tool->Container->box_at( @message_box_at )->name(
        $self->_msg( 'Message contents' )
    );
    $self->tool->Container->box_at( @message_box_at )->add_content(
        [ $message, $msg_buttons ]
    );

    my $tree = Dicole::Navigation::Tree->new(
        tree_id => 'message_tree',
        id_path => 1,
        no_new_root => 1
    );

    if ( $self->param('no_tree_collapsing') ) {
        $tree->folders_initially_open( 1 );
        $tree->no_collapsing( 1 );
    }

    $tree->root_href( '' );

    $tree->root_name( $self->thread->data->{title} );

    $tree->icon_files( $type_icons );

    $self->_get_dir_tree( $tree, \%unread_by_msg_id );

    unless ( CTX->request->param( 'tree_folder_action' ) ) {
        $tree->open_tree_path_to( $msg_id );
        my $element = $tree->find_element( $msg_id );
        $element->open_folder if $element->has_sub_elements;
    }

    my $buttons = Dicole::Content::Controlbuttons->new;
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Show topics' ),
        link  => Dicole::URL->create_from_current(
            task => 'threads',
            params => { id => $forum_id }
        )
    } );
    $buttons->add_buttons( {
        type  => 'link',
        value => $self->_msg( 'Show forums' ),
        link  => Dicole::URL->create_from_current(
            task => 'forums'
        )
    } );

    my @tree_box_at = ( 0, 1 );
    @tree_box_at = ( 0, 0 ) if $self->param( 'msg_tree_in_left' );

    $self->tool->Container->box_at( @tree_box_at )->name(
        $self->_msg( 'Tree of messages in topic' )
    );
    $self->tool->Container->box_at( @tree_box_at )->add_content(
        [ $buttons, $tree->get_tree ]
    );

    return $self->generate_tool_content;
}

sub _get_dir_tree {
    my ( $self, $tree, $unread ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_messages') );
    $data->query_params( {
        where => 'forum_id = ? AND thread_id = ? AND active = ?',
        value => [ $self->forum->data->id, $self->thread->data->id, 1 ]
    } );
    $data->data_group;

    # First we have to build a lookup hash, which serves
    # as a fast way to access a certain object and the
    # TreeElement object associated with it
    my $tree_lookup = {};
    foreach my $object ( @{ $data->data } ) {
        $tree_lookup->{ $object->id }{data} = $object;
        # OPTIMIZE: fetch all at once before loop
        my $user = $object->user( {skip_security => 1 } );
        my $user_name = $user->{first_name} . ' ' . $user->{last_name};
        my $class = ( $unread->{$object->id} ) ? 'unread' : '';
        $tree_lookup->{ $object->id }{element} =
            Dicole::Navigation::Tree::Element->new(
                element_id => $object->id,
                name => $object->{title} . ' - ' . $user_name,
                type => $object->{type},
                class => $class,
                override_link => Dicole::URL->create_from_current(
                    other => [
                        $self->forum->data->id,
                        $self->thread->data->id,
                        $object->id
                    ],
                ),
                ( $object->id eq $self->message->data->id )
                    ? ( selected => 1 ) : ()
            );
    }

    # Now we go through the objects the second time and this
    # time we use the lookup hash to add elements to the tree
    # in their correct places by mapping parent element to elements
    # that have parents.
    #
    # Elements that have a parent specified but the parent does not exist
    # will become root elements
    foreach my $object ( @{ $data->data } ) {

        my $tree_element = $tree_lookup->{ $object->id };

        # Child element because has parent
        if ( $tree_element->{data}{parent_id}
            && exists $tree_lookup->{ $tree_element->{data}{parent_id} }
        ) {
            $tree_element->{element}->parent_element(
                $tree_lookup->{ $tree_element->{data}{parent_id} }{element}
            );
            $tree->add_element( $tree_element->{element} );
        }
        # Root object because has no parent
        else {
            $tree->add_element( $tree_element->{element} );
        }

    }

    return $tree;

}

sub remove_message {
    my ( $self ) = @_;
    my $path = Dicole::Pathutils->new( {
        url_base_path => CTX->request->target_group_id
    } );
    my ( $forum_id, $thread_id, $msg_id ) = @{ $path->current_path_segments };
    return unless
        $self->_check_if_forum_exists( $forum_id );
    return unless
        $self->_check_if_thread_exists( $thread_id );
    return unless
        $self->_check_if_message_exists( $thread_id, $msg_id );

    my $name = $self->message->data->title;
    unless ( $self->message->data->{parent_id} ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Impossible to remove root message [_1].', $name )
        );
    }
    else {
        # We are cheating here.. only defining the message as not
        # activated, saving us the frustration or removing recursively
        # all message down below.. well, actually we do this also
        # to still maintain the possibility to revert mistakes and also
        # to retain the possibility of viewing all the messages and their
        # revisions posted to a thread. remove_topic is here for true removal.

        # FIXME
        # recursively deactive messages below the message
        $self->message->data->{active} = 0;
        $self->message->data_save;

        $self->_update_thread_message_count( $self->forum, $self->thread );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Topic [_1] successfully removed.', $name )
        );
    }

    my $redirect = Dicole::URL->create_from_current(
        task => 'messages',
        other => [ $forum_id, $thread_id ]
    );
    return CTX->response->redirect( $redirect );
}

sub _create_new_message {
    my $self = shift;

    my $p = {
        forum => $self->forum,
        thread => $self->thread,
        message => undef,
        reply_to => undef,
        edit => undef,
        @_
    };

    $p->{message} ||= $self->gtool->Data;

    my $forum_id = $p->{forum}->data->id;
    my $thread_id = $p->{thread}->data->id;
    my $reply_to_id = 0;
    $reply_to_id = $p->{reply_to}->data->id if ref $p->{reply_to};

    my $object = $p->{message}->data;
    my $time = time;
    my $user_id = CTX->request->auth_user_id;

    # Create some metadata for the message
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_metadata') );
    my $metadata = $data->data_new( 1 );
    my $type = Dicole::Generictool::Data->new;
    $type->object( CTX->lookup_object('typeset_types') );
    $type->data_single( $object->{type} );
    $metadata->{type} = $type->data->{type_id_string};
    $data->data_save;

    # Create first version of the message
    my $version_parent_id = 0;
    if ( ref $p->{reply_to} ) {
        $version_parent_id = $p->{reply_to}->data->forums_versions->id;
    }
    $data->object( CTX->lookup_object('forums_versions') );
    my $version = $data->data_new( 1 );
    $version->{forum_id} = $forum_id;
    $version->{groups_id} = CTX->request->target_group_id;
    $version->{thread_id} = $thread_id;
    # Remember to point to the metadata as well
    $version->{metadata_id} = $metadata->id;
    $version->{user_id} = $user_id;
    $version->{parent_id} = $version_parent_id;
    $version->{msg_id} = 0; # We will update this later
    $version->{date} = $time;
    $version->{title} = $object->{title};
    $data->data_save;

    # Convert to unix linefeeds
    $object->{content_0} =~ s/\r//sgi;

    # Replace two or more br tags in a row with two newline characters
    $object->{content_0} =~ s/(\s|\n)*<br\s*\/?>(\s|\n)*<br\s*\/?>(<br\s*\/?>|\s|\n)*/\n\n/sgi;

    # same for IE
    $object->{content_0} =~ s/\n*<p>(\n|\s)*(<br\s*\/?>|\s|\n)?/\n\n/sgi;

    # same for IE
    $object->{content_0} =~ s/(<br\s*\/?>)?(\s|\n)*<\/p>//sgi;

    $data->object( CTX->lookup_object('forums_parts') );
    foreach my $content ( split /\n\s*?\n/s, $object->{content_0} ) {

        # Check if a part contains a quoted part
        if ( $content =~ s/<\!-- origin_id:(\d+) --><span class="textQuoted">(.*?)(<\/span><\!-- origin_id_end -->)//s ) {
            my $origin_part_id = $1;
            my $origin_part_content = $2;
            $data->data_single( $origin_part_id, 1 );
            my $origin_part = $data->data;
            my $part = $data->data_new( 1 );
            $part->{version_id} = $version->id;
            $part->{metadata_id} = $origin_part->{metadata_id};
            $part->{forum_id} = $forum_id;
            $part->{thread_id} = $thread_id;
            $part->{groups_id} = CTX->request->target_group_id;
            $part->{user_id} = $origin_part->{user_id};
            $part->{origin_version_id} = $origin_part->{version_id};
            $part->{origin_part_id} = $origin_part_id;
            $part->{content} = $origin_part_content;
            $data->data_save;
            $self->log( 'debug', "Added quoted part:"
                . Data::Dumper::Dumper( $part ) );
        }

        # strip starting and ending br tags
        $content =~ s/^(<br\s*\/?>|\r|\n)*//si;
        $content =~ s/(<br\s*\/?>|\r|\n)*$//si;

        next if $content =~ /^\s*$/s;
        next unless $content;

        my $part = $data->data_new( 1 );
        $part->{version_id} = $version->id;
        # Remember to create the (metadata) metadata as well
        my $metadata_data = Dicole::Generictool::Data->new;
        $metadata_data->object( CTX->lookup_object('forums_metadata') );
        $metadata_data->data_new( 1 );
        $metadata_data->data_save;
        $part->{metadata_id} = $metadata_data->data->id;
        $part->{forum_id} = $forum_id;
        $part->{thread_id} = $thread_id;
        $part->{groups_id} = CTX->request->target_group_id;
        $part->{user_id} = $user_id;
        $part->{origin_version_id} = 0;
        $part->{origin_part_id} = 0;
        $part->{content} = $content;
        $data->data_save;
        $self->log( 'debug', "Added new part:"
            . Data::Dumper::Dumper( $part ) );
    }

    # Create the message in the messages database
    # Messages database is for speed of building up the tree,
    # so that's why we duplicate everything here

    $object->{metadata_id} = $metadata->id;
    $object->{version_id} = $version->id;
    $object->{updated} = $time;

    unless ( $p->{edit} ) {
        $object->{groups_id} = CTX->request->target_group_id;
        $object->{forum_id} = $forum_id;
        $object->{thread_id} = $thread_id;
        $object->{user_id} = $user_id;
        $object->{parent_id} = $reply_to_id;
        $object->{date} = $time;
        $object->{active} = 1;
    }

    $p->{message}->data_save;

    $self->message( $p->{message} );

    if ( $p->{edit} ) {
        $self->log( 'debug', "Edited message:"
            . Data::Dumper::Dumper( $object ) );
    } else {
        $self->log( 'debug', "Added new message:"
            . Data::Dumper::Dumper( $object ) );
    }

    # Point message id from version
    $data->data( $version );
    $version->{msg_id} = $object->id;
    $data->data_save;

    $self->log( 'debug', "Added new version:"
        . Data::Dumper::Dumper( $version ) );

    # Increment counts (posts in a thread, posts in a forum)
    # and save to relevant places

    $p->{forum}->data->{updated} = $time;
    $p->{thread}->data->{updated} = $time;
    $self->_update_thread_message_count( $p->{forum}, $p->{thread} );
    $self->_add_unread_tags_for_message( $object ) if ! $p->{edit};
    
}

sub _show_message {
    my ( $self, $type_icons ) = @_;

    # Display icon
    my $icon = $self->gtool->get_field( 'icon' );
    $icon->value( $type_icons->{$self->message->data->{type}} );
    $icon->use_field_value( 1 );

    my $message = Dicole::Content::Message->new;

    $message->title( $self->message->data->{title} );

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_parts') );
    $data->query_params( {
        where => 'version_id = ?',
        value => [ $self->message->data->{version_id} ],
        order => 'part_id'
    } );
    $data->data_group;

    foreach my $part_data ( @{ $data->data } ) {

        my $part_content = Dicole::Content::Text->new(
            text => $part_data->{content},
            no_filter => 1
        );

        if ( $part_data->{origin_part_id} ) {
            $part_content->attributes( {
                class => 'textQuoted'
            } );
        }

        $message->add_message( $part_content );
    }

	my $types = CTX->lookup_object('typeset_types')->fetch_iterator( {
	    where => "typeset_id = ?",
        value => [ $self->forum->data->{message_typeset} ],
    } );        

	while ( $types->has_next ) {
		my $type = $types->get_next;
		if ( $type->id == $self->message->data->{type}) {
			$self->gtool->get_field( 'icon' )->options->{title}
				= $self->_msg($type->{title} );
			last;
		}
	}

	# Fetch profile image and set it in message meta
	my $profile = CTX->lookup_object( 'profile' )->fetch_group( {
		where => 'user_id = ?',
		value => [ $self->message->data->{user_id} ]
	} );
	$profile->[0]{pro_image} =~ s/(\.\w+)$/_t$1/;
	$self->message->data->{pro_image} = $profile->[0]{pro_image};

	# If no portrait is set, remove image field to save space
	unless ( $self->message->data->{pro_image} ) {
		$self->gtool->del_visible_fields( $self->gtool->current_view, [ 'pro_image' ] );
	}

	# If updated is same as message date, remove updated field to save space
	if ( $self->message->data->{date} eq $self->message->data->{updated} ) {
		$self->gtool->del_visible_fields( $self->gtool->current_view, [ 'updated' ] );
	}

    my $metas = $self->gtool->construct_fields(
        $self->message->data, $self->gtool->visible_fields
    );

    my $i = 0;
    foreach my $field_id ( @{ $self->gtool->visible_fields } ) {
        my $field = $self->gtool->get_field( $field_id );
        $message->add_meta( $field->desc, $metas->[$i] );
        $i++;
    }

    return $message;
}

sub _check_if_message_exists {
    my ( $self, $thread_id, $msg_id ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_messages') );

    unless ( $msg_id ) {
        $data->query_params( {
            where => 'thread_id = ? AND groups_id = ? AND parent_id = 0',
            value => [ $thread_id, CTX->request->target_group_id ]
        } );
    }
    else {
        $data->query_params( {
            where => 'thread_id = ? AND groups_id = ? AND msg_id = ?',
            value => [ $thread_id, CTX->request->target_group_id, $msg_id ]
        } );
    }
    $data->data_group;
    $data->data( $data->data->[0] );
    if ( !ref( $data->data) || ref( $data->data ) eq 'ARRAY' ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Message with id [_1] does not exist.', $msg_id )
        );
        my $redirect = Dicole::URL->create_from_current(
            task => 'messages',
            other => [ $self->forum->data->id, $self->thread->data->id ]
        );
        CTX->response->redirect( $redirect );
        return undef;
    }

    $self->message( $data );

    return $data;
}

sub _add_unread_tags_for_message {
    my ( $self, $message ) = @_;
    
    my $groups_id = $message->{groups_id};
    my $thread_id = $message->{thread_id};
    my $forum_id = $message->{forum_id};
    my $msg_id = $message->{msg_id};
    my $author_id = $message->{user_id};

    my $group_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_group_user',
        where => 'groups_id = ?',
        value => [ $groups_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];
    
    my @ids = map { $_->{user_id} } @$group_users;
    my $unread_object = CTX->lookup_object('forums_messages_unread');

    for my $id (@ids) {
        next if $id == $author_id;
        
        $unread_object->new({
            user_id => $id,
            msg_id => $msg_id,
            groups_id => $groups_id,
            thread_id => $thread_id,
            forum_id => $forum_id,
        })->save;
    }
    
    
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
