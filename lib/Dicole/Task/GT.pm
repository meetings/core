package Dicole::Task::GT;

use base 'Dicole::Task';

use OpenInteract2::Context   qw( CTX );
use Dicole::Generictool;

Dicole::Task::GT->mk_accessors( qw(
  skip_security 
  class
  view
  tool_config
) );

sub _gt_init {
    my ( $self, $params ) = @_;

    $params ||= {};

    $self->action->init_tool( $params->{tool_config} );
    my $view = $params->{view} || ( split '::', ( caller(1) )[3] )[-1];
    $self->action->gtool(
        Dicole::Generictool->new(
            ( $params->{class}
                ? ( object => CTX->lookup_object( $params->{class} ) ) : ()
            ),
            skip_security => $params->{skip_security},
            current_view => $view,
        )
    );
    $self->action->init_fields;
}

sub _tool_config {
    my ( $self, $key, $value ) = @_;
    unless ( ref( $self->{tool_config} ) eq 'HASH' ) {
        $self->{tool_config} = {};
    }
    if ( $key ) {
        $self->{tool_config}{$key} = $value;
    }
    return $self->{tool_config};
}

1;
