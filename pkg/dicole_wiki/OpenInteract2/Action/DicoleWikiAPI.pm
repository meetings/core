package OpenInteract2::Action::DicoleWikiAPI;

use strict;
use base qw( OpenInteract2::Action::DicoleWikiCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub simple_rename_page {
    my ( $self ) = @_;

    my $new_title = $self->param('title');

    die unless $new_title;

    if ( $new_title && $self->param('suffix_tag') ) {
        $new_title .= ' (#' . $self->param('suffix_tag') . ')';
    }

    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );

    die unless $page;

    $page->readable_title( $self->_raw_title_to_readable_form( $new_title ) );
    $page->title( $self->_raw_title_to_internal_form( $new_title ) );
    $page->save;

    return 1;
}

sub get_sidebar_list_html_for_pages_with_any_of_tags {
    my ( $self ) = @_;

    my $params = {};
    $params->{pages} = $self->get_params_for_pages_with_any_of_tags;

    return unless $params->{pages} && scalar @{ $params->{pages} };

    return $self->generate_content( $params, { name => 'dicole_wiki::sidebar_list' } );
}

sub get_params_for_pages_with_any_of_tags {
    my ( $self ) = @_;

    my $tags = $self->param('tags');
    return unless $tags && scalar( @$tags );

    my $gid = $self->param('group_id');
    my $did = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    my $pages = CTX->lookup_action('tags_api')->e( tag_or_limited_fetch_group => {
        object_class => CTX->lookup_object('wiki_page'),
        tags => $tags,
        where => 'group_id = ?',
        value => [ $gid ],
    });

    my $infos = [];
    for my $page ( @$pages ) {
        my $info = {
            title => $page->readable_title,
            show_url =>  Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $page->groups_id,
                additional => [ $page->title ],
            )
        };

        push @$infos, $info;
    }

    return $infos;
}

sub get_latest_editors {
    my ( $self ) = @_;

    return $self->_get_latest_editors( $self->param('page'), $self->param('limit') );
}

sub get_latest_editors_data {
    my ( $self ) = @_;

    return $self->_get_latest_editors_data( $self->param('page'), $self->param('limit') );
}

sub create_page {
    my ( $self ) = @_;

    $self->param('target_group_id', $self->param('group_id') );

    my $readable_title = scalar( $self->param('readable_title') );

    if ( $readable_title && $self->param('suffix_tag') ) {
        $readable_title .= ' (#' . $self->param('suffix_tag') . ')';
    }

    my $title = scalar( $self->param('title') ) || $self->_title_to_internal_form( $readable_title );
    
    my $page = $self->_create_page(
        group_id => scalar( $self->param('group_id') ),
        domain_id => scalar( $self->param('domain_id') ),
        creator_id => scalar( $self->param('creator_id') ),
        created_date => $self->param('created_date'),

        readable_title => $readable_title,
        title => $title,

        content => scalar( $self->param('content') ),
        base_page_id => scalar( $self->param('base_page_id') ),
        prefilled_tags => scalar( $self->param('prefilled_tags') ),

        skip_starting_page_proposal => scalar( $self->param('skip_starting_page_proposal') ),
    );

    return $page;
}

sub remove_page {
    my ( $self ) = @_;

    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );

    $self->_remove_page( $page, $self->param('domain_id'), $self->param('user_id') );
}

sub fetch_version_for_page {
    my ( $self ) = @_;

    return $self->_fetch_version_for_page( $self->param('page'), $self->param('version_number') );
}

sub object_info {
    my ( $self ) = @_;

    return $self->_object_info( $self->param('page'), $self->param('requesting_user_id'), $self->param('domain_id') );
}

sub decode_title {
    my ( $self ) = @_;

    my ( $t, $a ) = $self->_decode_title( $self->param('title') );
    return ( $t, $a, $self->_title_to_internal_form( $t ) );
}

sub gather_page_data {
    my ( $self ) = @_;

    my $gid = scalar( $self->param('group_id') ) || CTX->controller->initial_action->param('target_group_id');
    my $page = $self->param('page') || $self->_fetch_page( $self->param('title'), undef, $gid );
    return $self->_gather_data_for_pages( [ $page ], $self->param('domain_id') )->[0];
}

sub readable_page_title {
    my ( $self ) = @_;

    my $gid = scalar( $self->param('group_id') ) || CTX->controller->initial_action->param('target_group_id');
    my $page = $self->param('page') || $self->_fetch_page( $self->param('title'), undef, $gid );
    return $page->readable_title;
}

sub filtered_page_content {
    my ( $self ) = @_;

    my $gid = scalar( $self->param('group_id') ) || CTX->controller->initial_action->param('target_group_id');
    my $page = $self->param('page') || $self->_fetch_page( $self->param('title'), undef, $gid );
    return $self->_filtered_page_content( $page, $self->param('link_generator'), $self->param('domain_id') );
}

