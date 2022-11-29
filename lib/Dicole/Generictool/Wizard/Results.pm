package Dicole::Generictool::Wizard::Results;

use 5.006;
use OpenInteract2::Context   qw( CTX );
use strict;

=pod

=head1 NAME

Dicole::Generictool::Wizard::Results - The class used to convert wizard database data to a more useful form.

=head1 SYNOPSIS

  my $results = {};
  # $wizard object has Results()-method which returns a Dicole::Generictool::Wizard::Results object
  $wizard->Results()->wizard_data( $wizard->_wizard_data() );
  foreach my $page ( @{ $wizard->pages() } ) {
  	$page->wizard_data( $wizard->_wizard_data() );
  	foreach my $field ( @{ $page->fields() } ) {
  		$wizard->Results()->field( $field );
  		my $method =  $wizard->Results()->can( 'results_' . $field->type() );
  		$results->{ $field->id() } = $method ?
  			$wizard->Results()->$method : $wizard->Results()->results_default();
  	}
  }
  

=head1 DESCRIPTION

The Results objects are used to convert saved wizard field data from database to a more useful
form. 

The class contains a set of methods named results_${field_type}() where $field_type is
the type of the L<Dicole::Generictool::Field|Dicole::Generictool::Field> object. If a
method isn't found for a given field, results_defauld()-method can be used instead for basic
field types.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 field( [OBJECT] )

Sets/returns the field whose database data the Results object should convert.

=head2 wizard_data( [HASHREF] )

Sets/returns the wizard data hash containing $field_id => $spops_object pairs.

=cut

Dicole::Generictool::Wizard::Results->mk_accessors(
	qw( field wizard_data )
);

$Dicole::Generictool::Wizard::Results::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 METHODS

=head2 new( HASH )

The constructor. The object parameters can be given in the argument hash.

Parameters:

=over 4

=item B<wizard_data> I<hashref>

=back

=cut

sub new {
	my ($class, %args) = @_;
	my $config = { };
	my $self = bless( $config, $class );

	# Initialization is handled in _init because we want our object to be
	# easily inheritable.
	$self->_init(\%args );

	return $self;
} 


sub _init {
	my ( $self, $args ) = @_;

	$self->wizard_data( $args->{wizard_data} );
}

=pod

=head2 results_default()

Returns object value.

=cut

sub results_default {
	my $self = shift;
	
	my $object = $self->_get_wizard_spops_object( $self->field()->id() );
	return $object->{http_value} if( defined $object );
	return undef;
}

=pod

=head2 results_date()

Retruns the date data as an anonymous hash containing keys 
'day', 'month', 'year', 'hour' and 'minute' pointing to corresponding values.

=cut

sub results_date {
	my $self = shift;
	
	my $object = $self->_get_wizard_spops_object( $self->field()->id() );
	if( defined $object ) {
		# yyyy-mm-dd hh:mm:ss format
		if ( $object->{http_value} =~ /^(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)$/ ) {
			return {
				day    => $3,
				month  => $2,
				year   => $1,
				hour   => $4,
				minute => $5
			}; 
		}
	}
	return undef;
}

sub results_advanced_select {
	my $self = shift;
	
	my $list = $self->_get_wizard_spops_object_list( $self->field->id );
	my @values = map { $_->{http_value} } @{ $list };
	return \@values;
}

=pod

=head1 PRIVATE METHODS

=head2 _get_wizard_spops_object( SCALAR )

Returns the spops object with the given field id. If an object
with the given field id isn't found, return undef.

=cut

sub _get_wizard_spops_object {
	my( $self, $field_id ) = @_;

	# return spops object OR undef unless object exists
	my $obj = exists $self->wizard_data()->{ $field_id } ? 
		$self->wizard_data()->{ $field_id } : undef;
		
	$obj = $obj->[0] if( ref( $obj ) eq 'ARRAY' ); # fallback
	
	return $obj;
}

sub _get_wizard_spops_object_list {
	my( $self, $field_id ) = @_;

	# return spops object OR undef unless object exists
	my $list = exists $self->wizard_data()->{ $field_id } ? 
		$self->wizard_data()->{ $field_id } : [];
		
	$list = [ $list ] unless( ref( $list ) eq 'ARRAY' ); # fallback
	
	return $list;
}

=pod

=head1 SEE ALSO

L<Dicole|Dicole>, 
L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>, 
L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, 
L<Dicole::Generictool::Field|Dicole::Generictool::Field>, 
L<OpenInteract|OpenInteract>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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

