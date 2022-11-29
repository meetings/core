package OpenInteract2::Action::DicoleRegister;

use strict;

use base ( qw( Dicole::Action ) );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

use OpenInteract2::Action::UserManager;

use Dicole::Generictool;
use Dicole::Generictool::Data;
use Dicole::URL;
use SPOPS::Utility;
use Dicole::Pathutils;
use OpenInteract2::Util;
use OpenInteract2::URL;
use DateTime::TimeZone;
use Dicole::LDAPAdmin;

use constant REMOVAL_TIME => 60 * 60 * 24 * 2; # Two days
use constant USER_REGISTRATION_ENABLED => 1;
use constant USER_REGISTRATION_DEFAULT_DISABLED => 0;

use constant UMANAGER_PREFIX => '/usermanager/show/0/?uid=';
use constant DMANAGER_PREFIX => '/dusermanager/show/0/?uid=';

use OpenInteract2::Context   qw( CTX );

sub _init_tool {
    my $self = shift;
    my %args = @_;
    $args{tool_args}->{no_tool_tabs} = 1;
    $self->init_tool( \%args );
    my $p = { @_ };
    $p->{view} ||= ( split '::', ( caller(1) )[3] )[-1];
    $self->gtool(
        Dicole::Generictool->new(
            object => CTX->lookup_object('user'),
            skip_security => 1,
            current_view => $p->{view},
        )
    );
    $self->init_fields( view => $p->{view} );
}

sub _create_password {
    my ( $self ) = @_;
    my $plain = SPOPS::Utility->generate_random_code( 6 );
    my $crypted = ( CTX->lookup_login_config->{crypt_password} )
                    ? SPOPS::Utility->crypt_it( $plain ) : $plain;
    return ( $plain, $crypted );
}

sub _create_ldap_user {
    my ($self, $data, $plain_pass) = @_;

    my $create_server = undef;
    eval {
        my $d = CTX->lookup_action('dicole_domains')->get_current_domain;
        $create_server = $d->external_auth;
    };

    $create_server ||= CTX->lookup_login_config->{create_server}->{default};
    
    return unless $create_server && $create_server !~ /^local$/i;
    
    # TODO: publish this as an action!
    return OpenInteract2::Action::UserManager->_create_ldap_user(
        $data, $plain_pass, $create_server
    );
}

sub register {
    my ( $self ) = @_;
    
    if ( CTX->request->param('cancel') ) {
        return $self->redirect( OpenInteract2::URL->create_from_action( 'login' ) );
    }
    
    $self->_init_tool;

    my $valid_event_invite = CTX->request->param('event_invite_code') ?
        eval { CTX->lookup_action('events_api')->e( validate_invite => {
            invite_code => CTX->request->param('event_invite_code'),
            target_group_id => $self->param('target_group_id'),
        } ) } || 0 : 0;
    
    my $gid = 0;
    if ( $self->param('target_type') eq 'group' ) {
        my $tg = $self->param('target_group');
        if ( ! $tg || ( $tg->joinable != 1 && ! $valid_event_invite ) ) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'User registration is not allowed to this area.' )
            );
            return $self->redirect( OpenInteract2::URL->create_from_action( 'register' ) );
        }
        else {
            $gid = $tg->id;
        }
    }

    # constants
    my $reg_allowed          = USER_REGISTRATION_ENABLED;
    my $reg_default_disabled = USER_REGISTRATION_DEFAULT_DISABLED;

    # global settings from server.ini
    if (defined(CTX->server_config->{dicole}{user_registration})) {
        $reg_allowed = CTX->server_config->{dicole}{user_registration};
    }
    if (defined(CTX->server_config->{dicole}{user_registration_default_disabled})) {
        $reg_default_disabled = CTX->server_config->{dicole}{user_registration_default_disabled};
    }

    # domain-specific settings (if applicable)
    my $d = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        my $reg_allowed_t = $d->execute( user_registration_enabled => {} );
        if (defined($reg_allowed_t)) {
            $reg_allowed = $reg_allowed_t;
        }
        my $reg_default_disabled_t = $d->execute( user_registration_default_disabled => {} );
        if (defined($reg_default_disabled_t)) {
            $reg_default_disabled = $reg_default_disabled_t;
        }
    }
    
