package OpenInteract2::Action::DicoleGroupsAPI;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );

sub add_group {
    my ( $self ) = @_;

    my $pid = $self->param( 'parent_group_id' ) || 0;
    my $visible = $self->param( 'visible' ) || 2;
    my $creator_id = $self->param( 'creator_id' ) || 0;
    my $has_area = $self->param( 'has_area' ) ? 1 : 0;
    my $joinable = $self->param('joinable') ? 1 : 3;
    my $name = $self->param('name');
    my $description = $self->param('description');
    my $domain_id = eval { Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) } || 0;
    my $type = $self->param('type') || 'common';
    my $meta = $self->param('meta');

    $type = 'common' unless grep { $_ eq $type } @{ $self->_valid_group_types };

    if ( $pid ) {
        $pid = 0 unless eval { CTX->lookup_object('groups')->fetch( $pid )->id == $pid };
    }

    die unless $name;

    my $group = CTX->lookup_object('groups')->new;
    $group->domain_id( $domain_id );
    $group->creator_id( $creator_id );
    $group->parent_id( $pid );
    $group->created_date( time() );
    $group->points( 0 );

    $group->has_area( $has_area );
    $group->joinable( $joinable );

    $group->name( $name );
    $group->description( $description );
    $group->type( $type );

    $self->_group_data_to_meta( $group, $meta || {} );

    $group->save;

    if ( $domain_id ) {
        eval {
            CTX->lookup_action( 'dicole_domains' )->execute( add_domain_group => {
                group_id => $group->id,
                domain_id => $domain_id,
            } );
        };
    }

    $self->_set_visible( $group, $visible );
    $self->_post_add_actions( $group, $creator_id, $domain_id );
    
    return $group;
}

sub modify_group {
    my ( $self ) = @_;
    
    my $group = $self->_group_from_params;

    my $new_name = $self->param('name');
    if ( defined( $new_name ) && $new_name ne $group->name ) {
        $self->_rename_group( $group, $self->param('name'), $self->param('domain_id') );
    }
    my $new_joinable = $self->param('joinable');
    if ( defined( $new_joinable ) && $new_joinable != $group->joinable ) {
        $group->joinable( $new_joinable );
        $group->save;
    }

    $self->_post_group_modify( $group );
}

sub meta_to_data {
    my ( $self ) = @_;

    return $self->_group_meta_to_data( $self->param('group') );
}

sub banner_for_group {
    my ($self) = @_;

    my $group = $self->_ensure_object( $self->param('group') || $self->param('group_id') );
    return '' unless $group;
    my $meta = $self->_group_meta_to_data( $group );
    return $meta->{banner_attachment_id} ? Dicole::URL->from_parts( action => 'groups', task => 'banner', target => $group->id, additional => [] ) : '';
}

sub info_for_groups {
    my ( $self ) = @_;

    return $self->_info_for_groups( scalar( $self->param('group_ids') ) );
}

sub _info_for_groups {
    my ( $self, $gids ) = @_;

    my $groups = CTX->lookup_object('groups')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( groups_id => $gids ),
    } );
    my $groups_hash = { map { $_->id => $_ } @$groups };

    return { map { $groups_hash->{$_} ? ( $_ => {
        object => $groups_hash->{$_},
        name => $groups_hash->{$_}->name,
    } ) : () } @$gids };
}

sub is_group_visible {
    my ( $self ) = @_;

    return $self->_is_visible( $self->param('group') );
}

sub member_id_list {
    my ( $self ) = @_;

    my $group_id = $self->param('group_id');

    my $group_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_group_user',
        where => 'groups_id = ?',
        value => [ $group_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];

    return [ map { $_->{user_id} } @$group_users ];
}

sub groups_ids_for_domain {
    my ( $self ) = @_;

    my $domain_id = $self->param( 'domain_id' );
    $domain_id = eval { CTX->controller->intial_action->param('domain_id') } unless defined $domain_id;

    return CTX->lookup_action('domains_api')->execute( groups_by_domain => {
        domain_id => $domain_id,
    } ) || [];
}

sub groups_ids_visible_to_user {
    my ( $self ) = @_;

    my $gids = $self->groups_ids_for_domain;
    return $self->_groups_ids_visible_to_user( $self->param('user_id'), $gids );
}

