package Dicole::Generictool::Field::Construct;

use 5.006;
use strict;

use DateTime;
use Dicole::Calcfunc;
use Dicole::Content::Formelement::Date;
use Dicole::Content::Formelement;
use Dicole::Content::Formelement::Password;
use Dicole::Content::Formelement::Dropdown;
use Dicole::Content::Formelement::PasswordGenerator;
use Dicole::Content::Formelement::Textarea;
use Dicole::Content::Text;
use Dicole::Content::Formelement::Chooser;
use Dicole::Content::Image;
use OpenInteract2::URL;
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use Log::Log4perl qw( get_logger );
use Dicole::Pathutils;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.71 $ =~ /(\d+)\.(\d+)/ );

my ( $log ); #the OI2 way

=pod

=head1 NAME

Field content constructor for Generictool

=head1 SYNOPSIS

  use Dicole::Generictool::Field::Construct;

  my $obj = Dicole::Generictool::Field::Construct->new();
  $obj->field( Dicole::Generictool::Field->new(
    id => 'example_password',
  ) );
  $obj->object( CTX->lookup_object('user')->new );
  $obj->modifyable( 1 );
  my $password = $obj->construct_password;

=head1 DESCRIPTION

The purpose of this class is to provide a way for I<Generictool> to construct content
objects out of I<SPOPS> objects which are mapped against field objects.

These content constructor methods are named after the type of field you want to
construct, e.g. C<construct_password()> for field type I<password>. If you want to
create your own constructors for different kind of field types this class is not
able to provide, feel free to inherit it and add new methods. I<Generictool>
is automagically able to call the correct method for your new field types.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=head2 new( [HASHREF] )

Returns a new I<Dicole::Generictool::Field::Construct> object. Optionally accepts initial
class attributes as parameter passed as an anonymous hash.

=head2 field( [OBJECT] )

Sets/gets the field object.

=head2 modifyable( [BOOLEAN] )

Sets/gets the modifyable flag. If this is set true the resulting content object
will be read-only.

=head2 object( [OBJECT] )

The I<SPOPS> object which fields are mapped against fields.

=head2 undef_if_empty( [BOOLEAN] )

Sets/gets the undef if empty flag. If the value of a field is empty or
null, undef will be returned as the field. This is useful if you want
to remove fields that are empty from a display.

=head2 custom_link_values( [HASHREF] )

Sets/gets the custom link values hashref. This hash can be used to insert a specified string into the links to replace CUSTOM_VALUE{hash_key}.
The value can be either a scalar which is used as is or a code reference
which returns the value when it is passed the current Construct object as
it's first parameter.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::Field::Construct->mk_accessors(
    qw( field modifyable object undef_if_empty custom_link_values )
);

=pod

=head2 get_field_value()

Gets value of the field from either the field object itself or the
SPOPS object.

This method is also aware of the possible has_a relation to another
object from the SPOPS object field and is able to fetch the related object
and return the specified relation fields as the value.

=cut

sub get_field_value {
    my ( $self ) = @_;
    my $value = undef;
    if ( $self->field->use_field_value ) {
        $value = $self->field->value;
    }
    elsif ( $self->field->relation ) {
        my $relation = $self->field->relation;
        my $related_object = eval { $self->object->$relation( {
            skip_security => 1
        } ) };
        if ( $@ ) {
            $log ||= get_logger( LOG_DS );
            $log->error( "Error fetching object relation: " . $@ );
        }
        $value = join $self->field->relation_field_separator, map(
            $related_object->{$_},
            @{ $self->field->relation_fields }
        );
    }
    else {
        $value = $self->object->{$self->field->object_field};
        $value = "$value" if ref( $value ) eq 'DateTime'; # Some SPOPS fields are DateTime objects
    }
    if ( $self->field->localize ) {
        $value = CTX->request->language_handle->maketext( $value );
    }
    if ( ( $value eq '' || !defined( $value ) ) && $self->field->default_value ) {
        return $self->field->default_value;
    }

    return $value;
}

=pod

=head2 construct_date()

Maps object field against date field, constructs a new content object
and returns it. Distinguishes date field type.

=cut