#     if ( $gid ) {
#         my $reg_allowed_t = Dicole::Settings->fetch_single_setting(
#            group_id => $gid,
#            tool => 'groups',
#            attribute => 'user_registration_enabled',
#         );
#         $reg_allowed = $reg_allowed_t;
#     }
    
    if ( ! $reg_allowed && ! $valid_event_invite ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'User registration is not allowed to this area.' )
        );
        return $gid ?
            $self->redirect( OpenInteract2::URL->create_from_action( 'register' ) )
            :
            $self->redirect( OpenInteract2::URL->create_from_action( 'login' ) );
    }
    
    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };
    my $user_manager_tool = $current_domain ?
        'domain_user_manager_' . $current_domain->domain_id : 'user_manager';
    my $tos_required = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'tos_link'
    );


    # old registration gateway can not be used if location is required
    return $self->redirect( OpenInteract2::URL->create_from_action( 'login' ) ) if Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'location_required_to_register'
    );

    $self->_generate_timezones;

    my $default_tz = eval { CTX->lookup_action('dicole_domains')->execute(
        'domain_default_timezone'
    ) };

    if ( $default_tz ) {
        $self->gtool->get_field( 'timezone' )->value( $default_tz );
        $self->gtool->get_field( 'timezone' )->use_field_value( 1 );
    }

    my $default_lang = eval { CTX->lookup_action('dicole_domains')->execute(
        'domain_default_language'
    ) };

    if ( $default_lang ) {
        $self->gtool->get_field( 'language' )->value( $default_lang );
        $self->gtool->get_field( 'language' )->use_field_value( 1 );
    }
    $self->gtool->add_bottom_button(
        name  => 'register',
        value => $self->_msg( 'Register' ),
    );
    $self->gtool->add_bottom_button(
        name  => 'cancel',
        value => $self->_msg( 'Cancel' ),
    );
    if ( CTX->request->param( 'register' ) && CTX->request->param('address1') ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg('Your registration has been identified as spam.')
        );
    }
    elsif ( CTX->request->param( 'register' ) && ! CTX->request->param('address2') ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg('Registering without javascript is disabled to reduce spam. Please turn javascript on to register.')
        );
    }
    elsif ( CTX->request->param( 'register' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { no_save => 1 }
        );
        my $data = $self->gtool->Data->data;

        if ( $tos_required && ! CTX->request->param( 'tos_checked' ) ) {
            $code = MESSAGE_ERROR;
            $message = $self->_msg('You need to accept the terms of service.');
        }
        elsif ( $code ) {
            $data->{login_name} = $data->{email};
            my $user = Dicole::Utils::User->fetch_user_by_login_in_current_domain( $data->{email} );

            if ( $user ) {
                $self->gtool->get_field( 'email' )->error( 1 );
                $code = 0;
                $message = $self->_msg(
                    "User with email address [_1] already exists. Choose a different email address.",
                    $data->{email}
                );
            }
            else {
                my ( $plain_pass, $crypted_pass ) = $self->_create_password;
                $data->{password} = $crypted_pass;
                $data->{removal_date} = OpenInteract2::Util->now( {
                    time => time + REMOVAL_TIME
                } );
                $data->{theme_id} = CTX->lookup_default_object_id( 'theme' );

                # login disabled, if specified in global server configuration
                # or domain configuration
                $reg_default_disabled && ($data->{login_disabled} = 1);

                # Create LDAP user if needed
                $self->_create_ldap_user( $data, $plain_pass );

                # save object to database
                $self->gtool->Data->data_save; # or $data->data_save ?

                eval {
                    CTX->lookup_action( 'dicole_domains' )->execute(
                        'add_user_to_domain', { user_id => $data->id }
                    );
                };

                Dicole::Settings->store_single_setting(
                    tool => $user_manager_tool,
                    user_id => $data->id,
                    attribute => 'tos_accepted',
                    value => 1,
                ) if $tos_required;

                # send mail notifying new user of the password
                $self->_send_new_user_email( $data, $plain_pass, $gid );

                # send mail to admin / domain admin notifying about new user
                $self->_send_new_user_admin_email( $data );

                # create directory storing user files & other misc. new user operations
                OpenInteract2::Action::UserManager->_new_user_operations( $data->id, $data );

                if ( $gid ) {
                    CTX->lookup_action('add_user_to_group')->execute( {
                        user_id => $data->id,
                        group_id => $gid,
                    } );
                }

                my $autologin_after_registering = Dicole::Settings->fetch_single_setting(
                    tool => $user_manager_tool,
                    attribute => 'autologin_after_registering'
                );
                if ( $autologin_after_registering ) {
                    $self->tool->add_message( $code, $self->_msg(
                        "Registration done. We have emailed you your account information."
                    ) );

                    if ( CTX->request && CTX->request->param('url_after_register') ) {
                         $self->redirect( Dicole::URL->from_parts(
                            action => 'login', task => 'login',
                            params => {
                                login_login_name => $data->{login_name},
                                login_password => $plain_pass,
                                url_after_login => CTX->request->param('url_after_register'),
                            },
                        ) );
                    }

                    return $gid ?
                        $self->redirect( Dicole::URL->from_parts(
                            action => 'groups', task => 'starting_page', target => $gid,
                            params => {
                                login_login_name => $data->{login_name},
                                login_password => $plain_pass,
                            },
                        ) )
                        :
                        $self->redirect( Dicole::URL->from_parts(
                            action => 'login', task => 'login',
                            params => {
                                login_login_name => $data->{login_name},
                                login_password => $plain_pass,
                            },
                        ) );
                }
                
                $self->tool->add_message( $code, $self->_msg(
                    "Registration done. We have sent you an email containing your login information."
                ) );
                $self->gtool->Data->clear_data_fields;

                if ( CTX->request && CTX->request->param('url_after_register') ) {
                    $self->redirect( CTX->request->param('url_after_register') );
                }

                my $redirect = $gid ? Dicole::URL->from_parts(
                        action => 'groups', task => 'starting_page', target => $gid,
                    )
                    :
                    OpenInteract2::URL->create_from_action( 'login' );
                return CTX->response->redirect( $redirect );
            }

        } else {
            $message = $self->_msg( "Registration failed: [_1]", $message );
        }
        
        $self->tool->add_message( $code, $message );
    }

    if ( $default_lang ) {
        $self->gtool->del_visible_fields(
            $self->gtool->current_view, [ 'language' ]
        );
    }

    if ( $default_tz ) {
        $self->gtool->del_visible_fields(
            $self->gtool->current_view, [ 'timezone' ]
        );
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Registration information' )
    );
    
    my $add = $self->gtool->get_add;
    
    unshift @$add, Dicole::Widget::HiddenBlock->new(
        content => Dicole::Widget::Vertical->new( contents => [
            Dicole::Widget::FormControl::TextField->new(
                id => 'address1',  name => 'address1'
            ),
            Dicole::Widget::FormControl::TextField->new(
                id => 'address2',  name => 'address2'
            ),
            Dicole::Widget::Javascript->new(
                defer => 1,
                code => "document.getElementById('address2').value=1;",
            )
        ] )
    );
    
    my $buttons = pop @$add;
    
    if ( $tos_required ) {
        push @$add, Dicole::Widget::Inline->new(
            class => 'tos_agreement_query',
            contents => [
                Dicole::Widget::FormControl::Checkbox->new( name => 'tos_checked', value => 1 ),
                ' ',
                $self->_msg( 'I accept the terms of service.' ),
                ' ',
                '(',
                Dicole::Widget::Hyperlink->new(
                    content => $self->_msg('Terms of service'),
                    'link' => $tos_required,
                ),
                ')',
            ],
        );
    }
    
    push @$add, $buttons;
    
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $add
    );
    return $self->generate_tool_content;
}

