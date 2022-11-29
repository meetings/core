package Dicole::Generictool::Data;

# If you want to inherit this class or create your own to be passed
# for Dicole::Generictool make sure your class implements
# atleast all the methods present in this class, because
# Generictool rely on those methods blindly

use strict;

use Log::Log4perl        qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Calcfunc;
use SPOPS::Error;
use Dicole::Utility;

# TODO: this class is used in many places, what if getting it under
# TODO: Dicole::* instead?

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/ );

=pod

=head1 NAME

For fetching SPOPS data in Generictool

=head1 SYNOPSIS

  use Dicole::Generictool::Data;

  my $obj = Dicole::Generictool::Data->new;
  $obj->object( CTX->lookup_object('user') );
  $obj->skip_active;
  $obj->where( ' lang = "en" ' );
  $obj->limit( 0, 10 );
  $obj->data_group;
  $o = $obj->data; # Arrayref of user objects

  # Total number of user objects with the same query
  $r = $obj->total_count;

=head1 DESCRIPTION

The purpose of this class is to provide a way for Generictool to retrieve
data for mapping into I<Generictool Fields>.

If you want to provide your own data handling logic for Generictool,
this is the class to inherit.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 new( [ HASHREF ] )

Returns a new I<Dicole::Generictool::Data object>. Optionally accepts initial
class attributes as parameter passed as an anonymous hash.

=head2 limit( [STRING] )

Sets/gets the parameter for SQL query B<LIMIT>. This allows limiting the
number of objects retrieved.

Example: "5,10"

=head2 order( [STRING] )

Sets/gets the parameter for SQL query B<ORDER BY>. This allows sorting
by wanted database columns.

Example: C<"first_name ASC, last_name DESC">

=head2 flag_active( [BOOLEAN] )

Sets/gets the active records flag. Setting this allows skipping all
records that have I<SPOPS> field (database column) I<active> set to anything
else other than I<1> when fetching groups of objects.

Also when removing objects, doesn't really remove them but sets the I<active>
field as zero for the objects which were marked for removal.

=over 4

=item B<Background information:>

When creating objects that contain pointers to themselves like a network
(or a discussion forum with tree-like presentation of messages), removing
a node from the network that has pointers into itself breaks part of the
network.

This is why it is a good idea to have a column in the database called I<active>,
which specifies if the object is removed, i.e. not displayed, not active or
anything similar. When the object doesn't have any more pointers to itself
in the system, it may be removed completely. So this is a semi-stage of being
removed, like moving something to a trash bin for later complete removal.

=back

=head2 skip_security( [BOOLEAN] )

Sets/gets the skip security bit. Setting this allows skipping I<SPOPS security>
completely, resulting in faster queries but lack of object security.

=head2 object( [CLASS] )

Sets/gets the I<SPOPS object> class in use.

=head2 where( [STRING] )

Sets/gets the parameter for SQL query B<WHERE>. Use this if you want to specify
fine-grained fetching.

=head2 reverse_active( [BOOLEAN] )

Sets/gets the reverse active bit. If this is on, reverses the behaviour
of I<flag_active>. This means that instead of flagging inactive (0), it flags
them as active.

=cut

# We are lazy...Lets generate some basic accessors for our class
__PACKAGE__->mk_accessors(
    qw( where flag_active limit order skip_security object reverse_active )
);

=pod

=head1 METHODS

=head2 total_count( [BOOLEAN] )

Gets the total count of objects retrieved based on the class attributes.

If passed with a parameter that is true, skips the cache of the total
count.

=cut

sub total_count {
    my ( $self, $no_cache ) = @_;

    my $spops_obj = $self->object;

    if ( $no_cache || !$self->{total_count} ) {
        # disabling sorting to make it faster to count total number of objects
        $self->{total_count} = eval {
            $spops_obj->fetch_count(
                $self->_fetch_group_query( no_sorting => 1 )
            )
        };
        my $log = get_logger( LOG_DS );
        $@ && $log->error( $@ );

        $self->{total_count} ||= 0;
    }

    return $self->{total_count};
}

=pod

=head2 data( [CLASS|ARRAYREF] )

Gets/sets the data, which contains one I<SPOPS object> or several
I<SPOPS objects> as an anonymous array.

=cut

