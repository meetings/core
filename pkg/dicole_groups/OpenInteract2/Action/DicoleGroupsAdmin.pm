package OpenInteract2::Action::DicoleGroupsAdmin;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );
use DateTime::Format::ISO8601;

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
}

sub detect {
    my ( $self ) = @_;

    my $tools = $self->_get_available_tools;
    my $tool = shift @$tools;
    die "security error" unless $tool;

    return $self->redirect( $tool->{url} );
}

sub info2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};

    my $group = CTX->lookup_object('groups')->fetch( $gid );
    my $meta = $self->_group_meta_to_data( $group );

    my $save_pressed = CTX->request->param('save');

    my $post_tags_old = CTX->lookup_action('tagging')->execute( 'get_tags_for_object_as_json', {
        object => $group,
        group_id => 0,
        user_id => 0,
    } ) || '[]';

    my $post_tags = $post_tags_old;

    my $can_manage_admin_only = $self->mchk_y( 'OpenInteract2::Action::DicoleSecurity', 'manage_admin_only' );

    my $group_types = [
        { value => 'usergroup', name => $self->_msg( 'Usergroup' ) },
        { value => 'workgroup', name => $self->_msg( 'Workgroup' ) },
        { value => 'organization', name => $self->_msg( 'Organization' ) },
        { value => 'class', name => $self->_msg( 'Class' ) },
        { value => 'course', name => $self->_msg( 'Course' ) },
        { value => 'project', name => $self->_msg( 'Project' ) },
        { value => 'administration', name => $self->_msg( 'Administration' ) },
        { value => 'section', name => $self->_msg( 'Section' ) },
        { value => 'common', name => $self->_msg( 'Common group' ) },
    ];

    my $parent_groups = $self->_get_valid_parent_hashes( $group->parent_id );

    if ( $save_pressed ) {
        $post_tags_old = CTX->request->param('tags_old');
        $post_tags = eval {
            CTX->lookup_action('tagging')->execute( merge_input_to_json_tags => {
                input => CTX->request->param('tags_add_tags_input_field'),
                json => CTX->request->param('tags'),
            } );
        };

        eval {
            my $tags = CTX->lookup_action('tagging');
            eval {
                $tags->execute( 'update_tags_from_json', {
                    object => $group,
                    group_id => 0,
                    user_id => 0,
                    json => $post_tags,
                    json_old => $post_tags_old,
                } );
            };
            $self->log('error', $@ ) if $@;
        };

        if ( CTX->request->param('group_photo_draft_id') ) {
            if ( $meta->{image_attachment_id} ) {
                CTX->lookup_action('attachments_api')->e( remove => {
                    attachment_id => $meta->{image_attachment_id},
                    object => $group,
                    group_id => 0,
                    user_id => 0,
                } );
            }

            my $attachment_id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => CTX->request->param('group_photo_draft_id'),
                object => $group,
                group_id => 0,
                user_id => 0,
            } );

            $meta->{image_attachment_id} = $attachment_id || 0;
        }

        if ( CTX->request->param('group_custom_banner_draft_id') ) {
            if ( $meta->{banner_attachment_id} ) {
                CTX->lookup_action('attachments_api')->e( remove => {
                    attachment_id => $meta->{banner_attachment_id},
                    object => $group,
                    group_id => 0,
                    user_id => 0,
                } );
            }

            my $attachment_id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => CTX->request->param('group_custom_banner_draft_id'),
                object => $group,
                group_id => 0,
                user_id => 0,
            } );

            $meta->{banner_attachment_id} = $attachment_id || 0;
        }

        $group->name( CTX->request->param('group_name') );
        $meta->{location} = CTX->request->param('group_location');
        $group->description( CTX->request->param('group_description') );

        $meta->{facebook} = CTX->request->param('group_facebook');
        $meta->{myspace} = CTX->request->param('group_myspace');
        $meta->{twitter} = CTX->request->param('group_twitter');
        $meta->{youtube} = CTX->request->param('group_youtube');
        $meta->{webpage} = CTX->request->param('group_webpage');

        $self->_group_data_to_meta( $group, $meta );

        my $vis = CTX->request->param('group_visibility');
        if ( $vis eq 'all' ) {
            $group->joinable( 1 );
            $self->_set_visible( $group, 1 );
        }
        elsif ( $vis eq 'none' ) {
            $group->joinable( 0 );
            $self->_set_visible( $group, 2 );
        }

        my $oldpid = $group->parent_id;

        if ( $can_manage_admin_only ) {
            $group->has_area( ( CTX->request->param('workspace_disabled') eq 'yes' ) ? 2 : 1 );
            my %valid_parents = map { $_->{value} => 1 } @$parent_groups;
            $group->parent_id( CTX->request->param('parent_group') ) if $valid_parents{ CTX->request->param('parent_group') };
            my %valid_types = map { $_->{value} => 1 } @$group_types;
            $group->type( CTX->request->param('group_type') ) if $valid_types{ CTX->request->param('group_type') };
            if ( my $aued = CTX->request->param('group_auto_user_email_domains') ) {
                my $original = $meta->{auto_user_email_domains};
                $meta->{auto_user_email_domains} = $aued;
                my %original_map = map { $_ => 1 } split /\s*\,\s*/, $original;
                for my $current ( split /\s*\,\s*/, $aued ) {
                    if ( ! $original_map{ $current } ) {
                        my $users = CTX->lookup_object('user')->fetch_group( {
                            where => 'email like ?',
                            value => [ '%@' . $current ],
                        } );

                        my $valid_users = Dicole::Utils::User->filter_list_to_domain_users( $users, $domain_id );

                        for my $user ( @$valid_users ) {
                            CTX->lookup_action('groups_api')->e( add_user_to_group => {
                                user_id => $user->id, group => $group, domain_id => $domain_id
                            } );
                        }
                    }
                }
            }
            else {
                delete $meta->{auto_user_email_domains};
            }

            $self->_group_data_to_meta( $group, $meta );
        }

        $group->save;

        $self->_fix_parent_loop( $group, $oldpid, $group->parent_id );
        $self->_post_group_modify( $group );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg('Group updated') );
        $self->redirect( $self->derive_url );
    }

    $self->_init_visible( $group );

    $params = {
        %$params,
        group_image => $meta->{image_attachment_id} ? $self->derive_url( action => 'groups', task => 'image', additional => [] ) : '',
        group_custom_banner => $meta->{banner_attachment_id} ? $self->derive_url( action => 'groups', task => 'banner', additional => [] ) : '',
        group_name => $group->name,
        group_location => $meta->{location},
        group_description => $group->description,
        tags_json => $post_tags,
        tags_old_json => $post_tags_old,
        tags => [],
        group_facebook => $meta->{facebook},
        group_myspace => $meta->{myspace},
        group_twitter => $meta->{twitter},
        group_youtube => $meta->{youtube},
        group_webpage => $meta->{webpage},
        group_auto_user_email_domains => $meta->{auto_user_email_domains},
        group_visibility => $group->{visible} == 1 ? 'all' : 'none',
        workspace_disabled => ( $group->has_area == 2 ) ? 'yes' : 'no',
        group_type => $group->type,
        group_types => $group_types,
        parent_group => $group->parent_id,
        parent_groups => $parent_groups,

        show_admin_settings => $can_manage_admin_only,
    };

    return $self->_generate_default_admin_boxes( 'info', $globals, $params );
}

