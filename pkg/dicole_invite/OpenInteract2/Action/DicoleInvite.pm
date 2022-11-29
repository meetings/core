package OpenInteract2::Action::DicoleInvite;

# $Id: DicoleInvite.pm,v 1.10 2010-07-20 03:53:31 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::MessageHandler qw( :message );
use OpenInteract2::Context   qw( CTX );
use Dicole::Generictool;
use MIME::Lite ();
use Dicole::Tool;
use Dicole::Generictool::FakeObject;
use SPOPS::Utility;
use OpenInteract2::Action::UserManager;
use OpenInteract2::Action::DicoleRegister;
use Dicole::Pathutils;
use OpenInteract2::Util;
use Dicole::Utils::Mail;

use base qw( OpenInteract2::Action::DicoleInviteCommon );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use constant CODE_LENGTH      => 8;    # characters
use constant UMANAGER_PREFIX => '/usermanager/show/0/?uid=';
use constant DMANAGER_PREFIX => '/dusermanager/show/0/?uid=';

# Initialize tool
sub _init_tool {
    my $self = shift;
    my $p = { @_ };
    $p->{tool_args}->{no_tool_tabs} = 1;
    $self->init_tool( $p );
}

sub accept_invite {
    my ( $self ) = @_;

    if ( CTX->request->auth_user_id ) {
        return $self->redirect( $self->derive_url(
            task => 'claim_invite',
            additional => [],
            params => { invite_code => CTX->request->param( 'k' ) },
        ) );
    }
    else {
        return $self->redirect( $self->derive_full_url(
            action => 'groupsummary',
            task => 'summary',
            additional => [],
        ) );
    }
}

sub claim_invite {
    my ( $self ) = @_;

    my $tgid = ( $self->param('target_type') eq 'group' ) ? $self->param('target_group_id') || 0 : 0;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $invite = $self->_fetch_invite( CTX->request->param('invite_code'), $tgid, $domain_id );

    if ( ! $invite ) {
        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->_msg( 'Registration key no longer valid.' ) );
        return $self->redirect( $self->derive_url( action => 'login', task => 'login', target => 0, additional => [] ) );
    }

    if ( my $uid = CTX->request->auth_user_id ) {
        if ( my $gid = $invite->group_id ) {
#             if ( Dicole::Utility->user_belongs_to_group( $uid, $gid ) ) {
#                 Dicole::MessageHandler->add_message( MESSAGE_ERROR,
#                     $self->_msg( 'You are already part of the group you were invited to.' )
#                 );
#                 return $self->redirect( $self->derive_url(
#                     action => 'groups',
#                     task => 'starting_page'
#                 ) );
#             }
#             else {
                $self->_consume_invite( $invite, CTX->request->auth_user );

                my $group = $self->param('target_group');

                Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
                    $self->_msg( 'Invite to [_1] has been accepted.', $group ? $group->name : '?' )
                );

                return $self->redirect( $self->derive_url(
                    action => 'groups',
                    task => 'starting_page'
                ) );
#             }
        }
        else {
            Dicole::MessageHandler->add_message( MESSAGE_ERROR,
                $self->_msg( 'You can not get invited to the system while logged in.' )
            );
            return $self->redirect( Dicole::URL->from_parts( action => 'login' ) );
        }
    }

    die "security error";
}

