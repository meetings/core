package Dicole::Widget::FormControl::TextField;

use strict;
use base qw( Dicole::Widget::FormControl );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_formcontrol_textfield' };

sub ACCESSORS { (
    field_size => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;
