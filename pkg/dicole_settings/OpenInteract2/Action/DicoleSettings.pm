package OpenInteract2::Action::DicoleSettings;

# $Id: DicoleSettings.pm,v 1.12 2010-07-28 13:35:16 amv Exp $

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler qw( :message );
use SPOPS::Utility;

use Dicole::Tool;
use Dicole::LDAPUser;
use DateTime::TimeZone;
use Dicole::Generictool;
use Dicole::Widget::Listing;
use Dicole::Widget::Image;
use Dicole::Widget::LinkImage;
use Dicole::Settings;
use Dicole::Task::GTSettings;

use base qw( Dicole::Action );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

sub detect {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_url(
        task => Dicole::Utils::Domain->setting( undef, 'hide_general_settings' ) ?
            ( Dicole::Utils::Domain->setting( undef, 'disable_notifications' ) ? 'change' : 'reminders' ) : 'settings',
    ) );
}

# Initialize tool
sub _init_tool {
    my $self = shift;
    my $p = {
        cols => 2,
        tool_args => { no_tool_tabs => 1 },
        @_,
    };
    $self->init_tool( $p );

    my $disabled = [];
    push @$disabled, 'tab_1' if Dicole::Utils::Domain->setting( undef, 'hide_general_settings' );
    push @$disabled, 'tab_2' if Dicole::Utils::Domain->setting( undef, 'disable_notifications' );
    
    my $navi = $self->tool->get_tablink_box( $self->_msg('Navigation'), $disabled );
    $self->tool->Container->box_at( 0, 0 )->name( $navi->{name} );
    $self->tool->Container->box_at( 0, 0 )->content( $navi->{content} );
}

# Generates timezone selection dropdown
sub _generate_timezones {
    my ( $self ) = @_;
    my $timezone = $self->gtool->get_field( 'timezone' );
    $timezone->add_dropdown_item( '', $self->_msg( '-- Select --' ) );
    foreach my $zone ( @{ DateTime::TimeZone->all_names } ) {
        $timezone->add_dropdown_item( $zone, $zone );
    }
}

# Generates strating page selection dropdown
sub _generate_starting_page {
    my ( $self, $uid ) = @_;
    my $starting_page = $self->gtool->get_field( 'starting_page' );
#    $starting_page->add_dropdown_item( 0, $self->_msg( 'Personal summary' ) ) if $self->param('target_type') eq 'user';
    my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
        from => [ qw(dicole_groups dicole_group_user) ],
        where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
            . 'AND dicole_group_user.user_id = ?',
        value => [ $uid ]
    } );
    
    my $gids = eval { CTX->lookup_action('dicole_domains')->groups_by_domain };
    my %gidhash = $gids ? map { $_ => 1 } @$gids : ();
    
    foreach my $group ( @{ $groups } ) {
        next if $gids && ! $gidhash{ $group->id };
        $starting_page->add_dropdown_item( $group->id, $group->{name} );
    }
}

sub _determine_uid_or_redirect {
    my ( $self ) = @_;
    
    my $uid = $self->param('target_type') eq 'user' ? $self->param('target_user_id') : $self->param('user_id');
    if ( ! defined( $uid ) ) {
        die $self->redirect( $self->derive_url( additional => [ CTX->request->auth_user_id ] ) );
    }
    else {
        die "security error" unless $self->schk_y( 'OpenInteract2::Action::DicoleSettings::reminders', $uid );
    }
    
    return $uid;
}

