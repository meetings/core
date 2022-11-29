package Dicole::Utility;

use strict;
use Dicole::Generictool::SessionStore;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Data::Dumper;
use DBI                      qw( :sql_types );
our $VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Helpful routines for Dicole

=head1 SYNOPSIS

  use Dicole::Utility;

=head1 DESCRIPTION

The purpose of this class is to provide a set of routines which are often
useful in Dicole.

Most of these should eventuallty be moved to Dicole::Utils::? namespaces.

=head1 METHODS

=head2 _new_session_store()

Creates and returns a new SessionStore.

=cut

sub _new_session_store {
    my ( $self ) = @_;

    # Check from session cache the cached information of the
    # element in question
    return Dicole::Generictool::SessionStore->new( {
        action => [ CTX->request->action_name, CTX->request->task_name ]
    } );
}

=pod

=head2 save_into_cache( KEY, [SUBKEY], [VALUE] )

Saves data into cache. Key is passed as the first parameter. Optionally accepts
subkey as a parameter, which identifies a location under the specified key. If
value is provided, a new value is added in the cache. If it is not provided, the
value of the cache is deleted if it exists.

=cut

sub save_into_cache {
    my ( $self, $category, $key, $save ) = @_;

    my $session_store = $self->_new_session_store;

    if ( defined $save ) {
        $session_store->by_key( $category, $save, $key );
    }
    else {
        $session_store->del_by_key( $category, $key );
    }
}

=pod

=head2 fetch_from_cache( KEY, [SUBKEY] )

Gets data from the cache. Key is passed as the first parameter. Optionally accepts
subkey as a parameter, which identifies a location under the specified key. The
contents of the cache is returned.

=cut

sub fetch_from_cache {
    my ( $self, $category, $key ) = @_;

    my $session_store = $self->_new_session_store;

    return $session_store->by_key( $category, undef, $key );
}

=pod

=head2 del_from_list( ARRAYREF ARRAYREF )

MOVED to Dicole::Utils::Array->remove_listed

Deletes from the first provided anonymous array items that are present
in second anonymous array. Returns the resulting anonymous array.

=cut

# Deletes items listed in $del_list from $list
sub del_from_list {
    my ( $self, $list, $del_list ) = @_;

    my %seen; # Lookup table
    my $result = []; # Resulting list

    # Build lookup table
    @seen{ @{ $del_list } } = ();

    foreach my $item ( @{ $list } ) {
        push @{ $result }, $item
            unless exists $seen{$item};
    }
    return $result;
}

=pod

=head2 checked_from_apache( STRING , [ HASH ] )

Gets checked checkbox items. Checkboxes apache parameters are usually in the
following form:

  prefix_3

Where I<prefix> is provided as a method parameter. The number in the parameter
is the unique checkbox id.

You can provide a hash of parameters to use instead of the parameters you
get from apache.

The method returns an anonymous hash of checkbox ids and associated values.

=cut

sub checked_from_apache {
    my ( $self, $prefix, $params ) = @_;
    my $ids = {};
    foreach my $param ( grep /^${prefix}_\d+$/, ($params) ?
                                keys %$params : keys %{ CTX->request->param } ) {
        $param =~ /^${prefix}_(\d+)$/;
        $ids->{$1} = ($params) ?
                    $params->{$param} : CTX->request->param( $param );
    }
    return $ids;
}

=pod

=head2 save_return( SCALAR, STRING, [STRING] )

Saves a return message ready for a provided task. This is useful if you want a
task to send a return message to another task where the user is then redirected.
First you save a return message for another task with this method and then you
retrieve the return message again in the correct task with I<check_return()>.

The first parameter is the return code. I<0> is failure, I<1> is success and
I<2> is warning.

The second parameter is the message which to send as a string.

The third parameter is the task which will receive the return message. If this
is not provided, the current task will be used.

=cut

sub save_return {
    my ( $self, $code, $message, $task ) = @_;
    my $action = [ CTX->request->action_name, CTX->request->task_name ];
    $task ||= $action->[1];
    my $store = Dicole::Generictool::SessionStore->new( {
        action => [ $action->[0], $task ],
    } );
    $store->by_key( 'error', [ $code, $message ] );
}

=pod

=head2 check_return()

This method will simply retrieve the return message saved with I<save_return()>.
Returns the return code and message as an anonymous array upon success, undef
upon failure.

Note: the return message will be removed from the session once found. This means
you can't retrieve it multiple times.

=cut

sub check_return {
    my ( $self ) = @_;
    my $return = $self->fetch_from_cache( 'error' );
    if ( ref( $return ) eq 'ARRAY' ) {
        $self->save_into_cache( 'error', undef, '' );
        return $return;
    }
    return undef;
}

=pod

=head2 renew_links_to()

MOVED TO Dicole::Utils::SPOPS

Renews links_to relations according to new information.
New objects are added and old are removed if they are not
found in new objects.

Required params:

object => object which links_to
relation => name of the links_to relation

Optional params:
new => list of new id's or objects
    : default is to remove all.
old => list of old id's or objects
    : default is to fetch all by relation.

=cut

