package OpenInteract2::Action::DicolePresentationsRaw;

use strict;
use base qw( OpenInteract2::Action::DicolePresentationsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::HTTP;
use Dicole::Utils::Data;

sub box_redirect {
    my ( $self ) = @_;

    my $prese_id = $self->param('prese_id');
    my $checksum = $self->param('checksum');

    die 'security error' unless lc( $checksum ) eq lc( $self->_generate_sec( $prese_id ) );

    my $prese = CTX->lookup_object('presentations_prese')->fetch( $prese_id );

    my $pa = Dicole::Utils::Data->get_note( new_box_view_document_attachment => $prese );
    my $refresh = 0;

    if ( Dicole::Utils::Data->get_note( new_box_view_document_id => $prese ) && ! ( $pa && ( $pa != $prese->attachment_id ) ) ) {
        my $session = $self->_get_session_for_box_prese( $prese );
        if ( $session ) {
            return CTX->response->redirect( $session );
        }
        else {
            $refresh = 1;
        }
    }

    $self->_send_prese_to_box( $prese, undef, undef, $refresh );

    return '<html><body><center><h1>Processing preview...</h1></center><script>setTimeout( function() { window.location.reload(); }, 1000 );</script></body></html>';
}

sub box_preview_redirect {
    return '<html><body><center><h1>No preview for this document type</h1></center></body></html>';
}

1;
