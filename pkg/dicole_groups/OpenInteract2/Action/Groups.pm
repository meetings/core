package OpenInteract2::Action::Groups;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Config::Ini;
use File::Spec;
use Dicole::Tool;
use Dicole::MessageHandler qw( :message );
use Dicole::Security qw( :receiver :target :check );
use Dicole::Files;
use Dicole::Utility;
use Dicole::Generictool::Data;
use Dicole::Generictool::Wizard;
use Dicole::Navigation::Tree;
use Dicole::Navigation::Tree::Element;
use Dicole::SessionStore;
use Dicole::URL;
use Dicole::Content::Horizontal;
use Dicole::Content::Image;
use Dicole::Widget::CategoryListing;
use Dicole::Widget::Raw;
use Dicole::Widget::Vertical;
use Dicole::Widget::LinkButton;
use Dicole::Utils::SQL;
use Dicole::Task::GTSettings;

use constant CONTROL_IMAGE_PATH => "/images/theme/default/navigation/controls";
use constant CONTROL_IMAGE_RES => "20x20";

sub image {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $group = CTX->lookup_object('groups')->fetch( $gid );
    my $meta = $self->_group_meta_to_data( $group );

    my $width = $self->param('width') || 200;
    my $height = $self->param('height') || 150;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $meta->{image_attachment_id},
        group_id => 0,
        user_id => 0,
        thumbnail => 1,
        force_width => $width,
        force_height => $height,
    } );
}

sub banner {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $group = CTX->lookup_object('groups')->fetch( $gid );
    my $meta = $self->_group_meta_to_data( $group );

    my $width = 300;
    my $height = 80;

    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $meta->{banner_attachment_id},
        group_id => 0,
        user_id => 0,
        thumbnail => 1,
        force_width => $width,
        force_height => $height,
    } );
}

