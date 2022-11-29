package OpenInteract2::Action::DicoleLoginJSON;

use strict;

use base qw(Dicole::Action);

use OpenInteract2::Util;
use OpenInteract2::URL;
use OpenInteract2::Context qw(CTX);

use Dicole::Utils::Session;
use Dicole::Utils::User;

sub instant_authorization_key {
    my ( $self ) = @_;

    return { result => 'anonymous' } unless CTX->request->auth_user_id;

    my $secure = Dicole::Utils::Session->current_is_secure;

    return { result => Dicole::Utils::User->identification_key( CTX->request->auth_user_id, $secure ) };
}

sub who_am_i {
    my ( $self ) = @_;

    return { result => CTX->request->auth_user_id || 0 };
}

1;
