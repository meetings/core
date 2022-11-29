package OpenInteract2::Action::DicoleDraftAttachmentJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleDraftAttachmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );
use URI;

sub store {
    my ( $self ) = @_;

    my $dac = $self->_create_new_draft_container;

    eval {
        CTX->lookup_action('attachment')->execute( store_from_request_upload => {
            upload_name => 'Filedata',
            object => $dac,
            group_id => 0,
            user_id => 0,
        } );
    };

    return $self->_draft_return_parameters( $dac );
}

sub url_store {
    my ( $self ) = @_;

    my $dac = $self->_create_new_draft_container;

    eval {
        my $url = CTX->request->param('url');
        my $image_data = Dicole::Utils::HTTP->get( $url );
        my $filename = CTX->request->param('filename') || ( URI->new( $url)->path_segments )[-1];
        
        CTX->lookup_action('attachment')->execute( store_from_bits => {
            filename => $filename,
            bits => $image_data,
            object => $dac,
            group_id => 0,
            user_id => 0,
        } );
    };
    return $self->_draft_return_parameters( $dac );
}

sub fileapi {
    my ( $self ) = @_;

    my $dac = $self->_create_new_draft_container;

    eval {
        my $filename = Dicole::Utils::Text->ensure_utf8(CTX->request->cgi->http('X-File-Name'));
        my $data = CTX->request->post_body;
        CTX->lookup_action('attachment')->execute( store_from_bits => {
            filename => $filename,
            bits => $data,
            object => $dac,
            group_id => 0,
            user_id => 0,
        } );
    };

    get_logger(LOG_APP)->error($@) if $@;

    return $self->_draft_return_parameters( $dac );
}

sub store_base64 {
    my ( $self ) = @_;

    my $dac = $self->_create_new_draft_container;

    eval {
        my $filename = Dicole::Utils::Text->ensure_utf8( CTX->request->param('filename') );
        my $data = CTX->request->post_body;
        CTX->lookup_action('attachment')->execute( store_from_base64 => {
            filename => $filename,
            base64_data => CTX->request->param('base64_data'),
            object => $dac,
            group_id => 0,
            user_id => 0,
        } );
    };

    get_logger(LOG_APP)->error($@) if $@;

    return $self->_draft_return_parameters( $dac );
}

sub _create_new_draft_container {
    my ( $self ) = @_;

    return $self->_init( $self->_fetch_session_id, Dicole::Utils::Domain->guess_current_id );
}

sub _draft_return_parameters {
    my ( $self, $dac ) = @_;

    my $size_params = { map { $_ => CTX->request->param( $_ ) } ( qw( width height max_width max_height ) ) };

    return $self->_draft_return_parameters_for_sizes(
        $dac, CTX->request->param('no_thumbnail') ? undef : $size_params, CTX->request->param('preview_image')
    );
}

1;
