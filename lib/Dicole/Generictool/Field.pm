package Dicole::Generictool::Field;

use strict;
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.29 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Field editor Generictool

=head1 SYNOPSIS

 use Dicole::Generictool::Field;
 my $field = Dicole::Generictool::Field->new( id => 'user_name' );
 $field->type( 'textfield' );
 $field->desc( 'Username' );
 $field->required( 1 );
 $field->link( '/usermanager/details/?uid=IDVALUE' );

=head1 DESCRIPTION

The purpose of this class is to provide an object oriented way to
maintain generic I<Dicole Fields>. In Dicole, Fields are sophisticated user
input elements that contain atleast I<id>, I<type>, I<value> and I<description>.

I<Id> is the unique way to identify the field. Usually field I<id> is the
same as the database column or the I<SPOPS object> field in question.
Fields are mapped against I<SPOPS objects>.

I<Type> specifies the field type, for example I<textfield> or I<date>, which
defines the logic how the field should behave and what it may contain.

Each field has a value, which is fetched from the I<SPOPS object> or received
as a user input.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 ACCESSORS

=head2 id( [STRING] )

Sets/gets the I<ID> of the field. This is used to identify the field.

Note the relation with accessor I<object_field()>.

=head2 desc( [STRING] )

Sets/gets the description of the field.

=head2 link( [STRING] )

Sets/gets the link of the field if displayed in list context. The
field appears to be linkable. Very useful if you want to generate
a list of SPOPS objects which are linkable. Link may contain the following
special keys as part of the link, which get replaced when a link
is created:

=over 4

=item B<IDVALUE>

The SPOPS id field which contents' will be replaced here.
The default is the object id value. To change this, see I<link_field()>.

=item B<GROUPID>

The target group id.

=item B<USERID>

The target user id.

=item B<TARGETID>

