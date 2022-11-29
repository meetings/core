package OpenInteract2::Action::DicoleMeetingsJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use URI;
use XML::Simple;
use URI::QueryParam;
use Dicole::Utils::HTTP;
use JSON ();
use Date::Parse;
use DateTime::SpanSet;
use DateTime::Span;
use DateTime::Set;
use DateTime;
use DateTime::Event::ICal;

sub login {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id ) {
        my $http_host = $self->_get_host_for_user(CTX->request->auth_user, undef, 443);

        my $url = CTX->request->param('url_after_login')
            ? CTX->request->param('url_after_login')
            : $http_host . $self->derive_url( action => 'meetings_global', task => 'detect', target => 0 );

        return {
            result => {
                url_after_post => $url,
            },
            success => JSON::true,
        }
    }
    return {
        error => { message => 'Please check your username & password.' }
    };
}


sub claim_meet_me {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( CTX->request->auth_user_id ) {
        die "security error" if CTX->request->auth_user->email;
    }

    my $frag = $self->param('meet_me_url');
    my $email = CTX->request->param('email');
    my $event_id = CTX->request->param('event_id');
    my $tz = CTX->request->param('timezone');

    my $existing = $frag ? $self->_resolve_matchmaker_url_user( $frag ) : '';
    if ( $existing ) {
        # just ignore this for now.. the user will just get forwarded to the page with a default url
    }

    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : $self->_create_temporary_user;

    $user->timezone( $tz ) if $tz;
    $self->_set_note_for_user( created_for_matchmaking_event_id => $event_id, $user, $domain_id, { skip_save => 1 } ) if $event_id;
    $self->_set_note_for_user( created_by_partner => $self->param('partner_id'), $user, $domain_id, { skip_save => 1 } ) if $self->param('partner_id');
    $self->_user_accept_tos( $user, $domain_id, 'skip_save' );
    $user->save;

    if ( $frag ) {
        my $success = $self->_set_user_matchmaker_url( $user, $domain_id, $frag );
        if ( ! $success ) {
            # just ignore this for now.. the user will just get forwarded to the page with a default url
        }
    }

    return { result => {
        url_after_post => $self->derive_url( action => 'meetings', task => 'wizard_profile', additional => [ $event_id || () ], params => {
             ( CTX->request->auth_user_id ? () : ( dic => Dicole::Utils::User->temporary_authorization_key( $user ) ) ),
             ( $email ? ( email => $email ) : () ),
        } ),
    } };
}

# Legacy and deprecated, Can be removed after chrome extension has been updated for a good while after 1.5.2014
sub meet_me_urls {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $fragment = $self->_fetch_user_matchmaker_fragment( $user );

    if ( $fragment ) {
        my $domain_host = $self->_get_host_for_self( 443 );
        return { result => [ $domain_host . $self->derive_url( action => 'meetings', task => 'meet', additional => [ $fragment ] ) ] };
    }
    else {
        return { result => [] };
    }
}

sub meet_me_pages {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user;

    my $fragment = $self->_fetch_user_matchmaker_fragment( $user );

    if ( $fragment ) {
        my $domain_host = $self->_get_host_for_self( 443 );
        my $mmrs = $self->_fetch_user_matchmakers_in_order( $user, $domain_id );
        my $data = [ {
            name => 'Cover page',
            url => $self->_generate_matchmaker_meet_me_url( $user, $domain_id, $domain_host, $fragment ),
        } ];
        for my $mmr ( @$mmrs ) {
            if ( $self->_get_note( direct_link_enabled => $mmr ) || $self->_get_note( direct_link_disabled => $mmr ) ) {
                next unless $self->_get_note( direct_link_enabled => $mmr );
            }
            else { # Legacy
                next if $mmr->matchmaking_event_id;
            }

            push @$data, {
                name => $mmr->name,
                url => $self->_generate_matchmaker_meet_me_url( $mmr, $user, $domain_host, $fragment ),
            };
        }
        return { result => $data };
    }
    else {
        return { result => [] };
    }
}

sub create {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;
    my $user = $uid ? CTX->request->auth_user : undef;
    my $secure = 0;

    my $k = $self->param( 'identification_key' );

    if ( ! $uid && $k ) {
        my ( $id, $sec, $domain_id, $time ) = Dicole::Utils::User->resolve_identification_key( $k );
        $uid = $id;
        $secure = $sec;
    }

    if ( ! $uid ) {
        if ( my $email = CTX->request->param('email') ) {
            my $target_user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );
            if ( $target_user && $self->_user_has_accepted_tos( $target_user, $domain_id ) ) {
                return { result => {
                    url_after_post => $self->derive_url( action => 'meetings', task => 'already_a_user', additional => [], params => { email => $email } ),
                } };
            }

            if ( ! CTX->request->param( 'tos' ) ) {
                return { error => { message => $self->_nmsg( 'You need to accept the Terms of Service!' ) } };
            }

            $target_user = eval { $self->_fetch_or_create_user_for_email( $email ) };

            return { error => { message => 'An error occured while creating user. Sorry.' } } unless $target_user;

            $self->_user_accept_tos( $target_user, $domain_id );

            for my $id ( qw( offers info ) ) {
                if ( CTX->request->param( $id ) ) {
                    $self->_set_note_for_user( 'emails_requested_for_' . $id, time, $target_user, $domain_id );
                }
            }

            $uid = $target_user->id;
        }
        else {
            $user = $self->_create_temporary_user;
            $user->timezone( CTX->request->param('timezone') ) if CTX->request->param('timezone');
            $user->save;

            $uid = $user->id;
        }
    }

    # If user is logged or a temp user, user must have gone through timezone selection at some point
    if ( $user ) {
        $self->_user_accept_tos( $user, $domain_id );
        $self->_user_filled_profile( $user, $domain_id )
    }

    my $title = CTX->request->param('title');

    my $epoch = 0;
    my $duration = 0;

    if ( CTX->request->param('schedule') && CTX->request->param('schedule') eq 'set' ) {
        if ( CTX->request->param('begin_epoch') ) {
            $epoch = CTX->request->param('begin_epoch');
        }
        else {
            my $bd = CTX->request->param('begin_date');
            my $bt = $self->_time_string_from_begin_params;
            $epoch = ( $bd && $bt ) ? eval { Dicole::Utils::Date->date_and_time_strings_to_epoch( $bd, $bt ) } : 0;
        }

        if ( $@ ) {
            return { error => { message => $self->_nmsg("We are sorry but the system did not understand the provided date. Please check the date and try again!") } };
        }

        $duration = CTX->request->param('duration') || ( CTX->request->param('duration_hours') * 60 + CTX->request->param('duration_minutes') ) || 0;
    }

    my $initial_agenda = CTX->request->param('agenda') ? Dicole::Utils::HTML->text_to_html( CTX->request->param('agenda') ) : '';

    my $base_group_id = $self->_determine_user_base_group( $uid );

    die "security error" unless $base_group_id;

    my $partner = $self->param('partner');
    my $partner_id = ( $partner && $self->_user_can_create_meeting_for_partner( $user, $partner ) ) ? $partner->id : 0;

    my $event = CTX->lookup_action('meetings_api')->e( create => {
        creator_id => $uid,
        partner_id => $partner_id,
        group_id => $base_group_id,
        title => CTX->request->param('title'),
        location => CTX->request->param('location'),
        begin_epoch => $epoch,
        duration => $duration,
        initial_agenda => $initial_agenda,
        disable_create_email => 1,
    });

    if ( CTX->request->param('schedule') && CTX->request->param('schedule') eq 'suggest' ) {
        $self->_set_note_for_meeting( open_suggestion_picker => 1, $event );
    }

    if ( my $participants = CTX->request->param('participants') ) {
        my $participants_data = Dicole::Utils::JSON->decode( $participants );
        my $list = $user ? $self->_fetch_user_verified_email_list( $user, $domain_id ) : [];
        my %user_emails = map { $_ => 1 } @$list;

        for my $p ( @$participants_data ) {
            next unless $p->{email};
            next if $user_emails{ $p->{email} };

            # TODO: handle responseStatus

            $self->_add_meeting_draft_participant( $event, { name => $p->{displayName}, email => $p->{email} }, $user );
        }
    }

    if ( CTX->request->auth_user_id  ) {
        return { result => {
            url_after_post => $self->derive_url( action => 'meetings', task => 'meeting', target => $base_group_id, additional => [ $event->id ] )
        } };
    }
    elsif ( $user ) {
        return { result => {
            url_after_post => $self->derive_url( action => 'meetings', task => 'meeting', target => $base_group_id, additional => [ $event->id ], params => { dic => Dicole::Utils::User->temporary_authorization_key( $user ) } )
        } };
    }
    elsif ( $secure ) {
        return { result => {
            url_after_post => $self->derive_url( action => 'meetings', task => 'meeting', target => $base_group_id, additional => [ $event->id ], params => {
                dic => Dicole::Utils::User->permanent_authorization_key( $uid ),
                message_success => $self->_nmsg('%1$s created successfully', [ $self->_meeting_title_string( $event ) ] ),
            } )
        } };
    }
    else {
        my $owner_user = Dicole::Utils::User->ensure_object( $uid );
        return { result => {
            url_after_post => $self->derive_url( action => 'meetings', task => 'thank_you', params => { create => 1, email => $owner_user->email } )
        } };
    }
}

sub update {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $event = $self->_get_valid_event;

    die "security error" unless $self->_user_can_manage_meeting( $user, $event );

    my $old_info = $self->_gather_meeting_event_info( $event );

    my $title = CTX->request->param('title');
    $event->title( $title ) if $title;

    my $location = CTX->request->param('location');
    $event->location_name( $location ) if $location;

    if ( my $option = CTX->request->param('online_conferencing_option') ) {
        $self->_set_note_for_meeting( online_conferencing_option => $option, $event );
    }

    if ( my $account = CTX->request->param('skype_account') ) {
        $self->_set_note_for_meeting( skype_account => $account, $event );
    }

    my $epoch = 0;
    my $duration = 0;

    if ( CTX->request->param('schedule') && CTX->request->param('schedule') eq 'set' ) {
        if ( CTX->request->param('begin_epoch') ) {
            $epoch = CTX->request->param('begin_epoch');
        }
        else {
            my $bd = CTX->request->param('begin_date');
            my $bt = $self->_time_string_from_begin_params;
            $epoch = ( $bd && $bt ) ? eval { Dicole::Utils::Date->date_and_time_strings_to_epoch( $bd, $bt ) } : 0;
        }

        if ( $@ ) {
            return { error => { message => $self->_nmsg("We are sorry but the system did not understand the provided date. Please check the date and try again!") } };
        }

        $duration = CTX->request->param('duration') || ( CTX->request->param('duration_hours') * 60 + CTX->request->param('duration_minutes') ) || 0;

        $self->_set_date_for_meeting( $event, $epoch, $epoch + 60 * $duration, { skip_event => 1 } );
    }

    if ( my $participants = CTX->request->param('participants') ) {
        my $participants_data = Dicole::Utils::JSON->decode( $participants );
        my $list = $user ? $self->_fetch_user_verified_email_list( $user, $domain_id ) : [];
        my %user_emails = map { $_ => 1 } @$list;

        for my $p ( @$participants_data ) {
            next unless $p->{email};
            next if $user_emails{ $p->{email} };

            # TODO: handle responseStatus

            $self->_add_meeting_draft_participant( $event, { name => $p->{displayName}, email => $p->{email} }, $user );
        }
    }

    # TODO: set the first agenda version if agenda is set
#    my $initial_agenda = CTX->request->param('agenda') ? Dicole::Utils::HTML->text_to_html( CTX->request->param('agenda') ) : '';

    $event->save;

    my $new_info = $self->_gather_meeting_event_info( $event );

    $self->_store_meeting_event( $event, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return { result => 1 };
}

sub create_matchmaker {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');

    my $mm_event_id = CTX->request->param('matchmaking_event_id');
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    # TODO: check rights to create an event for this mm_event

    if ( ! $mm_event ) {
        die "matchmaker creation not possible outside events yet";
    }

    my $user_mode = 'logged_in';
    my $user = ( CTX->request->auth_user_id && CTX->request->auth_user->email ) ? CTX->request->auth_user : undef;

    if ( ! $user ) {
        if ( my $email = CTX->request->param( 'email' ) ) {
            if ( my $old_user = $self->_fetch_user_for_email( $email, $domain_id ) ) {
                $user_mode = 'existing';
                $user = $old_user;
                $self->_add_user_profile_info_from_request_params( $user, $domain_id );
            }
            else {
                $user_mode = 'new';
                $user = $self->_fetch_or_create_user_for_email( $email, $domain_id );
                $self->_store_user_profile_info_from_request_params( $user, $domain_id );

                if ( $mm_event && $self->_get_note( default_timezone => $mm_event ) ) {
                    $user->timezone( $self->_get_note( default_timezone => $mm_event ) );
                    $user->save;
                }
            }
        }
        else {
            return { error => { code => 112, message => 'You need to specify an email address' } };
        }
    }

    my $mmr = CTX->lookup_object('meetings_matchmaker')->new( {
        domain_id => $domain_id,
        partner_id => $partner ? $partner->id : 0,
        creator_id => $user->id,
        matchmaking_event_id => $mm_event_id || 0,
        logo_attachment_id => 0,
        created_date => time,
        validated_date => 0,
        disabled_date => 0,
        allow_multiple => 0,
        vanity_url_path => '',
        name => CTX->request->param('registration_organization'),
        description => CTX->request->param('description'),
        website => CTX->request->param('website'),
    } );

    $mmr->save;

    # TODO: check values for validity
    my $track = CTX->request->param('track');
    $self->_set_note( track => $track, $mmr, { skip_save => 1 } );

    my $tracks = [ CTX->request->param('market') ];
    $self->_set_note( market_list => $tracks, $mmr );

    if ( my $logo_draft_id = CTX->request->param('logo_draft_id') ) {
        my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $logo_draft_id,
            } );

        CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $mmr,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

        $mmr->logo_attachment_id( $a->id );
        $mmr->save;
    }

    if ( my $deck_draft_id = CTX->request->param('deck_draft_id') ) {
        my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $deck_draft_id,
            } );

        CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $mmr,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

        $self->_set_note( deck_attachment_id => $a->id, $mmr );
        $mmr->save;
    }

    my $host = $partner ? $self->_get_host_for_partner( $partner, 443 ) : $self->_get_host_for_user( $user, $domain_id, 443 );
    if ( $user_mode eq 'logged_in' )  {
        my $url_after_post = $mm_event ?
            $self->derive_url( action => 'meetings', task => 'event_matchmaker_validated', target => 0, additional => [ $mmr->id ] )
            :
            $self->derive_url( action => 'meetings', task => 'meet', target => 0, additional => [ $mmr->id ], parameters => { review => 1 } );
        return { result => { success => 1, url_after_post => $url_after_post } };
    }
    else {
        my $login_url = $self->_generate_authorized_uri_for_user(
            $host . $self->derive_url( action => 'meetings', task => 'event_matchmaker_validated', additional => [ $mmr->id ] ),
            $user,
            $domain_id
        );

        $self->_send_partner_themed_mail(
            user => $user,
            partner_id => $partner ? $partner->id : 0,
            domain_id => $domain_id,

            template_key_base => 'meetings_validate_event_matchmaker',
            template_params => {
                user_name => Dicole::Utils::User->name( $user ),
                new_user => ( $user_mode eq 'new' ) ? 1 : 0,
                login_url => $login_url,
            },
        );

        my $url_after_post = $self->derive_url( action => 'meetings', task => 'validate_event_matchmaker', target => 0, additional => [], params => { email => $user->email } );

        return { result => { success => 1, url_after_post => $url_after_post } };
    }
}

