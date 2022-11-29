package Dicole::Widget::Listing;

use strict;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Widget );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_listing' };

sub ACCESSORS { (
    use_keys => Dicole::Widget::ACCESSOR_RAW,
    widths => Dicole::Widget::ACCESSOR_RAW,
    row_params => Dicole::Widget::ACCESSOR_RAW,
    rows => Dicole::Widget::ACCESSOR_SPECIAL,
    keys => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{use_keys} = 1;
    $args{row_params} = {} unless ref $args{row_params} eq 'HASH';
    $args{rows} = [] unless ref $args{rows} eq 'ARRAY';
    $args{keys} = [] unless ref $args{keys} eq 'ARRAY';

    $self->SUPER::_init( %args );
}

sub add_key {
    my ($self, %key) = @_;

    push @{$self->keys}, \%key;
}

sub add_keys {
    my ($self, @key) = @_;

    push @{$self->keys}, @key;
}

sub add_row {
    my ($self, @row) = @_;

    push @{$self->rows}, \@row;
}

sub add_rows {
    my ($self, @rows) = @_;

    push @{$self->rows}, @rows;
}

sub new_row {
    my ($self) = @_;

    push @{$self->rows}, [];
}

sub add_cell {
    my ($self, %cell) = @_;

    push @{$self->rows->[-1]}, \%cell;
}

sub add_cells {
    my ($self, @cells) = @_;

    push @{$self->rows->[-1]}, @cells;
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    if ( $params->{use_keys} ) {

        $params->{keys} = [];

        for my $key ( @{$self->keys} ) {

            my $hash = $self->content_params(
                $key->{content}
            );

            $hash->{class} = $key->{class};

            push @{ $params->{keys} }, $hash;
        }
    }

    $params->{rows} = [];

    for my $row ( @{$self->rows} ) {

        my $cells = [];

        for my $cell ( @$row ) {

            my $hash = $self->content_params(
                $cell->{content}
            );

            $hash->{class} = $cell->{class};

            push @$cells, $hash;
        }

        push @{ $params->{rows} }, $cells;
    }

    return $params;
}

1;
