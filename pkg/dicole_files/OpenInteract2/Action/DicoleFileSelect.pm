package OpenInteract2::Action::DicoleFileSelect;

# $Id: DicoleFileSelect.pm,v 1.24 2008-01-17 22:12:08 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Files;
use Dicole::Tool;
use Dicole::Utility;
use Dicole::Navigation::Tree::Element;
use Dicole::Navigation::Tree;
use Dicole::Content::Controlbuttons;
use Dicole::Content::Formelement::Chooser;
use Dicole::Content::Button;

use base qw( Dicole::Action OpenInteract2::Action::DicoleFiles );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.24 $ =~ /(\d+)\.(\d+)/);

# Initializes our tool objects
sub init_tool {
    my ( $self, $params ) = @_;
    $self->SUPER::init_tool( $params );
    # Set page structure
    $self->tool->structure( 'popup' );
}

sub detect {
    my ( $self ) = @_;
    my $gid = CTX->request->param('group_id');
    my $uid = CTX->request->param('user_id');
    return CTX->response->redirect( $self->derive_url(
        task => 'tree',
        target => CTX->request->auth_user_id,
        additional => $gid ?
            [ 'groups', $gid ] :
            [ 'users', $uid ],
        params => { tree_folder_action => 'select' },
    ) );
}

sub tree {
    my ( $self ) = @_;

    $self->init_tool;

    # We do some voodoo here to achieve a flat browsing view.
    # We use the tree classes but choose that a folder could
    # not be selected, the view could not be collapsed and folder icons
    # will always appear to be closed.
    #
    # Later we tell Fileops that
    # the directory tree should be retrieved flat, which means
    # that the whole tree is not read in, only the first level

    my $cached_base = Dicole::Utility->fetch_from_cache(
        'tree_' . $self->param( 'tree_id' ), 'base_path'
    );

    my $tree = Dicole::Navigation::Tree->new(
        no_collapsing => 1,
        no_folder_select => 1,
        folder_icons_always_closed => 1,
        descent_name => $self->_msg( 'Descend to previous folder' ),
        url_base_path => $self->target_user_id,
        root_name => $self->_msg( 'Documents' ),
        tree_id => $self->param( 'tree_id' ),
        base_path => $cached_base || $self->param( 'base_path' ),
    );

    my $action = CTX->request->param('tree_folder_action');

    if ( $action eq 'select' || ( $action eq 'detect' && ! $cached_base ) ) {
        my $path = $self->files->Pathutils->get_current_path;
        $tree->base_path( $path );
        Dicole::Utility->save_into_cache(
            'tree_' . $self->param( 'tree_id' ), 'base_path', $path
        );
        $cached_base = $path;
    }

    # Check that the current path is under the base path. If it is not,
    # we should redirect the browser to the base path. This is because
    # the dialog saves the last base path location and when opening a new
    # dialog the state should be restored
    my $base_path = $tree->base_path;
    if ( $self->files->Pathutils->get_current_path !~ /^$base_path/ ) {
        my $id = $self->param('target_user_id') || CTX->request->auth_user_id;
        my $redirect = OpenInteract2::URL->create(
            '/' . CTX->request->action_name . '/tree/' .
            $id . '/' . $tree->base_path
        );
        return CTX->response->redirect( $redirect );
    }

    my $mime_icons = OpenInteract2::Config::Ini->new({ filename => File::Spec->catfile(
    	CTX->repository->full_config_dir, 'dicole_base', 'mime_icons.ini'
	) });

    $tree->icon_files( $mime_icons->{mime_icons} );

    my ( $sec_id, $sec_prefix, $level_name ) = $self->_get_sec_based_on_path(
        $tree->base_path
    );

    # Make the tool path to correspond the current url path
    $self->tool->Path->del_all;
    my $i = 0;
    foreach my $path ( split "/", $self->files->Pathutils->get_current_path ) {
        if ( $i == 1 ) {
            $self->tool->Path->add( name => $level_name );
        }
        else {
            $self->tool->Path->add( name => $path );
        }
        $i++;
    }
    # If no path, show root, which is /
    unless ( $self->tool->Path->count ) {
        $self->tool->Path->add( name => '' );
    }

    # If base path is set, we sure are not on the root level.
    # This means we have to enable descending to previous folder.
    if ( $tree->base_path ) {
        $tree->descentable( 1 );
        $tree->root_icon( 'tree_folder_open.gif' );

        if ( $level_name ) {
            $tree->root_dropdown(
                $self->_create_element_dropdown( $level_name, $tree )
            );
        }
        # if target id is parsed but we don't have a level name
        # we must be in a subdirectory
        else {
            my @base = split '/', $tree->base_path;

            if ( $sec_id ) {
                $tree->root_dropdown(
                    $self->_create_element_dropdown( $base[-1], $tree )
                );
            }
            else {
                $tree->root_name( $base[-1] );
            }
        }
    }

    # Retrieve the directory tree as flat, which means only
    # one level of the whole tree will be retrieved
    $self->files->Fileops->dir_tree_flat( 1 );
    $self->get_dir_tree( $tree );

    $tree->init_tree;

    # A textfield which displays the current selected item
    # and a button to send the selected item to the parent opener window
    my $buttons = [
            Dicole::Content::Formelement->new(
                attributes => {
                    type => 'hidden',
                    name => 'selection',
                    value => '/' . $self->files->Pathutils->get_current_path
                }
            ),
            Dicole::Content::Button->new(
                type => 'onclick_button',
                link => 'javascript:filefieldToParent(this)',
                value => $self->_msg( 'Select' ),
            ),
            Dicole::Content::Button->new(
                type => 'onclick_button',
                link => 'top.close();',
                value => $self->_msg( 'Close' ),
            ),
    ];

    my $content = [
        Dicole::Content::Controlbuttons->new( buttons => $buttons ),
    ];

    push @{ $content }, $tree->get_tree;

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Select file' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content );

    $self->generate_content( $self->tool->generate_content_params );
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Handler::UserManager - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
