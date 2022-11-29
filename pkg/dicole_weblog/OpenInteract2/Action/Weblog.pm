package OpenInteract2::Action::Weblog;

use strict;
use base qw(
    Dicole::Action
    Dicole::Security::Checker
    Dicole::Action::Common::Summary
    Dicole::Action::Common::Settings
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Content::Message;
use Dicole::Content::List;
use Dicole::Content::Text;
use Dicole::Content::Hyperlink;
use Dicole::Widget::Listing;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::LinkImage;
use Dicole::Widget::Horizontal;
use Dicole::Widget::ContentBox;
#use Dicole::Widget::ConfirmBox;
#use Dicole::Widget::DialogButton;
use Dicole::Utility;
use Dicole::DateTime;
use Dicole::URL;
use Dicole::Content::Button;
use Dicole::Generictool;
use Dicole::Box;
use Dicole::Content::Text;
use Dicole::Feed;
use Dicole::Generictool::Data;
use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );
use Dicole::Utils::HTML;
use Dicole::Utils::SQL;
use Dicole::Utils::SPOPS;
use JSON;

use constant DEFAULT_POSTS_ON_PAGE => 20;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.148 $ =~ /(\d+)\.(\d+)/);

__PACKAGE__->mk_accessors( qw( _personal_summary ) );

sub personal_summary {
    my ( $self ) = @_;
    $self->_personal_summary( 1 );
    return $self->summary;
}

sub group_summary {
    my ( $self ) = @_;
    return $self->summary;
}

# Overrides Dicole::Action::CommonSummary
# Customize the summary box to include latest 5
# weblog posts based on current date (exclude posts
# that are in the future)
sub _summary_customize {
    my ( $self ) = @_;
    my $where = $self->_get_visible_query_limiter( time );
    my $value = [];
    my $title = Dicole::Widget::Horizontal->new;

    if ( $self->_personal_summary ) {
        $where .= ' AND groups_id = 0 AND user_id = ?';
        $value = [ $self->param( 'box_user' ) ];
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Recent blog entries'),
                link => Dicole::URL->create_from_parts(
                    action => 'personal_weblog',
                    task => 'posts',
                    target => CTX->request->target_user_id,
                ),
            )
        );
    }
    else {
        $where .= ' AND groups_id = ?';
        $value = [ $self->param( 'box_group' ) ];
        $title->add_content(
            Dicole::Widget::Hyperlink->new(
                content => $self->_msg('Recent blog entries'),
                link => Dicole::URL->create_from_parts(
                    action => 'group_weblog',
                    task => 'posts',
                    target => CTX->request->target_group_id,
                ),
            )
        );
    }

    return {
        box_title => $title->generate_content,
        object => 'weblog_posts',
        query_options => {
            where => $where,
            value => $value,
            limit => 5,
            order => 'date DESC',
        },
        empty_box => $self->_msg( 'No entries.' ),
    };
}

# modified to
sub _post_data_retrieve {
    my ( $self, $data, $config ) = @_;
    $data ||= [];

    my @ids = map { $_->id } @{ $data };
    my $counts = $self->_count_comments_and_trackbacks( \@ids, time );
    $config->{_item_comment_counts} = $counts;

    return $data;
};

# Modified to add information of number of comments if any
sub _summary_add_item {
    my ( $self, $cl, $topic, $item, $config ) = @_;
    my $title = $item->{ $config->{title_field} };

    my $count = $config->{_item_comment_counts}->{ $item->id };

    if ( $count && $count > 0 ) {
        $title .= ' (' . $count . ')';
    }

    $item->{ $config->{title_field} } = $title;

    $self->SUPER::_summary_add_item( $cl, $topic, $item, $config );
}

# Overrides Dicole::Action::CommonSummary
# Custom summary href to post items
sub _summary_item_href {
    my ( $self, $item ) = @_;
    return Dicole::URL->create_from_current(
        action => $self->_personal_summary ? 'personal_weblog' : 'group_weblog',
        task => 'show',
        additional => [ 0, $item->id ],
    );
}

# Overrides Dicole::Action::CommonSummary
# Defines author for the weblog post
sub _summary_item_author {
    my ( $self, $item ) = @_;
    my $author = $item->writer_user( { skip_security => 1 } );
    return join ' ', ( $author->{first_name}, $author->{last_name} );
}

# Overrides Dicole::Action
# Override some parameters passed to init_tool
# to include our RSS feed and other stuff
sub init_tool {
    my $self = shift;

    my $topic = $self->target_additional->[0];
    undef $topic if $topic !~ /^\d+$/;

    my $task = ($topic) ? 'feed_topic' : 'feed';

    my $feeds = $self->init_feeds(
        task => $task,
        additional => $topic ? [ $topic ] : [],
        dicole_type => 'subentries',
    );

    my $comment_feeds = $self->init_feeds(
        task => 'comment_' . $task,
        additional => $topic ? [ $topic ] : [],
        rss_desc => $self->_msg('Syndication feed (RSS 1.0) for comments'),
        dicole_desc => $self->_msg('Subscribe comments with feed reader'),
        dicole_type => 'subcomments',
    );

    if ( $topic || $self->chk_y( $self->param('target_type') . '_read' )  ) {
        $self->SUPER::init_tool( {
            tool_args => {
                feeds => [
                    $feeds->[0], $comment_feeds->[0],
                ]
            },
            @_,
        } );
    }
    else {
        $self->SUPER::init_tool( { @_ } );
    }

    if ( $self->param('target_type') ne 'group' ) {

        # Fetch profile image and set it as the tool icon
        my $profile = CTX->lookup_object( 'profile' )->fetch_group( {
            where => 'user_id = ?',
            value => [ CTX->request->target_user_id ]
        } );
        my $pro_image = $profile->[0]{pro_image};
        if ( $pro_image ) {
            $pro_image =~ s/(\.\w+)$/_t$1/;
            my @image_path = split m{/}, $pro_image;
            my $icon_name = pop @image_path;
            my $icon_path = join '/', @image_path;
            $self->tool->tool_icon( $icon_name );
            $self->tool->tool_icon_path( $icon_path );
        }

        my $user = CTX->lookup_object( 'user' )->fetch(
          CTX->request->target_user_id, { skip_security => 1 }
        );
        $self->tool->tool_name(
            $self->_generate_blog_name(
                $self->tool->tool_name,
                $user->{first_name} . ' ' . $user->{last_name}
            )
        );
    }
    else {
        $self->tool->tool_name(
            $self->_generate_blog_name(
                $self->tool->tool_name
            )
        );
    }
}

sub _generate_blog_name {
    my ( $self, $tool_name, $owner_name, $settings ) = @_;

    unless ( $settings ) {
        $settings = $self->_get_settings;
        $settings->fetch_settings;
    }

    if ( my $name = $settings->setting('custom_blog_name') ) {
        return $name;
    }
    else {
        return $owner_name ? $owner_name . ' - ' . $tool_name : $tool_name;
    }
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
        $items = CTX->lookup_object('weblog_posts')->fetch_group( {
            where => 'groups_id = ? AND date > ? AND ' .
                $self->_get_visible_query_limiter( $end_time ),
            value => [ $group_id, $start_time ],
            order => 'date DESC',
        } ) || [];
    }
    elsif ( $user_id ) {
        $items = CTX->lookup_object('weblog_posts')->fetch_group( {
            where => 'user_id = ? AND date > ? AND ' .
                $self->_get_visible_query_limiter( $end_time ),
            value => [ $user_id, $start_time ],
            order => 'date DESC',
        } ) || [];
    }

    if (! scalar( @$items ) ) {
        return undef;
    }

    my $return = {
        tool_name => $self->_msg( 'Weblog' ),
        items_html => [],
        items_plain => []
    };

    for my $item ( @$items ) {
        my $date_string = Dicole::DateTime->medium_datetime_format(
            $item->{date}, $self->param('timezone'), $self->param('lang')
        );
        my $link = $domain_host . Dicole::URL->create_from_parts(
            action => $group_id ? 'group_weblog' : 'personal_weblog',
            task => 'show',
            target => $group_id || $user_id,
            additional => [ 0, $item->id ],
        );

        my $user = CTX->lookup_object('user')->fetch( $item->{writer}, { skip_security => 1 } );
        my $user_name = $user->first_name . ' ' . $user->last_name;

        push @{ $return->{items_html} },
            '<span class="date">' . $date_string
            . '</span> - <a href="' . $link . '">' . $item->{title}
            . '</a> - <span class="author">' . $user_name . '</span>';

        push @{ $return->{items_plain} },
            $date_string . ' - ' . $item->{title}
            . ' - ' . $user_name . "\n  - " . $link;
    }

    return $return;
}

########################################
# RSS feed
########################################

sub feed {
    my ( $self ) = @_;
    return $self->_feed;
}

sub feed_topic {
    my ( $self ) = @_;

    my $topic = $self->_fetch_current_topic;

    die "No such topic" if ! $topic;

    return $self->_feed( $topic );
}

sub _feed {
    my ( $self, $topic ) = @_;

    # use the first additional to set a new language
    $self->_shift_additional_language;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    # Check if unlogged user is restricted by IP
    $self->_check_ip_blocking( $settings_hash, $topic );

    my $feed = Dicole::Feed->new( action => $self );
    $feed->creator( 'Dicole Weblog' );

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('weblog_posts') );

    # default to five posts per feed
    my $limit = $settings_hash->{ 'number_of_items_in_feed' } || 5;
    my $time = time;

    if ( $self->param('target_type') eq 'group' ) {
        my $group = CTX->lookup_object( 'groups' )->fetch(
            $self->param('target_group_id')
        );
        $feed->title(
            $self->_generate_blog_name(
                $self->_msg( 'Weblog' ),
                $group->{name},
                $settings
            )
        );
        $feed->desc( $group->{description} );

        # Fetch latest weblog posts
        if ( $topic ) {
            $feed->title( $feed->title . ' - ' . $topic->name );
            $feed->desc( $feed->desc . ' - ' . $topic->name );

            $data->query_params( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_topics_link'
                ],
                where =>
                    'dicole_weblog_topics_link.topic_id = ? AND ' .
                    'dicole_weblog_topics_link.post_id = ' .
                    'dicole_weblog_posts.post_id AND ' .
                    'groups_id = ? AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $topic->id, $self->param('target_group_id') ],
                limit => $limit,
                order => 'date DESC'
            } );
        }
        else {
            $data->query_params( {
                where => 'groups_id = ? AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $self->param('target_group_id') ],
                limit => $limit,
                order => 'date DESC'
            } );
        }
    }
    else {
        my $user = CTX->lookup_object( 'user' )->fetch(
            $self->param('target_user_id'), { skip_security => 1 }
        );
        my $uname = $user->{first_name} . ' ' . $user->{last_name};
        $feed->title(
            $self->_generate_blog_name(
                $self->_msg( 'Weblog' ),
                $uname,
                $settings
            )
        );
        $feed->desc( sprintf( $self->_msg('Weblog of user %s'), $uname ) );

        if ( $topic ) {
            $feed->title( $feed->title . ' - ' . $topic->name );
            $feed->desc( $feed->desc . ' - ' . $topic->name );

            $data->query_params( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_topics_link'
                ],
                where =>
                    'dicole_weblog_topics_link.topic_id = ? AND ' .
                    'dicole_weblog_topics_link.post_id = ' .
                    'dicole_weblog_posts.post_id AND ' .
                    'user_id = ? AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $topic->id, $self->param('target_user_id') ],
                limit => $limit,
                order => 'date DESC'
            } );
        }
        else {
            $data->query_params( {
                where =>
                    'user_id = ? AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $self->param('target_user_id') ],
                limit => $limit,
                order => 'date DESC'
            } );
        }
    }
    $data->data_group;

    my @ids = map { $_->id } @{ $data->data };
    my $counts = $self->_count_comments_and_trackbacks( \@ids, $time );

    $feed->list_task( 'posts' );
    $feed->abstract_field( 'abstract' );
    $feed->abstracts_only( 1 ) if $settings_hash->{'abstracts_only_in_feed' };

    foreach my $item ( @{ $data->data } ) {
        my $titles = $item->weblog_topics || [];
        my @meta = map { $_->{name} } @$titles;
        $item->{subject} = join ', ', @meta;
        if ( my $c = $counts->{ $item->id } ) {
            $item->{title} .= " ($c)";
        }
    }

    # if this is removed, all items are duplicated :(
    if ( $topic ) {
        $feed->display_task( 'show_topic' );
        $feed->list_task( 'posts_topic' );
    }

    return $feed->feed(
        objects => $data->data,
        additional_prefix => [ $topic ? $topic->id : 0 ],
        id_in_additional => 1, #hack
    );
}

