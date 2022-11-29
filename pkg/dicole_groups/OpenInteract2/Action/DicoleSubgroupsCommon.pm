package OpenInteract2::Action::DicoleSubgroupsCommon;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_PROFILE_LIST_SIZE { 3 };

sub _fetch_sections {
    my ( $self, $gid ) = @_;

    my $sections = CTX->lookup_object('groups')->fetch_group( {
        where => 'parent_id = ? AND type = ?',
        value => [ $gid, 'section' ],
    } );

    return [ map { { id => $_->id, name => $_->name } } @$sections ],
}

sub _fetch_visible_groups {
    my ( $self, $pgids ) = @_;

    my $candidate_groups = CTX->lookup_object('groups')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( parent_id => $pgids ) .' AND type != ?',
        value => [ 'section' ],
    } );

    my $groups = [];
    for my $group ( @$candidate_groups ) {
        next unless $self->mchk_y( 'OpenInteract2::Action::Groups', 'show_info', $group->id );
        next unless $self->_is_visible( $group );
        push @$groups, $group;
    }

    return $groups;
}

sub _sections_to_parent_ids {
    my ( $self, $gid, $sections, $section ) = @_;

    my $pgids = [];
    if ( $section eq 'all' ) {
        push @$pgids, $gid;
        push @$pgids, ( map { $_->{id} } @$sections );
    }
    else {
        push @$pgids, $section;
    }
    return $pgids;
}

sub _fetch_group_list_info {
    my ( $self, $gid, $domain_id, $size, $state ) = @_;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];

    my $section = $state->{section} ||= 'all';
    my $sections = $self->_fetch_sections( $gid );

    my $pgids = $self->_sections_to_parent_ids( $gid, $sections, $section );
    my $visible_groups = $self->_fetch_visible_groups( $pgids );
    my $visible_groups_ids = [ map { $_->id } @$visible_groups ];

    my $shown_groups = $state->{shown_groups} || [];
    my $groups = CTX->lookup_action('tagging')->execute( tag_limited_fetch_group => {
        object_class => CTX->lookup_object('groups'),
        where => Dicole::Utils::SQL->column_in( groups_id => $visible_groups_ids ) .
            ' AND ' . Dicole::Utils::SQL->column_not_in( groups_id => $shown_groups ),
        value => [],
        tags => $tags,
        user_id => 0,
        group_id => 0,
        domain_id => $domain_id,
    } ) || [];

    my %groups_by_gid = map { $_->id => $_ } @$groups;

    my $object_info_list = [];
    for my $group ( sort { lc( $a->name ) cmp lc( $b->name ) } @$groups ) {
        push @$shown_groups, $group->id;
        my $meta = $self->_group_meta_to_data( $group );

        my $image = $meta->{image_attachment_id} ? $self->derive_url( action => 'groups', task => 'image', target => $group->id, additional => [ 120, 90 ] ) : '';

        my $hash = {
            name => $group->name,
            url => $self->derive_url( action => 'subgroups', task => 'profile', additional => [ $group->id ] ),
            image => $image,
            member_count => $self->_group_member_count( $group ),
        };

        my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
            object => $group,
            user_id => 0,
            group_id => 0,
        } );

        $hash->{tags} = [ map { {
            name => $_, link => $self->derive_url( action => 'subgroups', task => 'browse', additional => [ $section, $_ ] )
        } } @$tags ];

        push @$object_info_list, $hash;
        last if scalar( @$object_info_list ) >= $size;
    }

    $state->{shown_groups} = $shown_groups;

    return {
        visible_groups => $visible_groups,
        object_info_list => $object_info_list,
        state => $state,
        sections => $sections,
        end_of_pages => ( scalar( @$groups ) > scalar( @$object_info_list ) ? 0 : 1 ),
        count => scalar( @$groups ),
    };
}

sub _fetch_group_filter_links {
    my ( $self, $gid, $domain_id, $limit, $state ) = @_;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];
    my $section = $state->{section} ||= 'all';
    my $sections = $self->_fetch_sections( $gid );

    my $pgids = $self->_sections_to_parent_ids( $gid, $sections, $section );
    my $visible_groups = $self->_fetch_visible_groups( $pgids );
    my $visible_groups_ids = [ map { $_->id } @$visible_groups ];

    my $weighted_tags = CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group_weighted_tags', {
        object_class => CTX->lookup_object('groups'),
        where => Dicole::Utils::SQL->column_in( groups_id => $visible_groups_ids ),
        value => [],
        tags => $tags,
        group_id => 0,
        user_id => 0,
    } );

    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => '#',
        limit => $limit,
    );

    my %tag_lookup = map { $_ => 1 } @$tags;
    $weighted_tags = [ map { $tag_lookup{$_->[0]} ? () : $_ } @$weighted_tags ];

    $cloud->add_weighted_tags_array( $weighted_tags );
    return $cloud->template_params->{links};
}

sub _subgroup_icon_hash {
    my ( $self, $gid, $group, $width, $height ) = @_;

    my $meta = $self->_group_meta_to_data( $group );
    my $image = $meta->{image_attachment_id} ? $self->derive_url( action => 'groups', task => 'image', target => $group->id, additional => [ $width, $height || $width ] ) : '';

    return {
        name => $group->name,
        location => $meta->{location},
        url => $self->derive_url( action => 'subgroups', task => 'profile', target => $gid, additional => [ $group->id ] ),
        image => $image,
        'image_' . $width => $image,
    };
}

sub _subgroup_icon_hash_list {
    my ( $self, $gid, $groups, $width, $height ) = @_;

    return [ map { $self->_subgroup_icon_hash( $gid, $_, $width, $height ) } @$groups ];
}

1;

__END__
