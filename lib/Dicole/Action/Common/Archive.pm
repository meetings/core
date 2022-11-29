package Dicole::Action::Common::Archive;

# $Id: Archive.pm,v 1.4 2009-01-07 14:42:32 amv Exp $

use base ( 'Dicole::Action::Common' );

use strict;
use OpenInteract2::Context   qw( CTX );

use Dicole::Generictool;
use Dicole::Utility;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating an archive view of objects

=head1 SYNOPSIS

 use base qw( Dicole::Action::Common::Archive );

=head1 DESCRIPTION

A common action helper for implementing an archive view with capabilities to
move SPOPS objects to an archive and move objects out of the archive.

The archive views have basic ascending/descending sorting, browsing,
columns presenting certain object columns and an optional link to view the SPOPS
object more closely. It has checkboxes to check the objects and an archive
or restore button with confirm capabilities to archive/restore the
checked SPOPS objects. Objects are identified to belong to an archive when
the I<archive> field of the object is set to true.

Has flexible configuration through I<action.ini>, I<fields.ini> and overridable
class methods.

=head1 TOOL CONFIGURATION

This common generic archive task generates an archive view based on
configuration specified in I<action.ini>.

Example configuration:

  [my_action c_archive]
  c_box_x = 0
  c_box_y = 0
  c_box_title = List of users
  c_path_name = Archive users
  c_skip_security = 1
  c_class = user
  c_check_prefix = archive
  c_archive_text = Archive checked
  c_confirm_title = Confirmation
  c_confirm_text = Are you sure you want to archive checked items?
  c_archive_field = archive

  [my_action c_restore]
  c_box_x = 0
  c_box_y = 0
  c_box_title = Archived users
  c_path_name = Archived users
  c_check_prefix = restore
  c_restore_text = Restore checked

=over 4

=item c_box_x
Box coordinate X

=item c_box_y
Box coordinate Y

=item c_box_title
Title of the box

=item c_box_archived_title
Title of the box in the archived section

=item c_path_name
Last part of the breadcrumbs

=item c_path_archived_name
Last part of the breadcrumbs in the archived section

=item c_skip_security
If true, skips SPOPS object security when retrieving list of objects.

=item c_class
Name of the SPOPS class

=item c_check_prefix
The prefix used for checkboxes and also the identifier of the archive button.

=item c_archive_text
The text that reads on the archive button.

=item c_restore_text
The text that reads on the restore button.

=item c_confirm_title
The title of the confirm box that appears when you click archive.

=item c_confirm_text
The text in the confirm box that appears when you click archive.

=item c_archive_field
Used to change the name of the archive field which is I<archive> by default.

=back

In addition to this you would have to describe the view and fields in both
of the archive and restore views. This is done through I<fields.ini>.

Example configuration:

  [views archive]
  fields = login_name
  fields = removal_date
  disable_browse = 0
  disable_sort   = 0
  disable_search = 1
  default_sort   = category
  no_search = removal_date
  no_sort = removal_date

  [views restore]
  fields = login_name
  fields = removal_date
  disable_browse = 0
  disable_sort   = 0
  disable_search = 1
  default_sort   = category
  no_search = removal_date
  no_sort = removal_date

  [fields login_name]
  id = login_name
  type = textfield
  desc = Login name
  link = /my_action/show/?uid=IDVALUE

  [fields removal_date]
  id = removal_date
  type = date
  desc = Expiration date
  date_format = string
  empty_text = Unlimited

The I<views> property must always be I<archive> while the fields should
correspond the SPOPS class provided by action parameter I<c_class>.

=head1 METHODS

=head2 archive()

The task which creates the archive list view. Uses L<Dicole::Generictool> to
construct the view based on tool configuration.

The order of execution is as follows:

=over 4

=item 1.
Run I<_pre_init_common_archive()>

=item 2.
Run I<_init_common_archive()>

=item 3.
Run I<_post_init_common_archive()>

=item 4.
Run I<_common_buttons_archive()>

