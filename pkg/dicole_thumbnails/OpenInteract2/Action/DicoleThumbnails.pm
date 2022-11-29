package OpenInteract2::Action::DicoleThumbnails;
use strict;

use base qw( OpenInteract2::Action::DicoleThumbnailsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub serve {
    my ($self) = @_;

    my $key = $self->param('key') or die "oh no";

    get_logger(LOG_APP)->debug("Serving '$key'");

    my @urls = $self->MOGILE->get_urls($key);

    CTX->response->content_type('image/png');
    CTX->response->header('X-Content-Type' => 'image/png' );
    CTX->response->header('X-Accel-Redirect' => '/reproxy' );
    CTX->response->header('X-REPROXY-URL' => join( " ", @urls ) );
}

1;
