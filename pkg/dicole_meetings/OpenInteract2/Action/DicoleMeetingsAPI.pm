package OpenInteract2::Action::DicoleMeetingsAPI;

use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Utils::MIME;
use List::Util;
use XML::Writer;
use Dicole::Utils::Data;
use Dicole::Utils::HTML::Diff;

sub _inform {
    my ( $self, $message, $logs ) = @_;

    print $message . "\n";
    push @$logs, $message if $logs;
}

sub create {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param( 'domain_id' ) );
    my $creator = $self->param('creator') || Dicole::Utils::User->ensure_object( $self->param('creator_id') );
    my $group_id = $self->param('group_id') || $self->_determine_user_base_group( $creator, $domain_id );

    my $begin_epoch = $self->param('begin_epoch');
    my $end_epoch = $self->param('end_epoch');
    $end_epoch ||= $self->param('duration') ? $begin_epoch + ( $self->param('duration') * 60 ) : 0;

    my $event = CTX->lookup_action('events_api')->e( create_event => {
        domain_id => $domain_id,
        group_id => $group_id,
        creator_id => $creator->id,
        title => $self->param('title'),
        location_name => $self->param('location'),
        begin_date => $begin_epoch,
        end_date => $end_epoch,
    } );

    $event->sos_med_tag( 'meeting_' . $event->id );

    my $partner_id = $self->param('partner_id');
    $self->_set_note_for_meeting(owned_by_partner_id => $partner_id, $event, undef, { skip_save => 1 } ) if $partner_id;

    my $creator_partner_id = $self->param('creator_partner_id');
    $self->_set_note_for_meeting(created_by_partner_id => $creator_partner_id, $event, undef, { skip_save => 1 } ) if $creator_partner_id;

    $self->_set_note_for_meeting( meeting_helpers_shown => 1, $event, { skip_save => 1 } ) if $self->param('disable_helpers');

    my $uid = $self->param('uid') || $self->_get_meeting_uid( $event, 'no_fill' );
    $self->_set_note_for_meeting( uid => $uid, $event, undef, { skip_save => 1 }  );

    if ( defined( my $option = $self->param('online_conferencing_option') ) ) {
        $self->_set_note_for_meeting( online_conferencing_option => $option, $event, { skip_save => 1 } );
    }

    if ( defined( my $account = $self->param('skype_account') ) ) {
        $self->_set_note_for_meeting( skype_account => $account, $event, { skip_save => 1 } );
    }

    if ( defined( my $option = $self->param('online_conferencing_data') ) ) {
        $self->_set_note_for_meeting( online_conferencing_data => $option, $event, { skip_save => 1 } );
        # this might go away at some point
        if ( $option->{skype_account} ) {
            $self->_set_note_for_meeting( skype_account => $option->{skype_account}, $event, { skip_save => 1 } );
        }
    }

    $self->_set_note( background_theme => $self->param('background_theme'), $event, { skip_save => 1 } );
    $self->_set_note( background_image_url => $self->param('background_image_url'), $event, { skip_save => 1 } ) if $self->param('background_theme') && $self->param('background_theme') eq 'u';
    $self->_set_note( meeting_type => $self->param('meeting_type'), $event, { skip_save => 1 } );

    $event->save;

    if ( my $upload_id = $self->param('background_upload_id') ) {
        my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $upload_id,
                object => $event,
                group_id => 0,
                user_id => 0,
                domain_id => $domain_id,
            } ) || '';

        $self->_set_note( background_attachment_id => $id, $event );
    }

    my $ia = eval { CTX->controller->initial_action };

    my $time = time;

    my $agenda_content = $self->param('initial_agenda');
    $agenda_content = '' if Dicole::Utils::HTML->html_to_text( $agenda_content ) =~ /^\s*$/s;

    my $participant_emails = $self->param('initial_participants');
    $self->_add_meeting_draft_participants_by_emails_string( $event, $participant_emails, $creator );

    if ( $self->param('initial_participants') && ! $self->param('title') && ! $self->param('skip_default_participant_title') ) {
        my $title = $self->_generate_meeting_title_from_participants( $event, { user => $creator } );

        $event->title( $title );
        $event->save;
    }

    CTX->lookup_action('wiki_api')->e( create_page => {
        group_id => $group_id,
        domain_id => $domain_id,
        creator_id => $creator->id,
        created_date => $time,

        readable_title => 'Agenda',
        suffix_tag => $event->sos_med_tag,

        content => $agenda_content,
        prefilled_tags => $event->sos_med_tag,

        skip_starting_page_proposal => 1,
    } );

    CTX->lookup_action('wiki_api')->e( create_page => {
        group_id => $group_id,
        domain_id => $domain_id,
        creator_id => $creator->id,
        created_date => $time + 1,

        readable_title => 'Action Points',
        suffix_tag => $event->sos_med_tag,

        content => '',
        prefilled_tags => $event->sos_med_tag,

        skip_starting_page_proposal => 1,
    } );

    $self->_store_meeting_event( $event, {
        author => $creator,
        event_type => 'meetings_meeting_created',
        classes => [ 'meetings_meeting' ],
        data => $self->_gather_meeting_event_info( $event ),
    } );

    $self->_send_meeting_created_email( $event, $creator ) unless $self->param('disable_create_email');

    return $event;
}

sub update {
    my ( $self ) = @_;

    my $meeting = $self->_ensure_meeting_object( $self->param('meeting') || $self->param('meeting_id') );

    my $old_info = $self->_gather_meeting_event_info( $meeting );

    my $title = $self->param('title');
    $meeting->title( $title ) if defined( $title );

    my $location = $self->param('location');
    $meeting->location_name( $location ) if defined( $location );

    if ( defined( my $option = $self->param('online_conferencing_option') ) ) {
        $self->_set_note_for_meeting( online_conferencing_option => $option, $meeting, { skip_save => 1 } );
    }

    if ( defined( my $account = $self->param('skype_account') ) ) {
        $self->_set_note_for_meeting( skype_account => $account, $meeting, { skip_save => 1 } );
    }

    if ( defined( my $option = $self->param('online_conferencing_data') ) ) {
        $self->_set_note_for_meeting( online_conferencing_data => $option, $meeting, { skip_save => 1 } );
        # this might go away at some point
        if ( $option->{skype_account} ) {
            $self->_set_note_for_meeting( skype_account => $option->{skype_account}, $meeting, { skip_save => 1 } );
        }
    }

    if ( defined( my $begin_epoch = $self->param('begin_epoch') ) && defined( my $end_epoch = $self->param('end_epoch') ) ) {
        my $by_user_id = Dicole::Utils::User->ensure_id( $self->param('author') );
        $self->_set_date_for_meeting( $meeting, $begin_epoch, $end_epoch, { skip_event => 1, set_by_user_id => $by_user_id, require_rsvp_again => $self->param('require_rsvp_again') || 0 } );
    }

    if ( $self->param('matchmaking_accepted') ) {
        $self->_set_note_for_meeting( 'matchmaking_accept_dismissed', time, $meeting );
    }

    $self->_set_note( background_theme => $self->param('background_theme'), $meeting, { skip_save => 1 } );
    $self->_set_note( background_image_url => $self->param('background_image_url'), $meeting, { skip_save => 1 } ) if $self->param('background_theme') && $self->param('background_theme') eq 'u';
    $self->_set_note( meeting_type => $self->param('meeting_type'), $meeting, { skip_save => 1 } );

    $meeting->save;

    if ( my $upload_id = $self->param('background_upload_id') ) {
        my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $upload_id,
                object => $meeting,
                group_id => 0,
                user_id => 0,
                domain_id => $meeting->domain_id,
            } ) || '';

        $self->_set_note( background_attachment_id => $id, $meeting );
    }

    my $new_info = $self->_gather_meeting_event_info( $meeting );

    $self->_store_meeting_event( $meeting, {
        author => $self->param('author'),
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return $meeting;
}

sub activate_suggestion {
    my ( $self ) = @_;

    my $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $self->param('suggestion') ||$self->param('suggestion_id') );

    die "cound not find suggestion" unless $suggestion;

    my $user = Dicole::Utils::User->ensure_object( $suggestion->user_id );
    my $agenda = Dicole::Utils::HTML->text_to_phtml( $suggestion->description );

    my $meeting = CTX->lookup_action('meetings_api')->e( create => {
        creator => $user,
        domain_id => $suggestion->domain_id,
        partner_id => $self->param('partner_id'),
        title => $suggestion->title,
        location => $suggestion->location,
        begin_epoch => $suggestion->begin_date,
        end_epoch => $suggestion->end_date,
        initial_agenda => $agenda,
        disable_create_email => $self->param('disable_create_email'),
    });

    $self->_set_note_for_meeting( meeting_helpers_shown => 1, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( created_from_suggestion => $suggestion->id, $meeting, { skip_save => 1 } );
    $meeting->save;

    my $aos = Dicole::Utils::Mail->string_to_address_objects( $suggestion->participant_list );
    for my $ao ( @$aos ) {
        my $email = Dicole::Utils::Text->ensure_utf8( $ao->address );
        my $participant = $self->_fetch_user_for_email( $email, $suggestion->domain_id );
        if ( $participant ) {
            if ( $participant->id != $user->id ) {
                my $dpo = $self->_add_meeting_draft_participant( $meeting, {
                    user_id => $participant->id,
                }, $user );
            }
        }
        else {
            my $dpo = $self->_add_meeting_draft_participant( $meeting, {
                email => $email,
                name => Dicole::Utils::Text->ensure_utf8( $ao->phrase ),
            }, $user );
        }
    }

    return $meeting;
}

sub remove {
    my ($self) = @_;

    my $meeting = $self->_ensure_meeting_object( $self->param('meeting') || $self->param('meeting_id') );
    my $user_id = Dicole::Utils::User->ensure_id( $self->param('user_id') || $self->param('user') );
    my $domain_id = $meeting->domain_id;

    $self->_store_meeting_event( $meeting, {
        event_type => 'meetings_meeting_removed',
        classes => [ 'meetings_meeting' ],
        data => $self->_gather_meeting_event_info( $meeting ),
    } );

    $meeting->removed_date( time );
    $meeting->save;
}

sub get_subscribed_users {
    my ($self) = @_;

    my @all_users = map { Dicole::Utils::User->ensure_object($_) }
        @{ CTX->lookup_action('domains_api')->e(users_by_domain => { domain_id => 76 }) };

    return [ grep { $self->_user_is_pro($_, 76) } @all_users ];
}

sub send_pending_emails {
    my ( $self ) = @_;

    $self->send_pending_before_emails unless $self->param('skip_befores');
    $self->send_pending_after_emails unless $self->param('skip_afters');
    $self->send_pending_digest_emails unless $self->param('skip_digests');
    $self->send_pending_scheduling_reminder_emails unless $self->param('skip_scheduling_reminders');
    $self->send_pending_scheduling_confirmation_emails unless $self->param('skip_scheduling_confirmations');
    $self->send_pending_rsvp_reminder_emails unless $self->param('skip_rsvp_reminders');
    $self->send_pending_matchmaker_accept_reminder_emails unless $self->param('skip_matchmaker_accept_reminders');
    $self->send_pending_draft_incomplete_emails unless $self->param('skip_draft_incompletes');
    $self->send_pending_action_points_incomplete_emails unless $self->param('skip_action_points_incompletes');
}

sub send_pending_draft_incomplete_emails {
    my ( $self ) = @_;
    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my %meetings_lookup = $limit_to_meetings ? map { $_ => 1 } @$limit_to_meetings : ();

    my $stack_seconds = ( $self->param('stack_hours') || 24 ) * 60 * 60;
    my $backlog_seconds = ( $self->param('backlog_days') || 24 ) * 24 * 60 * 60;
    my $dry_run = $self->param('dry_run');

    my $events = $self->_fetch_meetings( {
        where => 'domain_id = ? AND created_date > ?',
        value => [ $domain_id, time - $backlog_seconds ],
    });

    for my $event ( @$events ) {
        next if $limit_to_meetings && ! $meetings_lookup{ $event->id };
        next unless $self->_meeting_is_draft( $event );
        next if $self->_get_note_for_meeting( draft_incomplete_reminder_dismissed => $event );

        next if $event->created_date + $stack_seconds > time;
        my $last_reminder = $self->_get_note_for_meeting( 'draft_incomplete_reminder_sent', $event );
        next if $last_reminder && $last_reminder + $stack_seconds > time;

        next if $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event )
            && ! $self->_get_note_for_meeting( matchmaking_accept_dismissed => $event );

        next if $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event )
            && $self->_get_note_for_meeting( matchmaking_accept_dismissed => $event ) + $stack_seconds > time;

        my $dpos = $self->_fetch_meeting_draft_participation_objects( $event );
        next unless @$dpos;

        my $creator_user = Dicole::Utils::User->ensure_object( $event->creator_id );
        next unless $creator_user->email;

        next if $self->_get_note_for_meeting_user( 'disable_emails', $event, $creator_user->id );

        next if $event->begin_date && $event->begin_date < time;

        $self->_send_draft_incomplete_email( $event, $creator_user, $dry_run );

        $self->_set_note_for_meeting( 'draft_incomplete_reminder_sent', time, $event ) unless $dry_run;
    }
}

sub _send_draft_incomplete_email {
    my ( $self, $meeting, $creator_user, $dry_run ) = @_;

    print "NOT " if $dry_run;
    print "Sending draft incomplete reminder for meeting " . $meeting->id . " to " . $creator_user->email . "\n";

    $self->_send_meeting_user_template_mail( $meeting, $creator_user, 'meetings_draft_incomplete', {
        user_name => Dicole::Utils::User->name( $creator_user ),
    } ) unless $dry_run ;
}

sub send_pending_action_points_incomplete_emails {
    my ( $self ) = @_;
    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my %meetings_lookup = $limit_to_meetings ? map { $_ => 1 } @$limit_to_meetings : ();

    my $stack_seconds = ( $self->param('stack_hours') || 2 ) * 60 * 60;
    my $backlog_seconds = ( $self->param('backlog_hours') || 10 ) * 60 * 60;

    $stack_seconds = 0 if $self->param('dry_test');

    my $meetings =  $self->_fetch_meetings( {
        where => 'domain_id = ? AND end_date < ? AND end_date > ?',
        value => [ $domain_id, time - $stack_seconds, time - $backlog_seconds ],
    });

    my $events_by_id = {};

    for my $meeting ( @$meetings ) {
        next if $limit_to_meetings && ! $meetings_lookup{ $meeting->id };
        next if $self->_meeting_is_draft( $meeting );
        next if $self->_get_note_for_meeting( 'action_points_incomplete_reminder_sent', $meeting ) && ! $self->param('dry_test');

        if ( my $event_id = $self->_get_note( attached_to_matchmaking_event_id => $meeting ) ) {
            my $event = $events_by_id->{ $event_id } ||= $self->_ensure_object_of_type( meetings_matchmaking_event => $event_id );
            next if $event && $self->_get_note( disable_action_points_incomplete_reminders => $event );
        }

        my $creator_user = Dicole::Utils::User->ensure_object( $meeting->creator_id );
        next unless $creator_user && $creator_user->email;

        next if $self->_get_note_for_meeting_user( 'disable_emails', $meeting, $creator_user->id ) && ! $self->param('dry_test');
        next unless $self->_notification_setting_for_user( email_action_points_reminder => $creator_user, $meeting->domain_id );

        my $action_points_parameters = $self->_fetch_processed_meeting_action_points_parameters( $meeting ) || {};
        next if $action_points_parameters->{action_points_text};

        $self->_set_note_for_meeting( 'action_points_incomplete_reminder_sent', time, $meeting ) unless $self->param('dry_run') || $self->param('dry_test');

        next if $self->_meeting_has_swipetomeet( $meeting );

        $self->_send_themed_mail(
            user => $creator_user,
            reply_to => $self->_get_meeting_action_points_reply_email( $meeting, $creator_user ),
            domain_id => $meeting->domain_id,
            partner_id => $self->_get_partner_id_for_meeting( $meeting ),
            group_id => $meeting->group_id,
            template_key_base => 'meetings_missing_action_points',
            template_params => {
                meeting_title => $self->_meeting_title_string( $meeting ),
                participant_names_string => $self->_meeting_other_participant_names_string_for_user( $meeting, $creator_user ),
                login_url => $self->_generate_complete_meeting_user_material_url_for_selector_url(
                    $meeting, $creator_user, $action_points_parameters->{action_points_selector}
                ),
                %{ $self->_gather_theme_mail_template_params_for_meeting( $meeting ) },
            },
        ) unless $self->param('dry_run');


    }
}

sub send_pending_matchmaker_accept_reminder_emails {
    my ( $self ) = @_;
    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my %meetings_lookup = $limit_to_meetings ? map { $_ => 1 } @$limit_to_meetings : ();

    my $stack_seconds = ( $self->param('stack_hours') || 24*7 ) * 60 * 60;
    my $backlog_seconds = ( $self->param('backlog_days') || 24 ) * 24 * 60 * 60;
    my $dry_run = $self->param('dry_run');

    my $events =  $self->_fetch_meetings( {
        where => 'domain_id = ? AND created_date > ? AND begin_date > ?',
        value => [ $domain_id, time - $backlog_seconds, time ],
    });

    for my $event ( @$events ) {
        next if $limit_to_meetings && ! $meetings_lookup{ $event->id };
        next unless $self->_get_note_for_meeting( attached_to_matchmaking_event_id => $event );
        next unless $self->_meeting_is_draft( $event );
        next if $self->_get_note_for_meeting( matchmaking_accept_dismissed => $event );

        next if $event->created_date + $stack_seconds > time;
        my $last_reminder = $self->_get_note_for_meeting( 'matchmaker_accept_reminder_sent', $event );
        next if $last_reminder && $last_reminder + $stack_seconds > time;

        $self->_send_matchmaker_accept_reminder_email( $event, $dry_run );

        $self->_set_note_for_meeting( 'matchmaker_accept_reminder_sent', time, $event ) unless $dry_run;
    }
}

sub _send_matchmaker_accept_reminder_email {
    my ( $self, $meeting, $dry_run ) = @_;

    my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group({
            where => 'created_meeting_id = ?',
            value => [ $meeting->id ],
        });

    my $lock = pop @$locks;

    if ( ! $lock ) {
        get_logger(LOG_APP)->error('lock had disappeared from meeting ' . $meeting->id );
        return 0;
    }

    my $matchmaker = $self->_ensure_object_of_type( meetings_matchmaker => $lock->matchmaker_id );

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $creator_user = Dicole::Utils::User->ensure_object( $meeting->creator_id );
    my $requester_user = Dicole::Utils::User->ensure_object( $lock->expected_confirmer_id );
    my $requester_info = $self->_gather_user_info( $requester_user, -1, $meeting->domain_id );

    my $begin_date = $lock->locked_slot_begin_date;
    my $end_date = $lock->locked_slot_end_date;

    my $partner_id = $self->_get_partner_id_for_meeting( $meeting );
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );
    my $time_string = $self->_form_timespan_string_from_epochs( $begin_date, $end_date, $requester_user );

    print "NOT " if $dry_run;
    print "Sending matchmaker accept reminder to " . $creator_user->email . "\n";

    $self->_send_partner_themed_mail(
        user => $creator_user,
        domain_id => $meeting->domain_id,
        partner_id => $partner_id,
        group_id => 0,

        template_key_base => 'meetings_matchmaker_confirm_reminder',
        template_params => {
            user_name => Dicole::Utils::User->name( $creator_user ),
            requester_name => Dicole::Utils::User->name( $requester_user ),
            requester_email => $requester_user->email,
            requester_company => $requester_info->{organization},
            matchmaking_event => $mm_event->custom_name,
            greeting_message_html => Dicole::Utils::HTML->text_to_html( $lock->agenda ),
            greeting_message_text => $lock->agenda,
            accept_url => $self->_get_meeting_user_url( $meeting, $creator_user, $meeting->domain_id, $domain_host, { matchmaking_response => 'accept' } ),
            decline_url => $self->_get_meeting_user_url( $meeting, $creator_user, $meeting->domain_id, $domain_host, { matchmaking_response => 'decline' } ),
            meeting_url => $self->_get_meeting_user_url( $meeting, $creator_user, $meeting->domain_id, $domain_host ),
            meeting_title => $meeting->title,
            meeting_time => $time_string,
            meeting_location => $meeting->location_name,
        },
    ) unless $dry_run;
}

