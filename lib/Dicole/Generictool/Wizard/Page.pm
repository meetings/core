package Dicole::Generictool::Wizard::Page;

use 5.006;
use strict;
use Dicole::Generictool::Field::Construct;
use Dicole::Generictool::Field::Validate;
use Dicole::Generictool::FakeObject;
use Dicole::Generictool::Wizard::Datasaver;
use Dicole::Content::Controlbuttons;
use Dicole::Content::Button;
use Dicole::Content::List;
use Dicole::Content::Formelement;
use OpenInteract2::Context   qw( CTX );

$Dicole::Generictool::Wizard::Page::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Dicole::Generictool::Wizard::Page - The page objects used by L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>

=head1 SYNOPSIS

  my $page = Dicole::Generictool::Wizard::Page->new( wizard_id => $id, name => 'Hello world' );
  $page->add_field(
    id   => 'name',
    type => 'textfield',
    desc => 'Name',
  );

  # Generate Tool object
  my $tool = Dicole::Tool->new( action_params => $p );
  $tool->Container->generate_boxes( 1, 1 );
  $tool->Container->box_at( 0, 0 )->name( $page->name() );
  $tool->Container->box_at( 0, 0 )->add_content( $page->content() );

=head1 DESCRIPTION

The page objects are part of the Wizard objects. A wizard typically has
multiple pages, which are shown one after another.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 content( [ARRAYREF] )

Sets/returns the content of the wizard page as a list of L<Dicole::Content|Dicole::Content> -compatible
objects. Normally the content is generated automatically, so the user should use this methos only
to get the content.

=head2 wizard_data( [HASHREF] )

Sets/returns the raw wizard database data. The hash contains $field_id => $spops_object -pairs, and it
is used to 1) set old values for the fields if we are reaccessing a wizard page, and 2) gain access to
the spops objects to be able to save the changes the user has made.

=head2 wizard_id( [SCALAR] )

Sets/returns the random ID of the wizard instance.

=head2 page_number( [SCALAR] )

Sets/gets the ordinal number of this page (in the wizard). This is used to print
($obj->page_number/$obj->page_count) in the end of the page name when displaying page to the
user.

=head2 max_page_number( [SCALAR] )

Sets/gets the greatest page number accessed during this wizard.

=head2 page_count( [SCALAR] )

Sets/returns the total number of pages in the wizard. This is used to print
($obj->page_number/$obj->page_count) in the end of the page name when displaying page to the
user.

=head2 use_button_next( [BOOLEAN] )

Sets/returns the boolean value describing should we show the Next-button in the page when displaying it
to the user.

=head2 use_button_previous( [BOOLEAN] )

Sets/returns the boolean value describing should we show the Previous-button in the page when displaying it
to the user.

=head2 use_button_cancel( [BOOLEAN] )

Sets/returns the boolean value describing should we show the Cancel-button in the page when displaying it
to the user.

=head2 use_button_finish( [BOOLEAN] )

Sets/returns the boolean value describing should we show the Finish-button in the page when displaying it
to the user.

=head2 hidden_fields( [HASH] )

Sets/returns the hash containing extra hidden fields applied to the page.

=head2 page_id( [INTEGER] )

Sets/returns page id.

=cut

Dicole::Generictool::Wizard::Page->mk_accessors(
    qw( content wizard_data wizard_id page_number page_count max_page_number
        use_button_next use_button_previous use_button_cancel use_button_finish
            hidden_fields page_id gtool_options )
);

=pod

=head1 METHODS

=head2 new( HASH )

The constructor. The object parameters can be given in the argument hash. The argument wizard_id must always be given.

Parameters:

=over 4

=item B<name> I<scalar>

=item B<fields> I<array of objects>

=item B<wizard_data> I<hash of spops-objects>

=item B<wizard_id> I<scalar>

