package OpenInteract2::Action::DicoleMeetingsAPS;

use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _fetch_valid_company_subscription {
    my ( $self ) = @_;

    my $sub_id = CTX->request->param('sub_id');
    return undef unless $sub_id;
    my $sub = CTX->lookup_object('meetings_company_subscription')->fetch( $sub_id );
    # TODO: check that the marketplace matches?
    return $sub if ! $sub->partner_id;

    my $partner = $self->param('partner');
    return undef unless $sub->partner_id == $partner->id;

    return $sub;
}

sub _check_valid_provider_key {
    my ( $self ) = @_;

    my $partner = $self->param('partner');
    my $provider_key = CTX->request->param('provider_key');
    return 0 unless $provider_key && $partner && $partner->api_key;
    return 0 unless $provider_key eq $partner->api_key;
    return 1;
}

sub _return_invalid_secret_error {
    my ( $self ) = @_;

    $self->_return_error( "Invalid authentication" );
}

sub _return_error {
    my ( $self, $error, $code ) = @_;

    $code ||= 1;
    my $output = "    <errors><error id=\"$code\">" . ( $error ? "<message>$error</message>" : '' ) . "</error></errors>";

    return $self->_return_wrapped_configure_output( $output );
}

sub _return_ok {
    my ( $self ) = @_;
    return $self->_return_wrapped_configure_output( "" );
}

sub _return_settings {
    my ( $self, $settings ) = @_;

    my $output = "  <settings>\n";
    for my $key ( keys %$settings ) {
        $output .= "    <setting id=\"$key\">\n";
        $output .= "      <value>" . $settings->{ $key } . "</value>\n";
        $output .= "    </setting>\n";
    }
    $output .= "  </settings>\n";

    return $self->_return_wrapped_configure_output( $output );
}

sub _return_wrapped_configure_output {
    my ( $self, $content ) = @_;

    my $output = "<output xmlns=\"http://apstandard.com/ns/1/configure-output\">\n";
    $output .= $content;
    $output .= "</output>\n";

    return { result => $output };
}

sub configure_company {
    my ( $self ) = @_;

    my $log = $self->_log_aps_command;

    return $self->_return_invalid_secret_error unless $self->_check_valid_provider_key;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');

    my $command = CTX->request->param('command') || '';

    return $self->_return_ok if $command =~ /upgrade|configure/ || $command !~ /install|enable|disable|remove/;

    my $subscription;
    if ( $command =~ /enable|disable|configure|remove|upgrade/ ) {
        $subscription = $self->_fetch_valid_company_subscription;
        $self->_return_error( "Missing required company subscription id" ) unless $subscription;

        if ( $command eq 'enable' ) {
            $subscription->expires_date(0);
        }
        if ( $command eq 'disable' ) {
            $subscription->expires_date(time);
        }
        if ( $command eq 'remove' ) {
            $subscription->cancelled_date(time);
        }

        $subscription->updated_date( time );
    }
    elsif ( $command =~ /install/ ) {
        $subscription = CTX->lookup_object('meetings_company_subscription')->new( {
                domain_id => $domain_id,
                partner_id => $partner ? $partner->id : 0,
                created_date => time,
                creator_id => 0,
                admin_id => 0,
                removed_date => 0,
                remover_id => 0,
                expires_date => 0,
                cancelled_date => 0,
                updated_date => time,
                company_name =>  CTX->request->param('organization_name') || '',
                external_company_id => '', # TODO
                user_amount => 0,
                is_trial => 0,
                is_pro => 1,

                notes => '',
            } );

        $self->_set_note( aps_provisioned => 1, $subscription, { skip_save => 1 } );
    }
    else {
        return $self->_return_error( 'Unknown command: ' + $command );
    }

    if ( ! $subscription ) {
        return $self->_return_ok;
    }

    $subscription->save;

    Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_company_subscription_pro => {
            subscription_id => $subscription->id,
        } );


    return $self->_return_settings( {
        subscription_id => $subscription->id,
    } );
}

