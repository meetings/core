package Dicole::Generictool::Sort;

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Hyperlink;
use Dicole::Content::Text;

use Dicole::Generictool::SessionStore;
use Dicole::Generictool;

use Dicole::Utility;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Sorting for Generictool lists

=head1 SYNOPSIS

  use Dicole::Generictool::Sort;

  my $obj = Dicole::Generictool::Sort->new( action => ['Users','list'] );
  $obj->sortable( [ qw(login_name first_name) ] );
  $obj->fields( [ Dicole::Generictool::Field->new ] );
  $obj->set_sort( { column => 'first_name', order => 'DESC' } );
  $obj->get_sort_query();

=head1 DESCRIPTION

The purpose of this class is to provide

The links for sorting are constructed by modifying
the existing URL GET parameters, not by constructing a new URL. This is to ensure
that any other information we might have in our URL parameters gets passed
along as when we submit the page.

Sort information is stored in the session of the user to make sure that
the system I<remembers> the state of the sort if the user comes back later.

The sorting links are constructed by modifying the existing URL GET parameters,
not by constructing a new URL. This is to ensure that any other information
we might have in our URL parameters gets passed along as when we submit the page.

If you want to provide your own sorting logic for I<Generictool>,
this is the class to inherit.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 SessionStore( [CLASS] )

Sets/gets the SessionStore class. You may use this to change the object
in use which is responsible to store/retrieve browsing information from
the session cache.

=head2 fields( [ARRAYREF] )

Sets/gets the list of fields in the class attributes. Accepts an anonymous
array of I<Field> objects as a parameter. The I<Field> objects are used
to get the name of the columns based on field id's.

=head2 view( [STRING] )

Sets/gets the view id. View id is used to retrieve and store the
sorting in an unique place in the session based on the request
action, task and view id.

=cut

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Generictool::Sort->mk_accessors(
        qw( SessionStore fields view )
);

=pod

=head1 METHODS

=head2 new( { action => ARRAYREF } )

Returns a new I<Sort object>. I<action> parameter is required.
Optionally accepts initial class attributes as parameter passed in as an
anonymous hash.

=cut

sub new {
        my ($class, $args) = @_;
        my $self = $class->SUPER::new( $args );
        $self->SessionStore( Dicole::Generictool::SessionStore->new(
                { action => $args->{action} }
        ) );
        return $self;
}

=pod

=head2 sortable( [ARRAYREF] )

Sets/gets the sortable columns of the class.

=cut

sub sortable {
        my ( $self, $sortable ) = @_;
        if ( ref( $sortable ) eq 'ARRAY' ) {
                $self->{sortable} = $sortable;
        }
        unless ( ref( $self->{sortable} ) eq 'ARRAY' ) {
                $self->{sortable} = [];
        }
        return $self->{sortable};
}

=pod

=head2 del_sortable( ARRAYREF )

Deletes a column from the list of sortable columns in the class. Accepts
an anonymous array of columns to delete from the list of sortable columns.

=cut

sub del_sortable {
        my ( $self, $fields ) = @_;
        $self->sortable( Dicole::Utility->del_from_list(
                $self->sortable, $fields
        ) );
}

# Updates user preferred sorting information in the session cache.

=pod

=head2 set_sort( [HASHREF] )

Sets the sorting in the session cache and updates class attributes. If
passed with an anonymous hash with keys I<column> and I<order>, updates
the sorting information. If no parameters were passed, tries to read
apache parameters I<field_sort> and I<sort_order> to obtain the sorting
information.

Example:

  $self->set_sort( { column => 'login_name', order => 'ASC' } );

=cut

sub set_sort {

        my ( $self, $sort ) = @_;

        # Check if the user has requested for different kind of sorting.
        if ( CTX->request->param( 'field_sort' ) ne '' ) {
                my $sort_param = {};
                $sort_param->{column} = CTX->request->param( 'field_sort' );
                $sort_param->{order} = CTX->request->param( 'sort_order' );
                $self->_store_sort( $sort_param );
        }
        elsif ( ref( $sort ) eq 'HASH' && scalar keys %{ $sort } ) {
                $self->_store_sort( $sort );
        }
}

=pod

=head2 get_sort()

Returns the current sorting information as an anonymous hash. If
no sorting information was found, returns the default instead, which
is the first column of sortable columns sorted as ascending.

=cut

sub get_sort {
        my ( $self ) = @_;

        $self->_set_default_sort;
        return $self->{_sort};
}

=pod

=head2 default_sort( [HASHREF] )

Sets/gets the default sorting information in the class attributes.

=cut

