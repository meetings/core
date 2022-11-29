package OpenInteract2::Action::NotFound;

use strict;
use base qw( Dicole::Action );
use OpenInteract2::Context qw( CTX );

sub notfound {
    my ($self) = @_;

    CTX->response->status(404);

    if (CTX->request->url_relative =~ m,^/*(\?.*)?$,) {
        return CTX->response->redirect($self->derive_url( action => 'login', task => 'login' ));
    }

    my $not_found_action = CTX->lookup_action('dicole_domains')->execute(get_domain_setting => {
        attribute => 'not_found_action'
    });

    if ($not_found_action) {
        return CTX->lookup_action($not_found_action)->execute;
    } else {
        return $self->generate_content({}, { name => 'dicole_base::notfound.tmpl' });
    }
}

1;
