package Dicole::Diff3::Diff;
use strict;

use base qw( Text::Diff3::Base );
use Algorithm::Diff;

sub diff {
    my $self = shift;
    my( $A, $B ) = @_;
    my $f = $self->factory;

    $A = $f->create_text( $A ) unless $self->_type_check( $A );
    $B = $f->create_text( $B ) unless $self->_type_check( $B );

    my $diff = $f->create_list2;

    my( $ax, $bx ) = ( $A->first_index, $B->first_index );
    my( $an, $bn ) = ( $ax - 1, $bx - 1 );
    my( $loA, $loB ) = ( $ax, $bx );

    my @hunks = Algorithm::Diff::compact_diff( $A->text, $B->text );

#    use Data::Dumper; print Data::Dumper::Dumper(\@hunks);exit;

    my $count = 0;
    while (@hunks) {
        my $an = shift @hunks;
        my $bn = shift @hunks;
        
        ( $ax, $bx ) = ( $an - 1, $bn - 1 );

        # We don't care for the equal parts.
        if ( $count++ % 2 != 1 ) {
            if ( $ax >= $loA && $bx >= $loB ) {
                $diff->push( $f->create_range2( 'c', $loA+1, $ax+1, $loB+1, $bx+1 ) );
            } elsif ( $ax >= $loA ) {
                $diff->push( $f->create_range2( 'd', $loA+1, $ax+1, $loB+1, $loB-1+1 ) );
            } elsif ( $bx >= $loB ) {
                $diff->push( $f->create_range2( 'a', $loA+1, $loA-1+1, $loB+1, $bx+1 ) );
            }
        }
        
        ( $loA, $loB ) = ( $ax + 1, $bx + 1 );
    }

    return $diff;
}

sub _type_check {
    my( $self, $x ) = @_;
       UNIVERSAL::can( $x, 'first_index' )
    && UNIVERSAL::can( $x, 'last_index' )
    && UNIVERSAL::can( $x, 'range' )
    && UNIVERSAL::can( $x, 'at' )
    && UNIVERSAL::can( $x, 'eq_at' );
}


1;
