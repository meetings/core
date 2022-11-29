package Dicole::Navigation::Tree::Element;

use strict;
use Dicole::Utility;
use URI::URL;
use URI::Escape;
use Dicole::Pathutils;

use OpenInteract2::Context   qw( CTX DEPLOY_URL );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

my $log = get_logger( LOG_APP );

=pod

=head1 NAME

Representing tree elements

=head1 SYNOPSIS

 No synopsis.

=head1 DESCRIPTION

Not documented.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=cut

# We are lazy...Lets generate some basic accessors for our class
Dicole::Navigation::Tree::Element->mk_accessors(
    qw(
        element_id sub_elements depth type
        parent_element is_folder selected id_path element_uri_param
        no_collapsing element_count tree_object
        override_link no_link visible_name skip_selected
        dropdown class
    )
);

=pod

=head1 METHODS

=head2 new( HASH )

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

sub _init {
    my ($self, %args) = @_;

    # Tree in which the element belongs
    $self->tree_object( $args{'tree_object'} );

    # defines that the element is selected
    $self->selected( $args{'selected'} );

    # defines that the element is selected
    $self->skip_selected( $args{'skip_selected'} );

    # the unique ID of the element (user defined)
    $self->element_id( $args{'element_id'} );

    # Defines if the element is a folder (mau contain sub elements)
    $self->is_folder( $args{'is_folder'} );

    #list of Tree::Element objects
    $self->sub_elements( $args{'sub_elements'} ? $args{'sub_elements'} : [] );

    # how deep we are in the tree hierarchy
    $self->depth( $args{'depth'} );

    # element type (folder_open, folder_closed,
    # tree_horizontal application/pdf etc)
    $self->type( $args{'type'} );

    # Name of the element as displayed to the user
    $self->visible_name( $args{'visible_name'} );

    # Name of the element (used as path component)
    $self->name( $args{'name'} );

    # If this is true, the path will be constructed of element ids instead of
    # element names
    $self->id_path( $args{'id_path'} );

    # Special parameter to use in element URI:s. Will be the value
    # of apache param element_param
    $self->element_uri_param( $args{'element_uri_param'} );

    # object reference to the parent. undef, if root element
    $self->parent_element( $args{'parent_element'} );

    # if true, there won't be plus/minus signs drawn
    $self->no_collapsing( $args{'no_collapsing'} );

    # specify link insted of default
    $self->override_link( $args{'override_link'} );

    # specify link insted of default
    $self->no_link( $args{'no_link'} );

	# specify CSS class
	$self->class( $args{'class'} );
}

sub name {
    my ( $self, $name ) = @_;
    if ( defined $name ) {
        $self->{name} = $name;
        unless ( defined $self->visible_name ) {
            $self->visible_name( $self->{name} );
        }
    }
    return $self->{name};
}

sub folder_is_open {
    my ( $self ) = @_;
    my $open_folders = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->tree_object->tree_id,
        'open_folders'
    );
    if ( ref( $open_folders ) eq 'HASH'
        && $open_folders->{$self->element_path_as_string}
    ) {
        $self->{folder} = 1;
        $log->is_debug && $log->debug( 'Folder '
            . $self->element_path_as_string
            . ' is open' );
    }
    else {
        $log->is_debug && $log->debug( 'Folder '
            . $self->element_path_as_string
            . ' is closed' );
    }

    $log->is_debug && $log->debug( 'Currently open folders: '
       . join ', ', keys %{ $open_folders }
    );

    return $self->{folder};
}

sub open_folder {
    my ( $self ) = @_;
    my $open_folders = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->tree_object->tree_id,
        'open_folders'
    );
    unless ( ref( $open_folders ) eq 'HASH' ) {
        $open_folders = {};
    }

    $open_folders->{$self->element_path_as_string} = 1;

    Dicole::Utility->save_into_cache(
        'tree_' . $self->tree_object->tree_id,
        'open_folders',
        $open_folders
    );

    $log->is_debug &&
        $log->debug( 'Opened folder ' . $self->element_path_as_string );

    $self->{folder} = 1;
}

sub close_folder {
    my ( $self ) = @_;

    my $open_folders = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->tree_object->tree_id,
        'open_folders'
    );
    unless ( ref( $open_folders ) eq 'HASH' ) {
        $open_folders = {};
    }

    if ( exists $open_folders->{$self->element_path_as_string} ) {
        $log->is_debug &&
            $log->debug( 'Closed open folder ' . $self->element_path_as_string );
        delete $open_folders->{$self->element_path_as_string};
    }

    Dicole::Utility->save_into_cache(
        'tree_' . $self->tree_object->tree_id,
        'open_folders',
        $open_folders
    );

    $self->{folder} = undef;
}

