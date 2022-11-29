package Dicole::Utils::Date;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::Localization;
use Dicole::DateTime;
use DateTime::Locale;
use DateTime::TimeZone;
use Date::ICal;

sub epoch_to_ical {
    my ( $class, $epoch ) = @_;

    my $date = Date::ICal->new( epoch => $epoch )->ical;

    # NOTE: Google interprets dates without explicit time as it pleases, not as 00:00:00
    $date =~ s/^(\d{8})Z$/$1T000000Z/;

    return $date;
}

sub localized_about_when {
    my ( $self, %p ) = @_;

    my $when_parts = $self->about_when_parts( %p );
    return Dicole::Utils::Localization->translate( \%p, @$when_parts );
}

sub nlocalized_about_when {
    my ( $self, %p ) = @_;

    my $when_parts = $self->about_when_parts( %p );
    my ( $key, $param ) = @$when_parts;

    $key =~ s/ \(about_when\)//;
    $key =~ s/\[_1\]/%1\$s/;

    my @params = ( $key, [ $param ] );

    if ( $key eq '%1$s hours ago' ) {
        unshift @params, 'one hour ago';
    }

    if ( $key eq '%1$s days ago' ) {
        unshift @params, 'one day ago';
    }

    my $opts = $p{opts} || {};
    return Dicole::Utils::Localization->ntranslate( $opts, @params );
}

sub about_when_parts {
    my ( $self, %p ) = @_;
    my $epoch = $p{epoch};
    return '' unless $epoch;

    my $now = $p{now} || time;
    my $elapsed = $now - $epoch;

    return [ 'a moment ago (about_when)' ] if ( $elapsed < 60*45 );
    return [ 'an hour ago (about_when)' ] if ( $elapsed < 60*90 );

    # within six hours, report hours. otherwise report hours until we can say "yesterday"

    return [ '[_1] hours ago (about_when)', int( ( $elapsed + 30*60) / 60 / 60 ) ] if ( $elapsed < 60*60*6 );

    if ( $elapsed < 60*60*24 ) {
        my $ndt = $self->epoch_to_datetime( $now );
        my $edt = $self->epoch_to_datetime( $epoch );
        return [ '[_1] hours ago (about_when)', int( ( $elapsed + 30*60) / 60 / 60 ) ] if $ndt->day == $edt->day;
        return [ 'yesterday (about_when)' ];
    }

    # say "yesterday" until two day changes has passed

    if ( $elapsed < 60*60*24*2 ) {
        my $ydt = $self->epoch_to_datetime( $now - 60*60*24 );
        my $edt = $self->epoch_to_datetime( $epoch );
        return [ 'yesterday (about_when)' ] if $ydt->day == $edt->day;
    }

    # say "on weekday" until 7 day changes has passed

    if ( $elapsed < 60*60*24*7 ) {
        my $wdt = $self->epoch_to_datetime( $now - 60*60*24*7 );
        my $edt = $self->epoch_to_datetime( $epoch );
        unless ( $wdt->day == $edt->day ) {
            return [ {
                1 => 'on monday (about_when)',
                2 => 'on tuesday (about_when)',
                3 => 'on wednesday (about_when)',
                4 => 'on thursday (about_when)',
                5 => 'on friday (about_when)',
                6 => 'on saturday (about_when)',
                7 => 'on sunday (about_when)',
            }->{ $edt->wday } ];
        }
    }

    return ['[_1] days ago (about_when)', int( $elapsed / 60 / 60 / 24 ) ];
}

sub localized_ago {
    my ( $self, %p ) = @_;

    my $ago_parts = $self->ago_parts( %p );
    return Dicole::Utils::Localization->translate( \%p, @$ago_parts );
}

