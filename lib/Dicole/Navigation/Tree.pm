package Dicole::Navigation::Tree;

use strict;

use URI::URL;
use Dicole::Content::Tree;
use OpenInteract2::URL;
use Dicole::Utility;
use Dicole::Pathutils;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

For creating a tree navigation

=head1 SYNOPSIS

 use Dicole::Navigation::Tree;
 use Dicole::Navigation::Tree::Element;

 my $tree = Dicole::Navigation::Tree->new(
    root_name  => 'Root directory',
    selectable => 1,
    tree_id    => 'my_files',
 );

 my $element = Dicole::Navigation::Tree::Element->new(
    element_id => 'example',
    content => 'Example directory',
 );

 $tree->add_element( $element );

 $tree->add_element( Dicole::Navigation::Tree::Element->new(
    parent_element => $element,
    element_id => 'testing',
    content => 'Testing1',
 ) );

 my $navigation = $tree->get_tree; # Returns Dicole::Content::Tree object

=head1 DESCRIPTION

This a generic purpose tree navigation class that allows creating different
kind of tree navigations. Features include directory collapsing
(open / close folders), custom icons for tree elements, different icon set
resolutions, descending to previous folders and multiple ways to manipulate the
tree.

This class is designed to be used with L<Dicole::Navigation::Tree::Element>,
although you may create your own as well.

Each Tree object basically has pointers to root branches, i.e. the elements that
do not have parents but have sub elements. The tree is constructed by walking
down the branches, jumping from element object to another.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

Inherits L<Dicole::Navigation>, which provides some generic navigation
methods for our class.

=cut

use base qw( Dicole::Navigation Class::Accessor );

=pod

=head2 tree_id( [STRING] )

Sets/gets the tree id, which is used to identify the tree and elements
that belong to the tree. This is especially required if you want to
distinguish several trees on one page.

=head2 root_elements( [ARRAYREF] )

Sets/gets an array of root elements that belong to the root level. The
parameter is an anonymous array of L<Dicole::Navigation::Tree::Element>
objects.

=head2 used_ids( [ARRAYREF] )

Sets/gets an array of used element ids. This is required to make sure
the tree doesn't contain duplicates of the same element in different
parts of the tree.

=head2 root_name( [STRING] )

Sets/gets the name of the tree root level as it is displayed to the
user.

If this is not set it will be set to the default
value I<Root directory>.

=head2 root_icon( [STRING] )

Sets/gets the name of the icon to use for the root level.

If this is not set it will be set to the default value
I<top.gif>.

This icon resides in the same directory as the icon set itself, like
I</images/theme/default/tree/16x16/top.gif>, so you don't have to
write the exact directory path for the image.

=head2 no_collapsing( [BOOLEAN] )

Sets/gets the directory collapsing bit. Directory collapsing means
that it is possible to close (hide) and open the directories in the
tree. If it is set to off with
this class method the tree will appear in its whole.

The default is off (collapsing is on).

=head2 no_new_root( [BOOLEAN] )

