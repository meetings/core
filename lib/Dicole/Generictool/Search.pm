package Dicole::Generictool::Search;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;
use Dicole::Content::Formelement;
use Dicole::Content::Formelement::Dropdown;
use Dicole::Content::Button;
use Dicole::Generictool::SessionStore;
use Dicole::Generictool;

use Dicole::Utility;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Searching for Generictool lists

=head1 SYNOPSIS

  use Dicole::Generictool::Search;

  my $obj = Dicole::Generictool::Search->new( action => ['Users','list'] );
  $obj->searchable( [ qw(john peter) ] );
  $obj->search_type( 'select_column' );
  $obj->fields( [ Dicole::Generictool::Field->new ] );
  $obj->set_search_limit;
  my $search_boxes = $obj->get_search;

=head1 DESCRIPTION

The purpose of this class is to provide a way to handle browsing listings in
I<Dicole Generictool>. Basically this means that you want to limit a listing view
to include a certain ammount of objects and the remaining are splitted to
several pages, which you may browse with the browsing navigation.

Search information is stored in the session of the user to make sure that
the system I<remembers> the state of the search if the user comes back later.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 SessionStore( [CLASS] )

Sets/gets the SessionStore class. You may use this to change the object
in use which is responsible to store/retrieve search information from the
session cache.

=head2 fields( [ARRAYREF] )

Sets/gets the list of fields in the class attributes. Accepts an anonymous
array of I<Field> objects as a parameter. The I<Field> objects are used
to get the name of the searchable columns based on field id's.

=cut

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::Search->mk_accessors(
    qw( SessionStore fields )
);

=pod

=head1 METHODS

=head2 new( { action => ARRAYREF } )

Returns a new I<Search object>. I<action> parameter is required.
Optionally accepts initial class attributes as parameter passed
in the anonymous hash.

=cut

sub new {
    my ( $class, $args ) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init( $args );
    return $self;
}

sub _init {
    my ( $self, $args ) = @_;

    if ( ref( $args ) eq 'HASH' ) {
        foreach my $key ( keys %{ $args } ) {
            $self->{$key} = $args->{$key};
        }
    }
    $self->SessionStore( Dicole::Generictool::SessionStore->new(
        { action => $args->{action} }
    ) );
}

=pod

=head2 search_type( [STRING] )

Sets/gets the type of the search. Search types are described below:

=over 4

=item B<per_column>

User is able to search each of the searchable columns simultaneously.
All the search fields with descriptions are made visible. All column
searches are stored simultaneously.

=item B<select_column>

User is able to search one searchable column, which is selected
from a drop-down. If the column to search is changed, the new
column search clears the old column searches.

=back

=cut

sub search_type {
    my ( $self, $search_type ) = @_;
    if ( defined $search_type ) {
        $self->{search_type} = $search_type;
    }
    unless ( $self->{search_type} ) {
        $self->{search_type} = 'select_column';
    }
    return $self->{search_type};
}

=pod

=head2 searchable( [ARRAYREF] )

Sets/gets the searchable columns of the class.

=cut

sub searchable {
    my ( $self, $searchable ) = @_;
    if ( ref( $searchable ) eq 'ARRAY' ) {
        $self->{searchable} = $searchable;
    }
    unless ( ref( $self->{searchable} ) eq 'ARRAY' ) {
        $self->{searchable} = [];
    }
    return $self->{searchable};
}

=pod

=head2 del_searchable( ARRAYREF )

Deletes a column from the list of searchable columns in the class. Accepts
an anonymous array of columns to delete from the list of searchable columns.

=cut

sub del_searchable {
    my ( $self, $fields ) = @_;
    $self->searchable( Dicole::Utility->del_from_list(
        $self->searchable, $fields
    ) );
}

=pod

=head2 set_search_limit( [HASHREF] )

If I<limited_search> Apache parameter is true, the search values are
read from the Apache parameters. Search types:

=over 4

=item B<per_column>

In this type the search parameters are read from parameters
I<limit_search_*>, where * is the search column in question.

=item B<select_column>

In this type the search parameters and column to search are read from the
parameters I<custom_search_column> and I<custom_search_value>.

=back

If apache parameter I<clear_search> is true, the search values
are cleared from the session cache and class attributes.