sub ago_parts {
    my ( $self, %p ) = @_;
    my $epoch = $p{epoch} || 0;
#    return '' unless $epoch;

    my $time = $p{now} || time;
    my $elapsed = $time - $epoch;

    return ['Now', $elapsed ] if ( $elapsed < 60*5 );
    return ( int( $elapsed / 60 ) == 1 ) ? [ '1 minute ago' ] : ['[_1] minutes ago', int( $elapsed / 60 ) ] if ( $elapsed < 60*60 );
    return ( int( $elapsed / 60 / 60 ) == 1 ) ? [ '1 hour ago' ] :  ['[_1] hours ago', int( $elapsed / 60 / 60 ) ] if ( $elapsed < 60*60*24 );
    return ( int( $elapsed / 60 / 60 / 24 ) == 1 ) ? [ '1 day ago' ] :  ['[_1] days ago', int( $elapsed / 60 / 60 / 24 ) ];
}

sub localized_datetimestamp {
    my ($self, %p) = @_;

    my $epoch = $p{epoch};
    my $timezone = $p{timezone};
    my $lang = $p{lang};

    my $dt = $self->epoch_to_datetime($epoch, $timezone, $lang);
    my $now = $self->epoch_to_datetime($p{now} || time, $timezone, $lang);

    my $at_str = lc( $p{display_type} ) eq 'ampm' ?
        '%l:%M %p' : '%{hour}:%M';

    my $locale = Dicole::DateTime->load_locale( $lang ? ( 1, $lang ) : () );

    my $stamp = do {
        if    ($locale->name =~ /^en/i) { '%{day} %b at ' . $at_str      }
        elsif ($locale->name =~ /^fi/i) { '%{day}.%{month}. klo ' . $at_str   }
        elsif ($locale->name =~ /^se/i) { 'den %{day} %b kl. ' . $at_str }
    };

    return Dicole::Utils::Text->ensure_utf8(
        $dt->strftime( $now->year != $dt->year ? ($stamp . ', %{ce_year}') : $stamp )
    )
}

sub epoch_to_datetime {
    my ( $self, $epoch, $timezone, $lang ) = @_;

    $timezone ||= eval{ CTX->request->auth_user->{timezone} } if CTX->request && CTX->request->auth_user_id;
    $timezone ||= eval{ CTX->controller->initial_action->param('domain')->default_timezone };
    $timezone ||= CTX->server_config->{timezone} || 'UTC';

    my $locale = Dicole::DateTime->load_locale( undef, $lang );

    my $dt = DateTime->from_epoch(
        'locale' => $locale,
        'epoch' => $epoch || time
    );
    # just fall back to default timezone if users timezone can't be loaded
    eval { $dt->set_time_zone( $timezone ) };

    return $dt;
}

sub epoch_to_epoch {
    my ( $self, $epoch, $params ) = @_;
    $epoch ||= time;
    $params ||= {};

    my $dt = $self->epoch_to_datetime( $epoch );
    $dt->set( %$params );
    return $dt->epoch;
}

sub date_and_time_strings_to_epoch {
    my ( $self, $date_string, $time_string, $timezone, $lang ) = @_;

    $time_string ||= '';

    my $dt = Dicole::Utils::Date->epoch_to_datetime( undef, $timezone, $lang);

    my ( $yyyy, $mm, $dd ) = $date_string =~ /^\s*(\d+)\s*[\.\/\-]\s*(\d+)\s*[\.\/\-]\s*(\d+)\s*$/;

    if ( $dd > 31 ) {
        my $y = $dd;
        $dd = $yyyy;
        $yyyy = $y;
    }

    my ( $hour, $min, $ampm ) = $self->parse_time_string( $time_string );

    if ( $ampm ) {
        if ( $ampm =~ /p/i ) {
            $hour += 12 if $hour < 12;
        }
    }

    if ( ! defined( $hour ) ) {
        $hour = 12;
        $min = 0;
    }
    if ( ! defined( $min ) ) {
        $min = 0;
    }

    $dt->set( day => $dd, month => $mm, year => $yyyy, hour => $hour, minute => $min, second => 0 );

    return $dt->epoch;
}