Sets/gets the no new root bit. Selecting a new root means that it is
possible to click a folder icon and get its contents as a new root for
the tree browsing. The functionality is related to directory descending
(see I<descentable()>, which should be set on if a new root (not the
default one which is home) has been selected.

The default is off (selecting new root is possible).

=head2 no_root_select( [BOOLEAN] )

Sets/gets the no root select bit. If this is set on, the root
element will not be displayed as selected.

=head2 no_folder_select( [BOOLEAN] )

Sets/gets the no folder select bit. If this is set on, it will not be
possible to select a folder, it is only possible to select files.

Note: If it is possible to select
a new root (see I<no_new_root()>), it will be possible to select a new
root by clicking the folder name in addition to folder icon.

The default is off (it is possible to select folders).

=head2 folders_initially_open( [BOOLEAN] )

Sets/gets the folders initially open bit. If directory collapsing is
on and this is set to true, all the folders will appear open by
default.

=head2 id_path( [BOOLEAN] )

Sets/gets the id path bit. If this is true the tree element paths will
be constructed out of element ids, not out of element names.

=head2 icon_resolution( [STRING] )

Sets/gets the icon resolution to use. In practice this means it will
set the icon directory where the icons reside. If you set this for
example to I<32x32>, it will look for the icons in directory
I</images/theme/default/tree/32x32/>.

=head2 selectable( [BOOLEAN] )

Sets/gets the selectable bit. This specifies if the tree elements
are selectable with checkboxes or not. Each checkbox will be
named and identified after I<[tree_id]_[element_id]>.

For example, to access the checkbox information of element
id I<1234> in tree I<my-files>, you should write:

  my $checkbox_value = CTX->request->param('my-files_1234');

=head2 current_element( [OBJECT] )

Sets/gets the current L<Dicole::Navigation::Tree::Element> object. The sub
element of the tree checks the virtual path against the element path and sets
this automatically if the element is selected, so you seldom have to set this
yourself.

=head2 base_path( [STRING] )

Sets/gets the base path of the tree. This is the relative directory path which
will be the root for the tree navigation, for example:

  files/root

for:

  /files/tree/files/root

This parameter is designed to be used with the descending feature for setting
the new relative root for the display.

=head2 url_base_path( [STRING] )

Sets/gets the url base path of the tree. This is the relative url path which
will be in front of the tree path. Useful in group tools and similar where
you have to have additional path segments before the tool specific path.
For example:

  1/2/3

for:

  http://myserver.com/files/tree/1/2/3/documents/test.txt

In this case, we assume the tree specific path is I<documents/test.txt>.

=head2 descentable( [BOOLEAN] )

Sets/gets the descentable bit. If this is on a link for descending to previous
folders becomes available and all folder icons are clickable for selecting them
as the new root. The programmer has to implement the functionality for selecting
a new root and descending to previous folders. Both folder icon links and the link
for the descending behaviour will contain the following URI parameter:

  tree_folder_action=select

Through this parameter the programmer may implement the correct behaviour for
descending.

=head2 descent_icon( [STRING] )

Sets/gets the icon for the descending link in top of the tree.

The default is I<descend.gif>.

=head2 descent_name( [STRING] )

Sets/gets the name of the descending link in the top of the tree. The default
is I<Descend to previous folder>.

=head2 folder_icons_always_closed( [BOOLEAN] )

Sets/gets the folder icons always closed bit. When this is on, the icon for
a closed folder is always used, in other words there will be no difference
in the icon if the folder is open or not.

The default is off (there are different icons for open folders used).

=head2 no_icon_base( [BOOLEAN] )

Sets/gets the no icon base bit. If this is false, each icon image is prefixed
with a default icon path, usually under the current theme. Set this to true
if your images are located in an absolute URI instead of a relative URI
relative to the icon base path.

=head2 root_dropdown( [OBJECT] )

Sets/gets the root_dropdown Dicole::Content::Dropdown object. If this is set,
then the root element is provided through a Dicole::Content::Dropdown
object.

=cut

# We are lazy...Lets generate some basic accessors for our class
Dicole::Navigation::Tree->mk_accessors(
    qw(
        tree_id root_elements used_ids root_name root_icon
        no_collapsing folders_initially_open
        icon_resolution selectable current_element id_path
        base_path descent_icon descent_name descentable url_base_path
        no_new_root no_folder_select folder_icons_always_closed
        no_root_select no_icon_base root_dropdown
    )
);

=pod

=head1 METHODS

=head2 new( [HASH] )

Initializes and creates a new I<Dicole::Navigation:Tree> object.  Accepts a hash
of parameters for class attribute initialization.

Parameters:

See I<tree_id()>, I<base_path()>, I<icon_resolution()>, I<root_name()>,
I<root_icon()>, I<descentable()>, I<descent_name()>, I<descent_icon()>,
I<no_folder_select()>, I<selectable()>, I<root_elements()>, I<id_path()>,
I<used_ids()>, I<no_new_root()>, I<icon_files>, I<no_collapsing()>,
I<folder_icons_always_closed>, I<url_base_path> and I<folders_initially_open()>.

It is suggested that I<tree_id> is atleast provided upon creation of an object.

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init( %args );
    return $self;
}

