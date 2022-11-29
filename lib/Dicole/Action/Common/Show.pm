package Dicole::Action::Common::Show;

# $Id: Show.pm,v 1.6 2009-01-07 14:42:32 amv Exp $

use base ( 'Dicole::Action::Common' );

use strict;
use OpenInteract2::Context   qw( CTX );

use Dicole::Generictool;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating a show view for an object

=head1 SYNOPSIS

 use base qw( Dicole::Action::Common::Show );

=head1 DESCRIPTION

A common action helper for implementing a show view for a SPOPS object. It
simply just takes the defined fields, matches them with the values in the
SPOPS object and displays the resulting object.

Has flexible configuration through I<action.ini>, I<fields.ini> and overridable
class methods.

=head1 TOOL CONFIGURATION

This common generic show task generates a show view based on configuration
specified in I<action.ini>.

Example configuration:

  [my_action c_show]
  c_box_x = 0
  c_box_y = 0
  c_box_title = Show user details
  c_path_name = Show user details
  c_skip_security = 1
  c_class = user
  c_edit_link = /ACTION_NAME/edit?id=IDVALUE
  c_back_text = Show list of users
  c_back_link = /ACTION_NAME/list
  c_id_param = id

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

=item c_edit_link
If true, adds an I<Edit> button and if pressed, leads to an URL
specified in this property.

=item c_back_text
Text that reads in the I<Back> button.

=item c_back_link
If true, adds a I<Cancel> button and if pressed, leads to an URL
specified in this property.

=item c_id_param
The name of the POST/GET parameter which contains the object id to
edit.

=back

In addition to this you would have to describe the view and fields in the
view. This is done through I<fields.ini>.

Example configuration:

  [views show]
  fields = login_name
  fields = full_name

  [fields login_name]
  id = login_name
  type = textfield
  desc = Login name

  [fields fist_name]
  id = full_name
  type = textfield
  desc = Full name

The I<views> property must always be I<show> while the fields should correspond
the SPOPS class provided by action parameter I<c_class>.

=head1 METHODS

=head2 show()

The task which creates the show view. Uses L<Dicole::Generictool> to
construct the add view based on tool configuration.

The order of execution is as follows:

=over 4

=item 1.
Run I<_pre_init_common_edit()>

=item 2.
Run I<_init_common_edit()>

=item 3.
Run I<_post_init_common_edit()>

=item 4.
Run I<_common_buttons_edit()>

=item 5.
Run I<_common_save_edit()>

=item 6.
If save button pressed, run I<_validate_input_edit()>

=item 7.
If save button pressed and validation ok, run I<post_save_edit()>

=item 8.
If save button pressed, validation ok and object saved, run I<post_save_edit()>

=item 9.
Find out coordinates for the box based on action parameters
I<c_box_x> and I<c_box_y>

=item 10.
If preview button pressed, generate preview box with I<gen_preview_box_edit()>

=item 11.
Generate add box, use action parameter I<c_box_title> as the box
title

=item 12.
Run I<_pre_gen_tool_edit()>

=back

=cut

