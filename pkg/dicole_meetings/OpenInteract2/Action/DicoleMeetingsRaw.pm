package OpenInteract2::Action::DicoleMeetingsRaw;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use URI::URL;
use Dicole::Utils::HTML;
use Text::CSV;

sub longify_url {
    my ( $self ) = @_;

    my $code = $self->param('code');
    my $obj = $self->_get_url_object_from_shortened_url( $code );

    return $self->redirect( 'https://www.meetin.gs/404.html' ) unless $obj;

    if ( my $type = $self->_get_note( type => $obj ) ) {
        if ( $type eq 'notification_action' ) {
            Dicole::Utils::Gearman->dispatch_task( record_notification_action_click => { notification_id => $self->_get_note( notification_id => $obj ), notification_method => $self->_get_note( notification_method => $obj ), user_agent => CTX->request->user_agent } );
            $self->_queue_user_segment_event( $obj->creator_id, 'Notification link clicked', { notification_id => $self->_get_note( notification_id => $obj ), notification_method => $self->_get_note( notification_method => $obj ), user_agent => CTX->request->user_agent } );
        }
        if ( $type eq 'app_download_sms' ) {
            $self->_queue_user_segment_event( $obj->creator_id, 'App download SMS clicked', { user_agent => CTX->request->user_agent } );
        }
    }

    return $self->redirect( $obj->url );
}

sub logged_in_user_email {
    my ( $self ) = @_;

    return '' unless CTX->request->auth_user_id;
    return CTX->request->auth_user->email;
}

sub ics {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $meeting = $self->_get_valid_event;
    my $user_id = $self->param('user_id') || '';
    my $checksum = $self->param('checksum') || '';

    $user_id = CTX->request->auth_user_id unless $user_id =~ /^\d+$/ && $checksum;
    my $user = $user_id ? eval { Dicole::Utils::User->ensure_object( $user_id ) } : undef;

    return "security error" unless $user;

    my $users = $self->_fetch_meeting_participant_users( $meeting );

    die "security error" unless grep { $_->id == $user->id } @$users;

    die "security error" unless
        ( $checksum && $checksum eq $self->_generate_meeting_ics_digest_for_user( $meeting->id, $user ) )
        ||
        ( CTX->request->auth_user_id == $user->id );

    my $ics = $self->_ics_request_for_meeting( $meeting, $user, $users, $domain_id );

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/calendar' );
    CTX->response->header( 'Content-Disposition', 'attachment; filename="event.ics"' );

    return Dicole::Utils::Text->ensure_utf8( $ics );
}

sub ics_list {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = 0;
    my $k = $self->param( 'identification_key' );

    if ( ! $uid && $k ) {
        my ( $id, $sec, $domain_id, $time ) = Dicole::Utils::User->resolve_identification_key( $k );
        $uid = $id;
    }

    die "authentication error" unless $uid;

    my $user_events = $self->_get_user_meetings_in_domain( $uid, $domain_id );

    my $valid_events = [ map { $_->begin_date ? $_ : () } @$user_events ];

    my $ics_list = $self->_ics_list_for_meetings( $valid_events, $uid, $domain_id );

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/calendar' );

    return Dicole::Utils::Text->ensure_utf8( $ics_list );

}

sub matchmaker_lock_ics {
    my ( $self ) = @_;

    my $lock_id = $self->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    die "umm.. no lock?" unless $lock;

    my $user_id = $self->param('user_id') || '';
    my $checksum = $self->param('checksum') || '';

    $user_id = CTX->request->auth_user_id unless $user_id =~ /^\d+$/ && $checksum;
    my $user = $user_id ? eval { Dicole::Utils::User->ensure_object( $user_id ) } : undef;

    return "security error" unless $user;

    die "security error" unless
        ( $checksum && $checksum eq $self->_generate_meeting_ics_digest_for_user( $lock->id, $user ) )
        ||
        ( CTX->request->auth_user_id == $user->id );

    my $vevent = $self->_ics_vevent_for_matchmaker_lock( $lock, $user );

    my $ics = $self->_ics_request_for_vevent( $vevent );

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/calendar' );
    CTX->response->header( 'Content-Disposition', 'attachment; filename="event.ics"' );

    return Dicole::Utils::Text->ensure_utf8( $ics );
}

