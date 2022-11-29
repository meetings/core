package Dicole::ContentGenerator::TT2Process;
use strict;
use base qw/ OpenInteract2::ContentGenerator::TT2Process /;

sub generate {
    my ( $self, $template_config, $template_vars, $template_source ) = @_;
    delete $template_vars->{ACTION};
    delete $template_vars->{action_messages};
    $template_vars->{I18N_CONFIG} = {
        lang => $template_config->{lang},
        ampm => $template_config->{ampm},
        user => $template_config->{user},
        user_id => $template_config->{user_id},
        action => $template_config->{action},
    };
    return $self->SUPER::generate( $template_config, $template_vars, $template_source );
}

1;
