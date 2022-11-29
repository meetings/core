package OpenInteract2::Action::DicoleEventsJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleEventsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Cache;

# old and not used, but left here for future reference ;)
sub _attr {
    my ( $self ) = @_;

    my $event_id = $self->param('event_id');
    my $event = $self->_ensure_event_object( $self->param('event_id') );

    die "security error" unless $event;
    die "security error" unless $self->_current_user_can_manage_event( $event );

    my $name = CTX->request->param('name');
    my $value = CTX->request->param('value');

    my $raw_keys = {
        title => 1,
        abstract => 1,
        description => 1,
        location_name => 1,
        max_attenders => 1,
        attend_info => 1,
        latitude => 1,
        longitude => 1,

        event_state => 1,
        invite_policy => 1,

        show_yes => 1,
        show_no => 1,
        show_maybe => 1,
        show_waiting => 1,
        show_pages => 1,
        show_posts => 1,
        show_media => 1,
        show_tweets => 1,

        end_date => 1,
        begin_date => 1,

    };

    my $conditional_keys = {};

    my $in_mogrify = {
        sos_med_tag => sub {
            my ( $self, $value ) = @_;
            return $self->_prepare_sos_med_tag( $value );
        },
        invite_policy => sub {
            my ( $self, $value ) = @_;
            return $self->INVITE_BY_NAME->{ $value } || $self->INVITE_PLANNERS;
        },
        event_state => sub {
            my ( $self, $value ) = @_;
            return $self->STATE_BY_NAME->{ $value } || $self->STATE_PRIVATE;
        },
        show_yes => \&_show_in_mogrify,
        show_no => \&_show_in_mogrify,
        show_maybe => \&_show_in_mogrify,
        show_waiting => \&_show_in_mogrify,
        show_pages => \&_show_in_mogrify,
        show_posts => \&_show_in_mogrify,
        show_media => \&_show_in_mogrify,
        show_tweets => \&_show_in_mogrify,
        show_stream => \&_show_in_mogrify,
        show_map => \&_show_in_mogrify,
    };

    my $out_mogrify = {
        invite_policy => sub {
            my ( $self, $value ) = @_;
            return $self->INVITE_NAMES->{ $value } || $self->INVITE_NAMES->{ $self->INVITE_PLANNERS };
        },
        event_state => sub {
            my ( $self, $value ) = @_;
            return $self->STATE_NAMES->{ $value } || $self->INVITE_NAMES->{ $self->STATE_PRIVATE };
        },
        show_yes => \&_show_out_mogrify,
        show_no => \&_show_out_mogrify,
        show_maybe => \&_show_out_mogrify,
        show_waiting => \&_show_out_mogrify,
        show_pages => \&_show_out_mogrify,
        show_posts => \&_show_out_mogrify,
        show_media => \&_show_out_mogrify,
        show_tweets => \&_show_out_mogrify,
        show_stream => \&_show_out_mogrify,
        show_map => \&_show_out_mogrify,
    };

    if ( $raw_keys->{ $name } || $conditional_keys->{ $name } ) {
        if ( $value && $value ne $event->get( $name ) ) {
            eval {
                $conditional_keys->{ $name }( $self, $value ) if $conditional_keys->{ $name };
                $value = $in_mogrify->{ $name }( $self, $value ) if $in_mogrify->{ $name };
                $event->set( $name, $value );
                $event->updated_date( time() );
                $event->save;
            };
        }
        if ( $@ ) {
            return { error => { ref( $@ ) ? ( reason => $@->{reason} ) : ( message => $@ ) } };
        }
        else {
            my $out_value = $event->get( $name );
            $out_value = $out_mogrify->{ $name }( $self, $value ) if $out_mogrify->{ $name };
            return { result => { value => $out_value } };
        }
    }

    if ( $name eq 'tags' ) {
        if ( $value ) {
            my $tags = CTX->lookup_action('tags_api')->e( parse_input => { input => $value } );
            CTX->lookup_action('tags_api')->e( set_tags => {
                object => $event, user_id => 0, group_id => $event->group_id, domain_id => $event->domain_id, 'values' => $tags
            } );
        }
        return { result => { value => $self->_event_tags( $event ) } };
    }

    return { error => { message => 'invalid attr' } };
}

