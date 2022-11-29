package Dicole::Widget::Image;

use strict;

use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Widget::Element );

sub DEFAULT_TEMPLATE { 'widget_image' };

sub ACCESSORS { (
    src => Dicole::Widget::ACCESSOR_RAW,
    alt => Dicole::Widget::ACCESSOR_RAW,
    width => Dicole::Widget::ACCESSOR_RAW,
    height => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;