sub list_event_matchmakers {
    my ( $self ) = @_;

    # TODO: actually implement these..
    my $offset = CTX->request->param('offset') || 0;
    my $limit = CTX->request->param('limit') || 300;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;
    my $user_is_developer = $self->_get_note_for_user( developer => $user, $domain_id );

    my $mm_event_id = $self->param('matchmaking_event_id');
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    die "missing event" unless $mm_event;

    my $matchmakers = CTX->lookup_object('meetings_matchmaker')->fetch_group({
        where => 'matchmaking_event_id = ?',
        value => [ $mm_event->id ],
        order => "name asc"
    });

    my $user_created_meetings = $user ? $self->_get_user_created_meetings_for_matchmaking_event( $user, $mm_event, $matchmakers ) : [];
    my $meeting_by_matchmaker = { map { $self->_get_note( created_from_matchmaker_id => $_ ) => $_ } @$user_created_meetings };

    my $found_markets = {};

    my $pending_list = [];
    my $scheduled_list = [];
    my $other_list = [];
    my $disabled_list = [];
    my $unvalidated_list = [];

    for my $matchmaker ( @$matchmakers ) {
        next if $matchmaker->disabled_date && ! $user_is_developer;
        next unless $matchmaker->validated_date || $user_is_developer;

        my $user_info = $self->_gather_user_info( $matchmaker->creator_id, 30 );
        my $logo = $matchmaker->logo_attachment_id ? $self->derive_url( action => 'meetings_raw', task => 'matchmaker_image', additional => [ $matchmaker->id ] ) : '';

        my $status = '';
        my $enter_link = '';
        my $edit_link = '';
        if ( $user ) {
            if ( my $meeting = $meeting_by_matchmaker->{ $matchmaker->id } ) {
                $status = 'pending';

                my $po = $self->_fetch_meeting_participant_object_for_user( $meeting, $user );
                if ( $po ) {
                    $status = 'scheduled';
                    $enter_link = $self->_get_meeting_abs( $meeting );
                }
            }

            if ( $user->id == $matchmaker->creator_id || $user_is_developer ) {
                $edit_link = $self->derive_url( action => 'meetings', task => 'matchmaking_admin_editor', additional => [ $matchmaker->id ] );
            }
        }

        my $website = $matchmaker->website;
        $website = 'http://' . $website if $website && ! ( $website =~ /https?\:\/\// );

        my $market_list = $self->_get_note( market_list => $matchmaker ) || [];
        $found_markets->{ $_ } = 1 for @$market_list;

        my $data = {
            'link' => $website,
            description => $matchmaker->description,
            title => $matchmaker->name,
            image => $logo,
            status => $status,
            contact => $user_info,
            choose_link => $self->derive_url( action => 'meetings', task => 'matchmaking_calendar', additional => [ $matchmaker->id ] ),
            enter_link => $enter_link,
            edit_link => $edit_link,
            selected_market_list => $self->_get_note( market_list => $matchmaker ) || [],
            selected_track => $self->_get_note( track => $matchmaker ) || '',
            disabled => $matchmaker->disabled_date ? 1 : 0,
            validated => $matchmaker->validated_date ? 1 : 0,
        };

        if ( $matchmaker->disabled_date ) {
            push @$disabled_list, $data;
        }
        elsif ( ! $matchmaker->validated_date ) {
            push @$unvalidated_list, $data;
        }
        elsif ( $status eq 'pending' ) {
            push @$pending_list, $data;
        }
        elsif ( $status eq 'scheduled' ) {
            push @$scheduled_list, $data;
        }
        else {
            push @$other_list, $data;
        }
    }

    my $meetings_reserved = scalar( @$scheduled_list ) + scalar( @$pending_list );
    my $reserve_limit = $mm_event ? $self->_get_note( reserve_limit => $mm_event ) || 0 : 0;

    my $schedulings_left = $self->_count_available_user_matchmaking_event_schedulings( $user, $mm_event, $matchmakers, $user_created_meetings );

    if ( $schedulings_left == 0 ) {
        $_->{status} = 'limited' for @$other_list;
    }

    my $no_slots_left = $self->_get_note( no_slots_left => $mm_event );

    my $market_list = $self->_matchmaking_event_market_list( $mm_event ) || [];
    my $found_list = [ grep { $found_markets->{ $_ } } @$market_list ];

    return { result => {
        matchmakers => [ @$scheduled_list, @$pending_list, @$other_list, @$disabled_list, @$unvalidated_list ],
        market_list => $found_list,
        track_list => $self->_matchmaking_event_track_list( $mm_event ),
        user_logged_in => CTX->request->auth_user_id ? 1 : 0,
        meetings_left => $schedulings_left,
        no_slots_left => $no_slots_left,
    } };
}

sub matchmaker_create_lock {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $start_epoch = CTX->request->param('start');
    my $end_epoch = CTX->request->param('end');

    my $mm_id = $self->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;

    if ( $uid && $uid == $matchmaker->creator_id ) {
        return { error => { code => 7, message => 'You cannot make a reservation with yourself. Please log out of the service before trying to make the reservation with yourself.' } };
    }

    if ( ! $self->_check_matchmaker_lock_availability( $matchmaker, $start_epoch, $end_epoch ) ) {
        return { error => { code => 8, message => 'Could not get lock' } };
    }

    my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
    $self->language( $creator_user->language ) unless CTX->request->auth_user_id;

    my $lock = undef;
    my $selected_location = undef;

    my $locations = $self->_matchmaker_locations( $matchmaker );

    if ( @$locations ) {
        ( $lock, $selected_location ) = $self->_create_matchmaker_lock_with_location( $matchmaker, $start_epoch, $end_epoch, $uid, $locations );
    }
    else {
        $lock = $self->_create_matchmaker_lock_without_location( $matchmaker, $start_epoch, $end_epoch, $uid );
    }

    return { error => { message => 'Could not get lock (somebody just managed to take it)' } } unless $lock;

    $self->_store_matchmaker_lock_event( $matchmaker, $lock, 'created' );

    my ( $date, $times, $timezone ) = $self->_form_timespan_parts_from_epochs_tz_and_lang( $start_epoch, $end_epoch, $self->_get_note( time_zone => $matchmaker ), $self->language );
    my $times_string = $times . ' ' . $date . ' ' . $timezone;

    my $time_parts = $self->_gather_tiny_time_parts( $start_epoch, $end_epoch, $self->_get_note( time_zone => $matchmaker ), $self->language );

    my $user_times_string = $times_string;
    my $user_time_parts = $time_parts;

    if ( my $utz = CTX->request->param('user_time_zone') ) {
        my ( $udate, $utimes, $utimezone ) = $self->_form_timespan_parts_from_epochs_tz_and_lang( $start_epoch, $end_epoch, $utz, $self->language );

        $user_times_string = $utimes . ' ' . $udate . ' ' . $utimezone;
        $user_time_parts = $self->_gather_tiny_time_parts( $start_epoch, $end_epoch, $utz, $self->language );

        $self->_set_note( user_time_zone => $utz, $lock );
    }

    my $location_name = $self->_generate_matchmaker_lock_location_string( $lock, $matchmaker );

    return { result => {
            success => 1,
            lock_id => $lock->id,
            times_string => $times_string,
            time_parts => $time_parts,
            user_times_string => $user_times_string,
            user_time_parts => $user_time_parts,
            location_name => $location_name,
        } };
}

sub _gather_tiny_time_parts {
    my ( $self, $start_epoch, $end_epoch, $timezone, $language ) = @_;

    $language ||= 'en';

    my $now_dt = Dicole::Utils::Date->epoch_to_datetime( time, $timezone, $language );
    my $start_dt = Dicole::Utils::Date->epoch_to_datetime( $start_epoch, $timezone, $language );
    my $end_dt = Dicole::Utils::Date->epoch_to_datetime( $end_epoch, $timezone, $language );
    my $en_start_dt = Dicole::Utils::Date->epoch_to_datetime( $start_epoch, $timezone, 'en' );

    # _ncmsg( '%1$s of January'
    # _ncmsg( '%1$s of February'
    # _ncmsg( '%1$s of March'
    # _ncmsg( '%1$s of April'
    # _ncmsg( '%1$s of May'
    # _ncmsg( '%1$s of June'
    # _ncmsg( '%1$s of July'
    # _ncmsg( '%1$s of August'
    # _ncmsg( '%1$s of September'
    # _ncmsg( '%1$s of October'
    # _ncmsg( '%1$s of November'
    # _ncmsg( '%1$s of December'

    my $en_day_and_month = '%1$s of ' . ucfirst( lc( $en_start_dt->month_name ) );

    my $day_suffix = ( $language ne 'en' ) ? '.' : ( $start_dt->day > 10 && $start_dt->day < 14 ) ? 'th' : [ qw( th st nd rd th th th th th th ) ]->[ $start_dt->day % 10 ];
    my $day_and_month = $self->_ncmsg( $en_day_and_month, { lang => $language }, [ $start_dt->day . $day_suffix ] );

    my $tz_info = Dicole::Utils::Date->timezone_info_for_timezone_and_epoch( $timezone, $start_epoch );

    my $in_days = 0;
    while ( $in_days < 102 && ( $now_dt->ymd ne $start_dt->ymd ) ) {
        $in_days += 1;
        $now_dt->add( days => 1 );
    }

    my $in_days_readable = ( $in_days == 0 ) ? $self->_ncmsg('Today', { lang => $language } ) : '';
    $in_days_readable ||= ( $in_days == 1 ) ? $self->_ncmsg('Tomorrow', { lang => $language } ) : '';
    $in_days_readable ||= $self->_ncmsg('In %1$s days', { lang => $language }, [ $in_days ] );

    return {
        stamp => join( "-", $start_epoch, $end_epoch, $timezone ),
        start_epoch => $start_epoch,
        end_epoch => $end_epoch,
        start_time_ampm => Dicole::Utils::Date->datetime_to_hour_minute( $start_dt, 'ampm' ),
        end_time_ampm => Dicole::Utils::Date->datetime_to_hour_minute( $end_dt, 'ampm' ),
        start_time_24h => Dicole::Utils::Date->datetime_to_hour_minute( $start_dt, '24h' ),
        end_time_24h => Dicole::Utils::Date->datetime_to_hour_minute( $end_dt, '24h' ),
        weekday => $start_dt->day_of_week,
        weekday_readable => ucfirst( lc( $start_dt->day_name ) ),
        day => $start_dt->day,
        month => $start_dt->month,
        day_and_month_readable => $day_and_month,
        timezone => $tz_info->{name},
        timezone_readable => $tz_info->{readable_name},
        timezone_offset => $tz_info->{offset_value},
        timezone_offset_readable => $tz_info->{offset_string},
        in_days => $in_days,
        in_days_readable => $in_days_readable,
    };
}

sub matchmaker_cancel_lock {
    my ( $self ) = @_;

    my $mm_id = $self->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;

    my $lock_id = CTX->request->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    $lock->cancel_date( time );
    $lock->save;

    $self->_store_matchmaker_lock_event( $matchmaker, $lock, 'canceled' );

    return { result => { success => 1 } };
}

sub matchmaker_confirm {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    my $mm_id = $self->param('matchmaker_id');
    my $mm = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $mm;

    my $lock_id = CTX->request->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    return { error => { message => 'Lock could not be found' } } if ! $lock || $lock->cancel_date;
    return { error => { message => 'Lock has expired' } } if $lock->expire_date < time;

    $lock->agenda( CTX->request->param('agenda') );
    $lock->title( CTX->request->param('title') );

    if ( CTX->request->param('quickmeet_key') ) {
        $self->_set_note( quickmeet_key => CTX->request->param('quickmeet_key'), $lock );
        return { result => { url_after_post => $self->derive_url( action => 'meetings', task => 'matchmaking_success', additional => [ $lock->id ] ) } };
    }
    elsif ( $uid && CTX->request->auth_user->email ) {
        $lock->save;
        return { result => { url_after_post => $self->derive_url( action => 'meetings', task => 'matchmaking_success', additional => [ $lock->id ] ) } };
    }
    else {
        $lock->expire_date( time + 60*60 );
        $lock->save;
        return { result => { registration_needed => 1, lock_id => $lock->id } };
    }
}

sub matchmaker_confirm_register {
    my ( $self ) = @_;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $user_mode = '';
    my $user = undef;

    my $lock_id = CTX->request->param('lock_id');
    my $lock = $lock_id ? $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock_id ) : undef;

    die "no lock found" unless $lock;

    my $mm_id = $lock->matchmaker_id;
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "no matchmaker found" unless $matchmaker;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $email = CTX->request->param( 'email' );

    die unless $email;

    if ( my $old_user = $self->_fetch_user_for_email( $email, $domain_id ) ) {
        $user_mode = 'existing';
        $user = $old_user;
        $self->_add_user_profile_info_from_request_params( $user, $domain_id );
    }
    else {
        $user_mode = 'new';
        $user = $self->_fetch_or_create_user_for_email( $email, $domain_id, { language => $mm_event ? $self->_get_note( default_language => $mm_event ) : '' } );
        $self->_store_user_profile_info_from_request_params( $user, $domain_id );

        $user->language( $self->language );

        if ( $mm_event && $self->_get_note( default_timezone => $mm_event ) ) {
            $user->timezone( $self->_get_note( default_timezone => $mm_event ) );
        }
        elsif ( my $utz = $self->_get_note( user_time_zone => $lock ) ) {
            $user->timezone( $utz );
        }
        elsif ( my $tz = $self->_get_note( time_zone => $matchmaker ) ) {
            $user->timezone( $tz );
        }
        else {
            $user->timezone( 'UTC' );
        }

        $self->_set_note_for_user( created_through_matchmaker_id => $matchmaker->id, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( created_by_partner => $matchmaker->partner_id, $user, $domain_id, { skip_save => 1 } ) if $matchmaker->partner_id;

        get_logger(LOG_APP)->error("marked tos accept without parameter:" . $user->id ) unless CTX->request->param( 'accept_tos' );

        $self->_user_accept_tos( $user, $domain_id, 'skip_save' );
        $user->save;
    }

    $lock->expected_confirmer_id( $user->id );
    $lock->save;

    my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );

    my $host = $self->param('partner') ? $self->_get_host_for_partner( $self->param('partner'), 443 ) : '';

    my $validate_url = $self->_generate_authorized_uri_for_user(
        $host . $self->derive_url( action => 'meetings', task => 'matchmaking_success', additional => [ $lock->id ] ),
        $user,
        $domain_id,
    );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $domain_id,
        partner_id => $self->param('partner_id'),
        group_id => 0,

        template_key_base => ( $user_mode eq 'existing' ) ? 'meetings_matchmaker_choose_merge' : 'meetings_matchmaker_choose_registration',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            user_email => $user->email,
            matchmaker_name => Dicole::Utils::User->name( $creator_user ),
            matchmaker_email => $creator_user->email,
            matchmaker_company => $matchmaker->name,
            verify_url => $validate_url,
        },
    );

    return { result => {
        url_after_post => $self->derive_url( action => 'meetings', task => 'matchmaking_user_register_success', additional => [ $lock->id ], params => { email => $user->email } )
    } };
}

sub matchmaking_admin_editor_edit {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    die "security error" unless $user;

    my $mm_id = CTX->request->param('matchmaker_id');
    my $matchmaker = $mm_id ? $self->_ensure_object_of_type( meetings_matchmaker => $mm_id ) : undef;

    die "missing matchmaker" unless $matchmaker;
    die "security error" unless $matchmaker->creator_id == $user->id || $self->_get_note_for_user( developer => $user, $domain_id );

    $matchmaker->name( CTX->request->param('registration_organization') || '' );
    $matchmaker->description( CTX->request->param('description') || '' );
    $matchmaker->website( CTX->request->param('website') || '' );

    if ( $self->_get_note_for_user( developer => $user, $domain_id ) ) {
        $matchmaker->disabled_date( time ) if CTX->request->param('is_disabled') && ! $matchmaker->disabled_date;
        $matchmaker->disabled_date( 0 ) if ! CTX->request->param('is_disabled') && $matchmaker->disabled_date;
    }

    $matchmaker->save;

    if ( my $logo_draft_id = CTX->request->param('logo_draft_id') ) {
        my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $logo_draft_id,
            } );

        CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $matchmaker,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

        $matchmaker->logo_attachment_id( $a->id );
        $matchmaker->save;
    }

    if ( my $deck_draft_id = CTX->request->param('deck_draft_id') ) {
        my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $deck_draft_id,
            } );

        CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $matchmaker,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

        $self->_set_note( deck_attachment_id => $a->id, $matchmaker );
    }

    # TODO: check values for validity
    my $track = CTX->request->param('track');
    $self->_set_note( track => $track, $matchmaker, { skip_save => 1 } );

    my $tracks = [ CTX->request->param('market') ];
    $self->_set_note( market_list => $tracks, $matchmaker );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg("Your changes have been saved successfully.") );

    return { result => { url_after_post => $self->derive_url( action => 'meetings', task => 'matchmaking_admin_editor', additional => [ $matchmaker->id ] ) } };

}

sub comment_state { return $_[0]->_object_comment_state( $_[0]->_get_valid_event ); };
sub wiki_comment_state { return $_[0]->_object_comment_state( $_[0]->_get_valid_wiki ); };
sub prese_comment_state { return $_[0]->_object_comment_state( $_[0]->_get_valid_prese ); };

sub _object_comment_state {
    my ( $self, $object ) = @_;

    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = CTX->lookup_action('comments_api')->e( get_state => {
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
        size => CTX->request->param('commenter_size') || 36,
        no_default => 1,
        display_type => 'ampm',
    } );

    return { result => { state => $state } };
}

sub comment_state_info { return $_[0]->_object_comment_state_info( $_[0]->_get_valid_event ); };
sub wiki_comment_state_info { return $_[0]->_object_comment_state_info( $_[0]->_get_valid_wiki ); };
sub prese_comment_state_info { return $_[0]->_object_comment_state_info( $_[0]->_get_valid_prese ); };

sub _object_comment_state_info {
    my ( $self, $object ) = @_;

    my $event = $self->_get_valid_event;
    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $list_json = CTX->request->param('comment_id_list');
    my $list = Dicole::Utils::JSON->decode( $list_json || '[]' );

    my $comments = CTX->lookup_action('comments_api')->e( get_info_hash_for_id_list => {
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
        size => CTX->request->param('commenter_size') || 36,
        no_default => 1,
        id_list => $list,
        display_type => 'ampm',
    } );

    my $user = CTX->request->auth_user;
    my $right_to_manage = $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    for my $comment_id ( %$comments ) {
        my $comment = $comments->{ $comment_id };
        $comment->{user_data_url} =  $self->derive_url( action => 'meetings_json', task => 'user_info', additional => [ $event->id, $comment->{user_id} ] );
        if ( $right_to_manage || $comment->{user_id} == $user->id ) {
            $comment->{right_to_delete} = 1;
            $comment->{right_to_edit} = 1;
        }
    }

    return { comments => $comments };
}

sub comment_state_add { return $_[0]->_object_comment_state_add( $_[0]->_get_valid_event ); };
sub wiki_comment_state_add { return $_[0]->_object_comment_state_add( $_[0]->_get_valid_wiki ); };
sub prese_comment_state_add { return $_[0]->_object_comment_state_add( $_[0]->_get_valid_prese ); };

sub _object_comment_state_add {
    my ( $self, $object ) = @_;

    my $event = $self->_get_valid_event;
    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user_id = CTX->request->auth_user_id;

    die "security error" unless $user_id && $self->_fetch_meeting_participant_object_for_user( $event, $user_id );

    my $comment_content = CTX->request->param('content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
    } );

    my $comment = eval {
        CTX->lookup_action('comments_api')->e( add_comment_and_return_post => {
            thread => $thread,
            object => $object,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            content => $comment_html,
            parent_post_id => CTX->request->param('parent_post_id'),
            requesting_user_id => $user_id,
            requires_approval => 0,
            display_type => 'ampm',
        } );
    };

    if ( $comment ) {
        $self->_store_comment_event( $event, $comment, $object, 'created' );
    }

    my $state = CTX->lookup_action('comments_api')->e( get_state => {
        thread => $thread,
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
        size => CTX->request->param('commenter_size') || 36,
        no_default => 1,
        display_type => 'ampm',
    } );

    return { result => { state => $state } };
}

sub comment_state_delete { return $_[0]->_object_comment_state_delete( $_[0]->_get_valid_event ); };
sub wiki_comment_state_delete { return $_[0]->_object_comment_state_delete( $_[0]->_get_valid_wiki ); };
sub prese_comment_state_delete { return $_[0]->_object_comment_state_delete( $_[0]->_get_valid_prese ); };

sub _object_comment_state_delete {
    my ( $self, $object ) = @_;

    my $event = $self->_get_valid_event;
    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user_id = CTX->request->auth_user_id;

    die "security error" unless $user_id && $self->_fetch_meeting_participant_object_for_user( $event, $user_id );

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
    } );

    my $comment = eval {
        CTX->lookup_action('comments_api')->e( delete_comment_and_return_post => {
            thread => $thread,
            object => $object,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            post_id => CTX->request->param('post_id'),
            right_to_remove_comments => $self->_user_can_manage_meeting( CTX->request->auth_user, $event ) ? 1 : 0,
            requesting_user_id => CTX->request->auth_user_id,
            display_type => 'ampm',
        } );
    };

    if ( $comment ) {
        $self->_store_comment_event( $event, $comment, $object, 'removed' );
    }

    my $state = CTX->lookup_action('comments_api')->e( get_state => {
        thread => $thread,
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
        size => CTX->request->param('commenter_size') || 36,
        no_default => 1,
        display_type => 'ampm',
    } );

    return { result => { state => $state } };
}

sub comment_state_edit { return $_[0]->_object_comment_state_edit( $_[0]->_get_valid_event ); };
sub wiki_comment_state_edit { return $_[0]->_object_comment_state_edit( $_[0]->_get_valid_wiki ); };
sub prese_comment_state_edit { return $_[0]->_object_comment_state_edit( $_[0]->_get_valid_prese ); };

sub _object_comment_state_edit {
    my ( $self, $object ) = @_;

    my $event = $self->_get_valid_event;
    my $group_id = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user_id = CTX->request->auth_user_id;

    die "security error" unless $user_id && $self->_fetch_meeting_participant_object_for_user( $event, $user_id );

    my $comment_content = CTX->request->param('content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $object,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
    } );

    my $comment = eval {
        CTX->lookup_action('comments_api')->e( edit_comment_and_return_post => {
            thread => $thread,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            post_id => CTX->request->param('post_id'),
            content => $comment_html,
            right_to_edit_comments => $self->_user_can_manage_meeting( CTX->request->auth_user, $event ) ? 1 : 0,
            requesting_user_id => CTX->request->auth_user_id,
            display_type => 'ampm',
        } );
    };

    if ( $comment ) {
        $self->_store_comment_event( $event, $comment, $object, 'edited' );
    }

    my $state = CTX->lookup_action('comments_api')->e( get_state => {
        thread => $thread,
        object => $event,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
        size => CTX->request->param('commenter_size') || 36,
        no_default => 1,
        display_type => 'ampm',
    } );

    return { result => { state => $state } };
}

sub wiki_object_info {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $page = $self->_get_valid_wiki( $self, $event, CTX->request->auth_user );
    my $uid = CTX->request->auth_user_id;

    my $info = CTX->lookup_action('wiki_api')->e( object_info => { page => $page, requesting_user_id => CTX->request->auth_user_id } );

    my $current_lock = CTX->lookup_action('wiki_api')->e( get_full_lock => { page => $page } );
    my $locked_by_self = ( $uid && $current_lock && $current_lock->{user_id} == $uid ) ? 1 : 0;

    $info->{readable_title} = $self->_strip_tag_from_page_title( $info->{readable_title} );
    $info->{material_class} = 'agenda' if $self->_agenda_page_validator( $info );
    $info->{material_class} ||= 'action_points' if $self->_action_points_page_validator( $info );
    $info->{material_class} ||= 'other' if $self->_agenda_page_validator( $info );
    $info->{readable_title} = $self->_translate_special_page_title( $info->{readable_title} );

    my $attached_matchmaking_event_id = $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event );

    $info = {
        %$info,
        comment_state_url => $self->derive_url( action => 'meetings_json', task => 'wiki_comment_state', additional => [ $event->id, $page->id ] ),
        comment_info_url => $self->derive_url( action => 'meetings_json', task => 'wiki_comment_state_info', additional => [ $event->id, $page->id ] ),
        comment_add_url => $self->derive_url( action => 'meetings_json', task => 'wiki_comment_state_add', additional => [ $event->id, $page->id ] ),
        comment_delete_url => $self->derive_url( action => 'meetings_json', task => 'wiki_comment_state_delete', additional => [ $event->id, $page->id ] ),
        comment_edit_url => $self->derive_url( action => 'meetings_json', task => 'wiki_comment_state_edit', additional => [ $event->id, $page->id ] ),
        data_url => $self->derive_url( action => 'meetings_json', task => 'wiki_object_info', additional => [ $event->id, $page->id ] ),
        user_can_manage => $self->_user_can_manage_meeting( $uid, $event ),
        user_can_edit_material => $self->_user_can_edit_material( $uid, $event ),

        raw_get_url => $self->derive_url(
            action => 'meetings_json', task => 'start_wiki_edit', additional => [ $event->id, $page->id ],
        ),
        raw_continue_url => $self->derive_url(
            action => 'meetings_json', task => 'continue_wiki_edit', additional => [ $event->id, $page->id ],
        ),
        raw_put_url => $self->derive_url(
            action => 'meetings_json', task => 'store_wiki_edit', additional => [ $event->id, $page->id ],
        ),
        ensure_lock_url => $self->derive_url(
            action => 'meetings_json', task => 'ensure_wiki_lock', additional => [ $event->id, $page->id ],
        ),
        cancel_edit_url => $self->derive_url(
            action => 'meetings_json', task => 'cancel_wiki_edit', additional => [ $event->id, $page->id ],
        ),
        locked_by_name => ( $current_lock && $current_lock->{user_id} ) ? Dicole::Utils::User->name( $current_lock->{user_id} ) : '',
        locked_by_self => $locked_by_self,
        attached_to_matchmaking_event => $attached_matchmaking_event_id ? 1 : 0,
    };

    return { result => $info };
}

sub prese_object_info {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $prese = $self->_get_valid_prese( $self, $event );
    my $uid = CTX->request->auth_user_id;

    my $info = CTX->lookup_action('presentations_api')->e( object_info => { prese => $prese } );

    $info = {
        %$info,
        comment_state_url => $self->derive_url( action => 'meetings_json', task => 'prese_comment_state', additional => [ $event->id, $prese->id ] ),
        comment_info_url => $self->derive_url( action => 'meetings_json', task => 'prese_comment_state_info', additional => [ $event->id, $prese->id ] ),
        comment_add_url => $self->derive_url( action => 'meetings_json', task => 'prese_comment_state_add', additional => [ $event->id, $prese->id ] ),
        comment_delete_url => $self->derive_url( action => 'meetings_json', task => 'prese_comment_state_delete', additional => [ $event->id, $prese->id ] ),
        comment_edit_url => $self->derive_url( action => 'meetings_json', task => 'prese_comment_state_edit', additional => [ $event->id, $prese->id ] ),
        data_url => $self->derive_url( action => 'meetings_json', task => 'prese_object_info', additional => [ $event->id, $prese->id ] ),
        user_can_manage => $self->_user_can_manage_meeting_prese( $uid, $event, $prese ),
        user_can_edit_material => $self->_user_can_edit_material( $uid, $event ),
    };

    return { result => $info };
}

