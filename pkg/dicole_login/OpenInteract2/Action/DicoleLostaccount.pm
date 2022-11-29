package OpenInteract2::Action::DicoleLostaccount;

# $Id: DicoleLostaccount.pm,v 1.18 2009-03-29 23:18:11 amv Exp $

use strict;

use base qw(Dicole::Action);

use Dicole::Generictool;
use Dicole::Generictool::Data;
use Dicole::URL;
use SPOPS::Utility;
use Dicole::Pathutils;
use OpenInteract2::Util;
use OpenInteract2::URL;
use OpenInteract2::Context qw(CTX);

use constant RECOVERY_KEY_LENGTH      => 8;    # characters
use constant RECOVERY_EXPIRATION      => 86400; # seconds = 24h
use constant RECOVERY_LAST_VALID_TIME => time - RECOVERY_EXPIRATION;
use constant KEY_UNUSED               => 0;     # database int

our $VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);

sub lostaccount {
    my ( $self ) = @_;

    $self->init_tool( { tool_args => { no_tool_tabs => 1 } } );

    # Create new Generictool object
    $self->gtool( Dicole::Generictool->new );

    # Lets fake generictool with a fake object. This contains
    # the login form, basically.
    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'email' }
        )
    ] );

    $self->gtool->add_field(
        id => 'email',
        type => 'textfield',
        required => 1,
        desc => $self->_msg( 'Your registered email address' ),
    );

    # Set fields to views
    $self->gtool->set_fields_to_views( views => ['lostaccount'] );

    $self->gtool->current_view( 'lostaccount' );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => OpenInteract2::URL->create_from_action( 'login' )
    );
    $self->gtool->add_bottom_button(
        name  => 'submit',
        value => $self->_msg( 'Submit' ),
    );

    if ( CTX->request->param( 'submit' ) ) {
        if ( CTX->request->param( 'email' ) ) {
            my $data = Dicole::Generictool::Data->new;
            $data->object( CTX->lookup_object('user') );
            $data->query_params( {
                where => 'email = ?',
                value => [ CTX->request->param( 'email' ) ],
            } );
            $data->data_group;


            if ( scalar( @{ $data->data } ) ) { 
                my $goto = '';
                for my $user ( @{ $data->data } ) {
                    if ( my $did = $self->param('domain_id') ) {
                        next unless CTX->lookup_action('dicole_domains')->execute( user_belongs_to_domain => {
                            user_id => $user->id,
                            domain_id => $did,
                        } );
                    }

                    my $o_key = $self->_save_recovery_key($user);
                    if ( ! $o_key) {
                        $self->tool->add_message(0, $self->_msg( 'Failed to save recovery information.'));
                    }
                    else {
                        $self->_send_account_via_email($user, $o_key->{recovery_key});
                        $self->tool->add_message( 1,
                            $self->_msg( 'User account information has been sent to email address: [_1]',
                                CTX->request->param( 'email' ) )
                        );
                        $goto = OpenInteract2::URL->create_from_action('lostaccount_confirm');
                    }
                }
                return CTX->response->redirect( $goto || OpenInteract2::URL->create_from_action('lostaccount') );
            }
            else {
                $self->gtool->get_field( 'email' )->error( 1 );
                $self->tool->add_message( 0,
                    $self->_msg( 'No user account registered with the provided email address: [_1]', CTX->request->param( 'email' ) )
                );
            }
        }
        else {
            $self->gtool->get_field( 'email' )->error( 1 );
            $self->tool->add_message( 0,
                $self->_msg( 'Please provide your registered email address.' )
            );
        }
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Retrieve lost username and password' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );
    return $self->generate_tool_content;
}