=item B<page_number> I<scalar>

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

    croak( "Must provide wizard_id for Wizard page!" ) unless $args->{wizard_id};

    $self->gtool_options(
        ref($args->{gtool_options}) eq 'HASH' ?
            $args->{gtool_options} : {}
    );

    $self->name( $args->{name} );
    $self->fields( $args->{fields} );
    $self->wizard_data( $args->{wizard_data} );
    $self->wizard_id( $args->{wizard_id} );
    $self->page_number( $args->{page_number} );
    $self->page_id( $args->{page_id} );

    $self->max_page_number( CTX->request->param('dicole_wizard_max_page_number') || -1 );
}

=pod

=head2 fields( [ARRAYREF] )

Sets/returns the array of L<Dicole::Generictool::Field|Dicole::Generictool::Field> objects.
Returns empty anonymous array if there aren't any fields defined.

=cut

sub fields {
    my ( $self, $arrayref ) = @_;

    return $self->Generictool->fields( $arrayref );
}

=pod

=head2 add_field( HASH )

Creates a new L<Dicole::Generictool::Field|Dicole::Generictool::Field> object. The given
arguments are passed on to the constructor. The new object is pushed in the end of the
fields array.

=cut

sub add_field {
    my ( $self, %args ) = @_;

    return $self->Generictool->add_field( %args );
}

=pod

=head2 name( [SCALAR] )

Sets/returns the name of the page. The returned value is "$given_or_stored_name ($self->page_number / $self->page_count)".

=cut

sub name {
    my ( $self, $value ) = @_;
    $self->{_name} = $value if( defined $value );
    return [ $self->{_name}. ' (' . ($self->page_number()+1) . '/' . $self->page_count() . ')' ];
}

=pod

=head2 activate()

Activates the page. This must be called after all the fields have been defined for the page
object (that is, after initialization). Normally the wizard object calls this method automatically
when calling $wizard->activate().

The method first sets the shown field values according to the temporary wizard database values
(if the db values were given to the object by calling wizard_data() method). Then the method
generates the page content and stores it in the internal variables. After this the content can
be accessed by calling the content() method.

=cut

sub activate {
    my $self = shift;

    $self->max_page_number( $self->page_number() ) if( $self->page_number > $self->max_page_number );

    $self->_update_field_values();
    $self->_generate_content();

}

=pod

=head2 save_fields()

Saves the data in the page's fields to the temporary wizard database. Uses the Datasaver object
to convert the html field values to suitable values that can be stored to the database.

=cut

sub save_fields {
    my $self = shift;
    $self->Datasaver()->wizard_data( $self->wizard_data() );

    foreach my $field ( @{ $self->fields() } ) {
        $self->Datasaver()->field( $field );

        my $method =  $self->Datasaver()->can( 'save_' . $field->type() );
        if( $method ) { $self->Datasaver()->$method; }
        else          { $self->Datasaver()->save_default(); }
    }
}

=pod

=head2 validate_fields()

Validates the user input. Uses the Validator object to check if the user input given in
html fields was valid. If any invalid input is detected (including empty values in
fields marked as required), the method returns 0. Otherwise 1 is returned. The error message
can be read from $page->Validator()->error_msg().

=cut

sub validate_fields {
    my $self = shift;
    foreach my $field ( @{ $self->fields() } ) {
        $self->Validator()->field( $field );

        my $method =  $self->Validator()->can( 'validate_' . $field->type() );
        if( $method ) { $self->Validator()->$method; }
        else          { $self->Validator()->validate_default(); }
        $self->Validator()->check_required();
    }

    return $self->Validator->error_msg() ? 0 : 1;
}

=pod

=head2 Datasaver( [SCALAR] )

Returns the page's Datasaver object. A new L<Dicole::Generictool::Wizard::Datasaver|Dicole::Generictool::Wizard::Datasaver>
object is created and stored in the internal variables unless one is previously initialized. The user
can provied a custom class name as argument if he/she wants to use some custom class as the Datasaver.

=cut

sub Datasaver {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Datasaver} = $class->new( wizard_id => $self->wizard_id() );
    }
    unless ( ref $self->{_Datasaver} ) {
        $self->{_Datasaver} = Dicole::Generictool::Wizard::Datasaver->new( wizard_id => $self->wizard_id() );
    }
    return $self->{_Datasaver};
}