sub _show_in_mogrify {
    my ( $self, $value ) = @_;
    return $self->SHOW_BY_NAME->{ $value } || $self->SHOW_ALL;
}

sub _show_out_mogrify {
    my ( $self, $value ) = @_;
    return $self->SHOW_NAMES->{ $value } || $self->SHOW_NAMES->{ $self->SHOW_ALL };
}

sub upcoming {
    my ( $self ) = @_;

    return CTX->request->auth_user_id ?
        $self->_generic_listing(
            '( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) AND ' .
                '( dicole_events_event.event_state = ? OR ' .
                 $self->_current_user_visible_events_where( $self->param('target_group_id') ) .
                ' )',
           [ time(), time(), $self->STATE_PUBLIC() ],
            'dicole_events_event.begin_date asc',
        )
        :
        $self->_generic_listing(
            '( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) AND dicole_events_event.event_state = ?',
            [ time(), time(), $self->STATE_PUBLIC() ],
            'dicole_events_event.begin_date asc',
        );
}

sub past {
    my ( $self ) = @_;

    return CTX->request->auth_user_id ?
        $self->_generic_listing(
            '( dicole_events_event.begin_date < ? AND dicole_events_event.end_date < ? ) AND '.
                '( dicole_events_event.event_state = ? OR ' .
                $self->_current_user_visible_events_where( $self->param('target_group_id') ) .
                ' )',
            [ time(), time(), $self->STATE_PUBLIC() ],
            'dicole_events_event.begin_date desc',
        )
        :
        $self->_generic_listing(
            '( dicole_events_event.begin_date < ? AND dicole_events_event.end_date < ? ) AND dicole_events_event.event_state = ?',
            [ time(), time(), $self->STATE_PUBLIC() ],
            'dicole_events_event.begin_date desc'
        );

}

sub my {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    return $self->_generic_listing(
        $self->_user_events_where( CTX->request->auth_user_id, $self->param('target_group_id') ),
        undef,
        'dicole_events_event.begin_date desc',
    );
}

sub _generic_listing {
    my ( $self, $where, $value, $order, $from ) = @_;

    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $page_load = CTX->request->param('page_load');
    my $shown_ids_json = CTX->request->param('shown_entry_ids');
    my $shown_ids = eval { $shown_ids_json ? JSON->new->jsonToObj( $shown_ids_json ) : [] };
    $shown_ids = [] unless ref( $shown_ids ) eq 'ARRAY';

    my $entries = $self->_generic_events(
        tag => $tag,
        group_id => $gid,
        order => $order,
        where => 'dicole_events_event.created_date < ? AND ' . Dicole::Utils::SQL->column_not_in(
            'dicole_events_event.event_id' => $shown_ids,
        ) . ( $where ? ' AND ' . $where : '' ),
        value => [ $page_load, ( $value ? @$value : () ) ],
        limit => $self->OBJECTS_ON_PAGE,
        ( $from ? ( from => $from ) : () ),
    );

    my $widget = $self->_visualize_event_list( $entries, 1 );
    my $html = $widget->generate_content;

    return { messages_html => $html }
}

sub rsvp {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    die "security error" unless $self->_current_user_can_manage_event( $event );

    my $rsvp = $self->RSVP_BY_NAME->{ CTX->request->param('rsvp_name') };

    unless ( $rsvp ) {
        return { error => { reason => $self->_msg( 'Unknown error' ) } };
    }

    my $user = eval{ Dicole::Utils::User->ensure_object( CTX->request->param('user_id') ) };

    unless ( $user ) {
        return { error => { reason => $self->_msg( 'Unknown error' ) } };
    }

    if ( $rsvp == $self->RSVP_YES && ! $self->_event_has_seats_left( $event ) ) {
        return { error => { reason => $self->_msg( 'Event is full' ) } };
    }

    $self->_set_event_user_rsvp( $event, $user, $rsvp );

    return { result => { rsvp_name => $self->RSVP_NAMES->{ $rsvp } } };
}