=item 5.
Run I<_common_archive()>

=item 6.
If archive button pressed, run I<_pre_archive()>

=item 7.
If archive button pressed and objects archived, run I<_post_archive>

=item 8.
Find out coordinates for the box based on action parameters
I<c_box_x> and I<c_box_y>

=item 9.
Generate archive box, use action parameter I<c_box_title> as the box
title

=item 10.
Run I<_pre_gen_tool_archive()>

=back

=cut

sub archive {
    my ( $self ) = @_;

    my $prefix = $self->param( 'c_archive' )->{c_check_prefix} || 'archive';

    # Run custom pre-init operations
    $self->_pre_init_common_archive( $prefix );

    # Init tool
    $self->_init_common_archive;

    # Run custom post-init operations
    $self->_post_init_common_archive( $prefix );

    # Adds some buttons to the view
    $self->_common_buttons_archive( $prefix );

    # Archive objects
    $self->_common_archive( $prefix );

    my $x = $self->param( 'c_archive' )->{c_box_x} || 0;
    my $y = $self->param( 'c_archive' )->{c_box_y} || 0;

    $self->tool->Container->box_at( $x, $y )->name(
        $self->_msg( $self->param( 'c_archive' )->{c_box_title} || 'Box title' )
    );
    $self->tool->Container->box_at( $x, $y )->add_content(
        $self->gtool->get_sel( checkbox_id => $prefix )
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool_archive;

    return $self->generate_tool_content;
}

=pod

=head1 METHODS TO OVERRIDE

=head2 _pre_init_common_archive()

This method is meant to be overridden. It runs before I<_init_common_archive()>.

=cut

sub _pre_init_common_archive {
    my ( $self )  = @_;
}

=pod

=head2 _post_init_common_archive()

This method is meant to be overridden. It run after I<_init_common_archive()>.

By default, it adds a new path segment based on the action parameter
I<c_path_name>.

Hint: If you want to change properties of I<gtool()>, this is a good method
to override. Also, this is a good place to implement a new box just before the
list if you want to move the list box one level down.

=cut

sub _post_init_common_archive {
    my ( $self )  = @_;
    $self->tool->Path->add( name => $self->_msg(
        $self->param( 'c_archive' )->{c_path_name}
    ) ) if $self->param( 'c_archive' )->{c_path_name};
}

=pod

=head2 _pre_gen_tool_archive()

This method is meant to be overridden. It is run before
the tool is generated but just after the list box is
created.

Hint: this is a good place to place a new box just after the list box.

=cut

sub _pre_gen_tool_archive {
    my ( $self )  = @_;
}

=pod

=head2 _common_buttons_archive( PREFIX )

This method is meant to be overridden. It runs after
I<_post_init_common_archive()>.

By default, it adds a archive button with the checkbox prefix as the name in the
view.

Receives the checkbox prefix as a parameter.

Uses action parameters I<c_archive_text>, I<c_confirm_title> and
I<c_confirm_text> to generate a confirm box.

=cut

sub _common_buttons_archive {
    my ( $self, $prefix ) = @_;

    my $params = $self->param( 'c_archive' );

    $self->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->_msg( $params->{c_archive_text} || 'Archive checked' ),
        confirm_box => {
            title => $self->_msg(
                $params->{c_confirm_title} || 'Confirmation'
            ),
            name => $prefix,
            msg => $self->_msg(
                $params->{c_confirm_text}
                    || 'Are you sure you want to archive the selected items?'
            )
        }
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show archived' ),
        link  => $self->_replace_tags_in_link(
           '/ACTION_NAME/restore'
        )
    );

}

=pod

=head2 _pre_archive( HASHREF, DATA )

This method is meant to be overridden. It runs just before archiving the
checked objects with $self->gtool->Data->archive_group.

Receives a hashref of checked object ids. This is useful if you want to perform
something for each id.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
second parameter.

This method should return true if everything is ok. If it returns a
failure, the archive routines will not be run. In case of failure, remember
to leave an error message through $self->tool->add_message.

