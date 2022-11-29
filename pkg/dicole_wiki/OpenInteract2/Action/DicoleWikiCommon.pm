package OpenInteract2::Action::DicoleWikiCommon;

use strict;
use base qw( Dicole::Action Class::Accessor );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use List::Util qw( reduce );
use Text::Unidecode;
use Encode;
use Encode::Guess qw/iso-8859-1/;
use URI::Escape;

use Dicole::Utility;
use Dicole::Utils::HTML;

sub CHANGE_NORMAL { 0 }
sub CHANGE_MINOR  { 1 }
sub CHANGE_CREATE { 2 }
sub CHANGE_REVERT { 3 }
sub CHANGE_ANNO   { 4 }

sub CHANGE_LABELS {
    return {
        CHANGE_NORMAL() => 'change',
        CHANGE_MINOR() => 'minor_change',
        CHANGE_CREATE() => 'create',
        CHANGE_REVERT() => 'revert',
    };
}

########################
# common private functions

sub _create_page {
    my ( $self, %p ) = @_;

    my $group_id = $p{group_id};

    my $readable_title = $p{readable_title};
    my $title = $p{title};
    $title ||= $self->_title_to_internal_form( $readable_title );

    my $content = $p{content};
    my $base_page_id = $p{base_page_id};

    my $skip_starting_page_proposal =  $p{skip_starting_page_proposal};

    if ( $base_page_id ) {
        my $base_page = eval { CTX->lookup_object('wiki_page')->fetch( $base_page_id ) };
        if ( $base_page ) {
            my $content_object = eval { $base_page->last_content_id_wiki_content };
            $content = $content_object->content if $content_object;
        }
    }

    my $version = $self->_create_new_version( $content, undef, undef, undef, $p{creator_id}, $p{created_date} );

    my $new_page = CTX->lookup_object('wiki_page')->new( {
        title => $title,
        readable_title => $readable_title,
        groups_id => $group_id,
        created_date => $version->creation_time,
        creator_id => $version->creator_id,
        moderator_lock => 0,
        hide_comments => 0,
        hide_annotations => 0,
        show_annotations => 0,
    } );

    $self->_fill_page_from_version( $new_page, $version );
    $new_page->save;

    $self->_update_page_indexes( $new_page, $content );

    $version->page_id( $new_page->id );
    $version->save;

    $self->_insert_link_ids_for_page( $new_page );

    $self->_store_change_event( $version, $p{domain_id} );

    unless ( $skip_starting_page_proposal ) {
        my $settings = Dicole::Settings->new_fetched_from_params(
            tool => 'wiki',
            group_id => $group_id
        );
        $self->_propose_starting_page( $new_page, $settings, $group_id );
    }

    if ( $p{prefilled_tags} ) {
        eval {
            my $tags_action = CTX->lookup_action('tagging');
            eval {
                my $json_tags = $tags_action->execute( merge_input_to_json_tags => {
                    input => $p{prefilled_tags},
                    json => Dicole::Utils::JSON->encode([]),
                } );
                my $tags = eval { CTX->lookup_action('tags_api')->e( decode_json => { json => $json_tags } ) } || [];
                $self->log('error', $@ ) if $@;
                $tags_action->execute( 'attach_tags', {
                    object => $new_page,
                    user_id => 0,
                    group_id => $new_page->groups_id,
                    domain_id => Dicole::Utils::Domain->guess_current_id( $p{domain_id} ),
                    'values' => $tags || [],
                } );
            };
            $self->log('error', $@ ) if $@;
        };
    }
    return $new_page;
}

sub _remove_page {
    my ( $self, $page, $domain_id, $user_id ) = @_;

    my $version = $page->last_version_id_wiki_version;
    $self->_store_delete_event( $version, $domain_id, $user_id );

    eval { CTX->lookup_action('tags_api')->e( purge_tags => {
        object => $page,
        group_id => $page->groups_id,
        user_id => 0,
        domain => $domain_id,
    } ) };

    my $linking = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linked_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    for ( @$linking ) {
        $_->linked_page_id( 0 );
        $_->save;
    }

    my $linked = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linking_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    $_->remove for @$linked;

    # Content objects are not removed. Just in case ;)

    my $versions = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
    } ) || [];
    $_->remove for @$versions;
    
    my $summary_pages = CTX->lookup_object('wiki_summary_page')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
    } ) || [];

    $_->remove for @$summary_pages;

    $page->remove;
}

sub _object_info {
    my ( $self, $page, $requesting_user_id, $domain_id ) = @_;

    my $group_id = $page->groups_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $data = $self->_gather_data_for_pages( [ $page ], $domain_id )->[0];

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $page,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
    } );

    my $content = $self->_filtered_page_content( $page );
    my $autolinked_content = Dicole::Utils::HTML->link_plaintext_urls( $content );

    my $info = {
        id => $page->id,
        title => $page->title,
        readable_title => $page->readable_title,
        content => $content,
        autolinked_content => $autolinked_content,
        tags => CTX->lookup_action('tags_api')->e( get_tags_for_object => {
            object => $page,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
        } ),
        comments => CTX->lookup_action('comments_api')->e( get_comments_info => {
            thread => $thread,
            object => $page,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            size => CTX->request->param('commenter_size') || 60,
        } ),
        comment_thread_id => $thread->id,
        show_url => $data->{show_url},

        data_url => Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'wiki_json', task => 'object_info',
            target => $group_id, additional => [ $page->id ],
        ),
    };

    my $editor_id_list = $self->_get_latest_editors( $page, 5 );
    $info->{editors} = [];
    for my $editor_id ( @$editor_id_list ) {
        push @{ $info->{editors} }, {
            name => Dicole::Utils::User->name( $editor_id ),
            url => Dicole::Utils::User->url( $editor_id, $group_id ),
            image => Dicole::Utils::User->image( $editor_id, CTX->request->param('editor_size') || 28 ),
        };
   }

   return $info;
}

sub _fetch_current_full_lock_for_page {
    my ( $self, $page ) = @_;

    my $id = ref $page ? $page->id : $page;

    my $valid_time = time() - 15 * 60;
    my $locks = CTX->lookup_object('wiki_lock')->fetch_group( {
        where => 'page_id = ? AND lock_renewed > ?',
        value => [ $id, $valid_time ],
        order => 'lock_id asc',
    } ) || [];

    return $locks->[0];
}

sub _insert_link_ids_for_page {
    my ($self, $page) = @_;

    my $old_links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'groups_id = ? AND linked_page_title = ?',
        value => [ $page->groups_id, $page->title ],
    } ) || [];

    for (@$old_links) {
        $_->linked_page_id( $page->id );
        $_->save;
    }
}

