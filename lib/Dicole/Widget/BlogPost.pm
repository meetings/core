package Dicole::Widget::BlogPost;

use strict;
use base qw( Dicole::Widget::Element );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_blog_post' };
sub ACCESSORS { (
    title => Dicole::Widget::ACCESSOR_WIDGET,
    read_more => Dicole::Widget::ACCESSOR_WIDGET,
    date => Dicole::Widget::ACCESSOR_RAW,
    author => Dicole::Widget::ACCESSOR_WIDGET,
    preview => Dicole::Widget::ACCESSOR_RAW,
    source => Dicole::Widget::ACCESSOR_WIDGET,
    action_widgets => Dicole::Widget::ACCESSOR_WIDGET_ARRAY,
    control_widgets => Dicole::Widget::ACCESSOR_WIDGET_ARRAY,
    meta_widgets => Dicole::Widget::ACCESSOR_WIDGET_ARRAY
) };

__PACKAGE__->mk_widget_accessors;


sub template_params {

    my ( $self, $params ) = @_;
    $params = $self->SUPER::template_params( $params );
 #   use Data::Dumper;
 #   get_logger(LOG_APP)->error(Data::Dumper::Dumper($params));
    return $params;

}

sub add_action_widgets {

    #tänne promote denote rate discuss..
    my ( $self, @action_widgets ) = @_;
    push @{ $self->action_widgets }, @action_widgets;
}

sub add_control_widgets {

    #tänne edit-nappula
    my ( $self, @control_widgets ) = @_;
    push @{ $self->control_widgets }, @control_widgets;
}

sub add_meta_widgets {

    #tänne edit-nappula
    my ( $self, @meta_widgets ) = @_;
    push @{ $self->meta_widgets }, @meta_widgets;
}
1;
