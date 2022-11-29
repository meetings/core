package OpenInteract2::Action::DicolePresentationsAPI;

use strict;
use base qw( OpenInteract2::Action::DicolePresentationsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Digest::SHA;
use LWP::Simple              qw(getstore);

sub create {
    my ( $self ) = @_;

    my $object = CTX->lookup_object('presentations_prese')->new;
    my $gid = $self->param('group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    Dicole::Utils::Data->set_note( domain_id => $domain_id, $object, { skip_save => 1 } );

    $object->name( $self->param('title') || '?' );
    $object->description( $self->param('description') );
    $object->duration( $self->param('duration') );
    $object->presenter( $self->param('presenter') );
    $object->embed( $self->param('embed') );
    $object->url( $self->param('url') );
    $object->prese_type( $self->param('prese_type') );
    $object->creator_id( $self->param('creator_id') || 0 );

    $object->group_id( $gid );
    $object->creation_date( $self->param('creation_date') || $self->param('created_date') || time );
    $object->featured_date( 0 );
    $object->rating_count( 0 );
    $object->rating( 0 );
    $object->scribd_id('');
    $object->scribd_key('');

    $object->save;

    my $tags_data = scalar( $self->param('tags') );

    CTX->lookup_action('tags_api')->e( attach_tags => {
        object => $object,
        group_id => $gid,
        user_id => 0,
        'values' => $tags_data,
        domain_id => $domain_id,
    } );

    if ( my $a = $self->param('attachment') || $self->param('attachment_attachment') ) {
        CTX->lookup_action( 'attachment')->execute( reattach => {
            attachment => $a,
            user_id => 0,
            group_id => $gid,
            object => $object,
            domain_id => $domain_id,
         } );
        $object->attachment_id( $a->id );
        $object->save;
        $self->_process_new_attachment_for_object( $object, $a, $domain_id );
    }
    elsif ( my $fh = $self->param('attachment_fh') || $self->param('attachment_filehandle') ) {
        my $a = CTX->lookup_action( 'attachment')->execute( store_from_fh => {
            filehandle => $fh,
            filename => $self->param('attachment_filename'),
            user_id => 0,
            group_id => $gid,
            object => $object,
            domain_id => $domain_id,
         } );
        $object->attachment_id( $a->id );
        $object->save;
        $self->_process_new_attachment_for_object( $object, $a, $domain_id );
    }

    if ( my $a = $self->param('image_attachment') ) {
        CTX->lookup_action( 'attachment')->execute( reattach => {
            attachment => $a,
            user_id => 0,
            group_id => $gid,
            object => $object,
            domain_id => $domain_id,
         } );
        $object->image( $a->id );
    }
    elsif ( my $fh = $self->param('image_fh') || $self->param('image_filehandle') ) {
        my $a = CTX->lookup_action( 'attachment')->execute( store_from_fh => {
            filehandle => $fh,
            filename => $self->param('image_filename'),
            user_id => 0,
            group_id => $gid,
            object => $object,
            domain_id => $domain_id,
         } );
        $object->image( $a->id );
    }
    elsif ( my $url = $self->param('image_url') || $self->param('image') ) {
        $object->image( $url );
    }

    $object->save;

    $self->_store_creation_event( $object, $tags_data, $domain_id );

    return $object;
}

# TODO: does only attachment updating for now
sub update_object {
    my ( $self ) = @_;

    my $object = $self->param('prese');
    $object ||= CTX->lookup_object('presentations_prese')->fetch( $self->param('prese_id') );

    my $domain_id = $self->param('domain_id');

    my $a = $self->param('attachment');
    if ( $a ) {
        if ( $a->id != $object->attachment_id ) {
            CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $object,
                domain_id => $domain_id,
                user_id => 0,
                group_id => $object->group_id,
            } );

            $object->attachment_id( $a->id );
            $object->scribd_id('');
            $object->scribd_key('');
            $object->scribd_type('');
        }

        $object->save;
        $self->_process_new_attachment_for_object( $object, $a, $domain_id );
    }

    $object->save;

    $self->_store_editing_event( $object, undef, $domain_id, $self->param('updating_user') || $self->param('updating_user_id') );

    return $object;
}