sub data {
    my ( $self, $data ) = @_;
    if ( defined $data ) {
        $self->{data} = $data;
    }
    return $self->{data};
}

=pod

=head2 active_field( [STRING] )

Sets/gets the name of the active column. This used with C<flag_active()> to
define if the object should skip inactive records if this is set to false. The
default value is I<active>.

=cut

sub active_field {
    my ( $self, $field ) = @_;
    if ( defined $field ) {
        $self->{active_field} = $field;
    }
    unless ( $self->{active_field} ) {
        $self->{active_field} = 'active';
    }
    return $self->{active_field};
}

=pod

=head2 clear_data_fields( [SCALAR] )

If attribute data contains one object, B<clear_data_fields()> will go through
its' fields and clears the field values.

=cut

sub clear_data_fields {
    my ( $self, $object ) = @_;

    $object = $self->data unless ref $object;

    foreach my $object_field ( @{ $object->field_list } ) {
        $object->{$object_field} = '';
    }
}

=pod

=head2 remove_group( [STRING], [ARRAYREF] )

Removes or disables (if C<flag_active()> is set to true) items selected with
checkboxes (read from Apache parameters).

Optionally accepts prefix that defines what checkboxes we should
be looking for in Apache parameters. If none was provided, defaults to I<sel>.
See documentation of L<Dicole::Generictool|Dicole::Generictool> method
C<get_del()> for more details.

Optionally accepts an anonymous array of object ids or objects as a parameter.
If such a list is defined, it is used to select objects for removal instead of
reading from Apache parameters.

Returns true if objects were successfully removed, undef if removing some
of the objects failed.

=cut

sub remove_group {
    # TODO: Switch parameters around?
    my ( $self, $prefix, $custom_ids ) = @_;

    $prefix ||= 'sel';

    my @return = ( 1, "Selected objects were removed." );

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

    foreach my $id ( @ids ) {
        if ( $self->flag_active ) {
            my $object = $id;
            $object = $self->fetch_object( $id )
                unless ref $id;
            if ( ref $object ) {
                $object->{$self->active_field} = ($self->reverse_active) ? 1:0;
                eval { $object->save( {
                    ( $self->skip_security ) ? ( skip_security => 1 ) : (),
                } ) };
                if ( $@ ) {
                    my $log = get_logger( LOG_DS );
                    $log->error( $@ );

                    @return = ( 0, "Error disabling object number $id." );
                }
            }
        }
        else {
            unless ( $self->remove_object( $id ) ) {
                @return = ( 0, "Error removing object number $id." );
            }
        }
    }
    return @return;
}

=pod

=head2 data_save()

Saves object which is stored in class attribute I<data>. Does proper error
checking.

=cut

sub data_save {
    my ( $self ) = @_;

    eval { $self->data->save( {
        ( $self->skip_security ) ? ( skip_security => 1 ) : (),
    } ) };
    my $log = get_logger( LOG_DS );
    $@ && $log->error( $@ );

    return 1;
}

=pod

=head2 data_new( [BOOLEAN] )

Creates a new I<SPOPS object> and stores it in class attribute data. Returns
contents of data attribute. If passed with a parameter that is true, skips
the cache of the data. This means that the data is not created again if the
data attribute already exists.

=cut

sub data_new {
    my ( $self, $no_cache ) = @_;
    if ( $no_cache || ! ref( $self->{data} ) ) {
        $self->data( $self->object->new( $self->query_params ) );
    }
    return $self->data;
}

=pod

=head2 data_group( [BOOLEAN] )

Fetches a group of objects based on the class attributes and stores
it in the class attribute data as an anonymous array. Returns
contents of the data attribute. If passed with a parameter that is true,
skips the cache of the data. This means that the data is not fetched again
if the data attribute already exists.

=cut

sub data_group {
    my ( $self, $no_cache ) = @_;
    if ( $no_cache || ! ref( $self->{data} ) ne 'ARRAY' ) {
        $self->data( $self->fetch_group );
    }
    return $self->data;
}

=pod

=head2 data_single( SCALAR, [BOOLEAN] )

Fetches one object based on the class attributes and stores
it in the class attribute data. Returns contents of the data attribute.
First parameter defines the object id to retrieve. Second parameter
specifies if we should skip the cache of the data. This means that the
data is not fetched again if the data attribute already exists.