sub chat_object_info {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $event,
        group_id => $event->group_id,
        user_id => 0,
    } );

    my $info = {
        type => 'chat',
        title => $self->_nmsg('Scheduling Discussion'),
        comment_thread_id => $thread->id,
        comment_state_url => $self->derive_url( action => 'meetings_json', task => 'comment_state', additional => [ $event->id ] ),
        comment_info_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_info', additional => [ $event->id ] ),
        comment_add_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_add', additional => [ $event->id ] ),
        comment_delete_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_delete', additional => [ $event->id ] ),
        comment_edit_url => $self->derive_url( action => 'meetings_json', task => 'comment_state_edit', additional => [ $event->id ] ),
        data_url => $self->derive_url( action => 'meetings_json', task => 'chat_object_info', additional => [ $event->id ] ),
    };

    return { result => $info };
}

sub timezone_data {
    my ( $self ) = @_;

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    return { result => {
        timezone_choices => $timezone_choices,
        timezone_data => $timezone_data,
    } };
}

sub timezone_data_export {
    my ( $self ) = @_;

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    return {
        choices => $timezone_choices,
        data => $timezone_data,
    };
}

sub change_timezone {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    return "security error" unless $user;

    $user->timezone( CTX->request->param('timezone') );
    $user->save;

    return { result => { success => $user->id } };
}

sub confirm_timezone {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    die "security error" unless $user;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( my $choose = CTX->request->param('choose') ) {
        $user->timezone( $choose );
    }

    if ( my $dismiss = CTX->request->param('dismiss') ) {
        my $lookup = $self->_get_note_for_user( dismissed_timezones => $user, $domain_id ) || {};
        $lookup->{ $dismiss } = time;
        $self->_set_note_for_user( dismissed_timezones => $lookup, $user, $domain_id, { skip_save => 1 } );
    }

    $user->save;

    return { result => { success => $user->id } };
}


sub invite_participants_data {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $domain_id = $meeting->domain_id;
    my $user_id = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    die "security error" unless $user_id;

    # Cache the address book data only if this is an older user. This is because newer users
    # are more likely to need the fresh data from meetings which were just created AND it is
    # fast to generate their address book data so it doesn't matter.
    # NOTE: google contacts will nevertheless be cached inside _gather_addressbook_data.

    my $meeting_count = $self->_count_user_meeting_participation_objects_in_domain( $user, $domain_id );

    my $ab_data = Dicole::Cache->fetch_or_store( 'addressbook_data_for_user_' . $user->id, sub {
        return $self->_gather_addressbook_data( $user, $domain_id )
    }, { expires => 60*60, domain_id => $domain_id, no_group_id => 1, lock_timeout => 3*60, skip_cache => $meeting_count < 20 ? 1 : 0 } );

    my %participant_id_lookup = ();

    my $euos = $self->_fetch_meeting_participation_objects( $meeting );
    $participant_id_lookup{ $_->user_id } = 1 for @$euos;

    # Do some meeting specific modifications to the cached data like remove current meeting
    # data and add fresh current meeting participants to the user list as they might be
    # stale in the caced data but this is an important place for them to not be stale..

    my $meeting_data_list = [ map { $_->{id} == $meeting->id ? () : $_ } @{ $ab_data->{meetings} } ];
    my $users_data_hash = $self->_merge_users_to_users_data_hash( [ keys %participant_id_lookup ], $domain_id, $ab_data->{users_data_hash} );

    my $return_url = $self->derive_url( action => 'meetings_raw', task => 'cookie_forward', additional => [], params => { to => $self->derive_url( action => 'meetings', task => 'meeting', params => { open_addressbook => 1 } ) } );

    my $data = {
        participant_id_lookup => \%participant_id_lookup,
        user_data_list => $users_data_hash->{users_data},
        meeting_data_list => $meeting_data_list,

        facebook_connected => $self->_get_note_for_user( 'meetings_facebook_access_token', CTX->request->auth_user ) ? 1 : 0,
        facebook_start_url => $self->derive_url( action => 'meetings_global', task => 'facebook_start', target => 0, additional => [], params => { return_url => $return_url }  ),
        linkedin_connected => $self->_get_note_for_user( 'meetings_linkedin_access_token', CTX->request->auth_user ) ? 1 : 0,
        linkedin_start_url => $self->derive_url( action => 'meetings_global', task => 'linkedin_start', target => 0, additional => [], params => { return_url => $return_url }  ),
        google_connected => $self->_user_has_connected_google( CTX->request->auth_user ) ? 1 : 0,
        google_start_url => $self->derive_url( action => 'meetings_global', task => 'google_start_2', target => 0, additional => [], params => { return_url => $return_url, require_refresh_token => 1 }  ),
    };

    return { result => $data };
}

sub _gather_addressbook_data {
    my ( $self, $user, $domain_id ) = @_;

    my $meetings_data_hash = $self->_get_address_book_meetings_data_hash_for_user( $user, $domain_id );
    my $meetings_data_list = [ map { $meetings_data_hash->{ $_ } } keys %$meetings_data_hash ];

    my %user_id_lookup = ();

    for my $meeting_data ( @$meetings_data_list ) {
        $user_id_lookup{ $_ } = 1 for @{ $meeting_data->{participant_id_list} || [] };
    }

    for my $friend_id ( @{ $self->_user_facebook_friend_id_list( $user, $domain_id ) } ) {
        $user_id_lookup{ $friend_id } = 1;
    }

    my $users_data_hash = $self->_get_user_google_contacts_users_data_hash( $user->id, $domain_id );
    $users_data_hash = $self->_merge_users_to_users_data_hash( [ keys %user_id_lookup ], $domain_id, $users_data_hash );

    my $time_year_ago = time - 60 * 60 * 24 * 365;
    my $meetings_data = [ map { $_->{begin_date} < $time_year_ago ? () : $_ } @$meetings_data_list ];
    $meetings_data = [ sort { $b->{begin_date} <=> $a->{begin_date} } @$meetings_data ];

    return { users_data_hash => $users_data_hash, meetings => $meetings_data };
}

sub _merge_users_to_users_data_hash {
    my ( $self, $users, $domain_id, $users_data_hash ) = @_;

    my $new_user_list = [];

    for my $user ( @$users ) {
        my $id = Dicole::Utils::User->ensure_id( $user );
        push @$new_user_list, $user unless $users_data_hash->{id_lookup}->{ $id };
    }

    $users = Dicole::Utils::User->ensure_object_list( $new_user_list );
    my $users_data = $self->_gather_users_info( $users, 50, $domain_id, 'skip forwarded and empty' );

    for my $ud ( @$users_data ) {
        my $user_id = $ud->{user_id};
        next if $users_data_hash->{id_lookup}->{ $user_id };

        $users_data_hash->{id_lookup}->{ $user_id } = $ud;

        my $email = lc( $ud->{email} );
        my $nametag = $self->_generate_nametag( $ud->{name} );

        my $exists = 0;

        if ( my $old_ud = $users_data_hash->{email_lookup}->{ $email } ) {
            if ( ! $old_ud->{user_id} ) {
                $old_ud->{deleted} = 1;
                $users_data_hash->{email_lookup}->{ $email } = $ud;
            }
            else {
                $exists = 1;
            }
        }
        else {
            $users_data_hash->{email_lookup}->{ $email } = $ud;
        }

        if ( my $old_ud = $users_data_hash->{name_lookup}->{ $nametag } ) {
            if ( ! $old_ud->{user_id} ) {
                $old_ud->{deleted} = 1;
                $users_data_hash->{name_lookup}->{ $nametag } = $ud;
            }
        }
        else {
            $users_data_hash->{name_lookup}->{ $nametag } = $ud;
        }

        push @{ $users_data_hash->{users_data} }, $ud unless $exists;
    }

    $users_data_hash->{users_data} = [ map { $_->{deleted} ? () : $_ } @{ $users_data_hash->{users_data} } ];
    $users_data_hash->{users_data} = [ sort { uc($a->{name}) cmp uc($b->{name}) } @{ $users_data_hash->{users_data} } ];

    return $users_data_hash;
}

sub _get_user_google_contacts_users_data_hash {
    my ( $self, $user_id, $domain_id ) = @_;

    my $data = $self->_fetch_or_cache_user_google_contacts( $user_id, $domain_id );

    my $users_data = [];
    my $email_lookup = {};
    my $name_lookup = {};

    for my $id ( keys %{ $data->{entry} } ) {
        # "current" key is used to easily distinguish if  this is the object we are dealing
        # with on this round. It is deleted at the end before pushing to the users_data.
        my $ud = { current => 1 };

        my $e = $data->{entry}{ $id };

        if ( ref( $e->{"gd:email"} ) eq 'ARRAY' ) {
            for my $ed ( @{ $e->{"gd:email"} } ) {
                next unless $ed->{address};

                $ud->{email} = $ed->{address} if $ed->{primary} eq 'true';

                my $existing = $email_lookup->{ lc( $ed->{address} ) };
                $ud->{deleted} = 1 if $existing && ! $existing->{current};
                $email_lookup->{ lc( $ed->{address} ) } ||= $ud;
            }
        }
        else {
            $ud->{email} = $e->{"gd:email"}->{address};
            if ( $ud->{email} ) {
                my $existing = $email_lookup->{ lc( $ud->{email} ) };
                $ud->{deleted} = 1 if $existing && ! $existing->{current};
                $email_lookup->{ lc( $ud->{email} ) } ||= $ud;
            }
        }

        next unless $ud->{email};

        $ud->{name} = $e->{"gd:name"}{"gd:fullName"} || ( ref( $e->{"title"} ) ? '' : $e->{"title"} );
        $ud->{name} ||= $ud->{email};

        if ( my $nametag = $self->_generate_nametag( $e->{"gd:name"}{"gd:fullName"} ) ) {
            $ud->{deleted} = 1 if $name_lookup->{ $nametag } && ! $name_lookup->{ $nametag }->{current};
            $name_lookup->{ $nametag } ||= $ud;
        }

        if ( my $nametag = $self->_generate_nametag( ref( $e->{"title"} ) ? '' : $e->{"title"} ) ) {
            $ud->{deleted} = 1 if $name_lookup->{ $nametag } && ! $name_lookup->{ $nametag }->{current};
            $name_lookup->{ $nametag } ||= $ud;
        }

        my $image = '';
        for my $link ( @{ ref( $e->{link} ) eq 'ARRAY' ? $e->{link} : []  } ) {
            next unless $link->{rel} eq 'http://schemas.google.com/contacts/2008/rel#photo';
            my $source = $link->{href};
            next unless $source;
            my $i = $self->derive_url(
                action => 'meetings_raw', task => 'google_contact_image', additional => [ 'image.png' ],
                params => { url => $source },
            );
            ## TODO: this image url is not yet used
#            get_logger(LOG_APP)->error( $i );
#            $ud->{image} = $i;
        }

        delete $ud->{current};

        push @$users_data, $ud unless $ud->{deleted};
    }

    return {
        users_data => $users_data,
        name_lookup => $name_lookup,
        email_lookup => $email_lookup,
        id_lookup => {},
    };
}

sub _generate_nametag {
    my ( $self, $name ) = @_;

    return '' unless $name;

    my @n = split( /\s+/, lc($name) );

    return scalar(@n) > 1 ? $n[0].$n[-1] : $n[0];
}

sub get_meeting_info {
    my ($self) = @_;

    die "serucity error" unless CTX->request->auth_user_id;

    my $event = $self->_get_valid_event;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $event_users = $self->_fetch_meeting_participation_objects( $event );
    my $draft_participants = $self->_fetch_meeting_draft_participation_objects( $event );
    my $user_objects = Dicole::Utils::User->ensure_object_list( [ map { $_->user_id || () } ( @$event_users, @$draft_participants ) ] );

    my %user_objects = map { $_->user_id => $_ } @$user_objects;
    my %event_user_objects = map { $_->user_id => $_ } @$event_users;

    my $proposals = $self->_fetch_meeting_proposals( $event );

    my $participants_info = $self->_gather_meeting_users_info( $event, 50, $domain_id, \%event_user_objects, $user_objects, $proposals );
    my $draft_participants_info = $self->_gather_meeting_draft_participants_info( $event, 50, $draft_participants, $user_objects );

    my $participants = [];

    for ( @{ $self->_sort_participant_info_list( [ @$participants_info, @$draft_participants_info ] ) } ) {
        push @$participants, {
            name => $_->{name},
            user_id => $_->{user_id},
            initials => $_->{initials},
            rsvp_string => $_->{rsvp_string},
            last_action_string => $_->{last_action_string},
            is_manager => $_->{is_manager},
            is_creator => $_->{is_creator},
            rsvp => $_->{rsvp},
            rsvp_required => $_->{rsvp_required},
            rsvp_status => $_->{rsvp_status},
            image => $_->{image},
            draft_object_id => $_->{draft_object_id},
            data_url => $_->{data_url},
        } unless $_->{is_hidden};
    }

    my $user = CTX->request->auth_user;
    my $user_can_manage_meeting = $self->_user_can_manage_meeting( $user, $event );
    my $user_can_invite = $self->_user_can_invite( undef, $event );
    my $euo = $event_user_objects{ $user->id };

    my $sponsors = $self->_meeting_sponsor_names( $event, $user_objects{ $event->creator_id } );
    my $sponsors_string = $self->_meeting_sponsor_names_string( $event, $sponsors );

    my $meeting_is_pro = $self->_meeting_is_pro( $event, $user_objects{ $event->creator_id } );
    my $show_go_pro = ( $meeting_is_pro || $user->id != $event->creator_id ) ? 0 : 1;

    my $email = $self->_get_meeting_email( $event, $domain_id );
    my $creator_user = $event->creator_id ? Dicole::Utils::User->ensure_object( $event->creator_id ) : undef;

    my $join_pass = $self->_get_meeting_join_password( $event );
    my $join_guide_url = URI->new('https://m.meetin.gs/meeting_join_info.html');
    $join_guide_url->query_form(
        meeting_title => $self->_meeting_title_string( $event ),
        meeting_email => $email,
        meeting_password => $join_pass,
        meeting_url => $self->_get_host_for_meeting( $event, 443 ) . $self->derive_url( action => 'meetings', task => 'meeting' ),
    );

    my $rsvp_params = $self->_meeting_user_rsvp_required_parameters( $event, $user );

    my $next_action_bar_params = {};
    if ( $event->end_date && time > $event->end_date && ! $self->_meeting_is_draft( $event ) ) {
        my $seconds_until_after_email = $event->end_date + 12 * 60 * 60 - time;

#        my $f_meeting_id = $self->_get_note_for_meeting( 'followup_meeting_id', $event );
#        my $f_meeting = $f_meeting_id ? $self->_ensure_meeting_object( $f_meeting_id ) : undef;
#        my $f_meeting_euo = $f_meeting ? $self->_fetch_meeting_participant_object_for_user( $event, $user->id ) : undef;

        my $f_meeting = undef;
        my $f_meeting_euo = undef;

        # HACK: show instantly after meeting for now:
        $seconds_until_after_email = 0;

        if ( $f_meeting && $f_meeting_euo ) {
            $next_action_bar_params->{followup_meeting_url} = $self->derive_url( action => 'meetings', task => 'meeting', target => $f_meeting->group_id, additional => [ $f_meeting->id ] );
        }
        elsif ( $self->_get_note_for_meeting( 'after_emails_sent', $event ) || $seconds_until_after_email < 1 ) {
            $next_action_bar_params->{create_followup_url} = $self->derive_url( action => 'meetings', task => 'create_followup', target => $event->group_id, additional => [ $event->id ] );
        }
        else {
            $next_action_bar_params->{seconds_until_after_email} = $seconds_until_after_email > 0 ? $seconds_until_after_email : 0;
        }
    }

    my ( $date, $times, $timezone_string ) = $self->_timespan_parts_for_meeting( $event, $user );

    my $live_conf_params = $self->_gather_meeting_live_conferencing_params( $event, $user );

    return {
        result => {
            %{ $self->get_basic->{result} },
            %$next_action_bar_params,
            %$live_conf_params,
            participants => $participants,
            date_proposal_count => scalar( @$proposals ),
            helpers_shown => $self->_get_note_for_meeting( 'meeting_helpers_shown', $event ) ? 1 : 0,
            calendar => $self->_calendar_params_for_epoch($event->begin_date, $event->end_date),
            ics_url => $event->begin_date ? $self->derive_url( action => 'meetings_raw', task => 'ics', additional => [ $event->id, 'meeting.ics' ] ) : '',
            invite_participants_data_url => ($user_can_invite) ? $self->derive_url( task => 'invite_participants_data' ) : '',
            meeting_sponsored_by_count => scalar( @$sponsors ),
            meeting_sponsored_by_string => $sponsors_string,
            show_go_pro => $show_go_pro,
            short_email => $email,
            user_can_add_material => $self->_user_can_add_material( $user, $event, $euo ),
            ( $meeting_is_pro && $user_can_invite ) ? (
                join_password => uc( $join_pass ),
                join_guide_url => $join_guide_url->as_string,
            ) : (),
            $user_can_manage_meeting ? (
                $user->email ?
                    ( draft_ready_data_url => $self->derive_url( action => 'meetings_json', task => 'draft_ready' ) ) :
                    ( temp_draft_ready_data_url => $self->derive_url( action => 'meetings_json', task => 'temp_draft_ready' ) ),
                get_basic_url => $self->derive_url( action => 'meetings_json', task => 'get_basic' ),
                get_location_url => $self->derive_url( action => 'meetings_json', task => 'get_location' ),
                manage_conferencing_url => $self->derive_url( action => 'meetings_json', task => 'conferencing_data' ),
                user_is_admin => 1,
            ) : (),
            user_rsvp => $self->_determine_meeting_user_rsvp_status( $event, $user, $euo ),
            user_rsvp_required => $rsvp_params->{rsvp_required} ? 1 : 0,

            time_string => $times || '',
            date_string => $date || '',
            timezone_string => $timezone_string || '',
        }
    };
}

sub get_basic {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $event = $self->_get_valid_event;

    my $dts = $event->begin_date ? Dicole::Utils::Date->epoch_to_date_and_time_strings( $event->begin_date, undef, undef, 'ampm' ) : [ 0, '12 pm' ];

    my $duration_seconds = $event->end_date - $event->begin_date;
    my $duration_minutes = int( $duration_seconds / 60 );

    my $pos = $self->_fetch_meeting_proposals( $event );
    my $euos = $self->_fetch_meeting_participant_objects( $event );
    my $dps = $self->_fetch_meeting_draft_participation_objects( $event );

    my ( $hour, $min, $ampm );

    if ( $event->begin_date ) {
        my $dt = Dicole::Utils::Date->epoch_to_datetime( $event->begin_date, undef, undef );
        ( $hour, $min, $ampm ) = ( $dt->hour, $dt->minute, $dt->hour > 11 ? 'pm' : 'am' );
    }
    else {
        ( $hour, $min, $ampm ) = ( 12, 0, 'pm' );
    }

    my $attached_matchmaking_event_id = $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event );
    my $matchmaker_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $event );
    my $matchmaking_accepted = $self->_meeting_is_matchmaking_accepted( $event );

    my $matchmaking_banner_params = {};
    if ( ! $matchmaking_accepted ) {
        $matchmaking_banner_params->{matchmaking_accept_url} = $self->derive_url( task => 'accept_matchmaking_request' );
        $matchmaking_banner_params->{matchmaking_requester_name} = eval { $self->_get_meeting_matchmaking_requester_name( $event ) };
        $matchmaking_banner_params->{matchmaking_event_name} = eval { $self->_get_meeting_matchmaking_event_name( $event ) };
    }

    if ( my $mm_event_id = $self->_get_note( attached_to_matchmaking_event_id => $event ) ) {
        my $mm_event = $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id );
        $attached_matchmaking_event_id = 0 if $mm_event && $self->_get_note( unlock_date_changing => $mm_event );
    }

    return {
        result => {
            id => $event->id,
            attached_to_matchmaking_event => $attached_matchmaking_event_id ? 1 : 0,
            %$matchmaking_banner_params,
            remove_url => $self->derive_url( task => 'get_basic' ),
            title => $event->title,
            title_string => $self->_meeting_title_string( $event ),
            is_draft => $self->_meeting_is_draft( $event ),
            location => $event->location_name,
            location_string => $self->_meeting_location_string($event),
            physical_location_string => $self->_meeting_physical_location_string($event),
            virtual_location_string => $self->_meeting_virtual_location_string($event),
            online_conferencing_option => $self->_get_note_for_meeting( online_conferencing_option => $event),
            online_conferencing_data => $self->_get_note_for_meeting( online_conferencing_data => $event ),
            skype_account => $self->_get_note_for_meeting( skype_account => $event ),
            proposal_count => scalar( @$pos ),
            participant_count => scalar( @$euos ),
            draft_participant_count => scalar( @$dps ),
            begin_date_epoch => $event->begin_date,
            end_date_epoch => $event->end_date,
            begin_date => $dts->[0],
            begin_time_string => $dts->[1],
            begin_time_hours => $hour,
            begin_time_minutes => $min,
            begin_time_ampm => $ampm,
            duration_minutes => $duration_minutes % 60,
            duration_hours => int( $duration_minutes / 60 ),
            gevent_publish_url => $self->_generate_google_event_publish_url($event),
        }
    };
}

sub get_location {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $event = $self->_get_valid_event;

    my $location_data = $event->begin_date ? $self->_get_location_data_for_request : undef;
    # HACK for now only show for netherlands!
    $location_data = undef unless $location_data->{country_name} =~ /netherlands/i;

    my $attached_matchmaking_event_id = $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event );

    if ( my $mm_event_id = $self->_get_note( attached_to_matchmaking_event_id => $event ) ) {
        my $mm_event = $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id );
        $attached_matchmaking_event_id = 0 if $mm_event && $self->_get_note( unlock_location_changing => $mm_event );
    }

    return {
        result => {
            attached_to_matchmaking_event => $attached_matchmaking_event_id ? 1 : 0,
            location => lc( $event->location_name || '' ) eq 'online' ? '' : $event->location_name || '',
            location_string => $self->_meeting_location_string($event),
            geolocation_data => $location_data,
        }
    };
}