sub _add_user_to_current_domain {
    my ( $self, $user ) = @_;
    eval {
        CTX->lookup_action( 'dicole_domains' )->execute(
            'add_user_to_domain', { user_id => $user->id }
        );
    };
    
    OpenInteract2::Action::UserManager->_domain_join_operations( $user->id, $user );
    
    $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg( "Your existing account with login name '[_1]' has been added to this domain. Please log in with your old password or retrieve a new one through the normal password retrieval process.", $user->login_name
    ) );
    
    my $redirect = OpenInteract2::URL->create_from_action( 'login' );
    return CTX->response->redirect( $redirect );
}

# Generates timezone selection dropdown
sub _generate_timezones {
    my ( $self ) = @_;
    my $timezone = $self->gtool->get_field( 'timezone' );
    $timezone->add_dropdown_item( 'UTC', $self->_msg( '-- Select --' ) );
    foreach my $zone ( @{ DateTime::TimeZone->all_names } ) {
        $timezone->add_dropdown_item( $zone, $zone );
    }
}

sub _send_new_user_email {
    my ( $self, $new_user, $plain_password, $group_id ) = @_;

    eval {
        my $a = CTX->lookup_action('dusermanager');
        $a->_send_new_user_email( $new_user, $plain_password, $group_id );
    };
    if ( $@ ) {
        my $request = CTX->request;
        my $server_url = $group_id ? 
            Dicole::URL->get_server_url . Dicole::URL->from_parts(
                action => 'groups',
                task => 'starting_page',
                target => $group_id,
            )
            :
            Dicole::URL->get_server_url;
        
        my %email_params = ( login       => $new_user->{login_name},
                                password    => $plain_password,
                                server_name => $server_url );
        $self->log( 'info', "Sending registration information via email to '$email_params{login}'" );
        my $message = $self->generate_content(
            \%email_params,
            { name => 'dicole_user_manager::new_user_mail' }
        );
        my $subject = $self->_msg( 'Registration information from [_1]', $server_url );
        eval {
            Dicole::Utils::Mail->send(
                text => $message,
                to => $new_user->{email},
                subject => $subject
            )
        };
        if ( $@ ) {
            $self->log( 'error', "Cannot send email! $@" );
            $self->tool->add_message( $self->_msg( 'Error sending email: [_1]', $@ ) );
        }
    }
}

