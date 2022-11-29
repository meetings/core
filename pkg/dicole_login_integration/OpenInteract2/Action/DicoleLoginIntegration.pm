package OpenInteract2::Action::DicoleLoginIntegration;
use strict;
use base qw( Dicole::Action );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

$OpenInteract2::Action::DicoleLoginIntegration::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

sub _login_integration {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id ) {
        return $self->generate_content(
            {
                server => 'http://' . CTX->request->server_name,
                welcome_header => $self->_msg('Welcome'),
                hello_message => $self->_msg('Hello [_1]', CTX->request->auth_user->first_name ),
                go_to_dicole => $self->_msg('Go to Dicole'),
                logout => $self->_msg('Logout'),
            },
            { name => 'dicole_login_integration::logged_in_box' }
        );
    }
    else {
        return $self->generate_content(
            {
                server => 'http://' . CTX->request->server_name,
                login_header => $self->_msg('Login form'),
                login => $self->_msg('Login'),
                username => $self->_msg('Username'),
                password => $self->_msg('Password'),
                retrieve_lost => $self->_msg('Retrieve lost username or password'),
            },
            { name => 'dicole_login_integration::login_box' }
        );
    }
}

1;