sub resources2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};

    my $resource_filters = [
        { id => 'all_show', name => 'All show', object_like => '%', act_like => 'show' },
        { id => 'blog', name => 'Post show', object_like => 'OpenInteract2::BlogsEntry', act_like => 'show' },
        { id => 'media', name => 'Media show', object_like => 'OpenInteract2::PresentationsPrese', act_like => 'show' },
        { id => 'wiki', name => 'Page show', object_like => 'OpenInteract2::WikiPage', act_like => 'show' },
        { id => 'event', name => 'Event show', object_like => 'OpenInteract2::EventsEvent', act_like => 'show' },
        { id => 'all_download', name => 'All downloads', object_like => '%', act_like => 'download' },
    ];

    my %filters_by_id = map { $_->{id} => $_ } @$resource_filters;

    my $selected = CTX->request->param('filter') || 'all_show';
    $selected = 'all_show' unless $filters_by_id{ $selected };

    my $filter_ip_list_string = CTX->request->param('filter_ip_list_string') || '';

    if ( CTX->request->param('set') ) {
        return $self->redirect( $self->derive_url( params => {
            to_string => CTX->request->param('set_to_string'),
            from_string => CTX->request->param('set_from_string'),
            filter => $selected,
            filter_ip_list_string => $filter_ip_list_string,
        } ) );
    }

    if ( ! CTX->request->param('from_string') || ! CTX->request->param('to_string') ) {
        return $self->redirect( $self->derive_url( params => {
            to_string => DateTime->now->ymd,
            from_string => DateTime->now->subtract( months => 1 )->ymd,
            filter => $selected,
            filter_ip_list_string => $filter_ip_list_string,            
        } ) );        
    }

    my $from_dt = DateTime::Format::ISO8601->parse_datetime( CTX->request->param('from_string') );
    my $to_dt = DateTime::Format::ISO8601->parse_datetime( CTX->request->param('to_string') );

    for my $dt ( $from_dt, $to_dt) {
        $dt->hour( 0 );
        $dt->second( 0 );
        $dt->minute( 0 );
    }
    $to_dt->add( days => 1 )->subtract( seconds => 1 );

    my $from_epoch = $from_dt->epoch;
    my $to_epoch = $to_dt->epoch;
    my $from_string = $from_dt->ymd;
    my $to_string = $to_dt->ymd;

    my $filter_links = [];
    for my $filter ( @$resource_filters ) {
        push @$filter_links, {
            selected => ( $selected eq $filter->{id} ) ? 1 : 0,
            name => $filter->{name},
            link => $self->derive_url(
                params => { from_string => $from_string, to_string => $to_string, filter => $filter->{id}, filter_ip_list_string => $filter_ip_list_string },
            ),
        };
    }

    my $acts = CTX->lookup_object('object_activity')->fetch_group({
        where => 'domain_id = ? AND target_group_id = ? AND time > ? AND time < ? AND object_type LIKE ? AND act LIKE ?',
        value => [ $domain_id, $gid, $from_epoch, $to_epoch, $filters_by_id{$selected}{object_like}, $filters_by_id{$selected}{act_like} ],
    });

    my @filtered_ips = split /\s*\,\s*/, $filter_ip_list_string;
    my %filtered_ip_lookup = map { $_ ? ( $_ => 1 ) : () } @filtered_ips;

    my %distinct_acts = ();
    for my $a ( @$acts ) {
        next if $a->user_agent =~ /bot/i;
        next if $filtered_ip_lookup{ $a->from_ip };
        my $dt = DateTime->from_epoch( epoch => $a->time );
        my $stamp = $dt->ymd . $a->user_id;
        $stamp .= $a->from_ip unless $a->user_id;

        $distinct_acts{ $a->object_type }{ $a->object_id }{ $stamp }++;
    }

    my $results = [];
    for my $type ( keys %distinct_acts ) {
        my $ids = $distinct_acts{ $type };
        for my $id ( keys %$ids ) {
            my $stamps = $ids->{$id};
            my $data = $self->_object_data( $type , $id );
            next unless $data; 
            push @$results, {
                %$data,
                count => scalar( keys %$stamps ),
            };
        } 
    }

    $params = {
        %$params,
        filter_ip_list_string => $filter_ip_list_string,
        show_type => ( $filters_by_id{ $selected }{id} =~ /all/ ) ? 1 : 0,
        to_string => $to_string,
        from_string => $from_string,
        filter_links => $filter_links,
        results => [ sort { $b->{count} <=> $a->{count} } @$results ],
    };

    return $self->_generate_default_admin_boxes( 'resources', $globals, $params );
}

