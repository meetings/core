package Dicole::Container;

use strict;

use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use Dicole::Box;

=pod

=head1 NAME

Represent containers that contain boxes

=head1 SYNOPSIS

 use Dicole::Container;
  my $l = Dicole::Container->new;

  $l->generate_boxes( 2, 1 ); # columns,rows
  $l->box_at( 0, 0 )->name( 'Password' );
  $l->box_at( 0, 0 )->add_content( [ Dicole::Content::Text->new(content => 'Password') ] );
  $l->box_at( 1, 0 )->name( 'Password confirmation box' );
  $l->box_at( 1, 0 )->add_content( [ Dicole::Content::Text->new(content => 'Confirm') ] );

  return CTX->generate_response(
    { itemparams => $l->output },
    { name => $l->template }
 );

=head1 DESCRIPTION

This is used to represent a container that contains L<Dicole::Box> objects.
The boxes can be inserted in the container to any x/y location, and the object
calculates the correct output for the I<dicole_base::tool_content> template.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 ACCESSORS

=head2 template( [STRING] )

Sets/gets the name of the template for which the resulting data structure
representing the contaier will be provided.

=cut

Dicole::Container->mk_accessors( qw( template ) );

=pod

=head2 boxes( [ARRAYREF|OBJECT] )

Sets/gets the boxes in the container. Accepts an arrayref of hashes. Each
hash can have the following properties:

=over 4

=item B<x_pos> I<integer>

The x coordinate of the box.

=item B<y_pos> I<integer>

The y coordinate of the box.

=item B<colspan> I<integer>

The number of columns to span.

=item B<rowspan> I<integer>

The number of rows to span.

=item B<box> I<object>

The Box object itself.

=back

=cut

sub boxes {
    my ( $self, $content ) = @_;

    if ( defined $content ) {
        $self->{list} = $content if ref( $content ) eq 'ARRAY';
        $self->_clear_occupied;
        $self->_set_all_occupied;
    }
    unless ( defined $self->{list} ) {
        $self->{list} = [];
        $self->_clear_occupied;
        $self->_set_all_occupied;
    }
    return $self->{list};
}

=pod

=head2 columns( [INTEGER] )

Sets/gets the number of the columns to be used in the Container
and creates/removes arrayrefs in the two-dimensional arrays
$self->{cell_occupied} and $self->{cells} if needed.

=cut

sub columns {
    my ( $self, $columns ) = @_;
    if ( defined $columns ) {

        my $old_columns = $self->{columns};
        $self->{columns} = $columns;

        # create new columns if needed:
        for (my $i=$old_columns; $i < $columns; $i++ ) {
            $self->{cell_occupied}->[$i] = [];
            $self->{cells}->[$i] = [];
        }

        # remove additional columns if there are any
        splice @{ $self->{cell_occupied} }, $self->{columns}
            if @{ $self->{cell_occupied} } > $self->{columns};
        splice @{ $self->{cells} }, $self->{columns}
            if @{ $self->{cells} } > $self->{columns};
    }
    return $self->{columns};
}

=pod

=head2 colspan( INTEGER, [INTEGER] )

Sets/gets the colspan of a given box index number.

=cut

sub colspan {
    my ($self, $index, $value ) = @_;

    if ( defined $value ) {
        $self->boxes->[$index]{colspan} = $value;
    }
    return $self->boxes->[$index]{colspan};
}

=pod

=head2 rowspan( INTEGER, [INTEGER] )

Sets/gets the rowspan of a given box index number.

=cut

sub rowspan {
    my ($self, $index, $value ) = @_;

    if ( defined $value ) {
        $self->boxes->[$index]{rowspan} = $value;
    }
    return $self->boxes->[$index]{rowspan};
}

=pod

=head2 x_pos( INTEGER, [INTEGER] )

Sets/gets the x coordinate of a given box index number.

=cut

sub x_pos {
    my ($self, $index, $value ) = @_;

    if ( defined $value ) {
        $self->boxes->[$index]{x_pos} = $value;
    }
    return $self->boxes->[$index]{x_pos};
}

=pod

=head2 y_pos( INTEGER, [INTEGER] )

Sets/gets the y coordinate of a given box index number.

=cut

sub y_pos {
    my ($self, $index, $value ) = @_;

    if ( defined $value ) {
        $self->boxes->[$index]{y_pos} = $value;
    }
    return $self->boxes->[$index]{y_pos};
}

