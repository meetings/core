package Dicole::Meta;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub get_objects_associated_with_group {
    my ( $class, $object_type, $group_id, $domain_id ) = @_;

    my $all_objects;
    my $info = $class->spops_special_info->{ $object_type };

    if ( $info->{groups_by_object} || $info->{groups_by_dynamic_object} || $info->{groups_by_has_a_links} ) {
        if ( $domain_id && $info->{domain_id_field} ) {
            $all_objects = CTX->lookup_object( $object_type )->fetch_group({
                where => $info->{domain_id_field} . ' = ? OR ' . $info->{domain_id_field} . ' = ?',
                value => [ $domain_id, 0 ],
            });
        }
        else {
            $all_objects = CTX->lookup_object( $object_type )->fetch_group || [];
        }
    }
    elsif ( $info->{group_id_field} || $info->{group_id_field_list} ) {
        my @columns = $info->{group_id_field} || ();
        push @columns, $info->{group_id_field_list} ? @{ $info->{group_id_field_list} } : ();

        $all_objects = CTX->lookup_object( $object_type )->fetch_group( {
            where => join( ' OR ', ( map { $_ . ' = ?' } @columns ) ),
            value => [ map { $group_id } @columns ],
        } ) || [];
    }
    else {
        $all_objects = [];
    }
    
    my $filtered = [];

    for my $object ( @$all_objects ) {
        push @$filtered, $object if $class->object_is_associated_with_group( $object, $group_id );
    }

    return $filtered;
}

sub preload_associations {
    my ( $class, $object_type, $where, $value ) = @_;

    my $all_objects;
    my $info = $class->spops_special_info->{ $object_type };

    $all_objects = CTX->lookup_object( $object_type )->fetch_group({
        $where ? ( where => $where ) : (),
        $value ? ( value => $value ) : (),
    }) || [];
    $class->groups_associated_with_object( $_ ) for @$all_objects;
}

our $associations = {};

sub groups_associated_with_object {
    my ( $class, $object ) = @_;

    my $object_class = ref( $object );
    my $object_id = $object->id;

    return $associations->{$object_class}->{$object_id} if $associations->{$object_class}->{$object_id};

    my $object_key = $class->class_to_object_key( $object_class );
    my $info = $class->spops_special_info->{ $object_key };

    my @gids = ();
    push @gids, $object->get( $info->{group_id_field} ) if $info->{group_id_field};
    if ( my $ol = $info->{group_id_field_list} ) {
        push @gids, $object->get( $_ ) for @$ol;
    }
    if ( my $oi = $info->{groups_by_object} ) {
        my $delegate = CTX->lookup_object( $oi->[1] )->fetch( $object->get( $oi->[0] ) );
        if ( $delegate ) {
            push @gids, @{ $class->groups_associated_with_object( $delegate ) };
        }
    }
    if ( my $oh = $info->{groups_by_has_a_links} ) {
        my $delegates = CTX->lookup_object( $oh->[0] )->fetch_group( {
            where => $oh->[1] . ' = ?',
            value => [ $object_id ],
        } ) || [];
        push @gids, @{ $class->groups_associated_with_object( $_ ) } for @$delegates;
    }
    if ( my $od = $info->{groups_by_dynamic_object} ) {
        my $dynamic_key = $class->class_to_object_key( $object->get( $od->[0] ) );
        next unless $dynamic_key;
        my $delegate = CTX->lookup_object( $dynamic_key )->fetch( $object->get( $od->[1] ) );
        if ( $delegate ) {
            push @gids, @{ $class->groups_associated_with_object( $delegate ) };
        }
    }

    my %gids = map { $_ => 1 } @gids;
    delete $gids{0};

    $associations->{$object_class}->{$object_id} = [ sort keys %gids ];

    return $associations->{$object_class}->{$object_id};
}

sub object_is_associated_with_group {
    my ( $class, $object, $group_id ) = @_;

    my $gids = $class->groups_associated_with_object( $object );
    my %lookup = map { $_ => 1} @$gids;
    return $lookup{ $group_id } ? 1 : 0;
}

sub class_to_object_key {
    my ( $class, $lookup ) = @_;

    return $class->spops_class_to_key_hash->{ $lookup };
}

our $class_to_key_hash;

