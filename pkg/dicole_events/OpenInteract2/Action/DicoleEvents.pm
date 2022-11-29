package OpenInteract2::Action::DicoleEvents;

use strict;

use base qw( OpenInteract2::Action::DicoleEventsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );
use Dicole::Utils::Date;
use URI::Escape;


sub _events_upcoming_summary {
    my ( $self ) = @_;

    my $events = $self->_generic_events(
        group_id => $self->param('target_group_id'),
        where => '( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) '.
            ' AND ( dicole_events_event.event_state = ? OR ' .
            $self->_user_events_where( CTX->request->auth_user_id, $self->param('target_group_id') ) .
            ' )',
        value => [ time(), time(), $self->STATE_PUBLIC() ],
        order => 'dicole_events_event.begin_date asc',
        limit => 5
    );
    my $params = { events => [] };

    for my $event ( @$events ) {
        my $info = {
            title => $event->title,
            'link' => $self->_event_show_url( $event ),
            image => $event->logo_attachment ? $self->_event_small_logo_url( $event ) : '',
            date => $self->_event_date( $event ),
        };
        push @{ $params->{events} }, $info;
    }

    $params->{show_events_url} = Dicole::URL->from_parts( action => 'events', task => 'detect', target => $self->param('target_group_id') );

    my $content = $self->generate_content( $params, { name => 'dicole_events::upcoming_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Upcoming events') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _events_past_summary {
    my ( $self ) = @_;

    my $events = $self->_generic_events(
        group_id => $self->param('target_group_id'),
        where => '( dicole_events_event.begin_date < ? AND ( dicole_events_event.end_date < ? OR dicole_events_event.end_date = 0 ) ) '.
            ' AND ( dicole_events_event.event_state = ? OR ' .
            $self->_user_events_where( CTX->request->auth_user_id, $self->param('target_group_id') ) .
            ' )',
        value => [ time(), time(), $self->STATE_PUBLIC() ],
        order => 'dicole_events_event.begin_date desc',
        limit => 5
    );
    my $params = { events => [] };

    for my $event ( @$events ) {
        my $info = {
            title => $event->title,
            'link' => $self->_event_show_url( $event ),
            image => $event->logo_attachment ? $self->_event_small_logo_url( $event ) : '',
            date => $self->_event_date( $event ),
        };
        push @{ $params->{events} }, $info;
    }

    $params->{show_events_url} = Dicole::URL->from_parts( action => 'events', task => 'detect', target => $self->param('target_group_id') );

    my $content = $self->generate_content( $params, { name => 'dicole_events::upcoming_summary' } );

    my $box = Dicole::Box->new;
    $box->name( $self->_msg('Past events') );

    if ( $self->param( 'box_open' ) ) {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }

    return $box->output;
}

sub _legacy_events_upcoming_summary {
    my ( $self ) = @_;

    return OpenInteract2::Action::DicoleEvents::UpcomingSummary->new( $self, {
        box_title => $self->_msg('Upcoming events'),
        box_title_link => Dicole::URL->from_parts(
            action => 'events',
            task => 'upcoming',
            target => $self->param('target_group_id'),
        ),
        object => 'events_event',
        query_options => {
            where => 'dicole_events_event.group_id = ? AND ( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) AND ( dicole_events_event.event_state = ? OR ' .
                $self->_user_events_where( CTX->request->auth_user_id, $self->param('target_group_id') ) . ' )',
            value => [  $self->param('target_group_id'), time(), time(), $self->STATE_PUBLIC() ],
            order => 'dicole_events_event.begin_date asc',
            limit => 5,
        },
        empty_box_string => $self->_msg('No upcoming events found.'),
        title_field => 'title',
        date_field => 'begin_date',
        dated_list_separator_set => 'month & day',
    } )->execute;
}

sub _default_tool_init {
    my ( $self, %params ) = @_;
    my $tool_args = $params{tool_args} || {};
    delete $params{tool_args};
    $self->init_tool({ rows => 6, cols => 2, tool_args => { no_tool_tabs => 1, %$tool_args }, %params });
    $self->tool->Container->column_width( '280px', 1 );
    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/dicole_events.css' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Raw->new( raw => '<!--[if lt IE 7]><link rel="stylesheet" href="/css/dicole_events_ie6.css" media="all" type="text/css" /><![endif]-->' . "\n" ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dojo.require("dicole.events");' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::CSSLink->new( href => '/css/datepicker.css' ),
    );
    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new( src => '/js/datepicker.js' ),
    );
}

sub detect {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_url( task => 'upcoming' ) );
}

sub upcoming {
    my ( $self ) = @_;

    return $self->_generic_listing(
        'Upcoming events',
        '( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) AND ( dicole_events_event.event_state = ? OR ' .
            $self->_current_user_visible_events_where( $self->param('target_group_id') ) . ' )',
        [ time(), time(), $self->STATE_PUBLIC() ],
        'dicole_events_event.begin_date asc',
        0,
    );
}

sub past {
    my ( $self ) = @_;

    return $self->_generic_listing(
        'Past events',
        '( dicole_events_event.begin_date < ? AND dicole_events_event.end_date < ? ) AND ( dicole_events_event.event_state = ? OR ' .
        $self->_current_user_visible_events_where( $self->param('target_group_id') ) . ' )',
        [ time(), time(), $self->STATE_PUBLIC() ],
        'dicole_events_event.begin_date desc',
        1
    );
}

sub my {
    my ( $self ) = @_;

    die "security error" unless CTX->request->auth_user_id;
    return $self->_generic_listing(
        'My events',
        $self->_user_events_where( CTX->request->auth_user_id, $self->param('target_group_id') ),
        [],
        'dicole_events_event.begin_date desc',
        1
    );
}

