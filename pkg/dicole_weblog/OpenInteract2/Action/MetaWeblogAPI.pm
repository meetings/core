package OpenInteract2::Action::MetaWeblogAPI;

use strict;
use base qw(
    Dicole::Action
    Dicole::Security::Checker
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Security qw( :receiver :target :check );
use Dicole::URL;
use Dicole::Security::Checker;
use RPC::XML;
use DateTime;
use Dicole::Utility;
use DateTime::Format::ISO8601;
#use Unicode::MapUTF8;
use Dicole::Utils::HTML;
use Dicole::Utils::Domain;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors( qw( sec_checker ) );

sub _encode {
    my ( $self, $content, $to ) = @_;
    
    # Just return after the translation to utf-8
    return $content;
}

# blogger.newPost
# Description: Creates a new post, and optionally publishes it.
# Parameters: String appkey, String blogid, String username, String password, String content, boolean publish
#
# Return value: on success, String postid of new post; on failure, fault
#
# --------------
# metaWeblog.newPost
# Description: Creates a new post, and optionally publishes it.
# Parameters: String blogid, String username, String password, struct content, boolean publish
#
# Return value: on success, String postid of new post; on failure, fault
#
# Notes: the struct content can contain the following standard keys:
#
#   title, for the title of the entry;
#   description, for the body of the entry;
#   dateCreated, to set the created-on date of the entry.
#
# In addition, Movable Type's implementation allows you to pass in values for five other keys:
#
#   int mt_allow_comments, the value for the allow_comments field;
#   int mt_allow_pings, the value for the allow_pings field;#
#   String mt_convert_breaks, the value for the convert_breaks field;
#   String mt_text_more, the value for the additional entry text;
#   String mt_excerpt, the value for the excerpt field;
#   String mt_keywords, the value for the keywords field;
#   and array mt_tb_ping_urls, the list of TrackBack ping URLs for this entry.
#
# If specified, dateCreated should be in ISO.8601 format.

sub newPost {
    my ( $self ) = @_;
    my $method = CTX->controller->method;
    shift @{ $self->param( 'rpc_params' ) } if $method =~ /^blogger/i;

    my ( $blogid, $user, $pass, $content, $publish ) = @{ $self->param( 'rpc_params' ) };

    my ( $blog_type, $blog_id, $seed_id ) = split /_/, $self->_encode( $blogid );

    unless ( $blog_type eq 'group' ) {
        die CTX->controller->throw_fault( 802, "No such blog" );
    }

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $title = '?';
    my $post_content = '';
    my $time = time();

    if ( ref( $content ) eq 'HASH' ) {
        if ( $content->{title} ) {
            $title = Dicole::Utils::HTML->html_to_text( $self->_encode( $content->{title} ) );
        }
        if ( $content->{dateCreated} ) {
            my $dt = eval { DateTime::Format::ISO8601->parse_datetime( $content->{dateCreated} ) };
            if ( $@ ) {
                my ( $date, $hours ) = split /T/, $content->{dateCreated};
                $dt = eval { DateTime::Format::ISO8601->parse_datetime( $date ) };
                $dt = DateTime::Format::ISO8601->new( base_datetime => $dt );
                $dt = eval { $dt->parse_datetime( $hours ) };
                $dt = DateTime->now unless $dt;
            }
            $time = $dt->epoch;
        }
        $post_content = $self->_encode( $content->{description} || $content->{mt_excerpt} );
    }
    else {
        $post_content = $self->_encode( $content );
    }

    my $entry = CTX->lookup_action('blogs_api')->e( create_entry => {
        user_id => $user_object->id,
        group_id => $blog_id,
        seed_id => $seed_id,
        content => $post_content,
        title => $title,
        creation_date => $time,
#        last_updated => $time,
        tags => [],
#        domain_id => Dicole::Utils::Domain->guess_current_id(),
        published => 1,
    } );

    unless ( $entry ) {
        return 'unknown error';
    }

    my $post = CTX->lookup_action('blogs_api')->e( post_for_entry => { entry => $entry } );

    $self->log( 'info',
        'Saved new post with id [' . $post->id . ']'
    );

    return RPC::XML::string->new( $post->id );

}

# blogger.editPost
# Description: Updates the information about an existing post.
# Parameters: String appkey, String postid, String username, String password, String content, boolean publish
#
# Return value: on success, boolean true value; on failure, fault
#
# --------------
# metaWeblog.editPost
# Description: Updates information about an existing post.
# Parameters: String postid, String username, String password, struct content, boolean publish
#
# Return value: on success, boolean true value; on failure, fault
#
# Notes: the struct content can contain the following standard keys:
#
#   title, for the title of the entry;
#   description, for the body of the entry;#
#   dateCreated, to set the created-on date of the entry.
#
# In addition, Movable Type's implementation allows you to pass in values for five other keys:
#
#   int mt_allow_comments, the value for the allow_comments field;
#   int mt_allow_pings, the value for the allow_pings field;
#   String mt_convert_breaks, the value for the convert_breaks field;
#   String mt_text_more, the value for the additional entry text;
#   String mt_excerpt, the value for the excerpt field;
#   String mt_keywords, the value for the keywords field;
#   array mt_tb_ping_urls, the list of TrackBack ping URLs for this entry.
#
# If specified, dateCreated should be in ISO.8601 format.

sub editPost {
    my ( $self ) = @_;

    my $method = CTX->controller->method;
    shift @{ $self->param( 'rpc_params' ) } if $method =~ /^blogger/i;

    my ( $postid, $user, $pass, $content, $publish ) = @{ $self->param( 'rpc_params' ) };

    $postid =~ tr/[0-9]//cd;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch( $postid );

    eval { $self->_check_post_item( $post, 'user_edit', 'group_edit' ) };
    return $@ if $@;

    my $entry = $self->_entry_for_post_id( $post->id );
    return "entry does not exist" unless $entry;

    my $title = '?';
    my $post_content = '';
    my $time = time();

    if ( ref( $content ) eq 'HASH' ) {
        if ( $content->{title} ) {
            $title = Dicole::Utils::HTML->html_to_text( $self->_encode( $content->{title} ) );
        }
        if ( $content->{dateCreated} ) {
            my $dt = eval { DateTime::Format::ISO8601->parse_datetime( $content->{dateCreated} ) };
            if ( $@ ) {
                my ( $date, $hours ) = split /T/, $content->{dateCreated};
                $dt = eval { DateTime::Format::ISO8601->parse_datetime( $date ) };
                $dt = DateTime::Format::ISO8601->new( base_datetime => $dt );
                $dt = eval { $dt->parse_datetime( $hours ) };
                $dt = DateTime->now unless $dt;
            }
            $time = $dt->epoch;
        }
        $post_content = $self->_encode( $content->{description} || $content->{mt_excerpt} );
    }
    else {
        $post_content = $self->_encode( $content );
    }

    CTX->lookup_action('blogs_api')->e( update_entry => {
        entry => $entry,
        content => $post_content,
        title => $title,
        creation_date => $time,
    } );

    $self->log( 'info',
        'Edited post with id [' . $post->id . ']'
    );

    return RPC::XML::boolean->new( 'true' );
}

sub _set_categories_by_name { return 1;
    my ( $self, $post, $categories ) = @_;

    if ( $categories->[0] =~ /\/\|\-/ ) { # Check for /|- (Deepest sender)
        $categories = [ split /\/\|\-/, $categories->[0] ];
    }

    my $blog_topics = eval { CTX->lookup_object( 'weblog_topics' )->fetch_group( {
        where => 'user_id = ? AND groups_id = ?',
        value => [ $post->{user_id}, $post->{groups_id} ]
    } ) };

    if ( $@ ) {
        $self->log( 'warn',
            'Error fetching weblog post categories: ' . $@
        );
        return 0;
    }

    my $new_topics = [];

    foreach my $category ( @{ $categories } ) {
        $category = $self->_encode( $category );
        my ( $found_topic ) = grep { $_->{name} eq $category ? $_ : undef } @{ $blog_topics };
        if ( ref $found_topic ) {
            push @{ $new_topics }, $found_topic->id;
        }
    }

    $self->log( 'info',
        'Setting post [' . $post->id . '] categories to [' . join( ', ', @{$new_topics} ) . ']'
    );

    Dicole::Utility->renew_links_to(
        object => $post,
        relation => 'weblog_topics',
        new => $new_topics,
    );

    return 1;
}

# blogger.deletePost
# Description: Deletes a post.
# Parameters: String appkey, String postid, String username, String password, boolean publish
#
# Return value: on success, boolean true value; on failure, fault
#

sub deletePost {
    my ( $self ) = @_;

    my ( $appkey, $postid, $user, $pass, $publish ) = @{ $self->param( 'rpc_params' ) };

    $postid =~ tr/[0-9]//cd;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch( $postid );

    eval { $self->_check_post_item( $post, 'user_delete', 'group_delete' ) };
    return $@ if $@;

    $post->remove;
    
    CTX->lookup_action('notify_of_blog_removal')->execute( { post_id => $postid } );

    Dicole::Utility->renew_links_to(
        object => $post,
        relation => 'weblog_topics',
    );
    my $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
        where => 'post_id = ?',
        value => [ $postid ]
    } );
    foreach my $comment ( @{ $comments } ) {
        $comment->remove;
    }

    $self->log( 'info',
        'Deleted post with id [' . $postid . ']'
    );

    return RPC::XML::boolean->new( 'true' );
}

