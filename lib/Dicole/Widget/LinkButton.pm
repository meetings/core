package Dicole::Widget::LinkButton;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

LinkButton widget

=head1 SYNOPSIS

my $button = Dicole::Widget::LinkButton->new(
    href => '#',
    text => $self->_msg('Do magic'),

    # optional
    id => 'magic_button',
    class => 'additional classes',
    onclick => 'alert "magick"'
);

=head1 DESCRIPTION

LinkButton class!

Returns data in format understood by the template
I<dicole_base::widget_linkbutton>.

=head1 INHERITS

Inherits L<Dicole::Widget>.

=cut

use base qw( Dicole::Widget::Element );

=pod

=head1 ACCESSORS

=head2 text( [STRING] )

Button text.

=head2 href( [STRING] )

Link where button is pointing.

=head2 onclick( [STRING] )

Some javascript.

=cut

sub DEFAULT_TEMPLATE { 'widget_linkbutton' };

sub ACCESSORS { (
    onclick => Dicole::Widget::ACCESSOR_RAW,
    link => Dicole::Widget::ACCESSOR_RAW,
    text => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;

=pod

=head1 METHODS

=head2 new( [ %ARGS ] )

Creates object with optionally provided attributes.

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>antti@dicole.orgE<gt>

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