sub reminders {
    my ( $self ) = @_;

    my $uid = $self->_determine_uid_or_redirect;
    
    my $settings = Dicole::Settings->new;
    # Modify settings of current action based on current user
    $settings->user( 1 );
    $settings->user_id( $uid );
    $settings->tool( 'settings_reminders' );
    # Fetch settings based on above configuration
    $settings->fetch_settings;

    $self->_share_matrix_process_params( $settings );

    my %reminder_day = ();
    my %reminder_week = ();
    my %reminder_month = ();

    my $matrix = Dicole::Widget::Listing->new( use_keys => 1 );

    # add all keys
    $matrix->add_key( content => $self->_msg( 'Subscribe' ) );
    $matrix->add_key( content => $self->_msg( 'No reminders' ) );
    $matrix->add_key( content => $self->_msg( 'Daily' ) );
    $matrix->add_key( content => $self->_msg( 'Weekly' ) );
    $matrix->add_key( content => $self->_msg( 'Monthly' ) );

    my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
        from => [ qw(dicole_groups dicole_group_user) ],
        where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
            . 'AND dicole_group_user.user_id = ?',
        value => [ $uid ],
        order => 'dicole_groups.name'
    } ) || [];

    my @domain_groups = ();

    eval {
        my $ids = CTX->lookup_action( 'dicole_domains' )
            ->execute( 'groups_by_domain' );
        my %idcheck = map { $_ => 1 } @$ids;
        for ( @$groups ) {
            push @domain_groups, $_ if $idcheck{ $_->id };
        }
    };

    if ( $@ ) {
        @domain_groups = @$groups;
    }

    my @lines = map { [ $_->id, $_->name ] } @domain_groups;
    unshift @lines, [ 0, $self->_msg('Personal feed reader') ] if $self->param('target_type') eq 'user';
    push @lines, [
        'group_default',
        $self->_msg('Default when joining a group')
    ];

    # add rows for each groups
    for my $line ( @lines ) {
        $matrix->new_row;
        $matrix->add_cell( content => $line->[1] );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $settings, $line->[0], 'none'
            )
        );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $settings, $line->[0], 'daily'
            )
        );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $settings, $line->[0], 'weekly'
            )
        );
        $matrix->add_cell( content =>
            $self->_get_share_status_widget(
                $settings, $line->[0], 'monthly'
            )
        );
    }

    $self->_init_tool;

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg('Subscribe to email reminders') );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ $matrix ]
    );

    return $self->generate_tool_content;
}

sub _get_share_status_widget {
    my ( $self, $reminder_status, $group_id, $mode ) = @_;

    my $status = $reminder_status->setting( $group_id ) || 'none';
    if ( $status eq $mode ) {
        return Dicole::Widget::Image->new(
            src => '/images/theme/default/navigation/icons/16x16/true.gif',
            width => 16,
            height => 16
        );
    }
    else {
        return Dicole::Widget::LinkImage->new(
            link => $self->derive_url(
                params => {
                    groups_id => $group_id,
                    mode => $mode
                },
            ),
            src => '/images/theme/default/navigation/icons/16x16/false.gif',
            width => 16,
            height => 16
        );
    }

}

sub _share_matrix_process_params {
    my ( $self, $settings ) = @_;

    my $group_id = CTX->request->param( 'groups_id' );
    my $mode = CTX->request->param( 'mode' );

    return unless grep { $_ eq $mode } ( qw(daily weekly monthly none) );

    if ( $mode eq 'none' ) {
        $settings->remove_setting( $group_id );
    }
    else {
        $settings->setting( $group_id, $mode );
    }

    $self->redirect( $self->derive_url( params => {}, additional => [] ) );
}

sub settings {
    my ( $self ) = @_;

    return $self->redirect( $self->derive_url(
        task => 'reminders',
    ) ) if eval { CTX->lookup_action('domains_api')->e( get_domain_setting => {
            attribute => 'hide_general_settings',
        } ) };

    my $uid = $self->_determine_uid_or_redirect;
    
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    my $domain = $dicole_domains ? eval { $dicole_domains->get_current_domain } : undef;
    my $domain_id = $domain ? $domain->id : 0;
    
    # megahack :D
    my $sg = Dicole::Settings->fetch_single_setting(
        user_id => $uid,
        tool => 'login',
        attribute => 'starting_group_' . $domain_id,
    );

    if ( $sg ) {
        my $user = CTX->lookup_object('user')->fetch( $uid );
        $user->starting_page( $sg );
        $user->save;
    }

    $self->_init_tool;
    $self->gtool( Dicole::Generictool->new(
            object => CTX->lookup_object('user'),
            skip_security => 1,
            current_view => 'settings',
    ) );
    $self->init_fields;
    
    # Fill timezone dropdown with items
    $self->_generate_timezones;

    # Generate my groups in the starting page dropdown
    $self->_generate_starting_page( $uid );

    # if save button is pressed...
    if ( CTX->request->param( 'save' ) ) {
        if (CTX->request->auth_user->{external_auth} &&
            CTX->request->param('language')) {
            # save language to LDAP database
            eval {
                my $l = Dicole::LDAPUser->new({
                    ldap_server_name => CTX->request->auth_user->{external_auth},
                    login_name       => CTX->request->auth_user->{login_name}});
                $l->field('language', CTX->request->param('language'));
                my $res = $l->update;
                unless ($res) {
                    # failed to save language to LDAP database; this is a non-fatal error
                    my $ln = CTX->request->auth_user->{login_name};
                    my $ea = CTX->request->auth_user->{external_auth};
                    $self->log('warn', "Failed to save LDAP info for user [$ln] on server [$ea]");
                }
            };
        }

        # Check validity of fields. Save if ok.
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields,
            { object_id => $uid }
        );
        # Set status message and redirect to appropriate location
        if ( $code ) {
            # Update cached user object in the request if user object changed
            if ( CTX->request->auth_user_id eq $uid ) {
                $self->log( 'info',
                    "Updating cached auth user in request for user id [$uid]"
                );
                my $session = CTX->request->session;
                $session->{_oi_cache}{user_refresh_on} = time;
                $session->{lang} = undef;
            }
            $self->tool->add_message( $code, $self->_msg( "Changes were saved." ) );
            # megahack :D
            if ( $sg ) {
                my $user = CTX->lookup_object('user')->fetch( $uid );
                if ( $user->starting_page != $sg ) {
                    Dicole::Settings->store_single_setting(
                        user_id => $uid,
                        tool => 'login',
                        attribute => 'starting_group_' . $domain_id,
                        value => $user->starting_page,
                    );
                }
            }
            # We have to redirect to make changes in the session effective
            return CTX->response->redirect(
                Dicole::URL->create_from_current(
                    task => 'settings'
                )
            );
        } else {
            $self->tool->add_message( $code,
                $self->_msg( "Account settings modification failed: [_1]", $message )
            );
        }
    }

    # Modifying account settings
    $self->tool->Container->box_at( 1, 0 )->name(
        $self->_msg( 'User account settings' )
    );
    $self->gtool->add_bottom_button(
        name  => 'save',
        value => $self->_msg( 'Save' ),
    );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        $self->gtool->get_edit( id => $uid )
    );

    return $self->generate_tool_content;
}