sub renew_links_to {
    my ( $self, %p ) = @_;

    my $p = {
        relation => undef,
        object => undef,
        new => [],
        old => undef,
        %p
    };

    return if !$p->{relation} || !$p->{object};

    my $get = $p->{relation};
    my $add = $p->{relation}.'_add';
    my $remove = $p->{relation}.'_remove';

    $p->{old} ||= eval "\$p->{object}->$get( { skip_security => 1 } )";

    $p->{new} = [] if !ref $p->{new} eq 'ARRAY';
    $p->{old} = [] if !ref $p->{old} eq 'ARRAY';

    @{ $p->{new} } = map { (ref $_) ? $_->id : $_ } @{ $p->{new} };
    @{ $p->{old} } = map { (ref $_) ? $_->id : $_ } @{ $p->{old} };

    my %new_check = map { $_ => 1 } @{ $p->{new} };
    my %old_check = map { $_ => 1 } @{ $p->{old} };

    foreach my $id ( @{ $p->{old} } ) {
        next if !$id || $new_check{$id};
        eval "\$p->{object}->$remove( \$id )";
    }

    foreach my $id ( @{ $p->{new} } ) {
        next if !$id || $old_check{$id};
        eval "\$p->{object}->$add( \$id )";
    }
};

=pod

=head2 renew_links_to_objects()

MOVED TO Dicole::Utils::SPOPS

Renews links_to relations according to new information.
New objects are added and old are removed if they are not
found in new objects.
Links to is updated using the object link objects instead
of the normal links_to interface.

Required params:

object => the linker object
link_object => object representing a link
linker_key => link_objects attribute for linker object id
linked_key => link_objects attribute for linked object id

Optional params:
new => list of new linked objects or their id's (not link_objects)
    : default is to remove all.
old => list of old linked objects or their id's (not link_objects)
    : default is to fetch all by relation.

=cut

sub renew_links_to_objects {
    my ( $self, %p ) = @_;

    my $p = {
        object => undef,
        link_object => undef,
        linker_key => undef,
        linked_key => undef,
        new => undef,
        old => undef,
        %p
    };

    return if !$p->{object}|| !$p->{link_object};
    return if !$p->{linked_key}|| !$p->{linker_key};

    my $object_id = $p->{object}->id;

    $p->{old} ||= $p->{link_object}->fetch_group( {
        where => "$p->{linker_key} = ?",
        value => [ $object_id ]
    } );

    $p->{new} = [] unless ref $p->{new} eq 'ARRAY';
    $p->{old} = [] unless ref $p->{old} eq 'ARRAY';

    @{ $p->{new} } = map { (ref $_) ? $_->id : $_ } @{ $p->{new} };
    @{ $p->{old} } = map { (ref $_) ? $_->id : $_ } @{ $p->{old} };

    my %new_check = map { $_ => 1 } @{ $p->{new} };
    my %old_check = map { $_ => 1 } @{ $p->{old} };

    foreach my $id ( @{ $p->{old} } ) {
        next if !$id || $new_check{$id};

        my $link_objects = $p->{link_object}->fetch_group( {
            where => "$p->{linker_key} = ? AND $p->{linked_key} = ?",
            value => [ $object_id, $id ],
        } );

        next unless ref( $link_objects ) eq 'ARRAY';
        
        for my $link_object ( @$link_objects ) {
            $link_object->remove;
        }
    }

    foreach my $id ( @{ $p->{new} } ) {
        next if !$id || $old_check{$id};

        my $link_object = $p->{link_object}->new;

        $link_object->{ $p->{linker_key} } = $object_id;
        $link_object->{ $p->{linked_key} } = $id;

        $link_object->save;
    }
};

=pod

=head2 make_array( ARRAYREF|STRING )

MOVED to Dicole::Utils::Array->ensure_arrayref

Accepts an arrayref or a string value and returns an arrayref.
This is useful with INI configurations where you can specify multiple
instances of a certain parameter and OI will create an arrayref out
of the multiple instances, but only a string if the parameter was
specified only a single time.

=cut

sub make_array {
    my ( $self, $value ) = @_;
    return ref( $value ) eq 'ARRAY' ? $value : [$value];
}

=pod

=head2 sql_quoted_string_array( ARRAYREF )

MOVED TO Dicole::Utils::SQL::quoted_string_array

Accepts an arrayref and converts it to a value list. For example
  [ qw(a b c) ]
will usually become something like
  ( 'a', 'b', 'c' )
the default database handle will be used to escape values.

=cut

sub sql_quoted_string_array {
    my ( $self, $array ) = @_;
    return undef unless ref $array eq 'ARRAY' && scalar( @$array );
    my $dbh = CTX->datasource( CTX->lookup_system_datasource_name );
    my @escaped = ();
    
    for my $value ( @$array ) {
        push @escaped, $dbh->quote( $value, SQL_VARCHAR );
    }
    
    return '(' . join(',', @escaped) . ')';
}

=pod

=head2 user_belongs_to_group( USER_ID, GROUP_ID )

MOVED TO Dicole::Utils::User

returns wether user is a group member. Should be in the user object but.. well.. ;)

=cut

sub user_belongs_to_group {
    my ( $self, $user_id, $group_id ) = @_;

    my $group_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_group_user',
        where => 'user_id = ? AND groups_id = ?',
        value => [ $user_id, $group_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];
    
    return scalar( @$group_users ) ? 1 : 0;
}

=pod

=head1 SEE ALSO

L<Dicole>

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

