package OpenInteract2::Action::UserManagerAPI;

use strict;
use base ( qw/ OpenInteract2::Action::UserManagerCommon / );

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use constant REMOVAL_TIME => 60 * 60 * 24 * 2; # Two days

sub create_user {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) || die;

    my $user = CTX->lookup_object('user')->new;
    $user->email( $self->param('email') || '' );

    if ( $user->email && Dicole::Utils::User->fetch_user_by_login_in_domain( $user->email, $domain_id ) ) {
        die { message => $self->_msg( "User with email address [_1] already exists. Choose a different email address.",
            $user->email
        ) };
    }

    $user->first_name( $self->param('first_name') );
    $user->last_name( $self->param('last_name') );
    $user->facebook_user_id( $self->param('facebook_user_id') );

    $user->login_name( $user->email );

    $user->timezone( $self->param('timezone') );
    $user->language( $self->param('language') );

    if ( my $gid = $self->param('user_email_group_id') ) {
        if ( my $group = CTX->lookup_object('groups')->fetch( $gid ) ) {
            my $data = eval { Dicole::Utils::JSON->decode( $group->meta || '{}' ) } || {};
            $user->timezone( $data->{timezone} ) if $data->{timezone} && ! $user->timezone;
            $user->language( $data->{language} ) if $data->{language} && ! $user->language;
        }
    }

    $user->timezone( eval { CTX->lookup_action('domains_api')->e(
        domain_default_timezone => { domain_id => $domain_id }
    ) } || 'Europe/Helsinki' ) if ! $user->timezone;

    $user->language( eval { CTX->lookup_action('domains_api')->e(
        domain_default_language => { domain_id => $domain_id }
    ) } || 'en' ) if ! $user->language;

    my ( $password, $crypted_password ) = $self->_create_plaintext_and_crypted_passwords( $self->param('password') );
    $user->password( $crypted_password );

    $user->removal_date( OpenInteract2::Util->now( { time => time + REMOVAL_TIME } ) );
    $user->login_disabled( $self->param('login_disabled') || 0 );
    $user->theme_id( CTX->lookup_default_object_id( 'theme' ) );

    $self->_create_domain_ldap_user( $domain_id, $user, $password );

    $user->save;

    CTX->lookup_action( 'domains_api' )->e(  add_user_to_domain => {
        user_id => $user->id, domain_id => $domain_id
    } );

    $self->_new_user_operations( $user->id, $user, $domain_id );

    $self->_send_new_user_email( $user, $password, $self->param('user_email_group_id' ), $domain_id )
        if $self->param('send_user_email');

    $self->_send_new_user_admin_email( $user, $domain_id )
        if $self->param('send_admin_email');

    return $user;
}

sub create_plaintext_and_crypted_password {
    my ( $self ) = @_;

    return [ $self->_create_plaintext_and_crypted_passwords( $self->param('password' ) ) ];
}

sub allowed_domain_registration_target {
    my ( $self ) = @_;

    if ( $self->param('group_id') || $self->param('group_object') ) {
        if ( $self->current_domain_registration_allowed ) {
            return $self->param('group_object')->id if $self->param('group_object');
            return $self->param('group_id');
        }
        return CTX->lookup_action( 'user_manager_api' )->e( current_domain_registration_allowed => {
            domain_id => $self->param('domain_id')
        } ) ? -1 : undef;
    }

    return $self->current_domain_registration_allowed ? -1 : undef;
}

sub current_domain_registration_allowed {
    my ( $self ) = @_;
    if ( $self->param('group_object') || $self->param('group_id') ) {
        my $group = $self->param('group_object') || CTX->lookup_object('groups')->fetch( $self->param('group_id') );
        if ( ! $group || $group->joinable != 1 ) {
            return 0;
        }
    }

    # constants
    my $reg_allowed = 1;

    # global settings from server.ini
    if (defined(CTX->server_config->{dicole}{user_registration})) {
        $reg_allowed = CTX->server_config->{dicole}{user_registration};
    }

    # domain-specific settings (if applicable)
    my $d = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        my $reg_allowed_t = $d->execute( user_registration_enabled => { domain_id => $self->param('domain_id') } );
        if (defined($reg_allowed_t)) {
            $reg_allowed = $reg_allowed_t;
        }
    }

    return $reg_allowed ? 1 : 0;
}


sub current_domain_registration_default_disabled {
    my ( $self ) = @_;

    # constants
    my $reg_default_disabled = 0;

    # global settings from server.ini
    if (defined(CTX->server_config->{dicole}{user_registration_default_disabled})) {
        $reg_default_disabled = CTX->server_config->{dicole}{user_registration_default_disabled};
    }

    # domain-specific settings (if applicable)
    my $d = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        my $reg_default_disabled_t = $d->execute( user_registration_default_disabled => {} );
        if (defined($reg_default_disabled_t)) {
            $reg_default_disabled = $reg_default_disabled_t;
        }
    }

    return $reg_default_disabled ? 1 : 0;
}


1;
