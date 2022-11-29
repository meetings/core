package Dicole::Generictool;

use strict;
use URI::URL;

use SPOPS::Utility;

use OpenInteract2::Context   qw( CTX );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use constant LOG_TOOL => 'DLE.TOOL';
my $log = ();

use Dicole::Generictool::Data;
use Dicole::Generictool::Field;
use Dicole::Generictool::Field::Validate;
use Dicole::Generictool::Field::Construct;
use Dicole::Generictool::Search;
use Dicole::Generictool::Sort;
use Dicole::Generictool::Browse;

use Dicole::Content::Controlbuttons;
use Dicole::Content::Button;
use Dicole::Content::List;
use Dicole::Content::Formelement;

use Dicole::Utility;
use Dicole::Calcfunc;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.45 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

For creating generic Dicole features

=head1 SYNOPSIS

  use Dicole::Generictool;
  use Dicole::Tool;
  use OpenInteract::Request;

  # Create new tool object
  my $tool = Dicole::Tool->new( action_params => $p );

  $tool->Container->generate_boxes( 1, 1 );

  # Create new generictool object
  my $gentool = Dicole::Generictool->new(
    object => CTX->lookup_object('user'),  # SPOPS class the application uses
  );

  # Add new field
  my $login_name = $gentool->add_field( id => 'login_name' );
  $login_name->type( 'textfield' );
  $login_name->required( 1 );
  $login_name->desc( 'Login name' );
  $login_name->link( '/usermanager/show/?uid=IDVALUE' );

  # Set views which we are going to use in this action
  $gentool->views( [ 'list_view' ] );

  # Set that each generictool view contains the fields
  $gentool->set_fields_to_views;

  $tool->Path->add( name => 'List users' );

  # Modify tool object to contain list view in a single legend box
  $tool->Container->box_at( 0, 0 )->name( 'List of users' );
  $tool->Container->box_at( 0, 0 )->add_content( $gentool->get_list( 'list_view' ) );

  return $action->generate_content( $tool->generate_content_params );

=head1 DESCRIPTION

The purpose of this class is to provide generic methods that allow easy
creation of a web-based application that works around a database of
objects.

Most applications that work with some sort of data objects usually are
satisfactory when they provide at least functionality to add, list, remove,
show and edit objects.

I<Dicole::Generictool> tries to address these general requirements of
an application and adds a little bit more.

=head2 Definition of fields

Most applications work around the same set of data, or more precisely,
same set of object fields. These fields gain meaning when some kind of
description is attached to each field for user to easily identify and
come up with an idea what the field should contain.

There are several different types of object fields. Some common types of
fields are text fields, multi-line text fields, dropdowns and date
selection fields to name a few. There might be even more obscure fields
like a set of input fields that together define ISBN number for a book or
someones social security number.

The basic idea of I<Generictool> is to define these fields first by
defining some meta-data to identify each one of them:

  # Lets add a new field
  my $login_name = $gentool->add_field( id => 'login_name' );
  $login_name->type( 'textfield' );
  $login_name->required( 1 );
  $login_name->desc( 'Login name' );
  $login_name->link( '/usermanager/show/?uid=IDVALUE' );

For the sake of consistency, field id is the same as the field id in our
I<SPOPS> data class.

Field I<description> defines the visual identification that gives the user
a hint what the field should contain, while field id is usually used behind
the scenes, e.g. as a way to identify a browser form element.

When our business logic (objects, what fields they contain and what
data the fields should contain) is defined this way, we notice that
the exactly same data is used in most web-based applications to identify
general ways to modify the objects included in the application.

The semantics of the fields differ pretty much depending on what context it
is displayed in  our application. For example, the I<description> on a
listing page is most likely the name of the column and on an editing page
it is the identification of the form fields.

The method I<Dicole> uses is to convert these basic definitions of fields
to whatever our intention is. For example, on an editing page a
field of type I<date> should have three dropdowns for user to select day,
month and year. On show page, the field should display the date as simple
text like I<YYYY/MM/DD>. As a conclusion, the display and functionality
are both different on each different action page, yet the fundamentals
of the fields remain.

For more information about field definition, see documentation of
L<Dicole::Generictool::Field|Dicole::Generictool::Field>.

=head2 Examples of functionality

With relatively small ammount of pain (and even less code), I<Generictool>
is able to to construct a functional I<view> for the user by interacting
between fields and functionality (user input):

=over 4

=item B<Adding new objects>

I<Generictool> is able to create a page for adding new objects based on
the defined fields. The input form appears empty when first time accessed.
If user fills the form and submits it, it is validated with basic rules
before approved for addition as an object to the database. If input
validation fails, the form returns with an error and indicators of
fields that contain invalid or insufficient information. When an object is
added to the database, the form returns as empty for adding yet another object.

For more information about input validation and mapping fields as functional
forms, see documentation of
L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate> and
L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Construct>.

=item B<editing existing objects>

I<Generictool> is able to create a page for editing existing objects.
This is achieved by mapping the object data against the fields
and displaying the result to the user as an modifyable input form. Mostly the
same input validation features as in our generic add page works here as well,
expect that the form remains filled after the object has been edited in the
database.

For more information about retrieving object data for mapping against
fields, see documentation of
L<Dicole::Generictool::Data|Dicole::Generictool::Data>.

=item B<Showing object details>

This is pretty much the same as our generic edit but the catch is that the
form is converted to read-only data for display purposes only. Each field
is converted to its' read-only version.

=item B<Listing objects>

A way to list all objects in the database on one page. The objects are linkable
and links lead to editing or displaying the contents of each object (see showing
and editing of objects above). Because we want to provide user-friendly
interfaces, some functionality is provided by default for the user to manipulate
the listing view like sorting the data ascending or descending by column,
limiting the displayed objects by search rules and splitting the list of objects
into multiple pages with a navigation for browsing the pages back and forth.

For more information about sorting, browsing and searching, see documentation of
L<Dicole::Generictool::Sort|Dicole::Generictool::Sort>,
L<Dicole::Generictool::Browse|Dicole::Generictool::Browse> and
L<Dicole::Generictool::Search|Dicole::Generictool::Search>.

=item B<Selecting objects>

This is similar to a listing view. The only difference is that each object has
a way to select it through a checkbox or radiobutton. The interface may contain
buttons that (when pressed) perform certain things on each of the selected
object. One example is removing the selected objects or moving the selected
objects to an archive.

=back

These are just the basic yet powerful basic functionalities you may easily
implement in your application with I<Generictool>. The flexibility of
the implementation allows you to easily modify each part of the
functionality. For example, if you want to implement your own way to browse
the list just inherit the appropriate browsing class, override its' methods
to implement your own functionality and pass your new class as custom class
for browsing to I<Generictool>.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 object( [CLASS] )

Sets/gets the I<SPOPS object> class to use.

=head2 modifyable( [BOOLEAN] )

Sets/gets the modifyable bit. This controls if the resulting content fields
are modifyable or just plain text.

=head2 disable_browse( [BOOLEAN] )

Sets/gets the disable browsing bit. This controls if the page should have
browsing support or not.

=head2 optional_passwords( [BOOLEAN] )

Sets/gets the optional passwords bit. If you are on creating an editing page,
you might want to turn this on since it makes editing an password field
optional. If the password field doesn't contain a value, it is not updated
in the I<SPOPS object>.

