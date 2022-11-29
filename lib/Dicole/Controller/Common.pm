package Dicole::Controller::Common;

use 5.010;
use warnings;
use strict;
use base qw( Class::Accessor );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Constants qw( :log );
use Dicole::MessageHandler   qw( :message );

use Dicole::URL;
use Dicole::Summary;
use CGI::Cookie;
use CGI ();
use OpenInteract2::Cookie;
use Dicole::Utils::Session;

my $log;

Dicole::Controller::Common->mk_accessors( qw(
    used_htmltrees
) );

sub add_used_htmltree {
    my ( $self, $tree ) = @_;

    $self->used_htmltrees( [] ) unless ref( $self->used_htmltrees ) eq 'ARRAY';
    push @{ $self->used_htmltrees }, $tree;
}

sub clean_used_htmltrees {
    my ( $self ) = @_;

    if( ref( $self->used_htmltrees ) eq 'ARRAY' ) {
        while ( my $tree = pop @{ $self->used_htmltrees } ) {
            $tree->delete;
        }
    }
}

sub common_url_version_redirect {
    my ($self) = @_;

    return 0 unless eval { CTX->request->apache->method eq 'GET' };

    if ( $self->initial_action->param('url_version') == 1 ) {
        my $new_url = eval { Dicole::URL->create_full_from_current( force_version => 2 ) };
        return 0 if $@;

        CTX->response->redirect( $new_url );
        return 1;
    }
    return 0;
}