sub _groups_ids_visible_to_user {
    my ( $self, $uid, $limit_to_groups ) = @_;

    my $sec = Dicole::Security::Checker->new( $uid );

    my @visible_gids = ();
    for my $gid ( @$limit_to_groups ) {
        next unless $sec->mchk_y('OpenInteract2::Action::Groups', 'show_info', $gid );
        push @visible_gids, $gid;
    }

    return \@visible_gids;
}

sub groups_infos_visible_to_user {
    my ( $self ) = @_;

    my $gids = $self->groups_ids_visible_to_user;
    return $self->_info_for_groups( scalar( $self->param('group_ids') ) );
}

sub groups_ids_with_user_as_member {
    my ( $self ) = @_;

    my $gids = $self->groups_ids_for_domain;
    return $self->_groups_ids_with_user_as_member( $self->param('user_id'), $gids );
}

sub _groups_ids_with_user_as_member {
    my ( $self, $uid, $limit_to_groups ) = @_;

    my $user_groups = SPOPS::SQLInterface->db_select( {
        select => [ 'groups_id' ],
        from   => [ 'dicole_group_user' ],
        where  => 'user_id = ?',
        value  => [ $uid ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    } ) || [];

    my %user_group_id_map = map { $_->{groups_id} => 1 } @$user_groups;

    if ( ! $limit_to_groups ) {
        $limit_to_groups = [ keys %user_group_id_map ];
    }

    return [ map { $user_group_id_map{ $_ } ? $_ : () } @$limit_to_groups ];
}

sub groups_infos_with_user_as_member {
    my ( $self ) = @_;

    my $gids = $self->groups_ids_with_user_as_member;
    return $self->_info_for_groups( scalar( $self->param('group_ids') ) );
}

sub add_user_to_group {
    my ( $self ) = @_;
    my $domain_id = $self->param('domain_id');
    my $user_id = $self->param('user_id');
    my $group_id = $self->param('group_id');
    my $group = $self->param('group');
    my $as_admin = $self->param('as_admin');

    die if !$user_id || ( !$group_id && !$group );

    $group ||= CTX->lookup_object('groups')->fetch( $group_id );

    die if !$group;
    $group_id = $group->id;

    eval { $group->user_remove( $user_id ) };
    $group->user_add( $user_id );

    $self->param( 'group', $group );
    $self->add_sticky_group_visit;

    # set reminder to personal defaults
    my $settings = Dicole::Settings->new;
    $settings->user( 1 );
    $settings->user_id( $user_id );
    $settings->group( 0 );
    $settings->tool( 'settings_reminders' );
    $settings->fetch_settings;

    if ( my $default = $settings->setting('group_default') ) {
        $settings->setting( $group_id, $default );
    }

    # Add archetype group_admin collections to creator
    if ( $as_admin || $group->creator_id == $user_id ) {
        if ( my $coll = Dicole::Security->collection_by_idstring( 'group_admin' ) ) {
            my $sec = CTX->lookup_object( 'dicole_security' )->new;

            $sec->{receiver_user_id} = $user_id;
            $sec->{target_group_id} = $group->id;
            $sec->{collection_id} = $coll->id;
            $sec->{target_type} = TARGET_GROUP;
            $sec->{receiver_type} = RECEIVER_USER;

            $sec->save;
        }
    }
}

sub add_sticky_group_visit {
    my ( $self ) = @_;
    my $user_id = $self->param('user_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    die unless $user_id;

    my $group = $self->_group_from_params;

    my $groups_action = CTX->lookup_action('workgroups');
    $groups_action->param( 'target_group', $group );
    $groups_action->param( 'target_group_id', $group->id );
    $groups_action->param( 'domain_id', $domain_id );

    CTX->lookup_action('register_area_visit')->execute( {
        action => $groups_action,
        domain_id => $domain_id,
        user_id => $user_id,
        set_sticky => 1,
    } );
}

sub remove_user_from_group {
    my ( $self ) = @_;
    my $user_id = $self->param('user_id');
    die unless $user_id;

    my $group = $self->_group_from_params;
    my $group_id = $group->id;

    if ( my $user = eval { Dicole::Utils::User->ensure_object( $user_id ) } ) {
        my $domain_id = Dicole::Utils::Domain->domain_id_for_group_id( $group_id );
        my $rg = Dicole::Utils::User->get_domain_note( $user, $domain_id, 'removed_from_groups' );
        $rg ||= [];
        push @$rg, { group_id => $group_id, date => time };
        Dicole::Utils::User->set_domain_note( $user, $domain_id, 'removed_from_groups', $rg );
    }
    
    my $auth_membership = $group->user(
        { where => 'user_id = ?', value => [ $user_id ] }
    ) || [];

    foreach ( @$auth_membership ) {
        $group->user_remove( $_ );
    }

    my $objects = CTX->lookup_object( 'dicole_security' )->fetch_group( {
        where => 'receiver_user_id = ? AND target_type = ? AND target_group_id = ?',
        value => [ $user_id, TARGET_GROUP, $group_id ]
    } );

    $_->remove foreach @$objects;

    # Reset user default starting page if it's the group where the user did belong
    $self->_fix_starting_page( $user_id, $group_id );

    # Remove sticky from navigation
    CTX->lookup_action('remove_group_sticky')->execute( {
        group_id => $group_id, user_id => $user_id
    } );
}

sub _fix_starting_page {
    my ( $self, $uid, $gid ) = @_;
    # Reset user default starting page if it's the group where the user did belong
    my $user = CTX->lookup_object('user')->fetch( $uid, { skip_security => 1 } );
    if ( $user && $user->{starting_page} == $gid ) {
        $user->{starting_page} = 0;
        $user->save( { skip_security => 1 } );
    }
}

sub register_group_visit {
    my ( $self ) = @_;
    
    my $uid = $self->param( 'user_id' );
    my $gid = $self->param( 'group_id' );
    
    return if !$uid || !$gid;
    
    my $object = $self->_fetch_rcobject( $uid );
    my @gids = split /,/, $object->{recent_groups};

    return if @gids && $gids[0] == $gid;
    
    @gids = grep { $_ != $gid } @gids;
    unshift @gids, $gid;
    
    $object->{recent_groups} = join ",", @gids;
    $object->save;
}

sub recent_groups_ids {
    my ( $self ) = @_;

    my $uid = $self->param( 'user_id' );

    return if !$uid;

    my $object = $self->_fetch_rcobject( $uid );
    my @gids = split /,/, $object->{recent_groups};

    return \@gids;
}

sub _fetch_rcobject {
    my ( $self, $uid ) = @_;
    
    my $object_class = CTX->lookup_object( 'dicole_recent_groups' );
    my $object = $object_class->fetch( $uid );
    
    if ( ! $object ) {
        $object = $object_class->new( {
            user_id => $uid,
            recent_groups => '',
        } );
    }
    
    return $object;
}

sub set_group_look {
    my ( $self ) = @_;

    return 0 unless defined( $self->param('look') );
    $self->_group_look( $self->param('look') );
}

sub get_group_look {
    my ( $self ) = @_;

    return $self->_group_look;
}

sub _group_look {
    my ( $self, $look ) = @_;

    my $group_id = $self->param('group_id');
    die unless $group_id;

    my $domain_id = $self->param('domain_id');

    my $tool = 'navigation';
    if ( ! defined $domain_id ) {
        eval { $domain_id = CTX->lookup_action('dicole_domains')->execute( get_current_domain => {} )->id; };
    }
    $tool .= "_$domain_id" if $domain_id;

    if ( defined $look ) {
        Dicole::Settings->store_single_setting(
            tool => $tool,
            attribute => 'custom_css',
            group_id => $group_id,
            value => $look,
        );

        return 1;
    }
    else {
        return Dicole::Settings->fetch_single_setting(
            tool => $tool,
            attribute => 'custom_css',
            group_id => $group_id,
            value => $look,
        );
    }
}

sub add_to_group_tools {
    my ( $self ) = @_;
    
    my $tool = $self->_toolid_to_tool( $self->param( 'toolid' ) );
    $self->_get_group->tool_add( $tool->id );
}

sub remove_from_group_tools {
    my ( $self ) = @_;
    my $tool = $self->_toolid_to_tool( $self->param( 'toolid' ) );
    $self->_get_group->tool_remove( $tool->id );
}

sub add_group_member_right {
    my ( $self ) = @_;

    $self->_create_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        $self->_get_group->id,
    );
}

sub remove_group_member_right {
    my ( $self ) = @_;

    $self->_remove_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        $self->_get_group->id,
    );
}

