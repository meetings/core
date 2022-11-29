package OpenInteract2::Action::DicoleRandom;
use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );


sub _tuuma_custom_navigation {
    my ( $self ) = @_;

    my $ia = CTX->controller->initial_action;

    unless ( $ia && $ia->param('target_group_id') && $ia->param('target_group_id') == 2357 ) {
        my $navi_action = CTX->lookup_action('simple_navigation');
        my $navi = $navi_action->execute;
        for my $param ( qw/additional_css additional_js head_widgets footer_widgets end_widgets  / ) {
            $self->param( $param, scalar( $navi_action->param( $param ) ) );
        }
        return $navi;
    }
    
    my $p = {};

    my $tgid = $ia->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $domain_id = Dicole::Utils::Domain->guess_current_id( undef, $ia );

    my $url_after_login = CTX->request->param('url_after_login') || $ia->derive_full_url;

    if ( $ia && $ia->task =~ /upcoming/ ) {
        $p->{show_description} = 1;
    }

    if ( $uid ) {
        $p->{user} = Dicole::Utils::User->icon_hash( CTX->request->auth_user_id, 36, $tgid, $domain_id );
        if ( $tgid ) {
            $p->{user}->{profile_url} = $p->{user}->{url};
            $p->{user}->{settings_url} = $ia->derive_url( action => 'global_settings', task => 'detect', additional => [] );
        }
    }
    else {
        $p->{url_after_login} = $url_after_login;
    }

    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $tool_string = 'navigation';
    $tool_string .= '_' . $current_domain->{domain_id} if $current_domain;

    my $settings = Dicole::Settings->new_fetched_from_params(
        tool => $tool_string,
    );

    my ( @head_widgets, @footer_widgets, @end_widgets );

    my @custom_css = ();

    if ( $tgid ) {
        my $local_settings = Dicole::Settings->new_fetched_from_params(
            tool => $tool_string,
            user_id => 0,
            group_id => $tgid,
        );
        push @custom_css, $local_settings->setting('custom_css');
    }

    for my $css ( @custom_css ) {
        push @head_widgets, Dicole::Widget::Raw->new(
            raw => '<style type="text/css" media="all">'.$css.'</style>'
        ) if $css;
    }

    $self->param( 'head_widgets', \@head_widgets );
    $self->param( 'footer_widgets', \@footer_widgets );
    $self->param( 'end_widgets', \@end_widgets );

    return $self->generate_content( $p, { name => 'dicole_random::tuuma_navigation'} )
}

sub _deski_custom_navigation {
    my ( $self ) = @_;

    return $self->_common_deski_custom_navigation('deski');
}

sub _kvdeski_custom_navigation {
    my ( $self ) = @_;

    return $self->_common_deski_custom_navigation('kvdeski');
}

sub _common_deski_custom_navigation {
    my ( $self, $template ) = @_;

    my $p = {};

    my $ia = CTX->controller->initial_action;
    my $tgid = $ia->param('target_group_id');
    my $uid = CTX->request->auth_user_id;
    my $domain_id = Dicole::Utils::Domain->guess_current_id( undef, $ia );

    my $url_after_login = CTX->request->param('url_after_login') || $ia->derive_full_url;

    if ( $ia && $ia->task =~ /upcoming/ ) {
        $p->{main_link_selected} = 1;
    }

    if ( $uid ) {
        $p->{user} = Dicole::Utils::User->icon_hash( CTX->request->auth_user_id, 36, $tgid, $domain_id );
        if ( $tgid ) {
            $p->{user}->{profile_url} = $p->{user}->{url};
            $p->{user}->{settings_url} = $ia->derive_url( action => 'global_settings', task => 'detect', additional => [] );
        }
    }
    else {
        $p->{url_after_login} = $url_after_login;
    }

    my $current_domain = eval {
        CTX->lookup_action('dicole_domains')->execute('get_current_domain');
    };

    my $tool_string = 'navigation';
    $tool_string .= '_' . $current_domain->{domain_id} if $current_domain;

    my $settings = Dicole::Settings->new_fetched_from_params(
        tool => $tool_string,
    );

    my ( @head_widgets, @footer_widgets, @end_widgets );

    my @custom_css = ( $settings->setting('custom_css') );

    if ( $tgid ) {
        my $local_settings = Dicole::Settings->new_fetched_from_params(
            tool => $tool_string,
            user_id => 0,
            group_id => $tgid,
        );
        push @custom_css, $local_settings->setting('custom_css');
    }

    for my $css ( @custom_css ) {
        push @head_widgets, Dicole::Widget::Raw->new(
            raw => '<style type="text/css" media="all">'.$css.'</style>'
        ) if $css;
    }

    $self->param( 'head_widgets', \@head_widgets );
    $self->param( 'footer_widgets', \@footer_widgets );
    $self->param( 'end_widgets', \@end_widgets );





    return $self->generate_content( $p, { name => 'dicole_random::' . $template } )
}

1;

