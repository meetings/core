package OpenInteract2::Action::DicoleFeedreader;

use strict;

use base qw(
    Dicole::Action::Common::Add
    Dicole::Action::Common::Edit
);

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::Generictool::Data;
use Dicole::MessageHandler qw( :message );
use XML::RSS;
use XML::OPML;
use XML::Atom::Syndication::Feed;
use Data::Structure::Util;
use MIME::Decoder;
use IO::Scalar;
use LWP::UserAgent;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Format::Mail;
use Dicole::Navigation::Tree;
use Dicole::Navigation::Tree::Element;
use Dicole::Generictool;
use Dicole::Generictool::FakeObject;
use Dicole::Content::Message;
use Dicole::Pathutils;
use Dicole::DateTime;
use Dicole::URL;
use Dicole::Box;
use Encode;
use Encode::Guess qw/iso-8859-1/;
use URI::Escape;
use Dicole::Files::Filesystem;
use Image::Magick;
use Feed::Find;
use Dicole::Content::CategorizedList;
use Dicole::Content::Hyperlink;
use Dicole::Content::Text;
use Dicole::Content::Controlbuttons;
use Dicole::Content::Button;
use Dicole::Content::Formelement;
use Dicole::Content::Horizontal;
use Dicole::Generictool::Browse;
use Dicole::Security qw( :receiver :target :check );
use Dicole::Utils::HTML;
use Digest::SHA1;
use Storable;

use constant DEF_META_MAX_LENGTH => 40;
use constant MAX_NAME_LENGTH => 30;
use constant CONTROL_IMAGE_PATH => "/images/theme/default/navigation/controls";
use constant CONTROL_IMAGE_RES => "20x20";
use constant POSTS_ON_PAGE => 20;
use constant DEFAULT_MAX_ITEMS => 200;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.124 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors( qw( feed ) );

sub _action_add_feedreader_feed {
    my ( $self ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('feeds_users') );
    $data->data_new;

    $data->data->{url} = $self->param('url');
    $data->data->{folder} = $self->param('folder');
    $data->data->{title} = $self->param('title');

    if ( $self->param('target_user_id') ) {
        $self->param('target_type', 'user');
    }
    elsif ( $self->param('target_group_id') ) {
        $self->param('target_type', 'group');
    }

    $self->_pre_save_add( $data, 'skip_secure' );
    $data->data_save;
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
        $items = CTX->lookup_object('feeds_items')->fetch_group( {
            from  => [ 'dicole_feeds_items', 'dicole_feeds_users' ],
            where => 'dicole_feeds_users.feed_id = dicole_feeds_items.feed_id' .
                ' AND dicole_feeds_users.group_id = ?' .
                ' AND ( dicole_feeds_users.exclude_from_digest != ? OR dicole_feeds_users.exclude_from_digest is null )' .
                ' AND dicole_feeds_items.first_fetch_date >= ?' .
                ' AND dicole_feeds_items.first_fetch_date < ?',
            value => [ $group_id, 1, $start_time, $end_time ],
            order => 'dicole_feeds_items.first_fetch_date DESC, ' .
                'dicole_feeds_items.date DESC, ' .
                'dicole_feeds_items.title DESC',
        } ) || [];
    }
    elsif ( $user_id ) {
        $items = CTX->lookup_object('feeds_items')->fetch_group( {
            from  => [ 'dicole_feeds_items', 'dicole_feeds_users' ],
            where => 'dicole_feeds_users.feed_id = dicole_feeds_items.feed_id' .
                ' AND dicole_feeds_users.user_id = ?' .
                ' AND ( dicole_feeds_users.exclude_from_digest != ? OR dicole_feeds_users.exclude_from_digest is null )' .
                ' AND dicole_feeds_items.first_fetch_date >= ?' .
                ' AND dicole_feeds_items.first_fetch_date < ?',
            value => [ $user_id, 1, $start_time, $end_time ],
            order => 'dicole_feeds_items.first_fetch_date DESC, ' .
                'dicole_feeds_items.date DESC, ' .
                'dicole_feeds_items.title DESC',
        } ) || [];
    }

    if (! scalar( @$items ) ) {
        return undef;
    }

    my $return = {
        tool_name => $self->_msg('Feed reader'),
        items_html => [],
        items_plain => []
    };

    my $server_url = $domain_host;

    my $feed_name_cache = {};

    for my $item ( @$items ) {
        my $date_string = Dicole::DateTime->medium_datetime_format(
            $item->{date}, $self->param('timezone'), $self->param('lang')
        );
        $item->{'link'} = $server_url . $item->{'link'} if $item->{'link'} =~ m{^/};
        $item->{title} = $self->_convert_from_utf8( $item->{title} );

        # Fetch feed title if not in cache
        unless ( $feed_name_cache->{ $item->{feed_id} } ) {
            my $feed = CTX->lookup_object('feeds')->fetch( $item->{feed_id} );
            $feed_name_cache->{ $item->{feed_id} } = $feed->{title};
        }

        my $source = $item->{author};
        $source .= ' - ' if $source;
        $source .= $feed_name_cache->{ $item->{feed_id} };

        $source = $self->_convert_from_utf8( $source );

        push @{ $return->{items_html} },
            '<span class="date">' . $date_string
            . '</span> - <a href="' . $item->{'link'} . '">' . $item->{title}
            . '</a> - <span class="author">' . $source . '</span>';

        push @{ $return->{items_plain} },
            $date_string . ' - ' . $item->{title}
            . ' - ' . $item->{author} . "\n  - " . $item->{'link'};
    }

    return $return;
}

sub _summary_list {
    my ( $self ) = @_;
    my $gid = $self->param('group_id') || 0;
    my $uid = $gid ? 0 : $self->param('user_id');

    my $feeds = CTX->lookup_object( 'feeds_users_summary' )->fetch_group( {
        where => 'group_id = ? AND user_id = ?',
        value => [ $gid, $uid ],
    } ) || [];

    return [ map { $_->{summary} } @$feeds ];
}

sub _ping_feed {
    my ( $self ) = @_;

    my $feed_uri = $self->param('feed_uri');
    $self->log( 'debug', "Pinged $feed_uri" );
    my $feeds = CTX->lookup_object('feeds')->fetch_group( {
        where => 'url = ?',
        value => [ $feed_uri ]
    } ) || [];
    
    for my $feed ( @$feeds ) {
        $feed->{next_update} = 0;
        $feed->save;
    }
}

# Overrides Dicole::Action::CommonSummary
# Customize the summary box to include latest 5
# feed posts based on current date (exclude posts
# that are in the future)
sub summary {
    my ( $self ) = @_;
    my $current_search = $self->param( 'box_param' );
    my $search_type = undef;

    my $is_user = $self->param( 'target_type' ) eq 'user';

    my $url_action =  $is_user ?
        'personal_feed_reader' : 'group_feed_reader';

    my $url_target = $is_user ?
        CTX->request->target_user_id : CTX->request->target_group_id;

    my $title = Dicole::Widget::Horizontal->new;

    if ( !$current_search ) {
        $search_type = 1;
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Feed reader'),
                link => Dicole::URL->create_from_parts(
                    action => $url_action,
                    task => 'feeds',
                    target => $url_target,
                ),
            )  
        );
    }
    elsif ( $current_search =~ /^\d+$/ ) {
        my $object = $self->_get_used_feed_object( $current_search ) || {};

        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $object->title,
                link => Dicole::URL->create_from_parts(
                    action => $url_action,
                    task => 'feeds',
                    target => $url_target,
                    additional => [ $object->folder, $object->id ],
                ),
            )
        );

        $search_type = 2;
    }
    else {
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $current_search,
                link => Dicole::URL->create_from_parts(
                    action => $url_action,
                    task => 'feeds',
                    target => $url_target,
                    additional => [ $current_search ],
                ),
            )
        );

        $search_type = 3;
    }

    my $box = Dicole::Box->new;
    $box->name( $title->generate_content );

    if ( $self->param( 'box_open' ) ) {
        my $recent = $self->_get_summary( $search_type );
        $box->content( $recent );
    }

    return $box->output;
}

sub _get_summary {
    my ( $self, $search_type ) = @_;

    my $query_params = $self->_construct_item_query( $self->param( 'box_param' ) );
    $query_params->{limit} = 5;

    my $iter = CTX->lookup_object('feeds_items')->fetch_iterator( $query_params );

    unless ( $iter->has_next ) {
        return Dicole::Content::Text->new(
            text => $self->_msg( 'No posts.' )
        );
    }

    my $last_month = -1;
    my $last_day = -1;
    my ( $category, $topic );

    my $cl = Dicole::Content::CategorizedList->new;

    # Create a list of posts
    while ( $iter->has_next ) {
        my $post = $iter->get_next;

        my $month = Dicole::DateTime->month_year_long( $post->{date} );
        my $day = Dicole::DateTime->day( $post->{date} );

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

        my $meta = $self->_convert_from_utf8( $post->{author} );
        # If not a certain feed, display source as meta instead
        if ( $search_type != 2 ) {
            my $source = $self->_convert_from_utf8( $post->feeds->{title} );
            $meta = $meta ? $meta . ' @ ' . $source : $source;
        }
        # Cut the filename shorter if it's too long
        my $meta_max_length = $self->param( 'meta_max_length' ) || DEF_META_MAX_LENGTH;
        if ( length( $meta ) > $meta_max_length ) {
            $meta = substr( $meta, 0, $meta_max_length ) . '..';
        }

        $cl->add_entry(
            topic => $topic,
            elements => [ {
               width => '100%',
               content => Dicole::Content::Hyperlink->new(
                    text => $meta,
                    content => $self->_convert_from_utf8( $post->{title} ),
                    attributes => {
                        href => $post->{'link'},
                        title => $self->_convert_from_utf8( $post->{title} ),
                    },
                ),
            } ]
        );
    }

    return $cl;
}