sub comment_state {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    return { state => $self->_get_state( $event ) };
}

sub _get_state {
    my ( $self, $event ) = @_;

    my $info = $self->_get_comments_info( $event ); 

    return [ reverse( map { $_->{post_id} } @$info ) ];
}

sub comment_info {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    my $list_json = CTX->request->param('comment_id_list');
    my $list = Dicole::Utils::JSON->decode( $list_json || '[]' );

    my $all_info = $self->_get_comments_info( $event );
    my %info_by_id = map { $_->{post_id} => $_ } @$all_info;
    my @relevant_info = map { $info_by_id{$_} || () } @$list;

    my $info = $self->_prepare_comment_info_list( $event, \@relevant_info );

    my $comments = {};
    for my $id ( @$list ) {
        $comments->{$id} = $self->_process_comment_template( $info_by_id{$id} );
    }

    return { comments => $comments };
}

sub add_comment {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    my $comment_content = CTX->request->param('content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    CTX->lookup_action('comments_api')->e( add_comment_and_return_thread => {
        object => $event,
        group_id => $event->group_id,
        user_id => 0,
        content => $comment_html,
    } );

    $self->_update_comments_info( $event );

    return { state => $self->_get_state( $event ) };
}

sub delete_comment {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    my $can_delete = (
        $self->_user_is_event_planner( CTX->request->auth_user, $event ) ||
        $self->mchk_y('OpenInteract2::Action::DicoleEvents', 'admin' )
    ) ? 1 : 0;

    CTX->lookup_action('comments_api')->e( delete_comment => {
        object => $event,
        group_id => $event->group_id,
        user_id => 0,
        post_id => $self->param('comment_id'),
        right_to_remove_comments => $can_delete,
    } );

    $self->_update_comments_info( $event );

    return { state => $self->_get_state( $event ) };
}

sub dialog_data {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_invite_to_event( $event );

    my $data = CTX->lookup_action('invite_api')->e( dialog_data => {} );

    my $invite_planners = $self->_current_user_can_invite_planners_to_event( $event );

    $data->{levels} = [
        { value => 'participant', name => $self->_msg('Participant') },
        $invite_planners ? ( { value => 'planner', name => $self->_msg('Planner') } ) : (),
    ];

    return { result => $data };
}

sub levels_dialog_data {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_invite_to_event( $event );

    my $data = {};

    my $invite_planners = $self->_current_user_can_invite_planners_to_event( $event );

    $data->{levels} = [
        { value => 'participant', name => $self->_msg('Participant') },
        $invite_planners ? ( { value => 'planner', name => $self->_msg('Planner') } ) : (),
    ];

    return { result => $data };
}


sub invite {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_invite_to_event( $event );

    my $as_planner = CTX->request->param('level') eq 'planner' ? 1 : 0;

    $self->_invite(
        $event,
        CTX->request->param('users'),
        CTX->request->param('emails'),
        $as_planner,
        CTX->request->param('greeting_message'),
        CTX->request->param('greeting_subject'),
        CTX->request->param('add_instantly'),
    );

    return { result =>  { success => 1 } }; 
}

sub toggle_planner_status {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    my $uid = $self->param('user_id');
    my $euo = $self->_get_event_user_object( $event, $uid );

    return { error => 1 } if ! $euo || ! $self->_current_user_can_toggle_event_planner_status_for_user( $event, $uid );

    $euo->is_planner( $euo->is_planner ? 0 : 1 );
    $euo->save;

    return { success => 1, is_planner => $euo->is_planner ? 1 : 0 };
}

sub change_refresh {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    if ( $event->begin_date ) {
        # This means the date has changed and users should refresh to get a new counter
        if ( $event->begin_date > time() ) {
            return { refresh => 1 };
        }
        elsif ( $event->show_counter == $self->SHOW_NONE ) {
            return { refresh => 1 };
        }
    }
    return { refresh => 0 };
}

1;