sub send_pending_before_emails {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');

    my %meetings_lookup = $limit_to_meetings ? map { $_ => 1 } @$limit_to_meetings : ();
    my %user_lookup = $limit_to_users ? map { $_ => 1 } @$limit_to_users : ();

    my $window_start = time + 23*3600;
    my $window_stop = time + 24*3600;

    if ( $self->param('dry_run') || $self->param('dry_test') ) {
        $window_start = time;
        $window_stop = time + 7*24*3600;
    }

    my $meetings =  $self->_fetch_meetings( {
        where => 'domain_id = ? AND begin_date > ? AND begin_date < ?',
        value => [ $domain_id, $window_start, $window_stop ],
    });

    my $mm_event_before_sent_for_event = {};

    for my $meeting ( @$meetings ) {
        next if $limit_to_meetings && ! $meetings_lookup{ $meeting->id };

        if ( my $mm_event_id = $self->_get_note( attached_to_matchmaking_event_id => $meeting ) ) {
            next if $mm_event_before_sent_for_event->{ $mm_event_id };
            $self->_ensure_before_mm_event_email_sent( $mm_event_id );
            $mm_event_before_sent_for_event->{ $mm_event_id }++;
            next;
        }

        next if $self->_meeting_is_draft( $meeting ) || $self->_meeting_is_cancelled( $meeting );

        # No before emails for meetings created or readyed less than 34 hours before the
        # meeting starts.
        next if $meeting->created_date + 34*60*60 > $meeting->begin_date && ! $self->param('dry_test');

        my $ready_timestamp = $self->_get_note_for_meeting( draft_ready => $meeting );
        next if $ready_timestamp && $ready_timestamp + 34*60*60 > $meeting->begin_date && ! $self->param('dry_test');

#        next unless $self->_get_meeting_permission( $meeting, 'start_reminder' );

        # refresh the event object to minimize simultaneous execution problems
        $meeting = CTX->lookup_object('events_event')->fetch( $meeting->id );
        next if $self->_get_note_for_meeting( 'before_emails_sent', $meeting ) && ! $self->param('dry_test');

        my $organizer_user = $self->_fetch_meeting_organizer_user( $meeting );
        next if $self->_get_note_for_meeting_user( 'disable_emails', $meeting, $organizer_user->id ) && ! $self->param('dry_test');
        next unless $self->_notification_setting_for_user( email_24h_meeting_start => $organizer_user, $meeting->domain_id );

        my $euos = $self->_fetch_meeting_participant_objects( $meeting );

        my $agenda_parameters = $self->_fetch_processed_meeting_agenda_parameters( $meeting );

        $self->_set_note_for_meeting( 'before_emails_sent', 1, $meeting ) unless $self->param('dry_run') || $self->param('dry_test');

        next if $self->_meeting_has_swipetomeet( $meeting );

        if ( my $mmr_id = $self->_get_note( created_from_matchmaker_id => $meeting ) ) {
            my $mmr = $self->_ensure_object_of_type( meetings_matchmaker => $mmr_id );
            if ( $mmr && $self->_get_note( sms_reminder_template => $mmr ) ) {
                my $template = $self->_get_note( sms_reminder_template => $mmr );

                my $users = $self->_fetch_meeting_participant_users( $meeting );
                for my $user ( @$users ) {
                    next if $user->id == $organizer_user->id;

                    my $msg = $template;

                    my $bdt = Dicole::Utils::Date->epoch_to_datetime( $meeting->begin_date, $user->time_zone, $user->language );

                    my $msg_location = $meeting->location_name;
                    my $msg_day = $bdt->day . '.' . $bdt->month . '.';
                    my $msg_time = $bdt->hour . ':' .sprintf( "%02d", $bdt->minute );
                    my $msg_organizer_name = Dicole::Utils::User->name( $organizer_user );

                    my $attributes = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
                        user_id => $organizer_user->id,
                        domain_id => $domain_id,
                        attributes => {
                            contact_phone => undef,
                        },
                    } );

                    my $organizer_number = $attributes->{contact_phone} || '';
                    if ( $organizer_number ) {
                        $organizer_number = '+' . $organizer_number unless $organizer_number =~ /^(\+|0)/;
                        $organizer_number = ', '.$organizer_number;
                    }
                    $msg_organizer_name .= $organizer_number;

                    $msg =~ s/\[\[location\]\]/$msg_location/;
                    $msg =~ s/\[\[day\]\]/$msg_day/;
                    $msg =~ s/\[\[time\]\]/$msg_time/;
                    $msg =~ s/\[\[organizer_name\]\]/$msg_organizer_name/;

                    $self->_send_user_sms( $user, $msg, { creator_user => $organizer_user, domain_id => $meeting->domain_id, log_data => { type => 'lt_custom_reminder', meeting_id => $meeting->id } } )
                        unless $self->param('dry_run') || $self->param('dry_test');
                }
            }
        }

        next unless $agenda_parameters;
        next if $agenda_parameters->{agenda_text};

        $self->_send_themed_mail(
            user => $organizer_user,
            reply_to => $self->_get_meeting_agenda_reply_email( $meeting, $organizer_user ),
            domain_id => $meeting->domain_id,
            partner_id => $self->_get_partner_id_for_meeting( $meeting ),
            group_id => $meeting->group_id,
            template_key_base => 'meetings_missing_agenda',
            template_params => {
                meeting_title => $self->_meeting_title_string( $meeting ),
                participant_names_string => $self->_meeting_other_participant_names_string_for_user( $meeting, $organizer_user ),
                login_url => $self->_generate_complete_meeting_user_material_url_for_selector_url(
                    $meeting, $organizer_user, $agenda_parameters->{agenda_selector}
                ),
                %{ $self->_gather_theme_mail_template_params_for_meeting( $meeting ) },
            },
        ) unless $self->param('dry_run');
    }
}

sub send_pending_after_emails {
    my ( $self ) = @_;

    return 1;
}

sub _send_generic_meeting_template_mail {
    my ( $self, %p ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $p{user} || $p{user_id} );
    return unless $user->email;

    my $event = $p{event};

    my $organizer_user = $p{organizer_user} || $self->_fetch_meeting_organizer_user( $event );
    my $material_overview_params = $self->_gather_material_overview_params( $event, $user );
    my $meeting_image = $self->_generate_meeting_image_url_for_user( $event, $user );

    $self->_send_meeting_user_template_mail( $event, $user, $p{template_key_base}, {
        organizer_name => Dicole::Utils::User->name( $organizer_user ),
        organizer_first_name => Dicole::Utils::User->first_name( $organizer_user ),
        meeting_image => $meeting_image,
        %$material_overview_params,
        %{ $p{additional_template_params} || {} },
    }, $p{domain_host}, $p{meeting_email} );
}

sub _ensure_before_mm_event_email_sent {
    my ( $self, $event_id ) = @_;

    my $mm_event = $self->_ensure_matchmaking_event_object( $event_id );
    return unless $mm_event;

    if ( $self->_get_note( before_mm_event_email_sent => $mm_event ) ) {
        return unless $self->param('resend');
    }

    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');

    my %meetings_lookup = $limit_to_meetings ? map { $_ => 1 } @$limit_to_meetings : ();
    my %user_lookup = $limit_to_users ? map { $_ => 1 } @$limit_to_users : ();

    my $time = time;
    my $sent_to_users = {};
    my $possible_event_meetings = $self->_fetch_meetings({
        where => 'domain_id = ? AND begin_date > ? AND begin_date < ?',
        value => [ $mm_event->domain_id, time, time + 8 * 24 * 60 * 60 ],
    });

    for my $meeting ( @$possible_event_meetings ) {
        my $meeting_event_id = $self->_get_note( attached_to_matchmaking_event_id => $meeting );
        next unless $meeting_event_id && $meeting_event_id == $event_id;
        next if $limit_to_meetings && ! $meetings_lookup{ $meeting->id };
        next if $meeting->begin_date < time;

        my $domain_id = $meeting->domain_id;
        my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

        my $euos = $self->_fetch_meeting_participant_objects( $meeting );
        my $user_id_map = Dicole::Utils::User->ensure_object_id_map( [ map { $_->user_id } @$euos ] );

        for my $euo ( @$euos ) {
            next if $sent_to_users->{ $euo->user_id };
            $sent_to_users->{ $euo->user_id }++;

            my $user = $user_id_map->{ $euo->user_id };
            next unless $user;

            next if $limit_to_users && ! $user_lookup{ $user->id };

            print "[DRY-NOT] Sending before event mail to user ". $user->id ."\n" if $self->param('dry_run');
            eval { $self->_send_before_mm_event_email_to_user( $mm_event, $user, $domain_host ) } unless $self->param('dry_run');
            if ( $@ ) {
                get_logger(LOG_APP)->error( "Error sending event start email to user " . $user->id . ": $@" );
            }
        }
    }

    $self->_set_note( before_mm_event_email_sent => $time, $mm_event ) unless $self->param('dry_run') || $self->param('dry_test');
}

sub _send_before_mm_event_email_to_user {
    my ( $self, $mm_event, $user, $domain_host ) = @_;

    my $meetings = $self->_get_upcoming_user_meetings_in_domain( $user, $mm_event->domain_id, '', 'begin_date asc' );
    my $meetings_data = [];
    for my $meeting ( @$meetings ) {
        my $meeting_event_id = $self->_get_note( attached_to_matchmaking_event_id => $meeting );
        next unless $meeting_event_id && $meeting_event_id == $mm_event->id;
        next if $meeting->begin_date < time;

        my $url = $self->_generate_authorized_uri_for_user( $self->_get_meeting_url( $meeting, $domain_host ), $user, $meeting->domain_id );
        my $participant_users = $self->_fetch_meeting_participant_users( $meeting );
        my @participant_names = map( { Dicole::Utils::User->name($_) } @$participant_users );

        my $draft_participant_infos = $self->_gather_meeting_draft_participants_info( $meeting, -1, undef, undef, { user => $user } );
        push @participant_names, map( { $_->{is_hidden} ? () : $_->{name} } @$draft_participant_infos );

        my $participants = join ", ", @participant_names;

        my $tz = $self->_get_note( force_time_zone => $mm_event ) ||  $self->_get_note( default_timezone => $mm_event ) || $user->timezone;

        push @$meetings_data, {
            title => $self->_meeting_title_string( $meeting ),
            location => $self->_meeting_location_string( $meeting ),
            'time' => $self->_form_times_string_for_epochs( $meeting->begin_date, $meeting->end_date, $tz, $user->lang ),
            participants => $participants,
            meeting_url => $url,
            is_confirmed => $self->_meeting_is_draft( $meeting ) ? 0 : 1,
        };
    }

    print "Sending before event mail to user ". $user->id ."\n";

    my $instructions_html = $self->_get_note( instructions => $mm_event ) || $self->_get_note( instructions_html => $mm_event );
    my $instructions_text = $self->_get_note( instructions_text => $mm_event ) || Dicole::Utils::HTML->html_to_text( $instructions_html );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $mm_event->domain_id,
        partner_id => $mm_event->partner_id,
        group_id => 0,

        template_key_base => 'meetings_matchmaking_event_before_summary',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            user_email => $user->email,
            matchmaking_event => $mm_event->custom_name,
            meetings => $meetings_data,
            matchmaking_instructions_html => $instructions_html,
            matchmaking_instructions_text => $instructions_text,
        },
    ) if @$meetings_data;
}

sub send_pending_digest_emails {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $after_time = time - ( $self->param('since_hours') || 28 ) * 60 * 60;
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');
    my $skip_stacking = $self->param('skip_stacking');
    my $dry_run = $self->param('dry_run');

    # Uses raw sql.. for no particular reason :P
    my $events = CTX->lookup_object('event_source_event')->fetch_group( {
        sql => 'select * from dicole_event_source_event where' .
            ' domain_id = ' . $domain_id . ' AND' .
            ' updated > ' . $after_time .
            ' order by updated desc',
    } );

    my $meeting_events = $self->_index_events_by_meeting( $events, $limit_to_meetings );

    # Fetch meetings which have events and meetings with are just about to start
    my $meetings = $self->_fetch_meetings( {
        where => Dicole::Utils::SQL->column_in( event_id => [ keys %$meeting_events ] ) . ' OR ' .
            '( begin_date < ? AND begin_date > ? AND domain_id = ? )',
        value => [ time + 15 * 60, time, $domain_id ],
    }, { include_cancelled => 1 } );

    my %limited_meetings = map { $_ => 1 } ( $limit_to_meetings ? @$limit_to_meetings : () );

    my @process_meetings = ();
    for my $meeting ( @$meetings ) {
        next if $limit_to_meetings && ! $limited_meetings{ $meeting->id };
        next if $self->_meeting_is_draft( $meeting );

        my $last_check = $self->_get_note_for_meeting( 'digest_checked', $meeting ) || $meeting->created_date;

        if ( $self->_meeting_is_cancelled( $meeting ) ) {
            my $cancel_date = $self->_get_note_for_meeting( 'digest_meeting_cancel_sent', $meeting );
            if ( $cancel_date && ! $skip_stacking ) {
                next if $last_check > time - 23*60*60;
                next unless ( ( time - $cancel_date ) % ( 24*60*60 ) < 60*60 );
            }
        }
        elsif ( ! $skip_stacking ) {
            # Send 24 hour digests only within 1 hour of the time
            # of the day the meeting was created or meeting ended
            if ( ! $meeting->begin_date || $meeting->begin_date > time + 23*60*60 ) {
                next if $last_check > time - 23*60*60;
                next unless ( ( time - $meeting->created_date ) % ( 24*60*60 ) < 60*60 );
            }
            elsif ( time > $meeting->end_date + 24*60*60 ) {
                next if $last_check > time - 23*60*60;
                next unless ( ( time - $meeting->end_date ) % ( 24*60*60 ) < 60*60 );
            }
            elsif ( time > $meeting->end_date + 12*60*60 ) {
                next if $self->_get_note_for_meeting( 'digest_meeting_end_sent', $meeting );
            }
            else {
                next if time > $meeting->begin_date;

                if ( time + 15*60 < $meeting->begin_date ) {
                    next if $last_check > time - 58*60;
                    # Stack if we are soon to send the start digest
                    next if time + 75*60 > $meeting->begin_date;
                }
                next if $self->_get_note_for_meeting( 'digest_meeting_start_sent', $meeting );
            }
        }

        push @process_meetings, $meeting;
    }

    $self->_send_digests_for_meeting( $_, $meeting_events ) for @process_meetings;
}

sub _index_events_by_meeting {
    my ( $self, $events, $limit_to_meetings ) = @_;

    my %meeting_events = ();
    my %limited_meetings = map { $_ => 1 } ( $limit_to_meetings ? @$limit_to_meetings : () );

    for my $event ( @$events ) {
        next unless $event->classes =~ /meetings/;
        my $data = Dicole::Utils::JSON->decode( $event->payload );
        next unless $data->{meeting_id};
        next if $limit_to_meetings && ! $limited_meetings{ $data->{meeting_id} };
        push @{ $meeting_events{ $data->{meeting_id} } }, $event;
    }

    return \%meeting_events;
}

sub _send_digests_for_meeting {
    my ( $self, $meeting, $meeting_events ) = @_;

    return unless $self->_get_meeting_permission( $meeting, 'participant_digest' );

    my $limit_to_users = $self->param('limit_to_users');
    my %limited_users = map { $_ => 1 } ( $limit_to_users ? @$limit_to_users : () );

    my $participant_objects = $self->_fetch_meeting_participant_objects( $meeting );

    my $proposals = $self->_fetch_meeting_proposals( $meeting );

    my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );

    my $agenda_parameters = $self->_fetch_processed_meeting_agenda_parameters( $meeting, $pages );
    my $action_points_parameters = $self->_fetch_processed_meeting_action_points_parameters( $meeting, $pages );

    my $time = time;
    my $meeting_about_to_start = ( $time + 15*60 > $meeting->begin_date && $time < $meeting->begin_date) ? 1 : 0;
    my $meeting_summary_window = ( $meeting->end_date + 12*60*60 < $time && $meeting->end_date + 24*60*60 > $time ) ? 1 : 0;

    my $draft_ready_time = $self->_meeting_draft_ready_time( $meeting );

    for my $po ( @$participant_objects ) {
        next if $limit_to_users && ! $limited_users{ $po->{user_id} };
        next if $self->_get_note_for_meeting_user( 'disable_emails', $meeting, $po->user_id, $po );

        my $user = eval { Dicole::Utils::User->ensure_object( $po->{user_id} ) };
        next unless $user && $user->email;

        my $last_sent = $self->_get_note_for_meeting_user( 'digest_sent', $meeting, $user, $po ) || 0;

        # events that are close to the last send time (60 seconds before) are stored
        # for every user so that we can skip them.. this is because we can't guarantee
        # auto incremention (or even non-backwardness) with the event updated timestamps

        my $sent_event_id_string = $self->_get_note_for_meeting_user( 'digest_sent_event_ids', $meeting, $user, $po ) || '';
        my %skip_events = map { $_ => 1 } ( split /\s*,\s*/, $sent_event_id_string );

        my @new_events = ();
        my @event_id_list_to_store = ();
        for my $event ( @{ $meeting_events->{ $meeting->id } || [] } ) {
            push @event_id_list_to_store, $event->id if $event->updated > $time - 60;
            next if $event->updated < $draft_ready_time;
            next if $event->author == $user->id;
            next if $event->updated < $last_sent - 60;
            next if $skip_events{ $event->id };
            push @new_events, $event;
        }

        my $send_start = ( $meeting_about_to_start && ! $self->_get_note_for_meeting_user( 'digest_meeting_start_sent', $meeting, $user, $po ) ) ? 1 : 0;
        my $send_end = ( $meeting_summary_window && ! $self->_get_note_for_meeting_user( 'digest_meeting_end_sent', $meeting, $user, $po ) ) ? 1 : 0;

        $self->_send_digest( $meeting, $user, $po, \@new_events, $proposals, $agenda_parameters || undef, $action_points_parameters || undef, $send_start, $send_end ) if ( @new_events || $send_start || $send_end );

        unless ( $self->param('dry_run') || $self->param('dry_test') ) {
            $self->_set_note_for_meeting_user( 'digest_meeting_start_sent', $time, $meeting, $user, $po ) if $send_start;
            $self->_set_note_for_meeting_user( 'digest_meeting_end_sent', $time, $meeting, $user, $po ) if $send_end;
            $self->_set_note_for_meeting_user( 'digest_sent', $time, $meeting, $user, $po );
            $self->_set_note_for_meeting_user( 'digest_sent_event_ids', join( ",", @event_id_list_to_store ), $meeting, $user, $po );
        }
    }

    unless ( $self->param('dry_run') || $self->param('dry_test') ) {
        $self->_set_note_for_meeting( 'digest_checked', $time, $meeting );
        if ( $meeting_about_to_start && ! $self->_get_note_for_meeting( 'digest_meeting_start_sent', $meeting ) ) {
            $self->_set_note_for_meeting( 'digest_meeting_start_sent', $time, $meeting );
        }
        if ( $meeting_summary_window && ! $self->_get_note_for_meeting( 'digest_meeting_end_sent', $meeting ) ) {
            $self->_set_note_for_meeting( 'digest_meeting_end_sent', $time, $meeting );
        }
        if ( $self->_meeting_is_cancelled( $meeting ) && ! $self->_get_note_for_meeting( 'digest_meeting_cancel_sent', $meeting ) ) {
            $self->_set_note_for_meeting( 'digest_meeting_cancel_sent', $time, $meeting );
        }
    }
}