# metaWeblog.getPost
# Description: Returns information about a specific post.
# Parameters: String postid, String username, String password
#
# Return value: on success, struct containing
#
#   String userid,
#   ISO.8601 dateCreated
#   String postid
#   String description
#   String title
#   String link
#   String permaLink
#   String mt_excerpt
#   String mt_text_more
#   int mt_allow_comments
#   int mt_allow_pings
#   String mt_convert_breaks
#   String mt_keywords;
#
# on failure, fault
#
# Notes: link and permaLink are both the URL pointing to the archived post.
# The fields prefixed with mt_ are Movable Type extensions to the metaWeblog.getPost API.

sub getPost {
    my ( $self ) = @_;

    my ( $postid, $user, $pass ) = @{ $self->param( 'rpc_params' ) };

    $postid =~ tr/[0-9]//cd;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch( $postid );

    my ( $user_post, $target_id ) = eval { $self->_check_post_item( $post, 'user_read', 'group_read' ) };
    return $@ if $@;

#     my $action = 'group_weblog';
#     if ( $user_post ) {
#         $action = 'personal_weblog';
#     }
# 
#     my $link = Dicole::URL->get_server_url . Dicole::URL->create_from_parts(
#         action => $action,
#         task => 'show',
#         target => $target_id,
#         additional => [ 0, $post->id ]
#     );
    my $entry = $self->_entry_for_post_id( $post->id );
    die unless $entry;
    
    my $link = Dicole::URL->get_server_url . Dicole::URL->create_from_parts(
        action => 'blogs',
        task => 'show',
        target => $entry->group_id,
        additional => [ $entry->seed_id, $entry->id ],
    );

    my $dt = DateTime->from_epoch( epoch => $post->{date} );
    my $date = $dt->ymd('') . 'T' . $dt->hms;

    $self->log( 'info',
        'Got post with id [' . $post->id . ']'
    );

    my @categories = ();
#     foreach my $topic ( @{ $post->weblog_topics } ) {
#       push @categories, $self->_encode( $topic->{name}, 'to' );
#     }
    my $content = $self->_process_outgoing_content(
        $post->{content}, $post, $entry, $user_object, $user, $pass
    );
    
    return {
        userid => RPC::XML::string->new( $post->{user_id} ),
        postid => RPC::XML::string->new( $post->{post_id} ),
        title => RPC::XML::string->new( $self->_encode( $post->{title}, 'to' ) ),
        dateCreated => RPC::XML::datetime_iso8601->new( $date ),
        description => RPC::XML::string->new( $self->_encode( $content, 'to' ) ),
        'link' => $link,
        permaLink =>$link,
        categories => \@categories,
        mt_excerpt => $self->_encode( $post->{abstract}, 'to' ),
        mt_text_more => '',
        mt_allow_comments => 1,
        mt_allow_pings => 0,
        mt_convert_breaks => '',
        mt_keywords => ''
    };
}