sub _summary_info {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $group = CTX->lookup_object('groups')->fetch( $gid );

    my $meta = $self->_group_meta_to_data( $group );
    my $image = $meta->{image_attachment_id} ? $self->derive_url( action => 'groups', task => 'image', target => $group->id, additional => [ 240, 180 ] ) : '';

    my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
        object => $group,
        user_id => 0,
        group_id => 0,
        domain_id => $domain_id,
    } );

    my $params = {
        name => $group->name,
        location => $meta->{location},
        image => $image,
        description => Dicole::Utils::HTML->text_to_html( $group->description ),
        tags => $tags,
        number_of_members => $self->_group_member_count( $group->id ),
        myspace => $meta->{myspace_link},
        youtube => $meta->{youtube_link},
        twitter => $meta->{twitter_link},
        facebook => $meta->{facebook_link},
        webpage => $meta->{webpage_link},
    };

    $params->{dump} = Data::Dumper::Dumper( $params );
    my $content = $self->generate_content( $params, { name => 'dicole_groups::summary_info' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Group (summary title)') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}


###########################################
## previous interface

sub list {
    my ( $self ) = @_;

    my $tool = $self->init_tool( { cols => 2 } );

    $tool->Container->box_at( 0, 0 )->name( $self->_msg("Groups") );
    $tool->Container->box_at( 0, 0 )->add_content( $self->_tree_box );

#     my $list = [];
#     eval {
#         my $domains = CTX->lookup_action('dicole_domains');
#         $list = CTX->lookup_action('user_information_list')->execute( {
#             user_ids => $domains->users_by_domain || [],
#             browse_enabled => 1,
#             sort_by_activity => 1,
#         } );
#     };
#     if ( $@ ) {
#         $list = CTX->lookup_action('user_information_list')->execute( {
#             browse_enabled => 1,
#             sort_by_activity => 1,
#         } );
#     }
# 
#     $tool->Container->box_at( 1, 0 )->name( $self->_msg("People") );
#     $tool->Container->box_at( 1, 0 )->add_content( $list );

    return $self->generate_tool_content;
}

sub browse {
    my ( $self ) = @_;

    my $group = $self->param('target_group');
    unless ( $group && ( $self->chk_y('show_info') ||
            $group->creator_id == CTX->request->auth_user_id ) ) {
        return CTX->response->redirect( $self->derive_url( task => 'list', target => 0 ) );
    }

    my $rows = $self->chk_y('show_members') ? 2 : 1;

    my $tool = $self->init_tool( {
        cols => 2,
        rows => $rows,
        tab_override => 'list',
    } );

    $tool->Container->box_at( 0, 0 )->name( $self->_msg("Groups") );
    $tool->Container->box_at( 0, 0 )->add_content( $self->_tree_box );

    $tool->Container->box_at( 1, 0 )->name( $self->_msg("Group info") );
    $tool->Container->box_at( 1, 0 )->add_content( $self->_show_box );

    if ( $rows == 2 ) {

#         $tool->Container->box_at( 1, 1 )->name( $self->_msg("List of members") );
#         $tool->Container->box_at( 1, 1 )->add_content( $self->_members_box );
    }

    return $self->generate_tool_content;
}

sub show {
    my ( $self ) = @_;

    my $rows = $self->chk_y('show_members') ? 2 : 1;

    my $tool = $self->init_tool( {
        cols => 1,
        rows => $rows,
    } );

    $tool->Container->box_at( 0, 0 )->name( $self->_msg("Group info") );
    $tool->Container->box_at( 0, 0 )->add_content( $self->_show_box );

    if ( $rows == 2 ) {

        $tool->Container->box_at( 0, 1 )->name( $self->_msg("List of members") );
        $tool->Container->box_at( 0, 1 )->add_content( $self->_members_box );
    }

    return $self->generate_tool_content;
}

sub starting_page {
    my ( $self ) = @_;

    my $custom_url = Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'custom_starting_page',
        group_id => $self->param('target_group_id')
    );

    $self->redirect( $custom_url || Dicole::URL->create_from_parts(
        action => 'groupsummary',
        task => 'summary',
        target => $self->param('target_group_id'),
    ));
}

sub join_group {
    my ( $self ) = @_;

    my $group = $self->param('target_group');
    die "security error" unless $group && $group->joinable == 1;
    
    CTX->lookup_action('groups_api')->execute( add_user_to_group => {
        user_id => CTX->request->auth_user_id,
        group => $group,
    } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
          $self->_msg('Area joined')
    );

    if ( CTX->request && CTX->request->param('url_after_join') ) {
        $self->redirect( CTX->request->param('url_after_join') );
    }
    
    return $self->redirect( $self->derive_url( task => 'starting_page' ) );
}

sub _tree_box {
    my ( $self ) = @_;

    my $creator = new Dicole::Tree::Creator::Hash (
        id_key => 'groups_id',
        parent_id_key => 'parent_id',
        order_key => '',
        parent_key => '',
        sub_elements_key => 'sub_elements',
    );

    my $group_icons = OpenInteract2::Config::Ini->new({ filename => File::Spec->catfile(
        CTX->repository->full_config_dir, 'dicole_groups', 'group_icons.ini'
    ) });

    my $tree = Dicole::Navigation::Tree->new(
        root_name  => $self->_msg('Community'),
        selectable => 0,
        tree_id    => 'user_groups',
        folders_initially_open => 1,
        no_collapsing => 1,
        no_root_select => 1,
        icon_files => $group_icons->{group_icons},
    );

    $tree->root_href( $self->derive_url(
        task => 'list', target => 0
    ) );

    my $limited_groups = $self->_get_limited_groups;

    if ( ref($limited_groups) eq 'ARRAY' && @{ $limited_groups } > 0 ) {
        $creator->add_element_array(
            CTX->lookup_object('groups')->fetch_group( {
                where => Dicole::Utils::SQL->column_in(
                    'groups_id', $limited_groups
                ),
                order => 'name'
            } )
        );
    }
    elsif ( ref($limited_groups) eq 'ARRAY' ) {
        $creator->add_element_array( [] );
    }
    else {
        $creator->add_element_array(
            CTX->lookup_object('groups')->fetch_group( {
                order => 'name'
            } )
        );
    }

    $self->_rec_create_tree($tree, undef, $creator->create );

    return $tree->get_tree;
}

sub _rec_create_tree {
    my ($self, $tree, $parent, $array) = @_;

    return if ref $array ne 'ARRAY';

    foreach my $group (@$array) {

        next unless $self->chk_y( 'show_info', $group->{groups_id} ) ||
            $group->{creator_id} == CTX->request->auth_user_id;

        my $element = Dicole::Navigation::Tree::Element->new(
            parent_element => $parent,
            element_id => $group->{groups_id},
            name => $group->{name},
            type => $group->{type},
            override_link => $self->derive_url(
                task => 'browse',
                target => $group->{groups_id}
            ),
        );

        $tree->add_element( $element );

        $self->_rec_create_tree( $tree, $element, $group->{sub_elements} );
    }
}

# TODO: Add a button for recovering lost group creator rights.

sub _show_box {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $group = eval { CTX->lookup_object('groups')->fetch( $gid ) };

    if ( ! $group ) {
        $self->tool->add_message( MESSAGE_ERROR, $self->_msg( "No such group ( id '[_1]' ) found!", $gid ) );
        return; # where to redirect?
    }

    my $auth_membership = $group->user(
        { where => 'user_id = ?', value => [ $uid ] }
    ) || [];

    my $is_member = scalar @$auth_membership;

    if ( CTX->request->param('join') ) {

        if ($is_member) {
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg('You already are a group member!'));
        }
        elsif ( $group->{joinable} == 1 || $group->{creator_id} == $uid ) {

            CTX->lookup_action('add_user_to_group')->execute( {
                group => $group, user_id => CTX->request->auth_user_id
            } );

            $is_member = 1;

            # empty groups variables so that they get reloaded when
            # requested the next time
            CTX->request->auth_user_groups( '' );
            CTX->request->auth_user_groups_by_id( '' );
            CTX->request->auth_user_groups_ids( '' );

            $self->tool->add_message(MESSAGE_SUCCESS, $self->_msg('Join succesful!'));
            $self->redirect( $self->derive_url );
        }
        elsif ( $group->{joinable} == 2 ) {
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg('Applying not yet implemented!'));
        }
        elsif ( $group->{joinable} == 3 ) {
            get_logger( LOG_ACTION )->warn( "Join attempt on closed group $gid" );
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg("You can't join this group!"));
        }
        else {
            get_logger( LOG_ACTION )->error( "Could not determine groups $gid join policy" );
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg("Could not detect join policy: Can't join!"));
        }
    }
    elsif ( CTX->request->param('remove') ) {
        if (! $self->chk_y('remove') ) {
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg('You are not allowed to remove the group!'));
        }
        else {
            my $subgroups = CTX->lookup_object('groups')->fetch_group({
                where => 'parent_id = ?',
                value => [ $group->id ],
            }) || [];

            if (scalar(@$subgroups)) {
                $self->tool->add_message(MESSAGE_ERROR, $self->_msg('You can not remove the group as long as it has subgroups!'));
            }
            else {
                $self->_remove_group( $group );
                $self->tool->add_message(MESSAGE_SUCCESS, $self->_msg('Group removed.'));

                my $redirect = Dicole::URL->create_from_parts(
                    action => 'groups',
                    task => 'list',
                );
                return CTX->response->redirect( $redirect );
            }
        }
    }


    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('groups'),
            current_view => 'show'
        )
    );

    $self->init_fields;
    $self->_init_visible( $group );