sub remove_object {
    my ( $self ) = @_;

    my $object = $self->param('prese');
    $object ||= CTX->lookup_object('presentations_prese')->fetch( $self->param('prese_id') );

    $self->_remove_object( $object, $self->param('domain_id'), $self->param('user_id') );

    return 1;
}

sub retrieve_new_box_image_for_prese {
    my ( $self ) = @_;

    my $round = $self->param('round');
    my $prese_id = $self->param('prese_id');

    $round ||= 1;
    my $prese = CTX->lookup_object('presentations_prese')->fetch( $prese_id );

    if ( $prese->image ) {
        return { success => 2 };
    }

    my $box_id = $prese ? Dicole::Utils::Data->get_note( new_box_view_document_id => $prese ) : '';

    if ( ! $box_id ) {
        get_logger(LOG_APP)->error( "Failed to find box_id for thumbnailing prese " . $prese_id );
        return { error => 10 };
    }

    my $token = $self->_new_box_token_for_prese( $prese );

    ### ALTERNATIVE for fetching metadata on old TLS 1.0 machines
    # my $api_domain = CTX->server_config->{dicole}->{meetings_api_domain};
    # my $helper_url = 'https://'.$api_domain.'/v1/helper_box_com_api_get';
    # my $params = Dicole::Utils::JSON->encode( {
    #     url => 'https://api.box.com/2.0/files/'. $box_id .'?fields=representations',
    #     headers => {
    #         'Authorization' => $token,
    #         'User-Agent' => 'curl',
    #         'x-rep-hints' => '[jpg?dimensions=320x320]'
    #     },
    # } );
    # my $result = Dicole::Utils::HTTP->post( $helper_url, { params => $params } );
    # my $data = Dicole::Utils::JSON->decode( $result );
    #
    # my $metajson = $data->{result}{body};
    # my $meta = eval { Dicole::Utils::JSON->decode( $metajson ) };

    my $metajson = Dicole::Utils::HTTP->get( 'https://api.box.com/2.0/files/'. $box_id .'?fields=representations', undef, undef, undef, $token, 'curl', { 'x-rep-hints' => '[jpg?dimensions=320x320]' } );

    my $meta = eval { Dicole::Utils::JSON->decode( $metajson ) };

    my $response;

    if ( ! $@ ) {
        if ( $meta->{representations}{entries} ) {
            for my $entry ( @{ $meta->{representations}{entries} } ) {
                next unless $entry->{status}{state} eq 'success';
                next unless $entry->{content}{url_template};
                my $asseturl = $entry->{content}{url_template};
                $asseturl =~ s/content\/.*/content\//;
                $response = Dicole::Utils::HTTP->get_response( $asseturl, undef, undef, undef, $token, 'curl' );
                last;
            }
        }
    }

    if ( $response && $response->code =~ /^2/ && $response->content ) {
        my $a = CTX->lookup_action('attachments_api')->e( store_from_bits => {
            object => $prese,
            group_id => $prese->group_id,
            user_id => 0,
            owner_id => $prese->creator_id,
            bits => $response->content,
            filename => 'media_thumb.png',
        } );

        $a->save;

        Dicole::Utils::Data->set_note( new_box_generated_thumb => 1 => $prese, { skip_save => 1 });
        $prese->image( $a->id );
        $prese->save;
    }
    else {
        if ( $round > 6 ) {
            get_logger(LOG_APP)->error( "Response for $prese_id thumbnail: " . Data::Dumper::Dumper( [ $response || $metajson ] ) );
        }
        elsif ( $round > 12 ) {
            get_logger(LOG_APP)->error( "Failed to create thumbnail in 12 rounds for prese $prese_id" );
            return { error => 1 };
        }

        Dicole::Utils::Gearman->do_delayed_task( retrieve_new_box_image_for_prese => {
            prese_id => $prese->id,
            round => $round + 1,
        }, 2**$round );

        return { success => 1000 };
    }

    return { success => 1 };
}

