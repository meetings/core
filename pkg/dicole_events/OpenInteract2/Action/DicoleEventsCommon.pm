package OpenInteract2::Action::DicoleEventsCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Text::Unidecode;
use Dicole::Utils::Text;
use Dicole::Utils::Template;
use Dicole::MessageHandler qw( :message );
use Dicole::Utils::MIME;

sub OBJECTS_ON_PAGE { 10 }

sub STATE_DRAFT { 1 }
sub STATE_PRIVATE { 2 }
sub STATE_PUBLIC { 3 }

sub STATE_BY_NAME { return {
    'draft' => STATE_DRAFT(),
    'private' => STATE_PRIVATE(),
    'public' => STATE_PUBLIC(),
} }

sub STATE_NAMES { return {
    STATE_DRAFT() => 'draft',
    STATE_PRIVATE() => 'private',
    STATE_PUBLIC() => 'public',
} }

sub INVITE_PLANNERS { 1 }
sub INVITE_USERS { 2 }
sub INVITE_ANYONE { 3 }

sub INVITE_BY_NAME { return {
    'planners' => INVITE_PLANNERS(),
    'users' => INVITE_USERS(),
    'anyone' => INVITE_ANYONE(),
} }

sub INVITE_NAMES { return {
    INVITE_PLANNERS() => 'planners',
    INVITE_USERS() => 'users',
    INVITE_ANYONE() => 'anyone',
} }

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

sub SHOW_NAMES { return {
    SHOW_ALL() => 'all',
    SHOW_USER() => 'user',
    SHOW_ATTENDING() => 'attending',
    SHOW_NONE() => 'none',
    SHOW_PLANNER() => 'planner',
} }

sub SHOW_BY_NAME { return {
    all => SHOW_ALL(),
    user => SHOW_USER(),
    attending => SHOW_ATTENDING(),
    none => SHOW_NONE(),
    planner => SHOW_PLANNER(),
} }

sub EVENT_SHOW_COMPONENT_NAMES { return ( qw/
    show_yes
    show_no
    show_maybe
    show_waiting
    show_pages
    show_posts
    show_media
    show_tweets
    show_stream
    show_feedback
    show_map
    show_chat
    show_freeform
    show_counter
    show_imedia
    show_planners
    show_promo
    show_extras
    show_title
/ ); }

sub _event_show_url {
    my ( $self, $event, $params ) = @_;

    return Dicole::URL->from_parts(
        action => 'events', task => 'show', target => $event->group_id, domain_id => $event->domain_id,
        additional => [ $event->id, $self->_event_vanity_url_piece( $event ) ], params => $params,
    );    
}

sub _event_vanity_url_piece {
    my ( $self, $event ) = @_;

    return substr( Dicole::Utils::Text->utf8_to_url_readable( $event->title ), 0, 50 );
}

sub _generic_events {
    my ( $self, %p ) = @_;

    my $where = 'dicole_events_event.group_id = ?';
    $where .= ' AND ' . $p{where} if $p{where};
    my $value = [ $p{group_id}, $p{value} ? @{$p{value}} : () ];

    my $tags = ( $p{tags} && ref( $p{tags} ) eq 'ARRAY' ) ? $p{tags} : [];
    push @$tags, $p{tag} if $p{tag};

    my $entries = scalar( @$tags ) ?
        eval { CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group', {
            object_class => CTX->lookup_object('events_event'),
            tags => $tags,
            where => $where,
            value => $value,
            order => $p{order},
            limit => $p{limit},
            ( $p{from} ? ( from => $p{from} ) : () ),
        } ) } || []
        :
        CTX->lookup_object('events_event')->fetch_group( {
            where => $where,
            value => $value,
            order => $p{order},
            limit => $p{limit},
            ( $p{from} ? ( from => $p{from} ) : () ),
        } ) || [];

    return $entries;
}

sub _remove_event {
    my ( $self, $event, $domain_id, $user_id ) = @_;

    CTX->lookup_action('tags_api')->e( purge_tags => {
        object => $event,
        group_id => $event->group_id,
        user_id => 0,
        domain_id => $domain_id,
    } );

    $_->remove for @{ $self->_event_users_link_list( $event ) };
    $_->remove for @{ $self->_event_invites( $event ) };

    $event->remove;
}

sub _visualize_event_list {
    my ( $self, $events, $paritial ) = @_;

    my @visuals = map { $self->_visualize_event( $_ ) } @$events;
    my $time = time;
    
    # guess that there are more if $self->OBJECTS_ON_PAGE was rendered ;)
    if ( scalar( @$events ) >= $self->OBJECTS_ON_PAGE ) {
        my $button_container = Dicole::Widget::Container->new(
            class => 'events_more_container events_more_button_id_' . $time . '_container',
            id => 'events_more_container_' . $time,
            contents => [
                Dicole::Widget::Hyperlink->new(
                    content => Dicole::Widget::Raw->new( raw => '<span>&darr; ' . $self->_msg( 'More events' ) . '</span>' ),
                    class => 'yellow-button events_more_button events_more_button_id_' . $time,
                    id => 'events_more_button_' . $time,
                    link => $self->derive_url(
                        action => 'events_json',
                    ),
                    disable_click => 1,
                ),
            ],
        );
        push @visuals, $button_container;
    }
    elsif ( $self->task eq 'upcoming' ) {
        my $button_container = Dicole::Widget::Container->new(
            class => 'past_events_link_container',
            contents => [
                Dicole::Widget::Hyperlink->new(
                    content => Dicole::Widget::Raw->new( raw => '<span>&rarr; ' . $self->_msg( 'Show past events' ) . '</span>' ),
                    class => 'button past_events_link_button',
                    link => $self->derive_url(
                        action => 'events', task => 'past',
                    ),
                ),
            ],
        );
        push @visuals, $button_container;
    }
    
    my $list = Dicole::Widget::Vertical->new(
        contents => \@visuals,
        class => $paritial ? undef : 'events_event_listing',
        id => $paritial ? undef : 'events_event_listing_' . $time,
    );

    return $list;
}

sub _visualize_event {
    my ( $self, $event, $params ) = @_;

    $event = $self->_ensure_event_object( $event );

    $params ||= {};

    $params->{$_} = $event->get($_) for qw(
        title
        abstract
        sos_med_tag
        location_name
    );

    $params->{title} = $self->_msg('~[no name~]') unless $params->{title};

#    $params->{image_url} = CTX->lookup_action('thumbnails_api')->e( create => {
#        url => $event->image, width => 50, height => 50,
#    } );
    $params->{logo_url} = $event->logo_attachment ? $self->_event_logo_url( $event ) : '';

    $params->{date} = $self->_event_date( $event );
    $params->{ongoing} = $self->_event_is_ongoing( $event );

    $params->{tags} ||= $self->_event_tags( $event );
    $params->{linked_tags} = [ map {
        { name => $_, url => $self->derive_url( task => 'upcoming', additional => [ $_ ] ) }
    } @{ $params->{tags} } ];

    $params->{show_url} = $self->_event_show_url( $event );

    my $event_user_object = $self->_get_event_user_object( $event, CTX->request->auth_user_id );

    $params->{rsvp} = $event_user_object ? $self->RSVP_NAMES->{ $event_user_object->rsvp_state } || '' :'';

    $params->{private_event} = ( $event->event_state == $self->STATE_PRIVATE ) ? 1 : 0;
    $params->{invite_only} = $event->require_invite ? 1 : 0;

    $params->{'dump'} = Data::Dumper::Dumper( $params );
    return Dicole::Widget::Container->new(
        id => 'events_entry_container_' . $event->id,
        class => 'events_entry_container',
        contents => [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_events::component_listed_event' } )
        ) ],
    );
}

