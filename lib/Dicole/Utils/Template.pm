package Dicole::Utils::Template;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub process {
    my ( $class, $template, $params, $generator_params ) = @_;

    $generator_params ||= {};
    my $tt = CTX->content_generator('TT');

    return $tt->generate( $generator_params, $params, { text => $template } );
}

sub process_localized {
    my ( $class, %p ) = @_;

    my $p = {
        language_handle => undef,
        lang => undef,
        domain_id => undef,
        partner_id => undef,
        group_id => undef,

        template_key => undef,
        template_params => {},
        %p
    };

    my $template_key = $p->{'template_key'};
    my $template = Dicole::Utils::Localization->translate( { %$p }, $template_key );
    return Dicole::Utils::Template->process( $template, $p->{template_params} );
}

1;