=head2 clear_output( [BOOLEAN] )

Sets/gets the clear output bit. This controls if the output of fields should
not contain any values in the fields. Useful for clearing the form after
something was added on the generic add view.

=head2 fake_objects( [ARRAY] )

Sets/gets the fake objects. This is a anonymous array of hashes which contain
the values for fields. Imitates SPOPS objects.

For example, defining this allows you to initialize generictool without
passing a SPOPS object and still be able to use it to generate forms
based on defined fields.

=head2 merge_fake_to_spops( [BOOLEAN] )

If this is turned on we will try to merge fake object attribute values
(excluding id) to corresponding SPOPS object. This is the only way to
make a page display additional fields from somewhere else for an object.

=head2 current_view( [STRING] )

Sets/gets the view which generictools uses for output.

=head2 disable_sort( [BOOLEAN] )

If set to a true value disables sorting from applicable views.

=head2 disable_browse( [BOOLEAN] )

If set to a true value disables browsing from applicable views.

=head2 disable_searching( [BOOLEAN] )

If set to a true value disables searching from applicable views.

=head2 bb_also_on_top( [BOOLEAN] )

If set to a true value the bottom buttons will be also on the
top of the page.

=cut

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool->mk_accessors(
    qw( object modifyable clear_output merge_fake_to_spops
        disable_browse optional_passwords fake_objects
    current_view disable_sort disable_search
    bb_also_on_top )
);

=pod

=head1 METHODS

=head2 new( HASH )

Initializes and creates a new I<Dicole::Generictool> object. Accepts a hash
of parameters for class attribute initialization.

Parameters:

=over 4

=item B<fields> I<arrayref of objects>

Initial fields for the Generictool object. Array contains a list
of I<Dicole::Generictool::Field> objects. See documentation of
L<Dicole::Generictool::Field|Dicole::Generictool::Field> for
more information.

=item B<visible_fields> I<hashref of arrays>

Defines what fields are visible for each generic method.

Example:

  {
    edit => [ 'field_name', ... ],
    show => [ 'field_name', ... ]
  }

=item B<object> I<class>

The I<SPOPS class> to use for data retrieval. See
L<Dicole::Generictool::Data|Dicole::Generictool::Data> for
more information.

=item B<default_sort> I<hashref>

Defines the default sort that is used if no sorting was
provided in session cache or Apache parameters.

Example:

  { column => 'field_id', order => 'ASC' }

=item B<sortable> I<arrayref>

List of fields that are sortable.

=item B<skip_security> I<boolean>

Sets the skip security flag. This is used to set I<SPOPS>
object security off. See documentation of L<SPOPS|SPOPS> for
details.

=item B<flag_active> I<boolean>

Turns object I<active> checking on. See documentation
of L<Dicole::Generictool::Data|Dicole::Generictool::Data> for
details.

=item B<searchable> I<arrayref>

List of fields that are searchable.

=item B<current_view> I<string>

View used for output by default.

=item B<search> I<hashref>

Contains initial search parameters as a hash that contains
searchable column names and search values.

=item B<search_type> I<string>

Type of search to use. See documentation of
L<Dicole::Generictool::Search|Dicole::Generictool::Search>
for more information.

=item B<disable_browse> I<boolean>

Disables or enables browsing support.

=item B<custom_browse> I<class>

Set this if you want to use your own class that takes care of
the browsing support. See L<Dicole::Generictool::Browse|Dicole::Generictool::Browse>
for more information.

=item B<custom_search> I<class>

Set this if you want to use your own class that takes care of
the searching. See L<Dicole::Generictool::Search|Dicole::Generictool::Search>
for more information.

=item B<custom_data> I<class>

Set this if you want to use your own class that takes care of
the data retrieval. See L<Dicole::Generictool::Data|Dicole::Generictool::Data>
for more information.

=item B<custom_validate> I<class>

Set this if you want to use your own class that takes care of
the input validation. See L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>
for more information.

=item B<custom_construct> I<class>

Set this if you want to use your own class that takes care of
the constructing the content fields. See
L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>
for more information.

=item B<initial_construct_params> I<class>

Parameters passed to Construct object when it is created.

=item B<custom_sort> I<class>

Set this if you want to use your own class that takes care of
the sorting. See L<Dicole::Generictool::Sort|Dicole::Generictool::Sort>
for more information.

=item B<fake_objects> I<arrayref>

This is a anonymous array of L<Dicole::Generictool::FakeObject> objects
which contain the values for fields. Imitates SPOPS objects.

For example, defining this allows you to initialize generictool without
passing a SPOPS object and still be able to use it to generate forms
based on defined fields. If you are not using SPOPS, make sure you turn
I<no_spops> on.

=item B<merge_fake_to_spops> I<boolean>

If this is turned on we will try to merge fake object attribute values
(excluding id) to corresponding SPOPS object. This is the only way to
make a page display additional fields from somewhere else for an object.

=item B<disable_sort> I<boolean>

If set to a true value disables sorting from applicable views.

=item B<disable_search> I<boolean>

If set to a true value disables searching from applicable views.

=item B<disable_browse> I<boolean>

If set to a true value disables browsing from applicable views.

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

    # thou shall not modify thy arguments
    my %args = %{ $args };

    # evaluate that parameters contain correct data inititialize
    # object attributes, use parameters as optional input

    foreach ( qw( object fields views current_view disable_sort
          disable_browse disable_search visible_fields
          bb_also_on_top ) ) {

    eval "\$self->$_( \$args{$_} )";
    }

    # Initializes sorting
    $self->Sort( $args{custom_sort} );
    $self->Sort->sortable( $args{sortable} );
    if ( $args{default_sort} ) {
        $self->Sort->default_sort( $args{default_sort} );
    }
    if ( $args{fields} ) {
        $self->Sort->fields( $self->fields );
    }

    # Initializes search
    $self->Search( $args{custom_search} );
    $self->Search->searchable( $args{searchable} );
    if ( $args{searchable} && $args{search} && $args{fields} ) {
        # search doesn't have to contain anything.
        # search limit information is checked from apache
        # parameters if none was passed here
        $self->Search->fields( $self->fields );
        $self->Search->set_search_limit( $args{search} );
    }
    $self->Search->search_type( $args{search_type} );

    # Initializes input validation
    $self->Validate( $args{custom_validate} );

    # Initializes field constructor
    $self->Construct(
        $args{custom_construct},
        $args{initial_construct_params}
    );

    # Initializes browsing
    $self->disable_browse( $args{disable_browse} );
    unless ( $self->disable_browse ) {
        $self->Browse( $args{custom_browse} );
        $args{default_limitsize} ||= $self->_DEFAULT_LIMIT_SIZE;
        $self->Browse->default_limit_size( $args{default_limitsize} );
        $self->Browse->set_limits(
            $args{limit_start}, $args{limit_size}
        );
    }

    $self->merge_fake_to_spops( $args{merge_fake_to_spops} );

    # Initialize fake objects if such exist
    if ( ref( $args{fake_objects} ) eq 'ARRAY' ) {
        $self->fake_objects( $args{fake_objects} );
    }

    if ( $self->object ) {
        # Initializes data handling
        $self->Data( $args{custom_data} );
        $self->Data->flag_active( $args{flag_active} );
        $self->Data->skip_security( $args{skip_security} );
        $self->Data->object( $self->object );
    }

}

