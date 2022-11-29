package OpenInteract2::Auth::RadiusUser;

# $Id: RadiusUser.pm,v 1.9 2009-01-07 14:42:32 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utility;
use Authen::Radius;
use base qw( OpenInteract2::Auth::User );

use constant USER_STATUS => {
    'enabled'   => 0,
    'disabled'  => 1,
};

our $VERSION  = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub _login_user_from_input {
    my ( $class ) = @_;
    $log ||= get_logger( LOG_AUTH );
    my $login_config   = CTX->lookup_login_config;
    my $login_field    = $login_config->{login_field};
    my $password_field = $login_config->{password_field};
    my $radius_field   = $login_config->{radius_field};
    my $radius_server  = $login_config->{radius_server};
    my $radius_secret  = $login_config->{radius_secret};
    my $radius_port    = $login_config->{radius_port};
    my $radius_servers = $login_config->{radius_servers};

    unless ( $login_field and $password_field ) {
        $log->error( "No login/password field configured; please set ",
                     "server configuration keys 'login.login_field' and ",
                     "'login.password_field'" );
        return undef;
    }

    my $request = CTX->request;
    my $login_name = $request->param( $login_field );
    unless ( $login_name ) {
        $log->is_info &&
            $log->info( "No login name found" );
        return undef;
    }
    $log->is_info &&
        $log->info( "Found login name [$login_name]" );

    my $user = eval { CTX->lookup_object( 'user' )
                         ->fetch_by_login_name( $login_name,
                                                { skip_security => 1 } ) };
    if ( $@ ) {
      $log->error( "Error fetching user by login name: $@" );
    }

    unless ( $user ) {
        $log->warn( "User with login '$login_name' not found." );
        $request->add_action_message(
            'login_box', 'login', 'Invalid login, please try again.' );
        return undef;
    }

    # Check the password

    my $password = $request->param( $password_field );

    # If radius field is defined, we expect that the user may select
    # the radius server which against the authentication will be done.
    # Set radius_server and radius_secret according to user input.
    if ( $radius_field && $request->param( $radius_field ) ) {
        if ( ref( $radius_servers ) eq 'HASH' ) {
            my $radius_servers_array = Dicole::Utility->make_array( $radius_servers->{radius_server} );
            my $radius_secrets_array = Dicole::Utility->make_array( $radius_servers->{radius_secret} );
            my $radius_ports_array   = Dicole::Utility->make_array( $radius_servers->{radius_port} );
            for ( my $i = 0; $i < @{ $radius_servers_array }; $i++ ) {
                if ( $radius_servers_array->[$i] eq $request->param( $radius_field ) ) {
                    $radius_server = $radius_servers_array->[$i];
                    $radius_secret = $radius_secrets_array->[$i];
                    $radius_port   = $radius_ports_array->[$i];
                    last;
                }
            }
        }
    }

    if ( $radius_server && $radius_secret ) {

        my $host = $radius_server;
        $host .= ':' . $radius_port if $radius_port;

        my $radius = Authen::Radius->new(
            Host   => $host,
            Secret => $radius_secret
        );
        unless ( defined $radius ) {
            $log->warn( "Radius server [$radius_server] is not responding" );
            $request->add_action_message(
                'login_box', 'login',
                'Radius server is not responding, please try again.'
            );
            return undef;
        }
        unless ( $radius->check_pwd( $login_name, $password ) ) {
            $log->warn( "Password check for [$login_name] through "
                . "radius server failed: " . $radius->get_error
            );
            $request->add_action_message(
                'login_box', 'login', 'Invalid login, please try again.' );
            return undef;
        }
    }
    else {
        unless ( $user->check_password( $password ) ) {
            $log->warn( "Password check for [$login_name] failed" );
            $request->add_action_message(
                'login_box', 'login', 'Invalid login, please try again.' );
            return undef;
        }
    }
    $log->is_info &&
        $log->info( "Passwords matched for UID ", $user->id );

    # check if use account is disabled

    if ($user->{login_disabled} == USER_STATUS->{'disabled'}) {
	$log->warn("Disabled account tried to log in: [$login_name]");
	CTX->request->add_action_message('login_box',
					 'login',
					 'User account is disabled, please contact system administrator.');
	return undef;
    }

    return $user;
}

1;
