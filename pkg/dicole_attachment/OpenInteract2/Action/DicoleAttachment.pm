package OpenInteract2::Action::DicoleAttachment;

use strict;
use warnings;
use feature qw(switch);

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use MIME::Base64 ();
use File::Copy ();
use LWP::Simple              qw(getstore);
use File::Temp ();
use Dicole::MogileFS;
use MIME::Base64 ();
use Digest::SHA;

sub store_from_request_upload {
    my ( $self ) = @_;

    die 'no upload_name param found.'
        unless CTX->request->param( $self->param('upload_name') );

    if (!CTX->request->upload( $self->param('upload_name') )) {
        die 'no upload_object found. did you remember to put init_tool upload => 1';
    }

    my $upload_object = CTX->request->upload( $self->param('upload_name') );

    unless ($upload_object->filehandle) {
        get_logger(LOG_APP)->error("Upload " . $self->param('upload_name') . " did not have a defined filehandle");
        return;
    }

    return $self->_store_from_fh(
        $upload_object->filehandle,
        $upload_object->filename
    );
}

sub store_from_bits {
    my ( $self ) = @_;

    my $temp = File::Temp->new;

    $temp->print($self->param('bits'));
    $temp->flush;
    $temp->seek(0, 0);

    return $self->_store_from_fh(
        $temp,
        $self->param('filename') || '?'
    );
}

sub store_from_base64 {
    my ( $self ) = @_;

    $self->param(bits => MIME::Base64::decode($self->param('base64_data')));
    $self->store_from_bits;
}

sub store_from_fh {
    my ($self) = @_;

    return $self->_store_from_fh(
        $self->param('filehandle'),
        $self->param('filename') || '?'
    );
}

sub _store_from_fh {
    my ($self, $fh, $filename) = @_;

    $filename ||= '?';
    $self->_populate_params;

    my $attachment = CTX->lookup_object('attachment')->new;

    $attachment->filename($filename);

    my $size = -s $fh;
    $attachment->byte_size( $size || 0 );

    $self->_set_attachment_from_params($attachment);
    $self->_store_attachment_fh($attachment, $fh);
    my $mime = $self->_set_attachment_mime_type($attachment, $filename, $fh);

    $attachment->video_length_seconds($self->_video_length_in_seconds($attachment, $fh))
        if $mime =~ /video/;

    $attachment->save;

    return $attachment;
}

sub _set_attachment_mime_type {
    my ($self, $attachment, $filename, $fh) = @_;

    my $checker = Dicole::Files::MimeType->new;
    my $mime = $checker->mime_type_by_extension($attachment->filename)
        || $checker->mime_type_filehandle($fh)
        || 'application/octet-stream';

    $attachment->mime( $mime );

    return $mime;
}

sub _set_attachment_from_params {
    my ($self, $attachment) = @_;

    $attachment->owner_id( $self->param('owner_id') || 0 );
    $attachment->creation_time( time );
    $attachment->user_id( $self->param('user_id') || 0 );
    $attachment->domain_id( $self->param('domain_id') || 0 );
    $attachment->group_id( $self->param('group_id') || 0 );
    $attachment->object_id( $self->param('object_id') );
    $attachment->object_type( $self->param('object_type') );
    $attachment->save;
}