=pod

=head2 Data( [CLASS|OBJECT] )

Sets/gets the object that handles data retrieval. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Data|Dicole::Generictool::Data>
object.

Optionally accepts custom class as a parameter that handles
data retrieval instead.

=cut

sub Data {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Data} = ( ref $class ) ? $class : $class->new;
    }
    unless ( ref $self->{_Data} ) {
        $self->{_Data} = Dicole::Generictool::Data->new;
    }
    return $self->{_Data};
}

=pod

=head2 Sort( [CLASS|OBJECT] )

Sets/gets the object that handles sorting. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Sort|Dicole::Generictool::Sort>
object.

Optionally accepts custom class as a parameter that handles
sorting instead.

=cut

sub Sort {
    my ( $self, $class ) = @_;

    my $params = { action => [ CTX->request->action_name, CTX->request->task_name ] };

    if ( defined $class ) {
        $self->{_Sort} = ( ref $class ) ? $class : $class->new( $params );
    }
    unless ( ref $self->{_Sort} ) {
        $self->{_Sort} = Dicole::Generictool::Sort->new( $params );
    }
    return $self->{_Sort};
}

=pod

=head2 Browse( [CLASS|OBJECT] )

Sets/gets the object that handles browsing support. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Browse|Dicole::Generictool::Browse>
object.

Optionally accepts custom class as a parameter that handles
browsing instead.

=cut

sub Browse {
    my ( $self, $class ) = @_;

    my $params = { action => [ CTX->request->action_name, CTX->request->task_name ] };

    if ( defined $class ) {
        $self->{_Browse} = ( ref $class ) ? $class : $class->new( $params );
    }
    unless ( ref $self->{_Browse} ) {
        $self->{_Browse} = Dicole::Generictool::Browse->new( $params );
    }
    return $self->{_Browse};
}

=pod

=head2 Search( [CLASS|OBJECT] )

Sets/gets the object that handles searching. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Search|Dicole::Generictool::Search>
object.

Optionally accepts custom class as a parameter that handles
searching instead.

=cut

sub Search {
    my ( $self, $class ) = @_;

    my $params = { action => [ CTX->request->action_name, CTX->request->task_name ] };

    if ( defined $class ) {
        $self->{_Search} = ( ref $class ) ? $class : $class->new( $params );
    }
    unless ( ref $self->{_Search} ) {
        $self->{_Search} = Dicole::Generictool::Search->new( $params );
    }
    return $self->{_Search};
}

=pod

=head2 Validate( [CLASS|OBJECT] )

Sets/gets the object that handles input validation. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>
object.

Optionally accepts custom class as a parameter that handles
input validation instead.

=cut

sub Validate {
    my ( $self, $class ) = @_;
    if ( defined $class ) {
        $self->{_Validate} = ( ref $class ) ? $class : $class->new;
    }
    unless ( ref $self->{_Validate} ) {
        $self->{_Validate} = Dicole::Generictool::Field::Validate->new;
    }
    return $self->{_Validate};
}

=pod

=head2 Construct( [CLASS|OBJECT] )

Sets/gets the object that handles construction of content objects. If no
object yet exists, initializes the class attribute with
a new L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>
object.

Optionally accepts custom class as a parameter that handles
field construction instead.

=cut

sub Construct {
    my ( $self, $class, $params ) = @_;
    if ( defined $class ) {
        $self->{_Construct} = ( ref $class ) ?
            $class : $class->new( $params );
    }
    unless ( ref $self->{_Construct} ) {
        $self->{_Construct} =
            Dicole::Generictool::Field::Construct->new( $params );
    }
    return $self->{_Construct};
}

=pod

=head2 fields( [ARRAYREF] )

Sets/gets the fields. Optional parameter anonymous array contains a list
of I<Dicole::Generictool::Field> objects. See documentation of
L<Dicole::Generictool::Field|Dicole::Generictool::Field> for
more information.

=cut

sub fields {
    my ( $self, $fields ) = @_;

    if ( ref( $fields ) eq 'ARRAY' ) {
        $self->{fields} = $fields;
    }
    unless ( ref $self->{fields} eq 'ARRAY' ) {
        $self->{fields} = [];
    }
    return $self->{fields};
}

=pod

=head2 clear_fields()

Clears the fields.

=cut

sub clear_fields {
    my ( $self ) = @_;
    $self->{fields} = [];
}

=pod

=head2 set_fields_to_views( [no_sortable => BOOLEAN], [ no_searchable => BOOLEAN] )

Gets current field ids and sets visible fields for generic views defined by
class attribute I<views>.

Sets current field ids to sortable columns if parameter I<no_sortable>
is not given.

Sets current field ids to searchable fields if parameter I<no_searchable>
is not given.

=cut

sub set_fields_to_views {
    my $self = shift;

    my $args = {
        no_sortable => 0,
        no_searchable => 0,
        views => [$self->current_view],
        @_,
    };

    my $id_fields = $self->_get_id_fields;

    foreach my $view ( @{ $args->{views} } ) {
        $self->visible_fields( $view, $id_fields );
    }
    $self->Sort->sortable( $id_fields ) unless $args->{no_sortable};
    $self->Search->searchable( $id_fields ) unless $args->{no_searchable};
}

=pod

=head2 add_field( HASH )

Adds a new field to the list of fields. Accepts initial arguments for
L<Dicole::Generictool::Field|Dicole::Generictool::Field> method C<new()>.

=cut

sub add_field {
    my ( $self, %field_args ) = @_;
    my $field = Dicole::Generictool::Field->new( %field_args );
    push @{ $self->{fields} }, $field;
    return $field;
}

=pod

=head2 get_field( STRING )

Gets a field from the list of fields based of field id.

=cut

sub get_field {
    my ( $self, $id ) = @_;
    foreach my $field ( @{ $self->fields } ) {
        return $field if $field->id eq $id;
    }
    return "Field with id [$id] not found!";
}

=pod

=head2 visible_fields( STRING, [ARRAYREF] )

Sets/gets the visible fields for a certain view. Accepts
view id (e.g. I<show>) as parameter. If passed with the optional
anonymous array of field ids, sets the visible fields accordingly.

=cut

sub visible_fields {
    my ( $self, $fields, $view ) = @_;

    ## BACKWARDS COMPATIBILITY CHECK

    if ( ref $fields ne 'ARRAY' ) {
        my $temp = $fields;
        $fields = $view;
        $view = $temp;
    }

    $view ||= $self->current_view;

    if ( $view && ref( $fields ) eq 'ARRAY' ) {
        $self->{visible_fields}->{$view} = $fields;
    }
    elsif ( $view ) {
        return $self->{visible_fields}->{$view};
    }
}

=pod

=head2 del_visible_fields( STRING, ARRAYREF )

Deletes certain field ids' from the list of visible fields
for a certain view id. First parameter is the view id and
second parameter is an anonymous array of field ids'.

=cut

sub del_visible_fields {
    my ( $self, $field, $fields ) = @_;
    $self->{visible_fields}->{$field} = Dicole::Utility->del_from_list(
        $self->{visible_fields}->{$field}, $fields
    );
}