sub _add_event_planner {
    my ( $self, $event, $user, $by_user, $invited ) = @_;

    my $eu = $self->_get_event_user_object( $event, $user );
    $eu = $self->_add_event_user( $event, $user, $by_user, $invited ) unless $eu;
    $eu->is_planner( 1 );
    $eu->save;
    return $eu;
}

sub _add_event_user {
    my ( $self, $event, $user, $by_user, $invited ) = @_;

    my $eu = $self->_get_event_user_object( $event, $user );

    if ( $eu ) {
        if ( $invited && ! $eu->was_invited ) {
            $eu->by_user( $by_user || eval{ CTX->request->auth_user_id } || 0 );
            $eu->was_invited( 1 );
            $eu->save;
        }

        return $eu;
    }

    $eu = CTX->lookup_object('events_user')->new();
    $eu->event_id( $self->_ensure_event_id( $event ) );
    $eu->user_id( Dicole::Utils::User->ensure_id( $user ) );
    $eu->is_planner( 0 );

    my $eo = $self->_ensure_event_object( $event );
    $eu->domain_id( $eo->domain_id );
    $eu->group_id( $eo->group_id );

    $eu->rsvp_state( $self->RSVP_WAITING() );
    $eu->was_invited( $invited ? 1 : 0 );
    $eu->is_planner( 0 );

    $eu->creator_id( $by_user || eval{ CTX->request->auth_user_id } || 0 );
    $eu->created_date( time() );
    $eu->removed_date( 0 );
    $eu->attend_date( 0 );
    $eu->attend_info( '' );

    $eu->save;

    return $eu;
}

sub _remove_event_user {
    my ( $self, $event, $user ) = @_;

    my $eu;
    while ( $eu = $self->_get_event_user_object( $event, $user ) ) {
        $eu->removed_date(time);
        $eu->save;
    }

    return 1;
}

sub _get_event_user_object {
    my ( $self, $event, $user ) = @_;

    return undef unless $user;

    return shift @{ CTX->lookup_object('events_user')->fetch_group({
        where => 'removed_date = 0 AND user_id = ? AND event_id = ?',
        value => [ Dicole::Utils::User->ensure_id( $user ), $self->_ensure_event_id( $event ) ],
    } ) || [] };
}

sub _get_event_user_objects {
    my ( $self, $event, $user_ids ) = @_;

    $user_ids ||= [];

    return CTX->lookup_object('events_user')->fetch_group({
        where => 'removed_date = 0 AND event_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => $user_ids ),
        value => [ $self->_ensure_event_id( $event ) ],
    } ) || [];
}

sub _set_event_user_rsvp {
    my ( $self, $event, $user, $rsvp, $info ) = @_;

    my $o = $self->_get_event_user_object( $event, $user );
    if ( ! $o ) {
        $o = $self->_add_event_user( $event, $user );
    }
    $o->rsvp_state( $rsvp );
    $o->attend_info( $info ) if defined $info;
    $o->save;

    $self->_update_num_attenders( $event );
}

sub _update_num_attenders {
    my ( $self, $event ) = @_;

    $event = $self->_ensure_event_object( $event );

    my $os = $self->_event_users_link_list( $event );
    my $count = 0;
    for my $o ( @$os ) {
        $count++ if $o->rsvp_state == $self->RSVP_YES;
    }

    $event->num_attenders( $count );
    $event->save;
}

sub _user_events_id_list {
    my ( $self, $user_id, $group_id ) = @_;

    my $event_users = CTX->lookup_object('events_user')->fetch_group( {
        where => 'removed_date = 0 AND user_id = ?' . ( $group_id ? ' AND group_id = ?' : ''),
        value => [ $user_id, ( $group_id ? ( $group_id ) : () ) ],
    } );

    return [ map { $_->event_id } @$event_users ];
}

sub _event_users_id_list {
    my ( $self, $event ) = @_;

    my $eus = $self->_event_users_link_list( $event );

    return [ map { $_->user_id } @$eus ];
}

sub _event_planners_link_list {
    my ( $self, $event ) = @_;

    my $eus = $self->_event_users_link_list( $event );

    return [ map { $_->is_planner ? ( $_ ) : () } @$eus ];
}

sub _event_planners_map_by_id {
    my ( $self, $event ) = @_;

    my $eus = $self->_event_planners_link_list( $event );

    return { map { $_->user_id => $_ } @$eus };

}

sub _event_users_link_list {
    my ( $self, $event ) = @_;

    my $eus = CTX->lookup_object('events_user')->fetch_group( {
        from => [ 'dicole_group_user' ],
        where => 'dicole_events_user.removed_date = 0 AND event_id = ? AND dicole_group_user.user_id = dicole_events_user.user_id AND dicole_group_user.groups_id = ?',
        value => [ $self->_ensure_event_id( $event ), $event->group_id ],
    } );

    return $eus;
}

sub _event_invites {
    my ( $self, $event ) = @_;

    my $eis = CTX->lookup_object('events_invite')->fetch_group( {
        where => 'event_id = ?',
        value => [ $self->_ensure_event_id( $event ) ],
    } );

    return $eis;
}

sub _event_open_invites {
    my ( $self, $event ) = @_;

    my $eis = CTX->lookup_object('events_invite')->fetch_group( {
        where => 'event_id = ? AND disabled_date = ?',
        value => [ $self->_ensure_event_id( $event ), 0 ],
    } );

    return $eis;
}

sub _event_is_ongoing {
    my ( $self, $event, $now ) = @_;

    $now ||= time();

    my $e = $self->_ensure_event_object( $event );
    return ( $e->end_date && $e->end_date > $now && $e->begin_date < $now ) ? 1 : 0;
}

sub _event_has_seats_left {
    my ( $self, $event ) = @_;

    return ( ! $event->max_attenders || $event->max_attenders > $event->num_attenders ) ? 1 : 0;
}

sub _event_registration_is_open {
    my ( $self, $event ) = @_;
    
    return 0 if ! $self->_event_registration_has_started( $event );
    return 0 if $self->_event_registration_has_closed( $event );
    return 1;
}