# Overrides Dicole::Action
# Override some parameters passed to init_tool
# to include our RSS feed and other stuff
sub init_tool {
    my ( $self, $params ) = @_;
    $params ||= {};
    $self->SUPER::init_tool( {
        tool_args => { feeds => [ {
            type => 'opml',
            url => Dicole::URL->create_from_current(
                    task => 'export_opml',
                    other => [ 'export.opml' ]
                ),
            desc => $self->_msg( 'Export feeds (OPML)' )
        } ] },
        %{ $params }
    } );
}

sub export_opml {
    my ( $self ) = @_;
    my $opml = XML::OPML->new( version => '1.1' );
    $opml->head(
        title => "Dicole OPML export",
        dateCreated => DateTime::Format::Mail->format_datetime( DateTime->now )
    );

    my $target_type = $self->param( 'target_type' );

    my $target = $target_type eq 'user' ?
        CTX->request->target_user_id : CTX->request->target_group_id;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('feeds_users') );
    $data->query_params( {
        where => $target_type . "_id = ?",
        value => [ $target ],
        order => 'folder'
    } );
    $data->data_group;

    my %outline;

    # Push each item into outline and create folders when necessary
    foreach my $user_feed ( @{ $data->data } ) {
        my $feed = $user_feed->feeds;

        my $folder = $user_feed->{folder};
        my $title = $user_feed->{title};

        $folder =~ s/"//gi;
        $title =~ s/"//gi;

        my $item = {
            text => $title,
            title => $title,
            type => 'rss',
            xmlUrl => $feed->{url},
            htmlUrl => $feed->{link},
        };

        if ( $folder ) {
            $outline{ $folder }{ $user_feed->id } = $item;

            unless ( $outline{ $folder }{opmlvalue} eq 'embed' ) {
                $outline{ $folder }{opmlvalue} = 'embed';
                $outline{ $folder }{text} = $folder;
            }
        }
        else {
            $outline{ $user_feed->id } = $item;
        }
    }

    $opml->add_outline(
        opmlvalue => 'embed',
        text => 'Feeds',
        %outline
    );

    CTX->response->content_type( 'text/xml' );
    CTX->controller->no_template( 'yes' );
    return $opml->as_string;
}

# Replace inherited methods in Common::Add

sub _post_init_common_add {
    my ( $self ) = @_;
    $self->_make_select_menu( 'folder' );
    if ( CTX->request->param( 'discovered_url' ) ) {
        my $field = $self->gtool->get_field( 'url' );
        $field->use_field_value( 1 );
        $field->value( CTX->request->param( 'discovered_url' ) );
        Dicole::MessageHandler->add_message( MESSAGE_WARNING,
            $self->_msg( 'You are adding a pre-defined feed. Please select a folder for the feed.' )
        );
    }
}

sub _common_buttons_add {
    my ( $self ) = @_;
    $self->SUPER::_common_buttons_add;
    $self->gtool->add_bottom_button(
        type => 'link',
        value => $self->_msg( 'Discover feeds' ),
        link => Dicole::URL->create_from_current(
            task => 'discover',
        )
    );
    $self->gtool->add_bottom_button(
        type => 'link',
        value => $self->_msg( 'Import' ),
        link => Dicole::URL->create_from_current(
            task => 'import_opml',
        )
    );
}

sub _pre_save_add {
    my ( $self, $data, $skip_secure ) = @_;

    # Remove potential whitespace
    $data->data->{url} =~ s/\s//g;

    # Remove slashes from folders, because the path goes wrong if they are there
    $data->data->{folder} =~ s{/}{}g;

    my $fetch_time = time;

    # Check if feed is valid (i.e, URL is reachable and feed is parseable)
    my $rss = eval{ $self->_if_feed_valid( $data->data->{url}, $skip_secure ) };
    if ( $@ ) {
        if ( $self->can( 'gtool' ) && $self->gtool ) {
            my $field = $self->gtool->get_field( 'url' );
            $field->error( 1 ) if ref $field;
        }

        my $err_msg = $@;
        # We need no stinking line numbers
        $err_msg =~ s{ at /.+$}{};
        $self->log( 'warn', 'Parsing error for feed [' .
            $data->data->{url} . ']:' . $err_msg );

        if ( $self->can( 'tool' ) && $self->tool ) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( "Provided URL is not a valid feed: [_1]",
                    $err_msg )
            );
        }
        return undef;
    }

    # Update feed object in the database
    my $feed = $self->_update_feed_object( $rss, $data->data->{url} );

    # Add items of the feed to its own table
    $self->_add_feed_items( $feed->data, $rss, $fetch_time );

    # Set properties for feeds_users object
    $data->data->{date} = time;
    $data->data->{icon} = $feed->data->{icon};
    $data->data->{feed_id} = $feed->data->id;
    $data->data->{title} ||= $feed->data->{title};

    if ( $self->param( 'target_type' ) eq 'user' ) {
        $data->data->{user_id} = $self->param('target_user_id');
    }
    else {
        $data->data->{group_id} = $self->param('target_group_id');
    }

    # Increment number of observers of the feed before saving
    $feed->data->{observers}++;
    $feed->data_save;

    return 1;
}

sub _post_save_add {
    my ( $self, $data ) = @_;
    return $self->_msg( "Feed ([_1]) successfully added.", $self->_convert_from_utf8( $data->data->{title} ) );
}

# Replace inherited methods in Common::Edit

sub _pre_init_common_edit {
    my ( $self ) = @_;
    $self->_config_tool_edit( 'tab_override', 'feeds' );
    return $self->param( 'used_feed' );
}

sub edit {
    my ( $self ) = @_;

    unless ( $self->_check_if_feed_belongs_to_user ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Access denied.' )
        );
        return CTX->response->redirect( $self->derive_url(
            task => 'feeds'
        ) );
    }
    else {
        return $self->SUPER::edit;
    }
}

sub _post_init_common_edit {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_edit;
    $self->_make_select_menu( 'folder' );
}

sub _pre_save_edit {
    my ( $self, $data ) = @_;
    $data->data_save;
    $self->tool->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Modifications to feed were successfully saved.' )
    );
    return CTX->response->redirect( Dicole::URL->create_from_current(
        task => 'feeds',
        other => [ $data->data->{folder}, $data->data->id ]
    ) );
    return undef;
}

sub import_opml {
    my ( $self ) = @_;
    $self->init_tool( { upload => 1 } );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'file_name' }
        )
    ] );

    # Add fields
    $self->gtool->add_field(
        id  => 'file_name', type => 'file',
        required => 1, desc => $self->_msg( 'OPML file to upload' )
    );

    # Set views
    $self->gtool->current_view( 'upload_file' );
    $self->gtool->set_fields_to_views;

    # Defines submit buttons for our tool
    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' )
    );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $return_code, $return ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );
        if ( $return_code ) {
            my $upload_obj = CTX->request->upload( 'file_name' );
            my $fh = $upload_obj->filehandle;
            my $content;
            {
                local $/;
                $content = <$fh>;
            }
            my $feedcount = eval { $self->_read_opml( $content ) };
            if ( $@ ) {
                my $err_msg = $@;
                # We need no stinking line numbers
                $err_msg =~ s{ at /.+$}{};
                $self->gtool->get_field( 'file_name' )->error( 1 );
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg( "Error reading OPML file: [_1]", $err_msg )
                );
            } else {
                $self->tool->add_message( $return_code,
                    $self->_msg( "Imported [_1] feed(s) from the OPML file.", $feedcount )
                );
            }
        } else {
            $return = $self->_msg( "Upload failed: [_1]", $return );
            $self->tool->add_message( $return_code, $return );
        }
    }

    # Modify tool object to contain our form in a single legend box
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Import OPML file' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    $self->generate_tool_content;
}

sub _read_opml {
    my ( $self, $content ) = @_;

    my $opml = XML::OPML->new;
    eval{ $opml->parse( $content ) };

    if ( $@ ) {
        my $err_msg = $@;
        # We need no stinking line numbers
        $err_msg =~ s{ at /.+$}{};
        die $err_msg;
    }

    my $feedcount = 0;

    # Read each new outline as a top level folder
    # and all subfolders as first level folders.

    for my $folder ( @{ $opml->{outline} } ) {

        $feedcount += $self->_read_opml_folder_recursive( $folder, 0 );

    }

    return $feedcount;
}