sub add_public_group_right {
    my ( $self ) = @_;
    $self->_create_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        0,
    );
}

sub remove_public_group_right {
    my ( $self ) = @_;

    $self->_remove_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        0,
    );
}

sub add_individual_group_right {
    my ( $self ) = @_;
    $self->_create_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        0,
        $self->param( 'user_id' )
    );
}

sub remove_individual_group_right {
    my ( $self ) = @_;

    $self->_remove_group_collection(
        $self->_collection_id_by_idstring( $self->param( 'collection' ) ),
        $self->_get_group->id,
        0,
        $self->param( 'user_id' )
    );
}

sub _create_group_collection {
    my ( $self, $cid, $target_gid, $receiver_gid, $receiver_uid ) = @_;
    
    my $o = $self->_get_group_collection( $cid, $target_gid, $receiver_gid, $receiver_uid );
    return $o if $o;
    
    $o = CTX->lookup_object('dicole_security')->new;
    $o->{receiver_group_id} = $receiver_gid || 0;
    $o->{receiver_user_id} = $receiver_uid || 0;
    $o->{target_group_id} = $target_gid;
    $o->{collection_id} = $cid;
    $o->{target_type} = TARGET_GROUP;
    $o->{receiver_type} = $receiver_gid ? RECEIVER_GROUP : $receiver_uid ? RECEIVER_USER : RECEIVER_GLOBAL;
    
    $o->save;
    
    return $o;
}