sub _event_registration_has_started {
    my ( $self, $event ) = @_;
    
    return 1 if ! $event->reg_begin_date || time > $event->reg_begin_date;
    return 0;
}

sub _event_registration_has_closed {
    my ( $self, $event ) = @_;
    
    return 1 if $event->reg_end_date && time > $event->reg_end_date;
    return 0;
}

sub _any_user_can_attend_event {
    my ( $self, $event ) = @_;

    return 0 if $event->require_invite;
    return 0 unless $event->event_state == $self->STATE_PUBLIC;
    return 0 unless $self->_event_registration_is_open( $event );
    return 0 unless $self->_event_has_seats_left( $event );

    return 1;
}

sub _current_user_can_attend_event  {
    my ( $self, $event, $euo ) = @_;

    return 0 unless $self->_event_registration_is_open( $event );
    return 0 unless $self->_event_has_seats_left( $event );
    return 1 if $event->event_state == $self->STATE_PUBLIC && ! $event->require_invite;
    return 1 if $self->_user_was_invited_to_event( CTX->request->auth_user_id, $event, $euo );
    return 1 if $self->_user_is_attending_event( CTX->request->auth_user_id, $event, $euo );
    return 0;
}

sub _current_user_can_manage_event {
    my ( $self, $event ) = @_;

    return 0 unless CTX->request && CTX->request->auth_user_id;
    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 1 if $self->_user_is_event_planner( CTX->request->auth_user_id, $event );
    return 0;
}

sub _current_user_can_delete_event {
    my ( $self, $event ) = @_;

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 1 if CTX->request && CTX->request->auth_user_id == $event->creator_id;
    return 0;
}

sub _current_user_can_rsvp_event {
    my ( $self, $event, $euo ) = @_;

    return 0 unless eval{ CTX->request->auth_user_id };

    return 1 if $self->_user_is_event_user( CTX->request->auth_user_id, $event, $euo );
    return 1 if $event->event_state == $self->STATE_PUBLIC && ! $event->require_invite;
    return 1 if $self->_user_was_invited_to_event( CTX->request->auth_user_id, $event, $euo );
    return 1 if $self->_user_is_attending_event( CTX->request->auth_user_id, $event, $euo );

    return 0;
}

sub _current_user_can_toggle_event_planner_status_for_user {
    my ( $self, $event, $user, $current_user_euo, $user_euo ) = @_;

    return 0 unless eval{ CTX->request->auth_user_id };

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 1 if $self->_current_user_is_event_creator( $event );

    return 0 if $self->_user_is_event_creator( $user, $event );
    return 0 if eval { Dicole::Utils::User->ensure_id( $user ) } == CTX->request->auth_user_id;
    return 1 if $self->_current_user_is_event_planner( $event, $current_user_euo );
    return 0;
}

sub _current_user_can_invite_to_event {
    my ( $self, $event ) = @_;

    return 0 if $self->_event_registration_has_closed( $event );

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 0 unless CTX->request->auth_user_id;

    my $eo = $self->_ensure_event_object( $event );
    my $policy = $eo->invite_policy;

    return 1 if $policy == $self->INVITE_ANYONE;

    my $ueo = $self->_get_event_user_object( $eo, CTX->request->auth_user_id );

    return 0 unless $ueo;
    return 1 if $policy == $self->INVITE_USERS;

    return $ueo->is_planner ? 1 : 0;
}

sub _current_user_can_invite_planners_to_event {
    my ( $self, $event ) = @_;

    return 0 unless $self->_current_user_can_invite_to_event( $event );

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 1 if $self->_current_user_is_event_creator( $event );
    my $eo = $self->_ensure_event_object( $event );
    my $ueo = $self->_get_event_user_object( $eo, CTX->request->auth_user_id );
    return ( $ueo && $ueo->is_planner ) ? 1 : 0;
}

sub _current_user_can_see_event {
    my ( $self, $event, $invite ) = @_;

    $invite ||= $self->_fetch_invite( $event );
    return 1 if $invite && ! $invite->disabled_date;

    return 0 unless $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'view', $event->group_id );
    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin', $event->group_id );
    return 1 if $self->_user_is_event_user( CTX->request->auth_user_id, $event );
    return 1 if $event->event_state == $self->STATE_PUBLIC;
    return 0;
}

sub _current_user_can_see_component {
    my ( $self, $event, $component, $event_user_object ) = @_;

    $event = $self->_ensure_event_object( $event );

    return $self->_current_user_show_visibility( $event, $event->get( $component ), $event_user_object );
}

sub _current_user_show_visibility {
    my ( $self, $event, $show_value, $euo ) = @_;

    return 1 if $show_value == $self->SHOW_ALL;
    return 0 if $show_value == $self->SHOW_NONE;

    my $uid = CTX->request->auth_user_id;
    return 0 unless $uid;

    $euo = $self->_get_event_user_object( $event, $uid ) unless defined( $euo );

    return 0 unless $euo;
    return 1 if $show_value == $self->SHOW_USER;
    return 1 if $show_value == $self->SHOW_ATTENDING && $euo->rsvp_state == $self->RSVP_ATTENDING;
    return 1 if $show_value == $self->SHOW_PLANNER && $euo->is_planner;
    return 0;
}

sub _current_user_can_remove_comments_by_others {
    my ( $self, $event, $euo ) = @_;

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin');
    return 1 if $self->_user_is_event_planner( CTX->request->auth_user_id, $event, $euo );
    return 0;
}

sub _current_user_is_event_creator {
    my ( $self, $event ) = @_;

    return $self->_user_is_event_creator( eval { CTX->request->auth_user_id }, $event );
}

sub _current_user_is_event_planner {
    my ( $self, $event, $euo ) = @_;

    return $self->_user_is_event_planner( eval { CTX->request->auth_user_id }, $event, $euo );
}

sub _current_user_visible_events_where {
    my ( $self, $group_id ) = @_;

    $group_id =~ s/[^\d]//g;

    return '( dicole_events_event.group_id = ' . $group_id . ' )' if $self->mchk_y( 'OpenInteract2::Action::DicoleEvents', 'admin', $group_id );
    return $self->_user_events_where( CTX->request->auth_user_id, $group_id );
}

sub _user_events_where {
    my ( $self, $user_id, $group_id ) = @_;

    return $user_id ? Dicole::Utils::SQL->column_in(
        'dicole_events_event.event_id' => $self->_user_events_id_list( $user_id, $group_id )
    ) : '( 1 = 0 )';
}

sub _user_is_event_creator {
    my ( $self, $user, $event ) = @_;
    my $uid = eval { Dicole::Utils::User->ensure_id( $user ) };
    return 0 unless $uid;

    my $eo = $self->_ensure_event_object( $event );
    return $eo->creator_id == $uid ? 1 : 0;
}

sub _user_is_event_planner {
    my ( $self, $user, $event, $euo ) = @_;

    return 0 unless $user;
    $euo ||= $self->_get_event_user_object( $event, $user );
    return ( $euo && $euo->is_planner) ? 1 : 0;
}