=cut

sub data_single {
    my ( $self, $obj_id, $no_cache ) = @_;
    $obj_id ||= 0;
    if ( $no_cache || ! ref( $self->{data} ) ) {
        $self->data( $self->fetch_object( $obj_id ) );
    }
    return $self->data;
}

=pod

=head2 query_params( [HASHREF] )

Sets the query parameters passed to SPOPS B<fetch()>, B<new()> or
B<fetch_group()>. If Data class itself sets some parameters, these parameters
are merged with the existing parameters provided by the class.

=cut

sub query_params {
    my ( $self, $query_params ) = @_;
    unless ( ref( $self->{query_params} ) eq 'HASH' ) {
        $self->{query_params} = {};
    }
    if ( defined $query_params ) {
        if ( ref( $query_params ) eq 'HASH' ) {
            $self->{query_params} = $query_params;
        }
    }
    return $self->{query_params};
}

=pod

=head2 selected_where( list => HASHREF, [ invert => BOOLEAN ] )

Takes where attribute and extends it with where queries constructed
based on I<list> parameter and I<invert> parameter. Parameter I<list> contains
key / value pairs, which are the same as database column / column value
pairs. The value is an anonymous array of query parameters.

A new where query is constructed based on that, which will return
everything the I<list> parameters specify. If I<invert> parameter
is true, the resulting query will return everything _but_ the I<list>
parameters specify.

Examples:

Returns peter and john:

  $class->selected_where( list => { user_name => [ 'peter', 'john' ] } );

Returns everything _but_ peter:

  $class->( list => { user_name => [ 'peter' ] }, invert => 1 );

=cut

# Creates a valid SQL where clause for a list of elements.
# If invert is active, the query will return everything _but_ the
# list of elements.
sub selected_where {

    my $self = shift;

    my $args = {
        list      => {},
        invert    => '',
        where         => $self->where,
        @_
    };

    my (@where_list);
    foreach my $key ( keys %{$args->{list}} ) {
        next unless @{$args->{list}->{$key}};

        my $invert = undef;

        # We put "" around the value if it's not an integer number
        map {$_ = '"' . $_ . '"' unless $_ =~ /^[+-]?\d+$/} @{$args->{list}->{$key}};

        my $where = join ',', @{$args->{list}->{$key}};
        $invert = ' NOT' if $args->{invert};
        push @where_list, $key . $invert . " IN ($where)";
    }
    $args->{where} .= ' AND ' if $args->{where} && @where_list;
    $args->{where} .= join ' AND ', @where_list;

    $self->where( $args->{where} );

}
=pod

=head2 add_where()

Joins the specified clause to the existing where with an AND. If there is no
existing where, the where is set to the new clause.

Returns the new where.

=cut

sub add_where {
    my ($self, $new_where) = @_;

    my $where = $self->where;
    return $self->where( ($where) ? $where.' AND '.$new_where : $new_where );
}

=pod

=head2 fetch_group()

Fetches I<SPOPS objects> based on class attributes. Returns an anonymous
array of objects.

=cut

# Fetch data for list views (list, del...)
sub fetch_group {

    my $self = shift;

    my $objects = [];

    $objects = eval { $self->object->fetch_group( $self->_fetch_group_query ) };

    my $log = get_logger( LOG_DS );
    $@ && $log->error( $@ );

    # If limiting was not enabled, save number of objects as
    # total count
    $self->{total_count} = scalar @{ $objects } unless $self->limit;

    return $objects;
}

=pod

=head2 fetch_object( [SCALAR] )

Fetches SPOPS object based on class attributes. Accepts I<object id> as a
parameter.

Upon success, returns resulting object, otherwise returns undef.

=cut

sub fetch_object {

    my ( $self, $obj_id ) = @_;

    my $object = eval { $self->object->fetch( $obj_id, $self->_fetch_single_query ) };

    if ( $@ ) {
        my $log = get_logger( LOG_DS );
        $log->error( $@ );

        return undef;
    }

    return $object;
}

=pod

=head2 remove_object( [SCALAR|OBJECT] )

Removes a I<SPOPS> object. Accepts I<object id> or object itself as a
parameter. If the object id is not provided, the object in accessor
I<data()> will be removed.

