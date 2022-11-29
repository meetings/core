package OpenInteract2::Action::DicoleMeetingsJSONAPI;

use 5.010;
use strict;
use warnings;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _fetch_valid_partner {
    my ($self) = @_;

    die { code => 666, message => "SSL required" } unless $self->_connection_is_https;

    my $key = CTX->request->param('api_key')
        or die { code => 666, message => "api_key required" };

    my $partner = $self->PARTNERS_BY_API_KEY->{ $key }
        or die { code => 666, message => "unknown partner_key" };

    return $partner;
}

sub create {
    my ( $self ) = @_;

    my $partner = $self->_fetch_valid_partner;

    my $email = CTX->request->param('creator_email')
        or die { code => 666, message => "creator_email required" };

    my $title          = CTX->request->param('title')    // '?';
    my $location       = CTX->request->param('location');
    my $start_epoch    = CTX->request->param('start_epoch');
    my $end_epoch      = CTX->request->param('end_epoch');
    my $external_id    = CTX->request->param('external_id');
    my $agenda_text    = CTX->request->param('agenda_text');
    my $agenda_html    = CTX->request->param('agenda_html');
    my $disable_create_email = CTX->request->param('disable_create_email');
    my $merge_key = CTX->request->param('merge_key');

    my $agenda = $agenda_html || $agenda_text ? Dicole::Utils::HTML->text_to_html($agenda_text) : '';

    my $meeting = undef;
    my $user = undef;

    if ( $merge_key ) {
        my ( $meeting_id, $user_id ) = $merge_key =~ /^(\d+)_(\d+)_/;
        $meeting = $self->_ensure_meeting_object( $meeting_id );
        my $merge_user = Dicole::Utils::User->ensure_object( $user_id );

        die "security error" unless $merge_key eq $self->_create_meeting_partner_merge_verification_checksum_for_user( $meeting, $merge_user );

        $user = Dicole::Utils::User->ensure_object( $meeting->creator_id );

        if ( ! $user->email ) {
            my $email_user = $self->_fetch_user_for_email($email);
            if ( ! $email_user ) {
                $user->email( $email );
                $user->save;
            }
            else {
                $self->_transfer_meeting_from_temp_user_to_user( $meeting, $user, $email_user );
                $self->_merge_temp_user_to_user( $user, $email_user, $meeting->domain_id );
                $user = $email_user;
            }
        }

        $self->_fill_user_profile_from_params( $user, $partner->domain_id );

        $meeting->location( $location );
        $meeting->begin_epoch( $start_epoch );
        $meeting->end_epoch( $end_epoch );

        $self->_set_note_for_meeting(owned_by_partner_id => $partner->id, $meeting, undef, { skip_save => 1 } );
        $self->_set_note_for_meeting(merged_by_partner_id => $partner->id, $meeting, undef, { skip_save => 1 } );

        $meeting->save;
    } 
    else {
        my $user = $self->_fetch_user_for_email($email);
        if ( ! $user ) {
            $user = $self->_fetch_or_create_user_for_email($email);
            $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => time, $user, $partner->domain_id, { skip_save => 1 } );
            $self->_set_note_for_user( 'created_by_partner' => $partner->id, $user, $partner->domain_id, { skip_save => 1 } );
        }

        $self->_fill_user_profile_from_params( $user, $partner->domain_id );

        $meeting = CTX->lookup_action('meetings_api')->e(create => {
                creator        => $user,
                partner_id     => $partner->id,
                creator_partner_id => $partner->id,
                group_id       => $self->_determine_user_base_group( $user ),
                title          => $title,
                location       => $location,
                begin_epoch    => $start_epoch,
                end_epoch      => $end_epoch,
                initial_agenda => $agenda,
                disable_create_email => $disable_create_email ? 1 : 0,
            });
    }

    # TODO: partners that do not sponsor
    $self->_set_note_for_meeting(sponsoring_partner_id => $partner->id, $meeting, undef, { skip_save => 1 } );
    $self->_set_note_for_meeting(external_id => $partner->id . ':' .$external_id, $meeting, undef, { skip_save => 1 } ) if defined $external_id;

    my $rooms = eval { Dicole::Utils::JSON->decode( CTX->request->param('room_id_list') ) };
    $self->_set_note_for_meeting(partner_room_id_list => $rooms, $meeting, undef, { skip_save => 1 } ) if $rooms && ref( $rooms ) eq 'ARRAY';

    $meeting->save;

    # NOTE: Do this so that pertner sponsoring is updated correctly
    $self->_calculate_meeting_is_pro( $meeting, $user );

    return $self->_return_meeting_info( $meeting, $partner, 'creator_url', $email, $user  );
}

sub _return_meeting_info {
    my ( $self, $meeting, $partner, $url_type, $url_email, $email_user ) = @_;

    my %base_enter_parts = (
        action => 'meetings',
        task => 'enter_meeting',
        target => $meeting->group_id,
        domain_id => $meeting->domain_id,
        partner_id => $meeting->partner_id,
        additional => [ $meeting->id, $self->_get_meeting_cloaking_hash( $meeting ) ],
    );

    my $domain_host = $self->_get_host_for_meeting( $meeting );

    my $result = {
        uid => $self->_get_note_for_meeting( uid => $meeting ),
        external_id => $self->_get_meeting_external_id( $meeting ),
        room_id_list => $self->_get_note_for_meeting( partner_room_id_list => $meeting ) || [],
        email => $self->_get_meeting_email( $meeting ),
        url => $domain_host . Dicole::URL->from_parts( %base_enter_parts ),
        $url_type ? (
            $url_type => $domain_host . Dicole::URL->from_parts(
                %base_enter_parts,
                params => {
                    %{ $base_enter_parts{params} || {} },
                    login_email => $url_email,
                    $email_user ? ( pcs => $self->_create_partner_authentication_checksum_for_user( $partner, $email_user ) ) : (),
                },
            ),
        ) : (),
    };

    return { result => $result }
}