sub serve {
    my ( $self ) = @_;

    my $attachment = $self->param( 'attachment' ) ||
        CTX->lookup_object('attachment')->fetch( $self->param( 'attachment_id' ) );

    die "security error" unless $attachment;

    my @mogile_urls = do {
        if ($self->param('thumbnail')) {
            $self->_serve_thumbnail($attachment)
        }
        elsif ($self->param('preview')) {
            $self->_serve_preview($attachment)
        }
        elsif ($self->param('embeddable_video')) {
            $self->_serve_embeddable_video($attachment)
        }
        elsif ($self->param('embeddable_audio')) {
            $self->_serve_embeddable_audio($attachment)
        }
        else {
            CTX->response->content_type($attachment->mime || 'application/octet-stream');
            $self->_mogile->get_urls($attachment->id);
        }
    };

        get_logger(LOG_APP)->debug("Got mogile URLs: @mogile_urls");

        die "Legacy mode disabled" unless @mogile_urls;

    my $urls = join( " ", @mogile_urls );
    my $etag = Digest::SHA::sha1_base64( join( "", sort( @mogile_urls ) ) );

    if ( CTX->request->cgi->http('If-None-Match') && CTX->request->cgi->http('If-None-Match') eq $etag ) {
        CTX->response->status(304);
    }
    else {
# Note: this should be enabled somehow to allow fronts without perlbal, but so that nginx+perlbal could still work
        CTX->response->header('X-Content-Type' => $attachment->mime || 'application/octet-stream' );
        CTX->response->header('X-Accel-Redirect' => '/reproxy' );
        CTX->response->header('X-REPROXY-URL' => join( " ", @mogile_urls ) );
        if ( CTX->request->cgi->http('Range') ) {
            CTX->response->header('Range' => CTX->request->cgi->http('Range') );
        }
        else {
            CTX->response->header('ETag', $etag );
        }

        if ( $self->param('download') ) {
            CTX->response->header( 'Content-Disposition', 'attachment; filename="' . $attachment->filename . '"' );
        }
    }
}

sub _serve_embeddable_video {
    my ($self, $attachment) = @_;

    my $type = $self->param('video_type') || '';
    my $mime_type = { mp4 => 'video/mp4', ogv => 'video/ogg' }->{ $type } || 'video/x-flv';

    CTX->response->content_type( $mime_type );

    return $self->_mogile->get_urls($attachment->id)
        if $attachment->mime eq $mime_type;

    my $embedded_key = $attachment->id . "_embedded" . ( $type ? '_' . $type : '' );

    my @urls = $self->_mogile->get_urls($embedded_key);

    return @urls if @urls;

    my $video_fh = $self->_create_embeddable_video($attachment, $type);

    $self->_mogile->store_fh($embedded_key => $video_fh);

    return $self->_mogile->get_urls($embedded_key);
}

sub _create_embeddable_video {
    my ( $self, $attachment, $type ) = @_;

    my ($video_url) = $self->_mogile->get_urls($attachment->id)
        or return;

    my ( $suffix ) = $attachment->filename =~ /.*\.(.*)/;

    my $video    = File::Temp->new( $suffix ? ( SUFFIX => '.' . $suffix ) : () );
    my $in       = $video->filename;

    my $embedded = File::Temp->new(SUFFIX => $type ? '.' . $type : '.flv' );
    my $out      = $embedded->filename;

    getstore $video_url => $in;

    my $parameters = $type eq 'ogv'
        ? '-acodec libvorbis -ac 2 -ab 128k -ar 44100'
        : $type eq 'mp4'
            ? '-acodec aac -ac 2 -ab 128k -ar 44100 -vcodec libx264 -vpre ipod640 -b 1200k -f mp4 -threads 0'
            : '-ar 11025';

    my $output = qx(/usr/local/bin/ffmpeg -y -i $in $parameters $out 2>&1);

    get_logger(LOG_APP)->debug("ffmpeg: $output");

    return $embedded;
}

sub _serve_embeddable_audio {
    my ($self, $attachment) = @_;

    my $type = $self->param('audio_type') || 'mp3';
    my $mime_type = { ogg => 'audio/ogg', mp3 => 'audio/mpeg3' }->{ $type };

    CTX->response->content_type( $mime_type );

    return $self->_mogile->get_urls($attachment->id)
        if $attachment->mime eq $mime_type;

    my $embedded_key = $attachment->id . "_embedded_" . $type;

    my @urls = $self->_mogile->get_urls($embedded_key);

    return @urls if @urls;

    my $audio_fh = $self->_create_embeddable_audio($attachment, $type);

    $self->_mogile->store_fh($embedded_key => $audio_fh);

    return $self->_mogile->get_urls($embedded_key);
}

