package Dicole::Widget::KVListing;

use strict;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Widget );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_kvlisting' };

sub ACCESSORS { (
    rows => Dicole::Widget::ACCESSOR_SPECIAL,
    key_width => Dicole::Widget::ACCESSOR_SPECIAL,

    # Backwards compatibility
    widths => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{rows} = [] unless ref $args{rows} eq 'ARRAY';

    if ( ref( $args{widths} ) ne 'ARRAY' && ! $args{key_width} ) {
        $args{key_width} = '15%';
    }

    $self->SUPER::_init( %args );
}

sub add_row {
    my ($self, %row) = @_;

    $self->add_rows(\%row);
}

sub add_rows {
    my ($self, @rows) = @_;

    push @{$self->rows}, @rows;
}

sub new_row {
    my ($self) = @_;

    push @{$self->rows}, {};
}

sub add_key {
    my ($self, %cell) = @_;

    $self->rows->[-1]->{key} = \%cell;
}

sub add_value {
    my ($self, %cell) = @_;

    $self->rows->[-1]->{value} = \%cell;
}

sub add_class {
    my ($self, $class) = @_;

    $self->rows->[-1]->{class} = $class;
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    my $key_width = $self->key_width;
    if ( ref ($self->widths) eq 'ARRAY' && ! $key_width ) {
        $key_width = $self->widths->[0];
    }

    my ($value, $type) = $key_width =~ /(\d+)(%|px)?$/;
    if ( $type eq '%' ) {
        $params->{key_proportional} =  $value . '%';
        $params->{value_proportional} = ( 100 - $value ) . '%';
        # Backwards compatibility
        $params->{widths} = [
            $params->{key_proportional},
            $params->{value_proportional}
        ];
    }
    else {
        $params->{key_absolute} = $value . 'px';
        $params->{value_proportional} = '100%';
        # Backwards compatibility
        $params->{widths} = [ '15%', '85%' ];
    }
    
    $params->{rows} = [];

    for my $row ( @{$self->rows} ) {

        my $rhash = {};

        for my $key ( 'key', 'value' ) {

            my $hash = $self->content_params(
                $row->{$key}->{content}
            );

            $hash->{class} = $row->{$key}->{class};

            $rhash->{$key} = $hash;
        }
	
	$rhash->{class} = $row->{class};

        push @{ $params->{rows} }, $rhash;
    }

    return $params;
}

1;