sub _remove_group_collection {
    my ( $self, $cid, $target_gid, $receiver_gid, $receiver_uid ) = @_;
    
    my $o = $self->_get_group_collection(  $cid, $target_gid, $receiver_gid, $receiver_uid );
    $o->remove if $o;
}

sub _get_group_collection {
    my ( $self, $cid, $target_gid, $receiver_gid, $receiver_uid ) = @_;
    
    my $os = CTX->lookup_object('dicole_security')->fetch_group( {
        where => '' .
            'receiver_type = ? AND ' .
            'target_type = ? AND ' .
            'receiver_group_id = ? AND ' .
            'receiver_user_id = ? AND ' .
            'target_group_id = ? AND ' .
            'target_user_id = ? AND ' .
            'target_object_id = ? AND ' .
            'collection_id = ?',
        value => [
            $receiver_gid ? RECEIVER_GROUP : $receiver_uid ? RECEIVER_USER : RECEIVER_GLOBAL,
            TARGET_GROUP,
            $receiver_gid || 0,
            $receiver_uid || 0,
            $target_gid,
            0,
            0,
            $cid,
        ],
    } ) || [];
    
    my $o = shift @$os;
    $_->remove for @$os;
    return $o;
}

sub _get_group {
    my ( $self ) = @_;
    
    return $self->param('group') || CTX->lookup_object( 'groups' )->fetch(
        $self->param('group_id')
    );
}

sub _toolid_to_tool {
    my ( $self, $toolid ) = @_;
    
    my $tools = CTX->lookup_object( 'tool' )->fetch_group( {
        where => 'toolid = ?',
        value => [ $toolid ],
    } ) || [];
    
    return $tools->[0];
}

sub _collection_id_by_idstring {
    my ( $self, $id ) = @_;
    return Dicole::Security->collection_by_idstring( $id )->id;
}

sub _group_from_params {
    my ( $self ) = @_;

    my $group_id = $self->param('group_id');
    my $group = $self->param('group');

    die unless $group_id || $group;

    $group ||= CTX->lookup_object('groups')->fetch( $group_id );

    die unless $group;

    return $group;
}

sub group_security_levels {
    my ( $self ) = @_;

    my $group_id = $self->param('group_id');

    return [
        {
            id => 'admin', name => $self->_msg('Admin'),
            grant_secure => '',
            alter_secure => '',
        },
        {
            id => 'moderator', name => $self->_msg('Moderator'),
            grant_secure => '',
            alter_secure => '',
        },
        {
            id => 'user', name => $self->_msg('User'),
            grant_secure => '',
            alter_secure => '',
        },
    ];
}

sub group_security_levels_managed_by_current_user {
    my ( $self ) = @_;

    my $group_id = $self->param('group_id');
    my $levels = $self->param('levels') || $self->group_security_levels;

    for my $level ( @$levels ) {
        $level->{grant} = $self->schk_y( $level->{grant_secure}, $group_id ) ? 1 : 0;
        $level->{alter} = $self->schk_y( $level->{alter_secure}, $group_id ) ? 1 : 0;
    }

    return $levels;
}

sub group_security_levels_grantable_by_current_user {
    my ( $self ) = @_;

    my $group_id = $self->param('group_id');
    my $levels = $self->param('levels') || $self->group_security_levels;

    return [ map { $_->{grant} ? $_ : () } @$levels ];
}

1;
