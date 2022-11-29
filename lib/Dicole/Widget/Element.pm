package Dicole::Widget::Element;

use strict;
use base qw( Dicole::Widget );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub ACCESSORS { (
    id => Dicole::Widget::ACCESSOR_RAW,
    class => Dicole::Widget::ACCESSOR_RAW,
) }

__PACKAGE__->mk_widget_accessors;

=pod

=head1 NAME

Element base widget

=head1 DESCRIPTION

Base class for widgets with id and class

=head1 INHERITS

Inherits L<Dicole::Widget>.

=head1 ACCESSORS

=head2 id
=head2 class

=cut

1;