=pod

=head1 METHODS

=head2 new( [HASH] )

Creates and returns a new Container object.

Accepts a hash of parameters:

=over 4

=item B<boxes> I<arrayref>

See I<boxes()> accessor description.

=item B<template> I<string>

Name of the template for which the data structure of the container
will be provided. Default is I<dicole_base::tool_content>.

=item B<columns> I<integer>

Number of the columns in the container. Default is 1.

=back

=cut

sub new {
    my ( $class, %args ) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

sub _init {
    my ( $self, %args ) = @_;
    $args{template} = CTX->server_config->{dicole}{base} . '::tool_content'
        unless defined $args{template};
    $self->template( $args{template} );
    $self->{list} = $args{boxes} || [];
    $self->{columns} = $args{'columns'} || 1;
    $self->{cell_occupied} = [];
    $self->{cells} = [];
    for (my $i = 0; $i < $self->{columns}; $i++) {
        $self->{cell_occupied}[$i] = [];
        $self->{cells}[$i] = [];
    }
    $self->_set_all_occupied;
}

# $r->_set_occupied($i);
# Updates the $self->{_cell_occupied} (two-dimensional) array according to the properties of the box in index $i.
# Also copies a reference to the box element to $self->{_cells}->[$element->{x_pos}][$element->{y_pos}] to make life easier
# when $r->output() -function is called.
# (1) Copies the reference in $self->{_content}->[$index] to scalar $element to make our life easier
#     ( we can write $element->{attribute} instead of $self->{_content}->[$index]->{attribute} ).
# (2) Set default values if the element attributes are invalid.
# (3) Mark all the cells that this element spans to as occupied (in two-dimensional array $self->{_cell_occupied}).
#     If any of those cells was already occupied, die.
# (4) Copy a reference to the element in to the corresponding cell in another two-dimensional array $self->{_cells}
# (5) Create an 'arguments' -attribute for the element if it doesn't exist. Copy the rowspan and colspan also to the
#     'arguments' hashref (these are the XHTML arguments and cell colspan/rowspan is needed here)
sub _set_occupied {
    my ( $self, $index ) = @_;
    my $element = $self->boxes->[$index]; # (1)
    $element->{colspan} = 1 unless $element->{colspan}; # (2)
    $element->{rowspan} = 1 unless $element->{rowspan};
    $element->{x_pos} = 0 unless defined $element->{x_pos};
    $element->{y_pos} = 0 unless defined $element->{y_pos};
    for (my $i = 0; $i < $element->{colspan}; $i++ ) {
        for ( my $j = 0; $j < $element->{rowspan}; $j++ ) {
            die 'Tried to insert multiple elements in one cell'
                if $self->{cell_occupied}->[ $i + $element->{x_pos} ]
                    ->[ $j + $element->{y_pos} ]++; # (3)
        }
    }
    # set the "short cut":
    $self->{cells}->[ $element->{x_pos} ][ $element->{y_pos} ] = $element; # (4)
    $element->{arguments} = {} unless defined $element->{arguments}; # (5)
    $element->{arguments}{rowspan} = $element->{rowspan};
    $element->{arguments}{colspan} = $element->{colspan};
}

sub _set_all_occupied {
    my $self = shift;
    for ( my $i = 0; $i < $self->get_box_count; $i++ ) {
        $self->_set_occupied( $i );
    }
}

sub _is_occupied {
    my ( $self, $x, $y ) = @_;
    return $self->{cell_occupied}[$x][$y];
}

# returns true if the given cell should be skipped
# (cell is skipped if the space is occupied by a spanned cell
# that isn't however really defined in this $x,$y -position)
sub _is_spanned {
    my ($self, $x, $y) = @_;
    return $self->_is_occupied( $x, $y ) && !$self->{cells}[$x][$y];
}

# returns object at given coordinates
sub _object_at {
    my ($self, $x, $y) = @_;
    return $self->{cells}[$x][$y];
}

sub _clear_occupied {
    my $self = shift;
    for ( my $i = 0; $i < @{ $self->{cell_occupied} }; $i++ ) {
        for ( my $j = 0; $j < @{ $self->{cell_occupied}->[$i] }; $j++ ) {
            $self->{cell_occupied}[$i][$j] = 0;
        }
    }
    for ( my $i = 0; $i < @{ $self->{cells} }; $i++ ) {
        for ( my $j = 0; $j < @{ $self->{cells}[$i] }; $j++ ) {
            $self->{cells}[$i][$j] = undef;
        }
    }
}

=pod

=head2 get_box_count()

Get the number of boxes in the Container.

=cut

sub get_box_count {
    my $self = shift;
    my $count = @{ $self->{list} };
    return $count;
}

=pod

=head2 add_boxes( ARRAYREF )

Adds the given array of hashes to the end of the boxes.
The format is the same as the format of the I<boxes()> arguments.

=cut

sub add_boxes {
    my ( $self, $content ) = @_;
    my $next_i = $self->get_box_count;
    push @{ $self->{list} }, @{ $content } if ref $content eq 'ARRAY';
    for ( my $i = $next_i; $i < $self->get_box_count; $i++ ) {
        $self->_set_occupied( $i );
    }
}

=pod

=head2 clear_boxes()

Remove all boxes in the Container.

=cut

sub clear_boxes {
    my $self = shift;
    $self->{list} = [];
}

=pod

=head2 generate_boxes( INTEGER, INTEGER )

Generates a set of empty boxes into the Container.
These can be accessed with the I<box_at()> method.

=cut

sub generate_boxes {
    my ( $self, $columns, $rows ) = @_;
    $self->columns( $columns );
    my $lb_ref = [];
    for( my $x = 0; $x < $columns; $x++ ) {
        for( my $y = 0; $y < $rows; $y++ ) {
            push @{ $lb_ref }, {
                x_pos => $x,
                y_pos => $y,
                box   => Dicole::Box->new()
            },
        }
    }
    $self->boxes( $lb_ref );
}

=pod

=head2 box_at( INTEGER, INTEGER )

Returns the reference to a box object at given coordinates.

=cut

sub box_at {
    my $self = shift;
    return $self->_object_at(@_)->{box};
}

=pod

=head2 column_width( STRING, [INTEGER] )

Sets/gets the width of a column. The first paremeter is the width to set
(e.g. 50%). The optional second parameter is the number of the column.

If no column number is provided, the default column number will be 1
(the first column).

Without the width parameter returns the column width in question.

=cut

sub column_width {
    my ( $self, $width, $column ) = @_;
    $column ||= 1;
    if ( defined $width ) {
        $self->{containers_widths}[$column - 1] = $width;
    }
    return $self->{containers_widths}[$column - 1];
}

=pod

=head2 output()

Returns the contents of the Container object as a data structure
that the template dicole_base::tool_content wants. The format is:

 {
    containers_columns => [
        # an arrayref for each column:
        [
        # box index numbers. From top to bottom.
        # These are the index numbers in the containers -array defined below
            0, 1, 2
        ],
        ...
    ],
    containers_widths => [
        200px, 200px
    ],
    containers => [
        # a hashref for each box
        {
            name => '', #the name that appears on top of the container
            form_params => {
                # form parameters (if the box is wrapped in a form)
            },
            content => [
                # a hashref for each element inside the box
                {
                    template => '',
                    params => { ... }
                },
                ...
            ]
        },
    ]
 }

=cut

sub output {
    my $self = shift;
    my $output = {
        containers_columns => [],
        containers_widths  => [],
        containers         => [],
    };
    for ( my $i = 0; $i < $self->columns; $i++ ) {
        $output->{containers_columns}[$i] = []
            unless defined $output->{containers_columns}[$i];
        push @{ $output->{containers_widths} }, $self->column_width( undef, $i + 1 );
        for ( my $j = 0; $j < @{ $self->{cell_occupied}[$i] }; $j++ ) {

            # skip if the cell is defined elsewhere (spanned cell)
            next if $self->_is_spanned( $i,$j );

            my $object = $self->_object_at( $i, $j );

            next unless ref $object;

            # Don't draw boxes without any content
            next unless $object->{box}->get_content_count;

            # the index of the next element in this array
            my $box_index = @{ $output->{containers} };
            my $box_params = $object->{box}->output();
            push @{ $output->{containers} }, $box_params;

            push @{ $output->{containers_columns}[$i] }, $box_index;
        }
    }
    return $output;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

=pod

=head1 SEE ALSO

L<Dicole::Tool>, L<Dicole::Box>.

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;

