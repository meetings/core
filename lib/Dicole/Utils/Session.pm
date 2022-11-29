package Dicole::Utils::Session;

use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log SESSION_COOKIE SESSION_COOKIE_SECURE );
use OpenInteract2::Cookie;

sub _cookie_domain_suffix {
    my ( $class, $request ) = @_;

    $request ||= CTX->request;

    my $suffix = lc( $request->server_name );
    $suffix =~ s/[^\.]+\.[^\.]+$//;
    $suffix =~ tr/a-z//cd;

    return $suffix;
}

sub cookie_name {
    my ( $class, $request ) = @_;
    return SESSION_COOKIE . $class->_cookie_domain_suffix( $request );
}

sub secure_cookie_name {
    my ( $class, $request ) = @_;
    return SESSION_COOKIE_SECURE . $class->_cookie_domain_suffix( $request );
}

sub expire_session {
    my ( $class ) = @_;

    OpenInteract2::Cookie->expire( $class->cookie_name );
    OpenInteract2::Cookie->expire( $class->secure_cookie_name );
}

sub current_is_secure {
    my ($class) = @_;

    return !!CTX->request->cookie( $class->secure_cookie_name );
}

1;