sub init_common_variables {
    my ( $self, %params ) = @_;

    return unless $self->can( 'add_content_param' );

    my @head_widgets = @{ $params{head_widgets} || [] };
    my @footer_widgets = @{ $params{footer_widgets} || [] };
    my @end_widgets = @{ $params{end_widgets} || [] };

    $self->add_content_param( 'lang', {
        code => CTX->request->session->{lang}{code},
        charset => CTX->request->session->{lang}{charset}
    } );

    unless ( $params{disable_theme} ) {
        my ( $theme_css, $theme_images ) = $self->_get_theme_css_params();

        # Set theme stuff in controller params
        $self->add_content_param( 'theme_css', $theme_css );
        $self->add_content_param( 'theme_images', $theme_images );
    }

    unless ( $params{disable_navigation} || ( $self->no_template && $self->no_template eq 'yes' ) ) {
        my $navi_action = eval {
            CTX->lookup_action('dicole_domains')->execute( domain_custom_navigation => {} )
        };

        if ( $@ || ! $navi_action ) {
            $navi_action = CTX->lookup_action('simple_navigation');
        }

        if ( my $nav = $params{alternative_navigation} ) {
            $navi_action = CTX->lookup_action( $nav );
        }

        $self->add_content_param( 'navigation', $navi_action->execute );

        if ( my $css = $navi_action->param('additional_css') ) {
            push @head_widgets, Dicole::Widget::CSSLink->new( href => $css );
        }
        if ( my $js = $navi_action->param('additional_js') ) {
            push @head_widgets, Dicole::Widget::Javascript->new( src => $js );
        }
        if ( CTX->request->user_agent && CTX->request->user_agent =~ /tablet/i ) {
            push @head_widgets, Dicole::Widget::CSSLink->new( href => '/css/style_tablet.css' );
        }

        push @head_widgets, @{ $navi_action->param('head_widgets') || [] };
        push @footer_widgets, @{ $navi_action->param('footer_widgets') || [] };
        push @end_widgets, @{ $navi_action->param('end_widgets') || [] };

        # Legacy for backwards compatibility..
        if ( my $tool = $params{tool} ) {
            if ( $navi_action->param('disable_tool_name') ) {
                $tool->tool_name('');
                $tool->tool_icon('');
            }

            if ( $navi_action->name eq 'nice_navigation' || $navi_action->name eq 'simple_navigation' ) {
                $tool->nice_tabs(1);
            }
        }
    }

    my $did = eval { CTX->lookup_action('dicole_domains')->execute('get_current_domain')->id } || 0;

    $self->add_content_param( 'qbaka_key', 0 );

    my $settings_tool_name = $did ? 'domain_user_manager_' . $did : 'user_manager';

    my $settings = Dicole::Settings->new_fetched_from_params( tool => $settings_tool_name );

    my $custom_favicon = $settings->setting('custom_favicon');

    if ( $custom_favicon ) {
        if ( $custom_favicon =~ /png$/ ) {
            $self->add_content_param( 'custom_png_favicon', $custom_favicon );
        }
        else {
            $self->add_content_param( 'custom_ico_favicon', $custom_favicon );
        }
    }

    unless ( $params{disable_footer} ) {
        my $html = $settings->setting( 'custom_footer_html' );
        if ( $html ) {
            push @footer_widgets, Dicole::Widget::Container->new(
                class => 'domain_custom_footer_html',
                contents => [ Dicole::Widget::Raw->new( raw => $html ) ],
            );
        }
    }

    if ( my $custom_head = $settings->setting( 'custom_head_html' ) ) {
        $self->add_content_param( custom_head_html => $custom_head );
    }

    if ( my $custom_body_start = $settings->setting( 'custom_body_start_html' ) ) {
        $self->add_content_param( custom_body_start_html => $custom_body_start );
    }

    $self->add_content_param( page_title => $params{title} );
    $self->add_content_param( feed => $params{feed} );

    my ( $fb_id, $fb_secret, $fb_disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

    $self->add_content_param( facebook_connect_app_id => $fb_id ) unless $fb_disabled;

    unless ( $params{disable_dojo} ) {
        # inject dojo just after last tinymce include or else as first head widget
        my @stash = ();
        my $injected = 0;

        my $gmaps_api_key = $settings->setting( 'gmaps_api_key' ) || CTX->server_config->{dicole}{gmaps_api_key};

        my @anonymous_variables = (
            url_after_action => $self->initial_action->derive_full_url,
        );

        push @anonymous_variables, ( facebook_connect_app_id => $fb_id ) unless $fb_disabled;

        if ( ! CTX->request->auth_user_id ) {
            push @anonymous_variables, (
                url_after_login => CTX->request->param('url_after_login') || $self->initial_action->derive_full_url,
                retrieve_password_url => $self->initial_action->derive_url( action => 'lostaccount', task => '', target => 0, additional => [] ),
            );

            my $register_target = CTX->lookup_action( 'user_manager_api' )->e( allowed_domain_registration_target => {
                group_id => $self->initial_action->param('target_group_id'),
                group_object => $self->initial_action->param('target_group')
            } );

            my $ic = CTX->request->param('k');
            if ( $ic ) {
                my $valid_invite = eval { CTX->lookup_action('invite_api')->e( validate_invite => {
                    invite_code => $ic,
                    target_group_id => $self->initial_action->param('target_group_id'),
                    domain_id => $did,
                } ) } || 0;

                if ( $valid_invite ) {
                    $register_target = $self->initial_action->param('target_group_id');
                    push @anonymous_variables, ( open_invite_accept_dialog => 1 );
                }
            }

            my $eic = CTX->request->param('invite_code');
            if ( $eic ) {
                my $valid_event_invite = eval { CTX->lookup_action('events_api')->e( validate_invite => {
                    invite_code => $eic,
                    target_group_id => $self->initial_action->param('target_group_id'),
                } ) } || 0;

                if ( $valid_event_invite ) {
                    $register_target = $self->initial_action->param('target_group_id');
                }
            }

            if ( $register_target ) {
                push @anonymous_variables, ( auto_open_register => 1 ) if CTX->request->param('auto_open_register');
                push @anonymous_variables, ( register_url => $self->initial_action->derive_url(
                    action => 'register_json',
                    task => 'register',
                    target => $register_target > 0 ? $register_target : 0,
                    additional => [],
                    params => {
                        $eic ? ( event_invite_code => $eic ) : (),
                        $ic ? ( invite_code => $ic ) : (),
                    },
                ) );
                push @anonymous_variables, ( tos_url => $settings->setting('tos_link') || '' );
                push @anonymous_variables, ( registration_question => $settings->setting('registration_required_question') || '' );
                push @anonymous_variables, ( require_location => $settings->setting('location_required_to_register') || '' );
                push @anonymous_variables, ( privacy_info_url => $settings->setting('privacy_info_link') || '' );
                push @anonymous_variables, ( service_info_url => $settings->setting('service_info_link') || '' );
                my $domain = $self->initial_action->param('domain');
                push @anonymous_variables, ( banner_url => ( $domain && $domain->logo_image ) ? $domain->logo_image : '' );
            }
        }

        my $g = $self->initial_action->param('target_group');

        my $port = Dicole::URL->get_server_port;
        my $proto = (($port && $port == 443) ? 'https' : 'http');

        my $variables = {
            CTX->request->auth_user_id ? ( auth_user_email => CTX->request->auth_user->email ) : (),
            group_name => $g ? $g->name : '',
            auto_open_login => ( CTX->request->param('url_after_login') && $self->initial_action->name ne 'login' && $self->initial_action->task ne 'login' && ! CTX->request->auth_user_id ) ? 1 : 0,
            event_server_url => "$proto://event-server-1" . ( ( CTX->server_config->{dicole}{development_event_server} ) ?
                '-dev.dicole.net/' : '.dicole.net/' ),
            domain_host => Dicole::Utils::Domain->guess_current( undef, $self->initial_action )->domain_name,
            static_file_version => CTX->server_config->{dicole}{static_file_version},
            localization_api_url => $self->initial_action->derive_url(
                action => 'localization_json', task => 'lexicon', additional => [ $self->initial_action->language ]
            ),
            instant_authorization_key_url => $self->initial_action->derive_url(
                action => 'login_json', task => 'instant_authorization_key', target => 0, additional => []
            ),
            who_am_i_url => $self->initial_action->derive_url(
                action => 'login_json', task => 'who_am_i', target => 0, additional => []
            ),
            auth_user_id => CTX->request->auth_user_id,
            draft_attachment_store_url => $self->initial_action->derive_url(
                action => 'draft_attachment_json', task => 'store', target => 0, additional => []
            ),
            draft_attachment_url_store_url => $self->initial_action->derive_url(
                action => 'draft_attachment_json', task => 'url_store', target => 0, additional => []
            ),
            draft_attachment_fileapi_url => $self->initial_action->derive_url(
                action => 'draft_attachment_json', task => 'fileapi', target => 0, additional => []
            ),
            gmaps_api_key => $gmaps_api_key,
            @anonymous_variables,
        };

        my @inject_widgets = (
            Dicole::Widget::Raw->new( raw =>
                '<!--[if IE]>'."\n".'<script type="text/javascript" src="/js/ierange.js"></script>'."\n".'<![endif]-->' . "\n"
            ),
            ( CTX->server_config->{dicole}{development_mode} && ! CTX->server_config->{dicole}{disable_dojo_debug} ) ?
                Dicole::Widget::Javascript->new(
                    code => 'var djConfig = { isDebug : true }',
                ) : (),
            Dicole::Widget::Javascript->new(
                src => ( CTX->server_config->{dicole}{development_mode} || CTX->server_config->{dicole}{uncompressed_dojo} )?
                    '/js/dojo/dojo.js.uncompressed.js' : '/js/dojo/dojo.js',
            ),
            ( CTX->server_config->{dicole}{development_mode} && ! CTX->server_config->{dicole}{disable_script_bundle} ) ?
                Dicole::Widget::Javascript->new(
                    src => '/development_raw/bundled_javascripts/all.js',
                ) : (),
            ( $params{disable_swfupload} ) ? () : (
                Dicole::Widget::Javascript->new(
                    src => '/js/swfupload.js',
                ),
            ),
            Dicole::Widget::Javascript->new(
                src => '/js/swfobject.js',
            ),
            ( CTX->server_config->{dicole}{development_mode} ) ? () : (
                Dicole::Widget::Javascript->new(
                    src => $params{replace_dicole_bundle} || ( CTX->server_config->{dicole}{uncompressed_dojo} ? '/js/dojo/dicole.js.uncompressed.js' : '/js/dojo/dicole.js' ),
                ),
            ),
            ( $params{disable_default_requires} ) ? (
                Dicole::Widget::Javascript->new(
                    code => 'dojo.require("dicole.base");',
                ),
            ) : (
                Dicole::Widget::Javascript->new(
                    code => 'dojo.require("dicole.navigation");',
                ),
                Dicole::Widget::Javascript->new(
                    code => 'dojo.require("dicole.groups");',
                ),
                scalar( @anonymous_variables ) ? ( Dicole::Widget::Javascript->new(
                    code => 'dojo.require("dicole.user_manager");',
                ) ) : (),
            ),
            Dicole::Widget::Javascript->new(
                code => 'dicole.set_global_variables( ' . Dicole::Utils::JSON->uri_encode( $variables ) . ' );',
            ),
        );

        while ( my $widget = shift @head_widgets ) {
            if ( ! $injected && $widget && ref( $widget ) eq 'Dicole::Widget::Javascript' && ( ( $widget->src && $widget->src =~ /tiny_mce(_\w*)?\.js$/ ) || ( $widget->code && $widget->code =~ /tinymce3\.shortcut/ ) ) ) {
                push @stash, @inject_widgets;
                $injected = 1;
            }
            push @stash, $widget;
        }

        unless ( $injected ) {
            @stash = ( @inject_widgets, @stash );
        }

        while ( my $widget = shift @stash ) {
            push @head_widgets, $widget;
        }
    }

    # Add belated hack:
    unshift @head_widgets, Dicole::Widget::Raw->new( raw =>
        '<!--[if lt IE 8]>' . "\n" .
        '<link rel="stylesheet" href="/css/dicole_simple/style_ie6.css" media="all" type="text/css" />' . "\n" .
    	'<script src="/js/DD_belatedPNG.js"></script>' . "\n" .
        "<script>DD_belatedPNG.fix('#navi_tools a, #navi_logo_link, #navi_actions, body .defaultSkin span.mceIcon, .generic_attachment_png, .alpha_png');</script>" . "\n" .
        '<![endif]-->'
    );

    # Add legacy variables:
    my $action_id = ( CTX->request->action_name || '' ) . '_' . ( CTX->request->task_name || '' ) . '_' . ( CTX->request->target_id || '' );
    my $deployment = CTX->server_config->{context_info}{deployed_under};

    unshift @head_widgets, Dicole::Widget::Javascript->new( code =>
        "DicoleTargetId = '" . CTX->request->target_id . "'; " .
        "OIPath_dep = '" . ( $deployment || '/' ) . "'; " .
        "OIPath_action_id = '" . $action_id . "';"
    );

    # Move CSS widgets at the top to speed loading
    my @head_css = ();
    my @head_other = ();
    for my $widget ( @head_widgets ) {
        if ( $widget && ref( $widget ) eq 'Dicole::Widget::CSSLink' ) {
            push @head_css, $widget;
        }
        else {
            push @head_other, $widget;
        }
    }
    @head_widgets = ( @head_css, @head_other );

    my $head_widgets = [ map { Dicole::Widget->content_params( $_ ) } @head_widgets ];
    $self->add_content_param( head_widgets => $head_widgets );

    unless ( $params{disable_footer} ) {
        my $footer_widgets = [ map { Dicole::Widget->content_params( $_ ) } @footer_widgets ];
        $self->add_content_param( footer_widgets => $footer_widgets );
    }

    my $end_widgets = [ map { Dicole::Widget->content_params( $_ ) } @end_widgets ];
    $self->add_content_param( end_widgets => $end_widgets );

    my $body_classes = $params{body_classes} || '';
    $body_classes .= ' ' if $body_classes;
    $body_classes .= 'action_' . CTX->request->action_name . ' ' .
        'action_' . CTX->request->action_name . '_task_' . CTX->request->task_name;

    if ( CTX->request && CTX->request->auth_user_id ) {
        $body_classes .= ' logged_in_extras';
    }
    else {
        $body_classes .= ' logged_out_extras';
    }

    if ( my $ia = $self->initial_action ) {
        if ( $ia->mchk_y( 'OpenInteract2::Action::Groups', 'admin_extras') ) {
            $body_classes .= ' group_admin_extras';
        }
        else {
            $body_classes .= ' no_group_admin_extras';
        }

        if ( my $g = $ia->param('target_group') ) {
            if ( ! CTX->lookup_action('groups_api')->e( is_group_visible => { group => $g } ) ) {
                $body_classes .= ' hidden_group';
            }
        }
    }

    $self->add_content_param( body_action_task_classes => $body_classes );
}

sub _get_theme_css_params {
    my ( $self ) = @_;

    my $theme_css = [];

    # Theme_images is the last theme object that includes a value for theme_images
    my $theme_images = undef;

    # Retrieve theme from session
    my $theme_objects = CTX->request->session->{_dicole_cache}{theme};
    foreach my $parent_theme ( @{ $theme_objects->{parents} } ) {
        $theme_images = $parent_theme->{theme_images} if $parent_theme->{theme_images};
        push @{ $theme_css }, $self->_discover_theme_css_files( $parent_theme );
    }
    push @{ $theme_css },  $self->_discover_theme_css_files( $theme_objects->{root} );
    $theme_images = $theme_objects->{root}{theme_images} if $theme_objects->{root}{theme_images};
    $theme_images ||= '';

    my $deployment = CTX->server_config->{context_info}{deployed_under};

    return ( $theme_css, $deployment . $theme_images );
}

sub _discover_theme_css_files {
    my ( $self, $theme_object ) = @_;
    my @csses;
    my $deployment = CTX->server_config->{context_info}{deployed_under};
    foreach my $media ( qw( all aural braille embossed handheld print projection screen tty tv ) ) {
        $theme_object->{"css_" . $media} ||= '';
        foreach my $css_file ( split /\s+/, $theme_object->{"css_" . $media} ) {
            next unless $css_file;
            my $props = {};
            $props->{media} = $media;

            my $file_version = CTX->server_config->{dicole}{static_file_version};
            if ( $file_version && ! ( $css_file =~ /\&v\=|\?v\=/ ) ) {
                $css_file = $css_file . ( ( $css_file =~ /\?/ ) ? '&' : '?' ) . 'v=' . $file_version;
            }

            $props->{path} = $deployment . $css_file;
            push @csses, $props;
        }
    }
    return \@csses;
}

sub common_forced_actions_redirect {
    my ($self) = @_;

    return 0 unless CTX->request->auth_user_id;
    return 0 if lc( CTX->request->action_name ) eq 'networking_guide';

    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };
    my $user_manager_tool = $current_domain ?
        'domain_user_manager_' . $current_domain->domain_id : 'user_manager';

    return 0 unless Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        attribute => 'force_networking_guide',
    );

    return 0 if Dicole::Settings->fetch_single_setting(
        tool => $user_manager_tool,
        user_id => CTX->request->auth_user_id,
        attribute => 'profile_guide_passed',
    );

    CTX->response->redirect(
        Dicole::URL->from_parts(
            action => 'networking_guide',
            task => 'detect',
        )
    );

    return 1;
}