sub _read_opml_folder_recursive {
    my ( $self, $folder, $level ) = @_;

    next unless ref( $folder ) eq 'HASH';

    # first level items are placed into the root level (folder '')
    my $foldername = ( $level == 0 ) ? '' : $folder->{title} || $folder->{text};

    my $feedcount = 0;

    while ( my ( $key, $value ) = each %$folder ) {
        next unless ref( $value ) eq 'HASH';

        if ( $value->{opmlvalue} eq 'embed' ) {
            $feedcount += $self->_read_opml_folder_recursive( $value, $level + 1 );
        }
        else {
            my $feed = Dicole::Generictool::Data->new;

            $feed->object( CTX->lookup_object('feeds_users') );
            $feed->data_new;
            $feed->data->{folder} = $foldername;
            $feed->data->{url} = $value->{xmlUrl};
            $feed->data->{title} = $value->{title} || $value->{text};
            $feed->data->{notes} = $value->{description};

            if ( $self->_pre_save_add( $feed ) ) {
                $feed->data_save;
                $feedcount++;
            }
        }
    }

    return $feedcount;
}

sub remove {
    my ( $self ) = @_;

    my $redirect = $self->derive_url(
        task => 'feeds',
    );

    my $current_search = $self->param('used_feed') || $self->param('folder');

    my $ufo = $self->_get_used_feed_object( $self->param('used_feed') );

    unless ( $ufo ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Access denied.' )
        );
        return CTX->response->redirect( $redirect );
    }

    # Fetch also the real feed object through the user feed object
    my $feed = $ufo->feeds;

    # Remove user feed object
    $ufo->remove;

    # Decrease observers. If observers falls to zero, remove feed and items in it
    $feed->{observers}--;
    if ( $feed->{observers} ) {
        $feed->save;
    }
    else {
        my $items_iter = CTX->lookup_object( 'feeds_items' )->fetch_iterator( {
            where => 'feed_id = ?',
            value => [ $feed->id ],
        } );
        while ( $items_iter->has_next ) {
            my $item = $items_iter->get_next;
            $item->remove;
        }
        $feed->remove;
    }
    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Feed successfully removed.' )
    );
    $redirect = Dicole::URL->create_from_current(
        task => 'feeds',
    );

    # Remember to clean the summary entry if one exists
    my $target_type = $self->param( 'target_type' );

    my $target = $target_type eq 'user' ?
        CTX->request->target_user_id : CTX->request->target_group_id;

    my $summary = $target_type eq 'user' ?
        'personal_feed_reader_summary::' : 'group_feed_reader_summary::';

    my $where = 'summary = ? AND ' . $target_type . '_id = ?';

    my $summary_present = CTX->lookup_object( 'feeds_users_summary' )->fetch_group( {
         where => $where,
         value => [ $summary . $current_search, $target ],
         limit => 1,
    } )->[0];
    $summary_present->remove if ref $summary_present;

    return CTX->response->redirect( $redirect );
}

sub mediacast {
    my ( $self ) = @_;

    my $content = "#EXTM3U\n";

    my $current_search = $self->param('used_feed') || $self->param('folder');

    my $iter = CTX->lookup_object('feeds_items')->fetch_iterator(
        $self->_construct_item_query( $current_search, CTX->request->param('feed_search') )
    );
    while ( $iter->has_next ) {
        my $post = $iter->get_next;
        next unless $post->{enclosure};
        $content .= "#EXTINF:-1," . $post->{title} . "\n";
        $content .= $post->{enclosure} . "\n";
    }
    CTX->response->content_type( "audio/x-mpegurl" );
    CTX->response->header( 'Content-Length', length( $content ) );
    my $file_prefix = CTX->server_config->{dicole}{playlist_prefix};
    $file_prefix ||= 'Dicole';
    my $m3u_filename = int rand 1000000;
    CTX->response->header(
        'Content-Disposition',
        "attachment; filename=$file_prefix-$m3u_filename.m3u"
    );
    CTX->controller->no_template( 'yes' );
    return $content;
}

sub feeds {
    my ( $self ) = @_;

    my $used_feed = $self->param( 'used_feed' );
    my $folder = $self->param( 'folder' );
    my $feed_search = CTX->request->param( 'feed_search' );

    # we need this to get browsing right
    if ( $feed_search ) {
        my $url_query = CTX->request->url_query;
        $url_query->{feed_search} = $feed_search;
    }

    my $current_search = $used_feed || $folder;
    my $target_type = $self->param('target_type');

    my $ufo; # Used feed object
    if ( $used_feed ) {
        $ufo = $self->_get_used_feed_object( $used_feed );
        unless ( $ufo ) {
            return CTX->response->redirect(
                $self->derive_url(
                    additional => [ $folder || () ],
                )
            );
        };
    }

    $self->_init_common_tool( {
        tool_config   => {
            cols => 2,
            rows => 3,
            tool_args => {
                form_params => {
                    method => 'post',
                    name => 'Form',
                    action => Dicole::URL->create_full_from_current
                }
            },
        },
        class         => 'feeds',
        skip_security => 1,
        view          => 'feed_details',
    } );

    my $feed_object = undef;
    my $feed_title = undef;
    if ( ! $current_search ) {
        if ( my $category = CTX->request->param( 'category' ) ) {
            $feed_title = $self->_msg( "Latest posts from all feeds based on category [_1]", $category );
        }
        else {
            $feed_title = $self->_msg( "Latest posts from all feeds" );
        }
    }
    # certain feed
    elsif ( $ufo ) {

        $self->init_fields;

        # Tell gtool to skip construction of fields that are empty.
        # We limit the ammount of fields displayed in the profile
        # pages by this way.
        $self->gtool->Construct->undef_if_empty( 1 );

        $feed_object = CTX->lookup_object( 'feeds' )->fetch( $ufo->{feed_id} );

        $self->_convert_from_utf8( $feed_object );

        if ( $target_type eq 'user' || $self->chk_y( 'group_manage' ) ) {

            # Defines edit button
            $self->gtool->add_bottom_button(
                type => 'link',
                value => $self->_msg( 'Edit' ),
                link => $self->derive_url(
                    task => 'edit',
                )
            );
            # Defines remove button
            $self->gtool->add_bottom_button(
                type  => 'confirm_submit',
                value => $self->_msg( 'Remove' ),
                confirm_box => {
                    title => $self->_msg( 'Confirmation' ),
                    name => $current_search,
                    msg   => $self->_msg( 'This feed will be removed from your list of feeds. Are you sure?' ),
                    href  => $self->derive_url(
                        task => 'remove',
                    )
                }
            );
            # Defines refresh button
            $self->gtool->add_bottom_button(
                type => 'link',
                value => $self->_msg( 'Refresh' ),
                link => $self->derive_url(
                    task => 'refresh',
                )
            );
        }

        $self->tool->Container->box_at( 0, 2 )->name( $self->_msg( "Feed details" ) );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            $self->gtool->get_show( object => $feed_object )
        );

        $feed_title = $self->_msg( '[_1] - Readers: [_2] - Updated: [_3]',
            $self->_convert_from_utf8( $ufo->{title} ),
            $feed_object->{observers},
            Dicole::DateTime->short_datetime_format( $feed_object->{updated} )
        );

    }
    # certain folder
    else {
        $feed_title = $self->_msg( "Lastest posts in folder [_1]", $current_search );
    }

    my $bb = Dicole::Content::Controlbuttons->new;

    my ( $feed_content, $enclosure_count ) = $self->_get_feed(
        $current_search, $feed_object, $feed_search
    );

    # Toggling view of certains feeds on the summary page. All feed views (all/folder/feed) supported,
    # expect category.
    unless ( CTX->request->param( 'category' ) ) {

        if ( $target_type eq 'user' || $self->chk_y( 'group_manage' ) ) {

            my $summary_present = $self->_fetch_summary_presence( $current_search );

            unless ( ref $summary_present ) {
                $bb->add_buttons( {
                    type => 'link',
                    value => $self->_msg( 'Show on summary page' ),
                    'link' => $self->derive_url( task => 'toggle_summary' )
                } );
            }
            else {
                $bb->add_buttons( {
                    type => 'link',
                    value => $self->_msg( 'Remove from summary page' ),
                    'link' => $self->derive_url( task => 'toggle_summary' )
                } );
            }
        }
    }

    $bb->add_buttons( {
        type => 'link',
        value => $self->_msg( 'Download playlist' ),
        'link' => $self->derive_url( task => 'mediacast' )
    } ) if $enclosure_count;

    unshift @{ $feed_content }, $bb;

    my $search_box = Dicole::Content::Horizontal->new;
    my $search_field = Dicole::Content::Formelement->new(
        attributes => {
           type      => 'text',
           maxlength => '32',
           size      => '12'
        }
    );
    $search_field->set_name( 'feed_search' );
    $search_field->set_value( $feed_search );
    $search_field->modifyable( 1 );
    $search_box->add_content( $search_field );
    # Add submit button
    $search_box->add_content( Dicole::Content::Button->new(
        name      => 'start_search',
        value     => $self->_msg( 'Search' ),
    ) );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Search' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( $search_box );

    # Fetch users/groups feed tree
    my $tree = $self->_fetch_and_init_feed_tree;

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg("Tree of feeds") );
    $self->tool->Container->box_at( 0, 1 )->add_content( $tree );

    $self->tool->Container->box_at( 1, 0 )->name( $feed_title );
    $self->tool->Container->box_at( 1, 0 )->add_content( $feed_content );

    return $self->generate_tool_content;
}

