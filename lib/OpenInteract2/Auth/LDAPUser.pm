package OpenInteract2::Auth::LDAPUser;

# $Id: LDAPUser.pm,v 1.40 2009-05-18 02:03:45 amv Exp $

use strict;

use base qw( OpenInteract2::Auth::DicoleUser );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Security qw( :receiver :target :check );
use Dicole::Utility;
use Dicole::LDAPUser;
use Net::LDAP;
use Net::LDAP::Filter;
use SPOPS::Utility;

use constant USER_STATUS => {
    'enabled'   => 0,
    'disabled'  => 1,
};

our $VERSION  = sprintf("%d.%02d", q$Revision: 1.40 $ =~ /(\d+)\.(\d+)/);

my $log;

sub _login_user_from_input {
    my ($self) = @_;

    $log ||= get_logger( LOG_AUTH );

    my $login_config   = CTX->lookup_login_config;

    my $domain_field   = $login_config->{domain_field};
    my $login_field    = $login_config->{login_field};
    my $password_field = $login_config->{password_field};

    my $ldap_key       = CTX->request->param($domain_field) if $domain_field;
    my $login_name     = CTX->request->param($login_field);
    my $password       = CTX->request->param($password_field);

    $ldap_key = $self->_resolve_ldap_key( $login_name ) unless $ldap_key;
    
#    $log->debug("Before local domain prefix check user is ".
#        "'$login_name' and domain is '$ldap_key'");

    # Log in as local user if local: supplied before username
    # Does not work..
#     if ( $login_name =~ /^local:/i ) {
#         $login_name =~ s/^local:\s*//i;
#         $ldap_key = 'local';
#     }

    $log->info("Logging in as user '$login_name' to domain '$ldap_key'")
        if $login_name;

    # check that user supplied domain, username and password
    unless ($ldap_key) {
        return undef;
    }
    
    # local login: check Dicole user
    # NOTE: this means that user can't have LDAP server named "local" in server.ini
    if ($ldap_key =~ /^local$/i) {
        my $user = $self->SUPER::_login_user_from_input;
        return $user;
    }


    my $l = eval {
        new Dicole::LDAPUser( {
            ldap_server_name => $ldap_key,
            login_name       => $login_name,
            password         => $password
        });
    };
    if ($@) {
        $log->warn("Failed to fetch user object [$login_name] from " .
            "LDAP Database [$ldap_key]");
        return undef;
    }
    if ($l && $l->is_filled ) {
        unless ( $l->check_password ) {
            $log->warn("Password check for [$login_name] through LDAP ".
                "server [$ldap_key] failed");
            
            CTX->request->add_action_message(
                'login_box', 'login', 'Invalid login, please try again.'
            );
            
            return undef;
        }
    }
    else {
        $log->info("User [$login_name] not found in LDAP database [$ldap_key]");
    
        my $user = $self->SUPER::_login_user_from_input( allow_external => 1 );
        
        return undef unless $user;
        
        # Return if user can't log in to current domain
        return $user if eval {
            my $dd = CTX->lookup_action('dicole_domains');
            my $domain_id = $dd->get_current_domain->id;
            my $user_domains = $dd->get_user_domains( $user->id ) || [];
            return 0 if grep { $domain_id == $_ } @$user_domains;
            return 1;
        };
        
        return undef unless Dicole::LDAPAdmin->updates_allowed;
        
        if ( $user->{external_auth} && $ldap_key eq $user->{external_auth} ) {
        
            $log->info("Creating entry for user [$login_name] ".
                "in LDAP database [$ldap_key]");
        
            # TODO: publish this as an action!
            OpenInteract2::Action::UserManager->_create_ldap_user(
                $user, $password, $ldap_key
            );
        
            $l = eval {
                new Dicole::LDAPUser( {
                    ldap_server_name => $ldap_key,
                    login_name       => $login_name,
                    password         => $password
                });
            };
        
            unless ($l && $l->is_filled ) {
                $log->warn("Could not find user [$login_name] after creation!");
                CTX->request->add_action_message(
                    'login_box', 'login', 'New user creation failed.'
                );
                
                return undef;
            }
        }
    }

    # check Dicole user from database, return user object if found
    my $user = eval { CTX->lookup_object( 'user' )->fetch_by_login_name(
        $login_name, { skip_security => 1 }
    ) };
    
    if ( $user ) {
        return undef unless $self->_check_login_disabled( $user );
        
        if ( $l && $l->is_filled ) {
            $self->_map_ldap_to_user( $l, $password, $user );
            $user->save;
        }
        
        return $user;
    }

    # LDAP authentication succesfull but no user object in local db.
    # Create new user from data found in LDAP.
    my $new_user = CTX->lookup_object('user')->new;

    $new_user->{login_name}    = $login_name;
    $new_user->{language}      = CTX->server_config->{language}{default_language}; # XXX: -> ?
    $new_user->{theme_id}      = CTX->lookup_default_object_id( 'theme' );
    $new_user->{external_auth} = $ldap_key; # user external (LDAP) authentication
    $new_user->{incomplete}    = 1; # user must fill in rest of the data
    
    $self->_map_ldap_to_user( $l, $password, $new_user );

    eval {
        $new_user->save;
    };
    if ($@) {
        $log->warn("User object saving failed: $@");
        CTX->request->add_action_message('login_box', 'login', 'New user creation failed.');
        return undef;
    }
    
    if ( my $dd = eval { CTX->lookup_action('dicole_domains') } ) {
        eval {
            my $du = CTX->lookup_object( 'dicole_domain_user' )->new;
            $du->{domain_id} = $dd->get_current_domain->{domain_id};
            $du->{user_id}   = $new_user->{user_id};
            $du->save;
        };
        if ($@) {
            $log->warn("Failed to add user to domain: $@");
        }
    }

    # some additional user initialisation tasks
    # TODO: publish this as an action!
    eval {
        OpenInteract2::Action::UserManager->_new_user_operations($new_user->user_id, $new_user);
    };

    # If configuration spesifies a security to be given based on a certain field,
    # lookup the LDAP object for that field
    if ( $l->config->{sec_based_on_field} ) {
        my $memberOf_field = $l->field( $l->config->{sec_field} );
        if ($memberOf_field) {
            # Check if field has some spesific string
            if ($memberOf_field =~ /$l->config->{sec_field_string}/) {

                # Collection id based on idstring in server configuration
                my $cols = CTX->lookup_object('dicole_security_collection')->fetch_group( {
                    where => 'idstring = ?',
                    value => [ $l->config->{sec_collection_idstring} ]
                    } );

                # XXX: revoking security object if value in LDAP db changes?
                # If collection was returned, add security for user
                if ( $cols->[0]{collection_id} ) {
                    my $o = CTX->lookup_object('dicole_security')->new;
                    $o->{receiver_user_id} = $new_user->user_id;
                    $o->{collection_id} = $cols->[0]{collection_id};
                    $o->{target_type} = TARGET_SYSTEM;
                    $o->{receiver_type} = RECEIVER_USER;
                    $o->save;
                }
            }
        }
    }

    return $new_user;
}

sub _resolve_ldap_key {
    my ( $self, $login_name ) = @_;

    my $ldap_key = 'local';

    my $user = eval { 
        CTX->lookup_object( 'user' )->fetch_by_login_name(
            $login_name, { skip_security => 1 }
        )
    };

    return $user->{external_auth} if $user && $user->{external_auth};

    my $domain = eval {
        CTX->lookup_action('dicole_domains')->get_current_domain;
    };

    return $domain->{external_auth} if $domain && $domain->{external_auth};

    return $ldap_key;
}

sub _map_ldap_to_user {
    my ( $self, $ldap_user, $password, $user ) = @_;
    
    $user->{first_name} = $ldap_user->field(
        $ldap_user->config->{ldap_attribute_firstname}
    );
    
    $user->{last_name} = $ldap_user->field(
        $ldap_user->config->{ldap_attribute_lastname}
    );
    
    $user->{email} = $ldap_user->field(
        $ldap_user->config->{ldap_attribute_email}
    );
    
    my $crypted = ( CTX->lookup_login_config->{crypt_password} ) ? 
        SPOPS::Utility->crypt_it( $password ) : $password;
    
    $user->{password} = $crypted;
}

1;