Accepts optional anonymous hash of column names and values if
you want to override the columns to search.

=cut

# Updates user preferred search limiting information in the session cache
sub set_search_limit {

    my ( $self, $search_limit ) = @_;

    # We update the search limits only if the limited_search button was pressed
    if ( CTX->request->param( 'limited_search' ) ) {

        if ( $self->search_type eq 'per_column' ) {

            foreach my $search_column ( @{ $self->searchable } ) {
                my $search_value = CTX->request->param(
                    'limit_search_' . $search_column
                );
                $self->_store_search_limit( $search_value, $search_column );
            }
        }
        elsif ( $self->search_type eq 'select_column' ) {
            my $search_value = CTX->request->param( 'custom_search_value' );
            my $search_column = CTX->request->param( 'custom_search_column' );
            # Clear search before setting it again
            $self->SessionStore->by_key( 'search_limit', {} );
            $self->_store_search_limit( $search_value, $search_column );
        }

    }
    # if clear_search button was pressed, remove all search parameters
    elsif ( CTX->request->param( 'clear_search' ) ) {
        $self->SessionStore->by_key( 'search_limit', {} );
    }
    elsif ( $search_limit && ref( $search_limit ) eq 'HASH' ) {
        foreach my $key ( keys %{ $search_limit } ) {
            $self->_store_search_limit( $search_limit->{$key}, $key );
        }
    }
}

=pod

=head2 get_search_limit( [STRING] )

Gets the current search limit information from the session cache.
Returns an anonymous hash. Optionally accepts the column name
of which value to retrieve.

=cut

sub get_search_limit {
    my ( $self, $search_column ) = @_;
    my $session_key = $self->SessionStore->by_key( 'search_limit' );
    if ( $search_column ) {
        return $session_key->{$search_column}
            if exists $session_key->{$search_column};
    } else {
        return $session_key;
    }
}

=pod

=head2 get_cache_key()

Returns a cache key for unique identification of the search.

=cut

sub get_cache_key {
    my ( $self ) = @_;
    my @return;
    foreach my $key ( sort keys %{ $self->get_search_limit } ) {
        push @return, $key . '=' . $self->get_search_limit( $key );
    }
    return join ",", @return;
}

=pod

=head2 get_search_query()

Returns a valid SQL query B<WHERE> based on class attributes.

=cut

sub get_search_query {
    my ( $self ) = @_;

    my $search_query = undef;
    foreach my $search_column ( @{ $self->searchable } ) {
        if ( $self->get_search_limit( $search_column ) ) {
            $search_query .= ' AND ' if $search_query;
            $search_query .= $self->get_field( $search_column )->object_field
                . " LIKE '"
                .$self->get_search_limit( $search_column )
                ."'";
        }
    }
    return $search_query;
}

=pod

=head2 get_field( SCALAR )

Goes through the I<fields> attribute and searches for a field with the
id passed as a parameter. Returns the field class upon success, undef
upon failure.

=cut

sub get_field {
    my ( $self, $id ) = @_;
    foreach my $field ( @{ $self->fields } ) {
        return $field if $field->id eq $id;
    }
    return undef;
}

=pod

=head2 get_search()

Checks search type and returns appropriate search input fields based
on class attributes. Return value is a
L<Dicole::Content::Horizontal|Dicole::Content::Horizontal> object.

=cut