sub _check_post_item {
    my ( $self, $post, $auth_user, $auth_group ) = @_;
    my ( $user, $target_id );
    if ( $post->{user_id} ) {
        unless ( $self->sec_checker->schk_y( 'OpenInteract2::Action::Weblog::' . $auth_user, $post->{user_id} ) ) {
            $self->log( 'warn',
                'Authentication failed to access post id [' . $post->id . ']'
            );
            die CTX->controller->throw_fault( 120, "Authentication failed to access blog post id [" . $post->id . "]" );
        }
        $user = 1;
        $target_id = $post->{user_id};
    }
    elsif ( $post->{groups_id} ) {
        unless ( $self->sec_checker->schk_y( 'OpenInteract2::Action::Weblog::' . $auth_group, $post->{groups_id} ) ) {
            $self->log( 'warn',
                'Authentication failed to access post id [' . $post->id . ']'
            );
            die CTX->controller->throw_fault( 120, "Authentication failed to access blog post id [" . $post->id . "]" );
        }
        $user = 0;
        $target_id = $post->{groups_id};
    }
    else {
        die CTX->controller->throw_fault( 806, "No such item" );
    }
    return ( $user, $target_id );
}

# metaWeblog.newMediaObject
# Description: Uploads a file to your webserver.
# Parameters: String blogid, String username, String password, struct file
#
# Return value: URL to the uploaded file.
#
# Notes: the struct file should contain two keys:
#
#   base64 bits (the base64-encoded contents of the file)
#   String name (the name of the file).
#   The type key (media type of the file) is currently ignored by MT
#

