package Dicole::Generictool::Wizard::Datasaver;

use 5.006;
use strict;
use OpenInteract2::Context   qw( CTX );
use Data::Dumper;

=pod

=head1 NAME

Dicole::Generictool::Wizard::Datasaver - The class used to preprocess and save wizard data.

=head1 SYNOPSIS

  my $page = Dicole::Generictool::Wizard::Page->new( wizard_id => $id );
  my $datasaver = Dicole::Generictool::Wizard::Datasaver->new( wizard_id => $id );
  
  $datasaver->wizard_data( $page->wizard_data() );
  foreach my $field ( @{ $page->fields() } ) {
  	$datasaver->field( $field );
  	my $method =  $datasaver->can( 'save_' . $field->type() );
  	if( $method ) { $datasaver->$method; }
  	else          { $datasaver->save_default(); }
  }
  

=head1 DESCRIPTION

The Datasaver objects are used to save wizard field data to the temporary database. The
data is first preprocessed according to the type of the field, and then it's saved.

The class contains a set of methods named save_${field_type}() where $field_type is
the type of the L<Dicole::Generictool::Field|Dicole::Generictool::Field> object. If a
method isn't found for a given field, save_defauld()-method can be used instead for basic
field types.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 field( [OBJECT] )

Sets/returns the field whose data the Datasaver should save.

=head2 wizard_data( [HASHREF] )

Sets/returns the hashref containing the wizard spops objects as
$field_id => $spops_object -pairs.

=head2 wizard_id( [SCALAR] )

Sets/returns the wizard id.

=cut

Dicole::Generictool::Wizard::Datasaver->mk_accessors(
	qw( field wizard_data wizard_id )
);

$Dicole::Generictool::Wizard::Datasaver::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 METHODS

=head2 new( HASH )

The constructor. The object parameters can be given in the argument hash. The argument wizard_id must always be given.

Parameters:

=over 4

=item B<wizard_id> I<scalar>

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

=pod

=cut

sub _init {
	my ( $self, $args ) = @_;
	croak( "Must provide wizard_id for Wizard data saver!" ) unless $args->{wizard_id};

	$self->wizard_id( $args->{wizard_id} );
	$self->wizard_data( $args->{wizard_data} );
}

=pod

=head2 save_default()

The default save method that should be used if a specialiced method isn't found.
Saves the field in the database as a single database row containing the field id
and field value.

=cut

sub save_default {
	my $self = shift;
	
	my $object = $self->_get_wizard_spops_object( $self->field()->id() );
	
	$object->{http_value} = CTX->request->param( $self->field()->id() );
	$object->save();
}

=pod

=head2 save_date()

Saves a date field to the db. A date field contains multiple dropdowns. This
method gathers the data from these dropdowns and forms a single string containing
the values of all the date dropdowns. The method saves the date in the db as a
single database row containing the date field id and a string of the form
"$date{year}-$date{month}-$date{day} $date{hour}:$date{minute}:0" .

=cut

sub save_date {
	my $self = shift;
	
	my $object = $self->_get_wizard_spops_object( $self->field()->id() );
	my %date = $self->_get_date_from_apache( $self->field()->id() );

	$object->{http_value} = "$date{year}-$date{month}-$date{day} $date{hour}:$date{minute}:0";
	$object->save();
}


sub save_advanced_select {
	my $self = shift;

	my $list = $self->_get_wizard_spops_object_list( $self->field()->id() );

	my $values = $self->field->value; # list of selected id's
	$values = [ $values ] if( $values && !(ref($values) eq 'ARRAY') ); 
	
	# remove spops objects if necessary:
	my (@new_list);
	foreach my $obj ( @{ $list } ) {
		if( grep { $_ eq $obj->{http_value}  } @{ $values } ) { push @new_list, $obj; }
		else { $obj->remove(); }
	}
	
	@{ $list } = @new_list; # the list now contains only valid selections

	# create new spops objects if necessary
	foreach my $value ( @{ $values } ) {
		unless( grep { $_->{http_value} eq $value } @{ $list } ) {
			my $obj = CTX->lookup_object('dicole_wizard_data')->new();
			$obj->{wizard_id} = $self->wizard_id();
			$obj->{http_name} = $self->field()->id();
			$obj->{http_value} = $value;
			push @{ $list }, $obj;
			$obj->save();
		}
	}
}

=pod

=head1 PRIVATE METHODS

=head2 _get_wizard_spops_object( SCALAR )

Returns the wizard data spops object for the field with the id given as argument.
A new object is created unless an object already exists for the given field.

If the wizard data element with the given field id is an array of objects, returns
the first object in this array. Note however, that this method should not be used
when accessing wizard data with multiple elements. This is just a fallback which is
used when for example the programmer accidentally(?) gives two of his/her fields identical
names.

=cut

sub _get_wizard_spops_object {
	my( $self, $field_id ) = @_;

	# get old object / create new (unless exists)
	my $object = exists $self->wizard_data()->{ $field_id } ? 
		$self->wizard_data()->{ $field_id } : CTX->lookup_object('dicole_wizard_data')->new();
	
	$object = $object->[0] if( ref $object eq 'ARRAY' ); # fallback

	$object->{wizard_id} ||= $self->wizard_id();
	$object->{http_name} ||= $field_id;
	
	$self->wizard_data()->{ $field_id } = $object unless( exists $self->wizard_data()->{ $field_id } );
	
	return $object;
}

sub _get_wizard_spops_object_list {
	my( $self, $field_id ) = @_;

	# get old list / create new (unless exists)
	my $list = exists $self->wizard_data()->{ $field_id } ? 
		$self->wizard_data()->{ $field_id } : [];
	
	$list = [ $list ] unless( ref $list eq 'ARRAY' ); # fallback

	$self->wizard_data()->{ $field_id } = $list unless( exists $self->wizard_data()->{ $field_id } );
	
	return $list;
}

=pod

=head2 _get_date_from_apache( SCALAR )

Converts the dropdown values of the given date field to a hash. The parameter defines the field id of the date field.
Returns a hash with keys 'day', 'month', 'year', 'hour' and 'minute' pointing to corresponding values.

=cut

sub _get_date_from_apache {
	my( $self, $field_id ) = @_;
	my( %date );

	foreach my $suffix ( 'day', 'month', 'year', 'hour', 'minute' ) {
		$date{ $suffix } = CTX->request->param( $field_id . '_' . $suffix ) || 0;
	}
	return %date;
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

