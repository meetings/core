package Dicole::Generictool::Field::Validate;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

Field content validation for Generictool

=head1 SYNOPSIS

  use Dicole::Generictool::Field::Validate;

  my $obj = Dicole::Generictool::Field::Validate->new();
  $obj->field( Dicole::Generictool::Field->new(
    id => 'example_password',
    type => 'password'
  ) );
  my $password = $obj->validate_password;

=head1 DESCRIPTION

The purpose of this class is to provide a way for I<Generictool> to validate user
input for certain form fields.

These field validator methods are named after the type of field you want to
validate, e.g. C<validate_password()> for field type I<password>. If you want to
create your own validators for different kind of field types this class is not
able to provide, feel free to inherit it and add new methods. I<Generictool>
is automagically able to call the correct method for your new field types.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=head2 new( [HASHREF] )

Returns a new I<Dicole::Generictool::Field::Validate> object. Optionally accepts initial
class attributes as parameter passed as an anonymous hash.

=head2 field( [OBJECT] )

Sets/gets the field object.

=head2 error( [BOOLEAN] )

Sets/gets the error flag. If this is set true the validation failed.

=head2 error_code( [SCALAR] )

Sets/gets the error code, which are:

=over 4

=item B<0>

Failed.

=item B<1>

Succeed.

=item B<2>

Succeed, but info available.

=back

=head2 error_msg( [STRING] )

Sets/gets the resulting error message.

=head2 value( [STRING] )

Sets/gets value of the resulting field.

=cut

use base qw( Class::Accessor );

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::Field::Validate->mk_accessors(
    qw( field error error_code error_msg value )
);

=pod

=head2 get_field_value()

Gets value of the field from either the field object itself or from
apache parameters.

=cut

sub get_field_value {
    my ( $self ) = @_;

    my $value = undef;
    if ( $self->field->use_field_value ) {
        $value = $self->field->value;
    }
    else {
        $value = CTX->request->param( $self->field->id );
    }
    if ( $self->field->null_value && $value eq '' ) {
        return undef;
    }
    return $value;
}

=pod

=head2 validate_default()

Default action (no proper validate function for the field exists),
which retrieves apache parameter input and returns it.

=cut

sub validate_default {
    my $self = shift;

    my $value = $self->get_field_value;

    $self->value( $value );
    return $value;
}

=pod

=head2 validate_selectoradd()

Retrieves apache parameters and selects the value according
by preferring "or add new" field.

=cut

sub validate_selectoradd {
    my $self = shift;

    my $value = $self->get_field_value;

    if ( CTX->request->param( $self->field->id . '_add_new' ) ) {
        $self->value( CTX->request->param( $self->field->id . '_add_new' ) );
    }
    else {
        $self->value( $value );
    }
    return $self->value;
}

=pod

=head2 validate_checkbox()

Retrieves checkbox value from request parameters and sets value of
checkbox to either 1 or 0.

=cut

sub validate_checkbox {
    my $self = shift;
    
    my $value = $self->get_field_value;
            
    $self->value( $value || 0 );
    return $value;
}

=pod

=head2 validate_tags()

Validates the tags action field, if no value, sets to an empty JSON array

=cut

sub validate_tags {
    my $self = shift;
    
    my $value = $self->get_field_value;
    $self->value( $value || "[]" );

    return $value;
}
                    
=pod

=head2 validate_file()

Retrieves I<OpenInteract2::Upload> object for the file upload
field and returns the filename.

=cut

sub validate_file {
    my $self = shift;

    my $upload = CTX->request->upload( $self->field->id );

    my $value = $upload->filename if ref $upload;

    $self->value( $value );
    return $value;
}

=pod

=head2 validate_date()

Retrieves apache parameters and constructs an UTC epoch return
value for date. Distinguishes date field type.

=cut

sub validate_date {

    my $self = shift;

    my $value = undef;
    my $field = $self->field;
    my $field_id = $field->id;

    if ( $self->field->use_field_value ) {
        $value = $self->get_field_value;
        $self->value( $value );
        return $value;
    }

    if ( $field->date_format eq 'string' ) {

        $value = sprintf('%d-%d-%d %d:%d:%d',
                CTX->request->param( $field_id . '_year' ),
                CTX->request->param( $field_id . '_month' ),
                CTX->request->param( $field_id . '_day' ),
                CTX->request->param( $field_id . '_hour') || '00',
                CTX->request->param( $field_id . '_minute' ) || '00',
                '00'
                );

    }
    elsif ( $field->date_format eq 'epoch' ) {

        eval {
            my $date = DateTime->now;
            my $timezone = CTX->request->auth_user->{timezone} || 'UTC';
            $date->set_time_zone( $timezone );
            $date->set( year => CTX->request->param( $field_id . '_year' ) )
                if defined CTX->request->param( $field_id . '_year' );
            $date->set( month => CTX->request->param( $field_id . '_month' ) )
                if defined CTX->request->param( $field_id . '_month' );
            $date->set( day => CTX->request->param( $field_id . '_day' ) )
                if defined CTX->request->param( $field_id . '_day' );
            ( defined CTX->request->param( $field_id . '_hour' ) ) ?
                $date->set( hour => CTX->request->param( $field_id . '_hour' ) )
                : $date->set( hour => '00' );
            ( defined CTX->request->param( $field_id . '_minute' ) ) ?
                $date->set( minute => CTX->request->param( $field_id . '_minute' ) )
                : $date->set( minute => '00' );
            $date->set( second => '00' );
            $value = $date->epoch;
        };

        if ($@) {
            $self->error( 1 );
            $self->error_code( 0 );
            $self->error_msg(
                CTX->request->language_handle->
                    maketext( 'Given date does not exist' )
            );
            $field->error( 1 );
        }
   }

    $self->value( $value );
    return $value;
}