sub _object_data {
    my ( $self, $class, $id ) = @_;

    my $o = eval { $class->fetch( $id ) };
    return unless $o;

    my $keys = {
        'OpenInteract2::WikiPage' => {
            type => 'Page',
            creator_field => 'creator_id',            
            url_parts => {
                action => 'wiki',
                task => 'show_by_id',
            },
            name_sub => sub { return $_[0]->readable_title },
        },
        'OpenInteract2::EventsEvent' => {
            type => 'Event',
            creator_field => 'creator_id',            
            url_parts => {
                action => 'events',
                task => 'show',
            },
            name_sub => sub { return $_[0]->title },
        },
        'OpenInteract2::PresentationsPrese' => {
            type => 'Media',
            creator_field => 'creator_id',            
            url_parts => {
                action => 'presentations',
                task => 'show',
            },
            name_sub => sub { return $_[0]->name },
        },
        'OpenInteract2::BlogsEntry' => {
            type => 'Post',
            creator_field => 'user_id',
            url_parts => {
                action => 'blogs',
                task => 'show',
                additional => [ 0 ],
            },
            name_sub => sub {
                my $o = $_[0];
                my $post = CTX->lookup_object('weblog_posts')->fetch( $o->post_id );
                return $post ? $post->title : '?',  
            },
        },
    };

    return unless $keys->{ $class };
    my $up = $keys->{ $class }->{url_parts};

    $up->{additional} ||= []; 
    push @{ $up->{additional} }, $o->id;
    return {
        type => $keys->{ $class }->{type},
        creator => eval { Dicole::Utils::User->name( $o->get( $keys->{ $class }->{creator_field} ) ) } || '?',
        link => $self->derive_url( %$up ),
        name => $keys->{ $class }->{name_sub}( $o ),
    };
}

