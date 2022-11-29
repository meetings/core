package OpenInteract2::Action::DicoleDraftAttachmentAPI;

use strict;

use base qw( OpenInteract2::Action::DicoleDraftAttachmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub create {
    my ( $self ) = @_;

    my $dac = $self->_init( $self->param('session_id'), $self->param('domain_id' ) );

    eval {
        my $filename = $self->param('filename');
        if ( $self->param('bits') ) {
            CTX->lookup_action('attachment')->execute( store_from_bits => {
                    filename => $filename,
                    bits => scalar( $self->param('bits') ),
                    object => $dac,
                    group_id => 0,
                    user_id => 0,
                } ); 
        }
        else {
            CTX->lookup_action('attachment')->execute( store_from_bits => {
                    filename => $filename,
                    base64_data => scalar( $self->param('bits_base64') ),
                    object => $dac,
                    group_id => 0,
                    user_id => 0,
                } ); 
        }   
    };

    get_logger(LOG_APP)->error($@) if $@;

    return $self->_draft_return_parameters_for_sizes( $dac );
}

sub reattach_last_attachment {
    my ( $self ) = @_;

    my $dac = $self->_fetch_valid_draft_from_params;

    return undef unless $dac;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $dac,
        domain_id => $dac->domain_id,
        group_id => 0,
        user_id => 0,
    } );

    my $a = pop @$as;

    return undef unless $a;

    CTX->lookup_action('attachments_api')->e( reattach => {
        attachment => $a,
        object => $self->param('object'),
        object_id => $self->param('object_id'),
        object_type => $self->param('object_type'),
        user_id => $self->param('user_id'),
        group_id => $self->param('group_id'),
        domain_id => $dac->domain_id,
    } );

    return $a->id;
}

sub fetch_last_attachment {
    my ( $self ) = @_;

    my $dac = $self->_fetch_valid_draft_from_params;

    return undef unless $dac;

    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $dac,
        domain_id => $dac->domain_id,
        group_id => 0,
        user_id => 0,
    } );

    return pop @$as;
}

1;
