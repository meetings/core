package Dicole::Widget::Comment;

use strict;
use base qw( Dicole::Widget::Element );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_comment' };

sub ACCESSORS { (
    date => Dicole::Widget::ACCESSOR_RAW,
    content => Dicole::Widget::ACCESSOR_RAW,
    user_name => Dicole::Widget::ACCESSOR_RAW,
    user_link => Dicole::Widget::ACCESSOR_RAW,
    user_avatar => Dicole::Widget::ACCESSOR_RAW,
    post_id => Dicole::Widget::ACCESSOR_RAW,
    thread_id => Dicole::Widget::ACCESSOR_RAW,
    action_widgets => Dicole::Widget::ACCESSOR_WIDGET_ARRAY,
    control_widgets => Dicole::Widget::ACCESSOR_WIDGET_ARRAY
) };

__PACKAGE__->mk_widget_accessors;

1;


