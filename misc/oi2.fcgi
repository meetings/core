#!/usr/bin/perl

# $Id: oi2.fcgi,v 1.1 2005/02/18 03:29:40 lachoy Exp $

use strict;
use CGI::Fast;
use File::Spec::Functions qw( catfile );
use Log::Log4perl qw(get_logger);
use OpenInteract2::Auth;
use OpenInteract2::Controller;
use OpenInteract2::Context;
use OpenInteract2::Constants qw(:log);
use OpenInteract2::Request;
use OpenInteract2::Response;

use Data::Dumper qw(Dumper);

{
    my $website_dir = '/usr/local/dicole';
    my $l4p_conf = File::Spec->catfile(
                       $website_dir, 'conf', 'log4perl.conf' );
    Log::Log4perl::init( $l4p_conf );

    my $log = get_logger(LOG_APP);

    $log->error("Creating context");

    my $ctx = OpenInteract2::Context->create({
        website_dir => $website_dir
    });

    $log->error("Assigning request and response types");

    $ctx->assign_request_type( 'cgi' );
    $ctx->assign_response_type( 'cgi' );

    $log->error("Creating FastCGI request object");
    
    #my $fcgi_request = FCGI::Request();

    $log->error("Waiting for a client request");

    while ( my $fcgi_request = CGI::Fast->new ) { # ) $fcgi_request->Accept() >= 0 ) {
        $SPOPS::Tie::COUNT = {};

        #DB::enable_profile();

        $log->error("Got a request");

        $log->error("Creating response");
        my $response = OpenInteract2::Response->new({ cgi => $fcgi_request });

        $log->error("Creating request");
        my $request  = OpenInteract2::Request->new({ cgi => $fcgi_request });

        $log->error("Calling auth->new");

        OpenInteract2::Auth->new()->login();

        $log->error("Creating controller object");

        my $controller = eval {
            OpenInteract2::Controller->new( $request, $response )
        };
        if ( $@ ) {
            $log->error("Controller returned error: $@");
            $response->content( $@ );
        }
        else {
            $log->error("Executing controller");
            $controller->execute;
        }

        $log->error("Sending response");

        $response->send;

        $log->error("Cleaning up");

        $ctx->cleanup_request;

        #DB::disable_profile();

        $log->error(Dumper($SPOPS::Tie::COUNT));
    }
}

