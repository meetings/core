package OpenInteract2::Action::DicoleMeetingsJSONP;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use DateTime;
use Dicole::Cache;

sub user_is_logged_in {
    my ( $self ) = @_;

    return { result => CTX->request->auth_user_id ? 1 : 0 };
}

sub update_user_customer_service_notes {
    my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $die = CTX->request->auth_user_id ? 0 : 1;
    $die ||= CTX->request->auth_user->email =~ /\@(meetin\.gs|dicole\.com)$/ ? 0 : 1;
    $die ||= CTX->request->auth_user->email =~ /demo\@meetin\.gs$/ ? 1 : 0;

    return { error => 'you are not allowed to do this. contact antti@meetin.gs to know why' } if $die;

    my $user = Dicole::Utils::User->ensure_object( CTX->request->param('user_id') );
    my $notes = CTX->request->param('notes');

    $self->_set_note_for_user( customer_service_notes_last_set_by => CTX->request->auth_user_id, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( customer_service_notes => $notes, $user, $domain_id );

    return { result => 1 };
}

sub login {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id ) {
        my $domain_id = Dicole::Utils::Domain->guess_current_id;
        my $http_host = $self->_get_host_for_user( CTX->request->auth_user, 443);

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

sub create {
	my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $domain_host = Dicole::URL->get_domain_url($domain_id, 80);
    my $uid = CTX->request->auth_user_id;
    my $email = CTX->request->param('email');

    if ( $uid ) {
        return { result => {
            url_after_post => $domain_host . $self->derive_url( action => 'meetings', task => 'user_new_meeting', additional => [] ),
        } };
    }
    else {
        if ( $email ) {
            my $user = Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );
            if ( $user && $self->_user_has_accepted_tos( $user, $domain_id ) ) {
                return { result => {
                    url_after_post => $domain_host . $self->derive_url( action => 'meetings', task => 'already_a_user', additional => [], params => { email => $email, mobile => CTX->request->param('mobile') } ),
                } };
            }

            if ( ! CTX->request->param( 'tos' ) ) {
                return { error => { message => $self->_nmsg( 'You need to accept the Terms of Service!' ) } };
            }

            $user = eval { $self->_fetch_or_create_user_for_email( $email ) };

            return { error => { message => 'An error occured while creating user. Sorry.' } } unless $user;

            $self->_user_accept_tos( $user, $domain_id );

            for my $id ( qw( offers info ) ) {
                if ( CTX->request->param( $id ) ) {
                    $self->_set_note_for_user( 'emails_requested_for_' . $id, time, $user, $domain_id );
                }
            }

            $uid = $user->id;
        }
        else {
            die "security error";
        }
    }

    if ( ! CTX->request->param('title') ) {
        return { error => { message => $self->_nmsg( 'Please give the meeting a title!' ) } };
    }

    my $epoch = 0;
    my $duration = 0;

    if ( CTX->request->param('schedule') && CTX->request->param('schedule') eq 'set' ) {
        my $bd = CTX->request->param('begin_date');
        my $bt = CTX->request->param('begin_time');

        $epoch = ( $bd && $bt ) ? eval { Dicole::Utils::Date->date_and_time_strings_to_epoch( $bd, $bt ) } : 0;

        if ( $@ ) {
            return { error => { message => $self->_nmsg("We are sorry but the system did not understand the provided date. Please check the date and try again!") } };
        }

        $duration = CTX->request->param('duration') || ( CTX->request->param('duration_hours') * 60 + CTX->request->param('duration_minutes') ) || 0;
    }

    my $initial_agenda = CTX->request->param('agenda') ? Dicole::Utils::HTML->text_to_html( CTX->request->param('agenda') ) : '';

    my $base_group_id = $self->_determine_user_base_group( $uid );

    die "security error" unless $base_group_id;

    my $event = CTX->lookup_action('meetings_api')->e( create => {
        creator_id => $uid,
        group_id => $base_group_id,
        title => CTX->request->param('title'),
        location => CTX->request->param('location'),
        begin_epoch => $epoch,
        duration => $duration,
        initial_agenda => $initial_agenda,
    });

    if ( CTX->request->param('schedule') && CTX->request->param('schedule') eq 'suggest' ) {
        $self->_set_note_for_meeting( open_suggestion_picker => 1, $event );
    }

    return { result => {
        url_after_post => $domain_host . $self->derive_url( action => 'meetings', task => 'thank_you', params => { create => 1, email => $email, mobile => CTX->request->param('mobile') } )
    } };
}

sub _user_email_objects_by_email {
    my ( $self, $domain_id ) = @_;

    return Dicole::Cache->in_request_fetch_or_store( "user_email_objects_by_email_$domain_id" => sub {
        my $ueos = CTX->lookup_object('meetings_user_email')->fetch_group({
            where => 'domain_id = ?',
            value => [ $domain_id ],
            order => 'created_date asc',
        }) || [];

        return { map { $_->email => $_ } @$ueos };
    } );
}


sub usage_stats {
	my ( $self ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $usage_stats = Dicole::Cache->fetch_or_store( 'usage_stats', sub {
        return $self->_generate_usage_stats_for_domain( $domain_id );
    }, { no_group_id => 1, domain_id => $domain_id, expires => 60*60*1  } );

    return { site_stats => $usage_stats };
}

sub _generate_usage_stats_for_domain {
	my ( $self, $domain_id ) = @_;

    my $domain_users = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
    my $users = Dicole::Utils::User->ensure_object_list( $domain_users );
    my $now = time;

    my $events = CTX->lookup_object('events_event')->fetch_group({
        where => 'domain_id = ?',
        value => [$domain_id] ,
    }) || [];

    my $euos = CTX->lookup_object('events_user')->fetch_group({
        where => 'domain_id = ?',
        value => [ $domain_id ],
    }) || [];

    my $euos_by_user = {};
    for my $euo ( @$euos ) {
        $euos_by_user->{ $euo->user_id } ||= [];
        push @{ $euos_by_user->{ $euo->user_id } }, $euo;
    }

    my $valid_users_by_id = {};
    my $valid_tos_users_by_id = {};

    for my $user ( @$users ) {
        next if $self->_user_email_objects_by_email( $domain_id )->{ $user->email };
        $valid_users_by_id->{ $user->id } = $user;
        next unless $self->_user_has_accepted_tos( $user, $domain_id );
        $valid_tos_users_by_id->{ $user->id } = $user;
    }

    my $users_who_have_participated = {};
    my $users_who_have_invited_to_meeting = {};

    foreach (@$euos) {
        $users_who_have_participated->{ $_->user_id }++;

        if ( $_->creator_id != $_->user_id ) {
           $users_who_have_invited_to_meeting->{$_->creator_id} += 1;
        }
    }

    my $first_user_visit = {};
    my $users_who_have_used = {};
    my $users_who_have_used_this_month = {};
    my $users_who_have_used_this_week = {};
    my $users_who_have_created = {};
    my $users_who_have_sent_beta_invites = {};

    my $site_stats = {};

    my %wmcache = ();
    my $distill_by_dwm = sub {
        my ( $base, $date ) = @_;
        my $d = DateTime->from_epoch( epoch => $date );
        $d->set( second => 0, hour => 0, minute => 0 );

        my $day_epoch = $d->epoch * 1000;
        $site_stats->{ $base . '_by_day' }->{ $day_epoch }++;

        if ( my $c = $wmcache{ $day_epoch } ) {
            $site_stats->{ $base . '_by_week' }->{ $c->{week} }++;
            $site_stats->{ $base . '_by_month' }->{ $c->{month} }++;
        }
        else {
            $wmcache{ $day_epoch } = {};

            my $dow = $d->day_of_week - 1;
            $d->subtract( days => $dow ) if $dow;
            my $week_epoch = $d->epoch * 1000;
            $site_stats->{ $base . '_by_week' }->{ $week_epoch }++;
            $wmcache{ $day_epoch }{week} = $week_epoch;

            $d->add( days => $dow ) if $dow;
            $d->set_day(1);
            my $month_epoch = $d->epoch * 1000;
            $site_stats->{ $base . '_by_month' }->{ $month_epoch }++;
            $wmcache{ $day_epoch }{month} = $month_epoch;
        }
    };

    my $daily_usage_stats = CTX->lookup_object('statistics_action')->fetch_group({
        where => 'action = ? AND domain_id = ? AND group_id = ?',
        value => [ 'user_active_daily', $domain_id, 0 ],
        order => 'date asc',
    });

    foreach (@$daily_usage_stats) {
        my $user = $valid_users_by_id->{ $_->user_id };
        next unless $user;

        $first_user_visit->{$_->user_id} ||= $_->date;
        $users_who_have_used->{$_->user_id} += 1;

        next if $_->date < $now - 60*60*24*30;
        $users_who_have_used_this_month->{$_->user_id} += 1;
        next if $_->date < $now - 60*60*24*7;
        $users_who_have_used_this_week->{$_->user_id} += 1;
    }

    for my $user ( @$users ) {
        next unless $valid_users_by_id->{ $user->id };

        $site_stats->{total_users}++;
        $site_stats->{total_participated}++ if $users_who_have_participated->{ $user->id };
        $site_stats->{total_participated_and_visited}++ if $users_who_have_participated->{ $user->id } && $users_who_have_used->{ $user->id };

        my $invited_users = $self->_get_note_for_user( meetings_users_invited => $user, $domain_id ) || [];

        if ( scalar( @$invited_users) ) {
            $users_who_have_sent_beta_invites->{ $user->id } += scalar( @$invited_users );
        }


        my $creation_time = $self->_get_note_for_user('creation_time', $user, $domain_id);
        $distill_by_dwm->( new_users => $creation_time ) if $creation_time;

        my $tos_accepted_time = $self->_get_note_for_user('beta_tos_accepted', $user, $domain_id) || $self->_get_note_for_user('tos_accepted', $user, $domain_id);
        $distill_by_dwm->( new_tos_users => $tos_accepted_time ) if $tos_accepted_time;

        my $first_visit_time = $first_user_visit->{ $user->id };
        $distill_by_dwm->( first_visits => $first_visit_time ) if $first_visit_time;
    }

    foreach (@$events) {
        $site_stats->{total_events}++;

        $users_who_have_created->{$_->creator_id} += 1;

        my $created_date = $_->created_date;
        $distill_by_dwm->( user_events => $created_date ) if $created_date;
    }

    # And now for the real funnel
    for my $user ( @$users ) {
        my $uid = $user->id;
        next unless $valid_tos_users_by_id->{ $uid };

        $site_stats->{funnel_total_users}++;

        $site_stats->{funnel_logged_in}++ if $users_who_have_used->{ $uid };
        $site_stats->{funnel_participated}++ if $users_who_have_participated->{ $uid };
        $site_stats->{funnel_participated_and_visited}++ if $users_who_have_participated->{ $uid } && $users_who_have_participated->{ $uid };
        $site_stats->{funnel_event_created}++ if $users_who_have_created->{ $uid };
        $site_stats->{funnel_beta_invite_sent}++ if $users_who_have_sent_beta_invites->{ $uid };
        $site_stats->{funnel_meeting_invite_sent}++ if $users_who_have_invited_to_meeting->{ $uid };
        $site_stats->{funnel_used_this_month}++ if $users_who_have_used_this_month->{ $uid };
        $site_stats->{funnel_is_pro}++ if $self->_user_is_pro( $user, $domain_id );
        $site_stats->{funnel_is_paid}++ if $self->_get_note_for_user( paypal_subscription_last_payment_timestamp => $user, $domain_id );
    }

    for my $user_id ( keys %$users_who_have_used ) {
        next unless $valid_users_by_id->{ $user_id };
        for my $count ( 1, 2, 6, 20 ) {
            $site_stats->{"users_who_have_used_on_at_least_n_days"}->{ $count }++
                if $users_who_have_used->{ $user_id } >= $count;
        }
    }
    for my $user_id ( keys %$users_who_have_used_this_month ) {
        next unless $valid_users_by_id->{ $user_id };
        for my $count ( 1, 2, 3, 4, 5, 6, 20 ) {
            $site_stats->{"users_who_have_used_on_at_least_n_days_this_month"}->{ $count }++
                if $users_who_have_used_this_month->{ $user_id } >= $count;
        }
    }
    for my $user_id ( keys %$users_who_have_used_this_week ) {
        next unless $valid_users_by_id->{ $user_id };
        for my $count ( 1, 2, 3, 4, 5, 6, 7 ) {
            $site_stats->{"users_who_have_used_on_at_least_n_days_this_week"}->{ $count }++
                if $users_who_have_used_this_week->{ $user_id } >= $count;
        }
    }

    for my $user_id ( keys %$users_who_have_participated ) {
        next unless $valid_users_by_id->{ $user_id };
        for my $count ( 1, 2, 6, 20 ) {
            $site_stats->{"users_who_have_participated_in_at_least_n_meetings"}->{ $count }++
                if $users_who_have_participated->{ $user_id } >= $count;
        }
    }

    for my $user_id ( keys %$users_who_have_created ) {
        next unless $valid_users_by_id->{ $user_id };
        for my $count ( 1, 2, 6, 20 ) {
            $site_stats->{"users_who_have_created_at_least_n_meetings"}->{ $count }++
                if $users_who_have_created->{ $user_id } >= $count;
        }
    }

    $site_stats->{users_who_have_sent_beta_invites} = keys( %$users_who_have_sent_beta_invites );
    $site_stats->{users_who_have_invited_to_meeting} = keys( %$users_who_have_invited_to_meeting );

    return $site_stats;
}

sub invite_cohorts {
    my ( $self ) = @_;

    my $cohorts = $self->_generate_cohorts;

    for my $cohort ( @$cohorts ) {
        $cohort->{count} = 0;
        $cohort->{max_slot} = 0;
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $domain_users = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
    my $users = Dicole::Utils::User->ensure_object_list( $domain_users );
    my $now = time;

    my $result = {
        total => {
            name => 'All time',
            count => 0,
            max_slot => 0,
            slots => {},
        },
        cohorts => $cohorts,
    };

    my $user_visit_dates = $self->_user_visit_dates( $domain_id );
    my $user_participation_dates = $self->_user_participation_dates( $domain_id );
    my $user_sent_invite_objects = $self->_user_sent_invite_objects( $domain_id );

    for my $user ( @$users ) {
        next if $self->_user_email_objects_by_email( $domain_id )->{ $user->email };
        next unless $user_visit_dates->{ $user->id } && $user_participation_dates->{ $user->id };

        my $first_visit = $user_visit_dates->{ $user->id }->[0];
        my $first_participation = $user_participation_dates->{ $user->id }->[0];

        my $first = $first_visit > $first_participation ? $first_visit : $first_participation;

        my @sorted = sort { $a->created_date <=> $b->created_date } @{ $user_sent_invite_objects->{ $user->id } || [] };

        my $user_cohort;
        for my $cohort ( @$cohorts ) {
            if ( $first >= $cohort->{start} ) {
                $user_cohort = $cohort;
                last;
            }
        }

        my $days = ( CTX->request->param('mode') eq 'monthly' ) ? 30 : 7;
        for my $cohort ( $result->{total}, $user_cohort || () ) {
            $cohort->{count}++;
            for my $invite_object ( @sorted ) {
                my $slot = int( ( $invite_object->created_date - $first ) / ( $days * 24 * 60 * 60 ) );
                $cohort->{slots}->{ $slot }++;
                $cohort->{max_slot} = $slot if $cohort->{max_slot} < $slot;
            }
        }

    }

    for my $cohort ( $result->{total}, @$cohorts ) {

        my $array = [];

        if ( $cohort->{count} ) {
            for my $n ( 0 .. $cohort->{max_slot} ) {
                push @$array, ( ( $cohort->{slots}->{ $n } || 0 ) / $cohort->{count} );
            }
        }

        $cohort->{average_slots_array} = $array;
    }

    return $result;
}

sub cohorts_for_meeting_creation_behaviour_after_first {
    my ( $self ) = @_;

    my $cohorts = $self->_generate_cohorts;

    for my $cohort ( @$cohorts ) {
        $cohort->{count} = 0;
        $cohort->{max_slot} = 0;
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $domain_users = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
    my $users = Dicole::Utils::User->ensure_object_list( $domain_users );
    my $now = time;

    my $user_created_meeting_dates = $self->_user_created_meeting_dates( $domain_id );

    my $result = {
        total => {
            name => 'All time',
            count => 0,
            max_slot => 0,
            slots => {},
        },
        cohorts => $cohorts,
    };

    for my $user ( @$users ) {
        next if $self->_user_email_objects_by_email( $domain_id )->{ $user->email };
        next unless $user_created_meeting_dates->{ $user->id };

        my @sorted = sort { $a <=> $b } @{ $user_created_meeting_dates->{ $user->id } };
        my $first = shift @sorted;

        my $user_cohort;
        for my $cohort ( @$cohorts ) {
            if ( $first >= $cohort->{start} ) {
                $user_cohort = $cohort;
                last;
            }
        }

        my $days = ( CTX->request->param('mode') eq 'monthly' ) ? 30 : 7;
        for my $cohort ( $result->{total}, $user_cohort || () ) {
            $cohort->{count}++;
            for my $epoch ( @sorted ) {
                my $slot = int( ( $epoch - $first ) / ( $days * 24 * 60 * 60 ) );
                $cohort->{slots}->{ $slot }++;
                $cohort->{max_slot} = $slot if $cohort->{max_slot} < $slot;
            }
        }

    }

    for my $cohort ( $result->{total}, @$cohorts ) {

        my $array = [];

        if ( $cohort->{count} ) {
            for my $n ( 0 .. $cohort->{max_slot} ) {
                push @$array, ( ( $cohort->{slots}->{ $n } || 0 ) / $cohort->{count} );
            }
        }

        $cohort->{average_slots_array} = $array;
    }

    return $result;
}

sub _meeting_objects {
    my ( $self, $domain_id ) = @_;

    return Dicole::Cache->in_request_fetch_or_store( "meeting_objects_$domain_id" => sub {
        return CTX->lookup_object('events_event')->fetch_group({
            where => 'domain_id = ?',
            value => [$domain_id] ,
        }) || [];
    } );
}

sub _user_created_meeting_dates {
    my ( $self, $domain_id ) = @_;

    my $meetings = $self->_meeting_objects( $domain_id );

    my $user_created_meeting_dates = {};
    for my $meeting ( @$meetings ) {
        next unless $meeting->creator_id;
        $user_created_meeting_dates->{ $meeting->creator_id } ||= [];
        push @{ $user_created_meeting_dates->{ $meeting->creator_id } }, $meeting->created_date;
    }

    return $user_created_meeting_dates;
}

sub _generate_cohorts {
    my ( $self, $months ) = @_;
    $months ||= CTX->request ? CTX->request->param('months') || 6 : 6;

    my $dt = DateTime->now;
    $dt->set( second => 0, minute => 0, hour => 0, day => 1 );

    my $cohorts = [];
    for (1..$months) {
        push @$cohorts, {
            start => $dt->epoch,
            name => $dt->month_abbr . ' ' . $dt->year,
            slots => {},
        };
        $dt->subtract( months => 1 );
    }

    return $cohorts;
}

sub _user_visit_dates {
    my ( $self, $domain_id ) = @_;

    my $daily_usage_stats = CTX->lookup_object('statistics_action')->fetch_group({
        where => 'action = ? AND domain_id = ? AND group_id = ?',
        value => [ 'user_active_daily', $domain_id, 0 ],
        order => 'date asc',
    });

    my $user_visit_days = {};
    foreach (@$daily_usage_stats) {
        $user_visit_days->{ $_->user_id } ||= [];
        push @{ $user_visit_days->{ $_->user_id } }, $_->date;
    }

    return $user_visit_days;
}

sub _user_participation_dates {
    my ( $self,  $domain_id ) = @_;
    return Dicole::Cache->in_request_fetch_or_store( "meeting_user_participation_dates_$domain_id" => sub {
        my $invite_objects = $self->_meeting_invite_objects( $domain_id );

        my $lookup = {};
        for my $invite ( @$invite_objects ) {

            $lookup->{ $invite->user_id } ||= {};
            my $dt = DateTime->from_epoch( epoch => $invite->created_date );
            $dt->set( second => 0, minute => 0, hour => 0 );

            $lookup->{ $invite->user_id }{ $dt->epoch }++;
        }

        my $return = {};
        for my $user_id ( keys %$lookup ) {
            $return->{ $user_id } = [ map { $_ } sort { $a <=> $b } keys %{ $lookup->{ $user_id } } ];
        }
        return $return;
    } );
}

sub _user_sent_invite_dates {
    my ( $self,  $domain_id ) = @_;
    return Dicole::Cache->in_request_fetch_or_store( "meeting_user_sent_invite_dates_$domain_id" => sub {
        my $invite_objects = $self->_meeting_invite_objects( $domain_id );

        my $lookup = {};
        for my $invite ( @$invite_objects ) {
            next if $invite->creator_id && $invite->creator_id == $invite->user_id;

            $lookup->{ $invite->creator_id } ||= {};
            my $dt = DateTime->from_epoch( epoch => $invite->created_date );
            $dt->set( second => 0, minute => 0, hour => 0 );

            $lookup->{ $invite->creator_id }{ $dt->epoch }++;
        }

        my $return = {};
        for my $user_id ( keys %$lookup ) {
            $return->{ $user_id } = [ map { $_ } sort { $a <=> $b } keys %{ $lookup->{ $user_id } } ];
        }
        return $return;
    } );
}

sub _user_sent_invite_objects {
    my ( $self,  $domain_id ) = @_;
    return Dicole::Cache->in_request_fetch_or_store( "meeting_user_sent_invite_objects_$domain_id" => sub {
        my $invite_objects = $self->_meeting_invite_objects( $domain_id );

        my $lookup = {};
        for my $invite ( @$invite_objects ) {
            next if $invite->creator_id && $invite->creator_id == $invite->user_id;

            $lookup->{ $invite->creator_id } ||= [];
            push @{ $lookup->{ $invite->creator_id } }, $invite;
        }

        return $lookup;
    } );
}

sub _user_participation_objects {
    my ( $self, $domain_id ) = @_;

    my $os = $self->_meeting_invite_objects( $domain_id );

    my $lookup = {};
    for my $o ( @$os ) {
        next unless $o->user_id;
        $lookup->{ $o->user_id } ||= [];
        push @{ $lookup->{ $o->user_id } }, $o;
    }
    return $lookup;
}

sub _meeting_invite_objects {
    my ( $self, $domain_id ) = @_;

    return Dicole::Cache->in_request_fetch_or_store( "meeting_invite_objects_$domain_id" => sub {
        return CTX->lookup_object('events_user')->fetch_group({
            where => "domain_id = $domain_id",
            order => "created_date asc",
        });
    } );
}

sub funnel_cohorts {
    my ( $self ) = @_;

    my $cohorts = $self->_generate_cohorts;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $domain_users = CTX->lookup_action('domains_api')->e( users_by_domain => { domain_id => $domain_id } );
    my $users = Dicole::Utils::User->ensure_object_list( $domain_users );

    my $result = {
        total => {
            name => 'All time',
            slots => {},
        },

        cohorts => $cohorts,

        data_points => [
            { id => 'contact', name => 'Contact', },
            { id => 'activation', name => 'Activation', },
            { id => 'participant', name => 'Participant', },
            { id => 'organizer', name => 'Organizer', },
            { id => 'inviter', name => 'Inviter', },
            { id => 'recurring', name => 'Recurring inviter', },
            { id => 'payment', name => 'Payment', },
        ],
    };

    my $user_visit_dates = $self->_user_visit_dates( $domain_id );
    my $user_participation_dates = $self->_user_participation_dates( $domain_id );
    my $user_participation_objects = $self->_user_participation_objects( $domain_id );
    my $user_sent_invite_dates = $self->_user_sent_invite_dates( $domain_id );
    my $user_created_meeting_dates = $self->_user_created_meeting_dates( $domain_id );

    my $meeting_objects = $self->_meeting_objects( $domain_id );
    my $meeting_objects_by_id = { map { $_->id => $_ } @$meeting_objects };

    my $user_type = CTX->request->param('user_type');

    for my $user ( @$users ) {
        next if $self->_user_email_objects_by_email( $domain_id )->{ $user->email };

        my $created_date = $self->_get_note_for_user( creation_time => $user, $domain_id );

        if ( $user_type ) {
            my $is_participant = $self->_user_is_participant( $user, $user_participation_objects, $meeting_objects_by_id );

            next if $user_type eq 'participant' && ! $is_participant;
            next if $user_type eq 'signup' && $is_participant;
        }


        my $user_cohort;
        for my $cohort ( @$cohorts ) {
            if ( $created_date >= $cohort->{start} ) {
                $user_cohort = $cohort;
                last;
            }
        }

        $self->_increment_slot( contact => $result => $user_cohort );

        if ( $user_visit_dates->{ $user->id } ) {
            $self->_increment_slot( activation => $result => $user_cohort );

            if ( $user_participation_dates->{ $user->id } ) {
                $self->_increment_slot( participant => $result => $user_cohort );

                if ( $user_created_meeting_dates->{ $user->id } ) {
                    $self->_increment_slot( organizer => $result => $user_cohort );

                    if ( $user_sent_invite_dates->{ $user->id } ) {
                        $self->_increment_slot( inviter => $result => $user_cohort );

                        if ( scalar( @{ $user_sent_invite_dates->{ $user->id } } ) > 1 ) {
                            $self->_increment_slot( recurring => $result => $user_cohort );
                        }
                    }
                }
            }
        }

        $self->_increment_slot( payment => $result => $user_cohort )
            if $self->_get_note_for_user( meetings_pro => $user, $domain_id );
    }

    return $result;
}

sub _user_is_participant {
    my ( $self, $user, $user_participation_objects, $meeting_objects_by_id ) = @_;

    my $is_participant = 0;

    my $first_participation = $user_participation_objects->{ $user->id }->[0];
    if ( $first_participation ) {
        if ( $first_participation->creator_id ) {
            if ( $first_participation->creator_id != $user->id ) {
                $is_participant = 1;
            }
        }
        else {
            if ( my $meeting = $meeting_objects_by_id->{ $first_participation->event_id } ) {
                if ( $meeting->creator_id != $user->id ) {
                    $is_participant = 1;
                }
            }
        }
    }

    return $is_participant;
}

sub _increment_slot {
    my ( $self, $key, $result, $cohort ) = @_;
    $result->{total}{slots}{ $key }++;
    $cohort->{slots}{ $key }++ if $cohort;
}

1;
