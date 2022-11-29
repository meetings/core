package OpenInteract2::Action::DicoleMeetingsInternal;

use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub session_info {
    my ( $self ) = @_;

    return { result => { user_id => CTX->request->auth_user_id } };
}

1;