sub construct_date {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable ) && !$value ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;
    $attributes->{attributes}{name} = $self->field->id;

    # epoch format
    if ( defined Dicole::Calcfunc::if_int( $value ) ) {
        $attributes->{epoch} = $self->get_field_value;
    }
    # yyyy-mm-dd hh:mm:ss format
    elsif ( $value =~ /^(\d+)-(\d+)-(\d+).(\d+):(\d+):(\d+)$/ ) {
        $attributes->{epoch} = DateTime->new(
            year   => $1,
            month  => $2,
            day    => $3,
            hour   => $4,
            minute => $5
            )->epoch;
    }

    my $timezone = CTX->request->auth_user->{timezone} || 'UTC';
    $attributes->{timezone} ||= $timezone;

    return Dicole::Content::Formelement::Date->new( %{ $attributes } );
}

=pod

=head2 construct_selectoradd()

Maps object field against a select-or-add field, constructs a new content object
and returns it. If the content is modifyable, returns an arrayref of content objects
(select dropdown, text and input field).

=cut

sub construct_selectoradd {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    my %input_attributes = (
        attributes => {
            type => 'text',
            name => $self->field->id . '_add_new',
        },
        required => $self->field->required,
        error => $self->field->error,
    );

    # error and required only for the text field
    delete $attributes->{required};
    delete $attributes->{error};

    # Prefer value in dropdown, if value is not in the dropdown
    # add it into the text field
    foreach my $option ( @{ $attributes->{options} } ) {
        if ( $option->{attributes}{value} eq $value ) {
            $attributes->{selected} = $value;
            last;
        }
    }
    unless ( defined $attributes->{selected} ) {
        $input_attributes{attributes}{value} = $value;
    }

    my $lh = CTX->request->language_handle;

    if ( !$self->field->text_only && $self->modifyable ) {
        unshift @{ $attributes->{options} }, {
            attributes => { value => '' },
            content => '===' . $lh->maketext( 'Select' ) . '==='
        };
        $attributes->{attributes}{name} = $self->field->id;
        $attributes->{attributes}{id} = $self->field->id;
        $attributes->{attributes}{readonly} = $attributes->{readonly}
            if $attributes->{readonly};

        return [
            Dicole::Content::Formelement::Dropdown->new( %{ $attributes } ),
            Dicole::Content::Text->new( content => $lh->maketext( 'or add new' ) ),
            Dicole::Content::Formelement->new( %input_attributes )
        ];
    }
    else {
        $attributes->{attributes}{name} = $self->field->id;
        $attributes->{attributes}{id} = $self->field->id;
        return Dicole::Content::Formelement::Dropdown->new( %{ $attributes } );
    }
}

=pod

=head2 construct_image()

Maps object field against image field, constructs a new content object
and returns it.

=cut

sub construct_image {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    if ( !$self->field->text_only && $self->modifyable ) {
        $attributes->{attributes}{name} = $self->field->id;
        $attributes->{attributes}{id} = $self->field->id;
        $attributes->{attributes}{type} = 'text';
        $attributes->{attributes}{value} = $value;
        $attributes->{attributes}{readonly} = $attributes->{readonly}
            if $attributes->{readonly};
        return Dicole::Content::Formelement::Chooser->new( %{ $attributes } );
    }
    else {
        $value = undef unless $value =~ m{^(http)|(/)};
        if ( $attributes->{prefix_url} && $value =~ m{^/} ) {
            $value = $attributes->{prefix_url} . $value;
        }
        $attributes->{href} = $attributes->{plaintext_link} if $attributes->{plaintext_link};
        $attributes->{src} = $value;
		if ( $attributes->{title} ) {
	        $attributes->{attributes}{alt} = $attributes->{title};
    	    $attributes->{attributes}{title} = $attributes->{attributes}{alt};
		}
        unless ( $value ) {
            return $self->_show_empty_text;
        }
        else {
            return Dicole::Content::Image->new( %{ $attributes } );
        }
    }
}

=pod

=head2 construct_textfield()

Maps object field against text field, constructs a new content object
and returns it.

=cut