=pod

=head2 get_controlbuttons( STRING, SCALAR )

Gets the current control buttons for a certain view based on class attributes.

First parameter is the view id for which we wish to retrieve the control
buttons and second parameter is the object id for which we should replace
the special tag C<IDFIELD> in possible link buttons' links.

Returns a L<Dicole::Content::Controlbuttons|Dicole::Content::Controlbuttons>
object.

=cut

sub get_controlbuttons {
    my ( $self, $method, $obj_id ) = @_;

    my $bottom_buttons = $self->bottom_buttons( $method );

    return undef unless ref $bottom_buttons eq 'ARRAY';

    my $buttons = Dicole::Content::Controlbuttons->new;

    # add custom buttons
    foreach my $but ( @{ $bottom_buttons } ) {

        # If it is a hash, we assume we are getting the parameters
        # to pass for Dicole::Content::Button
        if ( ref $but eq 'HASH' ) {

            $but = Dicole::Content::Button->new( %{ $but } );

            # Replace IDFIELD with object ID in hrefs
            my $button_link = $but->link;
            $button_link =~ s/IDVALUE/$obj_id/gs;
            $but->link( $button_link );
            my $confirm_box = $but->confirm_box;
            if ( ref( $confirm_box ) eq 'HASH' ) {
                $confirm_box->{href} =~ s/IDVALUE/$obj_id/gs;
                $confirm_box->{name} =~ s/IDVALUE/$obj_id/gs;
                $but->confirm_box( $confirm_box );
            }
        }
        # Otherwise we expect it is already a class,
        # usually Dicole::Content::Button. This functionality is
        # here to allow user to define custom class that is able
        # to answer in method call get_template() and get_template_params()
        else {
            # Replace IDVALUE with object ID only if object has get_link
            # and set_link methods
            if ( $but->can('set_link') && $but->can('get_link') ) {
                my $button_link = $but->link;
                $button_link =~ s/IDVALUE/$obj_id/g;
                $but->link( $button_link );
            }
        }
        $log ||= get_logger( LOG_TOOL );
        $log->is_info && $log->info( "Added control button name=[". $but->name ."]" );
        $buttons->add_buttons( $but );
    }

    return $buttons;
}

=pod

=head2 bottom_buttons( [ARRAYREF], [STRING] )

Sets/gets the buttons that are in the bottom row of the tool.

If no parameters were passed, returns an anonymous hash of
buttons for all views.

If passed with optional anonymous array parameter, sets
the buttons respectively. The array index contains each anonymous
hash parameters to pass for
L<Dicole::Content::Button|Dicole::Content::Button> method C<new()>.

Example:

  [
    { name => 'modify', value => 'Modify' },
    ...
  ],

The array index might also contain objects which are able to answer
to method calls C<get_template()> and C<get_template_params()>. This is
usually a custom L<Dicole::Content|Dicole::Content> object. Use this
feature if you want to have other content objects in the views' submit
row as well.

Optionally accepts the view id as a second parameter for which the buttons
are added. By default this is the return value of I<current_view()>.

=cut

sub bottom_buttons {
    my ( $self, $buttons, $method ) = @_;

    ## BACKWARDS COMPATIBILITY CHECK

    if ( ref $buttons ne 'ARRAY' ) {
        my $temp = $buttons;
        $buttons = $method;
        $method = $temp;
    }

    $method ||= $self->current_view;

    if ( $method && ref( $buttons ) eq 'ARRAY' ) {
        $self->{bottom_buttons}{$method} = $buttons;
    }
    elsif ( $method ) {
        unless ( ref( $self->{bottom_buttons}{$method} ) eq 'ARRAY' ) {
            $self->{bottom_buttons}{$method} = [];
        }
        return $self->{bottom_buttons}{$method};
    }
    unless ( ref( $self->{bottom_buttons} ) eq 'HASH' ) {
        $self->{bottom_buttons} = {};
    }
    return $self->{bottom_buttons};
}

=pod

=head2 add_bottom_button( HASH )

Adds one bottom button in the bottom row of the tool.

Pass a hash of parameters to pass for L<Dicole::Content::Button>
constructor C<new()>. Example:

 name => 'modify', value => 'Modify'

=cut

sub add_bottom_button {
    my $self = shift;

    my $params = {
       view => $self->current_view,
       @_
    };

    my $view = $params->{view};
    delete $params->{view};

    push @{ $self->{bottom_buttons}{$view} }, $params;
}

=pod

=head2 add_bottom_buttons( ARRAYREF, [SCALAR] )

Adds an array of button hashrefs to a specified (or current) view.

The array might also contain objects which are able to answer
to method calls C<get_template()> and C<get_template_params()>. This is
usually a custom L<Dicole::Content|Dicole::Content> object. Use this
feature if you want to have other content objects in the views' submit
row as well.

=cut

sub add_bottom_buttons {
    my ( $self, $buttons, $view ) = @_;
    $view ||= $self->current_view;

    return if ref $buttons ne 'ARRAY';

    foreach ( @$buttons ) {
    push @{ $self->{bottom_buttons}{$view} }, $_;
    }
}


=pod

=head2 get_list( [HASH] )

Constructs a list view of objects which contains sorting, searching,
browsing, data and control buttons based on class attributes.

If the list contains links to objects (links are defined in fields
of Generictool), the I<IDVALUE> in those links are replaced with each current
object id in question.

Parameters:

=over 4

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<view> I<string>

Id of the used view.

Default: $self->current_view

=item B<objects> I<arrayref>

Optional arrayref of spops objects to display as a list.

Default: undef

=item B<link_id> I<scalar>

A scalar number that is replaced in place of I<IDFIELD> in control
buttons which type are I<link>. Usually a I<SPOPS> object id.

Default: undef

=item B<list_params> I<hashref>

Optional hashref of parameters to the L<Dicole::Content::List> object.

=back

Returns:
An anonymous array of L<Dicole::Content> objects that form the resulting
view.

=cut

sub get_list {

    my $self = shift;
    my $p = {
        view => $self->current_view,
        link_id => undef,
        objects => undef,
        no_keys => 0,
        list_params => {},
        browse_location => 'both',
        @_
    };

    $self->modifyable( 0 );

    my $lh = CTX->request->language_handle;

    my $return = [];

    my $search = $self->_get_search;
    push @{ $return }, $search if ref $search;

    my $browse = $self->_get_browse;
    if ( ref $browse && ( $p->{browse_location} eq 'top' || $p->{browse_location} eq 'both' ) ) {
        push @{ $return }, $browse;
    }

    my $sort = $self->_get_sort( $p->{view} );

    my $objects = $p->{objects} || $self->_get_list_objects;

    if ( scalar @{ $objects } ) {
        my $resulting_view = $self->_make_view(
            view    => $p->{view},
            keys => $sort,
            no_keys     => $p->{no_keys},
            list_params => {
                type => 'vertical',
                %{ $p->{list_params} }
            },
            objects     => $objects,
            link_id     => $p->{link_id}
        );
        push @{ $return }, @{ $resulting_view };
    }
    else {
        push @{ $return }, Dicole::Content::Text->new(
            content => $lh->maketext( "Nothing found." )
        );
    }

    if ( ref $browse && ( $p->{browse_location} eq 'bottom' || $p->{browse_location} eq 'both' ) ) {
        push @{ $return }, $self->_get_browse;
    }

    return $return;
}

