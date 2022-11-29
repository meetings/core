package Dicole::Action::Common::Add;

# $Id: Add.pm,v 1.6 2009-01-07 14:42:32 amv Exp $

use base ( 'Dicole::Action::Common' );

use strict;
use OpenInteract2::Context   qw( CTX );

use Dicole::Generictool;
use Dicole::Content::Text;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating an add view for an object

=head1 SYNOPSIS

 use base qw( Dicole::Action::Common::Add );

=head1 DESCRIPTION

A common action helper for implementing an add view for a SPOPS object. The
add page has basic input validation, form handling and saves the object.

Has flexible configuration through I<action.ini>, I<fields.ini> and overridable
class methods.

=head1 TOOL CONFIGURATION

This common generic add task generates an add view based on configuration
specified in I<action.ini>.

Example configuration:

  [my_action c_add]
  c_box_x = 0
  c_box_y = 0
  c_box_title = Add users
  c_path_name = Users
  c_skip_security = 1
  c_class = user
  c_preview = 1
  c_cancel_link = /my_action/list
  c_save_redirect = /my_action/list

=over 4

=item c_box_x
Box coordinate X

=item c_box_y
Box coordinate Y

=item c_box_title
Title of the box

=item c_path_name
Last part of the breadcrumbs

=item c_skip_security
If true, skips SPOPS object security when saving it.

=item c_class
Name of the SPOPS class

=item c_preview
If true, adds a I<Preview> button and if pressed, a preview
box just above the add form. The preview box should be implemented
by the programmer, though. Inherit _gen_preview_box_add and
implement a preview box.

=item c_cancel_link
If true, adds a I<Cancel> button and if pressed, leads to an URL
specified in this property.

=item c_save_redirect
If true, the user agent is redirected to a new URL if the save
succeeds. The URL will be the one specified in this property.

=back

In addition to this you would have to describe the view and fields in the
view. This is done through I<fields.ini>.

Example configuration:

  [views add]
  fields = login_name
  fields = password

  [fields login_name]
  id = login_name
  type = textfield
  desc = Login name
  required = 1

  [fields password]
  id = password
  type = password
  required = 1
  desc = Password

The I<views> property must always be I<add> while the fields should correspond
the SPOPS class provided by action parameter I<c_class>.

=head1 METHODS

=head2 add()

The task which creates the add form view. Uses L<Dicole::Generictool> to
construct the add view based on tool configuration.

The order of execution is as follows:

=over 4

=item 1.
Run I<_pre_init_common_add()>

=item 2.
Run I<_init_common_add()>

=item 3.
Run I<_post_init_common_add()>

=item 4.
Run I<_common_buttons_add()>

=item 5.
Run I<_common_save_add()>

=item 6.
If save button pressed, run I<_validate_input_add()>

=item 7.
If save button pressed and validation ok, run I<post_save_add()>

=item 8.
If save button pressed, validation ok and object saved, run I<post_save_add()>

=item 9.
Find out coordinates for the box based on action parameters
I<c_box_x> and I<c_box_y>

=item 10.
If preview button pressed, generate preview box with I<gen_preview_box_add()>

=item 11.
Generate add box, use action parameter I<c_box_title> as the box
title

=item 12.
Run I<_pre_gen_tool_add()>

=back

=cut

# A task for editing user objects
sub add {
    my ( $self ) = @_;

    # Run custom pre-init operations
    $self->_pre_init_common_add;

    # Init tool
    $self->_init_common_add;

    # Run custom post-init operations
    $self->_post_init_common_add;

    # Adds some buttons to the view
    $self->_common_buttons_add;

    # Saves the object if save button pressed
    $self->_common_save_add;

    return undef if CTX->response->is_redirect;
    
    my $x = $self->param( 'c_add' )->{c_box_x} || 0;
    my $y = $self->param( 'c_add' )->{c_box_y} || 0;

    if ( CTX->request->param( 'preview_add' ) ) {

        # Move add form one level down
        $y++;

        # Fill the add form
        $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { fill_only => 1 }
        );

        # User should implement the preview box contents
        $self->_gen_preview_box_add;
    }

    # Create add form
    $self->tool->Container->box_at( $x, $y )->name(
        $self->_msg( $self->param( 'c_add' )->{c_box_title} || 'Box title' )
    );
    $self->tool->Container->box_at( $x, $y )->add_content(
        $self->gtool->get_add
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool_add;

    return $self->generate_tool_content;
}

=pod

=head1 METHODS TO OVERRIDE

=head2 _pre_init_common_add()

This method is meant to be overridden. It runs before I<_init_common_add()>.

By default it generates two boxes if the preview button was pressed.

=cut

sub _pre_init_common_add {
    my ( $self )  = @_;
    if ( CTX->request->param( 'preview_add' ) ) {
        $self->_config_tool_add( 'rows', 2 );
    }
}

=pod

=head2 _post_init_common_add()

This method is meant to be overridden. It runs after I<_init_common_add()>.

By default, it adds a new path segment based on the action parameter
I<c_path_name>.

Hint: If you want to change properties of I<gtool()>, this is a good method
to override. Also, this is a good place to implement a new box just before the
list if you want to move the list box one level down.

=cut

sub _post_init_common_add {
    my ( $self )  = @_;

    $self->tool->Path->add( name => $self->_msg(
        $self->param( 'c_add' )->{c_path_name}
    ) ) if $self->param( 'c_add' )->{c_path_name};

}

=pod

=head2 _gen_preview_box_add()

This method is meant to be overridden. It runs if the I<preview> button is
pressed.

If you use the preview functionality, you have to implement the preview box
yourself. The preview box is always placed above the add form.

