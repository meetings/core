package Dicole::Widget::Container;

use strict;

use base qw( Dicole::Widget::Element );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_container' };

sub ACCESSORS { (
    contents => Dicole::Widget::ACCESSOR_WIDGET_ARRAY,
) };

__PACKAGE__->mk_widget_accessors;

=pod

=head1 NAME

Container base widget

=head1 SYNOPSIS

See L<Dicole::Widget::Horizontal>.

=head1 DESCRIPTION

Base class for Container widgets

=head1 INHERITS

Inherits L<Dicole::Widget::Element>.

=head1 ACCESSORS

=head2 contents

=head1 OBJECT METHODS

=head2 add_content( WIDGET, .... )

=cut

sub _init {
    my ($self, %args) = @_;

    $args{contents} = [] if ref $args{contents} ne 'ARRAY';

    $self->SUPER::_init( %args );
}


sub add_content {
    my ($self, @content) = @_;
    push @{ $self->contents }, @content;
}

1;