sub comment_feed {
    my ( $self ) = @_;
    return $self->_comment_feed;
}

sub comment_feed_topic {
    my ( $self ) = @_;

    my $topic = $self->_fetch_current_topic;

    die "No such topic" if ! $topic;

    return $self->_comment_feed( $topic );
}

sub _comment_feed {
    my ( $self, $topic ) = @_;

    # use the first additional to set a new language
    $self->_shift_additional_language;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    # Check if unlogged user is restricted by IP
    $self->_check_ip_blocking( $settings_hash, $topic );

    my $feed = Dicole::Feed->new( action => $self );
    $feed->creator( 'Dicole Weblog' );

    # default to five posts per feed
    my $limit = $settings_hash->{ 'number_of_items_in_feed' } || 5;
    my $time = time;

    my $comments = [];
    my $trackbacks = [];
    my $target_id;

    if ( $self->param('target_type') eq 'group' ) {
        $target_id = $self->param('target_group_id');
        my $group = CTX->lookup_object( 'groups' )->fetch( $target_id );
        $feed->title(
            $self->_generate_blog_name(
                $self->_msg( 'Weblog comments' ),
                $group->{name},
                $settings
            )
        );
        $feed->desc( $self->_msg('Comments from weblog of group [_1]',
            $group->{name}
        ) );

        # Fetch latest weblog comments
        if ( $topic ) {
            $feed->title( $feed->title . ' - ' . $topic->name );
            $feed->desc( $feed->desc . ' - ' . $topic->name );

            $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_topics_link',
                    'dicole_weblog_comments',
                ],
                where =>
                    'dicole_weblog_topics_link.topic_id = ? AND ' .
                    'dicole_weblog_topics_link.post_id = ' .
                    'dicole_weblog_posts.post_id AND ' .
                    'dicole_weblog_posts.groups_id = ? AND ' .
                    'dicole_weblog_posts.post_id = ' .
                    'dicole_weblog_comments.post_id AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $topic->id, $target_id ],
                limit => $limit,
                order => 'dicole_weblog_comments.date DESC'
            } ) || [];
        }
        else {
            $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_comments',
                ],
                where => 'dicole_weblog_posts.groups_id = ? AND ' .
                    'dicole_weblog_posts.post_id = ' .
                    'dicole_weblog_comments.post_id AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $target_id ],
                limit => $limit,
                order => 'dicole_weblog_comments.date DESC'
            } ) || [];
        }
    }
    else {
        $target_id = $self->param('target_user_id');
        my $user = CTX->lookup_object( 'user' )->fetch(
            $target_id, { skip_security => 1 }
        );
        my $uname = $user->{first_name} . ' ' . $user->{last_name};
        $feed->title(
            $self->_generate_blog_name(
                $self->_msg( 'Weblog comments' ),
                $uname,
                $settings
            )
        );
        $feed->desc( $self->_msg('Comments from weblog of user [_1]',
            $uname
        ) );

        if ( $topic ) {
            $feed->title( $feed->title . ' - ' . $topic->name );
            $feed->desc( $feed->desc . ' - ' . $topic->name );

            $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_topics_link',
                    'dicole_weblog_comments',
                ],
                where =>
                    'dicole_weblog_topics_link.topic_id = ? AND ' .
                    'dicole_weblog_topics_link.post_id = ' .
                    'dicole_weblog_posts.post_id AND ' .
                    'dicole_weblog_posts.user_id = ? AND ' .
                    'dicole_weblog_posts.post_id = ' .
                    'dicole_weblog_comments.post_id AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $topic->id, $target_id ],
                limit => $limit,
                order => 'date DESC'
            } ) || [];
        }
        else {
            $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
                from => [
                    'dicole_weblog_posts',
                    'dicole_weblog_comments',
                ],
                where =>
                    'dicole_weblog_posts.user_id = ? AND ' .
                    'dicole_weblog_posts.post_id = ' .
                    'dicole_weblog_comments.post_id AND ' .
                    $self->_get_visible_query_limiter( $time ),
                value => [ $target_id ],
                limit => $limit,
                order => 'date DESC'
            } ) || [];
        }
    }

    $feed->list_task( 'posts' );
    $feed->link_field( 'custom_link' );
    $feed->content_field( 'custom_content' );
    $feed->creator_field( 'custom_creator' );
    $feed->title_field('custom_title');

    my @abstracted = ();

    my $posts = Dicole::Utils::SPOPS->fetch_linked_objects(
        from_elements => $comments,
        link_field => 'post_id',
        object_name => 'weblog_posts'
    );
    my %post_titles = map { $_->id => $_->{title} } @$posts;

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects(
        from_elements => $comments,
        link_field => 'user_id',
        object_name => 'user'
    );
    my %user_names = map {
        $_->id => $_->{first_name} . ' ' . $_->{last_name}
    } @$users;

    my $topic_id = $topic ? $topic->id : 0;

    for my $comment ( @$comments ) {
        my $title = $self->_msg( "Comment on '[_1]'",
            $post_titles{ $comment->post_id } || '?'
        );
        $title .= ' : ' . $comment->title if $comment->title;

        # Replace line breaks with HTML line breaks
        my $content = $comment->content;
        $content =~ s/\r?\n/<br \/>/sg;

        push @abstracted,
        {
            custom_title => $title,
            custom_creator => $self->_get_author_name_from_comment(
                $comment, $user_names{ $comment->user_id }
            ),
            custom_link => Dicole::URL->create_from_parts(
                action => ( $self->param('target_type') eq 'group' ) ?
                    'group_weblog' : 'personal_weblog',
                task => 'show',
                target => $target_id,
                additional => [ $topic_id, $comment->post_id ],
                anchor => $comment->id,
            ),
            custom_content => $content,
            date => $comment->date,
        };
    }
    @abstracted = sort { $b->{date} <=> $a->{date} } @abstracted;
    @abstracted = splice( @abstracted, $limit ) unless $limit >= @abstracted;

    # if this is removed, all items are duplicated :(
    if ( $topic ) {
        $feed->list_task( 'posts_topic' );
    }

    return $feed->feed(
        objects => \@abstracted,
    );
}

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'weblog' );
}

sub _settings_tool_params {
    return ( cols => 2, tab_override => 'config' );
}

sub _settings_container_box {
    my ( $self ) = @_;
    return $self->tool->Container->box_at( 1, 0 );
}

sub _pre_generate_common_settings {
    my ( $self )  = @_;

    $self->_add_config_select_box(
        box => $self->tool->Container->box_at( 0, 0 ),
        selected => 'settings',
    );
}

########################################

# needed for topic feeds
sub posts_topic {
    my ( $self ) = @_;
    return CTX->response->redirect( $self->derive_url( task => 'posts' ) );
}

# needed for topic feeds
sub show_topic {
    my ( $self ) = @_;
    return CTX->response->redirect( $self->derive_url( task => 'show' ) );
}

sub posts {
    my ( $self ) = @_;

    my $topic = $self->_fetch_current_topic;
    my $visible_topics = $self->_get_all_topics;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    # Check if unlogged user is restricted by IP
    $self->_check_ip_blocking( $settings_hash, $topic );

    if ( ! $self->chk_y( $self->param('target_type') . '_read' ) ) {
        $visible_topics = $self->_get_accessible_topics( $visible_topics );

        if ( ! scalar( @$visible_topics ) ) {
            die 'security error';
        }
        if ( $topic && ! grep { $_->id == $topic->id } @$visible_topics ) {
            return CTX->response->redirect(
                $self->derive_url( additional => [] )
            );
        }
    }

    $self->init_tool( cols => 2, rows => 2);

    my $abstracts = $self->_get_accessible_abstracts(
        $visible_topics, $topic
    );

    my $aname = ( $topic ) ?
        $self->_msg('Recent entries to topic [_1]', $topic->{name} ) :
        $self->_msg('Recent entries');


    $self->tool->Container->box_at( 0, 0 )->name( $aname );
    $self->tool->Container->box_at( 0, 0 )->add_content( $abstracts );

    my $recent = $self->_get_recent( $visible_topics, $topic );
    my $topics = $self->_get_topic_select( $visible_topics );

    $self->tool->Container->column_width( '250px', 2 );
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg('Recent')
    );
    $self->tool->Container->box_at( 1, 0 )->add_content( $recent );

    if ( $topics ) {
        $self->tool->Container->box_at( 1, 1 )->name(
            $self->_msg('Browse by topic')
        );
        $self->tool->Container->box_at( 1, 1 )->add_content( $topics );
    }

    return $self->generate_tool_content;
}

