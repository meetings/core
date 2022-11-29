package OpenInteract2::Action::DicoleMeetingsCommon;

use 5.010;
use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use Dicole::Utils::Session     ();

use Date::ICal;
use Data::ICal;
use Data::ICal::Entry::Event;
use DateTime;
use DateTime::Duration;
use Dicole::Utils::OAuth::Client;
use Dicole::Utils::SQL;
use Dicole::Utils::Date;
use URI::Encode;
use URI;

use Digest::MD5;
use Digest::SHA;

use Text::CSV;
use IO::Scalar;
use List::Util;

use Number::Phone::Lib;

my $nonrequest_partner_cache;

sub PARTNERS {
    if ( CTX->request ) {
        CTX->request->request_cache->{partners} ||= CTX->lookup_object('meetings_partner')->fetch_group( { order => 'id asc' } );

        return CTX->request->request_cache->{partners};
    }
    else {
        $nonrequest_partner_cache ||= CTX->lookup_object('meetings_partner')->fetch_group( { order => 'id asc' } );

        return $nonrequest_partner_cache;
    }
}

sub clear_partner_cache {
    my ( $self ) = @_;

    undef $nonrequest_partner_cache;
    if ( CTX->request ) {
        undef CTX->request->request_cache->{partners};
    }
}

sub PARTNERS_BY_API_KEY {
    my $self = shift;
    return { map { $_->{api_key} => $_ } @{$self->PARTNERS} };
}

sub PARTNERS_BY_ID {
    my $self = shift;
    return { map { $_->{id} => $_ } @{$self->PARTNERS} };
}

sub PARTNERS_BY_DOMAIN_ALIAS {
    my $self = shift;

    my $return = {};

    for my $partner ( @{ $self->PARTNERS } ) {
        next unless $partner->domain_alias;
        $return->{ $partner->domain_alias } //= $partner;
    }

    return $return;
}

sub PARTNERS_BY_APPDIRECT_BASE_URL {
    my $self = shift;

    my $return = {};

    for my $partner ( @{ $self->PARTNERS } ) {
        my $base_url = $self->_get_note( appdirect_base_url => $partner );
        next unless $base_url;
        $return->{ $base_url } //= $partner;
    }

    return $return;
}

sub SOCIAL_APP_KEYS {
    return {
        linkedin_key => 'tblwhiv9imku',
        linkedin_secret => 'x',
        google_key => 'meetin.gs',
        google_secret => 'x',
        google_apikey => 'AIzaSyD02yeJU9YRvDjlhWEFnyPEyCaaPQ34frs',
        twitter_key => 'cMxY2LNsGaANjka6mSsJVw',
        twitter_secret => 'x',
        facebook_key => '181390985231333',
        facebook_secret => 'x',
    };
}

sub THEME_NAMES {
    return [ qw(
        blue
        darkblue
        turquoise
        purple
        green
        pink_red
        grey
        brown
    ) ];
}

sub THEME_NAME_MAP { return { map { $_ => 1 } @{ THEME_NAMES() } }; }

sub NOTIFICATION_MAP {
    return {
        hd_video => 1,
        teleconference => 1,
        carbon_footprint => 1,
        meeting_cost => 1,
    };
}

sub ENABLABLE_USER_RIGHTS {
    return [ qw(
        add_time_suggestions
    ) ];
}

sub DISABLABLE_USER_RIGHTS {
    return [ qw(
        invite
        add_material
        edit_material

        start_reminder
        virtual_conferencing_reminder
        participant_digest
        participant_digest_new_participant
        participant_digest_material
        participant_digest_comments
    ) ];
}

sub USER_RIGHTS { return [ map { $_ } ( @{ ENABLABLE_USER_RIGHTS() }, @{ DISABLABLE_USER_RIGHTS() } ) ] }

sub ENABLABLE_USER_RIGHTS_MAP { return { map { $_ => 1 } @{ ENABLABLE_USER_RIGHTS() } } };
sub DISABLABLE_USER_RIGHTS_MAP { return { map { $_ => 1 } @{ DISABLABLE_USER_RIGHTS() } } };
sub USER_RIGHTS_MAP { return { map { $_ => 1 } @{ USER_RIGHTS() } } };


sub RSVP_WAITING { 1 }
sub RSVP_YES { 2 }
sub RSVP_NO { 3 }
sub RSVP_MAYBE { 4 }

sub RSVP_NAMES { return {
    RSVP_WAITING() => 'waiting',
    RSVP_YES() => 'yes',
    RSVP_NO() => 'no',
    RSVP_MAYBE() => 'maybe',
} };

sub RSVP_BY_NAME { return {
    'waiting' => RSVP_WAITING(),
    'yes' => RSVP_YES(),
    'no' => RSVP_NO(),
    'maybe' => RSVP_MAYBE(),
} };

sub SHOW_ALL { 1 }
sub SHOW_USER { 2 }
sub SHOW_ATTENDING { 3 }
sub SHOW_NONE { 4 }
sub SHOW_PLANNER { 5 }

my $tables_map = {
    sys_user => user => (),
    dicole_events_event => meeting => (),
    dicole_events_user => meeting_participant => (),
    dicole_meetings_draft_participant => meeting_draft_participant => (),
    dicole_meetings_matchmaker => matchmaker => (),
    dicole_meetings_matchmaker_url => matchmaker_url => (),
    dicole_meetings_matchmaking_event => matchmaking_event => (),
    dicole_meetings_partner => partner => (),
    dicole_meetings_meeting_suggestion => suggested_meeting => (),
    dicole_meetings_trial => trial => (),
    dicole_meetings_subscription => user_subscription => (),
    dicole_meetings_paypal_transaction => user_subscription_transaction => (),
    dicole_meetings_company_subscription => company_subscription => (),
    dicole_meetings_company_subscription_user => company_subscription_user => (),
    dicole_meetings_user_activity => user_activity => (),
    dicole_meetings_user_contact_log => user_contact_log => (),
    dicole_meetings_scheduling => scheduling => (),
    dicole_meetings_scheduling_answer => scheduling_answer => (),
    dicole_meetings_scheduling_option => scheduling_option => (),
    dicole_meetings_scheduling_log_entry => scheduling_log_entry => (),
};

my $reverse_tables_map = { map { $tables_map->{ $_ } => $_ } keys %$tables_map };

sub _resolve_spops_object_type_info {
    my ( $self, $alias ) = @_;

    my $real_type = $alias;
    my $real_table = $reverse_tables_map->{ $alias };

    my $real_key;
    my $object_class;

    if ( $real_table ) {
        $real_key = $real_table;
        $real_key =~ s/^(dicole|sys)_//;
    }
    else {
        if ( $tables_map->{ 'dicole_' . $alias } ) {
            $real_key = $alias;
            $real_type = $tables_map->{ 'dicole_' . $alias };
        }
        elsif ( $tables_map->{ $alias } ) {
            $real_key = $alias;
            $real_key =~ s/^(dicole|sys)_//;
            $real_type = $tables_map->{ $alias };
        }
        else {
            $real_key = 'meetings_' . $alias;
            $object_class = eval { CTX->lookup_object( $real_key ) };
            if ( ! $object_class ) {
                $real_key = $alias;
                $object_class = eval { CTX->lookup_object( $real_key ) };
            }
            if ( ! $object_class ) {
                $real_key = 'dicole_' . $alias;
                $object_class = eval { CTX->lookup_object( $real_key ) };
                $real_type = $real_key;
            }
            else {
                $real_type = $real_key;
                $real_type =~ s/^dicole_//;
                $real_type =~ s/^meetings_//;
            }
        }
    }

    $object_class ||= CTX->lookup_object( $real_key );

    die "Could not resolve $alias to an object type" unless $object_class;

    return {
        key => $real_key,
        type => $real_type,
        class => $object_class,
    };
}

sub _spops_object_to_json_data {
    my ( $self, $object, $object_info ) = @_;

    my $data = {};
    for my $field ( @{ $object->field_list } ) {
        $data->{$field} = $object->get( $field );
    }

    $data->{spops_object_type} = $object_info->{type};
    $data->{spops_id_field} = $object->object_description->{id_field};
    $data->{id} = $object->id;

    if ( $object_info->{type} eq 'meeting' ) {
        if ( $data->{attend_info} =~ /^\{/ ) {
            $data->{notes} = delete $data->{attend_info};
        }
    }

    if ( $object_info->{type} eq 'user' ) {
        for my $date_key ( qw( last_login removal_date ) ) {
            $data->{ $date_key } = $data->{ $date_key }->epoch if $data->{ $date_key };
        }
    }

    if ( $data->{notes} ) {
        $data->{notes} = eval { Dicole::Utils::JSON->decode( $data->{notes} ) };
        if ( $@ ) {
            get_logger(LOG_APP)->error( "Unexpected error parsing object notes: " . $object->id . ' of type ' . ref( $object ) );
            die;
        }
    }

    return $data;
}

sub _full_cookie_forward {
    my ( $self, $add_params, $remove_params ) = @_;

    return $self->redirect(
        $self->_get_cookie_param_abs(
            $self->derive_full_url( add_params => $add_params, remove_params => $remove_params ),
        )
    );
}

sub _expire_cookie_parameter_and_return_value {
    my ( $self, $parameter ) = @_;

    if ( my $value = CTX->request->cookie('cookie_parameter_' . $parameter ) ) {

        OpenInteract2::Cookie->create( {
                name => 'cookie_parameter_' . $parameter,
                path => '/',
                value => 'expired_by_date',
                expires => '-3M',
                HEADER => 'YES',
            } );

        return $value;
    }

    return 0;
}

sub _fetch_all_user_pin_objects_withing_a_week {
    my ( $self, $user, $domain_id ) = @_;

    my $week_since_epoch = time - 60*60*24*7;
    my $user_id = Dicole::Utils::User->ensure_id( $user );
    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_object('meetings_pin')->fetch_group({
        where => 'user_id = ? AND domain_id = ? AND creation_date > ?',
        value => [ $user_id, $domain_id, $week_since_epoch ],
        order => 'creation_date desc',
    });
}

sub _fetch_all_valid_user_pin_objects {
    my ( $self, $user, $domain_id ) = @_;

    my $pins = $self->_fetch_all_user_pin_objects_withing_a_week( $user, $domain_id );
    my $active = [];
    for my $pin ( @$pins ) {
        next if $pin->disabled_date || $pin->used_date;
        next if $pin->creation_date < time - 30*60;
        push @$active, $pin;
    }

    return $active;
}

sub _check_and_use_pin_code_for_user {
    my ( $self, $pin_code, $user, $domain_id ) = @_;

    my $pins = $self->_fetch_all_valid_user_pin_objects( $user, $domain_id );
    for my $pin ( @$pins ) {
        next if $pin->pin ne $pin_code;
        $pin->used_date( time );
        $pin->save;
        return $pin;
    }

    return undef;
}

sub _check_if_pin_just_expired_or_used_for_user {
    my ( $self, $pin_code, $user, $domain_id ) = @_;

    my $pins = $self->_fetch_all_user_pin_objects_withing_a_week( $user, $domain_id );
    for my $pin ( @$pins ) {
        next if $pin->pin ne $pin_code;
        return 1;
    }

    return 0;
}

sub _generate_and_return_pin_code_for_user {
    my ( $self, $user, $ip, $domain_id, $notes ) = @_;

    my $demo_user = ( $user->phone && $user->phone =~ /\#\#\#/ ) ? 1 : 0;

    $ip ||= $self->_get_ip_for_request( 'skip_override' );
    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $old_pins = $self->_fetch_all_user_pin_objects_withing_a_week( $user, $domain_id );
    my $total_pin_volume = $self->_count_total_pins_in_the_last_hour( $domain_id );
    my $ip_pin_volume = $self->_count_total_pins_in_the_last_hour_from_ip( $ip, $domain_id );

    my $today_count = 0;
    my $hour_count = 0;
    for my $pin ( @$old_pins ) {
        $hour_count++ if $pin->creation_date > time - 60*60;
        $today_count++ if $pin->creation_date > time - 60*60*24;
    }

    return 0 if $hour_count > 10 && ! $demo_user;
    return 0 if $today_count > 20 && ! $demo_user;

    my $number_count = 4;
    $number_count += 1 if $today_count;
    $number_count += 1 if $hour_count > 1;
    $number_count += 2 if scalar( @$old_pins ) > 10;
    $number_count += 1 if $total_pin_volume > 100;
    $number_count += 1 if $total_pin_volume > 1000;
    $number_count += 1 if $ip_pin_volume > 10;
    $number_count += 1 if $ip_pin_volume > 100;

    my $pin = int( rand( 10 ** $number_count - 10 ** ( $number_count - 1 )  ) + 10 ** ( $number_count - 1 ) );
    $pin = '1234' if $demo_user;

    my $user_id = Dicole::Utils::User->ensure_id( $user );

    my $object = CTX->lookup_object('meetings_pin')->new({
        domain_id => $domain_id,
        user_id => $user_id,
        pin => $pin,
        creator_ip => $ip,
        creation_date => time,
        disabled_date => 0,
        used_date => 0,
    });

    for my $key ( keys %{ $notes || {} } ) {
        $self->_set_note( $key, $notes->{ $key }, $object, { skip_save => 1 } );
    }

    $object->save;

    return $pin;
}

sub _count_total_pins_in_the_last_hour {
    my ( $self, $domain_id ) = @_;

    my $hour_since_epoch = time - 60*60;
    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_object('meetings_pin')->fetch_count({
        where => 'domain_id = ? AND creation_date > ?',
        value => [ $domain_id, $hour_since_epoch ],
    });
}

sub _count_total_pins_in_the_last_hour_from_ip {
    my ( $self, $ip, $domain_id ) = @_;

    my $hour_since_epoch = time - 60*60;
    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_object('meetings_pin')->fetch_count({
        where => 'creator_ip = ? AND domain_id = ? AND creation_date > ?',
        value => [ $ip, $domain_id, $hour_since_epoch ],
    });
}

sub _user_has_accepted_tos {
    my ( $self, $user, $domain_id ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    if (
        $self->_get_note_for_user( 'tos_accepted' => $user, $domain_id ) ||
        $self->_get_note_for_user( 'beta_tos_accepted' => $user, $domain_id )
    ) {
        return 1;
    }
    return 0;
}

sub _user_accept_tos {
    my ( $self, $user, $domain_id, $skip_save ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    if ( ! $self->_get_note_for_user(tos_accepted => $user, $domain_id) ) {
        return $self->_set_note_for_user( 'tos_accepted' => time, $user, $domain_id, { skip_save => $skip_save ? 1 : 0 } ) ? 1 : 0;
    }

    return 1;
}

sub _user_profile_is_filled {
    my ( $self, $user, $domain_id ) = @_;

    return 1 if $user->first_name || $user->last_name;

    return $self->_get_note_for_user( profile_filled => $user, $domain_id ) ? 1 : 0;
}

sub _user_filled_profile {
    my ( $self, $user, $domain_id ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    if ( ! $self->_get_note_for_user( profile_filled => $user, $domain_id) ) {
        return $self->_set_note_for_user( profile_filled => time, $user, $domain_id ) ? 1 : 0;
    }

    return 1;
}

sub _user_is_pro {
    my ($self, $user, $domain_id) = @_;

    return 0 if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    return 1 if $self->_user_is_real_pro( $user, $domain_id );
    return 1 if $self->_user_is_trial_pro( $user, $domain_id );
    return 0;
}

sub _user_is_trial_pro {
    my ( $self, $user, $domain_id ) = @_;

    return 0 if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    if ( ! $self->_get_note_for_user( 'meetings_pro_calculated', $user, $domain_id ) ) {
        $self->_calculate_user_is_pro( $user, $domain_id );
    }

    if ( $self->_get_note_for_user( 'meetings_trial_pro', $user, $domain_id ) ) {
        my $expires = $self->_get_note_for_user( 'meetings_trial_pro_expires', $user, $domain_id );
        return 1 unless $expires && time > $expires;
    }

    return 0;
}

sub _user_is_real_pro {
    my ( $self, $user, $domain_id ) = @_;

    return 0 if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    if ( my $ts = $self->_get_note_for_user( 'paypal_pending_subscription_timestamp', $user, $domain_id ) ) {
        return 1 if $ts + 300 > time;
    }

    if ( ! $self->_get_note_for_user( 'meetings_pro_calculated', $user, $domain_id ) ) {
        $self->_calculate_user_is_pro( $user, $domain_id );
    }

    return 1 if $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id );

    if ( $self->_get_note_for_user( 'meetings_pro', $user, $domain_id ) ) {
        my $expires = $self->_get_note_for_user( 'meetings_pro_expires', $user, $domain_id );
        return 1 unless $expires && time > $expires;
    }

    return 0;
}

sub _user_is_pro_expires {
    my ($self, $user, $domain_id) = @_;
    die if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    return 0 if $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id );
    return 0 if $self->_get_note_for_user( 'meetings_pro', $user, $domain_id ) && ! $self->_get_note_for_user( 'meetings_pro_expires', $user, $domain_id );

    my $expires = -1;

    my $ts = $self->_get_note_for_user( 'paypal_pending_subscription_timestamp', $user, $domain_id );
    $expires = $ts + 300 if $ts;

    if ( $self->_get_note_for_user( 'meetings_pro', $user, $domain_id ) ) {
        my $pro_expires = $self->_get_note_for_user( 'meetings_pro_expires', $user, $domain_id );
        $expires = $pro_expires if $pro_expires && $pro_expires > $expires;
    }

    if ( $self->_get_note_for_user( 'meetings_trial_pro', $user, $domain_id ) ) {
        my $trial_expires = $self->_get_note_for_user( 'meetings_trial_pro_expires', $user, $domain_id );
        $expires = $trial_expires if $trial_expires && $trial_expires > $expires;
    }

    return $expires;
}

sub _user_free_trial_has_expired {
    my ($self, $user, $domain_id) = @_;
    die if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    return 1 if $self->_get_note_for_user( 'meetings_free_trial_disabled', $user, $domain_id );

    my $expires_epoch = $self->_get_note_for_user( 'meetings_free_trial_expires', $user, $domain_id );
    return 0 unless $expires_epoch;
    return 0 if $expires_epoch > time;
    return 1;
}

sub _form_user_pro_footprint {
    my ($self, $user, $domain_id) = @_;

    return join( "-", (
        $self->_get_note_for_user( 'paypal_pending_subscription_timestamp', $user, $domain_id ),
        $self->_get_note_for_user( 'meetings_beta_pro', $user, $domain_id ),
        $self->_get_note_for_user( 'meetings_pro_expires', $user, $domain_id ),
        $self->_get_note_for_user( 'meetings_pro', $user, $domain_id ),
        $self->_get_note_for_user( 'meetings_trial_pro_expires', $user, $domain_id ),
        $self->_get_note_for_user( 'meetings_trial_pro', $user, $domain_id ),
    ) );
}

sub _calculate_user_is_pro {
    my ($self, $user, $domain_id) = @_;

    return if ! $user && ! CTX->request->auth_user_id;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    $self->_set_note_for_user( 'meetings_pro_expires' => 0, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( 'meetings_pro' => 0, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( 'meetings_pro_type' => '', $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( 'meetings_trial_pro_expires' => 0, $user, $domain_id, { skip_save => 1 } );
    $self->_set_note_for_user( 'meetings_trial_pro' => 0, $user, $domain_id, { skip_save => 1 } );

    my $subs = CTX->lookup_object('meetings_subscription')->fetch_group({
        where => 'user_id = ?',
        value => [ $user->id ],
        order => 'subscription_date asc',
    } );

    for my $sub ( @$subs ) {
        # NOTE: this disables old paypal subscriptions
        next if $self->_get_note( payer_id => $sub );

        if ( my $valid_until = $self->_get_note( valid_until_timestamp => $sub ) ) {
            next if $valid_until < time;
            $self->_set_note_for_user( 'meetings_pro_expires' => $valid_until, $user, $domain_id, { skip_save => 1 } );
        }
        else {
            $self->_set_note_for_user( 'meetings_pro_expires' => 0, $user, $domain_id, { skip_save => 1 } );
        }
        $self->_set_note_for_user( 'meetings_pro' => $sub->subscription_date, $user, $domain_id, { skip_save => 1 } );
        $self->_set_note_for_user( 'meetings_pro_type' => 'user', $user, $domain_id, { skip_save => 1 } );
    }

    my $company_subs = CTX->lookup_object('meetings_company_subscription_user')->fetch_group({
        where => 'user_id = ? AND removed_date = 0',
        value => [ $user->id ],
        order => 'created_date asc',
    } );

    for my $sub_user ( @$company_subs ) {
        my $sub = $self->_ensure_object_of_type( meetings_company_subscription => $sub_user->subscription_id );
        next unless $sub;
        next if $sub->removed_date;
        next unless $sub->is_pro;
        next if $sub->is_trial;

        my $previous_valid_until = $self->_get_note_for_user( 'meetings_pro_expires' => $user, $domain_id );
        my $valid_until = $sub->expires_date;
        my $valid_sub_found = 0;
        if ( ! $valid_until ) {
            $self->_set_note_for_user( 'meetings_pro_expires' => 0, $user, $domain_id, { skip_save => 1 } );
            $valid_sub_found = 1;
        }
        elsif ( $previous_valid_until && $valid_until > time && $valid_until > $previous_valid_until ) {
            $self->_set_note_for_user( 'meetings_pro_expires' => $valid_until, $user, $domain_id, { skip_save => 1 } );
            $valid_sub_found = 1;
        }

        if ( $valid_sub_found ) {
            $self->_set_note_for_user( 'meetings_pro' => $sub_user->created_date, $user, $domain_id, { skip_save => 1 } );
            $self->_set_note_for_user( 'meetings_pro_type' => 'company', $user, $domain_id, { skip_save => 1 } );
        }
    }

    if ( ! $self->_get_note_for_user( 'meetings_pro', $user, $domain_id ) ) {
        my $trials = CTX->lookup_object('meetings_trial')->fetch_group({
            where => 'user_id = ?',
            value => [ $user->id ],
            order => 'creation_date asc',
        } );

        $self->_set_note_for_user( 'meetings_free_trial_expires' => undef, $user, $domain_id, { skip_save => 1 } );

        for my $trial ( @$trials ) {
            my $dt = DateTime->from_epoch( epoch => $trial->start_date );
            # NOTE: add hours instead of days to avoid DST crash on nonexisting hours
            $dt->add( hours => 24 * $trial->duration_days  );
            if ( $trial->trial_type eq 'free_trial_30' ) {
                $self->_set_note_for_user( 'meetings_free_trial_expires' => $dt->epoch, $user, $domain_id, { skip_save => 1 } );
            }
            next if $dt->epoch < time;

            $self->_set_note_for_user( 'meetings_trial_pro_expires' => $dt->epoch, $user, $domain_id, { skip_save => 1 } );
            $self->_set_note_for_user( 'meetings_trial_pro' => $trial->start_date, $user, $domain_id, { skip_save => 1 } );
        }

        for my $sub_user ( @$company_subs ) {
            my $sub = $self->_ensure_object_of_type( meetings_company_subscription => $sub_user->subscription_id );
            next unless $sub;
            next if $sub->removed_date;
            next unless $sub->is_pro;
            next unless $sub->is_trial;

            my $previous_valid_until = $self->_get_note_for_user( 'meetings_trial_pro_expires' => $user, $domain_id );
            my $valid_until = $sub->expires_date;
            if ( ! $valid_until ) {
                $self->_set_note_for_user( 'meetings_trial_pro_expires' => 0, $user, $domain_id, { skip_save => 1 } );
                $self->_set_note_for_user( 'meetings_trial_pro' => $sub_user->created_date, $user, $domain_id, { skip_save => 1 } );
            }
            elsif ( $previous_valid_until && $valid_until > time && $valid_until > $previous_valid_until ) {
                $self->_set_note_for_user( 'meetings_trial_pro_expires' => $valid_until, $user, $domain_id, { skip_save => 1 } );
                $self->_set_note_for_user( 'meetings_trial_pro' => $sub_user->created_date, $user, $domain_id, { skip_save => 1 } );
            }
        }
    }

    my $old_footprint = $self->_get_note_for_user( 'meetings_pro_calculated_footprint', $user, $domain_id );
    my $new_footprint = $self->_form_user_pro_footprint( $user, $domain_id );

    if ( $new_footprint ne $old_footprint ) {
        $self->_set_note_for_user( 'meetings_pro_calculated_footprint' => $new_footprint, $user, $domain_id );
        $self->_recalculate_is_pro_for_all_user_meetings( $user, $domain_id );
    }
    $self->_set_note_for_user( 'meetings_pro_calculated' => time, $user, $domain_id );
}

sub _user_is_new_user {
    my ( $self, $user, $domain_id ) = @_;

    my $creation_time = $self->_get_note_for_user( creation_time => $user, $domain_id );

    return 1 if $creation_time + 30 > time;
    return 0;
}

sub _user_has_connected_google {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_get_note_for_user( meetings_google_oauth2_refresh_token => $user, $domain_id ) ? 1 : 0;
}

sub _user_has_connected_device_calendar {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_get_note_for_user( meetings_device_calendar_last_connected => $user, $domain_id ) ? 1 : 0;
}

sub _ensure_user_device_calendar_connected_is_set {
    my ( $self, $user, $domain_id ) = @_;

    my $last = $self->_get_note_for_user( meetings_device_calendar_last_connected => $user, $domain_id ) || 0;

    unless ( $last ) {
        $self->_set_note_for_user( meetings_device_calendar_first_connected => time, $user, $domain_id, { skip_save => 1 } );
    }

    $self->_set_note_for_user( meetings_device_calendar_last_connected => time, $user, $domain_id )
        if $last + 24*60*60 < time;

    $self->_dispatch_ensure_fresh_segment_identify_for_user( $user ) unless $last;

    return 1;
}

sub _clear_user_google_tokens {
    my ( $self, $user, $domain_id ) = @_;

    $self->_set_note_for_user( 'meetings_google_request_token', undef, $user, $domain_id, 'no_save' );
    $self->_set_note_for_user( 'meetings_google_request_token_secret', undef, $user, $domain_id, 'no_save' );
    $self->_set_note_for_user( 'meetings_google_access_token', undef, $user, $domain_id, 'no_save' );
    $self->_set_note_for_user( 'meetings_google_access_token_secret', undef, $user, $domain_id, 'no_save' );
    $self->_set_note_for_user( 'meetings_google_oauth2_refresh_token', undef, $user, $domain_id );

    my $service_accounts = $self->_get_user_service_accounts( $user, $domain_id );
    for my $sa ( @$service_accounts ) {
        next unless $sa->service_type =~ /google/;
        $sa->remove;
    }
}

sub _get_trial_ending_date {
    my ($self, $trial) = @_;

    return DateTime->from_epoch(epoch => $trial->start_date) + DateTime::Duration->new(days => $trial->duration_days);
}

sub _recalculate_is_pro_for_all_user_meetings {
    my ( $self, $user, $domain_id ) = @_;

    my $meetings = $self->_get_user_meetings_in_domain( $user, $domain_id );

    for my $meeting ( @$meetings ) {
        $self->_calculate_meeting_is_pro( $meeting );
    }
}

sub _meeting_is_cancelled {
    my ( $self, $meeting ) = @_;

    return 1 if $meeting->cancelled_date;
    return 1 if $self->_get_note( cancelled_date => $meeting );
    return 0;
}

sub _meeting_is_draft {
    my ( $self, $meeting, $euos, $no_update ) = @_;

    return 0 if $self->_get_note_for_meeting( draft_ready => $meeting );

    # this can be set if an user has been invited separately without exiting draft mode
    # It can also be set as an optimization
    return 1 if $self->_get_note_for_meeting( draft_until_ready => $meeting );

    $euos ||= $self->_fetch_meeting_participant_objects( $meeting );

    if ( scalar( @$euos ) < 2 ) {
        $self->_set_note_for_meeting( draft_until_ready => time, $meeting ) unless $no_update;
        return 1;
    }
    else {
        my @sorted = sort { $a->created_date <=> $b->created_date } @$euos;
        # take the second participant, expect draft ready then.
        my $time = eval { $sorted[1]->created_date } || time;
        $self->_set_note_for_meeting( draft_ready => $time, $meeting ) unless $no_update;
        return 0;
    }
}

sub _meeting_is_matchmaking_accepted {
    my ( $self, $meeting ) = @_;

    return 1 unless $self->_meeting_is_draft( $meeting );
    return 1 unless $self->_get_note( created_from_matchmaker_id => $meeting );
    return $self->_get_note( matchmaking_accept_dismissed => $meeting ) ? 1 : 0;
}

sub _meeting_draft_ready_time {
    my ( $self, $meeting, $euos ) = @_;

    return 0 if $self->_meeting_is_draft( $meeting, $euos );

    return $self->_get_note_for_meeting( draft_ready => $meeting );
}


sub _meeting_is_pro {
    my ( $self, $meeting, $creator_user ) = @_;

    if ( ! $self->_get_note_for_meeting( 'meetings_pro_calculated', $meeting ) ) {
        $self->_calculate_meeting_is_pro( $meeting, $creator_user );
    }

    return 0 unless $self->_get_note_for_meeting( 'meetings_is_pro', $meeting );

    my $sponsored_expires = $self->_get_note_for_meeting( 'meetings_is_pro_expires', $meeting );
    return 0 if $sponsored_expires && time > $sponsored_expires;

    return 1;
}

sub _meeting_is_sponsored {
    my ( $self, $meeting, $creator_user ) = @_;

    if ( ! $self->_get_note_for_meeting( 'meetings_pro_calculated', $meeting ) ) {
        $self->_calculate_meeting_is_pro( $meeting, $creator_user );
    }

    return 0 unless $self->_get_note_for_meeting( 'meetings_is_sponsored', $meeting );

    my $sponsored_expires = $self->_get_note_for_meeting( 'meetings_is_sponsored_expires', $meeting );
    return 0 if $sponsored_expires && time > $sponsored_expires;

    return 1;
}

sub _meeting_sponsor_names {
    my ( $self, $meeting, $creator_user ) = @_;

    if ( ! $self->_get_note_for_meeting( 'meetings_pro_calculated', $meeting ) ) {
        $self->_calculate_meeting_is_pro( $meeting, $creator_user );
    }

    my $partner_id = $self->_get_note_for_meeting( sponsoring_partner_id => $meeting );
    my $partner = $partner_id ? $self->PARTNERS_BY_ID->{ $partner_id } : undef;

    my $sponsors_json = $self->_get_note_for_meeting( sponsoring_users => $meeting );
    my $sponsors_hash = Dicole::Utils::JSON->decode( $sponsors_json || '{}' );

    my $id_list = [];
    for my $id ( keys %$sponsors_hash ) {
        push @$id_list, $id unless $sponsors_hash->{ $id } && time > $sponsors_hash->{ $id };
    }

    my $users = Dicole::Utils::User->ensure_object_list( $id_list );

    my @sponsor_names = ();
    push @sponsor_names, $partner->{name} if $partner;
    push @sponsor_names, map { Dicole::Utils::User->name( $_ ) } @$users;

    return \@sponsor_names;
}

sub _meeting_sponsor_names_string {
    my ( $self, $meeting, $sponsor_names ) = @_;

    $sponsor_names ||= $self->_meeting_sponsor_names( $meeting );

    my @sponsors = @$sponsor_names;
    my $last_sponsor = pop @sponsors;

    return join ( " and ", ( join( ", ", @sponsors ) || (), $last_sponsor || () ) );
}

sub _calculate_meeting_is_pro {
    my ($self, $meeting, $creator_user ) = @_;

    return if ! $meeting;
    $meeting = $self->_ensure_meeting_object( $meeting );

    my $domain_id = $meeting->domain_id;
    $creator_user ||= $meeting->creator_id ? Dicole::Utils::User->ensure_object( $meeting->creator_id ) : undef;

    $self->_set_note_for_meeting( 'meetings_is_pro' => 0, $meeting, { skip_save => 1 } );

    if ( $creator_user && $self->_user_is_pro( $creator_user, $domain_id ) ) {
        $self->_set_note_for_meeting( 'meetings_is_pro' => 1, $meeting, { skip_save => 1 } );
        $self->_set_note_for_meeting( 'meetings_is_pro_expires' => $self->_user_is_pro_expires( $creator_user, $domain_id ), $meeting, { skip_save => 1 } );
    }

    my $partner_id = $self->_get_note_for_meeting( sponsoring_partner_id => $meeting );
    my $meeting_sponsored_expires = $partner_id ? 0 : -1;

    my $users = $self->_fetch_meeting_participant_users( $meeting );

    my %sponsors = ();
    for my $user ( @$users ) {
        next unless $user && $self->_user_is_pro( $user, $domain_id );
        my $user_pro_expires = $self->_user_is_pro_expires( $user, $domain_id );
        $sponsors{ $user->id } = $user_pro_expires;

        if ( $meeting_sponsored_expires ) {
            $meeting_sponsored_expires = $user_pro_expires if $user_pro_expires > $meeting_sponsored_expires;
            $meeting_sponsored_expires = 0 if ! $user_pro_expires;
        }
    }

    $self->_set_note_for_meeting( sponsoring_users => Dicole::Utils::JSON->encode( \%sponsors ), $meeting, { skip_save => 1 } );

    if ( $partner_id || scalar( keys %sponsors ) ) {
        $self->_set_note_for_meeting( 'meetings_is_sponsored' => 1, $meeting, { skip_save => 1 } );
        $self->_set_note_for_meeting( 'meetings_is_sponsored_expires' => $meeting_sponsored_expires, $meeting, { skip_save => 1 } );
    }

    $self->_set_note_for_meeting( 'meetings_pro_calculated' => time, $meeting );
}

sub _determine_user_base_group {
    my ( $self, $user, $domain_id ) = @_;

    return 0 unless $user || CTX->request->auth_user_id;
    $user ||= CTX->request->auth_user;
    $user = Dicole::Utils::User->ensure_object( $user );

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    die unless $domain_id;

    return 0 unless $user;

    my $base_gid = $self->_get_note_for_user( 'meetings_base_group_id', $user, $domain_id );

    if ( ! $base_gid ) {
        my $group = CTX->lookup_action('groups_api')->e( add_group => {
            name => $user->id,
            creator_id => $user->id,
            domain_id => $domain_id,
        } );

        $self->_set_note_for_user( 'meetings_base_group_id', $group->id, $user, $domain_id );
        $base_gid = $group->id;
    }

    return $base_gid;
}

sub _notification_requested_for_user {
    my ( $self, $notification, $user ) = @_;

    return $self->_get_note_for_user( 'requested_notification_for_' . $notification, $user );
}

sub _strip_tag_from_page_title {
    my ( $self, $title ) = @_;

    $title =~ s/ \(#meeting_\d+\)$//;

    return $title;
}

sub _get_meeting_highlight_data_for_user {
    my ( $self, $meeting, $user ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $user = Dicole::Utils::User->ensure_object( $user );

    # NOTE: expects the there is only one manager before draft ready so this is called for manager only!
    if ( $self->_meeting_is_draft( $meeting ) ) {
        my $dpos = $self->_fetch_meeting_draft_participation_objects( $meeting );
        if ( ! @$dpos ) {
            return {
                type => 'add_participants',
                message => $self->_ncmsg('Add Participants', { user => $user }),
            }
        }

        my $content_highlight = $self->_resolve_common_before_meeting_content_hightlights_for_admin( $meeting, $user );
        return $content_highlight if $content_highlight;

        return {
            type => 'send_invitations',
            message => $self->_ncmsg('Send Invitations', { user => $user }),
        }
    }
    else {
        my $euos = $self->_fetch_meeting_participation_objects( $meeting );
        my $euo = $self->_fetch_meeting_participant_object_for_user( $meeting, $user, $euos );
        my $is_manager = $euo->is_planner ? 1 : 0;

        return undef unless $is_manager;

        if ( ! $meeting->begin_date || $meeting->begin_date > time ) {
            my $content_highlight = $self->_resolve_common_before_meeting_content_hightlights_for_admin( $meeting, $user );
            return $content_highlight if $content_highlight;
        }
        elsif ( $meeting->end_date < time && $meeting->end_date + 12*60*60 > time ) {
            my $ap_page = $self->_fetch_meeting_action_points_page( $meeting );
            if ( $ap_page && ! $ap_page->last_content_id_wiki_content->content ) {
                return {
                    type => 'fill_action_points',
                    message => $self->_ncmsg('Fill Action Points', { user => $user }),
                };
            }
        }
    }

    return undef;
}

sub _resolve_common_before_meeting_content_hightlights_for_admin {
    my ( $self, $meeting, $user ) = @_;

    if ( ! $meeting->title ) {
        return {
            type => 'set_title',
            message => $self->_ncmsg('Set a Title', { user => $user }),
        }
    }

    if ( ! $meeting->begin_date ) {
        my $pos = $self->_fetch_meeting_proposals( $meeting );
        if ( ! @$pos ) {
            return {
                type => 'suggest_dates',
                message => $self->_ncmsg('Suggest Dates', { user => $user })
            };
        }
        else {
            # TODO: pick a date only if all have answered
        }
    }

    if ( ! $meeting->location_name ) {
        return {
            type => 'set_location',
            message => $self->_ncmsg('Set the Location', { user => $user }),
        }
    }

    my $a_page = $self->_fetch_meeting_agenda_page( $meeting );
    if ( $a_page && ! $a_page->last_content_id_wiki_content->content ) {
        return {
            type => 'add_agenda',
            message => $self->_ncmsg('Add Agenda', { user => $user }),
        }
    }

    return undef;
}

sub _get_meetings_in_domain {
    my ( $self, $domain_id, $extra_where, $order, $limit ) = @_;

    my $sql = 'SELECT DISTINCT dicole_events_event.*, GREATEST( dicole_events_event.begin_date, dicole_events_event.created_date ) sort_date' .
        ' FROM dicole_events_event' .
        " WHERE dicole_events_event.domain_id = $domain_id AND removed_date = 0" .
        ( $extra_where ? " AND ( $extra_where )" : '' ) .
        ( $order ? " ORDER BY $order" : "" ) .
        ( $limit ? " LIMIT $limit" : "" );

    my $events = CTX->lookup_object('events_event')->fetch_group( {
        sql => $sql,
    } );

    return $events;
}

sub _get_meetings_within_timespan_in_domain {
    my ( $self, $span, $domain_id, $extra_where ) = @_;

    my $from = $span->start->epoch;
    my $to = $span->end->epoch;

    return $self->_get_meetings_within_epochs_in_domain( $from, $to, $domain_id, $extra_where );
}

sub _get_meetings_within_epochs_in_domain {
    my ( $self, $from, $to, $domain_id, $extra_where ) = @_;

    my @where = ( $extra_where || () );
    $to =~ s/\D//g;
    $from =~ s/\D//g;
    push @where, "dicole_events_event.begin_date < $to AND dicole_events_event.end_date > $from";

    my $where = '(' . join( ") AND (", @where ) . ')';

    return $self->_get_meetings_in_domain(
        $domain_id, $where
    );
}

sub _get_user_meetings_within_epochs_in_domain {
    my ( $self, $user, $from, $to, $domain_id, $extra_where ) = @_;

    my @where = ( $extra_where || () );
    $to =~ s/\D//g;
    $from =~ s/\D//g;
    push @where, "dicole_events_event.begin_date < $to AND dicole_events_event.end_date > $from";

    my $where = '(' . join( ") AND (", @where ) . ')';

    return $self->_get_upcoming_user_meetings_in_domain(
        $user, $domain_id, $where
    );
}

sub _get_upcoming_user_meetings_in_domain {
    my ( $self, $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $date = Dicole::Utils::Date->epoch_to_datetime( time );
    $date->set( hour => 0 , minute => 0, second => 0 );
    my $addition = "dicole_events_event.begin_date >= " . $date->epoch;
    $extra_where = $extra_where ? "( $extra_where ) AND ( $addition )" : $addition;

    return $self->_get_user_meetings_in_domain( $user, $domain_id, $extra_where, $order, $limit );
}

sub _get_user_meetings_in_domain {
    my ( $self, $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $sql = 'SELECT DISTINCT dicole_events_event.*, GREATEST( dicole_events_event.begin_date, dicole_events_event.created_date ) sort_date' .
        ' FROM dicole_events_event, dicole_events_user' .
        " WHERE dicole_events_user.domain_id = $domain_id AND dicole_events_user.user_id = $user_id" .
        ' AND dicole_events_event.event_id = dicole_events_user.event_id AND dicole_events_event.removed_date = 0 AND dicole_events_user.removed_date = 0' .
        ( $extra_where ? " AND ( $extra_where )" : '' ) .
        ( $order ? " ORDER BY $order" : "" ) .
        ( $limit ? " LIMIT $limit" : "" );

    my $events = CTX->lookup_object('events_event')->fetch_group( {
        sql => $sql,
    } );

    return $events;
}

sub _get_active_user_meeting_suggestions {
    my ( $self,  $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $addition = "disabled_date = 0 AND vanished_date = 0";
    $extra_where = $extra_where ? "( $extra_where ) AND ( $addition )" : $addition;

    return $self->_get_user_meeting_suggestions( $user, $domain_id, $extra_where, $order, $limit );
}

sub _get_upcoming_active_user_meeting_suggestions {
    my ( $self, $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $addition = "end_date >= " .  ( time - 24*60*60 );
    $extra_where = $extra_where ? "( $extra_where ) AND ( $addition )" : $addition;

    return $self->_get_active_user_meeting_suggestions( $user, $domain_id, $extra_where, $order, $limit );
}

sub _get_nonvanished_user_suggestions_within_epochs_in_domain {
    my ( $self, $user, $from, $to, $domain_id, $extra_where ) = @_;

    my @where = ( $extra_where || () );
    $to =~ s/\D//g;
    $from =~ s/\D//g;
    push @where, "begin_date < $to AND end_date > $from AND vanished_date = 0";

    my $where = '(' . join( ") AND (", @where ) . ')';

    return $self->_get_user_meeting_suggestions(
        $user, $domain_id, $where
    );
}

sub _get_upcoming_nonvanished_user_meeting_suggestions {
    my ( $self, $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $addition = "end_date >= " .  ( time - 24*60*60 ) . " AND vanished_date = 0";
    $extra_where = $extra_where ? "( $extra_where ) AND ( $addition )" : $addition;

    return $self->_get_user_meeting_suggestions( $user, $domain_id, $extra_where, $order, $limit );
}

sub _get_user_meeting_suggestions {
    my ( $self, $user, $domain_id, $extra_where, $order, $limit ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;

    my $suggestions = CTX->lookup_object('meetings_meeting_suggestion')->fetch_group( {
            where => "removed_date = 0 AND user_id = ?" . ( $extra_where ? " AND ( $extra_where )" : '' ),
            value => [ $user_id ],
            order => $order,
            limit => $limit,
    } );

    return $suggestions;
}

sub _get_user_google_calendars {
    my ( $self, $user, $domain_id, $force_refresh ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    $self->_ensure_user_google_calendars_are_imported( $user, $domain_id, $force_refresh );

    my $sources = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
            where => "user_id = ? AND provider_type = ?",
            value => [ $user->id, 'google' ],
    } );

    return $sources;
}

sub _create_shortened_url {
    my ( $self, $url, $by_user, $notes ) = @_;

    my @chars = split //, "abcdefghjkmnpqrstxz23456789";
    my $code;

    for ( 1..10 ) {
        $code = join "", map { $chars[rand @chars] } 1 .. 16;

        my $obj = CTX->lookup_object('meetings_shortened_url')->new( {
            creator_id => $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : 0,
            created_date => time,
            removed_date => 0,
            code => $code,
            url => $url,
        } );

        $self->_set_notes( $notes, $obj );

        my $objs = CTX->lookup_object('meetings_shortened_url')->fetch_group( {
            where => 'code = ?',
            value => [ $code ],
            order => 'id asc'
        } );

        shift @$objs;

        if ( @$objs ) {
            $objs->remove;
            $code = '';
        }
        else {
            last;
        }
    }

    return '' unless $code;

    my $domain = CTX->server_config->{dicole}->{shorted_url_base} || 'http://d.sw2.me/';

    return $domain . $code;
}

sub _get_url_from_shortened_url {
    my ( $self, $url ) = @_;

    my $obj = $self->_get_url_object_from_shortened_url( $url );

    return $obj ? $obj->url : '';
}

sub _get_url_object_from_shortened_url {
    my ( $self, $url ) = @_;

    my $code = $url;
    if ( $code =~ /\// ) {
        ( $code ) = $url =~ /.*\/(.*)/;
    }

    my $objs = CTX->lookup_object('meetings_shortened_url')->fetch_group( {
        where => 'code = ?',
        value => [ $code ],
        order => 'id asc'
    } );

    return shift @$objs;
}

sub _get_user_meetings_within_timespan_in_domain {
    my ( $self, $user, $span, $domain_id, $extra_where ) = @_;

    return [] unless $span && ! $span->duration->is_zero();

    my @where = ( $extra_where || () );

    if ( ref( $span->duration ) ) {
        my $from = $span->start->epoch;
        my $to = $span->end->epoch;

        push @where, "dicole_events_event.begin_date < $to AND dicole_events_event.end_date > $from";
    }

    my $where = '(' . join( ") AND (", @where ) . ')';

    return $self->_get_user_meetings_in_domain(
        $user, $domain_id, $where
    );
}

sub _count_user_meetings_in_domain {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_count_user_meeting_participation_objects_in_domain( $user, $domain_id );
}

sub _fetch_created_meetings_by_user_hash_for_domain {
    my ( $self, $domain_id ) = @_;

    my $objects = $self->_fetch_meetings( {
        where => 'domain_id = ?',
        value => [ $domain_id ],
    }) || [];

    my $by_user = {};
    for my $ob ( @$objects ) {
        my $list = $by_user->{ $ob->creator_id } ||= [];
        push @$list, $ob;
    }

    return $by_user;
}

sub _fetch_user_created_meetings_in_domain {
    my ( $self, $user, $domain_id ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return $self->_fetch_meetings( {
        where => 'creator_id = ? AND domain_id = ?',
        value => [ $user_id, $domain_id ],
    } ) || [];
}

sub _count_user_created_meetings_in_domain {
    my ( $self, $user, $domain_id ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_object('events_event')->fetch_count( {
        where => 'creator_id = ? AND domain_id = ? AND removed_date = 0',
        value => [ $user_id, $domain_id ],
    } ) || 0;
}

sub _get_user_meeting_participation_objects_in_domain {
    my ( $self, $user, $domain_id, $extra_where, $extra_values ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my @where = ('user_id = ? AND domain_id = ? AND removed_date = 0');
    my @value = ( $user_id, $domain_id );

    push @where, $extra_where || ();
    my $where = '('. join( ') AND (', @where ) .')';

    push @value, @{ $extra_values || [] };

    return CTX->lookup_object('events_user')->fetch_group( {
        where => $where,
        value => \@value,
    } ) || [];
}

sub _count_user_meeting_participation_objects_in_domain {
    my ( $self, $user, $domain_id ) = @_;

    my $user_id = $user ? Dicole::Utils::User->ensure_id( $user ) : CTX->request->auth_user_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return CTX->lookup_object('events_user')->fetch_count( {
        where => 'user_id = ? AND domain_id = ? AND removed_date = 0',
        value => [ $user_id, $domain_id ],
    } ) || 0;
}

sub _gather_quickbar_meetings_for_user_api {
    my ( $self, $user, $domain_id ) = @_;

    my $list = $self->_gather_quickbar_meetings_for_user( $user, $domain_id );
    return [ map { {
        id => $_->{id},
        title => $_->{title},
        begin_epoch => $_->{begin_epoch},
        desktop_url => $_->{url},
    } } @$list ];
}

sub _gather_quickbar_meetings_for_user {
    my ( $self, $user, $domain_id ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $user = Dicole::Utils::User->ensure_object( $user );

    my $ueos = CTX->lookup_object('events_user')->fetch_group( {
        where => 'user_id = ? AND domain_id = ? AND removed_date = 0',
        value => [ $user->id, $domain_id ],
    } );

    my $events = $self->_fetch_meetings( {
        where => Dicole::Utils::SQL->column_in( event_id => [ map { $_->event_id } @$ueos ] ),
    } );

    my %euo_lookup = map { $_->event_id => $_ } @$ueos;

    #my @quickbar_events = map { $euo_lookup{ $_->id }->attend_date == 0 ? $_ : () } @$events;
    #my @scheduled_events = map { $_->begin_date ? () : $_ } @quickbar_events;
    #my @sortable_events = map { $_->begin_date ? $_ : () } @quickbar_events;

    my @sorted_events = reverse sort {
        ($a->begin_date || $a->created_date) <=> ($b->begin_date || $b->created_date)
    } @$events;

    return [ map { {
        title => $self->_meeting_title_string( $_ ),
        id => $_->id,
        begin_epoch => $_->begin_date,
        begin_date => $self->_epoch_to_mdy( $_->begin_date, $user ) || undef,
        url => $self->derive_url( action => 'meetings', task => 'meeting', target => $_->group_id, additional => [ $_->id ] ),
    } } @sorted_events ];
}

sub _get_valid_cloaked_event {
    my ( $self, $action, $meeting_id, $meeting_cloak ) = @_;

    $meeting_cloak ||= $self->param( 'cloak_hash' );

    return unless $meeting_cloak;

    my $meeting = $self->_get_valid_event( $action, $meeting_id );

    return unless $meeting;

    my $cloak = $self->_get_meeting_cloaking_hash( $meeting );

    return unless lc( $cloak ) eq lc( $meeting_cloak );

    return $meeting;
}

sub _get_valid_event {
    my ( $self, $action, $meeting_id ) = @_;

    $action ||= $self;
    $meeting_id ||= $action->param('event_id');

    my $meeting = $self->_events_api( ensure_event_object_in_group => { event_id => $meeting_id, group_id => $action->param('target_group_id')} );

#    if ($self->_meeting_is_sponsored($meeting)) {
#        return if $self->_redirect_unless_https($meeting);
#
#        unless ($self->_session_is_secure) {
#            $self->_send_secure_login_link($meeting);
#            die $self->redirect( $self->derive_url( action => 'meetings', task => 'secure_login_info' ) );
#        }
#    }

    return $meeting;
}

sub _redirect_to_auth_path_for_mobile {
    my ( $self, $meeting ) = @_;

    # TODO: check disabling cookie

    if ( CTX->request && CTX->request->param('dic') ) {
        if ( $self->_current_user_agent_is_mobile ) {
            return $self->_offer_mobile() unless $meeting;

            if ( $meeting && ! CTX->request->cookie('cookie_parameter_open_promo_subscribe') && ! CTX->request->cookie('cookie_parameter_open_language_selector') ) {
                    if ( my $matchmaking_response = CTX->request->param('matchmaking_response') ) {
                        return $self->_offer_mobile( { meeting_id => $meeting->id, matchmaking_response => $matchmaking_response } );
                    }

                    return $self->_offer_mobile( { meeting_id => $meeting->id } ) if $meeting->begin_date;

                    my $pos = $self->_fetch_meeting_proposals( $meeting );

                    return $self->_offer_mobile( { meeting_id => $meeting->id } ) unless @$pos;

                    my $eus = $self->_fetch_meeting_participation_objects( $meeting );

                    my $all_answered = 1;
                    my $user_answered = 1;

                    for my $euo ( @$eus ) {
                        my $open = $self->_fetch_open_meeting_proposals_for_user( $meeting, $euo->user_id, $euo, $pos );
                        $all_answered = 0 if scalar( @$open );
                        $user_answered = 0 if scalar( @$open ) && $euo->user_id == CTX->request->auth_user_id;
                    }

                    return $self->_offer_mobile( { meeting_id => $meeting->id, proposals => 'answer' } ) unless $user_answered;

                    return $self->_offer_mobile( { meeting_id => $meeting->id, proposals => 'choose' } ) if $all_answered &&
                        $self->_user_can_manage_meeting( CTX->request->auth_user, $meeting );

                    return $self->_offer_mobile( { meeting_id => $meeting->id } );
            }
        }
        if ( $self->_current_user_agent_is_mobile ) {
            unless ( CTX->request->url_relative =~ /^\/?($|\?|\#)/ ) {
                OpenInteract2::Cookie->create( {
                    name => 'override_path',
                    path => '/',
                    expires => '+1h',
                    value => time . Dicole::URL->strip_auth_from_current,
                    HEADER => 'YES',
                } );

                my $u = URI->new( '/' );
                $u->query_form( dic => CTX->request->param('dic') );

                return $self->redirect( $u->as_string );
            }
        }
    }
}

sub _redirect_meetme_for_mobile {
    my ( $self ) = @_;
    if ( $self->_current_user_agent_is_mobile ) {
        return $self->_offer_mobile( { meetme => 1 } );
    }
}

sub _redirect_lock_confirm_for_mobile {
    my ( $self, $lock ) = @_;
    if ( $self->_current_user_agent_is_mobile ) {
        return $self->_offer_mobile( { confirmed_matchmaker_lock_id => $lock->id } );
    }
}

sub _redirect_for_mobile_with_params {
    my ( $self, $params ) = @_;
    if ( $self->_current_user_agent_is_mobile ) {
        return $self->_offer_mobile( $params );
    }
}

sub _current_user_agent_is_mobile {
    my ( $self ) = @_;

    return ( ( CTX->request && CTX->request->user_agent =~ /iPhone|iPad|Android|Lumia/i ) ? 1 : 0 );
}

sub _offer_mobile {
    my ( $self, $params ) = @_;

    $params ||= {};

    die $self->redirect( $self->derive_url(
            action => 'meetings_raw',
            task => 'offer_mobile',
            params => {
                ( CTX->request->param('dic') ? ( dic => CTX->request->param('dic') ) : () ),
                %$params,
            }
        ) );
}

sub _redirect_to_hide_url_authentication {
    my ( $self ) = @_;

    if ( CTX->request && CTX->request->param('dic') ) {
        return if CTX->request->user_agent =~ /iPhone|iPad|iPod|Lumia/i || CTX->request->url_relative =~ /^\/?($|\?|\#)/;

        return $self->redirect( Dicole::URL->strip_auth_from_current );
    }
}

sub _fetch_meeting_proposals {
    my ( $self, $meeting ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    my $dates = CTX->lookup_object('meetings_date_proposal')->fetch_group({
# NOTE: for migration easing purposes use code filtering - can be simplified to a query like this later..
#        where => 'domain_id = ? AND meeting_id = ? AND removed_date = ? AND disabled_date = ?',
#        value => [ $meeting->domain_id, $meeting->id, 0, 0 ],
        where => 'domain_id = ? AND meeting_id = ?',
        value => [ $meeting->domain_id, $meeting->id ],
    }) || [];

    return [ map { ( $_->removed_date || $_->disabled_date ) ? () : $_ } @$dates ];
}

sub _fetch_proposal_hash_for_meetings {
    my ( $self, $meetings ) = @_;

    return {} unless @$meetings;

    my @id_list = map { $_->id } @$meetings;
    my $dates = CTX->lookup_object('meetings_date_proposal')->fetch_group({
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( meeting_id => \@id_list ),
        value => [ $meetings->[0]->domain_id ],
    } ) || [];

    my $hash = {};
    for my $date ( map { ( $_->removed_date || $_->disabled_date ) ? () : $_ } @$dates ) {
        my $list = $hash->{ $date->meeting_id } ||= [];
        push @$list, $date;
    }

    return $hash;
}

sub _clear_meeting_proposals {
    my ( $self, $meeting, $pos ) = @_;

    $pos ||= $self->_fetch_meeting_proposals( $meeting );

    $self->_disable_meeting_proposed_date( $meeting, $_ ) for @$pos;
}

sub _fetch_open_meeting_proposals_for_user {
    my ( $self, $meeting, $user, $euo, $pos ) = @_;

    $euo ||= $self->_fetch_meeting_participant_object_for_user( $meeting, $user );
    $pos ||= $self->_fetch_meeting_proposals( $meeting );

    my @pos = map { $self->_get_note_for_meeting_user( 'answered_proposal_' . $_->id, $meeting, $user, $euo ) ? () : $_ } @$pos;

    return \@pos;
}

sub _add_meeting_proposed_date {
    my ( $self, $meeting, $begin_date, $end_date, $creator, $creator_euo ) = @_;

    my $creator_id = $creator ? Dicole::Utils::User->ensure_id( $creator ) : eval { CTX->request->auth_user_id };

    my $object = CTX->lookup_object('meetings_date_proposal')->new( {
        domain_id => $meeting->domain_id,
        meeting_id => $meeting->id,
        created_date => time,
        removed_date => 0,
        disabled_date => 0,
        created_by => $creator_id || 0,
        begin_date => $begin_date,
        end_date => $end_date,
    } );

    $object->save;

    $self->_set_note_for_meeting_user( 'answered_proposal_' . $object->id => 'yes', $meeting, $creator, $creator_euo );

    $self->_store_date_proposal_event( $meeting, $object, 'created' );

    return $object;
}

sub _set_meeting_proposed_date_answer {
    my ( $self, $meeting, $proposal, $user, $value, $euo ) = @_;

    $self->_set_note_for_meeting_user( 'answered_proposal_' . $proposal->id => $value, $meeting, $user, $euo );

    my $params = { data => {
        answer_user_id => Dicole::Utils::User->ensure_id( $user ),
        answer_value => $value,
    } };

    $self->_store_date_proposal_event( $meeting, $proposal, 'answered', $params );
}

sub _get_meeting_proposed_date_answer {
    my ( $self, $meeting, $proposal, $user, $euo ) = @_;

    return $self->_get_note_for_meeting_user( 'answered_proposal_' . $proposal->id, $meeting, $user, $euo );
}

sub _disable_meeting_proposed_date {
    my ( $self, $meeting, $proposal ) = @_;

    $proposal->disabled_date( time );
    $proposal->save;

    $self->_store_date_proposal_event( $meeting, $proposal, 'disabled' );

    return 1;
}

sub _remove_meeting_proposed_date {
    my ( $self, $meeting, $proposal ) = @_;

    $proposal->removed_date( time );
    $proposal->save;

    $self->_store_date_proposal_event( $meeting, $proposal, 'deleted' );

    return 1;
}

sub _timespan_for_proposal {
    my ( $self, $po, $user ) = @_;

    return $self->_form_timespan_string_from_epochs( $po->begin_date, $po->end_date, $user );
}

sub _timespan_parts_for_proposal {
    my ( $self, $po, $user ) = @_;

    return $self->_form_timespan_parts_from_epochs_for_user( $po->begin_date, $po->end_date, $user );
}

sub _timespan_for_meeting {
    my ( $self, $meeting, $user ) = @_;

    return $self->_form_timespan_string_from_epochs( $meeting->begin_date, $meeting->end_date, $user );
}

sub _timespan_parts_for_meeting {
    my ( $self, $meeting, $user ) = @_;

    return $self->_form_timespan_parts_from_epochs_for_user( $meeting->begin_date, $meeting->end_date, $user );
}

sub _form_timespan_string_from_epochs {
    my ( $self, $begin, $end, $user ) = @_;

    return $self->_form_timespan_string_from_timespan_parts(
        $self->_form_timespan_parts_from_epochs_for_user( $begin, $end, $user )
    );
}

sub _form_timespan_string_from_epochs_tz_and_lang {
    my ( $self, $begin, $end, $timezone, $lang ) = @_;

    return $self->_form_timespan_string_from_timespan_parts(
        $self->_form_timespan_parts_from_epochs_tz_and_lang( $begin, $end, $timezone, $lang )
    );
}

sub _form_timespan_string_from_timespan_parts {
    my ( $self, $date, $times, $timezone_string ) = @_;

    return "$date, $times" . ( $timezone_string ? " $timezone_string" : "" );
}

sub _form_timespan_parts_from_epochs_for_user {
    my ( $self, $begin, $end, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user ) if $user;

    my $timezone = $user ? $user->timezone : undef;
    my $lang = $user ? $user->language : 'en';

    return $self->_form_timespan_parts_from_epochs_tz_and_lang( $begin, $end, $timezone, $lang );
}

sub _form_timespan_parts_from_epochs_tz_and_lang {
    my ( $self, $begin, $end, $timezone, $lang ) = @_;

    return () unless $begin && $end;

    $lang ||= 'en';

    my $begin_dt = Dicole::Utils::Date->epoch_to_datetime( $begin, $timezone, $lang );
    my $end_dt = ( $end && $end > $begin ) ? Dicole::Utils::Date->epoch_to_datetime( $end, $timezone, $lang ) : undef;

    my $wd = ucfirst( $begin_dt->day_name );
    my $day = $begin_dt->day;
    my $month = ucfirst( $begin_dt->month_name );

    my @times = ( Dicole::Utils::Date->datetime_to_hour_minute( $begin_dt, ( $lang eq 'en' ) ? 'ampm' : '24h' ) );
    push @times, $end_dt ? Dicole::Utils::Date->datetime_to_hour_minute( $end_dt, ( $lang eq 'en' ) ? 'ampm' : '24h' ) : ();

    my $timezone_string = $timezone
        ? Dicole::Utils::Date->timezone_info($timezone)->{offset_string}
        : "";

    my $ordinal_day = [ qw( th st nd rd th th th th th th ) ]->[ $day % 10 ];
    my $date = ( $lang eq 'en' ) ? "$wd $month $day$ordinal_day" : "$wd $day. $month";

    return ( $date, join( "-", @times ), $timezone_string );
}

sub _form_date_from_epoch_for_user {
    my ( $self, $epoch, $user ) = @_;

    $self->_form_date_from_epoch_tz_and_lang( $epoch, $user->timezone, $user->language );
}

sub _form_date_from_epoch_tz_and_lang {
    my ( $self, $epoch, $timezone, $lang ) = @_;

    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch, $timezone, $lang );
    my $wd = ucfirst( $dt->day_name );
    my $day = $dt->day;
    my $month = ucfirst( $dt->month_name );

    my $date = "$wd $day. $month";
    if ( $lang eq 'en' ) {
        my $ordinal_day = [ qw( th st nd rd th th th th th th ) ]->[ $day % 10 ];
        $ordinal_day = 'th' if $day == 11 || $day == 12;
        $date = "$wd $month $day$ordinal_day";
    }

    $date .= ' ' . $dt->year unless $dt->year == Dicole::Utils::Date->epoch_to_datetime( time, $timezone, $lang )->year;

    return $date;
}

sub _choose_proposal_for_meeting {
    my ( $self, $meeting, $proposal_id, $params ) = @_;

    $params ||= {};

    my $pos = $params->{pos} ||= $self->_fetch_meeting_proposals( $meeting );
    my $euos = $params->{euos} ||= $self->_fetch_meeting_participation_objects( $meeting );

    for my $proposal ( @$pos ) {
        next if $proposal->id != $proposal_id;

        for my $euo ( @$euos ) {
            if ( my $answer = $self->_get_meeting_proposed_date_answer( $meeting, $proposal, $euo->user_id, $euo ) ) {
                # NOTE: this should be either 'yes' or 'no'
                $self->_set_note_for_meeting_user( rsvp => $answer, $meeting, $euo->user_id, $euo );
            }
        }

        $self->_set_date_for_meeting( $meeting, $proposal->begin_date, $proposal->end_date, { euos => $euos, set_by_user_id => $params->{set_by_user_id}, require_rsvp_again => $params->{require_rsvp} || 0 } );

        return 1;
    }

    return 0;
}

sub _set_date_for_meeting {
    my ( $self, $meeting, $begin_date, $end_date, $params ) = @_;

    my $old_info = $self->_gather_meeting_event_info( $meeting );

    $meeting->begin_date( $begin_date );
    $meeting->end_date( $end_date );
    $meeting->save;

    my $new_info = $self->_gather_meeting_event_info( $meeting );

    $self->_store_meeting_event( $meeting, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
        skip_notification => $params->{set_from_scheduling_id} ? 1 : 0,
    } ) unless $params->{skip_event};

    my $pos = $params->{pos} || $self->_fetch_meeting_proposals( $meeting );
    $self->_clear_meeting_proposals( $meeting, $pos ) unless $params->{skip_proposal_clearing};

    my $set_by_user_id = $params->{set_by_user_id} || eval { CTX->request->auth_user_id };
    my $euos = $params->{euos} || $self->_fetch_meeting_participation_objects( $meeting );

    $self->_require_rsvp_again_for_meeting_users( $meeting, { euos => $euos, set_by_user_id => $set_by_user_id } ) if $params->{require_rsvp_again};

    my $matchmaker_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $meeting );

    my $matchmaker = $matchmaker_id ? $self->_ensure_matchmaker_object( $matchmaker_id ) : undef;

    for my $euo ( @$euos ) {
        next if $old_info->{begin_epoch} == $new_info->{begin_epoch} && $old_info->{end_epoch} == $new_info->{end_epoch};
        next if scalar( @$pos ) && $params->{skip_proposal_clearing};
        next if $self->_meeting_is_draft( $meeting );

        my $action = 'time_was_cleared';

        if ( $new_info->{begin_epoch} ) {
            if ( scalar( @$pos ) ) {
                $action = 'proposal_was_chosen';
            }
            elsif ( $old_info->{begin_epoch} ) {
                $action = 'time_was_changed'
            }
            else {
                $action = 'time_is_set';
            }
        }

        my $user = Dicole::Utils::User->ensure_object( $euo->user_id );
        my $rsvp_required_parameters = $self->_meeting_user_rsvp_required_parameters( $meeting, $user );

        my $sent_by_self = ( $set_by_user_id && $set_by_user_id == $euo->user_id ) ? 1 : 0;
        if ( $params->{set_from_scheduling_id} ) {
            $self->_ensure_scheduling_instruction( $params->{set_from_scheduling_id}, 'time_found' );
            $self->_record_notification(
                user_id => $user->id,
                date => time,
                type => 'scheduling_date_found',
                data => {
                    author_id => $meeting->creator_id,
                    meeting_id => $meeting->id,
                    scheduling_id => $params->{set_from_scheduling_id},
                },
            );
        }
        elsif ( ! $sent_by_self ) {
            $self->_send_meeting_user_template_mail( $meeting, $user, 'time_changed', {
                %$rsvp_required_parameters,
                $action => 1,
            } );

            $self->_send_meeting_user_invite_sms( $meeting, $user, 'lt_custom_reschedule', $matchmaker );
        };

        my $rsvp_answer = $self->_get_note_for_meeting_user( rsvp => $meeting, $user ) || 'yes';

        my $lthack = $matchmaker ? $self->_get_note( lahixcustxz_hack => $matchmaker ) : undef;
        if ( $lthack ) {
            if ( $user->id == $self->_get_note_for_meeting( matchmaking_requester_id => $meeting ) ) {
                $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'time_changed', lahixcustxz_hack => { this_disables_promo => 1 } } );
            }
            elsif ( $user->id == $meeting->creator_id ) {
                $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'time_changed_by_self', lahixcustxz_hack => { no_data_for_reschedule => 1 }, send_copy_to => $self->_get_note( send_ics_copy_to => $matchmaker ) } );
            };
        }
        elsif ( $meeting->begin_date && $rsvp_answer eq 'yes' && ! $rsvp_required_parameters->{rsvp_required} ) {
            $self->_send_meeting_ical_request_mail( $meeting, $user, { type => $params->{set_from_scheduling_id} ? 'scheduling_completed' : $sent_by_self ? 'time_changed_by_self' : 'time_changed' } );
        }
    }

    # Send the 15 minutes before digest even if moved close by and digest_checked is near
    if ( time < $meeting->begin_date && time > $meeting->begin_date - ( 75 * 60 ) ) {
        $self->_set_note_for_meeting( 'digest_checked', $meeting->begin_date - ( 75 * 60 ), $meeting, { skip_save => 1 } );
    }

    # Send before and after emails again if time changes
    $self->_set_note_for_meeting( 'before_emails_sent', undef, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( 'after_emails_sent', undef, $meeting );

    for my $po ( @$euos ) {
        $self->_set_note_for_meeting_user( 'digest_meeting_start_sent', undef, $meeting, $po->user_id, $po );
    }

    if ( $meeting->begin_date && $params->{set_from_scheduling_id} ) {
        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $params->{set_from_scheduling_id} );

        $scheduling->completed_date( time );
        $scheduling->save;

        $self->_set_meeting_current_scheduling( $meeting, 0 );

        $self->_record_scheduling_log_entry_for_user( "time_found", $scheduling, $params->{set_by_user_id}, { found_epoch => $begin_date } );

        $self->_dispatch_ensure_fresh_segment_identify_for_user( $scheduling->creator_id );

        for my $euo ( @$euos ) {
            $self->_dispatch_user_pusher_event( $euo->user_id, 'scheduling_time_found', { scheduling_id => $scheduling->id } );
        }
    }
    elsif ( $meeting->begin_date && $self->_get_note( current_scheduling_id => $meeting ) ) {
        my $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $self->_get_note( current_scheduling_id => $meeting ) );

        $scheduling->cancelled_date( time );
        $scheduling->save;

        $self->_set_meeting_current_scheduling( $meeting, 0 );

        $self->_record_scheduling_log_entry_for_user( "time_set_manually", $scheduling, $params->{set_by_user_id}, {} );

        for my $euo ( @$euos ) {
            $self->_dispatch_user_pusher_event( $euo->user_id, 'scheduling_time_found', { scheduling_id => $scheduling->id } );
        }
    }

    return 1;
}

sub _dispatch_ensure_fresh_segment_identify_for_user {
    my ( $self, $user ) = @_;

    my $user_id = Dicole::Utils::User->ensure_id( $user );

    Dicole::Utils::Gearman->dispatch_task( ensure_fresh_segment_identify_for_user => {
        user_id => $user_id,
    } );
}

sub _dispatch_user_pusher_event {
    my ( $self, $user, $event, $data ) = @_;

    my $user_id = Dicole::Utils::User->ensure_id( $user );

    Dicole::Utils::Gearman->dispatch_task( dispatch_pusher_event => {
        channel => "private-meetings_user_$user_id", event => $event, data => $data
    } );
}

sub _dispatch_meeting_pusher_event {
    my ( $self, $meeting, $event, $data, $params ) = @_;

    $params ||= {};

    my $euos = $params->{euos} || $self->_fetch_meeting_participation_objects( $meeting );

    for my $euo ( @$euos ) {
        $self->_dispatch_user_pusher_event( $euo->user_id, $event, $data );
    }
}

sub _require_rsvp_again_for_meeting_users {
    my ( $self, $meeting, $params ) = @_;

    my $euos = $params->{euos} || $self->_fetch_meeting_participation_objects( $meeting );
    my $set_by_user_id = $params->{set_by_user_id} || eval { CTX->request->auth_user_id };

    for my $euo ( @$euos ) {
        next if $set_by_user_id && $set_by_user_id == $euo->user_id;
        next if $self->_get_note( is_hidden => $euo );
        $self->_set_note_for_meeting_user( rsvp => '', $meeting, $euo->user_id, $euo, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( rsvp_reminder_sent => time, $meeting, $euo->user_id, $euo, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( rsvp_require_sent => time, $meeting, $euo->user_id, $euo, { skip_save => 1 } );
        $self->_set_note_for_meeting_user( rsvp_required => '1', $meeting, $euo->user_id, $euo );
    }
}

sub _answer_meeting_proposals_for_user {
    my ( $self, $meeting, $proposal_data, $user, $params ) = @_;

    $params ||= {};
    $user = Dicole::Utils::User->ensure_object( $user );

    return 0 unless $user;

    my $pos = $params->{pos} ||= $self->_fetch_meeting_proposals( $meeting );
    my $euos = $params->{euos} ||= $self->_fetch_meeting_participation_objects( $meeting );

    my ( $auth_euo ) = grep { $_->user_id == $user->id } @$euos;

    return 0 unless $auth_euo;

    my $unanswered_was_set = 0;
    my $unanswered_found = 0;

    my $proposal_yes_count = {};

    for my $proposal ( @$pos ) {
        if ( my $answer = $proposal_data->{ $proposal->id } ) {

            if ( $answer =~ /^yes$/i ) { $answer = 'yes' }
            elsif ( $answer =~ /^no$/i ) { $answer = 'no' }
            else { $answer = '' }

            if ( $answer && ! $self->_get_meeting_proposed_date_answer( $meeting, $proposal, $user, $auth_euo ) ) {
                $unanswered_was_set++;
            }

            $self->_set_meeting_proposed_date_answer( $meeting, $proposal, $user, $answer, $auth_euo );
        }

        $proposal_yes_count->{ $proposal->id } ||= 0;
        for my $euo ( @$euos ) {
            my $answer = $self->_get_meeting_proposed_date_answer( $meeting, $proposal, $euo->user_id, $euo );

            $proposal_yes_count->{ $proposal->id }++ if $answer && $answer eq 'yes';

            next if $answer;
            $unanswered_found++;
        }
    }

    $self->_set_note_for_meeting_user( 'last_scheduling_confirmation' => time, $meeting, $user, $auth_euo );

    # This informs the admins that all the users have answered
    if ( scalar( @$euos ) > 1 && $unanswered_was_set && ! $unanswered_found ) {
        for my $euo ( @$euos ) {
            my $euser = eval { Dicole::Utils::User->ensure_object( $euo->user_id ) };
            next unless $euser && $self->_user_can_manage_meeting( $euser, $meeting, $euo );

            my $params = {};
            my @ordered_pos = sort { $proposal_yes_count->{ $a->id } <=> $proposal_yes_count->{ $b->id } } @$pos;

            my $largest_count = 0;
            my @best_pos = ();
            while ( scalar( @ordered_pos ) && ( ! $largest_count || $proposal_yes_count->{ $ordered_pos[-1]->id } == $largest_count ) ) {
                $largest_count = $proposal_yes_count->{ $ordered_pos[-1]->id };
                push @best_pos, pop @ordered_pos;
            }

            $params->{best_times} = [ map { $self->_get_proposal_info( $_, $euser )->{timestring} } @best_pos ];

            $self->_send_meeting_user_template_mail( $meeting, $euser, 'meetings_scheduling_answers_received', $params );
        }
    }

    return 1;
}

sub _send_secure_login_link_to_meeting {
    my ($self, $meeting) = @_;

    $self->_send_secure_login_link($self->derive_url(
        action     => 'meetings',
        task       => 'meeting',
        target     => $meeting->group_id,
        additional => [ $meeting->event_id ]
    ));
}

sub _send_secure_login_link {
    my ( $self, $url, $user ) = @_;

    $user ||= Dicole::Utils::User->ensure_object(CTX->request->auth_user);
    my $email = $user->email;

    $url ||= CTX->request->param('url_after_login') || $self->derive_url(action => 'meetings', task => 'summary');

    $self->_send_login_email(
        email => $email,
        url   => $url
    );

}

sub _generate_complete_meeting_user_material_url_for_selector_url {
    my ( $self, $meeting, $user, $base_url, $domain_host ) = @_;

    return '' unless $base_url;

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );

    my $params = { selected_material_url => $base_url || () };

    return $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, $params );
}

sub _generate_complete_meeting_user_material_url_from_data {
    my ( $self, $meeting, $user, $object_data, $domain_host ) = @_;

    my $base_url = $object_data->{prese_id} ?
        $self->_generate_meeting_material_prese_url_from_data( $meeting, $object_data ) :
        $self->_generate_meeting_material_wiki_url_from_data( $meeting, $object_data );

    return $self->_generate_complete_meeting_user_material_url_for_selector_url( $meeting, $user, $base_url, $domain_host );
}

sub _get_object_for_wiki_id {
    my ( $self, $page_id ) = @_;

    return CTX->lookup_object('wiki_page')->fetch( $page_id );
}

sub _generate_meeting_material_wiki_url_from_data {
    my ( $self, $event, $object_data ) = @_;

    my $object = $self->_get_object_for_wiki_id( $object_data->{page_id} );
    return '' unless $object;

    return $self->_generate_meeting_material_url_for_wiki( $event, $object );
}

sub _get_object_for_prese_id {
    my ( $self, $prese_id ) = @_;

    return CTX->lookup_object('presentations_prese')->fetch( $prese_id );
}

sub _generate_meeting_material_prese_url_from_data {
    my ( $self, $event, $object_data ) = @_;

    my $object = $self->_get_object_for_prese_id( $object_data->{prese_id} );
    return '' unless $object;

    return $self->_generate_meeting_material_url_for_prese( $event, $object );
}

sub _generate_meeting_material_url_for_wiki {
    my ( $self, $event, $object ) = @_;

    return Dicole::URL->from_parts(
        action => 'meetings_json',
        task => 'wiki_object_info',
        target => $event->group_id,
        domain_id => $event->domain_id,
        additional => [ $event->id, $object->id ],
    );
}

sub _get_valid_wiki {
    my ( $self, $action, $event, $check_user ) = @_;

    $action ||= $self;
    $event ||= $self->_get_valid_event( $action );
    my $check_user_id = $check_user ? Dicole::Utils::User->ensure_id( $check_user ) : 0;

    my $page = CTX->lookup_object('wiki_page')->fetch( $action->param('object_id') );

    my $group_id = $action->param('target_group_id');
    die "security error" unless $page && $group_id && $page->groups_id == $group_id;
    die "security error" if $check_user && ! $self->_fetch_meeting_participant_object_for_user( $event, $check_user_id );

    return $page;
}

sub _generate_meeting_material_url_for_prese {
    my ( $self, $event, $object ) = @_;

    return Dicole::URL->from_parts(
        action => 'meetings_json',
        task => 'prese_object_info',
        target => $event->group_id,
        domain_id => $event->domain_id,
        additional => [ $event->id, $object->id ],
    );
}

sub _get_valid_prese {
    my ( $self, $action, $event ) = @_;

    $action ||= $self;

    $event ||= $self->_get_valid_event( $action );

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $action->param('object_id') );

    my $group_id = $action->param('target_group_id');
    die "security error" unless $prese && $group_id && $prese->group_id == $group_id;

    return $prese;
}

sub _add_material_to_meeting_from_draft {
    my ( $self, $meeting, $draft_id, $by_user_id, $material_name ) = @_;

    my $a = CTX->lookup_action('draft_attachments_api')->e( fetch_last_attachment => {
        draft_id => $draft_id,
    } );

    $material_name ||= $a->filename;

    my $prese = CTX->lookup_action('presentations_api')->e( create => {
        domain_id => $meeting->domain_id,
        group_id => $meeting->group_id,
        creator_id => $by_user_id,
        title => $material_name,
        attachment => $a,
        tags => [ $meeting->sos_med_tag ],
    } ) or die;

    $self->_store_material_event( $meeting, $prese, 'created' );

    return $prese;
}

sub _events_api {
    my ( $self, $task, $params ) = @_;

    return CTX->lookup_action('events_api')->e( $task => $params );
}

sub _gather_user_info {
    my ( $self, $user, $size, $domain_id ) = @_;

    my $results = $self->_gather_users_info( [ $user ], $size, $domain_id );
    return shift @$results;
}

sub _gather_users_info {
    my ($self, $users, $size, $domain_id, $skip_forwarded_and_empty ) = @_;

    return [] unless $users && @$users;

    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $user_objects = Dicole::Utils::User->ensure_object_list( $users );

    my @user_emails = map { $_->email || () } @$user_objects;

    my %skip_by_email_lookup = ();

    if ( $skip_forwarded_and_empty ) {
        my $forwards = CTX->lookup_object('meetings_user_email')->fetch_group( {
                where => Dicole::Utils::SQL->column_in_strings( email => \@user_emails ),
        } );

        %skip_by_email_lookup = map { $_->email => 1 } @$forwards;

        if ( @$forwards ) {
            my %user_objects_by_id = map { $_->id => $_ } @$user_objects;
            my @missing_user_ids = map { $user_objects_by_id{ $_->user_id } ? () : $_->user_id } @$forwards;

            my $additional_user_objects = Dicole::Utils::User->ensure_object_list( \@missing_user_ids );
            $user_objects = [ @$user_objects, @$additional_user_objects ];
        }
    }

    # Removes users without email, duplicate users and forwarded users
    my $valid_user_objects = [];

    for my $user ( @$user_objects ) {
        next if $skip_forwarded_and_empty && ! $user->email;
        next if $user->email && $skip_by_email_lookup{ $user->email };
        push @$valid_user_objects, $user;
        $skip_by_email_lookup{ $user->email } = 1 if $user->email;
    }

    $user_objects = $valid_user_objects;

    my $user_profiles = CTX->lookup_action('networking_api')->e( user_profile_object_map => {
        domain_id    => $domain_id,
        user_id_list => [ map { $_->id } @$user_objects ],
    });

    return [ map {
        my $user = $_;
        my $id = $user->id;

        my $name = Dicole::Utils::User->name( $user );
        my $initials = Dicole::Utils::User->initials( $user );

        my $li = $user_profiles->{$id}->personal_linkedin || '';
        $li =~ s/^ +//;

        if ( $li && $li !~ /^http/ ) {
            $li = 'http://' . $li;
        }

        {
            user_id => $id,
            user_id_md5 => Digest::MD5::md5_hex( $id ),
            is_pro => $self->_user_is_pro( $user, $domain_id ),
            free_trial_has_expired => $self->_user_free_trial_has_expired( $user, $domain_id ),
            phone => $user->phone || $user_profiles->{$id}->contact_phone || '',
            skype => $user_profiles->{$id}->contact_skype || '',
            linkedin => $li,
            email => $user->email,
            private_email => $user->email,
            alternative_emails => [],
            facebook_user_id => $user->facebook_user_id,
            organization => $user_profiles->{$id}->contact_organization || '',
            organization_title => $user_profiles->{$id}->contact_title || '',
            name => $name,
            initials => uc( $initials ),
            first_name => $user->first_name || '',
            last_name => $user->last_name || '',
            image_attachment_id => ( $user_profiles->{$id}->portrait =~ /^\d+$/ ) ? $user_profiles->{$id}->portrait || 0 : 0,
            image => ( $size && $size > 0 ) ? CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
                user_id => $id,
                domain_id => $domain_id,
                profile_object => $user_profiles->{$id},
                no_default => 1,
                size => $size || 50,
            } ) : '',
            vcard_url => Dicole::URL->from_parts(
                domain_id => $domain_id, target_id => 0,
                action => 'networking_raw', task => 'get_information_as_vcard',
                additional => [ $id, $user->first_name.$user->last_name.'.vcf' ],
            ),
        }
    } @$user_objects ];
}

sub _gather_draft_participant_objects_info {
    my ( $self, $objects, $size, $users ) = @_;

    $users ||= Dicole::Utils::User->ensure_object_list( [ map { $_->user_id || () } @$objects ] );
    my %users = map { $_->id => $_ } @$users;

    my ( $existing_users, $new_objects, $domain_id );
    for my $o ( @$objects ) {
        $domain_id ||= $o->domain_id;

        if ( $o->user_id ) {
            push @$existing_users, $users{ $o->user_id };
        }
        else {
            push @$new_objects, $o;
        }
    }

    my $existing_users_info = $self->_gather_users_info( $existing_users, $size, $domain_id );
    my %existing_users_info = map { $_->{user_id} => $_ } @$existing_users_info;

    my $objects_info = [];
    for my $o ( @$objects ) {
        if ( $o->user_id ) {
            push @$objects_info, { %{ $existing_users_info{ $o->user_id } || {} } };
        }
        else {
            my %copied_info = map { $_ => $self->_get_note( $_, $o ) || '' } ( qw(
                phone
                skype
                email
                organization
                organization_title
                name
                first_name
                last_name
                image
                initials
            ) );

            $copied_info{initials} = Dicole::Utils::User->form_user_initials_for_name( $copied_info{name} || $copied_info{email} )
                unless $copied_info{initials};
            $copied_info{name} ||= $copied_info{email};

            push @$objects_info, {
                %copied_info,
            };
        }

        $objects_info->[-1]->{rsvp} = $self->_determine_rsvp_status( $self->_get_note( rsvp => $o ), $self->_get_note( rsvp_required => $o ) );
        $objects_info->[-1]->{scheduling_disabled} = $self->_get_note( scheduling_disabled => $o ) ? 1 : 0;
        $objects_info->[-1]->{draft_object_id} = $o->id;
    }

    return $objects_info;
}

sub _fetch_meeting_participation_objects {
    my ( $self, $meeting ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    return CTX->lookup_object('events_user')->fetch_group( {
        where => 'event_id = ? AND domain_id = ? AND removed_date = 0',
        value => [ $meeting->id, $meeting->domain_id ],
    } ) || [];
}

sub _fetch_meeting_draft_participation_objects {
    my ( $self, $meeting ) = @_;

    return CTX->lookup_object('meetings_draft_participant')->fetch_group({
        where => 'domain_id = ? AND event_id = ? AND sent_date = ? AND removed_date = ?',
        value => [ $meeting->domain_id, $meeting->id, 0, 0 ],
    });
}

sub _gather_meeting_user_info {
    my ( $self, $meeting, $user, $size, $event_user, $lc_opts ) = @_;

    $meeting ||= $self->_ensure_meeting_object( $event_user->event_id );
    $meeting = $self->_ensure_meeting_object( $meeting  );
    $user = Dicole::Utils::User->ensure_object( $user || $event_user->user_id );
    $event_user ||= $self->_get_user_meeting_participation_object( $user, $meeting );

    my $results = $self->_gather_meeting_users_info(
        $meeting, $size, $event_user->domain_id, { $event_user->user_id => $event_user }, $user ? [ $user ] : undef, undef, $lc_opts
    );

    return shift @$results;
}

sub _gather_meeting_users_info {
    my ($self, $meeting, $size, $domain_id, $event_user_objects_by_user_id, $users, $proposals, $lc_opts ) = @_;

    $domain_id ||= $meeting->domain_id;
    $proposals ||= $self->_fetch_meeting_proposals( $meeting );

    if ( ! $event_user_objects_by_user_id ) {
        my $event_users = $self->_fetch_meeting_participation_objects( $meeting );
        $event_user_objects_by_user_id = { map { $_->user_id => $_ } @$event_users };
    }

    $users ||= Dicole::Utils::User->ensure_object_list( [ keys %$event_user_objects_by_user_id ]  );
    $users = [ map { $event_user_objects_by_user_id->{ $_->id } ? $_ : () } @$users ];

    my $users_info = $self->_gather_users_info( $users, $size, $domain_id );
    my %users_info = map { $_->{user_id} => $_ } @$users_info;

    my $answers_by_user = {};

    if ( my $scheduling_id = $self->_get_note_for_meeting( current_scheduling_id => $meeting ) ) {
        my $user_answers = CTX->lookup_object('meetings_scheduling_answer')->fetch_group( {
            where => 'scheduling_id = ?',
            value => [ $scheduling_id ],
            order => 'id asc',
        } );
        for my $answer ( @$user_answers ) {
            $answers_by_user->{ $answer->user_id } = 1;
        }
    }

    my $result = [];
    for my $user ( @$users ) {
        my $user_id = $user->id;
        my $user_info = $users_info{ $user_id } || {};
        my $event_user = $event_user_objects_by_user_id->{ $user_id };

        my $unanswered_proposal_count = 0;
        my $proposal_answers = {};

        for my $proposal ( @$proposals ) {
            my $answer = $self->_get_meeting_proposed_date_answer( $meeting, $proposal, $user, $event_user );
            $proposal_answers->{ $proposal->id } = $answer;
            $unanswered_proposal_count += 1 unless $answer;
        }

        my $scheduling_disabled = $self->_get_note_for_meeting_user( scheduling_disabled => $meeting, $user_id, $event_user ) ? 1 : 0;
        my $scheduling_disabled_by_user_id = $self->_get_note_for_meeting_user( scheduling_disabled_by_user_id => $meeting, $user_id, $event_user );

        # NOTE: for legacy disables, say that it was the user
        $scheduling_disabled_by_user_id ||= $user_id if $scheduling_disabled;

        push @$result, {
            has_answered_current_scheduling => $answers_by_user->{ $user_id } ? 1 : 0,
            participant_object_id => $event_user->id,
            %$user_info,
            invited_epoch => $event_user->created_date || 0,
            scheduling_disabled => $scheduling_disabled,
            scheduling_disabled_by_user_id => $scheduling_disabled_by_user_id,
            rsvp => $self->_get_note_for_meeting_user( 'rsvp', $meeting, $user_id, $event_user ) || '',
            rsvp_required => $self->_get_note_for_meeting_user( 'rsvp_required', $meeting, $user_id, $event_user ) || '',
            rsvp_status => $self->_determine_meeting_user_rsvp_status( $meeting, $user_id, $event_user ),
            rsvp_string => $self->_determine_meeting_user_rsvp_string( $meeting, $user_id, $event_user, $proposals, $lc_opts ),
            is_creator => ( $meeting->creator_id == $user_id ) ? 1 : 0,
            last_action_string => $self->_create_last_action_string_for_meeting_user( $meeting, $user_id, $event_user, $lc_opts ),
            is_manager => $event_user->is_planner,
            is_hidden => $self->_get_note( is_hidden => $event_user ),
            proposal_answers => $proposal_answers,
            unanswered_proposal_count => $unanswered_proposal_count,
            data_url => $self->derive_url(
                action => 'meetings_json', task => 'user_info', target => $event_user->group_id,
                additional => [ $event_user->event_id, $user_id ],
            ),
            change_manager_status_url => $self->derive_url(
                action => 'meetings_json', task => 'change_manager_status', target => $event_user->group_id,
                additional => [ $event_user->event_id, $user_id ],
            ),
        };
    }

    return $result;
}

# _nmsg( 'a moment ago'
# _nmsg( 'an hour ago'
# _nmsg( 'one hour ago', '%1$d hours ago'
# _nmsg( 'yesterday'
# _nmsg( 'on monday'
# _nmsg( 'on tuesday'
# _nmsg( 'on wednesday'
# _nmsg( 'on thursday'
# _nmsg( 'on friday'
# _nmsg( 'on saturday'
# _nmsg( 'on sunday'
# _nmsg( 'one day ago','%1$d days ago'

sub _create_last_action_string_for_meeting_user {
    my ( $self, $meeting, $user_or_id, $event_user, $lc_opts ) = @_;

    if ( my $epoch = $self->_get_note_for_meeting_user( last_page_loaded => $meeting, $user_or_id, $event_user ) ) {
        return $self->_ncmsg( "Last visited %1\$s.", $lc_opts, [ Dicole::Utils::Date->nlocalized_about_when( epoch => $epoch, opts => $lc_opts ) ] );
    }

    if ( my $epoch = $self->_get_note_for_meeting_user( last_meeting_image_served => $meeting, $user_or_id, $event_user ) ) {
        return $self->_ncmsg( "Email opened %1\$s.", $lc_opts, [ Dicole::Utils::Date->nlocalized_about_when( epoch => $epoch, opts => $lc_opts ) ] );
    }

    if ( my $epoch = $self->_get_note_for_meeting_user( rsvp_require_sent => $meeting, $user_or_id, $event_user ) ) {
        return $self->_ncmsg( "RSVP request sent %1\$s.", $lc_opts, [ Dicole::Utils::Date->nlocalized_about_when( epoch => $epoch, opts => $lc_opts ) ] );
    }

    return $self->_ncmsg( "Invitation sent %1\$s.", $lc_opts, [ Dicole::Utils::Date->nlocalized_about_when( epoch => $event_user->created_date, opts => $lc_opts ) ] ) if $event_user->created_date;

    return "";
}

sub _determine_meeting_user_rsvp_string {
    my ( $self, $meeting, $user_or_id, $event_user, $suggestions, $lc_opts ) = @_;

    if ( $meeting->begin_date ) {
        my $rsvp = $self->_get_note_for_meeting_user( rsvp => $meeting, $user_or_id, $event_user );
        return $self->_ncmsg( "Attending.", $lc_opts ) if $rsvp && $rsvp eq 'yes';
        return $self->_ncmsg( "Not attending.", $lc_opts ) if $rsvp && $rsvp eq 'no';

        my $rsvp_required = $self->_get_note_for_meeting_user( rsvp_required => $meeting, $user_or_id, $event_user );
        return $rsvp_required ?
            $self->_ncmsg( "Not answered yet.", $lc_opts ) :
            $self->_ncmsg( "Presumedly attending.", $lc_opts );
    }
    elsif ( $suggestions && scalar( @$suggestions ) ) {
        my $open_proposals = $self->_fetch_open_meeting_proposals_for_user( $meeting, $user_or_id, $event_user, $suggestions );
        return $self->_ncmsg( "Answered suggested times.", $lc_opts ) unless scalar( @$open_proposals );
        return $self->_ncmsg( "Not answered yet.", $lc_opts );
    }
    else {
        my $rsvp = $self->_get_note_for_meeting_user( rsvp => $meeting, $user_or_id, $event_user );
        return $self->_ncmsg( "Set as Attending.", $lc_opts ) if $rsvp && $rsvp eq 'yes';
        return $self->_ncmsg( "Set as Not attending.", $lc_opts ) if $rsvp && $rsvp eq 'no';
        return $self->_ncmsg( "Presumedly attending.", $lc_opts );
    }
}

sub _determine_meeting_user_rsvp_status {
    my ( $self, $meeting, $user_or_id, $event_user ) = @_;

    return $self->_determine_rsvp_status(
         $self->_get_note_for_meeting_user( rsvp => $meeting, $user_or_id, $event_user ) || '',
         $self->_get_note_for_meeting_user( rsvp_required => $meeting, $user_or_id, $event_user ) ? 1 : 0,
    );
}

sub _determine_rsvp_status {
    my ( $self, $rsvp, $rsvp_required ) = @_;

    return $rsvp eq 'yes' ? 'yes' : $rsvp eq 'no' ? 'no' : $rsvp_required ? '' : 'yes';
}

sub _gather_meeting_draft_participant_info {
    my ( $self, $meeting, $size, $object, $user, $lc_opts ) = @_;

    my $results = $self->_gather_meeting_draft_participants_info(
        $meeting, $size, [ $object ], $user ? [ $user ] : undef, $lc_opts
    );

    return shift @$results;
}

sub _gather_meeting_draft_participants_info {
    my ( $self, $meeting, $size, $objects, $users, $lc_opts ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $objects ||= $self->_fetch_meeting_draft_participation_objects( $meeting );
    my $objects_info = $self->_gather_draft_participant_objects_info( $objects, $size, $users );
    my %objects_info = map { $_->{draft_object_id} => $_ } @$objects_info;

    my $return = [];
    for my $o ( @$objects ) {
        my $user_info = $objects_info{ $o->id };
        push @$return, {
            %$user_info,
            last_action_string => $self->_ncmsg( 'User not invited yet.', $lc_opts ),
            is_manager => $self->_get_note( is_planner => $o ),
            is_hidden => $self->_get_note( is_hidden => $o ),
            data_url => $self->derive_url(
                action => 'meetings_json', task => 'draft_participant_info', target => $meeting->group_id,
                additional => [ $meeting->event_id, $o->id ],
            ),
            change_manager_status_url => $self->derive_url(
                action => 'meetings_json', task => 'change_draft_manager_status', target => $meeting->group_id,
                additional => [ $meeting->event_id, $o->id ],
            ),
        };
    }

    return $return;
}

sub _sort_participant_info_list {
    my ( $self, $list ) = @_;

    my @carriers = ();
    for my $object ( @$list ) {
        my $sort = $object->{rsvp} eq 'yes' ? 6 : $object->{rsvp} eq 'no' ? 2 : 4;
        $sort += $object->{is_manager} ? 1 : 0;
        push @carriers, [ $sort, $object ];
    }

    my $sorted_list = [];

    for ( ( sort { $b->[0] <=> $a->[0] || lc( $a->[1]->{name}) cmp lc($b->[1]->{name} ) } @carriers ) ) {
        push @$sorted_list, $_->[1];
    }

    return $sorted_list;
}

sub _clean_up_duplicate_draft_participant {
    my ( $self, $meeting, $candidate_draft_participant ) = @_;

    my $participants = $self->_fetch_meeting_participant_users( $meeting );
    my $draft_participant_objects = $self->_fetch_meeting_draft_participant_objects( $meeting );
    my $existing_draft_participant_objects = [ map { $_->user_id ? $_ : () } @$draft_participant_objects ];
    my $existing_draft_participants = Dicole::Utils::User->ensure_object_list( [ map { $_->user_id } @$existing_draft_participant_objects ] );
    my $users_by_id = { map { $_->id => $_ } @$existing_draft_participants };

    my $email_lookup = {};
    $email_lookup->{ $_->email } = 1 for @$participants;
    my $phone_lookup = {};
    $phone_lookup->{ $_->phone } = 1 for @$participants;

    for my $draft_participant ( @$draft_participant_objects ) {
        my $user = $draft_participant->user_id ? $users_by_id->{ $draft_participant->user_id } : undef;
        my $email = $user ? $user->email : $self->_get_note( email => $draft_participant );
        my $phone = $user ? $user->phone : $self->_get_note( phone => $draft_participant );
        if ( $draft_participant->id != $candidate_draft_participant->id ) {
            $email_lookup->{ $email } = 1;
            $phone_lookup->{ $phone } = 1;
        }
        elsif ( $phone ) {
            if ( $phone_lookup->{ $phone } ) {
                $draft_participant->remove;
                return 1;
            }
        }
        elsif ( $email ) {
            if ( $email_lookup->{ $email } ) {
                $draft_participant->remove;
                return 1;
            }
        }
    }

    return 0;
}

sub _clean_up_duplicate_participant {
    my ( $self, $meeting, $candidate_participant ) = @_;

    my $participants = $self->_fetch_meeting_participant_objects( $meeting );

    my $id_lookup = {};

    for my $participant ( @$participants ) {
        if ( $participant->user_id != $candidate_participant->user_id ) {
            $id_lookup->{ $participant->user_id } = 1;
        }
        else {
            if ( $id_lookup->{ $participant->user_id } ) {
                $participant->remove;
                return 1;
            }
        }
    }

    return 0;
}

sub _add_meeting_draft_participants_by_emails_string {
    my ( $self, $meeting, $emails, $creator_user ) = @_;

    my $eos = Dicole::Utils::Mail->string_to_address_objects( $emails );

    return $self->_add_meeting_draft_participants_by_email_objects( $meeting, $eos, $creator_user );
}

sub _add_meeting_draft_participants_by_email_objects {
    my ( $self, $meeting, $email_objects, $creator_user ) = @_;

    my $participants = $self->_fetch_meeting_participant_users( $meeting );
    my $draft_participant_objects = $self->_fetch_meeting_draft_participant_objects( $meeting );
    my $existing_draft_participant_objects = [ map { $_->user_id ? $_ : () } @$draft_participant_objects ];
    my $unexisting_draft_participant_objects = [ map { $_->user_id ? () : $_ } @$draft_participant_objects ];
    my $existing_draft_participants = Dicole::Utils::User->ensure_object_list( [ map { $_->user_id } @$existing_draft_participant_objects ] );

    my $email_lookup = {};
    $email_lookup->{ $_->email } = 1 for @$participants;
    $email_lookup->{ $_ ? $_->email : '' } = 1 for @$existing_draft_participants;
    $email_lookup->{ $self->_get_note( email => $_ ) || '' } = 1 for @$unexisting_draft_participant_objects;

    for my $eo ( @$email_objects ) {
        my $email = Dicole::Utils::Text->ensure_utf8( $eo->address );
        next if $email_lookup->{ $email }++;
        my $draft_user = $self->_add_meeting_draft_participant_by_email_object( $meeting, $eo, $creator_user );
        $email_lookup->{ $self->_get_note( email => $draft_user ) || '' }++;
    }
}

sub _add_meeting_draft_participant_by_email_object {
    my ( $self, $meeting, $email_object, $creator_user ) = @_;

    my $email = Dicole::Utils::Text->ensure_utf8( $email_object->address );
    return unless $email;
    my $phrase = Dicole::Utils::Text->ensure_utf8( $email_object->phrase || $email );

    return $self->_add_meeting_draft_participant_by_email_and_name( $meeting, $email, $phrase, $creator_user );
}

sub _add_meeting_draft_participant_by_email_and_name {
    my ( $self, $meeting, $email, $name, $creator_user ) = @_;

    my $user = $self->_fetch_user_for_email( $email, $meeting->domain_id );

    if ( $user ) {
        return $self->_add_meeting_draft_participant( $meeting, { user_id => $user->id }, $creator_user )
    }

    return $self->_add_meeting_draft_participant( $meeting, {
            email => $email,
            name => $name || $email,
        }, $creator_user );
}

sub _add_meeting_draft_participant_by_phone_and_name {
    my ( $self, $meeting, $phone, $name, $creator_user ) = @_;

    $phone = $self->_internationalize_phone_number( $phone, $creator_user, $meeting->domain_id );

    my $user = $self->_fetch_user_for_phone( $phone, $meeting->domain_id, undef, { creator_user => $creator_user } );

    if ( $user ) {
        return $self->_add_meeting_draft_participant( $meeting, { user_id => $user->id }, $creator_user )
    }

    return $self->_add_meeting_draft_participant( $meeting, {
            phone => $phone,
            name => $name || $phone,
        }, $creator_user );
}

sub _add_meeting_draft_participant {
    my ($self, $meeting, $user_data, $creator_user ) = @_;

    $user_data = {
        user_id => 0,
        email => '',
        phone => '',
        first_name => '',
        last_name => '',
        name => '',

        %{ $user_data || {} },
    };

    if ( $user_data->{name} && ! $user_data->{first_name} && ! $user_data->{last_name} ) {
         my ( $first_name, $last_name ) = $self->_parse_first_and_last_names_from_email_address_phrase( $user_data->{name} );
         $user_data->{first_name} = $first_name;
         $user_data->{last_name} = $last_name;
    }

    my $new = CTX->lookup_object('meetings_draft_participant')->new( {
        domain_id => $meeting->domain_id,
        event_id => $meeting->id,
        user_id => $user_data->{user_id},
        created_date => time,
        creator_id => $creator_user ? Dicole::Utils::User->ensure_id( $creator_user ) : 0,
        sent_date => 0,
        removed_date => 0,
    } );

    for my $attr ( keys %$user_data ) {
        next if $attr eq 'user_id';
        $self->_set_note( $attr, $user_data->{ $attr }, $new, { skip_save => 1 } );
    }

    $new->save;

    return $new;
}

sub _remove_meeting_draft_participant {
    my ($self, $meeting, $object, $by_user ) = @_;

    $object->removed_date( time );
    $object->save;
}

sub _check_if_request_ip_matches_provided_limit_list {
    my ( $self, $list ) = @_;

    return 0 unless $list;

    my $ip = $self->_get_ip_for_request();
    return 0 unless $ip;

    my %map = map { $_ => 1 } @$list;
    return 1 if $map{ $ip };
}

sub _get_ip_for_request {
    my ( $self, $skip_override ) = @_;

    my $ip = ( CTX->request && CTX->request->cgi ) ? CTX->request->cgi->http('X-Forwarded-For') : '';
    if ( CTX->request && CTX->request->auth_user_id && ! $skip_override ) {
        my $force_ip = $self->_get_note_for_user( 'meetings_force_ip', CTX->request->auth_user, Dicole::Utils::Domain->guess_current_id );
        $ip = $force_ip || $ip;
    }

    if ( $ip ) {
        my @ip = split /\s*[\s\,]\s*/, $ip;
        $ip = shift @ip;
    }

    return $ip;
}

sub _get_location_data_for_request {
    my ( $self ) = @_;

    my $ip = $self->_get_ip_for_request;

    return $self->_get_location_data_for_ip( $ip );
}

sub _get_location_data_for_ip {
    my ( $self, $ip ) = @_;

    my $location_data = {};

    if ( $ip ) {
        $location_data = Dicole::Cache->fetch_or_store( 'freegeoip:' . $ip, sub {
                my $json = Dicole::Utils::HTTP->get( "http://freegeoip.net/json/$ip" );
                my $data = Dicole::Utils::JSON->decode( $json );
                return $data;
            }, { no_domain_id => 1, no_group_id => 1 } );
    }

    return $location_data;
}

sub _decode_state {
    my ( $self, $json_state ) = @_;

    return $json_state ? Dicole::Utils::JSON->decode( $json_state ) :
        { starting_time => time, id_list => [] };
}

sub _append_state {
    my ( $self, $state, $added_objects ) = @_;

    $state ||= $self->_decode_state;

    if ( scalar( @$added_objects ) ) {
        push @{ $state->{id_list } }, map { $_->id } @$added_objects;
    }

    return $state;
}

sub _encode_state {
    my ( $self, $state ) = @_;

    $state ||= $self->_decode_state;

    return Dicole::Utils::JSON->encode( $state );
}

sub _calendar_params_for_epoch_and_user {
    my ( $self, $epoch, $end_epoch, $time, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    return $self->_calendar_params_for_epoch( $epoch, $end_epoch, $time, $user->timezone, $user->language  );
}

sub _calendar_params_for_epoch {
    my ( $self, $epoch, $end_epoch, $time, $timezone, $lang ) = @_;

    if ( ! $epoch ) {
        return {
            hm => '',
            month => '',
            day => '?',
            status => 'unknown',
        };
    }

    my $dts = Dicole::Utils::Date->epoch_to_date_and_time_strings( $epoch, $timezone, $lang, 'ampm' );
    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch, $timezone, 'en' );

    $time ||= time();
    $end_epoch ||= $epoch;

    # _nmsg("Mon")
    # _nmsg("Tue")
    # _nmsg("Wed")
    # _nmsg("Thu")
    # _nmsg("Fri")
    # _nmsg("Sat")
    # _nmsg("Sun")

    # _nmsg("Jan")
    # _nmsg("Feb")
    # _nmsg("Mar")
    # _nmsg("Apr")
    # _nmsg("May")
    # _nmsg("Jun")
    # _nmsg("Jul")
    # _nmsg("Aug")
    # _nmsg("Sep")
    # _nmsg("Oct")
    # _nmsg("Nov")
    # _nmsg("Dec")

    return {
        hm => $dts->[1],
        month => $self->_ncmsg( substr( $dt->month_abbr, 0, 3 ), { lang => $lang } ),
        weekday => $self->_ncmsg( substr( $dt->day_abbr, 0, 3 ), { lang => $lang } ),
        day => $dt->day,
        status => ( $time < $epoch ) ? 'before' : ( $end_epoch > $time ) ? 'during' : 'after',
    };
}

sub _get_meeting_email {
    my ( $self, $event ) = @_;

    return CTX->lookup_action('emails_api')->e( get_shortened_email => {
        action => 'meetings_email_anon_dispatch',
        params => [ $event->domain_id, $event->id ],
        domain_id => $event->domain_id,
    } );
}

sub _get_meeting_join_password {
    my ( $self, $event ) = @_;

    my $pass = $self->_get_note_for_meeting( join_password => $event );

    if ( ! $pass ) {
        $pass = $self->_get_random_password( 4 );
        $self->_set_note_for_meeting( join_password => $pass, $event );
    }

    return $pass;
}

sub _get_random_password {
    my ( $self, $length ) = @_;

    my @chars = split //, "abcdefghjkmnpqrstxz23456789";
    return join "", map { $chars[rand @chars] } 1 .. $length;
}

sub _get_meeting_user_email {
    my ( $self, $event, $user, $domain_id ) = @_;

    $domain_id ||= $event->domain_id;
    my $user_id = Dicole::Utils::User->ensure_id( $user );

    return CTX->lookup_action('emails_api')->e( get_validated_email => {
        action => 'meetings_email_dispatch',
        params => [ $domain_id, $event->id, $user_id ],
        domain_id => $domain_id,
        user => Dicole::Utils::User->ensure_object( $user ),
    } );
}

sub _get_meeting_user_email_string {
    my ( $self, $event, $user, $domain_id ) = @_;

# TODO: localization
#    $user = Dicole::Utils::User->ensure_object( $user );
    my $address = $self->_get_meeting_user_email( $event, $user, $domain_id );

    return Dicole::Utils::Mail->form_email_string( $address, 'Email to ' . $self->_meeting_title_string( $event ) );
}

sub _get_meeting_user_proposal_email {
    my ( $self, $event, $user, $proposal, $domain_id ) = @_;

    my $user_id = Dicole::Utils::User->ensure_id( $user );
    $domain_id ||= $event->domain_id;

    return CTX->lookup_action('emails_api')->e( get_validated_email => {
        action => 'meetings_email_scheduling_answer',
        params => [ $user_id, $domain_id, $event->id, $proposal->id ],
        domain_id => $domain_id,
        user => Dicole::Utils::User->ensure_object( $user ),
    } );
}

sub _get_meeting_agenda_reply_email {
    my ( $self, $meeting, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    return CTX->lookup_action('emails_api')->e( get_validated_email => {
        action => 'meetings_email_agenda_reply',
        params => [ $user->id, $meeting->domain_id, $meeting->id ],
        domain_id => $meeting->domain_id,
        user => $user,
    } );
}

sub _get_meeting_action_points_reply_email {
    my ( $self, $meeting, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    return CTX->lookup_action('emails_api')->e( get_validated_email => {
        action => 'meetings_email_action_points_reply',
        params => [ $user->id, $meeting->domain_id, $meeting->id ],
        domain_id => $meeting->domain_id,
        user => $user,
    } );
}

sub _get_cookie_param_abs {
    my ( $self, $to, $domain_id ) = @_;

    return $self->derive_url( action => 'meetings_raw', task => 'cookie_forward', target => 0, additional => [], params => { to => $to } );
}

sub _get_meeting_abs {
    my ( $self, $meeting, $extra_params ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    return Dicole::URL->from_parts(
        domain_id => $meeting->domain_id,
        action => 'meetings',
        task => 'meeting',
        target => $meeting->group_id,
        additional => [ $meeting->id ],
        params => $extra_params || {},
    );
}


sub _get_meet_me_config_abs {
    my ( $self, $event_id, $params, $domain_id ) = @_;

    return $self->derive_url( domain_id => $domain_id, action => 'meetings', task => 'meetme_config', target => 0, additional => [ $event_id ? ( 'init', $event_id ) : () ], params => $params );
}


sub _get_current_utm_params {
    my ( $self, $params ) = @_;

    $params ||= {};
    for my $param ( qw( utm_source utm_medium utm_campaign ) ) {
        next unless CTX->request->param( $param );
        $params->{ $param } = CTX->request->param( $param );
    }
    return $params;
}

sub _get_meeting_url {
    my ( $self, $meeting, $domain_host, $extra_params ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );
    $domain_host =~ s/^http:/https:/;

    return $domain_host . $self->_get_meeting_abs( $meeting, $extra_params );
}

sub _user_permanent_dic {
    my ( $self, $user, $domain_id ) = @_;

    if ( $domain_id ) {
        return '' if $self->_get_note_for_user( eliminate_link_auth => $user, $domain_id );
    }
    return Dicole::Utils::User->permanent_authorization_key( $user );
}

sub _get_meeting_user_url {
    my ( $self, $event, $user, $domain_id, $domain_host, $extra_params ) = @_;

    $domain_id ||= $event->domain_id;
    $domain_host ||= $self->_get_host_for_meeting( $event, 443 );
    $domain_host =~ s/^http:/https:/;
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    my $meeting_url = $domain_host . $self->derive_url(
        domain_id => $domain_id,
        action => 'meetings',
        task => 'meeting',
        target => $event->group_id,
        additional => [ $event->id ],
        params => {
            dic => $self->_user_permanent_dic( $user, $domain_id ),
        },
    );

    my $uri = URI::URL->new( $meeting_url );
    my %query = $uri->query_form;
    $uri->query_form( { %query, %{ $extra_params || {} } } );

    return $uri->as_string;
}

sub _get_meeting_enter_url {
    my ( $self, $meeting, $domain_host, $extra_params ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );
    $domain_host =~ s/^http:/https:/;

    return $domain_host . $self->_get_meeting_enter_abs( $meeting, $extra_params );
}

sub _get_meeting_enter_abs {
    my ( $self, $meeting, $extra_params ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    return $self->derive_url(
        domain_id => $meeting->domain_id,
        action => 'meetings',
        task => 'enter_meeting',
        target => $meeting->group_id,
        additional => [ $meeting->id, $self->_get_meeting_cloaking_hash( $meeting ) ],
        params => {
            %{ $extra_params || {} },
        },
    );
}
sub _get_suggestion_enter_url {
    my ( $self, $suggestion, $domain_host, $extra_params ) = @_;

    $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $suggestion );

    $domain_host ||= $self->_get_host_for_domain( $suggestion->domain_id, 443 );
    $domain_host =~ s/^http:/https:/;

    return $domain_host . $self->_get_suggestion_enter_abs( $suggestion, $extra_params );
}

sub _get_suggestion_enter_abs {
    my ( $self, $suggestion, $extra_params ) = @_;

    $suggestion = $self->_ensure_object_of_type( meetings_meeting_suggestion => $suggestion );

    return $self->derive_url(
        domain_id => $suggestion->domain_id,
        action => 'meetings',
        task => 'activate_suggestion',
        target => 0,
        additional => [ $suggestion->id ],
        params => {
            %{ $extra_params || {} },
        },
    );
}

sub _get_meeting_user_unsubscribe_url {
    my ( $self, $event, $user, $domain_id, $domain_host ) = @_;

    $domain_id ||= $event->domain_id;
    $domain_host ||= $self->_get_host_for_user( $user, $domain_id, 443 );
    $user = Dicole::Utils::User->ensure_object( $user );

    my $meeting_url = $domain_host . $self->derive_url(
        domain_id => $domain_id,
        action => 'meetings',
        task => 'disable_meeting_emails',
        target => $event->group_id,
        additional => [ $event->id ],
        params => { dic => $self->_user_permanent_dic( $user, $domain_id ) },
    );
}

sub _fetch_meeting_organizer_user {
    my ( $self, $event ) = @_;

    return Dicole::Utils::User->ensure_object( $event->creator_id );
}

sub _epoch_to_mdy {
    my ($self, $epoch, $user) = @_;

    return unless $epoch;

    my $timezone = $self->_determine_timezone($user);

    my $date = DateTime->from_epoch(epoch => $epoch, time_zone => $timezone, locale => 'en_US');

    my $ordinal_day = sprintf( "%2d", $date->day ) . [ qw( th st nd rd th th th th th th ) ]->[ $date->day % 10 ];

    return join " ", $date->month_abbr, $ordinal_day, ($date->year == DateTime->now->year ? () : $date->year);
}

sub _epoch_to_ymd {
    my ( $self, $epoch, $user ) = @_;

    return '????-??-??' unless $epoch;

    my $timezone = $self->_determine_timezone( $user );

    return DateTime->from_epoch( epoch => $epoch, time_zone => $timezone )->ymd("-");
}

sub _determine_timezone {
    my ( $self, $user ) = @_;

    $user ||= CTX->request ? CTX->request->auth_user : undef;

    if ( $user && $user->{timezone} ) {
        return $user->{timezone};
    }

    return 'UTC';
}

sub _ics_publish_for_vevent {
    my ( $self, $vevent ) = @_;

    my $calendar = Data::ICal->new();
    $calendar->add_property( METHOD => 'PUBLISH'  );
    $calendar->add_property( "DTSTAMP" => Dicole::Utils::Date->epoch_to_ical( time ) );

    $calendar->add_entry( $vevent );

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub _ics_request_for_vevent {
    my ( $self, $vevent ) = @_;

    my $calendar = Data::ICal->new();
    $calendar->add_property( METHOD => 'REQUEST'  );
    $calendar->add_property( "DTSTAMP" => Dicole::Utils::Date->epoch_to_ical( time ) );

    $calendar->add_entry( $vevent );

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub _ics_cancel_for_meeting {
    my ( $self, $event, $user, $users, $domain_id, $params ) = @_;

    my $initial_properties = [
        [ METHOD => 'CANCEL' ],
    ];

    return $self->_ics_for_meeting( $event, $user, $users, $domain_id, $initial_properties, $params )
}

sub _ics_publish_for_meeting {
    my ( $self, $event, $user, $users, $domain_id ) = @_;

    my $initial_properties = [
        [ METHOD => 'PUBLISH' ],
    ];

    return $self->_ics_for_meeting( $event, $user, $users, $domain_id, $initial_properties )
}

sub _ics_request_for_meeting {
    my ( $self, $event, $user, $users, $domain_id, $params ) = @_;

    my $initial_properties = [
        [ METHOD => 'REQUEST' ],
    ];

    $params ||= {};
    $params->{add_organizer} = 1;
    $params->{add_attendees} = 1;

    return $self->_ics_for_meeting( $event, $user, $users, $domain_id, $initial_properties, $params )
}

sub _ics_for_meeting {
    my ( $self, $event, $user, $users, $domain_id, $initial_properties, $params ) = @_;

    my $vevent = $self->_ics_vevent_for_meeting( $event, $user, $users, $domain_id, $params );

    return '' unless $vevent;

    my $calendar = Data::ICal->new();

    $initial_properties ||= [];
    for my $ip ( @$initial_properties ) {
        $calendar->add_property( $ip->[0] => $ip->[1] );
    }

    $calendar->add_entry($vevent);

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub _ics_list_for_meetings {
    my ( $self, $events, $user, $domain_id ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $vevents = [ map { $self->_ics_vevent_for_meeting( $_, $user, undef, $domain_id ) } @$events ];

    my $calendar = Data::ICal->new();

    # TODO: translate properly with user language
    $calendar->add_property( "X-WR-CALNAME" => Dicole::Utils::Text->ensure_internal( Dicole::Utils::User->name( $user ) . ' on Meetin.gs' ) );
    $calendar->add_entry($_) for @$vevents;

    return Dicole::Utils::Text->ensure_utf8( $calendar->as_string );
}

sub _ics_vevent_for_meeting {
    my ( $self, $event, $user, $users, $domain_id, $params ) = @_;

    return '' unless $event->begin_date;
    $params ||= {};

    $domain_id ||= $event->domain_id;
    $user = Dicole::Utils::User->ensure_object( $user || CTX->request->auth_user );

    my $domain_host = $self->_get_host_for_meeting( $event, 443 );
    my $inmail_address = $self->_get_meeting_email( $event, $domain_id );

    my $meeting_enter_url = $self->_meeting_has_swipetomeet( $event ) ?
        $self->_get_new_mobile_redirect_url( { redirect_to_meeting => $event->id, utm_source => 'ics' } )
        :
        $self->_get_meeting_enter_url( $event, $domain_host );

    my $description = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_ics_description_text_template' ),{
            meeting_email => $inmail_address,
            meeting_url => $meeting_enter_url,
            lahixcustxz_hack => $params->{lahixcustxz_hack},
        }, { user => $user }
    );

    my $vevent = Data::ICal::Entry::Event->new();

    my $ical_sequence = $self->_get_note( 'ical_sequence' => $event );

    my $location_string = $self->_meeting_location_string_without_default( $event );

    $vevent->add_properties(
        dtstamp => Dicole::Utils::Date->epoch_to_ical( time ),
        summary => Dicole::Utils::Text->ensure_internal( $self->_meeting_title_string( $event ) ),
        description => Dicole::Utils::Text->ensure_internal( $description ),
        status => $self->_meeting_is_cancelled( $event ) ? 'CANCELLED' : 'CONFIRMED',
        ( ( $location_string ) ? ( location => Dicole::Utils::Text->ensure_internal( $location_string ) ) : () ),
        dtstart => Dicole::Utils::Date->epoch_to_ical( $event->begin_date ),
        ( $event->end_date ) ? ( dtend  => Dicole::Utils::Date->epoch_to_ical( $event->end_date ) ) : (),
        uid => $self->_get_meeting_uid( $event ),
        ( $ical_sequence ) ? ( sequence => $ical_sequence ) : (),
    );

    if ( $params->{add_organizer} ) {
        my $oemail = 'assistant@' . ( CTX->server_config->{dicole}->{limited_email_gateway} || CTX->server_config->{dicole}->{default_email_gateway} );
        $vevent->add_properties(
             organizer => [ 'MAILTO:' . $oemail, { CN => 'Meetin.gs Assistant' } ],
        );
    }

    if ( $params->{add_attendees} ) {
        $users ||= $self->_fetch_meeting_participant_users( $event );

        for my $attendee ( @$users ) {
            my $ae = $attendee->email;
            if ( my $ics_email = $self->_get_note_for_user( ics_email => $attendee, $domain_id ) ) {
                $ae = $ics_email;
            }
            next unless $ae;
            $vevent->add_properties(
                 attendee => [ 'MAILTO:' . Dicole::Utils::Text->ensure_internal( $ae ), { CN => Dicole::Utils::Text->ensure_internal( Dicole::Utils::User->name( $attendee ) ), RSVP => 'FALSE', PARTSTAT => 'ACCEPTED' } ],
            );
        }
    }

    return $vevent;
}

sub _ics_vevent_for_matchmaker_lock {
    my ( $self, $lock, $user, $meeting ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user || $lock->creator_id || $lock->expected_confirmer_id );

    $meeting ||= $self->_ensure_meeting_object( $lock->created_meeting_id );

    # TODO: if accepted or declined, return meeting vevent

    my $creator_user = Dicole::Utils::User->ensure_object( $meeting->creator_id );
    my $creator_email = $creator_user->email;
    my $creator_name = Dicole::Utils::User->name( $creator_user );

    my $creator_long_name = $creator_name;
    $creator_long_name .= ' ('.$creator_email.')' unless $creator_long_name eq $creator_email;

    my $description = $self->_nmsg( 'This meeting is tentative. Wait for %1$s to confirm the meeting.', [ $creator_long_name ] );
    my $vevent = Data::ICal::Entry::Event->new();

    $vevent->add_properties(
        dtstamp => Dicole::Utils::Date->epoch_to_ical( time ),
        summary => Dicole::Utils::Text->ensure_internal( $lock->title . ' ' . $self->_nmsg( '(tentative)' ) ),
        status => 'TENTATIVE',
        description => Dicole::Utils::Text->ensure_internal( $description ),
        location => $self->_generate_matchmaker_lock_location_string( $lock ),
        dtstart => Dicole::Utils::Date->epoch_to_ical( $lock->locked_slot_begin_date ),
        dtend => Dicole::Utils::Date->epoch_to_ical( $lock->locked_slot_end_date ),
        uid => $self->_get_meeting_uid( $meeting ),
    );

    my $oemail = 'assistant@' . ( CTX->server_config->{dicole}->{limited_email_gateway} || CTX->server_config->{dicole}->{default_email_gateway} );
    $vevent->add_properties(
         organizer => [ 'MAILTO:' . $oemail, { CN => 'Meetin.gs Assistant' } ],
    );

    $vevent->add_properties(
        attendee => [ 'MAILTO:' . Dicole::Utils::Text->ensure_internal( $user->email ), { CN => Dicole::Utils::Text->ensure_internal( Dicole::Utils::User->name( $user ) ), RSVP => 'FALSE', PARTSTAT => 'ACCEPTED' } ],
    );

    $vevent->add_properties(
        attendee => [ 'MAILTO:' . Dicole::Utils::Text->ensure_internal( $creator_email ), { CN => Dicole::Utils::Text->ensure_internal( $creator_name ), RSVP => 'FALSE', PARTSTAT => 'TENTATIVE' } ],
    );

    return $vevent;
}

my $type_class_lookup = {
   PDF => "presentation",
   PSD => "image",
   XLS => "excel",
   XLSX => "excel",
   ODS => "excel",
   CSV => "excel",
   NUMBERS => "excel",
   PNG => "image",
   JPG => "image",
   JPEG => "image",
   GIF => "image",
   TIFF => "image",
   BMP => "image",
   AVI => "video",
   QT => "video",
   MP4 => "video",
   WMV => "video",
   MP2 => "video",
   PPT => "presentation",
   ODP => "presentation",
   PPTX => "presentation",
   KEY => "presentation",
   DOC => "document",
   DOCX => "document",
   TXT => "document",
   ODT => "document",
   RTF => "document",
   PAGES => "document",
   MPGA => "music",
   WAV => "music",
   OGG => "music",
};

sub _get_object_for_material_id {
    my ( $self, $material_id ) = @_;

    my ( $meeting_id, $object_type, $object_id ) = split /\:/, $material_id;
    return unless $object_type;

    # TODO: chech that object belongs to meeting...

    if ( $object_type eq 'page' ) {
        return $self->_get_object_for_wiki_id( $object_id );
    }
    elsif ( $object_type eq 'media' ) {
        return $self->_get_object_for_prese_id( $object_id );
    }
    elsif ( $object_type eq 'chat' ) {
        return $self->_ensure_meeting_object( $meeting_id );
    }

    die "invalid material id";
}

sub _translate_special_page_title {
    my ( $self, $title, $lc_opts ) = @_;

    if ( lc( $title ) eq 'action points' ) {
        $title = $self->_ncmsg('Action Points', $lc_opts )
    }
    if ( lc( $title ) eq 'previous action points' ) {
        $title = $self->_ncmsg('Previous Action Points', $lc_opts )
    }
    if ( lc( $title ) eq 'agenda' ) {
        $title = $self->_ncmsg('Agenda', $lc_opts )
    }
    return $title;
}

sub _gather_material_data_params {
    my ( $self, $meeting, $lc_opts ) = @_;

    my $event = $meeting;
    $lc_opts ||= {};

    my @materials = ();

    my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );
    my $media = $self->_gather_media_data( $meeting );

    for my $page ( @$pages ) {
        $page->{fetch_type} = 'page';
        $page->{type_class} = 'editabledocument';
        $page->{data_url} = $self->derive_url( action => 'meetings_json', task => 'wiki_object_info', domain_id => $meeting->domain_id, additional => [ $meeting->id, $page->{page_id} ] );
        $page->{material_id} = $self->_form_meeting_material_id( $meeting, $page );

        $page->{material_class} = 'agenda' if $self->_agenda_page_validator( $page );
        $page->{material_class} ||= 'action_points' if $self->_action_points_page_validator( $page );
        $page->{material_class} ||= 'other' if $self->_agenda_page_validator( $page );

        $page->{title} = $self->_translate_special_page_title( $page->{title} , $lc_opts );

        push @materials, $page;
    }

    push @materials, map {
        $_->{fetch_type} = 'media';
        $_->{type_class} = $type_class_lookup->{ $_->{readable_type} } || 'other';

        $_->{data_url} = $self->derive_url( action => 'meetings_json', task => 'prese_object_info', domain_id => $meeting->domain_id, additional => [ $meeting->id, $_->{prese_id} ] );
        $_->{material_id} = $self->_form_meeting_material_id( $meeting, $_ );
        $_->{material_class} = 'other';
        $_;
    } reverse @$media;

    @materials = sort { $a->{created_epoch} <=> $b->{created_epoch} } @materials;

    my $chat_title = '';
    if ( ! $meeting->begin_date ) {
        my $pos = $self->_fetch_meeting_proposals( $meeting );
        $chat_title = $self->_ncmsg('Scheduling Discussion', $lc_opts) if @$pos;
    }

    my $number_of_notes = CTX->lookup_action('comments_api')->e( get_comment_count => {
        object => $meeting,
        group_id => $meeting->group_id,
        user_id => 0,
        domain_id => $meeting->domain_id,
    } ) || 0;

    if ( ! $chat_title && $number_of_notes ) {
        $chat_title ||= $self->_ncmsg('Scheduling Discussion', $lc_opts );
        $chat_title = '' if 0;
    }

    if ( $chat_title ) {
        push @materials, {
            fetch_type => 'chat',
            type_class => 'document',
            data_url => $self->derive_url( action => 'meetings_json', task => 'chat_object_info', domain_id => $meeting->domain_id, additional => [ $meeting->id ] ),
            material_id => $self->_form_meeting_material_id( $meeting, 'chat' ),
            title => $chat_title,
            comment_count => $number_of_notes,
        };
    }

    return { materials => \@materials };
}

sub _gather_material_overview_params {
    my ( $self, $meeting, $user ) = @_;

    my $domain_id = $meeting->domain_id;
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $number_of_notes = CTX->lookup_action('comments_api')->e( get_comment_count => {
        object => $meeting,
        group_id => $meeting->group_id,
        user_id => 0,
        domain_id => $domain_id,
    } );

    my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );
    my $media = $self->_events_api( gather_media_data => { event => $meeting, limit => 999 } );

    my $materials = [];
    my $number_of_comments = $number_of_notes;

    for my $material ( @$pages, reverse @$media ) {
        push @$materials, {
            url => $self->_generate_complete_meeting_user_material_url_from_data( $meeting, $user, $material, $domain_host ),
            title => $material->{title},
            author_name => $material->{author_name},
            timestamp => $material->{time_ago},
            comment_count => $material->{comment_count} || 0,
        };
        $number_of_comments += $material->{comment_count} || 0;
    }

    return {
        materials => $materials,
        number_of_comments => $number_of_comments,
    };
}

sub _fetch_participations_by_user_hash_for_domain {
    my ( $self, $domain_id ) = @_;

    my $objects = CTX->lookup_object('events_user')->fetch_group({
        where => 'domain_id = ? AND removed_date = 0',
        value => [ $domain_id ],
    }) || [];

    my $by_user = {};
    for my $ob ( @$objects ) {
        my $list = $by_user->{ $ob->user_id } ||= [];
        push @$list, $ob;
    }

    return $by_user;
}

sub _fetch_meeting_participant_objects {
    my ( $self, $meeting ) = @_;

    return $self->_fetch_participant_objects_for_meeting_list( [ $meeting ] );
}

sub _fetch_meeting_scheduling_participant_objects {
    my ( $self, $meeting ) = @_;

    my $euos = $self->_fetch_meeting_participant_objects( $meeting );
    return [ map { $self->_get_note( scheduling_disabled => $_ ) ? () : $_ } @$euos ];
}

sub _fetch_participant_objects_for_meeting_list {
    my ( $self, $events ) = @_;

    return CTX->lookup_object('events_user')->fetch_group({
        where => 'removed_date = 0 AND ' . Dicole::Utils::SQL->column_in( event_id => [ map { ref( $_ ) ? $_->id : $_ } @$events ] ),
    }) || [];
}

sub _fetch_meeting_draft_participant_objects {
    my ( $self, $event ) = @_;

    return $self->_fetch_draft_participant_objects_for_meeting_list( [ $event ] );
}

sub _fetch_draft_participant_objects_for_meeting_list {
    my ( $self, $events ) = @_;

    return CTX->lookup_object('meetings_draft_participant')->fetch_group({
        where => Dicole::Utils::SQL->column_in( event_id => [ map { ref( $_ ) ? $_->id : $_ } @$events ] ) .
            ' AND sent_date = ? AND removed_date = ?',
        value => [ 0, 0 ],
    });
}

sub _fetch_meeting_participant_object_for_user {
    my ( $self, $event, $user, $euos ) = @_;

    if ( $euos ) {
        return { map { $_->user_id => $_ } @$euos }->{ Dicole::Utils::User->ensure_id( $user ) };
    }

    my $euo = CTX->lookup_object('events_user')->fetch_group({
        where => 'event_id = ? AND user_id = ? AND removed_date = 0',
        value => [ $self->_ensure_meeting_id( $event ), Dicole::Utils::User->ensure_id( $user ) ],
    }) || [];

    return pop @$euo;
}

sub _ensure_meeting_id {
    my ( $self, $meeting ) = @_;

    return ref( $meeting ) ? $meeting->id : $meeting;
}

sub _ensure_partner_object {
    my ( $self, $partner ) = @_;

    return ref( $partner ) ? $partner : $self->PARTNERS_BY_ID->{ $partner };
}

sub _ensure_meeting_object {
    my ( $self, $meeting ) = @_;

    return $self->_ensure_object_of_type( events_event => $meeting );
}

sub _ensure_object_id {
    my ( $self, $object_or_id ) = @_;

    return ref( $object_or_id ) ? $object_or_id->id : $object_or_id;
}

sub _ensure_object_of_type {
    my ( $self, $type, $object ) = @_;

    die "missing type" unless $type;

    return $object unless $object;

    return ref( $object ) ? $object : CTX->lookup_object($type)->fetch( $object );
}

sub _ensure_matchmaker_object {
    my ( $self, $mmr ) = @_;
    return $self->_ensure_object_of_type( meetings_matchmaker => $mmr );
}

sub _ensure_matchmaking_event_object {
    my ( $self, $candidate ) = @_;

    return $self->_ensure_object_of_type( meetings_matchmaking_event => $candidate );
}

sub _ensure_wiki_lock_object {
    my ( $self, $lock ) = @_;

    return $self->_ensure_object_of_type( wiki_lock => $lock );
}

sub _ensure_wiki_page_object {
    my ( $self, $page ) = @_;

    return $self->_ensure_object_of_type( wiki_page => $page );
}

sub _fetch_meeting_participant_users {
    my ( $self, $event, $euos, $return_hidden ) = @_;

    $euos ||= $self->_fetch_meeting_participant_objects( $event );

    return $return_hidden ?
        Dicole::Utils::User->ensure_object_list( [ map { $_->user_id } @$euos ] )
        :
        Dicole::Utils::User->ensure_object_list( [ map { $self->_get_note('is_hidden' => $_ ) ? () : $_->user_id } @$euos ] );
}

sub _internationalize_phone_number {
    my ( $self, $phone, $creator_user, $domain_id ) = @_;

    my $original = $phone;

    my ( $demosuffix ) = $phone =~ /(\#\#\#.*)$/;
    $phone =~ s/(\#\#\#.*)$// if $demosuffix;

    my $phone_obj = Number::Phone::Lib->new( $phone );
    if ( ! $phone_obj && $creator_user ) {
        $creator_user = Dicole::Utils::User->ensure_object( $creator_user );
        my $creator_ext = $domain_id ? $self->_get_note_for_user( 'meetings_force_phone_ext', $creator_user, $domain_id ) : '';

        if ( $creator_ext ) {
            $phone_obj = Number::Phone::Lib->new( $creator_ext, $phone );
        }
        else {
            my $creator_phone = $creator_user->phone || '';
            $creator_phone =~ s/(\#\#\#.*)$//;
            # TODO: fetch phone also from profile
            my $creator_obj = $creator_phone ? Number::Phone::Lib->new( $creator_phone ) : undef;
            if ( $creator_obj ) {
                $phone_obj = Number::Phone::Lib->new( '+' . $creator_obj->country_code, $phone );
            }
        }
    }

    $phone = $phone_obj ? $phone_obj->format : $phone;

    if ( $phone !~ /^\s*\+/ && $phone =~ /^\s*00/ ) {
        $phone =~ s/^\s*00/+/;

        my $phone_obj = Number::Phone::Lib->new( $phone );
        $phone = $phone_obj ? $phone_obj->format : $phone;
    }

    die "could not internationalize $original for creator " . ( $creator_user ? Dicole::Utils::User->ensure_id( $creator_user ) : 0 ) unless $phone =~ /^\s*\+/;

    $phone .= $demosuffix || '';
    $phone =~ s/\s//g;

    return $phone;
}

sub _fetch_user_for_phone {
    my ( $self, $phone, $domain_id, $guessed_user, $opts ) = @_;

    $phone = $self->_internationalize_phone_number( $phone, $opts->{creator_user}, $domain_id );

    my $user;

    if ( $guessed_user && ! $user ) {
        $user = $guessed_user if $phone eq $guessed_user->phone;
    }


    if ( ! $user ) {
        $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

        my $phones = CTX->lookup_object('meetings_user_service_account')->fetch_group({
            where => 'domain_id = ? AND service_type = ? AND service_uid = ? AND verified_date > ?',
            value => [ $domain_id, 'phone', $phone, 0 ],
            order => 'created_date asc',
        }) || [];


        for my $p ( @$phones ) {
            $user ||= eval { Dicole::Utils::User->ensure_object( $p->user_id ) };
        }

        $user ||= Dicole::Utils::User->fetch_user_by_phone_in_domain( $phone, $domain_id );
    }

    if ( CTX->request && $user ) {
        return CTX->request->auth_user if $user->id == CTX->request->auth_user_id;
    }

    return $user;
}

sub _fetch_user_objects_map_by_emails {
    my ( $self, $emails, $domain_id ) = @_;

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in_strings( email => $emails ),
    } ) || [];

    my $users_map = { map { $_->id => $_ } @$users };

    my $domain_users = CTX->lookup_object('dicole_domain_user')->fetch_group( {
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => [ keys %$users_map ] ),
        value => [ $domain_id ],
    } ) || [];

    return { map { lc( $users_map->{ $_->user_id }->email ) => $users_map->{ $_->user_id } } @$domain_users };
}

sub _fetch_user_for_email {
    my ( $self, $email, $domain_id, $guessed_user ) = @_;

    my $ao = eval { Dicole::Utils::Mail->string_to_address_object( $email ) };
    return undef unless $ao;

    return $self->_fetch_user_for_address_object( $ao, $domain_id, $guessed_user );
}

sub _fetch_or_create_user_for_email {
    my ( $self, $email, $domain_id, $opts ) = @_;

    my $ao = Dicole::Utils::Mail->string_to_address_object( $email );

    return $self->_fetch_or_create_user_for_address_object( $ao, $domain_id, $opts );
}

sub _fetch_user_for_address_object {
    my ( $self, $ao, $domain_id, $guessed_user ) = @_;

    Carp::confess "No valid address object" unless $ao;

    my $address = Dicole::Utils::Text->ensure_utf8( $ao->address );
    die unless $address;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $ueos = CTX->lookup_object('meetings_user_email')->fetch_group({
        where => 'domain_id = ? AND email = ? AND verified_date > ?',
        value => [ $domain_id, $address, 0 ],
        order => 'created_date asc',
    }) || [];

    my $user;

    for my $ueo ( @$ueos ) {
        $user = eval { Dicole::Utils::User->ensure_object( $ueo->user_id ) };
        last if $user;
    }

    if ( $guessed_user && ! $user ) {
        $user = $guessed_user if $address eq $guessed_user->email;
    }

    $user ||= Dicole::Utils::User->fetch_user_by_login_in_domain( $address, $domain_id );

    if ( CTX->request && $user ) {
        return CTX->request->auth_user if $user->id == CTX->request->auth_user_id;
    }

    return $user;
}

sub _fetch_or_create_user_for_address_object {
    my ( $self, $ao, $domain_id, $opts ) = @_;

    $opts ||= {};

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $user = $self->_fetch_user_for_address_object( $ao, $domain_id );

    if ( ! $user ) {
        my ( $first_name, $last_name ) = $self->_parse_first_and_last_names_from_email_address_phrase( $ao->phrase );
        # create new user
        $user = CTX->lookup_action('user_manager_api')->e( create_user => {
            domain_id => $domain_id,
            email => Dicole::Utils::Text->ensure_utf8( $ao->address ),
            first_name => $first_name,
            last_name => $last_name,
            timezone => $opts->{timezone} || $self->_determine_timezone,
            language => $opts->{language} || 'en', # TODO TRANS
        } );

        my $group = CTX->lookup_action('groups_api')->e( add_group => {
            name => $user->id,
            creator_id => $user->id,
            domain_id => $domain_id,
        } );

        $self->_set_note_for_user( 'meetings_base_group_id', $group->id, $user, $domain_id );

        # NOTE: do this here to avoid race conditions where invalidation secret gets overwritten because it is empty in many processes
        Dicole::Utils::User->authorization_key_invalidation_secret( $user );

        eval { CTX->lookup_action('meetings_api')->e( check_user_startup_status => {
            user => $user,
            domain_id => $domain_id,
        } ) };
    }

    return $user;
}

sub _fetch_or_create_user_for_phone_and_name {
    my ( $self, $phone, $name, $domain_id, $opts ) = @_;

    $opts ||= {};

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $phone = $self->_internationalize_phone_number( $phone, $opts->{creator_user}, $domain_id );

    my $user = $self->_fetch_user_for_phone( $phone, $domain_id, undef, $opts );

    if ( ! $user ) {
        my ( $first_name, $last_name ) = $self->_parse_first_and_last_names_from_email_address_phrase( $name );

        # create new user
        $user = CTX->lookup_action('user_manager_api')->e( create_user => {
            domain_id => $domain_id,
            email => '',
            first_name => $first_name,
            last_name => $last_name,
            timezone => $opts->{timezone} || $self->_determine_timezone,
            language => $opts->{language} || 'en', # TODO TRANS
        } );

        $user->phone( $phone );

        my $phoneobj = Number::Phone::Lib->new( $phone );
        if ( $phoneobj && lc( $phoneobj->country ) eq 'us' ) {
            $self->_set_note_for_user( time_display => 'ampm', $user, $domain_id, { skip_save => 1 } );
        }

        $user->save;

        my $group = CTX->lookup_action('groups_api')->e( add_group => {
            name => $user->id,
            creator_id => $user->id,
            domain_id => $domain_id,
        } );

        $self->_set_note_for_user( 'meetings_base_group_id', $group->id, $user, $domain_id );

        CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            user_id => $user->id,
            domain_id => $domain_id,
            attributes => {
                contact_phone => $user->phone || undef,
            },
        } );

        # NOTE: do this here to avoid race conditions where invalidation secret gets overwritten because it is empty in many processes
        Dicole::Utils::User->authorization_key_invalidation_secret( $user );

        eval { CTX->lookup_action('meetings_api')->e( check_user_startup_status => {
            user => $user,
            domain_id => $domain_id,
        } ) };
    }

    return $user;
}

sub _send_user_sms {
    my ( $self, $user, $body, $opts ) = @_;

    $opts ||= {};
    $opts->{user} = $user;

    my $phone = $user->phone;
    if ( ! $phone ) {
        my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            user_id => $user->id,
            domain_id => $opts->{domain_id},
            attributes => { contact_phone => undef },
        } );
        $phone = $attrs->{contact_phone};
        $phone = $phone ? eval { $self->_internationalize_phone_number( $phone, $opts ? $opts->{creator_user} : undef, $opts->{domain_id} ) } : 0;
    }

    return 0 unless $phone;

    $phone =~ s/\#.*//;

    return $self->_send_sms( $phone, $body, $opts );
}

sub _send_sms {
    my ( $self, $to, $body, $opts ) = @_;

    my $twilio_sid = CTX->server_config->{dicole}{twilio_sid};
    my $twilio_token = CTX->server_config->{dicole}{twilio_token};
    my $twilio_from = CTX->server_config->{dicole}{twilio_from};
    my $alternative_numbers = CTX->server_config->{dicole}{twilio_alternative_numbers};

    my ( $t4, $t3, $t2, $t1 ) = $to =~ /^((((\+.).).).)/;

    my $alternative_number = '';
    my $alternative_number_level = 0;

    $alternative_numbers = [ $alternative_numbers || () ] unless ref( $alternative_numbers ) eq 'ARRAY';
    for my $n ( @$alternative_numbers ) {
        my ( $n4, $n3, $n2, $n1 ) = $n =~ /^((((\+.).).).)/;
        if ( $alternative_number_level < 4 && ( $n4 eq $t4 ) ) {
            $alternative_number = $n;
            $alternative_number_level = 4;
        }
        elsif ( $alternative_number_level < 3 && ( $n3 eq $t3 ) ) {
            $alternative_number = $n;
            $alternative_number_level = 3;
        }
        elsif ( $alternative_number_level < 2 && ( $n2 eq $t2 ) ) {
            $alternative_number = $n;
            $alternative_number_level = 2;
        }
        elsif ( $alternative_number_level < 1 && ( $n1 eq $t1 ) ) {
            $alternative_number = $n;
            $alternative_number_level = 2;
        }
    }

    $twilio_from = $alternative_number if $alternative_number;
    my $response;
    eval {
        $response = Dicole::Utils::HTTP->post( "https://api.twilio.com/2010-04-01/Accounts/$twilio_sid/Messages", {
            'To' => $to,
            'From' => $twilio_from,
            'Body' => $body,
        }, 15, $twilio_sid, $twilio_token );
    };

    if ( $@ ) {
        if ( ! $response ) {
            $response = $@;
        }
        $body = 'UNDELIVERED: ' . $body;
    }

    if ( $opts->{user} ) {
        my $log_data = $opts->{log_data} || {};
        $log_data->{snippet} = [split "\n", $body]->[0];
        $self->_record_user_contact_log( $opts->{user}, 'sms', $to, $twilio_from, { raw_body => ''.$body, raw_response => ''.$response, %$log_data } );
    }

    return 1;
}

sub _create_temporary_user {
    my ( $self, $domain_id, $language ) = @_;

    my $user = CTX->lookup_action('user_manager_api')->e( create_user => {
        domain_id => $domain_id,
        email => '',
        first_name => '',
        last_name => '',
        timezone => $self->_determine_timezone,
        language => $language || 'en',
    } );

    my $group = CTX->lookup_action('groups_api')->e( add_group => {
        name => $user->id,
        creator_id => $user->id,
        domain_id => $domain_id,
    } );

    $self->_set_note_for_user( 'meetings_base_group_id', $group->id, $user, $domain_id );

    # NOTE: do this here to avoid race conditions where invalidation secret gets overwritten because it is empty in many processes
    Dicole::Utils::User->authorization_key_invalidation_secret( $user );

    return $user;
}

sub _purge_temporary_user {
    my ( $self, $user, $domain_id ) = @_;

    my $group_id = $self->_get_note_for_user( 'meetings_base_group_id', $user, $domain_id );

    return;
    # TODO: implement these:

    CTX->lookup_action('user_manager_api')->e( remove_user => {
        user => $user,
        domain_id => $domain_id,
    } );

    CTX->lookup_action('groups_api')->e( remove_group => {
        group_id => $group_id,
    } );
}

sub _add_user_email {
    my ( $self, $user, $domain_id, $email, $verified ) = @_;

    my $user_email_object = CTX->lookup_object('meetings_user_email')->new( {
        user_id => $user->id,
        domain_id => $domain_id,
        created_date => time,
        verified_date => $verified ? time : 0,
        email => $email,
    });

    $user_email_object->save;

    return $user_email_object;
}

sub _get_verified_user_email_objects {
    my ( $self, $user, $domain_id ) = @_;

    return CTX->lookup_object('meetings_user_email')->fetch_group({
        where => 'user_id = ? AND domain_id = ?',
        value => [ $user->id, $domain_id ],
    });
}

sub _get_user_with_verified_service_account {
    my ( $self, $type, $uid, $domain_id ) = @_;

    my $existing_owners = CTX->lookup_object('meetings_user_service_account')->fetch_group({
        where => 'service_type = ? AND service_uid = ? AND domain_id = ? AND verified_date > ?',
        value => [ $type, $uid, $domain_id, 0 ],
        order => 'verified_date asc',
    }) || [];

    return undef unless @$existing_owners;

    my $account = shift @$existing_owners;
    return Dicole::Utils::User->ensure_object( $account->user_id );
}

sub _add_user_service_account {
    my ( $self, $user, $domain_id, $service_type, $service_uid, $verified, $notes ) = @_;

    my $existing = CTX->lookup_object('meetings_user_service_account')->fetch_group( {
        where => 'user_id = ? AND domain_id = ? AND service_type = ? AND service_uid = ?',
        value => [ $user->id, $domain_id, $service_type, $service_uid ],
    } );

    my $account;

    if ( scalar( @$existing ) ) {
        $account = shift @$existing;
        $account->verified( time ) if $verified && ! $account->verified;
        $account->save;
        # TODO: merge notes somehow :P
    }
    else {
        $account = CTX->lookup_object('meetings_user_service_account')->new;
        $account->user_id( $user->id );
        $account->domain_id( $domain_id );
        $account->service_type( $service_type );
        $account->service_uid( $service_uid );
        $account->created_date( time );
        $account->verified_date( $verified ? time : 0 );
        $account->notes( Dicole::Utils::JSON->encode( $notes || [] ) );
        $account->save;
    }
    return $account;
}

sub _get_user_service_accounts {
    my ( $self, $user, $domain_id ) = @_;

    return CTX->lookup_object('meetings_user_service_account')->fetch_group( {
        where => 'user_id = ? AND domain_id = ?',
        value => [ $user->id, $domain_id ],
    } );
}

sub _get_verified_user_service_accounts {
    my ( $self, $user, $domain_id ) = @_;

    my $service_accounts = $self->_get_user_service_accounts( $user, $domain_id );
    return [ map { $_->verified_date ? $_ : () } @$service_accounts ];
}

sub _parse_first_and_last_names_from_email_address_phrase {
    my ( $self, $phrase ) = @_;

    $phrase = Dicole::Utils::Text->ensure_utf8( $phrase );
    $phrase =~ s/^\s*(.*?)\s*$/$1/;
    my @parts = split /\s+/, $phrase;
    my $last_name = pop @parts;
    my $first_name = join " ", @parts;

    return ( $first_name, $last_name );
}

sub _count_user_beta_invites {
    my ( $self, $user, $invited_users ) = @_;

    return 0 unless $user || CTX->request->auth_user_id;
    $user ||= CTX->request->auth_user;

    $invited_users ||= $self->_get_note_for_user( 'meetings_users_invited', $user ) || [];
    my $total_invites = $self->_get_note_for_user( 'meetings_total_beta_invites', $user );
    $total_invites = 100 if $total_invites < 100;

    my %invited_users_by_id = map { $_ => 1 } @$invited_users;
    my $invited_users_number = scalar( keys %invited_users_by_id );

    return $total_invites - $invited_users_number;
}

sub _get_note_for_user {
    my ( $self, $note, $user, $domain_id ) = @_;

    $user ||= CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    return Dicole::Utils::User->get_domain_note( $user, $domain_id, $note );
}

sub _set_note_for_user {
    my ( $self, $note, $value, $user, $domain_id, $opts ) = @_;

    $opts = { skip_save => $opts } unless ref $opts eq 'HASH';

    $user ||= CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return Dicole::Utils::User->set_domain_note( $user, $domain_id, $note, $value, $opts );
}

sub _add_email_for_user {
    my ( $self, $email, $user, $verified, $domain_id ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    my $uid = Dicole::Utils::User->ensure_id( $user );

    my $existing = CTX->lookup_object('meetings_user_email')->fetch_group({
        where => 'domain_id = ? AND user_id = ? AND email = ?',
        value => [ $domain_id, $uid, $email ],
        order => 'created_date asc',
    });

    my $object = shift @$existing;

    if ( ! $object ) {
        CTX->lookup_object('meetings_user_email')->new( {
            domain_id => $domain_id,
            user_id => $uid,
            email => $email,
            created_date => time,
            verified_date => $verified ? time : 0,
        } )->save;

        $existing = CTX->lookup_object('meetings_user_email')->fetch_group({
            where => 'domain_id = ? AND user_id = ? AND email = ?',
            value => [ $domain_id, $uid, $email ],
            order => 'created_date asc',
        });

        $object = shift @$existing;
    }

    if ( $verified && $object && ! $object->verified ) {
        $object->verified( time );
        $object->save;
    }

    $_->remove for @$existing;

    return $object;
}

sub _remove_email_from_user {
    my ( $self, $email, $user, $domain_id ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    my $uid = Dicole::Utils::User->ensure_id( $user );

    my $existing = CTX->lookup_object('meetings_user_email')->fetch_group({
        where => 'domain_id = ? AND user_id = ? AND email = ?',
        value => [ $domain_id, $uid, $email ],
        order => 'created_date asc',
    });

    $_->remove for @$existing;

    return 1;
}

sub _remove_user_from_meeting {
    my ( $self, $user, $event, $opts ) = @_;

    return $self->_events_api( remove_event_user => {
        event => $event,
        user => $user,
    } );

    $self->_calculate_meeting_is_pro( $event ) unless $opts && $opts->{skip_calculate_is_pro};
}

sub _add_user_to_meeting {
    my ( $self, $user, $event, $by_user, $as_planner, $opts ) = @_;

    my $gid = $event->group_id;
    my $by_user_id = $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : CTX->request->auth_user_id || 0;

    if ( $gid && ! Dicole::Utils::User->belongs_to_group( $user, $gid ) ) {
        CTX->lookup_action('groups_api')->e( add_user_to_group => {
            user_id => Dicole::Utils::User->ensure_id( $user ), group_id => $gid, domain_id => $event->domain_id
        } );
    }

    my $euo = $self->_events_api( $as_planner ? 'add_event_planner' : 'add_event_user', {
        event => $event,
        user => $user,
        inviter_id => $by_user_id,
        was_invited => 1,
    } );

    # do not send digests from events that happened before join.. with 70 second margin
    $self->_set_note_for_meeting_user( 'digest_sent', time() + 70, $event, ref( $user ) ? $user->id : $user, $euo, 'skip_save' );
    # send first reminder after a day and not instantly.
    $self->_set_note_for_meeting_user( 'scheduling_reminder_sent' => time, $event, ref( $user ) ? $user->id : $user, $euo );

    $self->_calculate_meeting_is_pro( $event ) unless $opts && $opts->{skip_calculate_is_pro};

    return $euo;
}

sub _stripe_request {
    my ( $self, $method, $path, $opts ) = @_;

    my $stripe_key = CTX->server_config->{dicole}{stripe_secret_key};

    $opts ||= {};
    $opts->{timeout} ||= 10000;

    my $url = "https://api.stripe.com" . $path;

    my $request_options = {
        method => uc( $method ),
        url => $url,
        json => 1,
        auth => { user => $stripe_key },
        %$opts
    };

    my $response = Dicole::Utils::Gearman->do_task( http_request => $request_options );

    if ( ref( $response ) eq 'HASH' ) {
        return ( $response->{error}, $response->{response} );
    }
    return $response;
}

sub _add_user_to_meeting_unless_already_exists {
    my ( $self, %params ) = @_;

    my $params = { %params };

    my $user = $params->{user};
    my $meeting = $params->{meeting};
    my $by_user = $params->{by_user};

    return undef unless $user && $meeting;

    $by_user = Dicole::Utils::User->ensure_object( $by_user ) if $by_user;

    $params ||= {};

    my $participant = $self->_add_user_to_meeting( $user, $meeting, $by_user, 0, { skip_calculate_is_pro => 1 } );

    if ( $self->_clean_up_duplicate_participant( $meeting, $participant ) ) {
        return undef;
    }

    my $rsvp_required = $params->{require_rsvp} ? 1 : 0;

    $self->_set_note_for_meeting_user( rsvp_required => $rsvp_required, $meeting, $participant->user_id, $participant, { skip_save => 1 } );
    $self->_set_note_for_meeting_user( rsvp_require_sent => time, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $rsvp_required;
    $self->_set_note_for_meeting_user( rsvp_required_by_user_id => $by_user->id, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $rsvp_required;

    my $scheduling_disabled = $params->{scheduling_disabled} ? 1 : 0;

    $self->_set_note_for_meeting_user( scheduling_disabled => $scheduling_disabled, $meeting, $participant->user_id, $participant, { skip_save => 1 } );
    $self->_set_note_for_meeting_user( scheduling_disabled_by_user_id => $by_user->id, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $scheduling_disabled && $by_user;

    $participant->is_planner( 1 ) if $params->{is_planner};
    $self->_set_note_for_meeting_user( is_planner => 1, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $params->{is_planner};
    $self->_set_note_for_meeting_user( is_hidden => 1, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $params->{is_hidden};
    $self->_set_note_for_meeting_user( greeting_message => $params->{greeting_message}, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $params->{greeting_message};
    $self->_set_note_for_meeting_user( greeting_subject => $params->{greeting_subject}, $meeting, $participant->user_id, $participant, { skip_save => 1 } ) if $params->{greeting_subject};

    $participant->save;

    my $meetme_requester = $self->_get_meeting_matchmaking_requester_user( $meeting );
    my $from_user_meetme_request = ( $meetme_requester && $meetme_requester->id == $participant->user_id ) ? 1 : 0;

    $self->_store_participant_event( $meeting, $participant, 'created', { author => $by_user, data => { rsvp_required => $rsvp_required, from_user_meetme_request => $from_user_meetme_request }, skip_notification => $params->{skip_notification} } ) unless $params->{skip_event};

    if ( ! $params->{skip_event} ) {
        if ( $meeting->begin_date && ! $rsvp_required ) {
            $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'invitation', from_user => $by_user } );
        }
    }

    $self->_calculate_meeting_is_pro( $meeting ) unless $params->{skip_calculate_is_pro};

    return $participant;
}

sub _ensure_first_app_login_recorded_for_user {
    my ( $self, $user, $params ) = @_;

    return unless $params->{device_type} eq 'ios' || $params->{device_type} eq 'android';

    $user = Dicole::Utils::User->ensure_object( $user );

    my $prefix = $self->_determine_app_note_prefix( $params );
    if ( $user ) {
        my $login_note = join( "_", ( $prefix || () ), $params->{device_type} . '_device_first_login' );
        if ( ! $self->_get_note_for_user( $login_note, $user, $params->{domain_id} ) ) {
            $self->_set_note_for_user( $login_note, time, $user, $params->{domain_id} );
        }
    }
}

sub _determine_user_device_token_from_urbanairship {
    my ( $self, $user, $domain_id, $prefix, $device_id, $limit_device_type ) = @_;

    my $push_prefix = $prefix || 'live';
    my $cache = $self->_get_note_for_user( urban_airship_converted_devices => $user, $domain_id ) || {};

    if ( my $found = $cache->{ $push_prefix }->{ $device_id } ) {
        return '' if $limit_device_type && $found->{channel}{device_type} ne $limit_device_type;
        return $found->{channel}{push_address} || '';
    }

    return '';
}

sub _store_channel_from_urbanairship {
    my ( $self, $domain_id, $prefix, $channel ) = @_;

    my $push_prefix = $prefix || 'live';
    my $device_id = $channel->{channel_id};
    my $user_id = $channel->{alias};

    return unless $user_id && $device_id;

    my $user = eval { Dicole::Utils::User->ensure_object( $user_id ) };
    return unless $user;

    my $cache = $self->_get_note_for_user( urban_airship_converted_devices => $user, $domain_id ) || {};

    $cache->{ $push_prefix }->{ $device_id } = { channel => $channel };

    $self->_set_note_for_user( urban_airship_converted_devices => $cache, $user, $domain_id );

    return 1;
}

sub _fetch_enabled_user_push_tokens_of_type {
    my ( $self, $user, $domain_id, $prefix, $device_type ) = @_;

    my $push_prefix = $prefix || 'live';
    my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id );
    my $enabled = $device_data->{ $push_prefix }->{ $device_type }->{enabled} || {};
    my $disabled = $device_data->{ $push_prefix }->{ $device_type }->{disabled} || {};

    my $uc_tokens = {};

    my $tokens = [];

    for my $token ( keys %$enabled ) {
        next if $uc_tokens->{ uc( $token ) }++;
        push @$tokens, $token;
    }

    # NOTE: this is after the previous to still enable newly registered
    # tokens that were disabled by UA with different case
    for my $token ( keys %$disabled ) {
        next if $uc_tokens->{ uc( $token ) }++;
    }

    my $legacy_device_data = $self->_get_note_for_user( device_push_status_map => $user, $domain_id );
    my $legacy_enabled = $legacy_device_data->{ $prefix }->{enabled} || {};

    for my $legacy_token ( keys %$legacy_enabled ) {
        my $token = $self->_determine_user_device_token_from_urbanairship( $user, $domain_id, $prefix, $legacy_token, $device_type );
        next unless $token;
        next if $uc_tokens->{ uc( $token ) }++;
        push @$tokens, $token || ();
    }

    return $tokens;
}

sub _determine_app_version_prefix {
    my ( $self, $params ) = @_;

    return 'cmeet' if $params->{app_version} =~ /cmeet/i;
    return 'swipetomeet' if $params->{app_version} =~ /swipe/i;

    return '';
}

sub _determine_app_beta_prefix {
    my ( $self, $params ) = @_;

    return 'beta' if $params->{beta_device} || $params->{beta};

    return '';
}

sub _determine_app_note_prefix {
    my ( $self, $params ) = @_;

    my $beta = $self->_determine_app_beta_prefix( $params );
    my $version = $self->_determine_app_version_prefix( $params );

    return join( "_", $beta || (), $version || () );
}

sub _determine_app_urban_airship_auth {
    my ( $self, $params ) = @_;

    my $prefix = $self->_determine_app_note_prefix( $params );

    return $self->_determine_prefixed_urban_airship_auth( $prefix );
}

sub _determine_prefixed_urban_airship_auth {
    my ( $self, $prefix ) = @_;

    my $key_key = join( "_", ( $prefix || () ), 'urban_airship_key' );
    my $key_secret = join( "_", ( $prefix || () ), 'urban_airship_secret' );

    my $key = CTX->server_config->{dicole}->{ $key_key } || '';
    my $secret = CTX->server_config->{dicole}->{ $key_secret } || '';

    return $key ? "$key:$secret" : "";
}

sub _ensure_user_scheduling_state {
    my ( $self, $user, $scheduling, $state ) = @_;

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    my $user_id = Dicole::Utils::User->ensure_id( $user );

    my $logs = CTX->lookup_object('meetings_scheduling_log_entry')->fetch_group( {
            where => 'scheduling_id = ? AND meeting_id = ?',
            value => [ $scheduling->id, $scheduling->meeting_id ],
            order => 'created_date desc'
        });

    my $previous_state = '';

    for my $log ( @$logs ) {
        next unless $log->entry_type eq 'user_state_changed';
        my $data = $self->_get_note( data => $log );
        next unless $data && $data->{user_id} == $user_id;
        $previous_state = $data->{state};
        last;
    }

    return 1 if $previous_state eq $state;

    return $self->_record_scheduling_log_entry_for_user( 'user_state_changed', $scheduling, $user, { state => $state, user_id => $user_id } );
}

sub _ensure_scheduling_instruction {
    my ( $self, $scheduling, $instruction ) = @_;

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );

    my $logs = CTX->lookup_object('meetings_scheduling_log_entry')->fetch_group( {
            where => 'scheduling_id = ? AND meeting_id = ?',
            value => [ $scheduling->id, $scheduling->meeting_id ],
            order => 'created_date desc'
        });

    my $previous_instruction = '';

    for my $log ( @$logs ) {
        next unless $log->entry_type eq 'instruction_changed';
        my $data = $self->_get_note( data => $log );
        $previous_instruction = $data->{instruction};
        last;
    }

    return 1 if $previous_instruction eq $instruction;

    return $self->_record_scheduling_log_entry( "instruction_changed", $scheduling, { instruction => $instruction } );
}

sub _record_scheduling_log_entry_for_user {
    my ( $self, $type, $scheduling, $user, $data ) = @_;

    $data->{author_id} = Dicole::Utils::User->ensure_id( $user );

    return $self->_record_scheduling_log_entry( $type, $scheduling, $data );
}

sub _record_scheduling_log_entry {
    my ( $self, $type, $scheduling, $data, $override_date ) = @_;

    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );
    $data ||= {};

    Dicole::Utils::Gearman->dispatch_task( record_scheduling_log_entry => {
        domain_id => $scheduling->domain_id,
        scheduling_id => $scheduling->id,
        meeting_id => $scheduling->meeting_id,
        entry_type => $type,
        entry_date => delete $data->{entry_date},
        author_id => delete $data->{author_id},
        created_date => $override_date || time,

        data => $data,
    } );
}

sub _record_user_contact_log {
    my ( $self, $user, $method, $destination, $origin, $original_data ) = @_;

    my $data = { %{ $original_data || {} } };

    my $scheduling = delete $data->{scheduling};
    my $scheduling_id = $self->_ensure_object_id( $scheduling || $data->{scheduling_id} || 0 );
    my $meeting = delete $data->{meeting};
    my $meeting_id = $self->_ensure_object_id( $meeting || $data->{meeting_id} || 0 );
    my $created_date = delete $data->{created_date};
    my $success_date = delete $data->{success_date};
    my $type = delete $data->{type};
    my $snippet = delete $data->{snippet};
    my $user_id = Dicole::Utils::User->ensure_id( $user );

    Dicole::Utils::Gearman->dispatch_task( record_user_contact_log => {
        scheduling_id => $scheduling_id || 0,
        meeting_id => $meeting_id || 0,
        user_id => $user_id || 0,
        contact_method => $method || '',
        contact_destination => $destination || '',
        contact_origin => $origin || '',
        contact_type => $type || 'unknown',
        snippet => $snippet || '',
        created_date => $created_date || 0,
        success_date => $success_date || 0,

        data => $data,
    } );

    return 1;
}

sub _queue_user_scheduling_segment_event {
    my ( $self, $user, $scheduling, $event, $properties ) = @_;
    $properties ||= {};
    $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling );
    $properties->{scheduling_id} = $scheduling->id;
    $properties->{meeting_id} = $scheduling->meeting_id;

    return $self->_queue_user_segment_event( $user, $event, $properties );
}

sub _queue_user_segment_event {
    my ( $self, $user, $event, $properties ) = @_;
    $properties ||= {};
    $properties->{userId} = Dicole::Utils::User->ensure_id( $user );

    Dicole::Utils::Gearman->dispatch_task( send_segment_event => { event_name => $event, properties => $properties } );
}

sub _queue_user_segment_identify {
    my ( $self, $user, $properties ) = @_;
    $properties ||= {};

    Dicole::Utils::Gearman->dispatch_task( send_segment_identify => { user_id => Dicole::Utils::User->ensure_id( $user ), properties => $properties } );
}

sub _send_segment_event {
    my ( $self, $event, $properties ) = @_;

    $properties ||= {};
    my $userId = delete $properties->{userId};

    my $segment_data = {
        $userId ? ( userId => $userId ) : (),
        event => $event,
        properties => $properties,
    };

    my $response = Dicole::Utils::HTTP->post_json( 'https://api.segment.io/v1/track', $segment_data, undef, CTX->server_config->{dicole}->{segment_write_key} );

    my $all_good = 0;
    if ( $response ) {
        my $response_data = eval { Dicole::Utils::JSON->decode( $response || '{}' ) };
        if ( $response_data && ref( $response_data ) eq 'HASH' && ! $response_data->{error} ) {
            $all_good = 1;
        }
    }

    unless ( $all_good ) {
        get_logger( LOG_APP )->error( "Error pushing event to segment.io: " . ( $response || $@ ) . " -- " . Data::Dumper::Dumper( $segment_data ) );
        return 0;
    }

    return 1;

}

sub _send_segment_identify {
    my ( $self, $user, $properties ) = @_;

    my $segment_data = {
        userId => Dicole::Utils::User->ensure_id( $user ),
        traits => $properties,
    };

    my $response = Dicole::Utils::HTTP->post_json( 'https://api.segment.io/v1/identify', $segment_data, undef, CTX->server_config->{dicole}->{segment_write_key} );

    my $all_good = 0;
    if ( $response ) {
        my $response_data = eval { Dicole::Utils::JSON->decode( $response || '{}' ) };
        if ( $response_data && ref( $response_data ) eq 'HASH' && ! $response_data->{error} ) {
            $all_good = 1;
        }
    }

    unless ( $all_good ) {
        get_logger( LOG_APP )->error( "Error pushing identify to segment.io: " . ( $response || $@ ) . " -- " . Data::Dumper::Dumper( $segment_data ) );
        return 0;
    }

    return 1;
}

sub _send_mixpanel_event {
    my ( $self, $event, $properties ) = @_;

    $properties ||= {};
    $properties->{token} = CTX->server_config->{dicole}->{mixpanel_token};

    my $mixpanel_data = {
        event => $event,
        properties => $properties,
    };

    my $response = Dicole::Utils::HTTP->post( 'http://api.mixpanel.com/track?verbose=1', {
            data => Dicole::Utils::Data->single_line_base64_json( $mixpanel_data )
        } );

    my $all_good = 0;
    if ( $response ) {
        my $response_data = eval { Dicole::Utils::JSON->decode( $response ) };
        if ( $response_data && ref( $response_data ) eq 'HASH' && $response_data->{status} eq '1' ) {
            $all_good = 1;
        }
    }

    unless ( $all_good ) {
        get_logger( LOG_APP )->error( "Error pushing event to mixpanel: " . ( $response || $@ ) . " -- " . Data::Dumper::Dumper( $mixpanel_data ) );
        return 0;
    }

    return 1;
}


sub _user_can_manage_meeting {
    my ( $self, $user, $event, $uo ) = @_;

    $uo ||= $self->_get_user_meeting_participation_object( $user, $event, $uo );
    return ( $uo && $uo->is_planner ) ? 1 : 0;
}

sub _user_can_invite { return shift->_user_can( 'invite', @_ ); }
sub _user_can_add_material { return shift->_user_can( 'add_material', @_ ); }
sub _user_can_edit_material { return shift->_user_can( 'edit_material', @_ ); }
sub _user_can_add_time_suggestions { return shift->_user_can( 'add_time_suggestions', @_ ); }

sub _user_can {
    my ( $self, $permission, $user, $meeting, $euo ) = @_;

    $user    //= CTX->request->auth_user;
    $meeting //= $self->_get_valid_event;

    return 1 if $self->_user_can_manage_meeting( $user, $meeting, $euo );

    return $self->_get_meeting_permission( $meeting, $permission );
}

sub _get_meeting_permission {
    my ( $self, $meeting, $permission ) = @_;

    die unless $self->USER_RIGHTS_MAP->{$permission};

    if ( $self->ENABLABLE_USER_RIGHTS_MAP->{$permission} ) {
        return $self->_get_note_for_meeting( 'enable_user_' . $permission, $meeting ) ? 1 : 0;
    }
    else {
        return $self->_get_note_for_meeting( 'disable_user_' . $permission, $meeting ) ? 0 : 1;
    }
}

sub _set_meeting_permission {
    my ( $self, $meeting, $permission, $value, $opts ) = @_;

    die unless $self->USER_RIGHTS_MAP->{$permission};

    if ( $self->ENABLABLE_USER_RIGHTS_MAP->{$permission} ) {
        return $self->_set_note_for_meeting( 'enable_user_' . $permission, $value ? 1 : 0, $meeting, $opts );
    }
    else {
        return $self->_set_note_for_meeting( 'disable_user_' . $permission, $value ? 0 : 1, $meeting, $opts );
    }
}

sub _determine_meeting_settings {
    my ( $self, $meeting ) = @_;

    my @settings = qw(
        start_reminder
        participant_digest
        participant_digest_new_participant
        participant_digest_material
        participant_digest_comments
        invite
        add_material
        edit_material
    );

    my $result = {};

    for my $setting ( @settings ) {
        $result->{ $setting } = $self->_get_meeting_permission( $meeting, $setting );
    }

    return $result;
}

sub _store_meeting_settings {
    my ( $self, $meeting, $set_settings ) = @_;

    my @settings = qw(
        start_reminder
        participant_digest
        participant_digest_new_participant
        participant_digest_material
        participant_digest_comments
        invite
        add_material
        edit_material
    );

    my $do_save = 0;

    for my $setting ( @settings ) {
        next unless defined $set_settings->{ $setting };
        $do_save = 1;
        $self->_set_meeting_permission( $meeting, $setting, $set_settings->{ $setting }, { skip_save => 1 } );
    }

    $meeting->save if $do_save;
}

sub _get_note_for_meeting {
    my ( $self, $note, $meeting ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    return Dicole::Utils::Data->get_note( $note, $meeting, { note_field => 'attend_info' } );
}

sub _set_note_for_meeting {
    my ( $self, $note, $value, $meeting, $opts ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    $opts = { skip_save => $opts } unless ref $opts eq 'HASH';
    $opts->{note_field} = 'attend_info';

    return Dicole::Utils::Data->set_note( $note, $value, $meeting, $opts );
}

sub _session_is_secure {
    my ($self) = @_;

    return Dicole::Utils::Session->current_is_secure;
}

sub _get_note_for_meeting_user {
    my ( $self, $note, $event, $user, $euo ) = @_;

    $euo ||= $self->_get_user_meeting_participation_object( $user, $event );

    return Dicole::Utils::Data->get_note( $note, $euo, { note_field => 'attend_info' } );
}

sub _set_note_for_meeting_user {
    my ( $self, $note, $value, $event, $user, $euo, $opts ) = @_;

    $opts = { skip_save => $opts } unless ref $opts eq 'HASH';
    $opts->{note_field} = 'attend_info';

    $euo ||= $self->_get_user_meeting_participation_object( $user, $event );

    return Dicole::Utils::Data->set_note( $note, $value, $euo, $opts );
}

sub _get_note {
    my ($self, $note, $object) = @_;

    return $self->_get_note_for_meeting_user( $note, undef, undef, $object ) if ref( $object ) eq 'OpenInteract2::EventsUser';
    return $self->_get_note_for_meeting( $note, $object ) if ref( $object ) eq 'OpenInteract2::EventsEvent';

    return Dicole::Utils::Data->get_note( $note, $object );
}

sub _set_note {
    my ($self, $note, $new_value, $object, $opt) = @_;

    return $self->_set_note_for_meeting_user( $note, $new_value, undef, undef, $object, $opt ) if ref( $object ) eq 'OpenInteract2::EventsUser';
    return $self->_set_note_for_meeting( $note, $new_value, $object, $opt ) if ref( $object ) eq 'OpenInteract2::EventsEvent';

    return Dicole::Utils::Data->set_note( $note, $new_value, $object, $opt );
}

sub _set_notes {
    my ($self, $values, $object, $opt) = @_;

    return Dicole::Utils::Data->set_notes( $values, $object, $opt );
}

sub _get_id_for_any_participation_object {
    my ( $self, $object ) = @_;

    if ( ref( $object ) =~ /draft/i ) {
        return $object->event_id . ':draft:' . $object->id;
    }
    else {
        return $object->event_id . ':participant:' . $object->id;
    }
}

sub _get_any_participation_object_by_id {
    my ( $self, $id ) = @_;

    my ( $meeting_id, $type, $object_id ) = split /\:/, $id;

    if ( $type eq 'draft' ) {
        my $object = $self->_get_draft_participation_object( $object_id );
        return $object if $object->event_id == $meeting_id;
    }
    elsif ( $type eq 'participant' ) {
        my $object = $self->_get_participation_object( $object_id );
        return $object if $object->event_id == $meeting_id;
    }
    return undef;
}

sub _get_participation_object {
    my ( $self, $id ) = @_;

    return CTX->lookup_object('events_user')->fetch( $id );
}

sub _get_draft_participation_object {
    my ( $self, $id ) = @_;

    return CTX->lookup_object('meetings_draft_participant')->fetch( $id );
}


sub _get_user_meeting_participation_object {
    my ( $self, $user, $event, $uo ) = @_;

    return $uo if $uo;

    my $objects = CTX->lookup_object('events_user')->fetch_group( {
        where => 'event_id = ? AND user_id = ? AND removed_date = 0',
        value => [ $self->_ensure_meeting_id( $event ), Dicole::Utils::User->ensure_id( $user ) ],
    } ) || [];

    return $objects->[0];
}

sub _store_comment_event {
    my ( $self, $meeting, $comment, $object, $action, $params ) = @_;

    my $containers = {
        'OpenInteract2::EventsEvent' => 'note',
        'OpenInteract2::WikiPage' => 'wiki',
        'OpenInteract2::PresentationsPrese' => 'prese',
    };

    my $container = $containers->{ ref( $object ) } || '';

    $params ||= {};
    $params->{event_type} ||= 'meetings_' . $container . '_comment_' . $action;
    $params->{classes} ||= [ 'meetings_comment', 'meetings_' . $container . '_comment' ];

    my $times = { created => $comment->created_date, updated => $comment->updated_date, removed => $comment->removed_date };
    $params->{timestamp} ||= $times->{ $action };

    $params->{data} ||= {};
    $params->{data}->{container_type} = $container;
    $params->{data}->{object_type} = ref( $object );
    $params->{data}->{object_id} = $object->id;
    $params->{data}->{action_type} = $action;
    $params->{data}->{comment_id} = $comment->id;

    return $self->_store_meeting_event( $meeting, $params );
}

sub _store_participant_event {
    my ( $self, $meeting, $po, $action, $params ) = @_;

    $params ||= {};
    $params->{event_type} ||= 'meetings_participant_' . $action;
    $params->{classes} ||= [ 'meetings_participant' ];

    $params->{timestamp} = $po->created_date if $action =~ /created/;

    $params->{secure_tree} ||= [];
    push @{ $params->{secure_tree} }, [ 'u::' . $po->user_id ];

    $params->{data} ||= {};
    $params->{data}->{user_id} = $po->user_id;
    $params->{data}->{action_type} = $action;
    $params->{data}->{po_id} = $po->id;

    return $self->_store_meeting_event( $meeting, $params );
}

sub _store_draft_participant_event {
    my ( $self, $meeting, $dpo, $action, $params ) = @_;

    $params ||= {};
    $params->{event_type} ||= 'meetings_draft_participant_' . $action;
    $params->{classes} ||= [ 'meetings_draft_participant', 'meetings_participant' ];

    $params->{timestamp} = $dpo->created_date if $action =~ /created/;

    $params->{secure_tree} ||= [];

    $params->{data} ||= {};
    $params->{data}->{action_type} = $action;
    $params->{data}->{dpo_id} = $dpo->id;

    return $self->_store_meeting_event( $meeting, $params );
}

sub _store_date_proposal_event {
    my ( $self, $meeting, $proposal, $action, $params ) = @_;

    $params ||= {};
    $params->{event_type} ||= 'meetings_date_proposal_' . $action;
    $params->{classes} ||= [ 'meetings_date_proposal' ];

    $params->{timestamp} = time;

    $params->{secure_tree} ||= [];

    $params->{data} ||= {};
    $params->{data}->{action_type} = $action;
    $params->{data}->{proposal_id} = $proposal->id;

    return $self->_store_meeting_event( $meeting, $params );
}

sub _store_matchmaker_lock_event {
    my ( $self, $matchmaker, $lock, $action, $params ) = @_;

    $params ||= {};
    $params->{event_type} ||= 'meetings_matchmaker_lock_' . $action;
    $params->{classes} ||= [ 'meetings_matchmaker_lock' ];

    $params->{timestamp} = time;

    $params->{secure_tree} ||= [];

    $params->{data} ||= {};
    $params->{data}->{action_type} = $action;
    $params->{data}->{lock_id} = $lock->id;

    return $self->_store_matchmaker_event( $matchmaker, $params );
}

sub _store_material_event {
    my ( $self, $meeting, $object, $action, $params ) = @_;

    my $containers = {
        'OpenInteract2::WikiPage' => 'wiki',
        'OpenInteract2::PresentationsPrese' => 'prese',
    };

    my $container = $containers->{ ref( $object ) } || '';

    $params ||= {};
    $params->{event_type} ||= 'meetings_' . $container . '_material_' . $action;
    $params->{classes} ||= [ 'meetings_material', 'meetings_' . $container . '_material' ];

    # TODO: exact timestamp for creates? needed?

    $params->{data} ||= {};
    $params->{data}->{container_type} = $container;
    $params->{data}->{action_type} = $action;
    $params->{data}->{object_type} = ref( $object );
    $params->{data}->{object_id} = $object->id;

    $self->_record_meeting_material_notification( $meeting, $object, $params );

    return $self->_store_meeting_event( $meeting, $params );
}

sub _gather_meeting_event_info {
    my ( $self, $meeting ) = @_;

    my $lcp = $self->_gather_meeting_live_conferencing_params( $meeting );

    return {
        title => $self->_meeting_title_string( $meeting ),
        location => $self->_meeting_location_string( $meeting ),
        begin_epoch => $meeting->begin_date,
        end_epoch => $meeting->end_date,
        live_conferencing_params => $lcp,
    };
}

sub _get_meeting_uid {
    my ( $self, $event, $no_fill ) = @_;

    my $uid = $self->_get_note_for_meeting( uid => $event );
    return $uid if $uid;

    $uid = Digest::MD5::md5_hex( 'meeting_'  . $event->id ) . '@meetin.gs';
    $self->_set_note_for_meeting( uid => $uid => $event ) unless $no_fill;

    return $uid;
}

sub _get_partner_id_for_meeting {
    my ( $self, $meeting ) = @_;

    # NOTE: old meetings might have only created_by_partner_id
    return $self->_get_note_for_meeting( owned_by_partner_id => $meeting) ||
        $self->_get_note_for_meeting( created_by_partner_id => $meeting ) || 0;
}

sub _get_partner_for_meeting {
    my ( $self, $meeting ) = @_;

    return $self->PARTNERS_BY_ID->{ $self->_get_partner_id_for_meeting( $meeting ) };
}

sub _user_can_create_meeting_for_partner {
    my ( $self, $user, $partner ) = @_;

    return 1;
}


sub _create_meeting_partner_merge_verification_checksum_for_user {
    my ( $self, $meeting, $user ) = @_;

    my $meeting_id = $self->_ensure_meeting_id( $meeting );
    my $user_id = Dicole::Utils::User->ensure_id( $user );

    return  $meeting_id . '_' . $user_id . '_' . $self->_create_invalidable_parameter_digest_for_user( $meeting_id, $user );
}

sub _create_temp_account_email_verification_checksum_for_user {
    my ( $self, $email_object_id, $user ) = @_;

    my $a = $self->_create_invalidable_parameter_digest_for_user( 'temp_email_' . $email_object_id, $user );

    return $a;
}

sub _create_temp_meeting_verification_checksum_for_user {
    my ( $self, $meeting, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( 'temp_meeting_' . $meeting->id, $user );
}

sub _create_partner_authentication_checksum_for_user {
    my ( $self, $partner, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( $partner->api_key, $user );
}

sub _create_partner_authorization_key_for_user {
    my ( $self, $partner, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( $partner->id, $user );
}

sub _generate_meeting_image_digest_for_user {
    my ( $self, $meeting_id, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( 'meeting_image_' . $meeting_id, $user );
}

sub _generate_meeting_ics_digest_for_user {
    my ( $self, $meeting_id, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( 'meeting_ics_' . $meeting_id, $user );
}

sub _generate_meeting_material_digest_for_user {
    my ( $self, $meeting, $material, $user ) = @_;

    my $meeting_id = $self->_ensure_meeting_id( $meeting );
    my $material_id = ref( $material ) ? $material->id : $material;
    $user = Dicole::Utils::User->ensure_object( $user );

    return $user->id . '_' . $self->_create_invalidable_parameter_digest_for_user( 'meeting_material_' . $meeting_id . '_' . $material_id, $user );
}

sub _generate_header_image_digest_for_user {
    my ( $self, $user ) = @_;

    return $self->_create_invalidable_parameter_digest_for_user( 'header_image', $user );
}

sub _create_invalidable_parameter_digest_for_user {
    my ( $self, $params, $user ) = @_;

    my $is = Dicole::Utils::User->authorization_key_invalidation_secret( $user );

    return $self->_digest_string( $is . $params );
}

sub _digest_string {
    my ( $self, $string ) = @_;

    my $digest = Digest::SHA::sha1_base64( $string );
    $digest =~ tr/\+\//-_/;

    return $digest;
}

sub _partner_can_log_user_in {
    my ( $self, $partner, $target_user ) = @_;

    return 0 unless $partner && $target_user;

    return $self->_get_note_for_user( "login_allowed_for_partner_" . $partner->id => $target_user, $partner->domain_id ) ? 1 : 0;
}

sub _fetch_allowed_partners_for_user {
    my ( $self, $user ) = @_;

    my $allowed_partners = [];

    for my $partner ( @{ $self->PARTNERS } ) {
        push @$allowed_partners, $partner if $self->_partner_can_log_user_in( $partner, $user );
    }

    return $allowed_partners;
}

sub _fetch_domain_meeting_by_uid {
    my ( $self, $domain_id, $uid, $partner ) = @_;

    my $events = $self->_fetch_meetings( {
        where => 'attend_info LIKE ? AND domain_id = ?',
        value => [ '%' . $uid . '%', $domain_id ],
    } );

    for my $event ( @$events ) {
        if ($self->_get_meeting_uid( $event ) eq $uid ) {
            unless ( $partner && ! $self->_get_partner_id_for_meeting( $event ) == $partner->id ) {
                return $event;
            }
        }
    }

    return;
}

sub _fetch_domain_meeting_by_full_external_id {
    my ($self, $domain_id, $external_id ) = @_;

    my $events = $self->_fetch_meetings( {
        where => 'attend_info LIKE ? AND domain_id = ?',
        value => [ '%' . $external_id . '%', $domain_id ],
    } );

    for my $event ( @$events ) {
        my $full_external_id = $self->_get_note_for_meeting(external_id => $event);
        if ( $full_external_id eq $external_id) {
            return $event;
        };
    }

    return;
}

sub _get_meeting_external_id {
    my ($self, $meeting) = @_;

    my $db_id = $self->_get_note_for_meeting(external_id => $meeting);

    my ( $db_partner_id, $external_id ) = $db_id =~ /(\d+)\:(.*)/;

    return $external_id;
}

sub _get_meeting_cloaking_hash {
    my ( $self, $meeting ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    return substr( Digest::MD5::md5_hex( CTX->server_config->{dicole}->{meetings_general_secret} . $meeting->id ), 0, 10 );
}

sub _send_meeting_invite_mail_to_user {
    my ( $self, %p ) = @_;

    my $user = Dicole::Utils::User->ensure_object( $p{user} );
    my $event = $self->_ensure_meeting_object( $p{event} || $p{meeting} || $p{meeting_id} );

    my $extra_params = {
        user_has_joined => $p{user_has_joined},
        %{ $p{extra_mail_template_params} || {} },
    };

    my $mail_params = $self->_gather_user_meeting_invite_email_params( $user, $event, $extra_params );

    $self->_send_themed_mail( %$mail_params );
}

sub _gather_user_meeting_invite_email_params {
    my ( $self, $user, $meeting, $additional_parameters, $po ) = @_;

    $po ||= $self->_get_user_meeting_participation_object( $user, $meeting );

    my $from_user_id = $po->creator_id;
    $from_user_id ||= $meeting->creator_id;

    my $requester_id = $self->_get_note_for_meeting( matchmaking_requester_id => $meeting );
    my $lock_creator_id = $self->_get_note_for_meeting( matchmaking_lock_creator_id => $meeting );

    unless ( $lock_creator_id && $lock_creator_id == $meeting->creator_id ) {
        $from_user_id = $requester_id if $requester_id && $user->id == $meeting->creator_id;
    }

    my $from_user = $from_user_id ? Dicole::Utils::User->ensure_object( $from_user_id ) : undef;
    my $greeting_message_text = $self->_get_note( greeting_message => $po ) || '';
    my $greeting_message_html = Dicole::Utils::HTML->text_to_html( $greeting_message_text );
    my $greeting_subject = $self->_get_note( greeting_subject => $po ) || '';

    my $meeting_image = $self->_generate_meeting_image_url_for_user( $meeting, $user );
    my $agenda_parameters = $self->_fetch_processed_meeting_agenda_parameters( $meeting );
    my $rsvp_required_parameters = $self->_meeting_user_rsvp_required_parameters( $meeting, $user );

    my $params = {
        meeting_image                => $meeting_image,
        inviting_user_name           => $from_user ? Dicole::Utils::User->name( $from_user, '' ) : '',
        inviting_user_first_name     => $from_user ? Dicole::Utils::User->first_name( $from_user, '' ) : '',
        greeting_message_text        => $greeting_message_text,
        greeting_message_html        => $greeting_message_html,

        %{ $agenda_parameters || {} },
        comment_now_url => $self->_generate_complete_meeting_user_material_url_for_selector_url(
            $meeting, $user, $agenda_parameters->{agenda_selector}
        ),

        open_scheduling_option_count => 0,
        open_scheduling_options      => [],

        %$rsvp_required_parameters,
        %{ $additional_parameters || {} },
    };

    my $root_params = {
        from_user => $from_user || undef,
        override_subject => $greeting_subject || undef,
    };

    return $self->_get_meeting_user_template_mail_params(
        $meeting, $user, 'visitor_invite', $params, $root_params
    );

}

sub _meeting_user_rsvp_required_parameters {
    my ( $self, $meeting, $user, $euo ) = @_;

    return {} unless $meeting->begin_date;

    $euo ||= $self->_fetch_meeting_participant_object_for_user( $meeting, $user );
    return {} unless $self->_get_note_for_meeting_user( rsvp_required => $meeting, $user, $euo );

    my $answer = $self->_get_note_for_meeting_user( rsvp => $meeting, $user, $euo );
    return {} if grep { $answer eq $_ } ( qw( yes no ) );

    my $required_user_id = $self->_get_note_for_meeting_user( rsvp_required_by_user_id => $meeting, $user, $euo );
    $required_user_id ||= $euo->creator_id;

    my $required_user = $required_user_id ? Dicole::Utils::User->name( $required_user_id ) : '';

    return {
        rsvp_required => 1,
        rsvp_required_by => $required_user,
    };
}

sub _fetch_meeting_schedulings {
    my ( $self, $meeting ) = @_;

    return CTX->lookup_object('meetings_scheduling')->fetch_group({
        where => 'meeting_id = ?',
        value => [ $self->_ensure_meeting_id( $meeting ) ],
    });
}

sub _set_meeting_current_scheduling {
    my ( $self, $meeting, $scheduling ) = @_;

    my $scheduling_id = $self->_ensure_object_id( $scheduling || 0 );
    $meeting ||= $self->_ensure_object_of_type( meetings_scheduling => $scheduling )->meeting_id;
    $meeting = $self->_ensure_meeting_object( $meeting );

    my $old = $self->_get_note_for_meeting( current_scheduling_id => $meeting );
    $self->_set_note_for_meeting( previous_scheduling_id => $old, $meeting, { skip_save => 1 } ) if $old;
    $self->_set_note_for_meeting( current_scheduling_id => $scheduling_id, $meeting );
}

sub _meeting_has_swipetomeet {
    my ( $self, $meeting ) = @_;

    return 0 unless $meeting;

    my $from_swipetomeet = $self->_get_note_for_meeting( current_scheduling_id => $meeting ) ? 1 : 0;
    $from_swipetomeet ||= $self->_get_note_for_meeting( previous_scheduling_id => $meeting ) ? 1 : 0;

    return $from_swipetomeet;
}

sub _send_meeting_ical_request_mail {
    my ( $self, $meeting, $user, $params ) = @_;

    my $swipetomeet = $self->_meeting_has_swipetomeet( $meeting );

    my $meeting_url = $swipetomeet ?
        $self->_get_new_mobile_redirect_url_for_user( { redirect_to_meeting => $meeting->id, utm_source => 'ics_email' }, $user, $meeting->domain_id )
        :
        $self->_get_meeting_user_url( $meeting, $user );

    my $meeting_details = {
        domain_id => $meeting->domain_id,
        group_id => $meeting->group_id,
        partner_id => $self->_get_partner_id_for_meeting( $meeting ),

        meeting_id => $meeting->id,
        meeting_object => $meeting,
        current_scheduling_id => $self->_get_note( current_scheduling_id => $meeting ),

        ics => ( $params->{type} && $params->{type} eq 'cancel' ) ? $self->_ics_cancel_for_meeting( $meeting, $user ) : $self->_ics_request_for_meeting( $meeting, $user, undef, undef, $params ),
        title => $self->_meeting_title_string( $meeting ),
        domain_host => $self->_get_host_for_meeting( $meeting, 443 ),

        user_url => $meeting_url,

        from_swipetomeet => $swipetomeet,
    };

    return $self->_send_ical_request_mail( $user, $meeting_details, $params );
}

sub _send_matchmaker_lock_ical_request_email {
    my ( $self, $lock, $user, $meeting ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user || $lock->creator_id || $lock->expected_confirmer_id );
    $meeting ||= $self->_ensure_meetings_object( $lock->created_meeting_id );

    my $meeting_details = {
        domain_id => $meeting->domain_id,
        group_id => $meeting->group_id,
        partner_id => $self->_get_partner_id_for_meeting( $meeting ),

        meeting_id => $meeting->id,
        meeting_object => $meeting,
        current_scheduling_id => $self->_get_note( current_scheduling_id => $meeting ),

        ics => $self->_ics_request_for_vevent( $self->_ics_vevent_for_matchmaker_lock( $lock, $user, $meeting ) ),
        title => $lock->title . ' ' . $self->_nmsg( '(tentative)' ),
        domain_host => $self->_get_host_for_meeting( $meeting, 443 ),
        from_swipetomeet => $self->_meeting_has_swipetomeet( $meeting ),
    };

    return $self->_send_ical_request_mail( $user, $meeting_details, { type => 'tentative_reminder' } );

}

sub _send_ical_request_mail {
    my ( $self, $user, $meeting_details, $params ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    return if $self->_get_note_for_user( meetings_disable_ical_emails => $user, $meeting_details->{domain_id} ) && ! $self->_get_note_for_user( 'meetings_never_disable_ical_emails', $user, $meeting_details->{domain_id} );

    my $extra_params = {
        type => $params->{type},
    };

    if ( $params->{type} eq 'invitation' ) {
        $extra_params->{invitation_message} = $params->{invitation_message};
        $extra_params->{from_user_name} = Dicole::Utils::User->name( $params->{from_user} );
    }

    my $oemail = 'assistant@' . ( CTX->server_config->{dicole}->{limited_email_gateway} || CTX->server_config->{dicole}->{default_email_gateway} );

    my $disable_url = Dicole::URL->from_parts( domain_id => $meeting_details->{domain_id}, action => 'meetings_global', task => 'disable_ical_emails', target_id => 0 );
    $disable_url = $self->_generate_authorized_uri_for_user( $meeting_details->{domain_host} . $disable_url, $user, $meeting_details->{domain_id} );

    my $from_name = $meeting_details->{from_swipetomeet} ? 'SwipeToMeet' : 'Meetin.gs Assistant';
    my $from_email = $from_name .' <'.$oemail.'>';

    my $template_params = {
        meeting_title => $meeting_details->{title},
        from_swipetomeet => $meeting_details->{from_swipetomeet},
        meeting_url => $meeting_details->{user_url},
        disable_url => $disable_url,
        server_host => $meeting_details->{domain_host},
        %$extra_params,
    };

    my $result = Dicole::Utils::Mail->send_nlocalized_template_mail(
        disable_html => 1,

        user => $user,
        ics => $meeting_details->{ics},
        from => $from_email,
        reply_to => $from_email,

        domain_id => $meeting_details->{domain_id},
        partner_id =>  $meeting_details->{partner_id},
        group_id => $meeting_details->{group_id},

        template_key_base => 'meetings_ical_nofity_email',
        template_params => $template_params,
    );

    my $result_params = eval { { result_sent_date => ''.$result->sent_date, result_subject => ''.$result->subject } };
    $result_params ||= { result_error => Data::Dumper::Dumper( $result ) };

    my $log_data = {
        type => 'meetings_ical_nofity_email',
        snippet => eval { ''.$result->subject } || '[failed]',
        template_params => $template_params,
        invitation_type => $params->{type} || '',
        meeting_id => $meeting_details->{meeting_id} || 0,
        scheduling_id => $meeting_details->{current_scheduling_id} || 0,
        %$result_params,
    };

    $self->_record_user_contact_log( $user, 'email', $user->email || '', $from_email, $log_data );

    if ( $params->{send_copy_to} && $meeting_details->{meeting_object} ) {
        my $copy_params = { %{ $template_params } };

        delete $copy_params->{disable_url};
        $copy_params->{meeting_url} = $self->_get_meeting_enter_url( $meeting_details->{meeting_object}, $meeting_details->{domain_host} );

        my $copy_result = Dicole::Utils::Mail->send_nlocalized_template_mail(
            disable_html => 1,

            lang => $user->language,
            to => $params->{send_copy_to},
            ics => $meeting_details->{ics},
            from => $from_email,
            reply_to => $from_email,

            domain_id => $meeting_details->{domain_id},
            partner_id =>  $meeting_details->{partner_id},
            group_id => $meeting_details->{group_id},

            template_key_base => 'meetings_ical_nofity_email',
            template_params => $copy_params,
        );

        # TODO record anon contact log
    }

    return $result;
}

sub _agenda_page_validator {
    my ( $self, $page_info ) = @_;
    return 1 if $page_info->{title} =~ /agenda/i;
    return 0;
}

sub _action_points_page_validator {
    my ( $self, $page_info ) = @_;
    return 1 if $page_info->{title} =~ /action\s*points|notes/i;
    return 0;
}

sub _fetch_meeting_agenda_page {
    my ( $self, $meeting, $pages ) = @_;

    return $self->_fetch_validated_meeting_page(
        $meeting, $pages, sub { return $self->_agenda_page_validator( @_ ) }
    );
}

sub _fetch_meeting_action_points_page {
    my ( $self, $meeting, $pages ) = @_;

    return $self->_fetch_validated_meeting_page(
        $meeting, $pages, sub { return $self->_action_points_page_validator( @_ ) }
    );
}

sub _fetch_processed_meeting_agenda_parameters {
    my ( $self, $meeting, $pages ) = @_;

    my $params = $self->_fetch_validated_and_processed_meeting_page_parameters(
        $meeting, $pages, sub { return $self->_agenda_page_validator( @_ ) }
    );

    if ( $params ) {
        $params = { map { 'agenda_' . $_ => $params->{ $_ } } qw( title text html selector page_id ) };
    }

    return $params;
}

sub _fetch_processed_meeting_action_points_parameters {
    my ( $self, $meeting, $pages ) = @_;

    my $params = $self->_fetch_validated_and_processed_meeting_page_parameters(
        $meeting, $pages, sub { return $self->_action_points_page_validator( @_ ) }
    );

    if ( $params ) {
        $params = { map { 'action_points_' . $_ => $params->{ $_ } } qw( title text html selector page_id ) };
    }

    return $params;
}

sub _fetch_validated_and_processed_meeting_page_parameters {
    my ( $self, $meeting, $pages, $validator ) = @_;

    my ( $content, $title, $selector, $page_id ) = $self->_fetch_validated_meeting_page_content_and_title_and_selector( $meeting, $pages, $validator );

    return () unless $selector;

    my $return = {
        title => $title,
        selector => $selector,
        page_id => $page_id,
    };

    if ( $content ) {
        my $styles = $self->_gather_page_styles_for_meeting( $meeting );
        $return->{html} = Dicole::Utils::HTML->set_inline_style_attributes( $content, $styles );
        $return->{text} = Dicole::Utils::HTML->html_to_text( $content );
    }

    return $return;
}

sub _fetch_validated_meeting_page {
    my ( $self, $meeting, $pages, $validator ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $pages ||= $self->_events_api( gather_pages_data => { event => $meeting } );
    for my $page ( @$pages ) {
        next unless $validator->( $page );
        return CTX->lookup_object('wiki_page')->fetch( $page->{page_id} );
    }

    return ();
}

sub _fetch_validated_meeting_page_content_and_title_and_selector {
    my ( $self, $meeting, $pages, $validator ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $pages ||= $self->_events_api( gather_pages_data => { event => $meeting } );

    my @first_hit = ();

    for my $page ( @$pages ) {
        next unless $validator->( $page );

        my $bits = $self->_fetch_meeting_page_content_bits( $meeting, $page );
        my $selector = $self->_generate_meeting_material_wiki_url_from_data( $meeting, $page );

        if ( $bits ) {
            return ( $bits, $page->{title}, $selector, $page->{page_id} );
        }
        elsif ( ! @first_hit ) {
            @first_hit = ( $bits, $page->{title}, $selector, $page->{page_id} );
        }
    }

    return @first_hit;
}

sub _copy_material_from_meeting_to_meeting_by_user {
    my ( $self, $material_id, $material_type, $from_meeting, $to_meeting, $user, $params ) = @_;

    $from_meeting = $self->_ensure_meeting_object( $from_meeting );
    $to_meeting = $self->_ensure_meeting_object( $to_meeting );

    if ( lc ( $material_type ) eq 'page' ) {
        my $from_page = CTX->lookup_object('wiki_page')->fetch( $material_id );

        # TODO: check that the material actually belongs to the event ;)
        my ( $readable_title ) = $from_page->readable_title =~ /(.*) \(\#meeting_/;

        my $content = $from_page->last_content_id_wiki_content;
        my $page = CTX->lookup_action('wiki_api')->e( create_page => {
                group_id => $to_meeting->group_id,

                readable_title => $params->{override_name} || $readable_title,
                suffix_tag => $to_meeting->sos_med_tag,

                content => $content->content,
                prefilled_tags => $to_meeting->sos_med_tag,

                skip_starting_page_proposal => 1,

                $params->{override_created_date} ? ( created_date => $params->{override_created_date} ) : (),
            } );

        if ( $page && ! $params->{skip_event} ) {
            $self->_store_material_event( $to_meeting, $page, 'created' );
        }

        return $page;
    }
    elsif ( lc ( $material_type ) eq 'media' ) {
        my $from_prese = CTX->lookup_object('presentations_prese')->fetch( $material_id );

        # TODO: check that the material actually belongs to the event ;)

        my $prese = $self->_add_meeting_prese_from_prese( $to_meeting, $from_prese, {
            creator => $user,
            name => $params->{override_name},
            created_date => $params->{override_created_date},
        } );
    }

    return undef;
}

sub _add_meeting_prese_from_prese {
    my ( $self, $meeting, $prese, $params ) = @_;

    $params->{name} ||= $prese->name;

    return $self->_add_meeting_prese_from_attachment( $meeting, $prese->attachment_id, $params );
}

sub _add_meeting_prese_from_attachment {
    my ( $self, $meeting, $attachment, $params ) = @_;

    my $a = $attachment;

    $a = CTX->lookup_action('attachments_api')->e( get_object => { attachment_id => $a } ) unless ! $a || ref ( $a );

    my $fh = $a ? CTX->lookup_action('attachments_api')->e( filehandle => { attachment => $a } ) : undef;

    $params->{attachment_filename} = $a->filename;
    $params->{name} ||= $a->filename;

    $params->{attachment_filehandle} = $fh;

    return $self->_add_meeting_prese( $meeting, $params );
}

sub _add_meeting_prese {
    my ( $self, $meeting, $params ) = @_;

    my $creator = $params->{creator} || $params->{creator_id};
    my $creator_id = $creator ? Dicole::Utils::User->ensure_id( $creator ) : 0;

    my $prese = CTX->lookup_action('presentations_api')->e( create => {
            domain_id => $meeting->domain_id,
            group_id => $meeting->group_id,
            creator_id => $creator_id,
            title => $params->{name},
            attachment_filename => $params->{attachment_filename},
            attachment_filehandle => $params->{attachment_filehandle},
            embed => $params->{embed} || '',,
            tags => [ $meeting->sos_med_tag ],
            $params->{created_date} ? ( created_date => $params->{created_date} ) : (),
        } );

    if ( $prese && ! $params->{skip_event}  ) {
        $self->_store_material_event( $meeting, $prese, 'created' );
    }

    return $prese;
}

sub _gather_page_styles_for_meeting {
    my ( $self, $meeting ) = @_;
     # TODO customize 'a' color with theme color

    $meeting = $self->_ensure_meeting_object( $meeting );

    return {
        p => 'line-height:25px; font-size:15px; color:#4a4a4a; margin-top:15px; margin-bottom:15px; margin-left:17px; margin-right:17px; font-family:Arial,Verdana,sans-serif;',
        ul => 'list-style: disc outside none; line-height:25px; font-size:15px; color:#4a4a4a; margin-top:15px; margin-bottom:15px; margin-left:17px; margin-right:17px; font-family:Arial,Verdana,sans-serif; padding-left:16px;',
        ol => 'list-style: decimal outside none; line-height:25px; font-size:15px; color:#4a4a4a; margin-top:15px; margin-bottom:15px; margin-left:17px; margin-right:17px; font-family:Arial,Verdana,sans-serif; padding-left:16px;',
        h1 => 'line-height:20px; font-size:16px; font-weight:bold; margin-top:5px; margin-left:17px; margin-right:17px; margin-bottom:5px; color:#4a4a4a; font-family:Arial,Verdana,sans-serif;',
        h2 => 'line-height:18px; font-size:15px; font-weight:bold; margin-top:5px; margin-left:17px; margin-right:17px; margin-bottom:5px; color:#4a4a4a; font-family:Arial,Verdana,sans-serif;',
        h3 => 'line-height:16px; font-size:14px; font-weight:bold; margin-top:5px; margin-left:17px; margin-right:17px; margin-bottom:5px; color:#4a4a4a; font-family:Arial,Verdana,sans-serif;',
        h4 => 'line-height:14px; font-size:13px; font-weight:bold; margin-top:5px; margin-left:17px; margin-right:17px; margin-bottom:5px; color:#4a4a4a; font-family:Arial,Verdana,sans-serif;',
        a => 'font-family:Arial,Verdana,sans-serif;text-decoration:underline;',
    };
}

sub _send_beta_invite_mail_to_user {
    my ( $self, %p ) = @_;

    my $from_user = $p{from_user} ? Dicole::Utils::User->ensure_object( $p{from_user} ) : undef;
    my $user = Dicole::Utils::User->ensure_object( $p{user} );

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $p{domain_id} );
    my $gid = $p{group_id} || eval{ CTX->controller->initial_action->param('target_group_id') } || 0;
    my $domain_host = $p{domain_host} || $self->_get_host_for_user( $user, $domain_id, 443 );
    $domain_host =~ s/^http:/https:/;

    my $greeting_message_text = $p{greeting_message};
    my $greeting_message_html = Dicole::Utils::HTML->text_to_html( $greeting_message_text );
    my $greeting_subject = $p{greeting_subject};

    my $url = $domain_host . $self->derive_url(
        action => 'meetings',
        task => 'signup',
        target => 0,
        additional => [],
        params => {
            invited_by => $from_user ? $from_user->id : '-1',
            dic => $self->_user_permanent_dic( $user, $domain_id ),
        },
    );

    my $template_key_base = $p{template_key_base} || 'meetings_beta_invite';

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $domain_id,
        partner_id => $self->param('partner_id'),
        group_id => $gid,

        $from_user ? ( reply_to => Dicole::Utils::User->email_with_name( $from_user ) ) : (),

        template_key_base => $template_key_base,
        override_subject => $greeting_subject,
        template_params => {
            inviting_user_name => $from_user ? Dicole::Utils::User->name( $from_user, '' ) : '',
            inviting_user_first_name => $from_user ? Dicole::Utils::User->first_name( $from_user, '' ) : '',
            user_name => Dicole::Utils::User->name( $user ),
            register_url => $url,
            greeting_message_text => $greeting_message_text,
            greeting_message_html => $greeting_message_html,
        },
    );

    $self->_set_note_for_user( first_beta_invite_sent => time, $user, $domain_id )
        unless $self->_get_note_for_user( first_beta_invite_sent => $user, $domain_id );
}

sub _send_meeting_created_email {
    my ( $self, $meeting, $user ) = @_;

    return unless $user->email;

    my $params = { new_user => $self->_user_is_new_user( $user, $meeting->domain_id ) };
    $self->_send_meeting_user_template_mail( $meeting, $user, 'meeting_created', $params );
}

sub _get_proposal_info {
    my ( $self, $proposal, $user ) = @_;

    my $timestring = $self->_form_timespan_string_from_epochs( $proposal->begin_date, $proposal->end_date, $user );
    my ( $dp, $tp, $tzp ) = $self->_form_timespan_parts_from_epochs_for_user( $proposal->begin_date, $proposal->end_date, $user );

    return {
        id => $proposal->id,
        timestring => $timestring,
        datepartstring => $dp,
        timepartstring => $tp,
        timezonepartstring => $tzp,
        epoch => $proposal->begin_date,
    };
}

sub _get_participant_info {
    my ( $self, $user ) = @_;

    return { type => 'normal', id => Dicole::Utils::User->ensure_id( $user ), name => Dicole::Utils::User->name( $user ) };
}

sub _get_draft_participant_info {
    my ( $self, $object ) = @_;

    return { type => 'draft', id => 'draft:' . $object->id, name => $self->_get_note( name => $object ) || $self->_get_note( email => $object ) };
}

sub _gather_meeting_participant_info {
    my ( $self, $event, $users ) = @_;

    $users ||= $self->_fetch_meeting_participant_users( $event );

    return join ", ", ( map { Dicole::Utils::User->name( $_ ) } @$users );
}

sub _meeting_other_participant_names_string_for_user {
    my ( $self, $meeting, $user, $users ) = @_;

    $users ||= $self->_fetch_meeting_participant_users( $meeting );

    my @names = map { $_->id == $user->id ? () : Dicole::Utils::User->name( $_ ) } @$users;

    my $last = pop @names;
    if ( @names ) {
        my $other = join ", ", @names;
        return $self->_ncmsg('%1$s and %2$s', { user => $user }, [ join( ", ", @names ), $last ] );
    }
    else {
        return $last;
    }
}

sub _form_meeting_time_string {
    my ( $self, $event, $user ) = @_;

    return '' unless $event->begin_date;

    return $self->_form_times_string_for_epochs( $event->begin_date, $event->end_date, $user->timezone, $user->language );
}

sub _form_times_string_for_epochs_and_user {
    my ( $self, $begin_epoch, $end_epoch, $user ) = @_;
    $user = Dicole::Utils::User->ensure_object( $user );

    return $self->_form_times_string_for_epochs( $begin_epoch, $end_epoch, $user->timezone, $user->language );
}

sub _form_times_string_for_epochs {
    my ( $self, $begin_epoch, $end_epoch, $timezone, $lang ) = @_;

    $lang ||= 'en';

    my $bdt = Dicole::Utils::Date->epoch_to_datetime( $begin_epoch, $timezone, $lang );
    my $bdnt = Dicole::Utils::Date->epoch_to_date_and_time_strings( $begin_epoch, $timezone, $lang, ( $lang eq 'en' ) ? 'ampm' : '24h' );
    my $ednt = Dicole::Utils::Date->epoch_to_date_and_time_strings( $end_epoch, $timezone, $lang, ( $lang eq 'en' ) ? 'ampm' : '24h' );

    my $tzinfo = Dicole::Utils::Date->timezone_info( $timezone );

    my $day = $bdt->day;
    my $month = ucfirst( $bdt->month_abbr );
    my $wd = ucfirst( $bdt->day_abbr );

    my $date = "$wd $day. $month";
    if ( $lang eq 'en' ) {
        my $ordinal_day = [ qw( th st nd rd th th th th th th ) ]->[ $day % 10 ];
        $ordinal_day = 'th' if $day == 11 || $day == 12;
        $date = "$wd $month $day$ordinal_day";
    }

    return $date . ', ' .
        ( $end_epoch ? $bdnt->[1] . '-' . $ednt->[1] : $bdnt->[1] ) .
        ' (' . $tzinfo->{offset_string} . ')';
}

sub _time_string_from_begin_params {
    my ( $self ) = @_;

    my $time_hours = CTX->request->param('begin_time_hours');
    my $time_minutes = CTX->request->param('begin_time_minutes');
    my $time_ampm = CTX->request->param('begin_time_ampm');

    if ( $time_hours =~ /\d+\s*[ap]m/i ) {
        ( $time_hours, $time_ampm ) = $time_hours =~ /(\d+)\s*([ap]m)/i;
    }

    my $time_string = $time_hours . ':' . $time_minutes;
    $time_string .= ' ' . $time_ampm if $time_ampm;

    return $time_string;
}

# needs: event_type
# can: classes []
# can: topics []
# can: timestamp (epoch)
# can: author (id)
# can: data {}

sub _store_meeting_event {
    my ( $self, $meeting, $params ) = @_;

    $params->{classes} ||= [];
    push @{ $params->{classes} }, 'meetings';

    $params->{topics} ||= [];
    push @{ $params->{topics} }, 'meeting:' . $meeting->id;

    $params->{target_user} = 0;
    $params->{target_group} = $meeting->group_id;
    $params->{target_domain} = $meeting->domain_id;

    $params->{secure_tree} ||= [];

    push @{ $params->{secure_tree} },
        $self->_meeting_is_sponsored($meeting)
            ? ( [ 'sm::' . $meeting->id ], [ 'sg::' . $meeting->group_id ] )
            : ( [  'm::' . $meeting->id ], [  'g::' . $meeting->group_id ] );

    $params->{data} ||= {};
    $params->{data}->{meeting_id} = $meeting->id;

    $self->_record_meeting_notification( $meeting, $params ) unless $params->{skip_notification};

    CTX->lookup_action('event_source_api')->e( add_event => $params );
}

sub _store_matchmaker_event {
    my ( $self, $matchmaker, $params ) = @_;

    $params->{classes} ||= [];
    push @{ $params->{classes} }, 'meetings_matchmaker';

    $params->{topics} ||= [];
    push @{ $params->{topics} }, 'meetings_matchmaker:' . $matchmaker->id;

    if ( $matchmaker->matchmaking_event_id ) {
        push @{ $params->{classes} }, 'meetings_matchmaking_event';
        push @{ $params->{topics} }, 'meetings_matchmaking_event:' . $matchmaker->matchmaking_event_id;
    }

    $params->{target_user} = 0;
    $params->{target_group} = 0;
    $params->{target_domain} = $matchmaker->domain_id;

    $params->{secure_tree} ||= [];

    push @{ $params->{secure_tree} }, ( ['p'] );

    $params->{data} ||= {};
    $params->{data}->{matchmaker_id} = $matchmaker->id;

    $self->_record_matchmaker_notification( $matchmaker, $params );

    CTX->lookup_action('event_source_api')->e( add_event => $params );
}


sub _record_notification_for_user {
    my ( $self, $params, $user_id ) = @_;

    my $p = {
        record_for_user_id => $user_id,
        date => $params->{date},
        type => $params->{type},
        data => $params->{data}
    };

    Dicole::Utils::Gearman->dispatch_task( record_notification_for_user => $p );
}

sub _record_notification {
    my ( $self, %params ) = @_;

    $params{date} ||= time;

    $params{data} ||= {};
    $params{data}{author_id} //= $self->_determine_author_id( $params{event_params} );

    if ( $params{user_id} ) {
        $self->_record_notification_for_user( \%params, $params{user_id} );
    }
    else {
        Dicole::Utils::Gearman->dispatch_task( record_notification_for_relevant_users => {
            skip_user_id => $params{skip_user_id},
            date => $params{date},
            type => $params{type},
            data => $params{data}
        } );
    }
}

sub _record_meeting_material_notification {
    my ( $self, $meeting, $material, $params ) = @_;

    if ( $params->{event_type} eq 'meetings_wiki_material_created' || $params->{event_type} eq 'meetings_prese_material_created' ) {
        $self->_record_notification(
            event_params => $params,
            type => 'new_material',
            data => {
                meeting_id => $meeting->id,
                material_id => $self->_form_meeting_material_id( $meeting, $material ),
            },
        );
    }
}

sub _record_meeting_notification {
    my ( $self, $meeting, $params ) = @_;

    my %class_lookup = map { $_ => 1 } @{ $params->{classes} || [] };

    if ( $params->{event_type} eq 'meetings_meeting_changed' ) {
        if ( $params->{data}->{old_info}->{begin_epoch} != $params->{data}->{new_info}->{begin_epoch} || $params->{data}->{old_info}->{end_epoch} != $params->{data}->{new_info}->{end_epoch} ) {
            $self->_record_notification(
                event_params => $params,
                type => $params->{data}->{old_info}->{begin_epoch} ? 'new_meeting_date' : 'decided_meeting_date',
                data => {
                    meeting_id => $meeting->id,
                },
            );
        }
        if ( $params->{data}->{old_info}->{location} ne $params->{data}->{new_info}->{location} ) {
            $self->_record_notification(
                event_params => $params,
                type => $params->{data}->{old_info}->{location} ? 'new_meeting_location' : 'decided_meeting_location',
                data => {
                    meeting_id => $meeting->id,
                    new_location => $params->{data}->{new_info}->{location},
                },
            );
        }
        if ( $params->{data}->{old_info}->{title} ne $params->{data}->{new_info}->{title} ) {
            $self->_record_notification(
                event_params => $params,
                type => 'new_meeting_title',
                data => {
                    meeting_id => $meeting->id,
                    old_title => $params->{data}->{old_info}->{title},
                    new_title => $params->{data}->{new_info}->{title},
                },
            );
        }
    }

    if ( $params->{event_type} eq 'meetings_participant_created' ) {
        my $user_type = $params->{data}->{rsvp_required} ? 'rsvp' : 'invited';
        $user_type = "meetme_$user_type" if $params->{data}->{from_user_meetme_request};

        $self->_record_notification(
            event_params => $params,
            user_id => $params->{data}->{user_id},
            type => $user_type,
            data => {
                meeting_id => $meeting->id,
            },
        );

        # NOTE: we want to do this by hand instead of relying on the automatic participant notifications
        # NOTE: as we want to omit notifications from people who have been added around the same time.

        my $euos = $self->_fetch_meeting_participant_objects( $meeting );
        my $current_user_timestamp = 0;
        for my $euo ( @$euos ) {
            next unless $euo->user_id == $params->{data}->{user_id};
            $current_user_timestamp = $euo->created_date;
        }

        for my $euo ( @$euos ) {
            # HACK: disable new user notifications for larger events due to perf problems
            next if @$euos > 30;

            next if abs( $euo->created_date - $current_user_timestamp ) < 30;
            next if $params->{data}->{author_user_id} && $params->{data}->{author_user_id} == $euo->user_id;
            next if $params->{data}->{author_id} && $params->{data}->{author_id} == $euo->user_id;
            next if $params->{author} && $params->{author}->id == $euo->user_id;
            next if $params->{author_id} && $params->{author_id} == $euo->user_id;

            $self->_record_notification(
                event_params => $params,
                user_id => $euo->user_id,
                type => 'new_participant',
                data => {
                    meeting_id => $meeting->id,
                    user_id => $params->{data}->{user_id},
                },
            );
        }
    }

    if ( $params->{event_type} eq 'meetings_wiki_comment_created' || $params->{event_type} eq 'meetings_prese_comment_created' ) {
        my $material_container = $params->{data}->{container_type};

        $material_container =~ s/prese/media/;
        $material_container =~ s/wiki/page/;

        $self->_record_notification(
            event_params => $params,
            type => 'new_material_comment',
            data => {
                meeting_id => $meeting->id,
                material_id => join( ":", $meeting->id, $material_container, $params->{data}->{object_id} ),
            },
        );
    }

    if ( $params->{event_type} eq 'meetings_note_comment_created' ) {
        $self->_record_notification(
            event_params => $params,
            type => 'new_material_comment',
            data => {
                meeting_id => $meeting->id,
                material_id => join( ":", $meeting->id, 'chat' ),
            },
        );
    }
}

sub _record_matchmaker_notification {
    my ( $self, $matchmaker, $params ) = @_;

}

sub _user_has_push_device_available {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;
    return 1 if $self->_user_has_ios_push_device_available( $user, $domain_id, $only_prefix );
    return 1 if $self->_user_has_android_push_device_available( $user, $domain_id, $only_prefix );
    return 0;
}

sub _user_has_push_device_enabled {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;
    return 1 if $self->_user_has_ios_push_device_enabled( $user, $domain_id, $only_prefix );
    return 1 if $self->_user_has_android_push_device_enabled( $user, $domain_id, $only_prefix );
    return 0;
}

sub _user_has_ios_push_device_enabled {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;

    my $enabled_found = 0;
    for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet') {
        next if $only_prefix && ( $prefix ne $only_prefix );
        my $enabled_key = join( "_", ( $prefix || () ), 'ios_device_enabled' );
        return 1 if $self->_get_note_for_user( $enabled_key => $user, $domain_id );
        $enabled_found = 1 if defined( $self->_get_note_for_user( $enabled_key => $user, $domain_id ) );
    }

    # NOTE: this is for legacy support. can be removed in start of 2016
    if ( ! $enabled_found ) {
        return 1 if $self->_user_has_ios_push_device_available( $user, $domain_id, $only_prefix );
    }

    return 0;
}

sub _user_has_ios_push_device_available {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;
    for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet') {
        next if $only_prefix && ( $prefix ne $only_prefix );
        my $available_key = join( "_", ( $prefix || () ), 'ios_device_available' );
        return 1 if $self->_get_note_for_user( $available_key => $user, $domain_id );
    }
    return 0;
}

sub _user_has_android_push_device_enabled {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;

    my $enabled_found = 0;
    for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet') {
        next if $only_prefix && ( $prefix ne $only_prefix );
        my $enabled_key = join( "_", ( $prefix || () ), 'android_device_enabled' );
        return 1 if $self->_get_note_for_user( $enabled_key => $user, $domain_id );
        $enabled_found = 1 if defined( $self->_get_note_for_user( $enabled_key => $user, $domain_id ) );
    }

    # NOTE: this is for legacy support. can be removed in start of 2016
    if ( ! $enabled_found ) {
        return 1 if $self->_user_has_android_push_device_available( $user, $domain_id, $only_prefix );
    }

    return 0;
}

sub _user_has_android_push_device_available {
    my ( $self, $user, $domain_id, $only_prefix ) = @_;
    for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet') {
        next if $only_prefix && ( $prefix ne $only_prefix );
        my $available_key = join( "_", ( $prefix || () ), 'android_device_available' );
        return 1 if $self->_get_note_for_user( $available_key => $user, $domain_id );
    }
    return 0;
}

sub _ensure_scheduling_organizer_escalation_performed_for_notification {
    my ( $self, $n, $scheduling ) = @_;

    $n = $self->_ensure_object_of_type( meetings_user_notification => $n );

    if ( ! $scheduling ) {
        my $data = $self->_get_note( data => $n );
        return unlesss $data->{scheduling_id};

        $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $data->{scheduling_id} );
    }

    return unless $scheduling;

    return $self->_ensure_scheduling_organizer_escalation_performed_for_scheduling( $scheduling );
}

sub _ensure_scheduling_organizer_escalation_performed_for_scheduling {
    my ( $self, $scheduling ) = @_;

    return if $self->_get_note( last_missing_answers_organizer_notification => $scheduling );

    $scheduling = $scheduling = $self->_ensure_object_of_type( meetings_scheduling => $scheduling->id );

    return if $self->_get_note( last_missing_answers_organizer_notification => $scheduling );

    $self->_set_note( last_missing_answers_organizer_notification => time, $scheduling );

    $self->_record_notification(
        user_id => $scheduling->creator_id,
        date => time,
        type => 'scheduling_is_missing_answers',
        data => {
            author_id => $scheduling->creator_id,
            scheduling_id => $scheduling->id,
            meeting_id => $scheduling->meeting_id,
        }
    );

    $self->_ensure_scheduling_instruction( $scheduling, 'needs_activation' );

    return 1;
}

sub _get_notification_escalation_log_entry_name_for_method {
    my ( $self, $n, $method ) = @_;

    $n = $self->_ensure_object_of_type( meetings_user_notification => $n );
    my $type = $n->notification_type;
    my $data = $self->_get_note( data => $n ) || {};

    my $log_entry = '';
    if ( $method eq 'sms' ) {
        $log_entry = 'user_invited_sms' if $type =~ /^(new_scheduling_answers_needed)/;
        $log_entry = 'user_reinvited_sms' if $type =~ /^(new_scheduling_answers_needed)/ && $data->{reinvite};
        $log_entry = 'user_more_input_sms' if $type =~ /^(more_scheduling_answers_needed)/;
        $log_entry = 'organizer_input_sms' if $type =~ /^(organizer_scheduling_answers_needed)/;
    }
    elsif ( $method eq 'email' ) {
        $log_entry = 'user_invited_email' if $type =~ /^(new_scheduling_answers_needed)/;
        $log_entry = 'user_reinvited_email' if $type =~ /^(new_scheduling_answers_needed)/ && $data->{reinvite};
        $log_entry = 'user_more_input_email' if $type =~ /^(more_scheduling_answers_needed)/;
        $log_entry = 'organizer_input_email' if $type =~ /^(organizer_scheduling_answers_needed)/;
    }
    elsif ( $method eq 'push' ) {
        $log_entry = 'user_invited_push' if $type =~ /^(new_scheduling_answers_needed)/;
        $log_entry = 'user_reinvited_push' if $type =~ /^(new_scheduling_answers_needed)/ && $data->{reinvite};
        $log_entry = 'user_more_input_push' if $type =~ /^(more_scheduling_answers_needed)/;
        $log_entry = 'organizer_input_push' if $type =~ /^(organizer_scheduling_answers_needed)/;
    }

    return $log_entry;
}

sub _get_notification_escalation_policy {
    my ( $self, $notification, $user ) = @_;

    $user ||= Dicole::Utils::User->ensure_object( $notification->user_id );
    $notification = $self->_ensure_object_of_type( meetings_user_notification => $notification );

    return '' unless $user && $notification;

    my $domain_id = $notification->domain_id;

    return '' if $self->_get_note_for_user( deleted_user => $user, $domain_id );

    my $type = $notification->notification_type;
    my $data = $self->_get_note( data => $notification ) || {};

    my $p = $self->_user_has_push_device_enabled( $user, $domain_id ) ? 'P' : '-';
    my $s = $user->phone ? 'S' : '-';
    my $e = $user->email ? 'E' : '-';

    # NOTE dev Hack to disable pushes
    # $p = '-';

    my $capabilities = "$p$s$e";

    my $default_escalation_policy_actions = {
        meeting_invites => {
            'P--' => 'P',
            '-S-' => 'S',
            '--E' => 'E',
            'PS-' => 'P',
            '-SE' => 'E',
            'P-E' => 'P,E',
            'PSE' => 'P,E',
        },
        meeting_rsvp_invites => {
            'P--' => 'P,1440,P',
            '-S-' => 'S,1440,S',
            '--E' => 'E,1440,E,1440,E',
            'PS-' => 'P,1440,S,1440,P',
            '-SE' => 'E,1440,E,1440,S',
            'P-E' => 'P,E,1440,E,1440,E',
            'PSE' => 'P,E,1440,E,1440,E',
        },
        scheduling_invites => {
            'P--' => 'P,120,P,1260,P,60,O',
            '-S-' => 'S,120,S,1260,S,60,O',
            '--E' => 'E,1380,E,60,O',
            'PS-' => 'P,120,S,1260,P,60,O',
            '-SE' => 'S,120,E,1260,S,60,O',
            'P-E' => 'P,120,E,1260,P,60,O',
            'PSE' => 'P,120,S,120,E,1140,P,60,O',
        },
        scheduling_more => {
            'P--' => 'P,1380,P,60,O',
            '-S-' => 'S,1380,S,60,O',
            '--E' => 'E,1380,E,60,O',
            'PS-' => 'P,1380,S,60,O',
            '-SE' => 'S,1380,E,60,O',
            'P-E' => 'O,1380,E,60,O',
            'PSE' => 'P,1380,S,60,O',
        },
        scheduling_finalized => { # NOTE: refactor later to contain ics notifications
            'P--' => 'P',
            '-S-' => 'S',
            '--E' => '',
            'PS-' => 'P,S',
            '-SE' => 'S',
            'P-E' => 'P',
            'PSE' => 'P',
        },
        scheduling_stalled => {
            'P--' => 'P',
            '-S-' => 'S',
            '--E' => 'E',
            'PS-' => 'P,120,S',
            '-SE' => 'S,120,E',
            'P-E' => 'P,120,E',
            'PSE' => 'P,120,E',
        },
        _default => {
            _default => 'P',
        }
    };

    my $default_escalation_policy_disband_checks = {
        meeting_invites => [ qw/ user_is_participating_in_valid_meeting user_has_not_opened_meeting_yet / ],
        meeting_rsvp_invites => [ qw/ user_is_participating_in_valid_meeting user_has_not_answered_rsvp_yet / ],
        scheduling_invites => [ qw/ user_is_participating_in_valid_meeting user_is_participating_in_scheduling scheduling_is_ongoing this_is_the_latest_scheduling_invite user_has_not_opened_scheduling_yet / ],
        scheduling_finalized => [ qw/ user_is_participating_in_valid_meeting user_is_participating_in_scheduling user_has_not_opened_scheduling_yet / ],
        scheduling_stalled => [ qw/ user_is_participating_in_valid_meeting user_is_participating_in_scheduling scheduling_is_ongoing user_has_not_opened_scheduling_yet / ],
        _default => [],
    };

    my $disband_check_caches = {};
    my $disband_check_helpers = {
        meeting => sub { return $disband_check_caches->{meeting} ||= $self->_ensure_meeting_object( $data->{meeting_id} ); },
        euo => sub { return $disband_check_caches->{euo} ||= $self->_get_user_meeting_participation_object( $user, $data->{meeting_id} ); },
    };

    my $disband_checks_routines = {
        user_is_participating_in_valid_meeting => sub {
            my $meeting = $disband_check_helpers->{meeting}->();
            return 1 unless $meeting;
            return 1 if $meeting->removed_date;

            my $euo = $disband_check_helpers->{euo}->();

            return 1 unless $euo;
            return 0;
        },
        user_is_participating_in_scheduling => sub {
            my $meeting = $disband_check_helpers->{meeting}->();
            my $euo = $disband_check_helpers->{euo}->();

            return 1 if $self->_get_note( scheduling_disabled => $euo );

            # TODO: fetch scheduling object and check that it is still ongoing?
            return 0;
        },
        scheduling_is_ongoing => sub {
            my $meeting = $disband_check_helpers->{meeting}->();
            return 1 unless $self->_get_note( current_scheduling_id => $meeting ) == $data->{scheduling_id};
            return 0;
        },
        this_is_the_latest_scheduling_invite => sub {
            my $euo = $disband_check_helpers->{euo}->();
            if ( my $latest_id = $self->_get_note( latest_scheduling_invite_notification_id => $euo ) ) {
                return 1 unless $latest_id == $notification->id;
            }
            return 0;
        },
        user_has_not_opened_meeting_yet => sub {
            my $euo = $disband_check_helpers->{euo}->();
            if ( my $last_opened = $self->_get_note( note_last_page_loaded => $euo ) ) {
                return 1 if $last_opened > $notification->created_date
            }
            return 0;
        },
        user_has_not_answered_rsvp_yet => sub {
            my $euo = $disband_check_helpers->{euo}->();
            return 1 if $self->_get_note( rsvp => $euo );
            return 0;
        },
        user_has_not_opened_scheduling_yet => sub {
            my $euo = $disband_check_helpers->{euo}->();
            if ( my $last_opened = $self->_get_note( scheduling_opened => $euo ) ) {
                return 1 if $last_opened > $notification->created_date
            }
            return 0;
        },
    };

    my $type_policies = {
        rsvp => { action_class => 'meeting_rsvp_invites', disband_class => 'meeting_rsvp_invites' },
        meetme_rsvp => { action_class => 'meeting_rsvp_invites', disband_class => 'meeting_rsvp_invites' },
        invited => { action_class => 'meeting_invites', disband_class => 'meeting_invites' },
        meetme_invited => { action_class => 'meeting_invites', disband_class => 'meeting_invites' },
        new_scheduling_answers_needed => { action_class => 'scheduling_invites', disband_class => 'scheduling_invites' },
        more_scheduling_answers_needed => { action_class => 'scheduling_more', disband_class => 'scheduling_invites' },
        organizer_scheduling_answers_needed => { action_class => 'scheduling_invites', disband_class => 'scheduling_invites' },
        scheduling_date_found => { action_class => 'scheduling_finalized', disband_class => 'scheduling_finalized' },
        scheduling_date_not_found => { action_class => 'scheduling_finalized', disband_class => 'scheduling_finalized' },
        scheduling_is_missing_answers => { action_class => 'scheduling_stalled', disband_class => 'scheduling_stalled' },
        _default => {},
    };

    my $policy = $type_policies->{ $type } || $type_policies->{_default};
    my $action_class = delete $policy->{action_class} || '_default';
    my $action_options = $default_escalation_policy_actions->{$action_class};
    $policy->{actions} = $action_options->{ $capabilities } || $action_options->{_default};

    my $disband_class = delete $policy->{disband_class} || '_default';
    my $disband_checks = $default_escalation_policy_disband_checks->{$disband_class};

    $policy->{disband_check} = sub {
        for my $check ( @$disband_checks ) {
            return 1 if eval { $disband_checks_routines->{$check}->() };
            if ( $@ ) {
                get_logger(LOG_APP)->error('notification disband check error for notification ' . $notification->id . ': '. $@ );
                return 1;
            }
        }
        return 0;
    };

    return $policy;
}

sub _manual_disable_old_push_devices {
    my ( $self, $domain_id ) = @_;

    my $users = CTX->lookup_object('user')->fetch_group;

    my $process = [];
    for my $user ( @$users ) {
        next unless $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id )
        || $self->_get_note_for_user( device_push_status_map => $user, $domain_id );
        push @$process, $user;
    }

    for my $user ( @$process ) {
        my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id );
        for my $push_prefix ( keys %{ $device_data } ) {
            for my $device_type ( keys %{ $device_data->{ $push_prefix } } ) {
                for my $token ( keys %{ $device_data->{ $push_prefix }->{ $device_type }->{enabled} || {} } ) {
                    my $epoch = $device_data->{ $push_prefix }->{ $device_type }->{enabled}->{$token};
                    print "$token\n";
                    $self->_disable_push_device_from_users_if_enabled_before_epoch(
                        $push_prefix, $token, $device_type, $process, $domain_id, $epoch
                    );
                }
            }
        }
    }
}

sub _disable_push_device_from_users_if_enabled_before_epoch {
    my ( $self, $prefix, $token, $device_type, $users, $domain_id, $epoch ) = @_;
    my $push_prefix = $prefix || 'live';

    for my $user ( @$users ) {
        my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id );
        my $enabled = $device_data->{ $push_prefix }->{ $device_type }->{enabled}->{$token};
        next unless $enabled && $epoch > $enabled;
        print $user->id . " disabled $token\n";
        delete $device_data->{ $push_prefix }->{ $device_type }->{enabled}->{$token};
        $device_data->{ $push_prefix }->{ $device_type }->{disabled}->{$token} = time;
        $self->_set_note_for_user( device_full_push_status_map => $device_data, $user, $domain_id );
    }

    for my $user ( @$users ) {
        my $legacy_device_data = $self->_get_note_for_user( device_push_status_map => $user, $domain_id );
        my $legacy_enabled = $legacy_device_data->{ $prefix }->{enabled} || {};
        for my $legacy_token ( %$legacy_enabled ) {
            next if $legacy_device_data->{ $prefix }->{enabled} >= $epoch;
            my $new_token = $self->_determine_user_device_token_from_urbanairship( $user, $domain_id, $prefix, $legacy_token, $device_type );
            next unless $new_token && $new_token eq $token;

            my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id );
            next if $device_data->{ $push_prefix }->{ $device_type }->{disabled}->{$token};
            print $user->id . " disabled $legacy_token\n";
            delete $device_data->{ $push_prefix }->{ $device_type }->{enabled}->{$token};
            $device_data->{ $push_prefix }->{ $device_type }->{disabled}->{$token} = time;
            $self->_set_note_for_user( device_full_push_status_map => $device_data, $user, $domain_id );
        }
    }
}

sub _disable_push_token_from_other_users {
    my ( $self, $prefix, $token, $device_type, $user, $domain_id ) = @_;

    my $push_prefix = $prefix || 'live';
    my $device_data = $self->_get_note_for_user( device_full_push_status_map => $user, $domain_id );

    my $epoch = $device_data->{ $push_prefix }->{ $device_type }->{enabled}->{$token};

    return unless $epoch;

    my $device_logs = CTX->lookup_object('meetings_push_device')->fetch_group({
        where => 'push_address = ?',
        value => [ $token ],
    });

    my $user_map = { map { $_->user_id => 1 } @$device_logs };
    my $users = Dicole::Utils::User->ensure_object_list( [ keys %$user_map ] );

    $self->_disable_push_device_from_users_if_enabled_before_epoch( $prefix, $token, $device_type, $users, $domain_id, $epoch );
}

sub _get_new_mobile_redirect_url_for_user {
    my ( $self, $params, $for_user, $domain_id ) = @_;

    my $url = URI::URL->new( CTX->server_config->{dicole}->{new_mobile_url_base} || 'https://mobiledev.meetin.gs/' );

    $url->query_form( $params );
    $url = $self->_generate_authorized_uri_for_user( $url->as_string, $for_user, $domain_id );
    $url =~ s/^(.*?\/\/.*?)\//$1\/\#\//;

    return $url;
}

sub _get_new_mobile_redirect_url {
    my ( $self, $params ) = @_;

    my $url = URI::URL->new( CTX->server_config->{dicole}->{new_mobile_url_base} || 'https://mobiledev.meetin.gs/' );

    $url->query_form( $params );
    $url = $url->as_string;
    $url =~ s/^(.*?\/\/.*?)\//$1\/\#\//;

    return $url;
}

sub _get_notification_params_for_class {
    my ( $self, $notification, $class, $for_user ) = @_;

    my $domain_id = $notification->domain_id;

    $for_user ||= Dicole::Utils::User->ensure_object( $notification->user_id );

    return '' if $self->_check_if_user_has_disabled_notification( $notification, $for_user, $domain_id );

    my $type = $notification->notification_type;

    return '' if $type =~ /^(new_meeting_title|new_material_comment|new_material|new_participant|new_participants_collated)$/;

    my $cached_meeting_object;
    my $cached_requester_company;
    my $cached_scheduling_object;
    my $cached_participant_object;

    my $ndata = $self->_get_note( data => $notification ) || {};

    my $nd = sub { $ndata->{ $_[0] } };
    my $m = sub { $cached_meeting_object ||= $self->_ensure_meeting_object( $nd->('meeting_id') ) };
    my $s = sub { $cached_scheduling_object ||= $self->_ensure_object_of_type( meetings_scheduling => $nd->('scheduling_id') ) };
    my $po = sub { $cached_participant_object ||= $self->_get_user_meeting_participation_object( $for_user, $nd->('meeting_id') ) };

    my $author_name_cb = sub { Dicole::Utils::User->name( $nd->('author_id') ) };
    my $user_name_cb = sub { Dicole::Utils::User->name( $for_user ) };
    my $meeting_title_cb = sub { $self->_meeting_title_string( $m->() ) };
    my $meeting_location_cb = sub { $self->_meeting_location_string( $m->() ) };
    my $meeting_date_cb = sub { $self->_form_times_string_for_epochs_and_user( $m->()->begin_date, undef, $for_user ) };
    my $meeting_date_en_cb = sub { $self->_form_times_string_for_epochs( $m->()->begin_date, undef, $for_user->timezone, 'en' ) };
    my $requester_company_cb = sub { $cached_requester_company ||= $self->_gather_user_info( $nd->('author_id'), -1, $m->()->domain_id )->{organization} };
    my $scheduling_organizer_name_cb = sub { Dicole::Utils::User->name( $s->()->creator_id ) };
    my $scheduling_url_cb = sub {
        my $url = $self->_get_new_mobile_redirect_url_for_user(
            { redirect_to_meeting => $nd->('meeting_id'), redirect_to_scheduling => $nd->('scheduling_id'), utm_source => $class },
            $for_user, $domain_id
        );
        return $self->_create_shortened_url( $url, $for_user, { type => 'notification_action', notification_id => $notification->id, notification_method => $class } );
    };
    my $scheduling_log_url_cb = sub {
        my $url = $self->_get_new_mobile_redirect_url_for_user(
            { redirect_to_meeting => $nd->('meeting_id'), redirect_to_scheduling_log => $nd->('scheduling_id'), utm_source => $class },
            $for_user, $domain_id
        );
        return $self->_create_shortened_url( $url, $for_user, { type => 'notification_action', notification_id => $notification->id, notification_method => $class } );
    };
    my $meeting_url_cb = sub {
        my $url = $self->_get_new_mobile_redirect_url_for_user(
            { redirect_to_meeting => $nd->('meeting_id'), utm_source => $class },
            $for_user, $domain_id
        );
        return $self->_create_shortened_url( $url, $for_user, { type => 'notification_action', notification_id => $notification->id, notification_method => $class } );
    };

    if ( $type =~ /^meetme_request/ ) {
        $type .= $requester_company_cb->() ? '_company' : '';
    }
    if ( $class eq 'sms' && $type eq 'scheduling_date_found' && ! $for_user->email ) {
        $type .= '_without_email';
    }

    my $class_data = {};
    $class_data->{push} = {
        rsvp => [ '%1$s asked if you are attending %2$s.', [ $author_name_cb, $meeting_title_cb ] ],
        invited => [ '%1$s invited you to %2$s.', [ $author_name_cb, $meeting_title_cb ] ],
        meetme_rsvp => [ '%1$s accepted your request to meet.', [ $author_name_cb ] ],
        meetme_invited => [ '%1$s accepted your request and wants to double check your RSVP.', [ $author_name_cb ] ],
        meetme_request => [ '%1$s would like to meet you. Please respond now.', [ $author_name_cb ] ],
        meetme_request_company => [ '%1$s from %2$s would like to meet you. Please respond now.', [ $author_name_cb, $requester_company_cb ] ],
        new_meeting_date => [ 'Meeting time was changed to %1$s for %2$s.', [ $meeting_date_cb, $meeting_title_cb ] ],
        decided_meeting_date => [ 'Meeting time was set to %1$s for %2$s.', [ $meeting_date_cb, $meeting_title_cb ] ],
        new_meeting_location => [ 'Meeting location changed to %1$s for %2$s.', [ $meeting_location_cb, $meeting_title_cb ] ],
        decided_meeting_location => [ 'Meeting location was set to %1$s for %2$s.', [ $meeting_location_cb, $meeting_title_cb ] ],
        new_scheduling_answers_needed => ['%1$s is looking for a suitable time for a meeting.', [ $author_name_cb ] ],
        more_scheduling_answers_needed => ['We need more input from you to schedule %1$s.', [ $meeting_title_cb ] ],
        organizer_scheduling_answers_needed => ['We need your input to schedule %1$s.', [ $meeting_title_cb ] ],
        scheduling_date_found => ['Time found for %1$s on %2$s.', [ $meeting_title_cb, $meeting_date_en_cb ] ],
        scheduling_date_found_without_email => ['Time found for %1$s on %2$s.', [ $meeting_title_cb, $meeting_date_en_cb ] ],
        scheduling_date_not_found => ['We were unable to find a suitable time for %1$s.', [ $meeting_title_cb ] ],
        scheduling_is_missing_answers => ['Scheduling is stagnant. We are missing responses for %1$s.', [ $meeting_title_cb ] ],
    };

    my $push_category_by_type = {
        new_scheduling_answers_needed => 'swipetomeet',
        more_scheduling_answers_needed => 'swipetomeet',
        organizer_scheduling_answers_needed => 'swipetomeet',
    };

    $class_data->{sms} = {
        rsvp => [ '%1$s asked if you are attending %2$s'."\n\n".'See the meeting details and respond: %2$s', [ $author_name_cb, $meeting_title_cb, $meeting_url_cb ] ],
        invited => [ '%1$s invited you to %2$s.'."\n\n".'See the meeting details: %3$s', [ $author_name_cb, $meeting_title_cb, $meeting_url_cb ] ],
        meetme_rsvp => [ '%1$s accepted your request to meet.'."\n\n".'See the meeting details: %2$s', [ $author_name_cb, $meeting_url_cb ] ],
        meetme_invited => [ '%1$s accepted your request and wants to double check your RSVP.'."\n\n".'See the meeting details and respond: %2$s', [ $author_name_cb, $meeting_url_cb ] ],
        new_scheduling_answers_needed => ['%1$s is looking for a suitable time for a meeting.'."\n\n".'See the details and schedule it: %2$s', [ $author_name_cb, $scheduling_url_cb ] ],
        more_scheduling_answers_needed => ['We need more input from you to schedule %1$s.'."\n\n".'Answer additional time suggestions: %2$s', [ $meeting_title_cb, $scheduling_url_cb ] ],
        organizer_scheduling_answers_needed => ['We need your input to schedule %1$s.'."\n\n".'Give your input: %2$s', [ $meeting_title_cb, $scheduling_url_cb ] ],
        scheduling_date_found => ['A perfect time was found for %1$s:'."\n\n".'%2$s'."\n\n".'See the meeting details: %3$s', [ $meeting_title_cb, $meeting_date_en_cb, $scheduling_url_cb ] ],
        scheduling_date_found_without_email => ['A perfect time was found for %1$s:'."\n\n".'%2$s'."\n\n".'See the meeting details and add the event to your calendar: %3$s', [ $meeting_title_cb, $meeting_date_en_cb, $scheduling_url_cb ] ],
        scheduling_date_not_found => ['We were unable to find a suitable time for %1$s'."\n\n".'See the details and schedule it: %2$s', [ $meeting_title_cb, $scheduling_url_cb ] ],
        scheduling_is_missing_answers => ['Scheduling is stagnant. We are missing responses for %1$s.'."\n\n".'See the details: %2$s', [ $meeting_title_cb, $scheduling_log_url_cb ] ],
    };

    $class_data->{email} = {
        rsvp => { special_invite_params => 1 },
        invited => { special_invite_params => 1 },
        meetme_rsvp => { special_invite_params => 1 },
        meetme_invited => { special_invite_params => 1 },
        new_scheduling_answers_needed => {
            template_key_base => 'meetings_swipe_notification_new_scheduling_answers_needed',
            template_params => {
                organizer_name => $scheduling_organizer_name_cb,
                swipe_url => $scheduling_url_cb,
            }
        },
        more_scheduling_answers_needed => {
            template_key_base => 'meetings_swipe_notification_more_scheduling_answers_needed',
            template_params => {
                organizer_name => $scheduling_organizer_name_cb,
                swipe_url => $scheduling_url_cb,
            }
        },
        organizer_scheduling_answers_needed => {
            template_key_base => 'meetings_swipe_notification_organizer_scheduling_answers_needed',
            template_params => {
                organizer_name => $scheduling_organizer_name_cb,
                swipe_url => $scheduling_url_cb,
            }
        },

        scheduling_is_missing_answers => {
            template_key_base => 'meetings_swipe_notification_scheduling_is_missing_answers',
            template_params => {
                swipe_url => $scheduling_log_url_cb,
            }
        }
    };

    my $notification_class_data = $class_data->{ $class }{ $type };

    return '' unless $notification_class_data;

    if ( $class eq 'email' ) {
        my $params = {};

        my $params_functions = $notification_class_data->{template_params} || {};
        for my $key ( keys %$params_functions ) {
            $params->{ $key } = $params_functions->{ $key }->();
        }

        if ( $notification_class_data->{special_invite_params} ) {
            my $extra_params = $ndata->{extra_mail_template_params} || {};
            return $self->_gather_user_meeting_invite_email_params( $for_user, $m->(), $extra_params, $po->() );
        }

        if ( $ndata->{meeting_id} ) {
            return $self->_get_meeting_user_template_mail_params(
                $m->(), $for_user, $notification_class_data->{template_key_base}, $params
            );
        }
        else {
            return $self->_get_user_template_mail_params(
                $for_user, $domain_id, $notification_class_data->{template_key_base}, $params
            );
        }
    }
    elsif ( $class eq 'sms' || $class eq 'push' ) {
        my @params = ();
        for my $param_cb ( @{ $notification_class_data->[1] } ) {
            push @params, $param_cb->();
        }
        return { string => sprintf( $notification_class_data->[ 0 ], @params ), category => $push_category_by_type->{ $type } || '' };
    }
}

sub _check_if_user_has_disabled_notification {
    my ( $self, $notification, $user, $domain_id ) = @_;

    my $enable_keys = {
        rsvp => 'push_meeting_invitation',
        invited => 'push_meeting_invitation',
        meetme_rsvp => 'push_meeting_invitation',
        meetme_invited => 'push_meeting_invitation',
        meetme_request => 'push_meetme_received',
        meetme_request_company => 'push_meetme_received',
        new_meeting_date => 'push_meeting_date',
        decided_meeting_date => 'push_meeting_date',
        new_meeting_location => 'push_meeting_location',
        decided_meeting_location => 'push_meeting_location',
        new_participant => 'push_meeting_participant',
        new_participants_collated => 'push_meeting_participant',
        new_material => 'push_meeting_material',
        new_material_comment => 'push_meeting_material_comment',
    };

    my $enable_key = $enable_keys->{ $notification->notification_type };
    return 0 unless $enable_key;

    my $hash = $self->_user_notification_setting_values_hash( $user, $domain_id );

    my $is_enabled = $hash->{ $enable_key } ? 1 : 0;

    return $is_enabled ? 0 : 1;
}

sub _determine_author_id {
    my ( $self, $params ) = @_;

    $params ||= {};
    my $params_author = $params->{author} || $params->{author_id};
    return Dicole::Utils::User->ensure_id( $params_author ) if $params_author;

    my $r = CTX->request;
    return $r->auth_user_id if $r && $r->auth_user_id;
    return CTX->{current_job_auth_user_id} || 0;
}

sub _form_meeting_material_id {
    my ( $self, $meeting, $material ) = @_;

    $meeting = $meeting->id if ref( $meeting );

    return join ( ":", $meeting, 'page', $material->{page_id} ) if ref( $material ) && $material->{page_id};
    return join ( ":", $meeting, 'media', $material->{prese_id}  ) if ref( $material ) && $material->{prese_id};
    return join ( ":", $meeting, 'chat' );
}

sub _user_can_manage_meeting_prese {
    my ( $self, $user_id, $event, $prese ) = @_;

    $user_id = Dicole::Utils::User->ensure_id( $user_id );

    return 1 if $self->_user_can_manage_meeting( $user_id, $event );

    return $user_id == $prese->creator_id;
}

sub _form_user_create_meetings_url {
    my ( $self, $user, $domain_id, $domain_host ) = @_;

    $domain_host ||= $self->_get_host_for_user( $user, $domain_id, 443 );
    $user = Dicole::Utils::User->ensure_object( $user );

    my $bgid = $self->_determine_user_base_group( $user, $domain_id );

    return $domain_host . Dicole::URL->from_parts(
        domain_id => $domain_id,
        action => 'meetings',
        task => 'summary',
        target => $bgid,
        params => { dic => $self->_user_permanent_dic( $user, $domain_id ) },
    );
}

sub _form_user_beta_signup_url {
    my ( $self, $user, $inviter, $domain_id, $domain_host ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_host ||= $self->_get_host_for_user( $user, $domain_id, 443 );

    return $domain_host . Dicole::URL->from_parts(
        domain_id => $domain_id,
        action => 'meetings',
        task => 'signup',
        target => 0,
        params => {
            invited_by => $inviter ? Dicole::Utils::User->ensure_id( $inviter ) : -1,
            dic => $self->_user_permanent_dic( $user, $domain_id )
        },
    );
}

sub _generate_meeting_image_url_for_user {
    my ( $self, $meeting, $user ) = @_;

    my $url = Dicole::URL->from_parts(
        action => 'meetings_raw', task => 'meeting_image', target => 0, domain_id => $meeting->domain_id,
        additional => [ $meeting->id, $user->id, $self->_generate_meeting_image_digest_for_user( $meeting->id, $user ) . '.png' ]
    );

    $url = $self->_get_host_for_meeting( $meeting, 443 ) . $url;

    return $url;
}

sub _send_login_email {
    my ($self, %params) = @_;

    my $url   = $params{url};
    my $email = $params{email};
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $params{domain_id} );

    my $user = $params{user} || Dicole::Utils::User->fetch_user_by_login_in_domain( $email, $domain_id );

    die "no such user" unless $user;

    my $authorized_uri = $self->_generate_authorized_uri_for_user( $url, $user, $domain_id );

    my $clear_email = 0;
    if ( $email && ! $user->email ) {
        $clear_email = 1;
        $user->email( $email );
    }

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $domain_id,
        partner_id => $params{partner_id} || $self->param('partner_id'),
        group_id => 0,

        template_key_base => 'meetings_login_link_email',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            new_user => $params{new_user} || $self->_user_is_new_user( $user, $domain_id ),
            pin => $params{pin},
            login_url => $authorized_uri,
            account => $user->email,
            password => $params{password},
        },
    );

    if ( $clear_email ) {
        $user->email('');
        $user->save;
    }
}

sub _generate_authorized_uri_for_user {
    my ( $self, $url, $user, $domain_id, $days ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $days ||= 3;

    die "no such user" unless $user;

    $url = ( $url =~ /^http/ ) ? $url : $self->_get_host_for_user( $user, $domain_id, 443 ) . $url;

    my $authorized_uri = URI->new( $url );
    $authorized_uri->query_param_delete('dic');
    $authorized_uri->query_param( 'dic', Dicole::Utils::User->temporary_authorization_key( $user, $days * 24 ) )
        unless $self->_get_note_for_user( eliminate_link_auth => $user, $domain_id );
    $authorized_uri->query_param_delete('user_id');
    $authorized_uri->query_param( 'user_id', $user->id );

    return $authorized_uri->as_string;
}

sub _get_user_template_mail_params {
    my ( $self, $user, $domain_id, $template, $params, $root_params ) = @_;

    return {
        user_id => $user->id,
        domain_id => $domain_id,
        partner_id => 0,
        group_id => 0,
        template_key_base => $template,
        template_params => $params,
        %$root_params,
    };
}

sub _get_meeting_user_template_mail_params {
    my ( $self, $meeting, $user, $template, $params, $root_params, $domain_host, $meeting_email ) = @_;
    $meeting = $self->_ensure_meeting_object( $meeting );
    $user = Dicole::Utils::User->ensure_object( $user );

    return {
        %{ $self->_gather_meeting_user_template_mail_base_params( $meeting, $user, $template ) },
        %{ $root_params || {} },
        template_params => {
            %{ $self->_gather_meeting_user_template_mail_template_params( $meeting, $user, $domain_host, $meeting_email ) },
            %{ $params || {} },
        },
    };
}

sub _send_meeting_user_template_mail {
    my ( $self, $meeting, $user, $template, $params, $domain_host, $meeting_email ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $user = Dicole::Utils::User->ensure_object( $user );

    $self->_send_themed_mail(
        %{ $self->_get_meeting_user_template_mail_params( $meeting, $user, $template, $params, {}, $domain_host, $meeting_email ) }
    );
}

sub _meeting_ics_url_for_user {
    my ( $self, $meeting, $user, $domain_host ) = @_;

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );

    return $domain_host . Dicole::URL->from_parts(
        action => 'meetings_raw', task => 'ics',
        target => $meeting->group_id, domain_id => $meeting->domain_id,
        additional => [ $meeting->id, $user->id, $self->_generate_meeting_ics_digest_for_user( $meeting->id, $user ), 'meeting.ics' ]
    );
}

sub _gather_meeting_user_template_mail_template_params {
    my ( $self, $meeting, $user, $domain_host, $meeting_email, $meeting_participants ) = @_;

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );
    $domain_host =~ s/^http:/https:/;
    my $info = Dicole::Utils::Date->timezone_info( $user->timezone || 'UTC' );
    my $time_zone = $info->{offset_string} . ' ( ' . $info->{name} .' )';

    my $ics_url = '';
    my $gcal_url = '';

    if ( $meeting->begin_date ) {
        $ics_url = $self->_meeting_ics_url_for_user( $meeting, $user, $domain_host );
        $gcal_url = $self->_generate_google_event_publish_url( $meeting, $user );
    }

    my $partner_id = $self->_get_partner_id_for_meeting( $meeting );
    my $partner = $partner_id ? $self->PARTNERS_BY_ID->{$partner_id} : undef;

    my $disable_advertisements = 0;
    if ( $partner ) {
        $disable_advertisements = $self->_get_note( disable_advertisements => $partner ) ? 1 : 0,
    }

    my $meeting_has_ended = ( $meeting->begin_date && $meeting->end_date && time > $meeting->end_date ) ? 1 : 0;

    return {
        time_zone => $time_zone,
        ics_url => $ics_url,
        gcal_url => $gcal_url,
        allow_meeting_cancel => ( $self->_get_note( allow_meeting_cancel => $meeting ) && ! $meeting_has_ended ) ? 1 : 0,
        meeting_cancel_url => $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, { meeting_cancel_request => 1 } ),
        disable_advertisements => $disable_advertisements,
        meeting_title => $self->_meeting_title_string( $meeting ),
        meeting_location => $meeting->location_name,
        meeting_location_string => $self->_meeting_location_string( $meeting ),
        meeting_participants => $meeting_participants || $self->_gather_meeting_participant_info( $meeting ),
        meeting_time => $self->_form_meeting_time_string( $meeting, $user ),
        meeting_url => $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host ),
        meeting_email => $meeting_email || $self->_get_meeting_email( $meeting ),
        meeting_unsubscribe_url => $self->_get_meeting_user_unsubscribe_url( $meeting, $user, $meeting->domain_id, $domain_host ),
        meeting_rsvp_yes_url => $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, { rsvp => 'yes' } ),
        meeting_rsvp_no_url => $self->_get_meeting_user_url( $meeting, $user, $meeting->domain_id, $domain_host, { rsvp => 'no' } ),
        from_swipetomeet => $self->_meeting_has_swipetomeet( $meeting ),
        %{ $self->_gather_theme_mail_template_params_for_meeting( $meeting, $domain_host ) },
    };
}

sub _gather_meeting_user_template_mail_base_params {
    my ( $self, $meeting, $user, $template ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $user = Dicole::Utils::User->ensure_object( $user );
    $template = 'meetings_' . $template unless $template =~ /^meetings_/;

    return {
        user => $user,
        reply_to => $self->_get_meeting_user_email_string( $meeting, $user ),

        domain_id => $meeting->domain_id,
        partner_id => $self->_get_partner_id_for_meeting( $meeting ),
        group_id => $meeting->group_id,

        meeting_details => {
            meeting_id => $meeting->id,
            current_scheduling_id => $self->_get_note( current_scheduling_id => $meeting ) || 0,
        },

        template_key_base => $template,
    };
}

sub _connection_is_https { Dicole::URL->get_server_port == 443 }

sub _redirect_to_https {
    my ($self, $meeting) = @_;

    my $host = $meeting
        ? $self->_get_host_for_meeting($meeting, 443)
        : $self->_get_host(443);

    die $self->redirect($host . $self->derive_full_url);
}

sub _redirect_to_http {
    my ($self, $meeting) = @_;

    my $host = $meeting
        ? $self->_get_host_for_meeting($meeting, 80)
        : $self->_get_host(80);

    die $self->redirect($host . $self->derive_full_url);
}

sub _get_host {
    my ($self, $port) = @_;

    return CTX->request->auth_user_id
        ? $self->_get_host_for_user(CTX->request->auth_user, undef, $port)
        : Dicole::URL->get_domain_name_url(CTX->request->server_name, $port);
}

sub _redirect_unless_https {
    my ($self, $meeting) = @_;

    die $self->_redirect_to_https($meeting) unless $self->_connection_is_https;

    return;
}

sub _redirect_unless_http {
    my ($self, $meeting) = @_;

    die $self->_redirect_to_http($meeting) if $self->_connection_is_https;

    return;
}

sub _generate_google_event_publish_url {
    my ( $self, $event, $user ) = @_;

    my $domain_id = $event->domain_id;
    return '' unless $event->begin_date;

    my $inmail_address = $self->_get_meeting_email( $event, $domain_id );
    my $meeting_enter_url = $self->_get_meeting_enter_url( $event );

        my $description = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_ics_description_text_template' ),{
            meeting_email => $inmail_address,
            meeting_url => $meeting_enter_url,
        }, { user => $user }
    );

    my $title = $self->_meeting_title_string( $event );
    my $begin_date = $event->begin_date;
    my $end_date = $event->end_date;
    my $location = $event->location_name;

    return $self->_generate_google_publish_url( $title, $begin_date, $end_date, $location, $description );
}

sub _generate_google_publish_url {
    my ( $self, $title, $begin_date, $end_date, $location, $description ) = @_;

    return '' unless $begin_date;

    my $start_time = DateTime->from_epoch( epoch => $begin_date );
    $start_time->set_time_zone( 'UTC' );

    my $s = $start_time;
    $start_time = $s->year . sprintf("%02d", $s->month) . sprintf("%02d", $s->day) . 'T' . sprintf("%02d", $s->hour) . sprintf("%02d", $s->minute) . sprintf("%02d", $s->second) . 'Z';

    my $end_time = DateTime->from_epoch( epoch => $end_date );
    $end_time->set_time_zone( 'UTC' );
    my $e = $end_time;
    $end_time = $e->year . sprintf("%02d", $e->month) . sprintf("%02d", $e->day) . 'T' . sprintf("%02d", $e->hour) . sprintf("%02d", $e->minute) . sprintf("%02d", $e->second) . 'Z';

    my $query = {
        action => 'TEMPLATE',
        text => $title,
        dates => $start_time . '/' . $end_time,
        details => $description,
        location => $location,
        trp => 'true',
        sprop => 'http%3A%2F%2Fmeetin.gs',
        sprop => 'name:Meetin.gs',
    };

    my $url = URI::URL->new( 'http://www.google.com/calendar/event' );
    $url->query_form( $query );

    return $url->as_string;
}

sub _google_client {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $user = $user ? Dicole::Utils::User->ensure_object( $user ) : CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $o = Dicole::Utils::OAuth::Client->new(
        tokens => {
            consumer_key    => $self->SOCIAL_APP_KEYS->{google_key},
            consumer_secret => $self->SOCIAL_APP_KEYS->{google_secret},
            $opts->{new_request} ? () : (
                request_token =>  $self->_get_note_for_user( 'meetings_google_request_token', $user, $domain_id ),
                request_token_secret => $self->_get_note_for_user( 'meetings_google_request_token_secret', $user, $domain_id ),
                access_token => $self->_get_note_for_user( 'meetings_google_access_token', $user, $domain_id ),
                access_token_secret => $self->_get_note_for_user( 'meetings_google_access_token_secret', $user, $domain_id ),
            ),
        },

        urls => {
            request_token_url => 'https://www.google.com/accounts/OAuthGetRequestToken',
            authorization_url => 'https://www.google.com/accounts/OAuthAuthorizeToken',
            access_token_url => 'https://www.google.com/accounts/OAuthGetAccessToken',
        },
        protocol_version => '1.0a',
    );

    return $o;
}

sub _twitter_client {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $user ||= $user ? Dicole::Utils::User->ensure_object( $user ) : CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $o = Dicole::Utils::OAuth::Client->new(
        tokens => {
            consumer_key    => $self->SOCIAL_APP_KEYS->{twitter_key},
            consumer_secret => $self->SOCIAL_APP_KEYS->{twitter_secret},
            $opts->{new_request} ? () : (
                request_token =>  $self->_get_note_for_user( 'meetings_twitter_request_token', $user, $domain_id ),
                request_token_secret => $self->_get_note_for_user( 'meetings_twitter_request_token_secret', $user, $domain_id ),
                access_token => $self->_get_note_for_user( 'meetings_twitter_access_token', $user, $domain_id ),
                access_token_secret => $self->_get_note_for_user( 'meetings_twitter_access_token_secret', $user, $domain_id ),
            ),
        },
        urls => {
            request_token_url => 'https://api.twitter.com/oauth/request_token',
            authorization_url => 'https://api.twitter.com/oauth/authorize',
            access_token_url => 'https://api.twitter.com/oauth/access_token',
        },
        protocol_version => '1.0a',
    );

    return $o;
}

sub _facebook_client {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $user ||= $user ? Dicole::Utils::User->ensure_object( $user ) : CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $o = Dicole::Utils::OAuth::Client->new(
        tokens => {
            consumer_key    => $self->SOCIAL_APP_KEYS->{facebook_key},
            consumer_secret => $self->SOCIAL_APP_KEYS->{facebook_secret},
            $opts->{new_request} ? () : (
                request_token =>  $self->_get_note_for_user( 'meetings_facebook_request_token', $user, $domain_id ),
                request_token_secret => $self->_get_note_for_user( 'meetings_facebook_request_token_secret', $user, $domain_id ),
                access_token => $self->_get_note_for_user( 'meetings_facebook_access_token', $user, $domain_id ),
                access_token_secret => $self->_get_note_for_user( 'meetings_facebook_access_token_secret', $user, $domain_id ),
            ),
        },
        urls => {
            request_token_url => 'https://api.linkedin.com/uas/oauth/requestToken',
            authorization_url => 'https://www.linkedin.com/uas/oauth/authenticate',
            access_token_url => 'https://api.linkedin.com/uas/oauth/accessToken',
        },
        protocol_version => '1.0a',
    );

    return $o;
}

sub _facebook_code_to_access_token {
    my ( $self, $code, $redirect_uri ) = @_;

    my $http_params = {
        client_id => '181390985231333',
        client_secret => 'x',
        code => $code,
        redirect_uri => $redirect_uri,
    };

    my $url = new URI('https://graph.facebook.com/oauth/access_token');
    $url->query_form( $http_params );

    my $data = Dicole::Utils::HTTP->get( "".$url, $http_params );
    my ($at ) = $data =~ /access_token=([^\&]*)/;

    return $at
}

sub _facebook_info_for_access_token {
    my ( $self, $at ) = @_;

    my $http_params = {
        access_token => $at,
    };

    my $url = new URI('https://graph.facebook.com/me');
    $url->query_form( $http_params );

    my $data_json = Dicole::Utils::HTTP->get( $url, $http_params );

    my $data = Dicole::Utils::JSON->decode( $data_json );

    return $data;
}

sub _google_code_to_access_and_refresh_tokens {
    my ( $self, $code, $redirect_uri ) = @_;

    my $result = Dicole::Utils::HTTP->post( 'https://accounts.google.com/o/oauth2/token', {
        code => $code,
        client_id => '584216729178.apps.googleusercontent.com',
        client_secret => 'x',
        redirect_uri => $redirect_uri || 'postmessage',
        grant_type => 'authorization_code',
    } );

    my $result_data = Dicole::Utils::JSON->decode( $result );

    return ( $result_data->{access_token}, $result_data->{refresh_token} );
}

sub _google_info_for_access_token {
    my ( $self, $at ) = @_;

    my $google_url = URI::URL->new( 'https://www.googleapis.com/oauth2/v1/userinfo' );
    $google_url->query_form( { access_token => $at } );

    my $response = Dicole::Utils::HTTP->get( $google_url->as_string );

    return Dicole::Utils::JSON->decode( $response );
}

sub _linkedin_client {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $user ||= $user ? Dicole::Utils::User->ensure_object( $user ) : CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $o = Dicole::Utils::OAuth::Client->new(
        tokens => {
            consumer_key    => $self->SOCIAL_APP_KEYS->{linkedin_key},
            consumer_secret => $self->SOCIAL_APP_KEYS->{linkedin_secret},
            $opts->{new_request} ? () : (
                request_token =>  $self->_get_note_for_user( 'meetings_linkedin_request_token', $user, $domain_id ),
                request_token_secret => $self->_get_note_for_user( 'meetings_linkedin_request_token_secret', $user, $domain_id ),
                access_token => $self->_get_note_for_user( 'meetings_linkedin_access_token', $user, $domain_id ),
                access_token_secret => $self->_get_note_for_user( 'meetings_linkedin_access_token_secret', $user, $domain_id ),
            ),
        },
        # use /authenticate instead of /authorize, so users will be loggedin isntantly
        # if loggedin to linkedin, granted access and token not expired
        urls => {
            request_token_url => 'https://api.linkedin.com/uas/oauth/requestToken',
            authorization_url => 'https://www.linkedin.com/uas/oauth/authenticate',
            access_token_url => 'https://api.linkedin.com/uas/oauth/accessToken',
        },
        protocol_version => '1.0a',
    );

    return $o;
}

sub _dropbox_client {
    my ( $self, $user, $domain_id, $opts ) = @_;

    $user ||= $user ? Dicole::Utils::User->ensure_object( $user ) : CTX->request->auth_user;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $o = Dicole::Utils::OAuth::Client->new(
        tokens => {
            consumer_key    => CTX->server_config->{dicole}{dropbox_key},
            consumer_secret => CTX->server_config->{dicole}{dropbox_secret},
            $opts->{new_request} ? () : (
                request_token =>  $self->_get_note_for_user( 'meetings_dropbox_request_token', $user, $domain_id ),
                request_token_secret => $self->_get_note_for_user( 'meetings_dropbox_request_token_secret', $user, $domain_id ),
                access_token => $self->_get_note_for_user( 'meetings_dropbox_access_token', $user, $domain_id ),
                access_token_secret => $self->_get_note_for_user( 'meetings_dropbox_access_token_secret', $user, $domain_id ),
            ),
        },
        urls => {
            request_token_url => 'https://api.dropbox.com/1/oauth/request_token',
            authorization_url => 'https://www.dropbox.com/1/oauth/authorize',
            access_token_url => 'https://api.dropbox.com/1/oauth/access_token',
        },
        protocol_version => '1.0',
    );

    return $o;
}

sub _li_call_api {
    my ( $self, $user, $domain_id, $url, $method, $params ) = @_;

    my $o = $self->_linkedin_client( $user, $domain_id );
    return $o->make_restricted_request( $url, $method || 'GET', %{ $params || {} } );
}

sub _go2_call_api {
    my ( $self, $user, $domain_id, $url, $method, $params, $opts ) = @_;

    $opts = {
        timeout => 15,
        return_response => 0,
        skip_decode => 0,
        die_on_refresh => 0,
        %{ $opts || {} },
    };

    $method ||= 'GET';
    $params ||= {};

    my $access_token = $self->_get_note_for_user( meetings_google_oauth2_access_token => $user, $domain_id );
    my $access_token_expires = $self->_get_note_for_user( meetings_google_oauth2_at_expires => $user, $domain_id );

    if ( ! $access_token || ! $access_token_expires || time > $access_token_expires ) {
        $access_token = $self->_go2_refresh_user_access_token( $user, $domain_id );
    }

    my $response = undef;
    my $http_params = { %$params, access_token => $access_token };

    if ( lc ( $method ) eq 'get' ) {
        my $google_url = URI::URL->new( $url );

        $google_url->query_form( $http_params );

        $response = Dicole::Utils::HTTP->get_response( $google_url->as_string, $opts->{timeout} );
    }
    elsif ( lc ( $method ) eq 'post' ) {
        $response = Dicole::Utils::HTTP->post_response( $url, $http_params, $opts->{timeout} );
    }

    if ( $response->is_error ) {
        die $response->status_line unless $response->code == 400;
        die "Invalid token on refresh" if $opts->{die_on_refresh};

        $self->_set_note_for_user( meetings_google_oauth2_access_token => undef, $user, $domain_id, { skip_save => 1 } );

        return $self->_go2_call_api( $user, $domain_id, $url, $method, $params, { %$opts, die_on_refresh => 1 } );
    }

    return $response if $opts->{return_response};

    my $content = $response->decoded_content(charset => 'none');

    return $opts->{skip_decode} ? $content : Dicole::Utils::JSON->decode( $content );
}

sub _go2_refresh_user_access_token {
    my ( $self, $user, $domain_id ) = @_;

    my $refresh_token = $self->_get_note_for_user( meetings_google_oauth2_refresh_token => $user, $domain_id );

    die unless $refresh_token;

    my $response = Dicole::Utils::HTTP->post_response( 'https://accounts.google.com/o/oauth2/token', {
            refresh_token => $refresh_token,
            client_id => '584216729178.apps.googleusercontent.com',
            client_secret => 'x',
            grant_type => 'refresh_token',
        } );

    my $result_data = Dicole::Utils::JSON->decode( $response->decoded_content( charset => 'none') );

    # API docs lie about this one...
#    die unless ref( $result_data ) eq 'HASH' && $result_data->audience eq '584216729178.apps.googleusercontent.com';
    die unless $result_data->{access_token};

    $self->_set_note_for_user( meetings_google_oauth2_access_token => $result_data->{access_token}, $user, $domain_id, { skip_save => 1 } );

    my $epoch = time + ( $result_data->{expires_in} || 0 ) - 5;
    $self->_set_note_for_user( meetings_google_oauth2_at_expires => $epoch, $user, $domain_id );

    return $result_data->{access_token};
}

sub _go_call_api {
    my ( $self, $user, $domain_id, $url, $method, $params ) = @_;

    if ( $self->_get_note_for_user( meetings_google_oauth2_refresh_token => $user, $domain_id ) ) {
        return $self->_go2_call_api( $user, $domain_id, $url, $method, $params, { return_response => 1 } );
    }

    $method ||= 'GET';
    $params ||= {};

    $params->{ key } = $self->SOCIAL_APP_KEYS->{google_apikey};

    my $o = $self->_google_client( $user, $domain_id );
    return $o->make_restricted_request( $url, $method, %$params );
}

sub _fetch_user_info_from_google {
    my ( $self, $user, $domain_id ) = @_;

    my $response = $self->_go_call_api( $user, $domain_id, 'https://www.googleapis.com/oauth2/v1/userinfo', 'GET', { alt => 'json' } );
    return Dicole::Utils::JSON->decode( $response->decoded_content( charset => 'none') );
}

sub _fetch_user_contacts_from_google {
    my ( $self, $user, $domain_id ) = @_;

    my $items = {};
    my $url = 'https://www.google.com/m8/feeds/contacts/default/full?v=3&max-results=500';

    while ( $url ) {
        my $data = $self->_fetch_user_contacts_batch_from_google( $user, $domain_id, $url );

        for my $id ( keys %{ $data->{entry} || {} } ) {
            my $entry = $data->{entry}->{ $id };
            next unless $entry->{"gd:email"};

            my $stripped = {};
            for my $key ( qw( gd:email gd:name title ) ) {
                $stripped->{ $key } = $entry->{ $key };
            }

            for my $link ( @{ ref( $entry->{link} ) eq 'ARRAY' ? $entry->{link} : []  } ) {
                next unless $link->{rel} eq 'http://schemas.google.com/contacts/2008/rel#photo';
                $stripped->{link} ||= [];
                push @{ $stripped->{link} }, $link;
            }

            $items->{ $id } = $stripped;
        }

        $url = '';
        for my $link ( @{ $data->{link} || [] } ) {
            next unless $link->{rel} eq 'next';
            $url = $link->{href}
        }
    }
    return { entry => $items };
}

sub _fetch_user_contacts_batch_from_google {
    my ( $self, $user, $domain_id, $url ) = @_;

    my $uri = URI::URL->new( $url );
    my %query = $uri->query_form;
    $uri->query_form( {} );
    my $response = $self->_go_call_api( $user, $domain_id, $uri->as_string, 'GET', \%query );
    my $xs = new XML::Simple;
    return $xs->XMLin( $response->decoded_content( charset => 'none') );
}

sub _fetch_user_upcoming_primary_events_from_google {
    my ( $self, $user, $domain_id, $opts ) = @_;

    return $self->_fetch_user_upcoming_events_from_google_calendar( $user, $domain_id, 'primary', $opts );
}

# TODO: do multi-page fetches if result set does not fit in the first page. currently just fetches once with maxResults 1000
sub _fetch_user_upcoming_events_from_google_calendar {
    my ( $self, $user, $domain_id, $calendar_id, $opts ) = @_;

    $opts = {
        force_reload => 0, # NOTE: not implemented - always forces reload
        %{ $opts || {} },
    };

    my $calendar_uri = 'https://www.googleapis.com/calendar/v3/calendars/' . URI::Encode::uri_encode( $calendar_id ) . '/events';

    my $limit = $opts->{start_epoch} ?
        Dicole::Utils::Date->epoch_to_datetime( $opts->{start_epoch}, 'UTC', $user->language )
        :
        Dicole::Utils::Date->datetime_to_day_start_datetime(
            Dicole::Utils::Date->epoch_to_datetime( time - 24*60*60, 'UTC', $user->language )
        );

    my $start_limit = $limit.'Z';

    $limit = $opts->{end_epoch} ?
        Dicole::Utils::Date->epoch_to_datetime( $opts->{end_epoch}, 'UTC', $user->language )
        :
        Dicole::Utils::Date->datetime_to_day_start_datetime(
            Dicole::Utils::Date->epoch_to_datetime( time + 3*30*24*60*60, 'UTC', $user->language )
        );

    my $end_limit = $limit.'Z';
    my $result = $self->_go2_call_api( $user, $domain_id, $calendar_uri, 'GET', { timeMin => $start_limit, timeMax => $end_limit, maxResults => '1000', singleEvents => 'true', showHiddenInvitations => 'true' } );

    return $result;
}

sub _fetch_user_calendar_list_from_google {
    my ( $self, $user, $domain_id, $calendar_id, $opts ) = @_;

    $opts = {
        force_reload => 0, # NOTE: not implemented - always forces reload
        %{ $opts || {} },
    };

    my $calendars_uri = 'https://www.googleapis.com/calendar/v3/users/me/calendarList';

    my $result = $self->_go2_call_api( $user, $domain_id, $calendars_uri, 'GET', { minAccessRole => 'reader' } );

    return $result;
}

sub _gather_theme_mail_template_params_for_meeting {
    my ( $self, $meeting, $domain_host, $creator_user ) = @_;

    $domain_host ||= $self->_get_host_for_meeting( $meeting, 443 );
    $creator_user ||= $meeting->creator_id ? Dicole::Utils::User->ensure_object( $meeting->creator_id ) : undef;

    my $partner = $self->_get_partner_for_meeting( $meeting );

    $creator_user = undef if $partner && $self->_get_note( override_pro_themes => $partner );

    return $self->_gather_theme_mail_template_params_for_user( $creator_user, $meeting->domain_id, $domain_host, $meeting->id )
        if $creator_user && $self->_user_is_pro( $creator_user, $meeting->domain_id );

    return $self->_gather_theme_mail_template_params_for_partner( $partner, $domain_host ) if $partner;

    return {
        server_host => $domain_host
    };
}

sub _gather_theme_mail_template_params_for_user {
    my ( $self, $user, $domain_id, $domain_host, $meeting_id ) = @_;

    $domain_host ||= $self->_get_host_for_user( $user, $domain_id, 443 );

    my $theme = $self->_get_note_for_user( pro_theme => $user, $domain_id );
    my $header = $self->_get_note_for_user( pro_theme_header => $user, $domain_id );

    my $set_header_image = $self->_get_note_for_user( pro_theme_header_image => $user, $domain_id );
    my $image_url = '';
    if ( $set_header_image ) {
        if ( $meeting_id ) {
            $image_url = Dicole::URL->from_parts(
                domain_id => $domain_id, action => 'meetings_raw', task => 'authorized_meeting_header_image',
                additional => [ $meeting_id, $user->id, $self->_generate_meeting_image_digest_for_user( $meeting_id, $user ) . '.png' ]
            );
        }
        else {
            $image_url = Dicole::URL->from_parts(
                domain_id => $domain_id, action => 'meetings_raw', task => 'authorized_user_header_image',
                additional => [ $user->id, $self->_generate_header_image_digest_for_user( $user ) . '.png' ]
            );
        }
    }

    return $self->_form_theme_mail_template_params(
        $domain_host, $theme, $header, $image_url
    );
}

sub _gather_theme_mail_template_params_for_partner {
    my ( $self, $partner, $domain_host ) = @_;

    $domain_host ||= $self->_get_host_for_partner( $partner, 443 );

    my $theme = $self->_get_note( pro_theme => $partner );
    my $header = $self->_get_note( pro_theme_header => $partner );

    my $set_header_image = $self->_get_note( pro_theme_header_image => $partner );
    my $image_url ||= $set_header_image;

    my $partner_name = $partner->name;

    my $additional = {};
    $additional->{hide_app_promotion} = 1 if $self->_get_note( hide_app_promiotion => $partner ) || $self->_get_note( hide_app_promotion => $partner );

    return $self->_form_theme_mail_template_params(
        $domain_host, $theme, $header, $image_url, $partner_name, $additional
    );
}

sub _form_theme_mail_template_params {
    my ( $self, $domain_host, $theme, $header, $image_url, $image_alt, $additional_params ) = @_;

    if ( $image_url && $image_url =~ /^\// ) {
        $image_url = $domain_host . $image_url;
    }

    my %header_names = (
        inverted => 'dark',
        normal => 'gray',
    );

    return {
        server_host => $domain_host,
        theme_color_name => $theme || '',
        header_color_name => $header_names{ $header || '' } || '',
        logo_image => $image_url || '',
        logo_alt => $image_alt,
        %{ $additional_params || {} },
    };
}


sub _generate_theme_css_url_for_meeting {
    my ( $self, $meeting, $creator_user ) = @_;

    $creator_user ||= Dicole::Utils::User->ensure_object( $meeting->creator_id );

    return $self->_generate_theme_css_url_for_user( $creator_user, $meeting->domain_id )
        if $self->_user_is_pro( $creator_user, $meeting->domain_id );

    my $partner_id = $self->_get_partner_id_for_meeting( $meeting );

    return $self->_generate_theme_css_url_for_partner( $self->PARTNERS_BY_ID->{ $partner_id } )
        if $partner_id;

    return $self->_generate_theme_css_url;
}

sub _generate_theme_css_url_for_user {
    my ( $self, $theme_user, $domain_id ) = @_;

    my $theme = $self->_get_note_for_user( pro_theme => $theme_user, $domain_id );
    my $header = $self->_get_note_for_user( pro_theme_header => $theme_user, $domain_id );
    my $footer = $self->_get_note_for_user( pro_theme_footer => $theme_user, $domain_id );

    return $self->_generate_theme_css_url( $theme, $header, $footer );
}

sub _generate_theme_css_url_for_partner {
    my ( $self, $partner ) = @_;

    my $theme = $self->_get_note( pro_theme => $partner );
    my $header = $self->_get_note( pro_theme_header => $partner );
    my $footer = $self->_get_note( pro_theme_footer => $partner );

    return $self->_generate_theme_css_url( $theme, $header, $footer );
}

sub _generate_theme_css_url {
    my ( $self, $theme, $header, $footer ) = @_;

    $theme ||= 'blue';

    return "/css/meetings/$theme.css";
}

sub _create_theme_extra_style_for_user {
    my ( $self, $theme_user, $opts ) = @_;

    $opts ||= {};

    my $set_header_image = $self->_get_note_for_user( pro_theme_header_image => $theme_user );
    my $header_image_url = ( $set_header_image && $set_header_image =~ /^\d+$/ ) ?
       $self->derive_url( task => $opts->{use_meeting_theme} ? 'meeting_theme_header_image' : 'own_theme_header_image' )
       :
       $set_header_image;

    if ( $opts->{skip_background} ) {
        return $self->_create_theme_extra_style( $header_image_url );
    }

    my $set_background_image = $self->_get_note_for_user( pro_theme_background_image => $theme_user );
    my $background_image_url = ( $set_background_image && $set_background_image =~ /^\d+$/ ) ?
       $self->derive_url( task => $opts->{use_meeting_theme} ? 'meeting_theme_background_image' : 'own_theme_background_image' )
       :
       $set_background_image;

    my $background_position = $self->_get_note_for_user( pro_theme_background_position => $theme_user );

    return $self->_create_theme_extra_style( $header_image_url, $background_image_url, $background_position );
}

sub _create_theme_extra_style_for_partner {
    my ( $self, $partner, $opts ) = @_;

    $opts ||= {};

    my $set_header_image = $self->_get_note( pro_theme_header_image => $partner );
    my $header_image_url = $set_header_image;

    if ( $opts->{skip_background} ) {
        return $self->_create_theme_extra_style( $header_image_url );
    }

    my $set_background_image = $self->_get_note( pro_theme_background_image => $partner );
    my $background_position = $self->_get_note( pro_theme_background_position => $partner );
    my $background_image_url = $set_background_image;

    return $self->_create_theme_extra_style( $header_image_url, $background_image_url, $background_position );
}

sub _create_theme_extra_style {
    my ( $self, $header_image_url, $background_image_url, $background_position ) = @_;

    my $extra_style = '';
    $extra_style .= 'div#header-wrapper div#header div#header-logo h1, div#header-wrapper div#header div#header-logo h1.pro { background: url("'. $header_image_url .'") no-repeat left top; } ' if $header_image_url;

    if ( $background_image_url ) {
        $extra_style .= 'div.content { background-image: url("'. $background_image_url .'")' .'; background-repeat:no-repeat; background-size:cover; -moz-background-size:cover; background-attachment:fixed; } ';
    }

    return $extra_style;
}

sub _generate_sorted_timezone_choices_and_data {
    my ( $self ) = @_;

    my $timezone_choices = DateTime::TimeZone->all_names;
    push @$timezone_choices, 'UTC';
    my $timezone_data = { map { $_ => Dicole::Utils::Date->timezone_info( $_ ) } @$timezone_choices };

    $timezone_choices = [ sort { $timezone_data->{$a}->{offset_value} <=> $timezone_data->{$b}->{offset_value} } @$timezone_choices ];

    return { result => [ $timezone_choices, $timezone_data ] };
}

sub _sorted_timezone_choices_and_data {
    my ( $self ) = @_;

    my $data = Dicole::Cache->fetch_or_store( 'sorted_timezone_choices_and_data', sub {
        return $self->_generate_sorted_timezone_choices_and_data;
    }, { expires => 24*60*60, no_domain_id => 1, no_group_id => 1 } );

    return @{ $data->{result} };
}

sub _user_is_partner_booker {
    my ( $self, $user, $partner ) = @_;

    $partner ||= $self->param('partner');
    return 0 unless $partner;

    if ( $user && $user->email ) {
        my $bookers = $self->_get_note( booker_emails => $partner );
        for my $em ( @{ $bookers || [] } ) {
            next unless lc( $em ) eq lc( $user->email );
            return 1;
        }
    }

    return 0;
}

sub _user_is_partner_visitor {
    my ( $self, $user, $partner ) = @_;

    $partner ||= $self->param('partner');
    return 0 unless $partner;
    return 0 unless $self->_get_note( track_visitors => $partner );

    if ( $user && $user->email ) {
        my $hosts = $self->_get_note( non_visitor_emails => $partner );
        for my $em ( @{ $hosts || [] } ) {
            next unless lc( $em ) eq lc( $user->email );
            return 0;
        }
    }

    return 1;
}

sub _set_controller_variables {
    my ( $self, $globals, $title_front, $meeting, $creator_user, $head_widgets ) = @_;

    $head_widgets ||= [];

    my $user_lang = $self->language || 'en';
    push @$head_widgets, Dicole::Widget::Javascript->new( src => "/js/dicole/meetings/lang/$user_lang.js" );

    my $dts = Dicole::Utils::Date->epoch_to_date_and_time_strings( time + 60*60*12, undef, undef, 'ampm' );

    $globals = {
        %$globals,
        meetings_lang                           => $user_lang,
        meetings_stripe_key                     => CTX->server_config->{dicole}{stripe_publishable_key},
        meetings_initial_date_value             => $dts->[0],
        meetings_initial_time_value             => '12:00',
        meetings_initial_duration_value         => '60',
        meetings_initial_duration_hours_value   => '1',
        meetings_initial_duration_minutes_value => '00',
        meetings_ensure_user_caches_url         => $self->derive_url(action => 'meetings_json', task => 'ensure_user_caches' ),
        meetings_refresh_facebook_friends_url   => $self->derive_url(action => 'meetings_json', task => 'refresh_facebook_friends'),
        meetings_go_pro_url                     => $self->derive_url(action => 'meetings_paypaljson', task => 'start'),
        meetings_ics_feed_instructions_data_url => $self->derive_url(action => 'meetings_json', task => 'calendar_data', additional => [] ),
    };

    if ( CTX->request->auth_user_id ) {
        $globals->{meetings_feature_quickmeet} = CTX->request->auth_user->email =~ /\@(meetin\.gs|dicole\.com)$/ ? 1 : 0;
    }

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $body_classes = '';
    $globals->{meetings_extra_meeting_links} = [];

    if ( my $agents = $self->_get_note_for_user( 'meetings_supervised_agents' => $user, $domain_id ) ) {
        push @{ $globals->{meetings_extra_meeting_links} }, {
            title => 'Poissaolot',
            url => '/meetings/agent_absences'
        };
    }
    if ( my $areas = $self->_get_note_for_user( 'meetings_agent_admin_areas' => $user, $domain_id ) ) {
        push @{ $globals->{meetings_extra_meeting_links} }, {
            title => 'Käyttäjähallinta',
            url => '/meetings/agent_admin'
        };
    }

    if ( my $partner = $self->param('partner') ) {
        if ( my $return_domain = $self->_get_note( admin_return_domain => $partner ) ) {
            my $return = 'https://' . $return_domain . '/meetings/login';
            $globals->{meetings_admin_return_link} = '/xlogout?url_after_logout=' . $return;
        }

        $globals->{meetings_service_name} = $self->_get_note( custom_service_name => $partner );
        $globals->{meetings_service_name} ||= 'Meetin.gs';

        my $user_is_booker = $self->_user_is_partner_booker( $user ) ? 1 : 0;

        if ( $user_is_booker ) {
            push @{ $globals->{meetings_extra_meeting_links} }, {
                title => 'Varauskalenteri',
                url => '/meetings/agent_booking'
            };
        }

        my $user_shared_account_data = $self->_get_note_for_user( 'meetings_shared_account_data', $user, $domain_id ) || [];

        my $partner_shared_accounts = $self->_get_note( shared_admin_accounts => $partner );
        my $psamap = { map { lc( $_ ) => 1 } @$partner_shared_accounts };

        for my $account_data ( @$user_shared_account_data ) {
            next unless $psamap->{ lc( $account_data->{email} ) };

            push @{ $globals->{meetings_extra_meeting_links} }, {
                title => 'Ylläpito',
                url => Dicole::URL->from_parts(
                    action => 'meetings',
                    task => 'agent_manage',
                    domain_id => $domain_id,
                ),
            };

            last;
        }

        $globals->{meetings_user_is_visitor} = $self->_user_is_partner_visitor( $user ) ? 1 : 0;

        if ( my $logo_link = $self->_get_note( visitor_logo_link => $partner ) ) {
            if ( $globals->{meetings_user_is_visitor} ) {
                $self->param( 'override_logo_link', $logo_link );
            }
        }

        $body_classes = $self->_get_note( body_classes => $partner ) || '';

        if ( $user_is_booker ) {
            $body_classes = join( " ", ( $body_classes || (), 'agent_booker_extras' ) ) unless
                $self->_get_note_for_user( 'meetings_disable_agent_booker_exras', $user, $domain_id );
        }

        if ( $globals->{meetings_user_is_visitor} ) {
            $body_classes = join( " ", ( $body_classes || (), 'visitor_user_extras' ) );
        }
    }

    $globals->{meetings_refresh_facebook_friends}
        = $user && $user->facebook_user_id
                && Dicole::Utils::User->get_domain_note(
                    $user,
                    Dicole::Utils::Domain->guess_current_id,
                    'facebook_timestamp'
                ) < time - (CTX->server_config->{dicole}{refresh_facebook_friends_timeout_seconds} || 60*60);

    my $title = join (' | ', ( $title_front || (), 'Meetin.gs' ) );
    CTX->controller->add_content_param( 'page_title', $title );

    my $theme_css = $self->_generate_theme_css_url;
    my $extra_style = '';

    if ( $meeting ) {
        my $theme_user = $creator_user || ( $meeting && $meeting->creator_id ) ? Dicole::Utils::User->ensure_object( $meeting->creator_id ) : undef;
        my $partner = $self->_get_partner_for_meeting( $meeting );

        $theme_user = undef if $partner && $self->_get_note( override_pro_themes => $partner );

        if ( $theme_user && $self->_user_is_pro( $theme_user, $domain_id ) ) {
            $theme_css = $self->_generate_theme_css_url_for_user( $theme_user, $domain_id );
            $extra_style = $self->_create_theme_extra_style_for_user( $theme_user, { use_meeting_theme => 1 } );
        }
        elsif ( $partner ) {
            $theme_css = $self->_generate_theme_css_url_for_partner( $partner );
            $extra_style = $self->_create_theme_extra_style_for_partner( $partner );
        }
    }
    elsif ( $self->task !~ /^(meetme_config|meet|)$/ ) {
        my $theme_user = $user;
        my $partner = $self->param('partner');

        $theme_user = undef if $partner && $self->_get_note( override_pro_themes => $partner );

        if ( $theme_user && $self->_user_is_pro( $theme_user, $domain_id ) ) {
            $theme_css = $self->_generate_theme_css_url_for_user( $theme_user, $domain_id );
            $extra_style = $self->_create_theme_extra_style_for_user( $theme_user );
        }
        elsif ( $partner ) {
            $theme_css = $self->_generate_theme_css_url_for_partner( $partner );
            $extra_style = $self->_create_theme_extra_style_for_partner( $partner );
        }
    }
    else {
        my $theme_user = $user;
        my $partner = $self->param('partner');

        $theme_user = undef if $partner && $self->_get_note( override_pro_themes => $partner );

        if ( $theme_user && $self->_user_is_pro( $theme_user, $domain_id ) ) {
            $extra_style = $self->_create_theme_extra_style_for_user( $theme_user, { skip_background => 1 } );
        }
        elsif ( $partner ) {
            $extra_style = $self->_create_theme_extra_style_for_partner( $partner, { skip_background => 1 } );
        }
    }

    if ( my $logo_link = $self->param( 'override_logo_link' ) ) {
        $globals->{meetings_logo_link} = $logo_link;
    }

    CTX->controller->init_common_variables(
        body_classes => $body_classes,
        alternative_navigation => ( $self->task =~ /^(new_meeting|thanks|already_a_user|privacy_policy|takedown_policy|terms_of_service|beta_signup|the_next_web|thank_you|thanks_free)$/ ) ? 'meetings_external_navigation' : ( $self->task =~ /^(new_user|wizard|wizard_profile|new_invited_user|ext_login|enter_meeting|enter_meeting|login|logout|connect_service_account|verify_email)$/ ) ? 'meetings_clean_navigation' : ( $self->task =~ /^(matchmaking_registration|matchmaking_calendar|matchmaking_list|validate_event_matchmaker|event_matchmaker_validated|matchmaking_user_register_success|matchmaking_register_success|matchmaking_limit_reached|matchmaking_admin_editor|matchmaking_success)$/ ) ? 'meetings_matchmaking_navigation' : '',
        replace_dicole_bundle => CTX->server_config->{dicole}{uncompressed_dojo} ? '/js/dojo/dicole_meetings.js.uncompressed.js' : '/js/dojo/dicole_meetings.js',
        disable_default_requires => 1,
        head_widgets => [
            Dicole::Widget::Javascript->new( src => '/js/tinymce_meetings/tinymce.min.js' ),
            @$head_widgets,
            Dicole::Widget::Raw->new( raw => join "", (
                '<link rel="apple-touch-icon" href="/images/meetings/touch-icon-iphone.png">',
                '<link rel="apple-touch-icon" sizes="72x72" href="/images/meetings/touch-icon-ipad.png">',
                '<link rel="apple-touch-icon" sizes="114x114" href="/images/meetings/touch-icon-iphone4.png">',
                '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
                '<meta name="apple-mobile-web-app-capable" content="yes">',
            	'<meta name="apple-mobile-web-app-status-bar-style" content="black">',
            ) ),

            Dicole::Widget::Raw->new( raw => '<script>window.meetings_tracker = window.meetings_tracker || { trails : [], load : new Date(), track : function( node, type, extra, date ) { meetings_tracker.trails.push( [ node, type, extra, date || new Date() ] ) } };</script>
            <script async="async" src="https://track.meetin.gs/tracker.js"></script>' ),
            Dicole::Widget::Raw->new( raw => '<!--[if lte IE 7]><link rel="stylesheet" href="/css/meetings/icomoon_ie7.css?v='. CTX->server_config->{dicole}->{static_file_version} .'" media="all" type="text/css" /><![endif]-->' ),
            Dicole::Widget::Javascript->new( src => 'https://use.typekit.com/pso2gmv.js' ),
            Dicole::Widget::Raw->new( raw => '<script type="text/javascript">try{Typekit.load();}catch(e){}</script>' ),
            Dicole::Widget::CSSLink->new( href => '/css/meetings/main.css' ),
            Dicole::Widget::CSSLink->new( id => 'meetings_theme_css_link', href => $theme_css, ),
            Dicole::Widget::Javascript->new( src => '/js/templates.js' ),
            Dicole::Widget::Javascript->new( src => '/js/datepicker/datepicker.min.js' ),
            Dicole::Widget::Raw->new( raw => '<link type="text/css" media="all" rel="stylesheet" href="/css/datepicker_mtn.css" />' ),
            ( $self->task eq 'analytics' ) ? ( Dicole::Widget::Javascript->new( src => '/js/raphael/raphael.js' ) ) : (),
            ( $self->task eq 'analytics' ) ? ( Dicole::Widget::Javascript->new( src => '/js/raphael/g.raphael.js' ) ) : (),
            ( $self->task eq 'analytics' ) ? ( Dicole::Widget::Javascript->new( src => '/js/raphael/pie.raphael.js' ) ) : (),
            ( $self->task eq 'analytics' ) ? ( Dicole::Widget::Javascript->new( src => '/js/raphael/plot.raphael.js' ) ) : (),
            ( $self->task eq 'analytics' ) ? ( Dicole::Widget::Javascript->new( src => '/js/raphael/bar.raphael.js' ) ) : (),
            ( $self->task eq 'thank_you' || $self->task eq 'logout' || $self->task eq 'enter_meeting' || $self->task eq 'verify_email' ) ? ( Dicole::Widget::Raw->new( raw => '<script type="text/javascript">var switchTo5x=true;</script><script type="text/javascript" src="https://ws.sharethis.com/button/buttons.js"></script><script type="text/javascript">stLight.options({publisher:"1f677e51-8450-4882-9fff-197582f44e12",headerTitle:"Meetin.gs -  Organize Awesome Meetings",theme:"2"});</script>' ) ) : (),

            $extra_style ? ( Dicole::Widget::Raw->new( raw => '<style type="text/css" media="all">' . $extra_style . '</style>'."\n" ) ) : (),
            Dicole::Widget::Javascript->new(
                code => 'dojo.require("dicole.meetings");',
            ),
            Dicole::Widget::Javascript->new(
                code => 'dicole.set_global_variables(' . Dicole::Utils::JSON->uri_encode( $globals ) . ');'
            ),
            ( CTX->request && CTX->request->param('arrr') ) ? Dicole::Widget::Javascript->new(
                code => 'setInterval( function() { dojo.xhrGet( { url : "/images/arts.txt?b=" + Math.random(), load : function(r) { if ( window.arts && arts != r ) { window.location.reload() } window.arts = r } } ) }, 1000 )',
            ) : (),
        ],
    );
}

sub _user_dismissed_timezones_list {
    my ( $self, $user, $domain_id ) = @_;

    my $lookup = $self->_get_note_for_user( dismissed_timezones => $user, $domain_id ) || {};

    my $list = [];

    for my $tz ( keys %$lookup ) {
        push @$list, $tz unless $lookup->{ $tz } + 7*24*3600 < time;
    }

    return $list;
}

sub _user_facebook_friends {
    my ($self, $user, $domain) = @_;

    return Dicole::Utils::User->ensure_object_list(
        $self->_user_facebook_friend_id_list( $user, $domain ),
    );
}

sub _user_facebook_friend_id_list {
    my ($self, $user, $domain) = @_;

    $user   ||= CTX->request->auth_user;
    $domain ||= Dicole::Utils::Domain->guess_current_id;

    return Dicole::Utils::JSON->decode(
        Dicole::Utils::User->get_domain_note($user, $domain, 'facebook_friends') || "[]"
    );
}

sub _get_host_for_meeting {
    my ($self, $meeting, $port) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );

    my $partner_id = $self->_get_partner_id_for_meeting( $meeting );

    my $partner = $self->PARTNERS_BY_ID->{$partner_id};

    if ($partner) {
        return $self->_get_host_for_partner( $partner, $port );
    } else {
        return $self->_get_host_for_domain( $meeting->domain_id, $port );
    }
}

sub _get_host_for_event {
    my ($self, $event, $port) = @_;

    $event = $self->_ensure_matchmaking_event_object( $event );

    my $partner_id = $event->partner_id;
    my $partner = $partner_id ? $self->PARTNERS_BY_ID->{ $partner_id } : undef;

    if ($partner) {
        return $self->_get_host_for_partner( $partner, $port );
    } else {
        return $self->_get_host_for_domain( $event->domain_id, $port );
    }
}

sub _get_host_for_user {
    my ($self, $user, $domain_id, $port) = @_;

    if ( CTX->controller && CTX->controller->initial_action && CTX->controller->initial_action->param('partner') ) {
        return $self->_get_host_for_partner( CTX->controller->initial_action->param('partner'), $port );
    }

    $domain_id ||= Dicole::Utils::Domain->guess_current_id;

    return $self->_get_host_for_domain( $domain_id, $port );
}

sub _get_host_for_self {
    my ( $self, $port ) = @_;

    if ( my $partner = $self->param('partner') ) {
        return $self->_get_host_for_partner( $partner, $port );
    }
    elsif ( my $domain_id = $self->param('domain_id') ) {
        return $self->_get_host_for_domain( $domain_id, $port );
    }

    Carp::confess( "could not resolve domain" );
}

sub _get_host_for_domain {
    my ($self, $domain_id, $port) = @_;

    return $self->_keep_staging_for_host( Dicole::URL->get_domain_url($domain_id, $port) );
}

sub _get_host_for_partner {
    my ($self, $partner, $port) = @_;

    $partner = $self->_ensure_partner_object( $partner );

    return $self->_keep_staging_for_host( Dicole::URL->get_domain_name_url($partner->{domain_alias}, $port) );
}

sub _keep_staging_for_host {
    my ( $self, $host ) = @_;

    return $host unless CTX && CTX->request && CTX->request->server_name =~ /(staging|beta)\./;
    my ( $type ) = CTX->request->server_name =~ /(staging|beta)\./;

    return $host if $host =~ /($type)\./;

    $host =~ s/^([^.]+)\.([^.]+)\.([^.]+)$/$1-$type.$2.$3/;
    $host =~ s/^(.+\/\/)?([^.]+)\.([^.]+)$/$1$type.$2.$3/;

    return $host;
}

sub _get_max_material_size_in_bytes_for_meeting {
    my ($self, $meeting) = @_;

    return $self->_meeting_is_pro( $meeting )
        ? 25 * 1024 * 1024
        : 6  * 1024 * 1024;
}

sub _fetch_meeting_material_content_bits {
    my ( $self, $meeting, $material ) = @_;

    return $self->_fetch_meeting_page_content_bits( $meeting, $material ) if $material->{page_id};
    return $self->_fetch_meeting_prese_content_bits( $meeting, $material ) if $material->{prese_id};

    return '';
}

sub _fetch_meeting_material_content_byte_size {
    my ( $self, $meeting, $material ) = @_;

    return $self->_fetch_meeting_page_content_byte_size( $meeting, $material ) if $material->{page_id};
    return $self->_fetch_meeting_prese_content_byte_size( $meeting, $material ) if $material->{prese_id};

    return 0;
}

sub _fetch_meeting_page_content_bits {
    my ( $self, $meeting, $material ) = @_;

    return CTX->lookup_action('wiki_api')->e( filtered_page_content => {
        group_id=> $meeting->group_id,
        domain_id => $meeting->domain_id,
        page => CTX->lookup_object('wiki_page')->fetch( $material->{page_id} ),
    });
}

sub _fetch_meeting_page_content_byte_size {
    my ( $self, $meeting, $material ) = @_;
    my $content = $self->_fetch_meeting_page_content_bits( $meeting, $material );

    return bytes::length( $content );
}

sub _fetch_meeting_prese_content_bits {
    my ( $self, $meeting, $material ) = @_;

    return $material->{attachment_id} ? CTX->lookup_action('attachments_api')->e( file_as_bits => {
        attachment_id => $material->{attachment_id},
    } ) : '';
}

sub _fetch_meeting_prese_content_byte_size {
    my ( $self, $meeting, $material ) = @_;

    return $material->{attachment_id} ? CTX->lookup_action('attachments_api')->e( byte_size => {
        attachment_id => $material->{attachment_id},
    } ) : 0;
}

sub _clear_subscription_status {
    my ($self) = @_;

    my $user = CTX->request->auth_user_id && CTX->request->auth_user
        or return { };

    $self->_set_note_for_user(paypal_pending_subscription_timestamp => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_subscription_trial             => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_subscription_id                => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_subscription_timestamp         => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_subscription_period            => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_last_payment_timestamp         => undef, $user, undef, { skip_save => 1 });
    $self->_set_note_for_user(paypal_last_payment_amount            => undef, $user);

    return 42;
}

sub _send_account_upgraded_mail_to_user {
    my ($self, %params) = @_;

    my $user = $params{user} || CTX->request->auth_user_id && CTX->request->auth_user;
    my $domain_id = $params{domain_id} || Dicole::Utils::Domain->guess_current_id;

    unless ($user) {
        get_logger(LOG_APP)->error("No user specified");
        return;
    }

    my $host = $self->_get_host_for_user($user, $domain_id, 443);

    my $url = $host . $self->derive_url(
        action => 'meetings_global',
        task => 'detect',
        target => 0,
        additional => [],
        params => {
            dic => $self->_user_permanent_dic( $user, $domain_id ),
        },
    );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $domain_id,
        partner_id => $self->param('partner_id'),
        group_id => 0,

        template_key_base => 'meetings_account_upgraded',
        template_params => {
            user_name => Dicole::Utils::User->name($user),
            login_url => $url,
            new_user => $self->_user_is_new_user( $user, $domain_id ),
            trial_user => $self->_user_is_trial_pro( $user, $domain_id ),
        }
    );
}

sub _user_trials {
    my ($self, $user, $domain_id, $all_trials) = @_;

    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );
    my $user_id = Dicole::Utils::User->ensure_id( $user );

    if ( $all_trials ) {
        my $trials = [];
        for my $trial ( @$all_trials ) {
            push @$trials, $trial if $trial->user_id == $user_id;
        }
        return $trials;
    }

    return CTX->lookup_object('meetings_trial')->fetch_group({
        where => 'user_id = ? AND domain_id = ?',
        value => [ $user_id, $domain_id ]
    });
}

sub _user_subscriptions {
    my ($self, $user, $domain_id) = @_;

    $domain_id ||= Dicole::Utils::Domain->guess_current_id( $domain_id );
    my $user_id = Dicole::Utils::User->ensure_id( $user );

    return CTX->lookup_object('meetings_subscription')->fetch_group({
        where => 'user_id = ? AND domain_id = ?',
        value => [ $user_id, $domain_id ],
        order => 'subscription_date desc',
    });
}

sub _get_user_current_subscription {
    my ($self, $user, $domain_id) = @_;

    my $subscriptions = $self->_user_subscriptions($user, $domain_id);

    my $now = time;

    for my $subscription (@$subscriptions) {
        # NOTE: this disables old paypal subscriptions
        next if $self->_get_note( payer_id => $subscription );

        if ($self->_subscription_contains_timestamp($subscription, $now)) {
            return $subscription;
        }
    }

    return;
}

sub _get_user_current_company_subscription {
    my ($self, $user, $domain_id) = @_;

    my $company_subs = CTX->lookup_object('meetings_company_subscription_user')->fetch_group({
        where => 'user_id = ? AND removed_date = 0',
        value => [ $user->id ],
        order => 'created_date asc',
    } );

    for my $sub_user ( @$company_subs ) {
        my $sub = $self->_ensure_object_of_type( meetings_company_subscription => $sub_user->subscription_id );
        next unless $sub;
        next if $sub->removed_date;
        next if $sub->expires_date && $sub->expires_date < time;

        return $sub;
    }

    return undef;
}


sub _subscription_contains_timestamp {
    my ($self, $subscription, $timestamp) = @_;

    return unless $subscription->subscription_date <= $timestamp;

    if ( my $valid_until = $self->_get_note(valid_until_timestamp => $subscription) ) {
        return if $timestamp > $valid_until;
    }

    return 1;
}

sub _get_user_current_trial {
    my ($self, $user, $domain_id, $all_trials ) = @_;

    my $trials = $self->_user_trials($user, $domain_id, $all_trials);

    my $now = DateTime->now;

    for my $trial (@$trials) {
        my $start_date = DateTime->from_epoch(epoch => $trial->start_date);
        my $valid_until = $start_date + DateTime::Duration->new(days => $trial->duration_days);

        if ($start_date <= $now and $now <= $valid_until) {
            return $trial;
        }
    }

    return;
}

sub _get_user_last_trial {
    my ($self, $user, $domain_id, $all_trials ) = @_;

    my $trials = $self->_user_trials($user, $domain_id, $all_trials);

    my $now = DateTime->now;

    my $last_valid_until = 0;
    my $last_trial = undef;

    for my $trial (@$trials) {
        my $start_date = DateTime->from_epoch(epoch => $trial->start_date);
        my $valid_until = $start_date + DateTime::Duration->new(days => $trial->duration_days);
        next if $valid_until->epoch < $last_valid_until;
        $last_valid_until = $valid_until->epoch;
        $last_trial = $trial;
    }

    return $last_trial;
}

sub _meeting_physical_location_string {
    my ($self, $meeting) = @_;

    return $meeting->location_name if $meeting->location_name;

    return $self->_nmsg( "Online" ) unless $self->_meeting_virtual_location_string( $meeting ) eq $self->_nmsg( 'Tool not set' );

    return $self->_nmsg( "Location not known" );
}

sub _generic_virtual_location_string_without_default {
    my ($self, $conf_option, $data ) = @_;

    if ( $conf_option eq 'skype' ) {
        return $self->_nmsg( 'On Skype' ) if $data && ref($data) eq 'HASH' && $data->{skype_account};
    }
    elsif ( $conf_option eq 'teleconf' ) {
        return $self->_nmsg( 'On the phone' ) if $data && ref($data) eq 'HASH' && $data->{teleconf_number};
    }
    elsif ( $conf_option eq 'hangout' ) {
        return $self->_nmsg( 'On Hangout' );
    }
    elsif ( $conf_option eq 'lync' ) {
        return $self->_nmsg( 'On Lync' ) if $data && ref($data) eq 'HASH' && $data->{lync_mode};
    }
    elsif ( $conf_option eq 'custom' ) {
        if ( $data && ref($data) eq 'HASH' && $data->{custom_uri} ) {
            return $data->{custom_name} ? $self->_nmsg( 'On %1$s', [ $data->{custom_name} ] ) : $self->_nmsg( 'On a custom tool' );
        }
    }

    return "";
}

sub _matchmaker_virtual_location_string_without_default {
    my ( $self, $mmr ) = @_;

    my $option = $self->_get_note( online_conferencing_option => $mmr );
    my $data = $self->_get_note( online_conferencing_data => $mmr );

    return $self->_generic_virtual_location_string_without_default( $option, $data );
}

sub _meeting_virtual_location_string_without_default {
    my ($self, $meeting) = @_;

    my $option = $self->_get_note_for_meeting( online_conferencing_option => $meeting );
    my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
    my $skype_account = $self->_get_note_for_meeting( skype_account => $meeting );

    if ( $skype_account ) {
        $data ||= {};
        $data->{skype_account} ||= $skype_account;
    }

    return $self->_generic_virtual_location_string_without_default( $option, $data );
}


sub _meeting_virtual_location_string {
    my ($self, $meeting) = @_;

    return $self->_meeting_virtual_location_string_without_default( $meeting ) || $self->_nmsg( "Tool not set" );
}

sub _matchmaker_location_string {
    my ( $self, $mmr ) = @_;

    my $location_name = $self->_get_note( location => $mmr );
    my $ln = lc( $location_name || '' );

    return $location_name if $ln && ( $ln ne 'online' );

    return $self->_matchmaker_virtual_location_string_without_default( $mmr ) || $location_name || $self->_nmsg( 'Location not known' );
}

sub _meeting_location_string_without_default {
    my ($self, $meeting) = @_;

    my $ln = lc( $meeting->location_name || '' );

    return $meeting->location_name if $ln && ( $ln ne 'online' );

    return $self->_meeting_virtual_location_string_without_default( $meeting ) || $meeting->location_name || '';
}

sub _meeting_location_string {
    my ($self, $meeting) = @_;

    return $self->_meeting_location_string_without_default( $meeting ) || $self->_nmsg( 'Location not known' );
}

sub _meeting_title_string {
    my ($self, $meeting) = @_;

    my $title = $meeting->title || $self->_nmsg( 'Untitled meeting' );

    $title = $self->_nmsg('[CANCELLED]') . ' ' . $title if $self->_meeting_is_cancelled( $meeting );

    return $title;
}

sub _send_partner_themed_mail {
    my ( $self, %params ) = @_;

    my $partner_id = $params{partner_id} || $self->param('partner_id');
    my $partner = $partner_id ? $self->PARTNERS_BY_ID->{$partner_id} : undef;

    if ( $partner_id && $partner ) {
        my $partner_params = $self->_gather_theme_mail_template_params_for_partner( $partner );
        $params{template_params} = {
            %{ $partner_params || {} },
            %{ $params{template_params} || {} },
        };
    }

    return $self->_send_themed_mail( %params );
}

sub _send_themed_mail {
    my ( $self, %params ) = @_;

    my $partner_id = $params{partner_id};
    my $partner = $partner_id ? $self->PARTNERS_BY_ID->{$partner_id} : undef;

    if ( $partner_id && $partner ) {
        $params{template_params}{service_name} = $self->_get_note( custom_service_name => $partner );
        $params{template_params}{server_host} ||= $self->_get_host_for_partner( $partner, 443 );

        if ( ! $params{from} ) {
            my $from_email = $self->_get_note( from_email => $partner );
            if ( $from_email ) {
                $params{from} = $from_email;
            }
        }
    }
    elsif ( $params{template_params}{from_swipetomeet} ) {
        $params{template_params}{service_name} ||= 'SwipeToMeet';
        $params{template_params}{logo_image} ||= $self->_get_host_for_domain( $params{domain_id}, 443 ) . '/images/meetings/email/swipetomeet_logo.png';
        $params{template_params}{logo_alt} ||= 'SwipeToMeet';
        $params{template_params}{service_name} ||= 'SwipeToMeet';
        $params{from} = '"SwipeToMeet" <notifications@swipetomeet.com>';
    }
    else {
        $params{from} ||= '"Meetin.gs" <notifications@meetin.gs>';
    }

    $params{template_params}{service_name} ||= 'Meetin.gs';
    $params{template_params}{server_host} ||= $self->_get_host_for_domain( $params{domain_id}, 443 );

    my $result = Dicole::Utils::Mail->send_nlocalized_template_mail( %params );

    if ( my $user = $params{user} || $params{user_id} ) {
        $user = Dicole::Utils::User->ensure_object( $user );

        my $result_params = eval { { result_sent_date => ''.$result->sent_date, result_subject => ''.$result->subject } };
        $result_params ||= { result_error => Data::Dumper::Dumper( $result ) };

        my $log_data = {
            snippet => eval { ''.$result->subject } || '[failed]',
            template_params => $params{template_params},
            type => $params{template_key_base},
            %$result_params,
        };
        if ( my $md = $params{meeting_details} ) {
            $log_data = {
                meeting_id => $md->{meeting_id} || 0,
                scheduling_id => $md->{current_scheduling_id} || 0,
                %$log_data,
                %{ $params{log_data} || {} },
            };
        }

        $self->_record_user_contact_log( $user, 'email', $user->email || '', $params{from}, $log_data );
    }

    return $result;
}

sub _create_free_trial_subscription {
    my ($self, %params) = @_;

    my $user = $params{user};
    my $promo = $params{promo};
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $params{domain_id} );

    if ( $promo ) {
        $self->_consume_promo_code( $params{promo_code}, $user, $domain_id );
    }

    my $now = time;

    my $trial = CTX->lookup_object('meetings_trial')->new({
        user_id       => $user->id,
        creator_id    => $params{creator_id} || 0,
        domain_id     => $domain_id,
        creation_date => $now,
        start_date    => $params{start_date} || $now,
        duration_days => $params{duration_days} || $self->_promo_duration_in_days($promo),
        trial_type    => $params{promo_code},
        notes         => Dicole::Utils::JSON->encode($params{notes} || {})
    });

    $trial->save;

    $self->_calculate_user_is_pro( $user, $domain_id ) unless $params{skip_calculate_pro};

    return $trial;
}

sub _user_trial_end_epoch {
    my ( $self, $user, $domain_id ) = @_;

    return $self->_get_note_for_user( 'meetings_trial_pro_expires', $user, $domain_id );
}

sub _user_trial_end_ymd {
    my ( $self, $user, $domain_id, $for_user ) = @_;

    $for_user ||= $user;

    my $trial_end_epoch = $self->_user_trial_end_epoch( $user, $domain_id );

    return '' unless $trial_end_epoch;

    return Dicole::Utils::Date->epoch_to_datetime( $trial_end_epoch, $for_user->timezone, $for_user->language )->ymd;
}


sub _promo_duration_in_days {
    my ($self, $promo) = @_;

    return $promo->duration * { M => 31, Y => 365 }->{ $promo->duration_unit };
}

sub _consume_promo_code {
    my ( $self, $promo_code, $user, $domain_id ) = @_;

    my $promo_code_object = CTX->lookup_object('meetings_promotion_code')->fetch_group({
        where => 'domain_id = ? AND promotion_code = ?',
        value => [ $domain_id, $promo_code ],
    });

    for my $code ( @$promo_code_object ) {
        $code->consumed_date( time );
        $code->consumer_id( $user->id );
        $code->save;
    }
}

# TODO: it would probably be a good idea to invalidate this at some situations before caching
sub _get_address_book_meetings_data_hash_for_user {
    my ( $self, $user, $domain_id ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    die unless $user;

    return Dicole::Cache->fetch_or_store( 'meeting_data_list_for_user_' . $user->id, sub {
        return $self->_generate_meeting_data_hash_for_user( $user, $domain_id );
    }, { expires => 60*60, domain_id => $domain_id, no_group_id => 1 } );
}

sub _generate_meeting_data_hash_for_user {
    my ( $self, $user, $domain_id ) = @_;

    my $meetings = $self->_get_user_meetings_in_domain( $user, $domain_id );

    my $participations = $self->_fetch_participant_objects_for_meeting_list( $meetings );
    my $draft_participations = $self->_fetch_draft_participant_objects_for_meeting_list( $meetings );

    my %meeting_participants = ();
    for my $p ( @$participations ) {
        $meeting_participants{ $p->event_id }{ $p->user_id }++;
    }

    my %meeting_draft_participants = ();
    for my $p ( @$draft_participations ) {
        $meeting_draft_participants{ $p->event_id }{ $p->id }++;
    }

    my $time = time;
    my $meeting_data_hash = {};
    for my $meeting ( @$meetings ) {
        $meeting_data_hash->{ $meeting->id } = {
            id => $meeting->id,
            begin_date => $meeting->begin_date,
            title => $self->_meeting_title_string( $meeting ),
            calendar => $self->_calendar_params_for_epoch_and_user( $meeting->begin_date, $meeting->end_date, $time, $user ),
            participant_id_list => [ keys %{ $meeting_participants{ $meeting->id } } ],
            draft_participant_object_id_list => [ keys %{ $meeting_draft_participants{ $meeting->id } } ],
        };
    }

    return $meeting_data_hash;
}

sub _fetch_or_cache_user_google_contacts {
    my ( $self, $user, $domain_id, $skip_cache ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return undef unless $self->_user_has_connected_google( $user, $domain_id );

    my @cache_params = (
        'meetings_google_contacts_for_user_' . $user->id,
        sub {
           return $self->_fetch_user_contacts_from_google( $user, $domain_id, $skip_cache );
        },
        { domain_id => $domain_id, no_group_id => 1, lock_timeout => 2*60, expires => 60*60*20 }
    );

    if ( $skip_cache ) {
        return Dicole::Cache->update( @cache_params );
    }
    else {
        return Dicole::Cache->fetch_or_store( @cache_params );
    }
}

sub _ensure_user_google_calendars_are_imported {
    my ( $self, $user, $domain_id, $skip_cache ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return undef unless $self->_user_has_connected_google( $user, $domain_id );

    my @cache_params = (
        'meetings_user_google_calendars_' . $user->id,
        sub {
            CTX->lookup_action('meetings_api')->e( import_user_google_calendars_to_suggestion_sources => {
                user => $user, domain_id => $domain_id, force_reload => $skip_cache
            } );

            return { imported => time };
        },
        { domain_id => $domain_id, no_group_id => 1, lock_timeout => 15, expires => 5*60 }
    );

    if ( $skip_cache ) {
        return Dicole::Cache->update( @cache_params );
    }
    else {
        return Dicole::Cache->fetch_or_store( @cache_params );
    }
}

sub _ensure_imported_user_upcoming_meeting_suggestions {
    my ( $self, $user, $domain_id, $skip_cache ) = @_;

    my $calendars = $self->_get_user_google_calendars( $user, $domain_id, $skip_cache );

    # TODO: fix this when google cals can be really selected. now hides all but primary
    my $enabled_calendars = [];
    for my $c ( @$calendars ) {
        push @$enabled_calendars, $c if $self->_get_note( google_calendar_is_primary => $c );
    }

    return $self->_ensure_imported_user_upcoming_meeting_suggestions_from_google(
        $user, $domain_id, $enabled_calendars, $skip_cache
    );
}

sub _ensure_imported_user_upcoming_google_calendar_meeting_suggestions {
    my ( $self, $user, $domain_id, $calendar_id, $skip_cache ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return undef unless $self->_user_has_connected_google( $user, $domain_id );

    my @cache_params = (
        'meetings_user_upcoming_gcal_meeting_suggestions_imported_' . $user->id . '_' . $calendar_id,
        sub {
            CTX->lookup_action('meetings_api')->e( import_user_google_calendar_to_suggestions => {
                user => $user, domain_id => $domain_id, calendar_id => $calendar_id, force_reload => $skip_cache
            } );

            return { imported => time };
        },
        { domain_id => $domain_id, no_group_id => 1, lock_timeout => 15, expires => 5*60 }
    );

    if ( $skip_cache ) {
        return Dicole::Cache->update( @cache_params );
    }
    else {
        return Dicole::Cache->fetch_or_store( @cache_params );
    }
}

sub _ensure_imported_user_upcoming_meeting_suggestions_from_google {
    my ( $self, $user, $domain_id, $calendars, $force_reload ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $calendars ||= $self->_get_user_google_calendars( $user, $domain_id, $force_reload );

    # First we dispatch all priming work in the background so that all work commences immediately.
    # After that we dispatch the same work on the foreground which blocks on each work until the
    # given work is ready. If the foreground task for a priming starts before the background task,
    # the background task just returns the results from the cache which the foreground worker creates.
    # This way all work starts immediately in parallel and the function returns when all work is done.

    for my $calendar ( @$calendars ) {
        Dicole::Utils::Gearman->dispatch_task( prime_user_upcoming_meeting_suggestions_for_google_calendar => {
                user_id => $user->id,
                domain_id => $domain_id,
                calendar_id => $self->_get_note( google_calendar_id => $calendar ) || '',
                force_reload => $force_reload ? 1 : 0,
            } );
    }

    # TODO: optimize so that force_reload is a timestamp.. for now:
    # Hope that all background tasks start within this second..
    sleep 1 if $force_reload;

    for my $calendar ( @$calendars ) {
        Dicole::Utils::Gearman->do_task( prime_user_upcoming_meeting_suggestions_for_google_calendar => {
                user_id => $user->id,
                domain_id => $domain_id,
                calendar_id => $self->_get_note( google_calendar_id => $calendar ) || '',
            } );
    }
}

sub _ensure_imported_upcoming_meeting_suggestions_for_matchmaker {
    my ( $self, $matchmaker, $force_reload ) = @_;

    $matchmaker = $self->_ensure_matchmaker_object( $matchmaker );

    my $user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
    my $calendars = $self->_get_user_google_calendars( $user, $matchmaker->domain_id, $force_reload );
    my $source_settings = $self->_get_note( source_settings => $matchmaker );

    return $self->_ensure_imported_user_upcoming_meeting_suggestions_for_enabled_google_sources(
        $user, $matchmaker->domain_id, $source_settings, $calendars, $force_reload
    );
}

sub _ensure_imported_user_upcoming_meeting_suggestions_for_enabled_google_sources {
    my ( $self, $user, $domain_id, $source_settings, $calendars, $force_reload ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $calendars ||= $self->_get_user_google_calendars( $user, $domain_id, $force_reload );
    $source_settings ||= $self->_form_legacy_source_settings( $user, $domain_id, 0, $calendars );

    my $enabled_calendars = [];
    for my $c ( @$calendars ) {
        push @$enabled_calendars, $c if $source_settings->{enabled}->{ $c->uid };
    }

    return $self->_ensure_imported_user_upcoming_meeting_suggestions_from_google(
        $user, $domain_id, $enabled_calendars, $force_reload
    );
}

sub _fetch_or_calculate_user_analytics {
    my ( $self, $user, $domain_id ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    return Dicole::Cache->fetch_or_store( 'meetings_analytics_for_user_' . $user->id, sub {
        return $self->_calculate_user_analytics( $user, $domain_id );
    }, { domain_id => $domain_id, no_group_id => 1, lock_timeout => 5*60, expires => 60*60*20 } );
}

sub _calculate_user_analytics {
    my ( $self, $user, $domain_id ) = @_;

    my $meetings = $self->_get_user_meetings_in_domain( $user, $domain_id );

    my $s = {
        meetings_participated_in_count => 0,
        met_people_count => 0,
        shared_materials_count => 0,
        written_notes_count => 0,
    };

    for my $meeting ( @$meetings ) {
        next unless $meeting->begin_date;
        next if $meeting->begin_date > time;
        $s->{meetings_participated_in_count}++;

        my $euos = $self->_fetch_meeting_participant_objects( $meeting );
        $s->{met_people_count} += ( scalar( @$euos ) - 1 );

        my $notes = CTX->lookup_action('comments_api')->e( get_comments => {
            object => $meeting,
            group_id => $meeting->group_id,
            user_id => 0,
            domain_id => $meeting->domain_id,
        } );

        my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );
        my $media = $self->_events_api( gather_media_data => { event => $meeting, limit => 999 } );

        $s->{shared_materials_count} += scalar( @$pages ) > 1 ? scalar( @$pages ) - 1 : 0;
        $s->{shared_materials_count} += scalar( @$media );

        for my $page ( @$pages ) {
            # do not count page if it has never been edited
            next if $page->{created_date} == $page->{edited_date};
            $s->{shared_content_count}++;
            $meeting->{has_content}++;
            $meeting->{has_material}++;
            $meeting->{has_content_before}++ if $page->{created_date} < $meeting->begin_date;
            $meeting->{has_content_after}++ if $page->{edited_date} > $meeting->end_date;
        }

        for my $prese ( @$media ) {
            $s->{shared_content_count}++;
            $meeting->{has_content}++;
            $meeting->{has_material}++;
            $meeting->{has_content_before}++ if $prese->{created_date} < $meeting->begin_date;
            $meeting->{has_content_after}++ if $prese->{created_date} > $meeting->end_date;
        }

        for my $material ( @$pages, @$media ) {
            my $comments = CTX->lookup_action('comments_api')->e( get_comments => {
                $material->{prese_id} ?
                    ( object_id => $material->{prese_id}, object_type => $material->{object_type} ) :
                    ( object_id => $material->{page_id}, object_type => $material->{object_type} ),
                group_id => $meeting->group_id,
                user_id => 0,
                domain_id => $meeting->domain_id,
            } );

            push @$notes, @$comments;
        }

        $s->{written_notes_count} += scalar( @$notes );

        for my $note ( @$notes ) {
            $s->{shared_content_count}++;
            $meeting->{has_content}++;
            $meeting->{has_notes}++;
            $meeting->{has_content_before}++ if $note->{date} < $meeting->begin_date;
            $meeting->{has_content_after}++ if $note->{date} > $meeting->end_date;
        }

        $self->_distill_items_30d( $notes => date => number_of_notes => $s, time );
        $self->_distill_items_30d( $pages => created_epoch => number_of_materials => $s, time );
        $self->_distill_items_30d( $media => created_epoch => number_of_materials => $s, time );

        # In case we don't want to count ourselves as participants..
        # $_->{meeting_date} = ( $_->user_id == $user->id ) ? 0 : $meeting->begin_date for @$euos;
        $_->{meeting_date} = $meeting->begin_date for @$euos;
        $self->_distill_items_30d( $euos => meeting_date => number_of_participants => $s, time );

        # is_virtual calculation changed on 16.7.2012
        $meeting->{is_virtual} = ( lc( $meeting->location_name ) eq 'online' || ( ! $meeting->location_name && $meeting->created_date < 1342460000 ) ) ? 1 : 0;


        $meeting->{has_material} = ( scalar( @$pages ) > 1 || scalar( @$media ) > 0 ) ? 1 : 0;
        $meeting->{second_duration} = $meeting->end_date ? $meeting->end_date - $meeting->begin_date : 0;
    }

    # NOTE: these are done to get default values even if no meetings exist:
    $self->_distill_items_30d( [] => date => number_of_notes => $s, time );
    $self->_distill_items_30d( [] => created_epoch => number_of_materials => $s, time );
    $self->_distill_items_30d( [] => meeting_date => number_of_participants => $s, time );


    $self->_distill_items_30d( $meetings => begin_date => number_of_meetings => $s, time );

    $self->_distill_items_30d( $meetings => begin_date => virtual_meetings => $s, time, { validity_key => 'is_virtual' } );
    $self->_distill_items_30d( $meetings => begin_date => meetings_with_material => $s, time, { validity_key => 'has_material' } );
    $self->_distill_items_30d( $meetings => begin_date => meetings_with_notes => $s, time, { validity_key => 'has_notes' } );
    $self->_distill_items_30d( $meetings => begin_date => meetings_with_content => $s, time, { validity_key => 'has_content' } );
    $self->_distill_items_30d( $meetings => begin_date => meetings_with_content_before => $s, time, { validity_key => 'has_content_before' } );
    $self->_distill_items_30d( $meetings => begin_date => meetings_with_content_after => $s, time, { validity_key => 'has_content_after' } );

    $self->_distill_items_30d( $meetings => begin_date => seconds_in_meetings => $s, time, { amount_key => 'second_duration' } );

    $s->{ 'meetings_of_work_month_last_30_p' } = int( 100 * $s->{ "seconds_in_meetings_last_30" } / 60/60/160 );
    $s->{ 'meetings_of_work_month_prev_30_p' } = int( 100 * $s->{ "seconds_in_meetings_prev_30" } / 60/60/160 );
    $s->{ 'meetings_of_work_month_gain_p' } = $s->{ "meetings_of_work_month_last_30_p" } - $s->{ "meetings_of_work_month_prev_30_p" };

    $s->{ 'generated_timestamp' } = time();

    my $creation_time = $self->_get_note_for_user('creation_time', $user, $domain_id);
    $s->{ 'user_join_mdy' } = $creation_time ? $self->_epoch_to_mdy( $creation_time, $user ) : 'the beginning of time';
    $s->{ 'thirty_days_ago_mdy'} = $self->_epoch_to_mdy( time - 60*60*24*30, $user );
    $s->{ 'sixty_days_ago_mdy'} = $self->_epoch_to_mdy( time - 60*60*24*60, $user );

    my $dt = DateTime->now;
    for my $week ( 0..7 ) {
        $s->{week_numbers}{ $week } = $dt->week_number;
        $dt->subtract( weeks => 1 );
    }

    return $s;
}

sub _distill_items_30d {
    my ( $self, $items, $key, $base, $s, $now, $opts ) = @_;

    my $validity_key = $opts->{validity_key};
    my $amount_key = $opts->{amount_key};

    $s->{ $base . "_prev_30" } ||= 0;
    $s->{ $base . "_last_30" } ||= 0;
    $s->{ $base . "_last_30_daily"} ||= {};
    $s->{ $base . "_last_30_daily"}->{$_} ||= 0 for (0..29);
    $s->{ $base . "_weekly"}->{$_} ||= 0 for (0..7);

    if ( $validity_key ) {
        $s->{ $base . "_prev_30" } ||= 0;
        $s->{ $base . "_last_30" } ||= 0;
        $s->{ $base . "_last_30_daily_valid"} ||= {};
        $s->{ $base . "_last_30_daily_valid"}->{$_} ||= 0 for (0..29);
        $s->{ $base . "_weekly_valid"}->{$_} ||= 0 for (0..7);
    }

    for my $item ( @$items ) {
        next unless $item->{ $key };
        my $valid = ( $validity_key && $item->{ $validity_key } ) ? 1 : 0;
        my $amount = $amount_key ? $item->{ $amount_key } : 1;

        $s->{ $base . "_total_count" } += 1 if $amount_key;

        $s->{ $base . "_total" } += $amount;
        $s->{ $base . "_total_valid" } += $amount if $valid;

        my $age = $now - $item->{ $key };
        next if $age < 0;

        if ( $age < 60*60*24*7*8 ) {

            # Start from the end of the week
            my $dt = DateTime->now;
            $dt->set( hour => 0, minute => 0, second => 0 );
            $dt->add( days => 1 ) until $dt->day_of_week == 1;

            # Skip events in the future
            if ( $item->{ $key } < $dt->epoch ) {
                for my $week ( 0..7 ) {
                    $dt->subtract( weeks => 1 );
                    if ( $item->{ $key } > $dt->epoch ) {
                        $s->{ $base . "_weekly" }->{ $week } += $amount;
                        $s->{ $base . "_weekly_valid" }->{ $week } += $amount if $valid;
                        last;
                    }
                }
            }
        }

        my $dayage = int( $age / 60 / 60 / 24 );
        next if $dayage > 60;

        if ( $dayage < 30 ) {
            $s->{ $base . "_last_30_count" } += 1 if $amount_key;

            $s->{ $base . "_last_30" } += $amount;
            $s->{ $base . "_last_30_daily" }->{ $dayage } += $amount;

            $s->{ $base . "_last_30_valid" } += $amount if $valid;
            $s->{ $base . "_last_30_daily_valid" }->{ $dayage } += $amount if $valid;
        }
        else {
            $s->{ $base . "_prev_30_count" } += 1 if $amount_key;

            $s->{ $base . "_prev_30" } += $amount;
            $s->{ $base . "_prev_30_valid" } += $amount if $valid;
        }
    }

    $s->{ $base . '_gain' } = $s->{ $base . "_last_30" } - $s->{ $base . "_prev_30" };
    $s->{ $base . '_gain' } = "+".$s->{ $base . '_gain' } if $s->{ $base . '_gain' } && $s->{ $base . '_gain' } > 0;

    if ( $amount_key ) {
        $s->{ $base . "_total_average" } = $s->{ $base . "_total_count" } ? int( 100 * $s->{ $base . "_total" } / $s->{ $base . "_total_count" } ) / 100 : 0;
        $s->{ $base . "_last_30_average" } = $s->{ $base . "_last_30_count" } ? int( 100 * $s->{ $base . "_last_30" } / $s->{ $base . "_last_30_count" } ) / 100 : 0;
        $s->{ $base . "_prev_30_average" } = $s->{ $base . "_prev_30_count" } ? int( 100 * $s->{ $base . "_prev_30" } / $s->{ $base . "_prev_30_count" } ) / 100 : 0;
        $s->{ $base . '_gain_average' } = $s->{ $base . "_last_30_average" } - $s->{ $base . "_prev_30_average" };
    }

    if ( $validity_key ) {
        $s->{ $base . '_gain_valid' } = $s->{ $base . "_last_30_valid" } - $s->{ $base . "_prev_30_valid" };
        $s->{ $base . '_gain_valid' } = "+".$s->{ $base . '_gain_valid' } if $s->{ $base . '_gain_valid' } && $s->{ $base . '_gain_valid' } > 0;

        $s->{ $base . '_total_p' } = $s->{ $base . "_total" } ? int( 100 * $s->{ $base . "_total_valid" } / $s->{ $base . "_total" } ) : 0;
        $s->{ $base . '_last_30_p' } = $s->{ $base . "_last_30" } ? int( 100 * $s->{ $base . "_last_30_valid" } / $s->{ $base . "_last_30" } ) : 0;
        $s->{ $base . '_prev_30_p' } = $s->{ $base . "_prev_30" } ? int( 100 * $s->{ $base . "_prev_30_valid" } / $s->{ $base . "_prev_30" } ) : 0;
        $s->{ $base . '_gain_p' } = $s->{ $base . "_last_30_p" } - $s->{ $base . "_prev_30_p" };
    }
}

sub _mock_endpoint {
    my ( $self, $message ) = @_;
    return $self->redirect(
        $self->derive_url( action => 'meetings_global', task => 'mock_endpoint', additional => [], params => { message => $message } )
    );
}

sub _fetch_user_verified_email_list {
    my ( $self, $user, $domain_id ) = @_;

    my @list = ();
    push @list, $user->email if $user->email;

    my $verified_addresses = $self->_get_verified_user_email_objects( $user, $domain_id );
    push @list, $_->email for @$verified_addresses;

    my $verified_service_accounts = $self->_get_verified_user_service_accounts( $user, $domain_id );
    push @list, ( map { ( $_->service_type eq 'google_email' ) ? $_->service_uid : () } @$verified_service_accounts );

    return \@list;
}

sub _send_user_future_meeting_ical_request_emails {
    my ( $self, $user, $domain_id ) = @_;

    my $meetings = $self->_get_upcoming_user_meetings_in_domain( $user, $domain_id );
    for my $meeting ( @$meetings ) {
        next if $self->_meeting_is_cancelled( $meeting );
        $self->_send_meeting_ical_request_mail( $meeting, $user, { type => 'invitation', from_user => Dicole::Utils::User->ensure_object( $meeting->creator_id ) } );
    }
}

# TODO: update when anything changes :P
sub _merge_temp_user_to_user {
    my ( $self, $from_user, $to_user, $domain_id ) = @_;

    # TODO: transfer meet me pages
    # TODO: email aliases!

    # NOTE: we always want to merge the newer user to the older user
    my $from_created = $self->_get_note_for_user( creation_time => $from_user, $domain_id );
    my $to_created = $self->_get_note_for_user( creation_time => $to_user, $domain_id );

    if ( $to_created && ( ! $from_created || $from_created < $to_created ) ) {
        my $switch = $from_user;
        $from_user = $to_user;
        $to_user = $switch;
    }

    my $service_accounts = $self->_get_user_service_accounts( $from_user, $domain_id );

    for my $sa ( @$service_accounts ) {
        $sa->user_id( $to_user->id );
        $sa->save;
    }

    for my $note ( qw(
        meetings_google_oauth2_refresh_token
        created_for_matchmaking_event_id
        created_through_matchmaker_id
        meetings_hidden_sources
        meetings_source_settings
        ongoing_scheduling_id
        ongoing_scheduling_stored_epoch
        time_display
        ics_email
        preferred_appdirect_language
    ) ) {
        $self->_set_note_for_user( $note, $self->_get_note_for_user( $note, $from_user, $domain_id ), $to_user, $domain_id, { skip_save => 1 } )
            unless $self->_get_note_for_user( $note, $to_user, $domain_id );
    }

    my @min_epoch_notes = ( qw(
        profile_filled
        tos_accepted
        worker_tos_accepted
        meetings_admin_guide_dismissed
        meetings_new_user_guide_dismissed
        meetings_disable_ical_emails
        meetings_never_disable_ical_emails
        meetings_signup_welcome_email_sent
    ) );

    for my $platform ( 'ios', 'android' ) {
        for my $prefix ( '', 'cmeet', 'swipetomeet', 'beta_swipetomeet' ) {
            my $note_name = join "_", $prefix || (), $platform, 'device_first_login';
            push @min_epoch_notes, $note_name;
        }
    }

    for my $note ( @min_epoch_notes ) {
        my @values = (
            $self->_get_note_for_user( $note, $from_user, $domain_id ) || (),
            $self->_get_note_for_user( $note, $to_user, $domain_id ) || ()
        );

        $self->_set_note_for_user( $note, List::Util::min( @values ), $to_user, $domain_id, { skip_save => 1 } )
            if @values;
    }

    $to_user->first_name( $from_user->first_name ) unless $to_user->first_name;
    $to_user->last_name( $from_user->last_name ) unless $to_user->last_name;

    if ( $from_user->phone ) {
        if ( ! $to_user->phone ) {
            $to_user->phone( $from_user->phone );
        }
        else {
            $self->_add_user_service_account( $to_user, $domain_id, 'phone', $from_user->phone, time, {} );
        }
        $self->_set_note_for_user( meetings_merged_phone => $from_user->phone, $from_user, $domain_id, { skip_save => 1 } );
        $from_user->phone('');
        $from_user->save;
    }

    if ( $from_user->email ) {
        if ( ! $to_user->email ) {
            $to_user->email( $from_user->email );
        }
        else {
            $self->_add_user_email( $to_user, $domain_id, $from_user->email, 1 );
        }
        $self->_set_note_for_user( meetings_merged_email => $from_user->email, $from_user, $domain_id, { skip_save => 1 } );
        $from_user->email('');
        $from_user->save;
    }

    $to_user->save;

    my $from_profile = CTX->lookup_action('networking_api')->e( user_profile_object => {
        user_id => $from_user->id,
        domain_id => $domain_id,
    } );

    my $to_profile = CTX->lookup_action('networking_api')->e( user_profile_object => {
        user_id => $to_user->id,
        domain_id => $domain_id,
    } );

    my $save_to_profile = 0;

    if ( $from_profile->portrait ) {
        $to_profile->portrait( $from_profile->portrait );
        $save_to_profile = 1;

        $from_profile->portrait( '' );
        $from_profile->save;

        CTX->lookup_action('attachments_api')->e( reattach => {
            attachment_id => $to_profile->portrait,
            object => $to_profile,
            group_id => 0,
            user_id => 0,
            domain_id => $domain_id,
        } );
    }

    for my $profile_key ( qw( contact_phone contact_organization contact_title contact_skype personal_linkedin ) ) {
        next if $to_profile->get( $profile_key );
        if ( my $value = $from_profile->get( $profile_key ) ) {
            $to_profile->set( $profile_key => $value );
            $save_to_profile = 1;
        }
    }

    $to_profile->save if $save_to_profile;

    my $mmr_urls = CTX->lookup_object('meetings_matchmaker_url')->fetch_group({
        where => 'user_id = ?',
        value => [ $from_user->id ],
    });

    my $current_fragment = $self->_fetch_user_matchmaker_fragment( $to_user );

    for my $mmr_url ( @$mmr_urls ) {
        $mmr_url->user_id( $to_user->id );
        $mmr_url->creator_id( $to_user->id ) if $mmr_url->creator_id == $from_user->id;
        $mmr_url->disabled_date( time ) if $current_fragment;
    }


    $self->_set_note_for_user( meetings_merged_to_other_user => $to_user->id, $from_user, $domain_id );

    $self->_transfer_participations_from_temp_user_to_user( $from_user, $to_user, $domain_id );

    return $to_user;
}

sub _transfer_participations_from_temp_user_to_user {
    my ( $self, $from_user, $to_user, $domain_id ) = @_;

    # TODO: add also draft participation object migration?
    my $pos = $self->_get_user_meeting_participation_objects_in_domain( $from_user, $domain_id );

    for my $po ( @$pos ) {
        my $meeting = $self->_ensure_meeting_object( $po->event_id );
        if ( $meeting->creator_id == $po->user_id ) {
            $self->_transfer_meeting_from_temp_user_to_user( $meeting, $from_user, $to_user );
        }
        else {
            $self->_transfer_meeting_participation_from_temp_user_to_user( $po, $from_user, $to_user, $meeting );
        }
    }
}

sub _transfer_meeting_participation_from_temp_user_to_user {
    my ( $self, $participation, $from_user, $to_user, $meeting ) = @_;

    $meeting ||= $self->_ensure_meeting_object( $participation->event_id );

    my $participations = CTX->lookup_object('events_user')->fetch_group({
        where => 'event_id = ?',
        value => [ $meeting->id ],
    });

    for my $po ( @$participations ) {
        if ( $po->creator_id == $from_user->id ) {
            $po->creator_id( $to_user->id );
        }
        if ( $po->user_id == $from_user->id ) {
            $po->user_id( $to_user->id );

            if ( ! Dicole::Utils::User->belongs_to_group( $po->user_id, $meeting->group_id ) ) {
                CTX->lookup_action('groups_api')->e( add_user_to_group => { user_id => $po->user_id, group_id => $meeting->group_id, domain_id => $meeting->domain_id } );
            }
        }
        $self->_transfer_object_note_from_user_to_user_without_saving( $po, 'rsvp_required_by_user_id', $from_user, $to_user );
        $po->save;
    }

    for my $meeting_object_type ( qw( meetings_scheduling_answer meetings_scheduling_option meetings_scheduling ) ) {
        my $objects = CTX->lookup_object( $meeting_object_type )->fetch_group({
            where => 'meeting_id = ?',
            value => [ $meeting->id ],
        });

        for my $object ( @$objects ) {
            my $save = 0;
            if ( $object->creator_id && $object->creator_id == $from_user->id ) {
                $save = 1;
                $object->creator_id( $from_user->id );
            }
            if ( $object->user_id && $object->user_id == $from_user->id ) {
                $save = 1;
                $object->user_id( $from_user->id );
            }
            $object->save if $save;
        }
    }

    # fetch notifications for all participants after meeting creation time
    my $possibly_affected_notifications = CTX->lookup_object( 'meetings_user_notification' )->fetch_group({
        where => 'created_date >= ? AND ' . Dicole::Utils::SQL->column_in( user_id => [ map { $_->{user_id} } @$participations ] ),
        value => [ $meeting->created_date ],
    } );

    for my $n ( @$possibly_affected_notifications ) {
        if ( $n->user_id == $from_user->id ) {
            $n->user_id( $to_user->id );
            $n->save;
        }

        my $d = $self->_get_note( data => $n );
        if ( $d && $d->{author_id} && $d->{author_id} == $from_user->id ) {
            $d->{author_id} = $to_user->id;
            $self->_set_note( data => $d, $n );
        }
    }

    my $gid = $meeting->group_id;
    $self->_transfer_object_attachments_from_group_to_group_and_from_user_to_user(
        $meeting, $gid, $gid, $from_user->id, $to_user->id
    );
    $self->_transfer_object_comments_from_group_to_group_and_from_user_to_user(
        $meeting, $gid, $gid, $from_user->id, $to_user->id
    );

    $self->_transfer_meeting_pages( $meeting, $gid, $gid, $from_user, $to_user );
    $self->_transfer_meeting_media( $meeting, $gid, $gid, $from_user, $to_user );

    if ( $meeting->begin_date > time ) {
        $self->_send_meeting_ical_request_mail( $meeting, $to_user, { type => 'invitation', from_user => Dicole::Utils::User->ensure_object( $meeting->creator_id ) } );
    }

    # TODO: transfer draft participations? -> creator_id and also user_id
}

sub _transfer_meeting_from_temp_user_to_user {
    my ( $self, $meeting, $from_user, $to_user ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    $from_user = Dicole::Utils::User->ensure_object( $from_user );
    $to_user = Dicole::Utils::User->ensure_object( $to_user );

    die unless $meeting->creator_id == $from_user->id;

    # TODO: transfer creator profile & generic user information selectively but do not override

    my $from_group_id = $meeting->group_id;
    my $to_group_id = $self->_determine_user_base_group( $to_user, $meeting->domain_id );

    my $participations = CTX->lookup_object('events_user')->fetch_group({
        where => 'event_id = ?',
        value => [ $meeting->id ],
    });

    for my $po ( @$participations ) {
        $po->group_id( $to_group_id );
        $po->save;

        eval { # In eval just to make sure - you never know! :P
            if ( $po->user_id && ! Dicole::Utils::User->belongs_to_group( $po->user_id, $to_group_id ) ) {
               CTX->lookup_action('groups_api')->e( add_user_to_group => {
                    user_id => $po->user_id, group_id => $to_group_id, domain_id => $meeting->domain_id
                } );
            }
        };

        if ( $po->user_id == $from_user->id ) {
             $self->_transfer_meeting_participation_from_temp_user_to_user( $po, $from_user, $to_user, $meeting );
        }
    }

    my $date_proposals = $self->_fetch_meeting_proposals( $meeting );

    for my $dp ( @$date_proposals ) {
        $dp->created_by( $to_user->id ) if $dp->created_by == $from_user->id;
        $dp->save;
    }

    my $draft_participants = CTX->lookup_object('meetings_draft_participant')->fetch_group({
        where => 'event_id = ?',
        value => [ $meeting->id ],
    });

    for my $po ( @$draft_participants ) {
        $po->creator_id( $to_user->id ) if $po->creator_id == $from_user->id;
        $self->_transfer_object_note_from_user_to_user_without_saving( $po, 'rsvp_required_by_user_id', $from_user, $to_user );
        $po->save;
    }

    $self->_transfer_object_attachments_from_group_to_group_and_from_user_to_user(
        $meeting, $from_group_id, $to_group_id, $from_user->id, $to_user->id
    );
    $self->_transfer_object_comments_from_group_to_group_and_from_user_to_user(
        $meeting, $from_group_id, $to_group_id, $from_user->id, $to_user->id
    );

    $self->_transfer_meeting_pages( $meeting, $from_group_id, $to_group_id, $from_user, $to_user );
    $self->_transfer_meeting_media( $meeting, $from_group_id, $to_group_id, $from_user, $to_user );

    my $events = CTX->lookup_object('event_source_event')->fetch_group({
        where => 'domain_id = ? AND group_id = ?',
        value => [ $meeting->domain_id, $from_group_id ],
    });

    for my $event ( @$events ) {
        next unless index( $event->topics, 'meeting:' . $meeting->id ) > -1;

        $event->group_id( $to_group_id );
        $event->author( $to_user->id ) if $event->author == $from_user->id;
        my $data = Dicole::Utils::JSON->decode( $event->payload );

        $data->{author_user_id} = $to_user->id if $data->{author_user_id} == $from_user->id;
        $data->{user_id} = $to_user->id if $data->{user_id} == $from_user->id;
        $data->{target_group_id} = $to_group_id;
        $event->payload( Dicole::Utils::JSON->encode( $data ) );

        my $to_user_id = $to_user->id;
        my $from_user_id = $from_user->id;

        my $secure = $event->secure;
        $secure =~ s/u\:$from_user_id(\b)/u:$to_user_id$1/g;
        $secure =~ s/g\:$from_group_id(\b)/u:$to_group_id$1/g;
        $event->secure( $secure );

        $event->save;
    }

    $meeting->group_id( $to_group_id );
    $meeting->creator_id( $to_user->id );
    $meeting->save;

    return $meeting;
}

sub _transfer_meeting_pages {
    my ( $self, $meeting, $from_group_id, $to_group_id, $from_user, $to_user ) = @_;

    my $pages = $self->_events_api( gather_pages_data => { event => $meeting } );
    for my $page_data ( @$pages ) {
        my $object = CTX->lookup_object('wiki_page')->fetch( $page_data->{page_id} );

        $self->_transfer_object_attachments_from_group_to_group_and_from_user_to_user(
            $object, $from_group_id, $to_group_id, $from_user->id, $to_user->id
        );
        $self->_transfer_object_comments_from_group_to_group_and_from_user_to_user(
            $object, $from_group_id, $to_group_id, $from_user->id, $to_user->id
        );

        CTX->lookup_action('tags_api')->e( attach_tags => {
            object => $object,
            domain_id => $meeting->domain_id,
            group_id => $to_group_id,
            user_id => 0,
            values => [ 'meeting_' . $meeting->id ],
        } );

        $object->groups_id( $to_group_id ) if $object->groups_id == $from_group_id;
        $object->creator_id( $to_user->id ) if $object->creator_id == $from_user->id;
        $object->last_author_id( $to_user->id ) if $object->last_author_id == $from_user->id;
        $object->save;

        my $versions = CTX->lookup_object('wiki_version')->fetch_group({
            where => 'page_id = ?',
            value => [ $object->id ],
        });

        for my $version ( @$versions ) {
            $version->groups_id( $to_group_id ) if $version->groups_id == $from_group_id;
            $version->creator_id( $to_user->id ) if $version->creater_id == $from_user->id;
            $version->save;
        }

        my $locks = CTX->lookup_object('wiki_lock')->fetch_group({
            where => 'page_id = ?',
            value => [ $object->id ],
        });

        for my $lock ( @$locks ) {
            $lock->user_id( $to_user->id ) if $lock->user_id == $from_user->id;
            $lock->save;
        }

    }
}

sub _transfer_meeting_media {
    my ( $self, $meeting, $from_group_id, $to_group_id, $from_user, $to_user ) = @_;

    my $media = $self->_events_api( gather_media_data => { event => $meeting, limit => 999 } );
    for my $media_data ( @$media ) {
        my $object = CTX->lookup_object('presentations_prese')->fetch( $media_data->{prese_id} );

        $self->_transfer_object_attachments_from_group_to_group_and_from_user_to_user(
            $object, $from_group_id, $to_group_id, $from_user->id, $to_user->id
        );
        $self->_transfer_object_comments_from_group_to_group_and_from_user_to_user(
            $object, $from_group_id, $to_group_id, $from_user->id, $to_user->id
        );

        CTX->lookup_action('tags_api')->e( attach_tags => {
            object => $object,
            domain_id => $meeting->domain_id,
            group_id => $to_group_id,
            user_id => 0,
            values => [ 'meeting_' . $meeting->id ],
        } );

        $object->group_id( $to_group_id ) if $object->group_id == $from_group_id;
        $object->creator_id( $to_user->id ) if $object->creator_id == $from_user->id;
        $object->save;
    }
}

sub _transfer_object_note_from_user_to_user_without_saving {
    my ( $self, $object, $note, $from_user, $to_user ) = @_;

    my $from_user_id = Dicole::Utils::User->ensure_id( $from_user );

    return 0 unless $self->_get_note( $note, $object ) == $from_user_id;

    $self->_set_note( $note, Dicole::Utils::User->ensure_id( $to_user ), $object, { skip_save => 1 } );

    return 1;
}

sub _transfer_object_attachments_from_group_to_group_and_from_user_to_user {
    my ( $self, $object, $from_group_id, $to_group_id, $from_user_id, $to_user_id ) = @_;

    my $as = CTX->lookup_action('attachments_api')->e( get_attachments_for_object => { object => $object, group_id => $from_group_id } );
    for my $a ( @$as ) {
        $a->group_id( $to_group_id ) if $a->group_id == $from_group_id;
        $a->owner_id( $to_user_id ) if $a->owner == $from_user_id;
        $a->save;
    }
}

sub _transfer_object_comments_from_group_to_group_and_from_user_to_user {
    my ( $self, $object, $from_group_id, $to_group_id, $from_id, $to_id ) = @_;

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => { object => $object, group_id => $from_group_id } );

    $thread->group_id( $to_group_id ) if $thread->group_id == $from_group_id;
    $thread->save;

    my $posts = CTX->lookup_object('comments_post')->fetch_group({
        where => 'thread_id = ?',
        value => [ $thread->id ],
    });

    for my $post ( @$posts ) {
        my $save_needed = 0;

        for my $attr ( qw( user_id published_by edited_by removed_by ) ) {
            next unless $post->get( $attr ) == $from_id;
            $post->set( $attr, $to_id );
            $save_needed = 1;
        }

        $post->save if $save_needed;
    }
}

sub _get_startup_domains {
    my ( $self ) = @_;

    return Dicole::Cache->fetch_or_store( 'startup_domains', sub {
        return $self->_fetch_startup_domains;
    }, { no_domain_id => 1, no_group_id => 1, expires => 24*60*60 } );
}

sub _update_startup_domains {
    my ( $self ) = @_;

    return Dicole::Cache->update( 'startup_domains', sub {
        return $self->_fetch_startup_domains;
    }, { no_domain_id => 1, no_group_id => 1, expires => 24*60*60 } );
}

sub _fetch_startup_domains {
    my ( $self ) = @_;

    my $list = `curl -s 'https://docs.google.com/spreadsheet/pub?key=0AhMvZDJku5J1dG5kbnNkRkFRQzJkazRTN19tOU53eUE&single=true&gid=0&range=H3%3AH999&output=csv'`;
    return [ map { $_ ? $_ : ()  } split /\n/, $list ];
}

sub _set_user_matchmaker_url {
    my ( $self, $user, $domain_id, $mmr_fragment, $old_url ) = @_;

    $old_url ||= $self->_fetch_user_matchmaker_fragment_object( $user );

    $mmr_fragment =~ s/[^a-zA-Z0-9\.\_\-]//g;
    return 0 unless $mmr_fragment =~ /.{3}/;
    return 0 unless $mmr_fragment =~ /[a-zA-Z]/;

    my $owner = $self->_resolve_matchmaker_url_user( $mmr_fragment );
    if ( ! $owner ) {
        my $url = CTX->lookup_object('meetings_matchmaker_url')->new( {
                domain_id => $domain_id,
                user_id => $user->id,
                creator_id => $user->id,
                creation_date => time,
                disabled_date => 0,
                url_fragment => $mmr_fragment,
            } );
        $url->save;

        $owner = $self->_resolve_matchmaker_url_user( $mmr_fragment );

        if ( $owner->id != $user->id ) {
            $url->remove;
            return 0;
        }
        elsif ( $old_url ) {
            $old_url->disabled_date( time );
            $old_url->save;
        }
    }
    elsif ( $owner->id != $user->id ) {
        return 0;
    }
    return 1;
}

sub _resolve_matchmaker_url_user {
    my ( $self, $fragment ) = @_;

    my $users = CTX->lookup_object('user')->fetch_group({
        from => [ 'dicole_meetings_matchmaker_url' ],
        where => 'sys_user.user_id = dicole_meetings_matchmaker_url.user_id AND dicole_meetings_matchmaker_url.url_fragment = ? and dicole_meetings_matchmaker_url.disabled_date = 0',
        value => [ $fragment ],
        order => 'creation_date asc',
    });

    return pop @$users;
}

sub _fetch_user_matchmaker_fragment_object {
    my ( $self, $user ) = @_;

    my $fragments = CTX->lookup_object('meetings_matchmaker_url')->fetch_group({
        where => 'user_id = ? AND disabled_date = 0',
        value => [ Dicole::Utils::User->ensure_id( $user ) ],
        order => 'creation_date desc',
    } );

    return shift @$fragments;
}

sub _fetch_user_matchmaker_fragment {
    my ( $self, $user ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $frag = $self->_fetch_user_matchmaker_fragment_object( $user );

    return $frag ? $frag->url_fragment : '';
}

sub _fetch_matchmaker_fragment_map_for_users {
    my ( $self, $users ) = @_;

    my $fragments = CTX->lookup_object('meetings_matchmaker_url')->fetch_group({
        where => 'disabled_date = 0 AND ' . Dicole::Utils::SQL->column_in( user_id => [ map { $_->id } @$users ] ),
        order => 'creation_date asc',
    } );

    my $fragment_map = {};
    for my $f ( @$fragments ) {
        $fragment_map->{ $f->user_id } = $f->url_fragment;
    }

    return $fragment_map;
}

sub _fetch_user_matchmakers {
    my ( $self, $user ) = @_;

    my $mmrs = CTX->lookup_object('meetings_matchmaker')->fetch_group( {
        where => 'creator_id = ? AND disabled_date = 0',
        value => [ Dicole::Utils::User->ensure_id( $user ) ],
        order => 'created_date asc',
    } ) || [];

    return $mmrs;
}

sub _fetch_suggestion_sources_for_users {
    my ( $self, $users ) = @_;

    my $uid_map = Dicole::Utils::User->ensure_object_id_map( $users );
    my $uids = [ keys %$uid_map ];

    my $mmrs = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => $uids ),
        value => [],
        order => 'created_date asc',
    } ) || [];

    return $mmrs;
}
sub _fetch_matchmakers_for_users {
    my ( $self, $users ) = @_;

    my $uid_map = Dicole::Utils::User->ensure_object_id_map( $users );
    my $uids = [ keys %$uid_map ];

    my $mmrs = CTX->lookup_object('meetings_matchmaker')->fetch_group( {
        where => 'disabled_date = 0 AND ' . Dicole::Utils::SQL->column_in( creator_id => $uids ),
        value => [],
        order => 'created_date asc',
    } ) || [];

    return $mmrs;
}

sub _fetch_user_matchmakers_in_order {
    my ( $self, $user, $domain_id ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $mmrs = $self->_fetch_user_matchmakers( $user, $domain_id );

    if ( my $meetme_order = $self->_get_note_for_user( meetme_order => $user, $domain_id ) ) {
        if ( ref( $meetme_order ) eq 'ARRAY' ) {
            my $ordered_mmrs = [];
            my $mmrs_by_id = { map { $_->id => $_ } @$mmrs };
            my $found_ids = {};
            for my $id ( @$meetme_order ) {
                next unless $mmrs_by_id->{ $id };
                push @$ordered_mmrs, $mmrs_by_id->{ $id };
                $found_ids->{ $id }++;
            }
            for my $mmr ( @$mmrs ) {
                next if $found_ids->{ $mmr->id };
                push @$ordered_mmrs, $mmr;
                $found_ids->{ $mmr->id }++;
            }
            $mmrs = $ordered_mmrs;
        }
    }

    return $mmrs;
}

sub _fetch_user_matchmaker_with_path {
    my ( $self, $user, $target_path ) = @_;

    $target_path = ( lc( $target_path ) eq 'default' ) ? '' : lc( $target_path );

    my $mmrs = $self->_fetch_user_matchmakers( $user );

    for my $m ( @$mmrs ) {
        my $path = lc( $m->vanity_url_path || '' );
        $path = '' if lc( $path ) eq 'default';
        return $m if $path eq $target_path;
    }

    return undef;
}

sub _fetch_event_matchmakers {
    my ( $self, $event ) = @_;

    my $mmrs = CTX->lookup_object('meetings_matchmaker')->fetch_group( {
        where => 'matchmaking_event_id = ? AND disabled_date = 0',
        value => [ $event->id ],
        order => 'created_date asc',
    } ) || [];

    return $mmrs;
}

sub _merge_matchmaker_preset_materials {
    my ( $self, $mmr, $preset_materials ) = @_;

    my $old_materials = $self->_get_note( preset_materials => $mmr ) || [];
    return $old_materials unless ref( $preset_materials ) eq 'ARRAY';

    my $old_attachments = {};
    for my $old_material ( @$old_materials ) {
        next unless $old_material->{attachment_id};
        $old_attachments->{ $old_material->{attachment_id} }++;
    }

    my $new_valid_materials = [];

    for my $preset_material ( @$preset_materials ) {
        if ( $preset_material->{attachment_id} ) {
            if ( $old_attachments->{ $preset_material->{attachment_id} } ) {
                push @$new_valid_materials, $preset_material;
            }
        }
        elsif ( $preset_material->{upload_id} ) {
            my $id = CTX->lookup_action('draft_attachments_api')->e( reattach_last_attachment => {
                draft_id => $preset_material->{upload_id},
                object => $mmr,
                group_id => 0,
                user_id => 0,
                domain_id => $mmr->domain_id,
            } ) || '';

            if ( $id ) {
                delete $preset_material->{upload_id};
                $preset_material->{attachment_id} = $id;
                push @$new_valid_materials, $preset_material;
            }
        }
    }

    return $new_valid_materials;
}

sub _count_available_user_matchmaking_event_schedulings {
    my ( $self, $user, $mm_event, $matchmakers, $user_created_meetings ) = @_;

    $user_created_meetings ||= $self->_get_user_created_meetings_for_matchmaking_event( $user, $mm_event, $matchmakers );
    my $limit = $self->_get_note( reserve_limit => $mm_event );

    return -1 unless $limit;

    my $left = $limit - scalar( @$user_created_meetings );
    return $left > 0 ? $left : 0;
}

sub _get_user_created_meetings_for_matchmaking_event {
    my ( $self, $user, $mm_event, $matchmakers ) = @_;

    $matchmakers ||= CTX->lookup_object('meetings_matchmaker')->fetch_group({
        where => 'matchmaking_event_id = ? AND disabled_date = 0',
        value => [ $mm_event->id ],
    });

    my @id_list = map { $_->id } @$matchmakers;

    # Use old locks to detect which have advanced to meeting status
    my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group({
        where => 'expected_confirmer_id = ? AND created_meeting_id != 0 AND ' . Dicole::Utils::SQL->column_in( matchmaker_id => \@id_list ),
        value => [ Dicole::Utils::User->ensure_id( $user ) ],
    });

    my @meeting_id_list = map { $_->created_meeting_id } @$locks;

    my $meetings = $self->_fetch_meetings( {
        where => Dicole::Utils::SQL->column_in( event_id => \@meeting_id_list ),
    });

    return [ grep { $self->_get_note( attached_to_matchmaking_event_id => $_ ) == $mm_event->id } @$meetings ];

    return $meetings;
}

sub _post_meeting_comment_under_agenda {
    my ( $self, $meeting, $comment_html, $comment_text, $by_user, $anon_email, $opts ) = @_;

    my $agenda = $self->_fetch_meeting_agenda_page( $meeting );
    return undef unless $agenda;

    return $self->_post_meeting_comment_under_page( $meeting, $comment_html, $comment_text, $agenda, $by_user, $anon_email, $opts );
}

sub _post_meeting_comment_under_page {
    my ( $self, $meeting, $comment_html, $comment_text, $page, $by_user, $anon_email, $opts ) = @_;

    my $user_id = $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : 0;
    $comment_html ||= Dicole::Utils::HTML->text_to_html( $comment_text );

    $opts ||= {};

    my $comment = CTX->lookup_action('comments_api')->e( add_comment_and_return_post => {
            object => $page,
            group_id => $meeting->group_id,
            date => $opts->{creation_epoch},
            user_id => 0,
            content => $comment_html,
            requesting_user_id => $user_id,
            $user_id ? () : (
                anon_email => Dicole::Utils::Text->ensure_utf8( $anon_email ),
            ),
            domain_id => $meeting->domain_id,
        } );

    if ( $comment && ! $opts->{skip_event} ) {
        $self->_store_comment_event( $meeting, $comment, $page, 'created', { author => $user_id } );
    }

    return $comment;
}


sub _get_meeting_matchmaking_requester_name {
    my ( $self, $meeting ) = @_;

    my $requester_user = $self->_get_meeting_matchmaking_requester_user( $meeting );
    return '' unless $requester_user;

    return Dicole::Utils::User->name( $requester_user );
}

sub _get_meeting_matchmaking_requester_user {
    my ( $self, $event ) = @_;

    if ( my $matchmaker_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $event ) ) {
        if ( my $uid = $self->_get_note_for_meeting( matchmaking_requester_id => $event ) ) {
            return Dicole::Utils::User->ensure_object( $uid );
        }

        my $requester_locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group({
                where => 'matchmaker_id = ? AND created_meeting_id = ?',
                value => [ $matchmaker_id, $event->id ],
            });

        if ( my $requester_user_id = $requester_locks->[0]->expected_confirmer_id ) {
            return Dicole::Utils::User->ensure_object( $requester_user_id );
        }
    }

    return '';
}

sub _get_meeting_matchmaking_event_name {
    my ( $self, $event, $matchmaker, $mm_event ) = @_;

    if ( $matchmaker ||= $self->_get_meeting_matchmaker( $event ) ) {
        $mm_event ||= ( $matchmaker && $matchmaker->matchmaking_event_id ) ? $self->_ensure_object_of_type( meetings_matchmaking_event => $matchmaker->matchmaking_event_id ) : undef;
        return $mm_event->custom_name if $mm_event;
    }

    return '';
}

sub _get_meeting_matchmaker {
    my ( $self, $meeting ) = @_;

    if ( my $matchmaker_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $meeting ) ) {
        return $self->_ensure_object_of_type( meetings_matchmaker => $matchmaker_id );
    }
    return undef;
}

sub _send_matchmaking_accept_email {
    my ( $self, $meeting, $user ) = @_;

    my $matchmaker = $self->_get_meeting_matchmaker( $meeting );
    my $mm_event = ( $matchmaker && $matchmaker->matchmaking_event_id ) ? $self->_ensure_object_of_type( meetings_matchmaking_event => $matchmaker->matchmaking_event_id ) : undef;
    my $mm_event_name = $self->_get_meeting_matchmaking_event_name( $meeting, $matchmaker, $mm_event );
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $draft_objects = CTX->lookup_object('meetings_draft_participant')->fetch_group( {
            where => 'event_id = ? AND removed_date = 0',
            value => [ $meeting->id ],
        } );

    $user = Dicole::Utils::User->ensure_object( $user );
    my $user_info = $self->_gather_user_info( $user, -1, $meeting->domain_id );

    for my $draft_object ( @$draft_objects ) {
        next unless $draft_object->user_id;
        my $draft_user = Dicole::Utils::User->ensure_object( $draft_object->user_id );
        my $schedulings_left = $mm_event ? $self->_count_available_user_matchmaking_event_schedulings( $draft_user, $mm_event ) : -1;
        my $user_matchmaking_url = $mm_event ? $self->_get_note( organizer_list_url => $mm_event ) || $self->_generate_authorized_uri_for_user( $domain_host . $self->derive_url( action => 'meetings', task => 'matchmaking_list', additional => [ $matchmaker->matchmaking_event_id ] ), $draft_user, $meeting->domain_id ) : '';

        $self->_send_meeting_user_template_mail( $meeting, $draft_user, 'meetings_matchmaker_accepted', {
                user_name => Dicole::Utils::User->name( $draft_user ),
                matchmaker_name => Dicole::Utils::User->name( $user ),
                matchmaker_email => $user->email,
                matchmaker_company => $user_info->{organization},
                matchmaking_url => $user_matchmaking_url,
                matchmaking_event => $mm_event_name,
                meeting_slots => $schedulings_left,
            } );
    }
}

sub _matchmaking_event_market_list {
    my ( $self, $mm_event ) = @_;

    return $self->_get_note( market_list => $mm_event ) || [],
}

sub _matchmaking_event_track_list {
    my ( $self, $mm_event ) = @_;

    return $self->_get_note( track_list => $mm_event ) || [],
}

sub _determine_meeting_invite_greeting_default_parameters_for_user {
    my ( $self, $meeting, $user, $meeting_time, $pos ) = @_;

    return $self->_determine_invite_default_parameters( $meeting, $meeting_time, $pos, $user );
}

sub _determine_invite_default_parameters {
    my ( $self, $meeting, $meeting_time, $pos, $user ) = @_;

    $user ||= CTX->request->auth_user;
    $user = Dicole::Utils::User->ensure_object( $user );

    $meeting_time ||= $self->_form_meeting_time_string( $meeting, $user );

    $pos ||= $self->_fetch_meeting_proposals( $meeting );
    my $user_info = $self->_gather_user_info( $user, -1, $meeting->domain_id );

    my $default_subject = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_visitor_invite_subject_template' ),{
            open_scheduling_option_count => scalar( @$pos ),
            open_scheduling_options => [ map { { id => $_->id } } @$pos ],
            inviting_user_name => Dicole::Utils::User->name( $user ),
            inviting_user_company => $user_info->{organization} || '',
            meeting_title => $self->_meeting_title_string( $meeting ),
            meeting_time => $meeting_time,
            matchmaker_meeting => $self->_get_note( created_from_matchmaker_id => $meeting ) ? 1 : 0,
        }, { user => $user }
    );

    my $default_message = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_visitor_invite_default_greeting_text_template' ),{
            open_scheduling_option_count => scalar( @$pos ),
            inviting_user_name => Dicole::Utils::User->name( $user ),
            inviting_user_company => $user_info->{organization} || '',
            meeting_title => $self->_meeting_title_string( $meeting ),
            meeting_time => $meeting_time,
        }, { user => $user }
    );

    my $default_message_rsvp = Dicole::Utils::Template->process(
        Dicole::Utils::Mail->nmail_template_for_key( 'meetings_visitor_invite_default_greeting_text_template' ),{
            open_scheduling_option_count => scalar( @$pos ),
            inviting_user_name => Dicole::Utils::User->name( $user ),
            inviting_user_company => $user_info->{organization} || '',
            meeting_title => $self->_meeting_title_string( $meeting ),
            meeting_time => $meeting_time,
            rsvp_required => 1,
        }, { user => $user }
    );

    return {
        subject => $default_subject,
        subject_rsvp => $default_subject,
        content => $default_message,
        content_rsvp => $default_message_rsvp
    };
}

sub _generate_meeting_title_from_participants {
    my ( $self, $meeting, $lc_opts ) = @_;

    my $users = $self->_fetch_meeting_participant_users( $meeting );
    my $dois = $self->_gather_meeting_draft_participants_info( $meeting, -1 );

    my @names = map { Dicole::Utils::User->name( $_ ) } @$users;
    push @names, map { $_->{name} || () } @$dois;

    my $last = pop @names;

    return undef unless scalar( @names );

    return $self->_ncmsg( "Meeting between %1\$s", $lc_opts, [ join( ", ", @names ) . " & $last" ] );
}

sub _rename_meeting_media {
    my ( $self, $meeting, $prese, $title, $opts ) = @_;

    $opts ||= {};
    $meeting = $self->_ensure_meeting_object( $meeting );

    if ( $prese && ! ref( $prese ) ) {
        $prese = CTX->lookup_object( 'presentations_prese' )->fetch( $prese );
    }

    die unless $prese;

    $prese->name( $title );
    $prese->save;

    $self->_store_material_event( $meeting, $prese, 'edited' ) unless $opts->{skip_event};

    return 1;
}

sub _rename_meeting_page {
    my ( $self, $meeting, $page, $title, $opts ) = @_;

    $opts ||= {};
    $meeting = $self->_ensure_meeting_object( $meeting );

    if ( $page && ! ref( $page ) ) {
        $page = CTX->lookup_object( 'wiki_page' )->fetch( $page );
    }

    die unless $page;

    CTX->lookup_action('wiki_api')->e( simple_rename_page => {
        page => $page,
        title => $title,
        suffix_tag => $meeting->sos_med_tag,
    } );

    $self->_store_material_event( $meeting, $page, 'edited' ) unless $opts->{skip_event};

    return 1;
}


sub _fill_profile_info_from_params {
    my ( $self, $user, $domain_id, $params, $force ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        user_id => $user->id,
        domain_id => $domain_id,
        attributes => {
#            contact_email => CTX->request->param('email') || '',
            contact_phone => undef,
            contact_organization => undef,
            contact_title => undef,
            contact_skype => undef,
            personal_linkedin => undef,
        },
    } );

    my %attr_param_map = (
        contact_phone => 'phone',
        contact_organization => 'organization',
        contact_title => 'organization_title',
        contact_skype => 'skype',
        personal_linkedin => 'linkedin',
    );

    my $update_attrs = {};

    for my $attr ( keys %attr_param_map ) {
        if ( $force || ! $attrs->{ $attr } ) {
            my $value = $params->{ $attr_param_map{ $attr } } || '';
            $value = '' if $value eq ( $params->{ $attr_param_map{ $attr } . '_default_value' } || '' );
            $update_attrs->{ $attr } = $value;
        }
    }

    CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        user_id => $user->id,
        domain_id => $domain_id,
        attributes => $update_attrs,
    } );

    if ( $params->{name} && ! $params->{first_name} && !  $params->{last_name} ) {
        my ( $f, $l ) = split /\s+/, $params->{name}, 2;
        $params->{first_name} = $f;
        $params->{last_name} = $l;
    }

    $user->first_name( $params->{first_name} || '' ) if $force || ! $user->first_name;
    $user->last_name( $params->{last_name} || '' ) if $force || ! $user->last_name;

    $user->timezone( $params->{time_zone} || $params->{timezone} ) if $params->{timezone} || $params->{time_zone};

    $user->save;

    if ( CTX->request && CTX->request->auth_user_id == $user->id ) {
        my $session = CTX->request->session;
        $session->{_oi_cache}{user_refresh_on} = time;
    }

    my $existing_profile_image = CTX->lookup_action('networking_api')->e( user_portrait => {
            user_id => $user->id,
            domain_id => $domain_id,
            no_default => 1,
        } );

    CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_draft => {
            user_id => $user->id,
            domain_id => $domain_id,
            draft_id => $params->{draft_id},
        } ) if $params->{draft_id} && ( $force || ! $existing_profile_image );
}

sub _check_if_meeting_has_material {
    my ( $self, $meeting, $material ) = @_;

    $meeting = $self->_ensure_meeting_object( $meeting );
    my $tag = $meeting->sos_med_tag;

    my $tags = CTX->lookup_action('tags_api')->e( get_tags => {
            object => $material,
            domain_id => $meeting->domain_id,
            group_id => $meeting->group_id,
            user_id => 0,
        } );

    for my $t ( @$tags ) {
        return 1 if $t eq $meeting->sos_med_tag;
    }

    return 0;
}

sub _get_user_existing_suggestion_sources {
    my ( $self, $user, $domain_id, $extra_where, $extra_values, $order ) = @_;

    my @where = ( 'vanished_date = 0' );
    push @where, $extra_where || ();
    my $where = '('. join( ') AND (', @where ) .')';

    return $self->_get_user_suggestion_sources( $user, $domain_id, $where, $extra_values, $order );
}

sub _get_user_suggestion_sources {
    my ( $self, $user, $domain_id, $extra_where, $extra_values, $order ) = @_;

    my @where = ('user_id = ?');
    my @value = ( Dicole::Utils::User->ensure_id( $user ) );

    push @where, $extra_where || ();
    my $where = '('. join( ') AND (', @where ) .')';

    push @value, @{ $extra_values || [] };

    return CTX->lookup_object('meetings_suggestion_source')->fetch_group({
        where => $where,
        value => \@value,
        order => $order || 'id asc',
    });
}

sub _set_user_suggestion_sources_for_provider {
    my ( $self, $user, $domain_id, $sources, $provider_id, $provider_type, $provider_name ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );

    my $previous_sources = $self->_get_user_suggestion_sources( $user, $domain_id, 'provider_id = ?', [ $provider_id ] );
    my $previous_sources_by_uid = { map { $_->uid => $_ } @$previous_sources };

    my $verified_sources = {};

    for my $source ( @$sources ) {

        my $uid = $source->{uid};
        if ( $provider_type eq 'google' ) {
            $uid ||= "$provider_type:" . $source->{notes}->{id_inside_container};
        }
        else {
            $uid ||= "$provider_type:$provider_id:" . $source->{notes}->{id_inside_container};
        }
        next if $verified_sources->{ $uid }++;

        my $suggestion_source_data = {
            uid => $uid,
            name => $source->{name},
            notes => $source->{notes},
            provider_id => $provider_id,
            provider_type => $provider_type,
            provider_name => $provider_name,
        };

        $self->_ensure_user_suggestion_source_exists( $user, $domain_id, $suggestion_source_data, $previous_sources, $previous_sources_by_uid );
    }

    for my $old_source ( @$previous_sources ) {
        next if $verified_sources->{ $old_source->uid };
        $old_source->vanished_date( time );
        $old_source->save;
    }
}

sub _ensure_user_suggestion_source_exists {
    my ( $self, $user, $domain_id, $source_data, $previous_sources, $previous_sources_by_uid ) = @_;

    return unless $source_data->{uid};

    if ( $source_data->{uid} !~ /^google/ ) {
        $self->_ensure_user_device_calendar_connected_is_set( $user, $domain_id );
    }

    my $object = $previous_sources_by_uid ? $previous_sources_by_uid->{ $source_data->{uid} } : undef;

    if ( ! $previous_sources_by_uid ) {
        my $candidates = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
            where => 'user_id = ? AND provider_id = ? AND uid = ?',
            value => [ $user->id, $source_data->{provider_id} || '', $source_data->{uid} ],
            order => 'id asc',
        } );
        $object = shift @$candidates;
    }

    my $new = 0;

    if ( ! $object ) {
        $object = CTX->lookup_object('meetings_suggestion_source')->new( {
            domain_id => $domain_id,
            user_id => $user->id,
            uid => $source_data->{uid},
            provider_id => $source_data->{provider_id} || '',
            provider_type => $source_data->{provider_type} || '',
            created_date => time,
        } );

        push @$previous_sources, $object if $previous_sources;
        $previous_sources_by_uid->{ $source_data->{uid} } = $object if $previous_sources_by_uid;

        $new = 1;
    }

    my $update_treshold = 5*60;

    # TODO: implement stamping for the future so that note changes get propagated timely
    return if ! $new && ( $object->provider_name || '' ) eq $source_data->{provider_name} && ( $object->name || '' ) eq $source_data->{name} && ( $object->verified_date || 0 ) + $update_treshold > time && ! $object->vanished_date;

    $object->provider_name( $source_data->{provider_name} || '' );
    $object->name( $source_data->{name} );
    $object->verified_date( time );
    $object->vanished_date( 0 );

    for my $key ( keys %{ $source_data->{notes} || {} } ) {
        $self->_set_note( $key => $source_data->{notes}->{ $key }, $object, { skip_save => 1 } );
    }

    $object->save;

    if ( $new ) {
        my $candidates = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
            where => 'user_id = ? AND provider_id = ? AND uid = ?',
            value => [ $user->id, $source_data->{provider_id} || '', $source_data->{uid} ],
            order => 'id asc',
        } );

        shift @$candidates;
        $_->remove for @$candidates;
    }
}

sub _ensure_user_calendar_suggestion_exists {
    my ( $self, $user, $domain_id, $suggestion_data, $suggestions, $suggestion_by_uid, $suggestions_by_begin, $previous_sources ) = @_;

    my $user_id = $user->id;
    my $s = $suggestion_data;

    my $uid = $s->{uid};
    my $title = $s->{title};
    my $start_epoch = $s->{begin_date};
    my $end_epoch = $s->{end_date};

    return unless $start_epoch && $end_epoch;

    $title //= '?';
    $title = '?' if $title eq '';

    if ( ! $suggestions ) {
        $start_epoch =~ s/[^\d]//g;
        my $where = 'begin_date = ' . $start_epoch;
        if ( $uid ) {
            $where = "( $where OR uid = \"" . Dicole::Utils::SQL->quoted_string( $uid ) . "\" )";
        }

        $suggestions = $self->_get_user_meeting_suggestions( $user, $domain_id, $where );
    }

    $suggestion_by_uid ||= { map { $_->uid ? ( $_->uid => $_ ) : () } @$suggestions };

    if ( ! $suggestions_by_begin ) {
        $suggestions_by_begin = {};
        for my $sugg ( @$suggestions ) {
            my $list = $suggestions_by_begin->{ $sugg->begin_date } ||= [];
            push @$list, $sugg;
        }
    }

    my $old_suggestion = $uid ? $suggestion_by_uid->{ $uid } : undef ;

    for my $sugg ( @{ $suggestions_by_begin->{ $start_epoch } || [] } ) {
        last if $old_suggestion;
        next if $sugg->end_date != $end_epoch;
        next if lc( $sugg->title ) ne lc( $title );
        $old_suggestion = $sugg;
    }

    my $stamp = Dicole::Utils::Data->signature( $s );

    my $notes = $s->{notes} || {};
    delete $s->{notes};

    if ( $notes->{source_uid} ) {
        $self->_ensure_user_suggestion_source_exists( $user, $domain_id, {
            uid => $notes->{source_uid},
            name => $notes->{source_name},
            provider_id => $notes->{source_provider_id},
            provider_type => $notes->{source_provider_type},
            provider_name => $notes->{source_provider_name},
            notes => $notes->{source_notes},
        }, $previous_sources );
    }
    else {
        if ( $s->{source} ) {
            my ( $type, $name ) = split ":", $s->{source};
            if ( $type eq 'phone' ) {
                $self->_ensure_user_suggestion_source_exists( $user, $domain_id, {
                    uid => 'phone:'. $name,
                    name => $name,
                    provider_id => 'phone',
                    provider_type => 'phone',
                    provider_name => 'Phone',
                }, $previous_sources );
            }
        }
    }

    if ( $old_suggestion ) {
        my $old_stamp = $self->_get_note( data_signature => $old_suggestion );
        unless ( $old_stamp && ( $old_stamp eq $stamp ) ) {
            for my $key ( keys %$s ) {
                $old_suggestion->set( $key, $s->{ $key } );
            }
            for my $key ( keys %$notes ) {
                $self->_set_note( $key => $notes->{ $key }, $old_suggestion, { skip_save => 1 } );
            }
            $self->_set_note( data_signature => $stamp, $old_suggestion );
        }

        if ( $old_suggestion->vanished_date ) {
            $old_suggestion->vanished_date( 0 );
            $old_suggestion->save;
        }

        return $old_suggestion;
    }
    else {
        my $sugg = CTX->lookup_object('meetings_meeting_suggestion')->new( $s );

        $sugg->created_date( time );
        $sugg->removed_date( 0 );
        $sugg->vanished_date( 0 );
        $sugg->disabled_date( 0 );

        for my $key ( keys %$notes ) {
            $self->_set_note( $key => $notes->{ $key }, $sugg, { skip_save => 1 } );
        }

        $self->_set_note( data_signature => $stamp, $sugg );

        return $sugg;
    }
}

sub _vanish_user_calendar_suggestions_within_dates_which_are_missing_from_list {
    my ( $self, $user, $domain_id, $calendar_uid, $start_epoch, $end_epoch, $ensured_suggestion_list ) = @_;

    my $ensured_suggestion_id_list = [ map { $_->id } @$ensured_suggestion_list ];

    return $self->_vanish_user_calendar_suggestions_within_dates_which_are_missing_from_id_list(
        $user, $domain_id, $calendar_uid, $start_epoch, $end_epoch, $ensured_suggestion_id_list
    );
}

sub _vanish_user_calendar_suggestions_within_dates_which_are_missing_from_id_list {
    my ( $self, $user, $domain_id, $calendar_uid, $start_epoch, $end_epoch, $ensured_suggestion_id_list ) = @_;

    $start_epoch =~ s/[^\d]//g;
    $end_epoch =~ s/[^\d]//g;

    my $suggestions = $self->_get_active_user_meeting_suggestions( $user, $domain_id, "end_date >= $start_epoch AND begin_date < $end_epoch" );
    my %ensured_lookup = map { $_ => 1 } @$ensured_suggestion_id_list;

    for my $suggestion ( @$suggestions ) {
        next unless ( $suggestion->source eq $calendar_uid ) || ( $self->_get_note( source_uid => $suggestion ) eq $calendar_uid );
        next if $ensured_lookup{ $suggestion->id };
        $suggestion->vanished_date( time );
        $self->_set_note( data_signature => '', $suggestion );
    }
}

sub _spanset_to_matchmaker_options {
    my ( $self, $mmr, $spanset, $tz, $lang ) = @_;

    my $options = [];

    my $iter = $spanset->iterator;

    while ( my $dts = $iter->next ) {
        # These need to be cloned to mutate timezone
        my $start = $dts->start->clone;
        my $end = $dts->end->clone;

        my $option = {
            start_epoch => $start->epoch,
            start => $start->epoch * 1000,
            end_epoch => $end->epoch,
            end => $end->epoch * 1000,
        };

        if ( $mmr ) {
            $option->{matchmaker_id} = $mmr->id;
        }

        $option->{id} = join "_", ( $option->{start_epoch}, $option->{end_epoch} );

        push @$options, $option;
    };

    return $options;
}

sub _get_matchmaker_creator_reservation_spanset_within_timespan {
    my ( $self, $mmr, $span, $params ) = @_;

    $params ||= {};
    $params->{buffer} = $self->_get_note( buffer => $mmr );
    $params->{source_settings} = $self->_get_note( source_settings => $mmr );

    $self->_ensure_imported_upcoming_meeting_suggestions_for_matchmaker( $mmr );

    $params->{local_matchmaker_id} = $mmr->id;

    return $self->_get_user_reservation_spanset_within_timespan_in_domain(
        $mmr->creator_id, $span, $mmr->domain_id, $params
    );
}

sub _suggestion_looks_like_a_whole_day_task {
    my ( $self, $s ) = @_;

    return 0 unless $s && $s->begin_date && $s->end_date;

    my $duration = $s->end_date - $s->begin_date;

    return 0 if $duration < 86395 || $duration > 86405;

    return 0 if $self->_get_note( freebusy_value => $s );

    return 1;
}

sub _suggestion_freebusy_is_free {
    my ( $self, $s ) = @_;

    return 0 unless $s;
    my $value = $self->_get_note( freebusy_value => $s );
    return 0 unless $value && $value eq 'free';
    return 1;
}

sub _user_meeting_attendance_is_hidden {
    my ( $self, $user, $meeting, $po ) = @_;

    $po ||= $self->_get_user_meeting_participation_object( $user, $meeting );

    return $self->_get_note( is_hidden => $po ) ? 1 : 0;
}

sub _user_is_not_attending_meeting {
    my ( $self, $user, $meeting, $po ) = @_;

    $po ||= $self->_get_user_meeting_participation_object( $user, $meeting );

    my $rsvp = $self->_get_note( rsvp => $po );

    return 1 if $rsvp && $rsvp eq 'no';

    return 0;
}

sub _get_user_reservation_spanset_within_timespan_in_domain {
    my ( $self, $user, $span, $domain_id, $params ) = @_;

    return DateTime::SpanSet->from_spans( spans => [] ) unless $span;

    $params ||= {};
    my $buffer = $params->{buffer} || 0;
    my $source_settings = $params->{source_settings};
    if ( ! $source_settings ) {
        if ( $params->{disable_legacy_source_settings} ) {
            $source_settings = {};
        }
        else {
            $source_settings = $self->_form_legacy_source_settings( $user, $domain_id, 'include_phone' );
        }
    }
    my $set = [];

    my $meetings = $self->_get_user_meetings_within_timespan_in_domain( $user, $span, $domain_id );

    my $pos = $self->_get_user_meeting_participation_objects_in_domain( $user, $domain_id, Dicole::Utils::SQL->column_in( event_id => [ map { $_->id } @$meetings ] ) );
    my $po_by_meeting_id = { map { $_->event_id => $_ } @$pos };

    for my $meeting ( @$meetings ) {
        next if $self->_meeting_is_cancelled( $meeting );

        my $po = $po_by_meeting_id->{ $meeting->id };
        next unless $po;

        next if $self->_user_is_not_attending_meeting( $user, $meeting, $po );
        next if $self->_user_meeting_attendance_is_hidden( $user, $meeting, $po );

        push @$set, Dicole::Utils::Date->epochs_to_span( $meeting->begin_date, $meeting->end_date );
    }

    my $suggestions = $self->_get_upcoming_nonvanished_user_meeting_suggestions( $user, $domain_id, "begin_date <= " . $span->end->epoch );

    for my $suggestion ( @$suggestions ) {
        next unless $source_settings->{enabled}->{ $self->_get_note( source_uid => $suggestion ) || '' };
        next if $self->_suggestion_looks_like_a_whole_day_task( $suggestion );
        next if $self->_suggestion_freebusy_is_free( $suggestion );
        push @$set, Dicole::Utils::Date->epochs_to_span( $suggestion->begin_date, $suggestion->end_date );
    }

    if ( $source_settings->{legacy_phone} ) {
        for my $suggestion ( @$suggestions ) {
            next unless ( $suggestion->source || '' ) =~ /^phone/;
            next if $self->_suggestion_looks_like_a_whole_day_task( $suggestion );
            push @$set, Dicole::Utils::Date->epochs_to_span( $suggestion->begin_date, $suggestion->end_date );
        }
    }

    # OPTIMIZE: add span limiting
    my $user_id = Dicole::Utils::User->ensure_id( $user );
    my $locks_by_user = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
            where => 'expected_confirmer_id = ? OR creator_id = ?',
            value => [ $user_id, $user_id ],
        } );

    my $locks_for_user = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
            from => [ 'dicole_meetings_matchmaker' ],
            where => 'dicole_meetings_matchmaker.creator_id = ? AND dicole_meetings_matchmaker.id = dicole_meetings_matchmaker_lock.matchmaker_id',
            value => [ $user_id ],
        } );

    for my $lock ( @$locks_by_user, @$locks_for_user ) {
        next if $params->{ignore_local_locks} && $params->{local_matchmaker_id} && $params->{local_matchmaker_id} == $lock->matchmaker_id;
        next if $lock->expire_date < time;
        next if $lock->cancel_date;

        push @$set, Dicole::Utils::Date->epochs_to_span( $lock->locked_slot_begin_date, $lock->locked_slot_end_date );
    }

    if ( $buffer ) {
        my $buffered_set = [];
        for my $span ( @$set ) {
            push @$buffered_set, Dicole::Utils::Date->epochs_to_span(
                $span->start->epoch - ( $buffer * 60 ), $span->end->epoch + ( $buffer * 60 )
            );
        }
        $set = $buffered_set;
    }

    return DateTime::SpanSet->from_spans( spans => $set );
}

sub _get_multiple_user_calendar_spanset_within_timespan_in_domain {
    my ( $self, $users, $span, $domain_id, $opts ) = @_;

    return DateTime::SpanSet->from_spans( spans => [] ) unless $span;

    # TODO: force source updates before returning unless explicitly not wanted in opts

    my %user_map = map { $_->id => $_ } @$users;

    my $sql = 'SELECT DISTINCT dicole_events_event.*' .
        ' FROM dicole_events_event, dicole_events_user' .
        " WHERE dicole_events_user.domain_id = $domain_id AND dicole_events_event.begin_date > 0" .
        ' AND ' . Dicole::Utils::SQL->column_in( 'dicole_events_user.user_id', [ map { $_->id } @$users ] ) .
        ' AND dicole_events_event.event_id = dicole_events_user.event_id AND dicole_events_event.removed_date = 0' .
        ' AND dicole_events_user.removed_date = 0' .
        ' AND dicole_events_event.begin_date < ' . $span->end->epoch .
        ' AND dicole_events_event.end_date >' . $span->start->epoch;

    my $meetings = CTX->lookup_object('events_event')->fetch_group( { sql => $sql } );

    my $suggestions = CTX->lookup_object('meetings_meeting_suggestion')->fetch_group( {
        where => "removed_date = 0 AND vanished_date = 0" .
            ' AND ' . Dicole::Utils::SQL->column_in( user_id => [ map { $_->id } @$users ] ) .
            ' AND begin_date < ' . $span->end->epoch .
            ' AND end_date >' . $span->start->epoch,
    } );

    my $sources = CTX->lookup_object('meetings_suggestion_source')->fetch_group( {
        where => 'vanished_date = 0' .
            ' AND ' . Dicole::Utils::SQL->column_in( user_id => [ map { $_->id } @$users ] ),
    } );

    my %source_settings_by_user = ();
    my %enabled_source_by_id = ();
    for my $source ( @$sources ) {
        my $user = $user_map{ $source->user_id };
        next unless $user;
        my $source_settings = $source_settings_by_user{ $user->id } ||= $self->_get_note_for_user( meetings_swiping_source_settings => $user, $domain_id ) || $self->_get_note_for_user( meetings_source_settings => $user, $domain_id ) || {};
        next if $source_settings->{disabled}->{ $source->uid };
        next unless $source_settings->{enabled}->{ $source->uid } || $self->_get_note( google_calendar_is_primary => $source ) || $self->_get_note( is_primary => $source );
        $enabled_source_by_id{ $source->user_id }{ $source->uid } = 1;
    }

    my $set = [];

    for my $m ( @$meetings ) {
        push @$set, Dicole::Utils::Date->epochs_to_span( $m->begin_date, $m->end_date );
    }

    for my $s ( @$suggestions ) {
        next unless $enabled_source_by_id{ $s->user_id }{ $s->source };
        next if $self->_suggestion_looks_like_a_whole_day_task( $s );
        next if $self->_suggestion_freebusy_is_free( $s );
        push @$set, Dicole::Utils::Date->epochs_to_span( $s->begin_date, $s->end_date );
    }

    return DateTime::SpanSet->from_spans( spans => $set );
}

sub _fetch_user_swiping_enabled_source_map {
    my ( $self, $user, $domain_id, $sources ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    $sources ||= $self->_get_user_existing_suggestion_sources( $user, $domain_id );

    my $enabled_source_by_id = {};
    my $source_settings = $self->_get_note_for_user( meetings_swiping_source_settings => $user, $domain_id ) || $self->_get_note_for_user( meetings_source_settings => $user, $domain_id ) || {};
    for my $source ( @$sources ) {
        next if $source_settings->{disabled}->{ $source->uid };
        next unless $source_settings->{enabled}->{ $source->uid } || $self->_get_note( google_calendar_is_primary => $source ) || $self->_get_note( is_primary => $source );
        $enabled_source_by_id->{ $source->uid } = 1;
    }

    return $enabled_source_by_id;
}

sub _form_legacy_source_settings {
    my ( $self, $user, $domain_id, $include_legacy_phone, $sources ) = @_;

    $sources ||= $self->_get_user_existing_suggestion_sources( $user, $domain_id );

    my $settings = { enabled => {}, disabled => {} };
    if ( $include_legacy_phone ) {
        $settings->{legacy_phone} = 1;
    }
    for my $source ( @$sources ) {
        next unless $self->_get_note( google_calendar_is_primary => $source ) || $self->_get_note( is_primary => $source );
        $settings->{enabled}{ $source->uid } = 1;
    }
    return $settings;
}

sub _matchmaker_spanset_within_epochs {
    my ( $self, $mmr, $begin_epoch, $end_epoch, $timezone, $lang ) = @_;

    $timezone ||= $self->_get_note( time_zone => $mmr );

    $mmr = $self->_ensure_matchmaker_object( $mmr );
    my $slots = $self->_get_note( slots => $mmr ) || [];
    $slots = Dicole::Utils::JSON->decode( $slots ) if ref( $slots ) ne 'ARRAY';

    my $spansets = $self->_matchmaker_slots_to_spanset_within_epochs(
        $slots, $begin_epoch, $end_epoch, $timezone
    );

    return $spansets;
}

sub _matchmaker_slots_to_spanset_within_epochs {
    my ( $self, $slots, $begin_epoch, $end_epoch, $timezone, $lang ) = @_;

    my $set = [];
    for my $slot ( @$slots ) {
        my $dt = Dicole::Utils::Date->epoch_to_datetime( $begin_epoch, $timezone, $lang );
        while ( $dt->epoch < $end_epoch ) {
            if ( $dt->day_of_week - 1 == $slot->{weekday} ) {
                my $day_start = Dicole::Utils::Date->datetime_to_day_start_datetime( $dt );
                my $slot_end_epoch = $day_start->epoch + $slot->{end_second};
                if ( $slot_end_epoch > $begin_epoch ) {
                    my $slot_begin_epoch = $day_start->epoch + $slot->{begin_second};
                    $slot_begin_epoch = $begin_epoch if $begin_epoch > $slot_begin_epoch;
                    $slot_end_epoch = $end_epoch if $end_epoch < $slot_end_epoch;
                    if ( $slot_begin_epoch < $slot_end_epoch ) {
                        push @$set, Dicole::Utils::Date->epochs_to_span(
                            $slot_begin_epoch, $slot_end_epoch, $timezone, $lang
                        );
                    }
                }
            }
            # NOTE: add hours instead of days to avoid DST crash on nonexisting hours
            my $orig_hour = $dt->hour;
            $dt->add( hours => 24 );

            # NOTE this corrects for the one hour DST changes
            # TODO: refactor this to the lib
            if ( $orig_hour != $dt->hour ) {
                if ( $orig_hour > $dt->hour ) {
                    $dt->add( hours => 1 );
                }
                else {
                    $dt->subtract( hours => 1 );
                }
                if ( $orig_hour == 0 && $dt->hour == 22 ) {
                    $dt->add( hours => 2 );
                }
                if ( $orig_hour == 23 && $dt->hour == 1 ) {
                    $dt->subtract( hours => 2 );
                }
            }
        }
    }

    return DateTime::SpanSet->from_spans( spans => $set );
}

sub _get_matchmaker_available_option_spanset {
    my ( $self, $matchmaker, $params ) = @_;

    my $begin = $params->{begin_epoch};
    my $end = $params->{end_epoch};
    $begin = time if $begin < time;
    $end = time if $end < time;

    my $total_spanset = $self->_matchmaker_spanset_within_epochs( $matchmaker, $begin, $end );
    my $locations = $self->_matchmaker_locations( $matchmaker );

    my $availability_data_to_spanset_cache = {};
    my $locks_by_location_map = $self->_gather_locks_by_location_map( $locations );

    my $any_location_spanset = DateTime::SpanSet->from_spans( spans => [] );
    for my $location ( @$locations ) {
        my $cached_spanset = $availability_data_to_spanset_cache->{ $location->availability_data } ||= $self->_get_location_option_spanset_within_epochs( $location, $begin, $end );
        my $spanset = $cached_spanset->clone;

        if ( ! $params->{ignore_local_locks} ) {
            my $locked_spanset = $self->_get_location_lock_spanset( $location, $spanset, $locks_by_location_map );
            $spanset = $spanset->complement( $locked_spanset );
        }
        else {
            my $locked_spanset = $self->_get_location_lock_spanset_without_matchmaker( $location, $matchmaker, $spanset, $locks_by_location_map );
            $spanset = $spanset->complement( $locked_spanset );
        }

        $any_location_spanset = Dicole::Utils::Date->join_spansets( $any_location_spanset, $spanset );
    }

    if ( ! @$locations ) {
        if ( ! $params->{ignore_local_locks} ) {
            my $locked_spanset = $self->_get_matchmaker_lock_spanset( $matchmaker, $total_spanset );
            $total_spanset = $total_spanset->complement( $locked_spanset );
        }
    }
    else {
        $total_spanset = $total_spanset->intersection( $any_location_spanset );
    }

    my $user_reserved_spanset = $self->_get_matchmaker_creator_reservation_spanset( $matchmaker, $total_spanset, $params );

    $total_spanset = $total_spanset->complement( $user_reserved_spanset );

    $total_spanset = $self->_limit_spanset_to_available_timespans( $total_spanset, scalar( $self->_get_note( available_timespans => $matchmaker ) ), $self->_get_note( time_zone => $matchmaker ) );

    return $total_spanset;
}

sub _limit_spanset_to_available_timespans {
    my ( $self, $total_spanset, $available_spans, $tz ) = @_;

    if ( $available_spans && ! ref( $available_spans ) ) {
        $available_spans = eval { Dicole::Utils::JSON->decode( $available_spans ) };
    }

    if ( $available_spans && ref( $available_spans ) eq 'ARRAY' && @$available_spans ) {
        my $available_timespans = [];

        for my $available_span ( @$available_spans ) {
            my $real_end = $available_span->{end} || 2147483646;
            push @$available_timespans, Dicole::Utils::Date->epochs_to_span(
                $available_span->{start}, $real_end, $tz
            ) if $real_end > $available_span->{start};
        }

        my $available_spanset = DateTime::SpanSet->from_spans( spans => $available_timespans );
        $total_spanset = $available_spanset->intersection( $total_spanset );
    }

    return $total_spanset;
}

sub _matchmaker_locations {
    my ( $self, $matchmaker ) = @_;

    my $locations = [];
    if ( my $mm_event_id = $matchmaker->matchmaking_event_id ) {
        $locations = CTX->lookup_object('meetings_matchmaking_location')->fetch_group({
                where => 'matchmaking_event_id = ?',
                value => [ $mm_event_id ],
            });
    }
    if ( my $type = $self->_get_note( limit_locations_to_event_type => $matchmaker ) ) {
        my $filtered = [];
        for my $l ( @$locations ) {
            push @$filtered, $l if $type eq ( $self->_get_note( location_event_type => $l ) || '');
        }
        $locations = $filtered;
    }

    return $locations;
}

sub _get_location_option_spanset_within_epochs {
    my ( $self, $location, $begin, $end ) = @_;

    my $spanset = $self->_get_location_option_spanset( $location );
    my $limits = DateTime::SpanSet->from_spans( spans => [ DateTime::Span->from_datetimes( start => DateTime->from_epoch( epoch => $begin ), end => DateTime->from_epoch( epoch => $end ) ) ] );

    return $spanset->intersection( $limits );
}

sub _get_location_option_spanset {
    my ( $self, $location ) = @_;

    my $total_spanset = DateTime::SpanSet->from_spans( spans => [] );

    my $availability_data = Dicole::Utils::JSON->decode( $location->availability_data );
    for my $data ( @$availability_data ) {
        my $start = $data->{start_params}{epoch} ? DateTime->from_epoch( epoch => $data->{start_params}{epoch} ) : DateTime->new( $data->{start_params} );
        my $end = $data->{end_params}{epoch} ? DateTime->from_epoch( epoch => $data->{end_params}{epoch} ) : DateTime->new( $data->{end_params} );

        my $spanset = undef;
        if ( $data->{recur_params} ) {
            my $startset = DateTime::Event::ICal->recur( %{ $data->{recur_params} }, dtstart => $start, dtend => $end );

            $spanset = DateTime::SpanSet->from_set_and_duration( %{ $data->{duration_params} }, set => $startset );

        }
        else {
            $spanset = DateTime::SpanSet->from_spans( spans => [ DateTime::Span->from_datetimes( start => $start, end => $end ) ] );
        }

        if ( $data->{mode} eq 'add' ) {
            $total_spanset = Dicole::Utils::Date->join_spansets( $total_spanset, $spanset );
        }
        elsif ( $data->{mode} eq 'remove' ) {
            $total_spanset = $total_spanset->complement( $spanset );
        }
    }

    return $total_spanset;
}

sub _gather_locks_by_location_map {
    my ( $self, $locations ) = @_;

    return {} unless $locations && @$locations;

    my @ids = map { $_->id } @$locations;

    my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( location_id => \@ids ),
    } ) || [];

    my $result = {};

    for my $lock ( @$locks ) {
        my $list = $result->{ $lock->location_id } ||= [];
        push @$list, $lock;
    }

    return $result;
}

sub _get_locks_for_location {
    my ( $self, $location, $locks_by_location_map ) = @_;

    if ( $locks_by_location_map ) {
        return $locks_by_location_map->{ $location->id } || [];
    }

    return CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
        where => 'location_id = ?',
        value => [ $location->id ],
    } ) || [];
}

sub _get_location_lock_spanset_without_matchmaker {
    my ( $self, $location, $matchmaker, $slots, $locks_by_location_map ) = @_;

    my $locks = $self->_get_locks_for_location( $location, $locks_by_location_map );
    $locks = [ map { $_->matchmaker_id == $matchmaker->id ? () : $_ } @$locks ];

    return $self->_get_spanset_for_locks( $locks );
}

sub _get_location_lock_spanset {
    my ( $self, $location, $slots, $locks_by_location_map ) = @_;

    my $locks = $self->_get_locks_for_location( $location, $locks_by_location_map );

    return $self->_get_spanset_for_locks( $locks );
}

sub _get_matchmaker_lock_spanset {
    my ( $self, $matchmaker, $slots ) = @_;

    # OPTIMIZE: add span limiting
    my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
            where => 'matchmaker_id = ?',
            value => [ $matchmaker->id ],
        } );

    return $self->_get_spanset_for_locks( $locks );
}

sub _get_spanset_for_locks {
    my ( $self, $locks ) = @_;

    my $set = [];

    return DateTime::SpanSet->from_spans( spans => $set ) unless @$locks;

    my @meeting_id_list = map { $_->created_meeting_id || () } @$locks;

    my $meetings = $self->_fetch_meetings( {
            where => Dicole::Utils::SQL->column_in( "event_id" => [ @meeting_id_list ] ),
        });
    my %valid_meeting_lookup = map { $_->id => $_ } @$meetings;

    for my $lock ( @$locks ) {
        if ( my $meeting_id = $lock->created_meeting_id ) {
            my $meeting = $valid_meeting_lookup{ $meeting_id };
            next unless $meeting;
            next if $meeting->removed_date;
            # TODO: event detaching check some day?
        }
        else {
            next if $lock->expire_date < time;
            next if $lock->cancel_date;
        }
        push @$set, DateTime::Span->from_datetimes(
            start => DateTime->from_epoch( epoch => $lock->locked_slot_begin_date ),
            end => DateTime->from_epoch( epoch => $lock->locked_slot_end_date )
        );
    }

    return DateTime::SpanSet->from_spans( spans => $set );
}

sub _check_matchmaker_lock_availability {
    my ( $self, $matchmaker, $start_epoch, $end_epoch ) = @_;

    # TODO: validate that this is sane and matches matchmaker reserved slot size
    my $lock_span = DateTime::Span->from_datetimes(
        start => DateTime->from_epoch( epoch => $start_epoch ),
        end => DateTime->from_epoch( epoch => $end_epoch ),
    );

    my $available_spans = $self->_get_matchmaker_available_option_spanset( $matchmaker, {
        begin_epoch => $start_epoch,
        end_epoch => $end_epoch,
    } );

    # DateTime::Set::contains does not work.. AND we need to make sure that the span
    # does not overlap existing span boundaries

    if ( ! Dicole::Utils::Date->spanset_contains_span( $available_spans, $lock_span ) ) {
        return 0;
    }
    return 1;
}

sub _create_matchmaker_lock_without_location {
    my ( $self, $matchmaker, $start_epoch, $end_epoch, $uid, $lock_minutes ) = @_;

    $lock_minutes ||= 15;

    my $lock = CTX->lookup_object('meetings_matchmaker_lock')->new( {
            domain_id => $matchmaker->domain_id,
            creator_id => $uid,
            expected_confirmer_id => $uid,
            matchmaker_id => $matchmaker->id,
            location_id => 0,
            created_meeting_id => 0,
            creation_date => time,
            expire_date => time + $lock_minutes*60,
            cancel_date => 0,
            locked_slot_begin_date => $start_epoch,
            locked_slot_end_date => $end_epoch,
            title => '',
            agenda => '',
            notes => '',
        } );

    $lock->save;

    my $still_available_spans = $self->_get_matchmaker_available_option_spanset( $matchmaker, {
            ignore_local_locks => 1,
            begin_epoch => $start_epoch,
            end_epoch => $end_epoch,
        } );

    my $lock_span = DateTime::Span->from_datetimes(
        start => DateTime->from_epoch( epoch => $start_epoch ),
        end => DateTime->from_epoch( epoch => $end_epoch ),
    );

    if ( ! Dicole::Utils::Date->spanset_contains_span( $still_available_spans, $lock_span ) ) {
        $lock->remove;
        $lock = undef;
    }
    else {
        # We still need to check that other locks for this matchmaker did not make it before this one
        my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
                where => 'matchmaker_id = ?',
                value => [ $matchmaker->id ],
                order => 'id asc',
            } );

        for my $other_lock ( @$locks ) {
            next if $other_lock->expire_date < time;
            next if $other_lock->cancel_date;
            next if $other_lock->locked_slot_end_date <= $lock->locked_slot_begin_date;
            next if $other_lock->locked_slot_begin_date >= $lock->locked_slot_end_date;

            if ( $other_lock->id != $lock->id ) {
                $lock->remove;
                $lock = undef;
            }

            last;
        }
    }

    return $lock;
}

sub _create_matchmaker_lock_with_location {
    my ( $self, $matchmaker, $start_epoch, $end_epoch, $uid, $locations, $lock_minutes ) = @_;

    my $lock = undef;
    my $selected_location = undef;

    $locations ||= $self->_matchmaker_locations( $matchmaker );
    $lock_minutes ||= 15;

    my $selection_logic = $self->_get_note( location_selection_logic => $matchmaker );
    if ( $selection_logic && $selection_logic eq 'random' ) {
        $locations = [ List::Util::shuffle( @$locations ) ];
    }

    for my $round ( qw( optimal any ) ) {

        next if $lock;

        for my $location ( @$locations ) {
            my $spanset = $self->_get_location_option_spanset( $location );

            my $locked_spanset = $self->_get_location_lock_spanset( $location, $spanset );
            my $location_available_spanset = $spanset->complement( $locked_spanset );

            my $lock_span = DateTime::Span->from_datetimes(
                start => DateTime->from_epoch( epoch => $start_epoch ),
                end => DateTime->from_epoch( epoch => $end_epoch ),
            );

            next if ! Dicole::Utils::Date->spanset_contains_span( $location_available_spanset, $lock_span );

            if ( $round eq 'optimal' ) {

                my $length = $end_epoch - $start_epoch;
                my $pre_lock_span = DateTime::Span->from_datetimes(
                    start => DateTime->from_epoch( epoch => $start_epoch - $length ),
                    end => DateTime->from_epoch( epoch => $end_epoch - $length ),
                );

                next if ! Dicole::Utils::Date->spanset_contains_span( $location_available_spanset, $pre_lock_span );

                my $post_lock_span = DateTime::Span->from_datetimes(
                    start => DateTime->from_epoch( epoch => $start_epoch + $length ),
                    end => DateTime->from_epoch( epoch => $end_epoch + $length ),
                );

                next if ! Dicole::Utils::Date->spanset_contains_span( $location_available_spanset, $post_lock_span );
            }

            $lock = CTX->lookup_object('meetings_matchmaker_lock')->new( {
                    domain_id => $matchmaker->domain_id,
                    creator_id => $uid,
                    expected_confirmer_id => $uid,
                    matchmaker_id => $matchmaker->id,
                    location_id => $location->id,
                    created_meeting_id => 0,
                    creation_date => time,
                    expire_date => time + $lock_minutes*60,
                    cancel_date => 0,
                    locked_slot_begin_date => $start_epoch,
                    locked_slot_end_date => $end_epoch,
                    title => '',
                    agenda => '',
                    notes => '',
                } );

            $lock->save;

            my $still_available_spans = $self->_get_matchmaker_available_option_spanset( $matchmaker, {
                    ignore_local_locks => 1,
                    begin_epoch => $start_epoch,
                    end_epoch => $end_epoch,
                } );

            if ( ! Dicole::Utils::Date->spanset_contains_span( $still_available_spans, $lock_span ) ) {
                $lock->remove;
                $lock = undef;
                next;
            }

            # We still need to check that other locks for this matchmaker did not make it before this one
            my $locks = CTX->lookup_object('meetings_matchmaker_lock')->fetch_group( {
                    where => 'matchmaker_id = ?',
                    value => [ $matchmaker->id ],
                    order => 'id asc',
                } );

            my $valid = 1;

            for my $other_lock ( @$locks ) {
                next if $other_lock->expire_date < time;
                next if $other_lock->cancel_date;
                next if $other_lock->locked_slot_end_date <= $lock->locked_slot_begin_date;
                next if $other_lock->locked_slot_begin_date >= $lock->locked_slot_end_date;

                if ( $other_lock->id != $lock->id ) {
                    $lock->remove;
                    $lock = undef;
                    $valid = 0;
                }

                last;
            }

            if ( $valid ) {
                $selected_location = $location;
                last;
            }
        }
    }

    return ( $lock, $selected_location );
}

sub _resolve_matchmaker_last_active_epoch {
    my ( $self, $mmr ) = @_;

    my $available_timespans = $self->_get_note( available_timespans => $mmr );

    return 0 unless $available_timespans && ref( $available_timespans ) eq 'ARRAY';

    my $last_epoch = 0;

    for my $ts ( @$available_timespans ) {
        $last_epoch = $ts->{end} if $ts->{end} && $ts->{end} > $last_epoch;
    }

    return $last_epoch;
}

sub _get_matchmaker_creator_reservation_spanset {
    my ( $self, $mmr, $slots, $params ) = @_;

    return DateTime::SpanSet->from_spans( spans => [] ) if $slots->is_empty_set;
    return $self->_get_matchmaker_creator_reservation_spanset_within_timespan( $mmr, $slots->span, $params )
}

sub _generate_user_meet_me_url {
    my ( $self, $user, $domain_id, $domain_host, $fragment ) = @_;

    return $self->_generate_user_meet_me_url_generic( $user, $domain_id, '', $domain_host, $fragment );
}

sub _generate_matchmaker_meet_me_url {
    my ( $self, $mmr, $user, $domain_host, $fragment ) = @_;

    $domain_host ||= $mmr->partner_id ? $self->_get_host_for_partner( $mmr->partner_id, 443 ) : $self->_get_host_for_domain( $mmr->domain_id, 443 );

    return $self->_generate_user_meet_me_url_generic( $user || $mmr->creator_id, $mmr->domain_id, $mmr->vanity_url_path || 'default', $domain_host, $fragment );
}

sub _generate_user_meet_me_url_generic {
    my ( $self, $user, $domain_id, $mmr_fragment, $domain_host, $fragment ) = @_;

    $fragment ||= $self->_fetch_user_matchmaker_fragment( $user );
    return '' unless $fragment;

    $domain_host ||= $self->_get_host_for_domain( $domain_id, 443 );

    return $domain_host . Dicole::URL->from_parts(
        domain_id => $domain_id,
        action => 'meetings',
        task => 'meet',
        target => 0,
        additional => [ $fragment, $mmr_fragment || () ]
    );
}

sub _fetch_valid_quickmeet {
    my ( $self, $key, $time ) = @_;

    my $quickmeets = CTX->lookup_object('meetings_quickmeet')->fetch_group({
        where => 'url_key = ? AND removed_date = 0 AND ( expires_date = 0 OR expires_date > ? )',
        value => [ $key, $time || time ],
        order => 'id asc',
    } );

    return $quickmeets->[0];
}

sub _correct_matchmaker_location_from_event {
    my ( $self, $mmr, $user ) = @_;

    return unless $mmr->matchmaking_event_id;
    my $mm_event = eval { $self->_ensure_matchmaking_event_object( $mmr->matchmaking_event_id ) };
    return unless $mm_event;
    return unless $self->_get_note( force_location_from_profile_data => $mm_event );

    $user ||= Dicole::Utils::User->ensure_object( $mmr->creator_id );

    return unless $user->email;

    my $company_data = $self->_get_matchmaking_event_google_docs_company_data( $mm_event );
    my $data = $user->email ? $company_data->{ lc( $user->email ) } : undef;

    if ( ! $data ) {
        my $email_objects = $self->_get_verified_user_email_objects( $user, $mmr->domain_id );
        for my $eo ( @$email_objects ) {
            $data = $company_data->{ lc( $eo->email ) };
            last if $data;
        }
    }

    if ( $data && $data->{location} ) {
        $self->_set_note( location => $data->{location}, $mmr );
    }
}

sub _confirm_matchmaker_lock_for_user {
    my ( $self, $lock, $requester_user, $matchmaker, $extra_data, $auth_user_id ) = @_;

    $lock = $self->_ensure_object_of_type( meetings_matchmaker_lock => $lock );
    die "umm.. no lock?" unless $lock;

    die "meeting already created for lock" if $lock->created_meeting_id;
    die "lock expired" if time > $lock->expire_date || $lock->cancel_date;

    $matchmaker ||= $self->_ensure_object_of_type( meetings_matchmaker => $lock->matchmaker_id ) || undef;

    die "no matchmaker found" unless $matchmaker;

    my $domain_id = $matchmaker->domain_id;
    my $creator_user = Dicole::Utils::User->ensure_object( $matchmaker->creator_id );

    my $quickmeet_key = $self->_get_note( quickmeet_key => $lock );
    my $quickmeet = $quickmeet_key ? $self->_fetch_valid_quickmeet( $quickmeet_key, time - 15*60 ) : undef;

    if ( $quickmeet ) {
        if ( my $email = $self->_get_note( email => $quickmeet ) ) {

            my $user = $self->_fetch_user_for_email( $email, $domain_id );
            if ( ! $user ) {
                $user = $self->_fetch_or_create_user_for_email( $email, $domain_id );
                $user->language( $creator_user->language );
                $user->timezone( $self->_get_note( user_time_zone => $lock ) || $self->_get_note( time_zone => $matchmaker ) || $creator_user->timezone );
                $self->_set_note_for_user( created_from_quickmeet_id => $quickmeet->id , $user, $domain_id );
            }

            my $attributes = {
                name => $self->_get_note( name => $quickmeet ),
                organization => $self->_get_note( organization => $quickmeet ),
                organization_title => $self->_get_note( title => $quickmeet ),
                phone => $self->_get_note( phone => $quickmeet ),
            };

            $self->_fill_profile_info_from_params( $user, $domain_id, $attributes );

            $requester_user = $user;
            $lock->expected_confirmer_id( $requester_user->id );
        }
    }

    $requester_user = Dicole::Utils::User->ensure_object( $requester_user );
    die "need an user to verify lock" unless $requester_user;

    die "security error" if $lock->expected_confirmer_id && $lock->expected_confirmer_id != $requester_user->id;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    my $mm_event = $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $schedulings_left = $mm_event ? $self->_count_available_user_matchmaking_event_schedulings( $requester_user, $mm_event ) : -1;

    die "matchmaking event limit reached" unless $schedulings_left;

    my $generated_title = $self->_get_note( preset_title => $matchmaker ) || '';
    $generated_title ||= $self->_generate_lock_title( $lock, $matchmaker, $quickmeet, $mm_event, $creator_user, $requester_user )
        unless $requester_user->id == $creator_user->id;

    if ( $generated_title =~ /\[\[\[reserver_name\]\]\]/ ) {
        my $name = Dicole::Utils::User->name( $requester_user );
        $generated_title =~ s/\[\[\[reserver_name\]\]\]/$name/;
    }

    my $confirm = $self->_get_note( confirm_automatically => $matchmaker ) ? 1 : 0;
    my $begin_date = $lock->locked_slot_begin_date;
    my $end_date = $lock->locked_slot_end_date;
    my $time_string = $self->_form_timespan_string_from_epochs( $begin_date, $end_date, $requester_user );
    my $creator_time_string = $self->_form_timespan_string_from_epochs( $begin_date, $end_date, $creator_user );

    my $location_name = $self->_generate_matchmaker_lock_location_string( $lock, $matchmaker );

    my $conf_option = $self->_get_note( online_conferencing_option => $matchmaker );
    my $preset_agenda = $self->_get_note( preset_agenda => $matchmaker ) || '';
    $preset_agenda ||= $mm_event ? $self->_get_note( default_agenda => $mm_event ) || '' : '';

    $lock->agenda( '' ) unless $lock->agenda && $lock->agenda =~ /[^\s]/;

    $preset_agenda = join ( '<p>---</p>', $preset_agenda || (), $lock->agenda ? Dicole::Utils::HTML->text_to_phtml( $lock->agenda ) : () ) || '';

    my $meeting = CTX->lookup_action('meetings_api')->e( create => {
            domain_id => $domain_id,
            creator_id => $matchmaker->creator_id,
            partner_id => $matchmaker->partner_id,
            online_conferencing_option => $self->_get_note( online_conferencing_option => $matchmaker ),
            online_conferencing_data => $self->_get_note( online_conferencing_data => $matchmaker ),
            title => $generated_title,
            location => $location_name,
            begin_epoch => $lock->locked_slot_begin_date,
            end_epoch => $lock->locked_slot_end_date,
            disable_create_email => 1,
            initial_agenda => $preset_agenda,
        });

    $self->_set_note_for_meeting( created_from_matchmaker_id => $lock->matchmaker_id, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( matchmaking_requester_id => $requester_user->id, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( matchmaking_lock_creator_id => $lock->creator_id, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( matchmaking_requester_comment => $lock->agenda, $meeting, { skip_save => 1 } );
    $self->_set_note_for_meeting( disable_followups => 1, $meeting, { skip_save => 1 } )
         if $self->_get_note( disable_followups => $matchmaker );

    if ( my $agent_reserved_area = $self->_get_note( agent_reserved_area => $matchmaker ) ) {
        $self->_set_note_for_meeting( agent_reserved_area => $agent_reserved_area, $meeting, { skip_save => 1 } );
    }

    $self->_set_note_for_meeting( attached_to_matchmaking_event_id => $matchmaker->matchmaking_event_id, $meeting );

    $self->_set_note_for_meeting( matchmaking_accept_dismissed => time, $meeting )
        if $requester_user->id == $meeting->creator_id || $confirm;

    $self->_set_note_for_meeting( allow_meeting_cancel => 1, $meeting, { skip_save => 1 } ) if $self->_get_note( lahixcustxz_hack => $matchmaker );
    $self->_set_note_for_meeting( allow_meeting_reschedule => 1, $meeting, { skip_save => 1 } ) if $self->_get_note( lahixcustxz_hack => $matchmaker );
    $self->_set_note_for_meeting( express_manager_set_date => 1, $meeting, { skip_save => 1 } ) if $self->_get_note( lahixcustxz_hack => $matchmaker );

    $lock->expire_date( time );
    $lock->title( $generated_title );
    $lock->created_meeting_id( $meeting->id );
    $lock->save;

    $self->_add_meeting_draft_participant( $meeting, { user_id => $requester_user->id }, $meeting->creator_id )
        unless $requester_user->id == $meeting->creator_id || $confirm;

    my $material_time_offset = 2;

    if ( my $deck_attachment_id = $self->_get_note( deck_attachment_id => $matchmaker ) ) {
        my $deck = $self->_add_meeting_prese_from_attachment( $meeting, $deck_attachment_id, {
                creator_id => $matchmaker->creator_id,
                created_date => time + $material_time_offset++,
                skip_event => 1,
            } );
    }
    my $preset_materials = $self->_get_note( preset_materials => $matchmaker );
    if ( ref( $preset_materials ) eq 'ARRAY' ) {
        for my $preset_material ( @$preset_materials ) {
            next unless $preset_material->{attachment_id};
            my $prese = $self->_add_meeting_prese_from_attachment( $meeting, $preset_material->{attachment_id}, {
                    creator => $creator_user,
                    name => $preset_material->{name},
                    created_date => time + $material_time_offset++,
                    skip_event => 1,
                } );
        }
    }

    if ( $confirm ) {
        my $participant = $self->_add_user_to_meeting_unless_already_exists(
            user => $requester_user,
            meeting => $meeting,
            by_user => $creator_user,
            require_rsvp => 0,
            skip_event => 1,
        );

        for my $email ( @{ $self->_get_note( hidden_users => $matchmaker ) || [] } ) {
            my $hidden_user = $self->_fetch_or_create_user_for_email( $email, $meeting->domain_id );
            my $participant = $self->_add_user_to_meeting_unless_already_exists(
                user => $hidden_user,
                meeting => $meeting,
                by_user => $creator_user,
                require_rsvp => 0,
                skip_event => 1,
                is_planner => 1,
                is_hidden => 1,
            );
        }

        my $auth_user = $auth_user_id ? eval { Dicole::Utils::User->ensure_object( $auth_user_id ) } : undef;

        my $extra_creator_mail_template_params = {};
        my $extra_requester_mail_template_params = {};

        $self->_send_meeting_user_invite_sms( $meeting, $requester_user, 'lt_custom', $matchmaker, $creator_user );

        if ( $self->_get_note( lahixcustxz_hack => $matchmaker ) ) {
            for my $key ( qw(
                add_material
                edit_material
            ) ) {
                $self->_set_meeting_permission( $meeting, $key, 0 );
            }

            $self->_set_note_for_user( 'meetings_new_user_guide_dismissed' => time, $requester_user, $domain_id );
            $self->_set_note_for_user( 'meetings_mailing_list_disabled', time, $requester_user, $domain_id );
            $self->_set_note_for_user( 'meetings_mailing_list_disabled_reason', 'partner', $requester_user, $domain_id );


            $extra_creator_mail_template_params = {
                inviting_user_name => $auth_user ? Dicole::Utils::User->name( $auth_user ) : 'Call Center',
                lahixcustxz_hack => {
                    birthdate => $extra_data->{birthdate},
                    address => $extra_data->{address},
                    area => $extra_data->{area},
                    notes => Dicole::Utils::HTML->text_to_html( $extra_data->{notes} ),
                    notes_text => $extra_data->{notes},
                }
            };

            $extra_requester_mail_template_params = {
                lahixcustxz_hack => {
                    this_disables_comment_button => 1,
                }
            };
        }

        $self->_record_notification(
            user_id => $requester_user->id,
            type => 'invited',
            data => {
                meeting_id => $meeting->id,
                author_id => $creator_user->id,
                extra_mail_template_params => $extra_requester_mail_template_params,
            },
        ) unless $lock->creator_id && $lock->creator_id == $requester_user->id && ! $self->_get_note( lahixcustxz_hack => $matchmaker );

        $self->_record_notification(
            user_id => $creator_user->id,
            type => 'invited',
            data => {
                meeting_id => $meeting->id,
                author_id => $auth_user_id || $requester_user->id,
                extra_mail_template_params => $extra_creator_mail_template_params,
            },
        );

        $self->_send_meeting_ical_request_mail( $meeting, $requester_user, { type => 'confirm', lahixcustxz_hack => $extra_requester_mail_template_params->{lahixcustxz_hack} } );
        $self->_send_meeting_ical_request_mail( $meeting, $creator_user, { type => 'confirm', lahixcustxz_hack => $extra_creator_mail_template_params->{lahixcustxz_hack}, send_copy_to => $self->_get_note( send_ics_copy_to => $matchmaker ) } );
        $self->_set_note_for_meeting( draft_ready => time, $meeting );

        return $lock;
    }

    for my $email ( @{ $self->_get_note( hidden_users => $matchmaker ) || [] } ) {
        my $hidden_user = $self->_fetch_or_create_user_for_email( $email, $meeting->domain_id );
        $self->_add_meeting_draft_participant( $meeting, { user_id => $hidden_user->id, is_hidden => 1, is_planner => 1 }, $meeting->creator_id );
    }

    my $partner_id = $self->_get_partner_id_for_meeting( $meeting );
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    $self->_record_notification(
        type => 'meetme_request',
        user_id => $creator_user->id,
        data => {
            meeting_id => $meeting->id,
            author_id => $requester_user->id,
        },
    ) unless $requester_user->id == $meeting->creator_id;

    my $requester_info = $self->_gather_user_info( $requester_user, -1, $matchmaker->domain_id );

    $self->_send_partner_themed_mail(
        user_id => $matchmaker->creator_id,
        domain_id => $meeting->domain_id,
        partner_id => $partner_id,
        group_id => 0,
        meeting_details => { meeting_id => $meeting->id },

        template_key_base => 'meetings_matchmaker_confirm_needed',
        template_params => {
            user_name => Dicole::Utils::User->name( $creator_user ),
            requester_name => Dicole::Utils::User->name( $requester_user ),
            requester_email => $requester_user->email,
            requester_company => $requester_info->{organization},
            matchmaking_event => $mm_event ? $mm_event->custom_name : '',
            greeting_message_html => Dicole::Utils::HTML->text_to_html( $lock->agenda ),
            greeting_message_text => $lock->agenda,
            accept_url => $self->_get_meeting_user_url( $meeting, $creator_user, $domain_id, $domain_host, { matchmaking_response => 'accept' } ),
            decline_url => $self->_get_meeting_user_url( $meeting, $creator_user, $domain_id, $domain_host, { matchmaking_response => 'decline' } ),
            meeting_url => $self->_get_meeting_user_url( $meeting, $creator_user, $domain_id, $domain_host ),
            meeting_title => $meeting->title,
            meeting_time => $creator_time_string,
            meeting_location => $location_name,
        },
    ) unless $requester_user->id == $meeting->creator_id;

    $self->_send_matchmaker_lock_ical_request_email( $lock, $requester_user, $meeting ) unless $quickmeet || $requester_user->id == $meeting->creator_id;

    return $lock;
}

sub _send_meeting_user_invite_sms {
    my ( $self, $meeting, $requester_user, $type, $matchmaker, $creator_user ) = @_;

    $type ||= 'unknown_user_invite';

    return unless $meeting && $requester_user;

    my $valid_requester_id = $self->_get_note_for_meeting( matchmaking_requester_id => $meeting );

    return unless $valid_requester_id && $valid_requester_id == $requester_user->id;

    my $matchmaker_id = $self->_get_note_for_meeting( created_from_matchmaker_id => $meeting );

    return unless $matchmaker_id;

    $matchmaker ||= $self->_ensure_matchmaker_object( $matchmaker_id );

    return unless $matchmaker;

    my $domain_id = $matchmaker->domain_id;
    $creator_user ||= Dicole::Utils::User->ensure_object( $matchmaker->creator_id );

    my $template = $self->_get_note( sms_invite_template => $matchmaker );

    return unless $template;
    my $msg = $template;

    my $bdt = Dicole::Utils::Date->epoch_to_datetime( $meeting->begin_date, $requester_user->time_zone, $requester_user->language );

    my $msg_location = $meeting->location_name;
    my $msg_day = $bdt->day . '.' . $bdt->month . '.';
    my $msg_time = $bdt->hour . ':' .sprintf( "%02d", $bdt->minute );
    my $msg_organizer_name = Dicole::Utils::User->name( $creator_user );

    my $attributes = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        user_id => $creator_user->id,
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

    $self->_send_user_sms( $requester_user, $msg, { creator_user => $creator_user, domain_id => $meeting->domain_id, log_data => { type => $type, meeting_id => $meeting->id } } );
}

sub _generate_lock_title {
    my ( $self, $lock, $matchmaker, $quickmeet, $mm_event, $creator_user, $requester_user ) = @_;

    $matchmaker ||= $self->_ensure_object_of_type( meetings_matchmaker => $lock->matchmaker_id ) || undef;

    die "no matchmaker found" unless $matchmaker;

    $creator_user ||= Dicole::Utils::User->ensure_object( $matchmaker->creator_id );
    $requester_user ||= Dicole::Utils::User->ensure_object( $lock->expected_confirmer_id );

    my $quickmeet_key = $self->_get_note( quickmeet_key => $lock );
    $quickmeet ||= $quickmeet_key ? $self->_fetch_valid_quickmeet( $quickmeet_key, time - 15*60 ) : undef;

    my $mm_event_id = $matchmaker->matchmaking_event_id;
    $mm_event ||= $mm_event_id ? $self->_ensure_object_of_type( meetings_matchmaking_event => $mm_event_id ) : undef;

    my $generated_prefix = $mm_event ? $mm_event->custom_name : '';

    my $creator_info = $self->_gather_user_info( $creator_user, -1, $matchmaker->domain_id );
    my $creator_string = $creator_info->{organization} || $creator_user->last_name || Dicole::Utils::User->name( $creator_user );

    my $requester_info = $self->_gather_user_info( $requester_user, -1, $matchmaker->domain_id );
    my $requester_string = $requester_info->{organization} || $requester_user->last_name || Dicole::Utils::User->name( $requester_user );

    my $generated_participants = join " & ", ( $creator_string || (), $requester_string || () );
    my $generated_title = join ": ", ( $generated_prefix || (), $generated_participants || () );

    if ( $quickmeet ) {
        if ( my $override_title = $self->_get_note( meeting_title => $quickmeet ) ) {
            $generated_title = $override_title;
        }
    }

    return $generated_title;
}

sub _generate_matchmaker_lock_location_string {
    my ( $self, $lock, $matchmaker ) = @_;

    my $lock_location = $self->_get_note( location => $lock );
    return $lock_location if $lock_location;

    my $location =  $lock->location_id ? $self->_ensure_object_of_type( meetings_matchmaking_location => $lock->location_id ) : undef;
    my $location_name = $location ? $location->name || '' : '';

    if ( ! $location_name ) {
        $matchmaker ||= $self->_ensure_matchmaker_object( $lock->matchmaker_id );
        return $self->_matchmaker_location_string( $matchmaker );
    }

    return $location_name;
}

sub _cancel_meeting {
    my ( $self, $meeting, $message, $user ) = @_;

    $self->_set_note( cancelled_date => time, $meeting, { skip_save => 1 } );
    $self->_set_note( cancelled_by_user_id => $user->id, $meeting, { skip_save => 1 } );
    $self->_set_note( cancel_message => $message, $meeting );

    $self->_post_meeting_comment_under_agenda( $meeting, undef, $message, $user )
        if $message && $message =~ /\S/;

    my $euos = $self->_fetch_meeting_participant_objects( $meeting );
    for my $euo ( @$euos ) {
        next if $self->_get_note( is_hidden => $euo );

        my $participant = Dicole::Utils::User->ensure_object( $euo->user_id );
        $self->_send_meeting_ical_request_mail( $meeting, $participant, { type => 'cancel' } );
    }
}


sub _send_decline_meeting_email_to_reserving_user {
    my ( $self, $meeting, $message, $user ) = @_;

    $user ||= Dicole::Utils::User->ensure_object( $meeting->creator_id );
    my $user_info = $self->_gather_user_info( $user, -1, $meeting->domain_id );

    my $matchmaker = $self->_get_meeting_matchmaker( $meeting );
    my $mm_event = ( $matchmaker && $matchmaker->matchmaking_event_id ) ? $self->_ensure_object_of_type( meetings_matchmaking_event => $matchmaker->matchmaking_event_id ) : undef;
    my $mm_event_name = $self->_get_meeting_matchmaking_event_name( $meeting, $matchmaker, $mm_event );
    my $domain_host = $self->_get_host_for_meeting( $meeting, 443 );

    my $requesting_user = $self->_get_meeting_matchmaking_requester_user( $meeting );

    my $schedulings_left = $mm_event ? $self->_count_available_user_matchmaking_event_schedulings( $requesting_user, $mm_event ) : -1;
    my $user_matchmaking_url = $mm_event ? $self->_get_note( organizer_list_url => $mm_event ) || $self->_generate_authorized_uri_for_user( $domain_host . $self->derive_url( action => 'meetings', task => 'matchmaking_list', additional => [ $matchmaker->matchmaking_event_id ] ), $requesting_user, $meeting->domain_id ) : '';

    $self->_send_meeting_user_template_mail( $meeting, $requesting_user, 'meetings_matchmaker_declined', {
            user_name => Dicole::Utils::User->name( $requesting_user ),
            matchmaker_name => Dicole::Utils::User->name( $user ),
            matchmaker_email => $user->email,
            matchmaker_company => $user_info->{organization},
            matchmaking_url => $user_matchmaking_url,
            matchmaking_event => $mm_event_name,
            greeting_message_html => Dicole::Utils::HTML->text_to_html( $message ),
            greeting_message_text => $message,
            meeting_slots => ( $schedulings_left < 0 ) ? -1 : $schedulings_left + 1,
        } );
}

sub _fetch_meetings {
    my ( $self, $fetch_group_params, $params ) = @_;

    die "_fetch_meetings can not be used with limit" if $fetch_group_params->{limit};

    my $meetings = CTX->lookup_object('events_event')->fetch_group( $fetch_group_params );

    $meetings = [ map { $_->removed_date ? () : $_ } @$meetings ] unless $params->{include_removed};
    $meetings = [ map { $self->_meeting_is_cancelled( $_ ) ? () : $_ } @$meetings ] unless $params->{include_cancelled};

    return $meetings;
}

sub _return_cached_data_for_params {
    my ( $self, $cache_params, $skip_cache ) = @_;

    if ( $skip_cache ) {
        return Dicole::Cache->update( @$cache_params );
    }
    else {
        return Dicole::Cache->fetch_or_store( @$cache_params );
    }
}

sub _application_for_api_key {
    my ( $self, $api_key, $domain_id ) = @_;

    if ( $api_key eq 'test' ) {
        return { domain_id => $domain_id, csv_url => 'https://docs.google.com/spreadsheet/pub?key=0AqnOWbpvdZ0qdFRUM0lTeDdnblBQekxiajdVSGduSWc&output=csv' };
    }
    elsif ( $api_key eq 'devtest' ) {
        return { domain_id => $domain_id, csv_url => 'https://docs.google.com/spreadsheet/pub?key=0AqnOWbpvdZ0qdGkySkdEX3k3VTZsVXc4a195Qjhmanc&output=csv' };
    }
    elsif ( $api_key eq 'bodylanguagesummitkey' ) {
        return { domain_id => $domain_id, vanity_url_path => 'bodylanguage', partner_id => 29, csv_url => 'https://docs.google.com/spreadsheet/pub?key=0AqnOWbpvdZ0qdEtMN0pCaWVNYU15UE9SdUhkXzFMRUE&output=csv' };
    }
    elsif ( $api_key eq 'slush2014apikey' ) {
        return { domain_id => $domain_id, vanity_url_path => 'slush14', partner_id => 43, csv_url => 'https://register.slush.org/api/v1/meetings_all?token=HkFRV4LHtUHguzC' };
    }
    elsif ( $api_key eq 'ulf2014apikey' ) {
        return { domain_id => $domain_id, vanity_url_path => 'ULF2014', partner_id => 47, csv_url => 'https://docs.google.com/spreadsheet/pub?key=0AqnOWbpvdZ0qdG1KYVZ2akFyNGxrMjZZZzd6UE9DRUE&output=csv' };
    }
    elsif ( $api_key eq 's2mdevapikey' ) {
        return { domain_id => $domain_id, csv_url => 'https://docs.google.com/spreadsheet/pub?key=0AqnOWbpvdZ0qdGxKRFdNRG4wVWpyOGllam9lU1hqWUE&output=csv' };
    }
    elsif ( $api_key eq 'ltdevapikey' ) {
        return ( $domain_id == 76 ) ? { domain_id => $domain_id, api_secret => 'test', partner_id => 11 } : undef;
    }
    elsif ( $api_key eq 'ltapikey' ) {
        return ( $domain_id == 131 ) ? { domain_id => $domain_id, api_secret => 'x', partner_id => 59 } : undef;
    }
    return undef;
}

sub _application_csv_as_hash_list {
    my ( $self, $application, $skip_cache ) = @_;

    return $self->_fetch_or_cache_csv_url_as_hash_list( $application->{csv_url}, $skip_cache );
}

sub _fetch_app_client_sync_user_data_map {
    my ( $self, $application, $skip_cache ) = @_;

    my $hash_list = $self->_fetch_or_cache_csv_url_as_hash_list( $application->{sync_users_csv_url}, $skip_cache );
    return { map { lc( $_->{Email} ) => $_ } @$hash_list };
}

sub _fetch_or_cache_csv_url_as_hash_list {
    my ( $self, $url, $skip_cache ) = @_;

    my $hash = Dicole::Utils::Data->signature_base64( $url );

    my @cache_params = (
        'csv_url_as_hash_list_' . $hash,
        sub {
            my $data = Dicole::Utils::HTTP->get( $url );
            return $self->_csv_data_to_hash_list( $data ) || [];
        },
        { no_domain_id => 1, no_group_id => 1, lock_timeout => 2*60, expires => 60 }
    );

    if ( $skip_cache ) {
        return Dicole::Cache->update( @cache_params );
    }
    else {
        return Dicole::Cache->fetch_or_store( @cache_params );
    }
}

sub _get_matchmaking_event_google_docs_company_data {
    my ( $self, $mm_event, $skip_cache ) = @_;

    $mm_event = $self->_ensure_matchmaking_event_object( $mm_event );

    my $url = $self->_get_note( prefill_profile_data_csv_url => $mm_event );
    return {} unless $url;

    my @cache_params = (
        'google_docs_company_data_for_event_' . $mm_event->id,
        sub {
            my $data = Dicole::Utils::HTTP->get( $url );
            my $field_keys = {};

            my $fields = "Approved	Firstname	Lastname	Email	Company name	Website	Founding year	Company description	City	Country	Market	Logo	Team	Product description	Target market	Company revenues	Number of employees	Customer acquisition	Investor contacts	Media contacts	Business partners	Recruiting	Other interests	Wish to launch a product	Product launch description	Wish to post job openings	Want to apply for pitching competition	Demo booth November 13th	Demo booth November 14th	Free IPR services	Want to participate in investor matchmaking	Funding received	Funding looking for	Significant investors and advisors	Notable milestones and metrics	Other information";
            $fields .= "	Product name	One sentence pitch	Many words pitch	Raised";
            $fields .= "	Accepted	Funding we are looking for	Funding raised	Category	Founded	Company";
            $fields .= "	Core competences	References	Certificates";
            $fields .= "	Business model	EMAIL	TOKEN	Competitors	Mainly looking for	Areas of interest";
            $fields .= "	Skype	LinkedInURL	Pitch deck URL";
            $fields .= "	Location";
            $fields .= "	Country of production	Primary Offering	Secondary Offering	Primary platform	Secondary platform";
            $fields .= "	Primary offering other	Secondary offering other	Primary platform other	Secondary platform other";
            $fields .= "	Elevator pitch";

            for my $field ( split /\t/, $fields ) {
                my $key = lc( $field );
                $key =~ s/\W/_/g;
                $field_keys->{ $key } ||= $field;
            }

            if ( $field_keys->{email} ) {
                $field_keys->{email} =~ s/^\s*//;
                $field_keys->{email} =~ s/\s*$//;
            }

            return $self->_matchmaking_event_google_docs_data_to_overridable_field_keys_data_by_lc_email( $mm_event, $data, $field_keys );
        },
        { domain_id => $mm_event->domain_id, no_group_id => 1, lock_timeout => 10, expires => 60*1 }
    );

    return $self->_return_cached_data_for_params( \@cache_params, $skip_cache );
}

sub _get_matchmaking_event_matchmaker_data {
    my ( $self, $mm_event, $image_size, $skip_cache ) = @_;

    $mm_event = $self->_ensure_matchmaking_event_object( $mm_event );
    return {} unless $mm_event;

    my $domain_id = $mm_event->domain_id;
    $image_size ||= 30;

    my @cache_params = (
        'google_docs_company_data_for_event_' . $mm_event->id . '_' . $image_size,
        sub {
            my $mmrs = $self->_fetch_event_matchmakers( $mm_event );
            my @creator_ids = map { $_->creator_id } @$mmrs;
            my $users = Dicole::Utils::User->ensure_object_list( \@creator_ids );
            my $users_map = { map { $_->id => $_ } @$users };
            my $fragment_map = $self->_fetch_matchmaker_fragment_map_for_users( $users );

            my $users_info = $self->_gather_users_info( $users, $image_size, $domain_id );
            my $users_info_map = { map { $_->{user_id} => $_ } @$users_info };

            my $email_aliases = CTX->lookup_object('meetings_user_email')->fetch_group( {
                where => Dicole::Utils::SQL->column_in( user_id => \@creator_ids ),
            } );

            my $domain_host = $self->_get_host_for_domain( $domain_id, 443 );

            my $infos = {};
            for my $mmr ( @$mmrs ) {
                my $creator_id = $mmr->creator_id;
                my $meetme_fragment = $fragment_map->{ $creator_id };
                next unless $meetme_fragment;

                my $vanity_url_path = $mmr->vanity_url_path || 'default';
                my $calendar_url = Dicole::URL->from_parts(
                    domain_id => $mmr->domain_id, action => 'meetings', task => 'meet', target => 0, additional => [ $meetme_fragment, $vanity_url_path, 'calendar' ]
                );

                if ( $self->_get_note( force_vanity_url_path => $mm_event ) eq 'shift2016' ) {
                    next unless $self->_get_note( additional_direct_matchmakers => $mmr );
                    $calendar_url = '';
                }

                my $user_info = $users_info_map->{ $mmr->creator_id };
                $user_info->{image} = $user_info->{image} ? $domain_host . $user_info->{image} : '';

                my $data = {
                    meetme_fragment => $meetme_fragment,
                    vanity_url_path => $vanity_url_path,
                    desktop_url => Dicole::URL->from_parts(
                        domain_id => $mmr->domain_id, action => 'meetings', task => 'meet', target => 0, additional => [ $meetme_fragment, $vanity_url_path ]
                    ),
                    desktop_calendar_url => $calendar_url,
                    contact_image => $user_info->{image},
                    contact_name => $user_info->{name},
                    contact_title => $user_info->{organization_title},
                    youtube_url => $self->_get_note( youtube_url => $mmr ) || '',
                };

                my @emails = ( eval{ $users_map->{ $creator_id }->email } || () );
                for my $alias ( @$email_aliases ) {
                    push @emails, $alias->email if $alias->user_id == $creator_id && $alias->verified_date;
                }

                for my $email ( @emails ) {
                    $infos->{ lc( $email ) } = $data;
                }
            }

            return $infos;
        },
        { domain_id => $domain_id, no_group_id => 1, lock_timeout => 10, expires => 60*1 }
    );

    return $self->_return_cached_data_for_params( \@cache_params, $skip_cache );
}


sub _get_matchmaking_event_google_docs_job_profile_data {
    my ( $self, $mm_event, $skip_cache ) = @_;

    $mm_event = $self->_ensure_matchmaking_event_object( $mm_event );

    my $url = $self->_get_note( prefill_profile_data_csv_url => $mm_event );
    return {} unless $url;

    my @cache_params = (
        'google_docs_job_profile_data_for_event_' . $mm_event->id,
        sub {
            my $data = Dicole::Utils::HTTP->get( $url );
            my $field_keys = {};

            my $fields = "Email	Phone number	City	Country	Education	Personal summary	Online profile or portfolio	Additional link	Internship	Full-time position	Software engineer	Hardware engineer	UI / UX designer	Industrial designer	Business	Other	Skills and expertise	Looking for";

            for my $field ( split /\t/, $fields ) {
                my $key = lc( $field );
                $key =~ s/\W/_/g;
                $field_keys->{ $key } = $field;
            }

            return $self->_matchmaking_event_google_docs_data_to_overridable_field_keys_data_by_lc_email( $mm_event, $data, $field_keys );
        },
        { domain_id => $mm_event->domain_id, no_group_id => 1, lock_timeout => 10, expires => 60*1 }
    );

    return $self->_return_cached_data_for_params( \@cache_params, $skip_cache );
}

# oi2_manage dicole_eval --code='d( CTX->lookup_action("meetings_api")->_get_matchmaking_event_google_docs_user_data( 5, 1) )'

sub _get_matchmaking_event_google_docs_user_data {
    my ( $self, $mm_event, $skip_cache ) = @_;

    return {} unless $mm_event;

    $mm_event = $self->_ensure_matchmaking_event_object( $mm_event );

    my @cache_params = ();

    my $field_keys = {
        first_name => 'Firstname',
        last_name => 'Lastname',
        email => 'Email',
        organization_title => 'Title',
        organization => 'Company',
        phone => 'Phone',
        skype => 'Skype',
        linkedin => 'LinkedInURL',
    };

    if ( my $gapier_token = $self->_get_note( prefill_profile_data_gapier_token => $mm_event ) ) {
        @cache_params = (
            'google_docs_gapier_user_data_for_event_' . $mm_event->id,
            sub {
                my $gapier_host = CTX->server_config->{dicole}->{gapier_host} || 'https://meetings-gapier.appspot.com/';
                my $gapier_url = $gapier_host . 'fetch?worksheet_token=' . $gapier_token;
                my $data_json = Dicole::Utils::HTTP->get( $gapier_url );
                my $data = Dicole::Utils::JSON->decode( $data_json );

                for my $key ( keys %$field_keys ) {
                    my $override_value = $self->_get_note( 'google_docs_key_for_' . $key, $mm_event );
                    $field_keys->{ $key } = $override_value if $override_value;
                }

                my $list = [];
                for my $row ( @$data ) {
                    my $data_row = {};
                    for my $key ( keys %$field_keys ) {
                        my $header = $field_keys->{ $key };
                        my $gsx = lc( $header );
                        $gsx =~ s/^[^a-z]*//;
                        $gsx =~ s/[^a-z0-9\.\-]//g;
                        $data_row->{ $key } = $row->{ $gsx };
                    }
                    if ( $data_row->{email} ) {
                        $data_row->{email} =~ s/^\s*//;
                        $data_row->{email} =~ s/\s*$//;
                    }
                    push @$list, $data_row;
                }

                return { map { lc( $_->{email} ) => $_ } @$list };
            },
            { domain_id => $mm_event->domain_id, no_group_id => 1, lock_timeout => 10, expires => 5*1 }
        );
    }
    else {
        my $url = $self->_get_note( prefill_profile_data_csv_url => $mm_event );
        return {} unless $url;

        @cache_params = (
            'google_docs_user_data_for_event_' . $mm_event->id,
            sub {
                my $data = Dicole::Utils::HTTP->get( $url );

                return $self->_matchmaking_event_google_docs_data_to_overridable_field_keys_data_by_lc_email( $mm_event, $data, $field_keys );
            },
            { domain_id => $mm_event->domain_id, no_group_id => 1, lock_timeout => 10, expires => 60*1 }
        );
    }

    return $self->_return_cached_data_for_params( \@cache_params, $skip_cache );
}

sub _matchmaking_event_google_docs_data_to_overridable_field_keys_data_by_lc_email {
    my ( $self, $mm_event, $data, $field_keys ) = @_;

    for my $key ( keys %$field_keys ) {
        my $override_value = $self->_get_note( 'google_docs_key_for_' . $key, $mm_event );
        $field_keys->{ $key } = $override_value if $override_value;
    }

    my $list = $self->_cvs_data_to_field_key_mapped_hash_list( $data, $field_keys );
    for my $data_row ( @$list ) {
        if ( $data_row->{email} ) {
            $data_row->{email} =~ s/^\s*//;
            $data_row->{email} =~ s/\s*$//;
        }
    }

    return { map { lc( $_->{email} ) => $_ } @$list };
}

sub _csv_data_to_hash_list {
    my ( $self, $data, $field_keys ) = @_;
    my $data_rows = [];
    my $csv = Text::CSV->new ( { binary => 1 } );

    my $fh = new IO::Scalar \$data;

    my $names_row = $csv->getline( $fh );
    $csv->column_names( @$names_row );

    while ( my $ref = eval { $csv->getline_hr( $fh ) } ) {
        next unless ref( $ref ) eq 'HASH';
        push @$data_rows, $ref;
    }

    return $data_rows;
}

sub _cvs_data_to_field_key_mapped_hash_list {
    my ( $self, $data, $field_keys ) = @_;

    my $data_rows = [];
    my $csv = Text::CSV->new ( { binary => 1 } );

    my $fh = new IO::Scalar \$data;

    my $names_row = $csv->getline( $fh );
    $csv->column_names( @$names_row );

    while ( my $ref = eval { $csv->getline_hr( $fh ) } ) {
        next unless ref( $ref ) eq 'HASH';
        my $data_row = {};
        for my $key ( keys %$field_keys ) {
            $data_row->{ $key } = $ref->{ $field_keys->{ $key } };
        }
        push @$data_rows, $data_row;
    }

    return $data_rows;
}

# NOTE: it is expected that this does not return any keys of online conferencing is not enabled
sub _gather_meeting_live_conferencing_params {
    my ( $self, $meeting, $user, $email ) = @_;

    my $option = $self->_get_note_for_meeting( online_conferencing_option => $meeting ) || '';
    my $params = {};

    if ( $option eq 'skype' ) {
        $email ||= $self->_get_meeting_email( $meeting );
        my ( $skype_token ) = $email =~ /(.*?)\@/;
        my $skype_account  = '';

        my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
        $skype_account = $data->{skype_account} if $data;

        $skype_account ||= $self->_get_note_for_meeting( skype_account => $meeting );

        # NOTE: this is for backwards compatibility
        if ( ! $skype_account ) {
            my $creator_user = Dicole::Utils::User->ensure_object( $meeting->creator_id );
            my $creator_info = $self->_gather_user_info( $creator_user, -1, $meeting->domain_id );
            $skype_account = $creator_info->{skype};
            $self->_set_note_for_meeting( skype_account => $skype_account, $meeting ) if $skype_account;
        }

        if ( $skype_account ) {
            $params->{skype_uri} = 'skype:' . $skype_account . '?call&token=' . $skype_token;

            if ( $user ) {
                my $user_info = $self->_gather_user_info( $user, -1, $meeting->domain_id );
                $params->{skype_is_organizer} = ( $user_info->{skype} eq $skype_account ) ? 1 : 0;
            }
        }
    }

    if ( $option eq 'teleconf' ) {
        my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
        if ( $data ) {
            if ( my $num = $data->{teleconf_number} ) {
                $params->{teleconf_number} = $num;
                $params->{teleconf_uri} = $num;

                if ( $num !~ /^(sips?|tel)\:/ ) {
                    $params->{teleconf_uri} = 'tel:' . $num;
                }

                if ( my $pin = $data->{teleconf_pin} ) {
                    $params->{teleconf_pin} = $pin;
                    $params->{teleconf_uri} .= ',,' . $pin;
                }
            }
        }
    }

    if ( $option eq 'hangout' ) {
        my $uri = URI->new('https://plus.google.com/hangouts/_/');
        if ( $user ) {
            my $gd = {
                user_id => $user->id,
                token => 'x',
                begin_milliepoch => 1000 * $meeting->begin_date,
                end_milliepoch => 1000 * $meeting->end_date,
                api_poll_url => 'https://'. CTX->server_config->{dicole}->{meetings_api_domain} .'/v1/meetings/' . $meeting->id . '/register_hangout_data',
            };

            $uri->query_form( gid => '742360352441', gd => Dicole::Utils::JSON->encode( $gd ) );

            $params->{hangout_organizer_uri} = $uri->as_string;
        }

        my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
        if ( $data && $data->{hangout_uri} && $data->{hangout_refreshed_epoch} + 60 > time ) {
            $params->{hangout_uri} = $data->{hangout_uri};
        }
    }

    if ( $option eq 'lync' ) {
        my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
        # legacy
        if ( $data && $data->{lync_uri} && ! $data->{lync_mode} ) {
            $params->{lync_uri} = $data->{lync_uri};
        }
        elsif ( $data && $data->{lync_mode} && $data->{lync_mode} eq 'uri' ) {
            if ( $data->{lync_copypaste} ) {
                # TODO parse uri
                my ( $uri ) = $data->{lync_copypaste} =~ /(http.*?)([ "<]|$)/;
                if ( $uri ) {
                    $params->{lync_uri} = $uri;
                }
            }
        }
        elsif ( $data && $data->{lync_mode} && $data->{lync_mode} eq 'sip' ) {
            if ( my $sip = $data->{lync_sip} ) {
                if ( $sip !~ /^sip\:/ ) {
                    $sip = 'sip:' . $sip;
                }
                $params->{lync_uri} = $sip;
            }
        }
    }

    if ( $option eq 'custom' ) {
        my $data = $self->_get_note_for_meeting( online_conferencing_data => $meeting );
        if ( $data && $data->{custom_uri} ) {
            $params->{custom_uri} = $data->{custom_uri};
        }
    }

    return $params;
}

sub _assing_user_to_company_subscription {
    my ( $self, $target_user, $subscription, $by_user, $opts ) = @_;

    my $assignments = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
        where =>'removed_date = 0 AND subscription_id = ? AND ' . ( $opts->{external_user_id} ?  '( user_id = ? OR external_user_id = ?)' : 'user_id = ?' ),
        value => [ $subscription->id, $target_user->id, $opts->{external_user_id} || () ],
        order => 'id asc',
    } );

    return shift @$assignments if @$assignments;

    my $o = CTX->lookup_object('meetings_company_subscription_user')->new( {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        partner_id => $subscription->partner_id,
        subscription_id => $subscription->id,
        user_id => $target_user->id,
        created_date => time,
        creator_id => $by_user ? Dicole::Utils::User->ensure_id( $by_user ) : 0,
        removed_date => 0,
        verified_date => time,
        remover_id => 0,
        external_user_id => $opts->{external_user_id} || '',
        is_admin => $opts->{is_admin} ? 1 : 0,
        notes => '',
    });

    $o->save;

    $assignments = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
        where => 'removed_date = 0 AND subscription_id = ? AND ' . ( $opts->{external_user_id} ?  '( user_id = ? OR external_user_id = ?)' : 'user_id = ?' ),
        value => [ $subscription->id, $target_user->id, $opts->{external_user_id} || () ],
        order => 'id asc',
    } );

    my $return = shift @$assignments;
    for my $a ( @$assignments ) {
        $a->remove;
    }

#    $self->_create_free_trial_subscription(
#        user => $target_user,
#        promo_code => 'appdirect_30_day',
#        domain_id => Dicole::Utils::Domain->guess_current_id,
#        start_date => $subscription->created_date,
#        duration_days => 30,
#        notes => {
#            appdirect_subscription_id => $subscription->id,
#        },
#        skip_calculate_pro => 1,
#    );

    Dicole::Utils::Gearman->dispatch_task( recalculate_user_pro => {
        user_id => $target_user->id,
    } );

    return $return;
}

sub _get_meetings_for_matchmaking_event {
    my ( $self, $event ) = @_;

    my $sql = 'SELECT DISTINCT dicole_events_event.*' .
        ' FROM dicole_events_event, dicole_meetings_matchmaker_lock, dicole_meetings_matchmaker, dicole_meetings_matchmaking_event' .
        ' WHERE dicole_events_event.removed_date = 0' .
            ' AND dicole_events_event.event_id = dicole_meetings_matchmaker_lock.created_meeting_id' .
            ' AND dicole_meetings_matchmaker_lock.matchmaker_id = dicole_meetings_matchmaker.id' .
            ' AND dicole_meetings_matchmaker.matchmaking_event_id = dicole_meetings_matchmaking_event.id' .
            ' AND dicole_meetings_matchmaking_event.id = ' . $event->id;

    my $events = CTX->lookup_object('events_event')->fetch_group( {
        sql => $sql,
    } );

    return $events;
}

sub _gather_matchmaking_event_users_data_list {
    my ( $self, $event ) = @_;

    $event = $self->_ensure_matchmaking_event_object( $event );
    my $mmrs = $self->_fetch_event_matchmakers( $event );
    my $datas = [ map { $self->_gather_matchmaker_data_for_matchmaking_event_listing( $_, $event ) } @$mmrs ];

    return $datas;
}

sub _gather_matchmaker_data_for_matchmaking_event_listing {
    my ( $self, $m, $e ) = @_;

    my $u = Dicole::Utils::User->ensure_object( $m->creator_id );
    my $i = $self->_gather_user_info( $u, 140, $e->domain_id );
    my $domain_host = $self->_get_host_for_event( $e, 443 );

    my $data = {
        TOKEN => $u->id,
        EMAIL => $u->email,
        Active => 'yes',
        'First name' => $u->first_name,
        'Last name' => $u->last_name,
        Organization => $i->{organization},
        Title => $i->{organization_title},
        LinkedIn => $i->{linkedin},
        'Image URL' => $i->{image} ? $domain_host . $i->{image} : '',
        'Meet me URL' => $self->_generate_matchmaker_meet_me_url( $m, $u, $domain_host ),
        'Edit URL' => $domain_host . $self->_get_meet_me_config_abs( $e->id, {}, $e->domain_id ),
    };
}

sub _gather_matchmaking_event_meetings_data_list {
    my ( $self, $event ) = @_;

    $event = $self->_ensure_matchmaking_event_object( $event );
    my $meetings = $self->_get_meetings_for_matchmaking_event( $event );
    my $datas = [];
    for my $m ( @$meetings ) {
        push @$datas, $self->_gather_meeting_data_for_matchmaking_event_listing( $m, $event )
            if time < $m->begin_date;
    }

    return $datas;
}

sub _gather_meeting_data_for_matchmaking_event_listing {
    my ( $self, $m, $e ) = @_;

    my $timezone = $self->_get_note( force_time_zone => $e ) || $self->_get_note( default_timezone => $e ) || 'UTC';
    my $lang = 'en';

    my $registrar_user = Dicole::Utils::User->ensure_object( $m->creator_id );
    my $requester_user = $self->_get_meeting_matchmaking_requester_user( $m );

    my $registrar_type = $self->_get_note( registrar_type => $e ) || 'Registrar';
    my $requester_type = $self->_get_note( requester_type => $e ) || 'Requester';

    my $dt = Dicole::Utils::Date->epoch_to_datetime( $m->begin_date, $timezone );

    my $time = $dt->ymd . ' ' . $dt->hms;
    $time =~ s/\:\d\d$//;
    $time .= " ($timezone)";

    my $cdt = Dicole::Utils::Date->epoch_to_datetime( $m->created_date, $timezone );
    my $ctime = $cdt->ymd . ' ' . $cdt->hms;
    $ctime =~ s/\:\d\d$//;
    $ctime .= " ($timezone)";

    my $domain_host = $self->_get_host_for_event( $e, 443 );

    my $data = {
        'Meeting ID' => $m->id,
        'Meeting name' => $self->_meeting_title_string( $m ),
        'Time' => $time,
        'Created time' => $ctime,
        'Space' => $m->location_name,
        'Invites sent' => $self->_meeting_is_draft( $m ) ? 0 : 1,
        'Meeting URL' => $domain_host . $self->_get_meeting_abs( $m ),
        'Accepted' => $self->_meeting_is_matchmaking_accepted( $m )
    };

    for my $userinfo ( [ $registrar_type, $registrar_user ], [ $requester_type, $requester_user ] ) {
        my $type = $userinfo->[0];
        my $user = $userinfo->[1];
        next unless $user;
        my $info = $self->_gather_user_info( $user, -1, $e->domain_id );

        $data->{ "$type email" } = $user->email;
        $data->{ "$type name" } = Dicole::Utils::User->name( $user );
        $data->{ "$type company" } = $info->{organization};
        $data->{ "$type phone" } = "'".$info->{phone};

        my $partner_id = $e->partner_id;
        my $partner = $partner_id ? $self->PARTNERS_BY_ID->{ $partner_id } : undef;
        my $params = $partner ? { pcs => $self->_create_partner_authentication_checksum_for_user( $partner, $user ) } : {};
        my $meeting_url = $domain_host . $self->_get_meeting_abs( $m, $params );

        $data->{ "$type meeting URL" } = $meeting_url;
    }

    return $data;
}

sub _get_partner_agent_booking_types {
    my ( $self, $partner_id ) = @_;

    my $partner = $partner_id ? $self->_ensure_partner_object( $partner_id ) : undef;
    my $all_meeting_types = $partner ? $self->_get_note( all_meeting_types => $partner ) : [];

    my $types = [];
    for my $type ( @$all_meeting_types ) {
        my $copy = { %$type };

        $copy->{key} = lc $type->{name};
        $copy->{key} =~ s/ //g;

        $copy->{path} = lc $type->{name};
        $copy->{path} =~ s/[^A-Za-z\d]/_/g;
        $copy->{path} =~ s/_+/_/g;

        push @$types, $copy;
    }
    return $types;
}

sub _get_partner_agent_booking_data {
    my ( $self, $partner_id ) = @_;

    my $partner = $partner_id ? $self->_ensure_partner_object( $partner_id ) : undef;
    my $url = $partner ? $self->_get_note( agent_booking_data_url => $partner ) : undef;
    my $officeurl = $partner ? $self->_get_note( agent_booking_office_data_url => $partner ) : undef;

    my $demoify = $partner ? $self->_get_note( agent_booking_demoify_emails => $partner ) ? 1 : 0 : 0;

    return {} unless $url && $officeurl;

    my $data = Dicole::Utils::JSON->decode( Dicole::Utils::HTTP->get( $url ) );

    for my $d ( @$data ) {
        next unless $demoify;
        if ( $d->{email} =~ /lahixcustxz/ ) {
            $d->{email} =~ s/\@.*//;
            $d->{email} = 'demo+' . $d->{email} . '+ltdemo@meetin.gs';
        }
    }

    my $officedata = Dicole::Utils::JSON->decode( Dicole::Utils::HTTP->get( $officeurl ) );

    return { users => $data, offices => $officedata };
}

sub _notification_settings_list {
    my ( $self, $lang, $opts ) = @_;

    $lang ||= 'en';
    $opts ||= {};

    my @sources = ();
    push @sources, {
        header => $self->_ncmsg( "Receive email notification when:", { lang => $lang } ),
        type => 'email',
        by_default_true_settings => {
            email_meeting_invitation => $self->_ncmsg( "Meeting invitation received", { lang => $lang } ),
            email_date_changes => $self->_ncmsg( "Date or time changes", { lang => $lang } ),
            email_24h_meeting_start => $self->_ncmsg( "Meeting starts in 24 hours", { lang => $lang } ),
            email_15m_online_meeting_start => $self->_ncmsg( "Online meeting starts in 15min", { lang => $lang } ),
            email_action_points_reminder => $self->_ncmsg( "Action points should be filled", { lang => $lang } ),
            $opts->{skip_meetme} ? () : (
                email_meetme_received => $self->_ncmsg( "Meet Me request is received", { lang => $lang } ),
            )
        }
    };

    push @sources, {
        header => $self->_ncmsg( "Included in daily digest email:", { lang => $lang } ),
        type => 'email',
        by_default_true_settings => {
            email_digest_title => $self->_ncmsg( "Meeting title changes", { lang => $lang } ),
            email_digest_location => $self->_ncmsg( "Location changes", { lang => $lang } ),
            email_digest_participants => $self->_ncmsg( "New participants", { lang => $lang } ),
            email_digest_materials => $self->_ncmsg( "New materials", { lang => $lang } ),
            email_digest_comments => $self->_ncmsg( "New comments", { lang => $lang } ),
        }
    };

    push @sources, {
        header => $self->_ncmsg( "Calendar events and updates (iCal):", { lang => $lang } ),
        type => 'email',
        by_default_true_settings => {
            email_ical => $self->_ncmsg( "Receive events and updates", { lang => $lang } ),
        }
    };

    push @sources, {
        header => $self->_ncmsg( "Send me a push notification when:", { lang => $lang } ),
        type => 'push',
        by_default_true_settings => {
            push_meeting_invitation => $self->_ncmsg( "Meeting invitation is received", { lang => $lang } ),
            push_meeting_date => $self->_ncmsg( "Date or time changes", { lang => $lang } ),
            push_meeting_location => $self->_ncmsg( "Location changes", { lang => $lang } ),
            $opts->{skip_meetme} ? () : (
                push_meetme_received => $self->_ncmsg( "Meet Me request is received", { lang => $lang } ),
            )
        },
        by_default_false_settings => {
            push_meeting_title => $self->_ncmsg( "Meeting title changes", { lang => $lang } ),
            push_meeting_participant => $self->_ncmsg( "New participant is added", { lang => $lang } ),
            push_meeting_material => $self->_ncmsg( "New material is added", { lang => $lang } ),
            push_meeting_material_comment => $self->_ncmsg( "New comment is received", { lang => $lang } ),
        }
    };

    my $return = [];
    for my $source ( @sources ) {
        my @rounds = ( [ by_default_true_settings => 1 ], [ by_default_false_settings => 0 ] );
        for my $round ( @rounds ) {
            my $settings = $source->{ $round->[0] };
            next unless $settings;
            for my $setting_id ( keys %$settings ) {
                push @$return, {
                    id => $setting_id,
                    title => $settings->{ $setting_id },
                    value => $round->[1],
                    type => $source->{type},
                    header => $source->{header},
                };
            }
        }
    }

    return $return;
}


sub _user_notification_settings_with_current_values {
    my ( $self, $user, $domain_id, $lang ) = @_;

    $user = Dicole::Utils::User->ensure_object( $user );
    my $current_fragment = $self->_fetch_user_matchmaker_fragment( $user );

    $lang ||= $user->language;

    my $settings = $self->_notification_settings_list( $lang, { skip_meetme => $current_fragment ? 0 : 1 } );
    my $values = $self->_get_note_for_user( notification_settings => $user, $domain_id ) || {};
    for my $setting ( @$settings ) {
        if ( defined( $values->{ $setting->{id} } ) ) {
            $setting->{value} = $values->{ $setting->{id} };
        }
    }

    return $settings;
}

sub _user_notification_setting_values_hash {
    my ( $self, $user, $domain_id, $lang ) = @_;

    my $hash = {};
    my $settings = $self->_user_notification_settings_with_current_values( $user, $domain_id, $lang );
    for my $setting ( @$settings ) {
        $hash->{ $setting->{id} } = $setting->{value};
    }

    return $hash;
}

sub _notification_setting_for_user {
    my ( $self, $setting_id, $user, $domain_id ) = @_;

    my $settings_hash = $self->_user_notification_setting_values_hash( $user, $domain_id, 'en' );
    return $settings_hash->{ $setting_id };
}

sub _gather_media_data {
    my ( $self, $meeting, $opts ) = @_;

    my $objects = eval { CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group', {
            domain_id => $meeting->domain_id,
            group_id => $meeting->group_id,
            user_id => 0,
            object_class => CTX->lookup_object('presentations_prese'),
            tags => [ $meeting->sos_med_tag ],
            where => 'dicole_presentations_prese.group_id = ?',
            value => [ $meeting->group_id ],
            order => 'creation_date desc',
        } ) } || [];

    return [] unless @$objects;

    my $comment_counts = $opts->{skip_comment_counting} ? {} : CTX->lookup_action('comments_api')->e(get_comment_counts => {
        objects => $objects
    });

    my $attachments = CTX->lookup_object('attachment')->fetch_group({
        where => Dicole::Utils::SQL->column_in(attachment_id => [ grep { $_ } map { $_->attachment_id } @$objects ])
    });

    my %attachments = map { $_->attachment_id => $_ } @$attachments;
    my %users = map { $_->user_id => $_ } @{ Dicole::Utils::User->ensure_object_list([ map { $_->creator_id } @$objects ]) };

    my $media = [];
    for my $object ( @$objects ) {
        my $user = $users{$object->creator_id};
        my $attachment = $attachments{$object->attachment_id};
        my $info = {
            prese_id => $object->id,
            object_type => ref( $object ),
            created_epoch => $object->creation_date,
            title => $object->name,
            from_file => $object->attachment_id ? 1 : 0,
            attachment_filename => $attachment ? $attachment->filename : '',
            attachment_mime => $attachment ? $attachment->mime : '',
            readable_type => $attachment ? Dicole::Utils::MIME->type_to_readable( $attachment->mime ) : '',
            creator_id => $user ? $user->id : 0,
            author_name => $user ? Dicole::Utils::User->name( $user ) : '',
            comment_count => $comment_counts->{$object->id} || 0,
        };
        push @$media, $info;
    }

    return $media;
}

sub _set_agent_object {
    my ($self, $data, $partner_id, $domain_id, $user_id ) = @_;

    for my $key ( qw( area model uid ) ) {
        if ( ! $data->{ $key } ) {
            die "$key is required to set object";
        }
    }

    $user_id ||= 0;

    my $objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
        where => 'domain_id = ? AND partner_id = ? AND generation = ? AND area = ? AND model = ? AND uid = ?',
        value => [ $domain_id, $partner_id, 'pending', $data->{area}, $data->{model}, $data->{uid} ],
        order => 'id asc',
    } ) || [];

    my $existing = shift @$objects;
    if ( ! $existing ) {
        $existing = CTX->lookup_object('meetings_agent_object_state')->new( {
            domain_id => $domain_id,
            partner_id => $partner_id,
            generation => 'pending',
            created_date => time,
            set_date => 0,
            removed_date => 0,
            set_by => $user_id,
        });
        $existing->{ $_ } = $data->{ $_ } for qw(area model uid);
        $existing->save;

        $objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
            where => 'domain_id = ? AND partner_id = ? AND generation = ? AND area = ? AND model = ? AND uid = ?',
            value => [ $domain_id, $partner_id, 'pending', $data->{area}, $data->{model}, $data->{uid} ],
            order => 'id asc',
        } ) || [];

        my $presumed = shift @$objects;

        if ( $existing->id != $presumed->id ) {
            $_->remove for @$objects;
            die 'Conflict when creating object';
        }
    }

    $existing->{set_date} = $data->{set_epoch} = time;
    $existing->{set_by} = $data->{set_by} = $user_id;
    $data->{created_epoch} = $existing->created_date;

    if ( $data->{removed_epoch} && $data->{removed_epoch} > 0 ) {
        $existing->{removed_date} = $data->{removed_epoch} = time;
    }
    else {
        delete $data->{removed_epoch};
        $existing->{removed_date} = 0;
    }

    my $old_payload = $existing->{payload} || '';
    my $new_payload = Dicole::Utils::JSON->encode( $data );

    delete $data->{set_by};
    delete $data->{set_epoch};

    my $old_data = Dicole::Utils::JSON->decode( $existing->{payload} || '{}' );

    delete $old_data->{set_by};
    delete $old_data->{set_epoch};

    if ( Dicole::Utils::JSON->encode( $data ) eq Dicole::Utils::JSON->encode( $old_data ) ) {
        return 0;
    }

    my $log_data = {
        domain_id => $domain_id,
        partner_id => $partner_id,
        created_date => time,
        old_payload => $old_payload,
        new_payload => $new_payload,
    };

    $log_data->{ $_ } = $data->{ $_ } for qw(area model uid);

    CTX->lookup_object('meetings_agent_object_log')->new( $log_data )->save;

    $existing->{payload} = $new_payload;
    $existing->save;

    return 1;
}

sub _sync_demoify_email_for_domain {
    my ( $self, $emails, $domain, $suffix ) = @_;

    $suffix ||= 'ltdemo';

    my $processed = [];
    for my $email ( split /\s*\,\s*/, $emails ) {
        if ( $email =~ /\@$domain$/ ) {
            $email =~ s/\@.*//;
            $email = 'demo+' . $email . '+' . $suffix . '@meetin.gs';
        }
        push @$processed, $email;
    }
    return join ", ", @$processed;
}


sub _sync_user_has_been_sent_finnish_login {
    my ( $self, $user, $skip_user_contact_log_checking ) = @_;

    return 0 if $skip_user_contact_log_checking;

    my $contacts = CTX->lookup_object('meetings_user_contact_log')->fetch_group( {
        where => 'user_id = ?',
        value => [ $user->id ],
    } );

    for my $contact ( @$contacts ) {
        return 1 if $contact->snippet =~ /Kirjaudu.*palveluun/;
    }

    return 0;
}

sub _sync_create_signature_from_data {
    my ( $self, $data ) = @_;
    return Dicole::Utils::Data->signature_base64url( $data );

}

sub _sync_create_mmr_signature {
    my ( $self, $object ) = @_;

    return $self->_sync_create_signature_from_data( $self->_sync_create_mmr_signature_data( $object ) );
}

sub _sync_create_user_signature {
    my ( $self, $object ) = @_;

    return $self->_sync_create_signature_from_data( $self->_sync_create_user_signature_data( $object ) );
}

sub _sync_create_partner_signature {
    my ( $self, $object ) = @_;

    return $self->_sync_create_signature_from_data( $self->_sync_create_partner_signature_data( $object ) );
}

sub _sync_create_mmr_signature_data {
    my ( $self, $object ) = @_;

    my $data = Dicole::Utils::Data->get_notes( $object );
    for my $key ( qw( name vanity_url_path description website allow_multiple disabled_date ) ) {
        $data->{ 'base_' . $key } = $object->get( $key ) || '';
    }

    return $data;
}

sub _sync_create_user_signature_data {
    my ( $self, $object, $domain_id ) = @_;

    my $data = Dicole::Utils::Data->get_notes( $object );
#    for my $key ( qw( name email phone title language timezone removal_date login_disabled ) ) {
    for my $key ( qw( name email phone title language timezone ) ) {
        $data->{ 'base_' . $key } = $object->get( $key ) || '';
    }

    my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        user_id => $object->id,
        domain_id => $domain_id,
    } );
    for my $key ( qw( contact_phone contact_organization contact_title ) ) {
        $data->{ 'attr_' . $key } = $attrs->{ $key } || '';
    }
    return $data;
}

sub _sync_create_partner_signature_data {
    my ( $self, $object ) = @_;

    my $data = Dicole::Utils::Data->get_notes( $object );
    for my $key ( qw( name domain_alias name api_key localization_namespace ) ) {
        $data->{ 'base_' . $key } = $object->get( $key ) || '';
    }
    return $data;
}

sub _store_signatures_for_touched_objects {
    my ( $self, $touched_objects, $filename_start ) = @_;

    $filename_start ||= '/root/latest_sync_signature';

    my $run_signature = {};
    my $run_signature_data = {};

    for my $id ( sort keys %{ $touched_objects->{mmr} } ) {
        my $object = $touched_objects->{mmr}->{$id};
        $object = CTX->lookup_object('meetings_matchmaker')->fetch( $id ) unless ref $object;
        my $data = $run_signature_data->{"mmr_" . $id} = $self->_sync_create_mmr_signature_data( $object );
        $run_signature->{"mmr_" . $id} = $self->_sync_create_signature_from_data( $data );
    }
    for my $id ( sort keys %{ $touched_objects->{user} } ) {
        my $object = $touched_objects->{user}->{$id};
        $object = CTX->lookup_object('user')->fetch( $id ) unless ref $object;
        my $data = $run_signature_data->{"user_" . $id} = $self->_sync_create_user_signature_data( $object );
        $run_signature->{"user_" . $id} = $self->_sync_create_signature_from_data( $data );
    }
    for my $id ( sort keys %{ $touched_objects->{partner} } ) {
        my $object = $self->PARTNERS_BY_ID->{ $id };
        my $data = $run_signature_data->{"partner_" . $id} = $self->_sync_create_partner_signature_data( $object );
        $run_signature->{"partner_" . $id} = $self->_sync_create_signature_from_data( $data );
    }

    open( my $fh, ">" . $filename_start . ".json" );
    print $fh Dicole::Utils::JSON->encode_pretty( $run_signature );
    close $fh;

    open( my $fh2, ">" . $filename_start . "_data.json" );
    print $fh2 Dicole::Utils::JSON->encode( $run_signature_data );
    close $fh2;

    `mkdir -p $filename_start`;
    for my $key ( keys %$run_signature_data ) {
        open( my $fh3, ">" . $filename_start . "/$key.json" );
        print $fh3 Dicole::Utils::JSON->encode_pretty( $run_signature_data->{$key} );
        close $fh3;
    }

    print "done.\n";
}

sub _fill_lt_stash_data {
    my ( $self, $stash ) = @_;

    $stash->{all_areas} = [
        { id => 'py', name => 'Palveluyhtiö', report_all_meetings => 1, skip_manage => 1 },

        { id => 'ete', name => 'Etelä' },
        { id => 'epo', name => 'Etelä-Pohjanmaa' },
        { id => 'hy', name => 'Henkiyhtiö' },
        { id => 'ita', name => 'Itä' },
        { id => 'kas', name => 'Kaakkois-Suomi' },
        { id => 'kak', name => 'Kainuu-Koilismaa' },
        { id => 'kes', name => 'Keski-Suomi' },
        { id => 'lap', name => 'Lappi' },
        { id => 'loh', name => 'Loimi-Häme' },
        { id => 'lan', name => 'Lännen' },
        { id => 'pir', name => 'Pirkanmaa' },
        { id => 'poh', name => 'Pohjoinen' },
        { id => 'pks', name => 'Pääkaupunkiseutu' },
        { id => 'sak', name => 'Savo-Karjala' },
        { id => 'sav', name => 'Savo' },
        { id => 'sat', name => 'Satakunta' },
        { id => 'sye', name => 'Sydkusten-Etelärannikko' },
        { id => 'uus', name => 'Uusimaa' },
        { id => 'vsu', name => 'Varsinais-Suomi' },
        { id => 'vel', name => 'Vellamo' },
        { id => 'osp', name => 'Österbotten-Pohjanmaa' },

        { id => 'esim', name => 'Esimerkkiyhtiö', skip_billing => 1 },
    ];


    $stash->{all_languages} = [
        { id => 'fi', long_id => 'suomi', name => 'Suomi' },
        { id => 'sv', long_id => 'svenska', name => 'Svenska' },
        { id => 'en', long_id => 'english', name => 'English' },
    ];

    $stash->{all_service_levels} = [
        { id => 'etutaso0-1', name => 'Etutaso 0-1' },
        { id => 'etutaso2-4', name => 'Etutaso 2-4' },
    ];

    $stash->{all_meeting_types} = [
        { id => 'omaisuudenvakuuttaminen', name => 'Omaisuuden vakuuttaminen' },
        { id => 'henkiloturvanvakuuttaminen', name => 'Henkilöturvan vakuuttaminen' },
        { id => 'saastaminenjasijoittaminen', name => 'Säästäminen ja sijoittaminen' },
        { id => 'vakuutusturvankartoitus', name => 'Vakuutusturvan kartoitus' },
        { id => 'vakuutusturvankartoituspuhelimella', name => 'Vakuutusturvan kartoitus puhelimella' },
        { id => 'vakuutusturvankartoituskotona', name => 'Vakuutusturvan kartoitus kotona', custom_address_from_user => 1 },
        { id => 'verkkotapaaminen', name => 'Verkkotapaaminen' },
        { id => 'esimerkkitapaaminen', name => 'Esimerkkitapaaminen' },
        { id => 'sijoitustapaaminenasiakkaanluona', name => 'Sijoitustapaaminen asiakkaan luona', custom_address_from_user => 1 },
        { id => 'saastaminen', name => 'Säästäminen' },
        { id => 'sijoittaminenhenkilotjayritykset', name => 'Sijoittaminen (Henkilöt ja Yritykset)' },
        { id => 'sijoittaminenyritys', name => 'Sijoittaminen (Yritys)' },
        { id => 'privatehenkilot', name => 'Private (Henkilöt)' },
        { id => 'privateyritys', name => 'Private (Yritys)' },
    ];

    $stash->{areas_by_id} = { map { $_->{id} => $_ } @{ $stash->{all_areas} } };
    $stash->{types_by_id} = { map { $_->{id} => $_ } @{ $stash->{all_meeting_types} } };
}

sub _demoify_agent_object_data {
    my ( $self, $ao ) = @_;

    if ( $ao->{model} eq 'user' ) {
        for my $key ( 'email', 'supervisor', 'changed_email', 'uid' ) {
            $ao->{ $key } = $self->_sync_demoify_email_for_domain( $ao->{ $key }, 'lahixcustxz.fi' );
        }
    }

    if ( $ao->{model} eq 'office' ) {
        for my $key ( 'group_email' ) {
            $ao->{ $key } = $self->_sync_demoify_email_for_domain( $ao->{ $key }, 'lahixcustxz.fi' );
        }
    }

    if ( $ao->{model} eq 'calendar' ) {
        for my $key ( 'user_email' ) {
            $ao->{ $key } = $self->_sync_demoify_email_for_domain( $ao->{ $key }, 'lahixcustxz.fi' );
        }
        $ao->{uid} = join " ", $ao->{office_full_name}, $ao->{user_email};
    }
}

sub _fill_agent_object_stash_from_db {
    my ( $self, $stash, $generation, $area, $opts ) = @_;

    die "missing generation" unless $generation;
    die "missing stash items" unless $stash;
    die "missing stash domain_id" unless $stash->{domain_id};
    die "missing stash partner_id" unless $stash->{partner_id};

    $opts ||= {};

    if ( ! $area || $opts->{force_refresh} || ! $stash->{objects_by_area}->{ $area } ) {
        my $objects = $area ?
            CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
                where => 'domain_id = ? AND partner_id = ? AND generation = ? AND removed_date = 0 AND area = ?',
                value => [ $stash->{domain_id}, $stash->{partner_id}, $generation, $area ],
            } )
            :
            CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
                where => 'domain_id = ? AND partner_id = ? AND generation = ? AND removed_date = 0',
                value => [ $stash->{domain_id}, $stash->{partner_id}, $generation ],
            } );

        my $agent_objects = [ map { Dicole::Utils::JSON->decode( $_->payload ) } @$objects ];

        $stash->{objects_by_area} ||= {};

        for my $ao ( @$agent_objects ) {
            next unless $ao->{area} && $ao->{model};

            $self->_demoify_agent_object_data( $ao ) if $stash->{domain_id} == 76 && ! $opts->{skip_demoify};

            $stash->{objects_by_area}->{ $ao->{area} } ||= {};
            my $model_key = $ao->{model} . 's';

            $stash->{objects_by_area}->{ $ao->{area} }->{ $model_key } ||= {};
            $stash->{objects_by_area}->{ $ao->{area} }->{ $model_key }->{ $ao->{uid} } = $ao;
        }

        for my $model_key ( qw( users offices calendars settings ) ) {
            $stash->{ $model_key . '_by_area' } ||= {};
            for my $a ( keys %{ $stash->{objects_by_area} } ) {
                $stash->{ $model_key . '_by_area' }->{ $a } = $stash->{objects_by_area}->{ $a }->{ $model_key } || {};
            }
        }
    }

    for my $a ( keys %{ $stash->{calendars_by_area} } ) {
        for my $cal ( values %{ $stash->{calendars_by_area}->{ $a } } ) {
            for my $enum_key ( qw( meeting_types languages service_levels ) ) {
                $cal->{ $enum_key . '_map' } = { map { $_ => 1 } @{ $cal->{ $enum_key } } };
            }
            $cal->{languages_long_map} = {
                suomi => $cal->{languages_map}->{fi},
                svenska => $cal->{languages_map}->{sv},
                english => $cal->{languages_map}->{en},
            };

            my $rep = $stash->{users_by_area}->{ $cal->{area} }->{ $cal->{user_email} };
            if ( $rep ) {
                $rep->{calendar_count} ||= 0;
                $rep->{calendar_count}++;
            }
        }
    }

    if ( $area ) {
        for my $model_key ( qw( users offices calendars settings ) ) {
            $stash->{ $model_key } = $stash->{objects_by_area}->{ $area }->{ $model_key };
        }

        if ( ! $stash->{settings}->{general} ) {
            $stash->{settings}->{general} = { 'etutaso0-1_length_minutes' => '120', 'etutaso2-4_length_minutes' => '90' };
        }
    }

    my $translations = $opts->{skip_translations} ? [] : Dicole::Utils::JSON->decode( Dicole::Utils::HTTP->get( 'http://versions.meetin.gs/ltcache/translations.json' ) );

    my $translation_map = {};
    for my $trans ( @$translations ) {
        my $target = $trans->{target};
        for my $lang ( qw( suomi english svenska ) ) {
            $translation_map->{$lang}->{ Dicole::Utils::Text->ensure_utf8( $target ) } = Dicole::Utils::Text->ensure_utf8( $trans->{ $lang } );
        }
    }

    $stash->{translations} = $translations;
    $stash->{translation_map} = $translation_map;

    my $partner = $self->PARTNERS_BY_ID->{ $stash->{partner_id} };

    $stash->{all_areas} ||= $self->_get_note( all_areas => $partner );
    $stash->{all_languages} ||= $self->_get_note( all_languages => $partner );
    $stash->{all_service_levels} ||= $self->_get_note( all_service_levels => $partner );
    $stash->{all_meeting_types} ||= $self->_get_note( all_meeting_types => $partner );

    $stash->{areas_by_id} = { map { $_->{id} => $_ } @{ $stash->{all_areas} } };
    $stash->{types_by_id} = { map { $_->{id} => $_ } @{ $stash->{all_meeting_types} } };

    return $stash;
}

sub _clear_email_for_new_user {
    my ( $self, $email, $domain_id ) = @_;

    my $user = $self->_fetch_user_for_email( $email, $domain_id );
    return unless $user;
    $user->email( $user->email . '-disabled-' . time );
    $user->login_name( $user->login_name . '-disabled-' . time );
    $user->save;

    # TODO: email aliases + service_accounts

}

sub _gather_agent_user_export_data {
    my ( $self, $from, $to, $selected_area, $domain_id, $partner ) = @_;

    my $partner_id = $partner->id;
    my $all_areas = $self->_get_note( all_areas => $partner );
    my $areas_by_id = { map { $_->{id} => $_ } @$all_areas };

    my $from_ymd = Dicole::Utils::Date->epoch_to_datetime( $from, 'Europe/Helsinki', 'en' )->ymd('-');
    my $to_ymd = Dicole::Utils::Date->epoch_to_datetime( $to, 'Europe/Helsinki', 'en' )->ymd('-');
    my ( $from_ym ) = $from_ymd =~ /^(.*)\-\d+$/;
    my ( $to_ym ) = $to_ymd =~ /^(.*)\-\d+$/;

    my $generation_where = "( generation like '$from_ym%' OR generation like '$to_ym%' )";

    my $area_where = $selected_area ? ' AND area = ?' : '';
    my @area_value = $selected_area ? ( $selected_area ) : ();

    my $objects = CTX->lookup_object('meetings_agent_object_state')->fetch_group( {
        where => 'removed_date = 0 AND domain_id = ? AND partner_id = ? AND ' . $generation_where . $area_where,
        value => [ $domain_id, $partner->id, @area_value ],
    } );

    my $billed_objects = $objects;

    if ( ! $selected_area ) {
        $billed_objects = [];
        for my $o ( @$objects ) {
            my $a = $areas_by_id->{ $o->area };
            next if $a && $a->{skip_billing};
            next if $a && $a->{id} eq 'esim';
            push @$billed_objects, $o;
        }
    }

    my $gen_to_epoch = {};
    my $found = {};

    for my $state ( @$billed_objects ) {
        next unless $state->model eq 'user';
        next if $found->{ $state->uid };

        my $epoch = $gen_to_epoch->{ $state->generation };

        if ( ! $epoch ) {
            my ( $ymd ) = $state->generation =~ /^(\d+\-\d+\-\d+)/;
            $epoch = Dicole::Utils::Date->ymd_to_day_start_epoch( $ymd, 'Europe/Helsinki' );
            $gen_to_epoch->{ $state->generation } = $epoch;
        }

        next if $epoch < $from;
        next if $epoch > $to;

        my $data = Dicole::Utils::JSON->decode( $state->payload );
        $found->{ $state->uid } = {
            Email => $data->{email},
            Nimi => $data->{name},
        };
    }

    return [ map { $found->{ $_ } } sort keys %$found ];
}

sub _gather_agent_meeting_export_data {
    my ( $self, $from, $to, $area, $domain_id, $partner ) = @_;

    my $partner_id = $partner->id;

    my $all_ms = CTX->lookup_object('events_event')->fetch_group({
        where => "domain_id = ? AND begin_date >= ? AND begin_date < ?",
        value => [ $domain_id, $from, $to ],
        order => 'begin_date asc',
    });

    my $ms = [];
    for my $meeting ( @$all_ms ) {
        my $meeting_partner_id = $self->_get_note( owned_by_partner_id => $meeting );
        next unless $meeting_partner_id && $meeting_partner_id == $partner_id;
        my $reserved_area = $self->_get_note( agent_reserved_area => $meeting );
        if ( ! $reserved_area ) {
            my $mmr_id = $self->_get_note( created_from_matchmaker_id => $meeting );
            next unless $mmr_id;
            my $mmr = $self->_ensure_matchmaker_object( $mmr_id );
            $reserved_area = $self->_get_note( agent_reserved_area => $mmr ) || 'pks';
            $self->_set_note( agent_reserved_area => $reserved_area, $meeting );
        }
        push @$ms, $meeting unless $area && $area ne $reserved_area;
    }

    my $first_date = $from;
    for my $m ( @$ms ) {
        $first_date = $m->created_date if $first_date > $m->created_date;
    }

    my $m_id_map = { map { $_->id => $_ } @$ms };

    my $contact_log = CTX->lookup_object('meetings_user_contact_log')->fetch_group({
        where => "domain_id = ? AND created_date >= ? AND created_date < ? and contact_method = ?",
        value => [ $domain_id, $first_date - 10, $to, 'sms' ],
        order => 'created_date asc',
    });
    my $log_map = {};
    for my $log ( @$contact_log ) {
        # NOTE Legacy fix
        if( $log->contact_type eq 'unknown' ) {
            next unless ( $log->snippet =~ /apaamisemme l/ || $log->snippet =~ /is getting closer/ );
            $log->contact_type( 'lt_custom_reminder' );
            $log->save;
        }

        # NOTE Legacy fix
        if ( ! $log->meeting_id ) {
            next unless $log->contact_type eq 'lt_custom' || $log->contact_type eq 'lt_custom_reminder';
            if ( $log->contact_type eq 'lt_custom' ) {
                for my $m ( @$ms ) {
                    next unless $m->created_date > $log->created_date - 15;
                    next unless $m->created_date < $log->created_date + 15;
                    next unless $self->_check_if_meeting_has_had_user_as_participant( $m, $log->user_id );
                    $log->meeting_id( $m->id );
                    $log->save;
                    next;
                }
            }

            if ( $log->contact_type eq 'lt_custom_reminder' ) {
                for my $m ( @$ms ) {
                    next unless $m->begin_date - 24*60*60 > $log->created_date - 75*60;
                    next unless $m->begin_date - 24*60*60 < $log->created_date + 75*60;
                    next unless $self->_check_if_meeting_has_had_user_as_participant( $m, $log->user_id );
                    $log->meeting_id( $m->id );
                    $log->save;
                    next;
                }
            }
        }

        next unless $log->contact_type eq 'lt_custom' || $log->contact_type eq 'lt_custom_reminder' || $log->contact_type eq 'lt_custom_reschedule';
        next unless $log->meeting_id && $m_id_map->{ $log->meeting_id };

        $log_map->{ $log->meeting_id } ||= [];
        push @{ $log_map->{ $log->meeting_id } }, $log;
    }

    my $uc = {};
    my $outputs = [];
    for my $meeting ( @$ms ) {
        my $reserver_id = $self->_get_note( matchmaking_lock_creator_id => $meeting );
        next unless $reserver_id;

        my $reserver = $uc->{ $reserver_id } ||= Dicole::Utils::User->ensure_object( $reserver_id );
        my $creator = $uc->{ $meeting->creator_id } ||= Dicole::Utils::User->ensure_object( $meeting->creator_id );

        my $mmr_id = $self->_get_note( created_from_matchmaker_id => $meeting );
        my $mmr = $self->_ensure_matchmaker_object( $mmr_id );
        my $data = $self->_get_note( lahixcustxz_data => $mmr );

        if ( ! $data ) {
            my ( $type ) = $meeting->title =~ /^(.*?) \//;
            my $lang = '?';
            $lang = 'suomi' if $self->_get_note(preset_agenda => $mmr ) =~ /Tervehdys/;
            my $level = '?';
            $level = 'etutaso0-1' if $mmr->name =~ /0\-1/;
            $level = 'etutaso2-4' if $mmr->name =~ /2\-4/;

            my $profile = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
                user_id => $creator->id,
                domain_id => $domain_id,
                attributes => {
                    contact_title => undef
                },
            } );

            $data = {
                type => $type,
                lang => $lang,
                level => $level,
                title => $profile->{contact_title},
            };
        }

        my $s1 = 0;
        my $s2 = 0;
        for my $log ( @{ $log_map->{ $meeting->id } || [] } ) {
            my ( $n ) = ( $log->{notes} || '' ) =~ /NumSegments.(\d+)..NumSegments/;
            next unless $n;
            $s1 += $n if $log->contact_type eq 'lt_custom' || $log->contact_type eq 'lt_custom_reschedule';
            $s2 += $n if $log->contact_type eq 'lt_custom_reminder';
        }
        $s1 .= '';
        $s2 .= '';

        my $output = {
            'Varaaja' => $reserver->email,
            'Varauksen nimi' => $meeting->title,
            'Varauksen vastaanottaja' => $creator->email,
            'Varaus tehty' => $self->_epoch_to_ymdhms( $meeting->created_date ),
            'Varauksen aika' => $self->_epoch_to_ymdhms( $meeting->begin_date ),
            'Varaus peruttu' => $self->_get_note( cancelled_date => $meeting ) ? 'PERUTTU' : '',
            'SMS kutsu pituus' => $s1,
            'SMS muistutus pituus' => $s2,
            'Tyyppi' => $data->{type},
            'Kieli' => $data->{lang},
            'Taso' => $data->{level},
            'Toimisto' => $data->{office},
            'Rooli' => $data->{title},
        };

        push @$outputs, $output;
    }

    return $outputs;
}

sub _epoch_to_ymdhms {
    my ( $self, $epoch ) = @_;
    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch, 'Europe/Helsinki', 'en' );
    return $dt->ymd('-'). ' '. $dt->hms(':');
}

sub _check_if_meeting_has_had_user_as_participant {
    my ( $self, $m, $user_id ) = @_;
    my $event_users = CTX->lookup_object('events_user')->fetch_group( {
        where => 'event_id = ?',
        value => [ $m->id ],
    } );
    for my $eu ( @$event_users ) {
        return 1 if $user_id == $eu->user_id;
    }
    return 0;
}

1;