sub _create_embeddable_audio {
    my ( $self, $attachment, $type ) = @_;

    my ($audio_url) = $self->_mogile->get_urls($attachment->id)
        or return;

    my ( $suffix ) = $attachment->filename =~ /.*\.(.*)/;

    my $audio    = File::Temp->new( $suffix ? ( SUFFIX => '.' . $suffix ) : () );
    my $in       = $audio->filename;

    my $embedded = File::Temp->new( SUFFIX => '.' . $type );
    my $out      = $embedded->filename;

    getstore $audio_url => $in;

    my $parameters = $type eq 'ogg'
        ? '-acodec libvorbis'
        : '';

    my $output = qx(/usr/local/bin/ffmpeg -y -i $in $parameters $out 2>&1);

    get_logger(LOG_APP)->debug("ffmpeg: $output");

    return $embedded;
}

sub _serve_preview {
    my ($self, $attachment) = @_;

    return $self->_serve_thumbnail( $attachment, 1 );
}

sub _serve_thumbnail {
    my ($self, $attachment, $preview) = @_;

    my $log = get_logger(LOG_APP);

    $log->debug("Attempting to serve thumbnail...");

    CTX->response->content_type( $preview ? 'image/jpg' : 'image/png');

    my $thumbnail_key = join( '_',
        $attachment->id,
        ( $preview ? 'preview' : 'thumb' ),
        $self->param('force_width')  || 0,
        $self->param('force_height') || 0,
        $self->param('max_width')    || 0,
        $self->param('max_height')   || 0,
    ) . '.image';

    $log->debug("Thumbnail key: $thumbnail_key");

    # Perhaps a thumbnail has already been created
    my @thumb_urls = $self->_mogile->get_urls($thumbnail_key);

    $log->debug("URLs: @thumb_urls");

    return @thumb_urls if @thumb_urls;

    # I guess not. Let's create one.
    my @image_urls = $self->_mogile->get_urls($attachment->id)
        or do {
            get_logger(LOG_APP)->info("Failed to fetch urls for image '" . $attachment->id . "'");
            return;
        };

    $log->debug("Original URLs: @image_urls");

    my $temp = File::Temp->new;

    my $code = getstore $image_urls[0] => $temp->filename;

    if ($code != 200) {
        $log->error("Failed to fetch '$image_urls[0]'");
        return;
    }

    my $thumbnail_fh;

    $log->debug("Thumbnailing file with MIME " . $attachment->mime);

    my $given = $attachment->mime;
    if ( 1 ) {
        if ( $given =~ /image/) {
            $thumbnail_fh = $self->_create_image_thumbnail($temp, $preview);
        }
        elsif ( $given =~ /video/) {
            $thumbnail_fh = $self->_create_video_thumbnail($attachment, $temp);
        }
    }

    $self->_mogile->store_fh($thumbnail_key => $thumbnail_fh);

    @thumb_urls = $self->_mogile->get_urls($thumbnail_key)
        or do {
            get_logger(LOG_APP)->error("Failed to fetch urls for thumbnail '$thumbnail_key'");
            return;
        };

    return @thumb_urls;
}

sub get_attachments_for_object {
    my ( $self ) = @_;

    return $self->_get_attachments_using_params;
}

sub purge_attachments_for_object {
    my ( $self ) = @_;

    my $as = $self->_get_attachments_using_params;
    $_->remove for @$as;

    return 1;
}

sub reattach {
    my ( $self ) = @_;

    $self->_populate_params;

    my $a = $self->param('attachment') ||
        CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') );

    $a->user_id( $self->param( 'user_id' ) || 0 );
    $a->group_id( $self->param( 'group_id' ) || 0 );
    $a->object_id( $self->param( 'object_id' ) );
    $a->object_type( $self->param( 'object_type' ) );

    $a->domain_id( $self->param( 'domain_id' ) ) if defined $self->param('domain_id');

    $a->save;
}