sub _get_used_feed_object {
    my ( $self, $used_feed ) = @_;

    return undef if $used_feed !~ /^\d+$/;

    my $object = CTX->lookup_object('feeds_users')->fetch( $used_feed );

    my $target_type = $self->param( 'target_type' );

    my $target = $target_type eq 'user' ?
        CTX->request->target_user_id : CTX->request->target_group_id;

    return undef if $object->{$target_type . '_id'} != $target;

    return $object;
}

# This function actually handles the toggling of the feed on the summary page
# based on search criteria
sub toggle_summary {
    my ( $self ) = @_;

    my $current_search = $self->param( 'used_feed') || $self->param( 'folder' );

    my $summary_present = $self->_fetch_summary_presence( $current_search );

    if ( ! ref $summary_present ) {
        my $new_summary = CTX->lookup_object( 'feeds_users_summary' )->new;

        if ( $self->param( 'target_type' ) eq 'user' ) {
            $new_summary->{user_id} = CTX->request->target_user_id;
            $new_summary->{summary} = 'personal_feed_reader_summary::' . $current_search;
        }
        else {
            $new_summary->{group_id} = CTX->request->target_group_id;
            $new_summary->{summary} = 'group_feed_reader_summary::' . $current_search;
        }

        $new_summary->save;
    }
    else {

        $summary_present->remove;
    }
    return CTX->response->redirect( $self->derive_url( task => 'feeds' ) );
}

sub _fetch_summary_presence {
    my ( $self, $current_search ) = @_;

    my $where = 'summary = ?';
    my $value = [];

    if ( $self->param( 'target_type' ) eq 'user' ) {
        $where .= ' AND user_id = ?';
        push @$value, 'personal_feed_reader_summary::' . $current_search;
        push @$value, CTX->request->target_user_id;
    }
    else {
        $where .= ' AND group_id = ?';
        push @$value, 'group_feed_reader_summary::' . $current_search;
        push @$value, CTX->request->target_group_id;
    }

    my $summarys = CTX->lookup_object( 'feeds_users_summary' )->fetch_group( {
        where => $where,
        value => $value,
        limit => 1,
    } );

    return ( $summarys ) ? $summarys->[0] : undef;
}

sub _convert_from_utf8 {
    my ( $self, $content ) = @_;
    # DISABLED AFTER TRANSFORMATIO TO UTF8
    return $content;
}

sub _construct_item_query {
    my ( $self, $userfeed_id, $feed_search ) = @_;

    my $where = 'dicole_feeds_users.feed_id = dicole_feeds_items.feed_id';
    my $value = [];

    if ( $self->param( 'target_type' ) eq 'user' ) {
        $where .= ' AND dicole_feeds_users.user_id = ?';
        push @$value, CTX->request->target_user_id;
    }
    else {
        $where .= ' AND dicole_feeds_users.group_id = ?';
        push @$value, CTX->request->target_group_id;
    }

    # Feed or folder:

    if ( $userfeed_id ) {
        if ( $userfeed_id =~ /^\d+$/ ) {
            $where .= ' AND dicole_feeds_users.userfeed_id = ?';
            push @$value, $userfeed_id;
        }
        else {
            $where .= ' AND dicole_feeds_users.folder = ?';
            $where .= ' AND dicole_feeds_items.date <= ?';
            push @$value, $userfeed_id, time + 60 * 60 * 24;
        }
    }

    # All:

    else {
        if ( my $category = CTX->request->param( 'category' ) ) {
            $where .= ' AND ( dicole_feeds_items.category = ? OR' .
                            ' dicole_feeds_items.subject = ? )';
            push @$value, $category, $category;
        }
        $where .= ' AND dicole_feeds_items.date <= ?';
        push @$value, time + 60 * 60 * 24;
    }

    if ( $feed_search ) {
        $feed_search =~ s/\%/\\%/gm;
        $feed_search =~ s/\_/\\_/gm;
        $where .= " AND ( dicole_feeds_items.content LIKE CONCAT('%', ? ,'%')"
        . " OR dicole_feeds_items.title LIKE CONCAT('%', ? ,'%') )";
        push @$value, ( $feed_search, $feed_search );
    }

    return {
        from  => [ 'dicole_feeds_items', 'dicole_feeds_users' ],
        where => $where,
        value => $value,
        order => 'dicole_feeds_items.date DESC, dicole_feeds_items.title DESC',
    };
}