=pod

=head2 get_sel( STRING, [SCALAR], [SCALAR], [BOOLEAN] )

Constructs a select view of objects which contains sorting, searching,
browsing, data and control buttons based on class attributes.

If the list contains links to objects (links are defined in fields
of Generictool), the I<IDVALUE> in those links are replaced with each current
object id in question.

Accepts view id as a parameter.

Optionally accepts checkbox id as a parameter. The default checkbox id
is I<sel>. See documentation of L<make_view()|_make_view_HASH_> for more
details.

Optionally accepts object id number as a parameter, which are similarly
replaced in link type control buttons.

Optionally accepts the pre-check bit, which will make all the checkboxes checked
by default.

Parameters:

=over 4

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<objects> I<arrayref>

Optional arrayref of spops objects to display as a list.

Default: undef

=item B<view> I<string>

Id of the used view.

Default: $self->current_view

=item B<link_id> I<scalar>

A scalar number that is replaced in place of IDVALUE in type link control buttons.
Usually a I<SPOPS> object id.

Default: undef

=item B<checkbox_id> I<string>

If checkboxes are turned on, sets the checkbox id for all checkboxes.
Defines if the objects should be selectable with checkboxes or not.

Default: undef

=item B<pre_checked> I<boolean>

Defines if ALL checkboxes should be pre-checked or not.

Default: 0

=item B<checked> I<arrayref>

Arrayref of pre_checked objects or objects' ids.

Default: []

=back

Returns:
An anonymous array of L<Dicole::Content|Dicole::Content> objects that
form the resulting view.

=cut

sub get_sel {

    my $self = shift;
    my $p = {
        view => $self->current_view,
        link_id => undef,
        objects => undef,
        no_keys => 0,
        checkbox_id => undef,
        pre_checked => 0,
        checked => [],
        @_
    };

    $self->modifyable( 0 );

    my $lh = CTX->request->language_handle;

    my $return = [];

    my $search = $self->_get_search;
    push @{ $return }, $search if ref $search;

    my $browse = $self->_get_browse;
    push @{ $return }, $browse if ref $browse;

    my $sort = $self->_get_sort( $p->{view} );

    my $objects = $p->{objects} || $self->_get_list_objects;

    if ( scalar @{ $objects } ) {
        my $resulting_view = $self->_make_view(
            view    => $p->{view},
            keys => $sort,
            no_keys     => $p->{no_keys},
            list_params => {
                type => 'vertical',
            },
            objects     => $objects,
            link_id     => $p->{link_id},
            checkboxes  => 1,
            pre_checked => $p->{pre_checked},
            ( defined $p->{checkbox_id} )
                ? ( checkbox_id => $p->{checkbox_id} ) : (),
            checked     => $p->{checked},
        );
        push @{ $return }, @{ $resulting_view };
    }
    else {
        push @{ $return }, Dicole::Content::Text->new(
            content => $lh->maketext( "Nothing found." )
        );
    }

    return $return;
}

=pod

=head2 get_advanced_sel( HASH )

Constructs an advanced select view of objects which contains sorting, searching,
browsing, data and control buttons based on class attributes.

Advanced select view has two boxes. The first one has items still to be selected
and the second box has a list of currently selected items. The functionality
allows moving objects back and forth between the two boxes.

The first box has a button for adding the checked items to the list of
selected items.

The second box has a button that allows removing checked items from the
list of selected items.

Both boxes have a button to check all checkboxes or clearing the checkboxes.
Both buttons also contain the buttons specified with I<bottom_buttons()> for the
view in question.

The programmer is required to write the functionality for manipulating the list
of selected objects (list of selected objects are in turn passed to the method
as the second parameter). I<get_advanced_sel()> provides the following Apache
parameters for the programmer to use:

=over 4

=item *

select_add_checked

=item *

selected_remove_checked

=back

These apache parameters tell what button was pressed. The button is prefixed
with the view id in this case. The prefix can be changed with the
method parameter that changes the view id.

If the list contains links to objects (links are defined in fields
of Generictool), the I<IDVALUE> in those links are replaced with each current
object id in question.

Method parameters:

=over 4

=item B<selected> I<arrayref>

An anonymous array of object id's that are currently selected. This is
used to construct the content of both boxes.

=item B<objects> I<arrayref>

Optional arrayref of spops objects to display as a list.

Default: undef

=item B<select_view> I<string>

View id for the select box. The default view id for the select box is
I<select>. This id is also applied as the checkbox id for the box in question.
See documentation of L<make_view()|_make_view_HASH_> for more details.

=item B<selected_view> I<string>

View id for the selected box. The default view id for the selected box is
I<selected>. This id is also applied as the checkbox id for the box in question.
See documentation of L<make_view()|_make_view_HASH_> for more details.

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<link_id> I<scalar>

The object id, which is replaced into link type control buttons. The default
value is 0.

=back

Returns two anonymous arrays of L<Dicole::Content|Dicole::Content> objects that
form the resulting selection boxes. The first one is the box from which to
select objects and the second one is the box that contains the currently
selected objects.

=cut

sub get_advanced_sel {

    my $self = shift;
    my $args = {
        selected => [],
        select_view => 'select',
        selected_view => 'selected',
        no_keys     => 0,
        objects => undef,
        link_id => 0,
        @_
    };

    $self->modifyable( 0 );

    my $lh = CTX->request->language_handle;

    my $id_field = $self->Data->object->id_field;

    # Selected_where modifies the where query so we save it first
    my $where = $self->Data->where;
    $self->Data->selected_where(
        list => { $id_field => $args->{selected} },
        invert => 1
    );

    # Get checkbox checking buttons and specified bottom buttons
    my ( $buttons, $pre_check ) = $self->_checkbox_checker(
        $args->{select_view}
    );
    my $select_buttons = [ {
        name  => $args->{select_view}.'_add_checked',
        value => $lh->maketext( 'Add checked items' )
    } ];
    push @{ $select_buttons }, @{ $buttons };
    push @{ $select_buttons }, @{ $self->bottom_buttons($args->{select_view}) };
    $self->bottom_buttons( $args->{select_view}, $select_buttons );

    # Construct selection box
    my $select_box = $self->get_sel(
        view => $args->{select_view},
        checkbox_id => $args->{select_view},
        no_keys     => $args->{no_keys},
        link_id => $args->{link_id},
        pre_checked => $pre_check
    );

    my $selected_box = [];

    $self->Data->limit( undef );
    $self->disable_browse( 1 );

    # If nothing was selected we have to explicitly return the page
    # for nothing found. Otherwise all objects will be retrieved
    unless ( scalar @{ $args->{selected} } ) {
        $selected_box = [
            Dicole::Content::Text->new(
                content => $lh->maketext( "Nothing found." )
            ),
            $self->get_controlbuttons(
                $args->{selected_view}, $args->{link_id}
            ),
        ];
    }
    else {
        # Restore saved where query (disabled)
        #$self->Data->where( $where );

        # It seems we always have something selected and that the
        # where query shouldn't affect it.. so we empty it first
        $self->Data->where( '' );

        $self->Data->selected_where(
            list => { $id_field => $args->{selected} }
        );
        my ( $buttons, $pre_check ) = $self->_checkbox_checker(
            $args->{selected_view}
        );
        my $selected_buttons = [ {
            name  => $args->{selected_view} . '_remove_checked',
            value => $lh->maketext( 'Remove checked' )
        } ];
        push @{ $selected_buttons }, @{ $buttons };
        push @{ $selected_buttons }, @{
            $self->bottom_buttons( $args->{selected_view} )
        };
        $self->bottom_buttons( $args->{selected_view}, $selected_buttons );

        # No searching for selected
        $self->Search->searchable( [] );
        $selected_box = $self->get_sel(
            view => $args->{selected_view},
            checkbox_id => $args->{selected_view},
            no_keys     => $args->{no_keys},
            link_id => $args->{link_id},
            pre_checked => $pre_check
        );
    }

    return $select_box, $selected_box;
}

