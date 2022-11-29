package OpenInteract2::Action::DicoleEventSourceAPI;

use strict;

use base qw( OpenInteract2::Action::DicoleEventSourceCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Security qw( :target );

sub add_event {
    my ( $self ) = @_;

    my $r = CTX->request;
    my $ia = CTX->controller ? CTX->controller->initial_action : undef;

    my $e = CTX->lookup_object('event_source_event')->new;

    my $version = $self->param('version') || 1;
    my $event_type = $self->param('event_type') || '';

    my $author = $self->param('author');
    $author = $r ? $r->auth_user_id || 0 : 0 unless defined( $author );
    $author = ref( $author ) ? $author->id : $author;

    my $user_id = $self->param('target_user') || $self->param('user_id');
    $user_id = $ia ? $ia->param('target_user_id') || 0 : 0 unless defined( $user_id );
    $user_id = ref( $user_id ) ? $user_id->id : $user_id;

    my $group_id = $self->param('target_group') || $self->param('group_id');
    $group_id = $ia ? $ia->param('target_group_id') || 0 : 0 unless defined( $group_id );

    my $domain_id = $self->param('target_domain') || $self->param('domain_id');
    $domain_id = $ia ? $ia->param('domain_id') || 0 : 0 unless defined( $domain_id );

    my $timestamp = $self->param('timestamp');
    $timestamp = time unless defined( $timestamp );

    my $coordinates = scalar( $self->param('coordinates') ) || [];
    $coordinates = [ $coordinates ] if $coordinates && ref($coordinates) ne 'ARRAY';
    my $classes = scalar( $self->param('classes') ) || [];
    $classes = [ $classes ] if $classes && ref($classes) ne 'ARRAY';
    my $interested = scalar( $self->param('interested') ) || [];
    $interested = [ $interested ] if $interested && ref($interested) ne 'ARRAY';
    my $tags = scalar( $self->param('tags') ) || [];
    $tags = [ $tags ] if $tags && ref($tags) ne 'ARRAY';
    my $topics = scalar( $self->param('topics') ) || [];
    $topics = [ $topics ] if $topics && ref($topics) ne 'ARRAY';
    my $secure = scalar( $self->param('secure_tree') ) || [];
    $secure = [ $secure ] if $secure && ref($secure) ne 'ARRAY';

    my $data = scalar( $self->param('data') ) || {};
    $data = {} if $data && ref($data) ne 'HASH';

    for my $kv (
        [ timestamp => $timestamp ],
        [ coordinates => $coordinates ],
        [ author_user_id => $author ],
        [ target_user_id => $user_id ],
        [ target_group_id => $group_id ],
        [ event_type => $event_type ],
    ) {
        next if defined( $data->{ $kv->[0] } );
        next if ! $kv->[1];
        next if ( ref($kv->[1]) && ref($kv->[1]) eq 'ARRAY' && ! scalar( @{ $kv->[1]} ) );
        $data->{ $kv->[0] } = $kv->[1];
    }

    my %classes = map { $_ => 1 } @$classes;
    push @$classes, $event_type unless $classes{$event_type};

    $e->version( $version );
    $e->event_type( $event_type );
    $e->author( $author );
    $e->user_id( $user_id );
    $e->group_id( $group_id );
    $e->domain_id( $domain_id );
    $e->timestamp( $timestamp );
    $e->updated( time );
    $e->coordinates(  join ",", @$coordinates );
    $e->classes( join ",", @$classes );
    $e->interested( join ",", @$interested );
    $e->tags( join ",", @$tags );
    $e->topics( join ",", @$topics );
    $e->secure( join ",", map( { join( '+', @$_ ) } @$secure ) );
    $e->payload( Dicole::Utils::JSON->encode( $data ) );

    $e->save;

    $self->nudge_gateways;
}

sub nudge_gateways {
    my ($self) = @_;

    my $gateways = CTX->lookup_object('event_source_gateway')->fetch_group( {
        order => 'last_update desc',
    } ) || [];

    for my $gateway (@$gateways) {
        my $url = $gateway->gateway or next;

        system "curl -s '$url' 2>&1 >/dev/null &";
    }
}

sub update_gateways {
    my ( $self ) = @_;

    my $safety_time = 15;
    my $sleep = 0;

    print "Started.." . "\n";

    my $not_safely_updated_after = time - $safety_time;
    my $pushed_events = {};

    while (1) {

        sleep 1 if $sleep;
        $sleep = 1;

        my $new_events = CTX->lookup_object('event_source_event')->fetch_group( {
            where => 'updated > ? AND ' . Dicole::Utils::SQL->column_not_in(
                event_id => [ keys %$pushed_events ]
            ),
            value => [ $not_safely_updated_after ],
            order => 'updated asc',
        } );

        next unless scalar( @$new_events );

        my $last_event_updated = $new_events->[-1]->updated;
        my $safely_updated_before = $last_event_updated - $safety_time;

        $not_safely_updated_after = $safely_updated_before - 1;

        $pushed_events->{ $_->id } = $_->updated for @$new_events;

        for my $id ( keys %$pushed_events ) {
            delete $pushed_events->{ $id } if $pushed_events->{ $id } < $safely_updated_before;
        }

        my $params = {
            secret => CTX->server_config->{dicole}{event_source_sync_secret},
            events => [ map { {
                version => $_->version,
                id => $_->id,
                timestamp => $_->timestamp,
                coordinates => $self->_form_event_coordinates( $_ ),
                topics => $self->_form_event_topics( $_ ),
                security => $self->_form_event_secure( $_ ),
                data => Dicole::Utils::JSON->decode( $_->payload ),
            } } @$new_events ],
        };

        my $gateways = CTX->lookup_object('event_source_gateway')->fetch_group( {
            order => 'last_update desc',
        } ) || [];
 
        for my $gateway ( @$gateways ) {

            next unless time < $gateway->last_update + 60*20;

            my $error = '';

            eval {
                my $res = Dicole::Utils::HTTP->json_api_call( $gateway->gateway, $params, 5 );

#                    print "result: " . Data::Dumper::Dumper( $res );
                if ( $res->{error} && $res->{error}->{code} == 101 ) {
                    $error = 'invalid credentials';
                    print $gateway->gateway . ": invalid credentials for gateway\n";
                }
                elsif ( ! $res->{result} ) {
                    $error = $res->{error}->{message};
                    print $gateway->gateway . ": http error -> ". $error ."\n";
                }
                else {
                    print $gateway->gateway . "great success!\n";
                    $sleep = 0;
                }
            };

            if ( $@ ) {
                print $gateway->gateway . "epic failure: " . $@ . $/;
                $error = $@;
            }

            if ( $error ) {
                $gateway->last_error( time . ': ' . $error );
                $gateway->save;
            }
        }
     }
}

sub update_subs {
    my ( $self ) = @_;

    my $sleep = 1;
    my $error_retry = {};

    print "Started.." . "\n";
    while (1) {

        sleep 1 if $sleep;
        $sleep = 1;

        my $sessions = CTX->lookup_object('event_source_sync_subscription')->fetch_group || [];

        for my $session ( @$sessions ) {

            if ( $session->error_count ) {
                my $next_time = $error_retry->{ $session->session_key } + ( 2 ** $session->error_count );
                next unless time > $next_time;
            }

            my $events = CTX->lookup_object('event_source_event')->fetch_group( {
                where => 'event_id > ?',
                value => [ $session->last_confirmed_event ],
                order => 'event_id asc',
                limit => 500,
            } );

            my $last_event = $events->[-1];

            if ( $last_event ) {
                print "updating session " . $session->id . " up to " .  $last_event->id . $/;

                eval {
                    my $res = Dicole::Utils::HTTP->json_api_call( $session->gateway, {
                        session => $session->session_key,
                        events => [ map { {
                            version => $_->version,
                            id => $_->id,
                            updated => $_->updated,
                            timestamp => $_->timestamp,
                            coordinates => $self->_form_event_coordinates( $_ ),
                            topics => $self->_form_event_topics( $_ ),
                            security => $self->_form_event_secure( $_ ),
                            data => Dicole::Utils::JSON->decode( $_->payload ),
                        } } @$events ],
                    } );

#                    print "result: " . Data::Dumper::Dumper( $res );
                    if ( $res->{error} && $res->{error}->{code} == 401 ) {
                        $session->remove;
                        $session = undef;
                        print "session error. session removed!\n";
                    }
                    elsif ( ! $res->{result} ) {
                        die $res->{error}->{message};
                    }
                    else {
                        print "great success!\n";
                    }
                    $sleep = 0;
                };

                if ( $@ ) {
                    print "epic failure: " . $@ . $/;
                    $sleep = 0;
                }

                next unless $session;
    
                if ( $@ ) {
                    get_logger(LOG_APP)->warn( "http push error while updating sync: $@" );
                    $session->last_update_error( time() . ': ' . $@ );
                    $session->error_count( $session->error_count + 1 );
                    $error_retry->{ $session->session_key } = time();
                }
                else {
                    $session->last_confirmed_event( $last_event->id );
    
                    if ( $session->error_count ) {
                        $session->error_count( 0 );
#                        $session->last_update_error( '' );
                    }
                }
    
                $session->save;
            }
        }
    }
}
1;
