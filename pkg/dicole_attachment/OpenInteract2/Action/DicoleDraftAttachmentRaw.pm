package OpenInteract2::Action::DicoleDraftAttachmentRaw;

use strict;

use base qw( OpenInteract2::Action::DicoleDraftAttachmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

sub thumbnail {
    my ( $self ) = @_;

    my $dac = $self->_fetch_valid_draft_from_params;
    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $dac,
        group_id => 0,
        user_id => 0,
    } );

    my $a = pop @$as;

    unless ( $a ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        $self->redirect( '/' );
    }

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        group_id => 0,
        user_id => 0,
        thumbnail => 1,
        force_width => $self->param('force_width'),
        force_height => $self->param('force_height'),
        max_width => $self->param('max_width'),
        max_height => $self->param('max_height'),
    } );
}

sub preview_image {
    my ( $self ) = @_;

    my $dac = $self->_fetch_valid_draft_from_params;
    my $as = CTX->lookup_action('attachment')->execute( get_attachments_for_object => {
        object => $dac,
        group_id => 0,
        user_id => 0,
    } );

    my $a = pop @$as;

    unless ( $a ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg('The file you requested does not exist.')
        );
        $self->redirect( '/' );
    }

    CTX->lookup_action('attachment')->execute( serve => {
        attachment => $a,
        group_id => 0,
        user_id => 0,
        preview => 1,
    } );
}

1;
