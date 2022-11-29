package OpenInteract2::Action::DicoleDomainUserManager;

# $Id: DicoleDomainUserManager.pm,v 1.13 2006/05/26 11:15:17 inf Exp $

use strict;

use base qw( Dicole::Action
             OpenInteract2::Action::UserManager
             Dicole::Action::Common::List
             Dicole::Action::Common::Add
             Dicole::Action::Common::Edit
             Dicole::Action::Common::Show
             Dicole::Action::Common::Remove
             Dicole::Action::Common::Settings );

use Dicole::Generictool;
use Dicole::Generictool::Data;
use Dicole::Tool;
use Dicole::Content::Text;
use Dicole::Files;
use Dicole::URL;
use Dicole::Security qw( :receiver :target :check );
use Dicole::Security::Checker;
use Dicole::Utility;
use Dicole::Pathutils;
use Dicole::MessageHandler qw( :message );
use DateTime::TimeZone;
use Template;
use Dicole::Task::GTSettings;

use Spreadsheet::ParseExcel;
use IO::File;
use Data::Dumper;

use OpenInteract2::Context qw( CTX );

our $VERSION =
    sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);


sub _settings_config {
    my ( $self, $settings ) = @_;

    # fetch domain_id from database
    my $d_obj = CTX->lookup_action('dicole_domains');
    $d_obj->task('get_current_domain');
    my $d     = $d_obj->execute;

    my $domain_id = $d->{domain_id};
    my $settings_str = 'domain_user_manager_' . $domain_id;

    $settings->tool( $settings_str );
    $settings->user( 0 );
    $settings->group( 0 );
    $settings->global( 1 );
}

# Generates theme selection dropdown
sub _generate_themes {
    my ( $self ) = @_;
    my $theme_dropdown = $self->gtool->get_field( 'dicole_theme' );
    $theme_dropdown->add_dropdown_item( 0, $self->_msg( 'Default' ) );
  # Removed theme list generation. Not needed for user adding in this context!
}

# Importing new users from a file
sub import_users {
    my ( $self ) = @_;

    $self->init_tool;

    # check that user is domain admin
    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this domain'));
        return $self->generate_tool_content;
    }

    return $self->SUPER::import_users;

}

sub ws_import_users {
    my ( $self ) = @_;

    $self->init_tool;

    # check that user is domain admin
    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this domain'));
        return $self->generate_tool_content;
    }

    return $self->SUPER::ws_import_users;
}

sub reset_default_personal_rights {
    my ( $self ) = @_;
# no access
}

# XXX: logging code
sub list {
    my ( $self ) = @_;

    $self->init_tool;

    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to view this domain'));
        return $self->generate_tool_content;
    }

    return $self->SUPER::list;
}

sub _post_init_common_list {
    my ( $self ) = @_;

    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $dicole_domains->task( 'users_by_domain' );
        my $limited_users = $dicole_domains->execute;
        if ( @{ $limited_users } > 0 ) {
            $self->gtool->Data->selected_where(
                list => { $self->gtool->Data->object->id_field => $limited_users }
            );
        }
    }
}

sub settings {
    my ( $self ) = @_;

    $self->init_tool;

    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to view this domain'));
        return $self->generate_tool_content;
    }

    return $self->SUPER::settings;
}

# XXX: logging code
sub show {
    my ( $self ) = @_;

    $self->init_tool;

    # check that admin user is domain admin for target user
    unless($self->_is_domain_user_admin(CTX->request->param('uid'))) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to view this user'));
        return $self->generate_tool_content;
    }

    return $self->SUPER::show;
}

# Show only groups in the current domain
sub _pre_gen_tool_show {
    my ( $self ) = @_;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'groups' ),
        skip_security => 1,
        current_view => 'show_user_groups',
    ) );
    $self->init_fields;

  my $domain_groups = [];
    eval {
        my $d = CTX->lookup_action('dicole_domains');
        $d->task('groups_by_domain');
        $domain_groups = $d->execute;
    };

    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Groups user belongs to' )
    );

    if ( @{ $domain_groups } ) {
        $self->gtool->Data->query_params( {
            from => [ qw(dicole_groups dicole_group_user) ],
            where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
                . 'AND dicole_group_user.user_id = ? '
        . 'AND dicole_groups.groups_id IN (' . ( join ',', @{ $domain_groups } ) . ')',
            value => [ CTX->request->param( 'uid' ) ],
            order => 'dicole_groups.name'
        } );
        $self->tool->Container->box_at( 0, 1 )->add_content(
            $self->gtool->get_list
        );
    }
    else {
        $self->tool->Container->box_at( 0, 1 )->add_content(
            Dicole::Content::Text->new( text => $self->_msg( 'No groups.' ) )
        );
    }
}