sub _generic_listing {
    my ( $self, $title, $where, $value, $order, $skip_feed ) = @_;

    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');

    $self->_default_tool_init(
        $skip_feed ? () : ( tool_args => {
            feeds => $self->init_feeds(
                action => 'events_feed',
                task => $self->task,
                additional_file => 'feed.rss',
                additional => $tag ? [ $tag ] : [ 0 ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        } )
    );

    my $events = $self->_generic_events(
        tag => $tag,
        group_id => $gid,
        order => $order,
        where => $where,
        value => $value,
        limit => $self->OBJECTS_ON_PAGE,
    );
    
    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Navigation') );
    $self->tool->Container->box_at( 0, 0 )->class( 'events_listing_navigation' );
    my $awfulhack = $self->tool->get_tablink_widgets;
    $awfulhack->{contents} = [ map { $_->content( Dicole::Widget::Raw->new( raw =>  '&rarr; ' . $_->content ) ); bless $_, 'Dicole::Widget::Hyperlink'; $_ } @{ $awfulhack->{contents} } ];
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ $awfulhack ]
    );
     
    $self->_fill_first_boxes( $events, $tag, $title);
    
    eval {
        my $tags = CTX->lookup_action('tagging')->execute( 'get_query_limited_weighted_tags', {
            object_class => CTX->lookup_object('events_event'),
            where => 'dicole_events_event.group_id = ? AND ' . ( $where || '1=1' ),
            value => [ $gid, ( $value ? @$value : () ) ],
        } );

        die unless scalar( @$tags );

        $self->tool->Container->box_at( 0, 4 )->name( $self->_msg('Filter by tag') );
        $self->tool->Container->box_at( 0, 4 )->class( 'events_listing_tags' );
        $self->tool->Container->box_at( 0, 4 )->add_content(
            [ $self->_fake_tag_cloud_widget(
                $self->derive_url( additional => [] ),
                $tags
            ) ]
        );
    };

    my $settings = Dicole::Settings->new_fetched_from_params(
        tool => 'events',
        group_id => $gid,
        user_id => 0,
    );

    if ( my $sbcontent = $settings->setting('custom_sidebar_content') ) {
        $self->tool->Container->box_at( 0, 5 )->class( 'events_custom_sidebar' );
        $self->tool->Container->box_at( 0, 5 )->add_content(
            [ Dicole::Widget::Raw->new( raw => $sbcontent ) ],
        );
        if ( my $sbtitle = $settings->setting('custom_sidebar_title') ) {
            $self->tool->Container->box_at( 0, 5 )->name( $sbtitle );
        }
    }

    return $self->generate_tool_content;
}

sub _fill_first_boxes {
    my ( $self, $events, $tag, $title ) = @_;
    
    $title .= ' tagged with: [_1]' if $tag;
    
    my $hide_add = 0;
    $hide_add ||= 1 if $tag;
    $hide_add ||= 1 if ! CTX->request->auth_user_id;
#    $hide_add ||= 1 if $self->task ne 'upcoming';
    $hide_add ||= 1 if ! $self->chk_y( 'add' );
    
    my $list = scalar( @$events ) ?
        $self->_visualize_event_list( $events ) :
        Dicole::Widget::Inline->new( contents => [
            Dicole::Widget::Text->new(
                class => 'events_no_events_found listing_not_found_string',
                text => $self->_msg('No events found.'),
            ),
            $hide_add ? () : (
                ' ',
                Dicole::Widget::Hyperlink->new(
                    class => 'events_no_events_add',
                    content => $self->_msg('Be the first to add one!'),
                    'link' => $self->derive_url(
                        task => 'add',
                        additional => [ ],
                    ),
                ),
            ),
            ( $self->task eq 'upcoming' ) ? Dicole::Widget::Container->new(
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
            ) : (),
        ] );

    # $self->_msg('Upcoming events');
    # $self->_msg('Upcoming events tagged with: [_1]');
    # $self->_msg('Past events');
    # $self->_msg('Past events tagged with: [_1]');
    # $self->_msg('My events');
    # $self->_msg('My events tagged with: [_1]');

    my $create = Dicole::Widget::Inline->new( id => 'events_create_button_container', contents => [
        Dicole::Widget::Hyperlink->new(
            class => 'yellow-button',
            'link' => $self->derive_url( task => 'add' ),
            content => Dicole::Widget::Text->new( text => '+ ' . $self->_msg('Create event'), class => 'events_create_event_button_text' ),
        ),
    ] );

    my $legend = Dicole::Widget::Inline->new(
        class => 'boxLegend boxLegend2',
        contents => [
            Dicole::Widget::Text->new(
                text => $self->_msg( $title, $tag ),
                class => 'boxLegend2Text'
            ),
            $hide_add ? () : ( $create ),
        ],
    );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( $title, $tag ) );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $legend, $list ]
    );
}

sub add {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_url( task => 'edit', additional => [] ) );
}