sub _generic_pages {
    my ( $self, %p ) = @_;

    my $where = 'dicole_wiki_page.groups_id = ?';
    $where .= ' AND ' . $p{where} if $p{where};
    my $value = [ $p{group_id}, $p{value} ? @{$p{value}} : () ];

    my $tags = ( $p{tags} && ref( $p{tags} ) eq 'ARRAY' ) ? $p{tags} : [];
    push @$tags, $p{tag} if $p{tag};

    my $pages = scalar( @$tags ) ?
        eval { CTX->lookup_action('tags_api')->execute( 'tag_limited_fetch_group', {
            domain_id => $p{domain_id},
            group_id => $p{group_id},
            user_id => 0,
            object_class => CTX->lookup_object('wiki_page'),
            tags => $tags,
            where => $where,
            value => $value,
            order => $p{order},
            $p{limit} ? ( limit => $p{limit} ) : (),
        } ) } || []
        :
        CTX->lookup_object('wiki_page')->fetch_group( {
            where => $where,
            value => $value,
            order => $p{order},
             $p{limit} ? ( limit => $p{limit} ) : (),
        } ) || [];

    return $pages;
}

sub _propose_starting_page {
    my ( $self, $page, $settings, $gid ) = @_;

    if ( $settings && ! $settings->setting( 'starting_page' ) ) {
        $settings->setting( 'starting_page', $page->title );
#        removed after separate custom summary front page
#        $self->_add_page_as_summary_page( $page, $gid );
    }
}

sub _add_page_as_summary_page {
    my ( $self, $page, $gid ) = @_;

    $gid ||= $self->param('target_group_id');

    my $a = CTX->lookup_object('wiki_summary_page')->fetch_group( {
        where => 'group_id = ? AND page_id = ?',
        value => [ $gid, $page->id ],
    } ) || [];

    unless ( scalar( @$a ) ) {
        CTX->lookup_object('wiki_summary_page')->new( {
            group_id => $gid,
            page_id => $page->id
        } )->save;
    }
}

sub _create_new_version {
    my ( $self, $version_html, $change_info, $base_version, $change_type, $creator_id, $created_time ) = @_;

    my $content = CTX->lookup_object('wiki_content')->new( {
        content => $version_html
    } );
    $content->save;

    my $page_id = $base_version ? $base_version->page_id : 0;
    my $version_number = $base_version ?
        $base_version->version_number + 1 : 0;

    my $description = CTX->request ? CTX->request->param('change_description') : '';
    
    if ( ! defined( $change_type ) ) {
        $change_type = CHANGE_CREATE;
        if ( $version_number != 0 ) {
            $change_type = ( $description =~ /^[\s\n]*$/ || CTX->request->param('change_minor') ) ?
                CHANGE_MINOR : CHANGE_NORMAL;
        }
    }

    my $version = CTX->lookup_object('wiki_version')->new( {
        page_id => $page_id,
        groups_id => $self->param('target_group_id'),
        content_id => $content->id,
        creator_id => $creator_id || CTX->request->auth_user_id,
        version_number => $version_number,
        creation_time => $created_time || time(),
        change_position => $change_info->{position} || 0,
        change_old_size => $change_info->{old} || 0,
        change_new_size => $change_info->{new} || 0,
        change_type => $change_type,
        change_description => $description,
    } );
    $version->save;

    return wantarray ? ($version, $content) : $version;
}

sub _create_new_version_for_page {
    my ( $self, $page, $html, $change_info, $current_version, $change_type, $creator_id, $domain_id ) = @_;

    $current_version ||= $page->last_version_id_wiki_version;

    my ($version, $content) = $self->_create_new_version(
        $html, $change_info, $current_version, $change_type, $creator_id
    );

    $self->_fill_page_from_version( $page, $version );
    $page->save;

    $self->_store_change_event( $version, $domain_id );

    return wantarray ? ($version, $content) : $version;
}

sub _fill_page_from_version {
    my ( $self, $page, $version ) = @_;

    $page->last_version_number( $version->version_number );
    $page->last_version_id( $version->id );
    $page->last_content_id( $version->content_id );
    $page->last_author_id( $version->creator_id );
    $page->last_modified_time( $version->creation_time );
}

sub _tree_from_content {
    my ( $self, $content ) = @_;
    return Dicole::Utils::HTML->safe_tree( $content );
}

sub _elements_from_content {
    my ( $self, $content ) = @_;
    my $tree = $self->_tree_from_content( $content );
    return $tree->guts;
}

sub _title_to_internal_form {
    my ($self, $title) = @_;
    
    return Dicole::Utils::Text->utf8_to_url_readable( $title );
}

sub _raw_title_to_readable_form {
    my ($self, $title) = @_;

    # Stupid MYSQL doesn't store trailing spaces before 5.0.3
    $title =~ s/ *$//;

    return $title;
}

sub _raw_title_to_internal_form {
    my ($self, $title) = @_;

    return $self->_title_to_internal_form(
        $self->_raw_title_to_readable_form( $title )
    );
}

sub _fetch_page {
    my ( $self, $title, $pages, $gid ) = @_;

    my $page;

    if ( ref $pages eq 'ARRAY' ) {
        for (@$pages) {
            if ( lc $_->title eq lc $title ) {
                $page = $_;
                last;
            }
        }
    }
    else {
        $gid ||= CTX->controller->initial_action->param( 'target_group_id' );
        $pages = CTX->lookup_object('wiki_page')->fetch_group( {
            where => "groups_id = ? AND title = ?",
            value => [ $gid, $title ],
        } ) || [];

        $page = shift @$pages;
    }

    return $page;
}

sub _fetch_redirected_page {
    my ( $self, $title, $gid ) = @_;

    $gid ||= CTX->controller->initial_action->param( 'target_group_id' );
    my $redirs = CTX->lookup_object('wiki_redirection')->fetch_group( {
        where => "group_id = ? AND title = ?",
        value => [ $gid, $title ],
        order => 'date desc',
    } ) || [];

    my $redir = shift @$redirs;

    if ( $redir ) {
        my $page = CTX->lookup_object('wiki_page')->fetch( $redir->page_id );
        return $page || undef;
    }
    return undef;
}

sub _parse_title {
    my ( $self ) = @_;

    my $title = $self->param('title');
    return $self->_raw_title_to_internal_form( $title );
}

sub _fetch_version_for_page {
    my ( $self, $page, $version_number ) = @_;

    return undef unless $version_number =~ /^\d+$/;
    my $id = ref $page ? $page->id : $page;

    my $versions = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'page_id = ? AND version_number = ?',
        value => [ $id, $version_number ],
        limit => 1,
    } ) || [];

    return shift @$versions;
}

sub _fetch_versions_for_page_since {
    my ( $self, $page, $version_number ) = @_;

    my $id = ref $page ? $page->id : $page;

    my $versions = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'page_id = ? AND version_number >= ?',
        value => [ $id, $version_number ],
        order => 'creation_time desc',
    } ) || [];

    return $versions;
}

sub _fetch_locks_for_page {
    my ( $self, $page ) = @_;

    my $id = ref $page ? $page->id : $page;

    my $valid_time = time() - 15 * 60;
    my $locks = CTX->lookup_object('wiki_lock')->fetch_group( {
        where => 'page_id = ? AND lock_renewed > ?',
        value => [ $id, $valid_time ],
    } ) || [];

    return $locks;
}

