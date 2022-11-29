package OpenInteract2::Action::DicoleBlogging;

use strict;
use base qw( OpenInteract2::Action::DicoleBlogsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub recent_entry_data_with_tags {
    my ( $self ) = @_;

    return $self->_entries_to_entry_datas( $self->_generic_entries(
        group_id => scalar( $self->param('group_id') ),
        seed_id => scalar( $self->param('seed_id') ),
        tags => scalar( $self->param('tags') ),
        where => scalar( $self->param('where') ),
        value => scalar( $self->param('value') ),
        limit => scalar( $self->param('limit') ),
        order => 'dicole_blogs_entry.date desc',
    ) );
}

sub recent_entry_rss_params_with_tags {
    my ( $self ) = @_;
    my $datas = $self->recent_entry_data_with_tags;

    return [ map { $self->_entry_data_to_rss_params( $_ ) } @$datas ];
}

sub data_for_entries {
    my ( $self ) = @_;
    my $entries = $self->param('entries') || $self->_fetch_entries_for_ids( scalar( $self->param('ids') ) );
    return $self->_entries_to_entry_datas( $entries, undef, $self->param('domain_id') );
}

sub post_for_entry {
    my ( $self ) = @_;

    return $self->_fetch_post_for_entry( $self->param('entry') );
}

sub post_count {
    my ( $self ) = @_;
    
    my $gid = $self->param('group_id');
    my $uid = $self->param('user_id');
    
    my $count = CTX->lookup_object('blogs_entry')->fetch_count( {
        where => 'user_id = ? AND group_id = ?',
        value => [ $uid, $gid ],
    } ) || 0;
    
    return $count;
}

sub entry_title {
    my ( $self ) = @_;
    
    my $entry = $self->param('entry') || $self->param('entry_id');
    my $post = $self->_fetch_post_for_entry( $entry );

    return $post->title;
};

sub entry_urltitle {
    my ( $self ) = @_;
    
    my $entry = $self->param('entry') || $self->param('entry_id');
    $entry = CTX->lookup_object('blogs_entry')->fetch( $entry )
        unless ref( $entry );

    return $self->_entry_url_title( $entry );
};

sub update_entry {
    my ( $self ) = @_;

    my $entry = $self->param('entry') || CTX->lookup_object( 'blogs_entry' )->fetch( $self->param('entry_id') );
    if ( ! $entry ) {
        return 1 if $self->param('entry_not_found_ok');
        die;
    }

    my $domain_id = eval { Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) };
    $domain_id = Dicole::Utils::Domain->domain_id_for_group_id( $entry->group_id ) unless defined $domain_id;

    my $update_needed = 0;

    my $title = $self->param('title');
    my $content = $self->param('content');
    my $creation_date = $self->param('creation_date');

    my $post = $self->_fetch_post_for_entry( $entry );
    if ( defined( $title ) ) {
        $post->title( $title );
        $update_needed = 1;
    }
    if ( defined( $content ) ) {
        $post->content( $content );
        $update_needed = 1;
    }
    if ( defined( $creation_date ) ) {
        $post->creation_date( $creation_date );
        $update_needed = 1;
    }

    my $previous_tags = [];
    my $new_tags = $self->param('tags');
    my $old_tags = $self->param('old_tags') || [];

    eval {
        my $tags_action = CTX->lookup_action('tagging');
        eval {
            $previous_tags = CTX->lookup_action('tagging')->execute( 'get_tags', {
                object => $entry,
                user_id => 0,
                group_id => $entry->group_id,
                domain_id => $domain_id,
            } ) || [];

            if ( $new_tags ) {
                CTX->lookup_action('tagging')->execute( 'update_tags', {
                    object => $post,
                    user_id => $entry->user_id,
                    group_id => 0,
                    domain_id => 0,
                    'values' => $new_tags,
                    'values_old' => $old_tags,
                } );
                $update_needed = 1;
            }
        };
        $self->log('error', $@ ) if $@;
    };

    if ( $update_needed ) {
        $post->edited_date( time - 1 );
        $post->save;
    }

    $update_needed = $self->_update_or_create_source( $entry->id ) ? 1 : $update_needed;

    if ( $update_needed ) {
        $post->edited_date( time - 1 );
        $post->save;

        CTX->lookup_action('update_blogs_entries')->execute( {
            group_id => $entry->group_id,
            post_id => $entry->post_id,
            domain_id => $domain_id,
        } );

        # force refetch of tags
        $self->_store_edit_event( $entry, undef, $domain_id, $self->param('user_id'), $previous_tags );
    }
}