sub upload_new_box_file {
    my ( $self ) = @_;

    my $prese_id = $self->param('prese_id');

    my $prese = $self->_ensure_prese_object( $prese_id );
    my $domain_id = $self->_prese_domain_id( $prese );

    my $a = CTX->lookup_object('attachment')->fetch( $prese->attachment_id );

    # NOTE: Download from url because workers are not directly connected to mogile
    my $download_url = Dicole::URL->get_domain_url( $domain_id ) . Dicole::URL->from_parts(
        domain_id => $domain_id, target => $a->group_id,
        action => 'presentations', task => 'attachment_box',
        additional => [ $a->id, $a->filename ],
        params => { sec => $self->_generate_scribd_sec( $a->id ) }
    );

    my ( $suffix ) = $a->filename =~ /.*\.([a-z0-9]*)/;

    my $tmpfile = File::Temp->new( $suffix ? ( SUFFIX => '.' . $suffix ) : () );
    my $tmpfilename = $tmpfile->filename;

    getstore $download_url => $tmpfilename;

    my $token = $self->_new_box_token_for_prese( $prese );

    my $boxfilename = time . '-' . $a->id . ( $suffix ? '.' . $suffix : '' );

    ### ORIGINAL: works when run on new class of machines
    my $result = `curl -s -H 'Authorization: $token' -X POST -F attributes='{"name":"$boxfilename", "parent":{"id":"0"}}' -F file=\@$tmpfilename 'https://upload.box.com/api/2.0/files/content' 2>&1`;

    my $data = Dicole::Utils::JSON->decode( $result );

    ### ALTERNATIVE for uploading through api machines, from old machines witl TLS 1.0
    # my $api_domain = CTX->server_config->{dicole}->{meetings_api_domain};
    # my $result = `curl -s -F authorization='$token' -X POST -F attributes='{"name":"$boxfilename", "parent":{"id":"0"}}' -F file=\@$tmpfilename 'https://$api_domain/v1/helper_box_com_api_upload' 2>&1`;

    # my $data = Dicole::Utils::JSON->decode( $result );
    # $data = Dicole::Utils::JSON->decode( $data->{result}{body} );

    # If thumb was previously generated by box, refresh thumb.
    $prese->image('') if Dicole::Utils::Data->get_note( new_box_generated_thumb => $prese );

    Dicole::Utils::Data->set_note( new_box_upload_started => undef, $prese, { skip_save => 1 } );
    Dicole::Utils::Data->set_note( new_box_view_document_id => $data->{entries}[0]{id}, $prese, { skip_save => 1 } );
    Dicole::Utils::Data->set_note( new_box_view_document_attachment => $a->id, $prese, { skip_save => 1 } );

    $prese->save;

    Dicole::Utils::Gearman->do_delayed_task( retrieve_new_box_image_for_prese => {
        prese_id => $prese->id,
    }, 0 ) if ! $prese->image;

    return { success => 1 };
}

sub object_info {
    my ( $self ) = @_;

    return $self->_object_info( $self->param('prese'), $self->param('domain_id') );
}

sub recent_object_data_with_tags {
    my ( $self ) = @_;

    my $gid = $self->param('group_id') || CTX->controller->initial_action->param('target_group_id');
    my $objects = $self->_generic_preses(
        domain_id => $self->param('domain_id'),
        group_id => $gid,
        tags => scalar( $self->param('tags') ),
        where => scalar( $self->param('where') ),
        value => scalar( $self->param('value') ),
        limit => scalar( $self->param('limit') ),
        order => 'creation_date desc',
    );

    return $self->_gather_data_for_objects( $objects, $self->param('domain_id') );
}

sub recent_object_rss_params_with_tags {
    my ( $self ) = @_;

    my $datas = $self->recent_object_data_with_tags;

    return [ map { $self->_object_data_to_rss_params( $_ ) } @$datas ];
}

sub data_for_objects {
    my ( $self ) = @_;

    my $objects = $self->param( 'objects' ) || $self->_fetch_objects_for_ids( scalar( $self->param('ids') ) );
    return $self->_gather_data_for_objects( $objects, $self->param('domain_id') );
}

