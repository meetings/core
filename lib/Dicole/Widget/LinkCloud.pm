package Dicole::Widget::LinkCloud;

use strict;
use base qw( Dicole::Widget::Element );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_link_cloud' };

sub ACCESSORS { (
    links => Dicole::Widget::ACCESSOR_SPECIAL,
    limit => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub template_params {
    my ( $self, $params ) = @_;

    $params = $self->SUPER::template_params( $params );

    my $wheel = $self->_get_limited_wheel;

    my %slots = ();
    my $total_weight = 0;
    my $current = 0;
    my $total_slots = 18;
    my $total = scalar( keys %$wheel );

    for my $key ( sort {$b <=> $a} (keys %$wheel) ) {
        my $weight_links = $wheel->{ $key };
        push @{ $slots{$current} }, @$weight_links;
        $total_weight += 1;
        $current = int( $total_slots * $total_weight / $total );
    }
    my %old_slots = (
        2 => 'tagTertiary', 1 => 'tagSecondary', 0 => 'tagPrimary'
    );

    my %classes = ();
    for my $slot (0..17) {
        $classes{$slot} = 
            'tag_weights_9_' . ( int( $slot / 2 ) + 1 ) .
#             ' tag_weights_6_' . ( int( $slot / 3 ) + 1 ) .
#             ' tag_weights_3_' . ( int( $slot / 6 ) + 1 ) .
            ' ' . $old_slots{ int( $slot / 6 ) };
    }

    my @clinks = ();
    for my $class ( keys %slots ) {
        for my $link (@{ $slots{ $class } }) {
            push( @clinks, {    
                name => $link->{name},
                class => $classes{ $class } . ' real_weight_' . $link->{weight},
                link => $link->{link},
                weight => $link->{weight},
            }  ); 
        }
    }

    @clinks = sort { $a->{name} cmp $b->{name} } @clinks;
    $_->{name} = Dicole::Utils::HTML->encode_entities( $_->{name} ) for @clinks;

    $params->{links} = \@clinks;

    return $params;
}

sub _get_limited_wheel {
    my ( $self ) = @_;
    
    my $links = $self->links;
    my $limit = $self->limit || 30;
    
    my %wheel = ();

    for my $link ( @$links ) {
        push @{ $wheel{ $link->{weight} } }, $link;
    }

    if ( $limit ) {
        my $total = 0;
        for my $key ( sort {$b <=> $a} (keys %wheel) ) {
            if ( $total > $limit ) {
                delete $wheel{$key};
            }
            else {
                my $amount = scalar( @{ $wheel{ $key } } );
                if ( $total != 0 && $total + $amount > $limit * 1.5 ) {
                    delete $wheel{$key};
                }
                $total += $amount;
            }
        }
    }
    
    return \%wheel;
}

sub get_limited_tags {
    my ( $self ) = @_;
    
    my $wheel = $self->_get_limited_wheel;
    my @tags = ();
    for my $key ( keys %$wheel ) {
        my $links = $wheel->{$key};
        for my $link ( @$links ) {
            push @tags, $link->{name};
        }
    }
    
    return \@tags;
}

1;