sub construct_textfield {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{type} = 'text';
    $attributes->{attributes}{value} = $value;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    return Dicole::Content::Formelement->new( %{ $attributes } );
}

=pod

=head2 construct_file()

Maps object field against file upload field, constructs a new content object
and returns it.

=cut

sub construct_file {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{type} = 'file';
    $attributes->{attributes}{value} = $value;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    return Dicole::Content::Formelement->new( %{ $attributes } );
}

=pod

=head2 construct_checkbox()

Maps object field against a checkbox field, constructs a new content object
and returns it. Investigates field properties to find out if the checkbox
is checked or not.

=cut

sub construct_checkbox {
    my $self = shift;

    if ( $self->field->text_only || !$self->modifyable ) {
        my $lh = CTX->request->language_handle;
        if ( $self->get_field_value ) {
            $self->field->empty_text( $lh->maketext( 'Yes' ) );
        }
        else {
            $self->field->empty_text( $lh->maketext( 'No' ) );
        }
        return $self->_show_empty_text;
    }

    my $field = $self->field;
    my $attributes = $self->_get_default_attributes;

    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{type} = 'checkbox';
    $attributes->{attributes}{value} = $field->value || 1;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    if ( $attributes->{checked}
        || ( !$self->field->use_field_value
        && $self->object->{$self->field->id} )
    ) {
        $attributes->{attributes}{checked} = 'checked';
    }

    return Dicole::Content::Formelement->new( %{ $attributes } );
}

=pod

=head2 construct_password()

Constructs a new content object for password and returns it.
Does not map object data against password fields because password
field contents are not displayable anyway. Investigates field properties
to look if the password field should contain an additional password
confirmation field.

=cut

sub construct_password {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }
    my $field = $self->field;
    my $attributes = $self->_get_default_attributes;
    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    $attributes->{attributes}{type} = $field->type;
    if ( $attributes->{confirm} ) {
        $attributes->{confirm} = 1;
    }
    # Password fields should be empty because there is nothing to see anyway
    $attributes->{attributes}{value} = "";

    return Dicole::Content::Formelement::Password->new( %{ $attributes } );
}

=pod

=head2 construct_password_generator()

Constructs a new content object for generating a password and returns it.
Does not map object data against password field because password
field contents are not displayable anyway.

=cut

sub construct_password_generator {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }
    my $field = $self->field;
    my $attributes = $self->_get_default_attributes;
    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{type} = 'text';
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    # Password fields should be empty because there is nothing to see anyway
    $attributes->{attributes}{value} = "";

    return Dicole::Content::Formelement::PasswordGenerator->new( %{ $attributes } );
}

=pod

=head2 construct_textarea()

Maps object field against text area field, constructs a new content object
and returns it.

=cut

sub construct_textarea {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{attributes}{value} = $value;
    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    if ( !$self->field->text_only && $self->modifyable ) {
        return Dicole::Content::Formelement::Textarea->new( %{ $attributes } );
    }
    else {
        return Dicole::Content::Text->new(
            content => $attributes->{attributes}{value},
            no_filter => $attributes->{no_filter},
            html_line_break => $attributes->{html_line_break}
        );
    }
}

=pod

=head2 construct_text()

Maps object field against text area field, constructs a new content object
and returns it.

=cut

sub construct_text {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{content} = $value;

    return Dicole::Content::Text->new( %{ $attributes } );
}

=pod

=head2 construct_hyperlink()

Maps object field against hyperlink field, constructs a new content object
and returns it.

=cut

sub construct_hyperlink {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{content} = $value;
    $attributes->{attributes}{href} = $attributes->{plaintext_link};

    return Dicole::Content::Hyperlink->new( %{ $attributes } );
}

=pod

=head2 construct_dropdown()

Maps object field against dropdown field, constructs a new content object
and returns it.

=cut

sub construct_dropdown {
    my $self = shift;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    my $attributes = $self->_get_default_attributes;

    $attributes->{selected} = $value;
    $attributes->{attributes}{name} = $self->field->id;
    $attributes->{attributes}{id} = $self->field->id;
    $attributes->{attributes}{readonly} = $attributes->{readonly}
        if $attributes->{readonly};

    return Dicole::Content::Formelement::Dropdown->new( %{ $attributes } );
}