sub spops_class_to_key_hash {
    $class_to_key_hash ||= {
          'OpenInteract2::AreaVisit' => 'area_visit',
          'OpenInteract2::Attachment' => 'attachment',
          'OpenInteract2::BlogsDeletedEntry' => 'blogs_deleted_entry',
          'OpenInteract2::BlogsDraftEntry' => 'blogs_draft_entry',
          'OpenInteract2::BlogsEntry' => 'blogs_entry',
          'OpenInteract2::BlogsEntryUid' => 'blogs_entry_uid',
          'OpenInteract2::BlogsPromotion' => 'blogs_promotion',
          'OpenInteract2::BlogsPublished' => 'blogs_published',
          'OpenInteract2::BlogsRating' => 'blogs_rating',
          'OpenInteract2::BlogsRepostedData' => 'blogs_reposted_data',
          'OpenInteract2::BlogsRepostedLink' => 'blogs_reposted_link',
          'OpenInteract2::BlogsReposter' => 'blogs_reposter',
          'OpenInteract2::BlogsSeed' => 'blogs_seed',
          'OpenInteract2::BlogsSummarySeed' => 'blogs_summary_seed',
          'OpenInteract2::CommentsPost' => 'comments_post',
          'OpenInteract2::CommentsThread' => 'comments_thread',
          'OpenInteract2::CustomLocalization' => 'custom_localization',
          'OpenInteract2::DicoleDomain' => 'dicole_domain',
          'OpenInteract2::DicoleDomainAdmin' => 'dicole_domain_admin',
          'OpenInteract2::DicoleDomainGroup' => 'dicole_domain_group',
          'OpenInteract2::DicoleDomainUser' => 'dicole_domain_user',
          'OpenInteract2::DicoleGroupUser' => 'group_user',
          'OpenInteract2::DicoleLang' => 'lang',
          'OpenInteract2::DicoleLoggedAction' => 'logged_action',
          'OpenInteract2::DicoleSecurity' => 'dicole_security',
          'OpenInteract2::DicoleSecurityCollection' => 'dicole_security_collection',
          'OpenInteract2::DicoleSecurityCollectionLevel' => 'dicole_security_col_lev',
          'OpenInteract2::DicoleSecurityLevel' => 'dicole_security_level',
          'OpenInteract2::DicoleSecurityMeta' => 'dicole_security_meta',
          'OpenInteract2::DicoleSummaryLayout' => 'dicole_summary_layout',
          'OpenInteract2::DicoleTag' => 'tag',
          'OpenInteract2::DicoleTagAttached' => 'tag_attached',
          'OpenInteract2::DicoleTagIndex' => 'tag_index',
          'OpenInteract2::DicoleTheme' => 'dicole_theme',
          'OpenInteract2::DicoleToolSettings' => 'dicole_tool_settings',
          'OpenInteract2::DicoleWizard' => 'dicole_wizard',
          'OpenInteract2::DicoleWizardData' => 'dicole_wizard_data',
          'OpenInteract2::DigestSource' => 'digest_source',
          'OpenInteract2::DraftContainer' => 'draft_container',
          'OpenInteract2::EventSourceEvent' => 'event_source_event',
          'OpenInteract2::EventSourceGateway' => 'event_source_gateway',
          'OpenInteract2::EventSourceSyncSubscription' => 'event_source_sync_subscription',
          'OpenInteract2::EventsEvent' => 'events_event',
          'OpenInteract2::EventsInvite' => 'events_invite',
          'OpenInteract2::EventsUser' => 'events_user',
          'OpenInteract2::FreeformSummary' => 'freeform_summary',
          'OpenInteract2::Group' => 'group',
          'OpenInteract2::Groups' => 'groups',
          'OpenInteract2::Invite' => 'invite',
          'OpenInteract2::LoggedUsageDaily' => 'logged_usage_daily',
          'OpenInteract2::LoggedUsageUser' => 'logged_usage_user',
          'OpenInteract2::LoggedUsageWeekly' => 'logged_usage_weekly',
          'OpenInteract2::NavigationItem' => 'navigation_item',
          'OpenInteract2::NetworkingContact' => 'networking_contact',
          'OpenInteract2::NetworkingProfile' => 'networking_profile',
          'OpenInteract2::PresentationsPrese' => 'presentations_prese',
          'OpenInteract2::PresentationsPreseRating' => 'presentations_prese_rating',
          'OpenInteract2::Security' => 'security',
          'OpenInteract2::Sessions' => 'sessions',
          'OpenInteract2::StatisticsAction' => 'statistics_action',
          'OpenInteract2::TagIndex' => 'tag_index',
          'OpenInteract2::ThemePersist' => 'theme',
          'OpenInteract2::ThemeProp' => 'themeprop',
          'OpenInteract2::Tool' => 'tool',
          'OpenInteract2::UrlAlias' => 'url_alias',
          'OpenInteract2::UserLanguage' => 'user_language',
          'OpenInteract2::WeblogPosts' => 'weblog_posts',
          'OpenInteract2::WikiAnnotation' => 'wiki_annotation',
          'OpenInteract2::WikiContent' => 'wiki_content',
          'OpenInteract2::WikiLink' => 'wiki_link',
          'OpenInteract2::WikiLock' => 'wiki_lock',
          'OpenInteract2::WikiPage' => 'wiki_page',
          'OpenInteract2::WikiRedirection' => 'wiki_redirection',
          'OpenInteract2::WikiSearch' => 'wiki_search',
          'OpenInteract2::WikiSummaryPage' => 'wiki_summary_page',
          'OpenInteract2::WikiSupport' => 'wiki_support',
          'OpenInteract2::WikiVersion' => 'wiki_version',
 
          'OpenInteract2::User' => 'user',
          'DicoleWeblogPosts' => 'weblog_posts',
     };

    return $class_to_key_hash;
}