sub meeting_image {
    my ( $self ) = @_;

    my $meeting_id = $self->param('meeting_id');
    my $user_id = $self->param('user_id');
    my $filename = $self->param('checksum_filename');
    my ( $checksum ) = $filename =~ /(.*)\./;

    my $meeting = $self->_ensure_meeting_object( $meeting_id );
    my $user = Dicole::Utils::User->ensure_object( $user_id );

    my $participation = $self->_get_user_meeting_participation_object( $user, $meeting );

    die unless $participation;
    die unless $checksum eq $self->_generate_meeting_image_digest_for_user( $meeting_id, $user );

    $self->_set_note( last_meeting_image_served => time, $participation );

    my $epoch = time;

    my $url = $self->derive_url( task => 'authorized_meeting_image_html', additional => [
        $meeting_id, $epoch, $self->_generate_authorized_meeting_digest( $meeting_id, $epoch )
    ] );

    $url = $self->_get_host_for_meeting( $meeting, 80 ) . $url;

    my $png = File::Temp->new( suffix => '.png' );
    my $png_path = $png->filename;

    my $cuty_host = CTX->server_config->{dicole}{cutyrpc_host} || 'https://cuty.meetin.gs/';
    my $cuty_auth = CTX->server_config->{dicole}{cutyrpc_auth} || 'x';

    `curl -o '$png_path' -s '$cuty_host?auth=$cuty_auth&width=10&height=10&url=$url'`;

    CTX->response->content_type('image/png');

    my $size = ( stat( $png ) )[7];
    CTX->response->header( 'Content-Length', $size );

    return CTX->response->send_filehandle( $png );
}

sub authorized_meeting_image_html {
    my ( $self ) = @_;

    my $meeting_id = $self->param('meeting_id');
    my $epoch = $self->param('epoch');
    my $checksum = $self->param('checksum');

    # authorization has 60 seconds to live
    die unless $epoch > time - 60;

    my $correct_checksum = $self->_generate_authorized_meeting_digest( $meeting_id, $epoch );
    die unless $checksum eq $correct_checksum;

    my $meeting = $self->_ensure_meeting_object( $meeting_id );

    my $participant_info_list = $self->_gather_meeting_users_info( $meeting, -1 );
    my $filtered_participant_info_list = [];

    for my $info ( @$participant_info_list ) {
        next if $info->{is_hidden};
        my $attachment_id = $info->{image_attachment_id};
        $info->{image} = $self->derive_url( task => 'internal_attachment_image', additional => [
            $attachment_id, 36, $self->_generate_attachment_image_digest( $attachment_id, 36 ) . '.png'
        ] ) if $attachment_id;
        push @$filtered_participant_info_list, $info;
    }

    my $params = $self->_gather_material_data_params( $meeting );
    $params->{participants} = $filtered_participant_info_list;

    $params->{css_url} = $self->_generate_theme_css_url_for_meeting( $meeting );
    $params->{static_file_version} = CTX->server_config->{dicole}{static_file_version};

    return $self->generate_content( $params, { name => 'dicole_meetings::main_meetings_mail_summary' } );
}

sub internal_attachment_image {
    my ( $self ) = @_;

    my $attachment_id = $self->param('attachment_id');
    my $size = $self->param('size');
    my $filename = $self->param('checksum_filename');
    my ( $checksum ) = $filename =~ /(.*)\./;

    die unless $checksum eq $self->_generate_attachment_image_digest( $attachment_id, $size );

    return CTX->lookup_action('attachment_api')->e( serve => {
        attachment_id => $attachment_id,
        thumbnail => 1,
        force_width => $size || 30,
        force_height => $size || 30,
    } );
}

sub matchmaker_image {
    my ( $self ) = @_;

    my $matchmaker_id = $self->param('matchmaker_id');
    my $matchmaker = $self->_ensure_object_of_type( meetings_matchmaker => $matchmaker_id );
    my $attachment_id = $matchmaker->logo_attachment_id;

    return CTX->lookup_action('attachment_api')->e( serve => {
        attachment_id => $attachment_id,
        thumbnail => 1,
        max_width => 170,
        max_height => 130,
#        force_height => ,
    } );
}