sub cancel_meeting {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $meeting = $self->_get_valid_event;
    my $user = CTX->request->auth_user;

    my $user_is_participant = eval { $self->_get_user_meeting_participation_object( $user, $meeting ) };
    return { error => { code => 400, message => 'could not find meeting'} } unless $user_is_participant;

    return { error => { code => 403, message => 'meeting is not cancellable' } } unless $self->_get_note( 'allow_meeting_cancel' => $meeting );

    $self->_cancel_meeting( $meeting, CTX->request->param('message'), $user );

    return {
        result => {
            success => 1
        }
    }
}

sub reschedule_meeting {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $meeting = $self->_get_valid_event;
    my $user = CTX->request->auth_user;

    my $user_is_participant = eval { $self->_get_user_meeting_participation_object( $user, $meeting ) };
    return { error => { code => 400, message => 'could not find meeting'} } unless $user_is_participant;

    return { error => { code => 403, message => 'meeting is not cancellable' } } unless $self->_get_note( 'allow_meeting_cancel' => $meeting );

    $self->_cancel_meeting( $meeting, '', $user );

    my $mmr_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $meeting );
    my $mmr = $self->_ensure_matchmaker_object( $mmr_id );

    my $creator_user = Dicole::Utils::User->ensure_object( $mmr->creator_id );
    my $user_mmr_fragment = $self->_fetch_user_matchmaker_fragment( $creator_user );

    my $url = $self->derive_url(
        action => 'meetings', task => 'meet', target => 0,
        additional => [ $user_mmr_fragment, $mmr->vanity_url_path, 'calendar', 'reschedule', $meeting->id ],
    );

    return {
        result => {
            success => 1,
            redirect_url => $url,
        }
    }
}

sub s2m_query {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;

    my $api_domain = CTX->server_config->{dicole}{s2m_api_domain} || 'http://api.seats2meet.com';
    my $web_domain = CTX->server_config->{dicole}{s2m_web_domain} || 'http://www.seats2meet.com';

    my $term = CTX->request->param('term') || '' ;
    my $latitude = CTX->request->param('latitude');
    my $longitude = CTX->request->param('longitude');

    my $radius = ( $latitude && $longitude ) ? 100 : 0;

    $latitude ||= '0.0';
    $longitude ||= '0.0';

    my $pos = $self->_fetch_meeting_participant_objects( $meeting );
    my $dpos = $self->_fetch_meeting_draft_participation_objects( $meeting );
    my $participant_count = scalar( @$pos ) + scalar( @$dpos );
    $participant_count = 2 if $participant_count < 2;

    my $dates = $meeting->begin_date ? {
        numberOfPeople => $participant_count,
        settingId => 0,
        roomType => 1,
        dateTimeStart => "/Date(" . $meeting->begin_date . "000)/",
        dateTimeEnd => "/Date(" . $meeting->end_date . "000)/",
    } : undef;

    my $query = {
        form => 'json',
        apiKey => '67675858',
        profileKey => '',
        page => 0,
        itemsPerPage => 10,
        profileKey => '',
        page => 0,
        itemsPerPage => 10,
        searchId => 0,
        channelId => 1,
        profileId => 0,
        languageId => 52,
        searchTerm => $term,
        searchType => 1,
        searchLatitude => $latitude,
        searchLongitude => $longitude,
        searchRadius => $radius,
        searchDates => $dates ? Dicole::Utils::JSON->encode( [ $dates ] ) : '',
        searchLocations => '',
        sortSearchOn => 1,
    };

    my $url = URI::URL->new( $api_domain . '/searchWS.asmx/GetAvailableLocations' );
    $url->query_form( $query );

    my $json = Dicole::Utils::HTTP->get( $url->as_string );
    my $data = Dicole::Utils::JSON->decode( $json );

    my $web_query = $self->_form_s2m_web_query( $meeting, CTX->request->auth_user, $participant_count );

    for my $location ( @$data ) {
        my $lquery = { %$web_query, locations => $location->{LocationId} };
        my $web_url = URI::URL->new( $web_domain . '/Wizard' );
        $web_url->query_form( $lquery );

        $location->{ReservationUrl} = $web_url->as_string;
    }

    return { result => { location_list => $data, participant_count => $participant_count, timespan_string => $self->_timespan_for_meeting( $meeting, CTX->request->auth_user ) } };

    # http://api-dev.seats2meet.com/searchWS.asmx/GetAvailableLocations?form=json&searchId=0&channelId=1&profileId=0&languageId=52&searchTerm=''&searchType=1&searchLatitude=0.0&searchLongitude=0.0&searchRadius=0&searchDates=[{"dateTimeStart":"/Date(1328357700000)/","dateTimeEnd":"/Date(1328372100000)/","numberOfPeople":1,"settingId":0,"roomType":1}]&searchLocations=''&sortSearchOn=1
}

sub _form_s2m_web_query {
    my ( $self, $meeting, $user, $participant_count ) = @_;

    if ( ! $participant_count ) {
        my $pos = $self->_fetch_meeting_participant_objects( $meeting );
        my $dpos = $self->_fetch_meeting_draft_participation_objects( $meeting );
        $participant_count = scalar( @$pos ) + scalar( @$dpos );
        $participant_count = 2 if $participant_count < 2;
    }

    my $bdt = DateTime->from_epoch( epoch => $meeting->begin_date, time_zone => 'Europe/Amsterdam' );
    my $edt = DateTime->from_epoch( epoch => $meeting->end_date, time_zone => 'Europe/Amsterdam' );
    my $date = $bdt->dmy;
    my $begin_time = $bdt->hour .':'. ($bdt->minute < 30 ? '00' : '30' );
    my $end_time = ( $edt->minute > 30 ? $edt->add( hours => 1 )->hour : $edt->hour ) .':'. ( $edt->minute > 30 ? '00' : $edt->minute > 0 ? '30' : '00' );

    my $merge_key = $self->_create_meeting_partner_merge_verification_checksum_for_user( $meeting, $user );
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $web_query = {
        setSearch => 1,
        searchType => 1,
        date => $date,
        searchTerm => '',
        locations => '',
        rows => Dicole::Utils::JSON->encode( [ join( ";", $participant_count, $begin_time, $end_time ) ] ),
        meetings_merge_key => $merge_key,
        meetings_return_url => $domain_host . $self->derive_url(
            action => 'meetings', task => 'meeting', additional => [ $meeting->id ], params => { set_location => 1 },
        ),
    };

    return $web_query;
}

sub s2m_autocomplete {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;

    my $api_domain = CTX->server_config->{dicole}{s2m_api_domain} || 'http://api.seats2meet.com';
    my $web_domain = CTX->server_config->{dicole}{s2m_web_domain} || 'http://www.seats2meet.com';

    my $term = CTX->request->param('term') || '' ;
    my $latitude = CTX->request->param('latitude');
    my $longitude = CTX->request->param('longitude');

    my $radius = ( $latitude && $longitude ) ? 100 : 0;

    $latitude ||= '0.0';
    $longitude ||= '0.0';

    my $query = {
        form => 'json',
        channelId => 1,
        languageId => 65,
        searchTerm => $term,
        latitude => $latitude,
        longitude => $longitude,
        radius => $radius,
    };

    my $url = URI::URL->new( $api_domain . '/LocationWS.asmx/AutoCompleteLocationCity' );
    $url->query_form( $query );

    my $json = Dicole::Utils::HTTP->get( $url->as_string );
    my $data = Dicole::Utils::JSON->decode( $json );

    my $web_query = $self->_form_s2m_web_query( $meeting, CTX->request->auth_user );

    for my $location ( @$data ) {
        my $lquery = { %$web_query, searchTerm => $location->{Name} };
        my $web_url = URI::URL->new( $web_domain . '/Wizard' );
        $web_url->query_form( $lquery );

        $location->{ReservationUrl} = $web_url->as_string;
    }

    return $data;

#    http://api-dev.seats2meet.com/LocationWS.asmx/AutoCompleteLocationCity?form=json&searchTerm=utr&channelId=1&languageId=65&latitude=0&longitude=0&radius=0
}

sub password_settings_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $result = {
        password => $self->_get_meeting_join_password( $event ) || '',
    };

    return { result => $result };
}

sub save_password_settings_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    # TODO: security :P
    $self->_set_note_for_meeting( join_password => CTX->request->param('meeting-password'), $event );

    my $result = {
        password => $self->_get_meeting_join_password( $event ) || '',
    };

    return { result => $result };
}


sub email_settings_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $result = {};

#        virtual_conferencing_reminder
    for my $key ( qw(
        start_reminder
        participant_digest
        participant_digest_new_participant
        participant_digest_material
        participant_digest_comments
    ) ) {
        $result->{ $key } = $self->_get_meeting_permission( $event, $key );
    }

    return {
        result => $result
    };
}

sub save_email_settings_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

#        virtual_conferencing_reminder
    for my $key ( qw(
        start_reminder
        participant_digest
        participant_digest_new_participant
        participant_digest_material
        participant_digest_comments
    ) ) {
        $self->_set_meeting_permission( $event, $key, CTX->request->param( $key ) );
    }

    return { result => 1 };
}

sub participant_rights_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $result = {};

    for my $key ( qw(
        invite
        add_material
        edit_material
    ) ) {
        $result->{ $key } = $self->_get_meeting_permission( $event, $key );
    }

    return {
        result => $result
    };
}

sub save_participant_rights_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    for my $key ( qw(
        invite
        add_material
        edit_material
    ) ) {
        $self->_set_meeting_permission( $event, $key, CTX->request->param( $key ) );
    }

    $self->_store_meeting_event( $event, { event_type => 'meetings_participant_rights_changed' } );

    return { result => 1 };
}

sub security_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $result = {};

    for my $key ( qw( force_secure_connections ) ) {
        $result->{ $key } = $self->_get_note_for_meeting( $key, $event ) ? 1 : 0;
    }

    return {
        result => $result
    };
}

sub quickbar {
    my ($self) = @_;

    if ( my $uid = CTX->request->auth_user_id ) {
        return { result => $self->_gather_quickbar_meetings_for_user($uid) };
    }
}

sub add_participants {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $input = CTX->request->param('users');

    my ( $user_id_lookup, $new_address_objects ) = $self->_get_existing_users_for_combined_invite_string( $input, $domain_id );

    my $participants_data = $self->_gather_users_info( [ values %$user_id_lookup ], 36, $domain_id );

    for my $ao ( @$new_address_objects ) {
        my $email = Dicole::Utils::Text->ensure_utf8( $ao->address );

        push @$participants_data, {
            name => Dicole::Utils::Text->ensure_utf8( $ao->phrase ),
            email => $email,
        };
    }

    my $meeting_participant_objects = $self->_fetch_meeting_participant_objects( $meeting );

    if ( $self->_meeting_is_draft( $meeting, $meeting_participant_objects ) ) {
        my %existing_id_lookup = map { $_->{user_id} => 1 } @$meeting_participant_objects;
        # add invited as draft participants unless they exist already
        my @added = ();
        for my $user_data ( @$participants_data ) {
            next if $user_data->{user_id} && $existing_id_lookup{ $user_data->{user_id} };
            my $dpo = $self->_add_meeting_draft_participant( $meeting, $user_data, CTX->request->auth_user );
            $self->_store_draft_participant_event( $meeting, $dpo, 'created' );
            push @added, $user_data->{name} || $user_data->{email};
        }

        return { result => {
            meeting_is_a_draft => 1,
            draft_participants_added => join( ", ", @added),
        } };
    }
    else {
        return {
            result => {
                users => CTX->request->param('users'),
                %{ $self->_determine_invite_default_parameters( $meeting ) },
                new_participants => $participants_data,
                meeting_time => $meeting->begin_date ? $self->_form_timespan_string_from_epochs( $meeting->begin_date, $meeting->end_date, CTX->request->auth_user ) : '',
                meeting_location => $meeting->location_name || '',
                meeting_location_string => $self->_meeting_location_string( $meeting ),
                show_rsvp_option => ( $meeting->begin_date < time ) ? 0 : 1,
            }
        };
    }
}

sub draft_ready {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;

    return { result => $self->_gather_customize_invite_result( $meeting ) };
}

sub temp_draft_ready {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $domain_id = $meeting->domain_id;

    my $user = CTX->request->auth_user;

    my $user_info = $self->_gather_user_info( $user, 134 );

    if ( ! $user_info->{email} ) {
        my $list = $self->_fetch_user_verified_email_list( $user, $domain_id );
        $user_info->{email} = shift( @$list ) || '';
    }

    $user_info->{email_verify_required} = 1;

    return { result => $user_info };
}

sub confirm_new_user_meet_me_profile {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $domain_host = $self->_get_host_for_self( 443);

    my $user = CTX->request->auth_user;
    my $email = CTX->request->param('email');
    my $event_id = CTX->request->param('event_id');

    if ( ! $email ) {
        return { error => { message => 'Email is required'} };
    }

    $self->_user_accept_tos( $user, $domain_id );

    $self->_store_user_profile_info_from_request_params( $user, $domain_id );
    my $existing_user = $self->_fetch_user_for_email( $email, $domain_id );

    if ( ! $existing_user ) {
        my $list = $self->_fetch_user_verified_email_list( $user, $domain_id );
        my %va = map { $_ => 1 } @$list;

        if ( $va{ $email } ) {
            $user->email( $email );
            $user->save;

            eval { CTX->lookup_action('meetings_api')->e( check_user_startup_status => {
                user => $user,
                domain_id => $domain_id,
            } ) };

            return { result => { url_after_post => $self->_get_meet_me_congif_abs( $event_id ) } };
        }
        else {
            my $user_email_object = $self->_add_user_email( $user, $domain_id, $email, 0 );

            my $verification = $self->_create_temp_account_email_verification_checksum_for_user( $user_email_object->id, $user );

            my $temp_account_verification_url = $domain_host . $self->derive_url(
                action => 'meetings', task => 'verify_temp_account_email', target => 0,
                additional => [ $user_email_object->id, $user->id, $verification, 0, 0, $event_id ],
                params => { dic => Dicole::Utils::User->permanent_authorization_key( $user ) },
            );

            $user->email( $email );

            $self->_send_partner_themed_mail(
                user => $user,
                domain_id => $domain_id,
                group_id => 0,

                template_key_base => 'meetings_verify_temp_account_email',
                template_params => {
                    user_name => Dicole::Utils::User->name( $user ),
                    verify_url => $temp_account_verification_url,
                },
            );

            $user->email('');
            $user->save;

            return { result => { url_after_post =>
                $self->derive_url( action => 'meetings', task => 'verify_email', target => 0, additional => [], params => { meet_me => 1, email => $email } )
            } };
        }
    }
    else {
        my $verification = $self->_create_temp_account_email_verification_checksum_for_user( $existing_user->id, $user );

        my $temp_account_verification_url = $domain_host . $self->derive_url(
            action => 'meetings', task => 'verify_temp_account_transfer', target => 0,
            additional => [ $existing_user->id, $user->id, $verification, $event_id ],
            params => { dic => Dicole::Utils::User->permanent_authorization_key( $existing_user ) },
        );

        my $meet_me_url = $self->_generate_user_meet_me_url( $user, $domain_id, $domain_host );

        $self->_send_partner_themed_mail(
            user => $existing_user,
            domain_id => $domain_id,
            group_id => 0,

            template_key_base => 'meetings_verify_temp_account_transfer',
            template_params => {
                meet_me_url => $meet_me_url,
                user_name => Dicole::Utils::User->name( $existing_user ),
                transfer_url => $temp_account_verification_url,
            },
        );

        return { result => { url_after_post =>
            $self->derive_url( action => 'meetings', task => 'verify_email', target => 0, additional => [], params => { meet_me => 1, join_accounts => 1, email => $existing_user->email } )
        } };
    }
}

sub confirm_new_user_profile {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $domain_id = $meeting->domain_id;

    my $user = CTX->request->auth_user;
    my $email = CTX->request->param('email');

    if ( ! $email ) {
        return { error => { message => 'Email is required'} };
    }

    $self->_store_user_profile_info_from_request_params( $user, $domain_id );

    my $existing_user = $self->_fetch_user_for_email( $email, $domain_id );

    if ( ! $existing_user ) {
        my $list = $self->_fetch_user_verified_email_list( $user, $domain_id );
        my %va = map { $_ => 1 } @$list;

        if ( $va{ $email } ) {
            $user->email( $email );
            $user->save;

            eval { CTX->lookup_action('meetings_api')->e( check_user_startup_status => {
                user => $user,
                domain_id => $domain_id,
            } ) };

            return { result => { url_after_post =>
                $self->derive_url( params => { send_now => 'all' } )
            } };
        }
        else {
            my $user_email_object = $self->_add_user_email( $user, $domain_id, $email, 0 );

            my $verification = $self->_create_temp_account_email_verification_checksum_for_user( $user_email_object->id, $user );

            my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );
            my $temp_account_verification_url = $domain_host . $self->derive_url(
                action => 'meetings', task => 'verify_temp_account_email', target => 0,
                additional => [ $user_email_object->id, $user->id, $verification, $meeting->id, 'all' ],
                params => { dic => Dicole::Utils::User->permanent_authorization_key( $user ) },
            );

            $user->email( $email );

            $self->_send_partner_themed_mail(
                user => $user,
                domain_id => $meeting->domain_id,
                partner_id => $self->_get_partner_id_for_meeting( $meeting ),
                group_id => 0,

                template_key_base => 'meetings_verify_temp_account_email',
                template_params => {
                    meeting => $meeting->id,
                    user_name => Dicole::Utils::User->name( $user ),
                    verify_url => $temp_account_verification_url,
                },
            );

            $user->email('');
            $user->save;

            return { result => { url_after_post =>
                $self->derive_url( action => 'meetings', task => 'verify_email', target => 0, additional => [], params => { email => $email } )
            } };
        }
    }
    else {
        my $verification = $self->_create_temp_meeting_verification_checksum_for_user( $meeting, $user );

        my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );
        my $temp_meeting_transfer_url = $domain_host . $self->derive_url(
            action => 'meetings', task => 'verify_temp_meeting_transfer', target => 0,
            additional => [ $meeting->id, $user->id, $verification, 'all' ],
            params => { dic => Dicole::Utils::User->permanent_authorization_key( $existing_user ) },
        );

        $self->_send_meeting_user_template_mail( $meeting, $existing_user, 'verify_temp_meeting_transfer', {
            transfer_url => $temp_meeting_transfer_url,
        } );

        return { result => { url_after_post =>
            $self->derive_url( action => 'meetings', task => 'verify_email', target => 0, additional => [], params => { join_accounts => 1, email => $existing_user->email } )
        } };
    }

}

sub _gather_customize_invite_result {
    my ( $self, $meeting, $dps ) = @_;

    $dps ||= $self->_fetch_meeting_draft_participation_objects( $meeting );

    my $participants_data = $self->_gather_meeting_draft_participants_info( $meeting, 36, $dps );

    return {
        %{ $self->_determine_invite_default_parameters( $meeting ) },
        send_now => 1,
        users => join( ",", map { "draft:" . $_->id } @$dps ),
        meeting_location => $meeting->location_name || '',
        meeting_location_string => $self->_meeting_location_string( $meeting ),
        meeting_time => $meeting->begin_date ? $self->_form_timespan_string_from_epochs( $meeting->begin_date, $meeting->end_date, CTX->request->auth_user ) : '',
        new_participants => $participants_data,
        show_rsvp_option => ( $meeting->begin_date && ! $self->_get_note( created_from_matchmaker_id => $meeting ) ) ? 1 : 0,
    };
}

sub _gather_participants_data_for_draft_participations {
    my ( $self, $draft_participations, $domain_id ) = @_;

    my $participants_data = $self->_gather_users_info( [ map { $_->user_id || () } @$draft_participations ], 36, $domain_id );

    for my $o ( map { $_->user_id ? () : $_ } @$draft_participations ) {
        my $data = {};

        for my $attr ( qw(
            first_name
            last_name
            name
            initials
            email
        ) ) {
            $data->{attr} = $self->_get_note( $attr, $o );
        }

        push @$participants_data, $data;
    }

    return $participants_data;
}

sub _get_existing_users_for_combined_invite_string {
    my ( $self, $input, $domain_id ) = @_;

    my $input_data = eval { Dicole::Utils::JSON->decode( $input ) };
    my @input = $@ ? ( split /\s*,\s*/, $input ) : @$input_data;

    my $users_string = join ',', grep { $_ =~ /^\d+$/ } @input;
    my $drafts_string = join ',', grep { $_ =~ /^draft:\d+$/ } @input;
    my $emails = join ',', grep { $_ !~ /^\d+$/ && $_ !~ /^draft:\d+$/ } @input;

    my @user_ids = map { ( $_ =~ /^\d+$/ ) ? $_ : () } ( split /\s*,\s*/, $users_string );

    $drafts_string =~ s/draft://g;
    my @draft_ids = split /,/, $drafts_string;

    my $draft_objects = CTX->lookup_object('meetings_draft_participant')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( id => \@draft_ids ),
    } );

    push @user_ids, map { $_->user_id || () } @$draft_objects;

    my $valid_user_ids = Dicole::Utils::User->filter_list_to_domain_users( \@user_ids, $domain_id );

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => $valid_user_ids ),
    } );

    my %user_id_lookup = map { $_->id => $_ } @$users;
    my %user_email_lookup = map { lc( $_->email ) => $_ } @$users;
    my @new_address_objects = ();

    my $aos = Dicole::Utils::Mail->string_to_address_objects( $emails );
    for my $ao ( @$aos ) {
        my $address = Dicole::Utils::Text->ensure_utf8( $ao->address );

        next unless $address;
        next if $user_email_lookup{ $address };

        my $user = $self->_fetch_user_for_address_object( $ao, $domain_id );
        if ( $user ) {
            $user_id_lookup{ $user->id } = $user;
        }
        else {
            push @new_address_objects, $ao;
        }
    }

    return ( \%user_id_lookup, \@new_address_objects, $draft_objects );
}

