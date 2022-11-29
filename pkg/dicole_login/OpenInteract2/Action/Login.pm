package OpenInteract2::Action::Login;

use strict;

=pod

=head1 NAME

OpenInteract2::Action::Login - Login handler

=head1 DESCRIPTION

Handles user login and logout actions.

=cut

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX );
use Dicole::Tool;
use DateTime;
use Dicole::Generictool;
use Dicole::MessageHandler qw( :message );
use Dicole::Generictool::FakeObject;
use Dicole::Security::Encryption;
use Dicole::URL;
use Dicole::Content::Hyperlink;
use OpenInteract2::URL;

sub login {
    my ( $self ) = @_;

    # Get configuration related to login
    my $login_config = CTX->lookup_login_config;
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };

    # If user is logged in...
    if ( CTX->request->auth_user_id ) {
        if ( $dicole_domains) {
            my $return_msg = $dicole_domains->execute( 'login_user_in_domain', {
                user_id => CTX->request->auth_user_id
            } );
            if ( $return_msg ) {
                my $uri = OpenInteract2::URL->create_from_action(
                    'login', undef, { logout => 3, msg => $return_msg }
                );
                $self->param( url_after_logout => $uri );
                return $self->logout;
            }
        }
        
        $self->_generic_login_actions;

        my $uri = $self->_redirect_url_after_login;

        return CTX->response->redirect( $uri );
    }
    
    my $current_domain = $dicole_domains ? $dicole_domains->execute('get_current_domain') : undef;
    
    my $tool_name = $current_domain ? 'domain_user_manager_' . $current_domain->domain_id : 'user_manager';
    my $alternative_login = Dicole::Settings->fetch_single_setting(
        tool => $tool_name, attribute => 'alternative_login'
    );
    
    if ( $alternative_login ) {
        my $uri = URI->new( $alternative_login );

        my $qparams = { $uri->query_form };

        if ( my $ual = CTX->request->param( 'url_after_login' ) ) {
            $qparams->{ url_after_login } = $ual;
        }

        for my $param ( qw( utm_source utm_medium utm_campaign ) ) {
            next unless CTX->request->param( $param );
            $qparams->{ $param } = CTX->request->param( $param );
        }

        $uri->query_form( %$qparams ) if keys %$qparams;

        $alternative_login = $uri->as_string;

        return $self->redirect( $alternative_login );
    }

    $self->init_tool;
    $self->tool->structure( 'login' );

    # If login buttom is pressed...
    if ( CTX->request->param( 'login' ) ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'Login failure. Please check your username and password.' )
        );
    }
    elsif ( CTX->request->param('logout') == 1 ) {
        $self->tool->add_message( 1,
            $self->_msg( 'Thank you for using our system. Always remember to log out after you are done to ensure your own privacy.' )
        );
    }
    elsif ( CTX->request->param('logout') == 2 ) {
        $self->tool->add_message( 2,
            $self->_msg( 'Session was not found, this probably means the session timed out. Please login again to proceed.' )
        );
    }
    elsif ( CTX->request->param('logout') == 3 ) {
        $self->tool->add_message( 2,
            $self->_msg( CTX->request->param( 'msg' ) )
        );
    }

    # TODO: Add session timed out, information of how long the user was inactive
    # and suggestion to re-login

    # registration allowed in server.ini?
    my $reg_allowed = CTX->server_config->{dicole}{user_registration};
    # disable password retrieve in server.ini
    my $dpr = CTX->server_config->{login}{disable_password_retrieve}{default};
    
    # registration allowed in domain database or retrieve in domain config?
    my $d = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $d->task( 'user_registration_enabled' );
        $d->param; # XXX: is this needed?
        my $reg_allowed_t = $d->execute;
        if (defined($reg_allowed_t)) {
            $reg_allowed = $reg_allowed_t;
        }
        my $ddpr = CTX->server_config->{login}{disable_password_retrieve}->
            { $d->get_current_domain->domain_name };
        $dpr = $ddpr if defined ( $dpr );
    }

    my ( $fb_id, $fb_secret, $fb_disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    my $params = {
        retrieve_url => $dpr ? '' : OpenInteract2::URL->create_from_action( 'lostaccount' ),
        register_url => $reg_allowed ? OpenInteract2::URL->create_from_action( 'register' ) : '',
        facebook_connect_app_id => $fb_disabled ? '' : $fb_id,
    };

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( 'Login' ) );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_login::login' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub _generic_login_actions {
	my ( $self ) = @_;
	
	# Get configuration related to login
    my $login_config = CTX->lookup_login_config;
	
	
    # If password was provided, catch it and encrypt it with AES-256.
    # Uses dynamic key for encryption, so no-one knows the key expect
    # the server. Store into user session.
    if ( CTX->request->param( $login_config->{password_field} ) ) {
        my $store = CTX->request->param( $login_config->{password_field} );
        my $sec = Dicole::Security::Encryption->new;
        $sec->use_dynamic( 1 );
        $store = $sec->encrypt( $store );
        CTX->request->session->{login_password} = $store;
    }

    # Increment ammount of logins the user has made. This
    # function also resets the expiration date of the user account.
    CTX->request->auth_user->increment_login;

    CTX->request->auth_user->{last_login} = DateTime->now;
    CTX->request->auth_user->save;

}

