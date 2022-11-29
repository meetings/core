package OpenInteract2::Action::DicoleBlogsRSS;

use strict;
use base qw( OpenInteract2::Action::DicoleBlogsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use XML::FeedPP;

sub featured {
    my ( $self ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    
    my $entries = $self->_generic_entries(
        tag => $tag,
        group_id => $gid,
        order => 'dicole_blogs_entry.featured desc',
        limit => 20,
        where => 'dicole_blogs_entry.featured > 0',
    );
    
    return $self->_entries_to_rss( $entries, $self->_msg( 'Featured posts' ) );
}

sub new {
    my $self = shift;
    return $self->_generic_listing(
        $self->_msg( 'New posts' ),
        'dicole_blogs_entry.date desc',
    );
}
sub rated {
    my $self = shift;
    return $self->_generic_listing(
        $self->_msg( 'Best rated posts' ),
        'dicole_blogs_entry.rating desc, dicole_blogs_entry.date desc',
    );
}

sub promoted {
    my $self = shift;
    return $self->_generic_listing(
        $self->_msg( 'Most promoted posts' ),
        'dicole_blogs_entry.points desc, dicole_blogs_entry.date desc',
    );
}

sub _generic_listing {
    my ( $self, $title, $order ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $sid = $self->param('seed_id');
    
    if ( $self->task eq 'new' && !$tag && !$sid && $self->param('new_feed_redirect') ) {
        if ( $self->name ne 'blogs_feed_direct' ) {
            return $self->redirect( $self->param('new_feed_redirect') );
        }
    }

    my $entries = $self->_generic_entries(
        tag => $tag,
        seed_id => $sid,
        group_id => $gid,
        order => $order,
        limit => 20,
    );
    
    return $self->_entries_to_rss( $entries, $title );
}

sub _entries_to_rss {
    my ( $self, $entries, $title ) = @_;

    CTX->response->content_type( 'text/xml; charset=utf-8' );
    
    my @datas = map { eval{ $self->_entry_data( $_ ) } || () } @$entries;
    
    my $feed = XML::FeedPP::RSS->new(
        link => Dicole::URL->get_server_url . $self->derive_url( action => 'blogs_feed' ),
        language => 'en',
        title => Dicole::Utils::Text->ensure_utf8( CTX->server_config->{dicole}{title} . ' - ' . $title ),
        pubDate => time(),
    );
    
    for my $data ( @datas ) {
        $feed->add_item( %{ $self->_entry_data_to_rss_params( $data ) } )
    }

    return $feed->to_string;
}

1;