# XXX: logging code
sub edit {
    my ( $self ) = @_;

    $self->init_tool;

    my $user_id = CTX->request->param('uid');

    # Check that admin user is domain admin for target user
    unless($self->_is_domain_user_admin($user_id)) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this user'));
        return $self->generate_tool_content;
    }

    # check that user to be edited is not system admin, system moderator or domain admin

    my $d = CTX->lookup_object('dicole_security')->fetch_group({
         from => [ qw(dicole_security dicole_security_collection) ],
        where => 'dicole_security_collection.target_type = ?'
           . 'AND dicole_security_collection.idstring IN (?, ?, ?)'
           . 'AND dicole_security_collection.collection_id = dicole_security.collection_id',
        value => [ TARGET_SYSTEM,
                   'system_administrator',
                   'system_moderator',
                   'domain_administrator' ],
        order => 'dicole_security.target_user_id'});
    my $forbidden;
    foreach my $ent (@$d) {
        if ($ent->{receiver_user_id} == $user_id) {
            $forbidden = 1;
        }
    }

    if ($forbidden) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this user'));
        return $self->generate_tool_content;
    }

    if ( CTX->request->param('disable_user') ) {
        my $user = Dicole::Utils::User->ensure_object( $user_id );
        my $notes = Dicole::Utils::User->notes_data( $user );
        my $domain_id = eval { CTX->lookup_action('domains_api')->e( 'get_current_domain' )->id } || 0;
        $notes->{$domain_id}{user_disabled_date} ||= [];
        push @{ $notes->{$domain_id}{user_disabled_date} }, time();
        $notes->{$domain_id}{user_disabled} = 1;
        Dicole::Utils::User->set_notes_data( $user, $notes );
    }
    elsif (  CTX->request->param('enable_user') ) {
        my $user = Dicole::Utils::User->ensure_object( $user_id );
        my $notes = Dicole::Utils::User->notes_data( $user );
        my $domain_id = eval { CTX->lookup_action('domains_api')->e( 'get_current_domain' )->id } || 0;
        $notes->{$domain_id}{user_enabled_date} ||= [];
        push @{ $notes->{$domain_id}{user_enabled_date} }, time();
        $notes->{$domain_id}{user_disabled} = 0;
        Dicole::Utils::User->set_notes_data( $user, $notes );
    }

    return $self->SUPER::edit;
}

sub _common_buttons_edit {
    my ( $self, $id ) = @_;

    $self->SUPER::_common_buttons_edit( $id );

# TODO: this works but it requires migration from login_disabled
# TODO: and visual indications in profile and user listings
#
#     my $user = Dicole::Utils::User->ensure_object( $id );
#     my $notes = Dicole::Utils::User->notes_data( $user );
#     my $domain_id = eval { CTX->lookup_action('domains_api')->e( 'get_current_domain' )->id } || 0;
# 
#     if ( $notes->{$domain_id}{user_disabled} ) {
#         $self->gtool->add_bottom_button(
#             name  => 'enable_user',
#             value => $self->_msg( 'Enable user' ),
#         )
#     }
#     else {
#         $self->gtool->add_bottom_button(
#             name  => 'disable_user',
#             value => $self->_msg( 'Disable user' ),
#         );
#     }
}

# XXX: logging code
sub add {
    my ($self) = @_;

    $self->init_tool;

    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this domain'));
        return $self->generate_tool_content;
    }

    return OpenInteract2::Action::DicoleDomainUserManager::Add->new( $self, {
        box_title => 'New user details',
        class => 'user',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

# XXX: logging code
sub remove {
    my ($self) = @_;

    $self->init_tool;

    unless($self->_is_domain_admin) {
        $self->tool->add_message(0, $self->_msg('You are not allowed to edit this domain'));
        return $self->generate_tool_content;
    }

    return OpenInteract2::Action::DicoleDomainUserManager::Remove->new( $self, {
        box_title => 'List of users in the domain',
        path_name => 'Remove users',
        class => 'user',
        skip_security => 1,
        confirm_text => 'Are you sure you want to remove the selected users?',
        view => 'remove',
    } )->execute;
}


# XXX: redundant?
sub _is_domain_admin {
    my ( $self ) = @_;

    my $is_domain_admin;

    eval {
        my $d = CTX->lookup_action('dicole_domains');
        $d->param('user_id', CTX->request->auth_user_id);
        $d->task('is_domain_admin');
        $is_domain_admin = $d->execute;
    };

    return $is_domain_admin;
}

# XXX: redundant?
sub _is_domain_user_admin {
    my ( $self, $user_id ) = @_;

    $user_id || return undef;

    # check that both admin user and target user
    # belong to the current domain and that admin user
    # is administrator for the curret domain

    my $is_admin = $self->_is_domain_admin;
    my $is_user;

    eval {
        my $d = CTX->lookup_action('dicole_domains');
        $d->task('is_domain_user');
        $d->param('user_id', $user_id);
        $is_user = $d->execute;
    };
    if ($@) {
        return undef;
    }

    ($is_user && $is_admin) ? return 1 : return 0;
}

sub _post_saving {
    my ( $self, $data, $password, $external_auth ) = @_;

    my $user = $data;
    if ( ref( $user ) && $user->can( 'data' ) && ref ( $user->data ) && ref ( $user->data ) ne 'HASH' ) {
        $user = $user->data;
    }
    
    # fetch domain_id from database
    my $d_obj = CTX->lookup_action('dicole_domains');
    $d_obj->task('get_current_domain');
    my $d     = $d_obj->execute;

    # save dicole_domain_user object

    my $du           = CTX->lookup_object( 'dicole_domain_user' )->new;
    $du->{domain_id} = $d->{domain_id};
    $du->{user_id}   = $user->{user_id};

    eval { $du->save; };
    if ($@) {
        # XXX: logging code
    }

    return $self->SUPER::_post_saving( $data, $password, $external_auth );
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
        group => 0,
        global => 1,
        view => 'look',
        box_title => 'Look settings',
    } )->execute;
}

