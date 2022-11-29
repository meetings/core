package OpenInteract2::Action::DicoleFiles;

# $Id: DicoleFiles.pm,v 1.129 2008-10-13 07:32:15 amv Exp $

use strict;

use constant DEF_F_MAX_LENGTH => 25;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Pathutils;
use Dicole::Files;
use Dicole::Files::Archive;
use Dicole::Files::MimeType;

use Dicole::Navigation::Tree::Element;
use Dicole::Navigation::Tree;

use Dicole::URL;
use Dicole::Box;
use Dicole::Feed;

use Dicole::Content;
use Dicole::Content::Controlbuttons;
use Dicole::Content::Button;
use Dicole::Content::Text;
use Dicole::Content::Hyperlink;
use Dicole::Content::Formelement::Dropdown;
use Dicole::Content::CategorizedList;
use Dicole::Content::Image;
use Dicole::Content::Dropdown;

use Dicole::Generictool::Data;

use Dicole::Utility;
use Dicole::MessageHandler qw( :message );

use Dicole::DateTime;

use base qw(
    Dicole::Action
    Class::Accessor
    Dicole::Action::Common::Settings
    OpenInteract2::Action::DicoleFilesAdd
    OpenInteract2::Action::DicoleFilesEdit
    OpenInteract2::Action::DicoleFilesClipboard
    OpenInteract2::Action::DicoleFilesArchive
    OpenInteract2::Action::DicoleFilesRename
    OpenInteract2::Action::DicoleFilesDelete
    OpenInteract2::Action::DicoleFilesView
);

OpenInteract2::Action::DicoleFiles->mk_accessors(
    qw( files element_dropdown )
);

# TODO: Use fields.conf instead of listing fields here

# TODO: Make internals (Dicole::Files) leave messages for later and catch them
# TODO: instead of the weird returning of status and message
# TODO: from the internals

our $VERSION = sprintf("%d.%02d", q$Revision: 1.129 $ =~ /(\d+)\.(\d+)/);

my $ICONS = undef;

# Overrides Dicole::Action
# Override some parameters passed to init_tool
# to include our RSS feed and other stuff
sub init_tool {
    my ( $self, $conf ) = @_;
    $conf ||= {};
    $self->SUPER::init_tool( {
        tool_args => {
            feeds => $self->init_feeds,
        },
        %{ $conf }
    } );
}

# Init the $self->files module if $self->can('files') and it
# has not been already inited. Returns the files module.
sub custom_init {
    my ( $self, $p ) = @_;

    my $type = $p->{target_type};
    my $id = $p->{target_id};
    
    # Hack to get expected id resolving with new action resolver
    if ( ! $id ) {
        my $segments = Dicole::URL->get_path_array( CTX->request->url_relative );
        if ( $segments->[2] && $segments->[2] =~ /^groups|users$/ ) {
            $id = undef;
        }
        elsif ( ( $type && $type eq 'group' ) ||
                ( ! $type && $self->name eq 'group_files' ) ) {
            $id = CTX->controller->initial_action->param('target_group_id')
        }
        else {
            $id = CTX->controller->initial_action->param('target_user_id')
        }
    }

    # Create Dicole::Files object if it does not exist.
    # Set dicole_files configuration path as the base path
    # for the object
    if ( ! ( $self->can( 'files' ) && ref( $self->files ) ) ) {
        
        my $files = Dicole::Files->new;
        $files->base_path( CTX->lookup_directory( 'dicole_files' ) );
        
        $self->files( $files ) if $self->can( 'files' );
        $files->Pathutils->url_base_path( $id );
        
        return $files;
    }
    else {
        return $self->files;
    }
}

########################################
# Summary
########################################

sub personal_summary {
    my ( $self ) = @_;
    return $self->_summary( 'personal' );
}

sub group_summary {
    my ( $self ) = @_;
    return $self->_summary;
}

sub _summary {
    my ( $self, $personal ) = @_;

    my $box = Dicole::Box->new;
    my $title = Dicole::Widget::Horizontal->new;

    if ( $personal ) {
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Latest files'),
                link => Dicole::URL->create_from_parts(
                    action => 'personal_files',
                    task => 'detect',
                    target => CTX->request->target_user_id,
                ),
            )
        );
    }
    else {
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Latest files'),
                link => Dicole::URL->create_from_parts(
                    action => 'group_files',
                    task => 'detect',
                    target => CTX->request->target_group_id,
                ),
            )
        );
    }

    $box->name( $title->generate_content );

    if ( $self->param( 'box_open' ) ) {
        my $recent = $self->_get_summary(
            $self->param( 'box_group' ), $personal
        );
        $box->content( $recent );
    }

    return $box->output;
}

