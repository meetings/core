package Dicole::Utils::Text;
use strict;

use Encode qw( encode decode decode_utf8 is_utf8 );
use Encode::Guess qw/iso-8859-15/;
use Log::Log4perl qw( get_logger );
use OpenInteract2::Constants qw( :log );

sub utf8_to_internal {
    my ( $self, $text ) = @_;

    if ( is_utf8( $text ) ) {
        Encode::_utf8_off( $text );
    }

    my $guess = guess_encoding($text);

    my $internal = eval { decode("Guess", $text) };

    if ( $@ ) {
        $internal = eval { decode_utf8( $text ) };
        if ( $@ ) {
            $internal = $text;
        }
    }

    Encode::_utf8_on($internal);

    return $internal;
}

sub latin_to_internal {
    my ( $self, $text ) = @_;

#     Is this needed here?
#     if ( Encode::is_utf8( $text ) ) {
#         Encode::_utf8_off( $text );
#     }

    my $internal = eval { Encode::Guess::decode("Guess", $text) };
    if ( $@ ) {
        $internal = eval { Encode::decode( 'iso-8859-15',  $text ) };
        if ( $@ ) {
            $internal = $text;
        }
    }

    Encode::_utf8_on($internal);

    return $internal;
}

sub internal_to_ascii {
    my ( $self, $text ) = @_;

    return Encode::encode(
        'ascii',
        $text,
        Encode::FB_DEFAULT
    );

}

sub internal_to_latin {
    my ( $self, $text ) = @_;

    return Encode::encode(
        'iso-8859-15',
        $text,
        Encode::FB_DEFAULT
    );

}

sub internal_to_htmlencoded_latin {
    my ( $self, $text ) = @_;

    return Encode::encode(
        'iso-8859-15',
        $text,
        Encode::FB_HTMLCREF
    );

}

sub internal_to_utf8 {
    my ( $self, $text ) = @_;
    my $a = Encode::encode( 'utf8', $text, Encode::FB_DEFAULT);
    Encode::_utf8_off($a);
    return $a;
}

sub ensure_utf8 {
    my ( $self, $text ) = @_;
    return $self->internal_to_utf8( $self->utf8_to_internal( $text ) );
}

sub ensure_internal {
    my ( $self, $text ) = @_;
    return $self->utf8_to_internal( $text );
}

# deprecated
sub utf8_to_latintext { return utf8_to_latin( @_ ); }

sub utf8_to_latin {
    my ( $self, $text ) = @_;

    return $self->internal_to_latin( $self->utf8_to_internal( $text ) );
}

sub utf8_to_htmlencoded_latin {
    my ( $self, $text ) = @_;

    return $self->internal_to_htmlencoded_latin( $self->utf8_to_internal( $text ) );
}

sub latin_to_utf8 {
    my ( $self, $text ) = @_;
    return $self->internal_to_utf8( $self->latin_to_internal( $text ) );
}

sub latin_to_url_readable {
    my ( $self, $text ) = @_;

    return $self->internal_to_url_readable( $self->latin_to_internal( $text ) );
}

sub utf8_to_url_readable {
    my ( $self, $text ) = @_;

    return $self->internal_to_url_readable( $self->utf8_to_internal( $text ) );
}

sub internal_to_url_readable {
    my ( $self, $text ) = @_;

    # rfc_unreserved = "-" | "_" | "." | "!" | "~" | "*" | "'" | "(" | ")"
    # rfc_reserved   = ";" | "/" | "?" | ":" | "@" | "&" | "=" | "+" | "$" | ","
    # rfc_delims     = "<" | ">" | "#" | "%" | <">

    # Convert high-ascii chracters to similiar low-ascii characters
    $text = Text::Unidecode::unidecode( $text );
    # Convert delims to something similiar
    $text =~ s{\<}{(}g;
    $text =~ s{\>}{)}g;
    $text =~ s{\#}{*}g;
    $text =~ s{\%}{~}g;
    $text =~ s{\"}{'}g;

    # Convert other nonvalid characters to something similiar
    $text =~ s{ }{_}g;
    $text =~ s{\`}{'}g;
    $text =~ s{\^}{'}g;
    $text =~ s{\[}{(}g;
    $text =~ s{\]}{)}g;
    $text =~ s{\{}{(}g;
    $text =~ s{\}}{)}g;
    $text =~ s{\\}{!}g;
    $text =~ s{\|}{!}g;

    # These reserved characters might mess up the url parsing
    $text =~ s{\/}{-}g;
    $text =~ s{\?}{!}g;

    # And these reserved characters would be escaped by OI2::URL
    $text =~ s{\;}{!}g;
    $text =~ s{\:}{!}g;
    $text =~ s{\@}{*}g;
    $text =~ s{\&}{*}g;
    $text =~ s{\=}{~}g;
    $text =~ s{\+}{*}g;
    $text =~ s{\$}{*}g;
    $text =~ s{\,}{.}g;

    return $self->internal_to_utf8( $text );
}

sub shorten_internal {
    my ( $self, $text, $length, $dots ) = @_;
    $length = 0 if $length < 0;
    $dots ||= '..';

    my $dots_length = length( $dots );

    if ( $length >= $dots_length ) {
        $length -= $dots_length;
        $text =~ s/^(.{$length}).{$dots_length}.+/$1$dots/s;
        return $text;
    }
    else {
        $text =~ s/(.{$length}).+/$dots/s;
        return $text;
    }
}

sub shorten {
    my ( $self, $text, $length, $dots ) = @_;
    return $self->internal_to_utf8(
        $self->shorten_internal(
            $self->ensure_internal( $text ), $length, $dots
        )
    );
}

sub charcount_internal {
    my ( $self, $text ) = @_;
    return length( $text );
}

sub charcount {
    my ( $self, $text ) = @_;

    my $i = $self->utf8_to_internal( $text );
    return $self->charcount_internal( $i );
}

sub break_long_strings_internal {
    my ( $self, $text, $length ) = @_;
    $length ||= 60;
    my $lengthplus = $length + 1;
    $text =~ s/([^\s]{$length})([^\s])/$1 $2/s
        while $text =~ /[^\s]{$lengthplus}/s;

    return $text;
}

sub break_long_strings {
    my ( $self, $text, $length ) = @_;
    return $self->internal_to_utf8(
        $self->break_long_strings_internal(
            $self->ensure_internal( $text ), $length
        )
    );
}


sub replace_double_bracketed_strings_from_text {
    my ( $self, $strings, $string ) = @_;

    for my $key ( keys %$strings ) {
        my $value = $strings->{ $key };
        $string =~ s/\[\[$key\]\]/$value/g;
    }

    return $string;
}

1;