sub _user_is_event_user {
    my ( $self, $user, $event, $euo ) = @_;

    return ( $euo || $self->_get_event_user_object( $event, $user ) ) ? 1 : 0;
}

sub _user_was_invited_to_event {
    my ( $self, $user, $event, $euo ) = @_;

    $euo ||= $self->_get_event_user_object( $event, $user );
    return 0 unless $euo;
    return 1 if $euo->was_invited || $euo->is_planner;
    return 0;
}

sub _user_is_attending_event {
    my ( $self, $user, $event, $euo ) = @_;

    $euo ||= $self->_get_event_user_object( $event, $user );
    return 1 if $euo && $euo->rsvp_state == $self->RSVP_YES;
    return 0;
}

sub _prepare_sos_med_tag {
    my ( $self, $tag ) = @_;

    $tag = Text::Unidecode::unidecode( Dicole::Utils::Text->ensure_internal( $tag ) );
    $tag = lc( $tag );
    $tag =~ s/[^\w]//g;
    $tag =~ s/^(.{15}).*$/$1/;

    return Dicole::Utils::Text->ensure_utf8( $tag );
}

sub _event_date {
    my ( $self, $event ) = @_;

    return Dicole::Utils::Text->ensure_utf8( $self->_event_date_internal( $event ) );
}

sub _event_date_internal {
    my ( $self, $event ) = @_;

    return $self->_msg('No date specified') if ! $event->begin_date;

    my $bdt = Dicole::Utils::Date->epoch_to_datetime( $event->begin_date );

    if ( ! $event->end_date ) {
        return $bdt->day . '. ' . $bdt->month_name . ' ' . $bdt->year;
    }
    else {
        my $edt = Dicole::Utils::Date->epoch_to_datetime( $event->end_date );
        if ( $bdt->year != $edt->year ) {
            return $bdt->day . '. ' . $bdt->month_abbr . ' ' . $bdt->year . ' - ' .
                $edt->day . '. ' . $edt->month_abbr . ' ' . $edt->year;
        }
        if ( $bdt->month != $edt->month ) {
            return $bdt->day . '. ' . $bdt->month_abbr . ' - ' .
                $edt->day . '. ' . $edt->month_abbr . ' ' . $edt->year;
        }
        if ( $bdt->day != $edt->day ) {
            return $bdt->day . '. - ' . $edt->day . '. ' . $edt->month_name . ' ' . $edt->year;
        }
        return $bdt->day . '. ' . $bdt->month_name . '  ' . $bdt->year . ', ' .
            join( '-', map( { $self->_epoch_to_time_string( $_ ) } ( $event->begin_date, $event->end_date ) ) );
    }
}

sub _registration_date {
    my ( $self, $epoch ) = @_;

    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch );

    my $daysuffix = '. ';
    if ( $dt->locale =~ /en/ ) {
        my @suffixes = ('st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th', 'th', 'th', 'th', 'th' );
        my $num = $dt->day % 100;
        $daysuffix = $suffixes[ $num ] || 'th';
        $daysuffix .= ' of ';
    }

    return Dicole::Utils::Text->ensure_utf8( $dt->day . $daysuffix .' ' . $dt->month_name . ' ' . $dt->year );
}

sub _epoch_to_date_string {
    my ( $self, $epoch ) = @_;
    return '' unless $epoch;
    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch );
    return Dicole::Utils::Text->ensure_utf8( join( "/", ( sprintf("%02d",$dt->day), sprintf("%02d",$dt->month), $dt->year ) ) );
}

sub _epoch_to_time_string {
    my ( $self, $epoch ) = @_;
    return '' unless $epoch;
    my $dt = Dicole::Utils::Date->epoch_to_datetime( $epoch );
    return Dicole::Utils::Text->ensure_utf8( join( ":", (  sprintf("%02d",$dt->hour),  sprintf("%02d",$dt->minute) ) ) );
}

sub _date_time_strings_to_epoch {
    my ( $self, $date_string, $time_string ) = @_;

    my $dt = Dicole::Utils::Date->epoch_to_datetime();

    my ( $dd, $mm, $yyyy ) = $date_string =~ /^\s*(\d+)\s*[\.\/]\s*(\d+)\s*[\.\/]\s*(\d+)\s*$/;
    my ( $hour, $min ) = $time_string =~ /^\s*(\d+)\s*\:\s*(\d+)\s*$/;
    if ( ! defined( $hour ) ) {
        $hour = 12;
        $min = 0;
    }

    $dt->set( day => $dd, month => $mm, year => $yyyy, hour => $hour, minute => $min, second => 0 );

    return $dt->epoch;
}