sub _get_summary {
    my ( $self, $group, $personal ) = @_;

    my $data = $self->_ordered_file_data_by_section( $personal, 5 );

    if ( ! scalar @{ $data->data } ) {
        return Dicole::Content::Text->new(
            text => $self->_msg( 'No files found.' )
        );
    }

    my $last_month = -1;
    my $last_day = -1;

    my $cl = Dicole::Content::CategorizedList->new;
    my $category;
    my $topic;

    my $mime = Dicole::Files::MimeType->new;
    my $icons = $self->_get_icons;

    foreach my $file ( @{ $data->data } ) {

        my $month = Dicole::DateTime->month_year_long( $file->{date} );
        my $day = Dicole::DateTime->day( $file->{date} );

        if ( $month ne $last_month || $day ne $last_day ) {
            if ( $month ne $last_month ) {
                $category = $cl->add_category(
                    name => $month,
                );
            }

            $topic = $cl->add_topic(
                category => $category,
                name => $day,
            );
        }

        $last_month = $month;
        $last_day = $day;

        my $meta = undef;
        if ( $file->{user_id} ) {
            my $author = $file->user( { skip_security => 1 } );
           $meta = $author->{first_name} . ' ' . $author->{last_name};
        }

        my ( $item_uri, $filename ) = $self->_get_item_uri_and_fname( $file, $personal );

        my $icon = 'tree_folder_closed.gif';
        unless ( $file->{is_folder} ) {
            my $type = $mime->mime_type_file( $filename );
            $icon = $icons->{ $type };
            unless ( $icon && $type =~ m{/} ) {
                $type =~ s/\/(.*)$//;
                $icon = $icons->{ $type };
            }
            unless ( $icon ) {
                $icon = 'document.gif';
            }
        }
        # Cut the filename shorter if it's too long
        my $short_filename = $filename;
        my $f_max_length = $self->param( 'f_max_length' ) || DEF_F_MAX_LENGTH;
        if ( length( $filename ) > $f_max_length ) {
            $short_filename = substr( $short_filename, 0, $f_max_length ) . '..';
        }
        $cl->add_entry(
            topic => $topic,
            elements => [
                {
                   width => '1%',
                   content => Dicole::Content::Image->new(
                        src => '/images/theme/default/tree/16x16/' . $icon,
                        width => 16,
                        height => 16
                    ),
                },
                {
                   width => '99%',
                   content => Dicole::Content::Hyperlink->new(
                        text => $meta,
                        content => $short_filename,
                        attributes => {
                            href => $item_uri,
                            title => $filename,
                            alt => $filename,
                        },
                    ),
                },
            ]
        );
    }

    return $cl;
}

sub _get_item_uri_and_fname {
    my ( $self, $file, $personal, $task ) = @_;
    $task ||= 'properties';
    my @file_path = split '/', $file->{path};
    my $item_uri = undef;
    if ( $personal ) {
        $item_uri = Dicole::URL->create_from_parts(
            action => 'personal_files',
            task => $task,
            target => CTX->request->target_id,
            additional => [ @file_path ],
        );
    }
    else {
        $item_uri = Dicole::URL->create_from_parts(
            action => 'group_files',
            task => $task,
            target => CTX->request->target_id,
            additional => [ @file_path ],
        );
    }
    return $item_uri, $file_path[-1];
}

sub _ordered_file_data_by_section {
    my ( $self, $personal, $limit ) = @_;
    my $path_search = 'groups/' . CTX->request->active_group . '/';
    $path_search = 'users/' . CTX->request->auth_user_id . '/' if $personal;
    $path_search .= '%';

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('files') );
    $data->query_params( {
        where => 'path like ? AND format != "inode/directory"',
        value => [ $path_search ],
        limit => $limit,
        order => 'date DESC'
    } );
    $data->data_group;
    return $data;
}

sub _if_personal {
    my ( $self ) = @_;
    return 1 if $self->param('target_type') ne 'group';
    return undef;
}