sub _checkbox_checker {
    my ( $self, $id ) = @_;

    my $lh = CTX->request->language_handle;

    my $buttons = [];
    my $pre_check = undef;
    if ( CTX->request->param( $id . '_check_all' ) ) {
        push @{ $buttons }, {
            name => $id . '_clear_all' ,
            value => $lh->maketext( 'Clear checkboxes' )
        };
        $pre_check = 1;
    }
    else {
        push @{ $buttons }, {
            name => $id . '_check_all',
            value => $lh->maketext( 'Check all' )
        };
    }
    return $buttons, $pre_check;
}

# Takes care of constructing a valid data object out of real data,
# fake object data or real and fake object data merged.
#
# Params: { object => [OBJECT|OBJECT_ID], use_data => BOOLEAN }

sub _construct_object {
    my ( $self, $args ) = @_;

    my $object = undef;

    if ( defined $self->fake_objects ) {
        $object = $self->fake_objects->[0];
    }
    if ( !defined $self->fake_objects || $self->merge_fake_to_spops ) {
        my $fake = $object;
        if ( ref $args->{object} ) {
            $object = $args->{object};
            $self->Data->data( $object );
        }
        elsif ( defined $args->{object} ) {
            $object = $self->Data->data_single( $args->{object} );
        }
        elsif ( $args->{use_data} ) {
            $object = $self->Data->data;
        }
        else {
            $object = $self->Data->data_new;
        }
        if ( $self->merge_fake_to_spops ) {
            foreach my $key ( keys %{ $fake } ) {
                $object->{$key} = $fake->{$key};
            }
        }
    }
    return $object;
}


=pod

=head2 get_show( [HASH] )

Constructs a show view based on class attributes.

Accepts a hash of parameters:

=over 4

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<view>

View id which to generate.

=item B<link_id>

Optionally accepts object id number as a parameter. If link type control
buttons contain I<IDFIELD>, this id is replaced in place. Otherwise the
object id is replaced in place.

=item B<id>

The SPOPS object id which will be retrieved.

=item B<object>

The SPOPS object itself which will be used.

=back

Returns a list of L<Dicole::Content> objects that form the resulting
view.

=cut

sub get_show {

    my $self = shift;
    my $p = {
        view => $self->current_view,
        id => undef,
        object => undef,
        link_id => undef,
        no_keys => 0,
        @_
    };

    $self->modifyable( 0 );

    my $object = $self->_construct_object( {
    object => $p->{object} || $p->{id}
    } );

    return $self->_make_view(
        view    => $p->{view},
        no_keys     => $p->{no_keys},
        keys => $self->_make_key_columns( $p->{view} ),
        list_params => {
            type => 'horizontal_simple',
        },
        objects     => [ $object ],
        link_id     => $p->{link_id} || $object->id,
    );
}

=pod

=head2 get_edit( [HASH]] )

Constructs an edit view based on class attributes.

Accepts a hash of parameters:

=over 4

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<view>

View id which to generate.

=item B<link_id>

Optionally accepts object id number as a parameter. If link type control
buttons contain I<IDFIELD>, this id is replaced in place. Otherwise the
object id is replaced in place.

=item B<id>

The SPOPS object id which will be retrieved.

=item B<object>

The SPOPS object itself which will be used.

=back

Returns a list of L<Dicole::Content> objects that form the resulting
view.

=cut

sub get_edit {

    my $self = shift;
    my $p = {
        view => $self->current_view,
        id => undef,
        object => undef,
        link_id => undef,
        no_keys => 0,
        @_
    };

    $self->modifyable( 1 );

    my $object = $self->_construct_object( {
        object => $p->{object} || $p->{id}
    } );

    return $self->_make_view(
        view    => $p->{view},
        keys => $self->_make_key_columns( $p->{view} ),
        no_keys     => $p->{no_keys},
        list_params => {
            type => 'horizontal_simple',
        },
        objects     => [ $object ],
        link_id     => $p->{link_id} || $object->id,
    );
}

=pod

=head2 get_add( [HASH] )

Constructs an add view based on class attributes.

Accepts a hash of parameters:

=over 4

=item B<no_keys> I<boolean>

If defined, keys are not displayed in the final result.

=item B<view>

View id which to generate.

=item B<link_id>

Optionally accepts object id number as a parameter. If link type control
buttons contain I<IDFIELD>, this id is replaced in place. Otherwise the
object id is replaced in place.

=back

Returns a list of L<Dicole::Content> objects that form the resulting
view.

=cut

sub get_add {

    my $self = shift;
    my $p = {
        no_keys => 0,
        view => $self->current_view,
        link_id => undef,
        @_
    };

    $self->modifyable( 1 );

    my $object = $self->_construct_object;

    return $self->_make_view(
        view    => $p->{view},
        keys => $self->_make_key_columns( $p->{view} ),
        list_params => {
            type => 'horizontal_simple',
        },
        no_keys     => $p->{no_keys},
        objects     => [ $object ],
        link_id     => $p->{link_id} || $object->id
    );
}

=pod

=head2 validate_and_save( ARRAYREF, HASHREF )

Validates user input. This is used in views add and edit to validate
that user has filled the form correctly. Upon success, the SPOPS object
is saved.

Accepts a list of field names as an anonymous array that should be
validated. This is usually the return of method I<visible_fields()>.

Accepts a hash of parameters that all affect the input validation:

By default the return value of method I<visible_fields()>.

=over 4

=item B<object> I<object>

A SPOPS object which should be saved if validation
succeeds.

=item B<object_id> I<scalar>

Id of SPOPS object which should be retrieved and saved if validation
succeeds.

=item B<spops_query> I<hash>

Query parameters for either I<SPOPS> C<fetch()> or C<new()>, depending
of if parameter I<object_id> was set or not.

=item B<skip_cache> I<boolean>

Sets the skip cache bit. By default skipping cache is turned on.
This controls if the data should be forcely retrieved and set to
our L<Dicole::Generictool::Data|Dicole::Generictool::Data> object.

Turning this off is useful if you have intentionally set
C<$gentool-E<gt>Data-E<gt>data> already and want to use that data instead or
if you are running a loop which saves a new object on each iteration.

=item B<clear_output> I<boolean>

Sets if we should clear fields upon success. This is useful in
add if you want the fields to appear empty after adding a new record.

=item B<fill_only> I<boolean>