sub _generate_authorized_meeting_digest {
    my ( $self, $meeting_id, $epoch ) = @_;

    my $string = join "", CTX->server_config->{dicole}{meetings_general_secret}, $meeting_id, $epoch;
    return $self->_digest_string( $string );
}

sub _generate_attachment_image_digest {
    my ( $self, $attachment_id, $size ) = @_;

    my $string = join "", CTX->server_config->{dicole}{meetings_general_secret}, $attachment_id, $size;
    return $self->_digest_string( $string );
}

sub authorized_meeting_header_image {
    my ( $self ) = @_;

    my $meeting_id = $self->param('meeting_id');
    my $user_id = $self->param('user_id');
    my $filename = $self->param('checksum_filename');
    my ( $checksum ) = $filename =~ /(.*)\./;

    my $user = Dicole::Utils::User->ensure_object( $user_id );

    die unless $checksum eq $self->_generate_meeting_image_digest_for_user( $meeting_id, $user );

    my $meeting = $self->_ensure_meeting_object( $meeting_id );
    my $creator = Dicole::Utils::User->ensure_object( $meeting->creator_id );

    return $self->_serve_user_header_image( $creator );
}

sub authorized_user_header_image {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id');
    my $filename = $self->param('checksum_filename');
    my ( $checksum ) = $filename =~ /(.*)\./;

    my $user = Dicole::Utils::User->ensure_object( $user_id );

    die unless $checksum eq $self->_generate_header_image_digest_for_user( $user );

    return $self->_serve_user_header_image( $user );
}

sub google_contact_image {
    my ( $self ) = @_;

    my $url = CTX->request->param('url');
    my $response = $self->_go_call_api( CTX->request->auth_user, Dicole::Utils::Domain->guess_current_id, $url, 'GET', {} );
    my $png = $response->content;

    CTX->response->content_type('image/png');

    my $size = length( $png );
    CTX->response->header( 'Content-Length', $size );

    return $png;
}

sub _serve_user_header_image {
    my ( $self, $user ) = @_;

    my $aid = $self->_get_note_for_user( 'pro_theme_header_image', $user );

    return CTX->lookup_action('attachments_api')->e( serve => {
        attachment_id => $aid,
        thumbnail => 1,
        max_width => 180,
        max_height => 40,
    } );
}

sub post_forward {
    my ( $self ) = @_;

    my $to = CTX->request->param('to');
    my $url = URI::URL->new( $to );

    my %parameters = $url->query_form;
    $url->query_form( {} );

    my $action = $url->as_string;

    my @inputs = ();
    for my $key ( keys %parameters ) {
        push @inputs, '<input type="hidden" name="'.Dicole::Utils::HTML->encode_entities($key).'" value="'. Dicole::Utils::HTML->encode_entities($parameters{$key}) .'"/>';
    }

    my $script = '<script>document.getElementById("f").submit();</script>';

    return '<html><body><form method="post" id="f" action="'.Dicole::Utils::HTML->encode_entities($action).'">'.join("", @inputs).'<input type="submit" value="Continue" /></form>'.$script.'</body></html>';
}

sub cookie_forward {
    my ( $self ) = @_;

    my $to = CTX->request->param('to');
    my $url = URI::URL->new( $to );

    my %parameters = $url->query_form;
    $url->query_form( {} );

    my %utm_params = ();
    for my $utm_param ( qw( utm_source utm_medium utm_campaign ) ) {
        next unless defined $parameters{ $utm_param };
        $utm_params{ $utm_param } = $parameters{ $utm_param };
        delete $parameters{ $utm_param };
    }

    $url->query_form( \%utm_params );

    my $action = $url->as_string;

    for my $key ( keys %parameters ) {
        OpenInteract2::Cookie->create( {
            name => 'cookie_parameter_' . $key,
            path => '/',
            value => $parameters{$key},
            expires => '+1h',
            HEADER => 'YES',
        } );
    }

    return $self->redirect( $action );
}