sub parse_time_string {
    my ( $self, $time_string ) = @_;

    my ( $hour, $min, $ampm ) = $time_string =~ /^\s*(\d+)\s*(?:[\:\.]\s*(\d+))? ?([ap]\.?m\.?)?\s*$/i;

    # For the weird way of denoting times as 3 pm:03 resulting from catenating am/pm displays
    if ( ! defined( $hour ) ) {
        ( $hour, $ampm, $min ) = $time_string =~ /^\s*(\d+)\s*([ap]\.?m\.?)\s*(?:[\:\.]\s*(\d+))?\s*$/i;
    }

    $min ||= 0;

    return ( $hour, $min, $ampm );
}

sub ymd_to_day_start_epoch {
    my ( $self, $ymd, $timezone ) = @_;

    $timezone ||= 'UTC';

    my ( $y, $m, $d ) = $ymd =~ /^\s*(....)\-(.?.)\-(.?.)\s*$/;

    return 0 unless defined( $y ) && defined( $m ) && defined( $d );

    return new DateTime( year => $y, month => $m, day => $d, hour => 0, minute => 0, time_zone => $timezone )->epoch;
}

sub epoch_to_date_and_time_strings {
    my ( $self, $epoch, $timezone, $lang, $display_type ) = @_;

    $epoch ||= 0;

    my $dt = $self->epoch_to_datetime( $epoch, $timezone, $lang );

    return [
        join( '-', (  $dt->year, sprintf( "%02d", $dt->month ), sprintf( "%02d", $dt->day ) ) ),
        $self->datetime_to_hour_minute( $dt, $display_type ),
    ];
}

sub timezone_info {
    my ( $self, $timezone, $epoch ) = @_;

    $epoch ||= time;

    my $tz_info = $self->timezone_info_for_timezone_and_epoch( $timezone, $epoch );

    my $change_epoch = $self->_determine_next_dst_change( $timezone, $epoch, $tz_info );

    if ( $change_epoch ) {
        my $changed_tz_info = $self->timezone_info_for_timezone_and_epoch( $timezone, $change_epoch );

        $tz_info->{dst_change_epoch} = $change_epoch;
        $tz_info->{changed_readable_name} = $changed_tz_info->{readable_name};
        $tz_info->{changed_offset_string} = $changed_tz_info->{offset_string};
        $tz_info->{changed_offset_value} = $changed_tz_info->{offset_value};
    }

    return $tz_info;
}

sub _determine_next_dst_change {
    my ( $self, $timezone, $epoch, $tz_info ) = @_;

    my $dtt = DateTime::TimeZone->new( name => $timezone );
    my $dt = DateTime->from_epoch( epoch => $epoch, time_zone => $dtt );

    my $original_offset_value = $dtt->offset_for_datetime( $dt );

    my $end = $epoch;
    my $start = $epoch;

    # Check 3 next 90 day spans for a dst change and if one is found,
    # return an epoch which is not more than hour older than the change epoch

    for my $round ( 1..3 ) {
        $start = $end;
        $end = $start + 90 * 24 * 60 * 60;
        if ( ! $self->_check_offset_match( $end, $dtt, $original_offset_value ) ) {
            return $self->_bfind_dst_change_between( $dtt, $start, $end, $original_offset_value );
        }
    }

    return 0;
}

sub _bfind_dst_change_between {
    my ( $self, $dtt, $start, $end, $start_offset_value ) = @_;

    if ( $end - $start < 60 * 60 ) {
        return $end
    };

    my $candidate = int( ( $start + $end ) / 2 );

    if ( $self->_check_offset_match( $candidate, $dtt, $start_offset_value ) ) {
        return $self->_bfind_dst_change_between( $dtt, $candidate, $end, $start_offset_value );
    }
    else {
        return $self->_bfind_dst_change_between( $dtt, $start, $candidate, $start_offset_value );
    }
}

sub _check_offset_match {
    my ( $self, $epoch, $dtt, $previous ) = @_;

    my $dt = DateTime->from_epoch( epoch => $epoch, time_zone => $dtt );

    return $dtt->offset_for_datetime( $dt ) == $previous;
}