=pod

=head2 Validator( [SCALAR] )

Returns the page's Validator object. A new L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>
object is created and stored in the internal variables unless one is previously initialized. The user
can provied a custom class name as argument if he/she wants to use some custom class as the Validator.

=cut

sub Validator {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Validator} = $class->new;
    }
    unless ( ref $self->{_Validator} ) {
        $self->{_Validator} = Dicole::Generictool::Field::Validate->new;
    }
    return $self->{_Validator};
}

=pod

=head2 Construct( [CLASS] )

Sets/gets the object that handles construction of content objects. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>
object.

Optionally accepts custom class as a parameter that handles
field construction instead.

=cut

sub Construct {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Construct} = $class->new;
    }
    unless ( ref $self->{_Construct} ) {
        $self->{_Construct} = Dicole::Generictool::Field::Construct->new;
    }
    return $self->{_Construct};
}

=pod

=head2 Generictool()

Returns the generictool object of this page.
Creates and initializes the GT-object unless one is already created.

=cut

sub Generictool {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Generict} = $class->new( %{ $self->gtool_options } );
    }
    unless ( ref $self->{_Generict}  ) {
        $self->gtool_options( {} ) unless( ref($self->gtool_options) eq 'HASH' );
        $self->{_Generict} = Dicole::Generictool->new( %{ $self->gtool_options } );
    }
    return $self->{_Generict};
}

=pod

=head1 PRIVATE METHODS

=head2 _construct_fields( ARRAYREF )

Goes through wizard fields defined in an
anonymous array (the parameter) and constructs appropriate
L<Dicole::Content|Dicole::Content> objects for each of them.

Returns an anonymous array containing the resulting content objects.

See L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>
for more information how the fields are converted to content objects.

=cut

sub _construct_fields {
    my ( $self, $fields ) = @_;

    my $content = [];

    $self->Construct->modifyable( 1 ); # default value for the fields

    foreach my $field ( @{ $fields } ) {

        my $value = undef;

        $self->Construct->field( $field );
        $self->Construct->object(
            Dicole::Generictool::FakeObject->new( { id => $field->id } )
        );

        # Check if we have a method with the same name as the field
        # type, and call it if true.
        my $method_ref = $self->Construct->can( 'construct_' . $field->type );
        if ( $method_ref ) {
            push @{ $content }, $self->Construct->$method_ref;
        }

    }

    return $content;
}

=pod

=head2 _generate_buttons()

Generates the buttons according to the object's internal variables.
Returns a L<Dicole::Content::Controlbuttons|Dicole::Content::Controlbuttons> object.

=cut

sub _generate_buttons {
    my $self = shift;
    my $buttons = [];

        my $lh = CTX->request->language_handle;

    push @{ $buttons }, Dicole::Content::Button->new(
        name => 'dicole_wizard_previous_button',
        value => $lh->maketext( 'Previous' )
    ) if( $self->use_button_previous() );

    push @{ $buttons }, Dicole::Content::Button->new(
        name => 'dicole_wizard_next_button',
        value => $lh->maketext( 'Next' )
    ) if( $self->use_button_next() );

    push @{ $buttons }, Dicole::Content::Button->new(
        name => 'dicole_wizard_finish_button',
        value => $lh->maketext( 'Finish' )
    ) if( $self->use_button_finish() );

    push @{ $buttons }, Dicole::Content::Button->new(
        name => 'dicole_wizard_cancel_button',
        value => $lh->maketext( 'Cancel' )
    ) if( $self->use_button_cancel() );

    return Dicole::Content::Controlbuttons->new(
        buttons => $buttons
    );

}


=pod

=head2 _generate_hidden_fields()

Generates the hidden form fields containing the wizard_id and
current wizard page number. Returns an array containing these
Dicole::Content::Formelement objects.

=cut

