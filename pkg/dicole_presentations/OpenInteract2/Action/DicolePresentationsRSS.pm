package OpenInteract2::Action::DicolePresentationsRSS;

use strict;
use base qw( OpenInteract2::Action::DicolePresentationsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use XML::FeedPP;

sub featured {
    my ( $self ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    
    my $entries = $self->_generic_preses(
        tag => $tag,
        group_id => $gid,
        order => 'dicole_presentations_prese.featured_date desc',
        limit => 20,
        where => 'dicole_presentations_prese.featured_date > 0',
    );
    
    return $self->_entries_to_rss( $entries, $self->_msg( 'Featured media' ) );
}

sub new {
    my $self = shift;
    return $self->_generic_listing(
        $self->_msg( 'New media' ),
        'dicole_presentations_prese.creation_date desc',
    );
}

sub top {
    my $self = shift;
    return $self->_generic_listing(
        $self->_msg( 'Best rated media' ),
        'dicole_presentations_prese.rating desc, dicole_presentations_prese.creation_date desc',
    );
}

sub _generic_listing {
    my ( $self, $title, $order ) = @_;
    
    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    
    if ( $self->task eq 'new' && !$tag && $self->param('new_feed_redirect') ) {
        return $self->redirect( $self->param('new_feed_redirect') );
    }

    my $entries = $self->_generic_preses(
        tag => $tag,
        group_id => $gid,
        order => $order,
        limit => 20,
    );
    
    return $self->_entries_to_rss( $entries, $title );
}

sub _entries_to_rss {
    my ( $self, $entries, $title ) = @_;

    CTX->response->content_type( 'text/xml; charset=utf-8' );
    
    my $surl = Dicole::URL->get_server_url;

    my $feed = XML::FeedPP::RSS->new(
        link => $surl . $self->derive_url( action => 'presentations_feed' ),
        language => 'en',
        title => Dicole::Utils::Text->ensure_utf8( CTX->server_config->{dicole}{title} . ' - ' . $title ),
        pubDate => time(),
    );
    
    for my $entry ( @{ $self->_gather_data_for_objects( $entries ) } ) {
        $feed->add_item( %{ $self->_object_data_to_rss_params( $entry ) } );
    }

    return $feed->to_string;
}

1;