=pod

=head2 validate_password()

Retrieves apache parameters for password field and validates
the contents.

Checks length of the password. If password
confirmation box is enabled for the field, checks if password
confirmation matches original password. Sets C<error()>
attribute if things fail.

If the password should be crypted, crypts it before returning
the value.

=cut

sub validate_password {

    my $self = shift;

    my $value = undef;
    my $field = $self->field;
    my $field_id = $field->id;

    my $password = $self->get_field_value;

    my $lh = CTX->request->language_handle;

    # Check if the passwords match if they should be verified
    if ( $field->options->{confirm}
            && ( $password ne CTX->request->param( $field_id . '_confirm' ) ) ) {
        $self->error( 1 );
        $self->error_code( 0 );
        $self->error_msg( $lh->maketext( 'The passwords do not match.' ) );
        $field->error( 1 );
    }

    # We skip password field if the field has a value and is shorter
    # than minimum password length
    if ( $password && length $password < $self->_MIN_PASS_LENGTH ) {
        $self->error( 1 );
        $self->error_code( 0 );
        $self->error_msg( $lh->maketext( 'The password is too short. '
            . 'Minimum password length is [_1] characters.',
            $self->_MIN_PASS_LENGTH
        ) );
        $field->error( 1 );
    }

    # check if password should be saved in encrypted form
    if ( $field->options->{crypt} ) {
        $value = SPOPS::Utility->crypt_it( $password );
    }
    elsif ( $password ) {
        $value = $password;
    }

    $self->value( $value );
    return $value;
}

=pod

=head2 validate_password_generator()

Retrieves apache parameters for password generator field and validates
the contents.

Checks length of the password. If password
confirmation box is enabled for the field, checks if password
confirmation matches original password. Sets C<error()>
attribute if things fail.

If the password should be crypted, crypts it before returning
the value.

=cut

sub validate_password_generator {

    my $self = shift;

    my $value = undef;
    my $field = $self->field;
    my $field_id = $field->id;

    my $password = $self->get_field_value;

    my $lh = CTX->request->language_handle;

    # We skip password field if the field has a value and is shorter
    # than minimum password length
    if ( $password && length $password < $self->_MIN_PASS_LENGTH ) {
        $self->error( 1 );
        $self->error_code( 0 );
        $self->error_msg( $lh->maketext( 'The password is too short. '
            . 'Minimum password length is [_1] characters.',
            $self->_MIN_PASS_LENGTH
        ) );
        $field->error( 1 );
    }

    # check if password should be saved in encrypted form
    if ( $field->options->{crypt} ) {
        $value = SPOPS::Utility->crypt_it( $password );
    }
    elsif ( $password ) {
        $value = $password;
    }

    $self->value( $value );
    return $value;
}

=pod

=head2 check_required()

If field is required, makes sure it is not empty. Sets C<error()> attribute
if things fail.

=cut

sub check_required {
    my ( $self ) = @_;

    if ( $self->field->required && $self->value eq '' ) {
        my $lh = CTX->request->language_handle;
        $self->error( 1 );
        $self->error_code( 0 );
        $self->error_msg( $lh->maketext( 'The fields marked with arrows are required.' ) );
        $self->field->error( 1 );
    }
}

=pod

=head1 PRIVATE METHODS

=head2 _MIN_PASS_LENGTH( [INT] )

Gets/sets default minimum password length, which is a default constant.

=cut

sub _MIN_PASS_LENGTH {
    my ( $self, $value ) = @_;
    if ( defined $value ) {
      $self->{_min_length} = $value;
    }
    unless ( defined $self->{_min_length} ) {
      $self->{_min_length} = CTX->lookup_login_config->{minimum_password_length} || 5;
    }
    return $self->{_min_length};
}

=pod

=head1 SEE ALSO

L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHOR

Sakari Lehtonen, E<lt>sakari@ionstream.fiE<gt>

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