sub invited {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_full_url( task => 'accept_invite' ) );

    $self->_init_tool;
    
    if ( CTX->request->param( 'cancel' ) ) {
        return $self->redirect( Dicole::URL->from_parts( action => 'login' ) );
    }
    
    my $tgid = ( $self->param('target_type') eq 'group' ) ? $self->param('target_group_id') || 0 : 0;
    
    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $secure_codes = CTX->lookup_object( 'invite' )->fetch_group( {
        where => 'secret_code = ? AND disabled = 0',
        value => [ CTX->request->param( 'k' ) ]
    } ) || [];
    my $secure_code = shift @$secure_codes;

    if ( ! $secure_code ||
        $secure_code->domain_id != ( $current_domain ? $current_domain->id : 0 ) ||
        (
            $self->param('target_type') eq 'group' && (
                ! $tgid || ( $secure_code->group_id != $tgid  )
            )
        )
    ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'Registration key no longer valid.' )
        );
        return $self->redirect( Dicole::URL->from_parts( action => 'login' ) );
    }
    
    my $user_manager_tool = $current_domain ?
        'domain_user_manager_' . $current_domain->domain_id : 'user_manager';
    
    my $tos_required = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'tos_link'
    );
    
    if ( my $uid = CTX->request->auth_user_id ) {
        if ( my $gid = $secure_code->group_id ) {
            if ( Dicole::Utility->user_belongs_to_group( $uid, $gid ) ) {
                $self->tool->add_message( MESSAGE_ERROR,
                    $self->_msg( 'You are already part of the group you were invited to.' )
                );
                return $self->redirect( $self->derive_url(
                    action => 'groups',
                    task => 'starting_page'
                ) );
            }
            elsif ( CTX->request->param( 'claim' ) ) {
                $self->_consume_invite( $secure_code, CTX->request->auth_user );

                $self->tool->add_message( MESSAGE_SUCCESS,
                    $self->_msg( 'Invite to this group has been accepted.' )
                );

                return $self->redirect( $self->derive_url(
                    action => 'groups',
                    task => 'starting_page'
                ) );
            }
            else {
                return $self->_output_invited_claim;
            }
        }
        else {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'You can not get invited to the system while logged in.' )
            );
            return $self->redirect( Dicole::URL->from_parts( action => 'login' ) );
        }
    }
    
    if ( CTX->request->param( 'save' ) ) {
        my $message;
        my $code = MESSAGE_ERROR;

        my $email = CTX->request->param('email');
        my $first_name = CTX->request->param('first_name');
        my $last_name = CTX->request->param('last_name');
        my $plain = CTX->request->param( 'password' );

        if ( ! $email || ! $first_name || ! $last_name || ! $plain ) {
            $message = $self->_msg('All fields are mandatory.');
        }
        elsif ( $tos_required && ! CTX->request->param( 'tos_checked' ) ) {
            $message = $self->_msg('You need to accept the terms of service.');
        }
        else {
            my $user = Dicole::Utils::User->fetch_user_by_login_in_current_domain( $email );

            if ( $user ) {
                $self->_consume_invite( $secure_code, $user );
                $self->tool->add_message( MESSAGE_SUCCESS,
                    $self->_msg( "Your previous account with email [_1] has been used to claim this invite. You may now login with your previous login name and password.", $email )
                );

                my $redirect = OpenInteract2::URL->create_from_action( 'login' );
                return $self->redirect( $redirect );
            }
            else {
                my $user = CTX->lookup_object('user')->new;
                my $crypted = ( CTX->lookup_login_config->{crypt_password} )
                    ? SPOPS::Utility->crypt_it( $plain ) : $plain;
                $user->password( $crypted );
                $user->email( $email );
                $user->first_name( $first_name );
                $user->last_name( $last_name );
                $user->login_name( $email );
                $user->{removal_date} = 0;
                $user->{language} = eval { CTX->lookup_action('dicole_domains')->execute( 'domain_default_language' ) } || CTX->server_config->{language}{default_language};
                $user->{timezone} = eval { CTX->lookup_action('dicole_domains')->execute( 'domain_default_timezone' ) } || CTX->server_config->{Global}{timezone};
                $user->{theme_id} = CTX->lookup_default_object_id( 'theme' );
    
                # Create LDAP user if needed
                $self->_create_ldap_user( $user, $plain );
    
                # save object to database
                $user->save;
    
                Dicole::Settings->store_single_setting(
                    tool => $user_manager_tool,
                    user_id => $user->id,
                    attribute => 'tos_accepted',
                    value => 1,
                ) if $tos_required;
    
                # send mail notifying new user of the password
                CTX->lookup_action('dusermanager')->_send_new_user_email( $user, $plain );
    
                # send mail to admin / domain admin notifying about new user
                $self->_send_new_user_admin_email( $user );
    
                # create directory storing user files & other misc. new user operations
                OpenInteract2::Action::UserManager->_new_user_operations( $user->id, $user );
    
                $self->_consume_invite( $secure_code, $user );
    
                my $autologin_after_registering = Dicole::Settings->fetch_single_setting(
                    tool => $user_manager_tool,
                    attribute => 'autologin_after_registering'
                );
    
                if ( $autologin_after_registering ) {
                    $self->tool->add_message( MESSAGE_SUCCESS,
                        $self->_msg( "Registration done. We have emailed you your account information." )
                    );
                    return $tgid ?
                        $self->redirect( Dicole::URL->from_parts(
                            action => 'groups', task => 'starting_page', target => $tgid,
                            params => {
                                login_login_name => $email,
                                login_password => $plain,
                            },
                        ) )
                        :
                        $self->redirect( Dicole::URL->from_parts(
                            action => 'login', task => 'login',
                            params => {
                                login_login_name => $email,
                                login_password => $plain,
                            },
                        ) );
                }
    
                $self->tool->add_message( MESSAGE_SUCCESS,
                    $self->_msg( "Registration done. We have emailed you your account information. You may now login with the provided information." )
                );
    
                my $redirect = $tgid ? Dicole::URL->from_parts(
                        action => 'groups', task => 'starting_page', target => $tgid,
                    )
                    :
                    OpenInteract2::URL->create_from_action( 'login' );
                return CTX->response->redirect( $redirect );
            }
        }
        $self->tool->add_message( $code, $message );
    }
    
    return $self->_output_invited( $tos_required, $secure_code );
}