sub confirm {
    my $self = shift;

    $self->init_tool( { tool_args => { no_tool_tabs => 1 } } );
    $self->gtool(Dicole::Generictool->new);

    my $key          = CTX->request->param('key');
    my $new_password = CTX->request->param('new_password');
    my $confirm      = CTX->request->param('new_password_confirm');

    if ($key && $new_password) {
        if ($new_password eq $confirm) {
            my $valid = $self->_check_recovery_key($key);
            unless($valid) {
                $self->log('error', "Failed to validate account recovery key [$key].");
                $self->tool->add_message(0, $self->_msg('Failed to validate recovery key.'));
                return CTX->response->redirect(OpenInteract2::URL->create_from_action('lostaccount_confirm'));
            }
            my $o_key = $self->_expire_recovery_key($key);
            unless($o_key) {
                $self->log('error', "Failed to expire account recovery key [$key].");
                $self->tool->add_message(0, $self->_msg('Failed to update account recovery information.'));
                return CTX->response->redirect(OpenInteract2::URL->create_from_action('login'));
            }
            my $res = $self->_change_password($o_key->{user_id}, $new_password);
            unless ($res) {
                $self->log('error', "Failed to change password for uid $o_key->{user_id}.");
                $self->tool->add_message(0, $self->_msg('Failed to change password.'));
                return CTX->response->redirect(OpenInteract2::URL->create_from_action('login'));
            } else {
                $self->log('info', "Password changed for uid $o_key->{user_id}.");
                $self->tool->add_message(1, $self->_msg('Password changed.'));
                return CTX->response->redirect(OpenInteract2::URL->create_from_action('login'));
            }
            $self->tool->add_message(1, $self->_msg('New password saved.'));
            return CTX->response->redirect(OpenInteract2::URL->create_from_action('login'));
        } else {
            $self->tool->add_message(0, $self->_msg("Passwords do not match"));
        }
    } 
    # create form for submitting account recovery key manually
    $self->gtool->current_view('lostaccount_confirm');
    $self->gtool->fake_objects([Dicole::Generictool::FakeObject->new({ id => 'key' })]);
    unless ($key) {
        $self->gtool->add_field(id       => 'key',
                                type     => 'textfield',
                                required => 1,
                                desc     => $self->_msg('Recovery key'));
    }
    $self->gtool->add_field(id       => 'new_password',
                            type     => 'password',
                            required => 1,
                            desc     => $self->_msg('New password'));
    $self->gtool->add_field(id       => 'new_password_confirm',
                            type     => 'password',
                            required => 1,
                            desc     => $self->_msg('Confirm password'));
    $self->gtool->set_fields_to_views;
    $self->gtool->add_bottom_button(type  => 'link',
                                    value => $self->_msg('Cancel'),
                                    link  => OpenInteract2::URL->create_from_action('login'));
    $self->gtool->add_bottom_button(name  => 'submit',
                                    value => $self->_msg('Save'));
    $self->tool->Container->box_at( 0, 0 )->name($self->_msg('Save new password'));
    $self->tool->Container->box_at( 0, 0 )->add_content($self->gtool->get_add);
    
    return $self->generate_tool_content;
}

sub _create_password {
    my ($self, $plain) = @_;
    $plain ||= SPOPS::Utility->generate_random_code(12, 'mixed');
    my $crypted = ( CTX->lookup_login_config->{crypt_password} )
                    ? SPOPS::Utility->crypt_it( $plain ) : $plain;
    return ( $plain, $crypted );
}

sub _generate_random_key {
    my ($self, $len) = @_;
    $len ||= RECOVERY_KEY_LENGTH;

    return SPOPS::Utility->generate_random_code($len, 'mixed');
}

sub _save_recovery_key {
    my ($self, $user) = @_;

    unless($user->{user_id}) {
        return undef;
    }

    my $obj = CTX->lookup_object('account_recovery_key')->new;
    $obj->{user_id}      = $user->{user_id};
    $obj->{recovery_key} = $self->_generate_random_key;
    $obj->{timestamp}    = time;
    $obj->{used}         = KEY_UNUSED;

    $obj->save ? return $obj : return undef;
}