sub show {
    my ( $self ) = @_;

    my $post_id = $self->param( 'post_id' );
    return unless $post_id;
    my $data = $self->_check_if_post_exists( $post_id );
    return unless $data;

    my $topic = $self->_fetch_current_topic;
    my $visible_topics = $self->_get_all_topics;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    # Check if unlogged user is restricted by IP
    $self->_check_ip_blocking( $settings_hash, $topic );
    
    my $post_topics = $data->data->weblog_topics || [];
    
    my $right = $self->param('target_type') . '_read';
    if ( ! $self->chk_y( $right ) ) {
        $visible_topics = $self->_get_accessible_topics( $visible_topics );

        die 'security error' unless scalar( @$visible_topics );

        # Forward to base because not an accessibel topic
        if ( $topic && ! grep { $_->id == $topic->id } @$visible_topics ) {
            return CTX->response->redirect(
                $self->derive_url( additional => [ 0, $post_id ] )
            );
        }

        my $right_to_view = 0;
        my $topic_ok = $topic ? 0 : 1;

        for my $post_topic ( @$post_topics ) {
            next if ! grep { $_->id == $post_topic->id } @$visible_topics;
            $right_to_view = 1;
            last if ! $topic;
            if ( $topic->id == $post_topic->id ) {
                $topic_ok = 1;
                last;
            }
        }

        if ( ! $right_to_view ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Access denied to read entry with id [_1].',
                    $post_id ),
            );
            return CTX->response->redirect(
                $self->derive_url(
                    task => 'posts',
                    additional => [],
                )
            );
        }

        return CTX->response->redirect(
            # No need to inform user.
            $self->derive_url(
                task => 'show',
                additional => [ 0, $post_id ],
            )
        ) if ! $topic_ok;
    }

    $self->init_tool( tab_override => 'posts', rows => 5, cols => 2 );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'weblog_posts' ),
            current_view => 'show',
        )
    );
    $self->init_fields;

    # check user rights and post expiration
    if (! $self->_check_post_expired($data)) {
        my $message = Dicole::Content::Text->new(text => $self->_msg('Entry not found'));
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Entry details') );
        $self->tool->Container->box_at( 0, 0 )->add_content([ $message ]);
        return $self->generate_tool_content;
    }

    my $message = $self->_get_post( $data->data, $topic );

    my $buttons = new Dicole::Content::Controlbuttons;
    $buttons->add_buttons( {
        type => 'link',
        value => $self->_msg('Edit entry'),
        link => Dicole::URL->create_from_current(
            task => 'edit',
            additional => [ $topic ? $topic->id : 0, $post_id ],
        )
    } ) if $self->chk_y( $self->param('target_type') . '_edit' );

    $buttons->add_buttons( {
         type  => 'confirm_submit',
         value => $self->_msg( 'Remove entry' ),
         confirm_box => {
            title => $self->_msg( 'Remove entry' ),
            name => 'post_' . $post_id,
            msg   => $self->_msg( 'This entry will be removed. Are you sure you want to remove this entry?' ),
            href  => Dicole::URL->create_from_current(
                task => 'del',
                additional => [ $topic ? $topic->id : 0, $post_id ],
            )
         }
    } ) if $self->chk_y( $self->param('target_type') . '_delete' );

    # if user has right to post to personal blog..
    if ( $self->chk_y( 'user_add', CTX->request->auth_user_id ) ) {
        my $rtitle = $data->data->title;
        my $writer = eval { $data->data->writer_user; };
        my $rauthor = $writer ?
            $writer->first_name.' '. $writer->last_name :
            undef;

        $buttons->add_buttons( {
            type => 'link',
            value => $self->_msg('Reply in personal weblog'),
            link => Dicole::URL->create_from_parts(
                action => 'personal_weblog',
                task => 'add',
                target => CTX->request->auth_user_id,
                params => {
                    reply_to => $post_id,
                    reply_url => $self->derive_url,
                    reply_author => $rauthor,
                    reply_title => $rtitle,
                }
            ),
        } );

        $buttons->add_buttons( {
            type => 'link',
            value => $self->_msg('Attach personal posts as reply'),
            link => Dicole::URL->create_from_parts(
                action => 'personal_weblog',
                task => 'attach_trackback',
                target => CTX->request->auth_user_id,
                additional => [ $post_id ],
            ),
        } );

    }

    # Delete comment
    my $comment_id = CTX->request->param( 'comment_id' );
    if ( $comment_id && CTX->request->auth_user_id ) {
        my $comment = CTX->lookup_object('weblog_comments')->fetch(
            $comment_id
        );

        $right = $self->param('target_type') . '_comment_delete';
        if ( $comment && (
                CTX->request->auth_user_id == $comment->user_id ||
                $self->chk_y( $right )
             )
        ) {
            $comment->remove;
            $self->tool->add_message( MESSAGE_SUCCESS,
                $self->_msg( 'Comment removed.' )
            );
        }
        else {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'Error removing comment [_1].', $comment_id )
            );
        }
        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'show',
                additional => [ $topic ? $topic->id : 0, $post_id ] ,
            )
        );
    }

    # Delete trackback
    if ( my $trackback_reply_id = CTX->request->param( 'trackback_id' ) ) {
        my $trackbacks =
            CTX->lookup_object('weblog_trackbacks')->fetch_group( {
                where => 'reply_id = ? AND post_id = ?',
                value => [ $trackback_reply_id, $post_id ],
            } ) || [];

        my $trackback = pop @$trackbacks;

        my $reply_post;

        if ( $trackback ) {
            $reply_post = $trackback->reply_id_weblog_posts;
        }

        my $right = $self->param('target_type') . '_comment_delete';
        if ( $reply_post && (
                CTX->request->auth_user_id == $reply_post->writer ||
                $self->chk_y( $right )
             )
        ) {
            $trackback->remove;
            $self->tool->add_message( MESSAGE_SUCCESS,
                $self->_msg( 'Reply removed.' )
            );
        }
        else {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'Error removing reply [_1].',
                    $trackback_reply_id )
            );
        }
        return CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => 'show',
                additional => [ $topic ? $topic->id : 0, $post_id ] ,
            )
        );
    }

    $right = $self->param('target_type') . '_comment';
    my $commenting_allowed = $self->chk_y( $right );

    if ( ! $commenting_allowed ) {
        for my $topic ( @$post_topics ) {
            if ( $self->chk_y( $right . '_topic', $topic->id ) ) {
                $commenting_allowed = 1;
                last;
            }
        }
    }

    # Add comment if comment filled
    if ( $commenting_allowed ) {

        $self->gtool(
            Dicole::Generictool->new(
                object => CTX->lookup_object( 'weblog_comments' ),
                current_view => CTX->request->auth_is_logged_in ?
                    'add_comment' : 'add_unlogged_comment',
            )
        );
        $self->init_fields;

        if ( CTX->request->param( 'add_comment' ) ) {

            # very probably spam
            if ( CTX->request->param('address1') ) {
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg('Your comment has been identified as spam.')
                );
            }
            # either spam or no javascript
            elsif ( ! CTX->request->param('address2') ) {
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg('Commenting without javascript is disabled to reduce spam. Please turn javascript on to comment.')
                );
            }
            else {
                my ( $code, $msg ) = $self->gtool->validate_and_save(
                    $self->gtool->visible_fields,
                    { no_save => 1 }
                );
                if ( $code ) {
                    my $cdata = $self->gtool->Data;
                    $cdata->data->{date} = time;
                    $cdata->data->{user_id} = CTX->request->auth_user_id;
                    $cdata->data->{post_id} = $post_id;
                    $cdata->data_save;
                    $self->_ping_feedreader_for_comment(
                        $cdata->data,
                        $data->data
                    );
                    $cdata->clear_data_fields;
                    $msg = $self->_msg( "Comment has been added." );
                } else {
                    $msg = $self->_msg( "Failed adding comment: [_1]", $msg );
                }
                $self->tool->add_message( $code, $msg );
            }
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Entry details') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $message, $buttons ]
    );

    my $reverse_trackbacks = $self->_get_reverse_trackbacks( $post_id );
    if ( scalar( @$reverse_trackbacks ) ) {
        $self->tool->Container->box_at( 0, 1 )->name(
            $self->_msg('This post is a reply to following posts')
        );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            $reverse_trackbacks
        );
    }

    my $comments = $self->_get_comments( $topic, $post_id );
    if ( scalar( @$comments ) ) {
        $self->tool->Container->box_at( 0, 2 )->name(
            $self->_msg('Comments')
        );
        $self->tool->Container->box_at( 0, 2 )->add_content(
            $comments
        );
    }

    my $trackbacks = $self->_get_trackbacks( $post_id );
    if ( scalar( @$trackbacks ) ) {
        $self->tool->Container->box_at( 0, 3 )->name(
            $self->_msg('Replies in other weblogs')
        );
        $self->tool->Container->box_at( 0, 3 )->add_content(
            $trackbacks
        );
    }

    if (  $commenting_allowed ) {
        my $spam_block = Dicole::Widget::HiddenBlock->new(
            content => Dicole::Widget::Vertical->new( contents => [
                Dicole::Widget::FormControl::TextField->new(
                    id => 'address1',  name => 'address1'
                ),
                Dicole::Widget::FormControl::TextField->new(
                    id => 'address2',  name => 'address2'
                ),
                Dicole::Widget::Javascript->new(
                    defer => 1,
                    code => "document.getElementById('address2').value=1;",
                )
            ] )
        );

        $self->gtool->add_bottom_button(
            name => 'add_comment',
            value => $self->_msg('Save')
        );
        $self->tool->Container->box_at( 0, 4 )->name(
            $self->_msg('Post your comment')
        );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $spam_block, @{ $self->gtool->get_add } ]
        );
    }

    my $recent = $self->_get_recent( $visible_topics, $topic );
    my $topics = $self->_get_topic_select( $visible_topics );

    $self->tool->Container->column_width( '250px', 2 );
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg('Recent')
    );
    $self->tool->Container->box_at( 1, 0 )->add_content( $recent );

    if ( $topics ) {
        $self->tool->Container->box_at( 1, 1 )->name(
            $self->_msg('Browse by topic')
        );
        $self->tool->Container->box_at( 1, 1 )->add_content( $topics );
    }

    return $self->generate_tool_content;
}

sub list {
    my ( $self ) = @_;

    $self->init_tool;
    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'weblog_posts' ),
            current_view => 'list',
        )
    );

    if ( $self->param('target_type') eq 'group' ) {
        $self->gtool->Data->add_where(
            'groups_id = ' . CTX->request->target_group_id
        );
    }
    else {
        $self->gtool->Data->add_where(
            'user_id = ' . CTX->request->target_user_id
        );
    }
    $self->init_fields;

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('List of entries') );
    $self->tool->Container->box_at( 0, 0 )->add_content($self->gtool->get_list);

    return $self->generate_tool_content;
}

sub attach_trackback {
    my ( $self ) = @_;

    if ( $self->param('target_type') ne 'user' ) {
        return CTX->response->redirect(
            $self->derive_url(
                task => 'posts',
                additional => [],
            )
        );
    }

    $self->init_tool;

    my $reply_id = $self->param('reply_id');

    unless ( $reply_id =~ /^\d+$/ ) {
        return CTX->response->redirect(
            $self->derive_url(
                task => 'posts',
                additional => [],
            )
        );
    }

    my $post = CTX->lookup_object( 'weblog_posts' )->fetch(
        $reply_id
    );

    if ( ! $post ) {
        $self->tool->add_message(
            MESSAGE_WARNING,
            $self->_msg('Could not find replied post!')
        );
        return CTX->response->redirect(
            $self->derive_url(
                task => 'posts',
                additional => [],
            )
        );
    }

   if ( ! $self->_user_has_right_to_comment( $post ) ) {
        $self->tool->add_message(
            MESSAGE_WARNING,
            $self->_msg('No rights to inform replied post owner of reply.')
        );
        return CTX->response->redirect(
            $self->derive_url(
                task => 'posts',
                additional => [],
            )
        );
    }

    my $old = CTX->lookup_object('weblog_trackbacks')->fetch_group( {
        where => 'post_id = ?',
        value => [ $post->id ]
    } ) || [];

    my %old_check = map { $_->reply_id => 1 } @$old;

    if ( CTX->request->param('attach') ) {
        my $selected = Dicole::Utility->checked_from_apache( 'sel' );

        for my $id ( keys %$selected ) {
            next if $old_check{ $id };
            my $reply = CTX->lookup_object( 'weblog_posts' )->fetch(
                $id
            );
            next if $reply->user_id != $self->param('target_user_id');
            $self->_add_post_as_reply_to( $reply, $post );
            $self->_ping_feedreader_for_post( $post );
        }

        if ( scalar( keys %$selected ) ) {
            $self->tool->add_message(
                MESSAGE_SUCCESS,
                $self->_msg('Replies attached.')
            );
            return CTX->response->redirect(
                $self->derive_url(
                    action => $post->groups_id ?
                        'group_weblog' : 'personal_weblog',
                    task => 'show',
                    target => $post->groups_id ?
                        $post->groups_id : $post->user_id,
                    additional => [0, $post->id],
                )
            );
        }
    }

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'weblog_posts' ),
            current_view => 'list',
        )
    );
    $self->init_fields;

    if ( $self->param('target_type') eq 'group' ) {
        $self->gtool->Data->add_where(
            'groups_id = ' . CTX->request->target_group_id
        );
    }
    else {
        $self->gtool->Data->add_where(
            'user_id = ' . CTX->request->target_user_id
        );
    }

    $self->gtool->add_bottom_buttons( [
        {
            name => 'attach',
            value => $self->_msg('Attach'),
            type => 'submit',
        }
    ] );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg('Select entries to attach as reply')
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_sel
    );

    return $self->generate_tool_content;
}