Returns true if method succeeds, undef if not.

=cut

sub remove_object {

    my ( $self, $obj_id ) = @_;

    my $object = $self->data;
    if ( $obj_id ) {
        $object = $obj_id;
        $object = $self->fetch_object( $obj_id, $self->_fetch_single_query )
            unless ref $obj_id;
    }

    eval { $object->remove( {
        ( $self->skip_security ) ? ( skip_security => 1 ) : (),
    } ) };
    if ( $@ ) {
        my $log = get_logger( LOG_DS );
        $log->error( $@ );

        return undef;
    }
    return 1;
}

=pod

=head1 PRIVATE METHODS

=head2 _fetch_group_query( [ no_sorting => BOOLEAN ] )

Creates the fetch query for SPOPS B<fetch_group()> based on class attributes.

Accepts optional parameter "no_sorting", if true, skips sorting of the
data. Useful when counting number of objects.

Returns the resulting fetch query.

=cut

sub _fetch_group_query {
    my ($self, %options) = @_;

    my $where_query = $self->where;

    my %query_params = %{ $self->query_params };

    # Merge sorting from query_params to existing sorting order
    my $sorting = undef;
    unless ( $options{no_sorting} ) {
        $sorting = $self->order;
        if ( $query_params{order} ) {
            $sorting .= ', ' if $sorting;
            $sorting .= $query_params{order};
            delete $query_params{order};
            # Make sure the first and last sorting values are not
            # equal. Prefer first sorting order
            if ( $sorting =~ /, / ) {
                $sorting =~ /^(\S+)(\s*.*?), (\S+)\s*.*$/;
                $sorting = $1.$2 if $1 eq $3;
            }
        }
        # Obey SPOPS field map
        if ( exists $self->object->CONFIG->{field_map} ) {
            while ( my ( $key, $value ) = each %{ $self->object->CONFIG->{field_map} } ) {
              $sorting =~ s/\b$key\b/$value/gi;
            }
        }
    }

    # We modify the WHERE method if inactive objects should be skipped
    # and the active column exists in our object
    if ( $self->flag_active ) {
          $where_query .= ' AND ' if $where_query;
          my $reverse = ($self->reverse_active) ? '!=' : '=';
          $where_query .= $self->active_field . $reverse . 1;
    }

    # Merge where query from query_params to existing where query
    if ( $query_params{where} ) {
        $where_query .= ' AND ' if $where_query;
        $where_query .= $query_params{where};
        delete $query_params{where};
    }

    # obey SPOPS field map
    if ( exists $self->object->CONFIG->{field_map} ) {
        while ( my ( $key, $value ) = each %{ $self->object->CONFIG->{field_map} } ) {
            $where_query =~ s/\b$key\b/$value/gi;
        }
    }

    $self->{_fetch_query} = {
        where => $where_query,
        limit => $self->limit,
        ( $self->skip_security )
            ? ( skip_security => 1 )
            : (),
        ( $sorting )
            ? ( order => $sorting )
            : (),
    };
    # We merge used defined fetch parameters in our parameters if
    # the user has defined such
    if ( scalar keys %query_params ) {
        my %merged = (
             %{ $self->{_fetch_query} }, %query_params
        );
        $self->{_fetch_query} = \%merged;
    }
    my $log = get_logger( LOG_DS );
    $log->is_debug && $log->debug( 'Fetch group with: ' .
    Data::Dumper::Dumper( $self->{_fetch_query} ) );
    return $self->{_fetch_query};
}

=pod

=head2 _fetch_single_query()

Creates the fetch query for SPOPS B<fetch(>) based on class attributes.
Returns the resulting fetch query.

=cut

sub _fetch_single_query {
    my ( $self ) = @_;

    $self->{_fetch_query} = {
        ( $self->skip_security ) ? ( skip_security => 1 ) : (),
    };

    # We merge used defined spops parameters in our parameters if
    # the user has defined such
    if ( scalar keys %{ $self->query_params } ) {
        my %merged = (
            %{ $self->{_fetch_query} }, %{ $self->query_params }
        );
        $self->{_fetch_query} = \%merged;
    }
    return $self->{_fetch_query};
}

=pod

=head1 SEE ALSO

L<SPOPS|SPOPS>, L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHORS

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