sub find_sub_element {
    my ( $self, $element_id ) = @_;

    if ( $self->element_id eq $element_id ) {
        return $self;
    }
    else {
        foreach my $element ( @{ $self->sub_elements } ) {
            my $found = $element->find_sub_element( $element_id );
            return $found if ref $found;
        }
    }
    return undef;
}

sub add_sub_element {
    my ( $self, $element ) = @_;

    $element->depth( $self->depth + 1 );
    $element->parent_element( $self );
    push @{ $self->{'sub_elements'} }, $element;

    return 1;
}

sub remove_sub_element {
    my ( $self, $element_id ) = @_;

    my $elements = [];
    foreach my $element ( @{ $self->{'sub_elements'} } ) {
        push @{ $elements }, $element
            unless $element->element_id eq $element_id;
    }
    $self->{'sub_elements'} = $elements;

    return 1;
}

sub sort_sub_elements {
    my ( $self, $sort ) = @_;
    unless ( $sort ) {
        $sort = sub { $b->is_folder <=> $a->is_folder
                || lc( $a->visible_name ) cmp lc( $b->visible_name ) };
    }
    else {
        $sort = eval $sort;
    }
    my @sorted = sort { &$sort } @{ $self->{sub_elements} };
    $self->{sub_elements} = \@sorted;
}

sub element_path {
    my ( $self, $element_path ) = @_;
    if ( ref( $element_path ) eq 'ARRAY' ) {
        $self->{element_path} = $element_path;
    }
    my @tree_path = split '/', $self->tree_object->base_path;
    my $element_name = ( $self->id_path ) ? $self->element_id : $self->name;
    unless ( ref( $self->{element_path} ) eq 'ARRAY' ) {
        my $element_path = [
            @tree_path,              # Base path
            $self->get_element_path, # Parent elements
            $element_name            # Name of the element itself
        ];
        $self->{element_path} = $element_path;
    }
    return $self->{element_path};
}

sub element_path_as_string {
    my ( $self ) = @_;
    return join '/', @{ $self->element_path };
}

sub init_element {
    my ( $self ) = @_;

    # If the element has sub elements, it is a folder
    if ( !$self->is_folder && $self->has_sub_elements ) {
        $self->is_folder( 1 );
        $self->update_status;
    }

    # when the plus/minus signs aren't displayed (no collapsing),
    # the folder must be open always.
    # Also check from cache
    if ( $self->no_collapsing
        || $self->folder_is_open
        || $self->tree_object->folders_initially_open ) {
        if ( $self->is_folder ) {
            $log->is_debug &&
                $log->debug( 'Opening folder ' . $self->element_path_as_string
                . ' because no_collapsing, folder_is_open or '
                . 'folders_initially_open returned true'
            );
            $self->open_folder;
        }
    }

}

sub update_status {
    my ( $self ) = @_;

    my $pathutils = Dicole::Pathutils->new;
    $pathutils->url_base_path( $self->tree_object->url_base_path );
    my $element_path = $self->element_path_as_string;
    if ( $self->selected || $pathutils->if_path_is_current( $element_path ) ) {
        # Select the element
        $self->selected( 1 ) unless $self->skip_selected;

        # Tell tree object itself that this element is the current
        # one based on URL path
        $self->tree_object->current_element( $self );

        # Modify element properties based on apache parameter input
        if ( $self->is_folder ) {

            if ( CTX->request->param('tree_folder_action') eq 'open' ) {
                $self->open_folder;
            }
            elsif ( CTX->request->param('tree_folder_action') eq 'close' ) {
                $self->close_folder;
            }
        }
    }
}

sub init_sub_tree {
    my ( $self ) = @_;

    $self->init_element;

    foreach my $element ( @{ $self->sub_elements } ) {
        $element->init_sub_tree;
    }
}

