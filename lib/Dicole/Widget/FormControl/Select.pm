package Dicole::Widget::FormControl::Select;

use strict;
use base qw( Dicole::Widget::FormControl );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_formcontrol_select' };

sub ACCESSORS { (
    options => Dicole::Widget::ACCESSOR_SPECIAL,
    value_text => Dicole::Widget::ACCESSOR_SPECIAL,
    value_index => Dicole::Widget::ACCESSOR_SPECIAL,
    autourl => Dicole::Widget::ACCESSOR_RAW,
    autosubmit => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{options} = [] if ref( $args{options} ) ne 'ARRAY';

    $self->SUPER::_init( %args );
}

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    my $value = $self->value;
    my $text = $self->value_text;
    my $index = $self->value_index;

    my $selected = undef;
    my %found = ();

    my @options = ();
    for my $option ( @{ $self->options } ) {
        my $hash = {
            value => $option->{value},
            text => $option->{text}
        };

        push @options, $hash;

        next if $found{option};

        if ( $option->{selected} ) {
            $selected = $hash;
            $found{option}++;
            next;
        }

        if ( defined $index ) {
            next if $found{indexed};

            if ( $index == 0 ) {
                $selected = $hash;
                $found{indexed}++;
                next;
            }
            $index--;
        }

        if ( $value && $text ) {
            if ( ! $found{both} ) {
                if ( $value eq $hash->{value} && $text eq $hash->{text} ) {
                    $selected = $hash;
                    $found{both}++;
                }
                elsif ( ! $found{value} ) {
                    if ( $value eq $hash->{value} ) {
                        $selected = $hash;
                        $found{value}++;
                    }
                    elsif ( ! $found{text} ) {
                        if ( $text eq $hash->{text} ) {
                            $selected = $hash;
                            $found{text}++;
                        }
                    }
                }
            }
        }
        elsif ( $value ) {
            if ( ! $found{value} && $value eq $hash->{value} ) {
                $selected = $hash;
                $found{value}++;
            }
        }
        elsif ( $text ) {
            if ( ! $found{text} && $text eq $hash->{text} ) {
                $selected = $hash;
                $found{text}++;
            }
        }
    }

    if ( $selected ) {
        $selected->{selected} = 'selected';
    }

    $params->{options} = \@options;

    return $params;
}

sub add_option {
    my ( $self, %option ) = @_;
    push @{ $self->options }, \%option;
}

sub add_options {
    my ( $self, @options ) = @_;
    push @{ $self->options }, @options;
}

=pod
=head1 CLASS METHODS

=head2 add_objects_as_options( HASHREF )

params:
 * objects = []
 * value_field || value_sub( $object ) || undef (uses ->id)
 * text_field || text_sub( $object ) || undef (uses ->id)
 * selected_value (matches id) || selected_sub( $object ) || undef (none)
 
=cut

sub add_objects_as_options {
    my ( $self, $p ) = @_;
    return if ! ref( $p->{objects} ) eq 'ARRAY';

    for my $object ( @{ $p->{objects} } ) {
        my ( $value, $text, $selected );

        if ( $p->{value_field} ) {
            $value = $object->{ $p->{value_field} };
        }
        elsif ( $p->{value_sub} ) {
            $value = $p->{value_sub}->( $object );
        }
        else {
            $value = $object->id;
        }

        if ( $p->{text_field} ) {
            $text = $object->{ $p->{text_field} };
        }
        elsif ( $p->{text_sub} ) {
            $text = $p->{text_sub}->( $object );
        }
        else {
            $text = $object->id;
        }

        if ( $p->{selected_id} ) {
            $selected = 1 if $object->id == $p->{selected_id};
        }
        elsif ( $p->{selected_sub}) {
            $selected = $p->{selected_sub}->( $object );
        }

        $self->add_option(
            value => $value,
            text => $text,
            selected => $selected,
        );
    }
}

1;