sub copy {
    my ( $self ) = @_;

    my $a = $self->param('attachment') ||
        ($self->param('attachment_id')
            && CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') ));

    $self->param(filename => $a->filename);
    $self->param(mime     => $a->mime);
    $self->param(bits     => ${ $self->_bits_ref_for_attachment($a) });

    return $self->store_from_bits;
}

sub remove {
    my ( $self ) = @_;

    $self->_populate_params;

    my $a = $self->param('attachment') ||
        CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') );

    $a->remove;
}

sub get_object {
    my ( $self ) = @_;

    $self->_populate_params;

    my $a = $self->param('attachment') ||
        CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') );

    return $a;
}

sub filehandle {
    my ( $self ) = @_;

    $self->_populate_params;

    my $a = $self->param('attachment') ||
        CTX->lookup_object('attachment')->fetch( $self->param('attachment_id') );

    return $self->_fh_for_attachment( $a );
}

sub byte_size {
    my ( $self ) = @_;

    my $attachment = $self->param( 'attachment' ) ||
        CTX->lookup_object('attachment')->fetch( $self->param( 'attachment_id' ) );

    return $attachment->byte_size;
}

sub file_as_base64 { MIME::Base64::encode ${ shift->file_as_bits_ref } }
sub file_as_bits   {                      ${ shift->file_as_bits_ref } }

sub file_as_bits_ref {
    my ( $self ) = @_;

    my $attachment = $self->param( 'attachment' ) ||
        CTX->lookup_object('attachment')->fetch( $self->param( 'attachment_id' ) );

    die "security error" unless $attachment;

    return $self->_bits_ref_for_attachment( $attachment );
}

sub thumbnail_as_base64 { MIME::Base64::encode ${ shift->thumbnail_as_bits_ref } }
sub thumbnail_as_bits   {                      ${ shift->thumbnail_as_bits_ref } }

sub thumbnail_as_bits_ref {
    my ( $self ) = @_;

    my $attachment = $self->param( 'attachment' ) ||
        CTX->lookup_object('attachment')->fetch( $self->param( 'attachment_id' ) );

    die "security error" unless $attachment;

    die "unimplemented";
}

sub video_length_in_seconds {
    my ( $self ) = @_;

    my $a = $self->param( 'attachment' ) ||
        CTX->lookup_object('attachment')->fetch( $self->param( 'attachment_id' ) );

    return $self->_video_length_in_seconds( $a );
}

sub get_attachment_list_data_for_object {
    my ( $self ) = @_;

    $self->_populate_params;
    my $attachments = $self->param('attachments') || $self->_get_attachments_using_params;
    my $object = $self->param('object');

    $attachments = [ sort { $b->creation_time <=> $a->creation_time } @$attachments ];

    my $uid = CTX->request->auth_user_id;

    my @adata = ();

    for my $a ( @$attachments ) {
        my $thumbnail_url = $self->param('action')->derive_url(
            action     => $self->param('action_name') || $self->param('action')->name,
            task       => $self->param('task_name') || 'attachment',
            additional => [ $object->id, $a->id, $a->filename ],
            params     => { thumbnail => 1 },
        );

        push @adata, {
            creation_time => $a->creation_time,
            filename      => $a->filename,
            mime          => $a->mime,
            download_url  => $self->param('action')->derive_url(
                action     => $self->param('action_name') || $self->param('action')->name,
                task       => $self->param('task_name') || 'attachment',
                additional => [ $object->id, $a->id, $a->filename ],
            ),
            list_image_url => ( $a->mime =~ /image/ )
                                ? CTX->lookup_action('thumbnails_api')->execute( create => {
                                    url    => $thumbnail_url,
                                    width  => 150,
                                    height => 95,
                                  } )
                                : '',
            thumbnail_url => ( $a->mime =~ /image/ ) ? $thumbnail_url : '',
            delete_url    => ( $self->param('delete_all_right') || $uid == $a->owner_id )
                ? $self->param('action')->derive_url(
                    action     => $self->param('delete_action_name')
                                    || $self->param('action_name')
                                    || $self->param('action')->name,
                    task       => $self->param('delete_task_name') || 'attachment_remove_data',
                    additional => [ $object->id, $a->id ],
                  )
                : '',
        };
    }

    return \@adata;
}

sub get_attachment_list_html_for_object {
    my ( $self ) = @_;

    my $adata = $self->get_attachment_list_data_for_object;

    return $self->generate_content( { attachments => $adata }, { name => 'dicole_attachment::attachment_list' } );
}


sub _video_length_in_seconds {
    my ( $self, $a, $fh ) = @_;

    die "security error" unless $a;
    die "security error" unless $a->mime =~ /video/;

    return $a->image_length_seconds if $a->image_length_seconds;

    my ($f, $temp);

    $temp = File::Temp->new;

    { local $/; $temp->print(<$fh>) }

    $f = $temp->filename;

    my $data = `ffmpeg -i $f 2>&1`;
    my ( $duration ) = $data =~ /Duration:\s*(\d+:\d+:\d+)/;

    return 0 unless $duration;

    my ( $h, $m, $s ) = split ':', $duration;
    return $s + $m*60 + $h*60*60;
}

sub _bits_ref_for_attachment {
    my ( $self, $a ) = @_;

    return $self->_bits_ref_from_fh( $self->_fh_for_attachment( $a ) );
}

sub _fh_for_attachment {
    my ( $self, $attachment ) = @_;

    my $log = get_logger(LOG_APP);

    my @image_urls = $self->_mogile->get_urls($attachment->id)
        or do {
            get_logger(LOG_APP)->error("Failed to fetch urls for image '" . $attachment->id . "'");
            return;
        };

    $log->debug("Original URLs: @image_urls");

    my $temp = File::Temp->new;

    my $code = getstore $image_urls[0] => $temp->filename;

    if ($code != 200) {
        $log->rror("Failed to fetch '$image_urls[0]'");
        return;
    }

    return $temp;
}

sub _bits_ref_from_fh {
    my ( $self, $fh ) = @_;
    my $buffer = '';
    my @parts = ();

    binmode $fh;
    while ( read( $fh, $buffer, 1*1024*1024 ) ) {
        push @parts, $buffer;
    }
    $buffer = join( '', @parts );

    return \$buffer;
}

sub _get_attachments_using_params {
    my ( $self, $prefix ) = @_;

    $self->_populate_params( $prefix );

    return CTX->lookup_object('attachment')->fetch_group( {
        where => 'user_id = ? AND group_id = ? AND object_id = ? AND object_type = ?',
        value => [
            $self->param( join "_", ($prefix || () , 'user_id'    )) || 0,
            $self->param( join "_", ($prefix || () , 'group_id'   )) || 0,
            $self->param( join "_", ($prefix || () , 'object_id'  )) ,
            $self->param( join "_", ($prefix || () , 'object_type')) ,
        ],
    } ) || [];
}

sub _store_attachment_fh {
    my ( $self, $attachment, $fh ) = @_;

    my $key = $attachment->id;

    $self->_mogile->store_fh($key, $fh);

    return $key;
}

sub _create_video_thumbnail {
    my ( $self, $a, $temp ) = @_;

    get_logger(LOG_APP)->debug("Thumbnailing video");

    my $duration = $self->_video_length_in_seconds( $a, $temp );
    my $halfway = int( $duration / 2 );

    my $temp_out = File::Temp->new;

    my $in  = $temp->filename;
    my $out = $temp_out->filename;

    my $cmd_out = qx(ffmpeg -y -ss $halfway -i $in -f mjpeg -vframes 1 -an $out);

    get_logger(LOG_APP)->debug("Conversion output: $cmd_out");

    return $temp_out;
}

sub _create_image_thumbnail {
    my ( $self, $infh, $preview ) = @_;

    my $image = Image::Magick->new;

    return if $self->_check_magick_error( $image->Read( file => $infh ) );

    $image->AutoOrient();

    my $fw = $self->param('force_width')  || 0;
    my $fh = $self->param('force_height') || 0;
    my $iw = $image->Get( 'width' )       || 0;
    my $ih = $image->Get( 'height' )      || 0;

    if ( $fw && $fh ) {
        my $image_ratio = $ih / $iw;
        my $target_ratio = $fh / $fw;

        if( $image_ratio > $target_ratio ) {
            $ih = $fw / $iw * $ih;
            $iw = $fw;
        }
        else {
            $iw = $fh / $ih  * $iw;
            $ih = $fh;
        }

        $self->_check_magick_error( $image->Thumbnail( width => $iw, height => $ih ) );
        $self->_check_magick_error(
            $image->Crop(width => $fw, height => $fh, x => $iw / 2 - $fw / 2, y => $ih / 2 - $fh / 2)
        );
        $self->_check_magick_error( $image->Set( page =>  int($fw) . 'x' . int($fh) . '+0+0' ) );
    }
    else {
        my $mw = $self->param('max_width')  || 0,
        my $mh = $self->param('max_height') || 0,

        my $tw = $iw;
        $tw = $mw if $mw && $tw > $mw;
        $tw = $fw if $fw;

        my $th = $ih;
        $th = $mh if $mh && $th > $mh;
        $th = $fh if $fh;

        # If the height is determined by the image width
        if ( ! $fh ) {
            $th = int( $tw * $ih / $iw );
            if ( $mh && $th > $mh ) {
                $th = $mh;
                unless ( $fw ) {
                    $tw = int( $th * $iw / $ih );
                }
            }
        }
        elsif ( ! $fw ) {
            $tw = int( $th * $iw / $ih );
            if ( $mw && $tw > $mw ) {
                $tw = $mw;
            }
        }

        $tw = 1 unless $tw;
        $th = 1 unless $th;

        $self->_check_magick_error( $image->Thumbnail( width => $iw, height => $ih ) );
        $self->_check_magick_error( $image->Scale(
            width => $tw, height => $th,
        ) );
    }

    open my $image_fh, '+>', undef or die "Failed to write image to a temporary file: $!";

    $image->Write(file => $image_fh, filename => $preview ? 'image.jpg' : 'image.png' );

    seek $image_fh, 0, 0;

    return $image_fh;
}

sub _check_magick_error {
    my ( $self, $error ) = @_;
    return unless $error;
    $error =~ /(\d+)/;
    # Status code less than 400 is a warning
    $self->log( 'error',
        "Image::Magick returned status $error while resizing attachment image"
    );
    if ( $1 >= 400 ) {
        return 1;
    }
    return;
}

sub _populate_params {
    my ( $self, $prefix ) = @_;

    $self->_populate_object_params( join "_", ( $prefix || (), 'object' ) );
    $self->_populate_id_params( $prefix );
}

sub _populate_id_params {
    my ( $self, $prefix ) = @_;

    $prefix = $prefix ? $prefix . '_' : '';

    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $self->param( $prefix . 'user_id', $ia->param('target_type') eq 'user' ? $ia->param('target_user_id') : 0 )
            unless defined $self->param( $prefix . 'user_id' );
        $self->param( $prefix . 'group_id', $ia->param('target_type') eq 'group' ? $ia->param('target_group_id') : 0 )
            unless defined $self->param( $prefix . 'group_id' );
        $self->param( $prefix . 'domain_id', Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) || 0 );
    }
    if ( my $req = CTX->request ) {
        $self->param( $prefix . 'owner_id', $req->auth_user_id || 0 ) unless defined $self->param( $prefix . 'owner_id' );
    }
}

sub _populate_object_params {
    my ( $self, $param ) = @_;

    if ( my $object = $self->param( $param ) ) {
        $self->param( $param . '_id', $object->id )
            unless defined $self->param( $param . '_id' );
        $self->param( $param . '_type', ref( $object ) )
            unless defined $self->param( $param . '_type' );
    }
}

sub _mogile {
    my $self = shift;

    return $self->{_mogile} ||= Dicole::MogileFS->new(
        domain => 'dicole.dcp.attachments',
        class  => 'attachment'
    );
}

1;
