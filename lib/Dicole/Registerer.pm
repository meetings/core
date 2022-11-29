package Dicole::Registerer;

use strict;

use OpenInteract2::Context   qw( CTX );
use Text::CSV_XS;

=pod

=head1 NAME

Takes care of registering tools

=head1 DESCRIPTION

This class has a register() method, which takes care
of registering tools.

=head1 METHODS

=head2 register( HASH )

Registers given items as given objects.

Parameters in hash:

 object_name
 items
 defaults
 id_fields
 order_fields
 csv_fields
 package

Returns an arrayref of created items' ids.

=cut

sub register {

    my ($self, %p) = @_;

    my $p = {
        object_name => undef,
        items => [],
        defaults => {},
        id_fields => [],
        order_fields => {},
        csv_fields => {},
        package => undef,
        %p
    };

    my $itemclass = CTX->lookup_object( $p->{object_name} );

    return if !$itemclass;

    # Set package right for every item. This must be done before
    # any item's ids are generated.
    $_->{package} = $p->{package} for values %{$p->{items}};

    $p->{csv_fields} ||= {};
    $p->{order_fields} ||= {};

    my $processed_items = {};
    my $created_ids = [];
    my $updated_ids = [];
    my $deleted_ids = [];
    my $skipped_ids = [];

    # Create and update registered items
    foreach my $nro (sort { $a <=> $b } keys %{ $p->{items} }) {

        # Gets checked if the object is created
        my $created = 0;

        # Construct unique id by joining id fields
        my @id_list = map { $p->{items}->{$nro}->{$_} } @{ $p->{id_fields} };
        my $itemid = join '::', @id_list;

        # Don't delete this item in the end
        $processed_items->{ $itemid } = 1;

        # check if old tool item exists with this toolid
        # if doesn't create new tool item and add it
        my $where = join( ' = ? AND ', @{ $p->{id_fields} } ) . ' = ?';

        my $item = $itemclass->fetch_group(
            { where => $where, value => [ @id_list ] }
        )->[0];

        if ( !$item ) {
            $self->_add_status( {
                is_ok => 'yes',
                action => $self->get_name,
                message => "Creating: $p->{object_name} $itemid..",
            } );
            $item = $itemclass->new;

            $created = 1;

            $processed_items->{ $itemid } = 'created';
        }
        elsif ( $item->{modified} ) {
            $self->_add_status( {
                is_ok => 'yes',
                action => $self->get_name,
                message => "User has modified: $p->{object_name} $itemid..",
            } );

            push @$skipped_ids, $item->id;

            $processed_items->{ $itemid } = 'exists';

            next;
        }
        else {
            $self->_add_status( {
                is_ok => 'yes',
                action => $self->get_name,
                message => "Updated: $p->{object_name} $itemid..",
            } );

            push @$updated_ids, $item->id;

            $processed_items->{ $itemid } = 'updated';
        }

        $item->{$_} = $p->{defaults}{$_} foreach ( keys %{ $p->{defaults} } );

        foreach my $key ( keys %{ $p->{items}{$nro} } ) {

            $item->{$key} = $p->{items}{$nro}{$key};

            # Encode if this was a cvs field
            if ( $p->{csv_fields}{$key} ) {
                my $binary = ( $p->{csv_fields}{$key} =~ /binary/ ) ? 1 : 0;
                my $csv = Text::CSV_XS->new( { binary => $binary } );
                my @fields =  ( ref $item->{$key} eq 'HASH' ) ?
                        (
                            %{ $item->{$key} }
                        ) :
                        (
                            ( ref $item->{$key} eq 'ARRAY' ) ?
                                @{ $item->{$key} } :
                                $item->{$key}
                        );
                $csv->combine( @fields );
                $item->{$key} = $csv->string;
            }
        }
        $item->save;

        push @$created_ids, $item->id if $created;

        # Update field with object id for orderfields
        my $resave = 0;
        foreach my $key ( keys %{ $p->{order_fields} } ) {
            if ( ! $item->{$key} ) {
                $item->{$key} = $item->id;
                $resave = 1;
            }
        }
        $item->save if $resave;

    }

    # Remove disappeared objects eg objects left in %orig_items
    my $orig_items = $itemclass->fetch_group(
        { where => 'package = ?', value => [ $p->{package} ] }
    ) || [];

    foreach my $item ( @$orig_items ) {

        # Construct unique id by joining id fields
        my @id_list = map { $item->{$_} } @{ $p->{id_fields} };
        my $itemid = join '::', @id_list;

        next if $processed_items->{ $itemid };

        push @$deleted_ids, $item->id;

        $item->remove;

        $self->_add_status( {
            is_ok => 'yes',
            action => $self->get_name,
            message => "Unregistered: $p->{object_name} $itemid..",
        } );

        $processed_items->{ $itemid } = 'removed';
    }
    return ( $created_ids, $updated_ids, $deleted_ids, $skipped_ids );
}

=head1 AUTHOR

Antti V��otam�i E<lt>antti@ionstream.fiE<gt>

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