sub change {
    my ( $self ) = @_;

    my $uid = $self->_determine_uid_or_redirect;
    my $user = CTX->request->auth_user_id == $uid ? CTX->request->auth_user : CTX->lookup_object('user')->fetch( $uid );
    die "security error" unless $user;

    $self->_init_tool;
    $self->tool->Path->add( name => $self->_msg( 'Login settings' ) );

#        id       => 'old_password',
#        id       => 'password',

    # LDAP password, specified in database (sys_user.external_auth)
    if (CTX->request->param('change') && CTX->request->auth_is_logged_in ) {
        if ( ! ( CTX->request->param('password') eq CTX->request->param('password_confirm') ) ) {
            $self->tool->add_message(MESSAGE_ERROR, $self->_msg("Passwords don't match"));
        }
        elsif ($user->{external_auth} && ! ($user->{external_auth} =~ /local/i)) {
            my $l = Dicole::LDAPUser->new({
                ldap_server_name => $user->{external_auth},
                login_name => $user->{login_name},
                password => CTX->request->param('old_password')
            });
            if ($l->check_password) {
                if ($l->password(CTX->request->param('password')) && $l->update) {
                    $self->tool->add_message(MESSAGE_SUCCESS, $self->_msg('New password saved.'));
                }
                else {
                    $self->tool->add_message(MESSAGE_ERROR, $self->_msg('Password modification failed'));
                }
            }
            else {
                $self->tool->add_message(MESSAGE_ERROR, $self->_msg('Old password authentication failed'));
            }
        }
        else {
            if ( CTX->lookup_login_config->{disable_superuser_password_change} && CTX->request->auth_is_admin ) {
                $self->tool->add_message(MESSAGE_ERROR, $self->_msg('Administrator is not allowed to change the password.'));
            }
            elsif (! CTX->request->auth_user->check_password(CTX->request->param('old_password'))) {
                $self->tool->add_message(MESSAGE_ERROR, $self->_msg( 'Old password is not correct.'));
            }
            else {
                my $crypted = ( CTX->lookup_login_config->{crypt_password} ) ?
                    SPOPS::Utility->crypt_it( CTX->request->param('password') ) : CTX->request->param('password');
                $user->password( $crypted );
                $user->save;

                $self->tool->add_message( MESSAGE_SUCCESS, $self->_msg( 'New password saved.'));
            }
        }
    }

    $self->tool->add_head_widgets( Dicole::Widget::Javascript->new(
        code => 'dojo.require("dicole.settings");',
    ) );

    my $params = {};
    my $globals = {};

    my ( $fb_id, $fb_secret, $fb_disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    unless ( $fb_disabled ) {

        $params = {
            %$params,
            facebook_connect_app_id => $fb_id,
            facebook_connected => $user->facebook_user_id ? 1 : 0,
        };
 
        my $uid_hash = Digest::MD5::md5_hex(Dicole::Utils::User->authorization_key_invalidation_secret( $uid ) . 'fb' );
        $globals = {
            %$globals,
            connect_facebook_url => $self->derive_url( task => 'connect_facebook', additional => [ $uid, $uid_hash ] ),
            disconnect_facebook_url => $self->derive_url( task => 'disconnect_facebook', additional => [ $uid, $uid_hash ] ),
        };
    }

    $self->tool->add_js_variables( $globals );

    $self->tool->Container->box_at( 1, 0 )->name( $self->_msg( 'Login settings' ) );
    $self->tool->Container->box_at( 1, 0 )->class( 'settings_login_settings' );
    $self->tool->Container->box_at( 1, 0 )->add_content(
        [ Dicole::Widget::Raw->new(
            raw => $self->generate_content( $params, { name => 'dicole_settings::login_settings' } )
        ) ]
    );

    return $self->generate_tool_content;
}

sub connect_facebook { return _connect_facebook( shift, 1 ); }
sub disconnect_facebook { return _connect_facebook( shift, 0 ); }

sub _connect_facebook {
    my ( $self, $connect ) = @_;

    my $user = CTX->request->auth_user;
    die "security error" unless $user;

    my $uid_hash = Digest::MD5::md5_hex( Dicole::Utils::User->authorization_key_invalidation_secret( $user ) . 'fb' );
    if ( $uid_hash eq $self->param('uid_hash') ) {
        if ( $connect ) {
            $user->facebook_user_id( CTX->request->param('facebook_user_id') );
            $user->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg("Facebook account connected.") );
        }
        else {
            $user->facebook_user_id( '' );
            $user->save;
            Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg("Facebook account disconnected.") );
        }
        return $self->redirect( $self->derive_url( task => 'change', additional => [ $user->id ] ) );
    }

    die "security error";
}