# somewhat deprecated..
sub recent_page_data {
    my ( $self ) = @_;

    my $data = $self->recent_page_data_with_tags;
    delete $_->{page} for @$data;
    return $data;
}

sub recent_page_data_with_tags {
    my ( $self ) = @_;

    my $gid = $self->param('group_id') || CTX->controller->initial_action->param('target_group_id');
    my $did = $self->param('domain_id') || CTX->controller->initial_action->param('domain_id');

    my $pages = $self->_generic_pages(
        group_id => $gid,
        domain_id => $did,
        tags => scalar( $self->param('tags') ),
        where => scalar( $self->param('where') ),
        value => scalar( $self->param('value') ),
        limit => scalar( $self->param('limit') ),
        order => 'last_modified_time desc',
    );

    return $self->_gather_data_for_pages( $pages, $did );
}

sub recent_change_rss_params_with_tags {
    my ( $self ) = @_;

    my $gid = scalar( $self->param('group_id') );

    my $pages = $self->_generic_pages(
        group_id => $gid,
        tags => scalar( $self->param('tags') ),
    );

    my %page_by_id = map { $_->id => $_ } @$pages;
    my %page_tags = ();

    my $objects = scalar( @$pages ) ? CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'groups_id = ? AND change_type = ? AND ' .
            Dicole::Utils::SQL->column_in( page_id => [ keys %page_by_id ] ),
        value => [ $gid, $self->CHANGE_NORMAL ],
        order => 'creation_time DESC',
        limit => $self->param('limit'),
    } ) || [] : [];

    my $surl = $self->param('server_url') || Dicole::URL->get_server_url;

    my @data = ();

    for my $item ( @$objects ) {
        my $vn = $item->version_number;
        my @diffs = $vn ? ( $vn - 1, $vn ) : ( 0, 0 );
        my $page = $page_by_id{ $item->page_id };

        my $link = Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'changes',
            target => $gid,
            additional => [
                $page->{title},
                @diffs
            ],
        );

        if ( ! $page_tags{ $page->id } ) {
            $page_tags{ $page->id } = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
                object => $page,
                group_id => $page->groups_id,
                user_id => 0,
                domain_id => $self->param('domain_id'),
            } ) || [];
        }
        my $tags = $page_tags{ $page->id } || [];

        push @data,{
            link => $surl . $link,
            title => $page->{readable_title},
            description => $item->change_description,
            pubDate => $item->creation_time,
            author => Dicole::Utils::User->name( $item->creator_id ),
            guid => $surl . $link,
            category => $tags,
        };
    }

    return \@data;
}

sub data_for_pages {
    my ( $self ) = @_;

    my $pages = $self->param('pages') || $self->_fetch_pages_for_ids( scalar( $self->param('ids') ) );
    return $self->_gather_data_for_pages( $pages, $self->param('domain_id') );
}

sub wiki_link_from_title {
    my ( $self ) = @_;

    my $title = $self->param('title');
    my $group_id = $self->param('group_id');
    my $domain_id = $self->param('domain_id');

    unless ( $group_id ) {
        $group_id = eval { CTX->controller->initial_action->param('target_group_id') };
    }

    my ( $t, $a ) = $self->_decode_title( $title );

    my $internal = $self->_title_to_internal_form( $t );

    return $group_id ? Dicole::URL->create_from_parts(
        action => 'wiki',
        task => 'show',
        target => $group_id,
        additional => [ $internal ],
        anchor => $a,
        ( defined $domain_id ? ( domain_id => $domain_id ) : () ),
    ) : '#';
}

sub init_store_change_event {
    my ( $self ) = @_;

    return $self->_store_change_event(
        $self->param('version'),
        $self->param('domain_id'),
    );
}

sub get_full_lock {
    my ($self) = @_;

    my $lock = $self->_fetch_current_full_lock_for_page( $self->param('page') || $self->param('page_id') )
        or return { error => "no such lock" };

    return {
        user_id => $lock->user_id,
        lock_id => $lock->lock_id,
        autosave_content => $lock->autosave_content
    };
}