sub edit {
    my ( $self ) = @_;

    my $event_id = $self->param('event_id');

    die 'security error' unless $event_id || $self->chk_y( 'add' );

    my $event = undef;
    if ( ! $event_id && CTX->request->param('save') ) {
        if ( CTX->request->param('title') ) {
            $event = CTX->lookup_action('events_api')->e( create_event => {
                title => CTX->request->param('title'),
            } );
            $event_id = $event->id;
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Event needs a title!' )
            );
        }
    }

    if ( $event_id ) {
        $event ||= $self->_ensure_event_object_in_current_group( $event_id );
        die 'security error' unless $event;
        die 'security error' unless $self->_current_user_can_manage_event( $event );
    }

    my $save_failed = 0;
    if ( $event && CTX->request->param('save') ) {

        if ( CTX->request->param( 'title' ) ) {
            $event->title( CTX->request->param( 'title' ) );
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Event needs a title!' )
            );
            $save_failed = 1;
        }

        for my $attr ( qw(
            abstract
            description
            stream
            feedback
            freeform_title
            freeform_content
            sos_med_tag
            attend_info
            location_name
        ) ) {
            $event->set( $attr, CTX->request->param( $attr ) );
        }

        # HACK: evil :/
        if ( $self->param('domain') && $self->param('domain')->domain_name =~ /deski|onlinepressconference/ && ! $event->sos_med_tag ) {
            $event->sos_med_tag( 'deski_x' );
        }

        $event->sos_med_tag( $event->title ) unless $event->sos_med_tag;
        $event->sos_med_tag( $self->_prepare_sos_med_tag( $event->sos_med_tag ) );

        for my $attr ( qw( latitude longitude ) ) {
            $event->set( $attr, CTX->request->param( $attr ) || 0 );
        }

        $event->{require_phone} = CTX->request->param('require_phone') ? 1 : 0;
        $event->{require_invite} = CTX->request->param('require_invite') ? 1 : 0;
        $event->{max_attenders} = CTX->request->param('max_attenders') =~ /^\d+$/ ? CTX->request->param('max_attenders') : 0;

        my $begin_date = eval{ $self->_date_time_strings_to_epoch( CTX->request->param('begin_date'), CTX->request->param('begin_time') ) } || 0;
        my $end_date = eval{ $self->_date_time_strings_to_epoch( CTX->request->param('end_date'), CTX->request->param('end_time') ) } || 0;
        $end_date = 0 if $end_date < $begin_date;

        $event->begin_date( $begin_date );
        $event->end_date( $end_date );

        my $reg_begin_date = eval { $self->_date_time_strings_to_epoch( CTX->request->param('reg_begin_date'), CTX->request->param('reg_begin_time') ) } || 0;
        my $reg_end_date = eval { $self->_date_time_strings_to_epoch( CTX->request->param('reg_end_date'), CTX->request->param('reg_end_time') ) } || 0;
        $reg_end_date = $reg_begin_date if $reg_end_date && $reg_end_date < $reg_begin_date;

        $event->reg_begin_date( $reg_begin_date );
        $event->reg_end_date( $reg_end_date );

        $event->event_state( $self->STATE_BY_NAME->{ CTX->request->param( 'event_state_name' ) } || $self->STATE_PRIVATE );
        # $event->invite_policy( $self->INVITE_BY_NAME->{ CTX->request->param( 'invite_policy_name' ) } || $self->INVITE_PLANNERS );
        $event->{invite_policy} = (
                ( $event->event_state == $self->STATE_PUBLIC && CTX->request->param('public_users_can_invite') ) ||
                ( $event->event_state == $self->STATE_PRIVATE && CTX->request->param('private_users_can_invite') )
            ) ? $self->INVITE_ANYONE : $self->INVITE_PLANNERS;

        $self->_process_image_uploads( $event );

        for my $attr ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
            $event->set( $attr, $self->SHOW_BY_NAME->{ CTX->request->param( $attr . '_name' ) } || $self->SHOW_NONE );
        }

        unless ( $save_failed ) {
            $event->updated_date( time() );
            $event->save;

            # HACK: evil :/
            if ( $self->param('domain') && $self->param('domain')->domain_name =~ /deski|onlinepressconference/ && $event->sos_med_tag eq 'deski_x' ) {
                $event->sos_med_tag( 'deski_' . $event->id );
                $event->save;
            }

            my $previous_tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
                object => $event,
            } );

            my $new_tags = CTX->lookup_action('tags_api')->execute( merge_input_to_json_tags => {
                input => CTX->request->param('tags_add_tags_input_field'),
                json => CTX->request->param('tags'),
            } );

            CTX->lookup_action('tags_api')->execute( update_tags_from_json => {
                object => $event,
                json => $new_tags,
                json_old => CTX->request->param('tags_old'),
            } );

            my $current_tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
                object => $event,
            } );

            if ( $self->param('event_id') ) {
                $self->_store_edit_event( $event, $current_tags, undef, CTX->request->auth_user_id, $previous_tags);
            }
            else {
                $self->_store_creation_event( $event, $current_tags );
            }

            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                $self->param('event_id') ?
                    $self->_msg( 'Changes saved.' ) :
                    $self->_msg( 'Event created.' ),
            );
            return $self->redirect( $self->_event_show_url( $event ) );
        }
    };

    my $params = $self->_gather_event_params( $event, CTX->request->param('save') );

    $params->{'dump'} = Data::Dumper::Dumper( $params );

    $self->_default_tool_init( upload => 1 );

    $self->tool->add_tinymce_widgets;

    my $hc = $self->_resolve_gmaps_api_key;

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new(
            code => 'dojo.require("dicole.tags");',
        ),
    );

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Extra controls' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'events_edit_extra_controls' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_events::component_edit_extra' } )
        ) ]
    );
    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Manage event' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'events_edit_manage_event' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_events::component_edit_info' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _process_image_uploads {
    my ( $self, $event ) = @_;
    for my $type ( qw( logo banner ) ) {
        if ( CTX->request->param( 'remove_' . $type ) ) {
            $event->set( $type . '_attachment', 0 );
        }

        my $upload_obj = CTX->request->param( $type ) ? CTX->request->upload( $type ) : undef;
        if ( ref( $upload_obj ) ) {
            my $a = CTX->lookup_action('attachment')->execute( store_from_request_upload => {
                object => $event,
                upload_name => $type,
                group_id => $event->group_id,
                user_id => 0,
                owner_id => CTX->request->auth_user_id,
                domain_id => $event->domain_id,
            } );
            $event->set( $type . '_attachment', $a->id );
        }
    }
}