#    $self->_init_parent_id( undef, 'all' );


    $self->gtool->add_bottom_buttons( [
        {
            value => $self->_msg('Edit info'),
            type => 'link',
            link => $self->derive_url(
                action => 'groups',
                task => 'info',
            ),
        }
    ] ) if $self->chk_y( 'info' );

    $self->gtool->add_bottom_buttons( [
        {
            value => $self->_msg('Edit member rights'),
            type => 'link',
            link => $self->derive_url(
                action => 'groups',
                task => 'member_rights',
            ),
        }
    ] ) if $self->name eq 'groups' && $self->chk_y( 'select' );


    if ( ! $is_member && (
            $group->{joinable} == 1 ||
            $group->{joinable} == 2 ||
            $group->{creator_id} == $uid ) ) {

        my $value = ( $group->{joinable} == 1 ||
            $group->{creator_id} == $uid ) ?
           $self->_msg('Join group') :
           $self->_msg('Apply to group');

        $self->gtool->add_bottom_buttons( [
            {
                value => $value,
                name => 'join',
            }
        ] );
    }

    $self->gtool->add_bottom_buttons( [
        {
            value => $self->_msg('Go to work area'),
            type => 'link',
            link => Dicole::URL->create_from_parts(
                action => 'groups',
                task => 'starting_page',
                target => $group->id,
            )
        }
    ] ) if $self->name ne 'workgroups' && $group->has_area == 1 &&
        $self->mchk_y( 'OpenInteract2::Action::DicoleGroupsSummary', 'read' );

    $self->gtool->add_bottom_buttons( [
        {
            value => $self->_msg('Create a subgroup'),
            type => 'link',
            link => Dicole::URL->create_from_parts(
                action => 'groups',
                task => 'add',
                target => $group->id,
            )
        },
    ] ) if $self->chk_y( 'create_subgroup' );

    $self->gtool->add_bottom_buttons( [
        {
            type => 'confirm_submit',
            value => $self->_msg('Part group'),
            name => 'part',
            confirm_box => {
                title => $self->_msg( 'Part group' ),
                name => 'part_group',
                msg   => $self->_msg( 'Are you sure you want to part this group?' ),
                href  => Dicole::URL->create_from_parts(
                    action => 'groups',
                    task => 'part',
                    target => $group->id,
                )
            }
        }
    ] ) if $is_member;

    $self->gtool->add_bottom_buttons( [
        {
            type => 'confirm_submit',
            value => $self->_msg('Remove group'),
            name => 'remove_group',
            confirm_box => {
                value => $self->_msg('Remove group'),
                name => 'remove',
                msg   => $self->_msg( 'Are you sure you want to remove this group?' ),
            }
        }
    ] ) if $self->chk_y( 'remove' );

    return $self->gtool->get_show( object => $group );
}