Only fills the object/form with apache input parameters.

This is useful if you want to perform submit operations while the
user is filling the form (uploading file attachments, for example).
With this the object is not saved and no errors get returned, the form
is just filled with previous values.

Note: This function does not fill fields of type password between submit operations.
This might be considered as a bug.

=item B<no_save> I<boolean>

Only fills the object/form with apache input parameters and validates the input.
Does not save the object or clear the object/form.

This is useful if you want to do something to the object after the validation before
the object is saved. To save the object manually, use I<Data-E<gt>data_save> directly.

=back

=cut

sub validate_and_save {

    my ($self, $fields, $params ) = @_;

    $fields ||= $self->visible_fields;
    $params ||= {};

    unless ( defined $params->{skip_cache} ) {
        $params->{skip_cache} = 1;
    };

    $self->clear_output( $params->{clear_output} );

    $self->Data->query_params( $params->{spops_query} );

    if ( ref $params->{object} ) {
        $self->Data->data( $params->{object} );
    }
    elsif ( defined $params->{object_id} ) {
        $self->Data->data_single(
            $params->{object_id}, $params->{skip_cache}
        );
    }
    else {
        $self->Data->data_new( $params->{skip_cache} );
    }

    if ( $params->{fill_only} ) {
        $self->_input_to_object(
            $self->_construct_object( { use_data => 1 } ),
            $fields
        );
    }
    else {

        my ( $return_code, $message ) = $self->validate_input( $fields );

        if ( $return_code && !$params->{no_save} ) {

            unless ( $self->Data->data_save ) {
                return ( 0, "An error occured while saving the object." );
            }
            if ( $self->clear_output ) {
                $self->Data->clear_data_fields;
            }
        }
        return ( $return_code, $message );
    }

}

=pod

=head2 construct_fields( OBJECT, ARRAYREF )

Goes through I<SPOPS> object (first parameter) fields defined in an
anonymous array (second parameter) and constructs appropriate
L<Dicole::Content|Dicole::Content> objects for each of them.

If no fields are provided, the default is to use the return value of
method I<visible_fields()>.

Returns an anonymous array containing the resulting content objects.

See L<Dicole::Generictool::Field::Construct>
for more information how the fields are converted to content objects.

=cut

sub construct_fields {
    my ( $self, $object, $fields ) = @_;

    $fields ||= $self->visible_fields;

    my $rows = [];

    $self->_make_passwords_optional
        if $self->optional_passwords;

    my $content = [];

    $self->Construct->modifyable( $self->modifyable );
    $self->Construct->object( $object );

    foreach my $field_id ( @{ $fields } ) {

        my $field = $self->get_field( $field_id );
        next unless $field;

        my $value = undef;

        $self->Construct->field( $field );

        # Check if we have a method with the same name as the field
        # type, and call it if true.
        my $method_ref = $self->Construct->can( 'construct_' . $field->{type} );
        if ( $method_ref ) {
            push @{ $content }, $self->Construct->$method_ref;
        }
    }

    return $content;
}

=pod

=head2 validate_input( ARRAYREF )

Goes through apache parameters for each field defined in an anonymous
array passed as a parameter. Validates that user input parameters are
correct for each field.

If no fields are provided, the default is to use the return value of
method I<visible_fields()>.

Returns resulting error/success code and error/success message.

See L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>
for more information how the fields are validated.

=cut

sub validate_input {

    my ( $self, $specific_fields ) = @_;

    $specific_fields ||= $self->visible_fields;

    my $required = undef;

    $self->_make_passwords_optional
        if $self->optional_passwords;

    $self->_input_to_object(
        $self->_construct_object( { use_data => 1 } ),
        $specific_fields,
        1
    );

    if ( $self->Validate->error ) {
        return ( $self->Validate->error_code, $self->Validate->error_msg );
    }

    my $lh = CTX->request->language_handle;

    return ( 1, $lh->maketext( 'Data was saved successfully.' ) );
}

=pod

=head1 PRIVATE METHODS

=cut

# The specified object fields are modified to correspond Apache input fields.
# With additional boolean parameter the fields are checked if they are required
# (red arrow) and an error is set into Validate object.
sub _input_to_object {
    my ( $self, $object, $specific_fields, $check_required ) = @_;

    $object = $self->_construct_object( { use_data => 1 } );

    foreach my $field_id ( @{ $specific_fields } ) {

        my $field = $self->get_field( $field_id );
        next unless $field;

        my $value = undef;

        $self->Validate->field( $field );

        # Check if we have a method with the same name as the field
        # type, and call it if true.
        my $method_ref = $self->Validate->can( 'validate_' . $field->{type} );
        if ( $method_ref ) {
            $value = $self->Validate->$method_ref;
        }
        else {
            $value = $self->Validate->validate_default;
        }

        if ( $check_required ) {
            $self->Validate->check_required;
        }

        # Skip setting password field in the object if the field
        # was left empty. It is not possible to save empty
        # passwords
        unless ( $field->type eq 'password' && !$value ) {
            $object->{$field->object_field} = $value;
        }

    }
}

=pod

=head2 _get_sort( STRING )

Sets fields for our I<Sort> object and order for I<Data> object
based on I<Sort> object attributes.

Accepts view id as parameter for which the sort columns should
be constructed.

Returns sort columns as an anonymous array.

=cut

sub _get_sort {
    my ( $self, $view_id ) = @_;
    return undef if $self->disable_sort;

    $self->Sort->fields( $self->fields );
    $self->Sort->view( $view_id );
    $self->Data->order( $self->Sort->get_sort_query );
    my $list_columns = $self->Sort->get_sort_columns(
        $self->visible_fields( $view_id )
    );
    return $list_columns;
}

=pod

=head2 _get_search()

If searchable columns exists, sets fields and search limit information
for our I<Search> object and where query for I<Data> object based on
I<Search> object attributes.

Returns content objects for the search form.

=cut

sub _get_search {
    my ( $self ) = @_;
    return undef if $self->disable_search;

    if ( scalar @{ $self->Search->searchable } ) {
        $self->Search->fields( $self->fields );
        $self->Search->set_search_limit;
        my $search_query = $self->Search->get_search_query;
        if ( $search_query ) {
            my $where_query = $self->Data->where;
            $where_query .= ' AND ' if $where_query;
            $where_query .= $search_query;
            $self->Data->where( $where_query );
        }
        return $self->Search->get_search;
    }
    return undef;
}

=pod

=head2 _get_browse()

If browsing is not disabled, sets limit for I<Data> object
based on I<Browse> object attributes and sets I<total_count>
for I<Browse> object b ased on I<Data> object attributes.

Returns content objects for the browsing form.

=cut

sub _get_browse {
    my ( $self ) = @_;
    return undef if $self->disable_browse;

    unless ( $self->disable_browse ) {
        unless ( $self->Data->limit ) {
            $self->Data->limit(     $self->Browse->get_limit_query );
        }
        my $total_count = $self->Data->total_count;
        $self->Browse->total_count( $total_count );

        # If total number of objects is less that limit start,
        # we are out of bounds. In that case, sets limit start to be
        # the last available page
        if ( $total_count && $total_count <= $self->Browse->limit_start ) {

            my $pages = int( $total_count / $self->Browse->limit_size );
            $self->Browse->set_limits(
                ( $pages * $self->Browse->limit_size )
                - $self->Browse->limit_size
            );
            $self->Data->limit(     $self->Browse->get_limit_query );
        }
        return $self->Browse->get_browse;
    }
    return undef;
}

