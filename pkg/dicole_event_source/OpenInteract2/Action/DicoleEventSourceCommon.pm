package OpenInteract2::Action::DicoleEventSourceCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _form_event_coordinates {
    my ( $self, $event ) = @_;

    return [ split /\s*,\s*/, $event->coordinates ];
}

sub _form_event_topics {
    my ( $self, $event ) = @_;

    my @topics = split /\s*,\s*/, $event->topics;

    for my $type ( split /\s*,\s*/, $event->classes ) {
        push @topics, 'class:' . $type;
    }

    for my $tag ( split /\s*,\s*/, $event->tags ) {
        push @topics, 'tag:' . $tag;
    }

    for my $i ( split /\s*,\s*/, $event->interested ) {
        push @topics, 'i:' . $i;
    }

    push @topics, 'author:' . $event->author if $event->author;
    push @topics, 'user:' . $event->user_id if $event->user_id;
    push @topics, 'group:' . $event->group_id if $event->group_id;
    push @topics, 'domain:' . $event->domain_id if $event->domain_id;

    return \@topics;
}

sub _form_event_secure {
    my ( $self, $event ) = @_;

    my @secure = ();
    for my $secs ( split /\s*,\s*/, $event->secure ) {
        my @needed = split /\s*\+\s*/, $secs;
        push @secure, \@needed;
    }

    return \@secure;
}

1;

