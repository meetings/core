package Dicole::Widget::FormControl;

use strict;
use base qw( Dicole::Widget::Element );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub ACCESSORS { (
    name => Dicole::Widget::ACCESSOR_RAW,
    value => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

1;