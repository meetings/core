package Dicole::Generictool::Wizard::Page::AdvancedSelect;

use 5.006;
use OpenInteract2::Context   qw( CTX );
use strict;

=pod

=head1 NAME

Dicole::Generictool::Wizard::Page::AdvancedSelect - The advanced select list page objects used by the wizard

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 INHERITS

Inherits L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, and
overwrites some of its methods.

=cut

use base qw( Dicole::Generictool::Wizard::Page );
use Dicole::Generictool::Wizard::Page;
use Dicole::Generictool;
use Dicole::Generictool::Field;
use Dicole::Utility;
use Dicole::Content::Formelement;

$Dicole::Generictool::Wizard::Page::AdvancedSelect::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);


Dicole::Generictool::Wizard::Page::AdvancedSelect->mk_accessors(
    qw( _list_of_selected _adv_sel_field _select _selected select_name selected_name)
);
=pod

=head1 METHODS

=head2 new( HASH )

Constructor. Accepts all superclass's arguments & the additional arguments:

=over 4

=item B<gtool_options> I<anonymous hash of options for the generictool constructor> .

=item B<field_options> I<anonymous hash containing the options for the advanced list field (especially you shoud define id, and probably value for default value)> .

=item B<select_id> I<optional id for separating advanced selects in same wizard> .

=back

=cut

sub _init {
    my ( $self, $args ) = @_;

    $self->SUPER::_init( $args ); # call _init() of the parent class

    $self->_adv_sel_field( Dicole::Generictool::Field->new(
        id => $self->page_id() . '_adv_sel',
        type => 'advanced_select',
        ref($args->{field_options}) eq 'HASH' ?
            %{ $args->{field_options} } : ()
    ) );

        $self->select_name( $args->{select_name} );
        $self->selected_name( $args->{selected_name} );

        $self->_selected( 'selected-'.$self->page_id );
        $self->_select( 'select-'.$self->page_id );
}

=pod

=head2 fields( [ARRAYREF] )

Sets/returns the array of L<Dicole::Generictool::Field|Dicole::Generictool::Field> objects
used by the Generictool object.
Returns the single generated field object of the advanced select page in an anonymous array.

=cut

sub fields {
    my $self = shift;
    $self->Generictool->fields(@_) if( @_ );
    return [ $self->_adv_sel_field() ];
}

=pod

=head2 add_field( HASH )

Creates a new L<Dicole::Generictool::Field|Dicole::Generictool::Field> object. The given
arguments are passed on to the constructor. The new object is pushed in the end of the
fields array.

=cut

sub add_field {
    my $self = shift;
    return $self->Generictool->add_field(@_);
}

=pod

=head2 name()

Returns the content of the advSelect page.

=cut

sub name {
    my $self = shift;
    my $selname = $self->select_name. ' (' . ($self->page_number()+1) . '/' . $self->page_count() . ')';
    return [ $selname, $self->selected_name ];
}

=pod

=head2 content()

Returns the content of the advSelect page.

=cut

sub content {
    my $self = shift;

    # Add some query parameters. These are added into the browsing, sorting etc. links
    my $query_params = CTX->request->url_query;
    $query_params->{dicole_wizard_random_id} = $self->wizard_id;
    $query_params->{dicole_wizard_page_number} = $self->page_number;
    $query_params->{dicole_wizard_max_page_number} = $self->max_page_number;

    # Include additional hidden fields also in the query parameters.
    if ( $self->hidden_fields ) {
        foreach ( keys %{ $self->hidden_fields } ) {
            $query_params->{$_} = $self->hidden_fields->{$_};
        }
    }

    # two anonymous arrays of Content objects are returned:
    my ($select, $selected) = $self->Generictool->get_advanced_sel(
            selected => $self->_list_of_selected,
            select_view => $self->_select,
            selected_view => $self->_selected,
        );

    return [
        [ @{$select} ],
        [ @{$selected} ,
            $self->_generate_buttons(),
            $self->_generate_hidden_fields(),
            ]
    ];
}