sub common_check_firewall {
    my ( $self ) = @_;
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ( $@ ) {
        $dicole_domains->task( 'check_if_domain_invalid' );
        if ( my $return_content = $dicole_domains->execute ) {
            # Send an expiration cookie, clear authentication
            # and save new anonymous session
            Dicole::Utils::Session->expire_session;
            CTX->request->auth_clear;
            CTX->response->save_session;
            CTX->response->content( \$return_content );
            return 0;
        }
        $dicole_domains->task( 'check_ip_address_restriction' );
        if ( my $return_content = $dicole_domains->execute ) {
            # Send an expiration cookie, clear authentication
            # and save new anonymous session
            Dicole::Utils::Session->expire_session;
            CTX->request->auth_clear;
            CTX->response->save_session;
            CTX->response->content( \$return_content );
            return 0;
        }
    }
    return 1;
}

sub common_update_desktop_positions {
    my ( $self ) = @_;

    my @names = CTX->request->cookie;

    my $cookies = {};

    foreach my $name ( @names ) {
        next if $name !~ /^summary_/;

        my $layout = Dicole::Summary->parse_cookie(
            $name, CTX->request->cookie( $name )
        );

        Dicole::Summary->store_summary_layout( $layout ) if $layout;

        # expire the cookie so we don't have to update this on every request

        my $deployment = CTX->server_config->{context_info}{deployed_under};
        $deployment .= '/' unless $deployment =~ /\/$/;

        my $cookie = CGI::Cookie->new(
            -name => $name,
            -path => $deployment,
            -expires => 0,
            -value => "",
        );

        CTX->response->cookie( $cookie );
    }
}