=cut

sub _gen_preview_box_add {
    my ( $self )  = @_;
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Preview' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Content::Text->new( text => 'Preview box not implemented.' ) ]
    );
}

=pod

=head2 _common_buttons_add()

This method is meant to be overridden. It runs after I<_post_init_common_add()>.

By default, it adds a save button with name I<save> in the view.

If action parameter I<c_preview> is true, adds a preview button with name
I<preview_add>.

If action parameter I<c_cancel_link> exists, adds a cancel button with the
value of parameter as the link.

=cut

sub _common_buttons_add {
    my ( $self ) = @_;

    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );

    my $params = $self->param( 'c_add');

    if ( $params->{c_preview} ) {
        $self->gtool->add_bottom_button(
            name  => 'preview_add',
            value => $self->_msg( 'Preview' ),
        );
    }

    if ( $params->{c_cancel_link} ) {
        $self->gtool->add_bottom_button(
            type  => 'link',
            value => $self->_msg( 'Cancel' ),
            link  => $self->_replace_tags_in_link( $params->{c_cancel_link} )
        );
    }

}

=pod

=head2 _pre_save_add( DATA )

This method is meant to be overridden. It runs after I<_validate_input_add()>
if validate was a success and just before saving the object in
$self->gtool->Data->data.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
parameter.

This method should return true if everything is ok. If it returns a
failure, the object will not be saved. In case of failure, remember
to leave an error message through $self->tool->add_message.

=cut

sub _pre_save_add {
    my ( $self, $data ) = @_;
    return 1;
}

=pod

=head2 _post_save_add( DATA )

This method is meant to be overridden. It runs just after the object
in $self->gtool->Data->data has been saved.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
parameter.

Optionally, returns the alternative success message which replaces the default.

=cut

sub _post_save_add {
    my ( $self, $data ) = @_;
    return undef;
}

=pod

=head2 _validate_input_add()

Takes care of validating the user form input.

By default, it runs $self->gtool->validate_and_save without saving
the object in $self->gtool->Data->data.

Returns the code and message as an array. Code can be:

=over 4

=item 0
Failure (red box, the object will not be saved)

=item 1
Success (green box, the object will be saved)

=item 2
Warning (success, but warning returned, the object will be saved)

=back

=cut

sub _validate_input_add {
    my ( $self ) = @_;
    my ( $code, $message ) = $self->gtool->validate_and_save(
        $self->gtool->visible_fields,
        { no_save => 1 }
    );
    return ( $code, $message );
}

=pod

=head2 _common_save_add()

Checks if the save button is pressed, if it is, validates the input
and saves the object if validation succeeds. Sets tool messages
apropriately. Redirects the user if necessary based on I<c_save_redirect>.

=cut

sub _common_save_add {
    my ( $self ) = @_;

    if ( CTX->request->param( 'save' ) ) {

        # Validate input parameters
        my ( $code, $message ) = $self->_validate_input_add;

        if ( $code ) {

            my $data = $self->gtool->Data;

            # Run pre tasks for saving the object
            if ( $self->_pre_save_add( $data ) ) {

                $data->data_save;

                # Run post tasks for saving the object
                my $new_message = $self->_post_save_add( $data );

                # Clear fields of the add view, otherwise the filled
                # fields will appear in the output. The form should be empty
                # after adding.
                $data->clear_data_fields;

                $self->tool->add_message( $code, $new_message || $message );

                return CTX->response->redirect(
                    $self->_replace_tags_in_link(
                        $self->param( 'c_add')->{c_save_redirect}
                    )
                ) if $self->param( 'c_add')->{c_save_redirect};
            }
        } else {
            $message = $self->_msg( "Save failed: [_1]", $message );
            $self->tool->add_message( $code, $message );
        }

    }

}

=pod

=head2 _pre_gen_tool_add()

This method is meant to be overridden. It is run before
the tool is generated but just after the list box is
created.

Hint: this is a good place to place a new box just after the add box.

=cut

sub _pre_gen_tool_add {
    my ( $self )  = @_;
}

=pod

=head1 PRIVATE ACTION METHODS

=head2 _config_tool_add( [KEY, VALUE] )

This accessor is for setting parameters passed to I<init_tool()> of
L<Dicole::Action>. The first parameter is the key and the second parameter
is the value. The accessor returns a hashref of current values.

Some examples of cases where this is required to modify is in cases the
requirement to change the number of columns and rows or if the page contains an
upload field. Best place to change these properties is through the
I<_post_init_tool_add()> method.

=cut

sub _config_tool_add {
    my ( $self, $key, $value ) = @_;
    unless ( ref( $self->{_config_tool_add} ) eq 'HASH' ) {
        $self->{_config_tool_add} = {};
    }
    if ( $key ) {
        $self->{_config_tool_add}{$key} = $value;
    }
    return $self->{_config_tool_add};
}

=pod

=head2 _init_common_add()

Initializes L<Dicole::Generictool> object based on action
parameters I<c_class> and I<c_skip_security>, sets I<gtool> accessor
to that and fills the object with fields from fields.ini based on
task (view).

=cut

sub _init_common_add {
    my $self = shift;
    $self->_init_common_tool( {
        tool_config => $self->_config_tool_add,
        class => $self->param( 'c_add' )->{c_class},
        skip_security => $self->param( 'c_add' )->{c_skip_security},
        view => ( split '::', ( caller(1) )[3] )[-1]
    } );
}

=pod

=head1 SEE ALSO

L<Dicole::Action::Common>,
L<Dicole::Action::Generictool>

=head1 AUTHOR

Teemu Arina E<lt>teemu@dicole.orgE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2005 Ionstream Oy / Dicole
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