=pod

=head2 construct_customobject()

Maps object field against custom object and returns it.

If field attribute I<object> is specified, it will be used as the content object.
This function tries to call accessors I<required, error, modifyable, value and plaintext_link>
in the object with default parameters if such methods exist.

If field attribute I<class> is specified, it will be used to create a new
custom content object by providing default parameters to the constructor.

For more information fo the default attributes, see class method I<_get_default_attributes()>.

=cut

sub construct_customobject {
    my $self = shift;

    my $field = $self->field;

    my $attributes = $self->_get_default_attributes;

    my $value = $self->get_field_value;
    return undef if $self->undef_if_empty
        && ( !defined $value || $value eq '' );

    if ( ( $self->field->text_only || !$self->modifyable )
        && ( $value eq '' || !defined $value )
    ) {
        return $self->_show_empty_text;
    }

    $attributes->{attributes}{value} = $value;

    if ( ref $field->object ) {
        foreach my $option ( qw( required error modifyable plaintext_link ) ) {
            $field->object->$option( $attributes->{ $option } )
                if $field->object->can( $option );
        }
        $field->object->value( $attributes->{attributes}{value} )
            if $field->object->can( 'value' );
        return $field->object;
    }
    elsif ( $field->value_is_object ) {
        return $value;
    }

    return $field->class->new( %{ $attributes } );
}

=pod

=head1 PRIVATE METHODS

=head2 _get_default_attributes()

Constructs default parameters for content objects based on Field class attributes
and returns it as an anonymous hash. Also replaces I<IDVALUE> in field link with
field link_field or SPOPS object id. Example of the hash:

 {
     required => 1,
     error => 1,
     modifyable => 1
     plaintext_link => '/users/?id=5'
     attributes => {
         name => 'username'
     }
 }

Also appends the attributes present in the Field class accessor I<options> in the
resulting hash.

=cut

sub _get_default_attributes {
    my $self = shift;

    my $field = $self->field;

    my $link = $field->link;
    if ( $link ) {
        my $link_field = $field->link_field;
        my $link_id = ($link_field) ? $self->object->{$link_field} : $self->object->id;

        # If url should not be escaped
        if ( $field->link_noescape ) {
            $link =~ s/IDVALUE/$link_id/gs;
        }
        # Otherwise escape
        else {
            $link =~ s/IDVALUE/OpenInteract2::URL::_url_escape($link_id)/ges;
        }

        $link =~ s/GROUPID/CTX->request->target_group_id/ges;
        $link =~ s/USERID/CTX->request->target_user_id/ges;
        $link =~ s/TARGETID/CTX->request->target_id/ges;
        $link =~ s/ACTION_NAME/CTX->controller->initial_action->name/ges;
        $link =~ s/TASK_NAME/CTX->controller->initial_action->task/ges;

        if ( ref( $self->custom_link_values ) eq 'HASH' ) {
            for ( keys %{ $self->custom_link_values } ) {
                my $key = 'CUSTOM_VALUE{' . $_ . '}';
                my $value = $self->custom_link_values->{$_};
                if ( ref $value eq 'CODE' ) {
                    $value = $value->( $self );
                }
                $link =~ s/\Q$key/$value/gs;
            }
        }

        my $urlpath = Dicole::Pathutils->new;
        $urlpath->url_base_path( CTX->request->target_id ) if CTX->request->target_id;
        $link =~ s/PATH/$urlpath->get_current_path( 1 )/ges;
    }

    my $options = $field->options;
    $options = {} unless ref( $options ) eq 'HASH';
    return {
        %{ $options }, # common (default) options
        required => $field->required,
        error => $field->error,
        ( $self->modifyable )
            ? ( $field->text_only ? ( modifyable =>  0 ) : ( modifyable =>  1 ) )
            : ( modifyable =>  0 ),
        plaintext_link => $link
    };
}

=pod

=head2 _show_empty_text()

Returns a L<Dicole::Content::Text> object with the empty text specified.

=cut

sub _show_empty_text {
    my $self = shift;
    Dicole::Content::Text->new( content => $self->field->empty_text );
}

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