sub _check_recovery_key {
    my ($self, $recovery_key) = @_;
    
    $recovery_key || return undef;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('account_recovery_key'));
    $data->query_params({
        where => 'recovery_key = ? AND timestamp >= ? AND used = ?',
        value => [ $recovery_key, RECOVERY_LAST_VALID_TIME, KEY_UNUSED ],
        order => 'timestamp',
        limit => 1,
    });
    $data->data_group;

    defined($data->data->[0]->{user_id}) ? return $data->data->[0] : return undef;
}

sub _expire_recovery_key {
    my ($self, $key) = @_;

    $key || return undef;

    # fetch key from database
    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('account_recovery_key'));
    $data->query_params({
        where => 'recovery_key = ?',
        value => [ $key ],
        limit => 1,
    });
    $data->data_group;

    # check that key exists
    defined($data->data->[0]->{recovery_key}) ? my $obj = $data->data->[0] : return undef;

    # expire key
    $obj->{used} = 1;
    eval {
        $obj->save;
    };

    $@ ? return undef : return $obj;
}

sub _change_password {
    my ($self, $uid, $pw_plain) = @_;

    unless($uid && $pw_plain) {
        return undef;
    }

    my ($discard, $pw_crypted) = $self->_create_password($pw_plain);
    my $user;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('user'));
    $data->query_params({
        where => 'user_id = ?',
        value => [ $uid ],
        limit => 1,
    });
    $data->data_group;

    unless(ref($data->data->[0])) {
        $self->log('error', "Failed to fetch user $uid from database");
        return undef;
    } else {
        $user = $data->data->[0];
    }

    # save password to Dicole database
    $user->{password} = $pw_crypted;
    eval {
        $user->save;
    };
    if ($@) {
        $self->log('error', "Failed to save user $uid to database");
        return undef;
    }

    if ($user->{external_auth}) {
        # save password to LDAP database
        eval {
            my $la = new Dicole::LDAPAdmin($user->{external_auth});
            my $lu = $la->search_user($user->{login_name});
            my $ret = $la->update_user_password($lu, $pw_plain);
        };
        if ($@) {
            $self->log('error', "Failed to change LDAP password for account [$user->{login_name}]");
            return undef;
        }
    }

    # XXX: returning $user is not good design
    return ($pw_plain, $user);
}

sub _send_account_via_email {
    my ($self, $user, $key) = @_;

    ref($key) && ($key = $key->{recovery_key});

    my $request = CTX->request;
    my $server_url = Dicole::URL->get_server_url;

    # my $url = OpenInteract2::URL->create_from_action('lostaccount_confirm');
    # XXX: what is the correct way to create url to action?
    my $url = Dicole::URL->get_server_url . Dicole::URL->from_parts(
        action => 'lostaccount_confirm', target => 0, params => { key => $key }
    );

    my %email_params = (login       => $user->{login_name},
                        key         => $key,
                        server_name => $server_url,
                        url         => $url);
    $self->log('info', "Sending lost account via email to '$email_params{login}'");
    my $message = $self->generate_content(
        \%email_params,
        { name => 'dicole_login::account_mail' }
    );
    my $subject = $self->_msg( 'User account information from [_1]', $server_url );
    eval {
        Dicole::Utils::Mail->send(
            text => $message,
            to      => $user->{email},
            subject => $subject
        )
    };
    if ($@) {
        $self->log( 'error', "Cannot send email! $@" );
        $self->tool->add_message(0, $self->_msg( 'Error sending email: [_1]', $@ ) );
    }
}

=pod

=head1 NAME

OpenInteract2::Action::DicoleLostaccount

=head1 DESCRIPTION

Resets the user account password and sends a new password to email address provided
by the user in the user account details.

=head1 SEE ALSO

L<OpenInteract2::Action::Login>.

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>.

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
