package Dicole::Generictool::SessionStore;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Hook for storing data in the user session

=head1 SYNOPSIS

  use Dicole::Generictool::SessionStore;
  $object = Dicole::Generictool::SessionStore->new(
  	{}
  );
  $object->by_key( 'search', 'Peter%', 'user_name' );
  $object->by_key( 'search', 'peter', 'login_name' );
  $object->del_by_key();

=head1 DESCRIPTION

The purpose of this class is to provide a way to hook into user session cache
for temporary user-specific data storage purposes.

If you want to provide your own storage cache, this is the class to inherit.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 new( { action => ARRAYREF } )

Returns a new I<Browse object>. I<action> parameter is required. Optionally
accepts initial class attributes as parameter passed in the anonymous hash.

=head2 action( [ARRAYREF] )

Sets/gets the action/task class attribute, which is used to identify the
handler and handler method in question.

=cut

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::SessionStore->mk_accessors(
	qw( action )
);

=pod

=head1 METHODS

=head2 by_key( STRING, [STRING], [STRING] )

Sets/gets the key in the session cache. First parameter is the cache
identification key to use, second is the value and third is the
optional key to use.

=cut

sub by_key {
	my ( $self, $key, $value, $column ) = @_;

	my $action = $self->action;

	my $location;
	
	if ( defined $column ) {
		$location = \$self->_session->{tool}{$action->[0]}{$action->[1]}{$key}{$column};
	} else {
		$location = \$self->_session->{tool}{$action->[0]}{$action->[1]}{$key};
	}

	if ( defined $value ) {
		${ $location } = $value;
	}

	return ${ $location };
}

=pod

=head2 del_by_key( STRING, STRING )

Deletes a key from the session cache. First parameter is the cache
identification key and the second one is the key to use.

=cut

sub del_by_key {
	my ( $self, $key, $column ) = @_;

	my $action = $self->action;
	
	if ( exists $self->_session->{tool}{$action->[0]}{$action->[1]}{$key}{$column} ) {
		delete $self->_session->{tool}{$action->[0]}{$action->[1]}{$key}{$column};
		return 1;
	}
	return undef;
}

=pod

=head1 PRIVATE METHODS

=head2 _session()

Returns an anonymous hash that points to the session cache.

=cut

sub _session {
	my ( $self ) = @_;
	return CTX->request->session;
}

=pod

=head1 SEE ALSO

L<SPOPS|SPOPS>, L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHORS

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

