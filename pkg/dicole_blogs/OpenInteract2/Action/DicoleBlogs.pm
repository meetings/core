package OpenInteract2::Action::DicoleBlogs;

use strict;
use base qw( OpenInteract2::Action::DicoleBlogsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use HTML::Entities;
use Dicole::Widget::BlogPost;
use Dicole::Widget::TagSuggestionListing;
use Dicole::Widget::TagSuggestions;
use Dicole::Widget::FormControl::Tags;
use Dicole::Widget::FormControl::Checkbox;
use Dicole::Widget::Image;
use Dicole::Widget::TagCloudSuggestions;
use Dicole::Widget::FormControl::TextArea;
use CHI;

# use Log::Any::Adapter;
# Log::Any::Adapter->set(Dispatch => outputs => [[File => min_level => 'debug', filename => '/usr/local/dicole/crmjournal/logs/cache.log', newline => 1]]);

my $store = {};
my $cache = CHI->new(
    driver     => 'Memory',
    namespace  => 'dicole_blogs',
    expires_in => '1 day',
    datastore  => $store
#    debug      => 1,
);

sub _blogs_digest {
    my ( $self ) = @_;

   # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};
    $self->language( $self->param('lang') );

    my $group_id = $self->param('group_id');
    my $user_id = $self->param('user_id');
    my $domain_host = $self->param('domain_host');
    my $start_time = $self->param('start_time');
    my $end_time = $self->param('end_time');
    
    my $comments = CTX->lookup_object( 'comments_post' )->fetch_group( {
        from => [ 'dicole_comments_thread', 'dicole_comments_post' ],
        where => 'dicole_comments_thread.thread_id = dicole_comments_post.thread_id AND '.
            'dicole_comments_thread.group_id = ? AND dicole_comments_thread.object_type = ? AND ' .
            'published >= ? AND published < ? AND removed = ?',
        value => [ $group_id, CTX->lookup_object('blogs_entry'), $start_time, $end_time, 0 ],
    } ) || [];
    
    my $comments_by_thread = {};
    for my $comment ( @$comments ) {
        $comments_by_thread->{ $comment->thread_id } ||= [];
        push @{ $comments_by_thread->{ $comment->thread_id } }, $comment;
    }

    my $threads_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $comments,
        link_field => 'thread_id',
        object_name => 'comments_thread',
    );
    
    my $threads_by_entry = { map { $_->object_id => $_ } values %$threads_by_id };
    my @extra_entries_ids = keys %$threads_by_entry;

    my $disabled_seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND exclude_from_digest = ?',
        value => [ $group_id, 1 ],
    } ) || [];

    my @disabled_seed_ids = map { $_->id => 1 } @$disabled_seeds;

    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'group_id = ? AND ( (' .
            ' date >= ? AND date < ? AND ' .
            Dicole::Utils::SQL->column_not_in( seed_id => \@disabled_seed_ids )
            .' ) OR ( ' .
            Dicole::Utils::SQL->column_in( entry_id => \@extra_entries_ids ) .
            ' ) )',
        value => [ $group_id, $start_time, $end_time ],
        order => 'date DESC'
    } ) || [];
    
    if ( ! scalar( @$entries ) ) {
        return undef;
    }
    
    my $posts_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $entries,
        link_field => 'post_id',
        object_name => 'weblog_posts',
    );
    
    my $entry_users_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $entries,
        link_field => 'user_id',
        object_name => 'user',
    );
    
    my $comment_users_by_id = Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $comments,
        link_field => 'user_id',
        object_name => 'user',
    );
    
    my $users_by_id = {
        %$entry_users_by_id,
        %$comment_users_by_id,
    };

    my $return = {
        tool_name => $self->_msg( 'Conversations' ),
        items_html => [],
        items_plain => [],
    };
 
    for my $entry ( @$entries ) {
        my $post = $posts_by_id->{ $entry->post_id };
        my $user = $users_by_id->{ $entry->user_id };
        my $name = $user ? $user->first_name . ' ' . $user->last_name : $self->_msg('Unknown user');
        my $urltitle = Dicole::Utils::Text->utf8_to_url_readable(
            $post->title
        );

        my $link = $domain_host . Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'show',
            target => $group_id,
            additional => [
                $entry->seed_id, $entry->id, $urltitle
            ],
        );

        my $date_string = Dicole::DateTime->medium_datetime_format(
            $entry->date, $self->param('timezone'), $self->param('lang')
        );

        my $html = '<span class="date">' . Dicole::Utils::HTML->encode_entities($date_string) . '</span> - ' .
            '<a href="' . Dicole::Utils::HTML->encode_entities($link) . '">' . Dicole::Utils::HTML->encode_entities($post->title) . '</a> - ' . 
            '<span class="author">' . Dicole::Utils::HTML->encode_entities($name) . '</span>';

        my $text = $date_string . ' - ' . $post->title . ' - '  . $name . "\n  - " . $link;
        
        my $entry_comments = ref( $threads_by_entry->{ $entry->id } ) ?
            $comments_by_thread->{ $threads_by_entry->{ $entry->id }->id } || [] : [];
        if ( scalar( @$entry_comments ) ) {
            $html .= "\n" . '<ul>';
            for my $comment ( sort { $b->date <=> $a->date } @$entry_comments ) {
                my $cuser = $users_by_id->{ $comment->user_id };
                my $cname = $comment->anon_name;
                $cname ||= $cuser ? $cuser->first_name . ' ' . $cuser->last_name : $self->_msg('Unknown user');
                my $cdate_string = Dicole::DateTime->medium_datetime_format(
                    $comment->date, $self->param('timezone'), $self->param('lang')
                );
                my $clink = $domain_host . Dicole::URL->create_from_parts(
                    action => 'blogs',
                    task => 'show',
                    target => $group_id,
                    additional => [
                        $entry->seed_id, $entry->id, $urltitle
                    ],
                    anchor => 'comments_message_' . $comment->thread_id . '_' . $comment->id,
                );
                $html .= "\n" . '<li>';
                $html .= '<span class="date">' . Dicole::Utils::HTML->encode_entities($cdate_string) . '</span> - ' .
                    '<a href="' . Dicole::Utils::HTML->encode_entities($clink) . '">' . $self->_msg( 'Comment by [_1]', Dicole::Utils::HTML->encode_entities($cname) ) . '</a>';
                $html .= '</li>';
                
                $text .= '    * ' . $cdate_string . ' - ' . $self->_msg( 'Comment by [_1]', $cname ) . "\n" . $clink;
            }
            $html .= '</ul>';
        }
        
        push @{ $return->{items_html} }, $html;
        push @{ $return->{items_plain} }, $text;
    }

    return $return;
}

sub _featured_post_widget {
    my ( $self ) = @_;
    
    my $entries = $self->_generic_entries(
        group_id => CTX->request->target_group_id,
        order => 'dicole_blogs_entry.featured desc',
        where => 'dicole_blogs_entry.featured > 0',
        limit => 1,
    );
    
    my $entry = pop @$entries;
    return undef unless $entry;
    
    my $user = CTX->lookup_object('user')->fetch( $entry->user_id );
    my $post = CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
    return undef unless $post;
    
    my $show_url = Dicole::URL->create_from_parts(
        action => 'blogs',
        task => 'show',
        target => $entry->group_id,
        additional => [ 0, $entry->id, $self->_entry_url_title( $entry, $post, $user ) ],
    );
    my $date = Dicole::DateTime->long_date_format( $entry->date );
    my $title = Dicole::Widget::Hyperlink->new(
        link => $show_url, content => $post->{title}
    );
    
    my $content = $self->_process_post_content_for_output( $post->{content} );
    $content = Dicole::Utils::HTML->shorten( $content, 300 );
    $content = Dicole::Utils::HTML->break_long_strings( $content, 30 );
    
    my $read_more = Dicole::Widget::Hyperlink->new(
        link => $show_url,
        content => $self->_msg('Read more')
    );
    my $author = Dicole::Widget::Hyperlink->new(
        link => Dicole::URL->from_parts(
            action => 'networking',
            task => 'profile',
            target => CTX->request->target_group_id,
            additional => [ $user->id ],
        ),
        content => $user->first_name . ' ' . $user->last_name,
    );
    
    return Dicole::Widget::BlogPost->new(
        $title ? ( title => $title ) : (),
        preview => $content,
        date => $date,
        author => $author,
        meta_widgets => [],
        control_widgets => [],
        action_widgets => [],
        read_more => $read_more,
    );
}

sub _blogs_summary {
    my ( $self ) = @_;
    
    my $blog = $self->_featured_post_widget;

    return undef unless $blog;

    my $box = Dicole::Box->new();
    $box->name( $self->_msg( 'Featured post' ) );
    $box->content( $blog );

    return $box->output;
}

sub _blogs_new_posts_summary {
    my ( $self ) = @_;

    my $disabled_seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND exclude_from_summary = ?',
        value => [ $self->param('target_group_id'), 1 ],
    } ) || [];

    my @disabled_seed_ids = map { $_->id => 1 } @$disabled_seeds;

    return OpenInteract2::Action::DicoleBlogs::NewPostsSummary->new( $self, {
        box_title => $self->_msg('Latest conversations'),
        box_title_link => Dicole::URL->from_parts(
            action => 'blogs',
            task => 'new',
            target => $self->param('target_group_id'),
        ),
        object => 'blogs_entry',
        query_options => {
            where => 'group_id = ? AND ' . Dicole::Utils::SQL->column_not_in( seed_id => \@disabled_seed_ids ),
            value => [  $self->param('target_group_id') ],
            order => 'dicole_blogs_entry.date desc',
            limit => 5,
        },
        empty_box_string => $self->_msg('No conversations found.'),
        date_field => 'date',
        user_field => 'user_id',
        dated_list_separator_set => 'date & time',
    } )->execute;
}

sub _blogs_new_comments_summary {
    my ( $self ) = @_;

    return OpenInteract2::Action::DicoleBlogs::NewCommentsSummary->new( $self, {
        box_title => $self->_msg('Latest conversation comments'),
        object => 'comments_post',
        query_options => {
            from => [ 'dicole_comments_thread', 'dicole_comments_post' ],
            where => 'dicole_comments_thread.thread_id = dicole_comments_post.thread_id AND ' .
                'dicole_comments_thread.object_type = ? AND dicole_comments_thread.group_id = ?',
            value => [ CTX->lookup_object('blogs_entry') , $self->param('target_group_id') ],
            order => 'dicole_comments_post.date desc',
            limit => 5,
        },
        empty_box_string => $self->_msg('No conversation comments found.'),
        date_field => 'date',
        user_field => 'user_id',
        dated_list_separator_set => 'date & time',
    } )->execute;
}

sub _blogs_summary_seed_list {
    my ( $self ) = @_;

    my $a = CTX->lookup_object('blogs_summary_seed')->fetch_group( {
        where => 'group_id = ?',
        value => [ $self->param('group_id') ],
    } ) || [];

    return [ map { 'blogs_summary_seed::' . $_->seed_id } @$a ];
}

sub _blogs_summary_seed {
    my ( $self ) = @_;

    my $seed_id = $self->param( 'box_param' );
    my $gid = $self->param('target_group_id');
    my $seed = CTX->lookup_object('blogs_seed')->fetch( $seed_id );
    
    return OpenInteract2::Action::DicoleBlogs::NewPostsSummary->new( $self, {
        box_title => $seed->title,
        box_title_link => Dicole::URL->from_parts(
            action => 'blogs',
            task => 'new',
            target => $self->param('target_group_id'),
            additional => [ $seed->id ],
        ),
        object => 'blogs_entry',
        query_options => {
            where => 'group_id = ? AND seed_id = ?',
            value => [  $gid, $seed->id ],
            order => 'dicole_blogs_entry.date desc',
            limit => 5,
        },
        empty_box_string => $self->_msg('No conversations found.'),
        date_field => 'date',
        user_field => 'user_id',
        dated_list_separator_set => 'month & day',
    } )->execute;
}