sub invite {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    return { error => { code => 42, message => "User is not allowed to invite participants to this meeting" }}
        unless $self->_user_can_invite( undef, $event );

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $gid = $self->param('target_group_id');
    my $auth_user_id = CTX->request->auth_user_id;

    my $input = CTX->request->param('users');

    my ( $user_id_lookup, $new_address_objects, $draft_participation_objects ) = $self->_get_existing_users_for_combined_invite_string( $input, $domain_id );

    for my $ao ( @$new_address_objects ) {
        my $user = $self->_fetch_or_create_user_for_address_object( $ao, $domain_id, { language => $self->language } );
        if ( $user ) {
            $user_id_lookup->{ $user->id } = $user;
        }
    }

    my $user_dpo_lookup = {};
    for my $dpo ( @$draft_participation_objects ) {
        if ( ! $dpo->user_id ) {
            my $email = Dicole::Utils::Mail->form_email_string( $self->_get_note( email => $dpo ), $self->_get_note( name => $dpo ) );
            my $user = $self->_fetch_or_create_user_for_email( $email, $domain_id, { language => $self->language } );
            if ( $user ) {
                $user_id_lookup->{ $user->id } = $user;
                $user_dpo_lookup->{ $user->id } = $dpo;
            }
        }

        $dpo->sent_date( time );
        $self->_store_draft_participant_event( $event, $dpo, 'sent' );
        $dpo->save;
    }

    my $meetme_requester = $self->_get_meeting_matchmaking_requester_user( $event );

    for my $user ( values %$user_id_lookup ) {
        my $po = $self->_add_user_to_meeting( $user, $event, $auth_user_id, 0, { skip_calculate_is_pro => 1 } );

        my $rsvp_required = CTX->request->param('require_rsvp') ? 1 : 0;
        $self->_set_note_for_meeting_user( rsvp_required => $rsvp_required, $event, $po->user_id, $po, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( rsvp_require_sent => time, $event, $po->user_id, $po, { skip_save => 1 } ) if $rsvp_required;
        $self->_set_note_for_meeting_user( rsvp_required_by_user_id => $auth_user_id, $event, $po->user_id, $po, { skip_save => 1 } ) if $rsvp_required;

        if ( my $dpo = $user_dpo_lookup->{ $user->id } ) {
            if ( my $set_value = $self->_get_note( rsvp => $dpo ) ) {
                $self->_set_note_for_meeting_user( rsvp => $set_value, $event, $po->user_id, $po, { skip_save => 1 } );
            }
        }

        $po->save;

        my $from_user_meetme_request = ( $meetme_requester && $meetme_requester->id == $po->user_id ) ? 1 : 0;

        $self->_store_participant_event( $event, $po, 'created', { data => { rsvp_required => $rsvp_required, from_user_meetme_request => $from_user_meetme_request } } );
    }

    my $domain_host = $self->_get_host_for_meeting( $event, 443 );

    my $greeting_message = CTX->request->param('greeting_message');
    my $greeting_subject = CTX->request->param('greeting_subject');

    my $meeting_users = $self->_fetch_meeting_participant_users( $event );
    my $meeting_participants = $self->_gather_meeting_participant_info( $event, $meeting_users );

    my @invited_names = ();

    for my $user ( values %$user_id_lookup ) {
        $self->_send_meeting_invite_mail_to_user(
            user => $user,
            event => $event,
            group_id => $gid,
            domain_id => $domain_id,
            domain_host => $domain_host,
            meeting_participants => $meeting_participants,
            users => $meeting_users,
            greeting_message => $greeting_message,
            greeting_subject => $greeting_subject,
        );

        push @invited_names, Dicole::Utils::User->name( $user );
    }

    if ( $self->_meeting_is_draft( $event ) && $event->begin_date ) {
        $self->_send_meeting_ical_request_mail( $event, CTX->request->auth_user, { type => 'confirm' } );
    }

    my %user_map = map { $_->id => $_ } @$meeting_users;
    $self->_calculate_meeting_is_pro( $event, $user_map{ $event->creator_id } );

    # TODO: when single user inviting before draft exit is added, this might not be set but draft_until_ready might be
    $self->_set_note_for_meeting( draft_ready => time, $event );

    return { result => { success => 1, invited_users_string => join( ", ", @invited_names ) } };
}

sub invite_transfer {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $gid = $self->param('target_group_id');

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $euo = $self->_events_api( get_event_user_object => {
        event => $event,
        user => $user,
    } );

    die "security error" unless $euo;

    my $as_planner = $euo->is_planner;
    my $by_user_id = $euo->creator_id;

    my $email = CTX->request->param('email');
    my $target_user = $self->_fetch_or_create_user_for_email( $email );

    die unless $target_user;

    my @transfer_notes = qw( rsvp require_rsvp rsvp_required_by_user_id disable_emails );
    my %note_values = map { $_ => $self->_get_note_for_meeting_user( $_, $event, $euo->user_id, $euo ) } @transfer_notes;

    # TODO: transfer everything this user has done for this meeting to the anothe
    $self->_store_participant_event( $event, $euo, 'transfer_removed' );
    $self->_remove_user_from_meeting( $user, $event, { skip_calculate_is_pro => 1 } );
    my $po = $self->_add_user_to_meeting( $target_user, $event, $by_user_id, $as_planner );
    $self->_store_participant_event( $event, $po, 'transfer_created' );

    $self->_set_note_for_meeting_user( $_ => $note_values{ $_ }, $event, $po->user_id, $po ) for @transfer_notes;

    $self->_send_meeting_invite_mail_to_user(
        user => $target_user,
        from_user => $by_user_id,
        event => $event,
        domain_id => $domain_id,
        greeting_message => '',
#        greeting_subject => '',
    );

    if ( CTX->request->param('future') ) {
        $self->_add_email_for_user(
            $user->email, $target_user, 1
        );
    }

    return { result => {
        url_after_post => $self->derive_url(
            action => 'meetings_global', task => 'detect', target => 0, additional => [],
        )
    } };
}

sub signup {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = $self->param('target_group_id') || 0;

    unless ( CTX->request->param('tos') ) {
        return { result => { error => "You need to accept the Terms of Service." } };
    }

    my $email = CTX->request->param('email');
    my $old_user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );

    if ( $old_user ) {
        return { result => { url_after_post => $self->derive_url( action => 'meetings', task => 'already_a_user', additional => [], params => { email => $email, signup => 1 } ) } };
    }

    my $user = eval { $self->_fetch_or_create_user_for_email( $email ) };

    return { result => { error => "An error occured. Please check your email address." } } unless $user;

    $self->_user_accept_tos( $user, $domain_id );

    for my $id ( qw( offers info ) ) {
        if ( CTX->request->param( $id ) ) {
            $self->_set_note_for_user( 'emails_requested_for_' . $id, time, $user, $domain_id );
        }
    }

    my $domain_host = $self->_get_host_for_user( $user, $domain_id, 443 );
    $domain_host =~ s/^http:/https:/;

    my $url = $domain_host . $self->derive_url(
        action => 'meetings_global',
        task => 'detect',
        target => 0,
        additional => [],
        params => {
            dic => Dicole::Utils::User->permanent_authorization_key( $user ),
        },
    );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $domain_id,
        partner_id => $self->param('partner_id'),
        group_id => 0,

        template_key_base => 'meetings_account_created',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            login_url => $url,
        },
    );

    return { result => { url_after_post => $self->derive_url( action => 'meetings', task => 'thank_you', additional => [], params => { email => $user->email } ) } };
}

sub invite_beta {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = $self->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $auth_user = CTX->request->auth_user;

    my $invites_left = $self->_count_user_beta_invites( $auth_user );

    my $emails = CTX->request->param('emails');
    my %user_id_lookup = ();

    my $aos = Dicole::Utils::Mail->string_to_address_objects( $emails );
    for my $ao ( @$aos ) {
        next unless $ao->address;

        my $user = $self->_fetch_or_create_user_for_address_object( $ao, $domain_id );
        if ( $user ) {
            $user_id_lookup{ $user->id } = $user;
        }
    }

    my $invited_users = $self->_get_note_for_user( 'meetings_users_invited' );
    $invited_users ||= [];

    for my $user ( values %user_id_lookup ) {
        if ( $invites_left < 1 ) {
            $invites_left = $self->_count_user_beta_invites( $auth_user, $invited_users );
            if ( $invites_left < 1 ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_nmsg('Could not send invite to %1$s. No invites left!', [ Dicole::Utils::User->email_with_name( $user ) ] ) );
                next;
            }
        }

        $self->_send_beta_invite_mail_to_user(
            user => $user,
            from_user => $auth_user,
            domain_id => $domain_id,
            group_id => $group_id,
            greeting_message => CTX->request->param('greeting_message'),
            greeting_subject => CTX->request->param('greeting_subject'),
        );

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('Invite sent to %1$s', [ Dicole::Utils::User->email_with_name( $user ) ] ) );

        my $inviters = $self->_get_note_for_user( meetings_invited_to_beta_by => $user ) || [];
        push @$inviters, $auth_user->id;
        $self->_set_note_for_user( meetings_invited_to_beta_by => $inviters, $user );

        push @$invited_users, $user->id;
        $invites_left--;
    }

    $self->_set_note_for_user( 'meetings_users_invited', $invited_users );

    return { result => { success => 1 } };
}

sub invite_beta_transfer {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    my $email = CTX->request->param('email');
    my $target_user = $self->_fetch_or_create_user_for_email( $email );

    die unless $target_user;

    my $inviter_users = $self->_get_note_for_user( 'meetings_invited_to_beta_by' );
    $self->_set_note_for_user( 'meetings_invited_to_beta_by', [] );

    die "security error" unless $inviter_users && @$inviter_users;

    my $target_inviters = $self->_get_note_for_user( 'meetings_invited_to_beta_by', $target_user ) || [];
    push @$target_inviters, $_ for @$inviter_users;
    $self->_set_note_for_user( 'meetings_invited_to_beta_by', $target_inviters, $target_user );

    my $last_inviter = 0;
    for my $inviter_id ( @$inviter_users ) {
        next unless $inviter_id;

        my $inviter = eval { Dicole::Utils::User->ensure_object( $inviter_id ) };
        next unless $inviter;

        my $invited = $self->_get_note_for_user( 'meetings_users_invited', $inviter );

        push @$invited, $target_user->id;
        $invited = [ map { $_ == $user->id ? () : $_ } @$invited ];

        $self->_set_note_for_user( 'meetings_users_invited', $invited, $inviter );

        $last_inviter = $inviter;
    }

    $self->_send_beta_invite_mail_to_user(
        from_user => ( $last_inviter > 0 ) ? $last_inviter : 0,
        user => $target_user,
        domain_id => $domain_id,
        greeting_message => '',
#        greeting_subject => '',
    );

    if ( CTX->request->param('future') ) {
        $self->_add_email_for_user(
            $user->email, $target_user, 1
        );
    }

    return { result => {
        url_after_post => $self->derive_url(
            action => 'meetings_global', task => 'detect', target => 0, additional => [],
        )
    } };
}

sub send_login_email {
    my ( $self ) = @_;

    my $email = CTX->request->param('email');

    $email and $email =~ m'@' or return { result => { failure => $self->_nmsg("Please enter a valid email address.") } };

    # TODO: we shuold strip out utm_ params that will be added to the link if they exist..
    # OR then we should add them here for front page login IF they don't exist and strip the
    # adding from the login email..

    eval {
        $self->_send_login_email(
            email => $email,
            url   => CTX->request->param('url_after_login')
        );
    };

    if ($@) {
        return { result => { failure => $self->_nmsg("We do not have a user with email %1\$s.",[$email]) } };
    }

    return { result => { success => $email } };
}

sub send_facebook_login_email {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $email = CTX->request->param('email');
    my $user = $self->_fetch_or_create_user_for_email( $email );

    if ( $user ) {
        my $url_after_action = CTX->request->param('url_after_action');

        my $url = $self->_get_host_for_user( $user, $domain_id, 443 ) . $self->derive_url(
            action => 'meetings_global', task => 'verify_facebook',
            target => 0, additional => [],
            params => {
                facebook_user_id => CTX->request->param('facebook_user_id'),
                url_after_action => $url_after_action,
                dic => Dicole::Utils::User->permanent_authorization_key( $user ),
            },
        );

        $self->_send_partner_themed_mail(
            user => $user,
            domain_id => $domain_id,
            partner_id => $self->param('partner_id'),
            group_id => $self->param('target_group_id'),

            template_key_base => 'meetings_verify_facebook_email',
            template_params => {
                new_user => $self->_user_is_new_user( $user, $domain_id ),
                user_name => Dicole::Utils::User->name( $user ),
                authorize_url => $url,
            },
        );
    }

    return { result => { success => $user->email } };
}

sub send_google_login_email {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $email = CTX->request->param('email');
    my $user = $self->_fetch_or_create_user_for_email( $email );

    if ( $user ) {
        my $id = CTX->request->param('service_user_id');
        my $request_token = CTX->request->param('state');
        my $url_after_action = CTX->request->param('url_after_action');

        $self->_set_note_for_user( "meetings_temp_google_request_token_for_$id", $request_token, $user, $domain_id ) if $request_token;

        my $url = $self->_get_host_for_user( $user, $domain_id, 443 ) . $self->derive_url(
            action => 'meetings_global', task => 'verify_google',
            target => 0, additional => [],
            params => {
                google_user_id => $id,
                url_after_action => $url_after_action,
                dic => Dicole::Utils::User->permanent_authorization_key( $user ),
            },
        );

        $self->_send_partner_themed_mail(
            user => $user,
            domain_id => $domain_id,
            partner_id => $self->param('partner_id'),
            group_id => $self->param('target_group_id'),

            template_key_base => 'meetings_verify_google_email',
            template_params => {
                new_user => $self->_user_is_new_user( $user, $domain_id ),
                user_name => Dicole::Utils::User->name( $user ),
                authorize_url => $url,
            },
        );
    }

    return { result => { success => $user->email } };
}

sub start_wiki_edit {
    my ( $self ) = @_;

    my $page = $self->_get_valid_wiki( undef, undef, CTX->request->auth_user );

    return CTX->lookup_action('wiki_api')->e( start_raw_edit => { editing_user => CTX->request->auth_user, page => $page } );
}
sub continue_wiki_edit {
    my ( $self ) = @_;

    my $page = $self->_get_valid_wiki( undef, undef, CTX->request->auth_user );

    return CTX->lookup_action('wiki_api')->e( start_raw_edit => { editing_user => CTX->request->auth_user, page => $page, continue_edit => 1 } );
}

sub store_wiki_edit {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $page = $self->_get_valid_wiki( $self, $event, CTX->request->auth_user );

    my $return = CTX->lookup_action('wiki_api')->e( store_raw_edit => { editing_user => CTX->request->auth_user, page => $page, new_html => CTX->request->param('html'), old_html => CTX->request->param('old_html'), lock_id => CTX->request->param('lock_id'), target_group_id => $page->groups_id } );

    $self->_store_material_event( $event, $page, 'edited' ) if $return->{result}->{success};

    return $return;
}

sub cancel_wiki_edit {
    my ( $self ) = @_;

    my $page = $self->_get_valid_wiki( undef, undef, CTX->request->auth_user );

    return CTX->lookup_action('wiki_api')->e( cancel_raw_edit => { editing_user => CTX->request->auth_user, page => $page, lock_id => CTX->request->param('lock_id'), } );
}

sub ensure_wiki_lock {
    my ( $self ) = @_;

    my $page = $self->_get_valid_wiki( undef, undef, CTX->request->auth_user );

    return CTX->lookup_action('wiki_api')->e( renew_full_lock => { editing_user => CTX->request->auth_user, page => $page, lock_id => CTX->request->param('lock_id'), autosave_content => CTX->request->param('autosave_content'), } );
}

sub get_wiki_page_autosave_content {
    my ($self) = @_;

    my $material_id = CTX->request->param('material_id')
        or return { error => { message => "material_id required" } };

    my $lock = CTX->lookup_action('wiki_api')->e(get_full_lock => { page_id => $material_id });

    return { error => { message => "not locked" } } unless $lock && $lock->{lock_id};

    return { result => { autosave_content => $lock->{autosave_content} } };
}

sub add_material_wiki {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;

    my $page = CTX->lookup_action('wiki_api')->e( create_page => {
        group_id => $self->param('target_group_id'),

        readable_title => CTX->request->param('title'),
        suffix_tag => $event->sos_med_tag,

        content => '',
        prefilled_tags => $event->sos_med_tag,

        skip_starting_page_proposal => 1,
    } ) or die;

    $self->_store_material_event( $event, $page, 'created' );

    return { result => {
        success => 1,
        set_selected_material_url => $self->derive_url(
            action => 'meetings_json',
            task => 'wiki_object_info',
            additional => [ $event->id, $page->id ],
        ),
    } };
}

sub add_material_from_draft {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid && $self->_fetch_meeting_participant_object_for_user( $event, $uid );

    my $prese = $self->_add_material_to_meeting_from_draft( $event, CTX->request->param('draft_id'), $uid );

    return { result => {
        success => 1,
        set_selected_material_url => $self->derive_url(
            action => 'meetings_json',
            task => 'prese_object_info',
            additional => [ $event->id, $prese->id ],
        ),
    } };
}

sub add_material_embed {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid && $self->_fetch_meeting_participant_object_for_user( $event, $uid );

    my $title = CTX->request->param('title');
    my $embed = CTX->request->param('embed');

    my $prese = CTX->lookup_action('presentations_api')->e( create => {
        domain_id => $domain_id,
        group_id => $gid,
        creator_id => $uid,
        title => $title,
        embed => $embed,
        tags => [ $event->sos_med_tag ],
    } );

    $self->_store_material_event( $event, $prese, 'created' );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('%1$s added successfully', [ $title ] ) );

    return { result => {
        success => 1,
        set_selected_material_url => $self->derive_url(
            action => 'meetings_json',
            task => 'prese_object_info',
            additional => [ $event->id, $prese->id ],
        ),
    } };
}

sub add_material_previous {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid && $self->_fetch_meeting_participant_object_for_user( $event, $uid );

    my ( $last_prese, $last_page );

    my @info = split /\s*\,\s*/, CTX->request->param('materials_list');

    for my $info ( @info ) {
        my ( $from_event_id, $type, $material_id ) = split /\s*\:\s*/, $info;
        my $from_event = CTX->lookup_object('events_event')->fetch( $from_event_id );

        die "security error" unless $from_event && $self->_events_api( current_user_can_see_event => { event => $from_event } );

        if ( lc ( $type ) eq 'page' ) {
            my $from_page = CTX->lookup_object('wiki_page')->fetch( $material_id );

            # TODO: check that the material actually belongs to the event ;)
            my ( $readable_title ) = $from_page->readable_title =~ /(.*) \(\#meeting_/;

            my $content = $from_page->last_content_id_wiki_content;
            my $page = CTX->lookup_action('wiki_api')->e( create_page => {
                group_id => $gid,

                readable_title => $readable_title,
                suffix_tag => $event->sos_med_tag,

                content => $content->content,
                prefilled_tags => $event->sos_med_tag,

                skip_starting_page_proposal => 1,
            } );

            if ( $page ) {
                $self->_store_material_event( $event, $page, 'created' );
                $last_prese = undef;
                $last_page = $page;
            }
        }
        elsif ( lc ( $type ) eq 'media' ) {
            my $from_prese = CTX->lookup_object('presentations_prese')->fetch( $material_id );

            # TODO: check that the material actually belongs to the event ;)

            my $aid = $from_prese->attachment_id;
            my $a = $aid ? CTX->lookup_action('attachments_api')->e( get_object => { attachment_id => $aid } ) : undef;
            my $fh = $a ? CTX->lookup_action('attachments_api')->e( filehandle => { attachment => $a } ) : undef;

            my $prese = CTX->lookup_action('presentations_api')->e( create => {
                domain_id => $domain_id,
                group_id => $gid,
                creator_id => $uid,
                title => $from_prese->name,
                attachment_filename => $fh ? $a->filename : undef,
                attachment_filehandle => $fh,
                embed => $from_prese->embed,
                tags => [ $event->sos_med_tag ],
            } );

            if ( $prese ) {
                $self->_store_material_event( $event, $prese, 'created' );
                $last_page = undef;
                $last_prese = $prese;
            }
        }
    }

    return { result => {
        success => 1,
        set_selected_material_url => $last_prese ? $self->derive_url(
            action => 'meetings_json',
            task => 'prese_object_info',
            additional => [ $event->id, $last_prese->id ],
        ) : $last_page ? $self->derive_url(
            action => 'meetings_json',
            task => 'wiki_object_info',
            additional => [ $event->id, $last_page->id ],
        ) : '',
    } };
}

sub make_meeting_secure {
    my ($self) = @_;

    my $meeting = $self->_get_valid_event or return { error => 1 };

    $self->_set_note_for_meeting(secure => 1, $meeting);

    return {
        result => { success => 1 }
    }
}

sub edit_media_embed {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $title = CTX->request->param('title');
    my $embed = CTX->request->param('embed');

    my $prese = CTX->lookup_object('presentations_prese')->fetch( CTX->request->param('prese_id') );

    #die "security error" unless $self->_user_can_manage_meeting_prese( $uid, $event, $prese);
    die "security error" unless $self->_user_can_edit_material( $uid, $event, $prese );

    $prese->embed( $embed );
    $prese->name( $title );
    $prese->save;

    $self->_store_material_event( $event, $prese, 'edited' );

    return { result => { success => 1 } };
}

sub rename_media {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $self->_user_can_edit_material( $uid, $event );

    $self->_rename_meeting_media( $event, CTX->request->param('prese_id'), CTX->request->param('title') );

    return { result => { success => 1 } };
}

sub replace_media {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $prese = CTX->lookup_object('presentations_prese')->fetch( CTX->request->param('prese_id') ) or die;

    die "security error" unless $self->_user_can_manage_meeting_prese( $uid, $event, $prese );

    my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => { draft_id => CTX->request->param('draft_id') } );

    die "security error" unless $a;

    CTX->lookup_action('presentations_api')->e( update_object => {
        prese => $prese,
        attachment => $a,
        updating_user_id => $uid,
        domain_id => $domain_id,
    } );

    $self->_store_material_event( $event, $prese, 'edited' );

    return { result => { success => 1 } };
}

