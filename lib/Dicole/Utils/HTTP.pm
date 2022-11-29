package Dicole::Utils::HTTP;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Utils::HTTP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common qw();
use URI::Fetch;

sub get {
    my ( $class, $url, $timeout, $user, $pass, $token, $agent, $headers ) = @_;

    my $response = $class->get_response( $url, $timeout, $user, $pass, $token, $agent, $headers );

    if ( $response->is_success ) {
        return $response->decoded_content(charset => 'none');
    }

    get_logger(LOG_APP)->error( $url . ' -> ' . $response->status_line . ' > ' . $response->decoded_content(charset => 'none') );
    die $response->status_line;
}

sub get_response {
    my ( $class, $url, $timeout, $user, $pass, $token, $agent, $headers ) = @_;

    my $ua = $class->_get_ua( $timeout, $user, $pass, $agent );

    if ( $user || $token || $headers ) {
        my $req = HTTP::Request->new( GET => $url );
        $req->authorization_basic( "$user", "$pass" ) if $user;
        $req->header( 'Authorization', $token ) if $token;
        for my $key ( keys %{ $headers || {} } ) {
            $req->header( $key, $headers->{ $key } );
        }
        return $ua->request( $req );
    }

    return $ua->get( $url );
}

sub delete {
    my ( $class, $url, $timeout, $user, $pass ) = @_;

    my $response = $class->delete_response( $url, $timeout, $user, $pass );

    if ( $response->is_success ) {
        return $response->decoded_content(charset => 'none');
    }

    get_logger(LOG_APP)->error( $url . ' -> ' . $response->status_line . ' > ' . $response->decoded_content(charset => 'none') );
    die $response->status_line;
}

sub delete_response {
    my ( $class, $url, $timeout, $user, $pass ) = @_;

    my $ua = $class->_get_ua( $timeout, $user, $pass );

    if ( $user ) {
        my $req = HTTP::Request->new( DELETE => $url );
        $req->authorization_basic( "$user", "$pass" );
        return $ua->request( $req );
    }

    return $ua->delete( $url );
}

sub post_json {
    my ( $class, $url, $data, $timeout, $user, $pass, $token ) = @_;

    my $response = $class->post_json_response( $url, $data, $timeout, $user, $pass, $token );

    if ( $response->is_success ) {
        return $response->decoded_content(charset => 'none');
    }

    get_logger(LOG_APP)->error( $url . ' -> ' . $response->status_line . ' > ' . $response->decoded_content(charset => 'none') );
    die $response->status_line;
}

sub post_json_response {
    my ( $class, $url, $data, $timeout, $user, $pass, $token ) = @_;

    my $ua = $class->_get_ua( $timeout, $user, $pass );

    my $req = HTTP::Request::Common::POST( $url, 'Content-Type' => 'application/json', Content => Dicole::Utils::JSON->encode( $data ) );

    $req->authorization_basic( "$user", "$pass" ) if $user;
    $req->header( 'Authorization', $token ) if $token;

    return $ua->request( $req );
}

sub post {
    my ( $class, $url, $params, $timeout, $user, $pass ) = @_;

    my $response = $class->post_response( $url, $params, $timeout, $user, $pass );

    if ( $response->is_success ) {
        return $response->decoded_content(charset => 'none');
    }

    get_logger(LOG_APP)->error( $url . ' -> ' . $response->status_line . ' > ' . $response->decoded_content(charset => 'none') );
    die $response->status_line;
}

sub post_response {
    my ( $class, $url, $params, $timeout, $user, $pass ) = @_;

    my $ua = $class->_get_ua( $timeout, $user, $pass );

    if ( $user ) {
        my $req = HTTP::Request::Common::POST( $url, $params );
        $req->authorization_basic( "$user", "$pass" );
        return $ua->request( $req );
    }

    return $ua->post( $url, $params );
}

sub _get_ua {
    my ( $class, $timeout, $user, $pass, $agent ) = @_;

    my $ua = Dicole::Utils::HTTP::UserAgent->new;
    $ua->username( $user );
    $ua->password( $pass );
    $ua->timeout( $timeout || 15 );
    $ua->agent( $agent ) if $agent;

    return $ua;
}

sub json_api_call {
    my ( $class, $url, $params, $timeout, $user, $pass ) = @_;

    return Dicole::Utils::JSON->decode( $class->post(
        $url,
        { params => Dicole::Utils::JSON->encode( $params ) },
        $timeout, $user, $pass
    ) );
}

sub last_error {
    return URI::Fetch->errstr;
}

1;