sub logout {
    my ( $self ) = @_;

    return CTX->response->redirect( $self->_logout );
}

sub _logout {
    my ( $self ) = @_;

    # Clear authentication from this action, delete old session
    # object and create a new anonymous session with the language
    # of the logged out user.

    my $lang = CTX->request->session->{lang}{code};

    CTX->request->auth_clear;
    CTX->lookup_session_config->{class}->delete_session( CTX->request->session );

    CTX->request->session( { language => $lang } );

    CTX->response->cookie( CGI::Cookie->new( "-name" => 'oi2ssn', "-value" => undef, "-expires" => 1, "-path" => '/' ) );

    my ( $id, $secret, $enabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    my $domain = Dicole::Utils::Domain->guess_current;
    if ( $domain ) {
        my ( $tldomain ) = $domain->domain_name =~ /(\w+\.\w+)$/;
    
        CTX->response->cookie( CGI::Cookie->new( "-name" => 'fbs_' . $id, "-value" => undef, "-expires" => 1, "-path" => '/', "-domain" => $tldomain ) );
    }
    else {
        CTX->response->cookie( CGI::Cookie->new( "-name" => 'fbs_' . $id, "-value" => undef, "-expires" => 1, "-path" => '/' ) );

    }

    my $uri = $self->param( 'url_after_logout' );
    unless($uri) {
        $uri = CTX->request->param('url_after_logout');
    }
    unless( $uri ) {
        # check domain-specific url_after_logout from database
        eval {
            my $d_obj = CTX->lookup_action('dicole_domains');
            $d_obj->task('url_after_logout');
            $uri = $d_obj->execute;
        };
    }
    unless ( $uri ) {
        $uri = OpenInteract2::URL->create_from_action(
            $self->param( 'action_after_logout' ) || 'login', undef, { logout => 1 }
        );
    }

    return $uri;
}

sub _login_forward {
    my ( $self ) = @_;

    if ( CTX->request->param('url') && CTX->request->auth_user_id ) {
        return $self->redirect( CTX->request->param('url') );
    }
    return $self->redirect( '/' );
}

sub _rpc_check_register {
    my ( $self ) = @_;

    my $email = CTX->request->param('email');

    unless ( $email && CTX->request->param('first_name') && CTX->request->param('last_name') ) {
        return { success => 0, reason => $self->_msg('Email and name are required.') }
    }

    my $user = Dicole::Utils::User->fetch_user_by_login_in_current_domain( $email );

    if ( $user ) {
        return { success => 0, reason => $self->_msg('Email has already been taken. Try logging in with your previous account or use a different email.') }
    }

    return { success => 1 };
}

sub _rpc_login {
    my ( $self ) = @_;
    if ( CTX->request->auth_is_logged_in ) {
        my $dicole_domains = CTX->lookup_action('dicole_domains');
        if ( $dicole_domains) {
            my $return_msg = $dicole_domains->execute( 'login_user_in_domain', {
                user_id => CTX->request->auth_user_id
            } );
            if ( $return_msg ) {
                $self->_logout;
                return { success => 0, reason => $self->_msg( 'Login failed, please check your username and password.' ) };
            }
        }

        $self->_generic_login_actions;

        my $uri = $self->_redirect_url_after_login;
        
        return { success => 1, location => $uri };
    }
    else {
        return { success => 0, reason => $self->_msg( 'Login failed, please check your username and password.' ) };
    }
}

sub _redirect_url_after_login {
    my ( $self ) = @_;
    
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    my $domain = $dicole_domains ? eval { $dicole_domains->get_current_domain } : undef;
    my $domain_id = $domain ? $domain->id : 0;

    # URL after login is usually set in the GET parameters
    # if the session gets timed out. When the user logins again
    # he is forwarded to the previous page.
    if ( CTX->request->param( 'url_after_login' ) ) {
        return CTX->request->param( 'url_after_login' );
    }

    my $um = $domain ? 'domain_user_manager_' . $domain->domain_id : 'user_manager';

    my $front_page = Dicole::Settings->fetch_single_setting(
        tool => $um,
        attribute => 'front_page',
    );

    if ( $front_page ) {
        my $uri = URI->new( $front_page );

        my $qparams = { $uri->query_form };

        for my $param ( qw( utm_source utm_medium utm_campaign ) ) {
            next unless CTX->request->param( $param );
            $qparams->{ $param } = CTX->request->param( $param );
        }

        $uri->query_form( %$qparams ) if keys %$qparams;

        return $uri->as_string;
    }

    return $front_page if $front_page;

    my $uri = '';

    my $user_starting_group = Dicole::Settings->fetch_single_setting(
        user_id => CTX->request->auth_user_id,
        tool => 'login',
        attribute => 'starting_group_' . $domain_id,
    );

    $user_starting_group ||= CTX->request->auth_user->{starting_page};

    if ( $user_starting_group ) {
        if ( $domain_id ) {
            $user_starting_group = 0 unless $dicole_domains->execute( group_belongs_to_domain => {
                group_id => $user_starting_group,
                domain_id => $domain_id,
            } );
        }
    }

    if ( $user_starting_group ) {
        $user_starting_group = 0 unless
            Dicole::Utility->user_belongs_to_group( CTX->request->auth_user_id, $user_starting_group );
    }

    if ( $domain_id && ! $user_starting_group ) {
        my $group_ids = $dicole_domains->groups_by_domain( $domain_id );
        for my $gid ( @$group_ids ) {
            if ( Dicole::Utility->user_belongs_to_group( CTX->request->auth_user_id, $gid ) ) {
                my $group = eval { CTX->lookup_object('groups')->fetch( $gid ) };
                if ( $group && $group->has_area == 1 ) {
                    $user_starting_group = $gid;
                    last;
                }
            }
        }
    }

    # If user has defined a starting section for herself, redirect to such a page
    if ( $user_starting_group ) {
        my $group = eval { CTX->lookup_object('groups')->fetch( $user_starting_group ) };
        if ( $group && $group->has_area == 1 ) {
            $uri = Dicole::URL->create_from_current(
                action => $self->param( 'user_defined_action' ),
                task => $self->param( 'user_defined_task' ),
                target => $user_starting_group,
            );
        }
        elsif ( CTX->request->auth_user->{custom_starting_page} ) {
            $uri = CTX->request->auth_user->{custom_starting_page};
        }
    }
    elsif ( CTX->request->auth_user->{custom_starting_page} ) {
        $uri = CTX->request->auth_user->{custom_starting_page};
    }

    # The default is to use action parameters action_after_login and
    # task_after_login to determine where to go once the user has logged in.
    # TODO: user-specific action after login
    $uri ||= Dicole::URL->create_from_current(
        action => $self->param( 'action_after_login' ),
        task => $self->param( 'task_after_login' ),
    );

    if ( CTX->request->param( 'login_login_name' ) ) {
        if ( $domain ) {
            if ( my $ual = $domain->url_after_login ) {
                my $escaped = URI::Escape::uri_escape( $uri );
                $ual =~ s/%%original_url_after_login%%/$escaped/g;
                $uri = $ual;
            }
        }
    }
   
    return $uri;
}


=pod

=head1 PRIVATE METHODS

=head2 _make_array( ARRAYREF|STRING )

Accepts an arrayref or a string value and returns an arrayref.
This is useful with INI configurations where you can specify multiple
instances of a certain parameter and OI will create an arrayref out
of the multiple instances, but only a string if the parameter was
specified only a single time.

=cut

sub _make_array {
    my ( $self, $value ) = @_;
    return ref( $value ) eq 'ARRAY' ? $value : [$value];
}

=pod

=head1 SEE ALSO

L<OpenInteract2::Action::DicoleRegister>.

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;
