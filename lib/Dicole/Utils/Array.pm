package Dicole::Utils::Array;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

# This is an imbecil class.. But I wanted to move stuff from Dicole::Utility elsewhere ;)

sub ensure_arrayref {
    my ( $self, $value ) = @_;
    return ref( $value ) eq 'ARRAY' ? $value : [ $value ];
}

sub remove_listed {
    my ( $self, $list, $del_list ) = @_;

    my %seen; # Lookup table
    my $result = []; # Resulting list

    # Build lookup table
    @seen{ @{ $del_list } } = ();

    foreach my $item ( @{ $list } ) {
        push @{ $result }, $item
            unless exists $seen{$item};
    }
    return $result;
}

1;