# A task for editing user objects
sub show {
    my ( $self ) = @_;

    # Run custom pre-init operations
    my $id = $self->_pre_init_common_show;

    # Init tool
    $self->_init_common_show( $id );

    # Run custom post-init operations
    $self->_post_init_common_show( $id );

    # Adds some buttons to the view
    $self->_common_buttons_show( $id );

    my $x = $self->param( 'c_show' )->{c_box_x} || 0;
    my $y = $self->param( 'c_show' )->{c_box_y} || 0;

    # Create add form
    $self->tool->Container->box_at( $x, $y )->name(
        $self->_msg( $self->param( 'c_show' )->{c_box_title} || 'Box title' )
    );
    $self->tool->Container->box_at( $x, $y )->add_content(
        $self->gtool->get_show( id => $id )
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool_show( $id );

    return $self->generate_tool_content;
}

=pod

=head1 METHODS TO OVERRIDE

=head2 _pre_init_common_show()

This method is meant to be overridden. It runs before I<_init_common_show()>.

By default, it fetches the object id being displayed from request parameters
based on action parameter I<c_id_param>.

=cut

sub _pre_init_common_show {
    my ( $self )  = @_;
    return CTX->request->param( $self->param( 'c_show' )->{c_id_param} );
}

=pod

=head2 _post_init_common_show( ID )

This method is meant to be overridden. It runs after I<_init_common_show()>.

By default, it adds a new path segment based on the action parameter
I<c_path_name>.

Receives the object id currently under show as a parameter.

Hint: If you want to change properties of I<gtool()>, this is a good method
to override. Also, this is a good place to implement a new box just before the
list if you want to move the list box one level down.

=cut

sub _post_init_common_show {
    my ( $self, $id )  = @_;

    $self->tool->Path->add( name => $self->_msg(
        $self->param( 'c_show' )->{c_path_name}
    ) ) if $self->param( 'c_show' )->{c_path_name};

}

=pod

=head2 _common_buttons_show( ID )

This method is meant to be overridden. It runs after
I<_post_init_common_show()>.

By default, it adds a save button with name I<save> in the view.

Receives the object id currently under show as a parameter.

If action parameter I<c_back_link> exists, adds a back button with the
value of parameter as the link.

If action parameter I<c_edit_link> exists, adds an edit button with the
value of parameter as the link.

=cut

sub _common_buttons_show {
    my ( $self, $id ) = @_;

    my $params = $self->param( 'c_show' );

    if ( $params->{c_back_link} ) {
        $self->gtool->add_bottom_button(
            type  => 'link',
            value => $self->_msg( $params->{c_back_text} || 'Back' ),
            link  => $self->_replace_tags_in_link(
                $params->{c_back_link}, $id
            )
        );
    }
    if ( $params->{c_edit_link} ) {
        $self->gtool->add_bottom_button(
            type  => 'link',
            value => $self->_msg( 'Edit' ),
            link  => $self->_replace_tags_in_link(
                $params->{c_edit_link}, $id
            )
        );
    }

}

=pod

=head2 _pre_gen_tool_show( ID )

This method is meant to be overridden. It is run before
the tool is generated but just after the list box is
created.

Receives the object id currently under show as a parameter.

Hint: this is a good place to place a new box just after the show box.

=cut

sub _pre_gen_tool_show {
    my ( $self, $id )  = @_;
}

=pod

=head1 PRIVATE ACTION METHODS

=head2 _config_tool_show( [KEY, VALUE] )

This accessor is for setting parameters passed to I<init_tool()> of
L<Dicole::Action>. The first parameter is the key and the second parameter
is the value. The accessor returns a hashref of current values.

Some examples of cases where this is required to modify is in cases the
requirement to change the number of columns and rows or if the page contains an
upload field. Best place to change these properties is through the
I<_post_init_tool_show()> method.

=cut

sub _config_tool_show {
    my ( $self, $key, $value ) = @_;
    unless ( ref( $self->{_config_tool_show} ) eq 'HASH' ) {
        $self->{_config_tool_show} = {};
    }
    if ( $key ) {
        $self->{_config_tool_show}{$key} = $value;
    }
    return $self->{_config_tool_show};
}

=pod

=head2 _init_common_show( ID )

Initializes L<Dicole::Generictool> object based on action
parameters I<c_class> and I<c_skip_security>, sets I<gtool> accessor
to that and fills the object with fields from fields.ini based on
task (view).

Receives the object id currently under show as a parameter.

=cut

sub _init_common_show {
    my ( $self, $id ) = @_;
    $self->_init_common_tool( {
        tool_config => $self->_config_tool_show,
        class => $self->param( 'c_show' )->{c_class},
        skip_security => $self->param( 'c_show' )->{c_skip_security},
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
