package Dicole::Widget::Columns;

use strict;

use OpenInteract2::Context qw( CTX );

use base qw( Dicole::Widget );

sub DEFAULT_TEMPLATE { 'widget_columns' };

sub ACCESSORS { (
    height => Dicole::Widget::ACCESSOR_RAW,
    padding => Dicole::Widget::ACCESSOR_RAW,
    center_overflow => Dicole::Widget::ACCESSOR_RAW,
    right_overflow => Dicole::Widget::ACCESSOR_RAW,
    left_overflow => Dicole::Widget::ACCESSOR_RAW,

    center => Dicole::Widget::ACCESSOR_WIDGET,
    left => Dicole::Widget::ACCESSOR_WIDGET,
    right => Dicole::Widget::ACCESSOR_WIDGET,

    left_width => Dicole::Widget::ACCESSOR_SPECIAL,
    right_width => Dicole::Widget::ACCESSOR_SPECIAL,

    left_class => Dicole::Widget::ACCESSOR_RAW,
    left_td_class => Dicole::Widget::ACCESSOR_RAW,
    right_class => Dicole::Widget::ACCESSOR_RAW,
    right_td_class => Dicole::Widget::ACCESSOR_RAW,
    center_class => Dicole::Widget::ACCESSOR_RAW,
    center_td_class => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;


sub _init {
    my ( $self, %args ) = @_;

    $args{center_overflow} = 'auto' unless defined $args{center_overflow};
    $args{padding} = 2 unless defined $args{padding};

    $self->SUPER::_init( %args );
}

sub template_params {
    my ( $self, $params ) = @_;

    $params = $self->SUPER::template_params( $params );

    my $left_value = 0;
    my $left_type = '';

    if ( $self->left_width ) {
        my ($value, $type) = $self->left_width =~ /(\d+)(%|px)?$/;
        $left_value = $value;
        $left_type = $type;

        if ( $left_type eq '%' ) {
            $params->{left_proportional} =  $left_value . '%';
        }
        else {
            $params->{left_absolute} = $left_value . 'px';
        }
    }

    my $right_value = 0;
    my $right_type = '';

    if ( $self->right_width ) {
        my ($value, $type) = $self->right_width =~ /(\d+)(%|px)?$/;
        $right_value = $value;
        $right_type = $type;

        if ( $right_type eq '%' ) {
            $params->{right_proportional} =  $right_value . '%';
        }
        else {
            $params->{right_absolute} = $right_value . 'px';
        }
    }

    my $center = 100;
    $center -= $left_value if $left_type eq '%';
    $center -= $right_value if $right_type eq '%';

    $params->{center_proportional} = $center . '%';

    return $params;
}

1;