sub _blogs_summary_seed_old {
    my ( $self ) = @_;

    my $seed_id = $self->param( 'box_param' );
    my $gid = CTX->request->target_group_id;
    my $seed = CTX->lookup_object('blogs_seed')->fetch( $seed_id );

    return undef unless $seed;

    my $title = Dicole::Widget::Horizontal->new;

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $seed->title,
            link => Dicole::URL->create_from_parts(
                action => 'blogs',
                task => 'new',
                target => $gid,
                additional => [ $seed->id ],
            ),
        )
    );
    
    my $content = Dicole::Widget::Vertical->new();
    my $entries = $self->_generic_entries(
        group_id => $gid,
        seed_id => $seed->id,
        order => 'dicole_blogs_entry.date desc',
        limit => 5,
    ) || [];
    
    for my $item ( @$entries ) {
        my $post = eval { $self->_fetch_post_for_entry( $item ) };
        next unless $post;
        
        $content->add_content(
            Dicole::Widget::Hyperlink->new(
                link => Dicole::URL->create_from_parts(
                    action => 'blogs',
                    task => 'show',
                    target => $item->group_id,
                    additional => [ $item->seed_id, $item->id, $self->_entry_url_title( $item ) ],
                ),
                content => $post->title,
            ),
        );
    }

    my $box = Dicole::Box->new();
    $box->name( $title->generate_content );
    $box->content( $content );
    
    return $box->output;
}

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });
    $self->tool->Container->column_width( '280px', 1 );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.blogs");' ),
    );

    my @ab = ();
    push @ab, {
        name => $self->_msg('Create a seed'),
        class => 'blogs_add_seed_action',
        url => $self->derive_url( task => 'add_seed', additioal => [] ),
    } if $self->chk_y( 'create_seeds' ) && ( $self->task =~ /seeds/ );

    push @ab, {
        name => $self->_msg('New post'),
        class => 'blogs_new_post_action',
        url => $self->derive_url( task => 'post', additional => [] ),
    } if $self->chk_y( 'write' ) && ( $self->task =~ /^(my|featured|contacts|new|rated|promoted|show|seeds)$/ );

    $self->tool->action_buttons( [ @ab ] );
}

sub _add_navigation_box {
    my ( $self, %p ) = @_;
    $p{x} ||= 0;
    $p{y} ||= 0;
    $p{seed} ||= $p{seed_id} ? CTX->lookup_object('blogs_seed')->fetch( $p{seed_id} ) : undef;
    $p{seed} ||= ($p{entry} && $p{entry}->seed_id) ? CTX->lookup_object('blogs_seed')->fetch( $p{entry}->seed_id ) : undef;
    $p{id} ||= $self->task;
    my $sid = $p{seed} ? $p{seed}->id : 0;
    
    my $seeds_exist = $p{seed} ? 1 : scalar( @{ CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ?',
        value => [ $self->param('target_group_id') ],
        limit => 1,
    } ) || [] } ) ? 1 : 0;
    
    my $featured_exists = scalar( @{ CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'group_id = ? AND featured > ?' . 
            ( $sid ? ' AND seed_id = ?' : '' ),
        value => [ $self->param('target_group_id'), 0, ($sid ? $sid : ()) ],
        limit => 1,
    } ) || [] } ) ? 1 : 0;

    my $seed_widgets = Dicole::Widget::Vertical->new;
    my $action_widgets = Dicole::Widget::Vertical->new;
    my $widgets = Dicole::Widget::Vertical->new;
    
    # add seed logo and name if present
    if ( $p{seed} ) {
        my $link = $self->derive_url( task => 'new', additional => [ $p{seed}->id ] );
        $seed_widgets->add_content(
            Dicole::Widget::Container->new( contents => [
                Dicole::Widget::Raw->new( raw => '<div align="center">' ),
                Dicole::Widget::Vertical->new(
                    class => 'seed_info_container',
                    contents => [
                        Dicole::Widget::Hyperlink->new( link => $link, content =>
                            Dicole::Widget::Image->new(
                            class => 'seed_info_image',
                            src => $self->_seed_image_url( $p{seed} ),
                            ),
                        ),
                        Dicole::Widget::Hyperlink->new( link => $link, content =>
                            Dicole::Widget::Text->new(
                                class => 'seed_info_title',
                                text => $p{seed}->title
                            ),
                        ),
                    ]
                ),
                Dicole::Widget::Raw->new( raw => '</div>' ),
           ] ),
        );
    }
    
    
    
    my $enable_promoting = $self->_promoting_enabled_for_seed( $p{seed} );
    my $enable_rating = $self->_rating_enabled_for_seed( $p{seed} );

    my $right_to_write = $self->chk_y( 'write' );
    
    for my $link (
        {
            id => 'new',
            name => $self->_msg('New posts'),
            derive => { task => 'new', additional => [ $sid ] },
            class => 'blogs_navigation_new',
        },
        $self->_promoting_enabled_for_seed( $p{seed} ) ? {
            id => 'promoted',
            name => $self->_msg('Most promoted posts'),
            derive => { task => 'promoted', additional => [ $sid ] },
            class => 'blogs_navigation_promoted',
        } : (),
        $self->_rating_enabled_for_seed( $p{seed} ) ? {
            id => 'rated',
            name => $self->_msg('Best rated posts'),
            derive => { task => 'rated', additional => [ $sid ] },
            class => 'blogs_navigation_rated',
        } : (),
        $featured_exists ? {
            id => 'featured',
            name => $self->_msg('Featured posts'),
            derive => { task => 'featured', additional => [ $sid ] },
            class => 'blogs_navigation_featured',
        } : (),
        CTX->request->auth_user_id ? (
            ( $right_to_write ) ? {
                id => 'my',
                name => $self->_msg('My own posts'),
                derive => { task => 'my', additional => [ $sid ] },
                class => 'blogs_navigation_my',
            } : (),
        ) : (),
    ) {
        next if $link->{id} eq 'my' && ! $right_to_write;
	my @classes = ();
	if($p{id} eq $link->{id})
	{
		push(@classes, join('_', ($link->{class}, 'selected')));
		push(@classes, 'selected');
	}
	push(@classes, $link->{class});
        $widgets->add_content( Dicole::Widget::LinkBar->new(
            'link' => $link->{href} || $self->derive_url( %{ $link->{derive} } ),
            content => $link->{name},
#           class => $link->{class} . ( $p{id} eq $link->{id} ? ' selected' : '' ),
	    class => join(' ', @classes),
        ) );
    }
    
    my $uid = CTX->request->auth_user_id;
    
    for my $link (
        ( $right_to_write && ( ! $p{seed} || ! $p{seed}->closed_date ) ) ? {
            id => 'post_to_seed',
            name => $self->_msg('Write a post'),
            derive => { task => 'post_to_seed', additional => [ $sid, $uid ] },
            class => 'blogs_navigation_post',
        } : (),
        ( $p{seed} || ! $seeds_exist )  ? () : {
            id => 'seeds',
            name => $self->_msg('Show seeds'),
            derive => { task => 'seeds', additional => [] },
            class => 'blogs_navigation_seeds',
        },
        ( $p{seed} || $seeds_exist || ! $self->chk_y('create_seeds') )  ? () : {
            id => 'add_seed',
            name => $self->_msg('Create a seed'),
            derive => { task => 'add_seed', additional => [] },
            class => 'blogs_navigation_add_seed',
        },
        ( $p{seed} ) ? {
            id => 'seeds',
            name => $self->_msg('Change seed'),
            derive => { task => 'seeds', additional => [] },
            class => 'blogs_navigation_seeds',
        } : (),
    ) {
	my @classes = ();
        if($p{id} eq $link->{id})
        {
                push(@classes, join('_', ($link->{class}, 'selected')));
                push(@classes, 'selected');
        }
        push(@classes, $link->{class});
        $action_widgets->add_content( Dicole::Widget::LinkBar->new(
            'link' => $link->{href} || $self->derive_url( %{ $link->{derive} } ),
            content => $link->{name},
#           class => $link->{class} . ( $p{id} eq $link->{id} ? ' selected' : '' ),
	    class => join(' ', @classes),
        ) );
    }
    for my $link (
        ( ! $p{skip_seed_edit} && $p{seed} && ( ( $uid && $p{seed}->creator_id == $uid ) || $self->chk_y('edit_seeds') ) ) ? {
            id => 'edit_seed',
            name => $self->_msg('Edit seed'),
            derive => { task => 'edit_seed', additional => [ $p{seed}->id ] },
            class => 'blogs_navigation_edit_seed',
        } : (),
    ) {
	my @classes = ();
        if($p{id} eq $link->{id})
        {
                push(@classes, join('_', ($link->{class}, 'selected')));
                push(@classes, 'selected');
        }
        push(@classes, $link->{class});
        $seed_widgets->add_content( Dicole::Widget::LinkBar->new(
            'link' => $link->{href} || $self->derive_url( %{ $link->{derive} } ),
            content => $link->{name},
#           class => $link->{class} . ( $p{id} eq $link->{id} ? ' selected' : '' ),
	    class => join(' ', @classes),
        ) );
    }

    if ( $p{seed} && scalar( @{ $seed_widgets->contents } ) ) {
        $self->tool->Container->box_at( $p{x}, $p{y} )->name( $self->_msg('Seed') );
        $self->tool->Container->box_at( $p{x}, $p{y} )->add_content( [ $seed_widgets ]);
    }
    unless ( $p{skip_events} || ! $p{tags} || ! scalar( @{ $p{tags} } ) ) {
        eval {
            my $event_html = CTX->lookup_action('events_api')->e(
                get_sidebar_list_html_for_events_matching_tags => {
                    group_id => $self->param('target_group_id'),
                    tags => $p{tags},
                }
            );
            if ( $event_html ) {
                $self->tool->Container->box_at( $p{x}, $p{y}+1 )->name( $self->_msg('Related events') );
                $self->tool->Container->box_at( $p{x}, $p{y}+1 )->add_content( [
                    Dicole::Widget::Raw->new( raw => $event_html ), 
                ]);
            }
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error($@);
        } 
    }
    if ( $p{add_share_this} ) {
        my $share_this_box = CTX->lookup_action('awareness_api')->e( create_share_this_box => {} ); 
        if ( $share_this_box ) {
            $self->tool->Container->box_at( $p{x}, $p{y}+2 )->name( $share_this_box->{name} );
            $self->tool->Container->box_at( $p{x}, $p{y}+2 )->content( $share_this_box->{content} );
            $self->tool->Container->box_at( $p{x}, $p{y}+2 )->class( $share_this_box->{class} );
        }    
    }
    unless ( $p{skip_actions} || ! scalar( @{ $action_widgets->contents } ) ) {
        $self->tool->Container->box_at( $p{x}, $p{y}+3 )->name( $self->_msg('Actions') );
        $self->tool->Container->box_at( $p{x}, $p{y}+3 )->add_content( [ $action_widgets ]);
    }
    unless ( $p{skip_views} || ! scalar( @{ $widgets->contents } ) ) {
        $self->tool->Container->box_at( $p{x}, $p{y}+4 )->name( $self->_msg('Views') );
        $self->tool->Container->box_at( $p{x}, $p{y}+4 )->add_content( [ $widgets ]);
    }
}

sub detect {
    my ( $self ) = @_;
    my $seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND closed_date = ?',
        value => [ $self->param('target_group_id'), 0 ],
        limit => 1,
    } ) || [];
    
    if ( @$seeds ) {
        $self->redirect( $self->derive_url( task => 'seeds' ) );
    }
    else {
        $self->redirect( $self->derive_url( task => 'new', additional => [ 0 ] ) );
    }
}

sub seeds {
    my ( $self ) = @_;

    return $self->_seed_list( 'Seeds', {
        where => 'dicole_blogs_seed.group_id = ? AND dicole_blogs_seed.closed_date = ?',
        value => [ $self->param('target_group_id'), 0 ],
        order => 'dicole_blogs_seed.promoted_date desc, dicole_blogs_seed.active_date desc',
    } );
}

sub all_seeds {
    my ( $self ) = @_;

    return $self->_seed_list( 'All seeds', {
        where => 'dicole_blogs_seed.group_id = ?',
        value => [ $self->param('target_group_id') ],
        order => 'dicole_blogs_seed.opened_date desc',
    }  );
}

sub closed_seeds {
    my ( $self ) = @_;

    return $self->_seed_list( 'Closed seeds', {
        where => 'dicole_blogs_seed.group_id = ? AND dicole_blogs_seed.closed_date > ?',
        value => [ $self->param('target_group_id'), 0 ],
        order => 'dicole_blogs_seed.closed_date desc',
    } );
}