sub bookmarklets {
    my ( $self ) = @_;

    # Init tool
    $self->init_tool( cols => 2, tab_override => 'config' );

    $self->tool->Path->add(
        name => $self->_msg( 'Bookmarklets' )
    );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );
    $self->gtool->current_view( 'bookmarklets' );

    my $server_url = Dicole::Pathutils->new->get_server_url;
    $server_url .= $self->derive_url(
        task => 'add',
        additional => [],
    );

    $self->gtool->add_field(
        id  => 'text', type => 'text',
        desc => '',
        use_field_value => 1, value => $self->_msg( 'You may use these bookmarklets to blog a certain website with a single click. To install the bookmarklet, add the bookmarklet link to your bookmarks. To use it, simply just click the bookmark when you are on a page you want to post. If you want to quote something, just highlight the text you want to quote before clicking the bookmarklet.' ),
    );

    # Add a basic bookmarklet which is able to traverse through frames and popup a new window with an URL
    # of the current page
    $self->gtool->add_field(
        id  => 'default_bookmarklet', type => 'textfield',
        desc => $self->_msg( 'Bookmarklet' ),
        use_field_value => 1, value => $self->_msg( 'Post to weblog' ),
        link_noescape => 1,
        'link' => "javascript:Q='';x=document;y=window;if(x.selection){Q=x.selection.createRange().text;}else if(y.getSelection){Q=y.getSelection();}else if(x.getSelection){Q=x.getSelection();}location.href='$server_url?new_content='+escape(Q)+'&content_link='+escape(x.location.href)+'&new_title='+escape(x.title)"
    );

    # Set views
    $self->gtool->set_fields_to_views;

    # Lets fake we are a fake object
    $self->gtool->fake_objects( [ Dicole::Generictool::FakeObject->new( {
        id => 'feed_id'
    } ) ] );

    $self->_add_config_select_box(
        box => $self->tool->Container->box_at( 0, 0 ),
        selected => 'bookmarklets',
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( "Available bookmarklets" ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_show
    );

    return $self->generate_tool_content;

}

sub add {
    my ( $self ) = @_;

    $self->init_tool;
    $self->tool->add_tinymce_widgets;

    if ( CTX->request->param( 'content_link' ) ) {
        $self->tool->structure( 'popup' ) if CTX->request->param( 'content_link' );
        CTX->controller->set_main_template( 'dicole_base::base_popup' );
        $self->tool->Path->del_all;
        $self->tool->Path->add( name => $self->_msg( 'Write entry' ) );
    }

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('weblog_topics') );
    if ( $self->param('target_type') eq 'group' ) {
        $data->query_params( {
            where => 'groups_id = ?',
            value => [ CTX->request->target_group_id ]
        } );
    }
    else {
        $data->query_params( {
            where => 'user_id = ?',
            value => [ CTX->request->target_user_id ]
        } );
    }

#     unless ( $data->total_count ) {
#         $self->tool->add_message( MESSAGE_WARNING,
#             $self->_msg( 'No topics defined. You have to define topics before you can post.' )
#         );
#         return CTX->response->redirect( Dicole::URL->create_from_current(
#             task => 'config'
#         ) );
#     }

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('weblog_posts'),
            skip_security => 1,
            current_view => 'add',
        )
    );
    $self->init_fields;

    my $selected = [];

    if ( CTX->request->param( 'add' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );

        if ( $code ) {
            my $data = $self->gtool->Data;
            $data->data->{writer} = CTX->request->auth_user_id;
            if ( $self->param('target_type') eq 'group' ) {
                $data->data->{groups_id} = CTX->request->target_group_id;
                $data->data->{user_id} = 0;
            }
            else {
                $data->data->{groups_id} = 0;
                $data->data->{user_id} = CTX->request->target_user_id;
            }
            $data->data->edited_date( time - 1 );
            $data->data_save;

            my $legal_topics = $self->_get_legal_topics;
            # Add links_to links to topics
            Dicole::Utility->renew_links_to(
                object => $data->data,
                relation => 'weblog_topics',
                new => $legal_topics,
            );
            $selected = $legal_topics;
            $message = $self->_msg('Entry saved');
            $self->tool->add_message( $code, $message );
            $self->_ping_feedreader_for_post( $data->data, $legal_topics );

            if ( my $reply_id = CTX->request->param( 'reply_to' ) ) {
                my $post = CTX->lookup_object( 'weblog_posts' )->fetch(
                    $reply_id
                );
                if ( $post ) {
                    if ( $self->_user_has_right_to_comment( $post ) ) {
                        $self->_add_post_as_reply_to( $data->data, $post );
                        $self->_ping_feedreader_for_post( $post );
                    }
                    else {
                        $self->tool->add_message(
                            MESSAGE_WARNING,
                            $self->_msg('No rights to inform replied post owner of reply.')
                        );
                    }
                }
                else {
                    $self->tool->add_message(
                        MESSAGE_WARNING,
                        $self->_msg('Could not find replied post!')
                    );
                }
            }

            $data->clear_data_fields;

            if ( CTX->request->param( 'content_link' ) ) {
                $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Entry saved') );
                $self->tool->Container->box_at( 0, 0 )->add_content( [
                    Dicole::Content::Text->new( text => $self->_msg( 'Entry successfully saved. You may now close the window.' ) ),
                    Dicole::Content::Button->new( type => 'link', value => $self->_msg( 'Close' ),
                        'link' => "javascript:self.close()"
                    )
                ] );
                return $self->generate_tool_content;
            }
            else {
                return CTX->response->redirect(
                    $self->derive_url(
                        task => 'posts',
                        additional => [],
                    )
                );
            }
        } else {
            $message = $self->_msg('Failed adding entry: [_1]', $message );
            $self->tool->add_message( $code, $message );
        }
    }
    elsif ( CTX->request->param( 'content_link' ) ) {
        my $title = $self->gtool->get_field( 'title' );
        $title->use_field_value( 1 );
        $title->value( CTX->request->param( 'new_title' ) );
        my $content = $self->gtool->get_field( 'content' );
        $content->use_field_value( 1 );
        my $content_value = '<a href="' . CTX->request->param( 'content_link' ) . '">'
            . CTX->request->param( 'new_title' ) . '</a>';
        $content_value .= ':<br /><i>"' . CTX->request->param( 'new_content' )
            . '"</i><br /><br />' if CTX->request->param( 'new_content' );

        $content->value( $content_value );
    }
    elsif ( my $rurl = CTX->request->param( 'reply_url' ) ) {
        my $content = $self->gtool->get_field( 'content' );
        $content->use_field_value( 1 );

        my $rauthor = CTX->request->param( 'reply_author' );
        my $rtitle = CTX->request->param( 'reply_title' );
        $rtitle = '<em>' . $rtitle . '</em>' if $rtitle;
        my $begin = '<a href="' . $rurl . '">';
        my $end = '</a>';

        my $content_value = '<p>';
        if ( $rauthor && $rtitle ) {
            $content_value .=
                $self->_msg( 'Reply to a [_1]post[_2] by [_3] titled [_4]:',
                    $begin, $end, $rauthor, $rtitle );
        }
        elsif ( $rauthor ) {
            $content_value .=
                $self->_msg( 'Reply to a [_1]post[_2] by [_3]:',
                    $begin, $end, $rauthor );
        }
        elsif ( $rtitle ) {
            $content_value .=
                $self->_msg( 'Reply to a [_1]post[_2] titled [_3]:',
                    $begin, $end, $rtitle );
        }
        else {
            $content_value .=
                $self->_msg( 'Reply to a [_1]post[_2]:',
                    $begin, $end );
        }
        $content_value .= '</p><p></p>';

        $content->value( $content_value );
    }

    $self->gtool->add_bottom_button(
        name => 'add',
        value => $self->_msg('Save')
    );

    $self->_add_onunload_warning;

    my $topics = $self->_get_topic_list( selected => $selected );
    $self->gtool->get_field('topics')->object( $topics->[0] );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('New entry details') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ @{ $self->gtool->get_add } ]
    );

    return $self->generate_tool_content;
}

sub del {
    my ( $self ) = @_;

    my $topic_id = $self->param( 'target_object_id' );
    my $post_id = $self->param( 'post_id' );

    return unless $post_id;
    my $data = $self->_check_if_post_exists( $post_id );
    return unless $data;

    unless ( $data->remove_object ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error removing entry with name [_1].',
                $data->data->{title}
            )
        );
    }
    else {
        Dicole::Utility->renew_links_to(
            object => $data->data,
            relation => 'weblog_topics',
        );
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Entry with name [_1] successfully removed.',
                $data->data->{title}
            )
        );
        $data->object( CTX->lookup_object('weblog_comments') );
        $data->query_params( {
            where => 'post_id = ?',
            value => [ $post_id ]
        } );
        $data->remove_group( undef, $data->data_group( 1 ) );
    }

    my $redirect = $self->derive_url(
        task => 'posts',
        additional => [ $topic_id ],

    );
    return CTX->response->redirect( $redirect );
}

sub edit {
    my ( $self ) = @_;

    my $topic_id = $self->param( 'target_object_id' );
    my $post_id = $self->param( 'post_id' );

    return unless $post_id;
    my $data = $self->_check_if_post_exists( $post_id );
    return unless $data;

    my $save = CTX->request->param( 'save' );

    $self->init_tool(
        tab_override => 'list',
    );
    $self->tool->add_tinymce_widgets;

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('weblog_posts'),
            skip_security => 1,
            current_view => 'edit',
        )
    );
    $self->init_fields;

    # Tags
    # Get the tag action class
    my $tag_action = eval { CTX->lookup_action( 'tag_exports' ); };
    # Disabled for now
    if ( $tag_action && 0 ) {
        # Set the object_id so that it is passed to the
        # construct_tags correctly
        my $tags_field = $self->gtool->get_field( 'tags' );
        $tags_field->object_id( $post_id )
            if ref $tags_field;

        # Edit the tags if we are saving the page
        if ( $save ) {
            # We are editing the tags
            $tag_action->task( 'edit' );

            # Set the object_id and object_type as params
            $tag_action->param( object_id => $tags_field->object_id() );
            $tag_action->param(
                object_type => $tags_field->object_type()
            );

            # Call the tag action
            $tag_action->execute();
        }
    }

    my $selected = $data->data->weblog_topics;

    if ( $save ) {
        
        $data->data->edited_date( time );
        
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $data->data }
        );

        my $topics = Dicole::Utility->checked_from_apache('topic') || {};