sub _generate_hidden_fields {
    my $self = shift;

    my @elements = (
        Dicole::Content::Formelement->new(
            attributes => {
                type => 'hidden',
                name => 'dicole_wizard_random_id',
                value => $self->wizard_id()
            }
        ),
        Dicole::Content::Formelement->new(
            attributes => {
                type => 'hidden',
                name => 'dicole_wizard_page_number',
                value => $self->page_number()
            }
        ),
        Dicole::Content::Formelement->new(
            attributes => {
                type => 'hidden',
                name => 'dicole_wizard_max_page_number',
                value => $self->max_page_number()
            }
        )
    );

    my $hf = $self->hidden_fields;
    return @elements if !ref $hf eq 'HASH';

    foreach ( keys %{$hf} ) {

            push @elements, Dicole::Content::Formelement->new(
            attributes => {
                type => 'hidden',
                name => $_,
                value => $hf->{$_},
            }
        );
    }

    return @elements;
}

=pod

=head2 _get_field_keys()

Returns an anonymous array containing a hash for each field in this page. The
contents of the hashes is { name => $field->desc() } .

=cut

sub _get_field_keys {
    my $self = shift;
    my $list = [];
    foreach my $field ( @{ $self->fields() } ) {
        push @{ $list }, { name => $field->desc };
    }
    return $list;
}

=pod

=head2 _generate_content()

Generates, saves and returns the page content. An anonymous
array containing the L<Dicole::Content|Dicole::Content> objects is returned.

=cut


sub _generate_content {
    my $self = shift;
    my( $content, $list );

    $list = Dicole::Content::List->new(
        type => 'horizontal',
        keys => $self->_get_field_keys
    );

    my $contentrow = [];
    foreach my $field ( @{ $self->_construct_fields( $self->fields() ) } ) {
        push @{ $contentrow }, { content => $field };
    }
    $list->add_content( [ $contentrow ] );

    $content = [
            [ $list, $self->_generate_buttons(), $self->_generate_hidden_fields() ]
        ];

    $self->content( $content );
    return $content;
}

=pod
sub _generate_content {
    my ( $self ) = @_;

    $self->content( [
        [ $self->Generictool->get_add, $self->_generate_buttons(), $self->_generate_hidden_fields() ]
    ] ;

    return $self->content;
}
=cut

=pod

=head2 _update_field_values( [HASH] )

Inserts data into the field objects. If field data can be found from apache parameters,
use that data -- otherwise use the data read from db. If neither exists, use the default
value set by the programmer. The default value can be set with the value()-method of the
L<Dicole::Generictool::Field|Dicole::Generictool::Field> object.

If there are multiple wizard data objects with the same http_name (for example the data of
a checkbox list), the field value is set to be an array containing all the values. Otherwise
the scalar http_value of the single data object is set as the field value.

The optional arguments can be given in a hash. The following arguments are supported:

=over 8

=item ignore_defaults => boolean (if true, don't use the default parameters)

=back

=cut

sub _update_field_values {
    my ($self, %args) = @_;

    # insert the data into the fields
    foreach my $field ( @{ $self->fields() } ) {
        $field->use_field_value(1);
        # if apache->param( $id ) is found, use it -- otherwise if the temporary db value
        # exists, use the db value. Otherwise use the default field value set by the programmer
        # (that is, don't change the value that has possibly been set earlier).
        if( defined CTX->request->param( $field->id() ) ) { $field->value( CTX->request->param( $field->id() ) ); }
        elsif( exists $self->wizard_data()->{ $field->id() } ) {
            if( ref $self->wizard_data()->{ $field->id() } eq 'ARRAY' ) {
                my @values = map { $_->{http_value} } @{ $self->wizard_data()->{ $field->id() } };
                $field->value( \@values );
            }
            else { $field->value( $self->wizard_data()->{ $field->id() }->{http_value} ); }
        }
        elsif( $args{ignore_defaults} ) {
            $field->value( undef ); # clear the default parameter
        }
    }

}

=pod

=head1 SEE ALSO

L<Dicole|Dicole>,
L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>,
L<Dicole::Generictool::Wizard::Page::Switch|Dicole::Generictool::Wizard::Page::Switch>,
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

