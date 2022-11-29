package Dicole::Response::Apache;

use base qw( Dicole::Response OpenInteract2::Response::Apache );
use Apache::Constants        qw( REDIRECT );
use HTTP::Status             qw( RC_OK RC_FOUND );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use Unicode::MapUTF8;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/ );

my ( $log );

sub init {
    OpenInteract2::Response::Apache::init( @_ );
}

sub clear_current {
    OpenInteract2::Response::Apache::clear_current( @_ );
}

sub redirect {
    OpenInteract2::Response::Apache::redirect( @_ );
}


sub send {
    my ( $self ) = @_;

    $log ||= get_logger( LOG_RESPONSE );

    $log->is_info && $log->info( "Sending Apache response" );

    my $apache = $self->apache;

    $self->save_session;

    my $headers_out = $apache->headers_out;
    foreach my $cookie ( @{ $self->cookie } ) {
        $log->is_debug &&
            $log->debug( sprintf( "Adding cookie header to apache '%s'",
                                  $cookie->as_string ) );
        $headers_out->add( 'Set-Cookie', $cookie->as_string );
    }

    while ( my ( $name, $value ) = each %{ $self->header } ) {
        $log->is_debug &&
            $log->debug( "Adding header to apache '$name' = '$value'" );
        $headers_out->add( $name, $value );
    }

    my $filename = undef;

    if ( $self->is_redirect ) {
        $log->is_info &&
            $log->info( "Sending redirect to Apache" );
        $apache->content_type( 'text/html' );
        $apache->status( REDIRECT );
        $apache->send_http_header();
    }
    elsif ( $filename = $self->send_file || $self->send_filehandle ) {
        $self->set_file_info;
        my $fh = $self->send_filehandle;
        unless ( $fh ) {
            $fh = $apache->gensym;
            eval { open( $fh, "< $filename" ) || die $!; };
            if ( $@ ) {
                oi_error "Cannot open file from filesystem [$filename]: $@";
            }
        }
        $self->_send_header;
        $apache->send_fd( $fh );
    }
    else {
        $self->_send_header;
        my $content = ${ $self->content };
        my $content_type = $self->content_type;
        if ( $content_type =~ /^text\/html/ && $content_type =~ /^(.*); charset=(.*)$/ ) {
            my $charset = $2;

# If you have problems with UTF-8, uncomment
# this to force iso-8859-1

#            if ( $charset && $charset ne 'utf-8' ) {
#                $log->is_debug &&
#                    $log->debug( "Converting content from utf8 to charset '$charset'" );
#                $content = Unicode::MapUTF8::from_utf8( {
#                    -string => $content,
#                    -charset => $charset
#                } );
#            }

        }
        $apache->print( $content );
    }
}

1;