sub show {
    my ( $self ) = @_;

    if ( $self->param('domain_name') =~ /meetin/ ) {
        return $self->redirect( $self->derive_full_url( action => 'meetings', task => 'meeting' ) );
    }

    if ( CTX->request->param('dic') ) {
        return $self->redirect( $self->derive_url );
    }

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $uid = CTX->request->auth_user_id;
    my $gid = $self->param('target_group_id');

    my $user = CTX->request->auth_user_id ? CTX->request->auth_user : undef;

    my $invite = $self->_fetch_invite( $event );
    die "security error" unless $self->_current_user_can_see_event( $event, $invite );

    $self->_process_invite_consume( $invite, $uid, $gid ) if $invite && $uid;
    $self->_process_generic_register( CTX->request->param('register'), $invite ) if CTX->request->param('register');

    my $global_vars = {};
    my $params = $self->_gather_event_params( $event );

    my $allow_register = $invite ? 1 : 0;

    if ( ! $uid ) {
        if ( $invite ) {
            $params->{register_type} = 'invite';
            $params->{accept_invite} = 1;
            $params->{accept_invite_yes_url} = $self->derive_url( params => { invite_code => $invite->secret_code, rsvp => 'open_yes' } );
            $params->{accept_invite_maybe_url} = $self->derive_url( params => { invite_code => $invite->secret_code, rsvp => 'maybe' } );
            $params->{accept_invite_no_url} = $self->derive_url( params => { invite_code => $invite->secret_code, rsvp => 'no' } );
        }
        elsif ( $self->_any_user_can_attend_event( $event ) ) {
            my $ual = $self->derive_url( params => { open_attend => 1 } );
            $params->{register_type} = 'attend';
            $params->{attend_after_login_url} = $ual;
            $global_vars->{url_after_register} = $ual;

        }
        elsif ( ! $event->require_invite ) {
            $params->{register_type} = 'normal';
            $params->{suggest_login} = 1;
        }
        $params->{retrieve_password_url} = Dicole::URL->from_parts( action => 'lostaccount' );
        $allow_register ||= eval { CTX->lookup_action('user_manager_api')->e( current_domain_registration_allowed => {
            group_id => $self->param('target_group_id'),
        } ) };
        $params->{register_url} = $self->derive_full_url if $allow_register;
        $params->{url_after_login} = $self->derive_full_url;
    }

    if ( $uid && CTX->request->param( 'open_attend' ) ) {
        $params->{open_attend_dialog} = 1;
    }

    my $ues = $self->_event_users_link_list( $event );
    my $skip_list = {};
    if ( ! $self->_current_user_can_manage_event( $event ) ) {
        my $cueo =  CTX->request->auth_user_id ? $self->_get_event_user_object( $event, CTX->request->auth_user_id ) : undef;
        $skip_list->{ $self->RSVP_YES } = $self->_current_user_can_see_component( $event, 'show_yes', $cueo ) ? 0 : 1;
        $skip_list->{ $self->RSVP_MAYBE } = $self->_current_user_can_see_component( $event, 'show_maybe', $cueo ) ? 0 : 1;
        $skip_list->{ $self->RSVP_NO } = $self->_current_user_can_see_component( $event, 'show_no', $cueo ) ? 0 : 1;
        $skip_list->{ $self->RSVP_WAITING } = $self->_current_user_can_see_component( $event, 'show_waiting', $cueo ) ? 0 : 1;
        $skip_list->{admin} = 1;
    }

    for my $rsvp ( @$ues ) {
        $params->{users}->{ $self->RSVP_NAMES->{ $rsvp->rsvp_state } } ||= [];
        next if $skip_list->{ $rsvp->rsvp_state };

        my $user = Dicole::Utils::User->ensure_object( $rsvp->user_id );
        next unless $user;

        my $info = $self->_gather_info_for_event_user( $rsvp, $user );

        $info->{image} = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $rsvp->user_id, domain_id => $domain_id, no_default => 1, size => 50,
        } );
        $info->{'link'} = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $rsvp->user_id, domain_id => $domain_id, group_id => $gid,
        } );
        $info->{planner_status_change_url} = ( ! $skip_list->{admin} && 
            $self->_current_user_can_toggle_event_planner_status_for_user( $event, $user, undef, $rsvp ) ) ?
                $self->derive_url(
                    action => 'events_json',
                    task => 'toggle_planner_status',
                    additional => [ $event->id, $user->id ]
                ) : '';

        delete $info->{user_object};

        if ( $self->param('domain')->domain_name =~ /work\-dev|onlineitk/ ) {
            $info->{attend_info} = '';
        }

        push @{ $params->{users}->{ $self->RSVP_NAMES->{ $rsvp->rsvp_state } } }, $info;
    }

    my $pes = $self->_event_planners_link_list( $event );
    for my $rsvp ( @$pes ) {
        my $user = Dicole::Utils::User->ensure_object( $rsvp->user_id );
        next unless $user;

        my $info = $self->_gather_info_for_event_user( $rsvp, $user );

        $info->{image} = CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
            user_id => $rsvp->user_id, domain_id => $domain_id, no_default => 1, size => 50,
        } );
        $info->{'link'} = CTX->lookup_action('networking_api')->e( user_profile_url => {
            user_id => $rsvp->user_id, domain_id => $domain_id, group_id => $gid,
        } );
        delete $info->{user_object};

        $params->{planners} ||= [];
        push @{ $params->{planners} }, $info;
    }