sub create_entry {
    my ( $self ) = @_;

    my $uid = $self->param('user_id');
    my $gid = $self->param('group_id');
    my $sid = $self->param('seed_id');
    my $content = $self->param('content');
    my $title = $self->param('title');
    my $now = $self->param('creation_date') || time -1;
    my $last_updated = $self->param('last_updated') || time -1;
    my $domain_id = $self->param('domain_id');
    my $tags = $self->param('tags');
    my $published = $self->param('published');

    my $post = CTX->lookup_object('weblog_posts')->new;
    $post->writer( $uid );
    $post->groups_id( 0 );
    $post->user_id( $uid );
    $post->content( $content );
    $post->title( $title );

    $post->date( $now );
    $post->publish_date( $now );
    $post->edited_date( $last_updated );

    $post->save;

    eval {
        my $tags_action = CTX->lookup_action('tagging');
        eval {
            $tags_action->execute( 'attach_tags', {
                object => $post,
                user_id => $uid,
                group_id => 0,
                domain_id => 0,
                'values' => $tags || [],
            } );
        };
        $self->log('error', $@ ) if $@;
    };

    my $pub = CTX->lookup_object('blogs_published')->new;
    $pub->post_id( $post->id );
    $pub->group_id( $gid );
    $pub->seed_id( $sid );
    $pub->save;

    CTX->lookup_action('update_blogs_entries')->execute( {
#        last_update => $last_updated - 1,
        group_id => $gid,
        post_id => $post->id,
        domain_id => $domain_id,
    } );

    my $entries = $self->_fetch_entries_for_post_id( $post->id, $gid );
    my $e = shift @$entries;

    return unless $e;

    if ( $published ) {
        my $content = $self->_process_published_content( $e, $content );
        $post->content( $content );
        $post->save;
    }

    if ( my $unique_id = $self->param('unique_id') ) {
        my $uid_objects = CTX->lookup_object('blogs_entry_uid')->fetch_group( {
            where => 'entry_id = ?',
            value => [ $e->id ],
        } ) || [];

        for my $uo ( @$uid_objects ) {
            $uo->uid( $unique_id );
            $uo->save;
        }
    }

    $self->_update_or_create_source( $e->id );

    $self->_store_creation_event( $e, $tags, $domain_id );

    return $e;
}

sub init_store_creation_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'created', @_ );
}

sub init_store_edit_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'edited', @_ );
}

sub init_store_delete_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'deleted', @_ );
}

sub _init_store_some_event {
    my ( $self, $type ) = @_;

    return $self->_store_some_event(
        $type,
        $self->param('entry'),
        undef,
        $self->param('domain_id'),
        $self->param('user_id'),
        $self->param('previous_tags'),
    );
}

sub _store_creation_event {
    my $self = shift @_;
    return $self->_store_some_event( 'created', @_ );
}

sub _store_edit_event {
    my $self = shift @_;
    return $self->_store_some_event( 'edited', @_ );
}

sub _store_delete_event {
    my $self = shift @_;
    return $self->_store_some_event( 'deleted', @_ );
}

sub _store_some_event {
    my ( $self, $type, $entry, $tags, $domain_id, $user_id, $previous_tags ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    eval {
        my $a = CTX->lookup_action('event_source_api');

        eval {
            my $secure_tree = Dicole::Security->serialize_secure(
                'OpenInteract2::Action::DicoleBlogs::read', {
                    group_id => $entry->group_id,
                    domain_id => $domain_id,
                }
            );

            if ( ! $tags ) {
                $tags = CTX->lookup_action('tags_api')->e( get_tags => {
                    object => $entry,
                    group_id => $entry->group_id,
                    user_id => 0,
                    domain_id => $domain_id,
                } );
            }

            my $dd = {
                object_id => $entry->id,
                object_tags => $tags,
            };

            my %event_tags = map { $_ => 1 } @$tags;

            if ( $previous_tags ) {
                $dd->{previous_object_tags} = $previous_tags;
                $event_tags{ $_ } = 1 for @$previous_tags;
            }

            my $event_tags = [ keys %event_tags ];

            my $event_time = $entry->date;
            $event_time = $entry->last_updated if $type =~ /edit/;
            $event_time = time() if $type =~ /delete/;

            # interested? maybe people for whom this is a reply?

            $a->e( add_event => {
                event_type => 'blog_entry_' . $type,
                author => $user_id || $entry->user_id,
                target_user => 0,
                target_group => $entry->group_id,
                target_domain => $domain_id,
                timestamp => $event_time,
                coordinates => [],
                classes => [ 'blog_entry' ],
                interested => [],
                tags => $event_tags,
                topics => [ 'blog_entry::' . $entry->id ],
                secure_tree => $secure_tree,
                data => $dd,
            } )
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error( $@ );
        }
    };
}

sub _update_or_create_source {
    my ( $self, $entry_id ) = @_;

    return 0 unless $entry_id && ( $self->param('original_name') || $self->param('original_link') ||
        $self->param('source_name') || $self->param('source_link') );

    my $sources = CTX->lookup_object('blogs_reposted_link')->fetch_group( {
        where => 'entry_id = ?',
        value => [ $entry_id ]
    } ) || [];
    my $source = pop @$sources || undef;
    $_->remove for @$sources;

    if ( ! $source ) {
        $source = CTX->lookup_object('blogs_reposted_link')->new;
        $source->reposter_id( $self->param('reposter_id') || 0 );
        $source->domain_id( $self->param('domain_id') || 0 );
        $source->entry_id( $entry_id );
    }

    $source->reposter_name( $self->param('reposter_name') || '' );
    for my $key ( qw( source_name source_link original_name original_link ) ) {
        $source->set( $key, $self->param( $key ) || '' );
    }
    $source->original_date( $self->param('original_date') || 0 );
    $source->show_source( $self->param('show_source') );

    $source->save;

    return 1;
}

sub get_existing_entry {
    my ( $self ) = @_;
    
    my $uid = $self->param('uid');
    
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        from => [ 'dicole_blogs_entry', 'dicole_blogs_entry_uid' ],
        where => 'dicole_blogs_entry.entry_id = dicole_blogs_entry_uid.entry_id' .
            ' AND dicole_blogs_entry_uid.uid = ?',
        value => [ $uid ],
    } ) || [];
    
    return shift @$entries;
}