our $special_info;

sub spops_special_info {
    $special_info ||= {
#          'account_recovery_key' => 1,
          'area_visit' => { group_id_field => 'target_group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'target_user_id'] },
          'attachment' => { group_id_field => 'target_group_id', groups_by_dynamic_object => [ 'object_type', 'object_id' ], show => 0, user_id_field_list => ['user_id'] },
          'blogs_deleted_entry' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_draft_entry' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_entry' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_entry_uid' => { groups_by_object => [ entry_id => 'blogs_entry' ] },
          'blogs_promotion' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_published' => { group_id_field => 'group_id', show => 0 },
          'blogs_rating' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_reposted_data' =>  { groups_by_object => [ reposter_id => 'blogs_reposter' ], domain_id_field => 'domain_id', show => 0 },
          'blogs_reposted_link' => { groups_by_object => [ reposter_id => 'blogs_reposter' ], domain_id_field => 'domain_id', show => 0 },
          'blogs_reposter' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
          'blogs_seed' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['creator_id'] },
          'blogs_summary_seed' => { group_id_field => 'group_id', show => 0 },
          'comments_post' => { groups_by_object => [ thread_id => 'comments_thread' ], show => 0, user_id_field_list => ['user_id'] },
          'comments_thread' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
#          'content_type' => 1,
          'custom_localization' => { group_id_field => 'namespace_area', domains_by_matching_value => ['namespace_key', 'localization_namespace' ] },
#          'dcmi_metadata' => 1,
          'dicole_domain' => { domain_id_field => 'domain_id', show => 0 },
          'dicole_domain_admin' => { domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
          'dicole_domain_group' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0 },
          'dicole_domain_user' => { domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
#          'dicole_recent_groups' => 1,
          'dicole_security' => { group_id_field_list => ['target_group_id', 'receiver_group_id'], user_id_field_list => ['target_user_id', 'receiver_user_id']},
          'dicole_security_col_lev' => {},
          'dicole_security_collection' => {},
          'dicole_security_level' => {},
          'dicole_security_meta' => {},
          'dicole_summary_layout' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'dicole_theme' => {},
##### Special.. domains encoded in the tool name :(
          'dicole_tool_settings' => { group_id_field => 'groups_id', show => 0, user_id_field_list => ['user_id'] },
          'dicole_wizard' => { empty => 1 },
          'dicole_wizard_data' => { empty => 1 },
          'digest_source' => {},
          'draft_container' => { domain_id_field => 'domain_id', show => 0 },
          'event_source_event' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
          'event_source_gateway' => {},
          'event_source_sync_subscription' => {},
          'events_event' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['creator_id'] },
          'events_invite' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'creator_id'] },
          'events_user' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'creator_id'] },
