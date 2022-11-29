package Dicole::Tree::Creator;

use strict;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Superclass for creating trees from ramdomly ordered set of elements


=head1 SYNOPSIS

This is a superclass.

See for example L<Dicole::Tree::Creator::Hash|Dicole::Tree::Creator::Hash>.

=head1 DESCRIPTION

This is a superclass for creating tree structures.
Inheriting classes implement functions for getting element ids & parent ids and
setting element's parent and sub element properties.

=head1 INHERITS

None.

=head1 METHODS

=head2 new( )

Initializes and creates a new I<Dicole::Tree::Creator> object.  Accepts a
hash of parameters for class attribute initialization.

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );

    $self->{_order_key} = $args{order_key};
    $self->{_index} = {};
    $self->{_root_elements} = [];
    
    return $self;
} 

=pod

=head2 add_element( ELEMENT )

Adds an element in the tree. If the element doesn't have the parent_id_key
attribute specified, it will be added as a root element.

Sets parent_key-attribute while adding an element in the tree.

=cut

sub add_element {
    my ( $self, $element ) = @_;

    my $id = $self->_get_id($element);

    # no duplicate element ID's
    return 0 if $self->_has_element( $id );

    $self->_add_element_to_index($element);

    my $parent_id = $self->_get_parent_id($element);

    if ( !$parent_id ) {
    
        $self->_add_root_element($element);
    }
    else {
        
        $self->_add_normal_element($element);
    }

    return 1;
}


=pod

=head2 add_element_array( ARRAY_REF )

Adds all array's elements to the tree. If the the _get_parent_id call for the
element returns false, the element will be added as a root element.

=cut

sub add_element_array {
    my ( $self, $arrayref ) = @_;

    foreach (@$arrayref) {

        $self->add_element($_);
    }
}

=pod

=head2 remove_element( ELEMENT )

Removes an element from the tree.

Sets parent_key-attribute while adding an element in the tree.

=cut

sub remove_element {
    my ( $self, $element ) = @_;

    my $id = $self->_get_id($element);

    # no duplicate element ID's
    return 0 if !$self->_has_element( $id );

    my $parent_id = $self->_get_parent_id($element);

    if ( !$parent_id ) {
    
        $self->_remove_root_element($element);
    }
    else {
        
        $self->_remove_normal_element($element);
    }

    $self->_remove_element_from_index($element);

    return 1;
}

=pod

=head2 create( )

Forms a tree from the added elements.
Elements' parent is updated and sub elements added.

Returns a reference to an array containing root elements.

=cut

sub create {
    my ( $self ) = @_;

    return if !$self->{_root_elements};

    $self->_rec_create( undef, $self->{_root_elements}, 0 );
    
    return $self->{_root_elements};
}

sub _rec_create {
    my ( $self, $parent, $array, $depth ) = @_;

    next if !$array;

    # Sort "in place"
    if ( $self->{_order_key} ) {
        if ( $self->{_reverse_order} ) {
            @$array = sort {
                $a->{ $self->{_order_key} } <=> $b->{ $self->{_order_key} }
            } @$array;
        }
        else {
            @$array = sort {
                $b->{ $self->{_order_key} } <=> $a->{ $self->{_order_key} }
            } @$array;
        }
    }
    
    foreach my $element ( @$array ) {

        if ($parent) {

            $self->_set_parent( $element, $parent );
            $self->_add_sub_element( $parent, $element );
        }

        my $id = $self->_get_id( $element );
        $self->_set_depth( $element, $depth );
        $self->{_index}{$id}{depth} = $depth;

        $self->_rec_create(
            $element, $self->{_index}{$id}{sub_elements}, $depth + 1
        );
    }
}

=pod

=head2 element_array( )

Returns the elements of the tree in order of regular listing.

Calls create() first and use the index.

=cut

sub ordered_element_array {
    my ( $self ) = @_;
    
    my $elements = $self->create;
    
    return $self->_ordered_element_array_rec( $elements );
}

sub _ordered_element_array_rec {
    my ( $self, $elements ) = @_;
    return [] unless $elements;
    
    my @elements = ();
    for my $element ( @$elements ) {
        push @elements, $element;
        my $id = $self->_get_id( $element );
        
        push @elements, @{ $self->_ordered_element_array_rec(
            $self->{_index}{$id}{sub_elements}
        ) };
    }
    
    return \@elements;
}
=pod

=head2 get_index( )

Returns the index used to create the tree. The index can be used to find
elements based on their id faster than searching the whole tree.

It is not recommended to modify the index unless you are not planning to use it
anymore to build the tree.

=cut

sub get_index {
    my ( $self ) = @_;

    return $self->{_index};
}

=pod

=head1 FUNCTIONS TO OVERRIDE

=head2 _get_id ( ELEMENT )

Returns: Element's id.

=head2 _get_parent_id ( ELEMENT )

Returns: Element's parent's id.

=head2 _set_parent ( ELEMENT, PARENT_ELEMENT )

Sets element's parent.

=head2 _add_sub_element ( ELEMENT, SUB_ELEMENT )

Adds one element to elements sub elements.

=head2 _set_depth ( ELEMENT, DEPTH )

Sets the elements depth in the tree, 0 being root

=cut

sub _get_id { }

sub _get_parent_id { }

sub _set_parent { }

sub _add_sub_element { }

sub _set_depth { }

=pod

=head1 USED PRIVATE FUNCTIONS

 _add_root_element, _remove_root_element, _add_normal_element,
 _remove_normal_element, _add_element_to_index,
 _remove_element_from_index, _has_element, _rec_create

=cut

#
# adds a root element to _root_elements
#

sub _add_root_element {
    my ( $self, $element ) = @_;

    push @{ $self->{_root_elements} }, $element;
}

#
# removes a root element from _root_elements
#

sub _remove_root_element {
    my ( $self, $element ) = @_;
    
    my $id = $self->_get_id($element);
    my @new = ();
    
    foreach ( @{$self->{_root_elements}} ) {
        push @new, $_ if !$self->_get_id($_) ne $id;
    }

    $self->{_root_elements} = \@new;
}

#
# adds a normal element to parents sub_elements
#

sub _add_normal_element {
    my ( $self, $element ) = @_;

    my $parent_id = $self->_get_parent_id($element);
    
    push @{ $self->{_index}{$parent_id}{sub_elements} }, $element;
}

#
# removes a normal element from parents sub_elements
#

sub _remove_normal_element {
    my ( $self, $element ) = @_;

    my $parent_id = $self->_get_parent_id($element);
    my $id = $self->_get_id($element);
    my @new = ();
    
    foreach ( @{$self->{_index}{$parent_id}{sub_elements}} ) {
       push @new, $_ if $self->_get_id($_) ne $id;
    }
    
    $self->{_index}{$parent_id}{sub_elements} = \@new;
}

#
# adds element to index
#

sub _add_element_to_index {
    my ( $self, $element ) = @_;

    my $id = $self->_get_id($element);
    
    $self->{_index}{$id}{element} = $element;
}

#
# removes element to index
#

sub _remove_element_from_index {
    my ( $self, $element ) = @_;

    my $id = $self->_get_id($element);
    
    $self->{_index}{$id}{element} = undef;
}

#
# Checks if element with specified id exists
#

sub _has_element {
	my ( $self, $id ) = @_;

	return ($self->{_index}{$id}{element}) ? 1 : 0;
}



=pod 

=head1 SEE ALSO

L<Dicole::Tree::Creator::Hash|Dicole::Tree::Creator::Hash>

=head1 AUTHOR

Antti V�h�kotam�ki, E<lt>antti@ionstream.fiE<gt>

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

