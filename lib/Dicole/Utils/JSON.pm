package Dicole::Utils::JSON;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use JSON qw(encode_json decode_json);
use Encode qw(is_utf8);
use Data::Structure::Util qw(_utf8_on _utf8_off);
use URI::Escape;

sub uri_encode {
    my ( $class, $data ) = @_;

    my $ret = $class->encode( $data );
    my $escaped = uri_escape_utf8( Dicole::Utils::Text->ensure_internal( $ret ) );
    return $class->encode( { uri_encoded_variables => Dicole::Utils::Text->ensure_utf8( $escaped ) } );
}

sub encode {
    my ( $class, $data ) = @_;

    _utf8_on($data);

    my $ret = Dicole::Utils::Text->ensure_utf8(JSON->new->canonical(1)->encode($data));

    _utf8_off($data);

    return $ret;
}

sub encode_pretty {
    my ( $class, $data ) = @_;

    _utf8_on($data);

    my $ret = Dicole::Utils::Text->ensure_utf8(JSON->new->canonical(1)->pretty(1)->encode($data));

    _utf8_off($data);

    return $ret;
}

sub encode_canonical {
    my ( $class, $data ) = @_;

    _utf8_on($data);

    my $ret = Dicole::Utils::Text->ensure_utf8(JSON->new->canonical(1)->encode($data));

    _utf8_off($data);

    return $ret;
}

sub decode {
    my ( $class, $data ) = @_;

    _utf8_on($data);

    my $ret = eval { JSON->new->decode($data) };
    if ( $@ ) {
        my $error = $@ . ' - data was: ' . $data;
        get_logger(LOG_APP)->error( $error );
        die $error;
    }

    _utf8_off($data);
    _utf8_off($ret);

    return $ret;
}

sub as_json {
    my ( $class, $data ) = @_;

    return $class->encode( $data ) if ( ref( $data ) );
    return $data;
}

sub as_perl {
    my ( $class, $data ) = @_;

    return $class->decode( $data ) unless ( ref( $data ) );
    return $data;
}

1;