sub _digest {
    my ( $self ) = @_;

   # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};
    $self->language( $self->param('lang') );

    my $group_id = $self->param('group_id');
    my $user_id = $self->param('user_id');
    my $domain_host = $self->param('domain_host');
    my $start_time = $self->param('start_time');
    my $end_time = $self->param('end_time');

    my $items = [];

    if ( $group_id ) {
        my $path_search = 'groups/' . $group_id . '/%';
        $items = CTX->lookup_object('files')->fetch_group( {
            where => 'path like ? AND format != "inode/directory" AND date > ?',
            value => [ $path_search, $start_time ],
            order => 'date DESC',
        } ) || [];
    }
    elsif ( $user_id ) {
        my $path_search = 'users/' . $user_id . '/%';
        $items = CTX->lookup_object('files')->fetch_group( {
            where => 'path like ? AND format != "inode/directory" AND date > ?',
            value => [ $path_search, $start_time ],
            order => 'date DESC',
        } ) || [];
    }

    if (! scalar( @$items ) ) {
        return undef;
    }

    my $return = {
        tool_name => $self->_msg( 'Files' ),
        items_html => [],
        items_plain => []
    };

    for my $item ( @$items ) {

        my ( $item_uri, $filename ) = $self->_get_item_uri_and_fname(
            $item, $group_id ? 0 : 1
        );
        my $link = $domain_host . $item_uri;
        my $date_string = Dicole::DateTime->medium_datetime_format(
            $item->{date}, $self->param('timezone'), $self->param('lang')
        );

        my $user = CTX->lookup_object('user')->fetch( $item->{user_id}, { skip_security => 1 } );
        my $user_name = $user->first_name . ' ' . $user->last_name;

        push @{ $return->{items_html} },
            '<span class="date">' . $date_string
            . '</span> - <a href="' . $link . '"> - ' . $item->{format} . ' - ' . $filename
            . '</a> - <span class="author">' . $user_name . '</span>';

        push @{ $return->{items_plain} },
            $date_string . ' - ' . $item->{format} . ' - ' . $filename
            . ' - ' . $user_name . "\n  - " . $link;
    }

    return $return;
}

########################################
# RSS feed
########################################

# Provide RSS feed for the tool
sub feed {
    my ( $self ) = @_;

    # use the first additional to set a new language
    $self->_shift_additional_language;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    if ( ! $self->skip_secure ) {
        unless ( CTX->request->auth_is_logged_in ) {
            if ( $settings_hash->{ 'ip_addresses_feed'} =~ /^\d+/ ) {
                if ( $self->_check_ip_addresses(
                $settings_hash->{ 'ip_addresses_feed'} )
                ) {
                    return 'Access denied.';
                }
            }
            elsif ( !$settings_hash->{ 'public_feed' } ) {
                return 'Access denied.';
            }
        }
    }

    my $feed = Dicole::Feed->new( action => $self );

    $feed->list_task( 'detect' );
    $feed->creator( 'Dicole files' );

    unless ( $self->_if_personal ) {
        my $group = CTX->lookup_object( 'groups' )->fetch(
            $self->target_id
        );
        $feed->title( $group->{name} . ' - ' . $self->_msg( 'Files' ) );
        $feed->desc( $group->{description} );
    }
    else {
        my $user = CTX->lookup_object( 'user' )->fetch(
            $self->target_user_id, { skip_security => 1 }
        );
        my $user_name = $user->{first_name} . ' ' . $user->{last_name};
        # TODO: Translate?
        $feed->title( $user_name );
        $feed->desc( sprintf( 'Files of user %s', $user_name ) );
    }

    my $data = $self->_ordered_file_data_by_section(
        $self->_if_personal,
        ( $settings_hash->{ 'number_of_items_in_feed' } || 5 )
    );

    foreach my $object ( @{ $data->data } ) {
        my ( $item_uri, $filename ) = $self->_get_item_uri_and_fname(
            $object, $self->_if_personal
        );
        $object->{title_link} = $item_uri;
        $object->{title} = $filename;

        my $item_metadata = {};
        foreach my $field ( qw(
                title creator subject description publisher contributor
                type format identifier source language relation coverage rights
        ) ) {
            if ( $object->{$field} ) {
                $object->{content} .= ucfirst( $field ) . ": ";
                if ( $object->{$field} =~ m{^\s*\S+://} ) {
                    $object->{content} .= '<a href="' . $object->{$field}
                        . '">Here</a>';
                } else {
                    $object->{content} .= $object->{$field};
                }
                $object->{content} .= "<br />\n";
                $item_metadata->{$field} = $object->{$field};
            }
        }
        $object->{content} .= "<br />\n" if $object->{content};
        $object->{dc_metadata} = $item_metadata;

        my ( $item_download ) = $self->_get_item_uri_and_fname(
            $object, $self->_if_personal, 'download'
        );
        my ( $item_view ) = $self->_get_item_uri_and_fname(
            $object, $self->_if_personal, 'viewer'
        );
        my ( $item_info ) = $self->_get_item_uri_and_fname(
            $object, $self->_if_personal, 'properties'
        );

        $object->{content} .= "<a href=\"$item_download\">Download</a>" . ' - '
            . "<a href=\"$item_view\">view</a>" . ' - '
            . "<a href=\"$item_info\">Properties</a>";
    }

    # TODO: Add to content fields from the metadata that are filled.
    # TODO: Also include icon and some information like size etc.

    $feed->subject_field( 'title' );
    $feed->link_field( 'title_link' );
    $feed->item_dc_field( 'dc_metadata' );

    return $feed->feed(
        objects => $data->data,
    );
}

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'files' );
}

