package Dicole::Diff3::Merge;
use strict;

use Dicole::Diff3::Factory;

sub merge {
    my %text = (
        ancestor => shift,
        a => shift,
        b => shift 
    );
    my $conflict_fallback = shift || \&_default_conflict_callback;

    my $d3f = Dicole::Diff3::Factory->new;

    for my $tkey ( keys %text ) {
        $text{$tkey} = $d3f->create_text( $text{$tkey} );
    }
    
    my $diff3 = $d3f->create_diff3->diff3(
        $text{a}, $text{ancestor}, $text{b}
    );

    my @output = ();
    my $next = 1;
    my $conflicts = 0;

    for my $range (@{ $diff3->list }) {
        # Output the hunks that have not changed before this range
        if ( $next < $range->lo2 ) {
            push @output, $text{ancestor}->at( $_ )
                for ( $next .. ($range->lo2 - 1) );
        }
        
        # Case: a or ancestor has changed
        if ( $range->type eq '0' || $range->type eq '2' ) {
            push @output, $text{a}->at( $_ )
                for $range->range0;
        }
        # Case: b has changed
        elsif ( $range->type eq '1' ) {
            push @output, $text{b}->at( $_ )
                for $range->range1;
        }
        # Case: Conflict
        elsif ( $range->type eq 'A' ) {
            my @a = ();
            my @b = ();
            push @a, $text{a}->at( $_ )
                for $range->range0;
            push @b, $text{b}->at( $_ )
                for $range->range1;
            
            push @output, &$conflict_fallback( \@a, \@b );
            
            $conflicts++;
        }
          
        $next = $range->hi2 + 1;
    }
    
    # Output the last hunks that have not changed
    if ( $next <= $text{ancestor}->last_index ) {
        push @output, $text{ancestor}->at( $_ )
            for ( $next .. ($text{ancestor}->last_index) );
    }
    
    return wantarray ? (\@output, $conflicts) : \@output;
}

sub _default_conflict_callback {
    (
        q{>>> >>>>>>>>>>>>>>>>>>>>>>>>>>>>> >>>},
        (@{$_[0]}),
        q{--- ----------------------------- ---},
        (@{$_[1]}),
        q{<<< <<<<<<<<<<<<<<<<<<<<<<<<<<<<< <<<},
    )
}


1;

__END__

=head1 NAME

Dicole::Diff3::Merge - Merge from common ancestor

=head1 SYNOPSIS

  Use Dicole::Diff3::Merge;

  $t[0] = [qw( a b c d e f g )];
  $t[1] = [qw( a 1 d e 4 g )];
  $t[2] = [qw( a 2 c d 3 e 5 g )];

  my ( $merged_blocks, $conflict_count ) =
      Dicole::Diff3::Merge::merge( @t );

  print join $/, @{ Dicole::Diff3::Merge::merge( @t ) };

  my $merge = Dicole::Diff3::Merge::merge( @t, sub {
    (
      q{<!-- CONFLICT START -->},
      (@{$_[0]}),
      q{<!-- -------------- -->},
      (@{$_[1]}),
      q{<!--  CONFLICT END  -->},
    )
  } );
  
  print join $/, @$merge;
  
=head1 ABSTRACT

This module unifies Text::Diff3 and Algorithm::Diff and should
compute a LCS merge with customized conflict handling.

=cut
