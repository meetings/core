package OpenInteract2::Action::UserManagerCommon;

use strict;
use base ( qw/ Dicole::Action / );

use Dicole::Utils::User;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Security qw( :receiver :target :check );
use Dicole::MessageHandler qw( :message );

sub _new_user_operations {
    my ( $self, $uid, $user, $domain_id ) = @_;

    $user ||= Dicole::Utils::User->ensure_object( $uid );
    $uid ||= $user->id;

    Dicole::Utils::User->update_full_name( $user );

    # Add default_personal_rights collections to user
    if ( my $coll = Dicole::Security->collection_by_idstring(
            'default_personal_rights' ) ) {

        my $sec = CTX->lookup_object( 'dicole_security' )->new;

        $sec->{receiver_user_id} = $uid;
        $sec->{target_user_id} = $uid;
        $sec->{collection_id} = $coll->id;
        $sec->{target_type} = TARGET_USER;
        $sec->{receiver_type} = RECEIVER_USER;

        $sec->save;
    }

    # set default group default mail reminder settings to daily
    Dicole::Settings->store_single_setting(
        user_id => $uid,
        tool => 'settings_reminders',
        attribute => 'group_default',
        value => 'daily',
    );
    
    $self->_domain_join_operations( $uid, $user, $domain_id );

    return 1;
}

sub _domain_join_operations {
    my ( $self, $uid, $user, $domain_id ) = @_;

    $user ||= Dicole::Utils::User->ensure_object( $uid );
    $uid ||= $user->id;

    # Creates a default profile for user
    CTX->lookup_action('networking_api')->e( user_profile_object => {
        user_id => $uid, domain_id => $domain_id,
    } );

    if ( $domain_id ) {
        CTX->lookup_action('domains_api')->e( domain_custom_new_user_actions => {
            user_id => $uid, domain_id => $domain_id,
        } );
    }

    my $initial_groups = Dicole::Settings->fetch_single_setting(
        tool => Dicole::Utils::Domain->guess_current_settings_tool( $domain_id ),
        attribute => 'initial_groups'
    );

    for my $gid ( split /\s*,\s*/, $initial_groups ) {
        next unless $gid;
        eval {
            my $group = CTX->lookup_object('groups')->fetch( $gid );
            next unless $group;

            my $group_belongs_to_domain = $domain_id ? CTX->lookup_action('domains_api')->e( group_belongs_to_domain => {
                group_id => $gid, domain_id => $domain_id 
            } ) : 1; 

            if ( $group_belongs_to_domain ) {
                CTX->lookup_action('groups_api')->e ( add_user_to_group => {
                    user_id => $uid,
                    group_id => $group->id,
                    domain_id => $domain_id,
                } );
            }
        };
        if ( $@ ) {
            $self->log( error => 'Could not add user $uid to group $gid: $@' );
        }
    }

    my $possible_groups = CTX->lookup_object('groups')->fetch_group({
        where => 'meta LIKE ?',
        value => [ '%auto_user_email_domains%' ],
    });

    my $email_domain = $user->email;
    $email_domain =~ s/^.*\@//;

    for my $group ( @$possible_groups ) {
        next unless CTX->lookup_action('domains_api')->e( group_belongs_to_domain => { group_id => $group->id, domain_id => $domain_id } );
        my $meta = CTX->lookup_action('groups_api')->e( meta_to_data => { group => $group } );

        my @domains = split /\s*\,\s*/, $meta->{auto_user_email_domains};
        for my $domain ( @domains ) {
            if ( lc( $domain ) eq lc( $email_domain ) ) {
                CTX->lookup_action('groups_api')->e ( add_user_to_group => {
                    user_id => $uid,
                    group_id => $group->id,
                    domain_id => $domain_id,
                } );
            }
        }
    }

    my $notedata = Dicole::Utils::JSON->decode( $user->notes || '{}' );
    if ( ! $notedata->{ $domain_id }{creation_time} ) {
        $notedata->{ $domain_id }{creation_time} = time;
    }
    else {
        push @{ $notedata->{ $domain_id }{additional_creation_times} }, time;
    }
    $user->notes( Dicole::Utils::JSON->encode( $notedata ) );
    $user->save;

    return 1;
}

sub _create_domain_ldap_user {
    my ($self, $domain_id, $user, $plain_pass) = @_;

    my $create_server = undef;
    eval {
        my $domain = CTX->lookup_object('dicole_domain')->fetch( $domain_id );
        $create_server = $domain->external_auth;
    };

    $create_server ||= CTX->lookup_login_config->{create_server}->{default};

    return unless $create_server && $create_server !~ /^local$/i;

    return $self->_create_ldap_user(
        $user, $plain_pass, $create_server
    );
}