#         unless ( scalar keys %{ $topics } ) {
#             $code = MESSAGE_ERROR;
#             $message = $self->_msg( 'Select at least one topic.' );
#         }

        if ( $code ) {
            # Renew links_to topics
            my $legal_topics = $self->_get_legal_topics;
            Dicole::Utility->renew_links_to(
                object => $data->data,
                relation => 'weblog_topics',
                new => $legal_topics,
            );
            $selected = $legal_topics;

            $self->tool->add_message( $code, $self->_msg('Entry saved') );
            $self->_ping_feedreader_for_post( $data->data, $legal_topics );
            my $redirect = Dicole::URL->create_from_current(
                task => 'show',
                additional => [ $topic_id, $post_id ],
            );
            return CTX->response->redirect( $redirect );

        } else {
            $self->tool->add_message( $code,
                $self->_msg("Failed to edit entry: [_1]", $message )
            );
        }
    }

    $self->gtool->add_bottom_button(
        name => 'save',
        value => $self->_msg('Save'),
    );
    $self->gtool->add_bottom_button(
        type => 'link',
        value => $self->_msg( 'Show entry' ),
        link => Dicole::URL->create_from_current(
            task => 'show',
            additional => [ $topic_id, $post_id ],
        )
    );

    $self->_add_onunload_warning;

    my $topics = $self->_get_topic_list( selected => $selected );
    $self->gtool->get_field('topics')->object( $topics->[0] );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Entry details') );
        $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_edit( object => $data->data )
    );
    return $self->generate_tool_content;
}

sub config {
    my ( $self ) = @_;

    $self->init_tool(
        rows => 2,
        cols => 2
    );

    my $topic_class = CTX->lookup_object('weblog_topics');

    $self->gtool(
        Dicole::Generictool->new(
            object => $topic_class,
            skip_security => 1,
            current_view => 'topic_add',
        )
    );
    $self->init_fields;

    if ( CTX->request->param( 'add' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );
        if ( $code ) {
            my $data = $self->gtool->Data;
            if ( $self->param('target_type') eq 'group' ) {
                $data->data->{user_id} = 0;
                $data->data->{groups_id} = CTX->request->target_group_id;
            }
            else {
                $data->data->{user_id} = CTX->request->target_user_id;
                $data->data->{groups_id} = 0;
            }
            $data->data_save;
            $message = $self->_msg('Topic added');
            $data->clear_data_fields;
        } else {
            $message = $self->_msg("Failed adding topic: [_1]", $message );
        }
        $self->tool->add_message( $code, $message );
    }
    elsif ( CTX->request->param( 'remove' ) ) {
        # Remove topics upon request.
        # TODO: Rewrite links from posts to not include removed topics?
        my $topics = Dicole::Utility->checked_from_apache('topic') || {};
        foreach my $topic ( keys %$topics ) {
            eval {
                my $post = $topic_class->fetch( $topic );
                if ( $self->param('target_type') eq 'group' ) {
                    next if $post->{groups_id} != CTX->request->target_group_id;
                }
                else {
                    next if $post->{user_id} != CTX->request->target_user_id;
                }
                $post->remove;
            };
        }
        $self->tool->add_message( MESSAGE_SUCCESS,
            $self->_msg('Selected topics removed.')
        );
    }

    $self->gtool->add_bottom_button(
        name => 'add',
        value => $self->_msg('Save'),
    );

    $self->_add_config_select_box(
        box => $self->tool->Container->box_at( 0, 0 ),
        selected => 'config',
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Add topic') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_add
    );
    $self->tool->Container->box_at( 1, 1 )->name( $self->_msg('Remove topics') );
    $self->tool->Container->box_at( 1, 1 )->add_content(
        $self->_get_topic_list( remove => 1 )
    );
    return $self->generate_tool_content;
}

sub attached_file {
    my ( $self ) = @_;
    
    my $post_id = $self->param( 'post_id' );
    die 'security error' unless $post_id;
    my $data = $self->_check_if_post_exists( $post_id );
    die 'security error' unless $data;

    my $topic = $self->_fetch_current_topic;
    my $visible_topics = $self->_get_all_topics;

    # Check if unlogged user is restricted by IP
    $self->_check_ip_blocking( undef, $topic );
    
    my $post_topics = $data->data->weblog_topics || [];
    
    my $right = $self->param('target_type') . '_read';
    if ( ! $self->chk_y( $right ) ) {
        $visible_topics = $self->_get_accessible_topics( $visible_topics );

        die 'security error' unless scalar( @$visible_topics );

        my $right_to_view = 0;

        for my $post_topic ( @$post_topics ) {
            next if ! grep { $_->id == $post_topic->id } @$visible_topics;
            $right_to_view = 1;
            last;
        }

        die 'security error' unless $right_to_view;
    }
    
    my $parts = $self->target_additional;
    # Strip topic and post id's from additional to get file url
    shift @$parts while $parts->[0] =~ /^\d+$/;
    my $file_url = join '/', ( '', @$parts );
    
    return CTX->lookup_action('file_attachment')->execute( 'serve', {
        url => $file_url,
        from_html => $data->data->content,
        owner_type => $self->param('target_type'),
        owner_id => $self->param('target_type') eq 'user' ?
            $self->param('target_user_id') : $self->param('target_group_id'),
    } );
}

sub share_matrix {
    my ( $self ) = @_;

    $self->_share_matrix_process_params();

    my @ids = ();

    my $tt = $self->param( 'target_type' );

    my $all_collection = $self->_fetch_collection_id(
        archetype => $tt . '_weblog_user'
    );
    my $topic_collection = $self->_fetch_collection_id(
        archetype => $tt . '_weblog_topic_reader'
    );
    push @ids, $all_collection if $all_collection;
    push @ids, $topic_collection if $topic_collection;

    my $securities = CTX->lookup_object( 'dicole_security' )->fetch_group( {
        where => 'target_'. $tt .'_id = ? AND ' .
            Dicole::Utils::SQL->column_in( 'collection_id', \@ids ),
        value => [ $self->param( 'target_'. $tt .'_id' ) ],
    } ) || [];

    my %grouped_securities = ();
    my %targeted_topics = ();
    my %targeted_users = ();
    my %targeted_groups = ();

    for my $security ( @$securities ) {
        # gather targeted topics
        my $target_id = $security->target_object_id;
        $targeted_topics{ $target_id }++;

        # gather receiving groups & users and group
        # securities by their place in the matrix
        my $receiver_type = $security->receiver_type;
        my $receiver_id = 0;

        if ( $receiver_type == RECEIVER_USER ) {
            $receiver_id = $security->receiver_user_id;
            $targeted_users{ $receiver_id }++;
        }
        elsif ( $receiver_type == RECEIVER_GROUP ) {
            $receiver_id = $security->receiver_group_id;
            $targeted_groups{ $receiver_id }++;
        }

        $grouped_securities{ $target_id }
            ->{ $receiver_type }->{ $receiver_id } ||= [];

        push @{ $grouped_securities{ $target_id }
            ->{ $receiver_type }->{ $receiver_id } }, $security;
    }

    my $topics = $self->_get_all_topics || [];
    $topics = [ sort { $a->name cmp $b->name } @$topics ];

    my $users = Dicole::Utils::SPOPS->fetch_objects(
        object_name => 'user', ids => [ keys %targeted_users ]
    );
    $users = [ sort { $a->id <=> $b->id } @$users ];

    my $groups = Dicole::Utils::SPOPS->fetch_objects(
        object_name => 'groups', ids => [ keys %targeted_groups ]
    );
    $groups = [ sort { $a->id <=> $b->id } @$groups ];

    my $matrix = Dicole::Widget::Listing->new( use_keys => 1 );

    # add all keys
    $matrix->add_key( content => '' );
    $matrix->add_key( content => Dicole::Widget::Image->new(
        src => '/images/theme/default/navigation/icons/16x16/groups/common.gif',
        alt => $self->_msg('Whole internet'),
    ) );
    $matrix->add_key( content => Dicole::Widget::Image->new(
        src => '/images/theme/default/navigation/icons/16x16/domainmanager_mini.gif',
        alt => $self->_msg('Logged in users')
    ) );

    for my $group ( @$groups ) {
        $matrix->add_key( content => Dicole::Widget::Image->new(
            src => '/images/theme/default/navigation/icons/16x16/groups/usergroup.gif',
            alt => $group->name
        ) );
    }

    for my $user ( @$users ) {
        $matrix->add_key( content => Dicole::Widget::Image->new(
            src => '/images/theme/default/navigation/icons/16x16/profile_mini.gif',
            alt => $user->first_name . ' ' . $user->last_name
        ) );
    }

    $matrix->add_key( content => Dicole::Widget::Image->new(
        src => '/images/theme/default/navigation/icons/16x16/group_tools_mini.gif',
        alt => $self->_msg('New group')
    ) );
    $matrix->add_key( content => Dicole::Widget::Image->new(
        src => '/images/theme/default/navigation/icons/16x16/group_rights_mini.gif',
        alt => $self->_msg('New user')
    ) );

    # add rows for each topic
    for my $topic ( 0, @$topics ) {
        my $target_id = $topic ? $topic->id : 0;
        my $topic_name = $topic ? $topic->name : $self->_msg('All topics');
        my $sec_group = $grouped_securities{ $target_id };
        $matrix->new_row;
        $matrix->add_cell( content => $topic_name );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $sec_group, $target_id, $topic_name, RECEIVER_GLOBAL, 0
            )
        );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $sec_group, $target_id, $topic_name, RECEIVER_LOCAL, 0
            )
        );
        for my $group ( @$groups ) {
            $matrix->add_cell( content =>
                $self->_get_share_status_widget(
                    $sec_group, $target_id, $topic_name, RECEIVER_GROUP, $group
                )
            );
        }
        for my $user ( @$users ) {
            $matrix->add_cell( content =>
                $self->_get_share_status_widget(
                    $sec_group, $target_id, $topic_name, RECEIVER_USER, $user
                )
            );
        }
        $matrix->add_cell( content =>
            Dicole::Widget::LinkImage->new(
                link => $self->derive_url(
                    task => 'add_share_group',
                    additional => [ $target_id ],
                ),
                src => '/images/theme/default/navigation/icons/16x16/add.gif',
                alt => $self->_msg('Share topic [_1] to some group', $topic_name ),
                width => 16,
                height => 16
            )
        );
        $matrix->add_cell( content =>
            Dicole::Widget::LinkImage->new(
                link => $self->derive_url(
                    task => 'add_share_user',
                    additional => [ $target_id ],
                ),
                src => '/images/theme/default/navigation/icons/16x16/add.gif',
                alt => $self->_msg('Share topic [_1] to some user', $topic_name ),
                width => 16,
                height => 16
            )
        );
    }

    $self->init_tool;

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Sharing') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $matrix ]
    );

    return $self->generate_tool_content;
}

sub _get_share_status_widget {
    my ( $self, $sec_group, $target_id, $topic_name, $receiver_type, $receiver ) = @_;

    my %link_params = (
        rtype => $receiver_type,
        ruid => ($receiver_type == RECEIVER_USER) ? $receiver->id : 0,
        rgid => ($receiver_type == RECEIVER_GROUP) ? $receiver->id : 0,
    );

    my $rtype_string = undef;

    if ( $receiver_type == 1 ) {
        $rtype_string = $receiver->first_name . ' ' . $receiver->last_name;
    }
    elsif ( $receiver_type == 2 ) {
        $rtype_string = $receiver->name;
    }
    elsif ( $receiver_type == 3 ) {
        $rtype_string = lcfirst( $self->_msg('Logged in users') );
    }
    else {
        $rtype_string = lcfirst( $self->_msg('Whole internet') );
    }

    my $receiver_id = $receiver ? $receiver->id : 0;

    my $securities = $sec_group->{$receiver_type}->{$receiver_id};

    if ( ref $securities eq 'ARRAY' && scalar @$securities ) {
        return Dicole::Widget::LinkImage->new(
            link => $self->derive_url(
                additional => [ $target_id ],
                params => {
                    remove => 1,
                    %link_params
                },
            ),
            src => '/images/theme/default/navigation/icons/16x16/true.gif',
            alt => $self->_msg('Remove sharing of topic [_1] for [_2]', $topic_name, $rtype_string ),
            width => 16,
            height => 16
        );
    }
    else {
        return Dicole::Widget::LinkImage->new(
            link => $self->derive_url(
                additional => [ $target_id ],
                params => {
                    add => 1,
                    %link_params
                },
            ),
            src => '/images/theme/default/navigation/icons/16x16/false.gif',
            alt => $self->_msg('Share topic [_1] for [_2]', $topic_name, $rtype_string ),
            width => 16,
            height => 16
        );
    }

}

