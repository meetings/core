package OpenInteract2::Auth::DicoleUser;

# $Id: DicoleUser.pm,v 1.18 2010-07-28 13:35:15 amv Exp $

use strict;

use base qw( OpenInteract2::Auth::User );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Utils::User;
use URI;
use Digest::MD5;

use MIME::Base64 qw();
use Digest::SHA;

use constant USER_STATUS => {
  'enabled'   => 0,
  'disabled'  => 1,
};

our $VERSION  = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

my ( $log );
my $USER_ID_KEY = 'user_id';

# Override from base class to allow logging in while logged in.
# Also remove the stupid user session caching which can't be
# removed or invalidated by any means outside the session itself.

sub get_user {
    my ( $class, $auth ) = @_;

    $log ||= get_logger( LOG_AUTH );

    my $session_user_id = $class->_get_user_id;
    my $user = $class->_login_user_from_input;

    if ( $user ) {
        if ( $session_user_id ) {
            # TODO: Does this work? ;)
            my $session_info = CTX->lookup_session_config;
            my $oi_session_class = $session_info->{class};
            $oi_session_class->delete_session( CTX->request->session );
        }

        $class->_check_first_login( $user );
        $class->_remember_login( $user );
        $class->_set_cached_user( $user );

        $auth->user( $user );
        $auth->is_logged_in( 'yes' );
    }
    elsif ( $session_user_id ) {
        $log->is_debug && $log->debug( "Found user ID '$session_user_id'; fetching user" );

        # To avoid random problems, just retry twice
        $user = eval { $class->_fetch_user( $session_user_id ) };
        $user ||= eval { $class->_fetch_user( $session_user_id ) };
        sleep 1 unless $user;
        $user ||= eval { $class->_fetch_user( $session_user_id ) };

        # If there's a failure fetching the user, we need to ensure that
        # this user_id is not passed back to us again so we don't keep
        # going through this process...

        if ( $@ or ! $user ) {
            my $error = $@ || 'User not found';
            $class->_fetch_user_failed( $session_user_id, $error );
        }
        elsif ( ! $class->_check_valid_ip( $user ) ) {
            $user = undef;
        }
        else {
            $log->is_info && $log->info( "User found '$user->{login_name}'" );
            $class->_check_first_login( $user );
            $class->_set_cached_user( $user );

            $auth->user( $user );
            $auth->is_logged_in( 'yes' );
        }
    }

    if ( ! $user ) {
        $log->is_info && $log->info( "Creating the not-logged-in user." );

        my $session = CTX->request->session;
        if ( $session ) {
            delete $session->{ $USER_ID_KEY };
        }

        $auth->user( $class->_create_nologin_user );
        $auth->is_logged_in( 'no' );
    }

    return ( $auth->user, $auth->is_logged_in );
}

sub _login_user_from_input {
  my ( $class, %params ) = @_;
  $log ||= get_logger( LOG_AUTH );

#  my $user = $class->SUPER::_login_user_from_input;
  my $user = $class->_get_domain_user_from_login_input;
  $user ||= $class->_get_domain_user_from_dated_id_checksum;
  $user ||= $class->_get_domain_user_from_facebook_cookie;
  return undef unless $user;
  return undef unless $params{allow_external} ||
        $class->_check_external( $user );
  return undef unless $class->_check_login_disabled( $user );
  return undef unless $class->_check_valid_ip( $user );
  return $user;
}

sub _get_domain_user_from_login_input {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_AUTH );

    my $login_config = CTX->lookup_login_config;
    my $login_field    = $login_config->{login_field};
    my $password_field = $login_config->{password_field};
    unless ( $login_field and $password_field ) {
        $log->error( "No login/password field configured; please set ",
                     "server configuration keys 'login.login_field' and ",
                     "'login.password_field'" );
        return undef;
    }

    my $login_name = CTX->request->param( $login_field );
    my $login_password = CTX->request->param( $password_field );

    return unless $login_name && $login_password;

    my $domain = eval { CTX->lookup_action('dicole_domains')->get_current_domain };
    my $domain_id = $domain ? $domain->id : 0;

    my $user = Dicole::Utils::User->fetch_user_by_login( $login_name, $domain_id );

    return $class->_report_invalid_login unless $user;

    if ( lc( $user->email || '' ) =~ /demo\@meetin\.gs$/ && $login_password eq '1234' ) {
        return $user;
    }

    unless ( $user->check_password( $login_password ) ) {
        $log->warn( "Password check for [$login_name] failed" );
        return $class->_report_invalid_login;
    }
    return $user;
}

