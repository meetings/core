package OpenInteract2::Action::DicoleBlogsVoting;

# TODO: Rerfactor this so that it is basically all inherited from a lib.

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper;

$OpenInteract2::Action::DicoleBlogsVoting::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

sub rate_widget {
    my ( $self ) = @_;
    
    my $entry = $self->param( 'entry' );
    my $rating = $entry->rating || 0;
    my $entry_id = $entry->id;
    my $group_id = $entry->group_id;
    my $disabled = $self->param( 'rating_disabled' ) ? ' blogs_rating_disabled' : '';

    my %links = ();
    for my $num ( 1..5 ) {
        $links{ $num } = $self->param( 'rating_disabled' ) ? '#' : Dicole::URL->from_parts(
            action => 'blogs_vote', task => 'rate', target => $group_id,
            additional => [ $entry_id, $num ],
        );
    }

    my $raw = <<RAW;
<ul class="star-rating blogs_rate_link_id_EID_container blogs_rate_linksDISABLED" id="blogs_rate_links_EID">
<li class="current-rating" style="width:CURRENT%;"></li>
<li><a href="VOTEURL1" title="1 star out of 5" class="blogs_rate_link_EID blogs_rate_link blogs_rate_link_id_EID one-star" onclick="return false;"></a></li>
<li><a href="VOTEURL2" title="2 stars out of 5" class="blogs_rate_link_EID blogs_rate_link blogs_rate_link_id_EID two-stars" onclick="return false;"></a></li>
<li><a href="VOTEURL3" title="3 stars out of 5" class="blogs_rate_link_EID blogs_rate_link blogs_rate_link_id_EID three-stars" onclick="return false;"></a></li>
<li><a href="VOTEURL4" title="4 stars out of 5" class="blogs_rate_link_EID blogs_rate_link blogs_rate_link_id_EID four-stars" onclick="return false;"></a></li>
<li><a href="VOTEURL5" title="5 stars out of 5" class="blogs_rate_link_EID blogs_rate_link blogs_rate_link_id_EID five-stars" onclick="return false;"></a></li>
</ul>
RAW
    $raw =~ s/CURRENT/$rating/g;
    $raw =~ s/GID/$group_id/g;
    $raw =~ s/EID/$entry_id/g;
    $raw =~ s/DISABLED/$disabled/g;
    $raw =~ s/VOTEURL$_/$links{$_}/g for (1..5);
    return Dicole::Widget::Raw->new( raw => $raw );
}

sub promote_widget {
    my ( $self ) = @_;
    
    my $entry = $self->param( 'entry' );
    
    my $my_votes = CTX->lookup_object( 'blogs_promotion' )->fetch_group( {
        where => 'user_id = ? and entry_id = ?',
        value => [ $self->param('user_id'), $entry->id ],
        order => 'date desc',
    } ) || [];
    my $vote = pop @$my_votes;
    my $points = $vote ? $vote->points : 0;
    my $class_append = '';
    $class_append = ' promote_promote_selected' if $points > 0;
    $class_append = ' promote_demote_selected' if $points < 0;
    
    return Dicole::Widget::Container->new(
        class => 'blogs_promote_links' . $class_append,
        id => 'blogs_promote_links_' . $entry->id,
        contents => [
            Dicole::Widget::Hyperlink->new(
                link => Dicole::URL->from_parts(
                    action => 'blogs_vote',
                    task => 'promote',
                    target => $self->param('target_group_id'),
                    additional => [ $entry->id ],
                ),
                class => 'blogPostPromote blogs_promote_promote blogs_promote_promote_id_' . $entry->id,
                id => 'blogs_promote_promote_' . $entry->id,
                content => $self->_msg( 'Promote' ),
                disable_click => 1,
            ),
            Dicole::Widget::Hyperlink->new(
                link => Dicole::URL->from_parts(
                    action => 'blogs_vote',
                    task => 'demote',
                    target => $self->param('target_group_id'),
                    additional => [ $entry->id ],
                ),
                class => 'blogPostDemote blogs_promote_demote blogs_promote_demote_id_' . $entry->id,
                id => 'blogs_promote_demote_' . $entry->id,
                content => $self->_msg( 'Demote' ),
                disable_click => 1,
            ),
        ]
    );
}