sub _get_feed {
    my ( $self, $userfeed_id, $feed_object, $feed_search ) = @_;

    my $query_params = $self->_construct_item_query( $userfeed_id, $feed_search );

    $self->gtool( Dicole::Generictool->new(
            object => CTX->lookup_object('feeds_items'),
            skip_security => 1,
            current_view => 'feeds',
    ) );

    $self->init_fields;

    # For counting enclosures
    my $enclosure_count = undef;

    # If it's not pointing directly to a certain feed, display a link to each
    # feed
    my $show_feed_link = 0;
    $show_feed_link = 1 unless $userfeed_id =~ /^\d+$/;

    if ( $show_feed_link ) {
        $self->gtool->add_field(
            id => 'feed_url', type => 'textfield',
            use_field_value => 1, link_field => 'feed_url',
            link_noescape => 1, link => 'IDVALUE',
            desc => $self->_msg( 'From' )
        );
        $self->gtool->set_fields_to_views;
    }

    my $content = [];

    # Add some feed info and image if exists
    if ( ref $feed_object ) {
        push @{ $content }, Dicole::Content::Image->new(
            src   => $feed_object->{image_url},
            href  => $feed_object->{image_link},
            title => $feed_object->{image_title},
            class => 'feedImage'
        ) if $feed_object->{image_url};
        push @{ $content }, Dicole::Content::Text->new(
            text => $feed_object->{description},
            no_filter => 1,
            attributes => { class => 'feedDescription' }
        ) if $feed_object->{description};
    }

    my $feed_cache = {};

    my $limit_query = undef;
    my $browse = Dicole::Generictool::Browse->new( {
        action => [
            # Make browse page unique. Number of additionals + last additional should be
            # unique
            CTX->request->action_name . scalar( @{ $self->target_additional } ),
            $self->target_additional->[-1] ]
    } );
    $browse->default_limit_size( POSTS_ON_PAGE );
    $browse->set_limits;
    my $order = $query_params->{order};
    delete $query_params->{order};
    my $total_count = CTX->lookup_object('feeds_items')->fetch_count( $query_params );
    $query_params->{order} = $order;
    $browse->total_count( $total_count );
    $query_params->{limit} = $browse->get_limit_query;

    # If total number of objects is less that limit start,
    # we are out of bounds. In that case, sets limit start to be
    # the last available page
    if ( $total_count && $total_count <= $browse->limit_start ) {

        my $pages = int( $total_count / $browse->limit_size );
        $browse->set_limits(
            ( $pages * $browse->limit_size )
            - $browse->limit_size
        );
        $query_params->{limit} = $browse->get_limit_query;
    }

    my $browse_content = $browse->get_browse;
    push @{ $content }, $browse_content if ref $browse_content;

    my $iter = CTX->lookup_object('feeds_items')->fetch_iterator(
        $query_params
    );

    # Create a list of posts
    while ( $iter->has_next ) {
        my $post = $iter->get_next;
        my $message = Dicole::Content::Message->new;

        $self->_convert_from_utf8( $post );

        my $encoded_link = URI::Escape::uri_escape( $post->{'link'} );
        my $encoded_title = URI::Escape::uri_escape( $post->{title} );

        $message->title( $post->{title} );
        $message->title_url( $post->{'link'} );

        # IM this
        $message->add_controls( Dicole::Content::Image->new(
            src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/aim.gif',
            href => 'aim:goim?message='
                . $encoded_link . '%20(' . $encoded_title . ')',
            width => '20',
            height => '20',
            title => $self->_msg( "IM this" )
        ) );

        # Email this
        $message->add_controls( Dicole::Content::Image->new(
            src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/email.gif',
            href => 'mailto:?SUBJECT='
                . $encoded_title . '&BODY=' . $encoded_link,
            width => '20',
            height => '20',
            title => $self->_msg( "Email this" )
        ) );

        # Technorati this
        $message->add_controls( Dicole::Content::Image->new(
            src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/technorati.gif',
            href => 'http://www.technorati.com/cosmos/search.html?url=' . $encoded_link,
            href_target => '_blank',
            width => '20',
            height => '20',
            title => $self->_msg( "Technorati this" )
        ) );

        $message->date(
            Dicole::DateTime->long_datetime_format( $post->{date} )
        );
        $message->author_name( $post->{author} );

        $message->add_message( Dicole::Content::Text->new(
            text => $post->{content},
            no_filter => 1
        ) );


        # If we are displaying posts from all kinds of feeds,
        # we will need a link to each feed based on post
        if ( $show_feed_link ) {
            my $field = $self->gtool->get_field( 'feed_url' );
            unless ( $feed_cache->{$post->{feed_id}} ) {
                my $target_type = $self->param( 'target_type' );
                my $where = 'feed_id = ? AND ' . $target_type . '_id = ?';

                my $target = $target_type eq 'user' ?
                    CTX->request->target_user_id : CTX->request->target_group_id;
                my $value = [ $post->{feed_id}, $target ];

                $feed_cache->{$post->{feed_id}} = CTX
                    ->lookup_object( 'feeds_users' )->fetch_group( {
                        where => $where,
                        value => $value,
                        limit => 1,
                    } )->[0];
            }
            my $object = $feed_cache->{$post->{feed_id}};
            $field->value( $self->_convert_from_utf8( $object->{title} ) );
            $post->{feed_url} = Dicole::URL->create_from_current(
                other => [ $object->{folder}, $object->id ]
            );
        }

        # Replace links with hyperlinks
        foreach my $field_id ( @{ $self->gtool->visible_fields } ) {
            if ( $post->{$field_id} =~ m{^\s*\w+://} ) {
                my $field = $self->gtool->get_field( $field_id );
                next if $field->link;
                $field->link( $post->{$field_id} );
                $field->use_field_value( 1 );
                $field->value( $self->_msg( 'Link' ) );
            }
        }

        # Use generictool to generate post metadata fields
        my $metas = $self->gtool->construct_fields(
            $post, $self->gtool->visible_fields
        );
        my $i = 0;
        foreach my $field_id ( @{ $self->gtool->visible_fields } ) {
            $i++;
            next unless $post->{$field_id};
            my $field = $self->gtool->get_field( $field_id );
            $message->add_meta( $field->desc, $metas->[$i-1] );
        }
        $enclosure_count++ if $post->{enclosure};
        push @{ $content }, $message;
    }
    unless ( scalar @{ $content } ) {
        push @{ $content }, Dicole::Content::Text->new(
            text => $self->_msg( 'No posts.' )
        );
    }
    else {
        my $browse_content = $browse->get_browse;
        push @{ $content }, $browse_content if ref $browse_content;
    }
    return $content, $enclosure_count;
}

sub _fetch_and_init_feed_tree {
    my ( $self ) = @_;

    my $target = $self->param( 'target_type' ) eq 'user' ?
        CTX->request->target_user_id : CTX->request->target_group_id;

    my $tree = Dicole::Navigation::Tree->new(
        root_name     => $self->_msg( 'Feeds' ),
        url_base_path => $target,
        tree_id       => 'feeds',
        no_new_root   => 1,
        id_path       => 1,
    );
    $self->_create_tree( $tree, $target );
    $tree->init_tree;

    return $tree->get_tree;
}

sub _create_tree {
    my ( $self, $tree, $target ) = @_;

    my $last_folder = undef;
    my $current_parent = undef;

    my $pathutils = Dicole::Pathutils->new;
    $pathutils->url_base_path( $target );
    my $current_path = $pathutils->get_current_path;

    my $column = $self->param( 'target_type' ) eq 'user' ? 'user_id' : 'group_id';

    my $iter = CTX->lookup_object('feeds_users')->fetch_iterator( {
        where => "$column = ?",
        value => [ $target ],
        order => 'folder, title',
    } );

    while ( $iter->has_next ) {
        my $feed = $iter->get_next;

        if ( ! $feed->{folder} ) {
            $current_parent = undef;
        }
        elsif ( $last_folder ne $feed->{folder} ) {
            $current_parent = Dicole::Navigation::Tree::Element->new(
                element_id => $feed->{folder},
                name => $self->_max_name_length( $feed->{folder} ),
                is_folder => 1
            );

            $tree->add_element( $current_parent );

            my $element_path = $current_parent->element_path_as_string;

            # Open folder if it is below our current path
            if ( ! $current_parent->folder_is_open ) {
                # "cleaning" needed for comparison
                my $ep = $pathutils->clean_location( $element_path ) .'/';
                $current_parent->open_folder if
                    index($current_path,$ep) == 0;
            }
        }

        my $type = 'document';

        if ( $feed->{icon} ) {
            $tree->icon_files( { $feed->id => 'feeds/' . $feed->{icon} } );
            $type = $feed->id;
        }

        my $element = Dicole::Navigation::Tree::Element->new(
            parent_element => $current_parent,
            element_id => $feed->id,
            name => $self->_max_name_length( $feed->{title} ),
            type => $type,
        );
        $tree->add_element( $element );

        $last_folder = $feed->{folder};
    }
}

sub _max_name_length {
    my ( $self, $string ) = @_;
    
    # DISABLED and transformed after translation to utf8
    return Dicole::Utils::Text->shorten( $string, MAX_NAME_LENGTH );
    
    if ( length( $string ) > MAX_NAME_LENGTH ) {
        $string = substr( $string, 0, MAX_NAME_LENGTH ) . '...';
    }

    my $utf8 = eval { Encode::Guess::decode("Guess", $string) };
    if ( $@ ) {
        $utf8 = Encode::decode_utf8( $string );
    }
    $string = Unicode::MapUTF8::from_utf8( {
       -string => $utf8, -charset => 'iso-8859-1'
    } );

    return $string;
}

sub discover {
    my ( $self ) = @_;

    # Init tool
    $self->init_tool( { tab_override => 'add' } );

    $self->tool->Path->add(
        name => $self->_msg( 'Discover feeds' )
    );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );
    $self->gtool->disable_search( 1 );
    $self->gtool->disable_browse( 1 );
    $self->gtool->current_view( 'discover' );

    my $discover_url = CTX->request->param( 'discover' );

    my $feeds = [];
    if ( $discover_url ) {
        my $i = 0;
        $discover_url = 'http://' . $discover_url unless $discover_url =~ /^.+\:\/\//;
        # Find each feed in the provided URL and construct a list of objects
        # out of them, each linking to the add page
        my @feeds = Feed::Find->find( $discover_url );
        foreach my $feed_url ( @feeds ) {
            my $rss = eval{ $self->_if_feed_valid( $feed_url ) };
            next if $@;
            $i++;
            my $feed = Dicole::Generictool::FakeObject->new( { id => 'feed_id' } );
            $feed->{title} = $self->_convert_from_utf8( $rss->{channel}{title} );
            $feed->{description} = $self->_convert_from_utf8( $rss->{channel}{description} );
            $feed->{version} = $self->_convert_from_utf8( $rss->{_internal}{version} );
            $feed->{url} = $feed_url;
            push @{ $feeds }, $feed;
        }
        unless ( $i ) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( "No feeds found on the given address." )
            );
            return CTX->response->redirect( Dicole::URL->create_from_current );
        }
        $self->tool->add_message( MESSAGE_SUCCESS,
            $self->_msg( "Found [_1] potential feeds. Click the feed title to add it.", $i )
        );
        # Add fields
        $self->gtool->add_field(
            id  => 'title', type => 'textfield',
            desc => $self->_msg( 'Title' ),
            link_field => 'url',
            link => Dicole::URL->create_from_current(
                task => 'add',
                params => { discovered_url => 'IDVALUE' }
            )
        );
        $self->gtool->add_field(
            id  => 'description', type => 'textarea',
            desc => $self->_msg( 'Description' )
        );
        $self->gtool->add_field(
            id  => 'version', type => 'textfield',
            desc => $self->_msg( 'Version' )
        );
        $self->gtool->add_bottom_button(
            type => 'link',
            value => $self->_msg( 'New search' ),
            link => Dicole::URL->create_from_current(
                task => 'discover',
            )
        );
    }
    else {
        push @{ $feeds }, Dicole::Generictool::FakeObject->new( {
            id => 'feed_id'
        } );
        $self->gtool->add_field(
            id  => 'discover', type => 'textfield', required => 1,
            desc => $self->_msg( 'URL where to search for feeds' ),
        );
        $self->gtool->add_bottom_button(
            name => 'submit',
            value => $self->_msg( 'Search' ),
        );
    }

    $self->gtool->add_bottom_button(
        type => 'link',
        value => $self->_msg( 'Back to add form' ),
        link => Dicole::URL->create_from_current(
            task => 'add',
        )
    );

    # Set views
    $self->gtool->set_fields_to_views( no_sortable => 1 );

    # Lets fake we are a fake object
    $self->gtool->fake_objects( $feeds );

    # Generate box with a list view
    if ( $discover_url ) {
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( "Discovered feeds" ) );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            $self->gtool->get_list
        );
    }
    else {
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( "Discover feeds" ) );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            $self->gtool->get_add
        );
    }

    return $self->generate_tool_content;

}

