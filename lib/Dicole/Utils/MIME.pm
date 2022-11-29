package Dicole::Utils::MIME;
use strict;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use MIME::Types;

sub type_to_readable {
    my ( $class, $type ) = @_;

    return uc( $class->type_to_extension( $type ) );
}

sub type_to_extension {
    my ( $class, $type ) = @_;

    return '' unless $type;

    my $mt = eval { MIME::Types->new->type( $type ) };

    return '' unless $mt;

    my @extensions = $mt->extensions;

    return $extensions[0] || '';
}

1;