The target id (user or group, doesn't matter).

=item B<ACTION_NAME>

The name of the current action.

=item B<TASK_NAME>

The name of the current task.

=back

=head2 link_field( [STRING] )

Sets the field of the object which is replaced in the link I<IDVALUE>.
Default is object id field.

=head2 link_noescape( [BOOLEAN] )

Sets/gets the link non-escaping bit. If this is set on, the link value
(IDVALUE) is not escaped when placed as part of the link.

=head2 empty_text( [STRING] )

Sets/gets the I<empty text> to display if the field is empty. This is used
in read only views to display some text in place of the field if it is empty.
For example, if a date is not specified in a date field you might want to set
I<empty_text> as I<Undefied>.

=head2 required( [BOOLEAN] )

Sets/gets the field required bit. In practice this means that the page will
display a blue arrow next to the field to indigate that the field is required.
The page doesn't allow saving the object until the field contains a value.

=head2 class( [CLASS] )

Sets/gets the custom class for the field.
When used with field type customobject, this allows you to set
a custom object class to call for the field.

=head2 object( [OBJECT] )

Sets/gets the custom object for the field.
When used with field type customobject, this allows you to set
a custom object for the field.

=head2 value_is_object( [BOOLEAN] )

Sets/gets the value is object bit. If this is true and field type is
customobject, then the resulting content field is retrieved from
the object or field value.

=head2 date_format( [STRING] )

Sets/gets the method which is used to store date in the object. Possible
options are I<epoch> and I<string>. Epoch is in UTC format, seconds since epoch.
String is in UTC format, in format I<YYYY-MM-DD HH:MM:SS>.

=head2 error( [BOOLEAN] )

Sets/gets the error bit. This is used to indicate that the field value is
not correct. Typically draws a red arrow next to the field. The page
doesn't allow saving the object until the field contains a correct value.

=head2 type( [STRING] )

Sets/gets the type of the field. Currently support types are I<text>,
I<date>, I<checkbox>, I<textfield>, I<selectoradd>, I<textarea>, I<dropdown>,
I<password>, I<image> and I<customobject>. With customobject you may define your
own I<Dicole Content object> that generates the content of the field.

=head2 use_field_value( [BOOLEAN] )

Sets/gets the field value bit. When this is on I<Generictool> reads
the field value from the field object itself and not from an arbitary
source.

=head2 value( [STRING] )

Sets/gets the value of the field.

=head2 null_value( [BOOLEAN] )

Sets/gets the null value bit. If this is set true and the field value
is empty, an undef is assigned instead of empty to the SPOPS object.
This is useful with certain database field types like I<int unsigned>,
which doesn't work with SPOPS properly if an empty value is used instead
of undef.

=head2 default_value( [STRING] )

Sets/gets the default value. If the value for the field retrieved from the object or
the field is empty or undef, the value of this accessor will be used instead.

=head2 object_field( [STRING] )

Sets/gets the SPOPS object field, which will be the target of this field.

By default object field is the same as Field id.

This is useful to change if you have two views for two different SPOPS
objects on a single page and both objects have some identical id fields.
This allows you to overcome the overlap of the id fields.

=head2 relation( [STRING] )

Defines that the object field is in a has_a relation to another object
through the specified method of the SPOPS object.

This is useful if you have a SPOPS object which has a has_a object
field which points to another object and want to use the value of the
another object instead of the has_a id field in your SPOPS object.

See also accessors I<relation_fields()> and I<relation_field_separator()>.

=head2 relation_fields( [ARRAYREF] )

Sets/gets the fields of the has_a object which will be displayed as
described in the I<relation()> accessor.

Because the accessor accepts an arrayref of relation fields, you may
provide a number of fields instead of a single one. This is useful
if you have a has_a relation to a user object which has the I<first_name>
and I<last_name> columns and want to display the full name of the user
instead of the first name and last name only. This is used in conjunction
with I<relation_field_separator()>.

=head2 relation_field_separator( [STRING] )

Sets/gets the separating string which will be used in conjunction with
I<relation_fields()>.

For example, if you have defined relation fields as I<first_name> and
I<last_name> and want to display the full name separated with a space,
provide a space to this accessor.

The default is space (" ").

=head2 text_only( [BOOLEAN] )

Sets/gets the text only bit. If this is true, then the field is not
possible to modify. This is mainly useful if you are planning to have
an edit or add form and have some of the fields marked with modifyable
as false to appear as the text-only versions.

=head2 localize( [BOOLEAN] )

Sets/gets the localize bit. If this is set on, the field value is
supposed to be run through the localization framework.

=cut

=head2 object_id ( [NUMERICAL] )

Sets/gets the object_id. Used to identify content objects. Used with the Tag
system.

=cut

=head2 object_id ( [STRING] )

Sets/gets the object_type. Same as the objects SPOPS name. Used to identify 
content objects. Used with the Tag system.

=cut

# We are lazy...Lets generate some basic accessors for our class
__PACKAGE__->mk_accessors(
    qw( id link desc empty_text required use_field_value value object
        date_format class error type null_value link_field object_field
        relation relation_fields relation_field_separator localize
        link_noescape value_is_object default_value text_only object_id
	object_type )
);

=pod

=head1 METHODS

=head2 new( id => STRING )

Method B<new()> creates a new
L<Dicole::Generictool::Field|Dicole::Generictool::Field> object. You may
specify initial field attributes by passing them as a list of hash keys
and values to B<new()>. For available attributes, available methods that
alter the object attributes. Attribute I<id> is required when creating
the object.

=cut

sub new {
    my ($class, %args) = @_;
    my $self = bless( {}, $class );
    $self->_init( %args );
    return $self;
}

=pod

=cut

sub _init {
    my ($self, %args) = @_;
    die( "Must provide id for Generictool field!" ) unless $args{id};
    foreach my $key ( keys %args ) {
        $self->$key( $args{$key} ) if $self->can( $key );
    }
    $self->class( $args{object} )
        if ref( $args{object} ) && $self->type eq 'customobject';
    $self->object_field( $self->id ) unless $self->object_field;
    $self->relation_field_separator( ' ' )
        unless defined $self->relation_field_separator;
    $self->options( {} ) unless $self->options;
}

=pod

=head2 options( [HASH] )

Sets/gets field type specific options. The options are passed to new()
of each content object. Special field specific options
(used by Generictool) are listed below:

=over 4

=item B<crypt>

A boolean value that specifies if the input from password fields should
be crypted before saving in the I<SPOPS object>.

=item B<checked>

A boolean value that controls the checked status of a checkbox field.

=item B<prefix_url>

A string which value will be used to prefix the url in file selection fields
that begin with forward slash (/). This is useful in image selection
fields, for example.

=item B<no_filter>

A boolean value that controls if a text-only version (non-modifyable)
of a field is filtered as HTML safe or not. This is useful if you want
to let HTML content through.

=back

For more field specific options, see documentation of the
corresponding object documentation:

L<Dicole::Content::Formelement|Dicole::Content::Formelement>,
L<Dicole::Content::Formelement::Password|Dicole::Content::Formelement::Password>,
L<Dicole::Content::Formelement::Date|Dicole::Content::Formelement::Date>,
L<Dicole::Content::Formelement::Dropdown|Dicole::Content::Formelement::Dropdown>

=cut

sub options {
    my ( $self ) = shift;
    if ( ref $_[0] eq 'HASH' ) {
        $self->{options} = $_[0];
    }
    elsif ( scalar @_ ) {
        $self->{options} = { @_ };
    }
    return $self->{options};
}

=pod

=head2 mk_dropdown_options( HASH )

Very often dropdowns contain options that are generated from a certain group
of I<SPOPS> objects. This simple utility method simplifies such a process and
is most of the time sufficient for our needs. In case of generating more complex
set of dropdown options the handler writer should implement her own.

The method accepts the following parameters as an anonymous hash:

=over 4

=item B<class> I<class>

The I<SPOPS> class name to use, for example CTX->lookup_object('user')

=item B<params> I<hashref>

Parameters to pass for I<SPOPS> C<fetch_group()> as an anonymous hash.

=item B<value_field> I<string>

The I<SPOPS> field name which content will be the value of the dropdown
option.

If this is not set, then the object id will be used.

=item B<content_field> I<string|arrayref>

The I<SPOPS> field name or an arrayref of field names which contents
will be the content of the dropdown option. If the parameter is an arrayref,
separator is used to separate field values from each other. See I<separator>
parameter.

=item B<separator> I<string>

The string that seprates the different field values from each other. See
I<content_field> parameter for more information.

=item B<distinct> I<boolean>

The dropdown option values will be distinct. This means that there will be no
duplicate values. This is useful if you want to construct a dropdown of "categories"
by selecting distinct values from a certain I<SPOPS> field.

=back

=cut

sub mk_dropdown_options {
    my ( $self, @p ) = @_;

    my %p = @p;
    my @rows;
    my %lookup_hash;

    foreach my $option ( @{ $p{class}->fetch_group( $p{params} ) } ) {
        if ( $p{distinct} ) {
            next if $lookup_hash{ $option->{$p{value_field}} };
            $lookup_hash{ $option->{$p{value_field}} } = 1;
        }
        push @rows, $option;
    }

    my $lh = CTX->request->language_handle;

    foreach my $option ( @rows ) {
        my $content = undef;
        if ( ref( $p{content_field} ) eq 'ARRAY' ) {
            my @content_values = ();
            foreach my $field ( @{ $p{content_field} } ) {
                push @content_values, $option->{ $field };
            }
            $content = join $p{separator}, @content_values;
        }
        else {
            $content = $option->{ $p{content_field} };
        }

        if ( $p{localize} ) {
            $content = $lh->maketext( $content );
        }
        $self->add_dropdown_item(
            $p{value_field} ? $option->{ $p{value_field} } : $option->id,
            $content
        );
    }
}

=pod

=head2 add_dropdown_item( STRING, STRING )

Adds a dropdown item. Accepts the value and the content of the dropdown
item as parameters.

=cut

sub add_dropdown_item {
    my ( $self, $value, $content ) = @_;

    push @{ $self->{options}{options} }, {
        attributes => { value => $value },
        content => $content
    };
}

=pod

=head2 del_dropdown_item( STRING )

Removes a dropdown item based on item id.

=cut

sub del_dropdown_item {
    my ( $self, $value ) = @_;
    $self->{options}{options} = [
        grep { $_->{attributes}{value} ne $value } @{ $self->{options}{options} }
    ];
}

=pod

=head2 add_dropdown_options( ARRAYREF )

Adds the dropdown options specified in the array reference.

=cut

sub add_dropdown_options {
    my ( $self, $array ) = @_;

    foreach ( @$array ) {
        push @{ $self->{options}{options} }, $_;
    }
}

=pod

=head1 BUGS

None known.

=head1 TO DO

None.

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>,
L<Dicole::Content::Formelement|Dicole::Content::Formelement>,
L<Dicole::Content::Formelement::Password|Dicole::Content::Formelement::Password>,
L<Dicole::Content::Formelement::Date|Dicole::Content::Formelement::Date>,
L<Dicole::Content::Formelement::Dropdown|Dicole::Content::Formelement::Dropdown>,
L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHORS

Teemu Arina, E<lt>teemu@dicole.fiE<gt>

=head1 COPYRIGHT

  Copyright (c) 2004 Ionstream Oy / Dicole
  http://www.dicole.fi

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 2 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

=cut

1;
