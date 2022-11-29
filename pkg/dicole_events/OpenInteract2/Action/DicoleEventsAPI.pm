package OpenInteract2::Action::DicoleEventsAPI;

use strict;

use base qw( OpenInteract2::Action::DicoleEventsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Text::Unidecode;

sub create_event {
    my ( $self ) = @_;

    my $event = CTX->lookup_object('events_event')->new();

    $event->domain_id( Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') ) );

    my $group_id = $self->param('group_id');
    $group_id = eval{ CTX->controller->initial_action->param('target_group_id') } || 0 unless defined( $group_id );
    $event->group_id( $group_id );

    my $creator_id = $self->param('creator_id');
    $creator_id = eval{ CTX->request->auth_user_id } || 0 unless defined( $creator_id );
    $event->creator_id( $creator_id );

    $event->title( $self->param('title') || '' );

    my $sos_med_tag = $self->param('sos_med_tag');
    $sos_med_tag = $self->_prepare_sos_med_tag( $event->title ) unless $sos_med_tag;
    $event->sos_med_tag( $sos_med_tag );

    $event->abstract( $self->param('abstract') || '' );
    $event->description( $self->param('description') || '' );
    $event->logo_attachment( 0 );
    $event->banner_attachment( 0 );
    $event->location_name( $self->param('location_name') || '' );

    $event->attend_info( $self->param('attend_info') || '' );
    $event->require_phone( $self->param('require_phone') || 0 );
    $event->require_invite( $self->param('require_invite') || 0 );
    $event->num_attenders( 0 );
    $event->max_attenders( $self->param('max_attenders') || 0 );
    $event->created_date( $self->param('created_date') || time() );
    $event->removed_date( 0 );
    $event->updated_date( $event->created_date );
    $event->promoted_date( $self->param('promoted') ? time() : 0 );

    $event->latitude( $self->param('latitude') );
    $event->longitude( $self->param('longitude') );

    $event->begin_date( $self->param('begin_date') || 0 );
    $event->end_date( $self->param('end_date') || 0 );
    $event->reg_begin_date( $self->param('reg_begin_date') || 0 );
    $event->reg_end_date( $self->param('reg_end_date') || 0 );

    $event->event_state( $self->STATE_BY_NAME()->{ $self->param('event_state') } || $self->param('event_state') || $self->STATE_PRIVATE );
    $event->invite_policy($self->INVITE_BY_NAME()->{ $self->param('invite_policy') } || $self->param('invite_policy') || $self->INVITE_PLANNERS );

    for ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
        $event->set( $_, $self->param( $_ ) || $self->SHOW_ALL );
    }

    $event->save();

    my $tags = $self->param('tags') || [];
    CTX->lookup_action('tags_api')->e( attach_tags => {
        object => $event, user_id => 0, group_id => $event->group_id, domain_id => $event->domain_id, 'values' => $tags,
    } );

    $self->_add_event_planner( $event, $creator_id, $creator_id, 1 ) if $creator_id;

    return $event;
}

sub remove_event {
    my ( $self ) = @_;

    my $event = $self->param('event') || CTX->lookup_object('events_event')->fetch( $self->param('event_id') );

    return $self->_remove_event( $event, $self->param('domain_id'), $self->param('user_id') );
}

sub validate_invite {
    my ( $self ) = @_;

    my $ic = $self->param('invite_code');
    my $tgid = $self->param('target_group_id');

    my $invite = $self->_fetch_invite( undef, $ic );
    return 0 unless $invite;
    return 0 unless $invite->group_id == $tgid;
    return 1;
}

sub add_event_user {
    my ( $self ) = @_;

    return $self->_add_event_user( $self->param('event') || $self->param('event_id'), $self->param('user') || $self->param('user_id'), $self->param('inviter_id'), $self->param('was_invited') );
}

sub add_event_planner {
    my ( $self ) = @_;

    return $self->_add_event_planner( $self->param('event') || $self->param('event_id'), $self->param('user') || $self->param('user_id'), $self->param('inviter_id'), $self->param('was_invited') );
}


sub init_store_creation_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'created', @_ );
}

sub init_store_edit_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'edited', @_ );
}

sub init_store_delete_event {
    my $self = shift @_;
    return $self->_init_store_some_event( 'deleted', @_ );
}

sub _init_store_some_event {
    my ( $self, $type ) = @_;

    return $self->_store_some_event(
        $type,
        $self->param('event'),
        undef,
        $self->param('domain_id'),
        $self->param('user_id'),
        $self->param('previous_tags'),
    );
}

sub get_sidebar_list_html_for_events_matching_tags {
    my ( $self ) = @_;

    my $params = {};
    $params->{events} = $self->get_params_for_events_matching_tags;

    return unless $params->{events} && scalar @{ $params->{events} };

    $params->{dump} = Data::Dumper::Dumper( $params );
    return $self->generate_content( $params, { name => 'dicole_events::sidebar_list' } );
}

sub get_params_for_events_matching_tags {
    my ( $self ) = @_;

    my $tags = $self->param('tags');

    return [] unless scalar @$tags;

    my $gid = $self->param('group_id');
    my $did = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    my $events = CTX->lookup_object('events_event')->fetch_group({
        where => 'group_id = ? AND ' . Dicole::Utils::SQL->column_in_strings( sos_med_tag => $tags ),
        value => [ $gid ],
    });

    my $infos = [];
    for my $event ( @$events ) {
        next unless $self->_current_user_can_see_event( $event );
        my $info = {
            title => $event->title,
            logo_url => $event->logo_attachment ? $self->_event_logo_url( $event ) : '',
            show_url => $self->_event_show_url( $event ),
        };

        push @$infos, $info;
    }

    return $infos;
}

sub ensure_event_object_in_group {
    my ( $self ) = @_;

    return $self->_ensure_event_object_in_group( $self->param('event') || $self->param('event_id'), $self->param('group_id') );
}

sub gather_event_params  {
    my ( $self ) = @_;

    return $self->_gather_event_params( $self->param('event') );
}

sub fetch_invite  {
    my ( $self ) = @_;

    return $self->_fetch_invite( $self->param('event') );
}

sub current_user_can_see_event {
    my ( $self ) = @_;

    return $self->_current_user_can_see_event( $self->param('event'), $self->param('invite') );
}

sub event_users_link_list {
    my ( $self ) = @_;

    return $self->_event_users_link_list( $self->param('event') );
}

sub gather_pages_data {
    my ( $self ) = @_;

    return $self->_gather_pages_data( $self->param('event') );
}

sub gather_media_data {
    my ( $self ) = @_;

    return $self->_gather_media_data( $self->param('event'), $self->param('limit') );
}

sub consume_invite {
    my ( $self ) = @_;

    return $self->_consume_invite( $self->param('invite'), $self->param('user') || $self->param('user_id') );
}

sub remove_event_user {
    my ( $self ) = @_;

    return $self->_remove_event_user( $self->param('event'), $self->param('user') || $self->param('user_id') );
}

sub get_event_user_object {
    my ( $self ) = @_;

    return $self->_get_event_user_object( $self->param('event') || $self->param('event_id'), $self->param('user') || $self->param('user_id') );
}

sub invite {
    my ( $self ) = @_;

    return $self->_invite(
        $self->param( 'event' ),
        $self->param( 'users' ),
        $self->param( 'emails' ),
        $self->param( 'as_planner' ),
        $self->param( 'greeting_message' ),
        $self->param( 'greeting_subject' ),
    );
}

sub update_comments_info {
    my ( $self ) = @_;

    return $self->_update_comments_info( $self->param('event'), $self->param('domain_id') );
}

1;