sub _output_invited {
    my ( $self, $tos_required, $secure_code ) = @_;
    
    my $page = Dicole::Widget::Vertical->new;
    
    my $group = $self->param('target_group');
    # TODO: Add a cutom name for environment!
    my $target = $group ? $group->name : 'Dicole';
    
    $page->add_content(
        Dicole::Widget::Text->new(
            text => $self->_msg( 'You have been invited to join [_1]. Please log in to claim this invite if you are already registered. Otherwise you can create a new account by filling the form below.', $target ),
            class => 'definitionHeader'
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'First name' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'first_name',
            id => 'invited_first_name',
            value => CTX->request->param('first_name') || '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Last name' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'last_name',
            id => 'invited_last_name',
            value => CTX->request->param('last_name') || '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Email' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'email',
            id => 'invited_email',
            value => CTX->request->param('email') || $secure_code->email || '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Password' ), class => 'definitionHeader' ),
        Dicole::Widget::Raw->new( raw => '<input type="password" name="password" />' ),
    );
    
    if ( $tos_required ) {
        $page->add_content( Dicole::Widget::Inline->new(
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
        ) );
    }
    
    $page->add_content(
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Register (action)'),
                name => 'save',
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Ignore invite'),
                name => 'cancel',
            ),
        ] ),
    );
    
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Invitation to [_1]', $target )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $page
    );
    return $self->generate_tool_content;
}

sub _output_invited_claim {
    my ( $self ) = @_;
    
    my $page = Dicole::Widget::Vertical->new;
    
    my $group = $self->param('target_group');
    my $target = $group->name;
    
    $page->add_content(
        # TODO: add group specific TOS
        Dicole::Widget::Text->new(
            text => $self->_msg( 'You have been invited to join [_1].', $target ),
            class => 'definitionHeader'
        ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Join'),
                name => 'claim'
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Ignore invite'),
                name => 'cancel'
            ),
        ] ),
    );
    
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Invitation to [_1]', $target )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $page
    );
    return $self->generate_tool_content;
}

# TODO: Copy paste from DicoleRegister with changes...  use directly?

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


    my %email_params = ( login_name    => $new_user->{email},
                         user_email    => $new_user->{email},
                         server_url    => $server_url,
                         user_edit_url => $user_edit_url );
    $self->log( 'info', "Sending new user registration details via email to '$admin_email'" );
    my $message = $self->generate_content(
        \%email_params,
        { name => 'dicole_user_manager::new_user_admin_mail' }
    );
    my $subject = $self->_msg( 'New user registered at [_1]', $server_url );
    eval {
        Dicole::Utils::Mail->send(
            text => $message,
            to => $admin_email,
            subject => $subject
        )
    };
    if ( $@ ) {
        $self->log( 'error', "Cannot send email! $@" );
    }
}