sub _sections_for_page {
    my ( $self, $page, $version ) = @_;
    
    if ( defined( $version ) ) {
         my $version_object = $self->_fetch_version_for_page( $page, $version );
         die "No such version" unless $version_object;
         return $self->_sections_for_page_version( $page, $version_object );
    }
    else {
        return $self->_current_sections_for_page( $page );
    }
}

sub _current_sections_for_page {
    my ( $self, $page ) = @_;

    my $content = $page->last_content_id_wiki_content;

    my $sections = $self->_parse_sections(
#        $content->content || '<p></p>'
        $content->content || ''
    );

    return $sections;
}

sub _sections_for_page_version {
    my ( $self, $page, $version ) = @_;

    my $content = $version->wiki_content;
    my $sections = $self->_parse_sections(
        $content->content || '<p></p>'
    );

    return $sections;
}

sub _fetch_pages_for_ids {
    my ( $self, $ids ) = @_;

    return CTX->lookup_object('wiki_page')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( page_id => $ids ),
    } ) || [];
}

sub _parse_sections_for_version {
    my ( $self, $version ) = @_;

    my $content = $version->wiki_content;

    return $self->_parse_sections( $content->content );
}

sub _parse_sections {
    my ( $self, $html ) = @_;
    return shift->_parse_sections_x( $html, 1 );
}

sub _parse_sections_part {
    my ( $self, $html ) = @_;
    return shift->_parse_sections_x( $html, 0 );
}

sub _parse_sections_x {
    my ( $self, $html, $full ) = @_;

    my $tree = $self->_tree_from_content( $html );

    my @nodes = $tree->guts;

    my @sections = ();
    my $count = 0;

    for my $node (@nodes) {

        if ( ( ref $node && $node->tag =~ /^h(\d+)$/ ) || ! @sections ) {
            my $level = $1 || 0;

            if ( $full && $level != 0 && ! @sections ) {
                $count++;
                push @sections, { level => 0, nodes => [], id => $count };
            }

            $count++;
            push @sections, { level => $level, nodes => [], id => $count };
        }

        push @{$sections[-1]->{nodes}}, $node;
    }

    if ( $full && ! scalar(@sections) ) {
        @sections = ( { level => 0, nodes => [], id => 1 } );
    }

    for my $section (@sections) {
        $section->{html} = $self->_nodes_to_html( $section->{nodes} );
    }

    return \@sections;
}

sub _get_target_block_from_sections {
    my ( $self, $sections, $target_id, $target_type ) = @_;

    my ( $before, $target, $after ) = $self->_split_sections_for_target(
        $sections, $target_id, $target_type
    );

    my $begin = $self->_get_length_for_sections( $before );
    my $size = $self->_get_length_for_sections( $target );

    return { position => $begin, size => $size };
} 

# Returns three arrayrefs of sections:
# before target, target and after target
sub _split_sections_for_target {
    my ( $self, $sections, $target_id, $target_type ) = @_;

    my @before = ();
    my @target = ();
    my @after = ();

    my $before_target = 1;
    # 0 is base level which absorbs everything.
    # the first block is at level 0 if it has no heading so
    # if it is edited as a block, edit the whole page.
    my $in_section_level = -1;

    for my $section (@$sections) {
        if ( $in_section_level > -1 ) {
            if ( $section->{level} > $in_section_level ) {
                push @target, $section;
                next;
            }
            $in_section_level = -1;
        }

        if ( $target_id == $section->{id} ) {
            $before_target = 0;
            push @target, $section;

            if ($target_type eq 'block') {
                $in_section_level = $section->{level};
            }
        }
        else {
            if ( $before_target ) {
                push @before, $section;
            }
            else {
                push @after, $section;
            }
        }
    }

    return \@before, \@target, \@after;
}

sub _get_length_for_sections {
    my ($self, $sections) = @_;

    my $length = 0;
    $length += $self->_get_length_for_section( $_ ) for @$sections;
    return $length;
}

sub _get_length_for_section {
    my ($self, $section) = @_;

    return scalar(@{ $section->{nodes} });
}

sub _sections_to_html {
    my ($self, $sections) = @_;

    my $html = '';
    $html .= $_->{html} for @$sections;

    return $html;
}

sub _nodes_to_html {
    my ($self, $nodes) = @_;

    my $htmls = $self->_nodes_to_html_nodes( $nodes );

    return join '', @$htmls;
}

sub _nodes_to_html_nodes {
    my ($self, $nodes) = @_;

    my @html_nodes = ();
    for my $node ( @$nodes ) {
        my $html = ref $node ? $node->as_HTML( undef, undef, {} ) : $node;
        $html = Dicole::Utils::Text->ensure_utf8( $html );
        push @html_nodes, $html;
    }

    return \@html_nodes;
}

sub _sections_to_html_nodes {
    my ($self, $sections) = @_;

    my @html_nodes = ();
    for my $section ( @$sections ) {
        my $hna = $self->_nodes_to_html_nodes( $section->{nodes} );
        push @html_nodes, @$hna;
    }

    return \@html_nodes;
}

sub _remove_lock {
    my ( $self, $lock_id ) = @_;
    
    $lock_id ||= CTX->request->param('edit_lock');

    if ( $lock_id ) {
        my $lock = CTX->lookup_object('wiki_lock')->fetch( $lock_id );
        if ( $self->_check_lock_ownership( $lock ) ) {
            $lock->remove;
            return 1;
        }
    }
    
    return 0;
}

sub _check_lock_ownership {
    my ( $self, $lock ) = @_;

    return ( $lock && $lock->user_id == CTX->request->auth_user_id ) ? 1 : 0;
}

sub _get_shifted_locks_for_version {
    my ( $self, $page, $target_version_number, $versions ) = @_;

    my $lock_blocks = $self->_fetch_lock_blocks( $page );

    $versions = $self->_fetch_needed_versions_for_locks(
        $page, $lock_blocks, $versions, $target_version_number
    );

    $self->_shift_blocks_up_for_versions(
        $lock_blocks, $versions
    );

    $self->_shift_blocks_down_to_version(
        $lock_blocks, $target_version_number, $versions
    );

    return $lock_blocks;
}

sub _fetch_lock_blocks {
    my ( $self, $page ) = @_;

    my $locks = $self->_fetch_locks_for_page( $page );

    return [] if ! scalar( @$locks );

    my $lock_blocks = [];
    for my $lock ( @$locks ) {
        push @$lock_blocks, {
            original_lock => $lock,
            version_number => $lock->version_number,
            position => $lock->lock_position,
            size => $lock->lock_size,
        };
    }

    return $lock_blocks;
}

sub _fetch_needed_versions_for_locks {
    my ( $self, $page, $locks, $versions, $base_version ) = @_;

    $versions ||= [];

    return $versions if ! scalar(@$locks);

    my $first_lock = reduce {
        $a->{version_number} < $b->{version_number} ? $a : $b
    } @$locks;

    if ( $first_lock ) {
        if ( ! defined $base_version ||
                $first_lock->{version_number} < $base_version ) {

            $versions = $self->_fetch_versions_for_page_since(
                $page, $first_lock->{version_number}
            );
        }
    }

    return $versions;
}