sub users2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group = CTX->lookup_object('groups')->fetch( $gid );
    my $params = {};

    my $users = $self->_fetch_group_users( $gid );

    my $profile_map = CTX->lookup_action('networking_api')->e( user_profile_object_map => { 
        user_id_list => [ map { $_->id } @$users ],
        domain_id => $domain_id,
    } );

    my $user_coll_map = $self->_user_special_rights_hash_for_group( $gid );
    my $admin_coll = $self->_admin_collection_id;
    my $mode_coll = $self->_moderator_collection_id;

    my $user_hashes = [];
    for my $user ( sort { lc( $a->{last_name} ) cmp lc( $b->{last_name} ) } @$users ) {
        my $icon_hash = Dicole::Utils::User->icon_hash( $user, 40, $gid, $domain_id, $profile_map->{$user->id} );

        my $level = $self->_determine_user_level_in_group(
            $user->id, $gid, $user_coll_map, $mode_coll, $admin_coll
        );

        my $levels = [ $level ];
        my $remove_url = '';

        if ( CTX->request->auth_user_id == $group->creator_id ) {
            $levels = $self->USER_LEVELS;
            $remove_url = $self->derive_url( action => 'groups_admin_json', task => 'remove_user', additional => [ $user->id ] );
        }
        elsif  ($user->id == $group->creator_id  ) {
                $levels = [ 'admin' ];
        }
        elsif ( $self->mchk_y('OpenInteract2::Action::Groups', 'users') ) {
            $levels = ['admin', 'moderator', 'user' ];
            $remove_url = $self->derive_url( action => 'groups_admin_json', task => 'remove_user', additional => [ $user->id ] );
        }
        elsif ( $user_coll_map->{ CTX->request->auth_user_id }{ $mode_coll } ) {
            if ( $level eq 'admin' ) {
                $levels = [ 'admin' ];
            }
            else {
                $levels = ['user', 'moderator'];
                $remove_url = $self->derive_url( action => 'groups_admin_json', task => 'remove_user', additional => [ $user->id ] );
            }
        }

        my $hash = {
            %$icon_hash,
            id => $user->id,
            email => $user->email,
            level => $level,
            levels => $levels,
            remove_url => $remove_url,
        };
        push @$user_hashes, $hash;
    }

    $params->{levels} = [];
    push @{ $params->{levels} }, { id => $_, name => $self->USER_LEVEL_NAMES->{$_} } for @{ $self->USER_LEVELS };

    $params->{users} = $user_hashes;
    $params->{mail_url} = $self->derive_url( action => 'groups_admin_json', task => 'mail_users' );
    $params->{mail_self_url} = $self->derive_url( action => 'groups_admin_json', task => 'mail_self' );
    $params->{export_url} = $self->derive_url( action => 'groups_admin_raw', task => 'export_users_xls' );
 
    my $globals = {
        update_rights_url => $self->derive_url( action => 'groups_admin_json', task => 'update_rights' ),
    };

    return $self->_generate_default_admin_boxes( 'users', $globals, $params );
}

sub tools2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};



    return $self->_generate_default_admin_boxes( 'tools', $globals, $params );
}

sub localizations2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};



    return $self->_generate_default_admin_boxes( 'localizations', $globals, $params );
}

sub reports2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};



    return $self->_generate_default_admin_boxes( 'reports', $globals, $params );
}