sub default_sort {
        my ( $self, $default_sort ) = @_;

        if ( ref $default_sort eq 'HASH' ) {
                $self->{_default_sort} = $default_sort;
        }
        return $self->{_default_sort};
}

=pod

=head2 get_sort_query()

Returns valid parameters for SQL query I<SORT> based on class attributes.

=cut

sub get_sort_query {
        my ( $self ) = @_;

        $self->_set_default_sort;
        my $sort = $self->SessionStore->by_key( $self->view, undef, 'sort' );
        return undef unless $sort->{column};
        return $self->get_field( $sort->{column} )->object_field
            . ' ' . $sort->{order};
}

=pod

=head2 get_cache_key()

Returns a valid cache key for unique identification of the sort.

=cut

sub get_cache_key {
        my ( $self ) = @_;
        return $self->get_sort_query;
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
        die sprintf( "Field with id [%s] not found", $id );
}

=pod

=head2 get_sort_columns( ARRAYREF )

Gets an arrayref (columns) of hashrefs (sort contents),
similar to this:

  [
        {
                name => "Column name",
                content => Dicole::Content::Text,
        },
        {
                name => "Column name",
                content => Dicole::Content::HyperLink,
        }
  ]

Where I<name> has the I<desc field> from the corresponding I<Field object>
mapped as the name of the column and where I<content> is the object
that displays the contents of the sort column. If it is sortable, a I<HyperLink>
is used with a link like C<?sort_order=ASC&field_sort=first_name> that sorts
the column.

Accepts the field id's as an anonymous array for which the columns
should be returned.

=cut

sub get_sort_columns {
        my ( $self, $fields ) = @_;

        my $list_columns = [];

        foreach my $col ( @{ $fields } ) {

                my $field = $self->get_field( $col );

                my $topic_content = undef;

                my $sort = $self->get_sort;

                # check if we can sort according to this column:
                if( grep { $_ eq $col } @{ $self->sortable } ) {

                        my %query_params = %{ CTX->request->url_query };

                        $query_params{field_sort} = $col;

                        # if we are handling the current sorting column, determine if the
                        # re-clicking should do ascending or descending sort:
                        if ( $sort->{column} eq $col ) {
                                $query_params{sort_order} =
                                        ( $sort->{order} eq 'DESC' )
                                        ? 'ASC' : 'DESC';
                        } else { $query_params{sort_order} = 'ASC'; } # default ascending


                        # Hack: get rid or GET parameters
                        my $url_abs = CTX->request->url_absolute;
                        $url_abs =~ s/\?.*$//;

                        my $uri = OpenInteract2::URL->create(
                            $url_abs,
                            \%query_params
                        );

                        my $hyperlink = Dicole::Content::Hyperlink->new(
                                content => $field->desc,
                                attributes => { href => $uri }
                        );

                        if ( $sort->{column} eq $col ) {
                                $topic_content = Dicole::Content::Horizontal->new;
                                $topic_content->add_content( $hyperlink );
                                $topic_content->add_content( Dicole::Content->new(
                                        template => CTX->server_config->{dicole}{base} . '::sort_arrow',
                                        content => { sort => $sort->{order} },
                                ) );
                        } else { $topic_content = $hyperlink; }
                }
                else {
                        $topic_content = Dicole::Content::Text->new(
                                content => $field->desc
                        );
                }
                push @{ $list_columns }, { name => $col, content => $topic_content };
        }
        return $list_columns;
}

=pod

=head1 PRIVATE METHODS

=head2 _set_default_sort()

Forces sorting information to be a the same as class attribute I<default_sort>.
If no default sorting information exists sets it to the default which is
the first sortable column sorted as ascending.

=cut

sub _set_default_sort {
        my ( $self ) = @_;

        # We need to sort according to some column by default if
        # none was provided, so we select the first sortable column
        # to be sorted by default
        unless ( ref $self->default_sort eq 'HASH' ) {
                my $sort = $self->SessionStore->by_key( 'sort' );
                unless ( ref( $sort ) eq 'HASH' ) {
                        return undef unless $self->sortable->[0];
                        $sort = {
                                column => $self->sortable->[0],
                                order  => 'ASC'
                        };
                }
                $self->default_sort( $sort );
        }
        $self->set_sort( $self->default_sort );
}

=pod

=head2 _store_sort( HASHREF )

Stores the provided sorting information to the session cache of the user.

=cut

sub _store_sort {
        my ( $self, $sort ) = @_;

        $sort->{order} = ( uc $sort->{order} eq 'DESC' )
                ? 'DESC'
                : 'ASC';
        if ( $sort->{column} ) {
                $self->{_sort} = $sort;
                $self->SessionStore->by_key( $self->view, $sort, 'sort' );
        }
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