sub _seed_list {
    my ( $self, $title, $fetch_params ) = @_;

    my $tag = $self->param('tag');

    my $all_target_seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        %$fetch_params
    } ) || [];
    
    my $seeds = $tag ?
        eval { CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group', {
            object_class => CTX->lookup_object('blogs_seed'),
            tags => [ $tag ],
            %$fetch_params
        } ) } || []
        :
        $all_target_seeds;

    # force seeds that should be exluded from summary to the bottom of the list
    my @seeds_top = ();
    my @seeds_bottom = ();
    for my $seed ( @$seeds ) {
        if ( $seed->exclude_from_summary ) {
            push @seeds_bottom, $seed,
        }
        else {
            push @seeds_top, $seed,
        }
    }
    push @seeds_top, @seeds_bottom;
    $seeds = [ @seeds_top ];

    $self->_default_tool_init;
    
    my $list = Dicole::Widget::Vertical->new;
    
    for my $seed (@$seeds) {
        $list->add_content( $self->_visualize_seed( $seed ) );
    }
    
    if ( ! scalar( @$seeds ) ) {
        $list = Dicole::Widget::Text->new(
            class => 'blogs_no_seeds_found listing_not_found_string',
            text => $self->_msg('No seeds found.'),
        );
    }
    
    $title .= ' tagged with: [_1]' if $tag;
    
#     $self->_msg( 'Seeds' );
#     $self->_msg( 'All seeds' );
#     $self->_msg( 'Closed seeds' );
#     $self->_msg( 'Seeds tagged with: [_1]' );
#     $self->_msg( 'All seeds tagged with: [_1]' );
#     $self->_msg( 'Closed seeds tagged with: [_1]' );
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( $title, $tag ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );
    
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );

    my $blog = $self->_featured_post_widget;
    if ( $blog ) {
        $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Featured post') );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            [ Dicole::Widget::Container->new( id => 'blogs_summary', contents => [
                Dicole::Widget::Container->new( class => 'contentItemContainer', contents => [
                    $blog
                ] )
            ] ) ]
        );
    }

    eval {
        my $gid = $self->param('target_group_id') || die;

        my $key = 'blogs_get_query_limited_weighted_general_tags_' . $gid;
        my $use_cache = Dicole::Utils::Domain->setting(undef, 'enable_tag_caching');

        my $tags = $use_cache ? $cache->get($key) : undef;

        unless ( $tags ) {
            $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
                object_class => CTX->lookup_object('blogs_entry'),
                where => 'dicole_blogs_entry.group_id = ?',
                value => [ $gid ],
            } );

            $cache->set($key, $tags) if $use_cache;
        }

        $self->tool->Container->box_at( 0, 3 )->name( $self->_msg('Posts by tag') );
        $self->tool->Container->box_at( 0, 3 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( task => 'new', additional => [0, ''] ),
                $tags
            ) ]
        );
    };

    if ($@) {
        get_logger(LOG_APP)->error("$@");
    }

#     eval {
#         my $ids = [ map { $_->id } @$all_target_seeds ];
#         my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
#             object_class => CTX->lookup_object('blogs_seed'),
#             where => Dicole::Utils::SQL->column_in( 'dicole_blogs_seed.seed_id' => $ids ),
#         } );
#         
#         $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Topics by tag') );
#         $self->tool->Container->box_at( 0, 4 )->add_content(
#             [ $self->_fake_tag_cloud_widget(
#                 $self->derive_url( additional => [] ),
#                 $tags
#             ) ]
#         );
#     };

    return $self->generate_tool_content;
}

sub _visualize_seed {
    my ( $self, $seed, $display_view ) = @_;
    
    my $left = $display_view ?
        Dicole::Widget::Image->new(
            class => 'blogs_seed_listing_image',
            src => $self->_seed_image_url( $seed ),
        ) : 
        Dicole::Widget::LinkImage->new(
            class => 'blogs_seed_listing_image',
            src => $self->_seed_image_url( $seed ),
            'link' => $self->derive_url(
                task => 'new',
                additional => [ $seed->id ],
            ),
        );
    
    my $tags = eval {
        CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
            object => $seed
        } );
    } || [];
    
    my $tagstring = 'Tags: ' . join ', ', @$tags;
    
    my $stats = $self->_msg('[_1] post(s)', ( $seed->post_count || 0 ) );
    my $most_recent = '';
    if ( $seed->post_count && $seed->active_date ) {
        $most_recent = $self->_msg('Most recent post on [_1]', Dicole::DateTime->medium_date_format( $seed->active_date ) );
    }
    my $owner = $seed->override_creator;
    unless ( $owner ) {
        my $user = $seed->creator_id ? eval {CTX->lookup_object('user')->fetch( $seed->creator_id ) } : undef;
        $owner = $user ? $self->_msg( 'Organized by [_1]', $user->first_name .' '. $user->last_name ) : '';
    }
    
#    my $heat = $self->_get_seed_heat_rating( $seed );
#    my $unheated = 100 - $heat;
#    my $heat_level = int( $heat / 20 );
    
    my $right = Dicole::Widget::Container->new( contents => [
#         Dicole::Widget::Container->new(
#             class => 'blogs_seed_heat_outer heat_level_' . $heat_level,
#             contents => [
#                 Dicole::Widget::Container->new(
#                     class => 'blogs_seed_heat_inner',
#                     contents => [
#                         Dicole::Widget::Raw->new( raw =>
#                             '<div class="blogs_seed_heat_stretch" style="height:'.$unheated.'%"><!-- --></div>'
#                         ),
#                     ],
#                 ),
#             ],
#         ),
        Dicole::Widget::Vertical->new(
            contents => [
                Dicole::Widget::Horizontal->new(
                    class => 'blogs_seed_listing_title_container',
                    contents => [
                        $display_view ? Dicole::Widget::Text->new(
                            class => 'blogs_seed_listing_title',
                            text => $seed->title,
                        ) : 
                        Dicole::Widget::Hyperlink->new(
                            class => 'blogs_seed_listing_title',
                            content => $seed->title,
                            'link' => $self->derive_url(
                                task => 'new',
                                additional => [ $seed->id ],
                            ),
                        ),
                        ( $seed->closed_date && $self->task eq 'all_seeds' ) ?
                            Dicole::Widget::Text->new(
                                class => 'blogs_seed_listing_closed',
                                text => 'Closed',
                            ) : (),
                        ( $seed->promoted_date && $self->task eq 'seeds' ) ?
                            Dicole::Widget::Text->new(
                                class => 'blogs_seed_listing_promoted',
                                text => 'Promoted',
                            ) : (),
                    ]
                ),
                $owner ? Dicole::Widget::Text->new(
                    class => 'blogs_seed_listing_owner',
                    text => $owner,
                ) : (),
                Dicole::Widget::Container->new(
                    class => 'blogs_seed_listing_description',
                    contents => [ Dicole::Widget::Raw->new ( raw => $seed->description ) ],
                ),
#                 Dicole::Widget::Text->new(
#                     class => 'blogs_seed_listing_tags',
#                     text => $tagstring
#                 ),
                Dicole::Widget::Hyperlink->new(
                    class => 'blogs_seed_listing_stats',
                    content => $stats,
                    'link' => $self->derive_url(
                        task => 'new',
                        additional => [ $seed->id ],
                    ),
                ),
                $most_recent ? Dicole::Widget::Text->new(
                    class => 'blogs_seed_listing_most_recent',
                    text => $most_recent,
                ) : (),
            ],
        ),
    ] );
    my @bottom = ();
    unless ( $display_view ) {
        if ( $seed->closed_date ) {
            @bottom = (
                Dicole::Widget::Text->new(
                    class => 'blogs_seed_listing_closing_info',
                    text => $self->_msg('Seed has been closed and no further contributions will be accepted.'),
                ),
                Dicole::Widget::Container->new(
                    class => 'blogs_seed_listing_closing_comment',
                    contents => [
                        Dicole::Widget::Raw->new ( raw => $seed->closing_comment )
                    ],
                ),
            );
        }
    }

    return Dicole::Widget::FancyContainer->new(
        class => 'blogs_seed_fancycontainer',
        contents => [
            Dicole::Widget::Vertical->new(
                contents => [
                    Dicole::Widget::Columns->new(
                        left => $left,
                        right => $right,
                        left_width => '20%',
                        right_width => '80%'
                    ),
                    @bottom,
                ],
            ),
        ],
    );

}

sub add_seed {
    my ( $self ) = @_;
    
    my $gid = $self->param('target_group_id');
    
    $self->_default_tool_init( upload => 1 );
    $self->tool->add_tinymce_widgets;
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );
    
    my $title = CTX->request->param('title');
    my $description = CTX->request->param('description');
    my $tags_value = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };
    
    if ( CTX->request->param('add') ) {
        if ( ! $title || ! $description ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill both title and description.')
            );
        }
        else {
            my $seed = CTX->lookup_object('blogs_seed')->new;
            $seed->group_id( $gid );
            $seed->creator_id( CTX->request->auth_user_id );
            $seed->description( $description );
            $seed->title( $title );
            $seed->image(0);
            $seed->enable_rating( CTX->request->param('enable_rating') || 0 );
            $seed->enable_promoting( CTX->request->param('enable_promoting') || 0 );
            $seed->override_creator( CTX->request->param('override_creator') || '' );
            $seed->exclude_from_summary( CTX->request->param('exclude_from_summary') || 0 );
            $seed->exclude_from_digest( CTX->request->param('exclude_from_digest') || 0 );
            $seed->opened_date( time );
            $seed->active_date( time );
            $seed->promoted_date( 0 );
            $seed->closed_date( 0 );
            
            $seed->save;
            
            $self->_process_image_upload( $seed );

            eval {
                my $tags = CTX->lookup_action('tagging');
                eval {
                    $tags->execute( 'attach_tags_from_json', {
                        object => $seed,
                        json => $tags_value,
                        user_id => 0,
                        group_id => $gid,
                    } );
                };
                $self->log('error', $@ ) if $@;
            };

            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed created') );

            $self->redirect( $self->derive_url(
                task => 'seeds',
                additional => [],
            ) );
        }
    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Seed information') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_seed_fields( $tags_value )
    );
    
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $self->tool->get_tablink_widgets ]
    );

    return $self->generate_tool_content;
}