# TODO: Not userd yet and pretty heavy!
# TODO: At least don't do this for users who can't see these :D
#    my $open_invites = $self->_event_open_invites( $event );
#    my %sender_user = ();
#    for my $invite ( @$open_invites ) {
#        $sender_user{ $invite->creator_id } ||= eval { Dicole::Utils::User->ensure_object( $invite->creator_id ) };
#        my $info = {
#            invite_id => $invite->id,
#            email => $invite->email,
#            sender_name => Dicole::Utils::User->name( $sender_user{ $invite->creator_id } ),
#        };
#        push @{ $params->{open_invites} }, $info;
#    }

    $params->{browse_other_url} = $self->derive_url( task => 'upcoming', additional => [] );
    $params->{live_url} = $self->derive_url(
        action => 'cafe', task => 'display', target => $gid,
        params => {
            show_twitter => 1,
            show_posts => 1,
            show_pages => 1,
            show_media => 1,
            tag => $event->sos_med_tag,
            custom_title => $event->title,
        },
    ) if $event->sos_med_tag;
    # Disabled for now:
    $params->{live_url} = '';
    $params->{ics_url} = $self->derive_url( action => 'events_raw', task => 'ics', additional => [ $event->id, 'event.ics' ] );

    if ( $user ) {
        $params->{request_phone} = $event->require_phone ? 1 : 0;
        my $attrs = CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            user_id => $user->id,
            domain_id => $event->domain_id,
            attributes => {
                contact_phone => undef,
                contact_organization => undef,
                contact_title => undef,
            },
        } );

        $params->{prefill_phone} = $attrs->{contact_phone} || $user->phone;
        $params->{prefill_organization} = $attrs->{contact_organization};
        $params->{prefill_organization_title} = $attrs->{contact_title};
    }

    $params->{current_user} = Dicole::Utils::User->icon_hash(
        CTX->request->auth_user, 50, $gid, $domain_id
    );

    $params->{comments} = $self->_prepare_comment_info_list( $event,
        $self->_get_comments_info( $event )
    );

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $event,
        group_id => $event->group_id,
        user_id => 0,
    } );

    my $seconds = 0;
    if ( $event->begin_date ) {
        $seconds = $event->begin_date - time();
        $seconds = 0 if $seconds < 0;
    }

    $global_vars = {
        %$global_vars,
        events_comment_thread_id => $thread->id,
        events_comment_state_url => $self->derive_url(
            action => 'events_json', task => 'comment_state', additional => [ $event->id ],
        ),
        events_comment_info_url => $self->derive_url(
            action => 'events_json', task => 'comment_info', additional => [ $event->id ],
        ),
        events_seconds_until_start => $seconds,
        events_change_topic => 'events_event::' . $event->id,
        events_change_refresh_url => $self->derive_url(
            action => 'events_json', task => 'change_refresh', additional => [ $event->id ],
        ),
    };

    if ( $self->_current_user_can_invite_to_event( $event ) ) {
        $global_vars->{invite_dialog_data_url} = $self->derive_url(
            action => 'events_json', task => 'dialog_data', additional => [ $event->id ]
        );
        $global_vars->{invite_levels_dialog_data_url} = $self->derive_url(
            action => 'events_json', task => 'levels_dialog_data', additional => [ $event->id ]
        );
         $global_vars->{invite_submit_url} = $self->derive_url(
            action => 'events_json', task => 'invite', additional => [ $event->id ]
        );
        $global_vars->{invite_default_subject} = $self->_msg('You have been invited to the event [_1]', $event->title );
        $global_vars->{invite_dialog_title} = $self->_msg('Invite users to event [_1]', $event->title );
        $global_vars->{invite_add_instantly_text} = $self->_msg('Add users from the current area to event without sending email' );
    }

    if ( $self->chk_y( 'comment' ) ) {
        $global_vars->{events_comment_add_url} = $self->derive_url(
            action => 'events_json', task => 'add_comment', additional => [ $event->id ],
        );
        $params->{events_comment_add_url} = $self->derive_url(
            action => 'events_json', task => 'add_comment', additional => [ $event->id ],
        );
    }
    elsif ( ! $uid ) {
        $params->{commenting_possible_after_register} = $allow_register ? 1 : 0;
        # TODO: For now this would be always true when the comments are shown. In the future there will be a switch
        # which leaves the chat visible but prevents anyone from adding anything - then this could be false.
        # remember that this should affect the register variable too.
        $params->{commenting_possible_after_login} = 1;
    }

    my ( $fb_id, $fb_secret, $fb_disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    $params->{facebook_connect_app_id} = $fb_disabled ? '' : $fb_id;

    $params->{'dump'} = Data::Dumper::Dumper( $params );

    my $info = Dicole::Widget::Raw->new(
        raw => $self->generate_content( $params, { name => 'dicole_events::component_show_info' } )
    );

    $self->_default_tool_init(
        cols => $params->{show_extras} ? 2 : 1,
        tool_args => {
            feeds => $self->init_feeds(
                action => 'events_feed',
                task => 'event_rss',
                target => $event->group_id,
                additional_file => '',
                additional => [ $event->id ],
                rss_type => 'rss20',
                rss_desc => $self->_msg( 'Syndication feed (RSS 2.0)' ),
            ),
        }

    );

    $self->tool->add_js_variables( $global_vars );

    $self->tool->add_tinymce_widgets if $self->_current_user_can_manage_event( $event );

    eval { CTX->lookup_action('awareness_api')->e( register_object_activity => {
        object => $event,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        target_group_id => $event->group_id,
        act => 'show',
    } ) };
    get_logger(LOG_APP)->error( $@ ) if $@;

    if ( $params->{show_extras} ) {
        $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Extra info' ) );
        $self->tool->Container->box_at( 0, 0 )->class( 'events_show_extra_info' );
        $self->tool->Container->box_at( 0, 0 )->add_content(
            [ Dicole::Widget::Raw->new(
                raw => $self->generate_content( $params, { name => 'dicole_events::component_show_extra' } )
            ) ]
        );
    }

    if ( $params->{show_promo} ) {
        $params->{current_url} = Dicole::URL->get_domain_url . $params->{show_url};
        $params->{encoded_current_url} = URI::Escape::uri_escape( $params->{current_url} );
        $self->tool->add_head_widgets(
            Dicole::Widget::Javascript->new( src => 'https://apis.google.com/js/plusone.js' ),
        );
    }

    my $main_col = $params->{show_extras} ? 1 : 0;

    $self->tool->Container->box_at( $main_col, 0 )->name( $self->_msg( 'Event info' ) );
    $self->tool->Container->box_at( $main_col, 0 )->class( 'events_show_event_info' );
    $self->tool->Container->box_at( $main_col, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_events::component_show_info' } )
        ) ]
    );

    if ( $self->param('domain')->domain_name =~ /work\-dev|onlineitk/ ) {
        $params->{show_itk_fields} = 1;
    }

    $self->tool->add_footer_widgets( Dicole::Widget::Raw->new(
        raw => $self->generate_content( $params, { name => 'dicole_events::component_dialogs' } )
    ) );

    $self->tool->tool_title_suffix( $event->title );

    return $self->generate_tool_content;
}

