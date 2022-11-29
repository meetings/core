package Dicole::ContentGenerator::TT2Vars;

use Log::Log4perl qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Utils::Text;

sub customize_template_vars {
    my ( $class, $template_name, $template_vars ) = @_;
    my $lh = $template_vars->{LH};
    $template_vars->{MSG} = sub {
        return "$_[0]: no language handle" unless $lh;
        return OpenInteract2::Context->CTX->controller->initial_action->_msg( @_ );
    };
    $template_vars->{SHORTEN} = sub {
        # string, length, dots
        return Dicole::Utils::Text->shorten( @_ );
    };
    $template_vars->{MTN}{t} = sub {
        if ( $template_vars->{I18N_CONFIG} ) {
            return Dicole::Utils::Localization->email_ntranslate( $template_vars, @_ );
        }
        else {
            return OpenInteract2::Context->CTX->controller->initial_action->_nmsg( @_ );
        }
    };

    return $template_vars;
}

1;
