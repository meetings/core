package OpenInteract2::Action::DicoleGroupsCommon;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );

sub LEVEL_USER { 'user' }
sub LEVEL_MODERATOR { 'moderator' }
sub LEVEL_ADMIN { 'admin' }

sub USER_LEVELS {
    my $self = shift @_;
    return [
        $self->LEVEL_ADMIN(),
        $self->LEVEL_MODERATOR(),
        $self->LEVEL_USER(),
    ];
}

sub USER_LEVEL_NAMES {
    my $self = shift @_;
    return {
        $self->LEVEL_USER() => $self->_msg('User'),
        $self->LEVEL_MODERATOR() => $self->_msg('Moderator'),
        $self->LEVEL_ADMIN() => $self->_msg('Admin'),
    };
}

sub _determine_user_level_in_group {
    my ( $self, $user_id, $gid, $user_coll_map, $mode_coll, $admin_coll) = @_;

    $user_coll_map ||= $self->_user_special_rights_hash_for_group( $gid );
    $admin_coll ||= $self->_admin_collection_id;
    $mode_coll ||= $self->_moderator_collection_id;

    my $level = $self->LEVEL_USER;
    $level = $self->LEVEL_MODERATOR if $user_coll_map->{$user_id}{ $mode_coll };
    $level = $self->LEVEL_ADMIN if $user_coll_map->{$user_id}{ $admin_coll };

    return $level;    
}

sub _fetch_group_users {
    my ( $self, $gid ) = @_;

    my $uids = $self->_fetch_group_user_ids( $gid );

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => $uids ),
    } );

    return $users;
}

sub _fetch_group_user_ids {
    my ( $self, $gid ) = @_;

    my $group_user_objects = CTX->lookup_object('group_user')->fetch_group( {
        where => 'groups_id = ?',
        value => [ $gid ],
    } );

    my @uids = map { $_->user_id } @$group_user_objects;
    my %uids_map = map { $_ => 1 } @uids;

    return [ keys %uids_map ];
}

sub _post_add_actions {
    my ( $self, $group, $user_id, $domain_id ) = @_;
    
    unless ( $domain_id ) {
        my $domain_id = eval {
            CTX->lookup_action('dicole_domains')->execute(
                get_current_domain => {}
            )->id;
        } || 0;
    }

    # Add creator to group, parting is always an option later ;)
    # note: adds group admin rights too
    CTX->lookup_action('groups_api')->execute( add_user_to_group => {
        group => $group, user_id => $user_id, domain_id => $domain_id
    } ) if $user_id;

    # Add default user rights by default
    CTX->lookup_action('groups_api')->execute( add_group_member_right => {
        group => $group, collection => 'default_group_user'
    } );

#    $self->_add_url_alias( $group, $domain_id );

    $self->_post_group_modify( $group );
}

sub _add_url_alias {
    my ( $self, $group, $domain_id ) = @_;
    
    my $alias = Dicole::URL->create_alias( {
        domain_id => $domain_id,
        group_id => $group->id,
        from_string => $group->name,
    } );
}

sub _rename_group {
    my ( $self, $group, $name, $domain_id ) = @_;
    
    $group->name( $name );
    $group->save;
    
    my $domain_ids = defined( $domain_id ) ?
        [ $domain_id ]
        :
        eval { CTX->lookup_action('dicole_domains')->execute( get_group_domains => {
            group_id => $group->id,
        } ) } || [];
    
    unless ( scalar( @$domain_ids) ) {
        $domain_ids = [ 0 ];
    }
    
    for my $domain_id ( @$domain_ids ) {
        $self->_add_url_alias( $group, $domain_id );
    }
    
    return 1;
}

sub _post_group_modify {
    my ( $self, $group ) = @_;

    CTX->lookup_action('set_area_visiting_for_group')->execute( { group => $group } );
}

sub _set_visible {
    my ( $self, $group, $value ) = @_;

    return if ! $group;

    $self->_init_visible( $group );

    if ( my $vis = Dicole::Security->collection_by_idstring( 'show_group_info' ) ) {

        if ( $value == 1 && $group->{visible} != 1 ) {
            my $o = CTX->lookup_object('dicole_security')->new;

            $o->{target_group_id} = $group->id;
            $o->{collection_id} = $vis->id;
            $o->{target_type} = TARGET_GROUP;
            $o->{receiver_type} = RECEIVER_LOCAL;

            $o->save;

            $group->{visible} = 1;
        }
        elsif ( $value == 2 && $group->{visible} != 2 ) {
            my $targets = CTX->lookup_object('dicole_security')->fetch_group( {
                where => 'collection_id = ? AND target_group_id = ? AND receiver_type = ?',
                value => [ $vis->id, $group->id, RECEIVER_LOCAL ],
            } ) || [];

            $_->remove foreach @$targets;

            $group->{visible} = 2;
        }
    }
}

sub _init_visible {
    my ( $self, $group ) = @_;

    return if ! $group;

    $group->{visible} = 2; # no by default

    if ( my $vis = Dicole::Security->collection_by_idstring( 'show_group_info' ) ) {

        my $targets = CTX->lookup_object('dicole_security')->fetch_group( {
            where => 'collection_id = ? AND target_group_id = ? AND receiver_type = ?',
            value => [ $vis->id, $group->id, RECEIVER_LOCAL ],
        } ) || [];

        $group->{visible} = 1 if scalar @$targets;
    }
}

sub _is_visible {
    my ( $self, $group ) = @_;

    return unless $group;

    $self->_init_visible( $group ) unless defined $group->{visible};

    return $group->{visible} == 1 ? 1 : 0;
}