=cut

sub _pre_archive {
    my ( $self, $ids, $data ) = @_;
    return 1;
}

=pod

=head2 _post_archive( HASHREF, DATA )

This method is meant to be overridden. It runs just after archiving the
checked objects with $self->gtool->Data->archive_group.

Receives a hashref of checked object ids. This is useful if you want to perform
something for each id.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
second parameter.

Optionally, returns the alternative success message which replaces the default.

=cut

sub _post_archive {
    my ( $self, $ids, $data ) = @_;
}

=pod

=head2 _common_archive( PREFIX )

Checks if the button based on checkbox prefix is pressed, if it is,
archives the checked objects.

=cut

sub _common_archive {
    my ( $self, $prefix ) = @_;

    if ( CTX->request->param( $prefix ) ) {
        my $data = $self->gtool->Data;
        my $ids = Dicole::Utility->checked_from_apache( $prefix );
        if ( $self->_pre_archive( $ids, $data ) ) {
            my ( $code, $message ) = $data->remove_group( $prefix );
            if ( $code ) {
                my $new_message = $self->_post_archive( $ids, $data );
                $self->tool->add_message( $code, $new_message || $message );
            } else {
                $message = $self->_msg( "Error during archive: [_1]", $message);
                $self->tool->add_message( $code, $message );
            }
        }
    }

}

=pod

=head1 PRIVATE ACTION METHODS

=head2 _config_tool_archive( [KEY, VALUE] )

This accessor is for setting parameters passed to I<init_tool()> of
L<Dicole::Action>. The first parameter is the key and the second parameter
is the value. The accessor returns a hashref of current values.

Some examples of cases where this is required to modify is in cases the
requirement to change the number of columns and rows or if the page contains an
upload field. Best place to change these properties is through the
I<_post_init_tool_archive()> method.

=cut

sub _config_tool_archive {
    my ( $self, $key, $value ) = @_;
    unless ( ref( $self->{_config_tool_archive} ) eq 'HASH' ) {
        $self->{_config_tool_archive} = {};
    }
    if ( $key ) {
        $self->{_config_tool_archive}{$key} = $value;
    }
    return $self->{_config_tool_archive};
}

=pod

=head2 _init_common_archive()

Initializes L<Dicole::Generictool> object based on action
parameters I<c_class> and I<c_skip_security>, sets I<gtool> accessor
to that and fills the object with fields from fields.ini based on
task (view).

Sets active flag for the object.
This means it only displays objects in which the value of the field I<active>
is 1. When removing objects, doesn't really archive them but changes the value
of the active field to zero.

You can change the active field name with action parameter I<c_active_field>.
The default is I<active>.

=cut

sub _init_common_archive {
    my $self = shift;
    $self->_init_common_tool( {
        tool_config => $self->_config_tool_archive,
        class => $self->param( 'c_archive' )->{c_class},
        skip_security => $self->param( 'c_archive' )->{c_skip_security},
        view => ( split '::', ( caller(1) )[3] )[-1]
    } );
    $self->gtool->Data->flag_active( 1 );
    $self->gtool->Data->reverse_active( 1 );
    $self->gtool->Data->active_field(
        $self->param( 'c_archive' )->{c_archive_field} || 'archive'
    );                    
                        
    if ( ref( $self->param( 'c_archive' ) ) eq 'HASH' ) {
        if ( $self->param( 'c_archive' )->{c_active} ) {
            my $active_field = $self->param( 'c_archive' )
                ->{c_active_field} || 'active';
            if ( exists $self->gtool->Data->object->CONFIG->{field_map}{$active_field} ) {
   	       $active_field = $self->gtool->Data->object->CONFIG->{field_map}{$active_field};
   	    }
            $self->gtool->Data->add_where( "$active_field = 1" );
        }
    }
}

=head2 restore()

The task which creates the restore list view. Uses L<Dicole::Generictool> to
construct the view based on tool configuration.

The order of execution is as follows:

=over 4