sub part {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $group = eval { CTX->lookup_object('groups')->fetch( $gid ) };

    if ( ! $group ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg( "No such group ( id '[_1]' ) found!", $gid ) );
        my $redirect = Dicole::URL->create_from_parts(
            action => 'groups',
            task => 'list',
        );
        return CTX->response->redirect( $redirect );
    }

    my $auth_membership = $group->user(
        { where => 'user_id = ?', value => [ $uid ] }
    ) || [];

    my $is_member = scalar @$auth_membership;

    if (!$is_member) {
        Dicole::MessageHandler->add_message(MESSAGE_ERROR, $self->_msg('You are not a group member!'));
    }
    else {
        CTX->lookup_action('remove_user_from_group')->execute( {
            group => $group,
            user_id => $uid,
        } );

        Dicole::MessageHandler->add_message(MESSAGE_SUCCESS, $self->_msg('Part succesful!') );
    }
    my $redirect = Dicole::URL->create_from_parts(
        action => 'groups',
        task => 'list',
    );
    return CTX->response->redirect( $redirect );
}

sub _members_box {
    my ( $self ) = @_;

    my $list = CTX->lookup_action('user_information_list')->execute( {
        users => $self->param('target_group')->user || [],
    } );

    if ( $self->name eq 'groups' && $self->chk_y( 'users' ) ) {
        return Dicole::Widget::Vertical->new( contents => [
            $list,
            Dicole::Widget::LinkButton->new(
                text => $self->_msg('Edit users'),
                link => $self->derive_url(
                    task => 'users',
                ),
            ),
        ] );
    }
    else {
        return Dicole::Widget::Vertical->new( contents => [
            $list
        ] );
    }
}

# Is this needed anymore?

sub detect {
    my ( $self ) = @_;
    my $last_group = CTX->request->sessionstore->get_value( 'group', 'last_active' );
    my $redirect = undef;
    if ( $last_group ) {
        $redirect = Dicole::URL->create_from_current(
            action => 'groups',
            task => 'starting_page',
            other => [ $last_group ],
        );
    }
    elsif ( $self->param("auto_join_group") ) {
        my $data = Dicole::Generictool::Data->new;
        $data->object( CTX->lookup_object('groups') );
        $data->query_params( {
        from  => [ qw(dicole_groups dicole_group_user) ],
            where => "dicole_group_user.groups_id = dicole_groups.groups_id AND dicole_group_user.user_id = ?",
            value => [ CTX->request->auth_user_id ]
        } );
        $data->data_group;
        if ( scalar @{ $data->data } ) {
            $redirect = Dicole::URL->create_from_current(
                action => 'groups',
                task => 'starting_page',
                other => [ $data->data->[0]->id ]
            );
        }
    }
    unless ( $redirect ) {
        $redirect = Dicole::URL->create_from_current(
            action => 'groups',
            task => 'my_groups',
        );
    }
    return CTX->response->redirect( $redirect );
}