#############################################################

# Check if target file exists
sub _check_existence {
    my ( $self, $full_path ) = @_;

    $full_path ||= $self->files->Pathutils->clean_path_name;
    unless ( -e $full_path ) {
        return undef;
    }
    else {
        return 1;
    }
}

sub _check_location_security {
    my ( $self, $mode, $path ) = @_;
    my ( $sec_id, $sec_prefix, $system_protected ) = $self->_get_sec_based_on_path(
        $path || $self->files->Pathutils->get_current_path
    );
    if ( !$self->chk_y( $sec_prefix . '_' . $mode, $sec_id ) ) {
        return undef;
    }
    # Note that if return value is tested for defined, 0 will result
    # as true. There are special folders under users and groups that are
    # system protected, which means you are not allowed to delete, rename
    # or cut these away from the system even if you have write and delete
    # access to the folders.
    # In this case testing for defined in these not so
    # special cases allows us to enable write/delete operations like edit
    # properties and add new folders inside the system protected folder
    # and disallowing the delete, rename and cut operations even if the user
    # has write/delete access.
    if ( $system_protected && ( $mode eq 'delete' || $mode eq 'write' ) ) {
        return 0;
    }
    return 1;
}

sub _return_msg {
    my ( $self, $error, $home, $url ) = @_;

    $url ||= 'tree';

    Dicole::MessageHandler->add_message( $error->[0], $error->[1] );

    my $redirect = $self->files->Pathutils->form_url( $url );
    if ( $home ) {
        my $url_rel = CTX->request->url_relative;
        # Hack: get rid or GET parameters
        $url_rel =~ s/\?.*$//;

        $redirect = OpenInteract2::URL->create(
            $url_rel . '/' . $url
        );
    }
    return CTX->response->redirect( $redirect );
}

sub _get_object_by_path {
    my ( $self, $path, $fetch_only, $like ) = @_;

    $path ||= $self->files->Pathutils->get_current_path;

    my $object = [];

    unless ( $like ) {
        $object = CTX->lookup_object( 'files' )->fetch_group( {
            skip_security => 1,
            where => 'path = "' . $path . '"'
        } )->[0];
    }
    else {
        $object = CTX->lookup_object( 'files' )->fetch_iterator( {
            skip_security => 1,
            where => 'path = "' . $path . '" or path like "'. $path . '/%"'
        } );
    }

    if ( !$fetch_only && !ref $object ) {
        $object = $self->_create_default_object( $path );
    }
    return $object;
}

sub detect {
    my ( $self ) = @_;
    my $redirect = undef;
    unless ( $self->_if_personal ) {
        $redirect = OpenInteract2::URL->create( '/' . join( '/', (
                CTX->request->action_name, 'tree', CTX->request->active_group,
                'groups', CTX->request->active_group
            ) ),
            { tree_folder_action => 'select' }
        );
    } else {
        $redirect = OpenInteract2::URL->create( '/' . join( '/', (
                CTX->request->action_name, 'tree',
                ( $self->target_user_id || CTX->request->auth_user_id ),
                'users', $self->target_user_id
            ) ),
            { tree_folder_action => 'select' }
        );
    }
    return CTX->response->redirect( $redirect );
}