sub timezone_info_for_timezone_and_epoch {
    my ( $self, $timezone, $epoch ) = @_;

    my $dtt = DateTime::TimeZone->new( name => $timezone );
    my $dt = DateTime->from_epoch( epoch => $epoch, time_zone => $dtt );

    my $name = $dtt->name;
    my $offset_value = $dtt->offset_for_datetime( $dt );
    my $offset_hours = $offset_value / 60 / 60;

    my $offset_full_hours = int( $offset_hours );
    my $offset_left = $offset_hours - $offset_full_hours;

    my $offset_string = 'UTC';

    if ( $offset_hours ) {
        $offset_string .= ( $offset_hours < 0 ) ? '' : '+';
        $offset_string .= $offset_full_hours;

        if ( $offset_left ) {
            $offset_string .= ':' . abs( $offset_left * 60 );
        }
    }

    my $offset_hours_string = ( ( $offset_hours < 0 ) ? '' : '+' ) . $offset_full_hours . ':' . ( $offset_left ? abs( $offset_left * 60 ) : '00' );

    my $readable_name = $name;

    if ( $readable_name =~ /.*\/.*/ ) {
        $readable_name =~ s/(.*)\/(.*)/$2 ( $1 )/;
        $readable_name =~ s/_/ /g;
    }

    $readable_name = $offset_hours_string . ' ' . $readable_name;

    return {
        name => $name,
        readable_name => $readable_name,
        offset_string => $offset_string,
        offset_value => $offset_value,
    };
}

sub datetime_to_hour_minute {
    my ( $self, $dt, $display_type ) = @_;

    if ( lc( $display_type ) eq 'ampm' ) {
        return $dt->hour_12() . ( $dt->minute ? ':' . sprintf( "%02d", $dt->minute ) : '' ) . ' ' . $dt->am_or_pm();
    }
    else {
        return join( ':', ( sprintf( "%02d", $dt->hour ), sprintf( "%02d", $dt->minute ) ) );
    }
}

sub epochs_to_span {
    my ( $self, $start, $end, $timezone, $lang ) = @_;

    # This is the magic year 2038 number - 1! because!
    if ( ! $end ) {
        $end = 2147483646;
    }

    if ( $start > $end ) {
        Carp::confess;
    }
    return DateTime::Span->from_datetimes(
        start => $self->epoch_to_datetime( $start, $timezone, $lang ),
        end => $self->epoch_to_datetime( $end, $timezone, $lang ),
    );
}

sub spanset_to_fused_spanset_within_epochs {
    my ( $self, $spanset, $begin_epoch, $end_epoch, $timezone, $lang ) = @_;

    my $iter = $spanset->iterator( span => $self->epochs_to_span( $begin_epoch, $end_epoch, $timezone, $lang ) );
    my $spans = [];

    while ( my $span = $iter->next ) {
        if ( $spans->[-1] && $span->min->epoch <= $spans->[-1]->max->epoch ) {
            pop @$spans;
            push @$spans, DateTime::Span->from_datetimes( start => $spans->[-1]->min, end => $span->max );
        }
        else {
            push @$spans, $span;
        }
    }

    return DateTime::SpanSet->from_spans( spans => $spans );
}

sub output_spanset_debug_string {
    my ( $self, $spanset ) = @_;

    return "undef/false is not a spanset" unless $spanset;

    my @s = ();
    for my $span ( $spanset->as_list ) {
        push @s, $span->start . '->' . $span->end;
    }

    return scalar( @s ) . " spans: " . join " :: ", @s;
}

sub output_dateset_debug_string {
    my ( $self, $dateset ) = @_;

    return "undef/false is not a spanset" unless $dateset;

    my @s = ();
    for my $dt ( $dateset->as_list ) {
        push @s, scalar( $dt );
    }

    return scalar( @s ) . " items: " . join " :: ", @s;
}

