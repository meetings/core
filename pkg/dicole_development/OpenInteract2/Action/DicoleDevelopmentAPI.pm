package OpenInteract2::Action::DicoleDevelopmentAPI;

use strict;
use base qw( OpenInteract2::Action::DicoleDevelopmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub prepare_template_params {
    my ( $self ) = @_;
    return $self->_prepare_template_params( $self->param('dir'), $self->param('content'), $self->param('lang') );
}

1;