sub _share_matrix_process_params {
    my ( $self ) = @_;

    # this validates that the topic belongs to target
    my $topic = $self->_fetch_current_topic;
    $topic = $topic ? $topic->id : 0;

    my $rtype = CTX->request->param( 'rtype' );
    return if ! $rtype;
    return if $rtype < 1 || $rtype > 4;

    my $sec_params = {
        receiver_type => $rtype,
        receiver_user_id => ( $rtype == RECEIVER_USER ) ?
            CTX->request->param( 'ruid' ) : 0,
        receiver_group_id => ( $rtype == RECEIVER_GROUP ) ?
            CTX->request->param( 'rgid' ) : 0,
    };

    if ( my $d = eval { CTX->lookup_action('dicole_domains') } ) {
        if (
            $sec_params->{receiver_user_id} ||
            $sec_params->{receiver_group_id}
        ) {
            my $target = {};
            my $receiver = {};

            if ( $self->param('target_type') eq 'user')  {
                $target->{user} = $self->param('target_user_id');
            }
            else {
                $target->{group} = $self->param('target_group_id');
            }

            if ( $sec_params->{receiver_user_id} ) {
                $receiver->{user} = $sec_params->{receiver_user_id};
            }
            else {
                $receiver->{group} = $sec_params->{receiver_group_id};
            }

            $d->task('verify_matching_domain');
            return if ! eval { $d->execute( {
                a => $target,
                b => $receiver
            } ) };
        }
   }

    if ( $self->param('target_type') eq 'user' ) {

        if ( $topic ) {
            $sec_params->{target_type} = TARGET_OBJECT;
            $sec_params->{target_object_id} = $topic;
            $sec_params->{collection_id} = $self->_fetch_collection_id(
                archetype => 'user_weblog_topic_reader'
            );
        }
        else {
            $sec_params->{target_type} = TARGET_USER;
            $sec_params->{collection_id} = $self->_fetch_collection_id(
                archetype => 'user_weblog_user'
            );
        }

        $sec_params->{target_user_id} = $self->param('target_user_id');
    }
    else {
        if ( $topic ) {
            $sec_params->{target_type} = TARGET_OBJECT;
            $sec_params->{target_object_id} = $topic;
            $sec_params->{collection_id} = $self->_fetch_collection_id(
                archetype => 'group_weblog_topic_reader'
            );
        }
        else {
            $sec_params->{target_type} = TARGET_GROUP;
            $sec_params->{collection_id} = $self->_fetch_collection_id(
                archetype => 'group_weblog_user'
            );
        }

        $sec_params->{target_group_id} = $self->param('target_group_id');
    }

    if ( CTX->request->param( 'add' ) ) {
        CTX->lookup_object( 'dicole_security' )->new( $sec_params )->save;
    }
    elsif ( CTX->request->param( 'remove' ) ) {
        my $where = join(
            ' AND ',
            map { $_ . ' = ' . $sec_params->{$_} }
            keys %$sec_params
        );

        my $secs = CTX->lookup_object( 'dicole_security' )->fetch_group ( {
            where => $where,
        } ) || [];

        $_->remove for @$secs;
    }
    else {
        return;
    }

    $self->redirect( $self->derive_url( params => {}, additional => [] ) );
}

sub add_share_user {
    my ( $self ) = @_;

    my $topic = $self->_fetch_current_topic;

    $self->init_tool(
        rows => 1,
        cols => 2,
        tab_override => 'share_matrix',
    );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'user' ),
            current_view => 'add_share_user',
            skip_security => 1,
            initial_construct_params => {
                custom_link_values => {
                    topic_id => $topic ? $topic->id : 0,
                }
            }
        )
    );

    $self->init_fields;

    eval {
        my $limited_users = CTX->lookup_action( 'dicole_domains' )->execute(
            'users_by_user', { user_id => CTX->request->target_user_id }
        );

        $self->gtool->Data->selected_where(
            list => { $self->gtool->Data->object->id_field => $limited_users }
        );
    };

    $self->_add_config_select_box(
        box => $self->tool->Container->box_at( 0, 0 ),
        selected => 'share_matrix',
    );

    if ( $topic ) {
        $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select user to share topic [_1] with', $topic->name ) );
    }
    else {
        $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select user to share all topics with') );
    }

    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

sub add_share_group {
    my ( $self ) = @_;

    my $topic = $self->_fetch_current_topic;

    $self->init_tool(
        rows => 1,
        cols => 2,
        tab_override => 'share_matrix',
    );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'groups' ),
            current_view => 'add_share_group',
            skip_security => 1,
            initial_construct_params => {
                custom_link_values => {
                    topic_id => $topic ? $topic->id : 0,
                }
            }
        )
    );

    $self->init_fields;

    my $limited_groups = eval {
        CTX->lookup_action( 'dicole_domains' )->execute(
            'groups_by_user', { user_id => CTX->request->target_user_id }
        );
    };
    if ( $@ ) {
        my $groups = CTX->lookup_object('groups')->fetch_group || [];
        $limited_groups = [ map { $_->id } @$groups ];
    }

    my @real_groups = ();
    for ( @$limited_groups ) {
        push @real_groups, $_ if $self->schk_y(
            'OpenInteract2::Action::Groups::show_info', $_
        );
    }

    $self->gtool->Data->selected_where(
        list => { $self->gtool->Data->object->id_field => \@real_groups }
    );

    $self->_add_config_select_box(
        box => $self->tool->Container->box_at( 0, 0 ),
        selected => 'share_matrix',
    );

    if ( $topic ) {
        $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select group to share topic [_1] with', $topic->name ) );
    }
    else {
        $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select group to share all topics with') );
    }

    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

###########################################
# PRIVATE FUNCTIONS

sub _ping_feedreader_for_post {
    my ( $self, $post, $topics ) = @_;
    
    unless ( $topics ) {
        my $topic_objects = $post->weblog_topics;
        $topics = [ map { $_->id } @$topic_objects ];
    }
    
    $self->derive_feedreader_ping(
        task => 'feed',
    );
    for my $topic ( @$topics ) {
        $self->derive_feedreader_ping(
            task => 'feed_topic',
            additional => [ $topic ],
        );
    }
}

sub _ping_feedreader_for_comment {
    my ( $self, $comment, $post, $topics ) = @_;
    
    unless ( $post ) {
        $post = $comment->weblog_posts;
    }
    
    unless ( $topics ) {
        my $topic_objects = $post->weblog_topics;
        $topics = [ map { $_->id } @$topic_objects ];
    }
    
    $self->derive_feedreader_ping(
        task => 'comment_feed',
    );
    for my $topic ( @$topics ) {
        $self->derive_feedreader_ping(
            task => 'comment_feed_topic',
            additional => [ $topic ],
        );
    }
    
    $self->_ping_feedreader_for_post( $post, $topics );
}

sub _get_legal_topics {
    my ( $self ) = @_;
    
    my $topic_hash = Dicole::Utility->checked_from_apache('topic') || {};
    my @topic_ids = keys %$topic_hash;
    my $user_id = $self->target_user_id || 0;
    my $group_id = $self->target_group_id || 0;
    
    my $topics = Dicole::Utils::SPOPS->fetch_objects(
        object_name => 'weblog_topics',
        ids => \@topic_ids,
    );
    
    my @legal_ids = ();
    
    for my $topic ( @$topics ) {
        push @legal_ids, $topic->id if
            $topic->user_id == $user_id && $topic->groups_id == $group_id;
    }
    
    return \@legal_ids;
}

sub _add_post_as_reply_to {
    my ( $self, $reply, $post ) = @_;

    my $reply_id = ref( $reply ) ? $reply->id : $reply;
    my $post_id = ref( $post ) ? $post->id : $post;

    my $trackback = CTX->lookup_object( 'weblog_trackbacks' )->new( {
        post_id => $post_id,
        reply_id => $reply_id,
    } );
    eval { $trackback->save; };
}

sub _user_has_right_to_comment {
    my ( $self, $post, $topics ) = @_;
    my $target_type = $post->groups_id ? 'group' : 'user';
    my $target_id = $post->groups_id ? $post->groups_id : $post->user_id;
    return 1 if $self->chk_y( $target_type . '_comment', $target_id );

    $topics ||= $post->weblog_topics || [];

    for my $topic ( @$topics ) {
        return 1 if
            $self->chk_y( $target_type . '_comment_topic', $topic->id );
    }
    return 0;
}

sub _available_groups {
    my ($self) = @_;

    my $creator = new Dicole::Tree::Creator::Hash (
        id_key => 'groups_id',
        parent_id_key => 'parent_id',
        order_key => '',
        parent_key => '',
        sub_elements_key => 'sub_elements',
    );

    $creator->add_element_array( CTX->lookup_object('groups')->fetch_group );

    return $self->_rec_available_groups( $creator->create );
}

sub _rec_available_groups {
    my ($self, $array) = @_;

    return [] if ref $array ne 'ARRAY';

    my @return;

    foreach my $group (@$array) {
        next unless $self->schk_y( 'OpenInteract2::Action::Groups::show_info', $group->{groups_id} );

        push @return, $group;
        push @return, @{ $self->_rec_available_groups( $group->{sub_elements} ) };
    }

    return \@return;
}

sub _add_config_select_box {
    my ( $self, %p ) = @_;

    $self->tool->Container->column_width( '1%' );

    my $items =  [];

    if ( $self->param('target_type') eq 'user' ) {
        push @$items, [ $self->_msg('Topics'), 'config' ];
        push @$items, [ $self->_msg('General settings'), 'settings' ];
        push @$items, [ $self->_msg('Bookmarklets'), 'bookmarklets' ] if
            $self->chk_y( 'user_add' );
    }
    else {
        push @$items, [ $self->_msg('Topics'), 'config' ];
        push @$items, [ $self->_msg('General settings'), 'settings' ];
        push @$items, [ $self->_msg('Bookmarklets'), 'bookmarklets' ] if
            $self->chk_y( 'group_add' );
    }

    $p{box}->name( $self->_msg('Category') );

    my $content = [];

    for ( @$items ) {

        my $hl = Dicole::Widget::Hyperlink->new(
            content => $_->[0],
            link => $self->derive_url(
                task => $_->[1],
                additional => [],
            ),
        );

        $hl->class( 'bold' ) if $_->[1] eq $p{selected};

        push @$content, $hl;
    }

    $p{box}->add_content( $content );
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

sub _fetch_current_topic {
    my ( $self ) = @_;

    my $topic_id = $self->param( 'target_object_id' );

    return undef if ! $topic_id || $topic_id !~ /^\d+$/;

    my $topic = eval {
        CTX->lookup_object( 'weblog_topics' )->fetch( $topic_id );
    };

    if ( $self->param('target_type') eq 'group' ) {
        return undef if $topic->{groups_id} != $self->target_group_id;
    }
    else {
        return undef if $topic->{user_id} != $self->target_user_id;
    }

    return $topic;
}

sub _check_if_post_exists {
    my ( $self, $post_id ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('weblog_posts') );
    $data->data_single( $post_id );

    my $redirect = Dicole::URL->create_from_current(
        task => 'posts'
    );
    if ( !ref( $data->data) ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Blog entry with id [_1] does not exist or it was deleted.', $post_id )
        );
        CTX->response->redirect( $redirect );
        return undef;
    }
    else {
        if ( ( $self->param('target_type') eq 'group'
            && $data->data->{groups_id} != CTX->request->target_group_id ) ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Access denied to read entry with id [_1].', $post_id )
            );
            $self->log( 'warn', sprintf(
                "User id [%s] has no right to access entry with id [%s] because "
                . "entry group id [%s] is not the same as the target group id [%s]",
                CTX->request->auth_user_id, $post_id,
                $data->data->{groups_id}, CTX->request->target_group_id
            ) );
            CTX->response->redirect( $redirect );
            return undef;
        }
        elsif ( $self->param('target_type') ne 'group' &&
            $data->data->{user_id} != CTX->request->target_user_id ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Access denied to read entry with id [_1].', $post_id )
            );
            $self->log( 'warn', sprintf(
                "User id [%s] has no right to access entry with id [%s] because "
                . "entry user id [%s] is not the same as the target user id [%s]",
                CTX->request->auth_user_id, $post_id,
                $data->data->{user_id}, CTX->request->target_user_id
            ) );
            CTX->response->redirect( $redirect );
            return undef;
        }
    }
    return $data;
}

