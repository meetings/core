package Dicole::SessionStore;

use 5.006;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper;
use constant SS => 'sessionstore';

our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Hook for storing data in the user session

=head1 SYNOPSIS

  use Dicole::SessionStore;

  my $ss = Dicole::SessionStore->new( CTX->request->session );

  my $ss = CTX->request->sessionstore;

  $ss->set_value( 'key1', 'key2', 'value' );
  $ss->get_value( 'key1', 'key2' );
  $ss->delete_value( 'key1', 'key2' );

  my @path = ( qw( a b c d e f g h i j ) );
  $ss->set_value( @path, 'deep_value' );


=head1 DESCRIPTION

The purpose of this class is to provide a way to hook into user session cache
for temporary user-specific data storage purposes.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=cut

use base qw( Class::Accessor );

Dicole::SessionStore->mk_accessors(
    qw( session )
);


=pod

=head1 CONSTRUCTOR AND ACCESSORS

=head2 new( [ SESSION ] )

Constructor. If session is not provided tries to fetch CTX->request->session.

=cut

sub new {
    my ( $class, $session ) = @_;

    $session ||= CTX->request->session;

    my $self = {};

    bless $self, $class;

    $self->session( $session );

    return $self;
}

=pod

=head2 session( [ SESSION ] )

Sets/gets the session used for storing the data.


=head1 METHODS

=head2 get_value( SCALAR * )

Returns the specified data. Accepts as many levels of nested identifiers
for your data as you wish.

=cut

sub get_value {
    my ( $self, @array ) = @_;

    my $string = $self->_create_hash_string( @array );
    my $value = eval $string;

    return $value;
}

=head2 set_value( SCALAR *, SCALAR )

Set the specified data to value given as last argument. Accepts as many
levels of nested identifiers for your data as you wish.

=cut

sub set_value {
    my ( $self, @array ) = @_;

    my $value = pop @array;
    my $string = $self->_create_hash_string( @array );

    eval "$string = \$value";

    return $value;
}

=head2 value_exists( SCALAR * )

Return 1 if defined value exists. 0 otherwise.

=cut

sub value_exists {
    my ( $self, @array ) = @_;

    my $string = $self->_create_hash_string( @array );

    return (defined "$string") ? 1 : 0;
}

=head2 delete_value( SCALAR * )

Deletes the specified data. Accepts as many levels of nested identifiers
for your data as you wish.

=cut

sub delete_value {
    my ( $self, @array ) = @_;

    my $string = $self->_create_hash_string( @array );

    return eval "delete $string";
}

## SUBROUTINES

# _create_hash_string creates the hash structure suitable for eval

sub _create_hash_string {
    my ( $self, @array ) = @_;

    my @secure = @array;
    $_ =~ s/'//g foreach @secure;

    return "\$self->session->{'" . SS . "'}->{'". join( "'}->{'_h'}->{'", @secure ) . "'}->{'value'}";
}


=head1 AUTHORS

Antti Vähäkotamäki, E<lt>antti@ionstream.fiE<gt>

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

