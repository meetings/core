package Dicole::Handler;

use strict;
use Apache2::RequestRec ();
use Apache2::Connection ();
use Apache2::URI ();
use Apache2::Const           qw( OK );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Auth;
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Request;
use OpenInteract2::Response;

use Dicole::RuntimeLogger;

require APR::SockAddr;

use Time::HiRes qw( gettimeofday );

my ( $log );

sub handler : method {
    my ( $class, $r ) = @_;

    Dicole::RuntimeLogger->flush_timestamps;
    Dicole::RuntimeLogger->rlog('Handler execute');

    $log ||= get_logger( LOG_APP );

    $log->is_info &&
        $log->info( scalar( localtime ), ": request from ",
                    "'", $r->connection->remote_ip, "' for URL ",
                    "'", $r->construct_url, ( defined scalar( $r->args ) && "?" . scalar( $r->args ) ),
                    "'" );

    Dicole::RuntimeLogger->rlog('Handler create response');
    my $response = OpenInteract2::Response->new({ apache => $r });
    Dicole::RuntimeLogger->rlog('Handler create response');

    Dicole::RuntimeLogger->rlog('Handler create request');
    my $request  = OpenInteract2::Request->new({ apache => $r });
    Dicole::RuntimeLogger->rlog('Handler create request');

    Dicole::RuntimeLogger->rlog('Handler auth login');
    OpenInteract2::Auth->new()->login();
    Dicole::RuntimeLogger->rlog('Handler auth login');

    Dicole::RuntimeLogger->rlog('Handler create controller');
    my $controller = eval {
        OpenInteract2::Controller->new( $request, $response )
    };
    Dicole::RuntimeLogger->rlog('Handler create controller');

    if ( $@ ) {
        $log->error( "Error while creating controller: $@" );
        $response->content( \$@ );
    }
    else {
        Dicole::RuntimeLogger->rlog('Handler execute controller');
        eval { $controller->execute };
        Dicole::RuntimeLogger->rlog('Handler execute controller');
        if ( $@ ) {
            $log->error("Error while executing controller: $@" );
            $response->content( \$@ );
        }
    }

    Dicole::RuntimeLogger->rlog('Handler send response');
    $response->send;
    Dicole::RuntimeLogger->rlog('Handler send response');

    Dicole::RuntimeLogger->specify_timestamp('Handler execute', $request->url_relative );
    Dicole::RuntimeLogger->rlog('Handler execute');

    my $rlog = get_logger( 'RUNTIME' );
    $rlog->info( Dicole::RuntimeLogger->flush_timestamps( 1 ) ) if $rlog && $rlog->is_info;

    return OK;
}

1;

__END__

=head1 NAME

Apache::OpenInteract2 - OpenInteract2 Content handler for Apache 1.x

=head1 SYNOPSIS

 # Need to tell Apache to run an initialization script

 PerlRequire /path/to/my/site/conf/startup.pl

 # In httpd.conf file (or 'Include'd virtual host file)
 <Location />
    SetHandler perl-script
    PerlHandler Apache::OpenInteract2
</Location>

=head1 DESCRIPTION

This external interface to OpenInteract2 just sets up the
L<OpenInteract2::Request|OpenInteract2::Request> and
L<OpenInteract2::Response|OpenInteract2::Response> objects, creates an
L<OpenInteract2::Controller|OpenInteract2::Controller> and retrieves
the content from it, then sets the content in the response and returns
the proper error code to make Apache happy.

=head1 COPYRIGHT

Copyright (c) 2002-2005 Chris Winters. All rights reserved.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