sub _init {
    my ( $self, %args ) = @_;

    # Unique identification of the tree
    $self->tree_id( $args{'tree_id'} );

    # Base path of the tree
    $self->base_path( $args{'base_path'} );

    # Base path of the url
    $self->url_base_path( $args{'url_base_path'} );

    # Set icon resolution: 16x16, 32x32, 64x64
    $self->icon_resolution( $args{'icon_resolution'} );

    # Name of the tree displayed to the user
    $self->root_name( $args{'root_name'}
        ? $args{root_name}
        : 'Root directory'
    );

    # Name of a graphical icon for the tree
    $self->root_icon( $args{'root_icon'} ? $args{'root_icon'} : 'top.gif' );

    # if true, selecting folders is not possible
    $self->no_folder_select( $args{'no_folder_select'} );

    # if true, no items are shown as selected
    $self->no_root_select( $args{'no_root_select'} );

    # if true, selecting a new root is not possible
    $self->no_new_root( $args{'no_new_root'} );

    # Defines if it possible to go to parent directory (..)
    $self->descentable( $args{'descentable'} );

    # Name of the descent element displayed to the user
    $self->descent_name( $args{'descent_name'}
        ? $args{descent_name}
        : 'Descend to previous folder'
    );

    # Set root dropdown
    $self->root_dropdown( $args{'root_dropdown'} );

    # Name of a graphical icon for descent element
    $self->descent_icon( $args{'descent_icon'}
        ? $args{'descent_icon'} : 'descend.gif'
    );

    # Specifies if the tree elements are selectable or not
    $self->selectable( $args{'selectable'} );

    # list of root Tree::Element objects
    $self->root_elements( $args{'root_elements'}
        ? $args{'root_elements'} : []
    );

    # If this is true, the path will be constructed of element ids instead of
    # element names
    $self->id_path( $args{'id_path'} );

    # List of already used id's
    $self->used_ids( $args{'used_ids'} ? $args{'used_ids'} : [] );

    # if true, there won't be plus/minus signs drawn
    $self->no_collapsing( $args{'no_collapsing'} );

    # if true, the whole tree is shown initially
    $self->folders_initially_open( $args{'folders_initially_open'} );

    # if true, a closed folder icon will be used always for folders
    $self->folder_icons_always_closed( $args{'folder_icons_always_closed'} );

    # element type as hash key. File names are stored in this hash.
    # Additional images: lines connecting the symbols
    my $icon_files = {
        '' => '',
        document        => 'document.gif',
        tree_empty          => 'tree_empty.png',
        tree_tcross         => 'tree_tcross.png',
        tree_vertical       => 'tree_vertical.png',
        tree_corner         => 'tree_corner.png',
        tree_plus           => 'tree_plus.png',
        tree_minus          => 'tree_minus.png',
        tree_plus_corner    => 'tree_plus_corner.png',
        tree_minus_corner       => 'tree_minus_corner.png',
        tree_horizontal     => 'tree_horizontal.png',
        folder_open         => 'tree_folder_open.gif',
        folder_closed       => 'tree_folder_closed.gif',
        folder_protected    => 'tree_folder_protected.gif',
    };
    $self->icon_files( $icon_files );
    $self->icon_files( $args{'icon_files'} );

}

=pod

=head2 icon_files( [HASH] )

Sets/gets the used icon files as an anonymous hash. The hash key
is the element type while the hash value is the relative url to the icon.

We have a list of certain default icons specified:

  document      = document.gif
  tree_empty    = tree_empty.png
  tree_tcross       = tree_tcross.png
  tree_vertical     = tree_vertical.png
  tree_corner       = tree_corner.png
  tree_plus     = tree_plus.png
  tree_minus    = tree_minus.png
  tree_plus_corner  = tree_plus_corner.png
  tree_minus_corner = tree_minus_corner.png
  tree_horizontal   = tree_horizontal.png
  folder_open       = tree_folder_open.gif
  folder_closed     = tree_folder_closed.gif
  folder_protected  = tree_folder_protected.gif

If new icons are passed to this method, the new icons are merged to the
existing ones, overriding any duplicates.

=cut