sub newMediaObject {
    my ( $self ) = @_;
    my $method = CTX->controller->method;
    shift @{ $self->param( 'rpc_params' ) } if $method =~ /^blogger/i;

    my ( $blogid, $user, $pass, $struct ) = @{ $self->param( 'rpc_params' ) };

    my ( $blog_type, $blog_id, $seed_id ) = split /_/, $self->_encode( $blogid );

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;
    
    # use the user object to attach temporary files to
    my $attachment = eval {
        CTX->lookup_action('attachment')->execute( store_from_bits => {
            bits => $struct->{bits},
            filename => $struct->{name},
            mime => $struct->{type},
            object => $user_object,
            user_id => $user_object->id,
            group_id => $blog_id,
            owner_id => $user_object->id,
        } );
    };
    return $@ if $@;
    
    return {
        url => Dicole::URL->get_server_url . Dicole::URL->from_parts(
            action => 'blogs',
            task => 'temp_attachment',
            target => $blog_id,
            additional => [ $user_object->id, $attachment->id, $attachment->filename ],
        )
    };
}

# blogger.getRecentPosts
# Description: Returns a list of the most recent posts in the system.
# Parameters: String appkey, String blogid, String username, String password, int numberOfPosts
#
# Return value: on success, array of structs containing
#
#   ISO.8601 dateCreated
#   String userid
#   String postid
#   String content
#
# on failure, fault
#
# Notes: dateCreated is in the timezone of the weblog blogid
#
# --------------
# metaWeblog.getRecentPosts
# Description: Returns a list of the most recent posts in the system.
# Parameters: String blogid, String username, String password, int numberOfPosts
#
# Return value: on success, array of structs containing
#
#   ISO.8601 dateCreated
#   String userid
#   String postid
#   String description
#   String title
#   String link
#   String permaLink
#   String mt_excerpt
#   String mt_text_more
#   int mt_allow_comments
#   int mt_allow_pings
#   String mt_convert_breaks
#   String mt_keywords
#
# on failure, fault
#
# Notes: dateCreated is in the timezone of the weblog blogid;
# link and permaLink are the URL pointing to the archived post
#

sub getRecentPosts {
    my ( $self, $titles_only ) = @_;

    my $method = CTX->controller->method;
    shift @{ $self->param( 'rpc_params' ) } if $method =~ /^blogger/i;

    my ( $blogid, $user, $pass, $numposts ) = @{ $self->param( 'rpc_params' ) };

    $numposts =~ tr/[0-9]//cd;
    $numposts ||= undef;

    my ( $blog_type, $blog_id, $seed_id ) = split /_/, $blogid;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $posts = [];

    my ( $sec, $action, $where );
#     if ( $blog_type eq 'user' ) {
#         $sec = 'user_read';
#         $action = 'personal_weblog';
#         $where = 'user_id = ?';
#     }
    if ( $blog_type eq 'group' ) {
#         $sec = 'group_read';
#         $action = 'group_weblog';
#         $where = 'groups_id = ?';
    }
    else {
        return CTX->controller->throw_fault( 10, "Invalid blog type [$blog_type]" );
    }

    if ( $self->sec_checker->schk_y( 'OpenInteract2::Action::DicoleBlogs::read', $blog_id ) ) {
        my $entries = CTX->lookup_object( 'blogs_entry' )->fetch_group( {
            where => 'group_id = ? AND user_id = ?' .
                ( $seed_id ? ' AND seed_id = ?' : '' ),
            value => [ $blog_id, $user_object->id, $seed_id ? ( $seed_id ) : () ],
            order => 'date DESC',
            limit => $numposts
        } ) || [];
        
            
        my $blog_posts = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
            from_elements => $entries,
            link_field => 'post_id',
            object_name => 'weblog_posts',
        );
        
        foreach my $entry ( @{ $entries } ) {
            my $post = $blog_posts->{ $entry->post_id };
            
            next if $post->{removal_date_enable} && $post->{removal_date} < time;
            
            my $content = $self->_process_outgoing_content(
                $post->{content}, $post, $entry, $user_object, $user, $pass
            );

            my $link = Dicole::URL->get_server_url . Dicole::URL->create_from_parts(
                action => 'blogs',
                task => 'show',
                target => $blog_id,
                additional => [ $entry->seed_id, $entry->id ]
            );
            my $dt = DateTime->from_epoch( epoch => $post->{date} );
            my $date = $dt->ymd('') . 'T' . $dt->hms;
            my %post_struct = (
                userid => RPC::XML::string->new( $post->{user_id} ),
                postid => RPC::XML::string->new( $post->{post_id} ),
                title => RPC::XML::string->new( $self->_encode( $post->{title}, 'to' ) ),
                dateCreated =>RPC::XML::datetime_iso8601->new( $date )
            );
            unless ( $titles_only ) {
                my @categories = ();
#                 foreach my $topic ( @{ $post->weblog_topics } ) {
#                   push @categories, $self->_encode( $topic->{name}, 'to' );
#                 }
                %post_struct = ( %post_struct, (
                    description => RPC::XML::string->new( $self->_encode( $content, 'to' ) ),
                    'link' => $link,
                    permaLink => $link,
                    categories => \@categories,
                    mt_excerpt => $self->_encode( $post->{abstract}, 'to' ),
                    mt_text_more => '',
                    mt_allow_comments => 1,
                    mt_allow_pings => 0,
                    mt_convert_breaks => '',
                    mt_keywords => ''
                ) );
            }
            push @{ $posts }, \%post_struct;
        }
    }

    $self->log( 'info',
        'Retrieved post ids [' . join( ', ', map { $_->{postid} } @{$posts} ) . ']'
    );

    return $posts;
}

