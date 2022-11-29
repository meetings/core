package OpenInteract2::Action::DicoleGroupsAdminJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleGroupsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );

sub update_rights {
    my ( $self ) = @_;

    # TODO: security checks

    my $user_id = CTX->request->param('user_id');
    my $level = CTX->request->param('level');

    my $admin_coll = $self->_admin_collection_id;
    my $mode_coll = $self->_moderator_collection_id;

    CTX->lookup_action('groups_api')->e( remove_individual_group_right => {
        collection => $_,
        user_id => $user_id,
        group_id => $self->param('target_group_id'),
    } ) for ( 'group_admin', 'group_moderator' );

    my $collection = $level eq 'admin' ? 'group_admin' : $level eq 'moderator' ? 'group_moderator' : '';
    if ( $collection ) {
        CTX->lookup_action('groups_api')->e( add_individual_group_right => {
            collection => $collection,
            user_id => $user_id,
            group_id => $self->param('target_group_id'),
        } );
    }

    return { success => 1 };
}

sub remove_user {
    my ( $self ) = @_;

    # TODO: security checks

    CTX->lookup_action('groups_api')->e( remove_user_from_group => {
        user_id => $self->param('user_id'),
        group_id => $self->param('target_group_id'),
    } );

    return { success => 1 };
}

sub mail_users {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $check_digest = Dicole::Settings->fetch_single_setting(
        tool => Dicole::Utils::Domain->guess_current_settings_tool( $domain_id ),
        attribute => 'disable_mailing_if_no_digest'
    );

    my @uids = split /\s*[,_]\s*/, CTX->request->param( 'target_users' );
    my $valid_uids = Dicole::Utils::User->filter_list_to_group_members( \@uids, $gid );

    my $subject = CTX->request->param('subject');

    for my $uid ( @$valid_uids ) {
        if ( $check_digest ) {
            my $digest_freq = Dicole::Settings->fetch_single_setting(
                user_id => $uid,
                tool => 'settings_reminders',
                attribute => $gid,
            );

            if ( ! $digest_freq ) {
                next;
            }
        }

        my $auth_link = Dicole::URL->get_server_url . Dicole::URL->from_parts(
            domain_id => $domain_id,
            target => $gid,
            action => 'groups',
            task => 'starting_page',
            params => { dic => Dicole::Utils::User->temporary_authorization_key( Dicole::Utils::User->ensure_object( $uid ), 30*24 ) },
        );

        my $html = CTX->request->param('content');
        $html .= '<p>' . $self->_msg( 'Access the system through the following link:') . '</p>';
        $html .= '<p><a href="' . $auth_link .'">' . $auth_link . '</a></p>';

        my $text = Dicole::Utils::HTML->html_to_text( $html );

        eval{ Dicole::Utils::Mail->send(
            domain_id => $domain_id,
            user_id => $uid,
            subject => $subject,
            html => $html,
            text => $text,
        ); };
        if ( $@ ) {
            get_logger(LOG_APP)->error("Error sending event invite mail: $@" );
        }
    }

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Emails sent!' )
    );

    return { result => { success => 1 } };
}

sub mail_self {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $subject = CTX->request->param('subject');
    my $auth_link = Dicole::URL->get_server_url . Dicole::URL->from_parts(
        domain_id => $domain_id,
        target => $gid,
        action => 'groups',
        task => 'starting_page',
        params => { dic => Dicole::Utils::User->temporary_authorization_key( Dicole::Utils::User->ensure_object( CTX->request->auth_user_id ), 30*24 ) },
    );

    my $html = CTX->request->param('content');
    $html .= '<p>' . $self->_msg( 'Access the system through the following link:') . '</p>';
    $html .= '<p><a href="' . $auth_link .'">' . $auth_link . '</a></p>';

    my $text = Dicole::Utils::HTML->html_to_text( $html );

    eval{ Dicole::Utils::Mail->send(
        domain_id => $domain_id,
        user_id => CTX->request->auth_user_id,
        subject => $subject,
        html => $html,
        text => $text,
    ); };

    if ( $@ ) {
        get_logger(LOG_APP)->error("Error sending event invite test mail: $@" );
    }

    return { result => { success => 1 } };
}

1;

__END__
