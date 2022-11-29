package Dicole::Tree::Creator::Hash;

use strict;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Class for creating a tree using hash keys

=head1 SYNOPSIS

 use Dicole::Tree::Creator::Hash;
 
 my $creator = Dicole::Tree::Creator::Hash->new(

    id_key => 'id',
    parent_id_key => 'parent_id',

    order_key => 'order',
    reverse_order => 1,
    depth_key => 'depth',

    parent_key => 'parent',
    sub_elements_key => 'sub_elements',
    
 );

 $creator->add_element( { id => '1' } ); # 1/0

 $creator->add_element( { id => '2', parent_id => '1' } ); # 1/0
 
 $creator->remove_element( '1' ); # 1/0
 
 $creator->add_element_array( $array_of_elements );

 my $real_tree = $tree->create; # array ref

=head1 DESCRIPTION

This is a generic purpose tree creator for hash elements (and objects which
have their attributes accessible as a hash). You specify the hash keys which
correspond to id, parent id, parent and sub elements. Upon creation the parent
and sub elements are placed into their appropriate keys according to the id and
parent id attributes.

The tree is constructed by inserting elements or series of elements from array
or an iterator in any order. If element specifies a parent id but such element
does not exist when creating the tree, the element is not included in the tree.
Elements that do not specify parent id become root elements.

Creation returns an array of original root elements which refer to their sub
elements in an array placed in the sub_elements_key's attribute.

This is a subclass of L<Dicole::Tree::Creator|Dicole::Tree::Creator> and most of
the the functions are defined there.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

Inherits L<Dicole::Tree::Creator|Dicole::Tree::Creator>, which provides most of
the functionality

=cut

use base qw( Dicole::Tree::Creator Class::Accessor );


=head1 ACCESSORS

=head2 id_key( [STRING] )

Sets/gets the hash key used to get elements id.

Default: 'id'

=head2 parent_id_key( [STRING] )

Sets/gets the hash key used to get elements parent element's id.

Default: 'parent_id'

=head2 parent_key( [STRING] )

Sets/gets the hash key used to set elements parent element.

Default: 'parent'

=head2 sub_elements_key( [STRING] )

Sets/gets the hash key used to set elements sub element array.

Default: 'sub_elements'

=head2 depth_key( [STRING] )

Sets/gets the hash key used to set elements depth in the tree

Default: 'depth'

=cut

Dicole::Tree::Creator::Hash->mk_accessors(
    qw(
        id_key parent_id_key parent_key sub_elements_key depth_key
    )
);

=pod

=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Tree::Creator::Hash> object.  Accepts a
hash of parameters for class attribute initialization.

Parameters:
See I<id_key()>, I<parent_id_key()>,I<(parent_key)>, I<sub_elements_key()>.

=cut

sub new {

    my ($class, %args) = @_;
    my $self = Dicole::Tree::Creator::new( $class, %args );
    $self->_init( %args );
    return $self;
} 

sub _init {

    my ( $self, %args ) = @_;

    $self->id_key( defined $args{id_key}
                   ? $args{id_key}
                   : 'id' );
                   
    $self->parent_id_key( defined $args{parent_id_key}
                          ? $args{parent_id_key}
                          : 'parent_id' );


    $self->parent_key( defined $args{parent_key}
                       ? $args{parent_key}
                       : 'parent' );
                       
    $self->sub_elements_key( defined $args{sub_elements_key}
                             ? $args{sub_elements_key}
                             : 'sub_elements' );
    
    $self->depth_key( defined $args{depth_key}
                             ? $args{depth_key}
                             : 'depth' );
}

#
# overridden functions..
#

sub _get_id {

    my ($self, $element) = @_;

    return $element->{$self->id_key};
}

sub _get_parent_id {

    my ($self, $element) = @_;

    return $element->{$self->parent_id_key};
}

sub _set_parent {

    my ($self, $element, $parent) = @_;

    return if !$self->parent_key;
    
    $element->{$self->parent_key} = $parent;
}

sub _add_sub_element {

    my ($self, $parent, $element) = @_;

    return if !$self->sub_elements_key;

    push @{ $parent->{$self->sub_elements_key} }, $element;
}

sub _set_depth {

    my ($self, $element, $depth) = @_;

    return if !$self->depth_key;
    
    $element->{$self->depth_key} = $depth;
}


=pod 

=head1 SEE ALSO

L<Dicole::Tree::Creator|Dicole::Tree::Creator>,

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

