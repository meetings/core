package Dicole::Request::CGI;

use strict;
use warnings;
use URI::URL;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use base qw( Dicole::Request OpenInteract2::Request::CGI );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/ );

sub init {
    my ( $self, $params ) = @_;

    $self = OpenInteract2::Request::CGI::init( $self, $params );

    my $cgi = $self->cgi;

    my $url_params = {};
    my @fields = $cgi->url_param;
    foreach my $field ( @fields ) {
        my @items = $cgi->url_param( $field );
        next unless ( scalar @items );
        
        if ( scalar @items > 1 ) {
            $url_params->{$field} = \@items;
        }
        else {
            $url_params->{$field} = $items[0];
        }
    }
       
    $self->assign_url_query( $url_params );
}

sub post_body {
    return OpenInteract2::Request::CGI::post_body( @_ );
}

1;