sub my_groups {
    my ( $self ) = @_;

    $self->init_tool;
    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('groups'),
            current_view => 'my_groups',
        )
    );
    $self->init_fields;
    $self->_init_parent_id( undef, 'all' );

    $self->gtool->Data->query_params( {
        from => [ qw(dicole_groups dicole_group_user) ]
    } );
    $self->gtool->Data->add_where(
        'dicole_group_user.groups_id = dicole_groups.groups_id'
    );
    $self->gtool->Data->add_where(
        'dicole_group_user.user_id = ' . CTX->request->auth_user_id
    );
    $self->gtool->Data->add_where(
        'dicole_groups.has_area = 1'
    );

    my $limited_groups = $self->_get_limited_groups;
    if ( ref( $limited_groups ) eq 'ARRAY' && @{ $limited_groups} > 0 ) {
        $self->gtool->Data->add_where(
            Dicole::Utils::SQL->column_in(
                'dicole_groups.groups_id', $limited_groups
            ),
        );
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'My groups' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_list
    );

    return $self->generate_tool_content;
}

sub add {
    my ( $self ) = @_;

    my $parent = eval {
        $self->param( 'target_group_id' ) ?
            CTX->lookup_object('groups')->fetch( $self->param( 'target_group_id' ) ) : undef;
    };

    my $admin = 0;

    my $pid = CTX->request->param('parent_id');
    undef $pid unless $admin;

    if ( ! defined $pid && $parent ) {
        $pid = Dicole::Settings->fetch_single_setting(
            tool => 'groups',
            group_id => $parent->id,
            attribute => 'default_parent_group_id',
        ) || $parent->id;

        unless ( $self->_user_can_create_subgroup( $parent->id ) ) {
            die "security error";
        }
    }
    else {
        $pid ||= 0;
        unless ( $self->_user_can_create_subgroup( $pid ) ) {
            die "security error";
        }
    }

    $self->init_tool({
        tab_override => $parent ? 'list' : 'add',
    });

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('groups'),
            current_view => 'add',
        )
    );

    $self->init_fields( view => $admin ? 'add_admin' : 'add' );
    $self->_init_parent_id( $pid ) if $admin;

    if ( CTX->request->param( 'save' ) ) {

        # Validate input parameters
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );

        if ( $code ) {

            my $data = $self->gtool->Data;

            $data->data->{creator_id} = CTX->request->auth_user_id;
            $data->data->{parent_id} = $pid;
            $data->data->{creation_date} = time;
            $data->data->{domain_id} = Dicole::Utils::Domain->guess_current_id;
            $data->data->{points} = 0;

#            if ( ! $admin ) {
                $data->data->{ 'joinable' } = 1;
                $data->data->{ 'visible' } = 1;
                $data->data->{ 'has_area' } = 1;
                $data->data->{ 'type' } = 'usergroup';
#            }

            $data->data_save;

            my $gid = $data->data->id;
            my $group = $data->data;

            eval {
                CTX->lookup_action( 'dicole_domains' )->execute( add_domain_group => {
                    group_id => $gid,
                } );
            };
            if ( $@ ) {
                get_logger(LOG_APP)->error( "Could not add group '$gid' to domain: $@" );
            }

            $self->_set_visible( $group, $group->visible );
            $self->_post_add_actions( $group, CTX->request->auth_user_id );

            my $groups_api = CTX->lookup_action( 'groups_api' );
            for my $toolid ( qw(
                group_wiki
                group_wiki_summary
                group_wiki_front_page_summary
                group_networking
                group_presentations
                group_blogs
                group_blogs_featured_summary
                groups_summary
                group_online_members
                group_discussions_summary
            ) ) {
                $groups_api->execute( add_to_group_tools => {
                    group => $group,
                    toolid => $toolid,
                } );
            }


            CTX->lookup_action('wiki_api')->e( create_page => {
                group_id => $gid,
                readable_title => $self->_msg('Front page (wiki automatic first page name)'),
            } );

            $self->tool->add_message( $code, $self->_msg('Group created!') );

            my $redirect = ( $group->{has_area} == 1 ) ?
                Dicole::URL->create_from_parts(
                    action => 'groups',
                    task => 'starting_page',
                    target => $gid,
                ) :
                Dicole::URL->create_from_parts(
                    action => 'groups',
                    task => 'browse',
                    target => $gid,
                );

            return CTX->response->redirect( $redirect );
        }
        else {
            $message = $self->_msg( "Save failed: [_1]", $message );
            $self->tool->add_message( $code, $message );
        }

    }

    $self->gtool->add_bottom_buttons( [
        {
            value => $self->_msg('Save'),
            name => 'save'
        }
    ] );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Group info' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub info {
    my ( $self ) = @_;

    my $group = CTX->lookup_object('groups')->fetch( $self->param('target_group_id') );

    return $self->_msg("No active group found!") if !$group;

    my $oldpid = $group->{parent_id};
    my $newpid = CTX->request->param('parent_id');
    my $save = CTX->request->param('save');

    unless ( ! $save ||
             $newpid == $group->{parent_id} ||
             $self->_user_can_create_subgroup( $newpid ) ) {
        die "security error";
    }

    my $tab = ( $self->name eq 'groups' ) ? 'list' : 'info';
    my $cols = ( $self->name eq 'groups' ) ? 2 : 1;

    $self->init_tool( {
        tab_override => $tab,
        cols => $cols,
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('groups'),
            current_view => 'edit'
        )
    );

    $self->init_fields;

    if ( $save ) {

        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object => $group }
        );
        if ( $code ) {

            $self->_set_visible( $group, CTX->request->param( 'visible' ) );

            # fix possible circular references
            $self->_fix_parent_loop( $group, $newpid, $oldpid );
            $self->_post_group_modify( $group );
            $self->tool->add_message( $code, $self->_msg("Changes were saved.") );

            if ( $self->name eq 'groups' ) {
                return CTX->response->redirect(
                    $self->derive_url( task => 'browse' )
                );
            }
        }
        else {
            $self->tool->add_message( $code,
                $self->_msg("Failed modifying user: [_1]", $message )
            );
        }
    }

    $self->_init_parent_id( $group->{parent_id} );
    $self->_init_visible( $group );

    $self->gtool->bottom_buttons( [ {
            name  => 'save',
            value => $self->_msg( 'Save' ),
        }
    ] );

    my $column = 0;

    if ( $self->name eq 'groups' ) {

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Group listing') );
        $self->tool->Container->box_at( 0, 0 )->add_content( $self->_tree_box );

        $column = 1;
    }


    $self->tool->Container->box_at( $column, 0 )->name( $self->_msg('Modify group details') );
    $self->tool->Container->box_at( $column, 0 )->add_content(
        $self->gtool->get_edit( object => $group )
    );

    return $self->generate_tool_content;

}