sub _fetch_objects_for_ids {
    my ( $seld, $ids ) = @_;

    return CTX->lookup_object('presentations_prese')->fetch_group( {
       where => Dicole::Utils::SQL->column_in( prese_id => $ids ),
    } ) || [];
}

sub init_store_creation_event {
    my ( $self ) = @_;

    return $self->_store_creation_event(
        $self->param('object'),
        undef,
        $self->param('domain_id'),
    );
}

sub scribd_thumbnail_fixer {
    my ( $self ) = @_;

    my $scribd_api_key = CTX->server_config->{dicole}->{scribd_api_key};
    die unless $scribd_api_key;

    my $presentations = CTX->lookup_object('presentations_prese')->fetch_group({
    	where =>
    		'scribd_id is not null AND '.
    		'scribd_key is not null AND '.
    		'scribd_thumbnail_disabled != 1 AND '.
    		'(scribd_thumbnail_timestamp <= ? OR scribd_thumbnail_timestamp is null)',
    	value => [ time ]
    });

    my $xml_parser = new XML::Simple;

    for my $presentation ( @$presentations ) {
    	my $scribd_settings_xml = Dicole::Utils::HTTP->post(
			'http://api.scribd.com/api',
			{
				method => 'docs.getSettings',
				doc_id => $presentation->scribd_id,
				api_key => $scribd_api_key
			}
		);

		my $scribd_settings = $xml_parser->XMLin($scribd_settings_xml);
		my $thumbnail_url = $scribd_settings->{thumbnail_url};
		$thumbnail_url =~ s/^\s+|\s+$//g;

		next if !$thumbnail_url;

		my $signature = CTX->lookup_action('thumbnails_api')->execute(
			refresh => {
				url => $thumbnail_url,
				width => $self->THUMBNAIL_WIDTH,
				height => $self->THUMBNAIL_HEIGHT
			}
		);

		if ( !$presentation->scribd_thumbnail_hash || $presentation->scribd_thumbnail_hash ne $signature ) {
			print "Hash not found or not equal!\n";
			$presentation->scribd_thumbnail_hash($signature);
			$presentation->scribd_thumbnail_timestamp_start(time);
			$presentation->scribd_thumbnail_timestamp(time + 5);
		}
		else {
			print "Hash equal, extending time!\n";
			my $difference = $presentation->scribd_thumbnail_timestamp - $presentation->scribd_thumbnail_timestamp_start;
			$presentation->scribd_thumbnail_timestamp($presentation->scribd_thumbnail_timestamp + $difference * 2);
		}

		$presentation->save;
    }
}

sub user_bookmarked_presentations_data {
    my ( $self ) = @_;

    my $ordered_preses = CTX->lookup_action('bookmarks_api')->e( bookmark_limited_fetch_group => {
        object_class => CTX->lookup_object('presentations_prese'),
        domain_id => $self->param('domain_id'),
        group_id => $self->param('group_id'),
        creator_id => $self->param('creator_id'),
        order => 'dicole_bookmark.created_date desc',
    } );

    return [ map { {
        title => $_->name,
        url => $self->_show_url( $_ ),
    } } @$ordered_preses ];
}

sub refresh_object_scribd_image {
    my ( $self ) = @_;

    my $scribd_api_key = CTX->server_config->{dicole}->{scribd_api_key};

    my $object = $self->param('object') || $self->_ensure_prese_object( $self->param('object_id') );
    return unless $object->scribd_id;

    return unless ! $object->image || $object->image =~ /scribd/ || $self->param('force_update');

    my $scribd_xml = Dicole::Utils::HTTP->post(
        'http://api.scribd.com/api',
        {
            method => 'thumbnail.get',
            width => 408,
            height => 228,
            doc_id => $object->scribd_id,
            api_key => $scribd_api_key
        }
    );

    my $xml_parser = new XML::Simple;
    my $scribd_data = $xml_parser->XMLin($scribd_xml);
    my $thumbnail_url = $scribd_data->{thumbnail_url};
    $thumbnail_url =~ s/^\s+|\s+$//g;

    return if !$thumbnail_url;
    $object->image( Dicole::Utils::Text->ensure_utf8( $thumbnail_url ) );
    $object->save;
}

1;