sub edit_seed {
    my ( $self ) = @_;
    
    my $gid = $self->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $seed = $self->_fetch_valid_seed;
    die "security error" unless $seed;
    die "security error" unless ( ( $uid && $seed->creator_id == $uid ) || $self->chk_y( 'edit_seeds' ) );
    
    $self->_default_tool_init( upload => 1 );
    $self->tool->add_tinymce_widgets;
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );
    
    my $title = CTX->request->param('title');
    my $description = CTX->request->param('description');
    my $tags_old = CTX->request->param('tags_old');
    my $tags_value = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };
    
    my $summary_seed_objects = CTX->lookup_object('blogs_summary_seed')->fetch_group( {
        where => 'group_id = ? AND seed_id = ?',
        value => [ $gid, $seed->id ],
    } ) || [];
    
    if ( CTX->request->param('save') ) {
        if ( ! $title || ! $description ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill both title and description.')
            );
        }
        else {
            $seed->description( $description );
            $seed->title( $title );
            $seed->image( CTX->request->param('image') );
            $seed->enable_rating( CTX->request->param('enable_rating') || 0 );
            $seed->exclude_from_summary( CTX->request->param('exclude_from_summary') || 0 );
            $seed->exclude_from_digest( CTX->request->param('exclude_from_digest') || 0 );
            $seed->enable_promoting( CTX->request->param('enable_promoting') || 0 );
            $seed->override_creator( CTX->request->param('override_creator') || '' );
            $seed->closing_comment( CTX->request->param('closing_comment') || '' );
            
            $self->_process_image_upload( $seed );

            $seed->save;

            eval {
                my $tags = CTX->lookup_action('tagging');
                eval {
                    $tags->execute( 'update_tags_from_json', {
                        object => $seed,
                        group_id => $gid,
                        user_id => 0,
                        json => $tags_value,
                        json_old => $tags_old,
                    } );
                };
                $self->log('error', $@ ) if $@;
            };

            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed updated') );

            $self->redirect( $self->derive_url( task => 'new' ) );
        }
    }
    elsif ( CTX->request->param('promote') ) {
        $seed->promoted_date( time );
        $seed->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed promoted.') );
    }
    elsif ( CTX->request->param('unpromote') ) {
        $seed->promoted_date( 0 );
        $seed->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed promotion removed.') );
    }
    elsif ( CTX->request->param('close') ) {
        $seed->closed_date( time );
        $seed->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed closed.') );
    }
    elsif ( CTX->request->param('reopen') ) {
        $seed->closed_date( 0 );
        $seed->save;
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed reopened.') );
    }
    elsif ( CTX->request->param('delete') ) {
        my $posts = CTX->lookup_object('blogs_entry')->fetch_group( {
            where => 'group_id = ? AND seed_id = ?',
            value => [ $seed->group_id, $seed->id ],
        } ) || [];
        
        for my $post ( @$posts ) {
            $post->seed_id( 0 );
            $post->save;
        }
        
        eval {
            CTX->lookup_action('tagging')->execute( 'remove_tags', {
                object => $seed,
                group_id => $seed->group_id,
                user_id => 0,
            } );
        };
        $_->remove for @$summary_seed_objects;
        $summary_seed_objects = [];
        
        $seed->remove;
        
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed removed.') );
        $self->redirect( $self->derive_url( task => 'detect', additional => [] ) );
    }
    elsif ( CTX->request->param('summary_add') ) {
        if ( ! scalar( @$summary_seed_objects ) ) {
            my $summary_object = CTX->lookup_object('blogs_summary_seed')->new( {
                group_id => $seed->group_id,
                seed_id => $seed->id
            } );
            $summary_object->save;
            push @$summary_seed_objects, $summary_object;
            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed added to summary.') );
        }
    }
    elsif ( CTX->request->param('summary_remove') ) {
        $_->remove for @$summary_seed_objects;
        $summary_seed_objects = [];
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Seed removed from summary.') );
    }

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Seed information') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_seed_fields( $tags_value, $seed, scalar( @$summary_seed_objects ) )
    );
    
    $self->_add_navigation_box( seed => $seed );
#     $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
#     $self->tool->Container->box_at( 0, 0 )->add_content(
#         [ $self->tool->get_tablink_widgets ]
#     );

    return $self->generate_tool_content;
}

sub _seed_fields {
    my ( $self, $combined_tags, $seed, $seed_in_summary ) = @_;

    my $pressed = $seed ? CTX->request->param('save') : CTX->request->param('add');
    my $upload = CTX->request->upload('upload_image');

    return Dicole::Widget::Vertical->new( contents => [
        Dicole::Widget::Text->new( text => $self->_msg( 'Title' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'title',
            id => 'seed_title',
            value => $pressed ? CTX->request->param('title') || '' : $seed ? $seed->title : '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Custom creator string' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'override_creator',
            id => 'seed_override_creator',
            value => $pressed ? CTX->request->param('override_creator') || '' : $seed ? $seed->override_creator : '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Description' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextArea->new(
            name => 'description',
            id => 'seed_descriptiont',
            value => $pressed ? CTX->request->param('description') || '<p></p>' : $seed ? $seed->description : '<p></p>',
            rows => 8,
            html_editor => 1,
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Image' ), class => 'definitionHeader' ),
        $seed ? Dicole::Widget::Image->new(
            class => 'blogs_seed_image_preview',
            src => $self->_seed_image_url( $seed ),
        ) : (),
        Dicole::Widget::Raw->new(
            raw => '<input class="req" name="upload_image" type="file" value="" />',
        ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::Text->new( text => $self->_msg( 'Enable rating' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::Checkbox->new(
                name => 'enable_rating',
                value => 1,
                class => 'enable_checkbox',
                checked => $pressed ? CTX->request->param('enable_rating') : $seed ? $seed->enable_rating : 1,
            ),
        ] ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::Text->new( text => $self->_msg( 'Enable promoting' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::Checkbox->new(
                name => 'enable_promoting',
                value => 1,
                class => 'enable_checkbox',
                checked => $pressed ? CTX->request->param('enable_promoting') : $seed ? $seed->enable_promoting : 1,
            ),
        ] ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::Text->new( text => $self->_msg( 'Exclude posts from summary' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::Checkbox->new(
                name => 'exclude_from_summary',
                value => 1,
                class => 'enable_checkbox',
                checked => $pressed ? CTX->request->param('exclude_from_summary') : $seed ? $seed->exclude_from_summary : 0,
            ),
        ] ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::Text->new( text => $self->_msg( 'Exclude posts from mail digest' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::Checkbox->new(
                name => 'exclude_from_digest',
                value => 1,
                class => 'enable_checkbox',
                checked => $pressed ? CTX->request->param('exclude_from_digest') : $seed ? $seed->exclude_from_digest : 0,
            ),
        ] ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Tags' ), class => 'definitionHeader' ),
        $self->_get_tagging_add_widget( $self->param('target_group_id'), 0, $pressed, $seed, $combined_tags ),
        $seed ? (
            Dicole::Widget::Text->new( text => $self->_msg( 'Closing comment' ), class => 'definitionHeader' ),
            Dicole::Widget::FormControl::TextArea->new(
                name => 'closing_comment',
                id => 'seed_closing_comment',
                value => $pressed ?
                    CTX->request->param('closing_comment') || '<p></p>' :
                    $seed->closing_comment || '<p></p>',
                rows => 8,
                html_editor => 1,
            ),
        ) : (),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                name => $seed ? 'save' : 'add',
                value => '1',
                text => $seed ? $self->_msg( 'Save' ) :
                    $self->_msg( 'Create' ),
            ),
            $seed ? (
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => $seed->promoted_date ? 'unpromote' : 'promote',
                    value => '1',
                    text => $seed->promoted_date ? $self->_msg( 'Unpromote seed' ) :
                        $self->_msg( 'Promote seed' ),
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => $seed->closed_date ? 'reopen' : 'close',
                    value => '1',
                    text => $seed->closed_date ? $self->_msg( 'Reopen seed' ) :
                        $self->_msg( 'Close seed' ),
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => $seed_in_summary ? 'summary_remove' : 'summary_add',
                    value => '1',
                    text => $seed_in_summary ? $self->_msg( 'Remove seed from summary' ) :
                        $self->_msg( 'Add seed to summary' ),
                ),
                Dicole::Widget::FormControl::SubmitButton->new(
                    name => 'delete',
                    value => '1',
                    text => $self->_msg( 'Remove seed' ),
                ),
            ) : (),
        ] ),
    ] );
}

sub _process_image_upload {
    my ( $self, $seed ) = @_;

    return unless CTX->request->param( 'upload_image' );

    my $upload_obj = CTX->request->upload( 'upload_image' );
    
    return unless ref $upload_obj;
    
    my $attachment = CTX->lookup_action('attachment')->execute(store_from_request_upload => {
        object => $seed,
        upload_name => 'upload_image',
        group_id => $seed->group_id,
        user_id => 0,
        owner_id => CTX->request->auth_user_id,
        domain_id => $seed->domain_id
    } );
    
    $seed->image($attachment->id);

    $seed->save;

    return 1;
}


sub _create_seed_image_path {
    my ( $self, @parts ) = @_;
    return CTX->lookup_directory( 'dicole_profilepics' ) . '/' .
        $self->_create_seed_image_filename( @parts );
}

sub _create_seed_image_filename {
    my ( $self, $seed, $random, $suffix ) = @_;
    return 'seed_image_' . $seed->id . "_$random.$suffix";
}

sub _check_magick_error {
    my ( $self, $error ) = @_;
    return undef unless $error;
    $error =~ /(\d+)/;
    # Status code less than 400 is a warning
    $self->log( 'error',
        "Image::Magick returned status $error while resizing profile image"
    );
    if ( $1 >= 400 ) {
        return 1;
    }
    return undef;
}

sub add_reposter {
    my ($self) = @_;

    OpenInteract2::Action::DicoleBlogs::AddReposter->new( $self, {
        box_title => 'New Reposter details',
        box_x => 1,
        class => 'blogs_reposter',
        skip_security => 1,
        view => 'add_reposter',
        skip_generate => 1,
        tool_config => { rows => 1, cols => 2, tool_args => { no_tool_tabs => 1 } },
    } )->execute;

    $self->_add_navigation_box( seed_id => $self->param('seed_id') || 0, skip_views => 1, skip_seed_edit => 1 );

    return $self->generate_tool_content;
}

sub post {
    my ( $self ) = @_;

    my $seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND closed_date = ?',
        value => [ $self->param('target_group_id'), 0 ],
        limit => 1,
    } ) || [];
    
    if ( @$seeds ) {
        $self->redirect( $self->derive_url(
            task => 'select_post_seed',
            additional => [],
        ) );
    }
    else {
        $self->redirect( $self->derive_url(
            task => 'post_to_seed',
            additional => [ 0, CTX->request->auth_user_id ],
        ) );
    }
}

sub select_post_seed {
    my ( $self ) = @_;

    my $seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND closed_date = ?',
        value => [ $self->param('target_group_id'), 0 ],
        order => 'promoted_date desc, active_date desc',
    });

    $self->_default_tool_init;
    
    my $list = Dicole::Widget::Vertical->new;
    
    for my $seed (@$seeds) {
        $list->add_content( $self->_visualize_seed( $seed, 1 ) );
        $list->add_content( Dicole::Widget::LinkBar->new(
        class => 'blogs_select_post_seed_link with_a_seed',
            content => $self->_msg( 'Post to seed "[_1]"', $seed->title ),
            'link' => $self->derive_url(
                task => 'post_to_seed',
                additional => [ $seed->id, CTX->request->auth_user_id ],
            ),
        ) );
    }

    $list->add_content( Dicole::Widget::LinkBar->new(
        class => 'blogs_select_post_seed_link without_a_seed',
        content => $self->_msg( 'Write a post without a seed' ),
        'link' => $self->derive_url(
            task => 'post_to_seed',
            additional => [ 0, CTX->request->auth_user_id ],
        ),
    ) );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select seed to post to') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );

#     $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Seed guide') );
#     $self->tool->Container->box_at( 0, 0 )->add_content(
#         [ Dicole::Widget::Inline->new(
#             class => 'blogs_seed_guide',
#             contents => [
#                 'Ideas in the Real-Time Economy Community are organized within seeds. ',
#                 'When posting an idea, you may choose in which seed your idea belongs to. ',
#                 'If you want to know more about seeds, check the ',
#                 Dicole::Widget::Hyperlink->new(
#                     content => 'Knowledge & Research article on Idea seeds.',
#                     link => '/wiki/show/1/Idea_seeds',
#                 )
#             ]
#         )]
#     );

    return $self->generate_tool_content;
}