sub users {
    my ( $self ) = @_;

    my $group = CTX->lookup_object('groups')->fetch( $self->active_group );

    return $self->_msg("No active group found!") if !$group;

    my $tab = ( $self->name eq 'groups' ) ? 'list' : 'users';
    my $cols = ( $self->name eq 'groups' ) ? 2 : 1;

    $self->init_tool( {
        rows => 2,
        cols => $cols,
        tab_override => $tab,
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('user'),
            skip_security => 1,
        )
    );

    $self->init_fields(
        package => 'dicole_groups',
        view => 'user',
    );

    $self->init_fields(
        package => 'dicole_groups',
        view => 'selected_user',
    );

    if ( CTX->request->param( 'user_add_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'user' ) }
        ) {
            CTX->lookup_action('add_user_to_group')->execute( {
                group => $group, user_id => $id
            } );
        }
    }
    elsif ( CTX->request->param( 'selected_user_remove_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'selected_user' ) }
        ) {
            CTX->lookup_action('remove_user_from_group')->execute( {
                group => $group,
                user_id => $id,
            } );
        }
    }

    my $buttons;

    if ( $self->name eq 'groups' ) {
        $buttons = Dicole::Content::Controlbuttons->new(
            buttons => [
            {
                value => $self->_msg('Show group info'),
                type => 'link',
                link => $self->derive_url( task => 'browse' )
            }
        ] );
    }

    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $self->gtool->Data->selected_where(
            list => { $self->gtool->Data->object->id_field => $dicole_domains->e( users_by_domain => {} ) }
        );
    }

    my ( $select, $selected ) = $self->gtool->get_advanced_sel(
        selected => [ map { $_->id } @{ $group->user( { skip_security => 1 } ) } ],
        select_view => 'user',
        selected_view => 'selected_user',
    );

    my $column = 0;

    if ( $self->name eq 'groups' ) {

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Group listing') );
        $self->tool->Container->box_at( 0, 0 )->add_content( $self->_tree_box );

        $column = 1;
    }

    $self->tool->Container->box_at( $column, 0 )->name( $self->_msg('Groups users') );
    $self->tool->Container->box_at( $column, 0 )->add_content( $select );

    $self->tool->Container->box_at( $column, 1 )->name( $self->_msg('Selected users') );
    $self->tool->Container->box_at( $column, 1 )->add_content(  [ @$selected, $buttons ] );

    return $self->generate_tool_content;

}

