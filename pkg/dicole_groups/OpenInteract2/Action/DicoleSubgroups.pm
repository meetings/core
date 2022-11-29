package OpenInteract2::Action::DicoleSubgroups;

use strict;

use base qw( OpenInteract2::Action::DicoleSubgroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _summary_browser {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $sections = $self->_fetch_sections( $gid );
    my $pgids = $self->_sections_to_parent_ids( $gid, $sections, 'all' );
    my $all_visible_groups = $self->_fetch_visible_groups( $pgids );

    $sections = [ { id => 'all', selected => 1, name => $self->_msg('All') } ] unless scalar( @$sections );

    my $first_selected = 0;
    for my $section ( @$sections ) {
        $section->{url} = $self->derive_url( action => 'subgroups', task => 'explore', target => $gid, additional => [ $section->{id} ] );
        $section->{selected} = ( $first_selected++ ) ? 0 : 1;

        my $visible_groups = ( $section->{id} eq 'all' ) ?
            $all_visible_groups :
            [ map { ( $_->parent_id eq $section->{id} ) ? $_ : () } @$all_visible_groups ];

        my $most_active_groups = CTX->lookup_action('statistics')->execute( get_most_active_groups => {
            domain_id => $domain_id,
            from_groups => $visible_groups,
            limit => 4,
        } ) || [];
    
        # append some new groups after active groups if active groups is less than 4 :)
        if ( @$most_active_groups < 4 ) {
            my %found_groups = map { $_->id => 1 } @$most_active_groups;
            my $new_group_objects = [ map { $found_groups{$_->id} ? () : $_ } @$visible_groups ];
            push @$most_active_groups, shift @$new_group_objects while scalar( @$new_group_objects ) && @$most_active_groups < 4;
        }

        $section->{areas} = [];
        for my $group ( @$most_active_groups ) {
            push @{ $section->{areas} }, {
                %{ $self->_subgroup_icon_hash( $gid, $group, 400, 300 ) },
                number_of_members => $self->_group_member_count( $group->id ),
            };
        }
    }

    my $params = {
        sections => $sections,
        more_url => Dicole::URL->from_parts( action => 'subgroups', task => 'detect', target => $gid, domain_id => $domain_id ),
    };

#    $params->{dump} = Data::Dumper::Dumper( $params );
#    get_logger(LOG_APP)->error($params->{dump});

    my $content = $self->generate_content( $params, { name => 'dicole_groups::summary_browser' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Groups (summary title)') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });
    $self->tool->Container->column_width( '280px', 1 );
    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/dicole_groups.css' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Raw->new( raw => '<!--[if lt IE 7]><link rel="stylesheet" href="/css/dicole_groups_ie6.css" media="all" type="text/css" /><![endif]-->' . "\n" ),
    );
    $self->tool->add_head_widgets( Dicole::Widget::Javascript->new(
        code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $params{globals} ) . ');'
    ) ) if $params{globals};

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.groups");' ),
    );

    # TODO: some other wayto control subgroup creation that matching to type organization...
    $self->tool->action_buttons( [ {
        name => $self->_msg('Create area'),
        class => 'subgroups_create_area' .
            ( eval { ( $self->param('target_group')->type eq 'organization' ) ? ' js_open_create_subgroup' : '' } || '' ),
        url => $self->derive_url( action => 'groups', task => 'add', additional => [] ),
    } ] ) if $self->mchk_y( 'OpenInteract2::Action::Groups', 'create_subgroup' ) && ( $self->task eq 'explore' || $self->task eq 'browse' );

}

sub detect {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_url( task => 'explore' ) );
}