sub stream {
    my ( $self, $paths ) = @_;

    unless ( ref( $paths ) eq 'ARRAY' ) {
        unless ( $self->_check_existence ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Location [_1] does not exist.',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        unless ( $self->_check_location_security( 'read' ) ) {
            return $self->_return_msg( [ 0, $self->_msg(
                'Security violation. No rights to read location [_1]',
                $self->files->Pathutils->get_current_path
            ) ] );
        }
        $paths = [ $self->files->Pathutils->get_current_path ];
    }

    # check security for paths, discard paths for which the user
    # has no read access rights
    $paths = [
        grep { $self->_check_location_security( 'read', $_ ) } @{ $paths }
    ];

    return $self->files->stream_files( $paths );
}

sub _do_action {
    my ( $self, $action ) = @_;

    # Check if action is not private and is available in our class
    if ( $action !~ /^\_/ && $self->can( $action ) ) {

        # Get values of the checked tree elements from apache
        # parameters based on tree id
        my $params = [];

        my $tree_id = $self->param( 'tree_id' );

        my $ids = Dicole::Utility->checked_from_apache( $tree_id );
        foreach my $id ( keys %{ $ids } ) {
            push @{ $params }, $ids->{$id};
        }

        # Get rid of distinct paths.. For example, we don't want to
        # delete a subdirectory which parent was just deleted (it itself
        # wouldn't exist anyway)
        $params = $self->files->Pathutils->parse_distinct_paths( $params );

        unless ( @{ $params } ) {
            $self->_return_msg( [ 0, $self->_msg( "No files or directories selected." ) ] );
        }
        # Call appropriate action on the current class
        return $self->$action( $params );
    }
}

sub _get_icons {
    my ( $self ) = @_;
    $ICONS ||= OpenInteract2::Config::Ini->new({ filename => File::Spec->catfile(
    	CTX->repository->full_config_dir, 'dicole_base', 'mime_icons.ini'
	) })->{mime_icons};
    return $ICONS;
}

sub tree {
    my ( $self ) = @_;

    $self->init_tool;

    if ( CTX->request->param( 'action' ) ) {
        return $self->_do_action( CTX->request->param( 'action' ) );
    }

    my $current_path = $self->files->Pathutils->get_current_path;

    $self->tool->Path->add( name => $self->_msg( 'Tree view' ) );

    my $tree = Dicole::Navigation::Tree->new(
        root_name => $self->_msg( 'Documents' ),
        url_base_path => ( $self->name eq 'group_files' )
            ? $self->target_group_id : $self->target_user_id,
        selectable => 1,
        no_root_select => 1,
        descent_name => $self->_msg( 'Descend to previous folder' ),
        tree_id => $self->param( 'tree_id' ),
        base_path => Dicole::Utility->fetch_from_cache(
            'tree_' . $self->param( 'tree_id' ), 'base_path'
        ) || $self->param( 'base_path' ),
    );

    $self->element_dropdown( 1 );

    $tree->icon_files( $self->_get_icons );

    # Select current path as the new base path
    if ( CTX->request->param('tree_folder_action') eq 'select' ) {
        my $path = $self->files->Pathutils->get_current_path;
        $tree->base_path( $current_path );
        Dicole::Utility->save_into_cache(
            'tree_' . $self->param( 'tree_id' ), 'base_path', $current_path
        );
    }

    # If the current path is not under the base path, select first two
    # segments of the path and define those as the new base path
    if ( $current_path !~ /^$tree->base_path/ ) {
        my $result_path = join '/', ( split '/', $current_path )[0,1];
        $tree->base_path( $result_path );
         Dicole::Utility->save_into_cache(
            'tree_' . $self->param( 'tree_id' ), 'base_path', $result_path
        );
    }

    if ( $tree->base_path ne $self->param( 'base_path' ) ) {
        $tree->descentable( 1 );
        my @base = split '/', $tree->base_path;
        $tree->root_name( $base[-1] );
        $tree->root_icon( 'tree_folder_open.gif' );
        my $level_name = undef;
        ( undef, undef, $level_name ) = $self->_get_sec_based_on_path(
            $tree->base_path
        );
        if ( $level_name ) {
            $tree->root_dropdown( $self->_create_element_dropdown( $level_name, $tree ) );
        }
    }

    $self->get_dir_tree( $tree );

    $tree->init_tree;

    my $buttons = [ ];

    push @{ $buttons }, Dicole::Content::Formelement::Dropdown->new(
        autosubmit => 1,
        attributes => { name => 'action' },
        options => [
            { attributes => { value => '' }, content => '=======' . $self->_msg( 'Checked items' ) . '=======' },
            { attributes => { value => 'cut' }, content => $self->_msg( 'Cut' ) },
            { attributes => { value => 'copy' }, content => $self->_msg( 'Copy' ) },
            { attributes => { value => '' }, content => '==========================' },
            { attributes => { value => 'del' }, content => $self->_msg( 'Delete' ) },
            { attributes => { value => 'stream' }, content => $self->_msg( 'Stream media files' ) },
            { attributes => { value => 'zip' }, content => $self->_msg( 'Download as Zip archive' ) },
            { attributes => { value => 'tar' }, content => $self->_msg( 'Download as Tar/gz archive' ) },
        ],
    );
    push @{ $buttons }, Dicole::Content::Button->new(
        type => 'link',
        value => $self->_msg( 'Return to home' ),
        link => $self->files->Pathutils->form_url( 'detect', 1 )
    );

    my $content = [
        Dicole::Content::Controlbuttons->new( buttons => $buttons ),
        $tree->get_tree
    ];
    push @{ $content }, Dicole::Content::Controlbuttons->new(
        buttons => $buttons
    ) if scalar @{ $tree->used_ids } > 30;

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Tree of files and directories' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( $content );

    $self->generate_tool_content;
}