sub get_sub_tree {
    my $self = shift;

    my $args = {
        is_last => undef,
        blocks_to_draw => [],
        @_
    };
    $self->init_element;

    # Make uri for the current element
    my $element_uri = $self->make_uri_path;

    # Get request parameters
    my %query_params;
    $query_params{tree_folder_action} = CTX->request->param( 'tree_folder_action' )
        if CTX->request->param( 'tree_folder_action' );

    if ( defined $self->element_uri_param ) {
        $query_params{element_param} = $self->element_uri_param;
    }

    my $tree_rows = [];

    # Build current tree level structure
    foreach my $image_name ( @{ $args->{blocks_to_draw} } ) {
        push @{ $tree_rows->[0]{images} }, {
            img => $self->tree_object->icon_files->{$image_name}
        };
    }

    # If it is a folder
    if ( $self->is_folder ) {

        my %folder_query_params = %query_params;

        # ... and the folder is open
        if ( $self->folder_is_open ) {

            # If no_collapsing is set, we don't want the
            # folder open/close functions
            unless ( $self->no_collapsing ) {
                $folder_query_params{tree_folder_action} = 'close';

                push @{ $tree_rows->[0]{images} }, {
                    img  => ( $args->{is_last} )
                        ? $self->tree_object->icon_files->{'tree_minus_corner'}
                        : $self->tree_object->icon_files->{'tree_minus'},
                    href => $self->get_link(
                            $element_uri,
                            \%folder_query_params
                    )
                };
            }
            unless ( $self->type ) {
                if ( $self->tree_object->folder_icons_always_closed ) {
                    $self->type( 'folder_closed' );
                }
                else {
                    $self->type( 'folder_open' );
                }
            }

        }
        # Folder is closed
        else {

            # If no_collapsing is set, we don't want the
            # folder open/close functions
            unless ( $self->no_collapsing ) {
                $folder_query_params{tree_folder_action} = 'open';

                push @{ $tree_rows->[0]{images} }, {
                    img  => ( $args->{is_last} )
                        ? $self->tree_object->icon_files->{'tree_plus_corner'}
                        : $self->tree_object->icon_files->{'tree_plus'},
                    href => $self->get_link(
                        $element_uri,
                        \%folder_query_params
                    )
                };
            }
            $self->type( 'folder_closed' ) unless $self->type;

        }
    }

    if ( !$self->is_folder || $self->no_collapsing ) {
        push @{ $tree_rows->[0]{images} }, {
            img => ( $args->{is_last} )
                ? $self->tree_object->icon_files->{'tree_corner'}
                : $self->tree_object->icon_files->{'tree_tcross'}
        };
    }

    # Add current element icon
    if ( $self->type ) {
        if ( $self->is_folder && !$self->tree_object->no_new_root ) {
            my %folder_query_params = %query_params;
            $folder_query_params{tree_folder_action} = 'select';

            push @{ $tree_rows->[0]{images} }, {
                img => $self->tree_object->icon_files->{ $self->type },
                href => $self->get_link(
                    $element_uri,
                    \%folder_query_params
                )
            };
        }
        else {
            my $type = $self->type;
            my $icon_files = $self->tree_object->icon_files;
            my $icon = $icon_files->{ $type };
            unless ( $icon && $type =~ m{/} ) {
                $type =~ s/\/(.*)$//;
                $icon = $icon_files->{ $type };
            }
            unless ( $icon ) {
                $icon = $icon_files->{'document'};
            }
            push @{ $tree_rows->[0]{images} }, {
                img => $icon
            };
        }
    }
    else {
        push @{ $tree_rows->[0]{images} }, {
            img => $self->tree_object->icon_files->{'document'}
        };
    }

    # Add element name:
    $tree_rows->[0]{content} = $self->visible_name;

	# Add CSS class if present
	$tree_rows->[0]{class} = $self->class;

    ## HACK FOR DROPDOWNS:

    if ( $self->dropdown ) {
        $tree_rows->[0]{template} = $self->dropdown->get_template;
        $tree_rows->[0]{params} = $self->dropdown->get_template_params;
    }


    # Special case: if it is not possible to select a folder but it is
    # possible to select a new root, then selecting
    # a folder as a new root is possible by clicking the folder
    # name in addition to folder icon
    if ( $self->is_folder && $self->tree_object->no_folder_select ) {
        unless ( $self->tree_object->no_new_root ) {
            $query_params{tree_folder_action} = 'select';
            $tree_rows->[0]{href} = $self->get_link(
                $element_uri,
                \%query_params
            );
        }
    }
    else {
        # Single-clicking an element selects it
        delete $query_params{tree_folder_action};
        $tree_rows->[0]{href} = $self->get_link(
            $element_uri,
            \%query_params
        );
    }

    $tree_rows->[0]{selected} = 1 if !$self->skip_selected && $self->selected;

    # Add checkbox value
    $tree_rows->[0]{value} = $self->element_path_as_string;

    # add the visible subelements only if the folder is open
    if ( $self->folder_is_open ) {

        my $sub_element_count = @{ $self->sub_elements };

        for ( my $i = 0; $i < $sub_element_count; $i++ ) {
            my $element = $self->sub_elements->[ $i ];

            # if it's the last element, add empty block.
            # Otherwise add vertical line block
            my $new_block = ( $args->{is_last} )
                ? 'tree_empty'
                : 'tree_vertical';

            #check if we are in the last subelement
            my $is_last = ( $i == $sub_element_count - 1 ) ? 1 : 0;

            push @{ $tree_rows }, @{ $element->get_sub_tree(
                is_last        => $is_last,
                only_hidden    => $args->{only_hidden},
                blocks_to_draw => [ @{ $args->{blocks_to_draw} }, $new_block ],
            ) };
        }
    }

    return $tree_rows;
}