sub explore {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $section = $self->param('section') || '';
    $section = 'all' unless $section =~ /^\d+$/;
    my $sections = $self->_fetch_sections( $gid );
    my $pgids = $self->_sections_to_parent_ids( $gid, $sections, $section );
    my $visible_groups = $self->_fetch_visible_groups( $pgids );
    my $visible_groups_ids = [ map { $_->id } @$visible_groups ];

    my $params = {
        sections => $self->_add_all_and_urls_to_sections( $sections, $section ),
        show_all_url => $self->derive_url( task => 'browse', additional => [ $section ] ),
    };

    my $new_groups = [ sort { $b->{created_date} <=> $a->{created_date} } @$visible_groups ];
    my $most_recent_groups = [ splice( @$new_groups, 0, 6 ) ];

    $params->{recent_groups} = $self->_subgroup_icon_hash_list( $gid, $most_recent_groups, 80, 60 );

    my $most_active_groups = CTX->lookup_action('statistics')->execute( get_most_active_groups => {
        domain_id => $domain_id,
        from_groups => $visible_groups,
        limit => 5,
    } ) || [];

    if ( @$most_active_groups < 4 ) {
        my %found_groups = map { $_->id => 1 } @$most_active_groups;
        my $new_group_objects = [ map { $found_groups{$_->id} ? () : $_ } @$visible_groups ];
        push @$most_active_groups, shift @$new_group_objects while scalar( @$new_group_objects ) && @$most_active_groups < 4;
    }

    $params->{most_active_groups} = $self->_subgroup_icon_hash_list( $gid, $most_active_groups, 120, 90 );


    my $wtags = CTX->lookup_action('tagging')->execute( get_query_limited_weighted_tags => {
        group_id => 0,
        user_id => 0,
        domain_id => $domain_id,
        object_class => CTX->lookup_object('groups'),
        where => Dicole::Utils::SQL->column_in( 'dicole_groups.groups_id' => $visible_groups_ids ),
        value => [],
    } );

    my $widget = Dicole::Widget::TagCloud->new(
        prefix => $self->derive_url( task => 'browse', additional => [ 'all' ] ),
        limit => 60,
    );
    $widget->add_weighted_tags_array( $wtags );
    $params->{filter_tags} = $widget->template_params->{links};

    $params->{dump} = Data::Dumper::Dumper( $params );

    my $globals = {
        subgroups_create_url => $self->derive_url(
            action => 'subgroups_json', task => 'create', additional => []
        ),
    };
    $self->_default_tool_init( globals => $globals );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Newest groups' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'subgroups_newest' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_subgroups_newest_left' } )
        ) ]
    );
    $self->tool->Container->box_at( 1, 0 )->class( 'subgroups_explore' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_subgroups_explore_right' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub browse {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $section = $self->param('section') || '';
    $section = 'all' unless $section =~ /^\d+$/;
    my $tag = $self->param('tag');

#     unless ( $section ) {
#         return $self->redirect( $self->derive_url( additional => [ 'all', $tag ? ( $tag ) : () ] ) );
#     }

    my $state = { tags => $tag ? [ $tag ] : [], section => $section };
    my $info = $self->_fetch_group_list_info( $gid, $domain_id, $self->DEFAULT_PROFILE_LIST_SIZE, $state );

    $state = $info->{state};
    my $links = $self->_fetch_group_filter_links( $gid, $domain_id, 50, $state );

    my $params = {
        sections => $self->_add_all_and_urls_to_sections( $info->{sections}, $section ),
        keywords => [ map { { name => $_ } } @{ $state->{tags} || [] } ],
        suggestions => $links,
        groups => $info->{object_info_list},
        result_count => $info->{count},
        end_of_pages => $info->{end_of_pages},

        subgroups_create_url => $self->derive_url(
            action => 'subgroups_json', task => 'create', additional => []
        ),
    };

    my $new_groups = [ sort { $b->{created_date} <=> $a->{created_date} } @{ $info->{visible_groups} } ];
    my $most_recent_groups = [ splice( @$new_groups, 0, 6 ) ];

    $params->{recent_groups} = $self->_subgroup_icon_hash_list( $gid, $most_recent_groups, 80, 60 );

    $params->{dump} = Data::Dumper::Dumper( $params );

    my $globals = {
        subgroups_groups_state => Dicole::Utils::JSON->encode( $state ),
        subgroups_keyword_change_url => $self->derive_url(
            action => 'subgroups_json', task => 'keyword_change', additional => [ $section ]
        ),
        subgroups_more_groups_url => $self->derive_url(
            action => 'subgroups_json', task => 'more_groups', additional => []
        ),
        subgroups_end_of_pages => $info->{end_of_pages},
    };

    $self->_default_tool_init( globals => $globals );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Newest groups' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'subgroups_newest' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_subgroups_newest_left' } )
        ) ]
    );