sub _valid_group_types {
    return [ qw/
        usergroup
        workgroup
        organization
        class
        course
        project
        administration
        section
        common
    / ];
}

sub _group_meta_to_data {
    my ( $self, $group ) = @_;

    my $data = Dicole::Utils::JSON->decode( $group->meta || '{}' );

    my $link;

    if ( $link = $data->{facebook} ) {
        $link = 'http://www.facebook.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{facebook_link} = $link;
    }

    if ( $link = $data->{myspace} ) {
        $link = 'http://www.myspace.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{myspace_link} = $link;
    }

    if ( $link = $data->{twitter} ) {
        $link = 'http://www.twitter.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{twitter_link} = $link;
    }

    if ( $link = $data->{youtube} ) {
        $link = 'http://www.youtube.com/' . $link unless $link =~ /^http\:\/\//;
        $data->{youtube_link} = $link;
    }

    if ( $link = $data->{webpage} ) {
        $link = 'http://' . $link unless $link =~ /^http\:\/\//;
        $data->{webpage_link} = $link;
    }

    return $data;
}

sub _group_data_to_meta {
    my ( $self, $group, $data ) = @_;

    $group->meta( ( ref $data ) ? Dicole::Utils::JSON->encode( $data ) :  $data || '{}' );
}

sub _group_member_count {
    my ( $self, $group ) = @_;

    my $guos = CTX->lookup_object('group_user')->fetch_group({
        where => 'groups_id = ?',
        value => [ $self->_ensure_id( $group ) ],
    });

    return scalar( @$guos );
}

sub _admin_collection_id {
    my ( $self ) = @_;

    return Dicole::Security->collection_id_by_idstring( 'group_admin' );
}

sub _moderator_collection_id {
    my ( $self ) = @_;

    return Dicole::Security->collection_id_by_idstring( 'group_moderator' );
}

sub _user_special_rights_hash_for_group {
    my ( $self, $group_id ) = @_;

    my $rights = CTX->lookup_object('dicole_security')->fetch_group( {
        where => 'receiver_type = ? AND target_type = ? AND target_group_id = ?',
        value => [ RECEIVER_USER, TARGET_GROUP, $group_id ],
    } );

    my %right_map = ();

    for my $right ( @$rights ) {
        $right_map{ $right->receiver_user_id }{ $right->collection_id } = 1;
    }

    return \%right_map;
}

sub _get_valid_parent_hashes {
    my ( $self, $current_id ) = @_;

    my $result = [];

    push @$result, { value => 0, name => ' ' } if $self->mchk_y( 'OpenInteract2::Action::Groups', 'create' );

    my $groups = CTX->lookup_object('groups')->fetch_group( {
        order => 'name',
    } );

    my $limited_groups = $self->_get_limited_groups;
    my %lookup = ();

    if ( $limited_groups ) {
        %lookup = map { $_ => 1 } @$limited_groups;
    }

    my $sections_only = Dicole::Utils::Domain->setting( undef, 'only_section_base_groups' );

    for my $group ( @$groups ) {
        next if $limited_groups && ! $lookup{ $group->id };
        next unless $group->id == $current_id || $self->_user_can_create_subgroup( $group->id );
        next if $sections_only && ! ( $group->type eq 'section' );
        push @$result, { value => $group->id, name => $group->name };
    }

    return $result;
}

sub _get_limited_groups {
    my ( $self ) = @_;

    my $limited_groups = [];
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $dicole_domains->task( 'groups_by_domain' );
        $limited_groups = $dicole_domains->execute;
    }
    else {
        return undef;
    }
    return $limited_groups;
}

sub _user_can_create_subgroup {
    my ( $self, $pid ) = @_;

    return 1 if ! $pid && $self->mchk_y( 'OpenInteract2::Action::Groups', 'create' );
    return 1 if $pid && $self->mchk_y( 'OpenInteract2::Action::Groups', 'show_info', $pid ) && $self->mchk_y( 'OpenInteract2::Action::Groups', 'create_subgroup', $pid );

    return 0;
}

# If group's new parent happens to be one of its children, we find the
# immediate child of the group which is ancestor to the new parent
# and change the immediate childs parent to groups old parent.
# What happens is that the branch which holds the new parent is
# detached from the group and moved in the groups place and all the
# other branches of the group follow the group to the new parent.
# This is probably the best thing we can do in case of a circ ref.

sub _fix_parent_loop {
    my ( $self, $group, $newpid, $oldpid ) = @_;

    return if $newpid == 0;

    my $parent = eval { $group->fetch( $newpid ) };

    my $ok = 1;
    while ( $parent && $parent->{parent_id} != 0 ) {
        if ( $parent->{parent_id} == $group->id ) {
            $ok = 0; last;
        }
        $parent = eval { $group->fetch( $parent->{parent_id} ); }
    }

    if ( !$ok ) {
        $parent->{parent_id} = $oldpid;
        $parent->save;
    }
}

sub _ensure_id {
    my ( $self, $group ) = @_;

    return ( ref( $group ) =~ /group/i ) ? $group->id : $group;
}

sub _ensure_object {
    my ( $self, $group ) = @_;

    return undef unless $group;

    return $group if ref( $group ) =~ /group/i;

    if ( CTX && CTX->controller && CTX->controller->initial_action ) {
        my $g = CTX->controller->initial_actoin->param( 'target_group' );
        return $g if $g && $g->id == $group;
    }

    return CTX->lookup_object('groups')->fetch( $group );
}

1;
