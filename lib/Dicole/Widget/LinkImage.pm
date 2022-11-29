package Dicole::Widget::LinkImage;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Widget::Image );

sub DEFAULT_TEMPLATE { 'widget_linkimage' };

sub ACCESSORS { (
    onclick => Dicole::Widget::ACCESSOR_RAW,
    link => Dicole::Widget::ACCESSOR_RAW,
    target => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;