sub _filter_page_name_tag {
    my ( $self, $event, $name ) = @_;

    return $name unless $event->sos_med_tag;
    my $stag = $event->sos_med_tag;
    my ( $title ) = $name =~ /^(.*?)(?: \(\#$stag\))?$/;
    return $title;
}

sub _event_tags {
    my ( $self, $event ) = @_;

    $event = $self->_ensure_event_object( $event );

    return CTX->lookup_action('tags_api')->e( get_tags => {
        object => $event, user_id => 0, group_id => $event->group_id, domain_id => $event->domain_id
    } );
}

sub _event_logo_url { return shift->_event_attachment_image_url( pop, 'logo' ); }

sub _event_small_logo_url { return shift->_event_attachment_image_url( pop, 'small_logo' ); }

sub _event_banner_url { return shift->_event_attachment_image_url( pop, 'image' ); }

sub _event_banner_wide_url { return shift->_event_attachment_image_url( pop, 'image_wide' ); }


sub _event_attachment_image_url {
    my ( $self, $event, $type ) = @_;

    return Dicole::URL->from_parts(
        action => 'events',
        task => $type,
        target => $event->group_id,
        additional => [ $event->id, $type . '.jpg' ],
    );
}

sub _user_can_be_invited_to_event {
    my ( $self, $user, $event ) = @_;
    $event = $self->_ensure_event_object( $event );
    return Dicole::Utils::User->belongs_to_group( $user, $event->group_id ) ? 1 : 0 
}

sub _fetch_invite {
    my ( $self, $event, $invite_code ) = @_;

    $invite_code ||= CTX->request->param('invite_code');
    $invite_code =~ s/^(.{20}).*$/$1/;

    return undef unless $invite_code;

    my $invites = CTX->lookup_object( 'events_invite' )->fetch_group( {
        where => 'secret_code = ? AND disabled_date = ?',
        value => [ $invite_code, 0 ],
    } ) || [];

    my $invite = shift @$invites;

    return undef unless $invite;

    if ( $event ) {
        my $event_id = $self->_ensure_event_id( $event );
        return undef unless $invite->event_id == $event_id;
    }

    return $invite;
}

sub _create_invite {
    my ( $self, $event, $email_original, $email_greeting, $planner ) = @_;

    my $email = Dicole::Utils::Mail->string_to_address( $email_original );
    die unless $email;

    $event ||= $self->ensure_event_object( $event );
    my $random_key = SPOPS::Utility->generate_random_code( 20, 'mixed' );

    my $invite = CTX->lookup_object( 'events_invite' )->new;
    $invite->secret_code( $random_key );
    $invite->domain_id( $event->domain_id );
    $invite->group_id( $event->group_id );
    $invite->event_id( $event->id );
    $invite->creator_id( eval{ CTX->request->auth_user_id } || 0 );
    $invite->user_id( 0 );
    $invite->email( $email );
    $invite->email_original( $email_original );
    $invite->email_greeting( $email_greeting );
    $invite->invite_date( time() );
    $invite->consumed_date( 0 );
    $invite->disabled_date( 0 );
    $invite->planner( $planner ? 1 : 0 );
    $invite->save;
}

sub _send_invite_notification_to_user {
    my ( $self, $event, $user, $greeting, $greeting_subject, $as_planner, $inviter_id ) = @_;

    $event = $self->_ensure_event_object( $event );
    $user = Dicole::Utils::User->ensure_object( $user );
    my $sender_user = eval{ Dicole::Utils::User->ensure_object( $inviter_id ) };

    my $params = {
        $self->_common_event_invite_mail_params( $event ),
        sender_name => Dicole::Utils::User->name( $sender_user ),
        greeting_text => $greeting,
        greeting_html => Dicole::Utils::HTML->text_to_html( $greeting ),
        planner => $as_planner,
        url => Dicole::URL->get_server_url . $self->_event_show_url( $event, {
            dic => Dicole::Utils::User->authorization_key(
                create_session => 1,
                valid_hours => 24,
                user => $user,
            )
        } )
    };

    Dicole::Utils::Mail->send_localized_template_mail(
        user => $user,
#        lang => $user->lang,
        template_key_base => 'events_invite_notification_to_user_mail',
        template_params => $params,
        override_subject => $greeting_subject,
    );
}

sub _send_invite {
    my ( $self, $invite, $event, $greeting_subject ) = @_;

    $event = $self->_ensure_event_object( $event || $invite->event_id );
    my $user = eval{ Dicole::Utils::User->ensure_object( $invite->creator_id ) };

    my $params = {
        $self->_common_event_invite_mail_params( $event ),
        sender_name => Dicole::Utils::User->name( $user ),
        greeting_text => $invite->email_greeting,
        greeting_html => Dicole::Utils::HTML->text_to_html( $invite->email_greeting ),
        planner => $invite->planner,
        url => Dicole::URL->get_server_url . $self->_event_show_url( $event, { invite_code => $invite->secret_code } ),
    };

    Dicole::Utils::Mail->send_localized_template_mail(
        to => $invite->email_original,

        template_key_base => 'events_invite_mail',
        template_params => $params,

        override_subject => $greeting_subject,
    );
}

sub _common_event_invite_mail_params {
    my ( $self, $event ) = @_;

    return (
        title => $event->title,
        abstract_text => $event->abstract,
        abstract_html => Dicole::Utils::HTML->text_to_html( $event->abstract ),
        description_text => Dicole::Utils::HTML->html_to_text( $event->description ),
        description_html => $event->description,
        date_string => $self->_event_date( $event ),
        location => $event->location_name,
    );
}

sub _consume_invite {
    my ( $self, $invite, $user ) = @_;
    
    $invite->user_id( Dicole::Utils::User->ensure_id( $user ) );
    $invite->consumed_date( time() );
    $invite->disabled_date( time() );
    $invite->save;
    
    $self->_add_event_user( $invite->event_id, $user, $invite->creator_id, 1 );
    $self->_add_event_planner( $invite->event_id, $user ) if $invite->planner;
}

sub _fetch_valid_event_user_objects_using_request {
    my ( $self, $event ) = @_;

    $event ||= $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    my @uids = split /\s*[,_]\s*/, CTX->request->param( 'target_users' ) || $self->param('user_id_list');

    return $self->_get_event_user_objects( $event, \@uids );
}

sub _fetch_valid_event_user_infos_using_request {
    my ( $self, $event ) = @_;

    return $self->_gather_info_for_event_users( $self->_fetch_valid_event_user_objects_using_request( $event ) );
}

sub _prepare_comment_info_list {
    my ( $self, $event, $list ) = @_;

    my $remove_others = $self->_current_user_can_remove_comments_by_others( $event );
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    for my $info ( @$list ) {
        $info->{id} = $info->{post_id};
        $info->{user_image} = $info->{user_avatar};
        $info->{delete_url} = ( $remove_others || ( $info->{user_id} && CTX->request->auth_user_id == $info->{user_id} ) ) ?
            $self->derive_url(
                action => 'events_json', task => 'delete_comment', additional => [ $event->id, $info->{post_id} ]
            ) : '';
        $info->{user_organization} = CTX->lookup_action('networking_api')->e( user_profile_attribute => {
            user_id => $info->{user_id},
            domain_id => $domain_id,
            name => 'contact_organization',
        } );
        $info->{date} = Dicole::Utils::Date->localized_datetimestamp(epoch => $info->{date_epoch});
        $info->{user_is_planner} = $self->_user_is_event_planner( $info->{user_id}, $event ) ? 1 : 0;
    }

    return $list;
}

sub _process_comment_template {
    my ( $self, $info ) = @_;

    return $self->generate_content( { comment => $info }, { name => 'dicole_events::component_comment' } );
}

sub _gather_event_params {
    my ( $self, $event, $submitted ) = @_;

    if ( ! $event ) {
        return $self->_gather_default_event_params( $submitted );
    }

    my $params = {};

    for my $attr ( qw(
        event_id
        title
        abstract
        stream
        feedback
        freeform_title
        freeform_content
        num_attenders
        max_attenders
        sos_med_tag
        attend_info
        require_phone
        require_invite
        location_name
        latitude
        longitude
        event_state
        invite_policy
    ) ) {
        $params->{ $attr } = $event->get( $attr );
    }

    $params->{description} = Dicole::Utils::HTML->strip_scripts( $event->get( 'description' ) );
    $params->{date} = $self->_event_date( $event );
    $params->{registration_is_open} = $self->_event_registration_is_open( $event );
    $params->{registration_has_started} = $self->_event_registration_has_started( $event );
    $params->{registration_has_closed} = $self->_event_registration_has_closed( $event );
    $params->{registration_start_date} = $event->reg_begin ? $self->_registration_date( $event->reg_begin ) : '';
    $params->{registration_close_date} = $event->reg_end ? $self->_registration_date( $event->reg_end ) : '';
    $params->{has_seats_left} = $self->_event_has_seats_left( $event ) ? 1 : 0;

    for my $battr ( qw/ begin end reg_begin reg_end / ) {
        $params->{ $battr . '_date' } = $self->_epoch_to_date_string( $event->get( $battr . '_date' ) );
        $params->{ $battr . '_time' } = $self->_epoch_to_time_string( $event->get( $battr . '_date' ) );
    }

    $params->{event_state_name} = $self->STATE_NAMES->{ $event->event_state };
    $params->{invite_policy_name} = $self->INVITE_NAMES->{ $event->invite_policy };

    $params->{users_can_invite} = ( $event->invite_policy == $self->INVITE_ANYONE ) ? 1 : 0;

    $params->{ongoing} = $self->_event_is_ongoing( $event );
    $params->{invite_url} = $self->_current_user_can_invite_to_event( $event ) ?
        $self->derive_url( task => 'invite' ) : '';

    # TODO: pass these through web thumbnailer? ;)
    $params->{logo_url} = $event->logo_attachment ? $self->_event_logo_url( $event ) : '';
    $params->{banner_url} = $event->banner_attachment ? $self->_event_banner_url( $event ) : '';
    $params->{banner_wide_url} = $event->banner_attachment ? $self->_event_banner_wide_url( $event ) : '';

    $params->{tags} = $self->_event_tags( $event );
    $params->{tags_json} = Dicole::Utils::JSON->encode( $params->{tags} );
    $params->{linked_tags} = [ map {
        { name => $_, url => $self->derive_url( task => 'upcoming', additional => [ $_ ] ) }
    } @{ $self->_event_tags( $event ) } ];

    $params->{user_can_manage_event} = $self->_current_user_can_manage_event( $event ) ? 1 : 0;
    $params->{manage_url} = $self->_current_user_can_manage_event( $event ) ?
        $self->derive_url( task => 'edit' ) : '';
    $params->{participants_url} = $self->_current_user_can_manage_event( $event ) ?
        $self->derive_url( action => 'events_json', task => 'rsvp' ) : '';
    $params->{mail_users_url} = $self->_current_user_can_manage_event( $event ) ?
        $self->derive_url( task => 'mail_users' ) : '';
    $params->{export_users_url} = $self->_current_user_can_manage_event( $event ) ?
        $self->derive_url( action => 'events_raw', task => 'export_users' ) : '';
    $params->{delete_url} = $self->_current_user_can_delete_event( $event ) ?
        $self->derive_url( task => 'delete' ) : '';
    $params->{clone_url} = $self->_current_user_can_manage_event( $event ) ?
        $self->derive_url( task => 'copy' ) : '';
    $params->{live_url} = ( 0 && CTX->request->auth_user_id && $event->sos_med_tag ) ?
        $self->derive_url( action => 'cafe', task => 'display', additional => [], params => {
            show_wiki => $event->show_wiki, show_blogs => $event->show_posts,
            show_media => $event->show_media, show_twitter => $event->show_twitter,
            custom_title => $event->title, tag => $event->sos_med_tag,
        } ) : '';

    $params->{rsvp_url} = $self->derive_url( task => 'rsvp' );

    $params->{listing_url} = $self->derive_url( task => 'upcoming', additional => [] );
    $params->{show_url} = $self->_event_show_url( $event );
    $params->{send_url} = $event->event_state == $self->STATE_PUBLIC ?
        Dicole::URL->get_server_url . $self->_event_show_url( $event ) : '';

    my $event_user_object = $self->_get_event_user_object( $event, CTX->request->auth_user_id );

    $params->{user_can_attend} = $self->_current_user_can_attend_event( $event, $event_user_object );
    $params->{user_can_rsvp} = $self->_current_user_can_rsvp_event( $event, $event_user_object );
    $params->{invite_planners} = 1 if $self->chk_y('admin');

    if ( $event_user_object ) {
        $params->{rsvp} = $self->RSVP_NAMES->{ $event_user_object->rsvp_state } || $self->RSVP_NAMES->{ $self->RSVP_WAITING };
        $params->{invite_planners} ||= $event_user_object->is_planner ? 1 : 0;
    }

    $params->{invite_planners} ||=  1 if $self->chk_y('admin');

    for ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
        $params->{ $_ } = $self->_current_user_can_see_component( $event, $_, $event_user_object );
        $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $event->get( $_ ) } || $self->SHOW_NAMES->{ $self->SHOW_NONE };
    }

    if ( $event->sos_med_tag ) {
        $params->{pages} = $self->_gather_pages_data( $event );
        $params->{new_page_url} = $self->mchk_y('OpenInteract2::Action::DicoleWiki', 'create') ? $self->derive_url(
            action => 'wiki', task => 'create',
            params => { prefilled_tags => $event->sos_med_tag, suffix_tag => $event->sos_med_tag },
        ) : '';

        my $posts = $self->_gather_posts_data( $event );
        $params->{posts} = [ shift @$posts || (), shift @$posts || (), shift @$posts || () ];
        $params->{new_post_url} = $self->mchk_y('OpenInteract2::Action::DicoleBlogs', 'write') ? $self->derive_url(
            action => 'blogs', task => 'post_to_seed', additional => [ 0, CTX->request->auth_user_id ],
            params => { prefilled_tags => $event->sos_med_tag },
        ) : '';
        $params->{more_posts_url} = ( @$posts ) ? $self->derive_url(
            action => 'blogs', task => 'new', additional => [ 0, $event->sos_med_tag ]
        ) : '';

        if ( $self->mchk_y('OpenInteract2::Action::DicolePresentations', 'view') ) {
            my $media = $self->_gather_media_data( $event, $event->show_imedia == $self->SHOW_ALL ? 50 : 10 );
            $params->{media} = $event->show_imedia == $self->SHOW_ALL ? [ reverse @$media ] : $media;
            $params->{new_media_url} = $self->mchk_y('OpenInteract2::Action::DicolePresentations', 'add') ? $self->derive_url(
                action => 'presentations', task => 'add',
                params => {
                    prefilled_tags => $event->sos_med_tag,
                    url_after_creation => $self->derive_url,
                },
            ) : '';
            $params->{more_media_url} = $self->derive_url(
                action => 'presentations', task => 'new', additional => [ 'any', $event->sos_med_tag ]
            );
        }
        else {
            $params->{show_media} = 0;
        }
    }

    $params->{gmaps_api_key} = $self->_resolve_gmaps_api_key;

    return $params;
}

