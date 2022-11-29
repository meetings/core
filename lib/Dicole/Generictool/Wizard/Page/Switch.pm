package Dicole::Generictool::Wizard::Page::Switch;

use 5.006;
use OpenInteract2::Context   qw( CTX );
use strict;

=pod

=head1 NAME

Dicole::Generictool::Wizard::Page::Switch - The page switch objects used by L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>

=head1 SYNOPSIS

  my $switch = Dicole::Generictool::Wizard::Page::Switch->new( wizard_id => $id, name => 'Hello world' );
  my $page_a = $switch->add_page( 
  	name => 'English',  
  	display_if => { 
  		language => 'en' 
  	}
  );
  $page_a->add_field(
  	id   => 'name',
  	type => 'textfield',
  	desc => 'Name',
  );
  my $page_b = $switch->add_page( 
  	name => 'Finnish',  
  	display_if => { 
  		language => 'fi' 
  	}
  );
  $page_b->add_field(
  	id   => 'nimi',
  	type => 'textfield',
  	desc => 'Nimi',
  );
  # Generate Tool object
  my $tool = Dicole::Tool->new( action_params => $p );
  $tool->Container->generate_boxes( 1, 1 );
  $tool->Container->box_at( 0, 0 )->set_name( $page->name() );
  $tool->Container->box_at( 0, 0 )->add_content( $page->content() );

=head1 DESCRIPTION

The page switch objects are part of the Wizard objects. A wizard typically has
multiple pages, which are shown one after another. A page switch object is a 
Page object -- that is, it implements the Page interface, plus adds a couple
of methods more.

A page switch can contain multiple pages which are shown conditionally. The added pages' 
display_if -requirements are checked, and the first page, whose all display_if
requirements are met, is displayed when requesting switch's name & content.
The display_if hashes contain $field_id => $value -pairs. The field ids should be
ids of fields that were displayed in some previous wizard pages. 

The developer should make sure that there is at least one page, whose display_if requirements
are met. The module doesn't produce any meaningful output unless a suitable page object is found.

=head1 INHERITS

Inherits L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, and 
overwrites some methods.

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Dicole::Generictool::Wizard::Page Class::Accessor );
use Dicole::Generictool::Wizard::Page;
use Dicole::Generictool::Wizard::Page::AdvancedSelect;
use Dicole::Generictool::Wizard::Page::Info;

use Data::Dumper;
use Dicole::Content::Text;

=pod

=head1 METHODS

=head2 _page_id_counter( [INTEGER] )

Holds the last id assigned to a page below this switch.

=cut

Dicole::Generictool::Wizard::Page::Switch->mk_accessors(
	qw( _page_id_counter )
);

$Dicole::Generictool::Wizard::Page::Switch::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 METHODS

=head2 new( HASH )

Constructor. Accepts all superclass's arguments & an additional argument: 

=over 4

=item B<pages> I<anonymous array of hashes> .

=back

=cut

sub _init {
	my ( $self, $args ) = @_;

	$self->SUPER::_init( $args ); # call _init() of the parent class
        $self->_page_id_counter( 0 );
	$self->pages( $args->{pages} );
}

=pod

=head2 content()

Returns the content of the shown switch page.
Returns an empty arrayref unless a suitable page was found.

=cut

## returns ref to empty array unless a suitable page was found
sub content {
	my $self = shift;

	my $shown_page = $self->ShownPage;
	return $shown_page->content if( defined $shown_page );
	return []; 
#	return [ Dicole::Content::Text->new( content => Dumper($self) ), Dicole::Content::Text->new( content => $self->_shown_page_index() ), Dicole::Content::Text->new( content => Dumper($self->ShownPage) ) ]; # debug
}

=pod

=head2 name( [SCALAR] )

Sets/returns the name of the page switch.

The returned value is of the form "$switch_name :: $shown_page_name ($page_index / $wizard_page_count)" .

=cut