sub _create_element_dropdown {
    my ( $self, $element, $tree, $no_clipboard ) = @_;

    my $element_path = ( ref $element ) ? $element->element_path_as_string : $tree->base_path;
    my $element_name = ( ref $element ) ? $element->visible_name : $element;

    my ( $sec_id, $sec_prefix, $system_protected_folder )
        = $self->_get_sec_based_on_path( $element_path );

    unless ( $sec_id && $self->chk_y( $sec_prefix . '_read', $sec_id ) ) {
        return undef;
    }

    my $dropdown = Dicole::Content::Dropdown->new(
        text => $element_name,
        title => $element_name,
    );

    my $pathutils = Dicole::Pathutils->new;
    $pathutils->base_path( $self->files->Pathutils->base_path );
    $pathutils->url_base_path( $self->files->Pathutils->url_base_path );
    $pathutils->path( $element_path );

    # If folder, add open/close as the first option
    if ( ref( $element ) && $element->is_folder ) {
        if ( $element->folder_is_open ) {
            $dropdown->add_element(
                link => $pathutils->form_url( 'tree', 1 ) . '?tree_folder_action=close',
                text => $self->_msg( 'Close' ),
            );
            $dropdown->add_delimiter;
        }
        else {
            $dropdown->add_element(
                link => $pathutils->form_url( 'tree', 1 ) . '?tree_folder_action=open',
                text => $self->_msg( 'Open' ),
            );
            $dropdown->add_delimiter;
        }
    }

    if ( ref( $element ) && !$element->is_folder ) {

        my $ctype = $element->type;

        $dropdown->add_element(
            link => $pathutils->form_url( 'download', 1 ),
            text => $self->_msg( 'Download' ),
        );
        $dropdown->add_element(
            link => $pathutils->form_url( 'viewer', 1 ),
            text => $self->_msg( 'View' ),
        );
        $dropdown->add_element(
            link => $pathutils->form_url( 'view', 1 ),
            text => $self->_msg( 'Open' ),
        );

        if ( $ctype =~ /^text/ || $ctype eq 'wwwserver/redirection' ) {
            $dropdown->add_element(
                link => $pathutils->form_url( 'edit', 1 ),
                text => $self->_msg( 'Edit' ),
            ) if $self->chk_y( $sec_prefix . '_write', $sec_id );
        }

        $dropdown->add_delimiter;
    }

    $dropdown->add_element(
        link => $pathutils->form_url( 'properties', 1 ),
        text => $self->_msg( 'Properties' ),
    );

    $dropdown->add_element(
        link => $pathutils->form_url( 'ren', 1 ),
        text => $self->_msg( 'Rename' ),
    ) if ! $system_protected_folder &&
         $self->chk_y( $sec_prefix . '_write', $sec_id );

    $dropdown->add_element(
        link => $pathutils->form_url( 'del', 1 ),
        text => $self->_msg( 'Delete' ),
    ) if ! $system_protected_folder &&
         $self->chk_y( $sec_prefix . '_delete', $sec_id );

    $dropdown->add_delimiter;

    $dropdown->add_element(
        link => $pathutils->form_url( 'cut', 1 ),
        text => $self->_msg( 'Cut' ),
    ) if ! $no_clipboard && !$system_protected_folder &&
         $self->chk_y( $sec_prefix . '_delete', $sec_id );

    $dropdown->add_element(
        link => $pathutils->form_url( 'copy', 1 ),
        text => $self->_msg( 'Copy' ),
    ) if ! $no_clipboard;

    # If current element is selected, display actions for folder elements
    if ( !ref( $element ) || $element->is_folder ) {

        if ( !$no_clipboard && $self->chk_y( $sec_prefix . '_add', $sec_id ) ) {
            $dropdown->add_element(
                link => $pathutils->form_url( 'paste', 1 ),
                text => $self->_msg( 'Paste' ),
            );
            $dropdown->add_delimiter;
        }

        if ( $self->chk_y( $sec_prefix . '_add', $sec_id ) ) {
            $dropdown->add_element(
                link => $pathutils->form_url( 'new_folder', 1 ),
                text => $self->_msg( 'Add folder' ),
            );
            $dropdown->add_element(
                link => $pathutils->form_url( 'upload', 1 ),
                text => $self->_msg( 'Upload file' ),
            );
            $dropdown->add_element(
                link => $pathutils->form_url( 'new_doc', 1 ),
                text => $self->_msg( 'New document' ),
            );
            $dropdown->add_element(
                link => $pathutils->form_url( 'new_url', 1 ),
                text => $self->_msg( 'New hyperlink' ),
            );
        }

        $dropdown->add_delimiter;
    }
    else {
        my $ctype = $element->type;

        if ( $ctype eq 'application/x-gzip'
            || $ctype eq 'application/x-zip-compressed'
            || $ctype eq 'application/x-tar'
            || $ctype eq 'application/x-compressed-tar'
        ) {
            $dropdown->add_element(
                link => $pathutils->form_url( 'uncompress', 1 ),
                text => $self->_msg( 'Uncompress' ),
            ) if $self->chk_y( $sec_prefix . '_write', $sec_id );
        }

        $dropdown->add_delimiter;
    }

    $dropdown->add_element(
        link => $pathutils->form_url( 'zip', 1 ),
        text => $self->_msg( 'Download as Zip archive' ),
    );
    $dropdown->add_element(
        link => $pathutils->form_url( 'tar', 1 ),
        text => $self->_msg( 'Download as Tar/gz archive' ),
    );

    return $dropdown;
}