sub show_page {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $gid = $self->param('target_group_id');

    die "security error" unless $self->_current_user_can_see_event( $event );

    my $data = CTX->lookup_action('wiki_api')->e( gather_page_data => {
        title => $self->param('title'), group_id => $gid, domain_id => $event->domain_id,
    } );

    my $readable_title = $self->_filter_page_name_tag( $event, $data->{readable_title} );

    my $content = CTX->lookup_action('wiki_api')->e( filtered_page_content => {
        page => $data->{page}, group_id => $gid, domain_id => $event->domain_id,
        link_generator => sub {
            my ( $title ) = @_;

            my ( $t, $a, $internal ) = CTX->lookup_action('wiki_api')->e( decode_title => { title => $title } );

            return Dicole::URL->create_from_parts(
                action => 'events',
                task => 'show_page',
                target => $gid,
                additional => [ $event->id, $title ],
                anchor => $a,
                domain_id => $domain_id,
            );
        },
    } );

    my $show_edit = 1;
    $show_edit = 0 unless $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'edit' );
    $show_edit = 0 if $data->{page}->moderator_lock && ! $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'lock' );

    my $params = $self->_gather_event_params( $event );
    $params->{browse_current_url} = $self->_event_show_url( $event );

    $self->_default_tool_init;

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Extra info' ) );
    $self->tool->Container->box_at( 0, 0 )->class( 'events_show_extra_info' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_events::component_show_extra' } )
        ) ]
    );


    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Page info' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'events_show_page_info' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [
            Dicole::Widget::Inline->new(
                class => 'boxLegend boxLegend2',
                contents => [
                    Dicole::Widget::Text->new(
                        text => $event->title . ' - ' . $readable_title,
                        class => 'boxLegend2Text'
                    ),
                    $show_edit ?
                        Dicole::Widget::Inline->new( id => 'events_show_page_edit_container', contents => [
                            Dicole::Widget::Hyperlink->new(
                                class => 'yellow-button',
                                'link' => $self->derive_url( action => 'wiki', task => 'show', additional => [ $data->{title} ] ),
                                content => Dicole::Widget::Text->new(
                                    text => $self->_msg('Edit'),
                                    class => 'events_show_page_edit',
                                ),
                            ),
                        ] ) : (),
                ]
            ),
            Dicole::Widget::Raw->new(
                raw => $content,
            ),
        ]
    );
    eval {
        my $t = CTX->lookup_action('commenting')->execute( 'get_comment_tree_widget', {
            object => $data->{page},
            comments_action => 'wiki_comments',
            disable_commenting => ( ! $data->{page}->moderator_lock && $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'comment' ) ) ? 0 : 1,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_comments' ),
        } );

        $self->tool->add_comments_widgets;

        $self->tool->Container->box_at( 1, 2 )->class( 'events_show_page_comments' );
        $self->tool->Container->box_at( 1, 2 )->name( $self->_msg('Comments') );
        $self->tool->Container->box_at( 1, 2 )->add_content(
            [ $t ]
        );
    } unless $data->{page}->hide_comments;

    $self->tool->add_footer_widgets( Dicole::Widget::Raw->new(
        raw => $self->generate_content( $params, { name => 'dicole_events::component_dialogs' } )
    ) );

    return $self->generate_tool_content;
}

sub _process_invite_consume {
    my ( $self, $invite, $user, $gid ) = @_;
    if ( $gid && ! Dicole::Utils::User->belongs_to_group( $user, $gid ) ) {
        CTX->lookup_action('groups_api')->e( add_user_to_group => {
            user_id => Dicole::Utils::User->ensure_id( $user ), group_id => $gid,
        } );
    }

    $self->_consume_invite( $invite, $user );

    if ( my $rsvp = CTX->request->param('rsvp') ) {
        return $self->redirect( $self->derive_url( task => 'rsvp', params => { rsvp => $rsvp } ) );
    }
    else {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Welcome! Please decide if you are going to join the event.' )
        );
        return $self->redirect( $self->derive_url );
    }
}

sub _process_generic_register {
    my ( $self, $type, $invite ) = @_;

    my $first_name = CTX->request->param('first_name');
    my $last_name = CTX->request->param('last_name');
    my $email = CTX->request->param('email');

    my $failure = 0;
    my $failure_message = '';

    if ( $failure ) {
        return $self->redirect( $self->derive_url(
            params => {
                $invite ? ( invite_code => $invite->secret_code ) : (),
                register_failure_message => $failure_message,
            }
        ) );
    }

    # TODO: If the area is not open, this requires
    # TODO: modification to the register code to allow this!

    if ( $type eq 'invite' ) {
        return $self->redirect( $self->derive_url(
            action => 'registering',
            task => 'register',
            params => {
                register => 1,
                first_name => $first_name,
                last_name => $last_name,
                email => $email,
                address2 => 1,
                $invite ? ( event_invite_code => $invite->secret_code ) : (),
                url_after_register => $self->derive_url(
                    params => { invite_code => $invite->secret_code },
                ),
            }
        ) );
    }
    elsif ( $type eq 'attend' ) {
        return $self->redirect( $self->derive_url(
            action => 'registering',
            task => 'register',
            params => {
                register => 1,
                first_name => $first_name,
                last_name => $last_name,
                email => $email,
                address2 => 1,
                $invite ? ( event_invite_code => $invite->secret_code ) : (),
                url_after_register => $self->derive_url(
                    params => { open_attend => 1 },
                ),
            }
        ) );
    }
    else {
        return $self->redirect( $self->derive_url(
            action => 'registering',
            task => 'register',
            params => {
                register => 1,
                first_name => $first_name,
                last_name => $last_name,
                email => $email,
                address2 => 1,
                $invite ? ( event_invite_code => $invite->secret_code ) : (),
                url_after_register => $self->derive_url,
            }
        ) );

    }
}