# Returns search inputs with titles.
sub get_search {

    my ( $self ) = @_;

    my $navigation = Dicole::Content::Horizontal->new;

    my $search_fields = [];

    foreach my $field ( @{ $self->searchable } ) {
        push @{ $search_fields }, {
            search_title => $self->get_field( $field )->desc,
            search_field => $field
        };
    }

    my $lh = CTX->request->language_handle;

    # Add the page text
    $navigation->add_content( Dicole::Content::Text->new(
        content => $lh->maketext( "Search:" )
    ) );

    my $search_submit = Dicole::Content::Button->new(
        name      => 'limited_search',
        value     => $lh->maketext( 'Search' ),
    );

    my $clear_search = Dicole::Content::Button->new(
        name      => 'clear_search',
        value     => $lh->maketext( 'Clear search' ),
    );

    if ( $self->search_type eq 'per_column' ) {

        # true if there is search active
        my $search_enabled = undef;

        # Go through the arguments
        foreach my $field ( @{ $search_fields } ) {

            my $searchexp = $self->_sql_to_search(
                $self->get_search_limit( $field->{search_field} )
            );
            $search_enabled++ if $searchexp;

            $navigation->add_content( Dicole::Content::Text->new(
                content => $field->{search_title}
            ) );
            my $search_field = Dicole::Content::Formelement->new(
                attributes => {
                    type      => 'text',
                    maxlength => '32',
                    size      => '12'
                }
            );
            $search_field->set_name( 'limit_search_' . $field->{search_field} );
            $search_field->set_value( $searchexp );
            $search_field->modifyable( 1 );
            $navigation->add_content( $search_field );
        }

        # Add submit button
        $navigation->add_content( $search_submit );

        # Add clear search button if search was enabled
        if ( $search_enabled ) {
            $navigation->add_content( $clear_search );
        }
    }
    elsif ( $self->search_type eq 'select_column' ) {

        my $search_column = undef;
        my $searchexp = undef;
        my $search_keys = $self->SessionStore->by_key( 'search_limit' );
        foreach my $key ( keys %{ $search_keys } ) {
            $search_column = $key;
            $searchexp = $self->_sql_to_search(
                $search_keys->{$key}
            );
            last if $searchexp;
        }

        my $custom_select = Dicole::Content::Formelement::Dropdown->new;
        $custom_select->set_name( 'custom_search_column' );
        $custom_select->modifyable( 1 );
        foreach my $field ( @{ $search_fields } ) {
            $custom_select->add_options( [ {
                attributes => { value => $field->{search_field} },
                content => $field->{search_title}
            } ] );
        }
        $custom_select->set_selected( $search_column ) if $search_column;
        $navigation->add_content( $custom_select );

        my $search_field = Dicole::Content::Formelement->new(
            attributes => {
                type      => 'text',
                maxlength => '32',
                size      => '12'
            }
        );
        $search_field->set_name( 'custom_search_value' );
        $search_field->set_value( $searchexp );
        $search_field->modifyable( 1 );
        $navigation->add_content( $search_field );

        # Add submit search button
        $navigation->add_content( $search_submit );

        # Add clear search button if search was enabled
        if ( $searchexp ) {
            $navigation->add_content( $clear_search );
        }
    }

    return $navigation;
}

=pod

=head1 PRIVATE METHODS

=head2 _store_search_limit( STRING, STRING )

Stores search information in the session cache. Accepts search value
as the first parameter and column to search as the second parameter.

=cut

sub _store_search_limit {
    my ( $self, $search_value, $search_column ) = @_;

    if ( $search_value ne '' ) {
        $search_value = $self->_search_to_sql( $search_value );
        $self->SessionStore->by_key(
            'search_limit', $search_value, $search_column
        );
    }
    else {
        # Delete key from hash if it exists and is empty (not to be limited)
        $self->SessionStore->del_by_key( 'search_limit', $search_column );
    }
}

=pod

=head2 _sql_to_search( STRING )

Converts SQL query B<LIKE> to a more logical form for display purposes.

Converts * to % and ? to _.

=cut

sub _sql_to_search {
    # Translate SQL wildcards back to more conventional wildcards
    my ( $self, $searchexp ) = @_;
    $searchexp =~ s/^\%([^_%]*)\%$/$1/;
    $searchexp =~ tr/%/*/;
    $searchexp =~ tr/_/?/;
    return $searchexp;
}

=pod

=head2 _search_to_sql( STRING )

Converts user input to a valid SQL query B<LIKE>.

Converts % to * and _ to ?.

=cut

sub _search_to_sql {
    my ( $self, $searchexp ) = @_;
    if ( $searchexp =~ /\*|\?/ ) {
        $searchexp =~ tr/*/%/; # * is replaced with %
        $searchexp =~ tr/?/_/; # ? is replaced with _
    }
    elsif ( $searchexp ) {
        $searchexp = '%' . $searchexp . '%';
    }
    return $searchexp;
}

=pod

=head1 SEE ALSO

L<Dicole::Content::Horizontal|Dicole::Content::Horizontal>,
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

