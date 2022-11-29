package OpenInteract2::Action::DicoleBlogsVote;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper;

$OpenInteract2::Action::DicoleBlogsVote::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub promote { return _promote( @_, 10 ); }
sub demote { return _promote( @_, -10 ); }

sub _promote {
    my ( $self, $points ) = @_;
    
    die 'security error' unless CTX->request->auth_user_id;
    
    my $entry = $self->_fetch_entry( $self->param('entry_id') );

    my $vote = CTX->lookup_object( 'blogs_promotion' )->new;
    $vote->group_id( $self->param('target_group_id') );
    $vote->date( time );
    $vote->entry_id( $entry->id );
    $vote->user_id( CTX->request->auth_user_id );
    $vote->points( $points );
    $vote->save;
    
    my $my_votes = CTX->lookup_object( 'blogs_promotion' )->fetch_group( {
        where => 'user_id = ? and entry_id = ?',
        value => [ CTX->request->auth_user_id, $entry->id ],
        order => 'date desc',
    } ) || [];
    
    shift @$my_votes;
    $_->remove for @$my_votes;
    
    # count the total points
    my $votes = CTX->lookup_object( 'blogs_promotion' )->fetch_group( {
        where => 'entry_id = ?',
        value => [ $entry->id ],
        order => 'date desc',
    } ) || [];
    
    my $total = 0;
    for my $vote ( @$votes ) {
        $total += $vote->points;
    }
    
    $entry->points( $total );
    $entry->save;
    
    my $widget = CTX->lookup_action('blogs_voting')->execute('promote_widget', {
        entry => $entry,
        target_group_id => $self->param('target_group_id'),
        user_id => CTX->request->auth_user_id,
    } );
    
    return {
        messages_html => $widget->generate_content,
        total_points => $total,
    };
}

sub rate {
    my ( $self ) = @_;
    
    die 'security error' unless CTX->request->auth_user_id;
    
    my $entry = $self->_fetch_entry( $self->param('entry_id') );
    my $new_rating = $self->param('rating');
    die 'security_error' unless scalar( grep { $new_rating == $_} (1..5) );

    my $vote = CTX->lookup_object( 'blogs_rating' )->new;
    $vote->group_id( $self->param('target_group_id') );
    $vote->date( time );
    $vote->entry_id( $entry->id );
    $vote->user_id( CTX->request->auth_user_id );
    $vote->rating( $new_rating );
    $vote->save;
    
    my $my_votes = CTX->lookup_object( 'blogs_rating' )->fetch_group( {
        where => 'user_id = ? and entry_id = ?',
        value => [ CTX->request->auth_user_id, $entry->id ],
        order => 'date desc',
    } ) || [];
    
    shift @$my_votes;
    $_->remove for @$my_votes;
    
    # count the total points
    my $votes = CTX->lookup_object( 'blogs_rating' )->fetch_group( {
        where => 'entry_id = ?',
        value => [ $entry->id ],
        order => 'date desc',
    } ) || [];
    
    my $total = 0;
    for my $vote ( @$votes ) {
        $total += $vote->rating;
    }
    my $rating = $total / scalar( @$votes );
    $rating = int( $rating * 100 / 5 );
    
    $entry->rating( $rating );
    $entry->save;
    
    my $widget = CTX->lookup_action('blogs_voting')->execute('rate_widget', {
        entry => $entry,
        target_group_id => $self->param('target_group_id'),
        user_id => CTX->request->auth_user_id,
    } );
    
    return $widget ? { messages_html => $widget->generate_content } : 0;
}


sub _fetch_entry {
    my ( $self, $entry_id ) = @_;
    
    my $entry = CTX->lookup_object( 'blogs_entry' )->fetch( $entry_id );
    die 'security error' unless $entry && $entry->group_id == $self->param('target_group_id');
    return $entry;
}