# TODO: Copy paste from DicoleRegister...  use directly?

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
     
sub invite {
    my ( $self ) = @_;

    $self->_init_tool;

    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $time = time;

    my $tool = $current_domain ?
        'domain_user_manager_' . $current_domain->id : 'user_manager';
    my $settings = Dicole::Settings->new_fetched_from_params( tool => $tool );
    
    my $max_invites = $settings->setting('invite_limit') || 99;
    my $hours = $settings->setting('invite_replenish');
    $hours = 24 unless defined( $hours ) && $hours ne '0';
    my $after_time = $hours ? $time - ( 3600 * $hours ) : 0;

    my $used_invites = CTX->lookup_object( 'invite' )->fetch_group( {
        where => 'user_id = ? AND domain_id = ? AND invite_date > ?',
        value => [
            CTX->request->auth_user_id,
            $current_domain ? $current_domain->id : 0,
            $after_time,
        ],
    } ) || [];

    my $remaining_invites = $max_invites - scalar @$used_invites;
    $remaining_invites = 999 if $self->chk_y( 'unlimited_invites' );
    
    my $emails = CTX->request->param('invite_email');
    for my $email ( split /\s*[;,]\s*/, $emails) {
    if ( CTX->request->param( 'invite' ) && $email ) {
        # Existing users
        if ( $remaining_invites < 1) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'You do not have any invites left.', $email )
            );
        }
        elsif ( $email !~ /\@/ ) {
            $self->tool->add_message( MESSAGE_ERROR,
                $self->_msg( 'Invalid email: [_1]', $email )
            );
        }
        else {
            my $users = CTX->lookup_object('user')->fetch_group( {
                $current_domain ? ( from => [ 'sys_user', 'dicole_domain_user' ] ) : (),
                where => 'sys_user.email = ?' .
                    ( $current_domain ?
                        ' AND dicole_domain_user.domain_id = ? AND sys_user.user_id = dicole_domain_user.user_id'
                        :
                        ''
                    ),
                value => [ $email, $current_domain ? $current_domain->id : () ],
            } ) || [];
            my $user = pop @$users;
    
            if ( $user ) {
                my $uname = $user->first_name . ' ' . $user->last_name;
                if ( my $gid = $self->param('target_group_id' ) ) {
                    if ( Dicole::Utility->user_belongs_to_group( $user->id, $gid ) ) {
                        $self->tool->add_message( MESSAGE_ERROR,
                            $self->_msg( '[_1] ([_2]) is already a member.', $uname, $email )
                        );
                    }
                    else {
                        $self->_create_invitation(
                            $current_domain, $self->param('target_group'), $email
                        );
                        $remaining_invites--;
                    }
                }
                else {
                    $self->tool->add_message( MESSAGE_ERROR,
                        $self->_msg( '[_1] ([_2]) is already a member.', $uname, $email )
                    );
                }
            }
            else {
                $self->_create_invitation(
                   $current_domain,  $self->param('target_group'), $email
                );
                $remaining_invites--;
            }
        }
    }
    }

    my $invites_string = ( $remaining_invites < 1 ) ?
        $self->_msg( 'No invites remaining.' ) : $remaining_invites;
    $invites_string = $self->_msg('Unlimited invites') if $self->chk_y( 'unlimited_invites' );

    my $page = Dicole::Widget::Vertical->new;
    $page->add_content(
        Dicole::Widget::Text->new( text => $self->_msg( 'Remaining invites' ), class => 'definitionHeader' ),
        Dicole::Widget::Text->new(
            text => $invites_string,
        ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Email' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new( name => 'invite_email' ),
        Dicole::Widget::Text->new( text => $self->_msg( 'Message' ), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextArea->new(
            name => 'invite_message',
            value => CTX->request->param('invite_message') || '',
            rows => 6,
            cols => 80
        ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                value => $self->_msg('Invite'),
                name => 'invite',
            )
        ] ),
        # TODO: Add preview of the template which will be sent ?
    );
    
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Send an invitation' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $page
    );

	return $self->generate_tool_content;
}

1;

__END__
