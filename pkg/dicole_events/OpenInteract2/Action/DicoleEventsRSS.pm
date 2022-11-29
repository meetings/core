package OpenInteract2::Action::DicoleEventsRSS;

use strict;
use base qw( OpenInteract2::Action::DicoleEventsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use XML::FeedPP;

sub event_rss {
    my ( $self ) = @_;

    my $event = $self->_ensure_event_object_in_current_group( $self->param('event_id') );
    die "security error" unless $event;
    die "security error" unless $self->_current_user_can_see_event( $event );
    die "security error" unless $event->sos_med_tag;

    CTX->response->content_type( 'text/xml; charset=utf-8' );

    my @data = ();
    if ( $event->show_posts ) {
        push @data, @{
            CTX->lookup_action('blogs_api')->e( recent_entry_rss_params_with_tags => {
                domain_id => $event->domain_id,
                group_id => $event->group_id,
                tags => [ $event->sos_med_tag ],
                limit => 20,
            } );
        };
    }

    if ( $event->show_pages ) {
        push @data, @{
            CTX->lookup_action('wiki_api')->e( recent_change_rss_params_with_tags => {
                domain_id => $event->domain_id,
                group_id => $event->group_id,
                tags => [ $event->sos_med_tag ],
                limit => 20,
            } );
        };
    }
    if ( $event->show_media ) {
        push @data, @{
            CTX->lookup_action('presentations_api')->e( recent_object_rss_params_with_tags => {
                domain_id => $event->domain_id,
                group_id => $event->group_id,
                tags => [ $event->sos_med_tag ],
                limit => 20,
            } );
        };
    }

    my @sorted_data = sort { $b->{pubDate} <=> $a->{pubDate} } @data;
    
    my $feed = XML::FeedPP::RSS->new(
        link => Dicole::URL->get_server_url . $self->_event_show_url( $event ),
        language => 'en',
        title => Dicole::Utils::Text->ensure_utf8( CTX->server_config->{dicole}{title} . ' - ' . $event->title ),
        pubDate => time(),
    );
    
    for my $data ( splice( @sorted_data, 0, 20 ) ) {
        $feed->add_item( %$data )
    }

    return $feed->to_string;
}

sub upcoming {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $order = 'dicole_events_event.begin_date asc';
    my $where = '( dicole_events_event.begin_date > ? OR dicole_events_event.end_date > ? ) AND ( dicole_events_event.event_state = ?  )';
    my $value = [ time(), time(), $self->STATE_PUBLIC() ];

    my $events = $self->_generic_events(
        tag => $self->param('tag') || undef,
        group_id => $gid,
        order => $order,
        where => $where,
        value => $value,
        limit => 50,
    );

    my $feed = XML::FeedPP::RSS->new(
        link => Dicole::URL->get_server_url . $self->derive_url( task => 'events', task => 'upcoming', additional => [] ),
        language => $self->param('language') || 'en',
        title => $self->_msg('Upcoming events'),
        pubDate => time(),
    );

    for my $event ( @$events ) {
        my $link = Dicole::URL->get_server_url . $self->_event_show_url( $event );
        my $description = $event->abstract;

        if ( CTX->request->param('use_euro_dates_as_description') ) {
            my $bdt = Dicole::Utils::Date->epoch_to_datetime( $event->begin_date, undef, $self->param('language') ); 
            my $edt = Dicole::Utils::Date->epoch_to_datetime( $event->end_date, undef, $self->param('language') );

            my $d = $bdt->day . '.' . $bdt->month . '.';

            if ( $bdt->month != $edt->month ) {
                $d = $d . '-' . $edt->day . '.' . $edt->month . '.';
            }
            elsif ( $bdt->day != $edt->day ) {
                $d = $bdt->day . '.-' .  $edt->day . '.' . $edt->month . '.';  
            } 
            $description = $d;
        }

        my %data = (
            title => $event->title,
            link => $link,
            guid => $link, 
            pubDate => $event->begin_date,
            description => $description,
        );

        $feed->add_item( %data );
    }

    return $feed->to_string;
}

1;