sub reseed_post {
    my ( $self ) = @_;

    $self->_default_tool_init;
    my $data = eval { $self->_entry_data( $self->param('entry_id') ) };
    my $entry = $data->{entry};
    die "security error" unless $entry && $entry->group_id == $self->param('target_group_id');
    
    # allow user to add a seed and reseeders to change seed
    if ( ! $self->chk_y( 'reseed' ) ) {
        die "security error" unless $entry->user_id == CTX->request->auth_user_id && ! $entry->seed_id;
    }
    
    my $seeds = CTX->lookup_object('blogs_seed')->fetch_group( {
        where => 'group_id = ? AND closed_date = ?',
        value => [ $self->param('target_group_id'), 0 ],
        order => 'promoted_date desc, active_date desc',
    }) || [];
    
    my %valid_seed_by_id = map { $_->id => $_ } @$seeds;
    
    if ( defined( CTX->request->param( 'seed_id' ) ) ) {
        my $seed_id = CTX->request->param( 'seed_id' );
        if ( $seed_id == 0 || $valid_seed_by_id{ $seed_id } ) {
            my $old_seed_id = $entry->seed_id;
            $entry->seed_id( $seed_id );
            $entry->save;
            
            $self->_update_seed_stats( $valid_seed_by_id{ $seed_id } ) if $seed_id;
            $self->_update_seed_stats( $valid_seed_by_id{ $old_seed_id } || $old_seed_id ) if $old_seed_id;
            
            $self->tool->add_message(
                MESSAGE_SUCCESS, $self->_msg('Post seed assigned.')
            );

            return $self->redirect( $self->derive_url(
                task => 'new',
                additional => [ $seed_id ],
            ) );
        }
        # TODO: error message for dummies..
    }
    
    
    my $list = Dicole::Widget::Vertical->new;
    
    $list->add_content( Dicole::Widget::Text->new(
        class => 'blogs_post_reseed_intro',
        text => $self->_msg('You are moving post titled "[_1]" into a new seed. Please select one of the options below:',
            $data->{post} ? $data->{post}->title : '?' ),
    ) );
    
    for my $seed (@$seeds) {
        next if $seed->id == $entry->seed_id;
        $list->add_content( $self->_visualize_seed( $seed, 1 ) );
        $list->add_content( Dicole::Widget::LinkBar->new(
            class => 'blogs_reseed_post_link with_a_seed',
            content => $self->_msg( 'Move post to seed "[_1]"', $seed->title ),
            'link' => $self->derive_url( params => { seed_id => $seed->id } ),
        ) );
    }

    $list->add_content( Dicole::Widget::LinkBar->new(
        class => 'blogs_reseed_post_link without_a_seed',
        content => $self->_msg( 'Remove post from seed' ),
        'link' => $self->derive_url( params => { seed_id => 0 } ),
    ) ) if $entry->seed_id;

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Select new seed') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );

#     $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Seed guide') );
#     $self->tool->Container->box_at( 0, 0 )->add_content(
#         [ Dicole::Widget::Inline->new(
#             class => 'blogs_seed_guide',
#             contents => [
#                 'Ideas in the Real-Time Economy Community are organized within seeds. ',
#                 'When posting an idea, you may choose in which seed your idea belongs to. ',
#                 'If you want to know more about seeds, check the ',
#                 Dicole::Widget::Hyperlink->new(
#                     content => 'Knowledge & Research article on Idea seeds.',
#                     link => '/wiki/show/1/Idea_seeds',
#                 )
#             ]
#         )]
#     );

    return $self->generate_tool_content;
}

sub post_to_seed {
    my ( $self ) = @_;
    
    my $uid = CTX->request->auth_user_id;
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    die "security error" unless $self->schk_y(
        'OpenInteract2::Action::Weblog::user_add', $uid
    );
    
    $self->_default_tool_init( upload => 1 );
    
    if ( $seed && $seed->closed_date > 0 ) {
        $self->tool->add_message(
            MESSAGE_ERROR, $self->_msg('You can not post to a closed seed.')
        );
        return $self->redirect( $self->derive_url( task => 'new', additional => [ $seed->id ] ) );
    }
    
    my $add_pressed = CTX->request->param('add') || CTX->request->param('add_continue');
    my $content = CTX->request->param('content');
    my $title = CTX->request->param('title');
    my $post_tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    my $draft = $self->_get_or_create_draft( $seed ? $seed->id : 0 );

    if ( $add_pressed ) {
        if ( ! $title || ! $content ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill both title and content.')
            );
        }
#        elsif ( $post_tags eq "[]" ) {
#            $self->tool->add_message(
#                MESSAGE_ERROR, $self->_msg('You must have at least one tag.')
#            );
#        }
        else {
            if ( my $additional = CTX->request->param('prefilled_tags') ) {
                $post_tags = CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                    input => $additional,
                    json => $post_tags,
                } );
            }

            my $tags = eval { CTX->lookup_action('tags_api')->e( decode_json => { json => $post_tags } ) } || [];

            my $entry = CTX->lookup_action('blogs_api')->e( create_entry => {
                user_id => $uid,
                group_id => $gid,
                seed_id => $sid,
                content => $content,
                title => $title,
                tags => $tags,
                domain_id => $self->param('domain_id'),
                published => 1,
            } );

            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Entry saved') );

            my $post = $self->_fetch_post_for_entry( $entry );

            eval {
                my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
                    object => $draft,
                    group_id => 0,
                    user_id => $uid,
                } );

                for my $a ( @$as ) {
                    CTX->lookup_action('attachment')->execute( reattach => {
                        attachment => $a,
                        object => $post,
                    } );
                }
            };

            $self->_clean_draft( $draft );
            
            # TODO: Is it required to ping feedreader?
            # TODO: add reply to
            
            return $self->redirect( Dicole::URL->create_from_parts(
            	action => 'blogs',
           		task => 'show',
            	target => $gid,
            	additional => [ $sid, $entry->id ],
            ) ) if CTX->request->param('add');
            
            return $self->redirect( $self->derive_url(
                task => 'edit_post',
                additional => [ $sid, $uid, $entry->id ],
            ) );
        }
    }

    my $fields = [ $self->_post_fields( $uid, $add_pressed, $post_tags, $seed, undef, undef, $draft ) ];

    push @$fields, Dicole::Widget::Hyperlink->new(
        class => 'f_dicole_draft_shipper_link hiddenBlock',
        id => 'f_Form_draft_shipper_link',
        'link' => $self->derive_url( action => 'blogs_json', task => 'store_draft' ),
    );
    push @$fields, Dicole::Widget::Raw->new( raw =>
        '<input type="hidden" name="draft_id" value="'.$draft->id.'" />'
    );

    $self->tool->add_tinymce_widgets( 'blogs', undef, {
        attachment_list_url => $self->derive_url(
            action => 'blogs_json', task => 'draft_attachment_list_data', additional => [ $draft->id ]
        ),
        attachment_post_url => $self->derive_url(
            action => 'blogs_raw', task => 'draft_attachment_post', additional => [ $draft->id ],
            params => { dic => Dicole::Utils::User->temporary_authorization_key( CTX->request->auth_user ) },
        ),
    } );

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Write a post') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $fields
    );
    
    $self->_add_navigation_box( seed_id => $sid, skip_views => 1, skip_seed_edit => 1 );
    $self->tool->tool_title_suffix( $self->_msg('Write a message') );

    return $self->generate_tool_content;
}

sub edit_post {
    my ( $self ) = @_;
    
    my $uid = $self->param('user_id');
    my $gid = $self->param('target_group_id');
    my $eid = $self->param('entry_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    my $data = eval { $self->_entry_data( $eid, $seed ); };

    if ( $@ ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The message you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'detect',
            additional => [],
        ) );
    }
    my $post = $data->{post};

    die "security error" unless $post && $post->user_id == $uid && $self->schk_y(
        'OpenInteract2::Action::Weblog::user_edit', $uid
    );
    
    $self->_default_tool_init( upload => 1 );
    
    if ( $seed ) {
        if ( $seed->id != $data->{entry}->seed_id ) {
            die "security error";
        }
        elsif ( $seed->closed_date > 0 ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You can not edit a post in a closed seed.')
            );
            return $self->redirect( $self->derive_url( task => 'new', additional => [ $seed->id ] ) );
        }
    }

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $post,
    } );

    $self->tool->add_tinymce_widgets( 'blogs', undef, {
        attachment_list_initial => $self->_attachment_list_html( $data->{entry}, $as ),
        attachment_list_url => $self->derive_url(
            action => 'blogs_json', task => 'attachment_list_data', additional => [ $eid ],
        ),
        attachment_post_url => $self->derive_url(
            action => 'blogs_raw', task => 'attachment_post', additional => [ $eid ],
            params => { dic => Dicole::Utils::User->temporary_authorization_key( CTX->request->auth_user ) },
        ),
    } );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );
    
    my $save_pressed = CTX->request->param('save') || CTX->request->param('save_continue');
    my $content = CTX->request->param('content');
    my $title = CTX->request->param('title');
    my $post_tags_old = CTX->request->param('tags_old');
    my $post_tags = eval {
        CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    if ( $save_pressed ) {
        if ( ! $title || ! $content ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill both title and content.')
            );
        }
        # allow storing no tags if post had no tags for backwards compatibility
#        elsif ( $post_tags eq "[]" && $post_tags_old ne "[]"  ) {
#            $self->tool->add_message(
#                MESSAGE_ERROR, $self->_msg('You must have at least one tag.')
#            );
#        }
        else {
            my $old_tags = eval { CTX->lookup_action('tags_api')->e( decode_json => { json => $post_tags_old } ) } || [];
            my $tags = eval { CTX->lookup_action('tags_api')->e( decode_json => { json => $post_tags } ) } || [];

            my $entry = CTX->lookup_action('blogs_api')->e( update_entry => {
                entry => $data->{entry},
                content => $content,
                title => $title,
                user_id => CTX->request->auth_user_id,
                old_tags => $old_tags,
                tags => $tags,
                domain_id => $self->param('domain_id'),
            } );
            
            #CTX->lookup_action('search_api')->execute(process => {object => $post});

#             eval {
#                 CTX->lookup_action('attachment')->execute( store_from_request_upload => {
#                     upload_name => 'upload_attachment',
#                     object => $post,
#                 } );
#             };
            
            # TODO: Check that published get updated if it can be changed here
            # In the future..

            $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Entry updated') );
            
            # TODO: Is it required to ping feedreader?
            # TODO: add reply to
            
            return CTX->request->param('save_continue') ?
                $self->redirect( $self->derive_url )
                :
                $self->redirect( $self->derive_url(
                    task => 'my',
                    additional => [ $sid, $uid ],
                ) );
        }
    }
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Edit post') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->_post_fields( $uid, $save_pressed, $post_tags, $seed, $post, $data->{entry} )
    );

    $self->_add_navigation_box( seed_id => $sid );
    $self->tool->tool_title_suffix($self->_msg('Edit message'));
    return $self->generate_tool_content;
}

sub _post_fields {
    my ( $self, $uid, $pressed, $post_tags, $seed, $post, $entry, $draft ) = @_;

    return Dicole::Widget::Vertical->new( contents => [
        Dicole::Widget::Text->new( text => $self->_msg( 'Title' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'title',
            id => 'blog_title',
            value => $pressed ? CTX->request->param('title') || '' : $post ? $post->title : '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Content' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextArea->new(
            name => 'content',
            id => 'blog_content',
            rows => 15,
            value => $pressed ? CTX->request->param('content') || '' : $post ? $post->content : '',
            html_editor => 1,
        ),
#        $self->_get_attachments_widget( $entry, $post ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Tags' ), class => 'definitionHeader' ),
        $self->_get_tagging_add_widget( 0, $uid, $pressed, $post, $post_tags ),
        $self->_get_tagging_suggestion_widgets( $self->param('target_group_id'), $seed ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                name => $post ? 'save' : 'add',
                value => '1',
                text => $post ? $self->_msg( 'Save' ) :  $self->_msg( 'Publish' ),
            ),
#             Dicole::Widget::FormControl::SubmitButton->new(
#                 name => $post ? 'save_continue' : 'add_continue',
#                 value => '1',
#                 text => $post ? $self->_msg( 'Save & continue editing' ) :
#                     $self->_msg( 'Publish & continue editing' ),
#             ),
        ] ),
    ] );
}

sub _get_tagging_add_widget {
    my ( $self, $gid, $uid, $form_posted, $object, $post_tags ) = @_;
    
    my @widgets = ();
    
    eval {
        my $tagging = CTX->lookup_action('tagging');
        
        my $old_tags = Dicole::Utils::JSON->encode([]);
        if ( $object ) {
            if ( ref( $object ) =~ /seed/i ) {
                $old_tags = $tagging->execute( 'get_tags_for_object_as_json', {
                    object => $object,
                    group_id => $gid,
                } ) || Dicole::Utils::JSON->encode([]);
            }
            else {
                $old_tags = $tagging->execute( 'get_tags_for_object_as_json', {
                    object => $object,
                    group_id => $gid,
                    user_id => $uid,
                    domain_id => 0,
                } ) || Dicole::Utils::JSON->encode([]);
            }
        }

        my $current_tags_json = $form_posted ? $post_tags || Dicole::Utils::JSON->encode([]) : $old_tags;
        if ( my $additional = CTX->request->param('prefilled_tags') ) {
            $current_tags_json = CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                input => $additional,
                json => $current_tags_json,
            } );
        }

        push @widgets, Dicole::Widget::FormControl::Tags->new(
            id => 'tags',
            name => 'tags',
            value => $current_tags_json,
            old_value => $form_posted ? CTX->request->param( 'tags_old' ) || Dicole::Utils::JSON->encode([]) :
                $old_tags,
            add_tag_text => $self->_msg('Add tag'),
        );
   };
   
   return @widgets;
}

