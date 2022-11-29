package Dicole::Action::Common;

# $Id: Common.pm,v 1.5 2009-01-07 14:42:32 amv Exp $

use base ( 'Dicole::Action' );

use strict;
use OpenInteract2::Context   qw( CTX );
use Dicole::Pathutils;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper base class

=head1 SYNOPSIS

 use base qw( Dicole::Action::Common );

=head1 DESCRIPTION

The purpose of this class is to inherit L<Dicole::Action> and provide
some generic methods for common action tasks to use. This class is not meant to
be used directly but is subclassed by various I<Dicole::Action::Common::*>
classes and used as a basis of implementation.

=head1 PRIVATE METHODS

=head2 _replace_tags_in_link( LINK, ID )

Usually used to replace certain tags in links. The following tags will be
replaced in the provided link:

=over 4

=item IDVALUE
Replaced with the provided ID (see method parameters).

=item GROUPID
Replaced with the target group id, third part of the path.

=item USERID
Replaced with the target user id, third part of the path.

=item TARGETID
Replaced with the target id, third part of the
path.

=item ACTION_NAME
Replaced with the current action name.

=item TASK_NAME
Replaced with the current action's task name.

=item PATH
Replaced with the components in the path (excluding action, task and target id if present).

=back

=cut

sub _replace_tags_in_link {
    my ( $self, $link, $link_id ) = @_;
    $link =~ s/IDVALUE/$link_id/gs if $link_id;
    $link =~ s/GROUPID/CTX->request->target_group_id/ges;
    $link =~ s/USERID/CTX->request->target_user_id/ges;
    $link =~ s/TARGETID/CTX->request->target_id/ges;
    $link =~ s/ACTION_NAME/CTX->controller->initial_action->name/ges;
    $link =~ s/TASK_NAME/CTX->controller->initial_action->task/ges;
    my $urlpath = Dicole::Pathutils->new;
    $urlpath->url_base_path( CTX->request->target_id ) if CTX->request->target_id;
    $link =~ s/PATH/$urlpath->get_current_path( 1 )/ges;
    return $link;
}

=pod

=head2 _init_common_tool( HASHREF )

Initializes L<Dicole::Generictool> object based on provided parameters.
Sets I<gtool> accessor to that and fills the object with fields from
I<fields.ini> based on task (view).

Hashref parameters:

=over 4

=item tool_config
A hashref of the configuration to pass to I<init_tool()>.

=item view
The view name to use. Uses caller method if none provided.

=item class
The SPOPS class to provide for CTX->lookup_object.

=item skip_security
If true, skips SPOPS security when prosessing SPOPS objects.

=back

=cut

sub _init_common_tool {
    my ( $self, $params ) = @_;

    $params ||= {};

    $self->init_tool( $params->{tool_config} );
    my $view = $params->{view} || ( split '::', ( caller(1) )[3] )[-1];
    $self->gtool(
        Dicole::Generictool->new(
            ( $params->{class}
                ? ( object => CTX->lookup_object( $params->{class} ) ) : ()
            ),
            skip_security => $params->{skip_security},
            current_view => $view,
        )
    );
    $self->init_fields;
}

=pod

=head1 SEE ALSO

L<Dicole::Action>

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