# metaWeblog.getCategories
# metaWeblog.getCategories (blogid, username, password) returns struct
# The struct returned contains one struct for each category, containing the following elements:
# description, htmlUrl and rssUrl.

# This entry-point allows editing tools to offer category-routing as a feature.

sub getCategories { return [];
    my ( $self, $mt_list ) = @_;

    my ( $blogid, $user, $pass ) = @{ $self->param( 'rpc_params' ) };

    my ( $blog_type, $blog_id ) = split /_/, $blogid;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $categories = [];

    my ( $sec, $action, $where );
    if ( $blog_type eq 'user' ) {
        $sec = 'user_read';
        $action = 'personal_weblog';
        $where = 'user_id = ?';
    }
    elsif ( $blog_type eq 'group' ) {
        $sec = 'group_read';
        $action = 'group_weblog';
        $where = 'groups_id = ?';
    }
    else {
        return CTX->controller->throw_fault( 10, "Invalid blog type [$blog_type]" );
    }

    if ( $self->sec_checker->schk_y( 'OpenInteract2::Action::Weblog::' . $sec, $blog_id ) ) {
        my $topics = CTX->lookup_object( 'weblog_topics' )->fetch_group( {
            where => $where,
            value => [ $blog_id ]
        } );
        foreach my $topic ( @{ $topics } ) {
            push @{ $categories }, {
                description => RPC::XML::string->new( $self->_encode( $topic->{name}, 'to' ) ),
                htmlUrl => Dicole::URL->get_server_url
                    . Dicole::URL->create_from_parts(
                        action => $action,
                        task => 'posts',
                        target => $blog_id,
                        additional => [ $topic->id ]
                    ),
                rssUrl => Dicole::URL->get_server_url
                    . Dicole::URL->create_from_parts(
                        action => $action,
                        task => 'feed_topic',
                        target => $blog_id,
                        additional => [ $self->language, $topic->id ]
                    ),
                categoryId => RPC::XML::string->new( $topic->id ),
                categoryName => RPC::XML::string->new( $self->_encode( $topic->{name}, 'to' ) )
            };
        }
    }
    else {
        $self->log( 'warn',
            'Authentication failed to access blog id [' . $blogid . ']'
        );
        return CTX->controller->throw_fault( 110, "Authentication failed to access blog id [$blogid]" );
    }

    $self->log( 'info',
        'Retrieved categories [' . join( ', ', map { $_->{categoryId} ? $_->{categoryId} : $_->{description} } @{$categories} ) . ']'
    );

    return $categories;
}

# mt.getRecentPostTitles
# Description: Returns a bandwidth-friendly list of the most recent posts in the system.
# Parameters: String blogid, String username, String password, int numberOfPosts
#
# Return value: on success
#
#   array of structs containing ISO.8601 dateCreated
#   String userid
#   String postid
#   String title
#
# on failure, fault
#
# Notes: dateCreated is in the timezone of the weblog blogid

sub getRecentPostTitles {
    my ( $self ) = @_;
    return $self->getRecentPosts( 1 );
}

# mt.getCategoryList
# Description: Returns a list of all categories defined in the weblog.
# Parameters: String blogid, String username, String password
#
# Return value: on success, an array of structs containing
#
#   String categoryId
#   String categoryName
#
# on failure, fault.

sub getCategoryList {
    my ( $self ) = @_;
    return $self->getCategories( 1 );
}

# mt.getPostCategories
# Description: Returns a list of all categories to which the post is assigned.
# Parameters: String postid, String username, String password
#
# Return value: on success, an array of structs containing
#
#   String categoryName
#   String categoryId
#   and boolean isPrimary
#
# on failure, fault.
#
# Notes: isPrimary denotes whether a category is the post's primary category.
#