sub _get_tagging_suggestion_widgets {
    my ( $self, $gid, $seed ) = @_;
    
    my @widgets = ();
    my %used_tags = ();
    
    eval {
        my $tagging = CTX->lookup_action('tagging');
        
        my $suggested_tags = $tagging->execute( 'get_suggested_tags', {
            group_id => $gid,
            user_id => 0,
        } );
        
        if ( scalar( @$suggested_tags ) ) {
            push @widgets, (
                Dicole::Widget::Text->new(
                    class => 'definitionHeader',
                    text => $self->_msg( 'Click to add suggested tags' ),
                ),
                Dicole::Widget::TagSuggestionListing->new(
                    target_id => 'tags',
                    tags => $suggested_tags,
                ),
            );
            $used_tags{ $_ }++ for @$suggested_tags;
        }
        
        my @popular_wtags_in_seed = ();
        
        if ( $seed ) {
            my $seed_tags = $tagging->execute( get_tags => { object => $seed } );
            my %seed_tags = map { $_ => 1 } @$seed_tags;
            
            my $seed_post_wtags = $tagging->execute( get_query_limited_weighted_tags => {
                object_class => CTX->lookup_object('blogs_entry'),
                where => 'dicole_blogs_entry.group_id = ?' . 
                    ' AND dicole_blogs_entry.seed_id = ?',
                value => [ $gid, $seed->id ],
            } );
            
            for my $wtag ( @$seed_post_wtags ) {
                next if $used_tags{ $wtag->[0] };
                if ( $seed_tags{ $wtag->[0] } ) {
                    $wtag->[1] = 99999;
                    delete $seed_tags{ $wtag->[0] };
                }
                push @popular_wtags_in_seed, $wtag;
            }

            for my $tag ( keys %seed_tags ) {
                push @popular_wtags_in_seed, [ $tag, 99999 ];
            }

            if ( scalar( @popular_wtags_in_seed ) ) {
                my $cloud = Dicole::Widget::TagCloudSuggestions->new(
                    target_id => 'tags',
                );
                $cloud->add_weighted_tags_array( \@popular_wtags_in_seed );

                push @widgets, (
                    Dicole::Widget::Text->new(
                        class => 'definitionHeader',
                        text => $self->_msg( 'Click to add tags popular in this seed' ),
                    ),
                    $cloud,
                );

                $cloud->set_tags_to_links;
                my $limited_tags = $cloud->get_limited_tags;
                $used_tags{ $_ }++ for @$limited_tags;
            }
        }
        
        my $weighted_tags = $tagging->execute( 'get_weighted_tags', {
            group_id => $gid,
            user_id => 0,
        } );
        
        my @popular_weighted = ();
        for my $wtag ( @$weighted_tags ) {
            next if $used_tags{ $wtag->[0] };
            push @popular_weighted, $wtag;
        }
        
        if ( scalar( @popular_weighted ) ) {
            my $cloud = Dicole::Widget::TagCloudSuggestions->new(
                target_id => 'tags',
            );
            $cloud->add_weighted_tags_array( \@popular_weighted );

            push @widgets, (
                Dicole::Widget::Text->new(
                    class => 'definitionHeader',
                    text => scalar( @popular_wtags_in_seed ) ?
                        $self->_msg( 'Click to add tags popular elsewhere' )
                        :
                        $self->_msg( 'Click to add popular tags' ),
                ),
                $cloud,
            );

#             $cloud->set_tags_to_links;
#             my $limited_tags = $cloud->get_limited_tags;
#             $used_tags{ $_ }++ for @$limited_tags;
        }
    };

    return @widgets;
}

sub _get_attachments_widget {
    my ( $self, $entry, $post ) = @_;

    my @widgets = ();
    eval {
        my $action = CTX->lookup_action('attachment');
        my $attachments = $post ? $action->execute( get_attachments_for_object => {
            object => $post,
        } ) || [] : [];
        
        if ( scalar( @$attachments ) ) {
            push @widgets, Dicole::Widget::Inline->new( contents => [
                Dicole::Widget::Text->new(
                    text => $self->_msg( 'Attachments' ),
                    class => 'definitionHeader',
                ),
                $post ? ( ' ', Dicole::Widget::Text->new(
                    text => $self->_msg('(Drag & drop links and images to the editor window)'),
                    class => 'definitionGuide',
                ) ) : (),
            ] );
            push @widgets, Dicole::Widget::Container->new(
                class => 'blogs_attachment_container',
                contents => [ $self->_attachment_listing_widget( $entry, $attachments ) ],
            );
        }
        
        push @widgets, Dicole::Widget::Text->new( text => $self->_msg( 'Add attachment' ), class => 'definitionHeader' );
        push @widgets, Dicole::Widget::Raw->new(
            raw => '<input class="req" name="upload_attachment" type="file" value="" />',
        );
    };
    
    return @widgets;
}

sub image {
    my ($self) = @_;
    
    my $seed = $self->_fetch_valid_seed;

    unless ($seed) {
        get_logger(LOG_APP)->error("Failed to fetch valid seed");
        return;
    }

    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $seed->image,
        thumbnail => 1,
        force_width => 170
    } );
}

sub my {
    my ( $self ) = @_;
    
    my $uid = $self->param('user_id');
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    unless ( defined $uid ) {
        $uid = CTX->request->auth_user_id;
        
        return $uid ? $self->redirect( $self->derive_url( additional => [ $sid, $uid, $tag ] ) ) :
            $self->redirect( $self->derive_url( task => 'new' ) );
    };
    
    $self->_default_tool_init;
    
    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        seed_id => $sid,
        user_ids => [ $uid ],
        order => 'dicole_blogs_entry.date desc',
        limit => 10,
    );
    
    my $title = $self->_msg( 'My posts' );
    my $title2 = 'My posts';
    my $title_append_values = [];
    unless ( CTX->request->auth_user_id == $uid ) {
        my $user = CTX->lookup_object('user')->fetch( $uid );
        my $name = $user->first_name . ' ' . $user->last_name;
        $title = $tag ? 'Posts by [_2]' : 'Posts by [_1]';
        $title_append_values = [$name];
    }
    
    $self->_fill_first_entries_boxes( $entries, $tag, $title, $seed, $title_append_values );
    $self->_add_navigation_box( seed_id => $sid );
     
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('blogs_entry'),
            where => 'dicole_blogs_entry.group_id = ? AND dicole_blogs_entry.user_id = ?' .
                ( $seed ? ' AND dicole_blogs_entry.seed_id = ?' : '' ),
            value => [ $gid, $uid, ( $seed ? $seed->id : () ) ],
        } );
        
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [$sid, $uid, ''] ),
                $tags
            ) ]
        );
    };

    $title2 .= ' tagged with: [_1]' if $tag;
    $self->tool->tool_title_suffix( $self->_msg($title2, $tag ? $tag : (), $title_append_values ? @$title_append_values : () ) );
    return $self->generate_tool_content;
}

sub contacts {
    my ( $self ) = @_;
    
    my $uid = $self->param('user_id');
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;

    unless ( defined $uid ) {
        $uid = CTX->request->auth_user_id;
        
        return $uid ? $self->redirect( $self->derive_url( additional => [ $sid, $uid, $tag ] ) ) :
            $self->redirect( $self->derive_url( task => 'new' ) );
    };
    
    $self->_default_tool_init;
    
    # TODO: move this to contacts package
    my $objects = CTX->lookup_object('networking_contact')->fetch_group( {
        where => 'user_id = ?',
        value => [ $uid ],
    } );
    
    my $ids = [ sort map { $_->contacted_user_id } @$objects ];
    
    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        seed_id => $sid,
        user_ids => $ids,
        order => 'dicole_blogs_entry.date desc',
        limit => 10,
    );
    
    $self->_fill_first_entries_boxes( $entries, $tag, 'Posts by contacts', $seed );
    $self->_add_navigation_box( seed => $seed );
     
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('blogs_entry'),
            where => 'dicole_blogs_entry.group_id = ?' .
                ( $seed ? ' AND dicole_blogs_entry.seed_id = ?' : '' ) .
                ' AND ' . Dicole::Utils::SQL->column_in( 'dicole_blogs_entry.user_id', $ids ),
            value => [ $gid, ( $seed ? $seed->id : () ) ],
        } );
        
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [$sid, $uid, ''] ),
                $tags
            ) ]
        );
    };
    my $title = 'Posts by contacts';
    $title .= ' tagged with: [_1]' if $tag;
    $self->tool->tool_title_suffix( $self->_msg($title, $tag ? $tag : () ) );
    return $self->generate_tool_content;
}

sub featured {
    my ( $self ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    $self->_default_tool_init(
        tool_args => {
            feeds => $self->init_feeds(
                action => 'blogs_feed',
                task => $self->task,
                additional_file => '',
                additional => $tag ? [ $sid, $tag ] : [ $sid ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        }
    );
    
    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        seed_id => $sid,
        order => 'dicole_blogs_entry.featured desc',
        limit => 10,
        where => 'dicole_blogs_entry.featured > 0',
    );
    
    $self->_fill_first_entries_boxes( $entries, $tag, 'Featured posts', $seed );
    $self->_add_navigation_box( seed => $seed );
     
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('blogs_entry'),
            where => 'dicole_blogs_entry.group_id = ? AND dicole_blogs_entry.featured > 0' . 
                ( $seed ? ' AND dicole_blogs_entry.seed_id = ?' : '' ),
            value => [ $gid, ( $seed ? $seed->id : () ) ],
        } );
        
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [$sid, ''] ),
                $tags
            ) ]
        );
    };
    my $title = 'Featured posts';
    $title .=  ' tagged with: [_1]' if $tag;
    $self->tool->tool_title_suffix( $self->_msg($title, $tag ? $tag : () ) );
    return $self->generate_tool_content;
}

sub new { return shift->_generic_listing(
    'Posts',
    'dicole_blogs_entry.date desc',
) };

sub rated { return shift->_generic_listing(
    'Best rated posts',
    'dicole_blogs_entry.rating desc, dicole_blogs_entry.date desc',
) };

sub promoted { return shift->_generic_listing(
    'Most promoted posts',
    'dicole_blogs_entry.points desc, dicole_blogs_entry.date desc',
) };

sub _generic_listing {
    my ( $self, $title, $order ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    $self->_default_tool_init(
        tool_args => {
            feeds => $self->init_feeds(
                action => 'blogs_feed',
                task => $self->task,
                additional_file => '',
                additional => $tag ? [ $sid, $tag ] : [ $sid ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        }
    );

    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        seed_id => $sid,
        order => $order,
        limit => 10,
    );
    
    $self->_add_navigation_box( seed => $seed );
    
    $self->_fill_first_entries_boxes( $entries, $tag, $title, $seed );
    
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('blogs_entry'),
            where => 'dicole_blogs_entry.group_id = ?' . 
                ( $seed ? ' AND dicole_blogs_entry.seed_id = ?' : '' ),
            value => [ $gid, ( $seed ? $seed->id : () ) ],
        } );
        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [$sid, ''] ),
                $tags
            ) ]
        );
    };
    # $self->_msg('Posts');
    # $self->_msg('Featured posts');
    # $self->_msg('Best rated posts');
    # $self->_msg('My posts');
    # $self->_msg('Posts tagged with: [_1]');
    # $self->_msg('Featured posts tagged with: [_1]');
    # $self->_msg('Best rated posts tagged with: [_1]');
    # $self->_msg('My posts tagged with: [_1]');
    $title .= ' tagged with: [_1]' if $tag;
    $self->tool->tool_title_suffix( $self->_msg($title, $tag ? $tag : () ) );
    return $self->generate_tool_content;
}

