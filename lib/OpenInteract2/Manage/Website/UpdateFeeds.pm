package OpenInteract2::Manage::Website::UpdateFeeds;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use Time::HiRes qw( gettimeofday );

my $log = ();

use constant DEFAULT_MAX_ITEMS => 200;

sub get_name {
    return 'update_feeds';
}

sub get_brief_description {
    return "Updates feeds in the database";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        max_items => {
        	description => 'Maximum number of feed items per feed. '
                . 'Default is ' . DEFAULT_MAX_ITEMS,
        	is_required => 'no',
    	},
        interval => {
            description => 'Sets the program in daemon mode and '
                . 'updates the feeds based on the provided interval (seconds)',
            is_required => 'no',
        },
        ttl => {
            description => 'Kills the as soon as possible after '
                . 'given amount of seconds',
            is_required => 'no',
        },
    };
}

sub run_task {
    my ( $self ) = @_;

    CTX->{current_domain_id} = 0;

    my $script_start = time;
    
    my $max_items = $self->param( 'max_items' )
		|| CTX->server_config->{dicole}{feed_max_items}
		|| DEFAULT_MAX_ITEMS;

    my $ttl = $self->param( 'ttl' );

    my $action = CTX->lookup_action( "personal_feed_reader" );
    my $feeds = CTX->lookup_object('feeds');
    my $items = CTX->lookup_object('feeds_items');
    my $interval = $self->param( 'interval' );

    # Daemon interval loop
    my $fetch_time;
    while ( 1 ) {
        $fetch_time = time;

        my $feed_count = $feeds->fetch_count( {
            where => 'next_update < ?',
            value => [ $fetch_time ],
        } );

        $self->notify_observers(
            progress => "Starting to update $feed_count feeds [$fetch_time]"
        ) if $feed_count;

        my $feeds_iter = $feeds->fetch_iterator( {
            where => 'next_update < ?',
            value => [ $fetch_time ],
        } );

        my $count = 0;
        while ( $feeds_iter->has_next ) {
            
            last if $ttl && time > $script_start + $ttl;
            
            my $start = gettimeofday;
            $count++;
            my $feed = $feeds_iter->get_next;

            $self->notify_observers(
                progress => "Processing feed [$count of $feed_count] from " .
                    $feed->{url}
            );

            my $rss = eval{ $action->_if_feed_valid( $feed->{url}, 1 ) };

            if ( $@ ) {
                my $took = gettimeofday - $start;
                $took =~ s/(.*\.....).*/$1/;
                $log ||= get_logger( LOG_CONFIG );

                $feed->{failed_attempts}++;

                my $error = 'Error number ' . $feed->{failed_attempts} .
                    ' after '. $took .' seconds when updating feed ' .
                    '['. $feed->{url} .']:' . $@;

                $log->warn( $error );
                $self->notify_observers( progress => $error );

                $feed->{update_interval} ||= 3600;
                $feed->{next_update} = $fetch_time +
                    $feed->{update_interval} *
                    ( $feed->{failed_attempts} + 1 );
                $feed->save;

                next;
            }

            # Update feed object and add new feed items
            $action->_update_feed_object( $rss, $feed->{url} );
            $action->_add_feed_items( $feed, $rss, $fetch_time );

            # Remove old items that cross the max items limit
            my $excess_items = $items->fetch_group( {
                where => 'feed_id = ?',
                value => [ $feed->id ],
                order => 'date DESC, item_id DESC',
                limit => DEFAULT_MAX_ITEMS() . ',9999',
            } ) || [];
            $_->remove for @$excess_items;

            my $took = gettimeofday - $start;
            $took =~ s/(.*\.....).*/$1/;
            $self->notify_observers(
                progress => 
                    'Update for feed [' . $feed->{url} .']' .
                    " took $took seconds",
            );
        }

        my $now = time;
        if ( $feed_count ) {
            $self->notify_observers(
                progress => "Done updating [$now]"
            );
        }
        else {
            $self->notify_observers(
                progress => "Nothing to update [$now]"
            );
        }

        # Sets the program in daemon mode, looping every $interval minutes
        if ( $interval ) {
            my $now = time;
            my $sleep = $interval + $fetch_time - $now;
            
            if ( $ttl ) {
                my $after_sleep = $now;
                $after_sleep += $sleep if $sleep > 0;
                last if $after_sleep > $script_start + $ttl;
            }
            sleep( $sleep ) if $sleep > 0;
        }
        else {
            last;
        }
    }

}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