sub _create_ldap_user {
    my ($self, $data, $pass, $ldap_server) = @_;
    
    # LDAP inetOrgPerson canonical name form
    my $cn = $data->{first_name} . ' ' . $data->{last_name};
    my $cs = $ldap_server;

    my $rs = eval {
        my $lu = new Dicole::LDAPUser({ldap_server_name => $cs,
                                       login_name       => $data->{login_name}});
        $lu->field('uid', $data->{login_name});
        $lu->field('first_name', $data->{first_name});
        $lu->field('last_name', $data->{last_name});
        $lu->field('cn', $cn);
        $lu->field('email', $data->{email});
        $lu->field('language', $data->{language});

        my $la = new Dicole::LDAPAdmin($cs);
        if (! $la->create_user($lu)) {
            my $lname = $data->{login_name};
            $self->log('warn', "Creating LDAP user $lname in server $cs failed");
            return undef;
        }

        return $la->update_user_password($lu, $pass);
    };
    if ($@) {
        my $lname = $data->{login_name};
        $self->log( 'warn',
            "Creating LDAP user $lname in server $cs failed: $@"
        );
        return undef;
    }

    return $rs;
}

sub _create_plaintext_and_crypted_passwords {
    my ( $self, $plain ) = @_;
    $plain ||= SPOPS::Utility->generate_random_code( 6 );
    my $crypted = SPOPS::Utility->crypt_it( $plain );
    return ( $plain, $crypted );
}

sub _send_new_user_email {
    my ( $self, $user, $password, $group_id, $domain_id ) = @_;

    my $server_url = Dicole::URL->get_domain_url( $domain_id );

    my %email_params = (
                        login       => $user->{login_name},
                        first_name  => $user->{first_name},
                        last_name   => $user->{last_name},
                        password    => $password,
                        server_name => $server_url
                       );

    my $settings = Dicole::Settings->new_fetched_from_params(
        user_id => 0,
        group_id => 0,
        tool => Dicole::Utils::Domain->guess_current_settings_tool( $domain_id ),
    );

    my $settings_hash = $settings->settings_as_hash;

    my ( $message, $subject );

    if ( $settings_hash->{'account_email'} ) {
        my $tt = Template->new;
        $tt->process( \$settings_hash->{'account_email'}, \%email_params, \$message );
    }
    else {
        $message = $self->generate_content(
            \%email_params,
            { name => 'dicole_domain_user_manager::new_user_mail' }
        );
    }

    if ( $settings_hash->{'account_email_subject'} ) {
        my $tt = Template->new;
        $tt->process( \$settings_hash->{'account_email_subject'}, \%email_params, \$subject );
    }
    else {
        $subject = $self->_msg( 'Registration information from [_1]', $server_url );
    }

    eval {
        Dicole::Utils::Mail->send(
            user => $user,
            subject => $subject,
            text => $message,
        )
    };
    if ( $@ ) {
        $self->log( 'error', "Cannot send email! $@" );
        Dicole::MessageHandler->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error sending email: [_1]', $@ )
        );
    }
}

sub _send_new_user_admin_email {
    my ( $self, $new_user, $domain_id ) = @_;

    my $admin_email = CTX->lookup_action( 'domains_api' )->e( domain_admin_email => { domain_id => $domain_id } ) ||
        CTX->server_config->{dicole}{user_registration};

    my $server_url = Dicole::URL->get_domain_url( $domain_id );

    my $user_edit_url = $server_url .  Dicole::URL->from_parts(
        domain_id => $domain_id,
        action => $domain_id ? 'dusermanager' : 'usermanager',
        task => 'show',
        target => 0,
        params => { uid => $new_user->id },
    );

    my %email_params = (
        login_name    => $new_user->{login_name},
        user_email    => $new_user->{email},
        server_url    => $server_url,
        user_edit_url => $user_edit_url,
    );

    my $message = $self->generate_content(
        \%email_params,
        { name => 'dicole_user_manager::new_user_admin_mail' }
    );
    my $subject = $self->_msg( 'New user registered at [_1]', $server_url );
    eval {
        Dicole::Utils::Mail->send(
            text    => $message,
            to      => $admin_email,
            subject => $subject
        )
    };
    if ( $@ ) {
        $self->log( 'error', "Cannot send email! $@" );
    }
}


1;