sub _send_new_user_admin_email {
    my ( $self, $new_user ) = @_;

    # global settings from server.ini
    my $admin_email = CTX->server_config->{dicole}{user_registration};

    my $u_prefix;

    # domain-specific settings (if applicable)
    eval {
        my $d = CTX->lookup_action( 'dicole_domains' );
        # use domain user manager
        $u_prefix = DMANAGER_PREFIX;
        $d->task( 'domain_admin_email' );
        $d->param; # XXX: is this needed?
        my $admin_email_t = $d->execute;
        if (defined($admin_email_t)) {
            $admin_email = $admin_email_t;
        }
    };

    # use normal user manager
    $u_prefix ||= UMANAGER_PREFIX;

    my $request    = CTX->request;
    my $server_url = Dicole::Pathutils->new->get_server_url;

    # XXX: what about Dicole installations not in root directory of web server?
    my $user_edit_url = $server_url . $u_prefix . $new_user->{user_id};


    my %email_params = ( login_name    => $new_user->{login_name},
                         user_email    => $new_user->{email},
                         server_url    => $server_url,
                         user_edit_url => $user_edit_url );
    $self->log( 'info', "Sending new user registration details ($new_user->{login_name}) via email to '$admin_email'" );
    my $message = $self->generate_content(
        \%email_params,
        { name => 'dicole_user_manager::new_user_admin_mail' }
    );
    my $subject = $self->_msg( 'New user registered at [_1]', $server_url );
    eval {
        Dicole::Utils::Mail->send(
            text => $message,
            to      => $admin_email,
            subject => $subject
        )
    };
    if ( $@ ) {
        $self->log( 'error', "Cannot send email! $@" );
    }
}

=pod

=head1 NAME

OpenInteract2::Action::DicoleRegister

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

L<OpenInteract2::Action::Login>.

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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
