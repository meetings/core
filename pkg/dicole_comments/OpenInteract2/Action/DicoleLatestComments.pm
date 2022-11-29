package OpenInteract2::Action::DicoleLatestComments;

use strict;
use base qw( OpenInteract2::Action::DicoleComments );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::MessageHandler qw( :message );
use Dicole::Widget::KVListing;
use HTML::Entities;
use List::Util;

sub _discussions {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $info = $self->_fetch_rolling_list_info( $gid, $self->DEFAULT_DISCUSSION_SIZE );

    my $params = {
        entries => $info->{object_info_list},
        script_data_json => $self->_generate_script_data_json( $gid, $info ),
        end_of_pages => $info->{end_of_pages},
    };

    my $content = $self->generate_content( $params, { name => 'dicole_comments::discussions_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Latest discussion topics') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _faces {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $limit = 5;
    my $info = [];
    my %processed = ();

    while ( @$info < $limit  ) {
        my $comments = CTX->lookup_object('comments_post')->fetch_group( {
            from => [ 'dicole_comments_thread', 'dicole_comments_post' ],
            where => 'dicole_comments_thread.thread_id = dicole_comments_post.thread_id AND ' .
                'dicole_comments_thread.group_id = ?' .
                ' AND dicole_comments_post.removed = 0 AND dicole_comments_post.published != 0' .
                ' AND ' . Dicole::Utils::SQL->column_not_in( 'dicole_comments_post.post_id' => [ keys %processed ] ),
            value => [ $gid ],
            order => 'dicole_comments_post.date desc',
            limit => 50,
        } );
        last unless @$comments;

        for my $comment ( @$comments ) {
            next if $processed{$comment->id}++;
            push @$info, $self->_generate_comment_info( $comment, undef, $gid, $domain_id );
            last unless @$info < $limit;
        }
    }


    my $params = {
        comments => $info,
    };

    my $content = $self->generate_content( $params, { name => 'dicole_comments::comments_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Latest comments') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _all {
    my ( $self ) = @_;

    return OpenInteract2::Action::DicoleLatestComments::All->new( $self, {
        box_title => $self->_msg('Latest comments'),
        object => 'comments_post',
        query_options => {
            from => [ 'dicole_comments_thread', 'dicole_comments_post' ],
            where => 'dicole_comments_thread.thread_id = dicole_comments_post.thread_id' .
                ' AND dicole_comments_post.removed = 0 AND dicole_comments_post.published != 0' .
                ' AND dicole_comments_thread.group_id = ?',
            value => [ $self->param('target_group_id') ],
            order => 'dicole_comments_post.date desc',
            limit => 5,
        },
        empty_box_string => $self->_msg('No comments found.'),
        date_field => 'date',
        user_field => 'user_id',
        dated_list_separator_set => 'date & time',
    } )->execute;
}

sub _entry_url_title {
    my ( $self, $entry, $post, $user ) = @_;
    
    $post ||= CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
#    $user ||= CTX->lookup_object('user')->fetch( $entry->user_id );
    
    my $urltitle = Dicole::Utils::Text->utf8_to_url_readable(
        $post->title
    );
    
    return $urltitle;
}

sub _generate_comment_info {
    my ( $self, $comment, $thread, $gid, $domain_id ) = @_;

    $thread ||= CTX->lookup_object('comments_thread')->fetch( $comment->thread_id );
    return () unless $thread;

    if ($thread->object_type eq "OpenInteract2::BlogsEntry") {
        my $entry = CTX->lookup_object('blogs_entry')->fetch( $thread->object_id );
        return () unless $entry;

        my $post = CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
        return () unless $post;

        return {
            comment_title => $self->_msg( 'Comment to [_1]' , $post->title ),
            comment_url => Dicole::URL->create_from_parts(
                action => 'blogs',
                task => 'show',
                target => $entry->group_id,
                additional => [ $entry->seed_id, $entry->id, $self->_entry_url_title( $entry, $post ) ],
                anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id,
            ),
            date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
            $self->_gather_author_details( $comment->user_id, $gid, $domain_id ),
        }
    }
    elsif ($thread->object_type eq "OpenInteract2::WikiPage") {
        my $page = CTX->lookup_object('wiki_page')->fetch($thread->object_id);
        return () unless $page;

        return {
            comment_title => $self->_msg( 'Comment to page [_1]' , $page->readable_title ),
            comment_url => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $thread->group_id,
                additional => [ $page->title ],
                anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id,
            ),
            date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
            $self->_gather_author_details( $comment->user_id, $gid, $domain_id ),
        }
    }
    elsif ($thread->object_type eq "OpenInteract2::WikiAnnotation") {
        my $anno = CTX->lookup_object('wiki_annotation')->fetch($thread->object_id);
        return () unless $anno;
        my $page = CTX->lookup_object('wiki_page')->fetch($anno->page_id);
        return () unless $page;

        return {
            comment_title => $self->_msg( 'Comment to page [_1]' , $page->readable_title ),
            comment_url => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $thread->group_id,
                additional => [ $page->title ],
                anchor => 'wiki_anno_comment_link_' . $anno->id,
            ),
            date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
            $self->_gather_author_details( $comment->user_id, $gid, $domain_id ),
        }
    }
    elsif ($thread->object_type eq "OpenInteract2::PresentationsPrese") {
        my $prese = CTX->lookup_object('presentations_prese')->fetch($thread->object_id);
        return () unless $prese;

        if(CTX->controller->initial_action->param('domain_id') == 70)
        {
            return {
                comment_title => $self->_msg( 'Comment to media [_1]' , $prese->name ),
                comment_url => Dicole::URL->create_from_parts(
                    action => 'presentations',
                    task => 'browse',
                    target => $thread->group_id,
                    anchor => $prese->prese_id . '_' . $comment->thread_id . '_' . $comment->id
                ),
                date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
                $self->_gather_author_details( $comment->user_id, $gid, $domain_id ),
            }
        }
        return {
            comment_title => $self->_msg( 'Comment to media [_1]' , $prese->name ),
            comment_url => Dicole::URL->create_from_parts(
                action => 'presentations',
                task => 'show',
                target => $thread->group_id,
                additional => [$thread->object_id],
                anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id
            ),
            date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
            $self->_gather_author_details( $comment->user_id, $gid, $domain_id ),
        }
    }
    elsif ($thread->object_type eq "OpenInteract2::EventsEvent") {
        my $event = CTX->lookup_object('events_event')->fetch($thread->object_id);
        return () unless $event;

        return {
            comment_title => $self->_msg( 'Comment to event [_1]' , $event->title ),
            comment_url => Dicole::URL->create_from_parts(
                action => 'events',
                task => 'show',
                target => $thread->group_id,
                additional => [$thread->object_id],
                anchor => 'comments_container',
            ),
            date => Dicole::Utils::Date->localized_ago( epoch => $comment->date ),
            $self->_gather_author_details( $comment->user_id, $gid, $domain_id, $comment ),
        }
    }
    return ();
}

sub _gather_author_details {
    my ( $self, $user_id, $gid, $domain_id, $comment ) = @_;

    if ( ! $user_id ) {
        return (
            author_name => $comment ? $comment->anon_name : '',
        );
    }

    my $hash = Dicole::Utils::User->icon_hash( $user_id, 40, $gid, $domain_id);

    my %hash = map { 'author_' . $_ => $hash->{ $_ } } keys %$hash;

    return %hash;
}

1;

package OpenInteract2::Action::DicoleLatestComments::All;

use strict;
use base qw( Dicole::Task::DatedListSummary );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _generate_item_title_widget {
    my ( $self, $item ) = @_;
    
    my $thread = CTX->lookup_object('comments_thread')->fetch( $item->thread_id );

    if ($thread->object_type eq "OpenInteract2::BlogsEntry")
    {
        my $entry = CTX->lookup_object('blogs_entry')->fetch( $thread->object_id );

        my $title = $self->_generate_item_title_text( $entry );
        my $link = $self->_generate_item_title_link( $item, $entry );
    
        return Dicole::Widget::Hyperlink->new(
            content => $self->action->_msg( 'Comment to [_1]' , $title ),
            link => $link,
            class => 'summary_list_title',
        );
    }
    if ($thread->object_type eq "OpenInteract2::WikiPage")
    {
        my $page = CTX->lookup_object('wiki_page')->fetch($thread->object_id);

        my $link = Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'show',
            target => $thread->group_id,
            additional => [ $page->title ],
            anchor => 'comments_message_' . $item->thread_id . '_' . $item->id,
        );
    
         return Dicole::Widget::Hyperlink->new(
            content => $self->action->_msg( 'Comment to page [_1]' , $page->title ),
            link => $link,
            class => 'summary_list_title',
        );
    }
    if ($thread->object_type eq "OpenInteract2::WikiAnnotation")
    {
        my $anno = CTX->lookup_object('wiki_annotation')->fetch($thread->object_id);
        my $page = CTX->lookup_object('wiki_page')->fetch($anno->page_id);

        my $link = Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'show',
            target => $thread->group_id,
            additional => [ $page->title ],
        );
    
         return Dicole::Widget::Hyperlink->new(
            content => $self->action->_msg( 'Comment to page [_1]' , $page->title ),
            link => $link,
            class => 'summary_list_title',
        );
    }
    if ($thread->object_type eq "OpenInteract2::PresentationsPrese")
    {
        my $prese = CTX->lookup_object('presentations_prese')->fetch($thread->object_id);

        if(CTX->controller->initial_action->param('domain_id') == 70)
        {
            my $link = Dicole::URL->create_from_parts(
                action => 'presentations',
                task => 'browse',
                target => $thread->group_id,
                anchor => $prese->prese_id . '_' . $item->thread_id . '_' . $item->id
            );

            return Dicole::Widget::Hyperlink->new(
                content => $self->action->_msg( 'Comment to media [_1]' , $prese->name ),
                link => $link,
                class => 'summary_list_title',
            );
        }

        my $link = Dicole::URL->create_from_parts(
            action => 'presentations',
            task => 'show',
            target => $thread->group_id,
            additional => [$thread->object_id],
            anchor => 'comments_message_' . $item->thread_id . '_' . $item->id
        );

        return Dicole::Widget::Hyperlink->new(
            content => $self->action->_msg( 'Comment to [_1]' , $prese->name ),
            link => $link,
            class => 'summary_list_title',
        );
    }
}

sub _generate_item_title_text {
    my ( $self, $item ) = @_;
    
    my $post = CTX->lookup_object('weblog_posts')->fetch( $item->post_id );
    return $post->title;
}

sub _generate_item_title_link {
    my ( $self, $comment, $item ) = @_;
    
    return Dicole::URL->create_from_parts(
        action => 'blogs',
        task => 'show',
        target => $item->group_id,
        additional => [ $item->seed_id, $item->id, $self->action->_entry_url_title( $item ) ],
        anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id,
    );
}

sub _generate_item_author_text {
    my ( $self, $item, $users_hash ) = @_;

    return $item->anon_name if $item->anon_name;
    return $self->SUPER::_generate_item_author_text( $item, $users_hash );
}

1;