sub configure_user {
    my ( $self ) = @_;

    my $log = $self->_log_aps_command;

    return $self->_return_invalid_secret_error unless $self->_check_valid_provider_key;

    my $subscription = $self->_fetch_valid_company_subscription;
    $self->_return_error( "Missing required company subscription id" ) unless $subscription;

    my $domain_id = Dicole::Utils::Domain->guess_current_id;
    my $partner = $self->param('partner');

    my $command = CTX->request->param('command') || '';

    # TODO: configure user_email ???
    return $self->_return_ok if $command =~ /enable|disable|upgrade/ || $command !~ /install|configure|remove/;

    if ( $command eq 'remove' ) {
        my $user_sub = CTX->lookup_object('meetings_company_subscription_user')->fetch( CTX->request->param('sub_user_id') );
        if ( $user_sub && $subscription->id == $user_sub->subscription_id ) {
            $user_sub->removed_date( time );
            $user_sub->save;

            Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_user_pro => {
                    user_id => $user_sub->user_id,
                } );

            my $user = Dicole::Utils::User->ensure_object( $user_sub->user_id );
            $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => 0, $user, $partner->domain_id );

            $self->_send_user_partner_downgrade_email( $user, $partner, $subscription );

            return $self->_return_ok;
        }
        else {
            return $self->_return_error( 'Invalid parameters for remove' );
        }
    }
    elsif ( $command eq 'install' ) {
        my $user_email = CTX->request->param('email');
        my $existing_target_user = eval { $self->_fetch_user_for_email( $user_email ) };
        my $target_user = $existing_target_user || eval { $self->_fetch_or_create_user_for_email( $user_email ) };

        return $self->_return_error( 'Valid email is required for the user' ) unless $target_user;

        $self->_set_note_for_user( meetings_free_trial_disabled => time, $target_user, $partner->domain_id, { skip_save => 1 } )
            unless $self->_get_note_for_user( meetings_free_trial_disabled => $target_user, $partner->domain_id );

        if ( ! $existing_target_user ) {
            my $lang = CTX->request->param('user_language');
            if ( $lang && lc( $lang ) eq 'nl' ) {
                $target_user->language( 'nl' );
            }
            if ( $lang && lc( $lang ) eq 'fr' ) {
                $target_user->language( 'fr' );
            }
            if ( $lang && lc( $lang ) eq 'en' ) {
                $target_user->language( 'en' );
            }
            $self->_set_note_for_user( aps_created_by_partner_id => $partner->id, $target_user, $partner->domain_id, { skip_save => 1 } );
            $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => time, $target_user, $partner->domain_id, { skip_save => 1 } );
        }
        else {
            my $user_subs = CTX->lookup_object('meetings_company_subscription_user')->fetch_group( {
                where => 'user_id = ? AND partner_id = ? AND removed_date = 0',
                value => [ $existing_target_user->user_id, $partner->id ],
            } );

            for my $user_sub ( @$user_subs ) {
                my $active_subs = CTX->lookup_object('meetings_company_subscription')->fetch_group( {
                    where => 'id = ? AND removed_date = 0 AND cancelled_date = 0 AND ( expires_date = 0 OR expires_date > ? )',
                    value => [ $user_sub->subscription_id, time ],
                } );

                return $self->_return_error( 'There is already a subscription for a user with this email' ) if @$active_subs;
            }

            # Automatically allow SSO also if user hasn't got a single meeting yet
            my $user_meetings = $self->_get_user_meetings_in_domain( $existing_target_user, $partner->domain_id );

            if ( ! @$user_meetings ) {
                $self->_set_note_for_user( 'login_allowed_for_partner_' . $partner->id => time, $existing_target_user, $partner->domain_id );
            }
        }

        if ( my $org = CTX->request->param('organization_name') ) {
            $self->_fill_profile_info_from_params( $target_user, $partner->domain_id, { organization => $org } );
        }

        my $fn = CTX->request->param('user_first_name');
        my $ln = CTX->request->param('user_last_name');

        if ( $fn && ! $target_user->first_name ) {
            $target_user->first_name( $fn );
        }

        if ( $ln && ! $target_user->last_name ) {
            $target_user->last_name( $ln );
        }

        $target_user->save;

        my $token = $self->_create_partner_authentication_checksum_for_user( $partner, $target_user );
        my $assignment = $self->_assing_user_to_company_subscription( $target_user, $subscription, 0 );

        $self->_send_user_partner_upgrade_email( $target_user, $partner, $subscription );

        return $self->_return_settings( {
            user_token => $token,
            subscription_user_id => $assignment->id,
        } );
    }
    elsif ( $command eq 'configure' ) {
        my $user_sub = CTX->lookup_object('meetings_company_subscription_user')->fetch( CTX->request->param('sub_user_id') );
        if ( $user_sub && $subscription->id == $user_sub->subscription_id ) {
            my $user = Dicole::Utils::User->ensure_object( $user_sub->user_id );

            if ( ! $self->_get_note_for_user( 'login_allowed_for_partner_' . $partner->id, $user, $partner->domain_id ) ) {
                return $self->_return_error( 'Can not change information for a user without single signon verification' );
            }

            my $new_email = CTX->request->param('email');

            if ( $user->email ne $new_email ) {

                my $existing_target_user = eval { $self->_fetch_user_for_email( $new_email ) };

                if ( ! $existing_target_user || $existing_target_user->id == $user->id ) {
                    $user->email( $new_email );
                }
                else {
                    my $old_user = $user;
                    $user = $existing_target_user;
                    $user_sub->user_id( $user->id );
                    $user_sub->save;

                    Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_user_pro => {
                        user_id => $old_user->id,
                    } );
                    Dicole::Utils::Gearman->dispatch_versioned_task( recalculate_user_pro => {
                        user_id => $user->id,
                    } );
                }
            }

            my $lang = CTX->request->param('user_language');

            if ( $lang && lc( $lang ) eq 'nl' ) {
                $user->language( 'nl' );
            }
            if ( $lang && lc( $lang ) eq 'fr' ) {
                $user->language( 'fr' );
            }
            if ( $lang && lc( $lang ) eq 'en' ) {
                $user->language( 'en' );
            }

            if ( my $fn = CTX->request->param('user_first_name') ) {
                $user->first_name( $fn );
            }

            if ( my $ln = CTX->request->param('user_last_name') ) {
                $user->last_name( $ln );
            }

            $user->save;

            if ( my $org = CTX->request->param('organization_name') ) {
                $self->_fill_profile_info_from_params( $user, $user_sub->domain_id, { organization => $org } );
            }

            my $token = $self->_create_partner_authentication_checksum_for_user( $partner, $user );

            $self->_send_user_partner_upgrade_email( $user, $partner, $subscription );

            return $self->_return_settings( {
                user_token => $token
            } );
        }
        else {
            return $self->_return_error( 'Invalid parameters for configure' );
        }
    }

    return $self->_return_error( 'Unknown command: ' + $command );
}