=pod

=head2 _get_list_objects()

Returns objects for list view based on I<Data> class attributes.

=cut

sub _get_list_objects {
    my ( $self ) = @_;
    my $objects = [];

    if ( defined $self->fake_objects ) {
        $objects = $self->fake_objects;
    }
    if ( !defined $self->fake_objects || $self->merge_fake_to_spops ) {
        my $fake = $objects;
        $objects = $self->Data->data_group;
        if ( $self->merge_fake_to_spops ) {
            for ( my $i = 0; $i < @{ $objects }; $i++ ) {
                foreach my $key ( keys %{ $fake->[$i] } ) {
                    $objects->[$i]->{$key} = $fake->[$i]->{$key};
                }
            }
        }
    }
    return $objects;
}

=pod

=head2 _DEFAULT_LIMIT_SIZE()

Gets default limit size, which is a default constant.

=cut

# Defines how many items are displayed on one page before the
# display is splitted to several pages
sub _DEFAULT_LIMIT_SIZE {
    my ( $self ) = @_;
    return 30;
}

=pod

=head2 _get_id_fields()

Goes through fields and constructs an anonymous array which contains
a list of field ids. Returns the resulting anonymous array.

=cut

sub _get_id_fields {
    my ( $self ) = @_;

    my $fields;
    foreach my $field ( @{ $self->fields } ) {
        push @{ $fields }, $field->id;
    }
    return $fields;
}

=pod

=head2 _make_key_columns( STRING )

Constructs list column key names (descriptions).

Goes through visible fields for a certain view passed as parameter
and constructs an anonymous array of anonymous hashes as correct
input for L<Dicole::Content::List|Dicole::Content::List> parameter
I<keys>.

=cut

sub _make_key_columns {
    my ( $self, $view ) = @_;

    my $detail_columns = [];
    foreach my $col ( @{ $self->visible_fields( $view ) } ) {
        my $field = $self->get_field( $col );
        next unless ref $field;
        push @{ $detail_columns }, { name => $field->desc };
    }
    return $detail_columns;
}

=pod

=head2 _make_view( HASH )

Creates an anonymous array containing a L<Dicole::Content::List|Dicole::Content::List>
object and control buttons based on class attributes and method parameters.

Parameters are:

=over 4

=item B<list_params> I<HASH>

Initial parameters for I<Dicole::Content::List> method C<new()>. Should contain
atleast parameters I<type> and I<keys>.

=item B<view> I<HASH>

View id.

=item B<objects> I<ARRAY>

An anonymous array of I<SPOPS> objects for which the list should be generated.
Usually one object if the list type is horizontal (e.g. I<add, edit, show>),
several if the list type is vertical (e.g. I<list, sel>).

=item B<link_id> I<SCALAR>

A scalar number that is replaced in place of IDVALUE in type link control buttons.
Usually a I<SPOPS> object id.

=item B<checkboxes> I<boolean>

Defines if the objects should be selectable with checkboxes or not. Each
checkbox points to an object in the list. You may retrieve the checkbox
value from Apache parameters. For example:

  $param = CTX->request->param( 'sel_1' );

The parameter is prefixed with checkbox id, which is I<sel> by default.
If you want to change the checkbox id, see parameter I<checkbox_id> below.

The parameter is suffixed with current object id in question.

=item B<checkbox_id> I<string>

If checkboxes are turned on, sets the checkbox id for all checkboxes.
Defines if the objects should be selectable with checkboxes or not.

=item B<pre_checked> I<boolean>

Defines if the checkboxes should be pre-checked or not. By default this is
turned off.

=item B<no_keys> I<boolean>

If true, disables keys in the final result.

=item B<checked> I<arrayref>

Arrayref of pre_checked objects or objects' ids.

Default: []


=back

Returns the resulting view as an anonymous array of I<Dicole::Content> objects.

=cut

sub _make_view {
    my $self = shift;

    my $return = [];

    my $params = {
        keys        => [],
        list_params => {},
        view        => undef,
        objects     => [],
        link_id     => 0,
        checkboxes  => undef,
        checkbox_id => 'sel',
        no_keys     => 0,
        pre_checked => undef,
        checked     => [],
        @_,
    };

    my $visible_fields = $self->visible_fields( $params->{view} );

    # Convert possible objects to ids and form a hash for checking
    my %checked = map { ( ref $_ ) ? $_->id : $_ => 1 } @{ $params->{checked} };

    # We need the append checkbox column to keys if
    # such was requested
    if ( $params->{checkboxes} ) {
        unshift @{ $params->{keys} },
            { attributes => { width => '10px' } };
    }

    my $list = Dicole::Content::List->new( %{ $params->{list_params} } );
    $list->no_keys( $params->{no_keys} );
    foreach my $object ( @{ $params->{objects} } ) {

        my $contentrow = [];

        if ( $params->{checkboxes} ) {
            push @{ $contentrow }, {
                content => Dicole::Content::Formelement->new(
                    modifyable => 1,
                    attributes => {
                        type  => 'checkbox',
                        name  => $params->{checkbox_id} . '_' . $object->id,
                        value => 1,
                        ( $params->{pre_checked} || $checked{ $object->id } )
                            ? ( checked => 'checked' ) : ()
                    }
                )
            };
        }

        my $content_fields = $self->construct_fields( $object, $visible_fields );

        my $i = 0;
        $i++ if $params->{checkboxes};
        my $keys = [];
        foreach my $content ( @{ $content_fields } ) {
            if ( ref $content ) {
                push @{ $keys }, $params->{keys}[$i];
                push @{ $contentrow }, { content => $content };
            }
            $i++;
        }
        unshift @{ $keys }, $params->{keys}[0] if $params->{checkboxes};
        $list->set_keys( $keys );

        if ( scalar @{ $contentrow } ) {
            $list->add_content_row( $contentrow );
        }
    }

    push @{ $return }, $list if $list;

    my $buttons = $self->get_controlbuttons(
        $params->{view}, $params->{link_id}
    );

    push @{ $return }, $buttons if $buttons;

    unshift @{ $return }, $buttons if $self->bb_also_on_top;

    $log ||= get_logger( LOG_TOOL );
    $log->is_debug && $log->debug( "Return of make view is: "
        . Data::Dumper::Dumper( $return ) );

    return $return;
}

=pod

=head2 _make_passwords_optional()

Goes through fields and sets all password fields as not required.

=cut

sub _make_passwords_optional {
    my ( $self ) = @_;

    # password field is forced to be not a required
    # field. Useful in editing mode. This is because if the
    # password field is left empty, it is not changed.
    # This enables editing of other object information
    # while leaving the password fields intact.
    foreach my $field ( @{ $self->fields } ) {
        if ( $field->type eq 'password' || $field->type eq 'password_generator' ) {
            $field->required( 0 );
        }
    }
}

=pod

=head1 TODO

Possibly move various different views as their own classes, enabling adding new
ones like plugins.

=head1 SEE ALSO

L<Dicole|Dicole>,
L<OpenInteract|OpenInteract>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
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

