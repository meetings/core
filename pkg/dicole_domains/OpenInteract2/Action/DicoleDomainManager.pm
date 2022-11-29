package OpenInteract2::Action::DicoleDomainManager;

# $Id: DicoleDomainManager.pm,v 1.8 2006/06/06 12:58:03 inf Exp $

use strict;

use base ( qw(
    Dicole::Action::Common::List
    Dicole::Action::Common::Edit
    Dicole::Action::Common::Show
) );

use Dicole::Security qw( :receiver :target :check );
use Dicole::MessageHandler qw( :message );
use Dicole::Generictool;
use Dicole::URL;
use Dicole::Utility;
use Dicole::Generictool::FakeObject;
use DateTime;
use Dicole::Utils::SQL;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

########################################
# Settings tab
########################################

sub add {
    my ($self) = @_;

    return OpenInteract2::Action::DicoleDomainManager::Add->new( $self, {
        box_title => 'New domain details',
        class => 'dicole_domain',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

sub remove {
    my ($self) = @_;

    return OpenInteract2::Action::DicoleDomainManager::Remove->new( $self, {
        box_title => 'List of domains',
        path_name => 'Remove domains',
        class => 'dicole_domain',
        confirm_text => 'Are you sure you want to remove the selected domains?',
        view => 'remove',
    } )->execute;
}

sub edit_domain_users {
    my ( $self ) = @_;

    my $domain_id = CTX->request->param( 'domain_id' );

    $self->init_tool( {
        rows => 2
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('user'),
            current_view => 'edit_domain_users',
            skip_security => 1
        )
    );

    $self->init_fields;

    if ( CTX->request->param( 'users_add_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'users' ) }
        ) {
            my $new_user_in_domain = CTX->lookup_object( 'dicole_domain_user' )->new;
            $new_user_in_domain->{user_id} = $id;
            $new_user_in_domain->{domain_id} = $domain_id;
            $new_user_in_domain->save;
        }
    }
    elsif ( CTX->request->param( 'selected_users_remove_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'selected_users' ) }
        ) {
            eval {
                my $d = CTX->lookup_action('domains_api')->e( remove_user_from_domain => {
                    user_id => $id, domain_id => $domain_id,
                } );
            };
        }
    }

    my $users_in_domain = CTX->lookup_object( 'user' )->fetch_group( {
        from => [ qw(sys_user dicole_domain_user) ],
        where => 'dicole_domain_user.user_id = sys_user.user_id '
            . 'AND dicole_domain_user.domain_id = ?',
        value => [ $domain_id ]
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current(
            task => 'show',
            params => { domain_id => $domain_id }
        )
    );

    my $controlbuttons = $self->gtool->get_controlbuttons;

    my ( $select, $selected ) = $self->gtool->get_advanced_sel(
        selected => [ map { $_->id } @{ $users_in_domain } ],
        select_view => 'users',
        selected_view => 'selected_users',
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Users') );
    $self->tool->Container->box_at( 0, 0 )->add_content( [ @{ $select }, $controlbuttons ] );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Users who belong to this domain') );
    $self->tool->Container->box_at( 0, 1 )->add_content( $selected );

    return $self->generate_tool_content;
}

sub edit_domain_admins {
    my ( $self ) = @_;

    my $domain_id = CTX->request->param( 'domain_id' );

    $self->init_tool( {
        rows => 2
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('user'),
            current_view => 'show_domain_admins',
            skip_security => 1
        )
    );

    # Show only users who belong to the domain already
    my $users_in_domain = CTX->lookup_object( 'user' )->fetch_group( {
        from => [ qw(sys_user dicole_domain_user) ],
        where => 'dicole_domain_user.user_id = sys_user.user_id '
            . 'AND dicole_domain_user.domain_id = ?',
        value => [ $domain_id ]
    } );
    if ( @{ $users_in_domain } > 0 ) {
        $self->gtool->Data->selected_where( list => {
           user_id => [ map { $_->{user_id} } @{ $users_in_domain } ]
        } );
    }
    # If no users were found, then we just need some query to get no values back
    else {
        $self->gtool->Data->add_where( 'user_id = 0' );
    }

    $self->init_fields;

    if ( CTX->request->param( 'users_add_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'users' ) }
        ) {
            my $new_domain_admin = CTX->lookup_object( 'dicole_domain_admin' )->new;
            $new_domain_admin->{user_id} = $id;
            $new_domain_admin->{domain_id} = $domain_id;
            $new_domain_admin->save;
        }
    }
    elsif ( CTX->request->param( 'selected_users_remove_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'selected_users' ) }
        ) {
            my $domain_admins = CTX->lookup_object( 'dicole_domain_admin' )->fetch_group( {
              where => 'user_id = ? AND domain_id = ?',
              value => [ $id, $domain_id ]
            } );
            foreach my $domain_admin ( @{ $domain_admins } ) {
                $domain_admin->remove;
            }
        }
    }

    my $domain_admins = CTX->lookup_object( 'user' )->fetch_group( {
        from => [ qw(sys_user dicole_domain_admin) ],
        where => 'dicole_domain_admin.user_id = sys_user.user_id '
            . 'AND dicole_domain_admin.domain_id = ?',
        value => [ $domain_id ]
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current(
            task => 'show',
            params => { domain_id => $domain_id }
        )
    );

    my $controlbuttons = $self->gtool->get_controlbuttons;

    my ( $select, $selected ) = $self->gtool->get_advanced_sel(
        selected => [ map { $_->id } @{ $domain_admins } ],
        select_view => 'users',
        selected_view => 'selected_users',
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Users') );
    $self->tool->Container->box_at( 0, 0 )->add_content( [ @{ $select }, $controlbuttons ] );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Domain admins') );
    $self->tool->Container->box_at( 0, 1 )->add_content( $selected );

    return $self->generate_tool_content;
}

sub edit_domain_groups {
    my ( $self ) = @_;

    my $domain_id = CTX->request->param( 'domain_id' );

    $self->init_tool( {
        rows => 2
    } );

    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('groups'),
            current_view => 'show_domain_groups'
        )
    );

    $self->init_fields;

    if ( CTX->request->param( 'groups_add_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'groups' ) }
        ) {
            my $new_group_in_domain = CTX->lookup_object( 'dicole_domain_group' )->new;
            $new_group_in_domain->{group_id} = $id;
            $new_group_in_domain->{domain_id} = $domain_id;
            $new_group_in_domain->save;
        }
    }
    elsif ( CTX->request->param( 'selected_groups_remove_checked' ) ) {
        foreach my $id (
            keys %{ Dicole::Utility->checked_from_apache( 'selected_groups' ) }
        ) {
            my $domain_groups = CTX->lookup_object( 'dicole_domain_group' )->fetch_group( {
                where => 'group_id = ? AND domain_id = ?',
                value => [ $id, $domain_id ]
            } );
            foreach my $domain_group ( @{ $domain_groups } ) {
                $domain_group->remove;
            }
        }
    }

    my $groups_in_domain = CTX->lookup_object( 'groups' )->fetch_group( {
        from => [ qw(dicole_groups dicole_domain_group) ],
        where => 'dicole_domain_group.group_id = dicole_groups.groups_id '
            . 'AND dicole_domain_group.domain_id = ?',
        value => [ $domain_id ]
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current(
            task => 'show',
            params => { domain_id => $domain_id }
        )
    );

    my $controlbuttons = $self->gtool->get_controlbuttons;

    my ( $select, $selected ) = $self->gtool->get_advanced_sel(
        selected => [ map { $_->id } @{ $groups_in_domain } ],
        select_view => 'groups',
        selected_view => 'selected_groups',
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Groups') );
    $self->tool->Container->box_at( 0, 0 )->add_content( [ @{ $select }, $controlbuttons ] );

    $self->tool->Container->box_at( 0, 1 )->name( $self->_msg('Groups that belong to this domain') );
    $self->tool->Container->box_at( 0, 1 )->add_content( $selected );

    return $self->generate_tool_content;
}

sub _post_init_common_list {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_list;
    $self->_generate_themes;
    $self->gtool->merge_fake_to_spops( 1 );
    $self->gtool->Sort->fields( $self->gtool->fields );
    $self->gtool->Sort->view( $self->gtool->current_view );
    $self->gtool->Data->order( $self->gtool->Sort->get_sort_query );
    $self->gtool->Search->fields( $self->gtool->fields );
    $self->gtool->Search->set_search_limit;
    $self->gtool->Data->where( $self->gtool->Search->get_search_query );
    $self->gtool->Data->limit( $self->gtool->Browse->get_limit_query );
    $self->gtool->Data->data_group;
    my $fake_objects = [];
    
    my %monthly_users = ();
    $monthly_users{ $_ } = $self->_get_monthly_users( $_ ) for ( 2, 1, 0 );
    
    foreach my $domain ( @{ $self->gtool->Data->data } ) {
        my $fake_object = Dicole::Generictool::FakeObject->new;
        # Calculate number of users online during the last month
        
        $fake_object->{users_month_before_last} =
            $self->_calculate_monthly_users( $domain, $monthly_users{ 2 } );
        $fake_object->{users_last_month} =
            $self->_calculate_monthly_users( $domain, $monthly_users{ 1 } );
        $fake_object->{users_this_month} =
            $self->_calculate_monthly_users( $domain, $monthly_users{ 0 } );

        push @{ $fake_objects }, $fake_object;
    }
    $self->gtool->fake_objects( $fake_objects );
}

sub _get_monthly_users {
    my ( $self, $months_before ) = @_;
    
    my $now = DateTime->now;
    $now->subtract( months => $months_before );
    
    my $monthstart = DateTime->new(
        year => $now->year,
        month => $now->month,
    );
    
    my $monthend = DateTime->from_epoch( epoch => $monthstart->epoch );
    $monthend->add( months => 1 );
    
    # TODO: Check that the activity package is installed or move
    # this to an exported function to the activity package
    my $uids = Dicole::Utils::SQL->arrays(
        select_modifier => 'DISTINCT',
        select => [
            'a.user_id'
        ],
        from   => [
            'dicole_logged_action a',
        ],
        where  => 'a.time > ? AND a.time < ?',
        value => [ $monthstart->epoch, $monthend->epoch ],
    );

    my @uids = map { $_->[0] } @$uids;
    return [ @uids ];
}

sub _calculate_monthly_users {
    my ( $self, $domain, $users ) = @_;
    my $uids = Dicole::Utils::SQL->arrays(
        select_modifier => 'DISTINCT',
        select => [
            'user_id'
        ],
        from   => [
            'dicole_domain_user',
        ],
        where  => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in(
            'user_id', $users
        ),
        value => [ $domain->id ],
    );

    my @uids = map { $_->[0] } @$uids;
    return scalar( @uids );
}
# Replace inherited methods in Common::Show

sub _pre_init_common_show {
    my ( $self ) = @_;
    $self->_config_tool_show( 'tab_override', 'list' );
    $self->_config_tool_show( 'rows', 4 );
    return $self->SUPER::_pre_init_common_show;
}

sub _post_init_common_show {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_show;
    $self->_generate_themes;
}

sub _pre_gen_tool_show {
    my ( $self, $id ) = @_;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'groups' ),
        current_view => 'show_domain_groups',
    ) );
    $self->init_fields;
    $self->gtool->Data->query_params( {
        from => [ qw(dicole_groups dicole_domain_group) ],
        where => 'dicole_domain_group.group_id = dicole_groups.groups_id '
            . 'AND dicole_domain_group.domain_id = ?',
        value => [ $id ],
        order => 'dicole_groups.name'
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_domain_groups',
            params => { domain_id => $id }
        )
    );

    my $controlbuttons = $self->gtool->get_controlbuttons;

    $self->gtool->bottom_buttons( [] );

    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Groups that belong to this domain' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        [ @{ $self->gtool->get_list }, $controlbuttons ]
    );

    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'user' ),
        skip_security => 1,
        current_view => 'show_domain_users',
    ) );
    $self->init_fields;
    $self->gtool->Data->query_params( {
        from => [ qw(sys_user dicole_domain_user) ],
        where => 'dicole_domain_user.user_id = sys_user.user_id '
            . 'AND dicole_domain_user.domain_id = ?',
        value => [ $id ],
        order => 'sys_user.login_name'
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_domain_users',
            params => { domain_id => $id }
        )
    );

    $controlbuttons = $self->gtool->get_controlbuttons;

    $self->gtool->bottom_buttons( [] );

    $self->tool->Container->box_at( 0, 2 )->name(
        $self->_msg( 'Users who belong to this domain' )
    );
    $self->tool->Container->box_at( 0, 2 )->add_content(
        [ @{ $self->gtool->get_list }, $controlbuttons ]
    );

    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'user' ),
        skip_security => 1,
        current_view => 'show_domain_admins',
    ) );
    $self->init_fields;
    $self->gtool->Data->query_params( {
        from => [ qw(sys_user dicole_domain_admin) ],
        where => 'dicole_domain_admin.user_id = sys_user.user_id '
            . 'AND dicole_domain_admin.domain_id = ?',
        value => [ $id ],
        order => 'sys_user.login_name'
    } );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Edit' ),
        link  => Dicole::URL->create_from_current(
            task => 'edit_domain_admins',
            params => { domain_id => $id }
        )
    );

    $controlbuttons = $self->gtool->get_controlbuttons;

    $self->gtool->bottom_buttons( [] );

    $self->tool->Container->box_at( 0, 3 )->name(
        $self->_msg( 'Domain admins' )
    );
    $self->tool->Container->box_at( 0, 3 )->add_content(
        [ @{ $self->gtool->get_list }, $controlbuttons ]
    );
}