sub _shift_blocks_up_for_versions {
    my ( $self, $blocks, $versions ) = @_;

    for my $block ( @$blocks ) {
        for my $version (
            sort { $a->version_number <=> $b->version_number } @$versions
        ) {
            # Shift only for versions after block base version
            next if $version->version_number <= $block->{version_number};

            # After this, the current version of the block is this
            $block->{version_number} = $version->version_number;

            # No need to shift if change occurs after block
            next if $version->change_position >=
                $block->{position} + $block->{size};

            # If change does not overlap, just move block
            if ( $version->change_position + $version->change_old_size <=
                    $block->{position} ) {

                $block->{position} += ( $version->change_new_size -
                    $version->change_old_size );
            }
            # Else block engulfs all overlapping changes
            # Basically we should never end up here since
            # locks should never overlap and this function
            # is used only for locks.
            else {
                my $begin_change = $block->{position} -
                    $version->change_position;

                if ( $begin_change > 0 ) {
                    $block->{position} -= $begin_change;
                    $block->{size} += $begin_change;
                }

                my $end_change = $version->change_old_size -
                        $block->{size} - $begin_change;

                if ( $end_change > 0 ) {
                    $block->{size} += $end_change;
                }

                $block->{size} += ( $version->change_new_size -
                    $version->change_old_size );
            }
        }
    }
}

sub _shift_blocks_down_to_version {
    my ( $self, $blocks, $target_version, $versions ) = @_;

    for my $block ( @$blocks ) {
        for my $version (
            sort { $b->version_number <=> $a->version_number } @$versions
        ) {
            # Shift only for versions after target
            next if $version->version_number <= $target_version;

            # When going down, we must not shift blocks that have not
            # been shifted up for this version.
            next if $version->version_number > $block->{version_number};

            # No need to shift if change occurs after block
            next if $version->change_position >=
                $block->{position} + $block->{size};

            # If change does not overlap, just move block
            if ( $version->change_position + $version->change_new_size <=
                    $block->{position} ) {

                $block->{position} -= ( $version->change_new_size -
                    $version->change_old_size );
            }
            # Else block engulfs all overlapping changes
            # No locks should end here. Only changes.
            else {
                my $begin_change = $block->{position} -
                    $version->change_position;

                if ( $begin_change > 0 ) {
                    $block->{position} -= $begin_change;
                    $block->{size} += $begin_change;
                }

                my $end_change = $version->change_new_size -
                        $block->{size} - $begin_change;

                if ( $end_change > 0 ) {
                    $block->{size} += $end_change;
                }

                $block->{size} -= ( $version->change_new_size -
                    $version->change_old_size );
            }
        }
    }
}

sub _get_lock_info {
    my ( $self, $locks ) = @_;
    return [] if !$locks;
    
    my @user_ids = ();
    my %lookup = ();
    for ( @$locks ) {
        my $uid = $_->{original_lock}->user_id;
        next if $lookup{$uid}++;
        push @user_ids, $uid;
    }
    
    my $in = "('" . join("','", @user_ids) . "')";
    my $users = CTX->lookup_object('user')->fetch_group( {
        where => "user_id IN $in",
    } ) || [];
    
    my %user_byid = map { $_->id => $_ } @$users;
    
    my $info = [];
    for my $lock ( @$locks ) {
    
        my $user = $user_byid{ $lock->{original_lock}->user_id };
        my $message;
        if ( $user->id == CTX->request->auth_user_id ) {
            $message = $self->_msg( "Locked by you" );
        }
        else {
            my $name = $user ?
                $user->first_name . ' ' . $user->last_name : '?';
            $message = $self->_msg( "Locked by [_1]", $name );
        }

        push @$info, {
            message => $message,
            position => $lock->{position},
            size => $lock->{size},
            user_id => $user->id,
        }
    }
    
    return $info;
}