sub icon_files {
    my ( $self, $icon_files ) = @_;
    unless ( ref( $self->{icon_files} ) eq 'HASH' ) {
    $self->{icon_files} = {};
    }
    if ( ref( $icon_files ) eq 'HASH' ) {
    my %joined = ( %{ $self->{icon_files} }, %{ $icon_files } );
        $self->{icon_files} = \%joined;
    }
    return $self->{icon_files};
}

=pod

=head2 root_href( [STRING] )

Sets/gets the url link to use for the root level element.

If this is not set it will be overridden with the default value by using the
current URI of the current action/task and possible return value of
I<url_base_path()>.

=cut

sub root_href {
    my ( $self, $href ) = @_;

    if ( defined $href ) {
        $self->{root_href} = $href;
    }
    unless ( defined $self->{root_href} ) {
        my $uri = URI::URL->new;
        $uri->query( CTX->request->url_query );
        my %query_params = $uri->query_form;
        $self->{root_href} = OpenInteract2::URL->create( '/'
        . join( '/', grep { defined $_ } (
                CTX->request->action_name,
                CTX->request->task_name,
                $self->url_base_path,
        $self->base_path
            ) ),
            \%query_params
        );
    }
    return $self->{root_href};
}

=pod

=head2 descent_href( [STRING] )

Sets/gets the descending URL to use. This is the link placed in the top of the
tree.

If this is not set it will be overridden with the default value
by using the current URI of the current action/task and possible return value of
I<url_base_path> and I<base_path()>. The parameter I<tree_folder_action=select>
is appended into the resulting URI.

=cut

sub descent_href {
    my ( $self, $href ) = @_;

    if ( defined $href ) {
        $self->{descent_href} = $href;
    }
    unless ( defined $self->{descent_href} ) {
        my @base_path = split '/', $self->base_path;
        pop @base_path;
        my $uri = URI::URL->new;
        $uri->query( CTX->request->url_query );
        my %query_params = $uri->query_form;
        $query_params{tree_folder_action} = 'select';
        $self->{descent_href} = OpenInteract2::URL->create( '/'
        . join( '/', grep { defined $_ } (
        CTX->request->action_name, CTX->request->task_name,
        $self->url_base_path, @base_path
        ) ),
            \%query_params
        );
    }
    return $self->{descent_href};
}

=pod

=head2 sort_root_elements( [SUBROUTINE] )

Sorts the root elements according to provided sorting subroutine. The default
subroutine for sorting is:

  sub { $b->is_folder <=> $a->is_folder
    || lc( $a->name ) cmp lc( $b->name ) }

Whichs sorts the root elements as folders first and then both folders and
non-folders ascending with a dictionary sort.

=cut

sub sort_root_elements {
    my ( $self, $sort ) = @_;
    unless ( ref( $sort ) eq 'CODE' ) {
        $sort = sub { $b->is_folder <=> $a->is_folder
            || lc( $a->name ) cmp lc( $b->name ) };
    }
    my @sorted = sort { &$sort } @{ $self->{root_elements} };
    $self->{root_elements} = \@sorted;
}

=pod

=head2 add_element( ELEMENT, [PARENT_ID] )

Adds an element in the tree. If the element doesn't have I<parent_element> class
attribute specified, it will be added as a root element.

Optionally accepts the id of the parent as the second parameter. Setting
I<parent_element> instead is a good idea, because it is faster (no need to
search the tree for the parent element).

While adding an element in the tree, sets certain element attributes based on
tree attributes.

=cut

sub add_element {
    my ( $self, $element, $parent_id ) = @_;

    # no duplicate element ID's
    return undef if $self->_check_for_duplicate( $element );

    my $parent = $element->parent_element;

    # If no parent class was specified and optional
    # argument parent id exists, tries to find the specified
    # element by id and set it as the parent element
    if ( !ref( $parent ) && $parent_id ) {
        $parent = $self->find_element( $parent_id );
        $element->parent_element( $parent ) if $parent;
    }

    # parentless are root elements
    return $self->_add_root_element( $element ) unless ref( $parent );

    $self->_generic_add_element( $element );

    $parent->add_sub_element( $element );
    push @{ $self->{'used_ids'} }, $element->element_id;

    return 1;
}

=pod