sub _gather_posts_data {
    my ( $self, $event ) = @_;

    my $blog_data = CTX->lookup_action('blogs_api')->e( recent_entry_data_with_tags => {
        domain_id => $event->domain_id, group_id => $event->group_id, tags => [ $event->sos_med_tag ], limit => 4,
    } );

    my $posts = [];
    for my $data ( @$blog_data ) {
        my $info = {
            title => $data->{post}->title,
            url => $data->{show_url},
            author_name => $data->{author_name},
            short_author_name => $data->{short_author_name},
            author_url => CTX->lookup_action('networking_api')->e( user_profile_url => {
                group_id => $event->group_id, user_id => $data->{user}->id, domain_id => $event->domain_id,
            } ),
            author_image => CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
                user_id => $data->{user}->id, domain_id => $event->domain_id, no_default => 1, size => 50,
            } ),
            time_ago => Dicole::Utils::Date->localized_ago( action => $self, epoch => $data->{post}->date ),
        };
        push @$posts, $info;
    }

    return $posts;
}

sub _gather_pages_data {
    my ( $self, $event ) = @_;

    my $wiki_data = CTX->lookup_action('wiki_api')->e( recent_page_data_with_tags => {
        domain_id => $event->domain_id, group_id => $event->group_id, tags => [ $event->sos_med_tag ],
    } );

    my $pages = [];
    for my $data ( @$wiki_data ) {
        my $title = $self->_filter_page_name_tag( $event, $data->{readable_title} );
        my $url = Dicole::URL->from_parts( domain_id => $event->domain_id, action => 'events', task => 'show_page', target => $event->group_id, additional => [ $event->id, $data->{title} ] );

        my $user_id = $data->{page}->{creator_id};

        my $info = {
            page_id => $data->{page}->id,
            object_type => ref( $data->{page} ),
            created_epoch => $data->{page}->{created_date},
            edited_epoch => $data->{last_modified_time},
            title => $title,
            creator_id => $user_id,
            author_name => $user_id ? Dicole::Utils::User->name( $user_id ) : '',
            url => $url,
            data_url => Dicole::URL->from_parts( domain_id => $event->domain_id, action => 'wiki_json', task => 'object_info', target => $event->group_id, additional => [ $data->{page}->id ] ),
            time_ago => Dicole::Utils::Date->localized_ago( action => $self, epoch => $data->{last_modified_time} ),
            comment_count => $data->{comment_count},
        };
        push @$pages, $info;
    }

    return $pages;
}