sub bookmarklets {
    my ( $self ) = @_;

    # Init tool
    $self->init_tool( { tab_override => 'add' } );

    $self->tool->Path->add(
        name => $self->_msg( 'Bookmarklets' )
    );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );
    $self->gtool->current_view( 'bookmarklets' );

    my $server_url = Dicole::Pathutils->new->get_server_url;
    $server_url .= Dicole::URL->create_from_current(
        task => 'discover'
    );

    $self->gtool->add_field(
        id  => 'text', type => 'text',
        desc => '',
        use_field_value => 1, value => $self->_msg( 'You may use these bookmarklets to subscribe to a website which has a feed available. To install the bookmarklet, add the bookmarklet link to your bookmarks. To use it, simply just click the bookmark when you are on a page you want to subscribe with.' ),
    );

    # Add a basic bookmarklet which is able to traverse through frames and popup a new window with an URL
    # of the current page
    $self->gtool->add_field(
        id  => 'default_bookmarklet', type => 'textfield',
        desc => $self->_msg( 'Bookmarklet' ),
        use_field_value => 1, value => $self->_msg( 'Subscribe with feed reader' ),
        link_noescape => 1,
        'link' => "javascript:location.href='$server_url?discover='+escape(window.location.href)",
#        'link' => "javascript:(function(){function traverse(w){try{
#open('$server_url?discover='+escape(w.location.href),'_blank');for(var i=0;
#i<w.frames.length;i++){traverse(w.frames[i])}}catch(e){}}traverse(window)})()"
    );

    # Set views
    $self->gtool->set_fields_to_views;

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [ Dicole::Generictool::FakeObject->new( {
        id => 'feed_id'
    } ) ] );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( "Available bookmarklets" ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_show
    );

    return $self->generate_tool_content;

}

sub user_shared_weblogs {
    my ( $self ) = @_;
    return $self->_shared_weblogs( 0 );
}

sub group_shared_weblogs {
    my ( $self ) = @_;
    return $self->_shared_weblogs( 1 );
}

sub _shared_weblogs {
    my ( $self, $group ) = @_;

    $self->init_tool( { rows => 2 } );

    my $aid = $self->_fetch_collection_id(
        archetype => 'user_weblog_user' );
    my $tid = $self->_fetch_collection_id(
        archetype => 'user_weblog_topic_reader' );

    my $shared_sec = [];
    my $securities = [];
    if ( $group ) {
        $securities = CTX->lookup_object('dicole_security')->fetch_group( {
            where => 'receiver_group_id = ? AND ' .
                    '( collection_id = ? OR collection_id = ? )',
            value => [
                $self->param('target_group_id'), $aid, $tid
            ],
            order => 'target_user_id DESC, collection_id ASC',
        } ) || [];
        $shared_sec = CTX->lookup_object('dicole_security')->fetch_group( {
            where => '( receiver_type = ? OR receiver_type = ? ) AND ' .
                    '( collection_id = ? OR collection_id = ? )',
            value => [
                RECEIVER_LOCAL, RECEIVER_GLOBAL, $aid, $tid
            ],
            order => 'target_user_id DESC, collection_id ASC',
        } ) || [];
    }
    else {
        $securities = CTX->lookup_object('dicole_security')->fetch_group( {
            where => 'receiver_user_id = ? AND ' .
                    '( collection_id = ? OR collection_id = ? )',
            value => [
                $self->param('target_user_id'), $aid, $tid
            ],
            order => 'target_user_id DESC, collection_id ASC',
        } ) || [];
        $shared_sec = CTX->lookup_object('dicole_security')->fetch_group( {
            where => '( receiver_type = ? OR receiver_type = ? ) AND ' .
                    '( collection_id = ? OR collection_id = ? )',
            value => [
                RECEIVER_LOCAL, RECEIVER_GLOBAL, $aid, $tid
            ],
            order => 'target_user_id DESC, collection_id ASC',
        } ) || [];
    }

    my $user_class = CTX->lookup_object( 'user' );
    my $topic_class = CTX->lookup_object( 'weblog_topics' );

    my %added = ();

    my $limited_users = [];
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        if ( $group ) {
            $limited_users = $dicole_domains->execute( 'users_by_group', {
                group_id => $self->param('target_group_id')
            } );
        }
        else {
            $limited_users = $dicole_domains->execute( 'users_by_user', {
                user_id => $self->param('target_user_id')
            } );
        }
    }

    my @real_securities = ();

    for my $sec ( @$securities ) {
        my $uid = $sec->target_user_id;
        if ( @{ $limited_users } > 0 ) {
            next unless ( grep { $_ == $uid } @{ $limited_users } ) > 0;
        }
        push @real_securities, $sec;
    }

    my @real_shared_sec = ();

    for my $sec ( @$shared_sec ) {
        my $uid = $sec->target_user_id;
        if ( @{ $limited_users } > 0 ) {
            next unless ( grep { $_ == $uid } @{ $limited_users } ) > 0;
        }
        push @real_shared_sec, $sec;
    }

    my $user_hash = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => [ @real_securities, @real_shared_sec ],
        link_field => 'target_user_id',
        object => $user_class,
    );

    my $topic_hash = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => [ @real_securities, @real_shared_sec ],
        link_field => 'target_object_id',
        object => $topic_class,
    );




    for ( [ 0, \@real_securities ], [ 1, \@real_shared_sec ] ) {
        my $boxrow = $_->[0];
        my $secs = $_->[1];

        my $listing = Dicole::Widget::Listing->new();

        $listing->add_key( content => $self->_msg( 'User' ) );
        $listing->add_key( content => $self->_msg( 'Topic' ) );
        $listing->add_key( content => '' );

        my $added_blogs = 0;
        for my $sec ( @$secs ) {
            my $uid = $sec->target_user_id;
            my $user = $user_hash->{ $uid };
            next if ! $user; # user might have been deleted ;)

            $added_blogs++;

            my $topic_name;
            my $topic_id;

            if ( my $oid = $sec->{target_object_id} ) {
                my $topic = $topic_hash->{ $oid };

                next if ! $topic;
                $topic_name = $topic->name;
                $topic_id = $topic->id;
            }
            else {
                $topic_name = $self->_msg( 'All topics' );
                $topic_id = 0;
            }

            next if $added{$uid}{$topic_id};
            $added{$uid}{$topic_id}++;

            my @add = ( $self->language );
            push @add, $topic_id if $topic_id;
            push @add, 'feed.rdf';

            my $sub_url = Dicole::URL->create_from_parts(
                action => $group ? 'group_feed_reader' : 'personal_feed_reader',
                task => 'add',
                target => $group ? $self->param('target_group_id') :
                    $self->param('target_user_id'),
                params => {
                    discovered_url => Dicole::URL->create_from_parts(
                        action => 'personal_weblog',
                        task => $topic_id ? 'feed_topic' : 'feed',
                        target =>  $uid,
                        additional => \@add,
                    ),
                },
            );

            my $comment_sub_url = Dicole::URL->create_from_parts(
                action => $group ? 'group_feed_reader' : 'personal_feed_reader',
                task => 'add',
                target => $group ? $self->param('target_group_id') :
                    $self->param('target_user_id'),
                params => {
                    discovered_url => Dicole::URL->create_from_parts(
                        action => 'personal_weblog',
                        task => $topic_id ?
                            'comment_feed_topic' : 'comment_feed',
                        target =>  $uid,
                        additional => \@add,
                    ),
                },
            );

            my $l = qq{javascript:void(window.open('/profile_popup/professional/}.
                    $uid . qq{', 'profile', 'toolbar=no,menubar=no,} .
                    qq{statusbar=no,scrollbars=yes,width=640,height=480'))};

            $listing->add_row(
                { content => Dicole::Widget::Hyperlink->new(
                    content => $user->{first_name} . ' ' . $user->{last_name},
                    link => $l,
                ) },
                { content => Dicole::Widget::Hyperlink->new(
                    content => $topic_name,
                    link => Dicole::URL->create_from_parts(
                        action => 'personal_weblog',
                        task => 'posts',
                        target =>  $uid,
                        additional => $topic_id ? [ $topic_id ] : [],
                    ),
                ) },
                { content => Dicole::Widget::Hyperlink->new(
                    content => $self->_msg('Subscribe'),
                    link => $sub_url
                ) },
                { content => Dicole::Widget::Hyperlink->new(
                    content => $self->_msg('Subscribe comments'),
                    link => $comment_sub_url
                ) },
            );
        }

        next if ! $added_blogs;

        my $box = $self->tool->Container->box_at( 0, $boxrow );

        $box->name( $boxrow == 0 ? $group ?
            $self->_msg( 'Blogs shared directly to this group' ) :
            $self->_msg( 'Blogs shared directly to you' ) :
            $self->_msg( 'Publicly available blogs' )
        );
        $box->add_content(
            [ $listing ]
        );
    }

    return $self->generate_tool_content;
}

sub _check_if_feed_belongs_to_user {
    my ( $self ) = @_;

    my $id = $self->param( 'used_feed' );

    return undef unless $id =~ /^\d+$/;

    my $object = CTX->lookup_object( 'feeds_users' )->fetch( $id );

    if ( ref $object ) {

        if ( $self->param( 'target_type' ) eq 'user' ) {
            return $object if $object->{user_id} == CTX->request->target_user_id;
        }
        else {
            return $object if $object->{group_id} == CTX->request->target_group_id;
        }
    }
    return undef;
}

sub refresh {
    my ( $self ) = @_;

    my $feed = $self->_check_if_feed_belongs_to_user;

    unless ( $feed ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Access denied.' )
        );
        return CTX->response->redirect( $self->derive_url(
            task => 'feeds'
        ) );
    }
    else {
        # From user feed object to feed object itself
        $feed = $feed->feeds;
    }

    my $rss = eval{ $self->_if_feed_valid( $feed->{url}, 1 ) };

    # Might be a good idea to store the error somewhere, someday ;)
    if ( $@ ) {
        $self->log( 'warn', 'Error when updating feed [' . $feed->{url} . ']:' . $@ );
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error when updating feed ([_1]): [_2]', $feed->{url}, $@ )
        );
        return CTX->response->redirect( $self->derive_url(
            task => 'feeds'
        ) );
    }
    else {
        # Update feed object and add new feed items
        my $fetch_time = time;
        $self->_update_feed_object( $rss, $feed->{url} );
        $self->_add_feed_items( $feed, $rss, $fetch_time );

        # Remove old items that cross the max items limit
        my $items_iter = CTX->lookup_object('feeds_items')->fetch_iterator( {
            where => 'feed_id = ?',
            value => [ $feed->id ],
            order => 'date DESC, item_id DESC',
        } );
        my $i = 0;
        while ( $items_iter->has_next ) {
            $i++;
            my $item = $items_iter->get_next;
            my $max_items = CTX->server_config->{dicole}{feed_max_items}
                || DEFAULT_MAX_ITEMS;
            if ( $i > $max_items ) {
                $item->remove;
            }
        }
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Feed successfully updated.' )
        );

    }

    return CTX->response->redirect( $self->derive_url(
        task => 'feeds'
    ) );
}