sub start_raw_edit {
    my ( $self ) = @_;

    my $user = $self->param( 'editing_user' ) || Dicole::Utils::User->ensure_object( $self->param( 'editing_user_id' ) );
    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );
    my $continue_edit = $self->param('continue_edit');

    my $sections = $self->_current_sections_for_page( $page );
    my $html = $self->_sections_to_html( $sections );

    my $current_lock = $self->_fetch_current_full_lock_for_page( $page );
    my $new_lock;

    if ( ! $current_lock ) {
        $new_lock = CTX->lookup_object('wiki_lock')->new( {
            page_id => $page->id,
            user_id => $user->id,
            version_number => $page->last_version_number,
            lock_created => time,
            lock_renewed => time,
            autosave_content => $html,
            lock_position => 0,
            lock_size => 10000001,
        } );
        $new_lock->save;

        $current_lock = $self->_fetch_current_full_lock_for_page( $page );

        if ( ! $current_lock || $current_lock->id != $new_lock->id ) {
            $new_lock->remove;
            undef $new_lock;
        }
    }

    if ( ! $new_lock ) {
        if ( ! $current_lock ) {
            return { result => { lock_id => 0 } };
        }

        my $locked_by_self = $current_lock->user_id == $user->id ? 1 : 0;
        if ( $locked_by_self && $continue_edit && $current_lock->lock_size == 10000001 ) {
            return { result => {
                html => $current_lock->autosave_content,
                lock_id => $current_lock->id,
            } };
        }

        return { result => {
            lock_id => 0,
        } };
    }

    return { result => {
        html => $html,
        lock_id => $new_lock->id,
    } };
}

sub store_raw_edit {
    my ( $self ) = @_;

    my $user = $self->param( 'editing_user' ) || Dicole::Utils::User->ensure_object( $self->param( 'editing_user_id' ) );
    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );

    my $lock_id = $self->param('lock_id');
    
    my $old_html = $self->param('old_html');
    my $new_html = $self->param('new_html');

    my $current_version = $page->last_version_id_wiki_version;
    my $current_sections = $self->_sections_for_page_version( $page, $current_version );

    my $current_lock = $self->_fetch_current_full_lock_for_page( $page );
    if ( ! $current_lock ) {
        my $current_html = $self->_sections_to_html( $current_sections );
        if ( $current_html eq $new_html ) {
            return { result => { success => 1, html => $new_html } };
        }
    }
    elsif ( $current_lock->user_id != $user->id || $current_lock->lock_id != $lock_id ) {
        return { error => 'You are trying to store content with an expired lock and somebody has already managed to lock the page while you were editing it. Please copy & paste your changes to a separate window and restart the editing process with the current version after other are done editing the page.' };    
    }

    my $old_size = $self->_get_length_for_sections( $current_sections );

    my $new_sections = $self->_parse_sections( $new_html );
    my $new_size = $self->_get_length_for_sections( $new_sections );

    my $change_info = {
        position => 0,
        old => $old_size,
        new => $new_size,
    };

    $self->_create_new_version_for_page( $page, $new_html, $change_info, $current_version, $self->CHANGE_MINOR, $user->id, $self->param('domain_id') ); 

    if ( $current_lock ) {
        $current_lock->remove;
    }

    return { result => { success => 1, html => $new_html } };
}

sub cancel_raw_edit {
    my ( $self ) = @_;

    my $user = $self->param( 'editing_user' ) || Dicole::Utils::User->ensure_object( $self->param( 'editing_user_id' ) );
    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );

    my $lock_id = $self->param('lock_id');

    my $current_lock = $self->_fetch_current_full_lock_for_page( $page );
    if ( $current_lock && $current_lock->user_id == $user->id && $current_lock->lock_id == $lock_id ) {
        $current_lock->remove;
    }
    
    return { result => { success => 1 } };
}

sub renew_full_lock {
    my ($self) = @_;

    my $user = $self->param( 'editing_user' ) || Dicole::Utils::User->ensure_object( $self->param( 'editing_user_id' ) );
    my $page = $self->param('page') || CTX->lookup_object('wiki_page')->fetch( $self->param('page_id') );

    my $current_lock = $self->_fetch_current_full_lock_for_page( $page );
    my $lock_id = $self->param('lock_id');
    my $autosave_content = $self->param('autosave_content');

    if ( $current_lock && $current_lock->user_id == $user->id && $current_lock->lock_id == $lock_id ) {
        my $time = time;
        my $lock = CTX->lookup_object('wiki_lock')->fetch( $lock_id );
        if ( $lock && $lock->user_id == $user->id ) {
            $lock->lock_renewed( $time );
            $lock->autosave_content( $autosave_content );
            $lock->save;
            return { result => { renew_succesfull => 1 } };
        }
    }
    return { result => { renew_succesfull => 0 } };
}

sub user_bookmarked_pages_data {
    my ( $self ) = @_;

    my $ordered_preses = CTX->lookup_action('bookmarks_api')->e( bookmark_limited_fetch_group => {
        object_class => CTX->lookup_object('wiki_page'),
        domain_id => $self->param('domain_id'),
        group_id => $self->param('group_id'),
        creator_id => $self->param('creator_id'),
        order => 'dicole_bookmark.created_date desc',
    } );

    return [ map { {
        title => $_->readable_title,
        url => Dicole::URL->from_parts(
            domain_id => $self->param('domain_id'), target => $self->param('group_id'),
            action => 'wiki', task => 'show', additional => [ $_->title ]
        ),        
    } } @$ordered_preses ];
}

1;
