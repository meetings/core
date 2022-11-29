package Dicole::Generictool::FakeObject;

use 5.006;
use strict;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Fake SPOPS object for use with Generictool

=head1 SYNOPSIS

  use Dicole::Generictool::FakeObject;

  my $obj = Dicole::Generictool::FakeObject->new( { id => 'user_id' } );
  my $fake_id = $obj->id;

=head1 DESCRIPTION

The purpose of this class is to provide a way to pass fake SPOPS objects to
I<Generictool>. This is useful if you want to use the features Generictool
offers but you don't want to tie the functionality against a real SPOPS object
(maybe you don't have one, after all).

For setting the object attributes, do it directly, like I<$obj->{attr} = 'xyz'>.
This is not good OO practice but is required to imitate the SPOPS object tie
interface.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=head2 new( [HASHREF] )

Returns a new I<Dicole::Generictool::FakeObject> object. Optionally accepts initial
class attributes as parameter passed as an anonymous hash.

=head2 id( [STRING] )

Sets/gets the field id of the object. This is similar to SPOPS object id.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::FakeObject->mk_accessors(
	qw( id )
);

=pod 

=head1 SEE ALSO

L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
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