sub _send_digest {
    my ( $self, $meeting, $user, $po, $events, $proposals, $agenda_parameters, $action_points_parameters, $send_start, $send_end ) = @_;

    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $send = 0;
    my $params = { info_updated => 0 };

    if ( $send_start ) {
        $params->{meeting_start} = 1;

        my $option = $self->_get_note_for_meeting( online_conferencing_option => $meeting );
        my $data = $self->_gather_meeting_live_conferencing_params( $meeting, $user );

        if ( $option && scalar( keys %$data ) ) {
            $params->{meeting_online_start} = 1;
            $params->{meeting_online_option} = $option;
            $send = 1;
        }

        if ( $agenda_parameters && $action_points_parameters->{agenda_text} ) {
            $params = {
                %$params,
                %$agenda_parameters,
                comment_now_url => $self->_generate_complete_meeting_user_material_url_for_selector_url(
                    $meeting, $user, $agenda_parameters->{agenda_selector}, $domain_host
                ),
            };
        }
    }
    elsif ( $send_end ) {
        $params->{meeting_end} = 1;

        if ( $action_points_parameters && $action_points_parameters->{action_points_text} ) {
            $send = 1;
            $params = {
                %$params,
                %$action_points_parameters,
                comment_now_url => $self->_generate_complete_meeting_user_material_url_for_selector_url(
                    $meeting, $user, $agenda_parameters->{action_points_selector}, $domain_host
                ),
            };
        }
    }

    my $participants = { added => {}, removed => {} };

    my $scheduling_changes_by = {};

    my $comments = {
        note => { added => {}, removed => {} },
        wiki => { added => {}, removed => {} },
        prese => { added => {}, removed => {} },
    };

    my $comments_by_object = { note => {}, wiki => {}, prese => {} };
    my $ordered_commented_materials = [];

    my $materials = {
        wiki => { added => {}, removed => {} },
        prese => { added => {}, removed => {} },
    };
    my $ordered_new_materials = [];
    my $new_material_lookup = { wiki => {}, prese => {} };

    my $original_event_info = $self->_gather_meeting_event_info( $meeting );

    my $page_changes_by = {};

    for my $event ( @$events ) {
        my $data = Dicole::Utils::JSON->decode( $event->payload );
        if ( $event->event_type eq 'meetings_meeting_changed' ) {
            $original_event_info = $data->{old_info};
        }
        elsif ( $event->event_type eq 'meetings_participant_created' ) {
            next unless $self->_get_meeting_permission( $meeting, 'participant_digest_new_participant' );
            if ( ! $participants->{removed}->{ $data->{user_id} } ) {
                $participants->{added}->{ $data->{user_id} } = 1;
            }
        }
        elsif ( $event->event_type eq 'meetings_participant_removed' ) {
            if ( ! $participants->{added}->{ $data->{user_id} } ) {
                $participants->{removed}->{ $data->{user_id} } = 1;
            }
        }
        elsif ( $event->event_type =~ /meetings_(.*)_comment_created/ ) {
            next unless $self->_get_meeting_permission( $meeting, 'participant_digest_comments' );
            if ( ! $comments->{ $1 }->{removed}->{ $data->{comment_id} } ) {
                $comments->{ $1 }->{added}->{ $data->{comment_id} } = 1;
                unless ( $comments_by_object->{ $1 }->{ $data->{object_id} } ) {
                    $comments_by_object->{ $1 }->{ $data->{object_id} } = [];
                    if ( $1 eq 'wiki' || $1 eq 'prese' ) {
                        push @$ordered_commented_materials, {
                            type => $1,
                            object_id => $data->{object_id},
                            author => $event->author,
                            timestamp => $event->timestamp,
                        };
                    }
                }
                push @{ $comments_by_object->{ $1 }->{ $data->{object_id} } }, $data->{comment_id};
            }
        }
        elsif ( $event->event_type =~ /meetings_(.*)_comment_removed/ ) {
            if ( ! $comments->{ $1 }->{added}->{ $data->{comment_id} } ) {
                $comments->{ $1 }->{removed}->{ $data->{comment_id} } = 1;
            }
        }
        elsif ( $event->event_type =~ /meetings_(.*)_material_created/ ) {
            next unless $self->_get_meeting_permission( $meeting, 'participant_digest_material' );
            if ( ! $materials->{ $1 }->{removed}->{ $data->{object_id} } ) {
                $materials->{ $1 }->{added}->{ $data->{object_id} } = 1;
                $new_material_lookup->{ $1 }{ $data->{object_id} } = 1;
                push @$ordered_new_materials, {
                    type => $1,
                    object_id => $data->{object_id},
                    author => $event->author,
                    timestamp => $event->timestamp,
                };
            }
        }
        elsif ( $event->event_type =~ /meetings_(.*)_material_removed/ ) {
            if ( ! $materials->{ $1 }->{added}->{ $data->{object_id} } ) {
                $materials->{ $1 }->{removed}->{ $data->{object_id} } = 1;
            }
        }
        elsif ( $event->event_type eq 'meetings_date_proposal_answered' ) {
            $scheduling_changes_by->{ $data->{answer_user_id} }++;
        }
        elsif ( $event->event_type eq 'meetings_wiki_material_edited' ) {
            $page_changes_by->{ $data->{object_id} }->{ $event->author }++;
        }
    }

    my $current_event_info = $self->_gather_meeting_event_info( $meeting );

    unless ( $current_event_info->{title} eq $original_event_info->{title} ) {
        $params->{changed_title} = $self->_meeting_title_string( $meeting );
        $params->{info_updated}++;
        $send = 1;
    }

    unless ( $current_event_info->{location} eq $original_event_info->{location} ) {
        $params->{changed_location} = $self->_meeting_location_string( $meeting );
        $params->{info_updated}++;
        $send = 1;
    }

    # Use the old meeting title in the subject. Otherwise user does not know which meeting everything is about
    $params->{meeting_title} = $original_event_info->{title};

    my $users = Dicole::Utils::User->ensure_object_list( [ keys %{ $participants->{added} } ] );
    $params->{added_users} = [ map { Dicole::Utils::User->name( $_ ) } @$users ];
    $params->{info_updated}++ if scalar( @{ $params->{added_users} } );

    if ( $self->_user_can_manage_meeting( $user, $meeting, $po ) ) {
        delete $scheduling_changes_by->{ $user->id };
        my $scheduled_users = Dicole::Utils::User->ensure_object_list( [ keys %{ $scheduling_changes_by } ] );
        $params->{new_scheduled_users} = [ map { Dicole::Utils::User->name( $_ ) } @$scheduled_users ];
    }

    $params->{new_notes} = $self->_gather_email_data_for_comments(
        $meeting, $meeting, $comments_by_object->{note}->{ $meeting->id } || [], $user
    );

    $params->{new_materials} = $self->_gather_email_data_for_materials(
        $meeting, $ordered_new_materials, $comments_by_object, $user
    );

    my $valid_cm = [ map { $new_material_lookup->{ $_->{type} }->{ $_->{object_id} } ? () : $_ } @$ordered_commented_materials ];

    $params->{commented_materials} = $self->_gather_email_data_for_materials(
        $meeting, $valid_cm, $comments_by_object, $user
    );

    for my $list ( qw( added_users new_notes new_materials commented_materials new_scheduled_users ) ) {
        $send = 1 if $params->{ $list } && @{ $params->{ $list } };
    }

    $params->{meeting_time_past} = ( $meeting->begin_date && time > $meeting->end_date ) ? 1 : 0;

    my $create_link = $domain_host . Dicole::URL->from_parts(
        domain_id => $meeting->domain_id, target => 0,
        action => 'meetings', task => 'create',
    );

    $params->{new_meeting_url} = $self->_generate_authorized_uri_for_user( $create_link, $user, $meeting->domain_id );

    for my $changed_page_id ( keys %$page_changes_by ) {
        my $authors = $page_changes_by->{ $changed_page_id };
        my @authors = map { $_ ? $_ : () } keys %$authors;
        next unless @authors;

        my $author_name = '';
        if ( @authors == 1 ) {
             $author_name = Dicole::Utils::User->name( $authors[0] );
        }

        if ( $agenda_parameters && $changed_page_id == $agenda_parameters->{agenda_page_id} ) {
            next if $send_start;
            $params->{changed_agenda_author} = $author_name;
            $params->{changed_agenda_text} = $agenda_parameters->{agenda_text};
            $params->{changed_agenda_html} = $agenda_parameters->{agenda_html};
            $params->{changed_agenda_url} = $self->_generate_complete_meeting_user_material_url_for_selector_url(
                $meeting, $user, $agenda_parameters->{agenda_selector}, $domain_host
            );

            $send = 1;
        }
        elsif ( $action_points_parameters && $changed_page_id == $action_points_parameters->{action_points_page_id} ) {
            next if $send_end;
            $params->{changed_action_points_author} = $author_name;
            $params->{changed_action_points_text} = $action_points_parameters->{action_points_text};
            $params->{changed_action_points_html} = $action_points_parameters->{action_points_html};
            $params->{changed_action_points_url} = $self->_generate_complete_meeting_user_material_url_for_selector_url(
                $meeting, $user, $action_points_parameters->{action_points_selector}, $domain_host
            );
            $send = 1;
        }
        else {
            # TODO maybe add these changes too?
        }
    }


    if ( $send && $send_end ) {
        $params->{meeting_image} = $self->_generate_meeting_image_url_for_user( $meeting, $user );
    }

    if ( $meeting->begin_date ) {
        if ( $meeting->begin_date > time ) {
            $params->{future_meeting} = 1;
        }
        else {
            $params->{past_meeting} = 1;
        }
        $params->{meeting_date} = $self->_form_date_from_epoch_for_user( $meeting->begin_date, $user );
    }

    if ( $send && ! $self->param('dry_run') ) {
        print "Sending mail to user ". $user->id ." about meeting ". $meeting->id ."\n";
        $self->_send_generic_meeting_template_mail(
            domain_id => $meeting->domain_id,
            event => $meeting,
            user => $user,
            template_key_base => 'meetings_digest_email',

            # The one in here overrides the meeting_title -parameter
            additional_template_params => $params,
        )
    }
    elsif ( $send ) {
        use Data::Dumper;
        print "DRY RUN: not sending mail for meeting " . $meeting->id . " user " . $user->id . ":\n";
        print Data::Dumper::Dumper($params);
    }
}

sub _gather_email_data_for_materials {
    my ( $self, $meeting, $material_info_list, $comments_by_object, $user ) = @_;

    return [] unless scalar( @$material_info_list );

    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $materials = [];
    for my $info ( @$material_info_list ) {
        my $material = {};
        if ( $info->{type} eq 'wiki' ) {
            $material->{object} = CTX->lookup_object('wiki_page')->fetch( $info->{object_id} );
            next unless $material->{object};

            $material->{title} = $material->{object}->readable_title;
            $material->{title} =~ s/\s*\(\#meeting_\d+\)\s*//;

            my $params = { selected_material_url => $self->_generate_meeting_material_url_for_wiki( $meeting, $material->{object} ) };
            $material->{url} = $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, $params );

            $material->{timestamp} = $self->_form_timestamp( $info->{timestamp}, $user ),
            $material->{author_name} = Dicole::Utils::User->name( $info->{author} );
        }
        elsif ( $info->{type} eq 'prese' ) {
            $material->{object} = CTX->lookup_object('presentations_prese')->fetch( $info->{object_id} );
            next unless $material->{object};

            $material->{title} = $material->{object}->name;
            my $params = { selected_material_url => $self->_generate_meeting_material_url_for_prese( $meeting, $material->{object} ) };
            $material->{url} = $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, $params );

            $material->{timestamp} = $self->_form_timestamp( $info->{timestamp}, $user ),
            $material->{author_name} = $info->{author} ?
                Dicole::Utils::User->name( $info->{author} ) : $material->{object}->presenter;
        }
        else {
            next;
        }

        $material->{new_comments} = $self->_gather_email_data_for_comments(
            $meeting, $material->{object}, $comments_by_object->{ $info->{type} }->{ $info->{object_id} } || [], $user
        );

        delete $material->{object};

        push @$materials, $material;
    }

    return $materials;

}

sub _gather_email_data_for_comments {
    my ( $self, $meeting, $object, $note_id_list, $user ) = @_;

    return [] unless $note_id_list;

    my $info_hash = CTX->lookup_action('comments_api')->e( get_info_hash_for_id_list => {
        object => $object,
        domain_id => $meeting->domain_id,
        group_id => $meeting->group_id,
        user_id => 0,
        id_list => $note_id_list,
    } );

    return [ map { $info_hash->{ $_ } ? {
        comment => $info_hash->{ $_ }->{content},
        user_name => $info_hash->{ $_ }->{user_name},
        timestamp => $self->_form_timestamp( $info_hash->{ $_ }->{date_epoch}, $user ),
    } : () } @$note_id_list ];
}

sub _form_timestamp {
    my ( $self, $epoch, $user ) = @_;

    my $dts = Dicole::Utils::Date->epoch_to_date_and_time_strings( $epoch, $user->timezone, $user->lang, 'ampm' );

    return $dts->[1];
}

sub send_pending_scheduling_confirmation_emails {
    my ( $self ) = @_;

    my $after_time = time - ( $self->param('since_hours') || 4 ) * 60 * 60;
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');
    my $wait_seconds = $self->param('wait_seconds') || 5 * 60;
    my $dry_run = $self->param('dry_run');

    return $self->_send_pending_scheduling_confirmation_emails( $after_time, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run );
}

sub _send_pending_scheduling_confirmation_emails {
    my ( $self, $after_time, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run ) = @_;

    # Uses raw sql.. for no particualr reason :P
    my $events = CTX->lookup_object('event_source_event')->fetch_group( {
        sql => 'select * from dicole_event_source_event where' .
            ' updated > ' . $after_time .
            ' order by updated desc',
    } );

    my %meeting_events = ();
    my %limited_meetings = map { $_ => 1 } ( $limit_to_meetings ? @$limit_to_meetings : () );
    my %limited_users = map { $_ => 1 } ( $limit_to_users ? @$limit_to_users : () );

    my $last_meeting_user_answer = {};
    my $meeting_user_answers = {};

    for my $event ( @$events ) {
        next unless $event->classes =~ /meetings_date_proposal_answered/;
        my $data = Dicole::Utils::JSON->decode( $event->payload );
        next unless $data->{meeting_id};
        next if $limit_to_meetings && ! $limited_meetings{ $data->{meeting_id} };
        next unless $data->{answer_user_id};
        next if $limit_to_users && ! $limited_users{ $data->{answer_user_id} };

        $last_meeting_user_answer->{ $data->{meeting_id} }{ $data->{answer_user_id} } ||= $event->timestamp;
        $meeting_user_answers->{ $data->{meeting_id} }{ $data->{answer_user_id} } ||= [];
        push @{ $meeting_user_answers->{ $data->{meeting_id} }{ $data->{answer_user_id} } }, {
            timestamp => $event->timestamp, proposal_id => $data->{proposal_id}
        };
    }

    for my $meeting_id ( keys %$last_meeting_user_answer ) {
        my $meeting_data = $last_meeting_user_answer->{ $meeting_id };
        for my $user_id ( keys %$meeting_data ) {
            my $last_timestamp = $meeting_data->{ $user_id };
            next if $last_timestamp > time - $wait_seconds;

            my $euo = $self->_fetch_meeting_participant_object_for_user( $meeting_id, $user_id );

            # NOTE: user might have been removed - what can we do?
            next unless $euo;

#            next if $self->_get_note_for_meeting_user( 'disable_emails', $meeting_id, $euo->user_id, $euo );

            my $last_sent = $self->_get_note_for_meeting_user( 'last_scheduling_confirmation', $meeting_id, $euo->user_id, $euo );
            my $pos_to_send = {};
            for my $po_data ( @{ $meeting_user_answers->{ $meeting_id }{ $user_id } } ) {
                next if $last_sent && $last_sent >= $po_data->{timestamp};
                $pos_to_send->{ $po_data->{proposal_id} }++;
            }

            next unless scalar( keys %$pos_to_send );

            print "sending $user_id\n";

            $self->_send_scheduling_confirmation_email( $meeting_id, $user_id, $pos_to_send, $dry_run );

            $self->_set_note_for_meeting_user( 'last_scheduling_confirmation' => time, $meeting_id, $euo->user_id, $euo ) unless $dry_run;
        }
    }
}

sub _send_scheduling_confirmation_email {
    my ( $self, $meeting_id, $user_id, $pos_to_send, $dry_run ) = @_;

    my $meeting = CTX->lookup_object('events_event')->fetch( $meeting_id );
    my $user = Dicole::Utils::User->ensure_object( $user_id );
    return unless $user->email;

    my $pos = $self->_fetch_meeting_proposals( $meeting );

    my %po_lookup = map { $_->id => $_ } @$pos;
    my @answered_pos = map { $po_lookup{ $_ } || () } keys %$pos_to_send;

    my $answered_data = [ map { {
        option => $self->_timespan_for_proposal( $_, $user ),
        answer => uc( $self->_get_meeting_proposed_date_answer( $meeting, $_, $user ) ),
    } } @answered_pos ];

    my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $meeting, $user );
    my $open_timespans = [ map { $self->_timespan_for_proposal( $_, $user ) } @$open_pos ];

    $self->_send_meeting_user_template_mail( $meeting, $user, 'scheduling_confirmation', {
        answered_scheduling_options => $answered_data,
        open_scheduling_options => $open_timespans,
    } ) unless $dry_run;
}

sub send_pending_scheduling_reminder_emails {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');
    my $wait_seconds = $self->param('wait_seconds') || 24 * 60 * 60;
    my $dry_run = $self->param('dry_run');

    return $self->_send_pending_scheduling_reminder_emails( $domain_id, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run );
}

sub _send_pending_scheduling_reminder_emails {
    my ( $self, $domain_id, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run ) = @_;

    my $logs = [];

    # Could be optimized by storing last option time in the event object
    # and queried for only those which have options in the future
    my $events =  $self->_fetch_meetings( {
        where => 'begin_date = 0 AND domain_id = ?',
        value => [ $domain_id ],
    } );

    my %meeting_events = ();
    my %limited_meetings = map { $_ => 1 } ( $limit_to_meetings ? @$limit_to_meetings : () );
    my %limited_users = map { $_ => 1 } ( $limit_to_users ? @$limit_to_users : () );

    for my $event ( @$events ) {
        next if $limit_to_meetings && ! $limited_meetings{ $event->id };

        my $pos = $self->_fetch_meeting_proposals( $event );
        next unless scalar( @$pos );

        # NOTE: for now stop sending when the last proposal passes
        my $last = List::Util::max( map { $_->begin_date } @$pos );
        next if $last < time;

        my $euos = $self->_fetch_meeting_participant_objects( $event );
        for my $euo ( @$euos ) {
            next if $limit_to_users && ! $limited_users{ $euo->user_id };
#            next if $self->_get_note_for_meeting_user( 'disable_emails', $event, $euo->user_id, $euo );

            if ( $wait_seconds ) {
                my $last = $self->_get_note_for_meeting_user( 'scheduling_reminder_sent', $event, $euo->user_id, $euo );
                next if $last && $last > time - $wait_seconds;
            }

            my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $event, $euo->user_id, $euo, $pos );
            next unless scalar @$open_pos;

            $self->_inform( "sending scheduling reminder for ". $event->id ." to user " . $euo->user_id, $logs );
            $self->_send_scheduling_reminder_email( $event, $euo, $open_pos, $dry_run, $logs );

            $self->_set_note_for_meeting_user( 'scheduling_reminder_sent' => time, $event, $euo->user_id, $euo ) unless $dry_run;
        }
    }

    $self->_inform( "done.", $logs );
    return $logs;
}

sub _send_scheduling_reminder_email {
    my ( $self, $meeting, $euo, $open_pos, $dry_run, $logs ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $euo->user_id );
    return unless $user->email;
    my $domain_id = $meeting->domain_id;

    my $users = $self->_fetch_meeting_participant_users( $meeting );
    my $open_timespans = [ map { { timestring => $self->_timespan_for_proposal( $_, $user ) } } @$open_pos ];

    $self->_send_meeting_user_template_mail( $meeting, $user, 'scheduling_reminder', {
        open_scheduling_options => $open_timespans,
        user_name => Dicole::Utils::User->name( $user ),
    } ) unless $dry_run;
}

sub send_pending_rsvp_reminder_emails {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $limit_to_meetings = $self->param('limit_to_meetings');
    my $limit_to_users = $self->param('limit_to_users');
    my $wait_seconds = $self->param('wait_seconds') || 24 * 60 * 60;
    my $dry_run = $self->param('dry_run');

    return $self->_send_pending_rsvp_reminder_emails( $domain_id, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run );
}