sub _get_path {
    my ( $self ) = @_;
    my $path = $self->files->Pathutils->get_current_path;
    my $level_name = undef;
    ( undef, undef, $level_name ) = $self->_get_sec_based_on_path(
        $self->files->Pathutils->get_current_path, 'get_level'
    );
    $path =~ s{^(groups|users)/(\d+)(/.*)?$}{$1/$level_name$3} if $level_name;
    return $path;
}

sub _get_sec_based_on_path {
    my ( $self, $path, $get_level ) = @_;

    my $sec_id = undef;
    my $sec_prefix = undef;
    my $level_name = undef;
    if ( $path =~ m{^(groups|users)/(\d+)(/.*)?$} ) {
        my $domain = $1;
        my $id = $2;
        my $add_path = $3;
        if ( $domain eq 'groups' ) {
            $sec_id = $id;
            $sec_prefix = 'group';
            if ( $get_level || !$add_path || $add_path eq '/' ) {
                $level_name = $self->get_group_name( $sec_id );
            }
        }
        else {
            $sec_id = $id;
            $sec_prefix = 'user';
            if ( $get_level || !$add_path || $add_path eq '/' ) {
                $level_name = $self->get_user_name( $sec_id );
            }
        }
    }
    return $sec_id, $sec_prefix, $level_name;
}

=pod

=head2 get_dir_tree( OBJECT, [sub{ SORT }], [ROOT_PATH] )

Constructs a L<Dicole::Navigation::Treenav> tree of
L<Dicole::Navigation::TreeElement> elements based on filesystem directory tree.
Heavily utilizes I<read_dir_tree()>. Accepts the current tree object as the first
parameter.

Optionally accepts the sorting to pass along to I<read_dir_tree()>.

Optionally accepts the root path to use instead of using
L<Dicole::Pathutils> to determine base path from where to start
constructing the directory tree.

Returns undef if the I<ROOT_PATH> does not exist. Otherwise returns the
resulting tree object itself.

=cut

sub get_dir_tree {
    my ( $self, $tree, $sort, $root_path ) = @_;
    $root_path ||= $self->files->Fileops->Pathutils->base_path;

    my $root = $root_path;
    $root_path = File::Spec->catdir(
        $root_path, $tree->base_path
    ) if $tree->base_path;

    return $self->read_dir_tree( $tree, undef, $root_path, $sort, $root );
}

