package OpenInteract2::Action::DicoleMeetingsEmails;

use 5.010;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Data::ICal;
use Date::ICal;
use Data::Dumper;
use List::Util;
use DateTime;
use DateTime::Format::ICal;
use Dicole::Utils::MailGateway;

sub dispatch {
    my ( $self ) = @_;

    my $ep = $self->param('encoded_params');
    my ( $domain_id, $event_id, $user_id ) = @$ep;

    my $user = Dicole::Utils::User->ensure_object( $user_id );

    return { error => "Authenticated user not found" } unless $user;
    return { error => "Skipped processing email from meetin.gs" } if $user->email =~ /\@(?:mtn|dev.mtn|meetin|mtn\.mailgun)\.(?:gs|org)/;

    # NOTE: currently disabled: emails directly to assistant@mtn.gs
    if ( Dicole::Utils::MailGateway->get_param('recipient') =~ /assistant\@/i ) {
        my $dispatch = $self->_store_initial_dispatch( $domain_id, $event_id, $user_id );

        return { disabled => 1 };
    }

    return $self->_dispatch( $domain_id, $event_id, $user_id );
}

sub anon_dispatch {
    my ( $self ) = @_;

    my $ep = $self->param('encoded_params');
    my ( $domain_id, $event_id ) = @$ep;

    my $email = Dicole::Utils::MailGateway->get_param('from');

    return { error => "Skipped processing email from meetin.gs" } if $email =~ /\@(?:mtn|dev.mtn|meetin|mtn\.mailgun)\.(?:gs|org)/;

    my $user = $self->_fetch_user_for_email( $email, $domain_id );
    my $user_id = $user ? $user->id : 0;

    # NOTE: anon_dispatches disabled but logged for now
    # NOTE: not even sure if these are used anymore from anywhere?

    my $dispatch = $self->_store_initial_dispatch( $domain_id, $event_id, $user_id );

    return { disabled => 1 };

#    return $self->_dispatch( $domain_id, $event_id, $user_id, $email );
}