sub _filter_outgoing_links {
    my ( $self, $page, $sections ) = @_;

    # no need to use group in fetch since page ids are unique
    my $links = CTX->lookup_object('wiki_link')->fetch_group( {
        where => 'linking_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my %link_map = map { Dicole::Utils::Text->ensure_internal( $_->readable_linked_title ) => $_} @$links;

    my $can_create = $self->mchk_y(
        'OpenInteract2::Action::DicoleWiki', 'create'
    );

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;
            
            my @alinks = $node->look_down(
                '_tag' => 'a',
                'class' => qr/wikiLink/,
            );
            
            for my $alink ( @alinks ) {
                my $class = $alink->attr('class');
                
                my ( $readable_title, $anchor ) =
                    $self->_decode_title( $alink->attr('title') );
                my $link = $link_map{ $readable_title };
                
                if ( $link && $link->linked_page_id ) {
                    $alink->attr( 'class', $class . ' existingWikiLink' );
                    $alink->attr( 'href', Dicole::Utils::Text->ensure_internal(
                        Dicole::URL->create_from_parts(
                            action => 'wiki',
                            task => 'show',
                            target => $page->groups_id,
                            additional => [ $link->linked_page_title ],
                            anchor => $anchor,
                        )
                    ) );
                }
                elsif ( $can_create ) {
                    $alink->attr( 'class', $class . ' missingWikiLink' );
                    $alink->attr( 'href', Dicole::Utils::Text->ensure_internal(
                        Dicole::URL->create_from_parts(
                            action => 'wiki',
                            task => 'create',
                            additional => [],
                            target => $page->groups_id,
                            params => {
                                new_title => Dicole::Utils::Text->ensure_utf8( $readable_title ),
                            },
                        )
                    ) );
                }
                else {
                    $alink->tag( 'span' );
                    $alink->attr( 'href', undef );
                    $alink->attr( 'title', undef );
                    $alink->attr( 'class', undef );
                }
                
                $rebuild_html++;
            }
        }
        
        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _filter_outgoing_annos {
    my ( $self, $page, $sections, $wiki_settings ) = @_;

    my $annos = CTX->lookup_object('wiki_annotation')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my %annos_by_id = map { $_->id => $_ } @$annos;

    my $annos_visible = $self->_page_annotations_visible( $page, $wiki_settings );

    my %hide_annos = ();

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;

            my @annospans = $node->look_down(
                '_tag' => 'span',
                'class' => qr/wiki_anno_end/,
            );
            for my $annospan ( @annospans ) {
                my $class = $annospan->attr('class');
                my ( $anno_id ) = $class =~ /wiki_anno_(\d+)/;
                next unless $anno_id;
                my $anno = $annos_by_id{ $anno_id };

                if ( ! $anno || ! $annos_visible ) {
                    $hide_annos{ $anno_id }++;
                    next;
                }

                my $postinsert_target = $annospan;
                if ( $annospan->is_inside('a') ) {
                    my $candidate = $postinsert_target;
                    while ( $candidate ) {
                        $postinsert_target = $candidate if $candidate->tag eq 'a';
                        $candidate = $candidate->parent;
                    }
                }

                my $params = {
                    data_url => Dicole::URL->create_from_parts(
                            action => 'wiki_comments',
                            task => 'get_annotation_comments',
                            target => $anno->group_id,
                            additional => [ $anno->id ],
                    ),
                    add_url => Dicole::URL->create_from_parts(
                            action => 'wiki_comments',
                            task => 'add_annotation_comment',
                            target => $anno->group_id,
                            additional => [ $anno->id ],
                    ),
                };

                my $comment_button = HTML::Element->new( 'a' );
                $comment_button->attr( 'href' , '#' );
                $comment_button->attr( 'class' , 'js_wiki_anno_comment_link wiki_anno_comment_link alpha_png' );
                $comment_button->attr( 'id' , 'wiki_anno_comment_link_' . $anno->id );
                $comment_button->attr( 'title', Dicole::Utils::JSON->encode( $params ) );
                $comment_button->push_content( $anno->comment_count );

                $postinsert_target->postinsert( $comment_button );

                $rebuild_html++;
            }
        }

        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;
            for my $id ( keys %hide_annos ) {
                my @annospans = $node->look_down(
                    '_tag' => 'span',
                    'class' => qr/wiki_anno_$id(\s|$)/,
                );
                for my $annospan ( @annospans ) {
                    my $cls = $annospan->attr( 'class' );
                    $cls =~ s/wiki_anno(_[^\s]+)?\s*//g;
                    $annospan->attr( 'class', $cls );
                    $rebuild_html++;
                }
            }
        }
        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _filter_outgoing_annos_to_anchor_list {
    my ( $self, $page, $sections ) = @_;

    my $annos = CTX->lookup_object('wiki_annotation')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my %annos_by_id = map { $_->id => $_ } @$annos;

    my $count = 1;
    my $list = [];

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;

            my @annospans = $node->look_down(
                '_tag' => 'span',
                'class' => qr/wiki_anno_end/,
            );
            for my $annospan ( @annospans ) {
                my $class = $annospan->attr('class');
                my ( $anno_id ) = $class =~ /wiki_anno_(\d+)/;
                my $anno = $annos_by_id{ $anno_id };
                next unless $anno;

                my $postinsert_target = $annospan;
                if ( $annospan->is_inside('a') ) {
                    my $candidate = $postinsert_target;
                    while ( $candidate ) {
                        $postinsert_target = $candidate if $candidate->tag eq 'a';
                        $candidate = $candidate->parent;
                    }
                }

                my $comment_button = HTML::Element->new( 'a' );
                $comment_button->attr( 'href' , '#wiki_anno_open_comments_' . $count );
                $comment_button->attr( 'class' , 'wiki_anno_comment_link alpha_png' );
                $comment_button->attr( 'title', '# ' . $count );
                $comment_button->push_content( '# ' . $count );

                $postinsert_target->postinsert( $comment_button );

                push @$list, {
                    id => $count,
                    anno => $anno,
                };

                $count++;

                $rebuild_html++;
            }
        }
        
        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }

    return $list;
}

sub _filter_outgoing_images {
    my ( $self, $page, $sections ) = @_;

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;

            my @imgs = $node->look_down(
                '_tag' => 'img',
                'class' => qr/dicole_embedded_html/,
            );
            for my $img ( @imgs ) {
                $rebuild_html = 1;
                my $html = $img->attr('alt');
                $html =~ s/mce_t(href|src)/$1/g;
                $html = Dicole::Utils::HTML->strip_scripts( $html );
                $img->replace_with( $self->_elements_from_content( $html ) );
            }
        }

        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _process_comments_info_for_annos {
    my ( $self, $anno, $comments_info ) = @_;

    my $supports = CTX->lookup_object('wiki_support')->fetch_group( {
        where => 'annotation_id = ?',
        value => [ $anno->id ],
    }) || [];

    my %supports_by_post = ();
    my %supporters_by_post = ();

    my @uids = ();

    for my $s ( @$supports ) {
        $supports_by_post{ $s->comment_id } ||= [];
        push @{ $supports_by_post{ $s->comment_id } }, $s;

        $supporters_by_post{ $s->comment_id } ||= {};
        $supporters_by_post{ $s->comment_id }->{ $s->creator_id || $s->anonymous_sid || '?' } = 1;

        push @uids, $s->creator_id if $s->creator_id;
    }

    my %user_names_by_id = map { $_ => Dicole::Utils::User->name( $_ ) } @uids;
    my $user_id_or_sid = CTX->request->auth_user_id || '-';

    for my $info ( @$comments_info ) {

        if ( $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_annotations' ) || ( $info->{user_id} && $user_id_or_sid == $info->{user_id} ) ) {
            $info->{remove_url} = $self->derive_url( task => 'delete_annotation_comment', additional => [ $anno->id, $info->{post_id} ] );
        }
        if ( $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'annotate' ) ) {
            if ( $info->{post_id} && $supporters_by_post{ $info->{post_id} }->{ $user_id_or_sid } ) {
                $info->{unsupport_url} = $self->derive_url( task => 'unsupport_annotation_comment', additional => [ $anno->id, $info->{post_id} ] );
            }
            else {
                $info->{support_url} = $self->derive_url( task => 'support_annotation_comment', additional => [ $anno->id, $info->{post_id} ] ) unless $info->{user_id} && $info->{user_id} == $user_id_or_sid;
            }
        }
        if ( $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ) && ! $info->{published} ) {
            $info->{publish_url} = $self->derive_url( task => 'publish_annotation_comment', additional => [ $anno->id, $info->{post_id} ] );
        }
        $info->{support_count} = scalar( @{ $supports_by_post{ $info->{post_id} } || [] } ) || '0';

        my @users = ();
        my %users_added = ();
        for my $sup ( @{ $supports_by_post{ $info->{post_id} } } ) {
            next if ! $sup->creator_id || $users_added{ $sup->creator_id };
            $users_added{ $sup->creator_id }++;
            next unless $user_names_by_id{ $sup->creator_id };
            push @users, $user_names_by_id{ $sup->creator_id };
        }
        $info->{support_string} = join ", ", @users;
    }

    return [ reverse @$comments_info ];
}

sub _shift_header_levels {
    my ( $self, $sections, $header_base ) = @_;
    
    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next if ! ref $node;
            if ( $node->tag =~ qr/^h(\d+)$/ ) {
                my $level = $1 + $header_base;
                $node->tag( "h$level" );
                $rebuild_html++;
            }
        }
        
        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _get_shifted_sections_from_raw_title {
    my ( $self, $raw_parts, $header_base ) = @_;

    my ( $raw_title, $anchor ) = $self->_decode_title( $raw_parts );
    my $readable_title = $self->_raw_title_to_readable_form( $raw_title );
    my $title = $self->_title_to_internal_form( $readable_title );
    my $page = $self->_fetch_page( $title );

    die "Could not find requested page" if ! $page;

    my $sections = $self->_current_sections_for_page( $page );
    $self->_filter_outgoing_links( $page, $sections );

    if ( $header_base && $header_base =~ /^\d+$/ ) {
        $self->_shift_header_levels( $sections, $header_base );
    }

    return $sections;
}