sub look2 {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $params = {};
    my $globals = {};

    my $tool = 'navigation';
    $tool .= '_' . $domain_id if $domain_id;

    if ( CTX->request->param('save') ) {
        $params->{custom_css} = Dicole::Settings->store_single_setting(
            tool => $tool,
            group_id => $gid,
            attribute => 'custom_css',
            value => CTX->request->param('custom_css') 
        );
    }

    $params->{custom_css} = Dicole::Settings->fetch_single_setting(
        tool => $tool,
        group_id => $gid,
        attribute => 'custom_css',
    );

    return $self->_generate_default_admin_boxes( 'look', $globals, $params );
}

sub _generate_default_admin_boxes {
    my ( $self, $task, $globals, $params, $override_selected_task ) = @_;

    $self->_default_tool_init( ( $globals ? ( globals => $globals ) : () ) );

    $self->tool->add_tinymce_widgets if $task eq 'users';

    my $tools = $self->_get_available_tools;

    my %tool_by_task = map { $_->{task} => $_->{name} } @$tools;

    $_->{class} = 'admin_navi_' . $_->{action} . '_' . $_->{task} for @$tools;

    my $navi_params = {
        tasks => $tools,
        selected_task => $override_selected_task || $task . '2',
    };

    if ( $task =~ /^users/ && $self->mchk_y( 'OpenInteract2::Action::DicoleInvite', 'invite' ) ) {

        $self->tool->action_buttons( [ {
            name => $self->_msg('Invite'),
            class => 'networking_invite_action js_hook_open_invite',
            url => $self->derive_url( action => 'invite', task => 'invite' ),
        } ] );

        my $g = $self->param('target_group');

        $self->tool->add_js_variables( {
            invite_dialog_data_url => $self->derive_url(
                action => 'invite_json', task => 'dialog_data', additional => []
            ),
            invite_levels_dialog_data_url => $self->derive_url(
                action => 'invite_json', task => 'levels_dialog_data', additional => []
            ),
             invite_submit_url => $self->derive_url(
                action => 'invite_json', task => 'invite', additional => []
            ),
            invite_default_subject => $g ? $self->_msg('You have been invited to [_1]', $g->name ) : '',
        } );
    }

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Navigation' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'groups_left_admin_navi groups_left_admin_navi_' . $task );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $navi_params, { name => 'dicole_groups::component_groups_left_admin_navi' } )
        ) ]
    );

    $params->{dump} = Data::Dumper::Dumper( $params );

    $self->tool->Container->box_at( 1, 0 )->name( $tool_by_task{ $task . '2' } );
    $self->tool->Container->box_at( 1, 0 )->class( 'groups_right_admin_' . $task );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_groups::component_groups_right_admin_' . $task } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _get_available_tools {
    my ( $self ) = @_;

    my $tools = [
        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'groups_admin', task => 'info2', name => $self->_msg('General settings') } ) : (),

#         $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
#             ( { action => 'workgroupsadmin', task => 'info', name => $self->_msg('Additional settings') } ) : (),

        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'workgroupsadmin', task => 'tools', name => $self->_msg('Tools') } ) : (),



        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'groups_admin', task => 'users2', name => $self->_msg('Users') } ) : (),

#         $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
#             ( { action => 'workgroupsadmin', task => 'users', name => $self->_msg('Add and remove users') } ) : (),

        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'workgroupsadmin', task => 'member_rights', name => $self->_msg('Default rights') } ) : (),

        ( $self->mchk_y('OpenInteract2::Action::Groups', 'users') && $self->mchk_y( 'OpenInteract2::Action::DicoleSecurity', 'manage_admin_only' ) ) ? 
            ( { action => 'groupcustomsecurity', task => 'member_list', name => $self->_msg('Custom user rights') } ) : (),

#         $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
#             ( { action => 'mail_members', task => 'send', name => $self->_msg('Mail members') } ) : (),


        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'group_reports', task => 'list_weekly', name => $self->_msg('User reports') } ) : (),

        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'groups_admin', task => 'resources2', name => $self->_msg('Resource reports') } ) : (),

        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'localization', task => 'customize', name => $self->_msg('Localizations') } ) : (),

        $self->mchk_y('OpenInteract2::Action::Groups', 'users') ? 
            ( { action => 'groups_admin', task => 'look2', name => $self->_msg('Custom CSS') } ) : (),

    ];

    $_->{url} = $self->derive_url( action => $_->{action}, task => $_->{task}, additional => [] ) for @$tools;

    return $tools;
}

1;

__END__