# Creates or updates the feed object
sub _update_feed_object {
    my ( $self, $rss, $url ) = @_;

    # If feed exists in database, do nothing. If not, create one
    my $feed = undef;
    $feed = $self->_get_feed_object( $url );
    unless ( ref $feed ) {
        $feed = Dicole::Generictool::Data->new;
        $feed->object( CTX->lookup_object('feeds') );
        $feed->data_new;
        # Save data, we need the ID
        $feed->data_save;
    }

    # Resolve and save icon
    if ( my $icon_content = $self->_get_feed_icon( $url ) ) {
        CTX->lookup_directory( 'dicole_feed_icons' ) || die 'dicole_feed_icons directory not set in server.ini!';
        my $files = Dicole::Files::Filesystem->new;
        my $image = Image::Magick->new( magick => 'ico' );
        $image->BlobToImage( $icon_content );
        $image->Set( magick => 'gif' );
        if ( ref( $image->[0] ) ) {
            $image->[0]->Resize(
                width => '16', height => '16',
                filter => 'Cubic'
            ) unless $image->[0]->Get( 'width' ) == 16;
            my $new_filename = $feed->data->id . '.gif';
            my $full_icon_path = CTX->lookup_directory( 'dicole_feed_icons' )
                . '/' . $new_filename;
            # If old icon exists, replace it
            if ( $files->check_existence( $full_icon_path ) ) {
                $files->delete( $full_icon_path );
            }
            if ( my $image_content = $image->[0]->ImageToBlob ) {
                $files->mkfile(
                    $new_filename,
                    $image_content, 1,
                    CTX->lookup_directory( 'dicole_feed_icons' )
                );
                $feed->data->{icon} = $new_filename;
            }
        }
    }

    # Map some matching fields
    foreach my $field (
        qw( title description language copyright generator )
    ) {
        $feed->data->{$field} = $rss->{channel}{$field};
    }

    # Combine RSS properties skipDays and skipHours as one epoch time
    if ( exists $rss->{skipDays} ) {
        $feed->data->{skip_time} += ( $rss->{skipDays} * 60 * 60 * 24 );
    }
    if ( exists $rss->{skipHours} ) {
        $feed->data->{skip_time} += ( $rss->{skipHours} * 60 * 60 );
    }

    # Some feeds have icons
    if ( exists $rss->{image} ) {
        $feed->data->{image_link} = $rss->{image}{'link'};
        $feed->data->{image_title} = $rss->{image}{'title'};
        $feed->data->{image_url} = $rss->{image}{'url'};
    }

    # Support for embedded Creative Commons licensing
    my $ccmod = 'http://backend.userland.com/creativeCommonsRssModule';
    if ( exists $rss->channel->{$ccmod} ) {
        $feed->data->{cc_license_url} = $rss->channel->{$ccmod}{license};
    }

    # Save feed object itself
    $feed->data->{url} = $url;
    $feed->data->{managing_editor} = $rss->{channel}{managingEditor};
    $feed->data->{web_link} = $rss->{channel}{'link'};
    $feed->data->{webmaster} = $rss->{channel}{webMaster};
    $feed->data->{version} = $rss->{_internal}{version};

    my $time = time;
    $feed->data->{updated} = $time;
    $feed->data->{update_interval} ||= 3600;
    $feed->data->{failed_attempts} = 0;
    $feed->data->{next_update} = $time + $feed->data->{update_interval};

    $feed->data_save;
    return $feed;
}

# Takes a feed item SPOPS object as an parameter and returns an ID
# for easy identification
sub _get_item_unique_id_hash {
    my ( $self, $feed_item ) = @_;
    return $feed_item->{uid_hash} if $feed_item->{uid_hash};
    
    my $id = $feed_item->{guid};
    $id ||= $feed_item->{'link'} if length( $feed_item->{'link'} ) > 10;
    $id ||= $feed_item->{title} . $feed_item->{date};
    
    $Storable::canonical = 1;
    return Digest::SHA1::sha1_hex( Storable::freeze( [ $id ] ) );
}

sub _get_item_content_hash {
    my ( $self, $feed_item ) = @_;
    return $feed_item->{content_hash} if $feed_item->{content_hash};
    
    my $content = '';
    for my $key ( sort keys %$feed_item ) {
        next if $key eq 'item_id';
        next if $key eq 'last_update_date';
        next if $key =~ /_hash/;
        $content .= $feed_item->{$key};
    }

    $Storable::canonical = 1;
    return Digest::SHA1::sha1_hex( Storable::freeze( [ $content ] ) );
}

sub _add_feed_items {
    my ( $self, $feed, $rss, $fetch_time ) = @_;

    $fetch_time ||= time;

    # Create a lookup array for checking if the item already exists or not.
    # For this purpose we use get_item_unique_id to come up with an identification
    # code that should be fairly accurate in identifying if a feed item already
    # exists or not.
    my %processed_uids = ();
    my %lookup_item = ();
    my $old_items = CTX->lookup_object('feeds_items')->fetch_group( {
        where => 'feed_id = ?',
        value => [ $feed->id ],
    } ) || [];
    for my $object ( @$old_items ) {
        $lookup_item{ $self->_get_item_unique_id_hash( $object ) } = $object;
    }

    foreach my $item ( @{ $rss->{items} } ) {
        my $feed_item = Dicole::Generictool::Data->new;
        $feed_item->object( CTX->lookup_object('feeds_items') );
        $feed_item->data_new;
        $feed_item->data->{content} = $item->{description};
        # Support for content RSS extension
        foreach my $key ( keys %{ $item } ) {
            next unless ref( $item->{$key} ) eq 'HASH';
            next unless exists $item->{$key}{encoded};
            $feed_item->data->{content} = $item->{$key}{encoded};
        }
        $feed_item->data->{feed_id} = $feed->id;
        $feed_item->data->{date} = $item->{pubDate};

        # Loop some fields that are identical
        foreach my $item_field (
            qw( category comments title link source author guid )
        ) {
            $feed_item->data->{$item_field} = $item->{$item_field};
        }

        # Enclosure might contain an MP3 or such enclosed with the item
        if ( ref( $item->{enclosure} ) eq 'HASH' ) {
            $feed_item->data->{enclosure} = $item->{enclosure}{url};
            $feed_item->data->{enclosure_type} = $item->{enclosure}{type};
        }

        # If Dublin Core metadata is present, use it to fill empty fields
        if ( ref( $item->{dc} ) ) {
            $feed_item->data->{author} ||= $item->{dc}{creator};
            $feed_item->data->{author} ||= $item->{dc}{publisher};
            $feed_item->data->{enclosure_type} ||= $item->{dc}{'format'};
            $feed_item->data->{source} ||= $item->{dc}{source};
            $feed_item->data->{date} ||= $item->{dc}{date};
            foreach my $field ( qw( subject description publisher contributor
                type format identifier source language relation coverage rights
            ) ) {
                $feed_item->data->{$field} = $item->{dc}{$field};
            }
        }

        if ( $feed_item->data->{date} ) {
            # Convert date to EPOCH
            my $new_date = 0;

            $new_date = eval{ DateTime::Format::ISO8601->parse_datetime(
                $feed_item->data->{date}
            )->epoch };
            # Some implement date incorrectly as RFC-2822
            if ( $@ ) {
                $new_date = eval{ DateTime::Format::Mail->parse_datetime(
                    $feed_item->data->{date}
                )->epoch };
            }
            $feed_item->data->{date} = $new_date;
        }
        else {
            $feed_item->data->{date} = 0;
        }

        # Force protocol in front of fields that contain links
        foreach my $link ( qw( link enclosure comments ) ) {
            next unless $feed_item->data->{$link};
            $feed_item->data->{$link} =~ s/^\s*(.*?)\s*$/$1/s;
            $feed_item->data->{$link} = $self->_force_protocol_in_links(
                $feed_item->data->{$link}, $rss
            );
        }

        # Save the feed item if it doesn't exist / is modified
        my $new = $feed_item->data;
        my $newuid = $self->_get_item_unique_id_hash( $new );

        if ( $processed_uids{ $newuid } ) {
            # Ignore item if one with the same uid has already been processed
            # Otherwise this creates stupid update loops
        }
        if ( my $old = $lookup_item{ $newuid } ) {

            $new->{first_fetch_date} = $old->{first_fetch_date};
            $new->{date} ||= $new->{first_fetch_date};

            # Check if item has changed and update old if it has
            my $newhash = $self->_get_item_content_hash( $new );
            my $oldhash = $self->_get_item_content_hash( $old );
            
            if ( $newhash ne $oldhash ) {
                for my $key ( keys %$old ) {
                    next if $key eq 'item_id';
                    next if $key eq 'last_update_date';
                    $old->{ $key } = $new->{ $key };
                }
                
                $old->{last_update_date} = $fetch_time;
                $old->{uid_hash} = $newuid;
                $old->{content_hash} = $newhash;
                $old->save;
            }
            
            $processed_uids{ $newuid } = 1;
        }
        else {
            $new->{first_fetch_date} = $fetch_time;
            $new->{last_update_date} = $fetch_time;
            $new->{date} ||= $new->{first_fetch_date};
            $new->{uid_hash} = $newuid;
            $new->{content_hash} = $self->_get_item_content_hash( $new );
            $feed_item->data_save;
            
            $processed_uids{ $newuid } = 1;
        }
    }

}