sub _send_pending_rsvp_reminder_emails {
    my ( $self, $domain_id, $limit_to_meetings, $limit_to_users, $wait_seconds, $dry_run ) = @_;

    my $logs = [];
    my $time = time;

    # Could be optimized by storing last option time in the event object
    # and queried for only those which have options in the future
    my $events = $self->_fetch_meetings( {
        where => 'begin_date > 0 AND end_date > ? AND domain_id = ?',
        value => [ $time, $domain_id ],
    } );

    my %meeting_events = ();
    my %limited_meetings = map { $_ => 1 } ( $limit_to_meetings ? @$limit_to_meetings : () );
    my %limited_users = map { $_ => 1 } ( $limit_to_users ? @$limit_to_users : () );

    for my $event ( @$events ) {
        next if $limit_to_meetings && ! $limited_meetings{ $event->id };

        my $euos = $self->_fetch_meeting_participant_objects( $event );
        for my $euo ( @$euos ) {
            next if $limit_to_users && ! $limited_users{ $euo->user_id };
#            next if $self->_get_note_for_meeting_user( 'disable_emails', $event, $euo->user_id, $euo );
            next if $euo->created_date + $wait_seconds > $time;

            my $last_sent = $self->_get_note_for_meeting_user( rsvp_reminder_sent => $event, $euo->user_id, $euo );
            next if $last_sent && $last_sent + $wait_seconds > $time;

            my $rsvp_required_parameters = $self->_meeting_user_rsvp_required_parameters( $event, $euo->user_id, $euo );
            next unless $rsvp_required_parameters->{rsvp_required};

            $self->_inform( "sending rsvp reminder for ". $event->id ." to user " . $euo->user_id, $logs );
            $self->_send_rsvp_reminder_email( $event, $euo, $rsvp_required_parameters, $dry_run, $logs );

            $self->_set_note_for_meeting_user( rsvp_reminder_sent => $time, $event, $euo->user_id, $euo ) unless $dry_run;
        }
    }

    $self->_inform( "done.", $logs );
    return $logs;
}

sub _send_rsvp_reminder_email {
    my ( $self, $meeting, $euo, $rsvp_required_parameters, $dry_run, $logs ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $euo->user_id );
    return unless $user->email;
    my $domain_id = $meeting->domain_id;

    $self->_send_meeting_user_template_mail( $meeting, $user, 'rsvp_reminder', {
        %{ $rsvp_required_parameters },
    } ) unless $dry_run;
}

# exclude user checker = sub ($self, $user) -> true if user should NOT be sent an email
# template_params_generator = sub ($self, $user) -> returns {} of params for that user
sub send_campaign_email {
    my ( $self ) = @_;

    my $template_key_base = $self->param('template_key_base') || die;
    my $domain_id = $self->param('domain_id') || die;
    my $partner_id = $self->param('partner_id') || 0;
    my $from = $self->param('from');

    my $limit_to_users = $self->param('limit_to_users');
    my %limit_to_users = map { $_ => 1 } @{ $limit_to_users || [] };
    my $exclude_users = $self->param('exclude_users');
    my %exclude_users = map { $_ => 1 } @{ $exclude_users || [] };

    my $users = $self->param('users');

    if ( ! $users ) {
        my $user_ids = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
        $users = Dicole::Utils::User->ensure_object_list( $user_ids );
    }

    my $sent_count = 0;

    for my $user ( @$users ) {
        next unless $user->email;
        next if $self->param('single_send_limit') && $sent_count >= $self->param('single_send_limit');
        next if $limit_to_users && ! $limit_to_users{ $user->id } && ! $limit_to_users{ $user->email };
        next if $exclude_users && ( $exclude_users{ $user->id } ||  $exclude_users{ $user->email } );
        next if $self->param('exclude_user_checker') && $self->param('exclude_user_checker')->( $self, $user );

        # skip user whose emails have been forwarded
        my $target_user = $self->_fetch_user_for_email( $user->email, $domain_id );
        next unless $target_user && $target_user->id == $user->id;

        # refresh user object to prevent stale information overriding
        $user = $target_user;

        next if $self->_get_note_for_user( 'meetings_mailing_list_disabled', $user, $domain_id );

        my $sent = $self->_get_note_for_user( 'sent_campaign_email_' . $template_key_base, $user, $domain_id );
        next if $sent && ! $self->param('skip_sent_check');

        my $params = $self->param('template_params') || $self->param('template_params_generator')->( $self, $user ) || {};
        my $reply_address = $params->{reply_address} || $self->param('reply_address') || undef;

        print "(dry) " if $self->param('dry_run');
        print ( ( $sent_count + 1 ) . " Sending $template_key_base mail to " . $user->email . "\n" );

        $self->_send_partner_themed_mail(
            user => $user,
            reply_to => $reply_address,
            from => $from,
            domain_id => $domain_id,
            partner_id => $partner_id || 0,
            group_id => 0,

            template_key_base => $template_key_base,
            template_params => $params,
        ) unless $self->param('dry_run');

        $self->_set_note_for_user( 'sent_campaign_email_' . $template_key_base, time, $user, $domain_id ) unless $self->param('dry_run');
        $sent_count++;
    }
}

sub send_trial_ending_emails {
    my ($self) = @_;

    my $domain_id = $self->param('domain_id');
    my $limit     = $self->param('limit');
    my $dry_run   = $self->param('dry_run');

    my $limit_to_users = $self->param('limit_to_users');
    my %limited_users = map { $_ => 1 } ( $limit_to_users ? @$limit_to_users : () );

    my $trials = CTX->lookup_object('meetings_trial')->fetch_group({
        where => 'domain_id = ?',
        value => [ $domain_id ]
    });

    my $processed_users = {};
    my $i = 0;

    for my $trial (@$trials) {
        next if $limit_to_users && ! $limited_users{ $trial->user_id };
        next if $processed_users->{ $trial->user_id }++;

        my $now                   = DateTime->now;
        my $trial_ending_date     = $self->_get_trial_ending_date($trial);
        my $days_until_end = ($trial_ending_date->epoch - $now->epoch) / (24*60*60);
        next if $days_until_end > 7 || $days_until_end < -7;

        my $user = Dicole::Utils::User->ensure_object( $trial->user_id );
        next unless $user->email;
        my $last_trial = $self->_get_user_last_trial( $user, $domain_id, $trials );
        next unless $last_trial;

        ++$i if $self->_maybe_send_trial_ending_email($trial, $domain_id, $self->param('dry_run'), $user );

        last if $limit and $i >= $limit;
    }
}

sub _maybe_send_trial_ending_email {
    my ($self, $trial, $domain_id, $dry_run, $user) = @_;

    $user ||= Dicole::Utils::User->ensure_object($trial->user_id);

    return if $self->_get_note_for_user( 'meetings_mailing_list_disabled', $user, $domain_id );

    my $now                   = DateTime->now;
    my $trial_ending_date     = $self->_get_trial_ending_date($trial);
    my $days_until_trial_ends = ($trial_ending_date->epoch - $now->epoch) / (24*60*60);
    my $trial_has_ended       = $trial_ending_date <= $now;

    return if $days_until_trial_ends > 7;
    return if $days_until_trial_ends > 1 && $self->_get_note_for_user("sent_trial_notification_week_before" => $user, $domain_id );
    return if $days_until_trial_ends > 0 && $self->_get_note_for_user("sent_trial_notification_day_before" => $user, $domain_id );
    return if $trial_has_ended && $self->_get_note_for_user("sent_trial_notification_trial_ended" => $user, $domain_id );

    my $real_user = $self->_fetch_user_for_email( $user->email, $domain_id );
    return unless $real_user && $real_user->user_id == $user->user_id;

    return if $self->_user_is_real_pro( $user, $domain_id );

    my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );

    my $situation = $trial_has_ended
        ? 'trial_ended'
        : $days_until_trial_ends <= 1
            ? 'day_before'
            : 'week_before';

    return if $self->_get_note_for_user("sent_trial_notification_$situation" => $user, $domain_id);

    $self->_set_note_for_user("sent_trial_notification_$situation" => time, $user, $domain_id)
        unless $dry_run;

    print "[DRY] " if $dry_run;
    print "Processed $situation for user_id: " . $trial->user_id . ", email: " . $user->email . ", ends: " . "$trial_ending_date\n";

    my $login_link = $domain_host . Dicole::URL->from_parts(
        domain_id => $domain_id, target => 0,
        action => 'meetings', task => 'upgrade',
    );

    my $unsub_link = $domain_host . Dicole::URL->from_parts(
        domain_id => $domain_id, target => 0,
        action => 'meetings_global', task => 'unsubscribe_from_promo_list',
        params => { reason => 'trial_end' }
    );

    $login_link = $self->_generate_authorized_uri_for_user( $login_link, $user, $domain_id );
    $unsub_link = $self->_generate_authorized_uri_for_user( $unsub_link, $user, $domain_id );

    $self->_send_themed_mail(
        user              => $user,
        domain_id         => $domain_id,
        group_id          => 0,
        template_key_base => 'meetings_trial_end',
        template_params   => {
            $situation      => 1,
            user_name       => Dicole::Utils::User->name($user),
            expiration_date => Dicole::Utils::Date->epoch_to_date_and_time_strings($trial_ending_date->epoch)->[0],
            upgrade_url     => $login_link,
            promo_unsubscribe_url => $unsub_link,
        }
    ) unless $dry_run;

    return 1;
}

sub _user_has_really_used_service {
    my ( $self, $user, $domain_id ) = @_;

    my $meeting_count = $self->_count_user_created_meetings_in_domain( $user, $domain_id );
    return 1 if $meeting_count > 3;

    my $meetings = $self->_fetch_user_created_meetings_in_domain( $user, $domain_id );
    for my $meeting ( @$meetings ) {
        return 1 if $meeting->created_date > time - 14*24*60*60 && ! $self->_meeting_is_draft( $meeting );
    }

    return 0;
}

sub check_campaign_reminders {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id') || die;
    my $user_ids = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
    my $users = Dicole::Utils::User->ensure_object_list( $user_ids );
    my %common_config = (
        domain_id => $domain_id,
        dry_run => $self->param('dry_run'),
        users => $users,
    );

    CTX->lookup_action('meetings_api')->e( send_campaign_email => {
        %common_config,
        template_key_base => 'meetings_beta_accept_reminder',
        template_params_generator => sub {
            my ( $self, $user ) = @_;
            my $params = {};

            return $params;
        },
    } );
}

sub autoinvite_signup_to_beta {
    my ( $self ) = @_;

    my $signup = $self->param('signup');
    my $domain_id = $self->param('domain_id') || $signup->domain_id;

    my $ao = Dicole::Utils::Mail->string_to_address_object( $signup->email );
    my $user = $self->_fetch_or_create_user_for_address_object( $ao, $domain_id );

    my $inviters = $self->_get_note_for_user('meetings_invited_to_beta_by', $user, $domain_id ) || [];

    if ( @{ $inviters } ) {
        $signup->invited_user_id( $user->id );
        $signup->save;
        return;
    }

    $signup->invited_user_id( $user->id );
    $signup->invited_date( time );
    $signup->save;

    my $domain_host = $self->param('domain_host');

    $self->_send_beta_invite_mail_to_user(
         user => $user,
         domain_id => $domain_id,
         domain_host => $domain_host,
         group_id => 0,
         template_key_base => 'meetings_automatic_beta_invite',
    );

    $inviters = [ '-1' ];
    $self->_set_note_for_user( meetings_invited_to_beta_by => $inviters, $user, $domain_id );

    return 1;
}

sub test_dropbox {
    my ( $self ) = @_;
    use Data::Dumper qw(Dumper);

    my $response = $self->_db_call_api( $self->param('user_id'), $self->param('domain_id'), $self->param('url'), $self->param('m') || 'GET', scalar( $self->param('content') ) );

    print Dumper( $response );
}

sub test_linkedin {
    my ( $self ) = @_;
    use Data::Dumper qw(Dumper);

    my $response = $self->_li_call_api( $self->param('user_id'), $self->param('domain_id'), $self->param('url'), $self->param('m') || 'GET', scalar( $self->param('content') ) );

    print Dumper( $response );
}

sub test_google {
    my ( $self ) = @_;
    use Data::Dumper qw(Dumper);

    my $response = $self->_go_call_api( $self->param('user_id'), $self->param('domain_id'), $self->param('url'), $self->param('m') || 'GET', scalar( $self->param('content') ) );

    print Dumper( $response );
}

sub get_partner_for_domain_name {
    my ( $self ) = @_;

    my $domain_name = $self->param('domain_name');
    return unless $domain_name;

    my $partner = $self->PARTNERS_BY_DOMAIN_ALIAS->{ $domain_name };
    return $partner if $partner;

    $domain_name =~ s/\-(staging|beta)\././;
    return $self->PARTNERS_BY_DOMAIN_ALIAS->{ $domain_name };
}

sub get_partner_for_id {
    my ( $self ) = @_;

    my $id = $self->param('id');

    return unless $id;

    return $self->PARTNERS_BY_ID->{ $id };
}

sub check_pending_dropbox_syncs {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $force_full_sync = $self->param('force_full_sync');
    my $after_time = time - ( $self->param('since_hours') || 1 ) * 60 * 60;

    my $users = CTX->lookup_object('user')->fetch_group({
        where => "notes LIKE '%dropbox%'",
    });

    my %user_by_id = map { $_->id => $_ } @$users;
    my %user_last_full_sync = map { $_->id => $self->_get_note_for_user( meetings_dropbox_last_full_sync => $_, $domain_id ) || 0 } @$users;

    for my $user ( @$users ) {
        next if ! $force_full_sync && $user_last_full_sync{ $user->id } + 24*60*60 > time;

        my $now = time;
        eval {
            CTX->lookup_action('meetings_api')->e( sync_user_meetings_with_dropbox => {
                user => $user, domain_id => $domain_id,
            } );
        };
        if ( my $error = $@ ) {
            print STDERR "Error while dropbox full sync for " .  Dicole::Utils::User->name( $user ) . ": " . $error . "\n";
        }
        $self->_set_note_for_user( meetings_dropbox_last_full_sync => $now, $user, $domain_id );
    }

    my $now = time;
    my $events = CTX->lookup_object('event_source_event')->fetch_group( {
        sql => 'select * from dicole_event_source_event where' .
            ' domain_id = ' . $domain_id . ' AND' .
            ' updated > ' . $after_time .
            ' order by updated desc',
    } );

    my %meeting_events = ();
    my %meeting_most_recent_event = ();

    for my $event ( @$events ) {
        next unless $event->classes =~ /meetings/;
        my $data = Dicole::Utils::JSON->decode( $event->payload );
        next unless $data->{meeting_id};
        push @{ $meeting_events{ $data->{meeting_id} } }, $event;
        $meeting_most_recent_event{ $data->{meeting_id} } ||= $event->updated;
    }

    my $meetings = $self->_fetch_meetings( {
        where => Dicole::Utils::SQL->column_in( event_id => [ keys %meeting_events ] ),
    } );

    for my $meeting ( @$meetings ) {
        my $last_user_sync = $self->_get_note_for_meeting( meetings_dropbox_last_user_sync => $meeting );
        next if $last_user_sync && $last_user_sync > $meeting_most_recent_event{ $meeting->id };

        my $mpos = $self->_fetch_meeting_participant_objects( $meeting );
        for my $mpo ( @$mpos ) {
            my $user = $user_by_id{ $mpo->user_id };
            next unless $user;
            next if $user_last_full_sync{ $user->id } > $meeting_most_recent_event{ $meeting->id };

            eval { $self->_sync_user_meeting_with_dropbox( $user, $meeting, { meeting_participation_object => $mpo, force_refresh => $self->param('force_refresh') } ) };

            # NOTE: error must be set to a new variable to pass it to eval
            if ( my $error = $@ ) {
                eval { $self->_db_handle_meeting_error_for_user( $meeting, $error, $user ) };
            }
        }
        $self->_set_note_for_meeting( meetings_dropbox_last_user_sync => $now, $meeting );
    }
}


sub sync_user_meetings_with_dropbox {
    my ( $self ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $self->param('user') || $self->param('user_id') );

    if ( ! $self->_get_note_for_user( meetings_dropbox_access_token => $user, $self->param('domain_id') ) ) {
        print "Dropbox sync not active for ". Dicole::Utils::User->name( $user ) ."\n";
    }

    my $delay = $self->_get_note_for_user( delay_dropbox_sync_until => $user, $self->param('domain_id') );

    if ( ! $self->param('skip_error_delay') && $delay && $delay > time ) {
        print "Dropbox sync delayed for ". Dicole::Utils::User->name( $user ) ."\n";
    }

    my $meetings = $self->_get_user_meetings_in_domain( $user, $self->param('domain_id') );

    print "Dropbox full sync for ". Dicole::Utils::User->name( $user ) .":\n";
    for my $meeting ( @$meetings ) {
        eval { $self->_sync_user_meeting_with_dropbox( $user, $meeting, { skip_user_save => 1, force_refresh => $self->param('force_refresh') } ) };

        # NOTE: error must be set to a new variable to pass it to eval
        if ( my $error = $@ ) {
            eval { $self->_db_handle_meeting_error_for_user( $meeting, $error, $user ) };
        }
    }

    $user->save;
}

sub sync_user_meeting_with_dropbox {
    my ( $self ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $self->param('user') || $self->param('user_id') );
    my $meeting = $self->_ensure_meeting_object( $self->param('meeting') || $self->param('meeting_id') );

    eval { $self->_sync_user_meeting_with_dropbox( $user, $meeting, { force_refresh => $self->param('force_refresh') } ) };

    # NOTE: error must be set to a new variable to pass it to eval
    if ( my $error = $@ ) {
        eval { $self->_db_handle_meeting_error_for_user( $meeting, $error, $user ) };
    }
}

sub _sync_user_meeting_with_dropbox {
    my ( $self, $user, $meeting, $opts ) = @_;

    $opts ||= {};
    $user = Dicole::Utils::User->ensure_object( $user );
    my $uo = $opts->{meeting_participation_object} || $self->_get_user_meeting_participation_object( $user, $meeting );
    return unless $uo;

    my $synced = $self->_get_note_for_meeting_user( dropbox_synced_as => $meeting, $user, $uo );

    print "Starting to sync " . $meeting->title . " for " . Dicole::Utils::User->name( $user) . " (from " . ( $synced->{real_folder_name} || '' ) . ")..\n";
    $synced = $self->_db_create_or_rename_meeting_folder_for_user( $meeting, $user, $synced, $opts );

    my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );
    my $media = $self->_events_api( gather_media_data => { event => $meeting, limit => 999 } );

    for my $material ( @$pages, @$media ) {
        eval {
            $synced = $self->_db_create_or_update_meeting_material_for_user( $meeting, $material, $user, $synced, $opts );
        };
    }

    $self->_set_note_for_meeting_user( dropbox_synced_as => $synced, $meeting, $user, $uo );

    $user->save unless $opts->{skip_user_save};

    print "Done syncing " . $meeting->title . "\n\n";
}

sub _db_create_or_rename_meeting_folder_for_user {
    my ( $self, $meeting, $user, $synced, $opts ) = @_;

    my $target_folder_name = $self->_db_generate_meeting_target_folder_name_for_user( $meeting, $user );

    unless ( $synced->{target_folder_name} && $synced->{target_folder_name} eq $target_folder_name && $self->_db_meeting_folder_exists_for_user( $target_folder_name, $user, $meeting->domain_id, $opts ) ) {
        my $real_folder_name_base = $target_folder_name;
        my $real_folder_name = $real_folder_name_base;

        for my $round ( 2..100 ) {
            last if $synced->{real_folder_name} && $synced->{real_folder_name} eq $real_folder_name;
            last unless $self->_db_meeting_folder_exists_for_user( $real_folder_name, $user, $meeting->domain_id, $opts );

            if ( $round > 99 ) {
                # TODO: report error to user.. and just skip this for now.
                die "Too many meeting folders with the same name!";
            }
            else {
                $real_folder_name = $real_folder_name_base . " $round";
            }
        }

        if ( ! $synced->{real_folder_name} || ! $self->_db_meeting_folder_exists_for_user( $synced->{real_folder_name}, $user, $meeting->domain_id, $opts ) ) {
            print "Creating folder $real_folder_name..\n";
            $self->_db_create_meeting_folder_for_user( $real_folder_name, $user, $meeting->domain_id );
        }
        elsif ( $synced->{real_folder_name} ne $real_folder_name ) {
            print "Renaming folder from " . $synced->{real_folder_name} .  " to $real_folder_name..\n";
            $self->_db_rename_meeting_folder_for_user( $synced->{real_folder_name}, $real_folder_name, $user, $meeting->domain_id );
        }

        $synced->{target_folder_name} = $target_folder_name;
        $synced->{real_folder_name} = $real_folder_name;
    }

    return $synced;
}

sub _db_generate_mid_for_material {
    my ( $self, $material ) = @_;

    return $material->{prese_id} ? 'prese_' . $material->{prese_id} : 'wiki_' . $material->{page_id};
}