sub join_spansets {
    my ( $self, $spanset1, $spanset2 ) = @_;

    # work real hard not to combine spans
    my @spans1 = $spanset1->as_list;
    my @spans2 = $spanset2->as_list;

    # from_sets with empty would create infinity set in the span
    return DateTime::SpanSet->from_spans( spans => [] ) unless @spans1 || @spans2;

    # from_sets is really slow if we don't filter duplicate sets before passing them to it

    my %inserted = ();
    my %inserted1 = ();
    my %inserted2 = ();

    my @spans = ();

    for my $span ( @spans1 ) {
        my $token = join( "-" , $span->start, $span->end );
        next if $inserted1{ $token }++;
        next if $inserted{ $token }++;
        push @spans, $span;
    }

    for my $span ( @spans2 ) {
        my $token = join( "-" , $span->start, $span->end );
        next if $inserted2{ $token }++;
        next if $inserted{ $token }++;
        push @spans, $span;
    }

    # from_sets always takes a while so if we can avoid it all together
    # with these that incur pretty much no performance penalty, it's cool

    my $stamp = join(",", sort(keys( %inserted )));
    return $spanset1 if $stamp eq join(",", sort(keys( %inserted1 )));
    return $spanset2 if $stamp eq join(",", sort(keys( %inserted2 )));

    # Because from_sets does NOT work with spans that start or end at the same time, we do some
    # filtering where we discard all but the smalles span that starts or ends at the same time

    my $largest_span_by_start = {};
    for my $span ( @spans ) {
        if ( my $previous_span = $largest_span_by_start->{ $span->start->epoch } ) {
            next unless $span->end->epoch > $previous_span->end->epoch;
        }
        $largest_span_by_start->{ $span->start->epoch } = $span;
    }

    my @spans_with_unique_start = values %$largest_span_by_start;

    my $largest_span_by_end = {};
    for my $span ( @spans_with_unique_start ) {
        if ( my $previous_span = $largest_span_by_end->{ $span->end->epoch } ) {
            next unless $span->start->epoch < $previous_span->start->epoch;
        }
        $largest_span_by_end->{ $span->end->epoch } = $span;
    }

    my @spans_with_unique_start_and_end = values %$largest_span_by_end;
    my @s = ();
    my @e = ();

    for my $span ( @spans_with_unique_start_and_end ) {
        push @s, $span->start;
        push @e, $span->end;
    }

    # from_sets is the only join method which does not join adjacent spans together
    my $return = DateTime::SpanSet->from_sets(
        start_set => DateTime::Set->from_datetimes( dates => \@s ),
        end_set => DateTime::Set->from_datetimes( dates => \@e ),
    );

    return $return;
}

sub spanset_contains_epochs {
    my ( $self, $spanset, $begin, $end ) = @_;

    return $self->spanset_contains_span( $spanset, Dicole::Utils::Date->epochs_to_span( $begin, $end ) );
}

sub spanset_contains_span {
    my ( $self, $spanset, $span ) = @_;

    my $iterator = $spanset->iterator;
    my $failsafe = 0;

    while ( my $span_container = $iterator->next ) {
        return 1 if $self->span_contains_span( $span_container, $span );
        last if $failsafe++ > 1000;
    }
    return 0;
}

sub spanset_contains_duration {
    my ( $self, $spanset, $seconds ) = @_;

    my $iter = $spanset->iterator;
    my $failsafe = 0;

    while ( my $dts = $iter->next ) {
        last if $failsafe++ > 1000;

        my $start = $dts->start->epoch;
        my $end = $dts->end->epoch;

        my $duration = $end - $start;
        next unless $duration;
        next unless $duration >= $seconds;

        return 1;
    }

    return 0;
}

sub span_contains_span {
    my ( $self, $span1, $span2 ) = @_;

    return 0 if $span1->end->epoch < $span2->end->epoch;
    return 0 if $span1->start->epoch > $span2->start->epoch;
    return 1;
}

sub datetime_to_day_start_datetime {
    my ( $self, $dt ) = @_;

    my $dts = $dt->clone;
    $dts->set( hour => 0, minute => 0, second => 0 );

    return $dts;
}

sub datetime_to_month_start_datetime {
    my ( $self, $dt ) = @_;

    my $dts = $dt->clone;
    $dts->set( day => 1, hour => 0, minute => 0, second => 0 );

    return $dts;
}

1;