sub common_set_language {
    my ($self) = @_;

    # HACK(ish): Force group language if set. This can't be done before group has
    # been determined and thus can't be added to Request's own assign_languages

    CTX->request->assign_current_group_language( $self );

    # Ensure language in the session and in the headers. This is used to
    # set the response content type charset, accepted
    # charset in the request (forms, see Dicole::Tool) and
    # as a target charset for converting the output from utf8 in
    # response (See Dicole::Response::Apache)

    my $lang = ref CTX->request->language_handle;
    $lang =~ s/^.*::(.*)$/$1/;

    unless ( CTX->request->session->{lang}{code} && CTX->request->session->{lang}{charset} ) {
        CTX->request->session->{lang}{code} = $lang;
        CTX->request->session->{lang}{charset} = $self->_fetch_charset( $lang );
    }

    my $charset = CTX->request->session->{lang}{charset};

    unless ( CTX->request->session->{lang}{code} eq $lang ) {
        $charset = $self->_fetch_charset( $lang );
    }

    CTX->response->content_type( 'text/html; charset=' . $charset );
}

sub _fetch_charset {
    my ( $self, $lang ) = @_;

    my $lang_user = undef;

    $lang_user = eval { CTX->lookup_object( 'lang' )->fetch_group( {
        where => "lang_code = ?",
        value => [ $lang ]
    } ) };

    if ( $@ ) {
        $lang_user = CTX->lookup_object( 'lang' )->fetch( 1 );
    }
    else {
        $lang_user = $lang_user->[0];
    }

    return $lang_user->{charset};
}