sub _get_topic_list {
    my ( $self, %args ) = @_;

    my $gtool = Dicole::Generictool->new(
            object => CTX->lookup_object('weblog_topics'),
            skip_security => 1,
            current_view => 'topic_list',
    );

    $self->init_fields(
        gtool => $gtool,
    );

    if ( $self->param('target_type') eq 'group' ) {
        $gtool->Data->add_where( 'groups_id = ' . CTX->request->target_group_id );
    } else {
        $gtool->Data->add_where( 'user_id = ' . CTX->request->target_user_id );
    }
    $gtool->add_bottom_button(
        name => 'remove',
        value => $self->_msg('Remove selected')
    ) if $args{remove};

    my $sel = $gtool->get_sel(
        checkbox_id => 'topic',
        checked => $args{selected},
    );
    return $sel;
}

sub _get_accessible_abstracts {
    my ( $self, $topics, $selected_topic, $limit ) = @_;

    my $time = time;
    my $query_limiter =  $self->_get_target_query_limiter . ' AND '.
        $self->_get_visible_query_limiter( $time );

    if ( $selected_topic ) {
        $topics = [ $selected_topic ];
    }

    my $browse = Dicole::Generictool::Browse->new( {
        action => [ # Make browse page unique.
            CTX->request->action_name . '_' .
            $self->param('target_user_id') . '_' .
            $self->param('target_group_id') . '_' .
            ( $selected_topic ? $selected_topic->id : 0)
        ]
    } );
    $browse->default_limit_size( DEFAULT_POSTS_ON_PAGE );
    $browse->set_limits;

    my $posts;
    if ( ! $selected_topic &&
        $self->chk_y( $self->param('target_type') . '_read' ) ) {

        my $total_count = CTX->lookup_object('weblog_posts')->fetch_count( {
            where => $query_limiter,
        } );
        $browse->total_count( $total_count );
        if ( $total_count && $total_count <= $browse->limit_start ) {
            my $raw_pages = $total_count / $browse->limit_size;
            my $actual_pages = int( $raw_pages );
            $actual_pages -= 1 if $raw_pages == $actual_pages;
            $browse->set_limits( $actual_pages * $browse->limit_size );
        }

        $posts = CTX->lookup_object('weblog_posts')->fetch_group( {
            where => $query_limiter,
            order => 'date DESC',
            limit => $browse->get_limit_query,
        } ) || [];
    }
    else {
        $query_limiter .=
            ' AND ' . $self->_get_accessible_query_limiter( $topics );

        my $total_count = CTX->lookup_object('weblog_posts')->fetch_count( {
            from => ['dicole_weblog_posts', 'dicole_weblog_topics_link'],
            select_modifier => 'DISTINCT',
            where => $query_limiter,
        } );
        $browse->total_count( $total_count );
        if ( $total_count && $total_count <= $browse->limit_start ) {
            my $raw_pages = $total_count / $browse->limit_size;
            my $actual_pages = int( $raw_pages );
            $actual_pages -= 1 if $raw_pages == $actual_pages;
            $browse->set_limits( $actual_pages * $browse->limit_size );
        }

        $posts = CTX->lookup_object('weblog_posts')->fetch_group( {
            from => ['dicole_weblog_posts', 'dicole_weblog_topics_link'],
            select_modifier => 'DISTINCT',
            where => $query_limiter,
            order => 'dicole_weblog_posts.date DESC',
            limit => $browse->get_limit_query,
        } ) || [];
   }

    unless (scalar @{ $posts } ) {
        return Dicole::Content::Text->new(
            text => $self->_msg('No entries.')
        );
    }

    my $return = [];

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object( 'weblog_posts' ),
            current_view => 'posts',
        )
    );

    $self->init_fields;

    my @ids = map { $_->id } @{ $posts };
    my $counts = $self->_count_comments_and_trackbacks( \@ids, $time );

    foreach my $post ( @{ $posts } ) {
        my $message = $self->_get_post( $post, $selected_topic );
        my $button = Dicole::Content::Hyperlink->new(
            content => $self->_msg( 'Permalink and comments ([_1])',
                $counts->{ $post->id } || '0' ),
            attributes => {
                href => $self->derive_url(
                    task => 'show',
                    additional => [
                        $selected_topic ? $selected_topic->id : 0,
                        $post->id
                    ],
                )
            }
        );
        $message->add_message( $button );
        push @{ $return }, $message;
    }

    my $browse_content = $browse->get_browse;
    push @{ $return }, $browse_content if $browse_content;

    return $return;
}

sub _get_target_query_limiter {
    my ( $self ) = @_;
    my $query_limiter = undef;
    if ( $self->param('target_type') eq 'group' ) {
        $query_limiter = 'groups_id = ' . CTX->request->target_group_id;
    }
    else {
        $query_limiter = 'user_id = ' . CTX->request->target_user_id;
    }
    return $query_limiter;
}

sub _get_visible_query_limiter {
    my ( $self, $time ) = @_;
    $time ||= time;
    my $query_limiter =
        '( dicole_weblog_posts.removal_date_enable is null OR '.
        'dicole_weblog_posts.removal_date_enable != 1 OR '.
        'dicole_weblog_posts.removal_date > '.$time.' ) AND '.
        'dicole_weblog_posts.publish_date < '.$time.' AND '.
        'dicole_weblog_posts.date < ' . $time;

    return $query_limiter;
}

sub _get_accessible_query_limiter {
    my ( $self, $topics ) = @_;

    return 'AND 1=0' unless ref $topics eq 'ARRAY' && scalar( @$topics );

    my $query_limiter =
        'dicole_weblog_posts.post_id = dicole_weblog_topics_link.post_id AND '
        . Dicole::Utils::SQL->column_in(
            'dicole_weblog_topics_link.topic_id', [ map { $_->id } @$topics ]
        );

    return $query_limiter;
}

sub _get_accessible_topics {
    my ( $self, $topics ) = @_;

    $topics ||= CTX->lookup_object('weblog_topics')->fetch_group( {
        where => $self->_get_target_query_limiter
    } ) || [];

    my @accessible;
    for my $topic ( @$topics ) {
        push @accessible, $topic if $self->chk_y(
             $self->param('target_type') . '_read_topic', $topic->id
        );
    }

    return \@accessible;
}

sub _get_comments {
    my ( $self, $topic, $post_id ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('weblog_comments') );
    $data->query_params( {
        where => 'post_id = ?',
        value => [ $post_id ],
        order => 'date',
    } );
    $data->data_group;

    return [] unless scalar @{ $data->data };

    my $return = [];

    foreach my $comment ( @{ $data->data } ) {
        my $message = Dicole::Content::Message->new;
        $message->title( $comment->{title} );
        $message->author_name(
            $self->_get_author_name_from_comment( $comment)
        );
        $message->author_href(
            $comment->{url}
        );
        $message->date(
            Dicole::DateTime->full_datetime_format( $comment->{date} )
        );
        $message->add_message( $comment->{content} );

        my $right = $self->param('target_type') . '_comment_delete';
        my $auth_id = CTX->request->auth_user_id;
        if ( $auth_id && $auth_id == $comment->user_id ||
                $self->chk_y( $right ) ) {

            $message->add_controls( {
                type  => 'confirm_submit',
                value => $self->_msg( 'Remove' ),
                confirm_box => {
                    title => $self->_msg( 'Confirmation' ),
                    name => 'comment_' . $comment->id,
                    msg   => $self->_msg( 'Are you sure you want to remove the selected comment?' ),
                    href  => Dicole::URL->create_from_current(
                        task => 'show',
                        additional => [ $topic ? $topic->id : 0, $post_id ],
                        params => { comment_id => $comment->id }
                    )
                }
            } );
        }
        push @{ $return }, $message;
    }
    return $return;
}

sub _get_author_name_from_comment {
        my ( $self, $comment, $prefetched_name ) = @_;

        if ( $comment->user_id ) {
            return $prefetched_name if $prefetched_name;
            my $author = $comment->user( { skip_security => 1 } );
            if ( $author ) {
                return $author->{first_name} . " " . $author->{last_name}
            }
        };

        return $comment->name if $comment->name;
        return $self->_msg('Anonymous');
}

sub _get_trackbacks {
    my ( $self, $post_id ) = @_;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('weblog_posts') );
    my $time = time;
    $data->query_params( {
        from => [ 'dicole_weblog_posts', 'dicole_weblog_trackbacks' ],
        where => 'dicole_weblog_posts.post_id = '.
            'dicole_weblog_trackbacks.reply_id AND '.
            'dicole_weblog_trackbacks.post_id = ? AND '.
            $self->_get_visible_query_limiter( $time ),
        value => [ $post_id ],
        order => 'date',
    } );
    $data->data_group;

    return [] unless scalar @{ $data->data };

    my $return = [];

    foreach my $post ( @{ $data->data } ) {
        my $message = Dicole::Content::Message->new;
        $message->title( $post->{title} );
        my $author = $post->writer_user( { skip_security => 1 } );
        $message->author_name(
            $author->{first_name} . " " . $author->{last_name}
        );
        $message->date(
            Dicole::DateTime->full_datetime_format( $post->{date} )
        );
        my $post_type = $post->groups_id ? 'group' : 'personal';
        my $href = Dicole::URL->create_from_parts(
            action => $post_type . '_weblog',
            task => 'show',
            target => $post->groups_id || $post->user_id,
            additional => [ 0, $post->id ],
        );
        $message->title_url( $href );

        my $text = Dicole::Utils::HTML->html_to_text( $post->{content} );
        my $cut_text = substr( $text, 0, 550);

        if ( length($text) != length($cut_text) ) {
            # remove the last word.
            ($cut_text) = $cut_text =~ /(.*)\s.*/s;
            $cut_text .= '.. ';
            $message->add_message(
                Dicole::Widget::Horizontal->new(
                    contents => [
                        $cut_text,
                        Dicole::Widget::Hyperlink->new(
                            link => $href,
                            content => $self->_msg('Read more..'),
                        )
                    ]
                )
            );
        }
        else {
            $message->add_message( $cut_text );
        }

        my $right = $self->param('target_type') . '_comment_delete';
        if ( CTX->request->auth_user_id == $post->writer ||
                $self->chk_y( $right ) ) {

            $message->add_controls( {
                type  => 'confirm_submit',
                value => $self->_msg( 'Remove' ),
                confirm_box => {
                    title => $self->_msg( 'Confirmation' ),
                    name => 'trackback_' . $post->id,
                    msg   => $self->_msg( 'Are you sure you want to remove the post from replies?' ),
                    href  => $self->derive_url(
                        params => { trackback_id => $post->id }
                    )
                }
            } );
        }
        push @{ $return }, $message;
    }
    return $return;
}