sub _gather_default_event_params {
    my ( $self, $submitted ) = @_;

    my $params = {};
    if ( $submitted ) {
        for my $attr ( qw(
            title
            abstract
            description
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
            event_state_name
            invite_policy_name
            users_can_invite

            begin_date
            begin_time
            end_date
            end_time

            reg_begin_date
            reg_begin_time
            reg_end_date
            reg_end_time
        ) ) {
            $params->{ $attr } = CTX->request->param( $attr );
        }

        $params->{tags_json} = CTX->request->param( 'tags' ) || '[]';
        $params->{tags_json_old} = '[]';

        for ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
            $params->{ $_ . '_name' } = CTX->request->param( $_ .'_name' );
        }
    }
    else {
        my $tomorrow_8 = Dicole::Utils::Date->epoch_to_epoch( time + 60*60*24, { hour => 8, minute => 0, second => 0 } );
        my $tomorrow_16 = Dicole::Utils::Date->epoch_to_epoch( time + 60*60*24, { hour => 16, minute => 0, second => 0 } );
        my $today_start = Dicole::Utils::Date->epoch_to_epoch( time, { hour => 0, minute => 0, second => 0 } );

        $params = {
            title => '',
            abstract => '',
            description => '',
            stream => '',
            feedback => '',
            freeform_title => '',
            freeeform_content => '',
            num_attenders => 0,
            max_attenders => 0,
            sos_med_tag => '',
            attend_info => '',
            require_phone => 0,
            require_invite => 0,
            location_name => '',
            latitude => undef,
            longitude => undef,
            event_state_name => $self->STATE_NAMES->{ $self->STATE_PRIVATE },
            invite_policy_name => $self->INVITE_NAMES->{ $self->INVITE_PLANNERS },
            users_can_invite => 0,

            logo_url => '',
            banner_url => '',
            tags_json => '[]',

            begin_date => $self->_epoch_to_date_string( $tomorrow_8 ),
            begin_time => $self->_epoch_to_time_string( $tomorrow_8 ),
            end_date => $self->_epoch_to_date_string( $tomorrow_16 ),
            end_time => $self->_epoch_to_time_string( $tomorrow_16 ),

            reg_begin_date => $self->_epoch_to_date_string( $today_start ),
            reg_begin_time => $self->_epoch_to_time_string( $today_start ),
            reg_end_date => $self->_epoch_to_date_string( $tomorrow_8 ),
            reg_end_time => $self->_epoch_to_time_string( $tomorrow_8 ),
        };

        for ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
            $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_ALL };
        }
        for ( qw/ show_stream show_feedback show_no show_waiting show_freeform show_imedia show_planners show_counter show_promo / ) {
            $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_NONE };
        }
        # HACK: evil :/
        if ( $self->param('domain') && $self->param('domain')->domain_name =~ /deski|onlinepressconference/ ) {
            for ( qw/ show_imedia show_planners show_counter / ) {
                $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_ALL };
            }
            for ( qw/ show_map show_tweets show_posts show_pages show_chat show_maybe show_no show_waiting / ) {
                $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_NONE };
            }
            for ( qw/ show_media / ) {
                $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_PLANNER };
            }
            for ( qw/ show_yes / ) {
                $params->{ $_ . '_name' } = $self->SHOW_NAMES->{ $self->SHOW_USER };
            }
        }
    }

    $params->{listing_url} = $self->derive_url( task => 'upcoming', additional => [] );

    return $params;
}

sub logo { shift->_serve_attachment_image( 'logo', { force_width => 113 } ) }

sub small_logo { shift->_serve_attachment_image( 'logo', { force_width => 50 } ) }

sub image { shift->_serve_attachment_image( 'banner', { max_width => 580 } ) }

sub image_wide { shift->_serve_attachment_image( 'banner', { max_width => 900 } ) }

sub _serve_attachment_image {
    my ( $self, $type, $params ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    CTX->lookup_action('attachment')->execute( serve => {
        attachment_id => $event->get( $type . '_attachment' ),
        thumbnail => 1,
        %$params,
    } );
}

sub invite {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_invite_to_event( $event );

    $self->_invite(
        $event,
        CTX->request->param('users'),
        CTX->request->param('emails'),
        CTX->request->param('as_planner'),
        CTX->request->param('greeting'),
        CTX->request->param('greeting_subject'),
    );

    $self->redirect( $self->_event_show_url( $event ) );
}

sub rsvp {
    my ( $self ) = @_;
    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );

    die "security error" unless $self->_current_user_can_rsvp_event( $event );
    die "security error" unless CTX->request->auth_user_id;

    my $info = CTX->request->param('attend_info');
    my $storable_info = $info;

    if ( $self->param('domain')->domain_name =~ /work\-dev|onlineitk/ ) {
        my $itkdata = { itk_info => $info };
        for my $key ( qw( itk_address itk_area itk_age itk_gender itk_education ) ) {
            $itkdata->{ $key } = CTX->request->param( $key );
        }
        $storable_info = Dicole::Utils::JSON->encode( $itkdata );
    }

    my $phone = CTX->request->param('phone');
    my $rsvp = $self->RSVP_BY_NAME->{ CTX->request->param('rsvp') };
    my $user = CTX->request->auth_user;

    unless ( $rsvp ) {
        if ( CTX->request->param('rsvp') eq 'open_yes' ) {
            $self->redirect( $self->_event_show_url( $event, { open_attend => 1 } ) );
        }
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Unknown error' )
        );
        $self->redirect( $self->_event_show_url( $event ) );
    }

    if ( $rsvp == $self->RSVP_YES ) {
        unless( $self->_event_has_seats_left( $event ) ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Sorry but the event is full' )
            );
            return $self->redirect( $self->_event_show_url( $event )  );
        }
        unless ( $self->_current_user_can_attend_event( $event ) ) {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'Sorry but attending requires an invite.' )
            );
            return $self->redirect( $self->_event_show_url( $event ) );
        }
        if ( $event->require_phone ) {
            my @phone_numbers = $phone =~ /(\d)/g;
            unless ( @phone_numbers > 5 ) {
                Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                    $self->_msg( 'Invalid phone number. Please try attending again.' )
                );
                return $self->redirect( $self->_event_show_url( $event ) );
            }
        }

        my $creator = Dicole::Utils::User->ensure_object( $event->creator_id );
        my $domain_host = Dicole::URL->get_domain_url( $event->domain_id );

        my $user_url_24h = $domain_host . $self->_event_show_url( $event, {
            dic => Dicole::Utils::User->temporary_authorization_key( $user, 24 ),
        } );

        my $creator_url_24h = $creator ? $domain_host . $self->_event_show_url( $event, {
            dic => Dicole::Utils::User->temporary_authorization_key( $creator, 24 ),
        } ) : '';

        my $attend_info_text = $info;
        my $attend_info_html = $info ? Dicole::Utils::HTML->text_to_html( $info ) : '';

        Dicole::Utils::Mail->send_localized_template_mail(
            user => $creator,
            domain_id => $event->domain_id,
            group_id => $event->group_id,

            template_key_base => 'events_organizer_confirmation',
            template_params => {
                user_name => Dicole::Utils::User->name( $user ),
                attend_info_text => $attend_info_text,
                attend_info_html => $attend_info_html,
                phone => $phone,
                email => $user->email,
                organization => CTX->request->param('organization'),
                organization_title => CTX->request->param('organization_title'),
                event_title => $event->title,
                url => $creator_url_24h,
            },
        ) if $creator;

        Dicole::Utils::Mail->send_localized_template_mail(
            user => $user,
            domain_id => $event->domain_id,
            group_id => $event->group_id,

            template_key_base => 'events_user_confirmation',
            template_params => {
                user_name => Dicole::Utils::User->name( $user ),
                event_title => $event->title,
                url => $user_url_24h,
            },
        ) unless $self->param('domain') && $self->param('domain')->domain_name =~ /deski|onlinepressconference/;

        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Attendance successfully registered.' )
        );
    }
    else {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Change of attendance successfully registered.' )
        );   
    }

    $self->_set_event_user_rsvp( $event, CTX->request->auth_user_id, $rsvp, $storable_info );

    if ( $phone ) {
        $user->phone( $phone );
        $user->save;
    }

    if ( CTX->request->param('organization') || CTX->request->param('organization_title') ) {
        CTX->lookup_action('networking_api')->e( user_profile_attributes => {
            domain_id => Dicole::Utils::Domain->guess_current_id,
            user_id => CTX->request->auth_user_id,
            attributes => {
                contact_organization => CTX->request->param('organization') || undef,
                contact_title => CTX->request->param('organization_title') || undef,
            },
        } );
    }

    $self->redirect( $self->_event_show_url( $event ) );
}