sub offer_mobile {
    my ( $self ) = @_;

    my $meeting_id = CTX->request->param('meeting_id');

    my $mobile_domain = CTX->server_config->{dicole}->{meetings_mobile_domain} || 'm.meetin.gs';
    my $mobile_uri = URI::URL->new( "https://$mobile_domain/" );

    my %params = ();
    for my $attr ( qw(
        dic
        proposals
        matchmaking_response
        user_fragment
        matchmaker_fragment
        confirmed_matchmaker_lock_id
        limit_reached_for_matchmaking_event_id
        expired_matchmaker_lock_id
        under_construction_url
        under_construction_message
        quickmeet_key
        open_calendar
        ensure_user_id
        ) ) {
        if ( my $val = CTX->request->param( $attr ) ) {
            $params{ $attr } = $val;
        }
    }

    $mobile_uri->query_form( { redirect_to_meeting => $meeting_id || 0, user_id => CTX->request->auth_user_id, %params } );

    my $desktop_uri = $meeting_id ? $self->_get_meeting_url( $meeting_id ) : $self->derive_url( action => 'meetings_global', task => 'detect' );

    return $self->redirect( $mobile_uri->as_string );
}

sub offer_desktop {
    my ( $self ) = @_;

    my $meeting_id = CTX->request->param('meeting_id');
    my $desktop_uri = $meeting_id ? $self->_get_meeting_url( $meeting_id ) : $self->derive_url( action => 'meetings_global', task => 'detect' );

    my $mobile_domain = CTX->server_config->{dicole}->{meetings_mobile_domain} || 'm.meetin.gs';
    my $mobile_uri = URI::URL->new( "https://$mobile_domain/" );
    $mobile_uri->query_form( { dic => CTX->request->param('dic'), redirect_to_meeting => $meeting_id || 0, user => CTX->request->auth_user_id, disable_desktop => '1' } );

    return $self->redirect( $desktop_uri );
}

sub prese_image {
    my ( $self ) = @_;

    my $meeting = $self->_ensure_meeting_object( $self->param('meeting_id') );
    my $prese = $self->_get_object_for_prese_id( $self->param('prese_id') );
    my $token = $self->param( 'token' );

    die "security error" unless $self->_check_if_meeting_has_material( $meeting, $prese );
    die "security error" unless $self->_check_if_material_digest_is_valid( $meeting, $prese, $token );

    # TODO: check rights in general..

    if ( $prese->image && $prese->image =~ /^\d+$/ ) {
        my $a = eval { CTX->lookup_object('attachment')->fetch( $prese->image ) };

        CTX->lookup_action('attachment')->execute( serve => {
            thumbnail => 1,
            attachment => $a,
            max_width => 640,
            max_height => 640,
        } );
    }
    else {
        my $a = eval { CTX->lookup_object('attachment')->fetch( $prese->attachment_id ) };

        CTX->lookup_action('attachment')->execute( serve => {
            thumbnail => 1,
            attachment => $a,
            max_width => 640,
            max_height => 640,
        } );
    }
}

sub meeting_background_image {
    my ( $self ) = @_;

    my $mmr = $self->_ensure_matchmaker_object( $self->param('meeting_id') );
    my $token = $self->param( 'token' );

    my $attachment_id = $self->_get_note( background_attachment_id => $mmr );

    die "security error" unless $attachment_id == $self->param('attachment_id');
    # TODO: check token

    my $a = eval { CTX->lookup_object('attachment')->fetch( $attachment_id ) };

    CTX->response->header( 'Expires', 'Thu, 15 Apr 2020 20:00:00 GMT' );

    CTX->lookup_action('attachment')->execute( serve => {
       attachment => $a,
#       thumbnail => 1,
#       max_width => 640,
#       max_height => 640,
    } );
}

sub matchmaker_background_image {
    my ( $self ) = @_;

    my $mmr = $self->_ensure_matchmaker_object( $self->param('matchmaker_id') );
    my $token = $self->param( 'token' );

    my $attachment_id = $self->_get_note( background_attachment_id => $mmr );

    die "security error" unless $attachment_id == $self->param('attachment_id');
    # TODO: check token

    my $a = eval { CTX->lookup_object('attachment')->fetch( $attachment_id ) };

    CTX->response->header( 'Expires', 'Thu, 15 Apr 2020 20:00:00 GMT' );

    CTX->lookup_action('attachment')->execute( serve => {
       attachment => $a,
#       thumbnail => 1,
#       max_width => 640,
#       max_height => 640,
    } );
}