#    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( '' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'subgroups_browse' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_subgroups_browse_right' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _add_all_and_urls_to_sections {
    my ( $self, $sections, $selected ) = @_;

    for my $section ( @$sections ) {
        $section->{url} = $self->derive_url( additional => [ $section->{id} ] );
        $section->{selected} = ( $section->{id} eq $selected ) ? 1 : 0;
    }

    if ( scalar( @$sections ) ) {
        unshift @$sections, { id => 'all', name => $self->_msg('All'), url => $self->derive_url( additional => [ 'all' ] ), selected => ( $selected eq 'all' ) ? 1 : 0 };
    }

    return $sections;
}

sub profile {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $subgroup_id = $self->param('subgroup_id');
    my $group = CTX->lookup_object('groups')->fetch( $subgroup_id );
    my $meta = $self->_group_meta_to_data( $group );

    my $tags = CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
        object => $group,
        group_id => 0,
        user_id => 0,
    } ) || '[]';
    
    my $params = {};
    $params = {
        %$params,
        group_image => $meta->{image_attachment_id} ? $self->derive_url( action => 'groups', task => 'image', target => $group->id, additional => [200,150] ) : '',
        group_name => $group->name,
        group_location => $meta->{location},
        group_description => $group->description,
        tags =>   [ map { {
            name => $_, link => $self->derive_url( action => 'subgroups', task => 'browse', additional => [ 'all', $_ ] )
        } } @$tags ],
        group_facebook => $meta->{facebook_link},
        group_myspace => $meta->{myspace_link},
        group_twitter => $meta->{twitter_link},
        group_youtube => $meta->{youtube_link},
        group_webpage => $meta->{webpage_link},
    };

    my $group_user_objects = CTX->lookup_object('group_user')->fetch_group( {
        where => 'groups_id = ?',
        value => [ $group->id ],
    } );

    my @uids = map { $_->user_id } @$group_user_objects;
    my %uids_map = map { $_ => 1 } @uids;
    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => \@uids ),
    } );

    my $user_coll_map = $self->_user_special_rights_hash_for_group( $group->id );
    my $admin_coll = $self->_admin_collection_id;
    my $mode_coll = $self->_moderator_collection_id;

    my @fans = ();
    my @members = ();

    for my $user ( @$users ) {
        if ( $user_coll_map->{ $user->id }{ $admin_coll } || $user_coll_map->{ $user->id }{ $mode_coll } ) {
            push @members, $user;
        }
        else {
            push @fans, $user;
        }
    }

    $params->{admins} = Dicole::Utils::User->icon_hash_list( \@members, 95, $gid, $domain_id );
    $params->{members} = Dicole::Utils::User->icon_hash_list( \@fans, 50, $gid, $domain_id );

    $params->{edit_url} = 1 ? $self->derive_url( action => 'groups_admin', task => 'info2', target => $group->id, additional => [] ) : '';

    my $user_can_join = CTX->request->auth_user_id && ! $uids_map{ CTX->request->auth_user_id } ? 1 : 0;
    $params->{join_url} = $user_can_join ? $self->derive_url( action => 'groups', task => 'join_group', target => $group->id, additional => [] ) : '';
    my $user_can_enter = CTX->request->auth_user_id && $uids_map{ CTX->request->auth_user_id } ? 1 : 0;
    $params->{enter_url} = $user_can_enter ? $self->derive_url( action => 'groups', task => 'starting_page', target => $group->id, additional => [] ) : '';

    my $globals = {
        subgroups_create_url => $self->derive_url(
            action => 'subgroups_json', task => 'create', additional => []
        ),
    };

    $self->_default_tool_init( globals => $globals );

    $params->{dump} = Data::Dumper::Dumper( $params );

#    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( '' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'subgroups_profile' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_subgroups_profile_right' } )
        ) ]
    );

    return $self->generate_tool_content;
}

1;

__END__
