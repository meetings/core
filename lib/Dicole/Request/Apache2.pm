package Dicole::Request::Apache2;

use URI::URL;
use Apache2::URI;

use base qw( Dicole::Request OpenInteract2::Request::Apache2 );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/ );

sub init {
    my ( $self, $params ) = @_;
    $self = OpenInteract2::Request::Apache2::init( $self, $params );
    my $uri = URI::URL->new;
    $uri->query( $self->apache->parsed_uri->query );
    $self->assign_url_query( { $uri->query_form } );
}

sub post_body {
    my ( $self ) = @_;
    OpenInteract2::Request::Apache2::post_body( @_ );
}
                                        
1;