sub remove_media {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $prese = CTX->lookup_object('presentations_prese')->fetch( CTX->request->param('prese_id') ) or die;

    die "security error" unless $self->_user_can_manage_meeting_prese( $uid, $event, $prese );

    $self->_store_material_event( $event, $prese, 'removed' );

    CTX->lookup_action('presentations_api')->e( remove_object => {
        prese_id => CTX->request->param('prese_id'),
        domain_id => $domain_id,
        user_id => $uid,
    } );

    return { result => { success => 1 } };
}

sub remove_page {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $page = CTX->lookup_object('wiki_page')->fetch( CTX->request->param('page_id') ) or die;

    die "security error" unless $self->_user_can_manage_meeting( $uid , $event );

    $self->_store_material_event( $event, $page, 'removed' );

    CTX->lookup_action('wiki_api')->e( remove_page => {
        page_id => CTX->request->param('page_id'),
        domain_id => $domain_id,
        user_id => $uid,
    } );

    return { result => { success => 1 } };
}

sub rename_page {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $self->_user_can_edit_material( $uid, $event );

    $self->_rename_meeting_page( $event, CTX->request->param('page_id'), CTX->request->param('title') );

    return { result => { success => 1 } };
}

sub remove_meeting {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;

    die "security error" unless $self->_user_can_manage_meeting( $uid, $meeting);

    CTX->lookup_action('meetings_api')->e( remove => { meeting => $meeting, user_id => $uid } );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_nmsg('%1$s successfully removed', [ $self->_meeting_title_string( $meeting ) ] ) );

    return { result => {
        url_after_post => $self->derive_url(
            action => 'meetings_global', task => 'detect', target => 0, additional => [],
        )
    } };
}

sub set_date {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user_id, $event);

    my $date_string = CTX->request->param('begin_date');
    my $time_string = $self->_time_string_from_begin_params;

    my $old_info = $self->_gather_meeting_event_info( $event );

    if ( $date_string ) {
        my $epoch = eval { Dicole::Utils::Date->date_and_time_strings_to_epoch( $date_string, $time_string ) };
        if ( $@ ) {
            return { error => { message => $self->_nmsg("We are sorry but the system did not understand the provided date. Please check the date and try again!") } };
        }

        my $duration = CTX->request->param('duration') || ( CTX->request->param('duration_hours') * 60 + CTX->request->param('duration_minutes') );

        my $end = $epoch + ( ( $duration || 0 ) * 60 ) ;

        my $express_set = $self->_get_note_for_meeting( express_manager_set_date => $event );

        if ( $epoch != $event->begin_date || $end != $event->end_date ) {
            if ( ! $express_set && ! CTX->request->param('require_rsvp_asked') && ! $self->_meeting_is_draft( $event ) ) {
                return { result => { ask_require_rsvp => 1 } };
            }
            else {
                my $require_rsvp_again = ( CTX->request->param('require_rsvp_asked') && CTX->request->param('require_rsvp') ) ? 1 : 0;

                $self->_set_date_for_meeting( $event, $epoch, $end, { skip_event => 1, require_rsvp_again => $require_rsvp_again } );
            }
        }
    }
    else {
        $self->_set_date_for_meeting( $event, 0, 0, { skip_event => 1 } );
    }

    $event->save;

    my $new_info = $self->_gather_meeting_event_info( $event );

    $self->_store_meeting_event( $event, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return { result => { success => 1 } };
}

sub set_location {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user_id, $event);

    my $old_info = $self->_gather_meeting_event_info( $event );

    $event->location_name( CTX->request->param('location') );

    if ( CTX->request->param('clear_conferencing_option') ) {
        $self->_set_note_for_meeting( online_conferencing_option => '' => $event, { no_save => 1 } );
    }

    $event->save;

    my $new_info = $self->_gather_meeting_event_info( $event );

    $self->_store_meeting_event( $event, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return { result => { success => 1 } };
}


sub set_title {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user_id, $event);

    my $old_info = $self->_gather_meeting_event_info( $event );

    $event->title( CTX->request->param('title') );
    $event->save;

    my $new_info = $self->_gather_meeting_event_info( $event );

    $self->_store_meeting_event( $event, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return { result => { success => 1 } };
}

sub set_meeting_helpers_shown {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user_id, $event);

    $self->_set_note_for_meeting( meeting_helpers_shown => 1, $event );

    return { result => { success => 1 } };
}

sub manage_virtual {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    $event->stream( CTX->request->param('stream_html') );
    $event->show_stream( CTX->request->param('stream_visible') ? $self->SHOW_ALL : $self->SHOW_NONE );

    $event->save;

    return { result => { success => 1 } };
}

sub conferencing_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $params = {};

    for my $notification ( keys %{ $self->NOTIFICATION_MAP } ) {
        $params->{ $notification . '_requested' } = $self->_notification_requested_for_user( $notification, CTX->request->auth_user ) ? 1 : 0;
    }

    $params->{selected_option} = $self->_get_note_for_meeting( online_conferencing_option => $event );

    my $skype_account = $self->_get_note_for_meeting( skype_account => $event );
    my $user_info = CTX->request->auth_user_id ? $self->_gather_user_info( CTX->request->auth_user, -1 ) : {};

    $params->{prefill_skype} = $skype_account || $user_info->{skype} || '';
    if ( my $data = $self->_get_note_for_meeting( online_conferencing_data => $event ) ) {
        $params->{prefill_teleconf_number} = $data->{teleconf_number};
        $params->{prefill_teleconf_pin} = $data->{teleconf_pin};
    }

    return { result => $params };
}

sub save_conferencing_data {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    $self->_set_note_for_meeting( online_conferencing_option => CTX->request->param('choose_option') => $event, { skip_save => 1} );
    $event->location_name('Online') if CTX->request->param('clear_location');
    $event->save;

    return { result => { selected_option => $self->_get_note_for_meeting( online_conferencing_option => $event ) } };
}

sub get_virtual {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    return {
        result => {
            stream_html => $event->stream,
            stream_visible => $event->show_stream == $self->SHOW_ALL ? 1 : 0,
        }
    };
}

sub get_scheduling_info {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    if ( $event->begin_date ) {
        return { result => {} };
    }

    my $uid = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    die "security error" unless $user;

    my $euos = $self->_fetch_meeting_participant_objects( $event );
    my $dpos = $self->_fetch_meeting_draft_participation_objects( $event );
    my $pos = $self->_fetch_meeting_proposals( $event );

    my $auth_euo = $self->_fetch_meeting_participant_object_for_user( $event, $uid, $euos );
    my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $event, $uid, $auth_euo, $pos );

    my $is_admin = $self->_user_can_manage_meeting( $user, $event );

    my $unanswered_data = {};
    my $answer_data = {};

    for my $euo ( @$euos ) {
        for my $po ( @$pos ) {
            my $answer = $self->_get_note_for_meeting_user(
                'answered_proposal_' . $po->id, $event, $euo->user_id, $euo
            );

            if ( $answer ) {
                $answer_data->{ $euo->user_id }->{ $po->id } = $answer;
            }
            else {
                $unanswered_data->{ $euo->user_id }->{ $po->id } = 1;
            }
        }
    }

    my $users = $self->_fetch_meeting_participant_users( $event, $euos );

    my ( $timezone_choices, $timezone_data ) = $self->_sorted_timezone_choices_and_data;

    my $user_can_invite = $self->_user_can_invite( $user, $event );

    my $real_participants_info = [];
    my $draft_participants_info = [];
    push @$real_participants_info, map { $self->_get_participant_info( $_ ) } @$users;
    push @$draft_participants_info, map { $self->_get_draft_participant_info( $_ ) } @$dpos;
    my $participants_info = [ @$real_participants_info, @$draft_participants_info ];

    return {
        result => {
            show_scheduling => 1,
            proposals => [ map { $self->_get_proposal_info( $_, $user ) } ( sort { $a->begin_date <=> $b->begin_date } @$pos ) ],
            open_proposals => [ map { $self->_get_proposal_info( $_, $user ) } ( sort { $a->begin_date <=> $b->begin_date } @$open_pos ) ],
            participants => $participants_info,
            real_participants_count => scalar( @$real_participants_info ),
            draft_participants_count => scalar( @$draft_participants_info ),
            current_user_id => CTX->request->auth_user_id,
            answer_data => $answer_data,
            unanswered_count => scalar( @$dpos ) + scalar( keys( %$unanswered_data ) ),
            user_is_admin => $is_admin,
            event_title => $self->_meeting_title_string( $event ),
            get_basic_url => $self->derive_url( task => 'get_basic' ),
            get_location_url => $self->derive_url( task => 'get_location' ),
            invite_participants_data_url => $user_can_invite ? $self->derive_url( task => 'invite_participants_data' ) : '',
            timezone_choices => $timezone_choices,
            timezone_data => $timezone_data,
        }
    };
}

sub cancel_scheduling {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $user = CTX->request->auth_user;

    die "security error" unless $user;
    die "security error" unless $self->_user_can_manage_meeting( $user, $event );

    $self->_clear_meeting_proposals( $event );

    # TODO: inform users in some way?

    return { result => 1 }
}

sub save_proposals {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    die "security error" unless $user;

    my $auth_euo = $self->_fetch_meeting_participant_object_for_user( $event, $uid );

    die "security error" unless $auth_euo;
    die "security error" unless $self->_user_can_manage_meeting( $user, $event, $auth_euo );

    my $pos = $self->_fetch_meeting_proposals( $event );

    my $proposal_data = eval { Dicole::Utils::JSON->decode( CTX->request->param('proposal_data') ) } || [];

    die "parse error" if $@;

    my $proposal_lookup = eval { return { map { $_->{id} => 1 } @$proposal_data } };

    die "parse error" if $@;

    my $valid_po_count = 0;
    for my $po ( @$pos ) {
        if ( ! $proposal_lookup->{ $po->id } ) {
            $self->_remove_meeting_proposed_date( $event, $po );
        }
        else {
            $proposal_lookup->{ $po->id } = 0;
            $valid_po_count++;
        }
    }

    my $new_po_list = [];
    for my $proposal_hash ( @$proposal_data ) {
        next unless $proposal_hash->{id};

        my ( $begin_epoch, $end_epoch ) = $self->_parse_proposal_hash( $proposal_hash );
        if ( $begin_epoch ) {
            if ( $valid_po_count < 8 ) {
                my $po = $self->_add_meeting_proposed_date( $event, $begin_epoch, $end_epoch, $uid, $auth_euo );
                push @$new_po_list, $po;
                $valid_po_count++;
            }
            else {
                # TODO: add error to be returned
            }
        }
        else {
            # TODO: add error to be returned
        }
    }

    my @informed_users = ();

    if ( @$new_po_list ) {
        my $users = $self->_fetch_meeting_participant_users( $event );
        my $euos = $self->_fetch_meeting_participant_objects( $event );
        my $euo_lookup = { map { $_->user_id => $_ } @$euos };
        my $current_po_list = $self->_fetch_meeting_proposals( $event );

        for my $u ( @$users ) {
            next if $u->id == $uid;
            $self->_inform_meeting_user_of_new_proposals( $event, $u, $euo_lookup->{ $u->id }, $new_po_list, $current_po_list );
            push @informed_users, Dicole::Utils::User->name( $u );
        }
    }

    if ( $event->begin_date || $event->end_date ) {
        $self->_set_date_for_meeting( $event, 0, 0, { skip_proposal_clearing => 1 } );
    }

    return { result => {
        informed_users => \@informed_users,
    } };
}

sub _inform_meeting_user_of_new_proposals {
    my ( $self, $meeting, $user, $euo, $new_po_list, $current_po_list, $users ) = @_;

    my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $meeting, $user, $euo, $current_po_list );
    my $open_timespans = [ map { { timestring => $self->_timespan_for_proposal( $_, $user ) } } @$open_pos ];
    my $new_timespans = [ map { { timestring => $self->_timespan_for_proposal( $_, $user ) } } @$new_po_list ];

    $self->_send_meeting_user_template_mail( $meeting, $user, 'scheduling_changed', {
        open_scheduling_options => $open_timespans,
        new_scheduling_options => $new_timespans,
    } );

    $self->_set_note_for_meeting_user( 'scheduling_reminder_sent' => time, $meeting, $user, $euo );
}

sub answer_proposals {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->param('user_id');
    my $user = Dicole::Utils::User->ensure_object( $uid );

    die "security error" unless $user;

    my $euos = $self->_fetch_meeting_participant_objects( $event );
    my ( $auth_euo ) = grep { $_->user_id == $uid } @$euos;

    die "security error" unless $auth_euo;
    die "security error" unless $uid == CTX->request->auth_user_id || $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    my $pos = $self->_fetch_meeting_proposals( $event );

    my $proposal_answers = {};

    for my $proposal ( @$pos ) {
        if ( my $answer = CTX->request->param( 'proposal_' . $proposal->id ) ) {
            $proposal_answers->{ $proposal->id } = $answer;
        }
    }

    my $success = $self->_answer_meeting_proposals_for_user( $event, $proposal_answers, $user, {
            pos => $pos,
            euos => $euos,
        } );

    return { result => {} };
}

sub choose_proposal {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $uid = CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;

    die "security error" unless $user;

    my $auth_euo = $self->_fetch_meeting_participant_object_for_user( $event, $uid );

    die "security error" unless $auth_euo;
    die "security error" unless $self->_user_can_manage_meeting( $user, $event, $auth_euo );

    my $success = $self->_choose_proposal_for_meeting( $event, CTX->request->param('proposal_id'), {
            require_rsvp => CTX->request->param('require_rsvp'),
        } );

    return { result => {
            success => 1,
            is_draft => $self->_meeting_is_draft( $event ) ? 1 : 0,
            require_rsvp => CTX->request->param('require_rsvp'),
        } } if $success;

    return { error => "could not find proposal" };
}

sub check_proposals {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    my $user = CTX->request->auth_user;

    my $return = { visible_proposals => [], invalid_proposals => {} };

    my $proposal_data = eval { Dicole::Utils::JSON->decode( CTX->request->param('proposal_data') ) };

    die "parse error" if $@;

    my $pos = $self->_fetch_meeting_proposals( $event );
    my $po_lookup = { map { $_->id => $_ } @$pos };
    my $found_pos = {};

    my $added_dates = {};

    my $valid_po_count = 0;
    for my $proposal_hash ( @$proposal_data ) {
        if ( my $po = $po_lookup->{ $proposal_hash->{id} } ) {
            my $date_stamp = join( ":", $po->begin_date, $po->end_date );
            if ( $added_dates->{ $date_stamp } ) {
                $return->{invalid_proposals}->{ $proposal_hash->{id} } = $self->_nmsg('Date already exists');
            }
            elsif ( $valid_po_count >= 8 ) {
                $return->{invalid_proposals}->{ $proposal_hash->{id} } = $self->_nmsg('Too many proposals');
            }
            else {
                push @{ $return->{visible_proposals} }, { state => 'old', %{ $self->_get_proposal_info( $po, $user ) } };
                $valid_po_count++;
                $added_dates->{ $date_stamp } = 1;
                $found_pos->{ $po->id } = 1;
            }
            next;
        }
        my ( $begin_epoch, $end_epoch ) = $self->_parse_proposal_hash( $proposal_hash );
        if ( $begin_epoch ) {
            my $date_stamp = join( ":", $begin_epoch, $end_epoch );
            if ( $added_dates->{ $date_stamp } ) {
                $return->{invalid_proposals}->{ $proposal_hash->{id} } = $self->_nmsg('Date already exists');
            }
            elsif ( $valid_po_count >= 8 ) {
                $return->{invalid_proposals}->{ $proposal_hash->{id} } = $self->_nmsg('Too many proposals');
            }
            else {
                my $timestring = $self->_form_timespan_string_from_epochs( $begin_epoch, $end_epoch, $user );
                push @{ $return->{visible_proposals} }, { state => 'new', epoch => $begin_epoch, id => $proposal_hash->{id}, "timestring" => $timestring };
                $valid_po_count++;
                $added_dates->{ $date_stamp } = 1;
            }
        }
        else {
            # TODO: different message if this was an existing but removed proposal ( id =~ /^\d+$/ )
            $return->{invalid_proposals}->{ $proposal_hash->{id} } = $self->_nmsg('The date could not be parsed');
        }
    }

    for my $po ( @$pos ) {
        next if $found_pos->{ $po->id };
        push @{ $return->{visible_proposals} }, { state => 'removed', %{ $self->_get_proposal_info( $po, $user ) } };
    }

    $return->{visible_proposals} = [ sort { $a->{epoch} <=> $b->{epoch} }  @{ $return->{visible_proposals} } ];

    return { result => $return };
}

sub _parse_proposal_hash {
    my ( $self, $hash ) = @_;

    my $begin_epoch = eval { Dicole::Utils::Date->date_and_time_strings_to_epoch( $hash->{date}, $hash->{time} ) };
    my $end_epoch = $begin_epoch;

    $end_epoch += eval { ( ( $hash->{duration_minutes} || 0 ) * 60 ) + ( ( $hash->{duration_hours} || 0 ) * 60 * 60 ) };

    return ( $begin_epoch, $end_epoch );
}

sub admin_accounts {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    die "security error" unless $user;

    my $data = {
        facebook_user_id => $user->facebook_user_id || 0,
        #facebook_connected => $self->_get_note_for_user( 'meetings_facebook_access_token', CTX->request->auth_user ) ? 1 : 0,
        #facebook_start_url => $self->derive_url( action => 'meetings_global', task => 'facebook_start', target => 0, additional => [], params => { return_url => CTX->request->param('return_url') }  ),
        linkedin_connected => $self->_get_note_for_user( 'meetings_linkedin_access_token', CTX->request->auth_user ) ? 1 : 0,
        linkedin_start_url => $self->derive_url( action => 'meetings_global', task => 'linkedin_start', target => 0, additional => [], params => { return_url => CTX->request->param('return_url') }  ),
        google_connected => $self->_user_has_connected_google( CTX->request->auth_user ) ? 1 : 0,
        google_start_url => $self->derive_url( action => 'meetings_global', task => 'google_start_2', target => 0, additional => [], params => { return_url => CTX->request->param('return_url'), require_refresh_token => 1 }  ),
    };

    return { result => $data };
}

sub disconnect_facebook {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    die "security error" unless $user;

    $self->_set_note_for_user( 'meetings_facebook_request_token', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_facebook_request_token_secret', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_facebook_access_token', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_facebook_access_token_secret', '', $user );

    return { result => { success => 1 } }

}

sub disconnect_linkedin {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    die "security error" unless $user;

    $self->_set_note_for_user( 'meetings_linkedin_request_token', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_linkedin_request_token_secret', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_linkedin_access_token', '', $user, undef, 'no_save' );
    $self->_set_note_for_user( 'meetings_linkedin_access_token_secret', '', $user );

    return { result => { success => 1 } }
}

sub disconnect_google {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "security error" unless $user;

    $self->_clear_user_google_tokens( $user, $domain_id );

    return { result => { success => 1 } }
}

sub admin_facebook {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $user = Dicole::Utils::User->ensure_object( $uid );

    die "security error" unless $user;

    $user->facebook_user_id( CTX->request->param('facebook_user_id') || 0 );
    $user->save;

    my $session = CTX->request->session;
    $session->{_oi_cache}{user_refresh_on} = time;

    return { result => { success => 1 } };
}

sub admin_password {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $user = Dicole::Utils::User->ensure_object( $uid );

    die "security error" unless $user;

#    $self->_verify_user_csrf();

    if ( my $password = CTX->request->param('password') ) {
        my $password_pair = CTX->lookup_action('user_manager_api')->e( create_plaintext_and_crypted_password => {
            password => $password
        } );
        $user->password( $password_pair->[1] );
    }

    $user->save;

    my $session = CTX->request->session;
    $session->{_oi_cache}{user_refresh_on} = time;

    return { result => { success => 1 } };
}


sub language_data {
    my ( $self ) = @_;

    return { result => {
        language => CTX->request->auth_user->language,
    } };
}

sub admin_language {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $user = CTX->request->auth_user;

#    $self->_verify_user_csrf();

    if ( my $language = CTX->request->param('language') ) {
        $user->language( $language );
    }

    $user->save;

    my $session = CTX->request->session;
    $session->{_oi_cache}{user_refresh_on} = time;

    return { result => { success => 1 } };
}


sub _verify_user_csrf {
    my ( $self, $csrf ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $candidate = CTX->request->param('csrf');
    my $checksum = $self->_produce_user_csrf_checksum( CTX->request->auth_user_id );

    die "security error" unless $candidate eq $checksum;
}

sub get_my_profile {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    return {
        result => $self->_gather_user_info( $uid, 134 ),
    };
}

sub edit_my_profile {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    if ( CTX->request->param('save_empty_values') ) {
        $self->_store_user_profile_info_from_request_params( $user, $domain_id );
    }
    else {
        $self->_add_user_profile_info_from_request_params( $user, $domain_id );
    }

    $self->_user_accept_tos( $user, $domain_id ) if CTX->request->param('accept_tos');

    $self->_set_note_for_user( profile_filled => time(), $user, $domain_id );

    my $url = CTX->request->param('url_after_save');

    return { result => { success => 1, $url ? ( url_after_post => $url ) : () } };
}

sub _store_user_profile_info_from_request_params {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_fill_profile_info_from_params( $user, $domain_id, $self->_profile_params_from_request, 'force' );
}

sub _add_user_profile_info_from_request_params {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_fill_profile_info_from_params( $user, $domain_id, $self->_profile_params_from_request );
}

sub _profile_params_from_request {
    my ( $self ) = @_;

    my $params = {};

    for my $param ( qw( email phone organization organization_title skype linkedin linkedin_default_value first_name last_name timezone time_zone draft_id ) ) {
        $params->{ $param } = CTX->request->param( $param );
    }

    return $params;
}

sub fill_skype {
    my ( $self ) = @_;

    die "security error" unless CTX->request->param('skype') || CTX->request->param('teleconf_number');

    my $uid = CTX->request->auth_user_id;

    die "security error" unless $uid;

    my $event = $self->_get_valid_event;
    $self->_set_note_for_meeting( skype_account => CTX->request->param('skype'), $event ) if CTX->request->param('skype');

    # TODO: alter the dialog to prompt user to store the acount as personal account
    # if user had not a skype account set - this can be detected almost always corerctly
    # by just checking if there is a prefilled skype account provided for the dialog

    if ( CTX->request->param('set_as_personal') ) {
        my $user = Dicole::Utils::User->ensure_object( $uid );
        my $domain_id = Dicole::Utils::Domain->guess_current_id;

        my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            user_id => $user->id,
            domain_id => $domain_id,
            attributes => {
                contact_skype => CTX->request->param('skype'),
            },
        } );
    }

    my $data = $self->_get_note_for_meeting( online_conferencing_data => $event ) || {};

    if ( my $num = CTX->request->param('teleconf_number') ) {
        $data->{teleconf_number} = CTX->request->param('teleconf_number');
        $data->{teleconf_pin} = CTX->request->param('teleconf_pin');

        $self->_set_note_for_meeting( online_conferencing_data => $data, $event );
    }

    if ( my $uri = CTX->request->param('custom_uri') ) {
        $data->{custom_uri} = CTX->request->param('custom_uri');
        $self->_set_note_for_meeting( online_conferencing_data => $data, $event );
    }

    if ( my $uri = CTX->request->param('lync_uri') ) {
        $data->{lync_uri} = CTX->request->param('lync_uri');
        $self->_set_note_for_meeting( online_conferencing_data => $data, $event );
    }

    my $params = {};
    my $skype_account = $self->_get_note_for_meeting( skype_account => $event );
    $params->{skype_account} = $skype_account || '';

    if ( my $data = $self->_get_note_for_meeting( online_conferencing_data => $event ) ) {
        $params->{teleconf_number} = $data->{teleconf_number};
        $params->{teleconf_pin} = $data->{teleconf_pin};
        $params->{custom_uri} = $data->{custom_uri};
        $params->{lync_uri} = $data->{lync_uri};
    }

    return { result => $params };
}