=head2 remove_element( ELEMENT_ID|ELEMENT )

Removes an element from the tree.

Accepts the id of the element or the element itself as a parameter.

While removing an element from the tree, alters the attributes in parent
element.

=cut

sub remove_element {
    my ( $self, $element ) = @_;

    $element = $self->find_element( $element )
        unless ref( $element );

    my $parent = $element->parent_element;

    if ( ref( $parent ) ) {
        $parent->remove_sub_element( $element->element_id );
    }
    else {
        $self->_remove_root_element( $element->element_id );
    }

    $element->parent_element( undef );

    return 1;
}

=pod

=head2 get_tree()

Goes through the root element branches, constructs valid parameter for passing
to I<Dicole::Content::Tree> and returns the resulting content object.

The object is constructed by calling I<get_sub_tree()> for each root element
object and passing the return value to I<Dicole::Content:Tree> objects class
method I<add_tree_rows()>.

=cut

sub get_tree {
    my $self = shift;

    my $root_element_count = @{ $self->root_elements };

    $self->init_tree;

    my $tree = Dicole::Content::Tree->new(
        base_path => $self->base_path,
        root_name => $self->root_name,
        root_icon => $self->root_icon,
        root_href => $self->root_href,
        no_icon_base => $self->no_icon_base,
        descentable => $self->descentable,
        descent_name => $self->descent_name,
        descent_icon => $self->descent_icon,
        descent_href => $self->descent_href,
        root_selected => ( ref $self->current_element )
            ? undef : ( $self->no_root_select ) ? undef : 1,
        tree_id => $self->tree_id,
        selectable => $self->selectable,
        icon_resolution => $self->icon_resolution
    );

    if ( $self->root_dropdown ) {
        $tree->root_template( $self->root_dropdown->get_template );
        $tree->root_params( $self->root_dropdown->get_template_params );
    }

    my $i = 0;

    if ( CTX->request->param('tree_folder_action') eq 'select' ) {
        my $open_folders = Dicole::Utility->fetch_from_cache(
            'tree_' . $self->tree_id,
            'open_folders'
        );
        $open_folders = {} unless ref( $open_folders ) eq 'HASH';

        my $pathutils = Dicole::Pathutils->new;
        $pathutils->url_base_path( $self->url_base_path );
        my $element_path = $pathutils->get_current_path;
        $open_folders->{$element_path} = 1;

        Dicole::Utility->save_into_cache(
            'tree_' . $self->tree_id,
            'open_folders',
            $open_folders
        );
    }

    foreach my $element ( @{ $self->root_elements } ) {
        $i++;
        $tree->add_tree_rows( $element->get_sub_tree(
            is_last => ( $i == $root_element_count ) ? 1 : 0
        ) );
    }

    return $tree;
}

=pod

=head2 init_tree()

Initializes the tree by calling I<init_sub_tree()> for each root element of the
tree. See documentation of I<init_sub_tree()> for more details.

=cut

sub init_tree {
    my $self = shift;
    foreach my $element ( @{ $self->root_elements } ) {
        $element->init_sub_tree;
    }
}

=pod

=head2 open_tree_path_to( ELEMENT_ID|ELEMENT )

opens a path to the specified element in the tree hierarchy, which means that
all parent folders are opened up to the root level.

=cut

sub open_tree_path_to {
    my ( $self, $element ) = @_;

    $element = $self->find_element( $element )
        unless ref $element;

    $element->open_parent_folder( 'recursive' ) if $element;
}

=pod

=head2 open_all_folders_under( ELEMENT_ID )

Opens all tree elements under the specified element in the tree hierarchy.

=cut

sub open_all_folders_under  {
    my ( $self, $element_id ) = @_;

    my $element = $self->find_element( $element_id );

    $element->open_all_sub_folders if $element;
}

=pod

=head2 close_all_folders_under( ELEMENT_ID )

Closes all tree elements under the specified element in the tree hierarchy.

=cut

sub close_all_folders_under  {
    my ( $self, $element_id ) = @_;

    my $element = $self->find_element( $element_id );

    $element->close_all_sub_folders if $element;
}

=pod

=head2 open_all_folders()

