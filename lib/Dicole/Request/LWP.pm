package Dicole::Request::LWP;

use base qw( Dicole::Request OpenInteract2::Request::LWP );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/ );

sub init {
    OpenInteract2::Request::LWP::init( @_ );
}