sub get_link {
    my ( $self, $element_uri, $query_params ) = @_;

    return if $self->no_link;

    my $deploy_url = DEPLOY_URL;

    # erge overridden links params to params we got. This is to ensure
    # that folder opening closing etc. still works.
    # Also reset deployed url, because we expect the overriding
    # link already contains deployment context
    if ( $self->override_link ) {
        CTX->assign_deploy_url( undef );
        my $override_uri = URI::URL->new( $self->override_link );
        my $override_params = { $override_uri->query_form };
        my %merged = ( %{ $query_params }, %{ $override_params } );
        $query_params = \%merged;
        $element_uri = $override_uri->path;
    }
    my $url = OpenInteract2::URL->create(
                $element_uri,
                $query_params
    );
    CTX->assign_deploy_url( $deploy_url );
    return $url;
}

sub make_uri_path {
    my ( $self ) = @_;

    # Create a new path
    my @new_uri_path = @{ $self->element_path };

    # Make sure the path contains only safe characters
    foreach my $segment ( @new_uri_path ) {
        $segment = URI::Escape::uri_escape( $segment );
    }

    return '/' . join( '/', grep { defined $_ } (
        CTX->request->action_name, CTX->request->task_name,
        $self->tree_object->url_base_path, @new_uri_path
    ) );
}

sub has_sub_elements
{
    my $self = shift;
    return $self->get_sub_element_count;
}

sub get_sub_element_count
{
    my $self = shift;
    my $count = @{ $self->sub_elements };
    return $count;
}

sub open_parent_folder
{
    my ( $self, $recursive ) = @_;

    if ( $self->parent_element ) {
        $self->parent_element->open_folder;
        if ( $recursive ) {
            $self->parent_element->open_parent_folder( $recursive );
        }
    }
}

sub get_element_path
{
    my ( $self ) = @_;

    my @path = ();

    if ( $self->parent_element ) {
        my $element_name = ( $self->id_path )
            ? $self->parent_element->element_id
            : $self->parent_element->name;
        unshift @path, $element_name;
        unshift @path, $self->parent_element->get_element_path;
    }
    return @path;
}

sub open_sub_folders
{
    my ( $self, $depth ) = @_;

    if ( $self->has_sub_elements ) {
        $self->open_folder;
    }
    $depth--;

    if ( $depth > 0 ) {
        foreach my $element ( @{ $self->sub_elements } ) {
            if ( $element->has_sub_elements ) {
                $element->open_sub_folders( $depth );
            }
        }
    }
}

sub open_all_sub_folders
{
    my $self = shift;

    if ( $self->has_sub_elements ) {
        $self->open_folder;
    }
    foreach my $element ( @{ $self->sub_elements } ) {
        if ( $element->has_sub_elements ) {
            $element->open_folder;
        }
    }
}

sub close_all_sub_folders
{
    my $self = shift;

    if ( $self->has_sub_elements ) {
        $self->close_folder;
    }
    foreach my $element ( @{ $self->sub_elements } ) {
        if ( $element->has_sub_elements ) {
            $element->close_folder;
        }
    }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Navigation::Tree - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Dicole::Navigation::Tree;
  blah blah blah

=head1 ABSTRACT

  This should be the abstract for Dicole::Navigation::Tree.
  The abstract is used when making PPD (Perl Package Description) files.
  If you don't want an ABSTRACT you should also edit Makefile.PL to
  remove the ABSTRACT_FROM option.

=head1 DESCRIPTION

Stub documentation for Dicole::Navigation::Tree, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Hannes Muurinen, E<lt>hmuurine@c47.orgE<gt>

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