sub _encode_title {
    my ( $self, $title, $anchor ) = @_;

    my $t = $title;
    $t =~ s/ /  /g if $t;

    my $a = $anchor;
    $a =~ s/ /  /g if $a;

    return ($t && $a ) ? $t . '   :   ' . $a : $t;
}

sub _decode_title {
    my ( $self, $raw ) = @_;

    my ( $title, $anchor ) = $raw =~ /^((?:[^ ]|  )+)   :   ((?:[^ ]|  )+)$/;
    if ( $title && $anchor ) {
        $title =~ s/  / /g;
        $anchor =~ s/  / /g;
    }
    else {
        $title = $raw;
        # conditional to try to preserve backwards compatibility
        # in cases where old title had adjacent spaces
        $title =~ s/  / /g if $title =~ /^(?:[^ ]|  )+$/;
    }

    # Stupid MYSQL doesn't store trailing spaces before 5.0.3
    $title =~ s/ *$//;

    return ( $title, $anchor );
}

sub _add_anchors_to_headers {
    my ( $self, $page, $sections ) = @_;

    my $used_ids = {};

    for my $section (@$sections) {
        my $rebuild_html = 0;
        for my $node ( @{ $section->{nodes} } ) {
            next unless ref $node && $node->tag =~ /^h(\d+)$/;

            my $name = $self->_get_anchor_from_node( $node, $used_ids );

            my $anchor = HTML::Element->new( 'a',
                name => $name,
                class => 'wiki_header_anchor',
            );

            $node->unshift_content( $anchor );

            $rebuild_html++;
        }
        
        if ( $rebuild_html ) {
            $section->{html} = $self->_nodes_to_html( $section->{nodes} );
        }
    }
}

sub _gather_toc_elements {
    my ( $self, $sections ) = @_;

    my $level_count = {};
    my $used_ids = {};
    my $base_level = 0;
    my $lowest_level = undef;

    my $last_level = $base_level;
    my @elements = ();

    for my $section (@$sections) {
        for my $node ( @{ $section->{nodes} } ) {
            next unless ref $node && $node->tag =~ /^h(\d+)$/;
            my $level = $1 + $base_level;
            $lowest_level = $level unless defined $lowest_level;

            # Continue from the count of the last lowest header level
            # if this is the new lowest level
            # This ensures a sane numbering even if document starts
            # with h3 but contains h1 after that.

            if ( $level < $lowest_level ) {
                $level_count->{ $level } = $level_count->{ $lowest_level };
                $lowest_level = $level;
            }

            if ( $level != $last_level ) {
                for ( keys %$level_count ) {
                    delete $level_count->{ $_ } if $_ > $level;
                }
                $level_count->{ $level } = 0 if $level > $last_level;
            }

            $level_count->{ $level }++;
            $last_level = $level;

            my ( $name, $text ) = $self->_get_anchor_from_node(
                $node, $used_ids
            );

            my @numbers = ();
            for ( sort {$a <=> $b} keys %$level_count ) {
                push @numbers, $level_count->{ $_ } if $_ <= $level;
            }

            push @elements, {
                anchor => $name,
                text => $text,
                numbers => \@numbers,
            };
        }
    }

    return \@elements;
}

sub _get_anchor_from_node {
    my ( $self, $node, $used_ids ) = @_;

    my $text = Dicole::Utils::HTML->html_to_text(
        Dicole::Utils::HTML->tree_nodes_as_xml( $node )
    );
    $text =~ s/\n/ /gs;
    $text =~ s/\s*$//gs;

    my $cleantext = Dicole::Utils::Text->utf8_to_url_readable( $text );
    my $anchor = $cleantext;
    my $count = 1;
    while ( $used_ids->{ $anchor } ) {
        $count++;
        $anchor = $cleantext . ' (' . $count . ')';
    }
    $used_ids->{ $anchor }++;

    return wantarray ? ( $anchor, $text ) : $anchor;
}

sub _shorten_filename {
    my($self, $filename, $max_length) = @_;
    
    return $filename if length($filename) <= $max_length;
    
    my $index = rindex($filename, '.');
    if($index > -1)
    {
        my $name = substr($filename, 0, $index);
        my $extension = substr($filename, $index + 1);
        return substr($name, 0, $max_length) . '....' . $extension;
    }
}

sub _get_attachments_listing_widget {
    my ( $self, $page, $attachments ) = @_;

    my $listing = Dicole::Widget::Listing->new;
    
    my $uid = CTX->request->auth_user_id;
    for my $a ( @$attachments ) {
        my $right_to_remove = ( $uid && $uid == $a->owner_id ) ||
            $self->schk_y( 'OpenInteract2::Action::DicoleWiki::remove_attachments' );

        $listing->add_row(
            {
                content => Dicole::Widget::Hyperlink->new(
                    content => $self->_shorten_filename($a->filename, 10),
                    'link' => $self->derive_url(
                        action => 'wiki',
                        task => 'attachment',
                        additional => [ $page->id, $a->id, $a->filename ],
                    ),
                )
            },
            {
                content => ( $right_to_remove ? Dicole::Widget::Hyperlink->new(
                    content => Dicole::Widget::Text->new(
                        text => $self->_msg( 'Remove' ),
                        class => 'wiki_attachment_remove_text'
                    ),
                    'link' => $self->derive_url(
                        action => 'wiki_json2',
                        task => 'attachment_remove',
                        additional => [ $page->id, $a->id ],
                    ),
                    class => 'wiki_attachment_remove_link',
                ) : () )
            },
        );
    }

    return $listing;
}

sub _attachment_list_html {
    my ( $self, $object, $attachments ) = @_;

    return CTX->lookup_action('attachment')->execute( get_attachment_list_html_for_object => {
        action => $self, action_name => 'wiki',
        attachments => $attachments, object => $object,
    } );
}

sub _attachment_list_data {
    my ( $self, $object, $attachments ) = @_;

    return CTX->lookup_action('attachment')->execute( get_attachment_list_data_for_object => {
        action => $self, action_name => 'wiki', delete_action_name => 'wiki_json',
        attachments => $attachments, object => $object,
        delete_all_right => 1,
    } );
}

sub _page_for_version {
    my ( $self, $version ) = @_;

    return unless $version->page_id;

    my $page = eval { CTX->lookup_object('wiki_page')->fetch( $version->page_id ) };

    return $page;
}

