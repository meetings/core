package Dicole::Response::LWP;

use base qw( Dicole::Response OpenInteract2::Response::LWP );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/ );

sub init {
    OpenInteract2::Response::LWP::init( @_ );
}
sub send {
    OpenInteract2::Response::LWP::send( @_ );
}
#sub response {
#    OpenInteract2::Response::LWP::response( @_ );
#}
sub redirect {
    OpenInteract2::Response::LWP::redirect( @_ );
}