sub _force_protocol_in_links {
    my ( $self, $link, $rss ) = @_;

    # If link doesn't begin with a protocol,
    # discover the potential prefix for the link
    unless ( $link =~ m{^\w+://} ) {
        if ( $rss->{channel}{'link'} =~ m{^\w+://} ) {
            $link = $rss->{channel}{'link'} . $link;
        }
    }
    return $link;
}

sub _get_feed_icon {
    my ( $self, $url ) = @_;
    my $ua = LWP::UserAgent->new;

    # Modify to include the path to favicon
    $url =~ s{^(\w+://.*?)/.*}{$1/favicon.ico};

    $ua->agent( 'Dicole Feed Reader' );
    $ua->timeout( $self->param( 'request_timeout' ) || 60 );
    my $response = $ua->get( $url );

    if ( !$response->is_success
        || $response->header('Content-Type') !~ /^image/
    ) {
        return undef;
    }

    return $response->content;
}

sub _if_feed_valid {
    my ( $self, $url, $skip_secure ) = @_;

    # let errors of this pop up
    my $content = $self->_fetch_feed_content( $url, $skip_secure );

    my $rss = XML::RSS->new( version => '2.0' );

    # Detect Atom and map it as an XML::RSS object
    if ( $content =~ /<feed(\s.*?)?>/ims ) {
        my $atom = eval {
            XML::Atom::Syndication::Feed->new( Stream => \$content );
        };

        # Prevent X::A::S::F from leaking memory
        Data::Structure::Util::circular_off( $atom );

        if ( $@ ) {
            my $err_msg = $@;
            $err_msg =~ s{ at /.+$}{};
            die $self->_msg( 'Unable to parse Atom feed: [_1]', $err_msg );
        }

        my %channel = ();
        $channel{title} = $self->_atom_text_to_text( $atom->title );
        $channel{tagline} = $self->_atom_text_to_text( $atom->subtitle );
        $channel{copyright} = $self->_atom_text_to_text( $atom->rights );
        $channel{link} = $atom->link->href if ref ( $atom->link );
        $channel{generator} = $atom->generator->agent if
            ref ( $atom->generator );
        $channel{managingEditor} = $atom->author->name if
            ref(  $atom->author );

        $rss->channel( %channel );

        for my $entry ( $atom->entries ) {
            my %item = ();
            $item{title} = $self->_atom_text_to_utf8_text( $entry->title );
            $item{link} = $entry->link->href if ref( $entry->link );
            $item{author} = $entry->author->name if ref( $entry->author );
            $item{pubDate} = $entry->published;
            $item{id} = $entry->id;
            $item{description} = $self->_atom_content_to_utf8_text(
                $entry->content
            );
            $item{description} ||= $self->_atom_text_to_utf8_text(
                $entry->summary
            );

            $rss->add_item( %item );
        }

        # this because it is stored to the database - quite useless ;)
        $rss->{_internal}{version} = '0.3';
    }
    else {
        eval{ $rss->parse( $content ) };
        if ( $@ ) {
            my $err_msg = $@;
            $err_msg =~ s{ at /.+$}{};
            die $self->_msg( 'Unable to parse RSS feed: [_1]', $err_msg );
        }
    }

    return $rss;
}

sub _atom_text_to_utf8_text {
    my $self = shift @_;
    return Encode::encode_utf8( $self->_atom_text_to_text( @_ ) );
}

sub _atom_text_to_text {
    my ( $self, $atom_text ) = @_;

    my $value = $self->_atom_common_to_text( $atom_text );

    # fall back to body content
    return defined( $value ) ? $value : $atom_text->body;
}

sub _atom_content_to_utf8_text {
    my $self = shift @_;
    return Encode::encode_utf8( $self->_atom_content_to_text( @_ ) );
}

sub _atom_content_to_text {
    my ( $self, $atom_content ) = @_;

    my $value = $self->_atom_common_to_text( $atom_content );

    return $value if defined $value;

    # content might be mime encoded
    if ( my $type = $atom_content->type ) {
#         my $decoder = MIME::Decoder->new( $type ) ||
#             return 'Unsupported mime type';
#         my $in_data = $atom_content->body;
#         my $in_fh = new IO::Scalar \$in_data;
#         my $out_data = '';
#         my $out_fh = new IO::Scalar \$out_data;
#         eval { $decoder->decode( $in_fh, $out_fh ) };
#         if ( $@ ) {
#             return 'Error while parsing MIME data: ' . $@;
#         }
#         else {
#             return $out_data;
#         }
        return 'MIME encoded content is not supported';
    }
    # if $type is empty, content should be text
    else {
        return $atom_content->body;
    }
}

sub _atom_common_to_text {
    my ( $self, $atom_common ) = @_;
    return '' unless ref $atom_common;

    my $type = $atom_common->type;

    if ( $type && $type =~ /^x?html$/i ) {
        my $value = Dicole::Utils::HTML->strip_scripts( $atom_common->body );
        return defined( $value ) ? $value : '';
    }
    elsif ( $type && lc( $type ) eq 'text' ) {
        my $value = $atom_common->body;
        return defined( $value ) ? $value : '';
    }
    else {
        return undef;
    }
}

sub _fetch_feed_content {
    my ( $self, $url, $skip_secure ) = @_;

    if ( $url =~ /^http/ ) {
        my $ua = LWP::UserAgent->new;
        $ua->agent( 'Dicole Feed Reader' );
        $ua->timeout( $self->param( 'request_timeout' ) || 60 );

        my $response = $ua->get( $url );

        unless ( $response->is_success ) {
            die $response->status_line;
        }

        return $response->content;
    }
    elsif ( $url =~ /^\// ) {

        my $action = $self->_create_url_action( $url, $skip_secure );

        die 'No valid task found' unless $action;

        return $action->execute;
    }
    else {
        die 'No valid task found';
    }
}

# Get feed object based on URL
sub _get_feed_object {
    my ( $self, $url ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('feeds') );
    $data->query_params( {
        where => 'url = ?',
        value => [ $url ]
    } );
    if ( $data->total_count ) {
        $data->data_group;
        $data->data( $data->data->[0] );
        return $data;
    }
    return undef;
}

sub _make_select_menu {
    my ( $self, $field ) = @_;

    my $class = $self->gtool->object;
    my $field_object = $self->gtool->get_field( $field );
    return unless ref( $field_object );
    my $where = 'user_id = ?';
    my $value = CTX->request->auth_user_id;
    if ( $self->param( 'target_type' ) eq 'group' ) {
        $where = 'group_id = ?';
        $value = CTX->request->target_id;
    }
    $field_object->mk_dropdown_options(
        class => $class,
        params => {
            where => $where,
            value => [ $value ],
            order => $field
        },
        content_field => $field,
        value_field => $field,
        distinct => 1
    );
}

# Find the action and target from a relative url
# Task, target and aditional are set into the action.

sub _create_url_action {
    my ( $self, $url, $skip_secure ) = @_;

    my $ar = OpenInteract2::ActionResolver->new('dicole_actionresolver');
    my $action = $ar->resolve( undef, $url );

    return undef if ! $action || ! $action->task;

    $action->skip_secure( $skip_secure );

    return $action;
}

sub _fetch_collection_id {
    my ( $self, %p ) = @_;

    my $collection = CTX->lookup_object( 'dicole_security_collection' )->fetch_group( {
        where => 'archetype = ? AND allowed = ?',
        value => [ $p{archetype}, CHECK_YES ],
        limit => 1,
    } );

    return $collection->[0]->id;
}


1;