sub _db_create_or_update_meeting_material_for_user {
    my ( $self, $meeting, $material, $user, $synced, $opts ) = @_;

    my $mid = $self->_db_generate_mid_for_material( $material );

    my $target_file_name = $self->_db_generate_material_target_file_name( $material, $user );
    my $real_file_name = $synced->{ $mid }->{real_file_name};

    unless ( $real_file_name && $synced->{ $mid }->{target_file_name} eq $target_file_name && $self->_db_meeting_material_file_exists_for_user( $meeting, $real_file_name, $user, $synced, $opts ) ) {
        $real_file_name = $target_file_name;
        for my $round ( 2..10 ) {
            last if $synced->{ $mid }->{real_file_name} && $synced->{ $mid }->{real_file_name} eq $real_file_name;
            last unless $self->_db_meeting_material_file_exists_for_user( $meeting, $real_file_name, $user, $synced, $opts );

            if ( $round > 9 ) {
                die "Too many files with the same name!";
            }
            else {
                $real_file_name = $self->_db_generate_stacking_real_file_name( $target_file_name, $round);
            }
        }
    }

    my $new_size = $self->_fetch_meeting_material_content_byte_size( $meeting, $material );

    # TODO: do we in any situation want to delete files from dropbox?
    return $synced unless $new_size;

    if ( $synced->{ $mid }->{real_file_name} && $synced->{ $mid }->{real_file_name} eq $real_file_name && $self->_db_meeting_material_file_exists_for_user( $meeting, $real_file_name, $user, $synced, $opts ) ) {
        $synced->{ $mid }->{target_file_name} = $target_file_name;
    }
    else  {
        if ( ! $synced->{ $mid }->{real_file_name} || ! $self->_db_meeting_material_file_exists_for_user( $meeting, $synced->{ $mid }->{real_file_name}, $user, $synced, $opts ) ) {
            print "Creating file $real_file_name..\n";
            $self->_db_create_meeting_material_file_for_user( $meeting, $material, $real_file_name, $user, $synced );
        }
        elsif ( $synced->{ $mid }->{real_file_name} ne $real_file_name ) {
            print "Renamed file from " . $synced->{ $mid }->{real_file_name} . " to $real_file_name..\n";
            $self->_db_rename_meeting_material_file_for_user( $meeting, $material, $synced->{ $mid }->{real_file_name}, $real_file_name, $user, $synced );
        }

        $synced->{ $mid }->{target_file_name} = $target_file_name;
        $synced->{ $mid }->{real_file_name} = $real_file_name;
    }

    $self->_db_update_meeting_material_file_for_user( $meeting, $material, $real_file_name, $user, $synced, $new_size );

    return $synced;
}