sub delete_entry {
    my ( $self ) = @_;

    my $entry = $self->param('entry');
    my $domain_id = $self->param('domain_id');
    return $self->_remove_by_post( $entry->post_id, $domain_id );
}

sub update_reposters {
    my ( $self ) = @_;

    my $reposters = CTX->lookup_object( 'blogs_reposter' )->fetch_group( {
        where => 'next_update < ? OR next_update = ?',
        value => [ time, 0 ],
    } ) || [];

    $self->_update_reposter( $_ ) for @$reposters;
}

sub add_reposter {
    my ( $self ) = @_;

    my $r = CTX->lookup_object('blogs_reposter' )->new;

    $r->last_update( 0 );
    $r->next_update( 0 );
    $r->error_count( 0 );
    $r->fetch_error('');

    $r->fetch_delay( $self->param('fetch_delay') || 3600  );

    $r->domain_id( $self->param('domain_id') || 0 );
    $r->user_id( $self->param('user_id') || die );
    $r->group_id( $self->param('group_id') || die );

    $r->seed_id( $self->param('seed_id') || 0 );

    $r->title( $self->param('title') || '' );
    $r->url( $self->param('url') || die );
    $r->username( $self->param('username') || '' );
    $r->password( $self->param('password') || '' );
    $r->filter_tags( $self->param('filter_tags') || '' );
    $r->append_tags( $self->param('append_tags') || '' );
    $r->show_source( $self->param('show_source') || '' );

    $r->apply_tags( 1 );
    $r->apply_tags( $self->param('apply_tags') ? 1 : 0 ) if defined $self->param('apply_tags');

    $r->append_title( 0 );
    $r->append_title( $self->param('append_title') ? 1 : 0 ) if defined $self->param('append_title');

    $r->max_age( $self->param('max_age') || 0 );

    $r->save;

    $self->_update_reposter( $r, 1 );
}

sub edit_reposter {
    my ( $self ) = @_;

    my $r = $self->param('reposter') || CTX->lookup_object('blogs_reposter' )->fetch( $self->param('reposter_id') );

    die unless $r;

    $r->fetch_delay( $self->param('fetch_delay') || 3600 ) if defined $self->param('fetch_delay');
    $r->seed_id( $self->param('seed_id') || 0 ) if defined $self->param('seed_id');

    $r->title( $self->param('title') ) if defined $self->param('title');
    $r->url( $self->param('url') ) if defined $self->param('url');
    $r->username( $self->param('username') || '' ) if defined $self->param('username');
    $r->password( $self->param('password') || '' ) if defined $self->param('password');
    $r->filter_tags( $self->param('filter_tags') || '' ) if defined $self->param('filter_tags');
    $r->append_tags( $self->param('append_tags') || '' ) if defined $self->param('append_tags');
    $r->apply_tags( $self->param('apply_tags') ? 1 : 0 ) if defined $self->param('apply_tags');
    $r->append_title( $self->param('append_title') ? 1 : 0 ) if defined $self->param('append_title');

    $r->max_age( $self->param('max_age') || 0 ) if defined $self->param('max_age');

    $r->save;
}


1;