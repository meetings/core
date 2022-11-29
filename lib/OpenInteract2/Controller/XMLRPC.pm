package OpenInteract2::Controller::XMLRPC;

# $Id: XMLRPC.pm,v 1.5 2008-08-25 00:34:11 amv Exp $

use strict;
use base qw( OpenInteract2::Controller );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use RPC::XML;
use RPC::XML::Parser;
use Unicode::MapUTF8;

our $VERSION  = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

my ( $log );

my @FIELDS = qw( method no_decode );
__PACKAGE__->mk_accessors( @FIELDS );

sub execute {
    my ( $self ) = @_;
    $log ||= get_logger( LOG_ACTION );
    my $action = $self->initial_action;

    my $xmlrpc = RPC::XML::Parser->new;
    my $req = undef;
    my $status = undef;
    my $post_body = CTX->request->post_body;

    eval {
        $req = $xmlrpc->parse( $post_body );

        # RPC::XML::Parser returns the error string on error or an object
        die $req unless ref $req;

        # Because we will die when request is not valid XMLRPC,
        # we simply test it. XXX TODO This results in a malformed
        # xml detected error, maybe we should catch it.
        $req->name;
        $req->args;
    };

    # parsing the request went fine
    if ( not $@ and defined $req->name ) {

        $self->method( $req->name );  # name of the method

        my @args = map { $_->value } @{ $req->args };
        $action->param( rpc_params => \@args );

        # foo.bar => bar
        my ( $task ) = reverse split( /\./, $self->method );

        $action->task( $task );

        # Notify system of called rpc method
        $log->is_info &&
            $log->info( 'XML-RPC: Method called: [' . $self->method . ']' );

        $log->is_debug &&
            $log->debug( 'Executing top-level action [', $action->name, "] ",
                     "with task [", $action->task, "]" );

        $status = eval { $action->execute };

        if ( $@ ) {
            $log->error( "Caught exception while executing XML-RPC request: $@" );
            $status = RPC::XML::fault->new( 500, $@ );
        }
        else {
            $log->is_debug &&
                $log->debug( "Executed XML-RPC request ok" );
        }

    # an error in parsing the request
    } elsif ( $@ && $@ !~ /\@INC/) {
        my $error_msg = "Invalid XML-RPC request: " . $@ . "\nBody was:\n" . $post_body;
        $log->error( $error_msg );
        $status = RPC::XML::fault->new( 500, $error_msg );

    # something is wrong, but who knows what...
    } else {
        my $error_msg = "Invalid XML-RPC request: Unknown error";
        $log->error( $error_msg );
        $status = RPC::XML::fault->new( 500, $error_msg );
    }

    CTX->response->charset( 'utf-8' ) unless CTX->response->charset;
    $RPC::XML::ENCODING = CTX->response->charset;
    my $res = RPC::XML::response->new( $status );
    my $content = $res->as_string;

# These are disabled after move to utf-8
#     # For some reason we get a double encoding error if the content is in utf-8
#     if ( CTX->response->charset =~ /utf-8/i && !$self->no_decode ) {
#         $content = Unicode::MapUTF8::from_utf8( {
#            -string => $content, -charset => 'iso-8859-1'
#         } );
#     }
    eval {
        $res = $xmlrpc->parse( $content );
        die $res unless ref $res;
    };
    if ( $@ ) {
        my $error_msg = "Invalid XML-RPC response: " . $@ . "\nBody was:\n" . $content;
        $log->error( $error_msg );
#         # This might help in cases where no double encoding exist
#         $content = Unicode::MapUTF8::to_utf8( {
#            -string => $content, -charset => 'iso-8859-1'
#         } );
    }

    CTX->response->content_type( 'text/xml' );
    CTX->response->header( 'Content-Length', length( $content ) );
    CTX->response->content( \$content );

    return $self;
}

sub throw_fault {
    my ( $self, $code, $error_msg ) = @_;
    return RPC::XML::fault->new( $code, $error_msg );
}

1;