sub _fill_first_entries_boxes {
    my ( $self, $entries, $tag, $title, $seed, $title_append_values ) = @_;
    
    $title .= ' tagged with: [_1]' if $tag;

    my $list = scalar( @$entries ) ?
        $self->_visualize_entry_list( $entries, $seed ) :
        Dicole::Widget::Inline->new( contents => [
            Dicole::Widget::Text->new(
                class => 'blogs_no_posts_found listing_not_found_string',
                text => $self->_msg('No posts found.'),
            ),
            ( $tag || ! CTX->request->auth_user_id || $self->task ne 'new' ) ? () : (
                ' ',
                Dicole::Widget::Hyperlink->new(
                    class => 'blogs_no_posts_add',
                    content => $self->_msg('Be the first to add one!'),
                    'link' => $self->derive_url(
                        task => 'post_to_seed',
                        additional => [ $seed ? $seed->id : 0, CTX->request->auth_user_id ],
                    ),
                ),
            ),
        ] );
    
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg(
        $title, $tag ? $tag : (), $title_append_values ? @$title_append_values : ()
    ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $list ]
    );
}

sub show {
    my ( $self ) = @_;
    
    # fix old seedless links
    if (  $self->param('entry_id') !~ /^\d+$/ ) {
        $self->param( entry_id => $self->param( 'seed_id' ) );
        $self->param( seed_id => 0 );
    }

    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    my $data = eval {
        $self->_entry_data( $self->param('entry_id'), $seed );
    };
    
    if ( $@ ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The message you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    my $user = $data->{user};
    my $post = $data->{post};
    my $entry = $data->{entry};
    my $tags = $data->{tags};
    
    $self->_default_tool_init;
    
    $self->tool->Container->box_at( 1, 0 )->name(
        $post->title
    );
    $self->tool->Container->box_at( 1, 0 )->add_content( [
        $self->_visualize_full_message( $entry, $seed ),
        $self->_get_show_attachments_widget( $entry, $post ),
    ] );

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object => $entry,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $self->param('target_group_id'),
        act => 'show',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    eval {
        my $t = CTX->lookup_action('commenting')->execute( 'get_comment_tree_widget', {
            object => $entry,
            comments_action => 'blogs_comments',
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            disable_commenting => $self->chk_y( 'comment' ) ? 0 : 1,
            commenting_closed => $entry->close_comments ? 1 : 0,
            right_to_remove_comments =>
                $self->chk_y( 'remove_comments' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
       
        if ( $self->chk_y( 'comment' ) ) {
            $self->tool->add_comments_widgets;
        }
        else {
            $self->tool->add_head_widgets(
                Dicole::Widget::Javascript->new(
                    code => 'dojo.require("dicole.comments");',
                )
            );
        }
    
        my $comment_count = CTX->lookup_action('commenting')->execute( 'get_comment_count', {
        	object => $entry
    	} ) || 0;
        
        if($comment_count == 0) {
        	$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('No comments') );
        } elsif($comment_count == 1) {
        	$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('One comment') );
        } elsif($comment_count > 1) {
        	$self->tool->Container->box_at( 1, 1 )->name( $self->_msg('[_1] comments', $comment_count) );
        }
        
        $self->tool->Container->box_at( 1, 1 )->add_content(
            [ $t ]
        );
    };
    get_logger(LOG_APP)->error( $@ ) if $@;

    $self->_add_navigation_box( seed => $seed, entry => $entry, tags => $tags, add_share_this => 1 );
    
#     $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Search by tag') );
#     $self->tool->Container->box_at( 0, 1 )->add_content(
#         [ $self->_global_tag_cloud_widget( $self->param('target_group_id') ) ],
#     );
    $self->tool->tool_title_suffix($self->_msg($post->title));

    eval { CTX->lookup_action('awareness_api')->e( add_open_graph_properties => {
        title => $self->tool->tool_title_suffix,
        description => Dicole::Utils::HTML->html_to_text( $post->content ),
        images_from_html => $post->content,
    } ) };

    return $self->generate_tool_content;
}

sub _get_show_attachments_widget {
    my ( $self, $entry, $post ) = @_;
    
    my @widgets = ();
    eval {
        my $attachments = $post ? CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
            object => $post,
        } ) || [] : [];
        
        if ( scalar( @$attachments ) ) {
            push @widgets, Dicole::Widget::Text->new(
                text => $self->_msg( 'Attachments' ), class => 'definitionHeader'
            );
            for my $a ( @$attachments ) {
                push @widgets, Dicole::Widget::LinkBar->new(
                    content => $a->filename,
                    'link' => $self->derive_url(
                        task => 'attachment',
                        additional => [ $entry->id, $a->id, $a->filename ],
                    ),
                );
            }
        }
    };
    
    return @widgets;
}

sub add_tags {
    my ( $self ) = @_;
    
    my $gid = $self->param('target_group_id');
    my $eid = $self->param('entry_id');
    my $seed = $self->_fetch_valid_seed;
    my $sid = $seed ? $seed->id : 0;
    
    $self->_default_tool_init;
    
    my $data = eval { $self->_entry_data( $eid, $seed ); };
    my $entry = $data->{entry};
    my $post = $data->{post};
    my $user = $data->{user};
    
    die unless $entry && $post && $user;
    
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.tags");', ),
        Dicole::Widget::CSSLink->new( href => '/css/dicole_tag.css' ),
    );
    
    if ( CTX->request->param('save') ) {
        my $tags_old = CTX->request->param('tags_old');
        my $tags_value = eval {
            CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                input => CTX->request->param('tags_add_tags_input_field'),
                json => CTX->request->param('tags'),
            } );
        };
        
        eval {
            my $tags = CTX->lookup_action('tagging');
            eval {
                $tags->execute( 'update_tags_from_json', {
                    object => $entry,
                    group_id => $gid,
                    user_id => 0,
                    json => $tags_value,
                    json_old => $tags_old,
                } );
            };
            $self->log('error', $@ ) if $@;
        };
        
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Tags updated.') );
    }
    
    if ( CTX->request->param('save') || CTX->request->param('cancel') ) {
        return $self->redirect( $data->{show_url} );
    }
    
    my $old_tags = CTX->lookup_action('tagging')->execute( 'get_tags_for_object_as_json', {
        object => $entry,
        group_id => $gid,
        user_id => 0,
    } );

    my @widgets = (
        Dicole::Widget::Text->new(
            class => 'definitionHeader',
            text => $self->_msg( 'Tags' ),
        ),
        Dicole::Widget::FormControl::Tags->new(
            id => 'tags',
            name => 'tags',
            value => $old_tags,
            old_value => $old_tags,
            add_tag_text => $self->_msg('Add tag'),
        ),
        $self->_get_tagging_suggestion_widgets( $gid, $seed ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Save tag changes'),
                name => 'save',
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Cancel'),
                name => 'cancel',
            ),
        ] ),
    );
    
    $self->_add_navigation_box( seed => $seed );
    
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'Add tags to post "[_1]"', $post->title )
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ @widgets ]
    );
    
    $self->tool->Container->box_at( 1, 1 )->name(
        $self->_msg( $self->_msg( 'Post information' ) )
    );
    $self->tool->Container->box_at( 1, 1 )->add_content( [
        $self->_visualize_message( $entry, $seed, {
            no_tags => 1,
            no_action => 1,
            no_control => 1,
            no_rating => 1,
            full_text => 1,
        } ),
    ] );
    
    return $self->generate_tool_content;
}

sub attachment {
    my ( $self ) = @_;
    
    my $data = eval {
        $self->_entry_data( $self->param('entry_id') );
    };
    
    if ( $@ ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The message you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    my %a_by_id = map { $_->id => $_ } @{ $data->{attachments} || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };
    
    unless ( $a ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => CTX->request->param('thumbnail') ? 1 : 0,
        max_width => 400,
    } );
}

sub draft_attachment {
    my ( $self ) = @_;
    
    my $draft = $self->_get_draft;
    
    if ( ! $draft ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The message you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $draft,
        group_id => 0,
        user_id => $draft->user_id,
    } );

    my %a_by_id = map { $_->id => $_ } @$as;
    my $a = $a_by_id{ $self->param('attachment_id') };
    
    unless ( $a ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => CTX->request->param('thumbnail') ? 1 : 0,
        max_width => 400,
    } );
}

sub temp_attachment {
    my ( $self ) = @_;
    
    my $user = eval {
        CTX->lookup_object('user')->fetch( $self->param('user_id') );
    };
    
    if ( $@ ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The user whose files you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    my $attachments = eval {
        CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
            object => $user,
            user_id => $user->id,
            group_id => $self->param('target_group_id'),
        } );
    };

    my %a_by_id = map { $_->id => $_ } @{ $attachments || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };
    
    unless ( $a ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        $self->redirect( $self->derive_url(
            task => 'new',
            additional => [],
        ) );
    }
    
    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        thumbnail => CTX->request->param('thumbnail') ? 1 : 0,
        max_width => 400,
    } );
}

sub feature {
    my ( $self ) = @_;
    
    my $entry = CTX->lookup_object('blogs_entry')->fetch( $self->param('entry_id') );
    die unless $entry;
    
    $entry->featured( time );
    $entry->save;
    
    $self->redirect( $self->derive_url( task => 'featured' , additional => [ $entry->seed_id ] ) );
}

sub unfeature {
    my ( $self ) = @_;
    
    my $entry = CTX->lookup_object('blogs_entry')->fetch( $self->param('entry_id') );
    die unless $entry;
    
    $entry->featured( 0 );
    $entry->save;
    
    $self->redirect( $self->derive_url( task => 'featured', additional =>  [ $entry->seed_id ] ) );
}

sub confirm_delete {
    my ( $self ) = @_;

    my $entry = CTX->lookup_object('blogs_entry')->fetch( $self->param('entry_id') );
    die 'security error' unless $entry;
    
    die 'security error' unless $self->schk_y(
        'OpenInteract2::Action::Weblog::user_delete', $entry->user_id
    );
    
    $self->init_tool( { tool_args => { no_tool_tabs => 1 } } );
    
    if ( CTX->request->param('del') ) {
        my $post = CTX->lookup_object('weblog_posts')->fetch( $entry->post_id );
        $self->_remove_by_post( $entry->post_id );
        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Entry removed') );
        $self->redirect( $self->derive_url(
            task => 'my',
            additional => [ $entry->seed_id, $entry->user_id ],
        ) );
    }
    
    my $button = Dicole::Widget::FormControl::SubmitButton->new(
        name => 'del',
        value => $self->_msg('Yes, I am sure that I want to delete the message permanently'),
    );
    
    my $no_button = Dicole::Widget::LinkButton->new(
        link => Dicole::URL->create_from_parts(
            action => 'blogs',
            task => 'show',
            target => $entry->group_id,
            additional => [ $entry->seed_id, $entry->id ],
        ),
        text => $self->_msg('No, I changed my mind'),
    );
    
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('You are about to delete a message') );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Horizontal->new( contents => [ $button, $no_button ] ) ]
    );
    $self->tool->tool_title_suffix($self->_msg('Delete message'));
    return $self->generate_tool_content;
}

sub _global_tag_cloud_widget {
    my ( $self, $task, $gid, $sid ) = @_;
    my $tags = eval {
        CTX->lookup_action('tagging')->execute( 'get_weighted_tags', {} );
    };
    
    return $self->_fake_tag_cloud_widget( "/blogs/$task/$gid/$sid/", $tags );
}

# TODO: Create a widget, used also in networking package
sub _fake_tag_cloud_widget {
    my ($self, $prefix, $tags, $limit ) = @_;
    
    return Dicole::Widget::Text->new( text => $self->_msg('No tags.') ) unless @$tags;
    
    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => $prefix,
        limit => $limit,
    );
    $cloud->add_weighted_tags_array( $tags );
    return $cloud;
}

# Blogs updating API functions
sub _update_blogs {
    my ( $self ) = @_;
    
    my $group_id = $self->param( 'group_id' );
    my $last_update = $self->param( 'last_update' );
    my $post_id = $self->param( 'post_id' );
    
    return $self->_update_blogs_internal( $group_id, $last_update, $post_id );
}

