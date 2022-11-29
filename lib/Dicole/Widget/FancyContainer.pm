package Dicole::Widget::FancyContainer;

use strict;

use base qw( Dicole::Widget::Container );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_fancycontainer' };

__PACKAGE__->mk_widget_accessors;

=pod

=head1 NAME

Container base widget

=head1 SYNOPSIS

See L<Dicole::Widget::FancyContainer>.

=head1 DESCRIPTION

Base class for Container widgets

=head1 INHERITS

Inherits L<Dicole::Widget::Container>.

=head1 ACCESSORS

=head2 contents

=head1 OBJECT METHODS

=head2 add_content( WIDGET, .... )

=cut

1;
