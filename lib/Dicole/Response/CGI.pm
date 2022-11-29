package Dicole::Response::CGI;

use base qw( Dicole::Response OpenInteract2::Response::CGI );
use OpenInteract2::Exception qw( oi_error );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Constants qw( :log );

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/ );

sub init {
    OpenInteract2::Response::CGI::init( @_ );
}
sub send {
    my ( $self ) = @_;

    $self->save_session;

    if ( $self->send_file || $self->send_filehandle ) {
        $self->set_file_info;
        my $fh = $self->send_filehandle || IO::File->new( "< " . $self->send_file )
                    || oi_error "Cannot open file [$filename]: $!";
        $self->out( $self->generate_cgi_header_fields, "\r\n\r\n" );
        my ( $data );
        while ( $fh->read( $data, 1024 ) ) {
            $self->out( $data );
        }
        return;
    }

    if ( ! $self->header( "Content-Length" ) ) {
        # Using bytes reported too a big size in some cases
        my $contentref = $self->content;
        $self->header( "Content-Length" => length( $$contentref ) );
    }

    $self->out( $self->generate_cgi_header_fields, "\r\n\r\n" );
    $self->out( $self->content );
}
#sub response {
#    OpenInteract2::Response::CGI::response( @_ );
#}
sub redirect {
    OpenInteract2::Response::CGI::redirect( @_ );
}