sub _gather_data_for_pages {
    my ( $self, $pages, $domain_id ) = @_;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my @datas = ();

    for my $page ( @$pages ) {
        my $data = {
            title => $page->title,
            comment_count => CTX->lookup_action('comments_api')->e( get_comment_count => {
                object => $page,
                user_id => 0,
                group_id => $page->groups_id,
                domain_id => $domain_id,
            } ),
            readable_title => $page->readable_title,
            last_modified_time => $page->last_modified_time,
            page => $page,
            show_url => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $page->groups_id,
                additional => [ $page->title ],
                ( $domain_id ) ? ( domain_id => $domain_id ) : ()
            ),
            show_comments_url => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $page->groups_id,
                additional => [ $page->title ],
                anchor => 'comments',
                ( $domain_id ) ? ( domain_id => $domain_id ) : ()
            ),
        };

        push @datas, $data;
    }

    return \@datas;
}

sub _filtered_page_content {
    my ( $self, $page, $link_generator, $domain_id ) = @_;

    my $sections = $self->_current_sections_for_page( $page );
    my $content = $self->_sections_to_html( $sections );

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_action('tinymce_api')->e( filter_outgoing_html => {
        group_id => $page->groups_id,
        domain_id => $domain_id,
        html => $content,
        wiki_link_generator => $link_generator,
    } );

}

sub _get_latest_editors_data {
    my ( $self, $page, $limit ) = @_;

    my $versions = $self->_fetch_versions_for_page_since( $page, 0 );

    my %uids = ();
    my @uids = ();

    for my $version ( @$versions ) {
        next if $limit && scalar( @uids ) >= $limit;
        next unless $version->creator_id;
        next if $uids{ $version->creator_id }++;
        push @uids, { user_id => $version->creator_id, timestamp => $version->creation_time };
    }

    return \@uids;
}

sub _get_latest_editors {
    my ( $self, $page, $limit ) = @_;

    my $editors_data = $self->_get_latest_editors_data( $page, $limit );

    return [ map { $_->{user_id} } @$editors_data ];
}

sub _store_change_event {
    my $self = shift @_;
    return $self->_store_some_event( 'changed', @_ );
}

sub _store_delete_event {
    my $self = shift @_;
    return $self->_store_some_event( 'deleted', @_ );
}