=pod

=head2 activate()

This method should be called after initialization. Does all the dirty work.

=cut

sub activate {
    my $self = shift;

    my $ignore_defaults = $self->max_page_number >= $self->page_number;
    $self->max_page_number( $self->page_number() ) if( $self->page_number > $self->max_page_number );

    $self->Generictool->set_fields_to_views( views => [ $self->_select, $self->_selected ] );

    $self->_update_field_values( ignore_defaults => $ignore_defaults ); # sets the field value for the generated advanced_select field

    $self->_add_checked() if( CTX->request->param( $self->_select.'_add_checked' ) );
    $self->_remove_checked() if( CTX->request->param( $self->_selected.'_remove_checked' ) );

    $self->_save_selected(); # save the changes
}

=pod

=head2 validate_fields()

Validates the fields of the currently shown switch page.
Returns false unless a suitable page was found.

=cut

## returns 0 unless a suitable page is found
sub validate_fields {
    my $self = shift;
    return 1;
}

=pod

=head2 save_fields()

Saves the fields of the currently shown switch page. Note that
this method doesn't really do anything. It is just defined to
replace the method in the parent class. The saving is actually
done automatically during the activate()-method.

=cut

sub save_fields {
    my $self = shift;
}


=pod

=head1 PRIVATE METHODS

=head2 _save_selected()

Saves the wizard temporary data (stored in the internal field variable) in database.

=cut

sub _save_selected {
    my $self = shift;
    $self->Datasaver()->wizard_data( $self->wizard_data() );

#   foreach my $field ( @{ $self->fields() } ) {
    my $field = $self->_adv_sel_field;
    $self->Datasaver()->field( $field );

    my $method =  $self->Datasaver()->can( 'save_' . $field->type() );
    if( $method ) { $self->Datasaver()->$method; }
    else          { $self->Datasaver()->save_default(); }
#   }

}

=pod

=head2 _add_checked()

Adds the selected objects to the list stored in the internal field variable.

=cut

sub _add_checked {
    my $self = shift;
    my @checked = $self->_checked_ids( $self->_select );

    my @new_list = ( @{ $self->_list_of_selected }, @checked );
    $self->_adv_sel_field->value( \@new_list );
}

=pod

=head2 _remove_checked()

Removes the selected objects from the list stored in the internal field variable.

=cut

sub _remove_checked {
    my $self = shift;
    my @checked = $self->_checked_ids( $self->_selected );

    my @new_list;
    foreach my $value ( @{ $self->_list_of_selected } ) {
        # push the value in the @new_list only if it can't be found from the list of removed elements
        push @new_list, $value unless( grep { $_ == $value } @checked );
    }
    $self->_adv_sel_field->value( \@new_list );
}

=pod

=head2 _checked_ids( SCALAR, [ARRAYREF] )

Fetches the checked ids from Apache. The first argument is the
prefix used in the checkbox names of the advanced selection list.

The optional second argument is a list of ids that should be
also included in the list.

Returns an array of ids.

=cut

sub _checked_ids {
    my ( $self, $prefix, $custom_ids ) = @_;
    $prefix ||= $self->_select;

    my @ids;
    if ( ref( $custom_ids ) eq 'ARRAY' ) {
        @ids = @{ $custom_ids };
    }
    else {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( $prefix ) }
        ) {
            push @ids, $id;
        }
    }
    return @ids;
}

=pod

=head2 _list_of_selected()

Returns the list of id values stored in the internal field variable (returns an anonymous array).

=cut

sub _list_of_selected {
    my $self = shift;

    my $value = $self->_adv_sel_field->value;
    # Returns anonymous array. If $value is scalar and it is defined, create new array containing the scalar.
    return ref( $value ) eq 'ARRAY' ?
        $value : defined $value ?
                [ $value ] : [];
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
L<Dicole::Generictool|Dicole::Generictool>,
L<OpenInteract|OpenInteract>

=head1 AUTHORS

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

