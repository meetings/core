package OpenInteract2::Action::DicoleRegisterJSON;

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


sub register {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $valid_event_invite = CTX->request->param('event_invite_code') ?
        eval { CTX->lookup_action('events_api')->e( validate_invite => {
            invite_code => CTX->request->param('event_invite_code'),
            target_group_id => $gid,
        } ) } || 0 : 0;

    my $valid_invite = CTX->request->param('invite_code') ?
        eval { CTX->lookup_action('invite_api')->e( validate_invite => {
            invite_code => CTX->request->param('invite_code'),
            target_group_id => $gid,
            domain_id => $domain_id,
        } ) } || 0 : 0;

    unless ( $valid_event_invite || $valid_invite ) {
        my $register_target = CTX->lookup_action( 'user_manager_api' )->e( allowed_domain_registration_target => {
            group_id => $gid, group_object => $self->param('target_group')
        } );

        die 'security error' unless $register_target;
        die 'security error' unless $register_target < 0 || $self->param('target_group')->joinable == 1;
    }

    my $user_manager_tool = Dicole::Utils::Domain->guess_current_settings_tool( $domain_id );

    my $tos_required = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'tos_link'
    );

    if ( $tos_required && ! CTX->request->param( 'tos_checked' ) && ! CTX->request->param( 'accept_eula' ) ) {
        return { error => { message => $self->_msg('You need to accept the terms of service.') } };
    }

    my $location_required = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'location_required_to_register'
    );
   
    if (  $location_required && ! CTX->request->param('user_location') ) {
        return { error => { message => $self->_msg( "Location is required to register" ) } };
    }

    my $answer_required = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'registration_required_question'
    );

    if ( $answer_required ) {
        my $expected_answer = Dicole::Settings->fetch_single_setting(
            tool => $user_manager_tool,
            attribute => 'registration_required_question_answer'
        );
        chomp $expected_answer;

        my $provided_answer = CTX->request->param('register_question');
        chomp $provided_answer;

        return {  error => { message => $self->_msg( "Unfortunately your answer to the required question was not correct. Please try again!" ) } } unless lc( $expected_answer ) eq lc( $provided_answer );
    }   

    my $user = eval { CTX->lookup_action('user_manager_api')->e( create_user => {
        first_name => CTX->request->param('user_first_name'),
        last_name => CTX->request->param('user_last_name'),
        email => CTX->request->param('user_email'),
        facebook_user_id => CTX->request->param('facebook_user_id'),
        send_user_email => 1,
        user_email_group_id => $gid,
        send_admin_email => 1,
        domain_id => $domain_id,
    } ) };

    if ( $@ ) {
        return { error => ref( $@ ) ? $@ : { message => 'unknown error occured' } };
    }

    my $tags = eval {
        CTX->lookup_action('tags_api')->execute( merge_input_to_json_tags => {
            input => CTX->request->param('tags_add_tags_input_field'),
            json => CTX->request->param('tags'),
        } );
    };

    CTX->lookup_action('networking_api')->e( update_tags_for_user_profile_from_json => {
        domain_id => $domain_id,
        user_id => $user->id,
        json => $tags,
        json_old => '[]',
    } );

    CTX->lookup_action('networking_api')->e( update_image_for_user_profile_from_draft => {
        draft_id => CTX->request->param('user_photo_draft_id') || '0',
        user_id => $user->id,
        domain_id => $domain_id,
    } );

    CTX->lookup_action('networking_api')->e( user_profile_attributes => {
        domain_id => $domain_id,
        user_id => $user->id,
        attributes => {
            contact_organization => CTX->request->param('user_organization'),
            contact_title => CTX->request->param('user_role'),
            contact_address_1 => CTX->request->param('user_location'),

            contact_skype => CTX->request->param('user_skype'),
            contact_phone => CTX->request->param('user_phone'),
            personal_twitter => CTX->request->param('user_twitter'),
            personal_facebook => CTX->request->param('user_facebook'),
            personal_blog => CTX->request->param('user_website'),
            about_me => CTX->request->param('user_about_me'),
        },
    } );

    Dicole::Settings->store_single_setting(
        tool => $user_manager_tool,
        user_id => $user->id,
        attribute => 'tos_accepted',
        value => 1,
    ) if $tos_required;

    if ( $gid ) {
        CTX->lookup_action('add_user_to_group')->execute( {
            user_id => $user->id,
            group_id => $gid,
        } );
    }

    my $redirect_url = CTX->request->param('url_after_register') || '';

    if ( $gid && ! $redirect_url ) {
        $redirect_url = Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'groups',
            task => 'starting_page',
            target => $gid
        );
    }

    my $autologin_after_registering = Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'autologin_after_registering'
    );

    if ( $autologin_after_registering ) {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( "Registration done. We have emailed you your account information." )
        );

        $redirect_url = Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'login',
            task => 'login',
            target => 0,
            params => {
                url_after_login => $redirect_url,
                dic => Dicole::Utils::User->authorization_key(
                    user => $user,
                    create_session => 1,
                    valid_minutes => 1,
                ),
            }
        );
    }
    else {
        Dicole::MessageHandler->add_message( MESSAGE_SUCCESS,
            $self->_msg( "Registration done. We have sent you an email containing your login information." )
        );

        $redirect_url ||= Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'login',
            task => 'login',
            target => 0,
        );
    }

    return { success => 1, url => $redirect_url };
}

1;