sub member_rights {
    my ( $self ) = @_;

    my $tab = ( $self->name eq 'groups' ) ? 'list' : 'member_rights';
    my $cols = ( $self->name eq 'groups' ) ? 2 : 1;

    $self->init_tool( {
        cols => $cols,
        tab_override => $tab,
    } );

    my $class = CTX->lookup_object('dicole_security');

    my $collections = CTX->lookup_object('dicole_security_collection')->fetch_group( {
        where => 'target_type = ? AND allowed = ?',
        value => [ TARGET_GROUP, 1 ], # TODO: use constants for allowed!
    } ) || [];

    my %collections_by_id = map { $_->id => $_ } @$collections;


    my $selected = $class->fetch_group( {
        where => 'receiver_group_id = ? AND target_group_id = ?',
        value => [ CTX->request->target_group_id, CTX->request->target_group_id ],
    } ) || [];

    my @old = map { $_->{security_id} => $_ } @$selected;
    my $new = Dicole::Utility->checked_from_apache( 'sel' ) || {};
    my @new = ();

    if ( CTX->request->param( 'save' ) ) {

        foreach my $sec ( @old ) {
                next if ! ref $sec || ! $collections_by_id{ $sec->{collection_id} };

                if ( $new->{ $sec->{collection_id} } ) {
                    delete $new->{ $sec->{collection_id} };
                    push @new, $sec->{collection_id};
                    next;
                }

                $sec->remove;
        }

        foreach my $id ( keys %$new ) {
                next if ! $collections_by_id{ $id };

                my $o = $class->new;

                $o->{receiver_group_id} = CTX->request->target_group_id;
                $o->{target_group_id} = CTX->request->target_group_id;
                $o->{collection_id} = $id;
                $o->{target_type} = TARGET_GROUP;
                $o->{receiver_type} = RECEIVER_GROUP;

                $o->save;

                push @new, $id;
        }

        $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg('Default rights updated') );

        if ( $self->name eq 'groups' ) {
            return CTX->response->redirect(
                $self->derive_url( task => 'browse' )
            );
        }
    }
    else {
        @new = map { $_->{collection_id} } @$selected;
    }

    my $metas = CTX->lookup_object('dicole_security_meta')->fetch_group( {
        order => 'ordering',
    } ) || [];

    push @$metas, { idstring => 'other', name => 'Other' };

    my %colls = ();

    for my $coll (@$collections ) {
        my $metaid = $coll->{meta} || 'other';
        push @{ $colls{$metaid} }, $coll;
    }

    my $list = Dicole::Widget::CategoryListing->new(
        widths => ['1%','99%'],
    );

    my %newcheck = map { $_ => 1 } @new;

    for my $meta ( @$metas ) {

        next if ref $colls{ $meta->{idstring} } ne 'ARRAY';

        $list->current_category(
            $meta->{idstring}, $self->_msg( $meta->{name} )
        );

        for my $coll ( @{ $colls{ $meta->{idstring} } } ) {

            my $sel = $newcheck{ $coll->id } ? ' checked="checked"' : '';

            $list->add_row(
                { content => Dicole::Widget::Raw->new(
                    raw => '<input name="sel_'. $coll->id .
                           '" value="1" type="checkbox"'. $sel .' />'
                ) },
                { content => $self->_msg( $coll->name ) },
            );
        }
    }

    my $buttons = Dicole::Content::Controlbuttons->new(
        buttons => [ { value => $self->_msg('Save'), name => 'save' } ]
    );

    my $column = 0;

    if ( $self->name eq 'groups' ) {

        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Group listing') );
        $self->tool->Container->box_at( 0, 0 )->add_content( $self->_tree_box );

        $column = 1;
    }

    $self->tool->Container->box_at( $column, 0 )->name( $self->_msg('Select default rights') );
    $self->tool->Container->box_at( $column, 0 )->add_content(
        [ $list, $buttons ],
    );

    return $self->generate_tool_content;
}

