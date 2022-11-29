package Dicole::Diff3::Factory;
use strict;

use base qw( Text::Diff3::Factory );
use Dicole::Diff3::Diff;

sub create_diff { Dicole::Diff3::Diff->new( @_ ) }

1;
