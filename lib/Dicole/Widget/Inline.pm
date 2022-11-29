package Dicole::Widget::Inline;

use strict;

use base qw( Dicole::Widget::Container );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_inline' };

1;

=pod
=head1 NAME

Horizontal items widget

=head1 SYNOPSIS

   my $container = Dicole::Widget::Inline->new(
      contents => [ Dicole::Widget::Text->new( text => 'Hello', ... ) ]
);

=head1 DESCRIPTION

This is a general purpose horizontal list class that can be used to make a horizontal list of widgets that appear one after anoter.

Returns data in format understood by the template I<dicole_base::widget_horizontal>.

=head1 INHERITS

Inherits L<Dicole::Widget::Container>.

=cut


=pod

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>
L<Dicole::Widget::Element|Dicole::Widget::Element>
L<Dicole::Widget::Container|Dicole::Widget::Container>

=head1 AUTHOR

Antti Vähäkotamäki, E<lt>antti@dicole.comE<gt>

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
