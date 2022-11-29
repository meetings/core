package OpenInteract2::Action::DicoleDraftAttachmentCommon;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _fetch_valid_draft_from_params {
    my ( $self ) = @_;

    my $dac = CTX->lookup_object('draft_container')->fetch( $self->param('draft_id') );
    die unless $dac && ( ( ! $dac->session_id ) || ( $dac->session_id eq $self->_fetch_session_id ) );
    return $dac;
}

sub _fetch_session_id {
    my ( $self ) = @_;
    return eval { CTX->request->session->id } || '';
}

sub _init {
    my ( $self, $session_id, $domain_id ) = @_;

    my $dac = CTX->lookup_object('draft_container')->new;
    $dac->domain_id( $domain_id );
    $dac->session_id( $session_id );
    $dac->creation_time( time() );
    $dac->save;
}

sub _draft_return_parameters_for_sizes {
    my ( $self, $dac, $size_params, $preview_image ) = @_;

    my $return = {
         draft_id => $dac->id
    };

    if ( $size_params ) {
        for my $dimension ( qw( width height ) ) {
            if ( $size_params->{ $dimension } && $size_params->{ $dimension } < 0 ) {
                $size_params->{ 'max_' . $dimension } ||= $size_params->{ $dimension };
                $size_params->{ $dimension } = 0;
            }
        }

        my @size_params = map { $size_params->{ $_ } || 0 } ( qw( width height max_width max_height ) );

        $return->{draft_thumbnail_url} = Dicole::URL->get_server_url . $self->derive_url(
            action => 'draft_attachment_raw', task => 'thumbnail',
            target => 0, domain_id => $dac->domain_id,
            additional => [ $dac->id, @size_params ],
        );
    }

    $return->{draft_preview_image_url} = Dicole::URL->get_server_url . $self->derive_url(
        action => 'draft_attachment_raw', task => 'preview_image',
        target => 0, domain_id => $dac->domain_id,
        additional => [ $dac->id ],
    ) if $preview_image;


    return $return;
}

1;
