package Dicole::Utils::OAuth::Client;
use strict;

use base qw( Net::OAuth::Simple );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use HTTP::Cookies;

sub _make_request {
    my $self    = shift;
    my $class   = shift;
    my $url     = shift;
    my $method  = uc(shift);
    my %extra   = @_;

    my $header = delete( $extra{extra_params}->{_header} );
    my $content = delete( $extra{extra_params}->{_content} );

    my $uri   = URI->new($url);

    $extra{extra_params} = {
        $uri->query_form,
        %{ $extra{extra_params} || {} },
    };

    $uri->query_form({});

    my $request = $class->new(
        consumer_key     => $self->consumer_key,
        consumer_secret  => $self->consumer_secret,
        request_url      => $uri,
        request_method   => $method,
        signature_method => $self->signature_method,
        protocol_version => $self->oauth_1_0a ? Net::OAuth::PROTOCOL_VERSION_1_0A : Net::OAuth::PROTOCOL_VERSION_1_0,
        timestamp        => time,
        nonce            => $self->_nonce,
        %extra,
    );

    $request->sign;
    return $self->_error("COULDN'T VERIFY! Check OAuth parameters.")
      unless $request->verify;

    my $params  = $request->to_hash;

    my $response;

    $self->{browser}->cookie_jar({}); # in-memory cookie store
    if ('GET' eq $method || 'PUT' eq $method) {
        $uri->query_form( %$params );
        my $req      = HTTP::Request->new( $method => $uri, $header, $content );

        $response = $self->{browser}->request( $req );
    } else {
        $response = $self->{browser}->post( $uri, $params );
    }

#    return $self->_error("$method on $request failed: ".$response->status_line)
#      unless ( $response->is_success );

    return $response;
}


1;