sub getPostCategories { return [];
    my ( $self ) = @_;

    my ( $postid, $user, $pass ) = @{ $self->param( 'rpc_params' ) };

    $postid =~ tr/[0-9]//cd;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch( $postid );

    eval { $self->_check_post_item( $post, 'user_read', 'group_read' ) };
    return $@ if $@;

    my $categories = [];
    my $i = 0;
    foreach my $topic ( @{ $post->weblog_topics } ) {
        push @{ $categories }, {
            categoryName => RPC::XML::string->new( $self->_encode( $topic->{name}, 'to' ) ),
            categoryId => RPC::XML::string->new( $topic->id ),
            isPrimary => RPC::XML::boolean->new( $i ? 'false' : 'true' )
        };
        $i++;
    }

    $self->log( 'info',
        'Retrieved category ids [' . join( ', ', map { $_->{categoryId} } @{$categories} ) . ']'
    );

    return $categories;
}

# mt.setPostCategories
# Description: Sets the categories for a post.
# Parameters: String postid, String username, String password, array categories
#
# Return value: on success, boolean true value; on failure, fault
#
# Notes: the array categories is an array of structs containing
#
#   String categoryId
#   boolean isPrimary
#
# Using isPrimary to set the primary category is optional--in the absence of this flag,
# the first struct in the array will be assigned the primary category for the post.

sub setPostCategories {    return RPC::XML::boolean->new( 'true' );

    my ( $self ) = @_;

    my ( $postid, $user, $pass, $categories ) = @{ $self->param( 'rpc_params' ) };

    $postid =~ tr/[0-9]//cd;

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch( $postid );

    eval { $self->_check_post_item( $post, 'user_edit', 'group_edit' ) };
    return $@ if $@;

    # TODO: Check that category IDs exist and match post being edited
    my $new_topics = [];
    foreach my $category ( @{ $categories } ) {
        push @{ $new_topics }, $category->{categoryId};
    }

    Dicole::Utility->renew_links_to(
        object => $post,
        relation => 'weblog_topics',
        new => $new_topics,
    );

    $self->log( 'info',
        'Set category ids [' . join( ', ', @{$new_topics} ) . '] for post [' . $postid . ']'
    );

    return RPC::XML::boolean->new( 'true' );
}

# mt.supportedMethods
# Description: Retrieve information about the XML-RPC methods supported by the server.
# Parameters: none
#
# Return value: an array of method names supported by the server.

sub supportedMethods {
    my ( $self ) = @_;
    return [ qw( newPost editPost deletePost getPost newMediaObject
        getRecentPosts getCategories getRecentPostTitles getCategoryList
        getPostCategories setPostCategories supportedMethods getUserInfo
        supportedTextFilters getTrackbackPings publishPost getUsersBlogs
    ) ];
}

# mt.supportedTextFilters
# Description: Retrieve information about the text formatting plugins supported by the server.
# Parameters: none
#
# Return value: an array of structs containing
#
#   String key
#   String label.
#
# key is the unique string identifying a text formatting plugin, and label is
# the readable description to be displayed to a user. key is the value that
# should be passed in the mt_convert_breaks parameter to newPost and editPost.

sub supportedTextFilters {
    my ( $self ) = @_;
    return [ {
        label => 'Convert Line Breaks',
        key   => '__default__'
    } ];
}

# mt.getTrackbackPings
# Description: Retrieve the list of TrackBack pings posted to a particular entry
# This could be used to programmatically retrieve the list of pings for a particular
# entry, then iterate through each of those pings doing the same, until one has
# built up a graph of the web of entries referencing one another on a particular
# topic.
#
# Parameters: String postid
#
# Return value: an array of structs containing
#
#   String pingTitle (the title of the entry sent in the ping)
#   String pingURL (the URL of the entry)
#   String pingIP (the IP address of the host that sent the ping).

sub getTrackbackPings {
   my ( $self ) = @_;
   return [];
}

# mt.publishPost
# Description: Publish (rebuild) all of the static files related to an entry from
# your weblog. Equivalent to saving an entry in the system (but without the ping).
#
# Parameters: String postid, String username, String password
#
# Return value: on success, boolean true value; on failure, fault

sub publishPost {
   my ( $self ) = @_;
   return RPC::XML::boolean->new( 'true' );
}

# blogger.getUsersBlogs
# Description: Returns a list of weblogs to which an author has posting privileges.
# Parameters: String appkey, String username, String password
#
# Return value: on success, array of structs containing
#
#   String url
#   String blogid
#   String blogName
#
# on failure, fault
# this function allowed me to get w.bloggar and blogbuddy to at least start up so I could test