sub _pre_init_common_edit {
    my ( $self ) = @_;
    $self->_config_tool_edit( 'tab_override', 'list' );
    return $self->SUPER::_pre_init_common_edit;
}

sub _post_init_common_edit {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_edit;
    $self->_generate_themes;
}

# Generates theme selection dropdown
sub _generate_themes {
    my ( $self ) = @_;
    my $theme_dropdown = $self->gtool->get_field( 'theme_id' );
    $theme_dropdown->add_dropdown_item( 0, $self->_msg( 'Default' ) );
    my $themes = CTX->lookup_object( 'dicole_theme' )->fetch_group( {
        where => 'user_id = 0 AND groups_id = 0',
        order => 'name',
    } );
    foreach my $theme ( @{ $themes } ) {
        $theme_dropdown->add_dropdown_item( $theme->id, $theme->{name} );
    }
}

package OpenInteract2::Action::DicoleDomainManager::Add;

use base 'Dicole::Task::GTAdd';
use OpenInteract2::Context   qw( CTX );

sub _post_init {
    my ( $self ) = @_;
    $self->action->_generate_themes;
}

sub _post_save {
    my ( $self, $data ) = @_;

    return $self->action->_msg( "Domain has been saved." );
}

package OpenInteract2::Action::DicoleDomainManager::Remove;

use base 'Dicole::Task::GTRemove';
use OpenInteract2::Context   qw( CTX );

# Replace inherited methods in Common::Remove

sub _post_remove {
    my ( $self, $ids ) = @_;

    $ids || return undef;

    # Cleanup tables that relate to domain
    # XXX: Should we remove groups/users related to a domain as well?
    # (those groups/users who belong only to one domain, which is being removed)
    foreach my $id (keys %{$ids}) {
        foreach my $object ( 'dicole_domain_user', 'dicole_domain_group' ) {
            my $dom_objects = CTX->lookup_object( $object )->fetch_group( {
                where => 'domain_id = ?',
                value => [ $id ]
            } );
            foreach my $dom_object ( @{ $dom_objects } ) {
                $dom_object->remove;
            }
        }
    }

    return $self->action->_msg( "Selected domains removed." );
}

sub _post_init {
    my ( $self ) = @_;
    $self->action->_generate_themes;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleDicoleDomainManager - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS


