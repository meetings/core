package OpenInteract2::Action::DicoleWikiJson;

use strict;
use base qw( OpenInteract2::Action::DicoleWikiCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use List::Util qw( reduce min );
use Dicole::Utils::HTML;

sub object_info {
    my ( $self ) = @_;

    my $page = CTX->lookup_object('wiki_page')->fetch(
        $self->param('page_id')
    );

    my $group_id = $self->param('target_group_id');

    die "Could not find requested page" if ! $page ||
        $page->groups_id != $group_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $info = $self->_object_info( $page, CTX->request->auth_user_id, $domain_id );

    return { result => $info };
}

sub page_autocomplete_data {
    my ( $self ) = @_;

    my $seed = CTX->request->param('seed') || '';

    return [] if Dicole::Utils::Text->charcount( $seed ) < 2;

    my $gid = $self->param('target_group_id');
    my $limit = CTX->request->param('limit') || 10;
    my $exclude = CTX->request->param('exclude') || '';
    my @exclude = split /\s*,\s*/, $exclude;

    my $like = '%' . $seed . '%';

    my $pages = CTX->lookup_object('wiki_page')->fetch_group({
        where => 'groups_id = ? AND readable_title LIKE ? AND ' .
            Dicole::Utils::SQL->column_not_in( page_id => \@exclude ),
        value => [ $gid, $like ],
        order => 'last_modified_time desc',
        limit => $limit,
    });

    my $data = [ map { {
        name => $_->readable_title,
        value => $_->readable_title,
    } } @$pages ];

    return { results => $data };
}

sub start_editing {
    my ( $self ) = @_;

    my ( $return, $page, $sections, $current_block, $target_id, $target_type ) = $self->_fetch_unlocked_editable_from_params;

    return $return if $return;

    my ( $before, $target, $after ) = $self->_split_sections_for_target(
        $sections, $target_id, $target_type
    );

    my $html = $self->_sections_to_html( $target );
    $html = "<p></p>" if $html =~ /^\s*$/;

    my $lock = $self->_create_lock( $page, $current_block, $html );

    return {
        lock_granted => 1,
        lock_id => $lock->id,
        content => $html,
    };
}

sub start_annotation {
    my ( $self ) = @_;

    my ( $return, $page, $sections, $current_block, $target_id, $target_type ) = $self->_fetch_unlocked_editable_from_params( 'content' );

    return $return if $return;

    my ( $before, $target, $after ) = $self->_split_sections_for_target(
        $sections, $target_id, $target_type
    );

    $self->_add_annotation_to_section(
        CTX->request->param('before'),
        CTX->request->param('text'),
        CTX->request->param('after'),
        $target->[0],
    );

    $self->_filter_outgoing_links( $page, $target );
    $self->_filter_outgoing_images( $page, $target );
    my $html = $self->_sections_to_html( $target );

    my $lock = $self->_create_lock( $page, $current_block, $html );

    return {
        lock_granted => 1,
        lock_id => $lock->id,
        content => $html,
    };
}

sub save_annotation {
    my ( $self ) = @_;

    unless ( $self->_remove_lock ) {
        return { error => 'no lock' };
    }

    my $base_version = CTX->request->param('base_version_number');
    my $target_id = CTX->request->param('edit_target_id');
    my $target_type = 'content';
    my $page = CTX->lookup_object('wiki_page')->fetch(
        CTX->request->param('page_id')
    );
    my $version = $self->_fetch_version_for_page(
        $page, $base_version
    );
    my $sections = $self->_parse_sections_for_version( $version );
    my ( $before, $target, $after ) = $self->_split_sections_for_target(
        $sections, $target_id, $target_type
    );

    my $anno = CTX->lookup_object('wiki_annotation')->new;
    $anno->page_id( $page->id );
    $anno->group_id( $page->groups_id );
    $anno->domain_id( Dicole::Utils::Domain->guess_current_id );
    $anno->creator_id( CTX->request->auth_user_id );
    $anno->creation_date( time() );
    $anno->comment_count( 1 );
    $anno->save;

    $self->_add_annotation_to_section(
        CTX->request->param('before'),
        CTX->request->param('text'),
        CTX->request->param('after'),
        $target->[0],
        $anno->id,
    );

    my $edit_content = $self->_sections_to_html( $target );

    my ( $new_sections, $change_info );

    if ($base_version == $page->last_version_number) {
        ( $new_sections, $change_info ) =
            $self->_create_new_sections_from_change(
                $sections, $target_id,
                $target_type, $edit_content
            );
    }
    else {
        ( $new_sections, $change_info ) =
            $self->_create_new_sections_from_merge(
                $sections, $target_id,
                $target_type, $edit_content,
                $page, $base_version
            );
    }

    my $html = $self->_sections_to_html( $new_sections );

    $self->_create_new_version_for_page(
        $page, $html, $change_info, undef, $self->CHANGE_ANNO
    );

    my $comment_content = CTX->request->param('comment_content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    my $comments_info = CTX->lookup_action('comments_api')->e( add_comment_and_return_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        content => $comment_html,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
            $self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
            $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    $anno->comment_count( $self->_count_anno_comments( $anno, $comments_info ) );
    $anno->save;

#    $self->_update_page_indexes( $page, $html );

    return { ok => $self->derive_url(
        action => 'wiki',
        task => 'show',
        additional => [ $page->title ],
        params => { anchor => 'wiki_anno_comment_link_' . $anno->id },
    ) };
}

sub _create_lock {
    my ( $self, $page, $current_block, $html ) = @_;

    my $time = time();
    my $lock = CTX->lookup_object('wiki_lock')->new( {
        page_id => $page->id,
        user_id => CTX->request->auth_user_id,
        version_number => CTX->request->param('base_version_number'),
        lock_position => $current_block->{position},
        lock_size => $current_block->{size},
        lock_created => $time,
        lock_renewed => $time,
        autosave_content => $html,
    } );

    $lock->save;

    return $lock;
}

sub _fetch_unlocked_editable_from_params {
    my ( $self, $target_type ) = @_;

    my $base_version = CTX->request->param('base_version_number');
    my $target_id = CTX->request->param('edit_target_id');
    $target_type ||= CTX->request->param('edit_target_type');

    my $page = CTX->lookup_object('wiki_page')->fetch(
        CTX->request->param('page_id')
    );

    die "Could not find requested page" if ! $page ||
        $page->groups_id != $self->param('target_group_id');

    die "Page is locked" if $page->moderator_lock;

    my $version = $self->_fetch_version_for_page(
        $page, $base_version
    );

    die "Invalid base version" if ! $version;

    my $sections = $self->_parse_sections_for_version( $version );

    my $current_block = $self->_get_target_block_from_sections(
        $sections, $target_id, $target_type
    );

    my $versions = $self->_fetch_versions_for_page_since(
        $page, $base_version
    );

    my $shifted_changes = $self->_get_shifted_changes_for_version(
        $page, $base_version, $versions
    );

    my $shifted_locks = $self->_get_shifted_locks_for_version(
        $page, $base_version, $versions
    );

    my $conflict_version = $self->_get_conflicting_shifted_for_block(
        $current_block, $shifted_changes
    );

    my $conflict_lock = $self->_get_conflicting_shifted_for_block(
        $current_block, $shifted_locks
    );

    if ( $conflict_version ) {
        return ( {
            lock_granted => 0,
            locks => $self->_get_lock_info( $shifted_locks ),
            changes => $self->_get_change_info( $shifted_changes ),
        } );
    }

    if ( $conflict_lock ) {
        my $lock = $conflict_lock->{original_lock};
        if ( ! $lock || $lock->{user_id} != CTX->request->auth_user_id ) {
            return ( {
                lock_granted => 0,
                locks => $self->_get_lock_info( $shifted_locks ),
                changes => $self->_get_change_info( $shifted_changes ),
            } );
        }

        return ( {
            lock_granted => 1,
            lock_id => $lock->id,
            content => $lock->autosave_content,
        } );
    }

    return ( undef, $page, $sections, $current_block, $target_id, $target_type );
}

sub renew_lock {
    my ($self) = @_;

    my $lock_id = CTX->request->param('lock_id');

    if ( $lock_id ) {
        my $time = time;
        my $lock = CTX->lookup_object('wiki_lock')->fetch( $lock_id );
        if ($lock && $lock->user_id == CTX->request->auth_user_id ) {
            $lock->lock_renewed( $time );
            $lock->autosave_content( CTX->request->param('autosave_content') );
            $lock->save;
            return { renew_succesfull => 1 };
        }
    }
    return { renew_succesfull => 0 };
}

sub page_content {
    my ($self) = @_;
    my $raw_title = CTX->request->param('raw_title');
    my $header_base = CTX->request->param('header_base');

    my $sections = $self->_get_shifted_sections_from_raw_title(
        $raw_title, $header_base
    );

    my $html = $self->_sections_to_html( $sections );

    return { content => $html };
}

sub page_anchors {
    my ($self) = @_;
    $self->param( 'title', CTX->request->param('title') );
    my $title = $self->_parse_title;
    my $page = $self->_fetch_page( $title );

    die "Could not find requested page" if ! $page;

    my $sections = $self->_current_sections_for_page( $page );
    my $elements = $self->_gather_toc_elements( $sections );

    return { anchors => $elements };
}

sub _get_lock_conflict_for_version {
    my ( $self, $block, $page, $base_version, $versions ) = @_;

    my $shifted_locks = $self->_get_shifted_locks_for_version(
        $page, $base_version, $versions
    );

    my $conflict_lock = $self->_get_conflicting_shifted_for_block(
        $block, $shifted_locks
    );

    return $conflict_lock;
}

sub _get_change_conflict_for_version {
    my ( $self, $block, $page, $base_version, $versions ) = @_;

    my $shifted_changes = $self->_get_shifted_changes_for_version(
        $page, $base_version, $versions
    );

    my $conflict_change = $self->_get_conflicting_shifted_for_block(
        $block, $shifted_changes
    );

    return $conflict_change;
}

sub _get_shifted_changes_for_version {
    my ( $self, $page, $base_version, $versions ) = @_;

    my $version_blocks = $self->_fetch_version_blocks(
        $page, $base_version, $versions
    );

    $self->_shift_blocks_down_to_version(
        $version_blocks, $base_version, $versions
    );

    return $version_blocks;
}

sub _fetch_version_blocks {
    my ( $self, $page, $base_version, $versions ) = @_;

    $versions ||= $self->_fetch_versions_for_page_since(
        $page, $base_version
    );

    my $version_blocks = [];
    for my $version ( @$versions ) {
        next if $version->{version_number} == $base_version;
        push @$version_blocks, {
            original_version => $version,
            version_number => $version->version_number,
            position => $version->change_position,
            size => $version->change_new_size,
        };
    }

    return $version_blocks;
}

sub _get_change_info {
    my ( $self, $changes ) = @_;
    return [] if !$changes;
    
    my @user_ids = ();
    my %lookup = ();
    for ( @$changes ) {
        my $uid = $_->{original_version}->creator_id;
        next if $lookup{$uid}++;
        push @user_ids, $uid;
    }
    
    my $in = "('" . join("','", @user_ids) . "')";
    my $users = CTX->lookup_object('user')->fetch_group( {
        where => "user_id IN $in",
    } ) || [];
    
    my %user_byid = map { $_->id => $_ } @$users;
    
    my $info = [];
    for my $change ( @$changes ) {
    
        my $user = $user_byid{ $change->{original_version}->creator_id };
        my $name = $user ?
            $user->first_name . ' ' . $user->last_name : '?';
        
        push @$info, {
            message => $self->_msg( "Changed by [_1]", $name ),
            position => $change->{position},
            size => $change->{size},
            user_id => $user->id,
        }
    }
    
    return $info;
}

sub _get_conflicting_shifted_for_block {
    my ($self, $block, $shifted_objects ) = @_;

    for my $shifted ( @$shifted_objects ) {
        next if ! $shifted->{size} > 0;
        if ( $shifted->{position} < $block->{position} ) {
            return $shifted if
                $shifted->{position} + $shifted->{size} >
                $block->{position};
        }
        else {
            return $shifted if
                $block->{position} + $block->{size} >
                $shifted->{position};
        }
    }
    return undef;
}

sub _add_annotation_to_section {
    my ( $self, $before, $target, $after, $section, $id ) = @_;

    $before = Dicole::Utils::Text->ensure_internal( $before );
    $target = Dicole::Utils::Text->ensure_internal( $target );
    $after = Dicole::Utils::Text->ensure_internal( $after );

    my $html = $self->_sections_to_html( [ $section ] );
    my $tree = $self->_tree_from_content( $html );
    $tree->objectify_text;

    my $annotation = $self->_determine_annotation_match( $tree, $before, $target, $after );

    $self->_add_annotation_to_tree( $annotation, $tree, $id );

    $tree->deobjectify_text;
    $section->{nodes} = [ $tree->guts ];
    $section->{html} = $self->_nodes_to_html( $section->{nodes} );

#    get_logger(LOG_APP)->error( $section->{html} );
#    delete $annotation->{begin_node};
#    delete $annotation->{end_node};
#    get_logger( LOG_APP )->error( Data::Dumper::Dumper( [ $annotation ] ) );
}

sub _determine_annotation_match {
    my ( $self, $tree, $before, $target, $after ) = @_;
#   get_logger(LOG_APP)->error( Data::Dumper::Dumper( [ $before, $target, $after, $tree ] ));

    my $possible_matches = $self->_fetch_matching_text_pieces_for_tree( $tree, $target );   
#     for my $m ( @$possible_matches ) {
#         delete $m->{begin_node};
#         delete $m->{end_node};
#         get_logger(LOG_APP)->error( Data::Dumper::Dumper( $m ));
#     }

    my $annotation = undef;
    if ( scalar( @$possible_matches ) > 1 ) {
        my $bmatch = $self->_string_to_annotation_match( $before );
        my $amatch = $self->_string_to_annotation_match( $after );
#         get_logger(LOG_APP)->error( Data::Dumper::Dumper( [ $bmatch, $amatch ] ));
        my %before_lookup = map { $_->{before} => $_ } @$possible_matches;
        my %after_lookup = map { $_->{after} => $_ } @$possible_matches;

        $annotation = $before_lookup{ $bmatch } || $after_lookup{ $amatch };

        # Guess first which has after shorter than wanted
        unless ( $annotation ) {
            for my $m ( @$possible_matches ) {
                next if length( $m->{after} ) >= length( $amatch );
                $annotation = $m;
                last;
            }
        }
    }
    else {
        $annotation = pop @$possible_matches;
    }

    die unless $annotation;

    return $annotation;
}

sub _add_annotation_to_tree {
    my ( $self, $annotation, $tree, $id ) = @_;

    $id ||= 'new';

    my $bre = $self->_annotation_match_to_regex( $annotation->{begin_match}, 0 );
    my $ere = $self->_annotation_match_to_regex( $annotation->{end_match}, 1 );
    if ( $annotation->{end_node}->same_as( $annotation->{begin_node} ) ) {
        my ( $before_and_target, $after ) = $annotation->{begin_node}->attr('text') =~ /^($ere)(.*)$/;
        my ( $before, $target ) = $before_and_target =~ /^($bre)(.*)$/;

        my $anno_span = HTML::Element->new( 'span', class => 'wiki_anno wiki_anno_begin wiki_anno_end wiki_anno_' . $id );
        $anno_span->push_content( HTML::Element->new( '~text', text => $target ) );

        $annotation->{begin_node}->replace_with(
            HTML::Element->new( '~text', text => $before ),
            $anno_span,
            HTML::Element->new( '~text', text => $after ),
        );

        return 1;
    }

    # special case with end node
    my ( $atarget, $after ) = $annotation->{end_node}->attr('text') =~ /^($ere)(.*)$/;

    my $end_span = HTML::Element->new( 'span', class => 'wiki_anno wiki_anno_end wiki_anno_' . $id );
    $end_span->push_content( HTML::Element->new( '~text', text => $atarget ) );

    $annotation->{end_node}->replace_with(
        $end_span,
        HTML::Element->new( '~text', text => $after ),
    );

    my $current = $self->_move_to_left_from_element( $end_span );

    while ( ! $current->same_as( $annotation->{begin_node} ) ) {
        if ( ! $annotation->{begin_node}->is_inside( $current ) ) {
            my $anno_span = HTML::Element->new( 'span', class => 'wiki_anno wiki_anno_' . $id );
            $current->preinsert( $anno_span );
            $current->detach;
            $anno_span->push_content( $current );
    
            $current = $self->_move_to_left_from_element( $anno_span );
        }
        else {
            $current = $current->content_array_ref->[-1];
        }
    }

    # special case with begin node
    my ( $before, $btarget ) = $annotation->{begin_node}->attr('text') =~ /^($bre)(.*)$/;

    my $begin_span = HTML::Element->new( 'span', class => 'wiki_anno wiki_anno_begin wiki_anno_' . $id );
    $begin_span->push_content( HTML::Element->new( '~text', text => $btarget ) );

    $annotation->{begin_node}->replace_with(
        HTML::Element->new( '~text', text => $before ),
        $begin_span,
    );
}

sub _move_to_left_from_element {
    my ( $self, $element ) = @_;

    my $left = $element->left;
    return $left if $left;
    return $self->_move_to_left_from_element( $element->parent );
}

sub _string_to_annotation_match {
    my ( $self, $string ) = @_;

    $string =~ s/\s+//g;

    return $string;
}

sub _annotation_match_to_regex {
    my ( $self, $match, $skip_end_whitespace ) = @_;

    return '\\s*' unless $match;

    my @chars = split //, $match;
    my $re = '\\s*' . join( '\\s*', ( map { quotemeta($_) } @chars ) ) . ( $skip_end_whitespace ? '' : '\\s*' );
    return $re;
}

# collect an array of begin end pairs with data for before and after contents
# for all the sections of the html tree which contain the matched text
sub _fetch_matching_text_pieces_for_tree {
    my ( $self, $tree, $target ) = @_;

    my $match = $self->_string_to_annotation_match( $target );

    my $matches = [];
    $self->_fetch_matching_text_pieces_for_element( $tree, $match, '', $matches, [] );

    return $matches;
}

# NOTE: does recursion and modifies $matches and $open_matches in place
sub _fetch_matching_text_pieces_for_element {
    my ( $self, $element, $match, $before_element, $matches, $open_matches ) = @_;

    my @children = $element->content_list;
    for ( my $child_index = 0; $child_index < @children; $child_index++ ) {
        my $child = $children[ $child_index ];
        if ( $child->tag ne '~text' ) {
            $before_element = $self->_fetch_matching_text_pieces_for_element( $child, $match, $before_element, $matches, $open_matches );
        }
        else {
            my $text = Dicole::Utils::Text->ensure_internal( $child->attr('text') );
            $text =~ s/\s+//g;

            $_->{after} .= $text for @$matches;

            # check if any of the open matches end, continue or break here
            for my $om ( @$open_matches ) {
#                 my $o = {%$om};
#                 delete $o->{begin_node};
#                 get_logger(LOG_APP)->error( Data::Dumper::Dumper([ $o ]) );
                
                my $m = $om->{remaining_match};
                if ( index( $text, $m ) == 0 ) {
                    $om->{end_node} = $child;
                    $om->{end_match} = $m;
                    $om->{after} = substr( $text, length( $m ) );
                    $om->{closed} = 1;
                    delete $om->{remaining_match};
                    push @$matches, $om;
                }
                elsif ( index( $m, $text ) == 0 ) {
                    $om->{remaining_match} = substr( $m, length( $text ) );
                }
                else {
                    $om->{closed} = 1;
                }
            }

            for ( my $i = 0; $i < @$open_matches; $i++ ) {
                if ( $open_matches->[$i]->{closed} ) {
                    delete $open_matches->[$i]->{closed};
                    splice @$open_matches, $i, 1;
                    $i--;
                }
            }

            # all occurences where the whole match is contained in this element
            if ( length( $match ) <= length( $text ) ) {
                my $start = 0;
                while ( 1 ) {
                    my $i = index( $text, $match, $start );
                    last if $i == -1;

                    my $before_match = $i ? substr( $text, 0, $i ) : '';
                    my $after_match = substr( $text, ( length( $before_match ) + length( $match ) ) );
                    push @$matches, {
                        begin_node => $child,
                        begin_match => $before_match,
                        end_node => $child,
                        end_match => $before_match . $match,
                        before => $before_element . $before_match,
                        after => $after_match,
                    };

                    $start = $i + 1;
                }
            }

            # all the possible ways this element can open a new match here
            my @text = split //, $text;
            my @match = split //, $match;
#            get_logger(LOG_APP)->error( Data::Dumper::Dumper([ \@text, \@match ]) );

            my $candidate_indexes = [ 0 .. ( scalar(@match) - 1 ) ];
            my $string_so_far = '';
            for ( my $i = 0; $i < scalar( @text ); $i++ ) {
                my $text_index = scalar( @text ) - $i - 1;
                $string_so_far = $text[ $text_index ] . $string_so_far;

                my @new_candidate_indexes = ();

                for my $ci ( @$candidate_indexes ) {
#            get_logger(LOG_APP)->error( Data::Dumper::Dumper([ $i, $ci ]) );

                    next if $ci < $i;

                    if( $match[ $ci - $i ] eq $text[ $text_index ] ) {
                        if ( $ci == $i ) {
                            my $remaining_match = substr( $match, $i + 1 );

                            # full matches are already dealt with
                            next unless $remaining_match;

                            my $before_match = substr( $text, 0, $text_index );

                            push @$open_matches, {
                                begin_node => $child,
                                begin_match => $before_match,
                                remaining_match => $remaining_match,
                                before => $before_element . $before_match,
                                after => '',
                            };
                        }
                        else {
                            push @new_candidate_indexes, $ci;
                        }
                    }
                }
                last unless scalar( @new_candidate_indexes );
                $candidate_indexes = \@new_candidate_indexes;
            }

            $before_element .= $text;
        }
    }

    return $before_element;
}

sub _attachment_remove {
    my ( $self ) = @_;

    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');

    my $attachments = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $page,
    } );

    my %a_by_id = map { $_->id => $_ } @ {$attachments || [] };
    my $a = $a_by_id{ $self->param('attachment_id') };

    die "security error" unless $a;
    my $uid = CTX->request->auth_user_id;
    die "security error" unless ( $uid && $uid == $a->owner_id ) ||
        $self->schk_y( 'OpenInteract2::Action::DicoleWiki::remove_attachments' );

    CTX->lookup_action('attachment')->execute( remove => {
        attachment => $a,
    } );

    $attachments = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $page,
    } );

    return ( $page, $attachments );
}

sub attachment_remove {
    my ( $self ) = @_;

    my ( $page, $attachments ) = $self->_attachment_remove;
    my $widget = $self->_get_attachments_listing_widget( $page, $attachments );
    my $html = $widget->generate_content;

    return { messages_html => $html };
}

sub attachment_remove_data {
    my ( $self ) = @_;

    my ( $page, $attachments ) = $self->_attachment_remove;

    return $self->_attachment_list_data( $page, $attachments );
}

sub attachment_list {
     my ( $self ) = @_;

    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');
    my $attachments = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $page,
    } );

   return { content => $self->_attachment_list_html( $page, $attachments ) };
}

sub attachment_list_data {
     my ( $self ) = @_;

    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');
    my $attachments = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $page,
    } );

   return $self->_attachment_list_data( $page, $attachments );
}

sub attachment_post {
    my ( $self ) = @_;

    my $page_id = $self->param('page_id');
    my $page = CTX->lookup_object( 'wiki_page' )->fetch($page_id);
    die "security error" unless $page && $page->groups_id == $self->param('target_group_id');

    eval {
        CTX->lookup_action('attachment')->execute( store_from_request_upload => {
            upload_name => 'Filedata',
            object => $page,
        } );
    };

    return CTX->request->param('i_am_flash') ? 'status=success' : '<textarea>status=success</textarea>';
}




1;
