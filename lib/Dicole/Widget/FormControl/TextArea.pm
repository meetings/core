package Dicole::Widget::FormControl::TextArea;

use strict;
use base qw( Dicole::Widget::FormControl );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_formcontrol_textarea' };

sub ACCESSORS { (
    rows => Dicole::Widget::ACCESSOR_RAW,
    cols => Dicole::Widget::ACCESSOR_RAW,
    html_editor => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;