Opens all tree elements in the tree hierarchy.

=cut

sub open_all_folders {
    my $self = shift;

    foreach my $element ( @{ $self->root_elements } ) {
        $element->open_all_sub_folders;
    }
}

=pod

=head2 close_all_folders()

Closes all tree elements in the tree hierarchy.

=cut

sub close_all_folders {
    my $self = shift;

    foreach my $element ( @{ $self->root_elements } ) {
        $element->close_all_sub_folders;
    }
}

=pod

=head2 open_sub_folders_by_depth( ELEMENT_ID, SCALAR )

Opens all sub folders of the specified element recursively until specified
depth.

=cut

sub open_sub_folders_by_depth {
    my ( $self, $element_id, $depth ) = @_;

    my $element = $self->find_element( $element_id );

    $element->open_sub_folders( $depth ) if $element and $depth > 0;
}

=pod

=head2 open_root_folders_by_depth( SCALAR )

Opens all sub folders of root elements recursively until specified depth.

=cut

sub open_root_folders_by_depth {
    my ( $self, $depth ) = @_;

    $depth--;

    if ( $depth > 0 ) {
        foreach my $element ( @{ $self->root_elements } ) {
            $element->open_sub_folders( $depth );
        }

    }
}

=pod

=head2 find_element( ELEMENT_ID )

Searches for an element in the tree by id. If the element is found the element
object is returned, otherwise returns undef.

=cut

sub find_element {
    my ( $self, $element_id ) = @_;

    foreach my $element ( @{ $self->root_elements } ) {
        my $object = $element->find_sub_element( $element_id );
        if ( ref $object ) {
            return $object;
        }
    }

    return undef;
}

=pod

=head1 PRIVATE METHODS

=head2 _add_root_element( ELEMENT )

Adds a root element in the root elements and its id in the used ids.

Checks for a dublicate. If the element is already in the tree, undef will be
returned.

Sets initial values based on the Tree object by calling
I<_generic_add_element()>.

Sets the depth to 1 for the element.

=cut

sub _add_root_element {
    my ( $self, $element ) = @_;

    # no duplicate element ID's
    return undef if $self->_check_for_duplicate( $element );

    # Because we are adding a root element it will be
    # in first level of depth
    $element->depth( 1 );

    $self->_generic_add_element( $element );

    push @{ $self->{ 'used_ids' } }, $element->element_id;
    push @{ $self->{ 'root_elements' } }, $element;

    return 1;
}

=head2 _remove_root_element( ELEMENT_ID )

Removes a root element from the root elements.

=cut

sub _remove_root_element {
    my ( $self, $element_id ) = @_;

    my $elements = [];
    foreach my $element ( @{ $self->{ 'root_elements' } } ) {
        push @{ $elements }, $element
            unless $element->element_id eq $element_id;
    }
    $self->{ 'root_elements' } = $elements;

    return 1;
}

=pod

=head2 _check_for_duplicate( ELEMENT )

Checks the used ids for the id of the element. Returns 1 if the element id
exists, undef upon failure.

=cut

sub _check_for_duplicate {
    my ( $self, $element ) = @_;

    # no duplicate element ID's
    return 1 if ( grep {$_ eq $element->element_id } @{ $self->used_ids } );
    return undef;
}

=pod

=head2 _generic_add_element( ELEMENT )

Sets the element object attributes based on the tree object attributes. Sets
things like icon override, id path, tree object, visibility, no collapsing and
folder open status.

=cut


sub _generic_add_element {
    my ( $self, $element ) = @_;

    # Pass id path bit to the element
    $element->id_path( $self->id_path );

    # Set the tree where the element belongs
    $element->tree_object( $self );

    # Update selected bit and folder visibility status
    $element->update_status;

    # Prefer elements no_collapsing attribute
    unless ( $element->no_collapsing ) {
        $element->no_collapsing( $self->no_collapsing ) ;
    }
    if ( $element->no_collapsing ) {
        if ( $element->is_folder ) {
            $element->open_folder;
        }
    }
}

=pod

=head1 SEE ALSO

L<Dicole::Content::Tree>,
L<Dicole::Navigation::Tree::Element>

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

