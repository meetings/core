package Dicole::Widget::CategoryListing;

use strict;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Widget );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_categorylisting' }

sub ACCESSORS { (
    categories => Dicole::Widget::ACCESSOR_SPECIAL,
    widths => Dicole::Widget::ACCESSOR_RAW,
) }

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{categories} = [] unless ref $args{keys} eq 'ARRAY';

    $self->SUPER::_init( %args );
}

sub add_category {
    my ($self, %cat) = @_;

    push @{$self->categories}, \%cat;
}

sub add_categories {
    my ($self, @cats) = @_;

    push @{$self->categories}, @cats;
}

# Set, get (and create unexisting) current category
# which will be used when adding rows or columns

sub current_category {
    my ($self, $id, $content) = @_;

    return $self->{current_category} unless defined $id;
    
    for my $cat ( @{ $self->categories } ) {
        next if $cat->{id} ne $id;

        return $self->{current_category} = $cat;
    }

    # failed to find category so we'll create a new one
    
    $content = $id unless defined $content;
    
    my $cat = {
        id => $id,
        content => $content,
    };
    
    $self->add_categories( $cat );
    
    return $self->{current_category} = $cat;
}

sub add_row {
    my ($self, @row) = @_;

    push @{$self->current_category->{rows}}, \@row;
}

sub add_rows {
    my ($self, @rows) = @_;

    push @{$self->current_category->{rows}}, @rows;
}

sub new_row {
    my ($self) = @_;

    push @{$self->current_category->{rows}}, [];
}

sub add_cell {
    my ($self, %cell) = @_;

    push @{$self->current_category->{rows}->[-1]}, \%cell;
}

sub add_cells {
    my ($self, @cells) = @_;

    push @{$self->current_category->{rows}->[-1]}, @cells;
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    $params->{categories} = [];
    
    for my $cat ( @{$self->categories} ) {

        my $cathash = $self->content_params(
            $cat->{content}
        );
        
        $cathash->{class} = $cat->{class};
        
        for my $row ( @{ $cat->{rows} } ) {

            my $cells = [];

            for my $cell ( @$row ) {

                my $hash = $self->content_params(
                    $cell->{content}
                );
            
                $hash->{class} = $cell->{class};

                push @$cells, $hash;
            }
        
            push @{ $cathash->{rows} }, $cells;
        }
        
        push @{ $params->{categories} }, $cathash;
    }
    
    return $params;
}

1;