#          'externalsource' => 1,
#          'feeds' => 1,
#          'feeds_items' => 1,
#          'feeds_items_users' => 1,
#          'feeds_users' => 1,
#          'feeds_users_summary' => 1,
#          'files' => 1,
#          'forums' => 1,
#          'forums_messages' => 1,
#          'forums_messages_unread' => 1,
#          'forums_metadata' => 1,
#          'forums_parts' => 1,
#          'forums_threads' => 1,
#          'forums_threads_read' => 1,
#          'forums_versions' => 1,
          'freeform_summary' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
#          'full_text_mapping' => 1,
          'group' => {},
#          'group_pages' => 1,
#          'group_pages_content' => 1,
#          'group_pages_link' => 1,
#          'group_pages_version' => 1,
#          'group_pages_version_content' => 1,
          'group_user' => { group_id_field => 'groups_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'creator_id'] },
          'groups' => { group_id_field => 'groups_id', show => 0 },
          'invite' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
          'lang' => {},
          'logged_action' => { group_id_field => 'target_group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'target_user_id'] },
          'logged_usage_daily' => { empty => 1 },
          'logged_usage_user' => { empty => 1 },
          'logged_usage_weekly' => { empty => 1},
#          'metadata' => 1,
#          'metadata_fields' => 1,
          'navigation_item' => {},
          'networking_contact' => { domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id', 'contacted_user_id'] },
          'networking_profile' => { domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
#          'news' => 1,
#          'news_section' => 1,
#          'object_action' => 1,
#          'page' => 1,
#          'page_content' => 1,
#          'page_directory' => 1,
          'presentations_prese' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['creator_id'] },
          'presentations_prese_rating' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['user_id'] },
          'security' => {},
          'sessions' => { empty => 1 },
          'statistics_action' => { empty => 1 },
          'tag' => { domain_id_field => 'domain_id', group_id_field => 'group_id', groups_by_has_a_links => [ tag_attached => 'tag_id' ], user_id_field_list => ['user_id'] },
          'tag_attached' =>  { groups_by_dynamic_object => [ 'object_type', 'object_id' ], domain_id_field => 'domain_id' },
          'tag_index' =>  { groups_by_dynamic_object => [ 'object_type', 'object_id' ], domain_id_field => 'domain_id', group_id_field => 'group_id', user_id_field_list => ['user_id'] },
          'theme' => {},
          'themeprop' => {},
          'tool' => {},
#          'typeset_types' => 1,
#          'typeset_types_link' => 1,
#          'typesets' => 1,
          'url_alias' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['user_id'] },
#          'user' => 'SPECIAL',
          'user_language' => {},
#          'weblog_comments' => 1,
          'weblog_posts' => { groups_by_has_a_links => [ blogs_entry => 'post_id' ], show => 0, user_id_field_list => ['user_id', 'writer'] },
#          'weblog_topics' => 1,
#          'weblog_trackbacks' => 1,
#         'whats_new' => 1,
          'wiki_annotation' => { group_id_field => 'group_id', domain_id_field => 'domain_id', show => 0, user_id_field_list => ['creator_id'] },
#### this is TOO slow (no index and huge dataset)
#          'wiki_content' => { groups_by_has_a_links => [ wiki_version => 'content_id' ], show => 0 },
          'wiki_link' => { group_id_field => 'groups_id', show => 0 },
          'wiki_lock' => { groups_by_object => [ page_id => 'wiki_page' ], show => 0, user_id_field_list => ['user_id'] },
          'wiki_page' => { group_id_field => 'groups_id', show => 0, user_id_field_list => ['last_author_id'] },
          'wiki_redirection' => { group_id_field => 'group_id', show => 0 },
          'wiki_search' => { groups_by_object => [ page_id => 'wiki_page' ], show => 0 },
          'wiki_summary_page' => { group_id_field => 'group_id', show => 0 },
          'wiki_support' => { group_id_field => 'group_id', show => 0, user_id_field_list => ['creator_id'] },
          'wiki_version' => { group_id_field => 'groups_id', show => 0, user_id_field_list => ['creator_id'] },
    };

    return $special_info;
}

1;

