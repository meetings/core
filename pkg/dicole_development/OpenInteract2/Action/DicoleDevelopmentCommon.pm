
package OpenInteract2::Action::DicoleDevelopmentCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::Mail;

# TODO: refactor as copied from mail_to_po_templates script
sub _prepare_template_params {
    my ( $self, $pkgdir, $file_content, $lang ) = @_;

    for ( 1..10 ) {
        $file_content =~ s/<<<(\/?)(\w*)>>>/$self->_include_part( $pkgdir, $2, $lang, $1 )/eg;
        last unless $file_content =~ /<<<\/?\w*>>>/;
    }

    my ( $subject, $content ) = split /\n\n/, $file_content, 2;

    my $text_content = $content;
    $text_content =~ s/\n//g;

    $content =~ s/\-\-\-n\-\-\-/\n/ig;
    $text_content =~ s/\-\-\-n\-\-\-/\n/ig;

    return {
        subject => $subject,
        html => $content,
        text => $text_content,
    };
}

sub _include_part {
    my ( $self, $dir, $base, $lang, $ending ) = @_;

    my $d = $dir;
    my $b = $base;
    my ( $fp ) = $d =~ /.*\/(\w+)\/?$/;

    my $p = $fp;
    $p =~ s/dicole_//;

    $b .= '_end' if $ending;

    my $file = "$d/src/mail/$b-$lang.part";
    $file = "$d/src/mail/${p}_$b-$lang.part" unless -f $file;
    $file = "$d/src/mail/${fp}_$b-$lang.part" unless -f $file;

    if ( ! $ending ) {
        $b .= '_begin';

        $file = "$d/src/mail/$b-$lang.part" unless -f $file;
        $file = "$d/src/mail/${p}_$b-$lang.part" unless -f $file;
        $file = "$d/src/mail/${fp}_$b-$lang.part" unless -f $file;
    }

    return `cat $file` if -f $file;

    die "Could not find referenced part: $dir + $base + $lang + [$ending]";
}

sub _ensure_development {
    my ( $self ) = @_;

    die unless CTX->server_config->{dicole}{development_mode};
}

1;