sub _store_some_event {
    my ( $self, $type, $version, $domain_id, $user_id, $previous_tags ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    eval {
        my $a = CTX->lookup_action('event_source_api');
        eval {
            my $page = $self->_page_for_version( $version );

            return unless $page;

            my $secure_tree = Dicole::Security->serialize_secure(
                'OpenInteract2::Action::DicoleWiki::read', {
                    group_id => $page->groups_id,
                    domain_id => $domain_id,
                }
            );

            my $tags = CTX->lookup_action('tags_api')->e( get_tags => {
                object => $page,
                group_id => $page->groups_id,
                user_id => 0,
                domain_id => $domain_id,
            } );

            my $dd = {
                object_id => $page->id,
                object_tags => $tags,
            };

            # interested? commenters && editors

            my $event_type = 'wiki_page_deleted';
            my $event_time = time();
            if ( $type =~ /change/ ) {
                $event_type = 'wiki_page_' . CHANGE_LABELS->{ $version->change_type };
                $event_time = $version->creation_time;
            }

            $a->e( add_event => {
                event_type => $event_type,
                author => $user_id || $version->creator_id,
                target_user => 0,
                target_group => $page->groups_id,
                target_domain => $domain_id,
                timestamp => $event_time,
                coordinates => [],
                classes => [ 'wiki_page' ],
                interested => [],
                tags => $tags,
                topics => [ 'wiki_page::' . $page->id ],
                secure_tree => $secure_tree,
                data => $dd,
            } )
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error( $@ );
        }
    };
}

sub _update_page_indexes {
    my ( $self, $page, $html ) = @_;

    $html ||= $self->_fetch_current_html_for_page( $page );

    $self->_update_wiki_links( $page, $html );
    $self->_update_search_table( $page, $html );
}

sub _update_wiki_links {
    my ($self, $page, $html) = @_;

    $html ||= $self->_fetch_current_html_for_page( $page );

    my $pagelinks = $self->_parse_wiki_links( $html );

    my $link_object = CTX->lookup_object('wiki_link');

    # no need to use group in fetch since page ids are unique
    my $old_links = $link_object->fetch_group( {
        where => 'linking_page_id = ?',
        value => [ $page->id ],
    } ) || [];

    my %old_link_map = map { $_->readable_linked_title => $_ } @$old_links;

    my %found_links = ();
    my @links_without_id = ();
    my @new_pagelinks = ();

    # sort links so that we can handle new and
    # existing but idless links differently
    for my $pagelink (@$pagelinks) {
        if ( my $link = $old_link_map{ $pagelink->{readable_title} } ) {
            unless ( $link->readable_linking_title eq $page->readable_title ) {
                $link->readable_linking_title( $page->readable_title );
                $link->save;
            }
            if ( $link->linked_page_id == 0 ) {
                push @links_without_id, $link;
            }
            $found_links{ $link->id }++;
        }
        else {
            push @new_pagelinks, $pagelink;
        }
    }

    for (@$old_links) {
        $_->remove() if ! $found_links{ $_->id };
    }

    # Fetch pages corresponding new links and also links which
    # previously had no page attached - just to see if it might
    # have magically appeared without the link being updated
    # Basically this should not happen but it is so cheap to check
    # here that we will do it ;)

    my @new_titles = map { $_->{presumed_title} } @new_pagelinks;
    my @titles_without_id = map { $_->linked_page_title } @links_without_id;

    my $linked_pages = CTX->lookup_object('wiki_page')->fetch_group( {
            where => 'groups_id = ? AND ' .
                Dicole::Utils::SQL->column_in_strings(
                    'title', [ @new_titles, @titles_without_id ]
                ),
            value => [ $page->groups_id ],
        } ) || [];

    my %page_map = map { lc $_->title => $_ } @$linked_pages;

    my $redirs = CTX->lookup_object('wiki_redirection')->fetch_group( {
            where => 'group_id = ? AND ' .
                Dicole::Utils::SQL->column_in_strings(
                    'title', [ @new_titles, @titles_without_id ]
                ),
            value => [ $page->groups_id ],
            order => 'date asc',
        } ) || [];

    my %redir_map = map { lc $_->title => $_ } @$redirs;

    for my $pagelink ( @new_pagelinks ) {
        my $presumed_title = lc $pagelink->{presumed_title};

        my $id = 0;
        my $linked_title = $presumed_title;

        if ( my $linked_page = $page_map{ $presumed_title } ) {
            $id = $linked_page->id;
            $linked_title = $linked_page->title;
        }
        elsif ( my $redir = $redir_map{ $presumed_title } ) {
            $id = $redir->page_id,
            $linked_title = $redir->title;
        }

        $link_object->new( {
            groups_id => $page->groups_id,
            linking_page_id => $page->id,
            linking_page_title => $page->title,
            readable_linking_title => $page->readable_title,
            linked_page_id => $id,
            linked_page_title => $linked_title,
            readable_linked_title => $pagelink->{readable_title},
        } )->save;
    }

    for my $link ( @links_without_id ) {
        if ( my $linked_page = $page_map{ lc $link->linked_page_title } ) {
            $link->linked_page_id( $linked_page->id );
            $link->linked_page_title( $linked_page->title );
            $link->save;
        }
        elsif ( my $redir =$redir_map{ lc $link->linked_page_title } ) {
            $link->linked_page_id( $redir->page_id );
            $link->linked_page_title( $redir->title );
            $link->save;
        }
    }
}

sub _fetch_current_html_for_page {
    my ($self, $page ) = @_;

    return '' unless $page;

    my $content = $page->last_content_id_wiki_content;
    return $content->content;
}

sub _update_search_table {
    my ($self, $page, $html) = @_;

    $html ||= $self->_fetch_current_html_for_page( $page );

    my $search = CTX->lookup_object('wiki_search')->fetch_group( {
        where => 'page_id = ?',
        value => [ $page->id ],
        limit => 1,
    } ) || [];

    $search = $search->[0];
    unless ( $search ) {
        $search = CTX->lookup_object('wiki_search')->new( {
            page_id => $page->id
        } );
    }

    my $text = Dicole::Utils::HTML->html_to_text( $html );
    $text = $page->readable_title . "\n\n" . $text;

    $search->text( $text );
    $search->save;
}

sub _parse_wiki_links {
    my ($self, $html) = @_;

    my $tree = $self->_tree_from_content( $html );
    my @wiki_links = $tree->look_down(
        '_tag' => 'a',
        'class' => qr/wikiLink/,
    );

    my @links = ();
    my %link_check = ();

    for my $alink (@wiki_links) {
        my $raw_title = Dicole::Utils::Text->ensure_internal( $alink->attr('title') );
        next if ! $raw_title;
        my ( $readable_title ) = $self->_decode_title( $raw_title );
        next if $link_check{ $readable_title };

        my $title = $self->_title_to_internal_form( $readable_title );

        push @links, {
            presumed_title => Dicole::Utils::Text->ensure_utf8( $title ),
            readable_title => Dicole::Utils::Text->ensure_utf8( $readable_title ),
        };

        $link_check{ $readable_title }++;
    }

    return \@links;
}

sub _create_new_sections_from_change {
    my ( $self, $sections, $target_id, $target_type, $content ) = @_;

    my ( $before, $old_target, $after, $new_target ) =
        $self->_get_change_sections(
            $sections, $target_id,
            $target_type, $content
        );

    # pass through parse functions once more
    # this is done to ensure that html and sections are in sync
    # and no elements are truncated or created when parts are
    # joined
    my $html = $self->_sections_to_html(
        [ @$before, @$new_target, @$after ]
    );

    my $new_sections = $self->_parse_sections( $html );

    my $position = $self->_get_length_for_sections( $before );
    my $old = $self->_get_length_for_sections( $old_target );
    my $new = $self->_get_length_for_sections( $new_sections )
        - $self->_get_length_for_sections( $after ) - $position;

    return (
        $new_sections,
        {
            position => $position,
            old => $old,
            new => $new
        }
    );
}

sub _create_new_sections_from_merge {
    my ( $self, $last_sections, $target_id, $target_type,
         $content, $page, $base_version_number ) = @_;

    my $base_version = $self->_fetch_version_for_page(
        $page, $base_version_number
    ) || die;
    my $base_content = $base_version->wiki_content || die;
    my $base_sections = $self->_parse_sections(
        $base_content->content
    );

    my ( $before, $old_target, $after, $new_target ) =
        $self->_get_change_sections(
            $base_sections, $target_id,
            $target_type, $content
        );

    my ( $before_size, $old_target_size, $after_size ) =
        $self->_translate_positions_to_latest_version(
            $page, $base_version_number,
            $before, $old_target, $after
        );

    my @last_nodes = ();
    push @last_nodes, @{ $_->{nodes} } for @$last_sections;

    my @inserted_nodes = ();
    push @inserted_nodes, @{ $_->{nodes} } for @$new_target;

    splice @last_nodes, $before_size, $old_target_size, @inserted_nodes;

    my $html = $self->_nodes_to_html( \@last_nodes );
    my $new_sections = $self->_parse_sections( $html );

    return (
        $new_sections,
        {
            position => $before_size,
            old => $old_target_size,
            new => $self->_get_length_for_sections( $new_sections ) -
                $before_size - $after_size,
        }
    );

}

sub _translate_positions_to_latest_version {
    my ( $self, $page, $base_version_number,
         $before, $target, $after ) = @_;

    my $before_size = $self->_get_length_for_sections( $before );
    my $target_size = $self->_get_length_for_sections( $target );
    my $after_size = $self->_get_length_for_sections( $after );

    my $versions = $self->_fetch_versions_for_page_since(
        $page, $base_version_number + 1
    );

    for my $version (
            sort { $a->version_number <=> $b->version_number } @$versions
        ) {

        if ( $version->change_position >= $before_size + $target_size ) {
            $after_size +=
                $version->change_new_size - $version->change_old_size;
        }
        elsif ( $version->change_position +
                $version->change_old_size <= $before_size ) {
            $before_size +=
                $version->change_new_size - $version->change_old_size;
        }
        else {
            # TODO: what should be done here?
        }
    }

    return ( $before_size, $target_size, $after_size );
}

sub _get_change_sections {
    my ( $self, $sections, $target_id, $target_type, $content ) = @_;

    my ( $before, $old_target, $after ) =
        $self->_split_sections_for_target(
            $sections, $target_id, $target_type
        );

    my $new_target = $self->_parse_sections_part( $content );

    # We want to ensure this block does not append the previous
    # block's last node even if new content begins with text.
    # So if the first node is text, we prepend a <br />
    # However This does not neet to be done if target is the
    # first block (no stuff in $before)

    if ( scalar(@$new_target) && scalar(@$before) ) {
        if ( ! ref($new_target->[0]->{nodes}->[0]) ) {
            $new_target = $self->_parse_sections_part(
                '<br />' . $content
            );
        }
    }

    return ( $before, $old_target, $after, $new_target );
}

sub _count_anno_comments {
    my ( $self, $anno, $comments_info ) = @_;

    $comments_info ||= CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
        	$self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
        	$self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    my $count = 0;
    for my $comment_info ( @$comments_info ) {
        $count++ if $comment_info->{published} && ! $comment_info->{removed};
    }

    return $count;
}

sub _commenting_requires_approval {
    my ( $self ) = @_;

    return Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'commenting_requires_approval',
        group_id => CTX->controller->initial_action->param('target_group_id'),
    ) ? 1 : 0;
}

sub _page_annotations_visible {
    my ( $self, $page, $wiki_settings ) = @_;

    $wiki_settings ||= $self->_fetch_wiki_settings_for_page( $page );

    if ( $wiki_settings->setting( 'show_annotations_by_default' ) ) {
        return $page->hide_annotations ? 0 : 1;
    }
    else {
        return $page->show_annotations ? 1 : 0;
    }
}

sub _fetch_wiki_settings_for_page {
    my ( $self, $page ) = @_;

    return Dicole::Settings->new_fetched_from_params(
        tool => 'wiki',
        group_id => $page->groups_id,
        user_id => 0,
    );
}

1;
