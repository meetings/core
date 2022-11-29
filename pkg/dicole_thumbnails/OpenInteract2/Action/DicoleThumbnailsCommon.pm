package OpenInteract2::Action::DicoleThumbnailsCommon;
use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use File::Temp;
use Dicole::MogileFS;
use Image::Magick;
use Digest::SHA;

my $mogile = Dicole::MogileFS->new(
    domain => 'dicole.dcp.thumbnails', 
    class  => 'thumbnail'
);

sub MOGILE {
    return $mogile;
}

sub _store {
    my ($self, $key, $thumb_image) = @_;

    open my $thumb, '+>', undef or die $!;

    $thumb_image->Set(magick => 'png');
    $thumb_image->Write(file => $thumb);

    seek $thumb, 0, 0;

    return $self->MOGILE->store_fh($key => $thumb);
}

sub _key {
    my ($self, $params) = @_;

    my $url      = $params->{url};
    my $width    = $params->{width}  || 0;
    my $height   = $params->{height} || 0;

    my $digest = Digest::SHA::sha1_base64($url);
    $digest =~ tr#/+#_-#;

    return join( '_', $digest, $width, $height ) . '.png';
}

sub _fetch {
    my ($self, $url, $width, $height) = @_;

    get_logger(LOG_APP)->debug("_fetch: Fetching '$url'");

    my $content = eval { Dicole::Utils::HTTP->get( $url, 5 ) };

    if ($@) {
        get_logger(LOG_APP)->debug("_fetch: Failed to fetch '$url': " . $@);
        return;
    }

    my $temp = File::Temp->new;

    $temp->print($content);
    $temp->seek(0, 0);

    get_logger(LOG_APP)->debug("_fetch: Fetched '$url' to '" . $temp->filename . "'");

    return $temp;
}

sub _create_thumb {
    my ($self, $file, $width, $height) = @_;

    my $image = Image::Magick->new;
    my $image_error = $image->Read(file => $file);

    if ("$image_error") { # Yes, this is how PerlMagick signals an error
        get_logger(LOG_APP)->debug("_create_thumb: $image_error");
        return
    }

    $self->_crop_image($image, $width, $height);
    
    return $image;
}

sub _crop_image {
	my( $self, $image, $width, $height ) = @_;
	
	my $image_width = $image->Get('width');
    my $image_height = $image->Get('height');

    die "Failed to get width or height of image" unless $image_width && $image_height;

    my $image_ratio = $image_height / $image_width;
    
    my $target_ratio = $image_ratio;
    if ( $height && $width ) {
        $target_ratio = $height / $width;
    }
    elsif ( $width ) {
        $height = int( $width * $image_ratio );
    }
    elsif ( $height ) {
        $width = int( $height / $image_ratio );
    }
    else {
        $width = $image_width;
        $height = $image_height;
    }

    if($image_ratio > $target_ratio) {
        $image_height = $width / $image_width * $image_height;
        $image_width = $width;
    }
    else {
        $image_width = $height / $image_height  * $image_width;
        $image_height = $height;
    }

    $image->Thumbnail(width => $image_width, height => $image_height);
    $image->Crop(width => $width, height => $height, x => $image_width / 2 - $width / 2, y => $image_height / 2 - $height / 2);
}

1;