sub user_info {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    my $event = $self->_get_valid_event;
    my $eus = $self->_fetch_meeting_participation_objects( $event );

    my %lookup = map { $_->user_id => $_ } @$eus;
    my $euo = $lookup{ $self->param('user_id') };

    return { error => { message => "User not found" } } unless $euo;

    return { result => {
        meeting_id => $event->id,
        meeting_is_pro => $self->_meeting_is_pro( $event ),
        meeting_is_draft => $self->_meeting_is_draft( $event ),
        managing_allowed => ( $uid == $self->param('user_id') ) ? 0 : $self->_user_can_manage_meeting( $uid, $event, $lookup{ $uid } ),
        is_self => ( $uid == $self->param('user_id') ) ? 1 : 0,
        send_emails => $self->_get_note_for_meeting_user( 'disable_emails', $event, $euo->user_id, $euo ) ? 0 : 1,
        %{ $self->_gather_meeting_user_info( $event, $euo->user_id, 200, $euo ) },
    } };
}

sub draft_participant_info {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    my $event = $self->_get_valid_event;
    my $objects = $self->_fetch_meeting_draft_participation_objects( $event );

    my %lookup = map { $_->id => $_ } @$objects;
    my $object = $lookup{ $self->param('draft_object_id') };

    return { error => { message => "User not found" } } unless $object;

    return { result => {
        meeting_id => $event->id,
        meeting_is_pro => $self->_meeting_is_pro( $event ),
        meeting_is_draft => $self->_meeting_is_draft( $event ),
        managing_allowed => $self->_user_can_manage_meeting( $uid, $event ),
        is_self => 0,
        rsvp => $self->_get_note( 'rsvp', $object ) ? 0 : 1,
        send_emails => $self->_get_note( 'disable_emails', $object ) ? 0 : 1,
        %{ $self->_gather_meeting_draft_participant_info( $event, 200, $object ) },
    } };
}

sub change_send_emails {
    my ( $self ) = @_;
    my $event = $self->_get_valid_event;
    my $eus = $self->_fetch_meeting_participation_objects( $event );
    my %lookup = map { $_->user_id => $_ } @$eus;
    my $rsvp = $lookup{ CTX->request->auth_user_id };

    return { error => { message => "User not found" } } unless $rsvp;

    my $disabled = CTX->request->param('send_emails' ) ? 0 : time();
    $self->_set_note_for_meeting_user( 'disable_emails', $disabled, $event, $rsvp->user_id, $rsvp );

    # if emails are re-enabled, send only events that occur after current time
    $self->_set_note_for_meeting_user( 'digest_sent', time(), $event, $rsvp->user_id, $rsvp ) if ! $disabled;

    return { result => {
        send_emails => $self->_get_note_for_meeting_user( 'disable_emails', $event, $rsvp->user_id, $rsvp ) ? 0 : 1,
    } };
}

sub set_rsvp_status {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless CTX->request->auth_user_id;

    my $user_id = CTX->request->param( 'user_id' ) || $self->param( 'user_id' ) || CTX->request->auth_user_id;

    die "security error" unless $user_id;
    die "security error" unless $user_id == CTX->request->auth_user_id || $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = Dicole::Utils::User->ensure_object( $user_id );
    my $euo = $self->_get_user_meeting_participation_object( $user, $event );

    my $old_rsvp_value = $self->_get_note_for_meeting_user( 'rsvp', $event, $user, $euo ) || '';

    my $value = lc( CTX->request->param('rsvp_status') );
    $value = '' unless grep { $value eq $_ } ( qw( yes no maybe ) );

    if ( $value eq 'yes' && $user_id == CTX->request->auth_user_id && $old_rsvp_value ne 'yes' ) {
        $self->_send_meeting_ical_request_mail( $event, $user, { type => 'rsvp' } );
    }

    $self->_set_note_for_meeting_user( 'rsvp', $value, $event, $user, $euo );

    $self->_store_participant_event( $event, $euo, 'rsvp_changed' );

    return { result => {
        rsvp_status => $value,
    } };
}

sub set_draft_rsvp_status {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    die "security error" unless CTX->request->auth_user_id;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    my $objects = $self->_fetch_meeting_draft_participation_objects( $event );

    my %lookup = map { $_->id => $_ } @$objects;
    my $object = $lookup{ CTX->request->param( 'draft_object_id' ) || $self->param('draft_object_id') };

    return { error => { message => "User not found" } } unless $object;

    my $value = lc( CTX->request->param('rsvp_status') );
    $value = '' unless grep { $value eq $_ } ( qw( yes no maybe ) );

    $self->_set_note( rsvp => $value, $object );

    $self->_store_draft_participant_event( $event, $object, 'rsvp_changed' );

    return { result => {
        rsvp_status => $value,
    } };
}

sub change_manager_status {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless CTX->request->auth_user_id;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    my $eus = $self->_fetch_meeting_participation_objects( $event );
    my %lookup = map { $_->user_id => $_ } @$eus;
    my $rsvp = $lookup{ $self->param('user_id') };

    return { error => { message => "User not found" } } unless $rsvp;

    if ( CTX->request->param('is_manager' ) ) {
        $rsvp->is_planner( 1 );
        $rsvp->save;
    }
    else {
        $rsvp->is_planner( 0 );
        $rsvp->save;
    }

    my $action = $rsvp->is_planner ? 'promoted' : 'demoted';

    $self->_store_participant_event( $event, $rsvp, $action );

    return { result => {
        is_manager => $rsvp->is_planner ? 1 : 0,
    } };
}

sub change_draft_manager_status {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;
    die "security error" unless CTX->request->auth_user_id;
    die "security error" unless $self->_user_can_manage_meeting( CTX->request->auth_user, $event );

    my $objects = $self->_fetch_meeting_draft_participation_objects( $event );

    my %lookup = map { $_->id => $_ } @$objects;
    my $object = $lookup{ $self->param('draft_object_id') };

    return { error => { message => "User not found" } } unless $object;

    my $is_planner = CTX->request->param('is_manager' ) ? 1 : 0;
    $self->_set_note( is_planner => $is_planner, $object );

    my $action = $is_planner ? 'promoted' : 'demoted';

    $self->_store_draft_participant_event( $event, $object, $action );

    return { result => {
        is_manager => $is_planner ? 1 : 0,
    } };
}

sub get_user_meetings {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;

    my $events = $self->_get_user_meetings_in_domain();
    my @meetings = sort { $b->begin_date <=> $a->begin_date } @$events;

    my $meeting_params = [ map { {
        title => $self->_meeting_title_string( $_ ),
        material_url => $self->derive_url( action => 'meetings_json', task => 'meeting_material_data', target => $_->group_id, additional => [ $_->event_id ], ),
        meeting_id => $_->event_id,
        time => $self->_calendar_params_for_epoch( $_->begin_date, $_->end_date, time ),
    } } @meetings ];

    return {
        result => {
            meetings => $meeting_params,
        },
        success => 1,
        meetings => $meeting_params
    };
}

sub admin_invites {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    die "security error" unless $uid;

    my $globals = {
        meetings_invite_beta_url => $self->derive_url( action => 'meetings_json', task => 'invite_beta' ),
        meetings_cancel_invite_url =>  $self->derive_url( action => 'meetings_json', task => 'cancel_invite'),
    };

    my $params = {};

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $auth_user = CTX->request->auth_user;

    my $invited_users = $self->_get_note_for_user( 'meetings_users_invited' ) || [];
    my $invites_left = $self->_count_user_beta_invites( $auth_user, $invited_users );

    my $default_subject = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_beta_invite_subject_template' ),{
            inviting_user_name => Dicole::Utils::User->name( $auth_user ),
        }
    );

    my $default_message = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_beta_invite_default_greeting_text_template' ),{
            inviting_user_name => Dicole::Utils::User->name( $auth_user ),
        }
    );

    my $user_data_list = [];
    my $user_data_added = {};
    for my $id ( reverse @$invited_users ) {
        next if $user_data_added->{$id}++;
        push @$user_data_list, $self->_gather_user_info( $id, 50 );
        last if scalar( @$user_data_list ) == 20;
    }

    $params = {
        %$params,
        invites_left => $invites_left,
        default_subject => $default_subject,
        default_message => $default_message,
        inviting_user_name => Dicole::Utils::User->name( $auth_user ),
        inviting_user_first_name => Dicole::Utils::User->first_name( $auth_user ),
        invited_user_data_list => $user_data_list,
    };

    return {result => $params};
}

sub cancel_invite {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    return "security error" unless $user;

    my $target_user = CTX->request->param('user_id');
    return "parameter error" unless $target_user;

    my $invited = $self->_get_note_for_user( meetings_users_invited => $user ) || [];

    my %invited_map = map { $_ => 1 } @$invited;
    if ( $invited_map{ $target_user } ) {

        my $invited_new;
        my $item;
        foreach $item (@$invited){
            if($item != $target_user){
                push @$invited_new, $item;
            }
        }
        $self->_set_note_for_user( meetings_users_invited => $invited_new, $user );

        my $cancelled = $self->_get_note_for_user( meetings_users_cancelled => $user ) || [];
        push @$cancelled, $target_user;
        $self->_set_note_for_user( meetings_users_cancelled => $cancelled, $user );

        # Remove from user
        #my $inviters = $self->_get_note_for_user( meetings_invited_to_beta_by => $target_user ) || [];
        #if ($user ~~ @$inviters){
        #    pop @$inviters, $user;
        #    $self->_set_note_for_user( meetings_users_invited => $invited, $target_user );
        #}
        return { result => { success => 1 } };
    }
    else{
        return { result => { failure => 1 } };
    }
}

sub resend_invite {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event( $self, CTX->request->param('target_meeting_id') );
    my $eus = $self->_fetch_meeting_participation_objects( $event );
    my %lookup = map { $_->user_id => $_ } @$eus;

    my $user_id = CTX->request->param('user_id');
    my $rsvp = $lookup{ $user_id };
    my $user = Dicole::Utils::User->ensure_object( $user_id );

    return { error => { message => "User not found" } } unless $rsvp && $user;

    $self->_send_meeting_invite_mail_to_user(
        user => $user,
        event => $event,
        greeting_message => '',
    );

    return { result => { success => 1, user_name => Dicole::Utils::User->name( $user ) } };
}

sub remove_self_from_meeting {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user_id;
    return "security error" unless $user;

    $self->param( 'self_user_id', CTX->request->auth_user_id );

    return $self->remove_participant;
}

sub remove_participant {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $removed = '';

    my $user_id = $self->param( 'self_user_id' ) || CTX->request->param('user_id');

    if ( my $draft_object_id = CTX->request->param('draft_object_id') ) {
        my $objects = $self->_fetch_meeting_draft_participation_objects( $event );

        my %lookup = map { $_->id => $_ } @$objects;
        my $object = $lookup{ $draft_object_id };

        return { error => { message => "User not found" } } unless $object;

        $removed = $object->user_id ? Dicole::Utils::User->name( $object->user_id ) : $self->_get_note( name => $object );

        $self->_remove_meeting_draft_participant( $event, $object );
        $self->_store_draft_participant_event( $event, $object, 'removed' );
    }
    elsif ( $user_id ) {
        if ( $event->creator_id == $user_id ) {
            return { error => { message => "Creator can not be removed!" } };
        }

        my $eus = $self->_fetch_meeting_participation_objects( $event );
        my %lookup = map { $_->user_id => $_ } @$eus;

        my $rsvp = $lookup{ $user_id };
        my $user = Dicole::Utils::User->ensure_object( $user_id );

        return { error => { message => "User not found" } } unless $rsvp && $user;
        $removed = Dicole::Utils::User->name( $user );

        $self->_store_participant_event( $event, $rsvp, 'removed' );

        $self->_remove_user_from_meeting( $user, $event );
     }
     else {
        return { error => { message => "User not found" } };
     }

    return { result => { success => 1, user_name => $removed } };
}

sub scheduler_peek {
   my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my @materials = ();

    my $pages = $self->_events_api( gather_pages_data => { event => $event } );
    my $media = $self->_events_api( gather_media_data => { event => $event, limit => 999 } );

    my $material_count = scalar( @$pages ) + scalar( @$media );
    my $comment_count = 0;
    $comment_count += $_->{comment_count} for ( @$pages, @$media );

    return { result => {
        material_count => $material_count,
        comment_count => $comment_count,
    } };
}

sub meeting_material_data {
    my ( $self ) = @_;

    my $uid = CTX->request->auth_user_id;
    my $event = $self->_get_valid_event;

    die "error" unless $uid && $event;
    die "security error" unless $self->_events_api( current_user_can_see_event => { event => $event } );

    return { result => $self->_gather_material_data_params( $event ) };
}

sub request_notification {
    my ( $self ) = @_;

    my $notification = CTX->request->param('notification');
    die "security error" unless $self->NOTIFICATION_MAP->{ $notification };

    $self->_set_note_for_user( 'requested_notification_for_' . $notification, time );

    return { result => 1 };
}

sub dismiss_guide {
    my ( $self ) = @_;

    my $guide = $self->param('guide');
    die "security error" unless $guide;

    $self->_set_note_for_user( 'meetings_' . $guide . '_dismissed', 1 );

    return { result => { success => 1 } };
}

sub dismiss_meeting_message {
    my ( $self ) = @_;

    my $event = $self->_get_valid_event;

    my $message = $self->param('message');
    my $creator_messages = { map { $_ => 1 } @{ $self->CREATOR_GUIDE_ID_LIST } };
    my $user_messages =  { map { $_ => 1 } @{ $self->VISITOR_GUIDE_ID_LIST } };

    my $valid_messages = { %$creator_messages, %$user_messages };

    die "security error" unless $valid_messages->{ $message };

    $self->_set_note_for_meeting_user( $message . '_dismissed', 1, $event, CTX->request->auth_user_id );

    return { result => { success => 1 } };
}

sub accept_matchmaking_request {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;

    $self->_set_note_for_meeting( 'matchmaking_accept_dismissed', time, $meeting );

    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    die "security error" unless $self->_user_can_manage_meeting( $user, $meeting );

#    $self->_send_matchmaking_accept_email( $meeting, $user );

    return { result => { success => 1 } };
}

sub decline_matchmaking_request {
    my ( $self ) = @_;

    my $meeting = $self->_get_valid_event;
    my $message = CTX->request->param('message');
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    die "security error" unless $self->_user_can_manage_meeting( $user, $meeting );

    $self->_send_decline_meeting_email_to_reserving_user( $meeting, $message, $user );

    return $self->remove_meeting;
}

sub email_current_user_login_link {
    my $self = shift;

    get_logger(LOG_APP)->error("Trying to send secure login link");

    $self->_send_secure_login_link(CTX->request->param('url_after_login'));

    return { result => { success => 1 } };

}

sub refresh_facebook_friends {
    my $self = shift;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "security error" unless $user;

    my $friends_list = Dicole::Utils::JSON->decode( CTX->request->param('friends') );
    my $fb_id_list = [ map { $_->{id} } @$friends_list ];

    my $users = CTX->lookup_object('user')->fetch_group({
        where => Dicole::Utils::SQL->column_in( facebook_user_id => $fb_id_list ),
    } );

    $users = Dicole::Utils::User->filter_list_to_domain_users( $users, $domain_id );
    my $friends_in_system = [ map { $_->id } @$users ];

    $self->_set_note_for_user( facebook_friends => Dicole::Utils::JSON->encode( $friends_in_system ), $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( facebook_timestamp => time, $user, $domain_id );

    return { result => 1 };
}

sub go_pro {
    my $self = shift;

    return { result => {
        go_pro => "now"
    } };
}

sub get_linkedin_contacts_for_user {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $response = $self->_li_call_api( $user, $domain_id, 'http://api.linkedin.com/v1/people/~/connections', 'GET' );
    my $xs = new XML::Simple;
    my $result = $xs->XMLin( $response->content );
    return { result => $result };
}

sub get_facebook_contacts_for_user {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $response = $self->_fb_call_api( $user, $domain_id, 'https://graph.facebook.com/me/friends', 'GET' );
    my $xs = new XML::Simple;
    my $result = $xs->XMLin( $response->content );
    return { result => $result };
}

# Get user details from google
sub fetch_user_info_from_google {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $result = $self->_fetch_user_info_from_google( $user, $domain_id );

    return { result => $result };
}

# Get user contacts from google
sub fetch_user_contacts_from_google {
    my ( $self ) = @_;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $result = $self->_fetch_or_cache_user_google_contacts($user, $domain_id);

    return { result => $result };
}

# Get user details from linkedin api
sub fetch_linkedin_user_details {

}

# Get user details from facebook api
sub fetch_facebook_user_details {

}

sub get_gcal_events_for_user {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $result = Dicole::Cache->fetch_or_store(
        'gcal_events_' . $user->id . '_' . $user->timezone,
        sub {
            my $data = $self->_fetch_user_upcoming_primary_events_from_google( $user, $domain_id );

            my $new = [];
            for my $item ( @{ $data->{items} } ) {
                my $start = $item->{start}{dateTime};
                my $end = $item->{end}{dateTime};
                my $start_epoch = eval { Date::Parse::str2time( $start ) };
                if ( $start_epoch ) {
                    next unless $item->{summary};
                    next if $start_epoch < time;
                    my $start_dt = Dicole::Utils::Date->epoch_to_datetime( $start_epoch, $user->timezone, $user->lang );
                    $item->{start_epoch} = $start_epoch;
                    $item->{start_hm} = Dicole::Utils::Date->datetime_to_hour_minute( $start_dt, 'ampm' );

                    my $end_epoch = eval { Date::Parse::str2time( $end ) };
                    if ( $end_epoch ) {
                        my $end_dt = Dicole::Utils::Date->epoch_to_datetime( $end_epoch, $user->timezone, $user->lang );
                        $item->{end_hm} = Dicole::Utils::Date->datetime_to_hour_minute( $end_dt, 'ampm' );
                    }
                    $item->{start_cal} = $self->_calendar_params_for_epoch( $start_epoch, $end_epoch, time, $user->timezone, $user->lang );
                    $item->{duration_minutes} = ( $end_epoch && $end_epoch > $start_epoch ) ? int( ( $end_epoch - $start_epoch ) / 60 ) : 0;

                    push @$new, $item;
                }
            }

            $data->{items} = [ sort { $a->{start_epoch} <=> $b->{start_epoch} } @$new ];
            return $data;
        },
        { no_group_id => 1, domain_id => $domain_id, expires => 60*5, skip_cache => 1 },
    );

    return { result => $result };
}

sub dropbox_data {
    my ( $self ) = @_;

    my $dropbox_connected = $self->_get_note_for_user( 'meetings_dropbox_access_token', CTX->request->auth_user ) ? 1 : 0;
    my $dropbox_start_url = $self->derive_url( action => 'meetings_global', task => 'dropbox_start', target => 0, additional => [] );

    return { result => {
        dropbox_connected => $dropbox_connected,
        dropbox_start_url => $dropbox_start_url,
    } };
}

sub dropbox_disconnect {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    for ( qw(
        meetings_dropbox_access_token
        meetings_dropbox_access_token_secret
        meetings_dropbox_request_token
        meetings_dropbox_request_token_secret
        dropbox_new_folders
        dropbox_removed_folders
        dropbox_sandbox_metadata
        dropbox_sandbox_metadata_updated
        delay_dropbox_sync_until
        meetings_dropbox_last_full_sync
    ) ) {
        $self->_set_note_for_user( $_, undef, $user, $domain_id, { skip_save => 1 } );
    }

    $user->save;

    for my $euo ( @{ $self->_get_user_meeting_participation_objects_in_domain( $user, $domain_id ) } ) {
        $self->_set_note_for_meeting_user( dropbox_synced_as => undef, $euo->event_id, $euo->user_id, $euo );
    }

    return { result => 1 };
}

sub bringio_data {
    my ( $self ) = @_;

    # Return bringio connect url
    return { result => { connect_url => 'bringio url' } };
}

sub appearance_data {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;

    my $preview_urls = {};

    for my $theme ( @{ $self->THEME_NAMES } ) {
        for my $header ( qw( normal inverted ) ) {
            for my $footer ( qw( normal inverted ) ) {
                $preview_urls->{ join('_', $theme, $header, $footer ) } = $self->_generate_theme_css_url( $theme, $header, $footer );
            }
        }
    }


    return { result => {
        themes => $self->THEME_NAMES,
        style_preview_urls => $preview_urls,
        theme => $self->_get_note_for_user( pro_theme => $user ) || 'blue',
        theme_header => $self->_get_note_for_user( pro_theme_header => $user ) || 'normal',
        theme_footer => $self->_get_note_for_user( pro_theme_footer => $user ) || 'normal',
        theme_header_image_url => $self->_get_note_for_user( pro_theme_header_image => $user ) ?
            $self->derive_url( action => 'meetings', task => 'own_theme_header_image', target => 0, additional => [] ) : '',
        theme_background_image_url => $self->_get_note_for_user( pro_theme_background_image => $user ) ?
            $self->derive_url( action => 'meetings', task => 'own_theme_background_image', target => 0, additional => [] ) : '',
        theme_background_color => $self->_get_note_for_user( pro_theme_background_color => $user ) || '',
        theme_background_position => $self->_get_note_for_user( pro_theme_background_position => $user ) || 'horizontal',
    } };
}

sub save_appearance_data {
    my ( $self ) = @_;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    die "security error" if CTX->request->param( 'theme' ) && ! $self->THEME_NAME_MAP->{ CTX->request->param( 'theme' ) };
    die "security error" if CTX->request->param( 'pro_theme_background_position' ) && ! $self->THEME_BACKGROUND_POSITION_MAP->{ CTX->request->param( 'pro_theme_background_position' ) };
    die "security error" if CTX->request->param( 'pro_theme_background_color' ) && ! CTX->request->param( 'pro_theme_background_color' ) =~ /^[\d\w]{6}$/;

    for my $piece ( qw( theme_header theme_footer ) ) {
        my $value = CTX->request->param( $piece );
        die "security error" if $piece && ! $piece =~ /^(normal|inverted)$/;
    }

    for my $piece ( qw( theme theme_header theme_footer theme_background_color theme_background_position ) ) {
        $self->_set_note_for_user( 'pro_' . $piece, CTX->request->param( $piece ), $user, $domain_id, { skip_save => 1 } );
    }

    if ( my $header_draft = CTX->request->param('theme_header_image_draft_id') ) {
        if ( $header_draft =~ /^\d+$/ ) {
            my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $header_draft,
            } );

            CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $user,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

            $self->_set_note_for_user( pro_theme_header_image => $a->id, $user, $domain_id, { skip_save => 1 } )
        }
        else {
            $self->_set_note_for_user( pro_theme_header_image => 0, $user, $domain_id, { skip_save => 1 } )
        }
    }

    if ( my $background_draft = CTX->request->param('theme_background_image_draft_id') ) {
        if ( $background_draft =~ /^\d+$/ ) {
            my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
                draft_id => $background_draft,
            } );

            CTX->lookup_action('attachments_api')->e( reattach => {
                attachment => $a,
                object => $user,
                user_id => 0,
                group_id => 0,
                domain_id => $domain_id,
            } );

            $self->_set_note_for_user( pro_theme_background_image => $a->id, $user, $domain_id, { skip_save => 1 } );
        }
        else {
            $self->_set_note_for_user( pro_theme_background_image => 0, $user, $domain_id, { skip_save => 1 } );
        }
    }

    $user->save;

    return { result => 1 };
}