sub _send_user_partner_upgrade_email {
    my ( $self, $user, $partner, $subscription ) = @_;

    return if $user->email =~ /^user.+\@c.+\.cdashboard\.be$/;

    my $url = Dicole::URL->from_parts(
        domain_id => $partner->domain_id, partner_id => $partner->id, target => 0,
        action => 'meetings', task => 'summary'
    );

    my $authorized_uri = $self->_generate_authorized_uri_for_user( $url, $user, $partner->domain_id );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $partner->domain_id,
        partner_id => $partner->id,
        group_id => 0,

        template_key_base => 'meetings_account_upgraded',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            login_url => $authorized_uri,
            new_user => 0,
            provisioned_user => 1,
            partner_support_url => $self->_get_note( support_url => $partner ) || '',
            provisioner_user_name => $subscription->company_name,
            customize_for_cmeet => $partner->domain_alias =~ /cmeet/ ? 1 : 0,
        },
    );
}

sub _send_user_partner_downgrade_email {
    my ( $self, $user, $partner, $subscription ) = @_;

    return if $user->email =~ /^user.+\@c.+\.cdashboard\.be$/;

    my $url = Dicole::URL->from_parts(
        domain_id => $partner->domain_id, partner_id => $partner->id, target => 0,
        action => 'meetings', task => 'summary'
    );

    my $authorized_uri = $self->_generate_authorized_uri_for_user( $url, $user, $partner->domain_id );

    $self->_send_partner_themed_mail(
        user => $user,
        domain_id => $partner->domain_id,
        partner_id => $partner->id,
        group_id => 0,

        template_key_base => 'meetings_company_subscription_terminated',
        template_params => {
            user_name => Dicole::Utils::User->name( $user ),
            login_url => $authorized_uri,
            organization => $subscription->company_name,
        },
    );
}

sub _log_aps_command {
    my ( $self ) = @_;

    my $cgi = CTX->request->cgi;
    my @keys = ( $cgi->url_param, $cgi->param );

    my %payload = map { $_ => "" . CTX->request->param( $_ ) } @keys;
    my $payload = Dicole::Utils::JSON->encode( \%payload );

    CTX->lookup_object('meetings_aps_command')->new( {
        domain_id => Dicole::Utils::Domain->guess_current_id,
        partner_id => $self->param('partner_id'),
        created_date => time,
        command_type => $self->task,
        payload => $payload,
    } )->save;
}

1;