sub user_meetme_background_image {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = Dicole::Utils::User->ensure_object( $self->param('user_id') );
    my $token = $self->param( 'token' );

    my $attachment_id = $self->_get_note_for_user( meetme_background_attachment_id => $user, $domain_id );

    die "security error" unless $attachment_id == $self->param('attachment_id');
    # TODO: check token

    my $a = eval { CTX->lookup_object('attachment')->fetch( $attachment_id ) };

    CTX->response->header( 'Expires', 'Thu, 15 Apr 2020 20:00:00 GMT' );

    CTX->lookup_action('attachment')->execute( serve => {
       attachment => $a,
#       thumbnail => 1,
#       max_width => 640,
#       max_height => 640,
    } );
}

sub prese_download {
    my ( $self ) = @_;

    my $meeting = $self->_ensure_meeting_object( $self->param('meeting_id') );
    my $prese = $self->_get_object_for_prese_id( $self->param('prese_id') );
    my $token = $self->param( 'token' );

    die "security error" unless $self->_check_if_meeting_has_material( $meeting, $prese );
    die "security error" unless $self->_check_if_material_digest_is_valid( $meeting, $prese, $token );

    # TODO: check rights in general..
    my $a = eval { CTX->lookup_object('attachment')->fetch( $prese->attachment_id ) };

    CTX->lookup_action('attachment')->execute( serve => {
        download => 1,
        attachment => $a,
    } );
}

sub prese_open {
    my ( $self ) = @_;

    my $meeting = $self->_ensure_meeting_object( $self->param('meeting_id') );
    my $prese = $self->_get_object_for_prese_id( $self->param('prese_id') );
    my $token = $self->param( 'token' );

    die "security error" unless $self->_check_if_meeting_has_material( $meeting, $prese );
    die "security error" unless $self->_check_if_material_digest_is_valid( $meeting, $prese, $token );

    # TODO: check rights in general..
    my $a = eval { CTX->lookup_object('attachment')->fetch( $prese->attachment_id ) };

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
    } );
}

sub _check_if_material_digest_is_valid {
    my ( $self, $meeting, $material, $token ) = @_;

    $token ||= '';

    my ( $user_id ) = split "_", $token;
    return 0 unless $user_id;

    my $user = Dicole::Utils::User->ensure_object( $user_id );
    return 0 unless $user;

    my $valid_token = $self->_generate_meeting_material_digest_for_user( $meeting, $material, $user );
    return 0 unless $token eq $valid_token;

    return 1;
}

sub js_redirect {
    my ( $self ) = @_;

    my $uri = CTX->request->param('uri');
    my $r = "'+\"'\"+'";
    $uri =~ s/\'/$r/g;
    my $a = <<END
<script>
window.location = '$uri';
</script>
END
;
    return $a;
}

sub generic_company_html {
    my ( $self ) = @_;

    my $data = $self->_company_html_data;
    return $data unless ref( $data );

    return $self->generate_content( $data, { name => 'dicole_meetings::external_meetings_meetme_company_data_generic'} )
}

sub slush_company_html {
    my ( $self ) = @_;

    my $data = $self->_company_html_data;
    return $data unless ref( $data );

    return $self->generate_content( $data, { name => 'dicole_meetings::external_meetings_meetme_company_data_slush'} )
}

sub pioneers_company_html {
    my ( $self ) = @_;

    my $data = $self->_company_html_data;
    return $data unless ref( $data );

    return $self->generate_content( $data, { name => 'dicole_meetings::external_meetings_meetme_company_data_pioneers'} );
}

sub _company_html_data {
    my ( $self ) = @_;

    my $email = CTX->request->param('email');

    if ( ! $email ) {
        my $user = eval { Dicole::Utils::User->ensure_object( CTX->request->param('id') ) };
        return '' unless $user;
        $email = $user->email;
    }

    my $data = $self->_gather_event_data_for_email( CTX->request->param('event_id'), $email );
    return '' unless $data;

    return $data;
}