sub subscription_data {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $urls = {
        change_interval_url       => 'http://www.paypal.com',
        change_payment_method_url => 'http://www.paypal.com',
        unsubscribe_url           => 'http://www.paypal.com',
        view_receipts_url         => 'http://www.paypal.com/history',
    };

    my $user = CTX->request->auth_user_id && CTX->request->auth_user
        or die {
            code => 42,
            message => "No such user"
        };

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $company_subscription = $self->_get_user_current_company_subscription($user, $domain_id);
    my $subscription = $self->_get_user_current_subscription($user, $domain_id);
    my $trial        = $self->_get_user_current_trial($user, $domain_id);

    if (!$subscription and !$trial and !$company_subscription) {
        if ($self->_get_note_for_user(meetings_beta_pro => $user, $domain_id)) {
            return {
                result => {
                    description => "You currently have PRO account sponsored by the Meetin.gs team. We hope you enjoy using it!",
                    has_active_subscription => 1,
                    %$urls
                }
            }
        }
        else {
            return {
                result => {
                    description => "You do not have a subscription."
                }
            }
        }
    }

    if ( $company_subscription ) {
        my $base_url = $self->_get_note(appdirect_base_url => $company_subscription );
        my $partner = $self->_get_note(appdirect_partner => $company_subscription );

        my $who = '';
        my $manage_all_url = $base_url . '/account/users';

        if ( $user->id != $company_subscription->admin_id ) {
            $who = Dicole::Utils::User->name( $company_subscription->admin_id );
            $manage_all_url = '';
        }

        return {
            result => {
                description => "You currently have $partner PRO account" . ( $who ? " bought by " . $who : '' ) . '!',
                manage_all_url => $manage_all_url,
                managed_by_other => $who,
            }
        }
    }

    get_logger(LOG_APP)->debug("User trial: " . $trial);

    my $trial_valid_until = $trial && DateTime->from_epoch(epoch => $trial->start_date)->add(days => $trial->duration_days)->ymd;
    my $trial_description = $trial && "You have an active Meetin.gs Pro trial. Your trial is valid until $trial_valid_until.";

    my $cancelled_subscription_valid_until = $subscription && $self->_get_note(cancelled_timestamp => $subscription)
        && DateTime->from_epoch(epoch => $self->_get_note(valid_until_timestamp => $subscription))->ymd;

    get_logger(LOG_APP)->debug("Trial valid until:        $trial_valid_until");
    get_logger(LOG_APP)->debug("Subscription start date:  " . ($subscription && DateTime->from_epoch(epoch => $subscription->subscription_date)));

    my $subscription_description = do {
        if ($subscription) {
            if ($cancelled_subscription_valid_until) {
                "You have a cancelled Meetin.gs Pro subscription, which is valid until $cancelled_subscription_valid_until."
            } else {
                "You have an active Meetin.gs Pro subscription."
            }
        }
        else {
            ""
        }
    };

    if ($trial and $subscription) {
        $trial_description = "";
    }

    my $transactions = CTX->lookup_object('meetings_paypal_transaction')->fetch_group({
        where => 'user_id = ? and domain_id = ?',
        value => [ $user->id, $domain_id ]
    });

    get_logger(LOG_APP)->debug("User '" . $user->id . "' has " . @$transactions . " transactions");

    my @receipts = map {
        +{
            title => DateTime->from_epoch(epoch => $_->payment_date)->ymd . ' $' . $self->_get_note(amount => $_),
            value => $_->id,
            send_email_url => $self->derive_url(action => 'meetings_paypaljson', task => 'send_receipt', params => { transaction_id => $_->id })
        }
    } reverse sort { $a->payment_date <=> $b->payment_date } @$transactions;

    get_logger(LOG_APP)->debug("Receipts: " . @receipts);

    return {
        result => {
            description             => "$trial_description $subscription_description",
            has_active_subscription => $subscription && !$cancelled_subscription_valid_until,
            has_transactions        => scalar @$transactions,
            receipts                => \@receipts,
            %$urls
        }
    }
}

# Return calendar ics file url
sub calendar_data {
    my ( $self ) = @_;

    return "must be logged in" unless CTX->request->auth_user_id;

    my $key = Dicole::Utils::User->identification_key( CTX->request->auth_user, 0, Dicole::Utils::Domain->guess_current_id );

    my $url = $self->_get_host_for_user( CTX->request->auth_user, undef, 443 ) . $self->derive_url( action => 'meetings_raw', task => 'ics_list', target => 0, additional => [ $key, 'meetings.ics' ] );

    my $regenerate_url = $self->derive_url( action => 'meetings_json', task => 'regenerate_calendar_url', target => 0, additional => [] );

    return { result => { ical_url => $url, regenerate_url => $regenerate_url } };
}

# Regenerate calendar ics file url
sub regenerate_calendar_url {
    my ( $self ) = @_;
    return { result => { ical_url => 'new url' } };
}

sub clear_subscription_status {
    my ($self) = @_;

    return { result => $self->_clear_subscription_status };
}

# Return autocomplete info for requested topic
sub location_autocomplete_data {
    my ($self) = @_;

    my $events = $self->_get_user_meetings_in_domain();

    my $locations = join "^", map( { $_->location_name  } @$events );

    return { result => { data => $locations } };
}

# (re)Build user caches on login
sub ensure_user_caches {
    my ($self) = @_;

    return {} unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;

    Dicole::Utils::Gearman->dispatch_versioned_task( prime_ip_location_data => { ip => $self->_get_ip_for_request } );
    Dicole::Utils::Gearman->dispatch_versioned_task( prime_user_google_contacts => { user_id => $user->id } );
    Dicole::Utils::Gearman->dispatch_versioned_task( prime_calculate_user_analytics => { user_id => $user->id } );

    return { result => 1 };
}

sub test_fg_gearman {
    my ($self) = @_;

    my $result = Dicole::Utils::Gearman->do_task( test_fg_gearman => { parameter => 1 } );
    die unless $result;

    return { result => { success => 1, result => $result } };
}

sub test_bg_gearman {
    my ($self) = @_;

    my $result = Dicole::Utils::Gearman->dispatch_task( test_bg_gearman => { parameter => 1 } );
    die unless $result;

    return { result => { success => 1, result => $result } };
}

sub agent_manage_data {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;
    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $shared_admin_accounts = $self->_get_note_for_user( 'meetings_shared_account_data', $user, $domain_id, { skip_save => 1 } ) || [];

    for my $account_data ( @$shared_admin_accounts ) {
        my $url = Dicole::URL->from_parts(
            action => 'meetings_global',
            task => 'switch_account',
            domain_id => $domain_id,
            params => { account => $account_data->{email} }
        );

        delete $account_data->{email};
        $account_data->{url} = $url;

        my $uid = lc( $account_data->{name} );
        $uid =~ s/[^a-z]//g;
        $uid = int(rand()*100000000) . '-' . $uid;
        $account_data->{safe_uid} = $uid;
    }

    my $shared_admin_accounts_map = { map { $_->{safe_uid} => $_ } @$shared_admin_accounts };

    my $data = {
        shared_accounts => $shared_admin_accounts,
        shared_accounts_map => $shared_admin_accounts_map,
    };

    return { result => $data };
}

sub agent_admin_data {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $partner_id = $partner->id;

    my $selected_area = CTX->request->param('area');
    my $selected_section = CTX->request->param('section') || 'users';

    my $areas = $self->_get_note_for_user( 'meetings_agent_admin_areas' => $user, $domain_id );
    die "security error" unless $areas;

    if ( $areas ne '_all' ) {
        $selected_area = $areas;
    }

    my $all_languages = $self->_get_note( all_languages => $partner );
    my $all_areas = $self->_get_note( all_areas => $partner );
    my $all_meeting_types = $self->_get_note( all_meeting_types => $partner );
    my $all_service_levels = $self->_get_note( all_service_levels => $partner );

    my $all_areas_map = { map { $_->{id} => $_ } @$all_areas };

    my $data = {
        all_sections => [
            { id => 'users', name => 'Käyttäjät' },
            { id => 'offices', name => 'Toimistot' },
            { id => 'calendars', name=> 'Kalenterit' },
            { id => 'settings', name=> 'Asetukset' },
            { id => 'reports', name=> 'Raportit' },
        ],
        all_areas => $all_areas,
        all_languages => $all_languages,
        all_service_levels => $all_service_levels,
        all_meeting_types => $all_meeting_types,

        selected_section => $selected_section,

        areas => $areas,
        selected_area => $selected_area,
        selected_area_name => $selected_area ? $all_areas_map->{ $selected_area }->{name} : '',

        users => undef,
        offices => undef,
        calendars => undef,
        reports => undef,
    };

    if ( ! $selected_area ) {
        return { result => $data };
    }

    if( $selected_section eq 'reports' ) {
        my $area = $all_areas_map->{ $selected_area };
        my @area_params = ( area => $area->{id} );
        my @meeting_area_params = $area->{report_all_meetings} ? () : @area_params;
        my $reports = [];
        my $dt = Dicole::Utils::Date->epoch_to_datetime( time, 'Europe/Helsinki' );
        $dt = Dicole::Utils::Date->datetime_to_month_start_datetime( $dt );
        for (1..24) {
            my $to = $dt->epoch;
            $dt->subtract( months => 1 );
            my $from = $dt->epoch;
            # NOTE: Billing with new model started after this date.
            # NOTE: Older reports also have errors SMS data.
            last if $dt->year eq '2016' && $dt->month eq '10';

            my $month_string = $dt->year . '-' . ( $dt->month < 10 ? '0'.$dt->month : $dt->month );
            push @$reports, {
                name => "Tapaamiset $month_string",
                url => $self->derive_url( action => 'meetings_raw', task => 'lt_export_meeting_data', target => 0, additional => [ 'meetings-' . $selected_area . '-' .$month_string . '.csv'], params => { from => $from, to => $to, @meeting_area_params } ),
            };

            push @$reports, {
                name => "Käyttäjät $month_string",
                url => $self->derive_url( action => 'meetings_raw', task => 'lt_export_user_data', target => 0, additional => [ 'users-' . $selected_area . '-' .$month_string . '.csv'], params => { from => $from, to => $to, @area_params } ),
            };
        }
        $data->{reports} = $reports;
        return { result => $data };
    }

    my $stash = { partner_id => $partner_id, domain_id => $domain_id };
    $self->_fill_agent_object_stash_from_db( $stash, 'pending', $selected_area, { skip_demoify => 1, skip_translations => 1 } );

    for my $key ( qw( users offices calendars settings ) ) {
        $data->{ $key } = [ values %{ $stash->{ $key } } ];
        for my $object ( @{ $data->{ $key } } ) {
            my $uid = lc( $object->{uid} );
            $uid =~ s/[^a-z]//g;
            $uid = int(rand()*100000000) . '-' . $uid;
            $object->{safe_uid} = $uid;
        }
    }

    return { result => $data };
}

sub set_agent_object {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');
    my $partner_id = $partner->id;

    my $data = Dicole::Utils::JSON->decode( CTX->request->param('payload') );

    die "security error" unless $data->{area};

    my $rights = $self->_get_note_for_user( meetings_agent_admin_areas => $user, $domain_id );

    die "security error" unless $rights eq '_all' || $rights eq $data->{area};

    if ( $data->{removed_epoch} ) {
        my $stash = { partner_id => $partner_id, domain_id => $domain_id };
        $self->_fill_agent_object_stash_from_db( $stash, 'pending', $data->{area}, { skip_demoify => 1, skip_translations => 1 } );

        for my $cal ( values %{ $stash->{calendars} } ) {
            next if $cal->{removed_epoch};
            if ( $data->{model} eq 'user' && $cal->{user_email} eq $data->{uid} ) {
                return { error => { message => "Tällä käyttäjällä on vielä aktiivisia kalentereita. Poistaminen epäonnistui." } };
            }
            if ( $data->{model} eq 'office' && $cal->{office_full_name} eq $data->{uid} ) {
                return { error => { message => "Tällä toimistolla on vielä aktiivisia kalentereita. Poistaminen epäonnistui." } };
            }
        }
    }

    my $result = eval {
        return $self->_set_agent_object( $data, $partner_id, $domain_id, $user->id );
    };

    if ( $@ ) {
        return { error => { message => $@ } };
    }
    else {
        return { result => $result };
    }
}

sub agent_absences_data {
    my ($self) = @_;

    die "security error" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $supervised_agents = $self->_get_note_for_user( 'meetings_supervised_agents' => $user, $domain_id );
    my $selected_category = CTX->request->param('category');
    my $fetched_agents = {};

    my $data = { selected_category => $selected_category, agents => [], categories => [] };

    return { result => $data } unless $supervised_agents && @$supervised_agents;

    my $categories = {};

    for my $agent_email ( @$supervised_agents ) {
        my $agent = $fetched_agents->{ $agent_email } ||= $self->_fetch_user_for_email( $agent_email );
        next unless $agent;
        my $category = $self->_get_note_for_user( meetings_absences_category => $agent );
        $categories->{ $category } = 1;
    }

    my $category_list = [ sort keys %$categories ];
    if ( @$category_list > 1 ) {
        $data->{categories} = $category_list;
        return { result => $data } unless $selected_category;
    }

    for my $agent_email ( @$supervised_agents ) {
        my $agent = $fetched_agents->{ $agent_email } ||= $self->_fetch_user_for_email( $agent_email );
        next unless $agent;
        my $category = $self->_get_note_for_user( meetings_absences_category => $agent );
        next if @$category_list > 1 && $selected_category && $selected_category ne $category;

        my $ud = {
            id => $agent->id,
            user_name => Dicole::Utils::User->name( $agent ),
            user_email => $agent->email,
            category => $category,
            absences => [],
        };

        push @{ $data->{agents} }, $ud;

        my $suggestions = $self->_get_upcoming_nonvanished_user_meeting_suggestions( $agent, $domain_id );
        my $meetings = $self->_get_upcoming_user_meetings_in_domain( $agent, $domain_id );

        for my $suggestion ( @$suggestions ) {
            next unless $suggestion->source eq 'absences:absences';
            my $overlapping = [];
            my $absence = {
                begin_epoch => $suggestion->begin_date,
                end_epoch => $suggestion->end_date,
                reason => $suggestion->title,
                id => $suggestion->id,
                overlapping_meetings => $overlapping,
            };

            for my $m ( @$meetings ) {
                next if $suggestion->begin_date > $m->end_date;
                next if $suggestion->end_date < $m->begin_date;
                push @$overlapping, {
                    begin_epoch => $m->begin_date,
                    end_epoch => $m->end_date,
                    title => $m->title,
                    id => $m->id,
                    enter_url => $self->_get_meeting_enter_abs( $m ),
                };
            }

            push @{ $ud->{absences} }, $absence;
        }
    }

    return { result => $data };
}

sub add_agent_absence {
    my ($self) = @_;

    my @param_list = qw/ agent_id first_day last_day reason /;

    my $params = { map { $_ => CTX->request->param( $_ ) } @param_list };

    die "security error" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $supervised_agents = $self->_get_note_for_user( 'meetings_supervised_agents' => $user, $domain_id );

    die "security error" unless $supervised_agents && @$supervised_agents;

    my $begin_date = Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{first_day}, '04:00', $user->time_zone, $user->language );
    my $end_date = Dicole::Utils::Date->date_and_time_strings_to_epoch( $params->{last_day}, '23:59', $user->time_zone, $user->language );


    return { error => { message => 'must begin before ends' } } if $begin_date > $end_date;

    for my $agent_email ( @$supervised_agents ) {
        my $agent = $self->_fetch_user_for_email( $agent_email );

        next unless $agent->id == $params->{agent_id};

        my $suggestion = CTX->lookup_object('meetings_meeting_suggestion')->new( {
            domain_id => $domain_id,
            user_id => $agent->id,
            created_date => time,
            disabled_date => 0,
            vanished_date => 0,
            removed_date => 0,
            begin_date => $begin_date,
            end_date => $end_date,

            title => $params->{reason},
            source => 'absences:absences',
        } );

        $self->_set_note( source_provider_type => 'absences', $suggestion, { skip_save => 1 } );
        $self->_set_note( source_uid => 'absences:absences', $suggestion, { skip_save => 1 } );
        $self->_set_note( source_provider_id => 'absences', $suggestion, { skip_save => 1 } );
        $self->_set_note( absence_creator_user_id => $user->id, $suggestion );

        return { result => { success => 1 } };
    }

    return { error => { message => 'could not find agent' } };
}

sub remove_agent_absence {
    my ($self) = @_;

    my @param_list = qw/ agent_id absence_id /;

    my $params = { map { $_ => CTX->request->param( $_ ) } @param_list };

    die "security error" unless CTX->request->auth_user_id;

    my $user = CTX->request->auth_user;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $supervised_agents = $self->_get_note_for_user( 'meetings_supervised_agents' => $user, $domain_id );

    die "security error" unless $supervised_agents && @$supervised_agents;

    for my $agent_email ( @$supervised_agents ) {
        my $agent = $self->_fetch_user_for_email( $agent_email );

        next unless $agent->id == $params->{agent_id};

        my $suggestion = CTX->lookup_object('meetings_meeting_suggestion')->fetch( $params->{absence_id} );

        die "security error" unless $suggestion && $suggestion->user_id == $agent->id && $suggestion->source eq 'absences:absences';

        $suggestion->removed_date( time );
        $self->_set_note( absence_remover_user_id => $user->id, $suggestion );

        return { result => { success => 1 } };
    }

    return { error => { message => 'could not find agent' } };
}

1;