sub _get_reverse_trackbacks {
    my ( $self, $post_id ) = @_;

    my $time = time;
    my $replied_posts = CTX->lookup_object('weblog_posts')->fetch_group( {
        from => [ 'dicole_weblog_posts', 'dicole_weblog_trackbacks' ],
        where => 'dicole_weblog_posts.post_id = '.
            'dicole_weblog_trackbacks.post_id AND '.
            'dicole_weblog_trackbacks.reply_id = ? AND '.
            $self->_get_visible_query_limiter( $time ),
        value => [ $post_id ],
        order => 'date DESC',
    } ) || [];

    return [] unless scalar @{ $replied_posts };

    my $return = [];

    foreach my $post ( @{ $replied_posts } ) {
        my $line = Dicole::Widget::Horizontal->new;

        my $author = $post->writer_user( { skip_security => 1 } );

        my $post_type = $post->groups_id ? 'group' : 'personal';
        my $href = Dicole::URL->create_from_parts(
            action => $post_type . '_weblog',
            task => 'show',
            target => $post->groups_id || $post->user_id,
            additional => [ 0, $post->id ],
        );

        $line->add_content(
            $author->{first_name} . " " . $author->{last_name} . ' : ',
            Dicole::Widget::Hyperlink->new(
                content => $post->{title},
                link => $href,
            ),
            '( '.Dicole::DateTime->full_datetime_format( $post->{date} ).' )',
        );

        push @{ $return }, $line;
    }
    return $return;
}

sub _get_post {
    my ( $self, $post, $topic ) = @_;

    my $message = Dicole::Content::Message->new;

    $message->title( $post->{title} );

    # Show abstract only if it exists
    if ( $post->{abstract} ) {
        my $abstract = Dicole::Content::Text->new(
            text => $post->{abstract},
            html_line_break => 1
        );
        $abstract->attributes( {
            class => 'textAbstract'
        } );
        $message->add_message( $abstract );
    }
    
    my $content_html = $post->{content};
    if ( my $a = eval { CTX->lookup_action('file_attachment') } ) {
        my $topic_id = $topic ? $topic->id : 0;
        $content_html = $a->execute( 'prefix_links', {
            html => $content_html,
            prefix => join '/', (
                '', $self->name, 'attached_file',
                $self->param('target_id'),
                $topic_id , $post->id
            ),
        } );
    }
    
    my $content = Dicole::Content::Text->new(
        text => $content_html,
        no_filter => 1
    );
    $message->add_message( $content );

    my $titles = $post->weblog_topics || [];

    # Create list of topics
    if ( scalar( @$titles ) ) {
        my @meta = map { $_->{name} } @$titles;
        my $topics_field = $self->gtool->get_field( 'list_of_topics' );
        $topics_field->value( join ', ', @meta );
        $topics_field->use_field_value( 1 );
    }
    else {
        $self->gtool->del_visible_fields(
            $self->gtool->current_view, [ 'list_of_topics' ]
        );
    }

    # Fetch profile image and set it in message meta
    my $profile = CTX->lookup_object( 'profile' )->fetch_group( {
        where => 'user_id = ?',
        value => [ $post->{writer} ]
    } );
    $profile->[0]{pro_image} =~ s/(\.\w+)$/_t$1/;
    $post->{pro_image} = $profile->[0]{pro_image};

    # If no portrait is set, remove image field to save space
    unless ( $post->{pro_image} ) {
        $self->gtool->del_visible_fields( $self->gtool->current_view, [ 'pro_image' ] );
    }

    # Use generictool to generate post metadata fields
    my $metas = $self->gtool->construct_fields(
        $post, $self->gtool->visible_fields
    );
    my $i = 0;
    foreach my $field_id ( @{ $self->gtool->visible_fields } ) {
        my $field = $self->gtool->get_field( $field_id );
        $message->add_meta( $field->desc, $metas->[$i] );
        $i++;
    }
    return $message;
}

sub _get_recent {
    my ( $self, $topics, $selected_topic ) = @_;

    my $time = time;
    my $query_limiter =  $self->_get_target_query_limiter . ' AND ' .
        $self->_get_visible_query_limiter( $time );

    if ( $selected_topic ) {
        $topics = [ $selected_topic ];
    }

    my $posts;
    if ( ! $selected_topic &&
        $self->chk_y( $self->param('target_type') . '_read' ) ) {

        $posts = CTX->lookup_object('weblog_posts')->fetch_group( {
            where => $query_limiter,
            order => 'date DESC',
            limit => 10,
        } ) || [];
    }
    else {
        $query_limiter .=
            ' AND ' . $self->_get_accessible_query_limiter( $topics );

        $posts = CTX->lookup_object('weblog_posts')->fetch_group( {
            from => ['dicole_weblog_posts', 'dicole_weblog_topics_link'],
            select_modifier => 'DISTINCT',
            where => $query_limiter,
            order => 'dicole_weblog_posts.date DESC',
            limit => 10,
        } ) || [];
   }

    my @ids = map { $_->id } @$posts;
    my $counts = $self->_count_comments_and_trackbacks( \@ids, $time );

    my $return = [];
    my $last_date = -1;

    foreach my $post ( @$posts ) {
        my $date_string = Dicole::DateTime->date( $post->{date} );
        if ( $date_string ne $last_date ) {
            my $date = Dicole::Content::Text->new(
                content => $date_string
            );
            push @{ $return }, $date;
            $last_date = $date_string;
        }

        my $count = $counts->{ $post->id };
        my $title = $post->{title} . ( $count ? " ($count)" : '' );

        my $item = Dicole::Content::Hyperlink->new(
            content => $title,
            attributes => {
                href => $self->derive_url(
                    task => 'show',
                    additional => [
                        $selected_topic ? $selected_topic->id : 0,
                        $post->id
                    ],
                )
            },
        );
        push @{ $return }, $item;
    }
    return $return;
}

sub _get_all_topics {
    my ( $self ) = @_;

    my $topics = CTX->lookup_object('weblog_topics')->fetch_group( {
        where => $self->_get_target_query_limiter,
    } ) || [];

    return $topics;
}

sub _get_topic_select {
    my ( $self, $topics ) = @_;

    return undef unless scalar( @$topics );

    my $return = [];

    my $all_msg = $self->chk_y( $self->param('target_type') . '_read' ) ?
        $self->_msg('All topics') :
        $self->_msg('All shared topics');

    push @{ $return }, Dicole::Content::Hyperlink->new(
        content => $all_msg,
        attributes => {
            href => Dicole::URL->create_from_current(
                task => 'posts',
                additional => [],
            )
        }
    );

    foreach my $topic ( @$topics ) {
        my $item = Dicole::Content::Hyperlink->new(
            content => $topic->{name},
            attributes => {
                href => Dicole::URL->create_from_current(
                    task => 'posts',
                    additional => [ $topic->id ],
                )
            },
        );
        push @{ $return }, $item;
    }
    return $return;
}

# returns a hashref containing counts for each post keyed with id
# first parameter is an arrayref of id's
sub _count_comments_and_trackbacks {
    my ( $self, $ids, $time ) = @_;

    return {} unless ref $ids eq 'ARRAY' && scalar( @$ids );
    $time ||= time;

    my $comments = CTX->lookup_object('weblog_comments')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( 'post_id ', $ids )
    } ) || [];

    my $trackbacks = CTX->lookup_object('weblog_trackbacks')->fetch_group( {
            from => [ 'dicole_weblog_posts', 'dicole_weblog_trackbacks' ],
            where => Dicole::Utils::SQL->column_in(
                    'dicole_weblog_trackbacks.post_id ', $ids
                ) . ' AND '.
                'dicole_weblog_posts.post_id = '.
                'dicole_weblog_trackbacks.reply_id AND '.
                $self->_get_visible_query_limiter( $time ),
    } );

    my %total = ();
    $total{ $_->post_id }++ for @$comments;
    $total{ $_->post_id }++ for @$trackbacks;

    return \%total;
}

sub _check_ip_blocking {
    my ( $self, $settings_hash, $topic ) = @_;
    
    if ( ! $settings_hash ) {
        my $settings = $self->_get_settings;
        $settings->fetch_settings;
        $settings_hash = $settings->settings_as_hash;
    }

    if ( ! $self->skip_secure && ! CTX->request->auth_is_logged_in ) {

        my $ipc = 'ip_addresses_feed';
        $ipc .= '_' . $topic->id if $topic;

        if ( $settings_hash->{$ipc} =~ /^\d+/ ) {
            if ( ! $self->_check_ip_addresses( $settings_hash->{$ipc} ) ) {
                die 'security error';
            }
        }
    }
}

sub _check_post_expired {
    my ($self, $data) = @_;
    # user edit rights
    if ($self->chk_y( $self->param('target_type') . '_edit' )) { return 1; }
    # publish & removal date
    my $time = time;
    if (! (($data->data->{ removal_date_enable }) && ($data->data->{ removal_date } < $time))) {
        if ($data->data->{ publish_date } < $time) {
            return 1 if ($data->data->{ date } < $time);
        }
    }
    return 0;
}

sub _hack_check {
    my ( $self, $topic ) = @_;

    return if $self->skip_secure;

    # to make sure before multiple targets in secure
    # that no general listing is allowed by using nonexisting
    # topic which user has rights to

    if ( ! $topic ) {
        die 'Access denied.' if @{ $self->secure_success } == 1 &&
            $self->secure_success->[0] =~ /topic$/;
    }
}

sub _add_onunload_warning {
    my ( $self ) = @_;
    
    $self->tool->add_end_widgets(
        Dicole::Widget::Javascript->new(
            code => 'beforeunload_strings = ' . Dicole::Utils::JSON->encode( {
                warning => $self->_msg('You have not saved the text you have written. If you continue you will lose the text you have written.')
            } ),
        ),
        Dicole::Widget::Javascript->new(
            code => <<CODE,
window.onbeforeunload = function() { try {
        var content = tinyMCE.getContent();
        var isEmpty = new RegExp("^(\\n| |&nbsp;|<br />)*(<p>(\\n| |&nbsp;|<br />)*</p>(\\n| |&nbsp;|<br />)*)*\$", "i");
        if ( ! last_form_submit ) {
            if ( content == null || content.match(isEmpty) == null ) {
                return beforeunload_strings['warning'];
            }
        }
    }
    catch (e) {alert(e);}
}
CODE
        )
    );
}
=pod

=head1 NAME

Personal and group weblog

=head1 DESCRIPTION

A weblog, or simply a blog, is a web application which contains periodic,
reverse chronologically ordered posts. It is related to an online journal,
but it's functionality is more social and collaborative than journals
and news publishing systems typically are.

Dicole weblog is available for personal and group use. It allows you to
add, edit, remove and display individual posts, provide RSS feeds,
allow commenting on posts and record your posts under multiple
categories.

A summary is generated on the summary page, containing the latest weblog
posts.

=head1 BUGS

None known.

=head1 TODO

Trackbacks, pingbacks, public sharing, personal weblog, commenting, better
calendar based navigation of posts.

=head1 AUTHORS

Antti V��otam�i, Teemu Arina

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