sub name {
	my( $self, $name ) = @_;

#	$self->{_name} = $name if( defined $name );

#	my $name = $self->{_name};
	my $shown_page = $self->ShownPage;
	return $shown_page->name if( defined $shown_page );
	return $name;
}

=pod

=head2 activate()

This method should be called after initialization. It activates
the currently shown switch page.

=cut

sub activate {
	my $self = shift;

	$self->max_page_number( $self->page_number() ) if( $self->page_number > $self->max_page_number );

	my $shown_page = $self->ShownPage();
	if( defined $shown_page ) {
		$shown_page->wizard_data( $self->wizard_data() );
		$shown_page->page_number( $self->page_number() );
		$shown_page->page_count( $self->page_count() );
		$shown_page->hidden_fields( $self->hidden_fields );

		$shown_page->use_button_previous( $self->use_button_previous() );
		$shown_page->use_button_next( $self->use_button_next() );
		$shown_page->use_button_finish( $self->use_button_finish() );
		$shown_page->use_button_cancel( $self->use_button_cancel() );

		$shown_page->activate();
	}

}

=pod

=head2 validate_fields()

Validates the fields of the currently shown switch page.
Returns false unless a suitable page was found.

=cut

## returns 0 unless a suitable page is found
sub validate_fields {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	if( defined $shown_page ) {
		$shown_page->wizard_data( $self->wizard_data() );
		return $shown_page->validate_fields();
	}
	return 0;
}

=pod

=head2 save_fields()

Saves the fields of the currently shown switch page.

=cut

sub save_fields {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	if( defined $shown_page ) {
		$shown_page->wizard_data( $self->wizard_data() );
		$shown_page->save_fields();
	}
}

=pod

=head2 fields()

Sets/returns the fields array of the currently shown page. If there
isn't a currently shown page, returns empty anonymous array.

=cut

sub fields {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	return $shown_page->fields(@_) if( defined $shown_page );
	return [];
}

=pod

=head2 pages( [ARRAYREF] )

Sets the switch pages. The array should contain a set of anonymous hashes
with content like { page => $page_object, display_if => \%display_if_requirements } .

=cut

sub pages {
	my ( $self, $pagesref ) = @_;
	
	$self->{pages} = $pagesref if( ref $pagesref eq 'ARRAY' );
	$self->{pages} = [] unless( ref $self->{pages} eq 'ARRAY' );
	
	return $self->{pages};
}

=pod

=head2 add_page( HASH )

Generates and adds a new Page object to the switch. The given hash arguments are
passed on to the page constructor. The hash should also contain B<display_if> argument
with an anonymous hash as its value. The hash should contain the requirements that must
be met before this page can be displayed. The requirements are defined as $field_id => $value -pairs.

=cut

# generates,adds and returns a new Page object
sub add_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page->new( 
		wizard_id => $self->wizard_id(), 
		page_number => $self->page_number,
                page_id => $self->page_id.'_'.$self->next_page_id,
		%page_args 
	);
	push @{$self->pages}, { page => $new_page, display_if => $page_args{display_if} };
	return $new_page;
}

=pod

=head2 add_advanced_select_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::AdvancedSelect|Dicole::Generictool::Wizard::Page::AdvancedSelect> object
and passes the given arguments to the constructor. The hash should also contain B<display_if> argument
with an anonymous hash as its value. The hash should contain the requirements that must
be met before this page can be displayed. The requirements are defined as $field_id => $value -pairs.

=cut

sub add_advanced_select_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::AdvancedSelect->new(
		wizard_id => $self->wizard_id(), 
		page_number => $self->page_number,
                page_id => $self->page_id.'_'.$self->next_page_id,
		%page_args 
	);
	push @{$self->pages}, { page => $new_page, display_if => $page_args{display_if} };
	return $new_page;
	
}

=pod

=head2 add_info_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::Info|Dicole::Generictool::Wizard::Page::Info> object
and passes the given arguments to the constructor. The hash should also contain B<display_if> argument
with an anonymous hash as its value. The hash should contain the requirements that must
be met before this page can be displayed. The requirements are defined as $field_id => $value -pairs.