sub copy {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_manage_event( $event );

    my $params = {};
    for my $attr ( qw(
        domain_id
        group_id
        title
        abstract
        description
        stream
        feedback
        freeform_title
        freeform_content
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

        begin_date
        end_date
        reg_begin_date
        reg_end_date
    ) ) {
        $params->{ $attr } = $event->get( $attr );
    }

    $params->{title} = $params->{title} . ' ' . $self->_msg( '(Copy) (single)' );

    for ( $self->EVENT_SHOW_COMPONENT_NAMES ) {
        $params->{ $_ } = $event->get( $_ );
    }

    $params->{tags} = $self->_event_tags( $event );
    $params->{creator_id} = CTX->request->auth_user_id;

    my $new = CTX->lookup_action('events_api')->e( create_event => $params );

    for my $type ( 'logo_attachment', 'banner_attachment' ) {
        if ( my $att_id = $event->get( $type ) ) {
            my $a = CTX->lookup_action('attachments_api')->e( copy => {
                attachment_id => $att_id, object => $new,
                user_id => 0, group_id => $new->group_id, domain_id => $new->domain_id
            } );
            $new->set( $type, $a->id ) if $a;
        }
    }

    $new->save;

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Event copied' )
    );

    return $self->redirect( $self->_event_show_url( $new ) );
}

sub delete {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $self->_current_user_can_delete_event( $event );

    $self->_remove_event( $event, Dicole::Utils::Domain->guess_current_id, CTX->request->auth_user_id );

    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
        $self->_msg( 'Event deleted' )
    );

    return $self->redirect( $self->derive_url( task => 'detect', additional => [] ) );
}

sub mail_users {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    my $infos = $self->_fetch_valid_event_user_infos_using_request( $event );

    my $subject = CTX->request->param('subject');
    my $html = CTX->request->param('content');
    my $text = Dicole::Utils::HTML->html_to_text( $html );

    if ( scalar( @$infos ) ) {
        for my $info ( @$infos ) {
            my $myhtml = $html;
            my $mytext = $text;

            if ( CTX->request->param('add_login_link') ) {
                my $msg = $self->_msg('You can log in to the event page using this link (valid for one day)');
                my $link = Dicole::URL->get_server_url .
                    $self->_event_show_url( $event, {
                        dic => Dicole::Utils::User->authorization_key(
                            create_session => 1,
                            valid_hours => 24,
                            user => $info->{user_object},
                        )
                    } );
                $myhtml .= '<p><a href="'.$link.'">'.Dicole::Utils::HTML->encode_entities( $msg ).'</a></p>';
                $mytext .= "\n\n" . $msg . ":\n\n" . $link;
            }

            eval{ Dicole::Utils::Mail->send(
                user => $info->{user_object},
                subject => $subject,
                html => $myhtml,
                text => $mytext,
            ); };
            if ( $@ ) {
                get_logger(LOG_APP)->error("Error sending event invite mail: $@" );
            }
        }
    
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( 'Emails sent!' )
        );
    }

    return $self->redirect( $self->_event_show_url( $event ) );
}

sub _fake_tag_cloud_widget {
    my ($self, $prefix, $tags, $limit ) = @_;
    
    return Dicole::Widget::Text->new( text => $self->_msg('No tags.') ) unless @$tags;
    
    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => $prefix,
        limit => $limit,
    );
    $cloud->add_weighted_tags_array( $tags );
    return $cloud;
}

1;


package OpenInteract2::Action::DicoleEvents::UpcomingSummary;


use strict;
use base qw( Dicole::Task::DatedListSummary );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub _generate_item_content {
    my ( $self, $item, $users_hash ) = @_;
    
    my $title_widget = $self->_generate_item_title_widget( $item );

    my $logo = $item->logo_attachment ? Dicole::URL->create_from_parts(
        action => 'events',
        task => 'small_logo',
        target => $item->group_id,
        additional => [ $item->id ],
    ) : '';

    return Dicole::Widget::Vertical->new( contents => [
        $title_widget,
        $item->location_name,
    ] );
}

sub _generate_item_title_link {
    my ( $self, $item ) = @_;

    return Dicole::URL->create_from_parts(
        action => 'events',
        task => 'show',
        target => $item->group_id,
        additional => [
            $item->id,
            substr( Dicole::Utils::Text->utf8_to_url_readable( $item->title ), 0, 50 ),
        ],
    );
}

1;