sub _gather_event_data_for_email {
    my ( $self, $event_id, $email ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $event = $self->_ensure_matchmaking_event_object( $event_id );
    return undef unless $event;

    my $event_data = $self->_get_matchmaking_event_google_docs_company_data( $event );
    return undef unless $event_data;

    my $user = $self->_fetch_user_for_email( $email );
    return undef unless $user;

    my $emails = $self->_fetch_user_verified_email_list( $user, $domain_id );

    my $data = undef;
    for my $user_email ( @$emails ) {
        $data = $event_data->{ lc( $user_email ) };
        last if $data;
    }

    return undef unless $data;

    unless ( $self->_get_note( do_not_force_https => $event ) ) {
        $data->{logo} =~ s/^http\:/https\:/ if $data->{logo};
    }
    $data->{dump} = Data::Dumper::Dumper( $data );

    return $data;
}

sub saml2entity {
    my ( $self ) = @_;
    my $provider = $self->param( 'provider' ) || 'lahixcustxz';
    $provider =~ s/\.xml$//;
    return Dicole::Utils::Gearman->do_task( saml2_get_metadata => {
        domain => CTX->request->server_name,
        provider => $provider,
    } )->{result};
}

sub lt_export_user_data {
    my ( $self ) = @_;

    my @l = ();

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $from = CTX->request->param('from');
    my $to = CTX->request->param('to');
    my $area = CTX->request->param('area');
    my $filename = $self->param('filename');

    my $user = CTX->request->auth_user;
    my $areas = $self->_get_note_for_user( 'meetings_agent_admin_areas' => $user, $domain_id );
    die "security error" unless $areas;
    die "security error" unless $areas eq '_all' || $areas eq $area;

    my $outputs = $self->_gather_agent_user_export_data( $from, $to, $area, $domain_id, $partner );

    my $csv = Text::CSV->new();

    my $column_names = [ 'Email', 'Nimi' ];

    unshift @$outputs, { map { $_ => $_ } @$column_names };

    my @rows = ();

    for my $output ( @$outputs ) {
        my @values = map { Dicole::Utils::Text->ensure_internal( $output->{ $_ } ) } @$column_names;
        my $status = $csv->combine( @values );
        return $csv->error_input() unless $status;
        push @rows, Dicole::Utils::Text->ensure_utf8($csv->string())
    }

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/csv' );
    CTX->response->header( 'Content-Disposition', 'attachment; filename="'.$filename.'"' );

    return join "\n", @rows, @l, '';}

sub lt_export_meeting_data {
    my ( $self ) = @_;

    my @l = ();

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $from = CTX->request->param('from');
    my $to = CTX->request->param('to');
    my $area = CTX->request->param('area');
    my $filename = $self->param('filename');

    my $user = CTX->request->auth_user;
    my $areas = $self->_get_note_for_user( 'meetings_agent_admin_areas' => $user, $domain_id );
    die "security error" unless $areas;
    die "security error" unless $areas eq '_all' || $areas eq $area;

    my $outputs = $self->_gather_agent_meeting_export_data( $from, $to, $area, $domain_id, $partner );

    my $csv = Text::CSV->new();

    my $column_names = [ 'Varaaja', 'Varauksen nimi', 'Varauksen vastaanottaja', 'Varaus tehty', 'Varauksen aika', 'Varaus peruttu', 'SMS kutsu pituus', 'SMS muistutus pituus', 'Tyyppi', 'Kieli', 'Taso', 'Toimisto', 'Rooli' ];

    unshift @$outputs, { map { $_ => $_ } @$column_names };

    my @rows = ();

    for my $output ( @$outputs ) {
        my @values = map { Dicole::Utils::Text->ensure_internal( $output->{ $_ } ) } @$column_names;
        my $status = $csv->combine( @values );
        return $csv->error_input() unless $status;
        push @rows, Dicole::Utils::Text->ensure_utf8($csv->string())
    }

    CTX->response->charset( 'utf-8' );
    CTX->response->content_type( 'text/csv' );
    CTX->response->header( 'Content-Disposition', 'attachment; filename="'.$filename.'"' );

    return join "\n", @rows, @l, '';
}

1;