sub _dispatch {
    my ( $self, $domain_id, $event_id, $user_id, $anon_email ) = @_;

    my $dispatch = $self->_store_initial_dispatch( $domain_id, $event_id, $user_id );

    my $event = CTX->lookup_object('events_event')->fetch( $event_id );
    my $gid = $event->group_id;

    my $comment_text = Dicole::Utils::Text->ensure_utf8( Dicole::Utils::MailGateway->get_param('stripped-text') );
    $comment_text = $self->_strip_comment_email( $comment_text );

    my @ret;

    if ( ! $anon_email && $user_id && $comment_text =~ /^\s*invite\b/i ) {
        @ret = $self->_process_invite( $domain_id, $event, $user_id, $comment_text );
    }
    elsif ( $user_id && $comment_text =~ /^\s*info\b/i ) {
        @ret = $self->_process_info( $domain_id, $event, $user_id );
    }
    elsif ( $user_id && $comment_text =~ /^\s*schedule\b/i ) {
        @ret = $self->_process_schedule( $domain_id, $event, $user_id );
    }
    elsif ( $user_id && $comment_text =~ /^\s*reschedule\b/i ) {
        @ret = $self->_process_schedule( $domain_id, $event, $user_id, 1 );
    }
    elsif ( $anon_email && ( $comment_text =~ /^\s*join\b/i || Dicole::Utils::MailGateway->get_param('subject') =~ /^\s*join\b/i ) ) {
        @ret = $self->_process_join( $domain_id, $event, $anon_email, $comment_text );
    }
    else {
        my $comment_html = $comment_text ? Dicole::Utils::HTML->text_to_html( $comment_text ) : '';

        my $uploads = [ CTX->request->upload ];

        my @attachments_over_size_limit;
        my $max_material_size = $self->_get_max_material_size_in_bytes_for_meeting($event);

        if ( @$uploads ) {
            my @prese_list = ();
            my @comment_list = ();

            for my $upload ( @$uploads ) {
                if ($upload->size > $max_material_size) {
                    push @attachments_over_size_limit, $upload;

                    next;
                }

                my $prese = CTX->lookup_action('presentations_api')->e( create => {
                        domain_id => $domain_id,
                        group_id => $gid,
                        creator_id => $user_id,
                        $user_id ? () : (
                            presenter => Dicole::Utils::Text->ensure_utf8( $anon_email ),
                        ),
                        attachment_filename => Dicole::Utils::Text->ensure_utf8( $upload->filename ),
                        attachment_filehandle => $upload->filehandle,
                        title => Dicole::Utils::Text->ensure_utf8( $upload->filename ),
                        tags => [ $event->sos_med_tag ],
                    } );

                $self->_store_material_event( $event, $prese, 'created', { author => $user_id } );

                push @prese_list, $prese->id;

                if ( $comment_text ) {
                    my $comment = CTX->lookup_action('comments_api')->e( add_comment_and_return_post => {
                            object => $prese,
                            group_id => $gid,
                            user_id => 0,
                            content => $comment_html,
                            requesting_user_id => $user_id,
                            $user_id ? () : (
                                anon_email => Dicole::Utils::Text->ensure_utf8( $anon_email ),
                            ),
                            domain_id => $domain_id,
                        } );

                    if ( $comment ) {
                        $self->_store_comment_event( $event, $comment, $prese, 'created', { author => $user_id } );
                        push @comment_list, $comment->id;
                    }
                }
            }

            $dispatch->prese_id_list( join( ",", @prese_list ) );
            $dispatch->comment_id_list( join( ",", @comment_list ) );
            $dispatch->final_content( $comment_text );
            $dispatch->save;
        }
        elsif ( $comment_text ) {
            my $comment = CTX->lookup_action('comments_api')->e( add_comment_and_return_post => {
                    object => $event,
                    group_id => $event->group_id,
                    user_id => 0,
                    content => $comment_html,
                    requesting_user_id => $user_id,
                    $user_id ? () : (
                        anon_email => Dicole::Utils::Text->ensure_utf8( $anon_email ),
                    ),
                    domain_id => $domain_id,
                } );
            if ( $comment ) {
                $self->_store_comment_event( $event, $comment, $event, 'created', { author => $user_id } );
            }

            $dispatch->comment_id_list( $comment->id );
            $dispatch->final_content( $comment_text );
            $dispatch->save;
        }

        unless ( $user_id && $self->_get_note_for_user( denied_email_notifications_of_received_emails => $user_id, $domain_id ) ) {

            my $user = $user_id ? Dicole::Utils::User->ensure_object( $user_id ) : undef;

            if ( $user_id && $self->_fetch_meeting_participant_object_for_user( $event, $user_id ) ) {
                $self->_send_meeting_user_template_mail( $event, $user, email_confirmed => {
                        user_is_participant => 1,
                        success             => scalar( @attachments_over_size_limit ) ? 0 : 1,
                        filesize_exceeded   => scalar @attachments_over_size_limit,
                        file_names          => join(", ", map { $_->filename } @attachments_over_size_limit ),
                        size_limit          => int($max_material_size / 1024 / 1024) . " MB",
                        disable_url         => $self->_get_host_for_domain( $domain_id, 443 ) . $self->derive_url( action => 'meetings_global', task => 'disable_email_upload_notifications', params => { dic => Dicole::Utils::User->permanent_authorization_key( $user ) } ),
                    } );
            }
            else {
                $self->_send_themed_mail(
                    to => $anon_email || $user->email,
                    reply_to => Dicole::Utils::MailGateway->get_param('recipient'),
                    domain_id => $domain_id,

                    template_key_base => 'meetings_email_confirmed',
                    template_params => {
                        anon_email          => $anon_email || $user->email,
                        success             => scalar( @attachments_over_size_limit ) ? 0 : 1,
                        filesize_exceeded   => scalar @attachments_over_size_limit,
                        file_names          => join(", ", map { $_->filename } @attachments_over_size_limit ),
                        size_limit          => int($max_material_size / 1024 / 1024) . " MB",
                    },
                );

            }
        }

    }

    $self->_store_dispatch_completed_timestamp($dispatch);

    return @ret ? @ret : { success => 1 };
}

sub _store_dispatch_completed_timestamp {
    my ($self, $dispatch) = @_;

    $dispatch->completed_date(time);
    $dispatch->save;

    return;
}