sub _fetch_valid_meeting_for_partner {
    my ( $self, $partner ) = @_;

    my $meeting;

    if ( my $uid = CTX->request->param('uid') ) {
        $meeting = $self->_fetch_domain_meeting_by_uid( $partner->{domain_id}, $uid, $partner);
    }
    elsif ( my $external_id = CTX->request->param('external_id') ) {
        $meeting = $self->_fetch_domain_meeting_by_full_external_id( $partner->{domain_id}, $partner->id . ':' . $external_id, $partner );
    }
    else {
        die { code => 666, message => 'You must provide either uid or external_id' };
    }

    die { code => 666, message => 'Meeting not found' }
        unless $meeting && $partner->id eq $self->_get_note_for_meeting( created_by_partner_id => $meeting );

    return $meeting;
}

sub info {
    my ($self) = @_;

    my $partner = $self->_fetch_valid_partner;
    my $meeting = $self->_fetch_valid_meeting_for_partner( $partner );

    if ( my $email = CTX->request->param('login_email') ) {
        my $user = eval { $self->_fetch_user_for_email( $email ) };
        return $self->_return_meeting_info( $meeting, $partner, 'login_email_url', $email, $user );
    }

    return $self->_return_meeting_info( $meeting, $partner );
}

sub update {
    my ($self) = @_;

    my $partner = $self->_fetch_valid_partner;
    my $meeting = $self->_fetch_valid_meeting_for_partner( $partner );

    my $agenda_text = CTX->request->param('agenda_text');
    my $agenda_html = CTX->request->param('agenda_html');

    my $agenda = $agenda_html || $agenda_text ? Dicole::Utils::HTML->text_to_html($agenda_text) : '';

    # TODO old_agenda and set new if current matches old

    my $old_info = $self->_gather_meeting_event_info($meeting);

    my $keymap = {
        title => "title",
        location => "location_name",
        start_epoch => "begin_date",
        end_epoch => "end_date",
    };

    my @errors = ();
    
    for my $param (qw/title location start_epoch end_epoch/) {
        my $key = $keymap->{ $param };
        my $new_value = CTX->request->param( $param );
        my $old_value = CTX->request->param( "old_" . $param );
        if ( defined( $new_value ) ) {
            if ( ! defined( $old_value ) ) {
                push @errors, "Could not find the old value for $param. Did not update $param.";
            }
            elsif ( $old_value ne $meeting->get( $key ) ) {
                push @errors, "Provided old value for $param did not match current. Did not update $param.";
            }
            else {
                $meeting->set( $key, $new_value );
            }
        }
    }

    my $rooms = eval { Dicole::Utils::JSON->decode( CTX->request->param('room_id_list') ) };
    $self->_set_note_for_meeting(partner_room_id => $rooms, $meeting, undef, { skip_save => 1 } ) if $rooms && ref( $rooms ) eq 'ARRAY';

    $meeting->save;

    my $new_info = $self->_gather_meeting_event_info( $meeting );

    $self->_store_meeting_event( $meeting, {
        event_type => 'meetings_meeting_changed',
        classes => [ 'meetings_meeting' ],
        data => { old_info => $old_info, new_info => $new_info },
    } );

    return { result => { saved => 1, ( scalar( @errors ) ? ( errors => [ @errors ] ) : () ) } };
}

sub cancel {
    my ($self) = @_;

    my $partner = $self->_fetch_valid_partner;
    my $meeting = $self->_fetch_valid_meeting_for_partner( $partner );

    $self->_set_note_for_meeting(sponsoring_partner_id => 0, $meeting );

    return { result => 1 };
}

sub _downgrade_premium_meeting {
    my ($self, $meeting) = @_;

    $self->_set_note_for_meeting(premium => 0, $meeting);
}

sub _make_meeting_premium {
    my ($self, $meeting) = @_;

    $self->_set_note_for_meeting(premium => 1, $meeting);
}

sub _fill_user_profile_from_params {
    my ($self, $user, $domain_id ) = @_;

    $self->_fill_user_object_attributes_from_params($user, $domain_id);

    $self->_fill_user_profile_attributes_from_params($user, $domain_id);

    $user->save;    
}

sub _fill_user_object_attributes_from_params {
    my ($self, $user, $domain_id) = @_;

    my @attributes = qw/first_name last_name timezone language/;

    for my $attribute (@attributes) {
        next if $user->$attribute;
        if (defined(my $value = CTX->request->param('creator_' . $attribute))) {
            $user->$attribute($value);
        }
    }
}

sub _fill_user_profile_attributes_from_params {
    my ($self, $user, $domain_id ) = @_;

    my @attributes = qw/skype title phone organization/;

    my $old_attributes = CTX->lookup_action('networking_api')->e(user_profile_attributes => {
        user_id => $user->id,
        domain_id => $domain_id,
        attributes => {
            personal_linkedin => undef || '',            
            map { +"contact_$_" => undef } @attributes
        }
    });

    my @unset_attributes = grep { ! $old_attributes->{ $_ } } @attributes;

    CTX->lookup_action('networking_api')->e(user_profile_attributes => {
        user_id => $user->id,
        domain_id => $domain_id,        
        attributes => {
            personal_linkedin => CTX->request->param('creator_linkedin') || '',
            map { +"contact_$_" => CTX->request->param("creator_$_") } @unset_attributes
        }
    }) if @unset_attributes;
}

1;