sub _update_blogs_internal {
    my ( $self, $group_id, $last_update, $post_id ) = @_;

    my $groups = $group_id ?
        [ CTX->lookup_object('groups')->fetch( $group_id ) || () ]
        :
        CTX->lookup_object('groups')->fetch_group || [];

    for my $group ( @$groups ) {

        my $domain_id = eval {
            my $domains = CTX->lookup_action('dicole_domains')->execute( get_group_domains => { group_id => $group->id } );
            return shift @$domains;
        } || 0;

        my $settings = Dicole::Settings->new_fetched_from_params(
            group_id => $group->id, tool => 'blogs',
        );
        $last_update = -1 if $post_id;
        $last_update = $settings->setting( 'last_update' ) unless defined $last_update;
        $last_update = -1 unless defined $last_update;
        my $last_edited = 0;

        my $users = $group->user || [];
        my $posts = CTX->lookup_object('weblog_posts')->fetch_group( {
            from => [ 'dicole_weblog_posts', 'dicole_blogs_published' ],
            where => 'dicole_blogs_published.group_id = ? AND edited_date > ? AND '.
                ( $post_id ? 'dicole_weblog_posts.post_id = ? AND ' : '' ) .
                'dicole_weblog_posts.post_id = dicole_blogs_published.post_id AND ' .
                Dicole::Utils::SQL->column_in( 'user_id', [ map { $_->id } @$users ] ),
            value => [ $group->id, $last_update, $post_id ? $post_id : () ],
        } );
        
        for my $post ( @$posts ) {
            my $pub = shift @{
                CTX->lookup_object('blogs_published')->fetch_group( {
                    where => 'group_id = ? AND post_id = ?',
                    value => [ $group->id, $post->id ],
                } ) || []
            };
            $self->_update_or_create_entry_from_post( $group, $post, $pub ? $pub->seed_id : 0, $domain_id );
            $last_edited = $post->{edited_date} if $post->{edited_date} > $last_edited;
        }
        
        # Do not update groups last edited mark if post_id was issued
        if ( ! $post_id ) {
            $settings->setting( 'last_update', $last_edited );
        }
    }
}

sub _notify_of_blog_removal {
    my ( $self ) = @_;
    
    my $post_id = $self->param( 'post_id' );

    return $self->_remove_by_post( $post_id );
}

sub _update_or_create_entry_from_post {
    my ( $self, $group, $post, $seed_id, $domain_id ) = @_;
    
    # TODO: Check wether entry is visible?
    
    my $seed = $seed_id ? eval { CTX->lookup_object('blogs_seed')->fetch( $seed_id ) } : undef;
    
    my $entry_object = CTX->lookup_object('blogs_entry');
    
    my $entry = $entry_object->fetch_group( {
        where => 'group_id = ? AND post_id = ?',
        value => [ $group->id, $post->id ],
    } ) || [];
    
    $entry = $entry->[0];
    
    if ( ! $entry ) {
        $entry = $entry_object->new;
        $entry->group_id( $group->id );
        $entry->post_id( $post->id );
        $entry->user_id( $post->user_id );
        $entry->date( $post->date );
        $entry->last_updated( 0 );
        $entry->rating( 0 );
        $entry->points( 0 );
        $entry->featured( 0 );
        $entry->seed_id( $seed ? $seed->id : 0 );
        
        $entry->save;
        
        #CTX->lookup_action('search_api')->execute(process => {object => $entry});
               
        my $uid_obj = CTX->lookup_object( 'blogs_entry_uid' )->new;
        $uid_obj->entry_id( $entry->id );
        $uid_obj->uid( 'dicole-' . eval { CTX->request->server_name } .'-blogs-entry-' . $entry->id );
        $uid_obj->save;
    }
    
    eval {
        my $clone_info = CTX->lookup_action('tagging')->execute( 'clone_tags', {
            from_object => $post,
            from_user_id => $post->user_id,
            from_group_id => 0,
            from_domain_id => 0,
            to_object => $entry,
            to_group_id => $group->id,
            to_user_id => $post->user_id,
            to_domain_id => $domain_id,
        } );
        
        my $attached_tags = $clone_info ? $clone_info->[0] : undef;
        my $removed_tags = $clone_info ? $clone_info->[1] : undef;
        
        if ( $attached_tags && scalar( @$attached_tags ) ) {
            CTX->lookup_action('tagging')->execute( 'attach_tags', {
                object => $entry,
                group_id => $group->id,
                user_id => 0,
                domain_id => $domain_id,
                values => $attached_tags,
            } );
        }
        
        if ( $removed_tags && scalar( @$removed_tags ) ) {
            CTX->lookup_action('tagging')->execute( 'detach_tags', {
                object => $entry,
                group_id => $group->id,
                user_id => 0,
                domain_id => $domain_id,
                values => $removed_tags,
            } );
        }
    };
     
    $entry->last_updated( time() );
    $entry->save;
        
    if ( $seed ) {
        $self->_update_seed_active_date( $seed, [ $entry ] );
        $self->_update_seed_post_count( $seed );
    }
}

sub _get_seed_heat_rating {
    my ( $self, $seed ) = @_;
    
    my $month_ago = DateTime->now;
    $month_ago->subtract( months => 1 );
    my $month_ago_epoch = $month_ago->epoch;
    
    my $entries = $self->_generic_entries(
        seed_id => $seed->id,
        group_id => $seed->group_id,
        where => 'dicole_blogs_entry.date > ?',
        value => [ $month_ago_epoch ],
    );
    
    my $comments = CTX->lookup_object('comments_post')->fetch_group( {
        from => [ 'dicole_comments_post', 'dicole_comments_thread', 'dicole_blogs_entry' ],
        where => 'dicole_comments_thread.object_type = ?' .
        ' AND dicole_comments_thread.object_id = dicole_blogs_entry.entry_id' .
        ' AND dicole_comments_post.thread_id = dicole_comments_thread.thread_id' .
        ' AND dicole_blogs_entry.seed_id = ?' .
        ' AND dicole_comments_post.date > ?',
        value => [ CTX->lookup_object('blogs_entry'), $seed->id, $month_ago_epoch ],
    } )|| [];
    
    my $ratings = CTX->lookup_object('blogs_rating')->fetch_group( {
        from => [ 'dicole_blogs_entry', 'dicole_blogs_rating' ],
        where => 'dicole_blogs_entry.seed_id = ?' .
        ' AND dicole_blogs_rating.entry_id = dicole_blogs_entry.entry_id' .
        ' AND dicole_blogs_rating.date > ?',
        value => [ $seed->id, $month_ago_epoch ],
    } )|| [];
    
    my $promotions = CTX->lookup_object('blogs_promotion')->fetch_group( {
        from => [ 'dicole_blogs_entry', 'dicole_blogs_promotion' ],
        where => 'dicole_blogs_entry.seed_id = ?' .
        ' AND dicole_blogs_promotion.entry_id = dicole_blogs_entry.entry_id' .
        ' AND dicole_blogs_promotion.date > ?',
        value => [ $seed->id, $month_ago_epoch ],
    } ) || [];
    
    my $now = time;
    
    my $rating = 0;
    $rating += $self->_calculate_heat_impact( $entries, $now ) * 5;
    $rating += $self->_calculate_heat_impact( $comments, $now ) * 3;
    $rating += $self->_calculate_heat_impact( $ratings, $now ) * 1;
    $rating += $self->_calculate_heat_impact( $promotions, $now ) * 1;
    
    $rating /= 5;
    $rating *= 100;
    $rating = int( $rating );
    
    $rating = 100 if $rating > 100;
    $rating = 0 if $rating < 0;

    return $rating;
}

sub _calculate_heat_impact {
    my ( $self, $objects, $now ) = @_;
    
    my $seconds_in_month = 2629743; # according to google ;)
    my $rating = 0;
    for my $o ( @$objects ) {
        my $time_elapsed = $now - $o->date;
        my $p = ( $seconds_in_month - $time_elapsed ) / $seconds_in_month;
        $rating += $p**5;
    };
    
    return $rating;
}

1;

package OpenInteract2::Action::DicoleBlogs::NewPostsSummary;


use strict;
use base qw( Dicole::Task::DatedListSummary );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _generate_item_title_text {
    my ( $self, $item ) = @_;
    
    my $post = CTX->lookup_object('weblog_posts')->fetch( $item->post_id );
    return $post->title;
}

sub _generate_item_title_link {
    my ( $self, $item ) = @_;
    
    return Dicole::URL->create_from_parts(
        action => 'blogs',
        task => 'show',
        target => $item->group_id,
        additional => [ $item->seed_id, $item->id, $self->action->_entry_url_title( $item ) ],
    );
}

sub _generate_item_title_widget {
    my ( $self, $item ) = @_;

    my $comment_count = CTX->lookup_action('commenting')->execute( 'get_comment_count', {
        object => $item
    } ) || 0;
    
    my $title = $self->_generate_item_title_text( $item );
    my $link = $self->_generate_item_title_link( $item );
    
    
   my $comment_link = Dicole::URL->create_from_parts(
        action => 'blogs',
        task => 'show',
        target => $item->group_id,
        additional => [ $item->seed_id, $item->id, $self->action->_entry_url_title( $item ) ],
        anchor => 'comments',
    );
    
    
    if ( $link ) {
       return Dicole::Widget::Inline->new( 
        contents => [ 
            Dicole::Widget::Hyperlink->new(
                content => $title,
                link => $link,
                class => 'summary_list_title',
            ),
            $comment_count ? (
                ' ',
                Dicole::Widget::Hyperlink->new(
                    content => '('.$comment_count.')',
                    link => $comment_link,
                    class => 'summary_list_comment_count',
                )
            )
            :
            (),
        ]
      );
    }
    else {
        return $title;
    }
}

1;

package OpenInteract2::Action::DicoleBlogs::NewCommentsSummary;


use strict;
use base qw( Dicole::Task::DatedListSummary );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _generate_item_title_widget {
    my ( $self, $item ) = @_;
    
    my $thread = CTX->lookup_object('comments_thread')->fetch( $item->thread_id );
    my $entry = CTX->lookup_object('blogs_entry')->fetch( $thread->object_id );
    
    my $title = $self->_generate_item_title_text( $entry );
    my $link = $self->_generate_item_title_link( $item, $entry );
    
    return Dicole::Widget::Hyperlink->new(
        content => $self->action->_msg( 'Comment to [_1]' , $title ),
        link => $link,
        class => 'summary_list_title',
    );
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

package OpenInteract2::Action::DicoleBlogs::AddReposter;

use strict;
use base qw( Dicole::Task::GTAdd );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _save {
    my ( $self ) = @_;

    if ( CTX->request->param( 'save' ) ) {
        my $params = {};
        for my $p ( qw/ url username password filter_tags append_tags apply_tags / ) {
            $params->{ $p } = CTX->request->param( $p );
        }

        if ( my $fd = CTX->request->param( 'fetch_delay' ) ) {
            $params->{fetch_delay} = $fd * 60*60;
        }

        if ( my $ma = CTX->request->param( 'max_age' ) ) {
            $params->{max_age} = $ma * 24*60*60;
        }

        $params->{seed_id} = $self->action->param('seed_id');
        $params->{group_id} = $self->action->param('target_group_id');
        $params->{user_id} = CTX->request->auth_user_id;
        $params->{domain_id} = $self->action->param('domain_id') || 0;

        eval {
            CTX->lookup_action('blogs_api')->execute( add_reposter => $params );
        };

        if ( $@ ) {
            $self->action->tool->add_message( MESSAGE_ERROR, $self->action->_msg( "Save failed: [_1]", $@ ) );
            $self->action->gtool->validate_and_save(
                $self->action->gtool->visible_fields,
                { fill_only => 1 }
            );
        }
        else {
            $self->action->tool->add_message( MESSAGE_SUCCESS,  $self->action->_msg( "Reposter saved.") );
        }
    }
}

1;

# package OpenInteract2::Action::DicoleDomainManager::Remove;
# 
# use base 'Dicole::Task::GTRemove';
# use OpenInteract2::Context   qw( CTX );
# 
# # Replace inherited methods in Common::Remove
# 
# sub _post_remove {
#     my ( $self, $ids ) = @_;
# 
#     $ids || return undef;
# 
#     # Cleanup tables that relate to domain
#     # XXX: Should we remove groups/users related to a domain as well?
#     # (those groups/users who belong only to one domain, which is being removed)
#     foreach my $id (keys %{$ids}) {
#         foreach my $object ( 'dicole_domain_user', 'dicole_domain_group' ) {
#             my $dom_objects = CTX->lookup_object( $object )->fetch_group( {
#                 where => 'domain_id = ?',
#                 value => [ $id ]
#             } );
#             foreach my $dom_object ( @{ $dom_objects } ) {
#                 $dom_object->remove;
#             }
#         }
#     }
# 
#     return $self->action->_msg( "Selected domains removed." );
# }