sub common_default_task_redirect {
    my ($self) = @_;

    if ( ! $self->initial_action->method &&
         ! $self->initial_action->task &&
         $self->initial_action->task_default ) {

        my @params = CTX->request->param;
        my %query_params = map { $_ => CTX->request->param( $_ ) } @params;

        CTX->response->redirect(
            Dicole::URL->create_from_current(
                task => $self->initial_action->task_default,
                params => \%query_params,
            )
        );

        return 1;
    }

    return 0;
}

sub common_set_last_active_group {
    my ($self) = @_;

    if ( $self->initial_action->name eq 'groupsummary' &&
         CTX->request->target_id ) {

        CTX->request->sessionstore->set_value(
            'group', 'last_active', CTX->request->target_id
        );
    }
}

sub common_register_group_visit {
    my ( $self ) = @_;

    return unless CTX->request->target_group_id;

    my $action = eval { CTX->lookup_action( 'register_group_visit' ) };
    return unless $action;

    $action->execute( {
        user_id => CTX->request->auth_user_id,
        group_id => CTX->request->target_group_id,
    } );

    if ( $self->initial_action ) {
        eval { CTX->lookup_action( 'register_area_visit' )->e( { action => $self->initial_action  } ) };
    }
}

sub common_register_activity {
    my ( $self ) = @_;

# Commented out because this was not necessary and it caused sessions to be updated too often
#     if ( CTX->request->auth_user_id ) {
#         # Using CTX->request->auth_user uses old object which might contain stale data
#         my $user = CTX->lookup_object('user')->fetch( CTX->request->auth_user_id );
#         $user->latest_activity( time );
#         $user->save;
#     }

    my $action = eval { CTX->lookup_action( 'register_activity' ) };
    return if !$action;

    $action->execute;
}