sub look {
    my ( $self ) = @_;
    
    my $tool_string = 'navigation';
    eval {
        my $d = CTX->lookup_action('dicole_domains')->
            execute('get_current_domain');
        $tool_string .= '_' . $d->{domain_id};
    };
    
    my $task = OpenInteract2::Action::DicoleSettings::Look->new( $self, {
        tool => $tool_string,
        user => 1,
        group => 0,
        global => 0,
        view => 'look',
        box_title => 'Look settings',
        box_x => 1,
    } );
    
    $task->_tool_config( cols => 2 );
    $task->_tool_config( tool_args => { no_tool_tabs => 1 } );
    
    return $task->execute;
}

1;

package OpenInteract2::Action::DicoleSettings::Look;
use base qw( Dicole::Task::GTSettings );

sub _post_init {
    my $self = shift @_;
    $self->SUPER::_post_init( @_ );
    
    my $navi = $self->action->tool->get_tablink_box( $self->action->_msg('Navigation') );
    $self->action->tool->Container->box_at( 0, 0 )->name( $navi->{name} );
    $self->action->tool->Container->box_at( 0, 0 )->content( $navi->{content} );
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Handler::DicoleSettings - Handler for changing the password

=head1 DESCRIPTION

A page handler that allows a user to change her password.

=head1 METHODS

=head2 _form_data()

S<my ( $list, $buttons ) = $self-E<gt>_form_data;>

=over 4

=item B<Return value>

Returns Dicole::Content::List and Dicole::Content::Controlbuttons objects
which basically include the form for changing the password.

=back

=head2 change( $self, \%params )

Changes the password if all tests are completed without errors.

=over 4

=item B<Test 1>

Checks if the user user has logged in and has requested for changing the password.

=item B<Test 2>

Checks if all the form elements are filled.

=item B<Test 3>

Checks if the new password matches with the verify password.

=item B<Test 4>

Checks if the password should be crypted in the database or not according to server configuration.

=item B<All tests passed>

If all tests are passed, the password will be changed and stored in the user object.

=item B<Result>

A page will be generated to display the form with return messages or not.

=back

=head1 BUGS

None known.

=head1 TO DO

Testing against minimum password length.

=head1 COPYRIGHT

 Copyright (c) 2003 Ionstream Oy / Dicole
 www.dicole.fi

=head1 AUTHORS

 Hannes Muurinen <hannes@ionstream.fi>
 Teemu Arina <teemu@ionstream.fi>

=cut