sub getUsersBlogs {
    my ( $self ) = @_;

    my ( $appkey, $user, $pass ) = @{ $self->param( 'rpc_params' ) };

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;
    
    my $valid_group_ids = eval {
        CTX->lookup_action('dicole_domains')->execute( groups_by_domain => {} )
    };
    my $valid_group_hash = $valid_group_ids ?
        { map { $_ => 1 } @$valid_group_ids } : undef;

    my $blogs = [];

#     if ( $self->sec_checker->schk_y( 'OpenInteract2::Action::Weblog::user_read', $user_object->id ) ) {
#         my $user_name = $user_object->{first_name} . ' ' . $user_object->{last_name};
#         push @{ $blogs }, {
#             'url' => Dicole::URL->get_server_url
#             . Dicole::URL->create_from_parts(
#                 action => 'personal_weblog',
#                 task => 'posts',
#                 target => $user_object->id
#             ),
#             'blogid' => 'user_' . $user_object->id,
#             'blogName' => $self->_encode( $user_name . ' - ' . $self->_msg( 'Weblog' ), 'to' )
#         };
#     }
    my $iter = CTX->lookup_object( 'groups' )->fetch_iterator( {
        from => [ 'dicole_group_user' ],
        where => ' dicole_groups.has_area = ? AND dicole_group_user.user_id = ? AND dicole_group_user.groups_id = dicole_groups.groups_id',
        value => [ 1, $user_object->id ]
    } );
    while ( $iter->has_next ) {
        my $group = $iter->get_next;
        next unless ! $valid_group_hash || $valid_group_hash->{ $group->id };
#        if ( $self->sec_checker->schk_y( 'OpenInteract2::Action::DicoleBlogs::read', $group->id ) ) {
            
            my $seeds = CTX->lookup_object( 'blogs_seed' )->fetch_group( {
                where => 'group_id = ?',
                value => [ $group->id ],
            } ) || [];
            
            for my $seed ( @$seeds ) {
                next if $seed->closed_date > 0;
                push @{ $blogs }, {
                    'url' => Dicole::URL->get_server_url
                    . Dicole::URL->create_from_parts(
                        action => 'blogs',
                        task => 'new',
                        target => $group->id,
                        additional => [ $seed->id ]
                    ),
                    'blogid' => 'group_' . $group->id . '_' . $seed->id,
                    'blogName' => $self->_encode( $group->{name} . ' - ' . $seed->title, 'to' )
                };
            }
            
            push @{ $blogs }, {
                'url' => Dicole::URL->get_server_url
                . Dicole::URL->create_from_parts(
                    action => 'blogs',
                    task => 'new',
                    target => $group->id,
                    additional => [ 0 ]
                ),
                'blogid' => 'group_' . $group->id . '_0',
                'blogName' => $self->_encode( $group->{name} , 'to' )
            };
            
#        }
    }

    CTX->controller->no_decode( 1 );

    $self->log( 'info',
        'Retrieved blog ids [' . join( ', ', map { $_->{blogid} } @{$blogs} ) . ']'
    );

    return $blogs;
}

# blogger.getUserInfo
# Description: Returns information about an author in the system.
# Parameters: String appkey, String username, String password
#
# Return value: on success, struct containing
#
#   String userid
#   String firstname
#   String lastname
#   String nickname
#   String email
#   String url
#
# on failure, fault
#
# Notes: firstname is the Movable Type username up to the first space character,
# and lastname is the username after the first space character.

sub getUserInfo {
    my ( $self ) = @_;

    my ( $appkey, $user, $pass ) = @{ $self->param( 'rpc_params' ) };

    my $user_object = eval { $self->_verify_user( $user, $pass ) };
    return $@ if $@;

    $self->log( 'info',
        'Retrieved user info for user id [' . $user_object->id . ']'
    );

    return {
        userid => $user_object->id,
        firstname => $self->_encode( $user_object->{first_name}, 'to' ),
        lastname => $self->_encode( $user_object->{last_name}, 'to' ),
        nickname => $self->_encode( $user_object->{login_name}, 'to' ),
        email => $self->_encode( $user_object->{email}, 'to' ),
#         url => Dicole::URL->get_server_url
#             . Dicole::URL->create_from_parts(
#                 action => 'profile',
#                 task => 'professional',
#                 target => $user_object->id
#             )
    };
}

sub _verify_user {
    my ( $self, $login_name, $pass ) = @_;

    my $user = eval {
        CTX->lookup_object( 'user' )
           ->fetch_by_login_name( $login_name, { skip_security => 1 } )
    };
    if ( $@ ) {
        $self->log( 'error', "Error fetching user by login name: $@" );
    }

    # Error codes as in Nucleus
    unless ( $user ) {
        $self->log( 'warn', "User with login '$login_name' not found." );
        die CTX->controller->throw_fault( 801, 'Invalid login, please try again' );
    }

    unless ( $user->check_password( $pass ) ) {
        $self->log( 'warn', "Password check for [$login_name] failed" );
        die CTX->controller->throw_fault( 801, 'Invalid login, please try again' );
    }
    $self->log( 'info', 'Passwords matched for user id [' . $user->id . ']' );

    $self->sec_checker( Dicole::Security::Checker->new( $user->id ) );

    return $user;
}