=cut

sub add_info_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::Info->new(
		wizard_id => $self->wizard_id(), 
		page_number => $self->page_number,
                page_id => $self->page_id.'_'.$self->next_page_id,
		%page_args 
	);
	push @{$self->pages}, { page => $new_page, display_if => $page_args{display_if} };
	return $new_page;
	
}

=pod

=head2 next_page_id()

Adds one to _page_id_counter and returns the new count.

=cut

sub next_page_id {
	my $self = shift;
        return $self->_page_id_counter( $self->_page_id_counter + 1 );
}


=pod

=head2 Validator()

Returns the Validator object of the currently shown page. Returns undef
unless a suitable page is found.

=cut

sub Validator {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	return $shown_page->Validator() if( defined $shown_page );
	return undef;
}

=pod

=head2 Datasaver()

Returns the Datasaver object of the currently shown page. Returns undef unless
a suitable page is found.

=cut

sub Datasaver {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	return $shown_page->Datasaver() if( defined $shown_page );
	return undef;
}

=pod

=head2 Construct()

Returns the Construct object of the currently shown page. Returns undef unless
a suitable page is found.

=cut

sub Construct {
	my $self = shift;
	my $shown_page = $self->ShownPage();
	return $shown_page->Construct() if( defined $shown_page );
	return undef;
}

=pod

=head2 switch_page_count()

Returns the number of pages in the switch's page array.

=cut

sub switch_page_count {
	my $self = shift;
	return scalar @{ $self->pages() };
}

=pod

=head2 ShownPage()

Returns the currently shown page object. If there isn't a single page whose display_if requirements
are met, undef is returned. 

=cut

# (Perhaps this "undef-behaviour" should be modified to make a more robust 
# system? Perhaps we should return a generic empty page, or a page displaying error message? After
# all, this should never happen, as the programmer should take care of defining at least some kind
# of fall-back page for the switch.)

sub ShownPage {
	my $self = shift;
	my $index = $self->_shown_page_index();
	return $self->pages()->[ $index ]->{page} if( defined $index );
	return undef;
}

=pod

=head1 PRIVATE METHODS

=head2 _shown_page_index()

Iterates through all the pages in this switch's page array. The index
of the first page whose all display_if requirements are met is returned.
Returns undef if there isn't a page whose all requirements are met.

Note that the requirement checking is literal, and thus display_if requirements
{ page_switch => '1' } and { page_switch => '01' } are _not_ equal.

=cut

## Check each page in the page switch. The index of the first page whose all display_if 
## requirements are met is returned. If none of the pages meets the requirements, undef is 
## returned. Note that the requirement checking is literal, and thus for example '00' and '0'
## do not match.
##
## Perhaps the value should be cached to prevent repeating this calculation?
## If caching is done, we must ensure that cache is emptied when $self->wizard_data() changes.
sub _shown_page_index {
	my $self = shift;
	
	for (my $i=0; $i<$self->switch_page_count(); $i++) {
		my $ok = 1;
		$self->pages()->[$i]->{display_if} = {} unless( ref $self->pages()->[$i]->{display_if} eq 'HASH' );
		foreach my $field_id ( keys %{ $self->pages()->[$i]->{display_if} } ) {
			my $field_value = $self->pages()->[$i]->{display_if}->{$field_id};
			if( exists $self->wizard_data()->{$field_id} && $self->wizard_data()->{$field_id}->{http_value} ne $field_value ) {
				$ok = 0;
				last;
			}
		}
		return $i if( $ok );
	}
	return undef;
}

=pod

=head1 SEE ALSO

L<Dicole|Dicole>, 
L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>, 
L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, 
L<Dicole::Generictool::Wizard::Results|Dicole::Generictool::Wizard::Results>, 
L<Dicole::Generictool::Field|Dicole::Generictool::Field>, 
L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>, 
L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>,
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

