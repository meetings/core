package Dicole::Widget::FormControl::Tags;

use strict;
use base qw( Dicole::Widget::FormControl );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_formcontrol_tags' };

sub ACCESSORS { (
    old_value => Dicole::Widget::ACCESSOR_RAW,
    add_more_tags_text => Dicole::Widget::ACCESSOR_RAW,
    add_tag_text => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{id} ||= int( 1000000*rand );
    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $args{add_more_tags_text} ||= $ia->_msg('Add more tags');
        $args{add_tag_text} ||= $ia->_msg('Add tag');
    }

    $self->SUPER::_init( %args );
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    unless ( $params->{old_value} ) {
        $params->{old_value} = $params->{value};
    }

    return $params;
}

1;