sub _gather_media_data {
    my ( $self, $event, $limit, $skip_thumbnail ) = @_;

    my $prese_data = CTX->lookup_action('presentations_api')->e( recent_object_data_with_tags => {
        domain_id => $event->domain_id, group_id => $event->group_id, tags => [ $event->sos_med_tag ], limit => $limit ? $limit : 10,
    } );

    my $show_edit = $self->_current_user_can_manage_event( $event );

    my $query = Dicole::Utils::SQL->column_in(attachment_id => [ grep { $_ } map { $_->{object}->attachment_id } @$prese_data ]);

    my $attachments = CTX->lookup_object('attachment')->fetch_group({
        where => $query
    });

    my %attachments = map { $_->attachment_id => $_ } @$attachments;

    my %seen_users = map { $_->user_id => $_ } @{ Dicole::Utils::User->ensure_object_list([ map { $_->{object}->creator_id } @$prese_data ]) };

    my $media = [];
    for my $data ( @$prese_data ) {
        my $presenter = $data->{object}->presenter;
        my $user = $seen_users{$data->{object}->creator_id};
        my $attachment = $attachments{$data->{object}->attachment_id};
        my $info = {
            prese_id => $data->{object}->id,
            object_type => ref( $data->{object} ),
            created_epoch => $data->{creation_date},
            attachment_id => $attachment ? $attachment->id : '',
            attachment_filename => $attachment ? $attachment->filename : '',
            attachment_mime => $attachment ? $attachment->mime : '',
            title => $data->{name},
            url => $data->{show_url},
            data_url => Dicole::URL->from_parts( domain_id => $event->domain_id, action => 'presentations_json', task => 'object_info', target => $event->group_id, additional => [ $data->{object}->id ] ),
            from_file => $data->{object}->attachment_id ? 1 : 0,
            from_url => $data->{object}->url ? 1 : 0,
            readable_type => $attachment ? Dicole::Utils::MIME->type_to_readable( $attachment->mime ) : '',
            edit_url => $show_edit ? $self->derive_url(
                action => 'presentations', task => 'edit', additional => [ $data->{object}->id ],
                params => { url_after_save => $self->derive_url }
            ) : undef,
            presenter => $data->{object}->presenter,
            creator_id => $user ? $user->id : 0,
            author_name => $user ? Dicole::Utils::User->name( $user ) : '',
            anon_email => $data->{object}->presenter,
            short_author_name => $user ? Dicole::Utils::User->short_name( $user ) : '',
            author_url => $user ? CTX->lookup_action('networking_api')->e( user_profile_url => {
                group_id => $event->group_id, user_id => $user->id, domain_id => $event->domain_id,
            } ) : '',
            author_image => $user ? CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
                user_id => $user->id, domain_id => $event->domain_id, no_default => 1, size => 50,
            } ) : '',
            thumbnail => ( $skip_thumbnail ? '' : CTX->lookup_action('thumbnails_api')->e( create => {
                width => 200, url => $data->{image}, domain_id => $event->domain_id,
            } ) ),
            time_ago => Dicole::Utils::Date->localized_ago( action => $self, epoch => $data->{creation_date} ),
            comment_count => $data->{comment_count},
        };
        push @$media, $info;
    }

    return $media;
}

sub _gather_info_for_event_users {
    my ( $self, $user_objects ) = @_;

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => [ map { $_->user_id } @$user_objects ] ),
    } ) || [];

    my %user_map = map { $_->id => $_ } @$users;

    return [ map { $self->_gather_info_for_event_user( $_, $user_map{ $_->user_id } ) } @$user_objects ];
}

sub _gather_info_for_event_user {
    my ( $self, $event_user, $user ) = @_;

    $user ||= CTX->lookup_object('user')->fetch( $event_user->user_id );

    my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        user_id => $user->id,
        domain_id => $event_user->domain_id,
        attributes => {
            contact_email => undef,
            contact_phone => undef,
            contact_organization => undef,
            contact_title => undef,
        },
    } );

    my $info = {
        user_object => $user,
        id => Dicole::Utils::User->ensure_id( $user ),
        name => Dicole::Utils::User->name( $user ),
        first_name => $user->first_name,
        last_name => $user->last_name,
        phone => $attrs->{contact_phone} || $user->phone,
        email => $attrs->{contact_email},
        private_email => $user->email,
        organization => $attrs->{contact_organization},
        organization_title => $attrs->{contact_title},
        attend_info => $event_user->attend_info,
        attend_date => $event_user->attend_date,
        is_planner => $event_user->is_planner,
        event_user_id => $event_user->id,
        rsvp_state => $event_user->rsvp_state,
        rsvp_name => $self->RSVP_NAMES->{ $event_user->rsvp_state },
    };

    return $info;
}

sub _resolve_gmaps_api_key {
    my ( $self ) = @_;

    my $domain_api_key = Dicole::Settings->fetch_single_setting(
        tool => Dicole::Utils::Domain->guess_current_settings_tool,
        attribute => 'gmaps_api_key',
    );

    return $domain_api_key || CTX->server_config->{dicole}{gmaps_api_key};
}

