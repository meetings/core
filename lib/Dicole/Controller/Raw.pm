package Dicole::Controller::Raw;

use strict;
use base qw( OpenInteract2::Controller Dicole::Controller::Common );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );

sub execute {
    my ( $self ) = @_;
    my $action = $self->initial_action;

    my $content = eval { $action->execute };
    $content = $self->_action_error_content( $@ ) if $@;

    CTX->response->content( \$content );
    return $self;
}

sub _action_error_content {
    my $self = shift @_;
    return $self->common_action_error_content( @_ );
}

1;