=item 1.
Run I<_pre_init_common_restore()>

=item 2.
Run I<_init_common_restore()>

=item 3.
Run I<_post_init_common_restore()>

=item 4.
Run I<_common_buttons_restore()>

=item 5.
Run I<_common_restore()>

=item 6.
If restore button pressed, run I<_pre_restore()>

=item 7.
If restore button pressed and objects restored, run I<_post_restore>

=item 8.
Find out coordinates for the box based on action parameters
I<c_box_x> and I<c_box_y>

=item 9.
Generate restore box, use action parameter I<c_box_title> as the box
title

=item 10.
Run I<_pre_gen_tool_restore()>

=back

=cut

sub restore {
    my ( $self ) = @_;

    my $prefix = $self->param( 'c_restore' )->{c_check_prefix} || 'restore';

    # Run custom pre-init operations
    $self->_pre_init_common_restore( $prefix );

    # Init tool
    $self->_init_common_restore;

    # Run custom post-init operations
    $self->_post_init_common_restore( $prefix );

    # Adds some buttons to the view
    $self->_common_buttons_restore( $prefix );

    # Restore objects
    $self->_common_restore( $prefix );

    my $x = $self->param( 'c_restore' )->{c_box_x} || 0;
    my $y = $self->param( 'c_restore' )->{c_box_y} || 0;

    $self->tool->Container->box_at( $x, $y )->name(
        $self->_msg( $self->param( 'c_restore' )->{c_box_title} || 'Box title' )
    );
    $self->tool->Container->box_at( $x, $y )->add_content(
        $self->gtool->get_sel( checkbox_id => $prefix )
    );

    # Run custom pre-generate tool content operations
    $self->_pre_gen_tool_restore;

    return $self->generate_tool_content;
}

=pod

=head1 METHODS TO OVERRIDE

=head2 _pre_init_common_restore()

This method is meant to be overridden. It runs before I<_init_common_restore()>.

By default, overrides the tab with I<archive> tab.

=cut

sub _pre_init_common_restore {
    my ( $self )  = @_;
    $self->_config_tool_restore( 'tab_override', 'archive' );
}

=pod

=head2 _post_init_common_restore()

This method is meant to be overridden. It run after I<_init_common_restore()>.

By default, it adds a new path segment based on the action parameter
I<c_path_name>.

Hint: If you want to change properties of I<gtool()>, this is a good method
to override. Also, this is a good place to implement a new box just before the
list if you want to move the list box one level down.

=cut

sub _post_init_common_restore {
    my ( $self )  = @_;
    $self->tool->Path->del_last;
    $self->tool->Path->add( name => $self->_msg(
        $self->param( 'c_restore' )->{c_path_name}
    ) ) if $self->param( 'c_restore' )->{c_path_name};
}

=pod

=head2 _pre_gen_tool_restore()

This method is meant to be overridden. It is run before
the tool is generated but just after the list box is
created.

Hint: this is a good place to place a new box just after the list box.

=cut

sub _pre_gen_tool_restore {
    my ( $self )  = @_;
}

=pod

=head2 _common_buttons_restore( PREFIX )

This method is meant to be overridden. It runs after
I<_post_init_common_restore()>.

By default, it adds a restore button with the checkbox prefix as the name in the
view.

Receives the checkbox prefix as a parameter.

Uses action parameters I<c_restore_text> for the restore checked button.

=cut