1;

package OpenInteract2::Action::DicoleDomainUserManager::Add;

use base qw(OpenInteract2::Action::UserManager::Add
            Dicole::Task::GTAdd);
use Dicole::URL;
use OpenInteract2::Context   qw( CTX );

sub _pre_save {
    my ( $self, $data ) = @_;

    my $email = $data->data->{email};
    $email || return undef;

    # check if email exists in database

    my $ec = eval {
        CTX->lookup_object( 'user' )
            ->fetch_group( { where => 'email = ?',
                             value => [ $email ] } )->[0];
    };

    # if email address not found, save user as usual
    $ec->{user_id} || return $self->SUPER::_pre_save($data);

    # check if user already in domain
    my $d = CTX->lookup_action('dicole_domains');
    $d->task('is_domain_user');
    $d->param('user_id', $ec->{user_id});
    my $res = $d->execute;
    if ($res) {
        # user already in domain
        $self->action->tool->add_message( 0, $self->action->_msg( 'User already in domain.') );
        $self->save_redirect ?
            return CTX->response->redirect( $self->save_redirect ) :
                return 0;
    }
    else {
        return $self->SUPER::_pre_save($data);
    }
}

1;


package OpenInteract2::Action::DicoleDomainUserManager::Remove;

use base qw(OpenInteract2::Action::UserManager::Remove);
use OpenInteract2::Context   qw( CTX );

# Replace inherited methods in Common::Remove

sub _post_init {
    my ( $self ) = @_;

    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $dicole_domains->task( 'users_by_domain' );
        my $limited_users = $dicole_domains->execute;
        if ( @{ $limited_users } > 0 ) {
            $self->action->gtool->Data->selected_where(
                list => { $self->action->gtool->Data->object->id_field => $limited_users }
            );
        }
    }

    # Deleting your own username is not possible
    $self->action->gtool->Data->query_params( {
        where => 'user_id != ?',
        value => [ CTX->request->auth_user_id ]
    } );
}

sub _pre_remove {
    my ( $self, $ids ) = @_;

    $ids || return undef;

    # remove users from domain
    # either remove all ids successfully, or return error (undef)

    foreach my $id (keys %{$ids}) {
        # what was this?? seemed to not do a thing..
        # $self->action->_is_domain_user_admin($id) || return undef;

        # remove dicole_domain_user object from database

        eval {
            my $d = CTX->lookup_action('domains_api')->e( remove_user_from_domain => {
                user_id => $id,
            } );
        };

        if ($@) {
            $self->action->log('warn',
                               "Failed to remove user id [$id] from domain.");
            return undef;
        }

        # if external_auth is defined, remove user drom LDAP database

        eval {
            my $o = CTX->lookup_object('user')->fetch($id, { skip_security => 1 });

            if (defined($o->{external_auth})) {
                # delete user from LDAP database
                my $login_name  = $o->{login_name};
                my $ldap_server = $o->{external_auth};
                my $la = new Dicole::LDAPAdmin($ldap_server);
                my $rs = $la->delete_user($la->search_user($login_name));
                unless ($rs) {
                    $self->action->log('warn',
                                       "Failed to remove user [$login_name] from LDAP database [$ldap_server].");
                }
            }
        };
    }

    return $ids;
}

sub _remove {
    my ( $self ) = @_;

    if ( CTX->request->param( $self->check_prefix ) ) {
        my $ids = Dicole::Utility->checked_from_apache( $self->check_prefix );
        my $data = $self->action->gtool->Data;

        if ( $self->_pre_remove( $ids, $data ) ) {
            ### NOTE: intentionally skip actually removing user objects from database
            ### my ( $code, $message ) = $data->remove_group( $self->check_prefix );
            my $message = $self->_post_remove( $ids, $data );
            $message && $self->action->tool->add_message( 1, $message );
        } else {
            my $message = $self->action->_msg( "Error during remove" );
            $self->action->tool->add_message( 0, $message );
        }
    }
}

sub _post_remove {
    my ( $self, $ids ) = @_;
    return $self->action->_msg( "Selected users removed." );
}

1;


__END__
