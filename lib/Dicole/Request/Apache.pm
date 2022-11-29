package Dicole::Request::Apache;

use URI::URL;
use Apache::URI;

use base qw( Dicole::Request OpenInteract2::Request::Apache );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/ );

sub init {
    my ( $self, $params ) = @_;
    $self = OpenInteract2::Request::Apache::init( $self, $params );
    my $uri = URI::URL->new;
    $uri->query( Apache::URI->parse( $self->apache )->query );
    $self->assign_url_query( { $uri->query_form } );
}

sub post_body {
    my ( $self ) = @_;
    OpenInteract2::Request::Apache::post_body( @_ );
}
                                        
1;