sub _invite {
    my ( $self, $event, $invite_users, $invite_emails, $as_planner, $greeting, $greeting_subject, $skip_send ) = @_;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $invite_as_planner = $self->_current_user_can_manage_event( $event ) ? $as_planner ? 1 : 0 : 0;
    my $inviter_id = CTX->request->auth_user_id;

    my $uids = $invite_users || '';
    my $user_ids = [ map { ( $_ =~ /^\d+$/ ) ? $_ : () } split( /\s*,\s*/, $uids ) ];

    my $addresses = Dicole::Utils::Mail->string_to_addresses( $invite_emails );
    my %addresses = map { lc( $_ ) => 1 } @$addresses;

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in_strings( email => [ keys %addresses ] ) .
            ' OR ' . Dicole::Utils::SQL->column_in( user_id => $user_ids ),
    } );

    # Add all user's emails to invite emails so that people who are stripped in the
    # following still get an email.

    my $user_emails = join ",", ( map { Dicole::Utils::User->email_with_name( $_ ) } @$users );
    $invite_emails = join ",", ( $invite_emails || (), $user_emails || () );

    my @valid_users = map { $self->_user_can_be_invited_to_event( $_, $event ) ? $_ : () } @$users;

    my $valid_domain_users = Dicole::Utils::User->filter_list_to_domain_users( \@valid_users, $domain_id );

    my %processed_addresses = ();
    for my $user ( @$valid_domain_users ) {
        next if $processed_addresses{ lc( Dicole::Utils::User->sanitized_email( $user ) ) }++;
        next unless $user->email;

        if ( $invite_as_planner ) {
            $self->_add_event_planner( $event, $user, $inviter_id, 1 );
        }
        else {
            $self->_add_event_user( $event, $user, $inviter_id, 1 );
        }
        if ( $skip_send ) {
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg( 'User [_1] added without sending email', Dicole::Utils::User->name( $user ) )
            );
        }
        else {
            eval{ $self->_send_invite_notification_to_user( $event, $user, $greeting, $greeting_subject, $invite_as_planner, $inviter_id ) };
            if ( $@ ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg( 'Sending invitation to user [_1] failed', Dicole::Utils::User->name( $user ) )
                );
            }
            else {
                Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                    $self->_msg( 'Sent an invitation to user [_1]',  Dicole::Utils::User->name( $user ) )
                 );
            }
        }
    }

    my $address_objects = Dicole::Utils::Mail->string_to_address_objects( $invite_emails );
    for my $ao ( @$address_objects ) {
        next if $processed_addresses{ lc( Dicole::Utils::Text->ensure_utf8( $ao->address ) ) }++;
        my $address = Dicole::Utils::Text->ensure_utf8( $ao->original );
        my $invite = $self->_create_invite( $event, $address, $greeting, $invite_as_planner );
        eval { $self->_send_invite( $invite, $event, $greeting_subject ) };
        if ( $@ ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Sending invitation to [_1] failed : [_2]', $address, $@ )
            );
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->_msg( 'Sent an invitation to [_1]', $address )
            );
        }
    }
}

sub _get_comments_info {
    my ( $self, $event ) = @_;

    my $key = join "_", 'events_comments_info', $event->id;

    return Dicole::Cache->fetch_or_store( $key, sub {
        my $params = {
            object => $event,
            group_id => $event->group_id,
            user_id => 0,
            size => 50,
            no_default => 1,
            domain_id => Dicole::Utils::Domain->guess_current_id,     
        };

        return CTX->lookup_action('comments_api')->e( get_comments_info => $params ) || [];
    }, { expires => 60*60*24*15 } ) || [];
}

sub _update_comments_info {
    my ( $self, $event, $domain_id ) = @_;

    my $key = join "_", 'events_comments_info', $event->id;

    return Dicole::Cache->update( $key, sub {
        my $params = {
            object => $event,
            group_id => $event->group_id,
            user_id => 0,
            size => 50,
            no_default => 1,
            domain_id => Dicole::Utils::Domain->guess_current_id( $domain_id ),     
        };

        return CTX->lookup_action('comments_api')->e( get_comments_info => $params ) || [];
    } ) || [];
}

sub _store_creation_event {
    my $self = shift @_;
    return $self->_store_some_event( 'created', @_ );
}

sub _store_edit_event {
    my $self = shift @_;
    return $self->_store_some_event( 'edited', @_ );
}

sub _store_delete_event {
    my $self = shift @_;
    return $self->_store_some_event( 'deleted', @_ );
}

sub _store_some_event {
    my ( $self, $type, $event, $tags, $domain_id, $user_id, $previous_tags ) = @_;

    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    eval {
        my $a = CTX->lookup_action('event_source_api');

        eval {
            my $secure_tree = Dicole::Security->serialize_secure(
                'OpenInteract2::Action::DicoleEvents::view', {
                    group_id => $event->group_id,
                    domain_id => $domain_id,
                }
            );

            if ( ! $tags ) {
                $tags = CTX->lookup_action('tags_api')->e( get_tags => {
                    object => $event,
                    group_id => $event->group_id,
                    user_id => 0,
                    domain_id => $domain_id,
                } );
            }

            my $dd = {
                object_id => $event->id,
                object_tags => $tags,
            };

            my %event_tags = map { $_ => 1 } @$tags;

            if ( $previous_tags ) {
                $dd->{previous_object_tags} = $previous_tags;
                $event_tags{ $_ } = 1 for @$previous_tags;
            }

            my $event_tags = [ keys %event_tags ];

            my $event_time = $event->created_date;
            $event_time = $event->updated_date if $type =~ /edit/;
            $event_time = time() if $type =~ /delete/;

            # interested? maybe planners?

            $a->e( add_event => {
                event_type => 'events_event_' . $type,
                author => $user_id || $event->creator_id,
                target_user => 0,
                target_group => $event->group_id,
                target_domain => $domain_id,
                timestamp => $event_time,
                coordinates => [],
                classes => [ 'events_event' ],
                interested => [],
                tags => $event_tags,
                topics => [ 'events_event::' . $event->id ],
                secure_tree => $secure_tree,
                data => $dd,
            } )
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error( $@ );
        }
    };
}

sub _ensure_event_object_in_current_group {
    my ( $self, $event, $group_id ) = @_;

    $group_id ||= $self->param('target_group_id');

    return $self->_ensure_event_object_in_group( $event, $group_id );
}

sub _ensure_event_object_in_group {
    my ( $self, $event, $group_id ) = @_;

    $event = $self->_ensure_event_object( $event );
    $event ||= $self->_ensure_event_object( $self->param('event_id') );

    die 'security error' unless $event && $group_id == $event->group_id;

    return $event;
}

sub _ensure_event_object {
    my ( $self, $oi ) = @_;

    return $oi if ref( $oi );
    $oi =~ s/^(\d+).*?$/$1/;
    return CTX->lookup_object('events_event')->fetch( $oi );
}

sub _ensure_event_id {
    my ( $self, $oi ) = @_;

    return $oi->id if ref( $oi );
    return $oi;
}


1;