sub common_check_action_error_redirect {
    my ($self, $error) = @_;
    $log ||= get_logger( LOG_ACTION );

    if ($error =~ /^redirect/ ) {
        $log->is_info && $log->info( "Initial action died to cause a redirect." );
        return 1;
    }
    if ($error =~ /^security error/ && ! CTX->request->auth_is_logged_in ) {
        $log->is_info && $log->info( "Security error while user not logged in. Redirecting to login page." );
        $self->common_login_redirect();
        return 1;
    }

    return 0;
}

sub common_action_error_logstring {
    my ($self, $error) = @_;

    my $info = 'url_absolute was: [' . CTX->request->url_absolute . ']. ';

    if ( my $user = CTX->request->auth_user ) {
        $info .= 'Requesting user was: ';
        $info .= $user->first_name . ' ' . $user->last_name;
        $info .= '(' . $user->id . ')';
    }
    else {
        $info .= 'User was not logged in.';
    }

    return $info;
}

# Decide an action based on returned error string - for now.
# In the future there should be real exception classes

sub common_action_error_content {
    my ($self, $error) = @_;
    $log ||= get_logger( LOG_ACTION );

    return if $self->common_check_action_error_redirect( $error );
    my $info = $self->common_action_error_logstring( $error );

    if ($error =~ /^security error/ ) {
        CTX->response->redirect(
            $self->initial_action->derive_url(
                action => 'login', task => 'login', target => 0, additional => []
            )
        );

        Dicole::MessageHandler->add_message( MESSAGE_ERROR, $self->initial_action->_msg(
            'You do not have the rights to access the page you tried to open. Contact your administrator for more information.'
        ) );

        return;
    }
    elsif ($error =~ /Cannot find valid method/) {
        return CTX->lookup_action_not_found->execute;
    }
    else {
        $self->no_template( 'yes' );

        $log->error("Unhandled error: $error . -- $info");
        return CGI::escapeHTML("ERROR: $error . -- $info");
    }
}

=pod

=head2 common_login_redirect()

Forwards the request to a login page while trying to preserve the call as it was after login. file upload doesn't work afaik.

=cut

sub common_login_redirect {
    my ( $self ) = @_;

    my $params = CTX->request->param;

    CTX->response->redirect(
        Dicole::URL->create(
            [
                'login',
                'login',
            ],
            {
                url_after_login => CTX->controller->initial_action->derive_url(
                    params => $params,
                ),
                logout => 2
            },
        )
    );
}

1;