=pod

=head2 read_dir_tree( OBJECT, [PARENT_OBJECT], PATH, [sub{ SORT }], [ROOT_PATH] )

Recursively constructs a L<Dicole::Navigation::Treenav> tree of
L<Dicole::Navigation::TreeElement> elements based on filesystem directory tree.
Accepts the current tree object as the first parameter.

The second parameter is optional. It defines the parent element for which the
element tree should be attached to.

The third parameter is the path from which the recursive construction
will be continued.

The fourth parameter is the sorting to use. See I<read_dir()> for details.

The fifth parameter is optional. It defines the original root where the
recursive element tree construction initiated. It is required to build the
relative paths for each elements' I<element_id>.

The L<Dicole::Navigation::TreeElement> objects are constructed to contain the
relative path as the I<element_id>, name of the file/directory as the I<name> of the
element and I<type> as returned by I<get_mime_type()>. Type is not specified for
directories. The I<is_folder> bit is set if the element is a directory. The code
doesn't recursively search directories that are not open.

Returns the resulting tree object, undef if the I<ROOT_PATH> or the I<PATH> does not
exist.

=cut

sub read_dir_tree {
    my ( $self, $tree, $parent, $path, $sort, $root ) = @_;

    # This is for folder descending feature
    my $root_path = $root;
    $root_path = File::Spec->catdir(
        $root, $tree->base_path
    ) if $tree->base_path;

    return undef unless -e $root_path;

    my $current_path = $self->files->Pathutils->get_current_path;

    foreach my $file ( $self->files->Fileops->read_dir( $path, $sort, $root_path ) ) {

        my $tree_element = Dicole::Navigation::Tree::Element->new(
            parent_element => $parent,
#            skip_selected => 1,
            skip_selected => 0,
            element_id => $file->[0],
            name => $file->[1],
            type => ( -d $file->[2] )
                ? undef : $self->files->Fileops->get_mime_type( $file->[2], 1 ),
            is_folder => ( -d $file->[2] ) ? 1 : undef,
        );

        $tree->add_element( $tree_element );

        my $element_path = $tree_element->element_path_as_string;

        # Open folder if it is below our current path
        $tree_element->open_folder if $tree_element->is_folder
            && !$tree_element->folder_is_open && $current_path =~ /^$element_path\//;

        my ( $sec_id, $sec_prefix, $level_name ) = $self->_get_sec_based_on_path(
            $element_path
        );

        $tree_element->visible_name( $level_name ) if $level_name;

        # HACK FOR DROPDOWN:
        if ( $self->element_dropdown ) {
            $tree_element->dropdown(
                $self->_create_element_dropdown(
                    $tree_element, $tree,
                )
            );
        }

        if ( $sec_id ) {
            my $sec_ok = $self->chk_y( $sec_prefix . '_read', $sec_id );
            my $domain_ok = 1;
            if ( $sec_ok ) {
                eval {
                    my $d = CTX->lookup_action('dicole_domains');
                    $domain_ok = ( $sec_prefix eq 'user' ) ?
                        $d->execute( user_belongs_to_domain => {
                            user_id => $sec_id
                        } ) :
                        $d->execute( group_belongs_to_domain => {
                            group_id => $sec_id
                        } );
                };
            }
            if ( ! $sec_ok || ! $domain_ok ) {
                $tree_element->is_folder( 0 );
                $tree_element->type( 'folder_protected' );
                $tree->remove_element( $tree_element );
                next;
            }
        }

        if ( !$self->files->Fileops->dir_tree_flat
            && -d $file->[2] && $tree_element->folder_is_open
        ) {
            $self->read_dir_tree( $tree, $tree_element, $file->[2], $sort, $root );
        }
    }
    return $tree;
}

sub get_group_name {
    my ( $self, $id ) = @_;
    my $group_object = CTX->lookup_object( 'groups' )->fetch(
        $id
    );
    my $group_name = $group_object->{name};
    if ( $group_object->{parent_id} ) {
        $group_name = CTX->lookup_object( 'groups' )->fetch(
            $group_object->{parent_id}
        )->{name} . ' :: ' . $group_name;
    }
    return $group_name;
}

sub get_user_name {
    my ( $self, $id ) = @_;
    my $user_object = CTX->lookup_object( 'user' )->fetch(
        $id, { skip_security => 1 }
    );
    return $user_object->{login_name};
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFiles - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