sub _db_generate_meeting_target_folder_name_for_user {
    my ( $self, $meeting, $user ) = @_;

    my $name = $self->_meeting_title_string( $meeting );

    # Dropbox does not allow these: \ / : ? * < > " |
    $name =~ s/[\\\/\:\?\*\<\>\"\|]/_/g;
    # NOTE: remove everything until we know better what breaks dropbox signatures
    $name =~ s/[^\w\d \_\-\.]/_/g;

    my $ymd = $self->_epoch_to_ymd( $meeting->begin_date, $user );
    $ymd =~ s/\?/0/g;

    return "/" . $ymd . ' ' . $name;
}

sub _db_generate_material_target_file_name {
    my ( $self, $material, $user ) = @_;

    my $name = $material->{title};
    if ( $material->{page_id} ) {
        $name = $self->_strip_tag_from_page_title( $name );
    }

    # TODO: strip some other characters too? :)
    $name =~ s/[\\\/\:\?\*\<\>\"\|]/_/g;
    # NOTE: remove everything until we know better what breaks dropbox signatures
    $name =~ s/[^\w\d \_\-\.]/_/g;

    if ( $material->{page_id} ) {
        $name .= '.html';
    }
    else {
        unless ( $name =~ /\./ ) {
            if ( $material->{attachment_filename} =~ /.*\./ ) {
                my @parts = split( /\./, $material->{attachment_filename} );
                $name = "$name." . pop @parts;
            }
            elsif ( my $mime = $material->{attachment_mime} ) {
                my $ext = Dicole::Utils::MIME->type_to_extension( $mime );
                $name = "$name.$ext" if $ext;
            }
        }
    }

    return $name;
}

sub _db_meeting_folder_exists_for_user {
    my ( $self, $folder_name, $user, $domain_id, $opts ) = @_;

    return $self->_db_meeting_folder_map_for_user( $user, $domain_id, $opts )->{ $folder_name } ? 1 : 0;
}

sub _db_generate_stacking_real_file_name {
    my ( $self, $real_file_name_base, $round ) = @_;

    my @parts = $real_file_name_base =~ /^(.*?)((?:\.[\w\d]{1,4})*)$/;

    return $parts[0] . " $round" . $parts[1];
}

sub _db_meeting_material_file_exists_for_user {
    my ( $self, $meeting, $material_file, $user, $synced, $opts ) = @_;

    return $self->_db_meeting_file_map_for_user( $meeting, $user, $synced, $opts )->{ $material_file } ? 1 : 0;
}

sub _db_create_meeting_folder_for_user {
    my ( $self, $folder_name, $user, $domain_id ) = @_;

    my $response = $self->_db_call_api( $user, $domain_id, 'https://api.dropbox.com/1/fileops/create_folder', POST => {
        root => 'sandbox',
        path => $folder_name,
    } );

    $self->_db_check_error( $response );

    my $new_folders = $self->_get_note_for_user( dropbox_new_folders => $user, $domain_id ) || [];
    my $removed_folders = $self->_get_note_for_user( dropbox_removed_folders => $user, $domain_id ) || [];

    push @$new_folders, $folder_name;
    $removed_folders = [ grep { $_ eq $folder_name ? 0 : 1 } @$removed_folders ];

    $self->_set_note_for_user( dropbox_new_folders => $new_folders, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( dropbox_removed_folders => $removed_folders, $user, $domain_id, { skip_save => 1 } );
}

sub _db_create_meeting_material_file_for_user {
    my ( $self, $meeting, $material, $file_name, $user, $synced ) = @_;

    my $folder = $synced->{real_folder_name};

    my @path_parts = split "/", $folder;
    push @path_parts, $file_name;

    my $encoded_path = join "/", @path_parts;

    my $content = $self->_fetch_meeting_material_content_bits( $meeting, $material );

    # NOTE: Dropbox does not allow creating empty files. Don't know how to handle this better..
    return unless $content;

    my $response = $self->_db_call_api( $user, $meeting->domain_id, 'https://api-content.dropbox.com/1/files_put/sandbox' . $encoded_path, PUT => {
        _content => $content,
    } );

    $self->_db_check_error( $response );

    my $mid = $self->_db_generate_mid_for_material( $material );

    $synced->{ $mid }->{metadata} = Dicole::Utils::JSON->decode( $response->content );
    $synced->{ $mid }->{metadata_updated} = time;

    my $new_files = $synced->{new_files} || [];
    my $removed_files = $synced->{removed_files} || [];

    push @$new_files, $file_name;
    $removed_files = [ grep { $_ eq $file_name ? 0 : 1 } @$removed_files ];

    $synced->{new_files} = $new_files;
    $synced->{removed_files} = $removed_files;
}

sub _db_update_meeting_material_file_for_user {
    my ( $self, $meeting, $material, $file_name, $user, $synced, $new_size ) = @_;

    my $mid = $self->_db_generate_mid_for_material( $material );

    # TODO: better check for this than size. currently preses don't hold an update date
    # so we can not check it against $synced->{ $mid }->{metadata_updated} :(
    $new_size ||= $self->_fetch_meeting_material_content_byte_size( $meeting, $material );

    return () unless $new_size;

    my $old_size = $synced->{ $mid }->{metadata}->{bytes};

    return () if $old_size && $old_size == $new_size;

    my $folder = $synced->{real_folder_name};

    my @path_parts = split "/", $folder;
    push @path_parts, $file_name;

    my $encoded_path = join "/", @path_parts;

    my $now = time;
    my $content = $self->_fetch_meeting_material_content_bits( $meeting, $material );

    # NOTE: Dropbox does not allow creating empty files. Don't know how to handle this better..
    return () unless $content;

    my $response = $self->_db_call_api( $user, $meeting->domain_id, 'https://api-content.dropbox.com/1/files_put/sandbox' . $encoded_path, PUT => {
        _content => $content,
    } );

    $self->_db_check_error( $response );

    $synced->{ $mid }->{metadata} = Dicole::Utils::JSON->decode( $response->content );
    $synced->{ $mid }->{metadata_updated} = $now;

    print "Updated $mid\n";
}

sub _db_rename_meeting_folder_for_user {
    my ( $self, $old_folder_name, $new_folder_name, $user, $domain_id ) = @_;

    my $response = $self->_db_call_api( $user, $domain_id, 'https://api.dropbox.com/1/fileops/move', POST => {
        root => 'sandbox',
        from_path => $old_folder_name,
        to_path => $new_folder_name,
    } );

    $self->_db_check_error( $response );

    my $new_folders = $self->_get_note_for_user( dropbox_new_folders => $user, $domain_id ) || [];
    my $removed_folders = $self->_get_note_for_user( dropbox_removed_folders => $user, $domain_id ) || [];

    push @$removed_folders, $old_folder_name;
    push @$new_folders, $new_folder_name;

    $new_folders = [ grep { $_ eq $old_folder_name ? 0 : 1 } @$new_folders ];
    $removed_folders = [ grep { $_ eq $new_folder_name ? 0 : 1 } @$removed_folders ];

    $self->_set_note_for_user( dropbox_new_folders => $new_folders, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( dropbox_removed_folders => $removed_folders, $user, $domain_id, { skip_save => 1 } );
}

sub _db_rename_meeting_material_file_for_user {
    my ( $self, $meeting, $material, $old_file_name, $new_file_name, $user, $synced ) = @_;

    my $folder = $synced->{real_folder_name};

    my $response = $self->_db_call_api( $user, $meeting->domain_id, 'https://api.dropbox.com/1/fileops/move', POST => {
        root => 'sandbox',
        from_path => "$folder/$old_file_name",
        to_path => "$folder/$new_file_name",
    } );

    $self->_db_check_error( $response );

    my $new_files = $synced->{new_files} || [];
    my $removed_files = $synced->{removed_files} || [];

    push @$removed_files, $old_file_name;
    push @$new_files, $new_file_name;

    $new_files = [ grep { $_ eq $old_file_name ? 0 : 1 } @$new_files ];
    $removed_files = [ grep { $_ eq $new_file_name ? 0 : 1 } @$removed_files ];

    $synced->{new_files} = $new_files;
    $synced->{removed_files} = $removed_files;
}


sub _db_meeting_folder_map_for_user {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $opts ||= {};

    my $metadata = $self->_get_note_for_user( dropbox_sandbox_metadata => $user, $domain_id );
    my $last_updated = $self->_get_note_for_user( dropbox_sandbox_metadata_updated => $user, $domain_id ) || 0;

    # We want to do force refresh really only for the first query in this incovation
    if ( $opts->{force_refresh} && ! $self->param( 'dropbox_force_refreshed_for_' . $user->id ) ) {
        $self->param( 'dropbox_force_refreshed_for_' . $user->id, 1 );
        $last_updated = 0;
    }

    if ( $last_updated + 25*60 < time ) {
        $metadata = $self->_db_fetch_sandbox_metadata_for_user( $user, $domain_id );
    }

    my %metadata_map = map { $_->{path} => 1 } @{ $metadata->{contents} || [] };

    my $new_folders = $self->_get_note_for_user( dropbox_new_folders => $user, $domain_id );
    my $removed_folders = $self->_get_note_for_user( dropbox_removed_folders => $user, $domain_id );

    $metadata_map{ $_ } = 1 for  @{ $new_folders || [] };
    delete $metadata_map{ $_ } for @{ $removed_folders || [] };

    return \%metadata_map;
}

sub _db_meeting_file_map_for_user {
    my ( $self, $meeting, $user, $synced, $opts ) = @_;

    $opts ||= {};

    my $metadata = $synced->{sandbox_metadata};
    my $last_updated = $synced->{sandbox_metadata_updated} || 0;

    # We want to do force refresh really only for the first query in this incovation
    if ( $opts->{force_refresh} && ! $self->param( 'dropbox_force_refreshed_for_' . $meeting->id . '_' . $user->id ) ) {
        $self->param( 'dropbox_force_refreshed_for_' . $meeting->id . '_' . $user->id, 1 );
        $last_updated = 0;
    }

    if ( $last_updated + 25*60 < time ) {
        $metadata = $self->_db_fetch_meeting_sandbox_metadata_for_user( $meeting, $user, $synced );
    }

    my %metadata_map = ();

    my $meeting_folder = $metadata->{path} . '/';
    for my $file_data ( @{ $metadata->{contents} || [] } ) {
        my $path = $file_data->{path};
        if ( index( $path, $meeting_folder ) == 0 ) {
            $path = substr( $path, length( $meeting_folder ) );
        }
        else {
            get_logger(LOG_APP)->error("Unexpectedly folder not found from dropbox file:" . $meeting_folder . ' from ' . $path );
        }
        $metadata_map{ $path } = 1;
    }

    my $new_files = $synced->{new_files};
    my $removed_files = $synced->{removed_files};

    $metadata_map{ $_ } = 1 for  @{ $new_files || [] };
    delete $metadata_map{ $_ } for @{ $removed_files || [] };

    return \%metadata_map;
}


sub _db_fetch_sandbox_metadata_for_user {
    my ( $self, $user, $domain_id ) = @_;

    my $metadata = $self->_get_note_for_user( dropbox_sandbox_metadata => $user, $domain_id );
    my $hash = $metadata ? $metadata->{hash} : '';

    my $response = $self->_db_call_api( $user, $domain_id, 'https://api.dropbox.com/1/metadata/sandbox/', GET => {
        $hash ? ( hash => $hash ) : (),
        list => 1,
    } );

    if ( $response && $response->code eq '200' ) {
        $metadata = Dicole::Utils::JSON->decode( $response->content );
        $self->_set_note_for_user( dropbox_sandbox_metadata => $metadata, $user, $domain_id, { skip_save => 1} );
        $self->_set_note_for_user( dropbox_sandbox_metadata_updated => time, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( dropbox_new_folders => [], $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( dropbox_removed_folders => [], $user, $domain_id, { skip_save => 1 } );
    }
    elsif ( $response && $response->code ne '304' ) {
        $self->_db_check_error( $response );
    }

    return $metadata || {};
}

sub _db_fetch_meeting_sandbox_metadata_for_user {
    my ( $self, $meeting, $user, $synced ) = @_;

    my $metadata = $synced->{sandbox_metadata};
    my $hash = $metadata ? $metadata->{hash} : '';

    my $response = $self->_db_call_api( $user, $meeting->domain_id, 'https://api.dropbox.com/1/metadata/sandbox' . $synced->{real_folder_name}, GET => {
        $hash ? ( hash => $hash ) : (),
        list => 1,
    } );

    if ( $response && $response->code eq '200' ) {
        $metadata = Dicole::Utils::JSON->decode( $response->content );
        $synced->{sandbox_metadata} = $metadata;
        $synced->{sandbox_metadata_updated} = time;
        $synced->{new_files} = [];
        $synced->{removed_files} = [];
    }
    if ( $response && $response->code eq '304' ) {
        $synced->{sandbox_metadata_updated} = time;
    }
    else {
        $self->_db_check_error( $response );
    }

    return $metadata || {};
}

sub _db_call_api {
    my ( $self, $user, $domain_id, $url, $method, $params ) = @_;

    my $o = $self->_dropbox_client( $user, $domain_id );
    return $o->make_restricted_request( $url, $method || 'GET', %{ $params || {} } );
}

sub _db_check_error {
    my ( $self, $response ) = @_;

    unless ( $response && $response->code eq '200' ) {
        die $response;
    }
}

sub _db_handle_meeting_error_for_user {
    my ( $self, $meeting, $response, $user ) = @_;

    use Data::Dumper qw(Dumper);

    unless ( ref( $response ) =~ /response/i ) {
        print STDERR Dumper( [ $response, $meeting, $user ] ) . "\n";
    }

    if ( $response->code == 401 ) {
        $self->_set_note_for_user( meetings_dropbox_access_token => '' => $user, $meeting->domain_id );
        print STDERR "Access token expired for " . Dicole::Utils::User->name( $user ) . "\n";
    }
    else {
        $self->_set_note_for_user( delay_dropbox_sync_until => time + 3600, $user, $meeting->domain_id );
        print STDERR Dumper( [ $response, $meeting, $user ] ) . "\n";
    }
}

sub check_user_startup_status {
    my ( $self ) = @_;

    $self->param('user_list', [ $self->param('user' ) ] );
    return $self->check_user_list_startup_status;
}

sub check_user_list_startup_status {
    my ( $self ) = @_;

    my $startup_domains = $self->_get_startup_domains;
    my $users = Dicole::Utils::User->ensure_object_list( scalar( $self->param('user_list') ) );

    for my $user ( @$users ) {
        $self->_check_user_startup_status( $user, $self->param('domain_id'), $startup_domains );
    }
    return 1;
}

sub check_startup_statuses {
    my ( $self ) = @_;

    $self->_update_startup_domains;

    my $domain_id = $self->param('domain_id');
    my $user_ids = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $self->param('domain_id') } );

    $self->param('user_list', $user_ids );
    return $self->check_user_list_startup_status;
}

sub _check_user_startup_status {
    my ( $self, $user, $domain_id, $startup_domains ) = @_;

    return 0 if CTX->server_config->{dicole}{development_mode};
    return 0; # Disabled for now

    $startup_domains ||= $self->_get_startup_domains;

    my $found = 0;
    for my $domain ( @$startup_domains ) {
        $found = 1 if index( lc($user->email) || '', '@'.lc($domain) ) > 0;
    }

    # TODO: no downgrades yet - maybe never needed
    return 0 unless $found;

    return 1 if $self->_get_note_for_user( startup_pro_enabled => $user, $domain_id );

    $self->_set_note_for_user( startup_pro_enabled => time, $user, $domain_id, { skip_save => 1 } );

    unless ( $self->_get_note_for_user( meetings_beta_pro => $user, $domain_id ) ) {
        $self->_set_note_for_user( meetings_beta_pro => time, $user, $domain_id, { skip_save => 1 } );
    }

    $user->save;

    my $trials = $self->_user_trials( $user, $domain_id );
    for my $trial ( @$trials ) {
        $self->_set_note( pre_startup_duration => $trial->duration_days, $trial, { skip_save => 1 } );
        $trial->duration_days( 9999 );
        $trial->save;
    }

    $self->_calculate_user_is_pro( $user, $domain_id );

    return 1;
}

sub init_google_sync_auth {
    my ( $self ) = @_;

    my $client_id = '584216729178-3l07e654m1uarh2ai6v6u5reaqsbscdc.apps.googleusercontent.com';
    my $google_url = URI::URL->new( 'https://accounts.google.com/o/oauth2/auth' );

    $google_url->query_form( {
        scope => 'https://spreadsheets.google.com/feeds',
        redirect_uri => 'urn:ietf:wg:oauth:2.0:oob',
        response_type => 'code',
        client_id => $client_id,
        state => '',
    } );

    return "Visit this url to gain a code (which you then pass to finish_google_sync_auth): " . $google_url->as_string . "\n";
}

sub finish_google_sync_auth {
    my ( $self ) = @_;

    my $client_id = '584216729178-3l07e654m1uarh2ai6v6u5reaqsbscdc.apps.googleusercontent.com';
    my $secret = 'x';
    my $code = $self->param('code');

    my $result = Dicole::Utils::HTTP->post( 'https://accounts.google.com/o/oauth2/token', {
            code => $code,
            client_id => $client_id,
            client_secret => $secret,
            redirect_uri => 'urn:ietf:wg:oauth:2.0:oob',
            grant_type => 'authorization_code',
        } );

    my $result_data = Dicole::Utils::JSON->decode( $result );

    my $refresh_token = $result_data->{refresh_token};

    return "This is your refresh_token: $refresh_token\n";
}

sub sync_sql_with_id_to_google_docs {
    my ( $self ) = @_;

    my $sql_file = $self->param('sql_file');
    my $sql = $self->param('sql') || ( $sql_file ? `cat $sql_file` : $sql_file );

    die "no sql defined" unless $sql;

    $self->param('result_hashes', Dicole::Utils::SQL->hashes( sql => $sql ) );

    return $self->sync_result_hashes_with_id_to_google_docs();
}

sub sync_result_hashes_with_id_to_google_docs {
    my ( $self ) = @_;
    my $client_id = '584216729178-3l07e654m1uarh2ai6v6u5reaqsbscdc.apps.googleusercontent.com';
    my $secret = 'x';
    my $token = $self->param('refresh_token');
    my $spreadsheet_key = $self->param('spreadsheet_key');
    my $results = $self->param('result_hashes');

    die "You need to pass in a refresh_token (get one from init_google_sync_auth), a spreadsheed_key and results_hashes!\n" unless $token && $spreadsheet_key && $results;

    my $params_array = $self->_array_of_hashes_to_google_docs_params_array( $results, $self->param('time_zone') || $self->param('timezone') );

    return $self->_sync_params_array_to_google_docs( $token, $spreadsheet_key, $params_array );
}

sub _array_of_hashes_to_google_docs_params_array {
    my ( $self, $results, $timezone ) = @_;

    my $params_array = [];
    for my $result ( @$results ) {
        my $params = {};
        for my $key ( keys %$result ) {
            if ( my ( $base ) = $key =~ /(.*)_epoch$/ ) {
                my $tz = $timezone || 'Europe/Helsinki';
                my $dt = Dicole::Utils::Date->epoch_to_datetime( $result->{ $key }, $tz, 'en' );
                my $time = $dt->ymd . ' ' . $dt->hms;
                $params->{"gsx:$base"} = $time;
            }
            else {
                $params->{"gsx:$key"} = $result->{ $key };
            }
        }
        push @$params_array, $params;
    }

    return $params_array;
}

sub sync_db_to_google_docs {
    my ( $self ) = @_;

    my $token = $self->param('refresh_token');
    my $spreadsheet_key = $self->param('spreadsheet_key');
    my $matchmaking_event_id = $self->param('matchmaking_event_id');

    die "You need to pass in a refresh_token (get one from init_google_sync_auth), a spreadsheed_key and a matchmaking_event_id!\n" unless $token && $spreadsheet_key && $matchmaking_event_id;

    my $matchmakers = $self->_fetch_matchmakers_for_event( $matchmaking_event_id );
    my $matchmaker_params_array = [ map { $self->_gather_matchmaker_params( $_ ) } @$matchmakers ];

    return $self->_sync_params_array_to_google_docs( $token, $spreadsheet_key, $matchmaker_params_array );
}

sub _sync_params_array_to_google_docs {
    my ( $self, $token, $spreadsheet_key, $params_array ) = @_;

    my $client_id = '584216729178-3l07e654m1uarh2ai6v6u5reaqsbscdc.apps.googleusercontent.com';
    my $secret = 'x';

    my $result = Dicole::Utils::HTTP->post( 'https://accounts.google.com/o/oauth2/token', {
            refresh_token => $token,
            client_id => $client_id,
            client_secret => $secret,
            grant_type => 'refresh_token',
        } );

    my $result_data = Dicole::Utils::JSON->decode( $result );

    my $access_token = $result_data->{access_token};
    my $token_type = $result_data->{token_type};

    my $ws_xml = `curl -s -H 'Authorization: $token_type $access_token' 'https://spreadsheets.google.com/feeds/worksheets/$spreadsheet_key/private/full'`;

    my $ws_data = XML::Simple->new( ForceArray => 1 )->XMLin( $ws_xml );
    my $links = $ws_data->{entry}->[0]->{link};

    my ( $listfeed_link ) = grep { $_->{rel} eq 'http://schemas.google.com/spreadsheets/2006#listfeed' } @$links;
    $listfeed_link = $listfeed_link->{href};

    my $listfeed_xml = `curl -s -H 'Authorization: $token_type $access_token' '$listfeed_link'`;
    my $listfeed_data = XML::Simple->new( ForceArray => 1 )->XMLin( $listfeed_xml );

    my ( $post_link ) = grep { $_->{rel} eq 'http://schemas.google.com/g/2005#post' } @{ $listfeed_data->{link} };
    $post_link = $post_link->{href};

    my $rows = $self->_google_listfeed_to_array_of_hashes( $listfeed_data );
    my $rows_by_id = { map { $_->{'gsx:id'} => $_ } @$rows };

    for my $params ( @$params_array ) {
        my $old = $rows_by_id->{ $params->{'gsx:id'} };
        next if $old && ! $self->_identify_changed_rows( $params, $old );

        $params->{id} = $old->{id} if $old;

        my $payload = $self->_generate_google_listfeed_entry( $params );
        $payload =~ s/'/'"'"'/g;

        if ( $old ) {
            my $edit_link = $old->{edit_link};
            `curl -s -X PUT -d '$payload' -H 'Content-Type: application/atom+xml' -H 'Authorization: $token_type $access_token' '$edit_link'`;
        }
        else {
            `curl -s -X POST -d '$payload' -H 'Content-Type: application/atom+xml' -H 'Authorization: $token_type $access_token' '$post_link'`;
        }
    }
}

sub _identify_changed_rows {
    my ( $self, $new, $old ) = @_;

    my @changed = ();
    for my $key ( keys %$new ) {
        my $old_key = $old->{ $key } || '';
        $old_key =~ s/^\'0/0/;

        my $new_key = $new->{ $key } || '';
        $new_key =~ s/^\'0/0/;

        next if $new_key eq $old_key;

        push @changed, $key;
    }
    return @changed;
}

sub _gather_matchmaker_params {
    my ( $self, $m ) = @_;

    my $creator = Dicole::Utils::User->ensure_object( $m->creator_id );
    my $track = $self->_get_note( track => $m ) || '';
    my $market_list = $self->_get_note( market_list => $m ) || [];

    return {
        'gsx:id' => $m->id,
        'gsx:description' => $m->description,
        'gsx:website' => $m->website,
        'gsx:organization' => $m->name,
        'gsx:email' => $creator->email,
        'gsx:firstname' => $creator->first_name,
        'gsx:lastname' => $creator->last_name,
        'gsx:track' => $track,
        'gsx:marketlist' => join( ", ", @$market_list) || '',
        'gsx:validated' => $m->validated_date ? 'yes' : 'no',
        'gsx:active' => $m->disabled_date ? 'no' : 'yes',
    };
}

sub _fetch_matchmakers_for_event {
    my ( $self, $matchmaking_event_id ) = @_;

    return CTX->lookup_object('meetings_matchmaker')->fetch_group({
        where => 'matchmaking_event_id = ?',
        value => [ $matchmaking_event_id ],
    });
}

sub _google_listfeed_to_array_of_hashes {
    my ( $self, $listfeed_data ) = @_;

    my $entries = $listfeed_data->{entry} || [];
    my $array = [];

    for my $e ( @$entries ) {
        my $hash = {};
        my $save = 0;
        for my $key ( keys %$e ) {
            my ( $realkey ) = $key =~ /^(gsx\:.*)/;
            next unless $realkey;
            next if ref ( $e->{ $key }->[0] );
            $hash->{ $realkey } = Dicole::Utils::Text->ensure_utf8( $e->{ $key }->[0] );
            $save = 1;
        }

        if ( $save ) {
            my ( $link ) = grep { $_->{rel} eq 'edit' } @{ $e->{link} };

            $hash->{edit_link} = Dicole::Utils::Text->ensure_utf8( $link->{href} );
            $hash->{id} =Dicole::Utils::Text->ensure_utf8(  $e->{id}->[0] );

            push @$array, $hash;
        }
    }

    return $array;
}

sub _generate_google_listfeed_entry {
    my ( $self, $params ) = @_;

    my $output = '';
    my $writer = XML::Writer->new( OUTPUT => \$output );

    $writer->startTag("entry", xmlns => "http://www.w3.org/2005/Atom", "xmlns:gsx" => "http://schemas.google.com/spreadsheets/2006/extended");

    if ( $params->{id} ) {
        $writer->dataElement( id => Dicole::Utils::Text->ensure_internal( $params->{id} ) );
    }

    for my $key ( keys ( %$params ) ) {
        next unless $key =~ /^gsx\:/;
        my $val = $params->{ $key };
        $val = "'$val" if $val =~ /^0\d*$/;
        $writer->dataElement( $key => Dicole::Utils::Text->ensure_internal( $val ) );
    }

    $writer->endTag("entry");
    $writer->end();

    return $output;
}

sub import_user_google_calendars_to_suggestion_sources {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $user = Dicole::Utils::User->ensure_object( $self->param('user') || $self->param('user_id') );
    die unless $user;

    return unless $self->_user_has_connected_google( $user, $domain_id );

    my $data = $self->_fetch_user_calendar_list_from_google( $user, $domain_id, { force_reload => $self->param('force_reload') } );

    my $sources = [];

    for my $item ( @{ $data->{items} } ) {
        my $id = Dicole::Utils::Text->ensure_utf8( $item->{id} );
        my $name = Dicole::Utils::Text->ensure_utf8( $item->{summary} );
        my $primary = $item->{primary} ? 1 : 0;
        push @$sources, {
            uid => 'google:' . $id,
            name => $name,
            notes => {
                google_calendar_id => $id,
                google_calendar_is_primary => $primary,
            },
        };
    }

    $self->_set_user_suggestion_sources_for_provider(
        $user, $domain_id, $sources, 'google', 'google', 'Google Calendar'
    );
}

sub import_user_primary_google_calendar_to_suggestions {
    my ( $self ) = @_;

    $self->param( calendar_id => 'primary' );

    return $self->import_user_google_calendar_to_suggestions;
}

sub import_user_google_calendar_to_suggestions {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $user = Dicole::Utils::User->ensure_object( $self->param('user') || $self->param('user_id') );
    die unless $user;

    return unless $self->_user_has_connected_google( $user, $domain_id );

    my $from = Dicole::Utils::Date->datetime_to_day_start_datetime(
        Dicole::Utils::Date->epoch_to_datetime( time - 24*60*60, 'UTC', $user->language )
    );

    my $to = Dicole::Utils::Date->datetime_to_day_start_datetime(
        Dicole::Utils::Date->epoch_to_datetime( time + 3*30*24*60*60, 'UTC', $user->language )
    );

    my $source_uid = 'google:' . $self->param('calendar_id');

    my $data = $self->_fetch_user_upcoming_events_from_google_calendar( $user, $domain_id, $self->param('calendar_id'), { force_reload => $self->param('force_reload'), start_epoch => $from->epoch, end_epoch => $to->epoch } );

    return unless $data && $data->{items};

    if ( ! @{ $data->{items} } ) {
        return $self->_vanish_user_calendar_suggestions_within_dates_which_are_missing_from_list(
            $user, $domain_id, $source_uid, $from->epoch, $to->epoch, []
        );
    }

    # NOTE: this takes a while so events are fetched before this - thus in case event fetching dies with an error, this function should be fairly fast
    my ( $suggestions, $suggestion_by_uid, $suggestions_by_begin ) = $self->_compile_user_suggestion_lookups( $user, $domain_id );
    my $previous_sources = $self->_get_user_suggestion_sources( $user, $domain_id );

    my $ensured_suggestions = [];
    for my $item ( @{ $data->{items} } ) {
        # This is the keyword for event whivh are marked as "Svailable" instead of "Busy"
        next if $item->{transparency} && $item->{transparency} eq 'transparent';

        my $start = $item->{start}{dateTime};
        my $end = $item->{end}{dateTime};
        my $start_epoch = eval { Date::Parse::str2time( $start ) };
        my $end_epoch = eval { Date::Parse::str2time( $end ) };

        my $s = {
            domain_id => $domain_id,
            user_id => $user->id,

            uid => $item->{id} ? $item->{id} . '@google.com' : '',

            begin_date => $start_epoch,
            end_date => $end_epoch,

            title => Dicole::Utils::Text->ensure_utf8( $item->{summary} || '' ),
            description => Dicole::Utils::Text->ensure_utf8( $item->{description} || '' ),
            location => Dicole::Utils::Text->ensure_utf8( $item->{location} || '' ),

            source => $source_uid,

#           created_date => 0, # not updated, set later when saving for the first time
#           removed_date => 0,
#           disabled_date => 0,
        };

        my $organizer = '';
        my @attendees = ();

        for my $atd ( @{ $item->{attendees} || [] } ) {
            my $name = Dicole::Utils::Text->ensure_utf8( $atd->{displayName} );
            my $email = Dicole::Utils::Text->ensure_utf8( $atd->{email} );
            my $string = Dicole::Utils::Mail->form_email_string( $email, $name );

            push @attendees, $string;

            if ( $atd->{rel} && ( $atd->{rel} eq 'organizer' ) ) {
                $organizer = $string;
            }
        }

        $s->{participant_list} = join( ", ", @attendees );
        $s->{organizer} = $organizer || '';

        if ( my $grid = Dicole::Utils::Text->ensure_utf8( $item->{recurringEventId} || '' ) ) {
            $s->{notes} = { google_recurring_event_id => $grid };
        }

        $s->{notes} = {
            %{ $s->{notes} || {} },
            source_uid => $source_uid,
            source_name => Dicole::Utils::Text->ensure_utf8( $data->{summary} || '' ),
            source_provider_id => 'google',
            source_provider_type => 'google',
            source_provider_name => 'Google Calendar',
            source_notes => { google_calendar_id => $self->param('calendar_id') },
        };

        my $ensured_suggestion = $self->_ensure_user_calendar_suggestion_exists(
           $user, $domain_id, $s, $suggestions, $suggestion_by_uid, $suggestions_by_begin, $previous_sources
        );

        push @$ensured_suggestions, $ensured_suggestion || ();
    }

    $self->_vanish_user_calendar_suggestions_within_dates_which_are_missing_from_list(
        $user, $domain_id, $source_uid, $from->epoch, $to->epoch, $ensured_suggestions
    );
}

sub _compile_user_suggestion_lookups {
    my ( $self, $user, $domain_id ) = @_;

    my $cutoff_date = time - 60*60*24*2;
    my $suggestions = $self->_get_user_meeting_suggestions( $user, $domain_id, "begin_date > $cutoff_date" );
    my $suggestion_by_uid = { map { $_->uid ? ( $_->uid => $_ ) : () } @$suggestions };

    my $suggestions_by_begin = {};
    for my $sugg ( @$suggestions ) {
        my $list = $suggestions_by_begin->{ $sugg->begin_date } ||= [];
        push @$list, $sugg;
    }

    return ( $suggestions, $suggestion_by_uid, $suggestions_by_begin );
}

sub sync_event_users_with_gapier {
    my ( $self ) = @_;

    my $events = CTX->lookup_object('meetings_matchmaking_event')->fetch_group({});
    my $gapier_host = CTX->server_config->{dicole}->{gapier_host} || 'https://meetings-gapier.appspot.com/';
    my $gapier_url = $gapier_host . 'add_or_update_row';
    for my $event ( @$events ) {
        my $token = $self->_get_note( users_gapier_token => $event );
        next unless $token;
        my $data_list = $self->_gather_matchmaking_event_users_data_list( $event );
        for my $set_data ( reverse @$data_list ) {
            my $match_data = { 'TOKEN' => delete $set_data->{'TOKEN'} };
            my $match_json = Dicole::Utils::JSON->encode( $match_data );
            my $set_json = Dicole::Utils::JSON->encode( $set_data );
            $set_json =~ s/'/'"'"'/g;
            print "Updating Meeting ID $match_json ...\n";
            print "curl $gapier_url -s --data-urlencode 'worksheet_token=$token' --data-urlencode 'match_json=$match_json' --data-urlencode 'set_json=$set_json'\n";
            print `curl $gapier_url -s --data-urlencode 'worksheet_token=$token' --data-urlencode 'match_json=$match_json' --data-urlencode 'set_json=$set_json'`;
            print "\n\n";
        }
    }
}

sub sync_event_reservations_with_gapier {
    my ( $self ) = @_;

    my $events = CTX->lookup_object('meetings_matchmaking_event')->fetch_group({});
    my $gapier_host = CTX->server_config->{dicole}->{gapier_host} || 'https://meetings-gapier.appspot.com/';
    my $gapier_url = $gapier_host . 'add_or_update_row';
    for my $event ( @$events ) {
        my $token = $self->_get_note( reservations_gapier_token => $event );
        next unless $token;

        my $data_list = $self->_gather_matchmaking_event_meetings_data_list( $event );
        my $id_list = [ map { $_->{'Meeting ID'} } @$data_list ];

        for my $set_data ( reverse @$data_list ) {
            my $match_data = { 'Meeting ID' => delete $set_data->{'Meeting ID'} };
            my $match_json = Dicole::Utils::JSON->encode( $match_data );
            my $set_json = Dicole::Utils::JSON->encode( $set_data );
            $set_json =~ s/'/'"'"'/g;
            print "Updating Meeting ID $match_json ...\n";
            print "curl $gapier_url -s --data-urlencode 'worksheet_token=$token' --data-urlencode 'accept_staleness=300' --data-urlencode 'match_json=$match_json' --data-urlencode 'set_json=$set_json'\n";
            print `curl $gapier_url -s --data-urlencode 'worksheet_token=$token' --data-urlencode 'accept_staleness=300' --data-urlencode 'match_json=$match_json' --data-urlencode 'set_json=$set_json'`;
            print "\n\n";
        }
    }
}

sub sync_full_run {
    my ( $self ) = @_;

    my $stash = $self->_sync_create_stash();

    return $self->_sync_full_run( $stash, 'current' );
}

sub _sync_full_run {
    my ( $self, $stash, $generation ) = @_;

    $generation ||= 'pending';
    $stash->{processed} = { calendars => {}, users => {}, offices => {}, };

    $self->_sync_ensure_stash_partners( $stash, 'lahixcustxz', Dicole::Utils::Text->ensure_internal( 'Lähixcustxz' ) );

    if ( $generation eq 'current' && ! $stash->{skip_generation_copy} ) {
        $self->_copy_agent_object_state_to_generation( $stash, 'pending', 'current' );

        my $ymd = Dicole::Utils::Date->epoch_to_datetime( time, 'Europe/Helsinki', 'en' )->ymd('-');
        $self->_copy_agent_object_state_to_generation( $stash, 'current', $ymd );
    }

    $self->_fill_lt_stash_data( $stash );
    $self->_fill_agent_object_stash_from_db( $stash, $generation );

    $self->_sync_process_partners( $stash );

    my $partner = $self->PARTNERS_BY_ID->{ $stash->{partner_id} };

    for my $area ( @{ $self->_get_note( all_areas => $partner ) } ) {
        $self->_fill_agent_object_stash_from_db( $stash, $generation, $area->{id} );
        $self->_sync_process_changed_emails( $stash );
        $self->_sync_ensure_manage_user_exists( $stash, $area );
        $self->_sync_ensure_user_processed( $stash, $_ ) for sort values %{ $stash->{users} };
    }

    $self->_sync_finalize_process( $stash );
}

sub _sync_create_stash {
    my ( $self, $stash ) = @_;

    $stash ||= {};
    $stash->{domain_id} ||= $self->param('domain_id');
    $stash->{partner_id} ||= $self->param('partner_id');
    $stash->{dry_run} ||= $self->param('dry_run');
    $stash->{limit_to_users} ||= $self->param('limit_to_users');
    $stash->{skip_generation_copy} ||= $self->param('skip_generation_copy');
    $stash->{override_agenda_changes} ||= $self->param('override_agenda_changes');

    die unless $stash->{domain_id};

    return $stash;
}

sub sync_get_current_stash {
    my ( $self ) = @_;

    my $stash = $self->_sync_create_stash();
    $self->_sync_ensure_stash_partners( $stash, 'lahixcustxz', Dicole::Utils::Text->ensure_internal( 'Lähixcustxz' ) );
    $self->_fill_agent_object_stash_from_db( $stash, 'current', '', { skip_translations => 1 } );

    return $stash;
}

sub _sync_ensure_stash_partners {
    my ( $self, $stash, $partner_domain_part, $partner_name ) = @_;
    my $domain_id = $stash->{domain_id};

    my $partner_domain_root = $partner_domain_part;
    my $partner_domain_suffix = '';

    if ( $domain_id == 76 ) {
        $partner_domain_suffix = '-dev';
    }

    my $partner_map = {};
    for my $p_type ( qw( normal admin ) ) {
        my $admin_fix = $p_type =~ /ad/ ? '-admin' : '';
        my $p_domain = join "", $partner_domain_root, $admin_fix, $partner_domain_suffix, '.meetin.gs';
        my $p_object = $self->PARTNERS_BY_DOMAIN_ALIAS->{ $p_domain };

        if ( ! $p_object ) {
            $p_object = CTX->lookup_object('meetings_partner')->new( {
                domain_id => $domain_id,
                creator_id => 0,
                creation_date => time,
                api_key => '',
                domain_alias => $p_domain,
                localization_namespace => $p_domain,
                name => $partner_name,
                notes => '',
            } );

            $p_object->save unless $stash->{dry_run};
            $stash->{touched_objects}->{partner}->{ $p_object->id } = $p_object;

            $self->PARTNERS_BY_DOMAIN_ALIAS->{ $p_domain } = $p_object;
            $self->PARTNERS_BY_ID->{ $p_object->id } = $p_object;
        }

        $partner_map->{ $p_type } = $p_object;
    }

    $stash->{partner_id} = $partner_map->{normal}->id;
    $stash->{partner_domain_root} = $partner_domain_root;
    $stash->{admin_partner_id} = $partner_map->{admin}->id;
}

sub _sync_generate_admin_email_for_area {
    my ( $self, $stash, $area ) = @_;

    return $stash->{partner_domain_root} . '-admin+' . $area->{id} . '@meetin.gs';
}

sub _sync_process_partners {
    my ( $self, $stash ) = @_;

    my $domain_id = $stash->{domain_id};
    my $partner = $self->PARTNERS_BY_ID->{ $stash->{partner_id} };
    my $partner_for_admin = $self->PARTNERS_BY_ID->{ $stash->{admin_partner_id} };

    my $all_areas = $stash->{all_areas} || $self->_get_note( all_areas => $partner, { skip_save => 1 } );
    my $all_languages = $stash->{all_languages} || $self->_get_note( all_languages => $partner, { skip_save => 1 } );
    my $all_service_levels = $stash->{all_service_levels} || $self->_get_note( all_service_levels => $partner, { skip_save => 1 } );
    my $all_meeting_types = $stash->{all_meeting_types} || $self->_get_note( all_meeting_types => $partner, { skip_save => 1 } );

    $self->_set_note( all_areas => $all_areas, $partner, { skip_save => 1 } );
    $self->_set_note( all_languages => $all_languages, $partner, { skip_save => 1 } );
    $self->_set_note( all_service_levels => $all_service_levels, $partner, { skip_save => 1 } );
    $self->_set_note( all_meeting_types => $all_meeting_types, $partner, { skip_save => 1 } );

    $self->_set_note( from_email => '"' . $partner->name . '" <notifications@meetin.gs>', $partner, { skip_save => 1 } );
    $self->_set_note( body_classes => 'partner_lt', $partner, { skip_save => 1 } );
    $self->_set_note( hide_app_promotion => 1, $partner, { skip_save => 1 }  );
    $self->_set_note( disable_advertisements => 1, $partner, { skip_save => 1 } );
    $self->_set_note( track_visitors => 1, $partner, { skip_save => 1 }  );
    $self->_set_note( visitor_logo_link => 'http://lahixcustxz.fi/', $partner, { skip_save => 1 }  );
    $self->_set_note( agent_booking_data_url => 'http://versions.meetin.gs/ltcache/reps.json', $partner, { skip_save => 1 }  );
    $self->_set_note( agent_booking_office_data_url => 'http://versions.meetin.gs/ltcache/offices.json', $partner, { skip_save => 1 }  );

    $self->_set_note( override_pro_themes => 1, $partner, { skip_save => 1 }  );
    $self->_set_note( pro_theme_header_image => "https://media.dicole.net/meetings_logos/lahixcustxz.png", $partner, { skip_save => 1 }  );

    if ( $partner->domain_alias =~ /dev/ ) {
        $self->_set_note( agent_booking_demoify_emails => 1, $partner, { skip_save => 1 }  );
    }

    $self->_set_note( saml2_provider => 'lahixcustxz', $partner, { skip_save => 1 }  );
    $self->_set_note( saml2_limit_ip_list => ['193.209.71.2'], $partner, { skip_save => 1 }  );

    $self->_set_note( admin_partner_domain => $partner_for_admin->domain_alias, $partner, { skip_save => 1 }  );

    my $non_visitor_emails_map = {};
    my $admin_emails_map = {};
    for my $rephash ( values %{ $stash->{users_by_area} } ) {
        for my $rep ( values %$rephash ) {
            my $rep_email = $rep->{changed_email} || $rep->{email};
            $non_visitor_emails_map->{ $rep_email }++;
            $admin_emails_map->{ $rep_email }++ if $rep->{booking_rights};
        }
    }

    my $non_visitor_emails = [ sort keys %$non_visitor_emails_map ];
    my $admin_emails = [ sort keys %$admin_emails_map ];

    $self->_set_note( non_visitor_emails => $non_visitor_emails, $partner, { skip_save => 1 } );
    $self->_set_note( booker_emails => $admin_emails, $partner, { skip_save => 1 } );

    my $shared_account_emails = [];
    for my $area ( @$all_areas ) {
        next if $area->{skip_manage};
        push @$shared_account_emails, $self->_sync_generate_admin_email_for_area( $stash, $area );
    }

    $self->_set_note( shared_admin_accounts => $shared_account_emails, $partner, { skip_save => 1 }  );

    $partner->save unless $stash->{dry_run};
    $stash->{touched_objects}->{partner}->{ $partner->id } = $partner;

    $self->_set_note( admin_return_domain => $partner->domain_alias, $partner_for_admin, { skip_save => 1 }  );
    $self->_set_note( body_classes => 'partner_lt partner_lt_admin', $partner_for_admin, { skip_save => 1 } );
    $self->_set_note( hide_app_promotion => 1, $partner_for_admin, { skip_save => 1 }  );
    $self->_set_note( disable_advertisements => 1, $partner_for_admin, { skip_save => 1 } );
    $self->_set_note( override_pro_themes => 1, $partner_for_admin, { skip_save => 1 }  );
    $self->_set_note( pro_theme_header_image => "https://media.dicole.net/meetings_logos/lahixcustxz.png", $partner_for_admin, { skip_save => 1 }  );
    $self->_set_note( track_visitors => 1, $partner_for_admin, { skip_save => 1 }  );

    $partner_for_admin->save unless $stash->{dry_run};
    $stash->{touched_objects}->{partner}->{ $partner_for_admin->id } = $partner_for_admin;
}

sub _sync_check_if_user_should_be_updated {
    my ( $self, $stash, $user ) = @_;

    return 0 unless $user->{email};
    return 0 if $stash->{limit_to_users} && ! $stash->{limit_to_users}->{ lc( $user->{email} ) };
    return 0 if $stash->{skip_users} && $stash->{skip_users}->{ lc( $user->{email} ) };
    return 1;
}

sub _sync_update_common_and_pending_agent_object_attributes_in_place {
    my ( $self, $stash, $item, $attributes ) = @_;

    my $objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
        where => 'domain_id = ? AND partner_id = ? AND generation IN ("current","pending") AND area = ? AND model = ? AND uid = ?',
        value => [ $stash->{domain_id}, $stash->{partner_id}, $item->{area}, $item->{model}, $item->{uid} ],
    } );

    for my $attr ( keys %$attributes ) {
        my $value = $attributes->{ $attr };

        if ( defined $value ) {
            $item->{ $attr } = $value;
        }
        else {
            delete $item->{ $attr };
        }
    }

    for my $existing ( @$objects ) {
        my $data = Dicole::Utils::JSON->decode( $existing->payload );
        for my $attr ( keys %$attributes ) {
            my $value = $attributes->{ $attr };

            if ( defined $value ) {
                $data->{ $attr } = $value;
            }
            else {
                delete $data->{ $attr };
            }

            if ( $attr eq 'uid' && $existing->generation eq 'current' ) {
                $data->{previous_uid} = $existing->uid;
            }
        }

        $existing->{ $_ } = $data->{ $_ } for qw(area model uid);

        my $new_payload = Dicole::Utils::JSON->encode( $data );
        $existing->{payload} = $new_payload;

        $existing->save;
    }
}

sub _sync_process_changed_emails {
    my ( $self, $stash ) = @_;
    my $domain_id = $stash->{domain_id};

    for my $rep ( values %{ $stash->{users} } ) {
        next unless $self->_sync_check_if_user_should_be_updated( $stash, $rep );

        if ( my $new_email = $rep->{changed_email} ) {
            my $old_email = $rep->{email};
            next if $new_email eq $old_email;

            my $user = $self->_fetch_user_for_email( $old_email, $domain_id );
            my $new_user = $self->_fetch_user_for_email( $new_email, $domain_id );

            if ( $user && $new_user && $user->id != $new_user->id ) {
                print "WARNING: Could not change user " . $rep->{email} ." email to $new_email because an user with this email already exists!\n";
                next;
                # TODO: maybe force migration here?
            }

            if ( $user ) {
                print "NOTE: Altering changed email $old_email to $new_email\n";
                $user->login_name( $new_email ) if $user->login_name eq $user->email;
                $user->email( $new_email );
                $user->save unless $stash->{dry_run};
                $stash->{touched_objects}->{user}->{ $user->id } = $user;
            }

            for my $cal ( values %{ $stash->{calendars} } ) {
                next unless $rep->{email} eq $cal->{user_email};

                delete $stash->{calendars}->{ $cal->{uid} };

                $self->_sync_update_common_and_pending_agent_object_attributes_in_place( $stash, $cal, {
                    uid => $cal->{office_full_name} . ' ' . $new_email,
                    user_email => $new_email,
                } );

                $stash->{calendars}->{ $cal->{uid} } = $cal;
            }

            delete $stash->{users}->{ $rep->{uid} };

            $self->_sync_update_common_and_pending_agent_object_attributes_in_place( $stash, $rep, {
                uid => $new_email,
                email => $new_email,
                changed_email => undef,
            } );

            $stash->{users}->{ $rep->{uid} } = $rep;
        }
    }
}

sub _sync_process_office {
    my ( $self, $stash, $office ) = @_;

    for my $cal ( values %{ $stash->{calendars} } ) {
        next if $cal->{office} != $office->{uid};
        $self->_sync_ensure_calendar_processed( $stash, $cal );
    }
}

sub _sync_ensure_calendar_processed {
    my ( $self, $stash, $calendar ) = @_;

    return if $stash->{processed}->{calendars}->{ $calendar->{uid} };

    $self->_sync_process_calendar( $stash, $calendar );
}

sub _sync_process_calendar {
    my ( $self, $stash, $cal ) = @_;

    my $domain_id = $stash->{domain_id};
    my $partner_id = $stash->{partner_id};

    $stash->{processed}->{calendars}->{ $cal->{uid} } = 1;

    $self->_sync_ensure_user_processed( $stash, $stash->{users}->{ $cal->{user_email} }, { skip_calendars => 1 } );

    my $rep = $stash->{users}->{ $cal->{user_email} };
    my $office = $stash->{offices}->{ $cal->{office_full_name} };

    if ( ! $rep ) {
        print "WARNING: skiping update for calendar because rep was not found: " . $cal->{uid} . "\n";
        return;
    }

    if ( ! $office ) {
        print "WARNING: skiping update for calendar because office was not found: " . $cal->{uid} . "\n";
        return;
    }

    my $user = $self->_fetch_user_for_email( $cal->{user_email}, $domain_id );
    my $area = $stash->{areas_by_id}->{ $cal->{area} };

    my $hidden_users = [];
    push @$hidden_users, $rep->{supervisor} if $rep->{supervisor};
    push @$hidden_users, $self->_sync_generate_admin_email_for_area( $stash, $area );
    $hidden_users = [ sort @$hidden_users ];

    # TODO: magic
    my $types = $self->_get_partner_agent_booking_types( $partner_id );
    my $user_matchmakers = $self->_fetch_user_matchmakers( $user, $domain_id );
    my $mmrs_by_path = { map { $_->vanity_url_path => $_ } @$user_matchmakers };

    my $variations = [];
    for my $type ( @$types ) {
        for my $lang ( qw( english svenska suomi ) ) {
            for my $level ( 'etutaso0-1', 'etutaso2-4' ) {
                my $really_found = 1;
                $really_found = 0 unless $cal->{meeting_types_map}->{ $type->{id} };
                $really_found = 0 unless $cal->{languages_long_map}->{ $lang };
                $really_found = 0 unless $cal->{service_levels_map}->{ $level };
                push @$variations, { type => $type, lang => $lang, level => $level, found => $really_found };
            }
        }
    }

    for my $variation ( @$variations ) {
        my $type = $variation->{type};
        my $lang = $variation->{lang};
        my $level = $variation->{level};
        my $shortlang = { suomi => 'fi', svenska => 'sv', english => 'en' }->{$lang};

        # TODO: limit
        #    next if $limit_to_mmr && ( $limit_to_mmr ne $type->{name} );

        my $name = Dicole::Utils::Text->ensure_utf8( $stash->{translation_map}->{$lang}->{ Dicole::Utils::Text->ensure_utf8( $type->{name} ) } || $type->{name} );

        my $name_without_level = $name;

        $name .= ' (0-1)' if $level =~ /1/;
        $name .= ' (2-4)' if $level =~ /2/;

        if ( $rep->{calendar_count} > 1 ) {
            $name .= ' ' . $office->{name};
        }

        my $path_office_name = lc( $cal->{office_full_name} );
        $path_office_name =~ s/[^a-z]//g;

        my $path = join( "-", $level, $type->{path}, $path_office_name, $lang );

        my $mmr = $mmrs_by_path->{ $path };
        if ( $mmr && ! $mmr->disabled_date && ! $variation->{found} ) {
            print "Disabling " . $rep->{email} . " ---> " . Dicole::Utils::Text->ensure_utf8( $name ) . "\n";

            $mmr->disabled_date( time );
            $mmr->save;
            $stash->{touched_objects}->{mmr}->{ $mmr->id } = $mmr;
        }

        next unless $variation->{found};

        print "Updating " . $rep->{email} . " ---> " . Dicole::Utils::Text->ensure_utf8( $name ) . "\n";

        if ( ! $mmr ) {
            $mmr = CTX->lookup_object('meetings_matchmaker')->new( {
                domain_id => $domain_id,
                partner_id => $partner_id,
                creator_id => $user->id,
                matchmaking_event_id => 0,
                logo_attachment_id => 0,
                allow_multiple => 0,
                created_date => time,
                validated_date => time,
                disabled_date => 0,
                vanity_url_path => $path,
                name => $name,
                description => '',
                website => '',
            } );

            $self->_set_note( buffer => 0, $mmr, { skip_save => 1 } );
        }
        else {
            my $old_hidden_users = $self->_get_note( hidden_users => $mmr ) || [];
            my $old_map = { map { $_ => 1 } @$old_hidden_users };
            for my $new_user ( @$hidden_users ) {
                next if $old_map->{ $new_user };
                $self->_share_fresh_user_meetings_with_new_supervisor( $user, $new_user, $domain_id );
            }
        }

        $mmr->disabled_date( 0 );
        $mmr->name( $name );
        $mmr->vanity_url_path( $path );

        $self->_set_note( created_for_partner => $partner_id, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_followups => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( hidden_users => $hidden_users, $mmr, { skip_save => 1 } );
        $self->_set_note( sms_invites => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( lahixcustxz_hack => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_title_edit => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_location_edit => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_duration_edit => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_tool_edit => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_time_zone_edit => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_available_timespans_edit => 1, $mmr, { skip_save => 1 } );

        $self->_set_note( time_zone => 'Europe/Helsinki', $mmr, { skip_save => 1 } );
        $self->_set_note( available_timespans => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( source_settings => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_option => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( online_conferencing_data => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( require_verified_user => 0, $mmr, { skip_save => 1 } );

        $self->_set_note( lahixcustxz_data => {
            type => $type->{name},
            lang => $lang,
            level => $level,
            office => $office->{name},
            title => $rep->{title},
        }, $mmr, { skip_save => 1 } );

        if ( $cal->{first_reservable_day} || $cal->{last_reservable_day} ) {
            my $span = {};
            if ( my $date = $cal->{first_reservable_day} ) {
                $span->{start} = Dicole::Utils::Date->ymd_to_day_start_epoch( $date, $user->timezone );
            }
            else {
                $span->{start} = new DateTime( year => 2000, month => 1, day => 1, hour => 3, minute => 0, time_zone => 'UTC' )->epoch;
            }
            if ( my $date = $cal->{last_reservable_day} ) {
                my ( $y, $m, $d, ) = $date =~ /(....)\-(.?.)\-(.?.)/;
                $span->{end} = Dicole::Utils::Date->ymd_to_day_start_epoch( $date, $user->timezone ) + 24*60*60;
            }
            else {
                $span->{end} = new DateTime( year => 2020, month => 1, day => 1, hour => 3, minute => 0, time_zone => 'UTC' )->add( days => 1 )->epoch;
            }
            $self->_set_note( available_timespans => [ $span ], $mmr, { skip_save => 1 } );
        }

        my $ltname = Dicole::Utils::Text->ensure_utf8( $stash->{translation_map}->{$lang}->{ Dicole::Utils::Text->ensure_utf8( 'Lähixcustxz' ) } );
        $self->_set_note( preset_title => "$name_without_level / [[[reserver_name]]] / $ltname", $mmr, { skip_save => 1 } );

        my $duration_default = ( $level eq 'etutaso0-1' ) ? 120 : 90;
        my $duration_key = ( $level eq 'etutaso0-1' ) ? 'etutaso0-1_length_minutes' : 'etutaso2-4_length_minutes';

        my $duration = $stash->{settings}->{general}->{$duration_key} || $duration_default;

        $self->_set_note( duration => $duration, $mmr, { skip_save => 1 } );

        my $location = $office->{"address_$shortlang"} || $office->{address_fi};
        if ( my $custom_location = $rep->{"omasijainti"} ) {
            $location = $stash->{translation_map}->{$lang}->{$custom_location} || $custom_location;
        }

        $self->_set_note( location => Dicole::Utils::Text->ensure_utf8( $location ), $mmr, { skip_save => 1 } );

        if ( $type->{name} eq 'Verkkotapaaminen') {
            $self->_set_note( location => $name_without_level, $mmr, { skip_save => 1 } );
        }

        $self->_set_note( send_ics_copy_to => $office->{'group_email'} || undef, $mmr, { skip_save => 1 } );

        my $agenda = $stash->{translation_map}->{$lang}->{"Agenda " . $type->{name} } || $stash->{translation_map}->{$lang}->{"Agenda"} || '';
        $agenda = Dicole::Utils::Text->ensure_utf8( $agenda );

        my $website = $office->{"website_$shortlang"} || $office->{website_fi};
        $website = Dicole::Utils::Text->ensure_utf8( $website );

        my $instructions = defined( $office->{"instructions_$shortlang"} ) ? $office->{"instructions_$shortlang"} : $office->{"instructions_$shortlang"} || '';
        $instructions = Dicole::Utils::Text->ensure_utf8( $instructions || '' );

        my $organizer_name = Dicole::Utils::User->name( $user );

        my $area_name = Dicole::Utils::Text->ensure_utf8( $stash->{translation_map}->{$lang}->{ Dicole::Utils::Text->ensure_utf8( $area->{name} ) } ) || $area->{name};

        my $meet_url = $cal->{extra_meeting_email};

        my $replace_strings = {
            location => $location,
            location_website => $website,
            additional_information => $instructions,
            organizer_name => $organizer_name,
            organizer_phone => $rep->{phone},
            area => $area_name,
            organizer_meet_url => $meet_url,
        };

        $agenda = Dicole::Utils::Text->replace_double_bracketed_strings_from_text( $replace_strings, $agenda );

        $agenda = Dicole::Utils::HTML->text_to_phtml( $agenda );

        $agenda =~ s/\[\[boldstart\]\]/<strong>/g;
        $agenda =~ s/\[\[boldend\]\]/<\/strong>/g;
        $agenda =~ s/\[\[linkstart\]\]/<a href="/g;
        $agenda =~ s/\[\[linkurlend\]\]/">/g;
        $agenda =~ s/\[\[linkend\]\]/<\/a>/g;

        my $original_agenda = $self->_get_note( partner_filled_preset_agenda => $mmr ) || '';
        my $current_agenda = $self->_get_note( preset_agenda => $mmr ) || '';

        my $agenda_edited = ( $original_agenda && ( $original_agenda ne $current_agenda ) ) ? 1 : 0;

        if ( ! $agenda_edited || $stash->{override_agenda_changes} || ( $agenda eq $current_agenda ) ) {
            if ( $agenda_edited && ( $agenda ne $current_agenda ) ) {
                print "OVERRIDING CHANGED AGENDA EDITED BY USER!\n";
                my $table = Dicole::Utils::HTML::Diff::html_text_diff( $agenda, $current_agenda , style => 'Table' );
                my @table = split /\n/, $table;
                for my $row ( @table ) {
                    print $row . "\n" if $row =~ /\*\s*\d+\s*\|/;
                }
            }
            $self->_set_note( preset_agenda => $agenda, $mmr, { skip_save => 1 } );
            $self->_set_note( partner_filled_preset_agenda => $agenda, $mmr, { skip_save => 1 } );
        }
        elsif ( $agenda ne $original_agenda ) {
            print "AGENDA CHANGED BUT EDITED BY USER! Not updating to new version..\n";
            my $table = Dicole::Utils::HTML::Diff::html_text_diff( $agenda, $current_agenda , style => 'Table' );
            my @table = split /\n/, $table;
            for my $row ( @table ) {
                print $row . "\n" if $row =~ /\*\s*\d+\s*\|/;
            }
        }

        my $sms_invite_template = $stash->{translation_map}->{$lang}->{"SMS kutsu " . $type->{name} };
        $sms_invite_template ||= $stash->{translation_map}->{$lang}->{"SMS kutsu"} || '';
        $sms_invite_template = Dicole::Utils::Text->replace_double_bracketed_strings_from_text( { area => $area_name }, $sms_invite_template );
        $sms_invite_template = Dicole::Utils::Text->ensure_utf8( $sms_invite_template );

        $self->_set_note( sms_invite_template => $sms_invite_template, $mmr, { skip_save => 1 } );

        my $sms_reminder_template = $stash->{translation_map}->{$lang}->{"SMS muistutus " . $type->{name} };
        $sms_reminder_template ||= $stash->{translation_map}->{$lang}->{"SMS muistutus"} || '';
        $sms_reminder_template = Dicole::Utils::Text->replace_double_bracketed_strings_from_text( { area => $area_name }, $sms_reminder_template );
        $sms_reminder_template = Dicole::Utils::Text->ensure_utf8( $sms_reminder_template );

        $self->_set_note( sms_reminder_template => $sms_reminder_template, $mmr, { skip_save => 1 } );

        $self->_set_note( agent_reserved_area => $cal->{area}, $mmr, { skip_save => 1 } );

        $self->_set_note( suggested_reason => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( ask_reason => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( disable_ask_reason => undef, $mmr, { skip_save => 1 } );
        $self->_set_note( confirm_automatically => 1, $mmr, { skip_save => 1 } );

        $self->_set_note( meeting_type => 0, $mmr, { skip_save => 1 } );

        $self->_set_note( direct_link_enabled => 0, $mmr, { skip_save => 1 } );
        $self->_set_note( direct_link_disabled => 1, $mmr, { skip_save => 1 } );

        $self->_set_note( meetme_visible => 1, $mmr, { skip_save => 1 } );
        $self->_set_note( meetme_hidden => 0, $mmr, { skip_save => 1 } );

        $self->_set_note( background_image_url => undef, $mmr, { skip_save => 1 } );

        $self->_set_note( youtube_url => undef, $mmr, { skip_save => 1 } );

        my $slotdef = { open_mon => 0, open_tue => 1, open_wed => 2, open_thu => 3, open_fri => 4 };
        my $slots = [];

        for my $key ( keys %$slotdef ) {
            my $weekday = $slotdef->{ $key };
            my $data = $office->{ $key };
            next unless $data;
            for my $span ( split /\s*\;\s*/, $data ) {
                my ( $b, $e ) = split /\s*\-\s*/, $span;
                my $slot = { begin => $b, end => $e };
                for my $x ( keys %$slot ) {
                    my ( $h, $m ) = split /\s*\:\s*/, $slot->{ $x };
                    $slot->{ $x } = $h*60*60 + $m*60;
                }

                push @$slots, { weekday => $weekday, begin_second => $slot->{begin}, end_second => $slot->{end} };
            }
        }
        $slots = [ sort { $a->{weekday} <=> $b->{weekday} } @$slots ];

        my $original_slots = $self->_get_note( partner_filled_slots => $mmr ) || [];
        my $current_slots = $self->_get_note( slots => $mmr ) || [];

        my $slots_json = Dicole::Utils::JSON->encode( $slots );
        my $original_slots_json = Dicole::Utils::JSON->encode( $original_slots );
        my $current_slots_json = Dicole::Utils::JSON->encode( $current_slots );

        my $slots_edited = ( $original_slots_json ne $current_slots_json ) ? 1 : 0;

        if ( ! $original_slots || ! $slots_edited ) {
            $self->_set_note( slots => $slots, $mmr, { skip_save => 1 } );
            $self->_set_note( partner_filled_slots => $slots, $mmr, { skip_save => 1 } );
        }
        elsif ( $slots_json ne $original_slots_json ) {
            print "SLOTS CHANGED BUT EDITED BY USER! Not updating to new version..\n";
        }

        my $original_planning_buffer = $self->_get_note( partner_filled_planning_buffer => $mmr );
        my $current_planning_buffer = $self->_get_note( planning_buffer => $mmr );
        my $dafult_planning_buffer = ( $level =~ /2/ ? 30*60 : 36*60*60 );

        if ( ! $original_planning_buffer || $original_planning_buffer eq $current_planning_buffer ) {
            $self->_set_note( planning_buffer => $dafult_planning_buffer, $mmr, { skip_save => 1 } );
            $self->_set_note( partner_filled_planning_buffer => $dafult_planning_buffer, $mmr, { skip_save => 1 } );
        }
        else {
            print "PLANNING BUFFER CHANGED BUT EDITED BY USER! Not updating to new version..\n";
        }

        $mmr->save;
        $stash->{touched_objects}->{mmr}->{ $mmr->id } = $mmr;

        $stash->{user_ensured_matchmakers} ||= {};
        $stash->{user_ensured_matchmakers}->{ $rep->{email} } ||= {};
        $stash->{user_ensured_matchmakers}->{ $rep->{email} }{ $mmr->id } = 1;
    }
}

sub _sync_ensure_user_processed {
    my ( $self, $stash, $rep, $opts ) = @_;

    return if $stash->{processed}->{users}->{ $rep->{uid} };

    $self->_sync_process_user( $stash, $rep, $opts );
}

sub _sync_process_user {
    my ( $self, $stash, $rep, $opts ) = @_;

    my $domain_id = $stash->{domain_id};
    my $partner = $self->PARTNERS_BY_ID->{ $stash->{partner_id} };

    $opts ||= {};

    $stash->{processed}->{users}->{ $rep->{uid} } = 1;

    return unless $self->_sync_check_if_user_should_be_updated( $stash, $rep );

    my $user = $self->_fetch_or_create_user_for_email( $rep->{email}, $domain_id );
    return unless $user;

    $stash->{touched_objects}->{user}->{ $user->id } = $user;

    print "processing " . $rep->{email} . "\n";

    $self->_set_note_for_user( 'meetings_agent_admin_areas' => $rep->{admin_rights} || undef, $user, $domain_id, { skip_save => 1 } );

    $self->_set_note_for_user( 'meetings_saml2_provider' => 'lahixcustxz', $user, $domain_id, { skip_save => 1 } );

    my $user_shared_account_data = [];
    for my $area ( @{ $stash->{all_areas} } ) {
        if ( $rep->{manage_rights} eq '_all' || $rep->{manage_rights} eq $area->{id} ) {
            next if $area->{skip_manage};
            push @$user_shared_account_data, {
                name => $area->{name},
                email => $self->_sync_generate_admin_email_for_area( $stash, $area ),
            };
        }
    }

    $self->_set_note_for_user( 'meetings_shared_account_data' => $user_shared_account_data, $user, $domain_id, { skip_save => 1 } );

    if ( $rep->{booking_rights} ) {
        $self->_set_note_for_user( 'meetings_agent_booking_partner' => $stash->{partner_id}, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'meetings_agent_booking_rights' => $rep->{booking_rights}, $user, $domain_id, { skip_save => 1 } );
    }
    else {
        $self->_set_note_for_user( 'meetings_agent_booking_partner' => undef, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'meetings_agent_booking_rights' => undef, $user, $domain_id, { skip_save => 1 } );
    }


    $self->_set_note_for_user( 'meetings_forward_login_to_partner' => $stash->{partner_id}, $user, $domain_id, { skip_save => 1 } );

    if ( $rep->{access_outside_intranet} || $domain_id == 76 ) {
        $self->_set_note_for_user( 'limit_ip_list' => undef, $user, $domain_id, { skip_save => 1 } );
    }
    else {
        $self->_set_note_for_user( 'limit_ip_list' => ['193.209.71.2'], $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'eliminate_link_auth' => 1, $user, $domain_id, { skip_save => 1 } );
    }

    my $supervised_agents = [];
    for my $r ( values %{ $stash->{users} } ) {
        next unless $r->{email} && $r->{supervisor};
        next unless $r->{supervisor} eq $rep->{email};
        next unless $r->{calendar_count};
        push @$supervised_agents, $r->{email};
    }

    $supervised_agents = [ sort @$supervised_agents ];
    $supervised_agents = undef unless @$supervised_agents;
    $self->_set_note_for_user( 'meetings_supervised_agents' => $supervised_agents, $user, $domain_id, { skip_save => 1 } );

    my $user_cals = [];
    for my $cal ( values %{ $stash->{calendars} } ) {
        push @$user_cals, $cal if $cal->{user_email} eq $rep->{uid};
    }

    if ( @$user_cals ) {
        $self->_set_note_for_user( 'meetings_force_phone_ext' => '+358', $user, $domain_id, { skip_save => 1 } );

        $self->_set_note_for_user( 'meetings_disable_agent_booker_exras' => time, $user, $domain_id, { skip_save => 1 } ) unless
            $self->_get_note_for_user( 'meetings_disable_agent_booker_exras', $user, $domain_id );

        my @ordered = sort { ( $b->{created_epoch} || 0 ) <=> ( $a->{created_epoch} || 0 ) } @$user_cals;
        my $last_cal = pop @ordered;


        my $office = $stash->{offices}->{ $last_cal->{office_full_name} };

        $self->_set_note_for_user( 'meetings_absences_category' => $office->{name}, $user, $domain_id, { skip_save => 1 } );

        $self->_set_note_for_user( 'meetings_never_disable_ical_emails' => 1, $user, $domain_id, { skip_save => 1 } );

        if ( ! $self->_fetch_user_matchmaker_fragment_object( $user, $domain_id ) ) {
            my $mmr_fragment = $rep->{email};
            $mmr_fragment =~ s/\@.*//;
            $mmr_fragment =~ s/[\.\_\+]/\-/g;
            $mmr_fragment = 'lahixcustxz-' . $mmr_fragment;

            my $success = $self->_set_user_matchmaker_url( $user, $domain_id, $mmr_fragment );
        }

        my $phone = $rep->{phone};

        CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            user_id => $user->id,
            domain_id => $domain_id,
            attributes => {
                $phone ? ( contact_phone => $phone ) : (),
                contact_organization => $partner->name,
                contact_title => $rep->{title}
            },
        } );

        my $sources = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
            where => 'user_id = ?',
            value => [ $user->id ]
        } );

        my $absences_found = 0;

        for my $source ( @$sources ) {
            next unless $source->uid eq 'absences:absences';
            $absences_found = 1;
        }

        if ( ! $absences_found ) {
            my $source = CTX->lookup_object('meetings_suggestion_source')->new({
                domain_id => $domain_id,
                user_id => $user->id,
                created_date => time,
                verified_date => time+60*60*24*365*10,
                vanished_date => 0,
                uid => 'absences:absences',
                name => 'Poissaolot',
                provider_id => 'absences',
                provices_type => 'absences',
                provider_name => 'Poissaolokalenterit',
            });

            $self->_set_note( is_primary => 1, $source );
        };
    }

    # the rest is generic basic user data

    $user->language( 'fi' );
    $user->timezone( 'Europe/Helsinki' );

    my $new_name = $rep->{name} || '';
    my $old_name = Dicole::Utils::User->name( $user ) || '';

    if ( $new_name ne $old_name ) {
        my ( $fn, $ln ) = split ' ', $new_name, 2;
        $user->first_name( $fn || '' ) if $fn;
        $user->last_name( $ln || '' ) if $ln;
    }

    $self->_user_accept_tos( $user, $domain_id, 'skip_save' );

    $self->_set_note_for_user( 'meetings_new_user_guide_dismissed', time, $user, $domain_id, { skip_save => 1 } ) unless $self->_get_note_for_user( 'meetings_new_user_guide_dismissed', $user, $domain_id );

    if ( ! $self->_get_note_for_user( 'meetings_mailing_list_disabled', $user, $domain_id ) ) {
        $self->_set_note_for_user( 'meetings_mailing_list_disabled' => time, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', 'partner', $user, $domain_id, { skip_save => 1 } );
    }

    my $previous_beta_pro = $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id );
    $self->_set_note_for_user( 'meetings_beta_pro' => time, $user, $domain_id, { skip_save => 1 } ) unless $previous_beta_pro;

    unless ( $stash->{dry_run} ) {
        $user->save;

        if ( ! $previous_beta_pro ) {
            $self->_calculate_user_is_pro( $user, $domain_id );
        }
    }


    # ensure each calendar is processed
    for my $cal ( values %{ $stash->{calendars} } ) {
        next if $opts->{skip_calendars};
        next unless $cal->{user_email} eq $rep->{uid};
        $self->_sync_ensure_calendar_processed( $stash, $cal );
    }

    # TODO: SEND EMAIL ???? NOT?

}

sub _sync_ensure_manage_user_exists {
    my ( $self, $stash, $area ) = @_;

    return if $area->{skip_manage};

    my $domain_id = $stash->{domain_id};

    my $name = $area->{name} . ' ylläpito';
    my $email = $self->_sync_generate_admin_email_for_area( $stash, $area );

    return unless $self->_sync_check_if_user_should_be_updated( $stash, { email => $email } );

    my $user = $self->_fetch_or_create_user_for_email( $email, $domain_id );

    return unless $user;

    $stash->{touched_objects}->{user}->{ $user->id } = $user;

    print "processing super " . $email . "\n";

    $self->_set_note_for_user( 'meetings_forward_login_to_partner' => $stash->{admin_partner_id}, $user, $domain_id, { skip_save => 1 } );

    if ( $domain_id == 76 ) {
        $self->_set_note_for_user( 'limit_ip_list' => undef, $user, $domain_id, { skip_save => 1 } );
    }
    else {
        $self->_set_note_for_user( 'limit_ip_list' => ['193.209.71.2'], $user, $domain_id, { skip_save => 1 } );
    }

    my $supervised_agents = [];
    for my $r ( values %{ $stash->{users} } ) {
        next unless $r->{email};
        next unless $r->{calendar_count};
        push @$supervised_agents, $r->{email};
    }

    $supervised_agents = [ sort @$supervised_agents ];
    $supervised_agents = undef unless @$supervised_agents;
    $self->_set_note_for_user( 'meetings_supervised_agents' => $supervised_agents, $user, $domain_id, { skip_save => 1 } );

    $user->language( 'fi' );
    $user->timezone( 'Europe/Helsinki' );

    my $new_name = $name || '';
    my $old_name = Dicole::Utils::User->name( $user ) || '';

    if ( $new_name ne $old_name ) {
        my ( $fn, $ln ) = split ' ', $new_name, 2;
        $user->first_name( $fn || '' ) if $fn;
        $user->last_name( $ln || '' ) if $ln;
    }

    $self->_user_accept_tos( $user, $domain_id, 'skip_save' );

    $self->_set_note_for_user( 'meetings_new_user_guide_dismissed', time, $user, $domain_id, { skip_save => 1 } ) unless $self->_get_note_for_user( 'meetings_new_user_guide_dismissed', $user, $domain_id );

    if ( ! $self->_get_note_for_user( 'meetings_mailing_list_disabled', $user, $domain_id ) ) {
        $self->_set_note_for_user( 'meetings_mailing_list_disabled' => time, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', 'partner', $user, $domain_id, { skip_save => 1 } );
    }

    my $previous_beta_pro = $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id );
    $self->_set_note_for_user( 'meetings_beta_pro' => time, $user, $domain_id, { skip_save => 1 } ) unless $previous_beta_pro;

    unless ( $stash->{dry_run} ) {
        $user->save;

        if ( ! $previous_beta_pro ) {
            $self->_calculate_user_is_pro( $user, $domain_id );
        }
    }

}

sub _share_fresh_user_meetings_with_new_supervisor {
    my ( $self, $user, $supervisor_email, $domain_id ) = @_;

    my $user_id = Dicole::Utils::User->ensure_id( $user );
    my $hidden_user = $self->_fetch_or_create_user_for_email( $supervisor_email, $domain_id );

    my $meetings = $self->_fetch_meetings( {
        where => 'creator_id = ? AND domain_id = ? AND begin_date > ?',
        value => [ $user_id, $domain_id, time - 30*24*60*60 ],
    } ) || [];

    for my $meeting ( @$meetings ) {
        my $mmr_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $meeting );
        next unless $mmr_id;
        my $mmr = $self->_ensure_matchmaker_object( $mmr_id );
        next unless $mmr;
        next unless $self->_get_note( lahixcustxz_hack => $mmr );

        my $participant = $self->_add_user_to_meeting_unless_already_exists(
            user => $hidden_user,
            meeting => $meeting,
            by_user => $user,
            require_rsvp => 0,
            skip_event => 1,
            is_hidden => 1,
        );
    }
}

sub _sync_finalize_process {
    my ( $self, $stash ) = @_;

    $self->_sync_clear_disappeared_matchmakers( $stash );

    print "Creating run signature..\n";
    $self->_store_signatures_for_touched_objects( $stash->{touched_objects}, '/root/latest_new_sync_signature' );

    my $partner = $self->PARTNERS_BY_ID->{ $stash->{partner_id} };
    $self->_set_note( latest_agent_sync => time, $partner );
}

sub _sync_clear_disappeared_matchmakers {
    my ( $self, $stash ) = @_;

    for my $rep ( values %{ $stash->{users} } ) {
        next unless $self->_sync_check_if_user_should_be_updated( $stash, $rep );
        my $user = $self->_fetch_or_create_user_for_email( $rep->{email}, $stash->{domain_id} );
        my $user_matchmakers = $self->_fetch_user_matchmakers( $user, $stash->{domain_id} );
        for my $mmr ( @$user_matchmakers ) {
            next if $stash->{user_ensured_matchmakers}->{ $rep->{email} }->{ $mmr->id };
            next unless $stash->{partner_id} == $self->_get_note( created_for_partner => $mmr );
            $stash->{touched_objects}->{mmr}->{ $mmr->id } = $mmr;
            next if $mmr->disabled_date;
            print "DISABLED extra mmr for user ".$rep->{email}.": " . $mmr->vanity_url_path . "\n";
            $mmr->disabled_date( time );
            $mmr->save;
        }
    }
}

sub _copy_agent_object_state_to_generation {
    my ( $self, $stash, $from_gen, $to_gen ) = @_;

    my $gen_suffix = 1;
    my $real_to_gen = $to_gen;
    while ( $gen_suffix < 999 ) {
        last if $to_gen eq 'current';
        $real_to_gen = join "-", $to_gen, $gen_suffix;
        my $existing_to_gen_objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
            where => 'domain_id = ? AND partner_id = ? AND generation = ?',
            value => [ $stash->{domain_id}, $stash->{partner_id}, $real_to_gen ],
        } );
        last unless @$existing_to_gen_objects;
        $gen_suffix++;
    }

    print "Copying agent object generation $from_gen to $real_to_gen...\n";

    my $state_objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
        where => 'domain_id = ? AND partner_id = ? AND generation = ? AND removed_date = 0',
        value => [ $stash->{domain_id}, $stash->{partner_id}, $from_gen ],
    } );

    my $obsolete_state_objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
        where => 'domain_id = ? AND partner_id = ? AND generation = ?',
        value => [ $stash->{domain_id}, $stash->{partner_id}, $real_to_gen ],
    } );

    $_->remove() for @$obsolete_state_objects;

    $self->_copy_agent_object_to_generation( $stash, $_, $real_to_gen ) for @$state_objects;

    return 1;
}

sub _copy_agent_object_to_generation {
    my ( $self, $stash, $agent_object, $to_gen ) = @_;

    my $object = CTX->lookup_object('meetings_agent_object_state')->new( {
        domain_id => $agent_object->domain_id,
        partner_id => $agent_object->partner_id,
        generation => $to_gen,
        created_date => $agent_object->created_date,
        set_date => $agent_object->set_date,
        removed_date => 0,
        set_by => $agent_object->set_by,
    });

    my $data = Dicole::Utils::JSON->decode( $agent_object->payload );
    $object->payload( Dicole::Utils::JSON->encode( $data ) );

    $object->{ $_ } = $data->{ $_ } for qw(area model uid);

    $object->save;
}

# check changed_email

1;