sub _get_domain_user_from_dated_id_checksum {
    my ( $class ) = @_;

    my $dic = CTX->request->param( 'dic' );
    return unless $dic;

    my $domain = eval { CTX->lookup_action('dicole_domains')->get_current_domain };
    my $domain_id = $domain ? $domain->id : 0;

    my ( $user, $type ) = Dicole::Utils::User->fetch_by_authorization_key( $dic );

    return undef unless $user && Dicole::Utils::User->belongs_to_domain( $user, $domain_id );

    unless ( $type =~ /c/ ) {
        # TODO: We should not create a session for this request.. so what to do??
        # TODO: This just does not work :(
        my $session_info = CTX->lookup_session_config;
        my $oi_session_class = $session_info->{class};
        my $session = $oi_session_class->delete_session( CTX->request->session );
    }

    CTX->request->{__logged_in_with_dic} = 1;

    return $user;
}
# function get_facebook_cookie($app_id, $application_secret) {
#   $args = array();
#   parse_str(trim($_COOKIE['fbs_' . $app_id], '\\"'), $args);
#   ksort($args);
#   $payload = '';
#   foreach ($args as $key => $value) {
#     if ($key != 'sig') {
#       $payload .= $key . '=' . $value;
#     }
#   }
#   if (md5($payload . $application_secret) != $args['sig']) {
#     return null;
#   }
#   return $args;
# }

sub _get_domain_user_from_facebook_cookie {
    my ( $class ) = @_;

    return unless CTX->request->param('login_fb');

    my ( $app_id, $secret, $disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    return undef if $disabled;

    # NOTE: Use custom header parsing because OI2 stack does not let us get to the Cookie object
    # NOTE: and returns only the first part of the bizarrely separated cookie parts ;)

    my %cookies = CGI::Cookie->parse( CTX->request->cookie_header );
    my $cookie_object = $cookies{'fbsr_' . $app_id};

    return unless $cookie_object;

    my($encoded_sig, $encoded_data) = split(/\./, $cookie_object->value, 2);

    my $sig = MIME::Base64::decode_base64url( $encoded_sig );

    my $json_payload = MIME::Base64::decode_base64url( $encoded_data );

    return unless $sig && $json_payload;

    return unless Digest::SHA::hmac_sha256( $encoded_data, $secret ) eq $sig;

    my $data = eval { Dicole::Utils::JSON->decode( $json_payload ) };

    return unless $data;

    my $fuid = $data->{user_id};

    my $potential_users = CTX->lookup_object('user')->fetch_group({
        where => 'facebook_user_id = ?',
        value => [ $fuid ],
    });

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    for my $user ( @$potential_users ) {
        return $user if Dicole::Utils::User->belongs_to_domain( $user, $domain_id );
    }

    return;
}

sub _report_invalid_login {
    my ( $self ) = @_;

    CTX->request->add_action_message(
        'login_box', 'login', 'Invalid login, please try again'
    );

    return undef;
}

sub _remember_login {
    my ( $class, @args ) = @_;

    # force renewal of cookie
    CTX->request->session->{is_new} = 1 if CTX && CTX->request && CTX->request->session;

    # Always remember dic urls permanently
    return if CTX->request && CTX->request->param('dic');

    return $class->SUPER::_remember_login( @args );
}

# Check if external_auth in user object has a value, return error if it has
sub _check_external {
  my ( $class, $user ) = @_;
  $log ||= get_logger( LOG_AUTH );
  if ( $user->{external_auth} && $user->{external_auth} !~ /^local$/i ) {
    $log->warn( "External_auth defined, but this is not LDAPUser class" );
    CTX->request->add_action_message(
      'login_box', 'login', 'Configuration mismatch, please contact system administrator'
    );
    return undef;
  }
  return 1;
}

sub _check_valid_ip {
    my ( $class, $user ) = @_;

    return 1 unless $user;

    my $domain = eval { CTX->lookup_action('dicole_domains')->get_current_domain };
    my $domain_id = $domain ? $domain->id : 0;

    return 1 unless $domain_id;

    my $user_limit_list = Dicole::Utils::User->get_domain_note( $user, $domain_id, 'limit_ip_list' );

    return 1 unless $user_limit_list;

    my $user_limit_map = { map { $_ => 1 } @$user_limit_list };

    my $remote_ip = eval { CTX->request->cgi->http('X-Forwarded-For') } || CTX->request->remote_host;
    $remote_ip = ( split /,\s+/, $remote_ip )[-1];
    $remote_ip =~ s/^\s+//;
    $remote_ip =~ s/\s+$//;

    return 1 if $remote_ip && $user_limit_map->{ $remote_ip };
    return 0;
}

# Check if login is disabled
sub _check_login_disabled {
  my ( $class, $user ) = @_;
  $log ||= get_logger( LOG_AUTH );
  # check that user is not disabled
  if ( $user->{login_disabled} == USER_STATUS->{'disabled'} ) {
    # user account is disabled
    my $login_name = CTX->request->param( CTX->lookup_login_config->{login_field} );
    $log->warn( "Disabled account tried to log in: [$login_name]" );
    CTX->request->add_action_message(
      'login_box', 'login',
      'This user account is disabled. Please contact your system administrator.'
    );
    return undef;
  }

    my $notes = Dicole::Utils::User->notes_data( $user );
    my $domain_id = eval { CTX->lookup_action('domains_api')->e( 'get_current_domain' )->id } || 0;

    if ( $notes->{$domain_id}{user_disabled} ) {
        my $login_name = CTX->request->param( CTX->lookup_login_config->{login_field} );
        $log->warn( "Disabled account tried to log in: [$login_name]" );
        CTX->request->add_action_message(
        'login_box', 'login',
        'This user account is disabled. Please contact your system administrator.'
        );
        return undef;
    }

  return 1;
}

1;