sub _strip_comment_email {
    my ( $self, $text ) = @_;
    # Never let the authorization keys through
    $text =~ s/dic\=\w+//g;

    # Try to manually ditch everything after various Outlook reply quotes:
    $text =~ s/\n\S*?\:[^\n]*[\[\<]\s*(mailto\:)?(assistant|notifications|info)\@meetin\.gs\s*[\]\>].*//s;
    $text =~ s/\n[^\n]*(assistant|notifications|info)\@meetin\.gs[^\n]*\:\s*\n+.*//s;

    # Strip LT banner image lines
    $text =~ s/^\s*\[[bB]anner.*//mg;

    # Normalize so that start and end whitespace is stripped
    ( $text ) = $text =~ /^\s*(.*?)\s*$/s;

    # Try to remove the last quote introduction line
    if ( $text =~ /\n((notifications|info)[^\n]+meetin\.gs[^\n]*|\:)$/s ) {
        $text =~ s/\n+[^\n]$//s;
    }

    if ( $text =~ /\n\s*\-\-\-\-[^\n]*$/s ) {
        $text =~ s/\n+[^\n]*$//s;
    }
    $text =~ s/\s*$//s;

    # Remove "sent from my iphone" etc..
    $text =~ s/\n(Sent from|Lähetetty)(\s+[^\s\n]*){1,5}$//s;
    $text =~ s/\s*$//s;

    if ( $text =~ /\n\s*\-\-\-\-[^\n]*$/s ) {
        $text =~ s/\n+[^\n]*$//s;
    }
    $text =~ s/\s*$//s;

    return $text;
}

sub _store_initial_dispatch {
    my ( $self, $domain_id, $event_id, $user_id ) = @_;

    my $dispatch = CTX->lookup_object('meetings_dispatched_email')->new({
        subject      => Dicole::Utils::MailGateway->get_param('subject'),
        from_email   => Dicole::Utils::MailGateway->get_param('from'),
        to_email     => Dicole::Utils::MailGateway->get_param('recipient'),
        reply_email  => Dicole::Utils::MailGateway->get_param('Reply-To') || Dicole::Utils::MailGateway->get_param('from'),
        html_content => Dicole::Utils::MailGateway->get_param('body-html'),
        text_content => Dicole::Utils::MailGateway->get_param('body-plain'),
        calendar_content => Dicole::Utils::MailGateway->get_param('body-calendar'),

        text_stripped => Dicole::Utils::MailGateway->get_param('stripped-text'),
        html_stripped => Dicole::Utils::MailGateway->get_param('stripped-html'),

        processed_date => time,
        sent_date      => Dicole::Utils::MailGateway->get_param('timestamp') || time,

        message_id    => Dicole::Utils::MailGateway->get_param('Message-Id'),

        event_id  => $event_id || 0,
        user_id   => $user_id || 0,
        domain_id => $domain_id || 0,
    });

    $dispatch->save;

    return $dispatch;
}

sub _process_invite {
    my ( $self, $domain_id, $meeting, $user, $comment_text ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    # TODO: ensure that the user has rights to invite
    # TODO: send confirmation email
    my $formatted_text = $comment_text;
    $formatted_text =~ s/([^\n])\n([^\n])/$1 $2/g;
    my ( $emails_string ) = $formatted_text =~ /^\s*invite\s+(.*)/mi;

    if ( $emails_string ) {
        my $emails = Dicole::Utils::Mail->string_to_full_addresses( $emails_string );

        $self->_ensure_emails_are_invited( $meeting, $emails, $user );
    }

    return { success => 1 };
}

sub _process_info {
    my ( $self, $domain_id, $meeting, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $meeting, $user );
    my $open_timespans = [ map { $self->_timespan_for_proposal( $_, $user ) } @$open_pos ];
    my $pos = $self->_fetch_meeting_proposals( $meeting );
    my $timespans = [ map { $self->_timespan_for_proposal( $_, $user ) } @$pos ];
    my $material_overview = $self->_gather_material_overview_params( $meeting, $user );
    my $meeting_image = $self->_generate_meeting_image_url_for_user( $meeting, $user );

    $self->_send_meeting_user_template_mail( $meeting, $user, 'meeting_info', {
        meeting_participants => $self->_gather_meeting_participant_info( $meeting ),
        open_scheduling_options => $open_timespans,
        scheduling_options => $timespans,
        meeting_image => $meeting_image,
        %{ $material_overview },
    } );

    return { success => 1 };
}


sub _process_schedule {
    my ( $self, $domain_id, $meeting, $user_id, $reschedule ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $user_id );
    my $pos = $self->_fetch_meeting_proposals( $meeting );
    my $open_pos = $self->_fetch_open_meeting_proposals_for_user( $meeting, $user );
    my $send_pos = $reschedule ? $pos : $open_pos;

    if ( $meeting->begin_date || ! scalar( @$send_pos ) ) {
        $self->_send_meeting_user_template_mail( $meeting, $user, 'scheduling_exception', {
            open_scheduling_options => [ map { $self->_timespan_for_proposal( $_, $user ) } @$open_pos ],
            scheduling_options => [ map { $self->_timespan_for_proposal( $_, $user ) } @$pos ],
        } );

        return { success => 1 };
    }

    for my $po ( @$send_pos ) {
        my $option = $self->_timespan_for_proposal( $po, $user );
        my $answer = $reschedule ? $self->_get_meeting_proposed_date_answer( $meeting, $po, $user ) : '';

        $self->_send_themed_mail(
            %{ $self->_gather_meeting_user_template_mail_base_params( $meeting, $user, 'scheduling_option' ) },
            reply_to => $self->_get_meeting_user_proposal_email( $meeting, $user, $po ),
            template_params => {
                %{ $self->_gather_meeting_user_template_mail_template_params( $meeting, $user ) },
                scheduling_option => $option,
                previous_answer => uc( $answer ) || '',
            },
        );
    }

    return { success => 1 };
}

sub _process_join {
    my ( $self, $domain_id, $meeting, $anon_email, $comment_text ) = @_;

    my ( $pass ) = $comment_text =~ /^\s*join\s+(.*)/mi;
    ( $pass ) = Dicole::Utils::MailGateway->get_param('subject') =~ /^\s*join\s+(.*)/mi unless $pass;

    if ( $pass && lc( $pass ) eq lc( $self->_get_note_for_meeting( join_password => $meeting ) ) ) {
        my $user = $self->_fetch_or_create_user_for_email( $anon_email, $domain_id );
        my $po = $self->_add_user_to_meeting( $user, $meeting, 0, 0 );

        $self->_store_participant_event( $meeting, $po, 'created', { author => $meeting->creator_id } );
        $self->_send_meeting_invite_mail_to_user(
            user => $user,
            event => $meeting,
            user_has_joined => 1,
        );
    }
    else {
        $self->_send_themed_mail(
            domain_id => $domain_id,
            to => $anon_email,
            template_key_base => 'meetings_join_request_confirmation',
            template_params => {
                meeting_title => $self->_meeting_title_string( $meeting ),
                meeting_email => $self->_get_meeting_email( $meeting ),
                %{ $self->_gather_theme_mail_template_params_for_meeting( $meeting ) },
            }
        );

        my $creator_user = Dicole::Utils::User->ensure_object( $meeting->creator_id );
        my $accept_url = $self->_get_meeting_user_url( $meeting, $creator_user, $domain_id, undef, {
            invite_email => $anon_email,
        } );

        my $user = $self->_fetch_user_for_email( $anon_email, $domain_id );

        $self->_send_meeting_user_template_mail( $meeting, $creator_user, 'join_request_prompt', {
            user_name => $user ? Dicole::Utils::User->name( $user ) : $anon_email,
            accept_url => $accept_url,
        } );
    }

    return { success => 1 };
}

sub agenda_reply {
    my ( $self ) = @_;

    return $self->_page_reply( sub { return $self->_fetch_meeting_agenda_page( @_ ) } );
}

sub action_points_reply {
    my ( $self ) = @_;

    return $self->_page_reply( sub { return $self->_fetch_meeting_action_points_page( @_ ) } );
}

sub _page_reply {
    my ( $self, $meeting_page_fetch_function ) = @_;
    my $ep = $self->param('encoded_params');

    my ( $user_id, $domain_id, $meeting_id ) = @$ep;

    my $meeting = $self->_ensure_meeting_object( $meeting_id );
    my $user = Dicole::Utils::User->ensure_object( $user_id );

    my $dispatch = $self->_store_initial_dispatch( $domain_id, $meeting_id, $user_id );

    my $content = Dicole::Utils::MailGateway->get_param('stripped-text') || Dicole::Utils::HTML->html_to_text( Dicole::Utils::MailGateway->get_param('stripped-html') );
    $content = $self->_strip_comment_email( $content );

    my $page = $meeting_page_fetch_function->( $meeting );
    if ( $page ) {
        my $bits = $self->_fetch_meeting_page_content_bits( $meeting, $page );
        my $response;
        if ( ! $bits ) {
            $response = CTX->lookup_action('wiki_api')->e( start_raw_edit => { editing_user => $user, page => $page } );
            if ( $response && $response->{result} && $response->{result}->{lock_id} ) {
                $response = CTX->lookup_action('wiki_api')->e( store_raw_edit => {
                        editing_user => $user,
                        page => $page,
                        new_html => Dicole::Utils::HTML->text_to_phtml( $content ),
                        old_html => $response->{result}->{html},
                        lock_id => $response->{result}->{lock_id},
                        target_group_id => $page->groups_id,
                    } );
            }
        }
        if ( $response && $response->{result} && $response->{result}->{success} ) {
            $self->_store_material_event( $meeting, $page, 'edited', { author => $user } );
        }
        else {
            $self->_post_meeting_comment_under_page( $meeting, undef, $content, $page, $user );
        }
    }

    $self->_store_dispatch_completed_timestamp($dispatch);

    return { success => 1 };
}

sub scheduling_answer {
    my ( $self ) = @_;

    my $ep = $self->param('encoded_params');
    my ( $user_id, $domain_id, $event_id, $proposal_id ) = @$ep;

    my $meeting = $self->_ensure_meeting_object( $event_id );

    my $dispatch = $self->_store_initial_dispatch( $domain_id, $event_id, $user_id );

    if ( $meeting->begin_date ) {
        # TODO: does the user need separate informing if scheduling is over?
    }

    my $content_html = Dicole::Utils::Text->ensure_utf8( Dicole::Utils::MailGateway->get_param('body-html') );
    my $content_text = Dicole::Utils::Text->ensure_utf8( Dicole::Utils::MailGateway->get_param('body-plain') );

    my $comment_text = $content_text;
    $comment_text ||= Dicole::Utils::HTML->html_to_text( $content_html );

    my $answer = '';
    $answer = 'yes' if $comment_text =~ /^\s*y(?:es|)\b/si;
    $answer = 'no' if $comment_text =~ /^\s*n(?:o|)\b/si;
    if ( ! $answer ) {
        $answer = 'yes' if Dicole::Utils::MailGateway->get_param('subject') =~ /^\s*yes\b/si;
        $answer = 'no' if Dicole::Utils::MailGateway->get_param('subject') =~ /^\s*no\b/si;
    }

    my $pos = $self->_fetch_meeting_proposals( $meeting );
    my $lookup = { map { $_->id => $_ } @$pos };
    my $proposal = $lookup->{ $proposal_id };

    if ( ! $proposal ) {
        # TODO: inform if the proposal had disappeared?
    }
    elsif ( ! $answer ) {
        my $user = Dicole::Utils::User->ensure_object( $user_id );
        my $option = $self->_timespan_for_proposal( $proposal, $user );
        my $answer = $self->_get_meeting_proposed_date_answer( $meeting, $proposal, $user ) || '';

        $self->_send_themed_mail(
            %{ $self->_gather_meeting_user_template_mail_base_params( $meeting, $user, 'error_invalid_scheduling_response' ) },
            reply_to => $self->_get_meeting_user_proposal_email( $meeting, $user, $proposal ),
            template_params => {
                %{ $self->_gather_meeting_user_template_mail_template_params( $meeting, $user ) },
                scheduling_option => $option,
                previous_answer => $answer || '',
            },
        );
    }
    else {
        # confirmations are sent as a bundle so just return a success after this
        $self->_set_meeting_proposed_date_answer( $meeting, $proposal, $user_id, $answer );
    }

    $self->_store_dispatch_completed_timestamp($dispatch);

    return { success => 1 };
}

sub setup {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $dispatch = $self->_store_initial_dispatch( $domain_id, 0, 0 );

    # NOTE: currently disabled: emails directly to assistant
    return { disabled => 1 };

    my $data = Dicole::Utils::MailGateway->get_param('body-calendar');

    if ( ! $data ) {
        my $uploads = [ CTX->request->upload ];
        for my $upload ( @$uploads ) {
            next unless $upload->filename =~ /\.ics$/;
            $data = '';
            my $fh = $upload->filehandle;
            while ( my $line = < $fh > ) {
                $data .= $line . "\n";
            }
            last;
        }
    }

    my $reply_to = Dicole::Utils::MailGateway->get_param('Reply-To') || Dicole::Utils::MailGateway->get_param('from');

    if ( ! $data ) {
        get_logger(LOG_APP)->warn("Could not find ical file or subject for setup call. Replying to $reply_to!" );
        $self->_send_meeting_setup_error_email( $reply_to, 'noical', $domain_id ) if $reply_to;
        return;
    }

    # add "\n" to make sure file gets parsed without an endign newline
    my $ical = Data::ICal->new( data => $data . "\n" );

    if ( ref( $ical ) eq 'Class::ReturnValue' ) {
        get_logger(LOG_APP)->warn('Could not find ical for setup call: ' . $ical->error_message . ". parsed data:\n$data" );
        $self->_send_meeting_setup_error_email( $reply_to, 'parse', $domain_id ) if $reply_to;
        return;
    }

    my $uid = $self->_vprop( uid => $ical );
    my $meeting = $self->_fetch_domain_meeting_by_uid( $domain_id, $uid );
    if ( ! $meeting ) {
        my $organizer_email = Dicole::Utils::MailGateway->get_param('from');

        my $user = $organizer_email ? $self->_fetch_user_for_email( $organizer_email, $domain_id ) : undef;
        my $base_group_id = $user ? $self->_determine_user_base_group( $user, $domain_id ) : 0;

        if ( ! $base_group_id ) {
            my $ical_organizer = $self->_vprop( organizer => $ical );
            if ( $ical_organizer ) {
                my $ical_email = $self->_strip_participant_to_email( $ical_organizer );
                if ( $ical_email ) {
                    my $ical_user = $self->_fetch_user_for_email( $ical_email, $domain_id );
                    if ( $ical_user ) {
                        $base_group_id = $self->_determine_user_base_group( $ical_user, $domain_id ) || 0;
                        if ( $base_group_id ) {
                            $organizer_email = $ical_email;
                            $user = $ical_user;
                        }
                    }
                }
            }

            if ( ! $base_group_id ) {
                $self->_send_meeting_setup_error_email( $organizer_email || $reply_to, 'right', $domain_id ) if $organizer_email || $reply_to;
                return;
            }
        }

        my $params = $self->_ical_to_params( $ical );

        unless ( $params->{title} ) {
            $self->_send_meeting_setup_error_email( $organizer_email, 'data', $domain_id );
            return;
        }

        $meeting = CTX->lookup_action('meetings_api')->e( create => {
            uid => $uid,
            domain_id => $domain_id,
            group_id => $base_group_id,
            creator_id => $user->id,

            %$params,
        } );

        $self->_ensure_ical_attendees_are_invited( $ical, $meeting );
    }
    else {
        my $params = $self->_ical_to_params( $ical );

        my $old_info = $self->_gather_meeting_event_info( $meeting );

        $meeting->title( $params->{title} ) if $params->{title};
        $meeting->location_name( $params->{location} ) if $params->{location};

        if ( $params->{begin_epoch} || $params->{end_epoch} ) {
            $self->_set_date_for_meeting(
                $meeting,
                $params->{begin_epoch} || $meeting->begin_date,
                $params->{end_epoch} || $meeting->end_date,
                { skip_event => 1, skip_proposal_clearing => 1 }
            );
        }

        $meeting->save;

        my $new_info = $self->_gather_meeting_event_info( $meeting );

        $self->_store_meeting_event( $meeting, {
            author => $meeting->creator_id,
            event_type => 'meetings_meeting_changed',
            classes => [ 'meetings_meeting' ],
            data => { old_info => $old_info, new_info => $new_info },
        } ) unless Data::Dumper->new([$old_info])->Sortkeys(1)->Dump eq Data::Dumper->new([$new_info])->Sortkeys(1)->Dump;

        # TODO: actually we can not trust the participant list in the update phaze
        # TODO: but as long as we don't have a way to ask the organizer to accept
        # TODO: new participants easily (reverse invite) we should just invite all
        # TODO: the users who we find as attendees in the ical :P

        $self->_ensure_ical_attendees_are_invited( $ical, $meeting );
    }

    $dispatch->event_id($meeting->id);

    $self->_store_dispatch_completed_timestamp($dispatch);

    return { success => 1 };
}

sub create {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $reply_to = Dicole::Utils::MailGateway->get_param('Reply-To') || Dicole::Utils::MailGateway->get_param('from');

    my $dispatch = $self->_store_initial_dispatch($domain_id, 0 , 0);

    my $subject = Dicole::Utils::MailGateway->get_param('subject');
    unless ( $subject ) {
        $self->_send_meeting_setup_error_email( $reply_to, 'data', $domain_id );
        return;
    }

    my $content = Dicole::Utils::MailGateway->get_param('body-plain') || Dicole::Utils::HTML->html_to_text( Dicole::Utils::MailGateway->get_param('body-html') );
    $content = Dicole::Utils::HTML->text_to_phtml( $content );

    my $remaining_content = $content;
    my $user = $self->_fetch_user_for_email( $reply_to, $domain_id );
    my $base_group_id = $user ? $self->_determine_user_base_group( $user, $domain_id ) : 0;

    if ( ! $base_group_id ) {
        $self->_send_meeting_setup_error_email( $reply_to, 'right', $domain_id ) if $reply_to;
        return;
    }

    my $meeting = CTX->lookup_action('meetings_api')->e( create => {
        domain_id => $domain_id,
        group_id => $base_group_id,
        title => $subject,
        creator_id => $user->id,
        initial_agenda => $remaining_content,
    } );

    my $uploads = [ CTX->request->upload ];

    for my $upload ( @$uploads ) {
        my $prese = eval { CTX->lookup_action('presentations_api')->e( create => {
            domain_id => $domain_id,
            group_id => $base_group_id,
            creator_id => $user->id,
            attachment_filename => Dicole::Utils::Text->ensure_utf8( $upload->filename ),
            attachment_filehandle => $upload->filehandle,
            title => Dicole::Utils::Text->ensure_utf8( $upload->filename ),
            tags => [ $meeting->sos_med_tag ],
        } ) };

        $self->_store_material_event( $meeting, $prese, 'created', { author => $user->id } ) if $prese;
    }

    my $to_emails = Dicole::Utils::Mail->string_to_addresses( Dicole::Utils::MailGateway->get_param('To') );
    my $cc_emails = Dicole::Utils::Mail->string_to_addresses( Dicole::Utils::MailGateway->get_param('Cc') );

    $self->_ensure_emails_are_invited( $meeting, [ @$to_emails, @$cc_emails ], $user );

    $dispatch->event_id($meeting->id) if $meeting;

    $self->_store_dispatch_completed_timestamp($dispatch);

    return { success => 1 };
}

sub _ical_to_params {
    my ( $self, $ical ) = @_;

    my $title = $self->_decode_ical_text( $self->_vprop( summary => $ical ) );
    my $location = $self->_decode_ical_text( $self->_vprop( location => $ical ) ) || '';
    my $initial_agenda = $self->_prepare_description_for_wiki( $self->_vprop( description => $ical ) ) || '';

    my $begin_epoch = eval { $self->_ical_first_event_timestamp_to_epoch(dtstart => $ical) } || 0;
    my $end_epoch   = eval { $self->_ical_first_event_timestamp_to_epoch(dtend   => $ical) } || 0;
    if ( ! $end_epoch ) {
        my $duration = $self->_vprop( duration => $ical );
        if ( $duration ) {
            $end_epoch = eval { Date::ICal->new(ical => $begin_epoch)->add( duration => $duration )->epoch } || 0;
        }
    }
    $end_epoch ||= $begin_epoch + 60*60;

    return {
        title          => $title,
        begin_epoch    => $begin_epoch,
        end_epoch      => $end_epoch,
        location       => $location,
        initial_agenda => $initial_agenda,
    };
}

sub _ical_first_event_timestamp_to_epoch {
    my ($self, $property_name, $ical) = @_;

    my $event = $self->_find_ical_entry_by_class($ical, 'Data::ICal::Entry::Event');

    my $property = $event->property($property_name)->[0];

    my $timestamp = $property->decoded_value;

    my $timezone_name = $property->parameters->{TZID};

    unless (defined $timezone_name) {
        return Date::ICal->new(ical => $timestamp)->epoch;
    }

    my @all_timezones = grep { ref eq 'Data::ICal::Entry::TimeZone' } @{ $ical->entries };

    my $timezone = List::Util::first { $_->property('tzid')->[0]->decoded_value eq $timezone_name } @all_timezones
        or die "Invalid TZID=$timezone_name";

    my $given = scalar @{ $timezone->entries };
    if ( 1 ) {
        if ( $given eq 2 ) {
            # Find out which observance (daylight savings or standard) the
            # timestamp lies on.

            my $daylight_observance = $self->_parse_observance($timezone, 'Daylight');
            my $standard_observance = $self->_parse_observance($timezone, 'Standard');

            my $datetime_assuming_timestamp_was_in_daylight = $self->_ical_timestamp_to_datetime_assuming_offset($timestamp, $daylight_observance->{offset});
            my $datetime_assuming_timestamp_was_in_standard = $self->_ical_timestamp_to_datetime_assuming_offset($timestamp, $standard_observance->{offset});

            # If both assumed datetimes end up on the same observance, the
            # datetime is unambiguous.

            # If they fall on different observances, we pick the later one.

            # max() works correctly in both cases.

            my $corrected_datetime_assuming_original_was_in_daylight =
                $daylight_observance->{start_set}->previous($datetime_assuming_timestamp_was_in_daylight)
                        < $standard_observance->{start_set}->previous($datetime_assuming_timestamp_was_in_daylight)
                    ? $datetime_assuming_timestamp_was_in_standard
                    : $datetime_assuming_timestamp_was_in_daylight;

            my $corrected_datetime_assuming_original_was_in_standard =
                $daylight_observance->{start_set}->previous($datetime_assuming_timestamp_was_in_standard)
                        < $standard_observance->{start_set}->previous($datetime_assuming_timestamp_was_in_standard)
                    ? $datetime_assuming_timestamp_was_in_standard
                    : $datetime_assuming_timestamp_was_in_daylight;

            return List::Util::max($corrected_datetime_assuming_original_was_in_daylight->epoch, $corrected_datetime_assuming_original_was_in_standard->epoch);
        }
        elsif ( $given eq 1 ) {
            my $observance = eval { $self->_parse_observance($timezone, 'Daylight') } || eval { $self->_parse_observance($timezone, 'Standard') }
                or die "Timezone contains unrecognized observance for TZID=$timezone_name";

            return $self->_ical_timestamp_to_datetime_assuming_offset($timestamp, $observance->{offset});
        }
        else {
            die "Missing timezone definition for TZID=$timezone_name";
        }
    }
}

sub _ical_timestamp_to_datetime_assuming_offset {
    my ($self, $timestamp, $offset) = @_;

    return DateTime->from_epoch(
        epoch => Date::ICal->new(
            ical   => $timestamp,
            offset => $offset
        )->epoch
    );
}

sub _parse_observance {
    my ($self, $timezone, $observance_class) = @_;

    my $observance = $self->_find_ical_entry_by_class(
        $timezone,
        "Data::ICal::Entry::TimeZone::$observance_class"
    ) or die "Observance $observance_class not found in iCal";

    my $observance_offset = $observance->property('tzoffsetto')->[0]->decoded_value;

    my $observance_rule = $observance->property('rrule')->[0]->decoded_value;

    return {
        offset    => $observance_offset,
        start_set => DateTime::Format::ICal->parse_recurrence(recurrence => $observance_rule)
    };
}

sub _find_ical_entry_by_class {
    my ($self, $ical, $class) = @_;

    List::Util::first { ref eq $class } @{ $ical->entries };
}

sub _ensure_ical_attendees_are_invited {
    my ( $self, $ical, $meeting ) = @_;

    my @attendees = $self->_vprop( attendee => $ical );
    my $organizer = $self->_vprop( organizer => $ical );

    push @attendees, $organizer if $organizer;

    my %emails = map { $self->_strip_participant_to_email( $_ ) => 1 } @attendees;

    $self->_ensure_emails_are_invited( $meeting, [ keys %emails ] );
}

sub _ensure_emails_are_invited {
    my ( $self, $meeting, $emails, $from_user ) = @_;

    $from_user ||= Dicole::Utils::User->ensure_object( $meeting->creator_id );

    my $pos = $self->_fetch_meeting_participant_objects( $meeting );
    my %participant_lookup = map { $_->user_id => 1 } @$pos;

    my $to_address = Dicole::Utils::MailGateway->get_param('recipient');

    my @added_users = ();

    for my $email ( @$emails ) {
        next unless $email;
        # HACK: explicitly forbid these as google apps might report the other one because of forwards
        # that had to be made because.. well.. new google apps panel does not support deafault inbox GRR..
        next if $email =~ /(?:create|setup|assistant|signup)\@(?:mtn|dev.mtn|meetin|mtn\.mailgun)\.(?:gs|org)/;
        next unless index( lc( $email ), lc( $to_address ) ) == -1 && index( lc( $to_address ), lc( $email ) ) == -1;

        my $user = $self->_fetch_or_create_user_for_email( $email, $meeting->domain_id );
        next if $participant_lookup{ $user->id };

        $participant_lookup{ $user->id } = 1;

        my $po = $self->_add_user_to_meeting( $user, $meeting, $from_user, 0, { skip_calculate_is_pro => 1 } );
        $self->_store_participant_event( $meeting, $po, 'created', { author => $meeting->creator_id } );

        push @added_users, $user;
    }

    for my $user ( @added_users ) {
        $self->_send_meeting_invite_mail_to_user(
            from_user => $from_user,
            user => $user,
            event => $meeting,
        );
    }

    $self->_calculate_meeting_is_pro( $meeting ) if @added_users;
}

sub _strip_participant_to_email {
    my ( $self, $participant ) = @_;

    my $email = $participant;
    $email =~ s/mailto\://;

    return $email;
}

sub _prepare_description_for_wiki {
    my ( $self, $desc ) = @_;

    # Strip evilness introduced by google calendar..
    $desc =~ s/(?:\\n)?View your event at http.*$//;

    $desc = $self->_decode_ical_text( $desc );

    return Dicole::Utils::HTML->text_to_phtml( $desc );
}

sub _decode_ical_text {
    my ( $self, $text ) = @_;

    $text =~ s/\\([\\;,nN])/sub{ lc( $_[0] ) eq 'n' ? "\n" : $_[0] }->($1)/ge;

    return $text;
}

sub _vprop {
    my ( $self, $property, $ical ) = @_;

    my $event = $self->_find_ical_entry_by_class($ical, 'Data::ICal::Entry::Event');

    return undef unless $event;

    my @values = map { $_->decoded_value } @{ $event->property( $property ) // [] };

    my @return = map { Dicole::Utils::Text->ensure_utf8( $_ ) } @values;

    return wantarray ? @return : $return[0];
}

sub _send_meeting_setup_error_email {
    my ( $self, $email, $type, $domain_id ) = @_;

    return if $email =~ /(?:create|setup|assistant|signup)\@(?:mtn|dev.mtn|meetin|mtn\.mailgun)\.(?:gs|org)/;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    my $user = eval { $self->_fetch_user_for_email( $email, $domain_id ) };

    $self->_send_themed_mail(
        to => $email,

        lang => $user ? $user->language : 'en',
        domain_id => $domain_id,

        template_key_base => 'meetings_setup_error_' . $type,
        template_params => {
            sent_to_email => Dicole::Utils::MailGateway->get_param('recipient')
        }
    );
}

sub signup {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $group_id = 0;

    my $email = Dicole::Utils::MailGateway->get_param('from');
    my $old_user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );

    my $dispatch = $self->_store_initial_dispatch( $domain_id, 0, $old_user ? $old_user->id : 0 );

    if ( $old_user ) {
        my $base_group_id = $self->_determine_user_base_group( $old_user, $domain_id );

        my $url = Dicole::URL->get_domain_url( $domain_id, 443 ) . Dicole::URL->from_parts(
            action => 'meetings_global', task => 'detect', domain_id => $domain_id, target => $base_group_id,
        );

        $self->_send_secure_login_link( $url, $old_user );

        return { success => 1 };
    }

    my $user = eval { $self->_fetch_or_create_user_for_email( $email, $domain_id ) };

    return { spam => 1 } unless $user;

#    $self->_user_accept_tos( $user, $domain_id );

#    for my $id ( qw( offers info ) ) {
#        if ( CTX->request->param( $id ) ) {
#            $self->_set_note_for_user( 'emails_requested_for_' . $id, time, $user, $domain_id );
#        }
#    }

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

    $self->_send_themed_mail(
        user => $user,
        domain_id => $domain_id,
        group_id => 0,

        template_key_base => 'meetings_account_created',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            login_url => $url,
        },
    );

    $self->_store_dispatch_completed_timestamp($dispatch);

    return { success => 1 };
}

1;