sub _process_outgoing_content {
    my ( $self, $content, $post, $entry, $user_object, $user, $pass ) = @_;

# Enable this when where is a way to strip technorati tags generated by random editors.. ;)
#     my $tags = eval { CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
#         object => $post,
#         group_id => 0,
#         user_id => $user_object->id,
#     } ) } || [];
#
#     $content .= $self->_technorati_tags_html( $tags );

    my $tree = Dicole::Utils::HTML->safe_tree( $content );
    my @imgtags = $tree->look_down( _tag => 'img' );
    
    $_->attr('src', $self->_process_outgoing_image_url( $_->attr('src'), $user, $pass ) ) for @imgtags;
    
    return Dicole::Utils::HTML->tree_guts_as_xml( $tree );
}

sub _process_outgoing_image_url {
    my ( $self, $url, $user, $pass ) = @_;
    
    my $uri = eval { URI->new( $url ) };
    my $host = CTX->request->server_name;
    if ( $uri && $url =~ /https?:\/\/$host(:\d+)?\// ) {
        my %keys = $uri->query_form;
        my @query = $uri->query_form;
        my @new_query = ();
        
        while ( scalar( @query ) )  {
            my $key = shift @query;
            my $value = shift @query;
            next if $key eq 'login_login_name' || $key eq 'login_password';
            push @new_query, ( $key, $value );
        }
        
        push @new_query, ( 'login_login_name', $user );
        push @new_query, ( 'login_password', $pass );
        
        $uri->query_form( \@new_query );
        $url = $uri->as_string;
    }
    
    return $url;
}

# not used yet..
sub _technorati_tags_html {
    my ( $self, $tags ) = @_;
    
    return join( '', map { '<a href="#" rel="tag">'.$_.'</a>' } @$tags );
}

# not used yet..
sub _parse_technorati_tags {
    my ( $self, $html ) = @_;
    
    my $tree = Dicole::Utils::HTML->safe_tree( $html );
    my @ttags = $tree->look_down(
        _tag => 'a', rel => 'tag'
    );
    
    my @tags = ();
    for my $ttag ( @ttags ) {
        my @contents = $ttag->content_list;
        my $tag = '';
        for my $content ( @contents ) {
            $tag .= $content if ! ref( $content );
        }
        $tag = lc ( $tag );
        $tag =~ s/^\s*//;
        $tag =~ s/\s*$//;
        push @tags, $tag if $tag;
    }
    
    return \@tags;
}

sub _process_saved_content {
    my ( $self, $post, $content ) = @_;
    
    my $tree = Dicole::Utils::HTML->safe_tree( $content );
    my @atags = $tree->look_down( _tag => 'a' );
    my @imgtags = $tree->look_down( _tag => 'img' );
    
    $_->attr('href', $self->_process_saved_url( $post, $_->attr('href') ) ) for @atags;
    $_->attr('src', $self->_process_saved_url( $post, $_->attr('src') ) ) for @imgtags;
    
    return Dicole::Utils::HTML->tree_guts_as_xml( $tree );
}

sub _process_saved_url {
    my ( $self, $post, $url ) = @_;
    
    if ( $url =~ /(.*blogs)\/(temp_attachment)\/(\d+)\/(\d+)\/(\d+)\/(.*)/ ) {
        my ( $begin, $attach, $gid, $uid, $aid, $end ) =
            $url =~ /^(.*)\/(temp_attachment)\/(\d+)\/(\d+)\/(\d+)\/(.*)$/;
            
        my $user = CTX->lookup_object('user')->fetch( $uid );
        my $entry = $self->_entry_for_post_id( $post->id );
        $url = join '/', ( $begin, 'attachment', $gid, $entry->id, $aid, $end );
        
        CTX->lookup_action('attachment')->execute( reattach => {
            attachment_id => $aid,
            object => $post,
            user_id => 0,
            group_id => $gid,
        } );
    }
    
    # Strip login name and password
    my $uri = eval { URI->new( $url ) };
    if ( $uri ) {
        my %keys = $uri->query_form;
        if ( $keys{login_login_name} || $keys{login_password} ) {
            my @query = $uri->query_form;
            my @new_query = ();
            while ( scalar( @query ) )  {
                my $key = shift @query;
                my $value = shift @query;
                next if $key eq 'login_login_name' || $key eq 'login_password';
                push @new_query, ( $key, $value );
            }
            $uri->query_form( \@new_query );
            $url = $uri->as_string;
        }
    }

    return $url;
}


sub _entry_for_post_id {
    my ( $self, $post_id ) = @_;
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'post_id = ?',
        value => [ $post_id ],
    } ) || [];
    
    return shift @$entries;
}

1;