sub _common_buttons_restore {
    my ( $self, $prefix ) = @_;

    my $params = $self->param( 'c_restore' );

    $self->gtool->add_bottom_button(
        name => $prefix,
        value => $self->_msg( $params->{c_restore_text} || 'Restore checked' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Show archive' ),
        link  => $self->_replace_tags_in_link(
           '/ACTION_NAME/archive'
        )
    );

}

=pod

=head2 _pre_restore( HASHREF, DATA )

This method is meant to be overridden. It runs just before restoring the
checked objects with $self->gtool->Data->restore_group.

Receives a hashref of checked object ids. This is useful if you want to perform
something for each id.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
second parameter.

This method should return true if everything is ok. If it returns a
failure, the restore routines will not be run. In case of failure, remember
to leave an error message through $self->tool->add_message.

=cut

sub _pre_restore {
    my ( $self, $ids, $data ) = @_;
    return 1;
}

=pod

=head2 _post_restore( HASHREF, DATA )

This method is meant to be overridden. It runs just after restoring the
checked objects with $self->gtool->Data->restore_group.

Receives a hashref of checked object ids. This is useful if you want to perform
something for each id.

Receives the $self->gtool->Data (L<Dicole::Generictool::Data>) object as a
second parameter.

Optionally, returns the alternative success message which replaces the default.

=cut

sub _post_restore {
    my ( $self, $ids, $data ) = @_;
}

=pod

=head2 _common_restore( PREFIX )

Checks if the button based on checkbox prefix is pressed, if it is,
restores the checked objects.

=cut

sub _common_restore {
    my ( $self, $prefix ) = @_;

    if ( CTX->request->param( $prefix ) ) {
        my $data = $self->gtool->Data;
        my $ids = Dicole::Utility->checked_from_apache( $prefix );
        if ( $self->_pre_restore( $ids, $data ) ) {
            my ( $code, $message ) = $data->remove_group( $prefix );
            if ( $code ) {
                my $new_message = $self->_post_restore( $ids, $data );
                $self->tool->add_message( $code, $new_message || $message );
            } else {
                $message = $self->_msg( "Error during restore: [_1]", $message);
                $self->tool->add_message( $code, $message );
            }
        }
    }

}

=pod

=head1 PRIVATE ACTION METHODS

=head2 _config_tool_restore( [KEY, VALUE] )

This accessor is for setting parameters passed to I<init_tool()> of
L<Dicole::Action>. The first parameter is the key and the second parameter
is the value. The accessor returns a hashref of current values.

Some examples of cases where this is required to modify is in cases the
requirement to change the number of columns and rows or if the page contains an
upload field. Best place to change these properties is through the
I<_post_init_tool_restore()> method.

=cut

sub _config_tool_restore {
    my ( $self, $key, $value ) = @_;
    unless ( ref( $self->{_config_tool_restore} ) eq 'HASH' ) {
        $self->{_config_tool_restore} = {};
    }
    if ( $key ) {
        $self->{_config_tool_restore}{$key} = $value;
    }
    return $self->{_config_tool_restore};
}

=pod

=head2 _init_common_restore()

Initializes L<Dicole::Generictool> object based on action
parameters I<c_class> and I<c_skip_security>, sets I<gtool> accessor
to that and fills the object with fields from fields.ini based on
task (view).

Sets archive flag for the object. This means it only displays objects in which
the value of the field I<archive> is 1. When restoring objects, doesn't really
restore them but changes the value of the I<archive> field to zero.

You can change the active field name with action parameter I<c_active_field>.
The default is I<active>.

=cut

sub _init_common_restore {
    my $self = shift;
    $self->_init_common_tool( {
        tool_config => $self->_config_tool_restore,
        class => $self->param( 'c_archive' )->{c_class},
        skip_security => $self->param( 'c_archive' )->{c_skip_security},
        view => ( split '::', ( caller(1) )[3] )[-1]
    } );
    $self->gtool->Data->flag_active( 1 );
    $self->gtool->Data->active_field(
        $self->param( 'c_archive' )->{c_archive_field} || 'archive'
    );

    if ( ref( $self->param( 'c_archive' ) ) eq 'HASH' ) {
        if ( $self->param( 'c_archive' )->{c_active} ) {
            my $active_field = $self->param( 'c_archive' )
                ->{c_active_field} || 'active';
            if ( exists $self->gtool->Data->object->CONFIG->{field_map}{$active_field} ) {
                $active_field = $self->gtool->Data->object->CONFIG->{field_map}{$active_field};
            }
            $self->gtool->Data->add_where( "$active_field = 1" );
        }
    }
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
