package OpenInteract2::Action::DicoleLocalizationCommon;
use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _lexicon {
    my ( $self, $filter_to_strings, $override_language ) = @_;

    my $domain = Dicole::Utils::Domain->guess_current( $self->param('domain') );
    my $partner = $self->param('partner');

    my $gid = 0;
    if ( ref( $domain ) && $domain->localization_namespace ) {
        $gid =  $self->param('target_group_id') || $self->param('group_id')
            || eval { CTX->controller->initial_action->param('target_group_id') }
            || eval { CTX->controller->initial_action->param('group_id') }
            || 0;
    }

    my @fake_args = ();
    push @fake_args, '[_' . $_ . ']' for (1..20);

    my $handle = $override_language ? OpenInteract2::I18N->get_handle( $override_language ) : $self->language_handle;
    my $dict = {};

    my %filter = ();
    $filter_to_strings ||= scalar( $self->param( 'filter_to_strings' ) );

    if ( $filter_to_strings ) {
        $filter{$_}++ for @$filter_to_strings;
    }

    for my $ref ( @{ $handle->_lex_refs } ) {
        for my $key ( keys %$ref) {
            next if $dict->{ $key };
            next if $filter_to_strings && ! $filter{ $key };

            my $localization_namespace = $partner ? $partner->localization_namespace : '';
            $localization_namespace ||= ref( $domain ) ? $domain->localization_namespace : '';

            my $custom = $localization_namespace ? Dicole::Localization->get_custom_localization_template(
                $handle, $localization_namespace, $gid, $key
            ) : undef;
            if ( $custom ) {
                $dict->{ $key } = $custom;
            }
            else {
                my $value = $ref->{ $key };
                $dict->{ $key } = ref( $value ) ? ref( $value ) eq 'SCALAR' ? $$value : &$value($handle, @fake_args) : $value;
            }
        }
    }

    return $dict;
}

1;

