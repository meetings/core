package OpenInteract2::Action::DicoleThumbnailsAPI;
use strict;

use base qw( OpenInteract2::Action::DicoleThumbnailsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use URI ();
use Dicole::URL;
use Dicole::Utils::User;
use Dicole::Cache;
use Dicole::Utils::Trace;

our $FAILURE_TIMEOUT = 12 * 60 * 60; # seconds

sub create {
    my ($self) = @_;

    my $url      = URI->new($self->param('url'));
    my $width    = $self->param('width')    || 0;
    my $height   = $self->param('height')   || 0;
    my $no_cache = $self->param('no_cache') || 0;

    get_logger(LOG_APP)->debug("Create thumbnail from $url");

    my $key  = $self->_key($self->param);

    my $trace = Dicole::Utils::Trace->start_trace("check $key: $url");

    my @urls = $self->MOGILE->get_urls($key);

    Dicole::Utils::Trace->end_trace($trace);

    return Dicole::URL->from_parts(
        domain_id => $self->param('domain_id'),
        action => 'thumbnails',
        task   => 'serve',
        additional => [ $key ]
    ) if @urls and not $no_cache;
 
    my $plain_url = $url;

    if ( $url->scheme !~ /^https?/ ) {
        return unless CTX->request;
        $url = $url->abs(Dicole::URL->get_server_url);
        $url->query_param(dic => Dicole::Utils::User->temporary_authorization_key(CTX->request->auth_user));
    }
   
    return unless $self->_should_we_even_bother($plain_url);

    get_logger(LOG_APP)->debug("Storing new file in mogile");

    $trace = Dicole::Utils::Trace->start_trace("fetch $url");

    my $original = $self->_fetch($url);

    Dicole::Utils::Trace->end_trace($trace);

    unless ($original) {
        get_logger(LOG_APP)->error("Failed to create image of '$url'");
        Dicole::Cache->update("thumbnail_fetch_data_for_$plain_url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return
    }

    $trace = Dicole::Utils::Trace->start_trace("thumbnail $url");

    my $thumb_image = eval { $self->_create_thumb($original, $width, $height) };

    Dicole::Utils::Trace->end_trace($trace);

    if ($@) {
        get_logger(LOG_APP)->error("Failed to create thumbnail for '$url': $@");
        Dicole::Cache->update("thumbnail_fetch_data_for_$plain_url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return
    }

    unless ($thumb_image) {
        get_logger(LOG_APP)->error("Failed to create thumbnail image of '$url'");
        Dicole::Cache->update("thumbnail_fetch_data_for_$plain_url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return
    }

    $trace = Dicole::Utils::Trace->start_trace("store $url");

    $self->_store($key => $thumb_image);

    Dicole::Utils::Trace->end_trace($trace);

    # DO NOT REMOVE THIS UNDEF! Otherwise perl crashes mysteriously upon scope cleanup ^_^
    undef $thumb_image;

    return Dicole::URL->from_parts(
        action => 'thumbnails',
        task   => 'serve',
        additional => [ $key ]
    );
}

sub _should_we_even_bother {
    my ($self, $url) = @_;

    my $key = "thumbnail_fetch_data_for_$url";

    my $stats = Dicole::Cache->fetch($key, { no_domain_id => 1, no_group_id => 1 }) or return 1;

    if ($stats->{timestamp} > time - $FAILURE_TIMEOUT * $stats->{tries}) {
        get_logger(LOG_APP)->error(
            "Skipping thumbnailing of '$url' due to previous failures: " . 
            "$stats->{tries} failed downloads, previous at $stats->{timestamp}"
        );
        return
    }

    return 1
} 

sub refresh {
    my ($self) = @_;

    my $url      = $self->param('url');
    my $width    = $self->param('width')    || 0;
    my $height   = $self->param('height')   || 0;
    my $no_cache = $self->param('no_cache') || 0;

    my $key = $self->_key($self->param);
 
    if ( $url->scheme !~ /^https?/ ) {
        $url = $url->abs(Dicole::URL->get_server_url);
        $url->query_param(dic => Dicole::Utils::User->temporary_authorization_key(CTX->request->auth_user));
    }
  
    my $original = $self->_fetch($url);

    unless ($original) {
        get_logger(LOG_APP)->debug("Failed to refresh image of '$url'");
        Dicole::Cache->update("thumbnail_fetch_data_for_$url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return;
    }
        
    my $thumb_image = eval { $self->_create_thumb($original, $width, $height) };

    unless ($thumb_image) {
        get_logger(LOG_APP)->debug("Failed to refresh thumbnail of '$url'");
        Dicole::Cache->update("thumbnail_fetch_data_for_$url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return
    }

    if ($@) {
        get_logger(LOG_APP)->debug("Failed to refresh thumbnail for '$url': $@");
        Dicole::Cache->update("thumbnail_fetch_data_for_$url" => sub { my $stats = shift // {}; $stats->{tries}++; $stats->{timestamp} = time; $stats }, { no_domain_id => 1, no_group_id => 1 });
        return;
    }

    $self->_store($key => $thumb_image);

    return $thumb_image->Get('Signature');
}

1;