sub tools {

    my ( $self ) = @_;

    my $group = CTX->lookup_object('groups')->fetch( $self->active_group );

    return $self->_msg("No active group found!") if !$group;

    $self->init_tool( {
        rows => 2
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('tool'),
            skip_security => 1,
        )
    );

    # Select only tools the group is able to use by
    # checking the groups_ids field in tool objects
    my $skip_tools = [];
    my $tools = CTX->lookup_object('tool')->fetch_iterator(
        { where => "type = 'group'" }
    );
    while ( my $tool = $tools->get_next() ) {
        if ( $tool->{groups_ids} ) {
            push @{ $skip_tools }, $tool->id unless scalar(
                grep { $_ == CTX->request->target_group_id }
                    split /\s*,\s*/, $tool->{groups_ids}
            );

        }
    }
    my $id_field = $self->gtool->Data->object->id_field;
    $self->gtool->Data->selected_where(
        list => { $id_field => $skip_tools },
        invert => 1
    );

    # Select only group tools
    $self->gtool->Data->add_where(
        "type = 'group'"
    );

    $self->init_fields(
        package => 'dicole_groups',
        view => 'tool',
    );

    $self->init_fields(
        package => 'dicole_groups',
        view => 'selected_tool',
    );

    if ( CTX->request->param( 'tool_add_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'tool' ) }
        ) {
            eval { $group->tool_add( $id ); };
        }
    }
    elsif ( CTX->request->param( 'selected_tool_remove_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'selected_tool' ) }
        ) {
            eval { $group->tool_remove( $id ); };
        }
    }

    my ( $select, $selected ) = $self->gtool->get_advanced_sel(
        selected => [ map { $_->id } @{ $group->tool } ],
        select_view => 'tool',
        selected_view => 'selected_tool',
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Groups tools') );
    $self->tool->Container->box_at( 0, 0 )->add_content( $select );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Selected tools') );
    $self->tool->Container->box_at( 0, 1 )->add_content( $selected );

    return $self->generate_tool_content;

}

sub _init_parent_id {
    my ( $self, $value, $all ) = @_;

    my $dd = $self->gtool->get_field('parent_id');

    $dd->add_dropdown_options( [
        { attributes => { value => 0 }, content => ' ' },
    ] ) if $all || $self->chk_y( 'create' );

    my $groups = CTX->lookup_object('groups')->fetch_group( {
        order => 'name',
    } );

    my $limited_groups = $self->_get_limited_groups;

    for my $group ( @$groups ) {
        if ( ref( $limited_groups ) eq 'ARRAY' && @{ $limited_groups } > 0 ) {
            next unless ( grep { $_ == $group->id } @{ $limited_groups } ) > 0;
        }
        unless ( $all ) {
            next unless $group->id == $value
                || $self->_user_can_create_subgroup( $group->id );
        }
        $dd->add_dropdown_item( $group->id, $group->{name} );
    }

    if ( defined $value ) {
        $dd->{value} = $value;
        $dd->use_field_value( 1 );
    }
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

    return 1 if ! $pid && $self->chk_y( 'create' );
    return 1 if $pid && $self->chk_y( 'show_info', $pid ) && $self->chk_y( 'create_subgroup', $pid );

    return 0;
}

sub _remove_group {
    my ($self, $group) = @_;

    my $auth_membership = $group->user || [];

    foreach ( @$auth_membership ) {
        CTX->lookup_action('remove_user_from_group')->execute( {
            group => $group,
            user_id => $_->id,
        } );
    }

    $self->notify_observers( 'pre remove', $group );

    $group->remove;
}

sub look {
    my ( $self ) = @_;
    
    my $tool_string = 'navigation';
    eval {
        my $d = CTX->lookup_action('dicole_domains')->
            execute('get_current_domain');
        $tool_string .= '_' . $d->{domain_id};
    };
    
    return Dicole::Task::GTSettings->new( $self, {
        tool => $tool_string,
        user => 0,
        group => 1,
        global => 0,
        view => 'look',
        box_title => 'Look settings',
    } )->execute;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::Groups - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
