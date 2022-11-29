package Dicole::Utils::Domain;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Carp;

sub guess_current_id {
    my ( $class, $passed, $action, $no_domain_ok ) = @_;

    return ref( $passed ) ? $passed->id : $passed if defined( $passed );

    my $id_from_action = $class->guess_current_id_from_action( $action );
    return $id_from_action if defined( $id_from_action );

    my $domain = $class->guess_current_from_action( $action );
    return $domain->id if $domain;

    $domain = eval { CTX->lookup_action('domains_api')->e( get_current_domain => {} ) };
    return $domain->id if $domain;

    return CTX->{current_domain_id} if defined( CTX->{current_domain_id} );
    return CTX->{current_domain}->id if CTX->{current_domain};

    unless ( $no_domain_ok ) {
        eval { Carp::confess };
        get_logger(LOG_APP)->error( "could not resolve domain id: ". $@ );
    }
    return 0;
}

sub guess_current {
    my ( $class, $passed, $action, $no_domain_ok ) = @_;

    if ( defined ( $passed ) ) {
        return ref( $passed ) ? $passed : eval { CTX->lookup_action('domains_api')->e(
            get_domain_object_by_id => { domain_id => $passed }
        ) };
    }

    my $from_action = $class->guess_current_from_action( $action );
    return $from_action if defined( $from_action );

    my $id_from_action = $class->guess_current_id_from_action( $action );
    if ( defined( $id_from_action ) ) {
        my $domain = eval { CTX->lookup_action('domains_api')->e(
            get_domain_object_by_id => { domain_id => $id_from_action }
        ) };
        return $domain if $domain;
    }

    my $domain = eval { CTX->lookup_action('domains_api')->e( get_current_domain => {} ) };
    return $domain if $domain;

    return CTX->{current_domain} if CTX->{current_domain};
    if ( CTX->{current_domain_id} ) {
        my $domain = eval { CTX->lookup_action('domains_api')->e(
            get_domain_object_by_id => { domain_id => CTX->{current_domain_id} }
        ) };
        return $domain if $domain;
    }

    unless ( $no_domain_ok ) {
        eval { Carp::confess };
        get_logger(LOG_APP)->error( "could not resolve domain: ". $@ );
    }
    return 0;
}

sub guess_current_id_from_action {
    my ( $class, $action ) = @_;

    if ( $action ) {
        my $action_param = $action->param('domain_id');
        return $action_param if defined( $action_param );
    }

    if ( CTX && CTX->controller && CTX->controller->initial_action ) {
        my $action_param = CTX->controller->initial_action->param('domain_id');
        return $action_param if defined( $action_param );
    }

    return undef;
}

sub guess_current_from_action {
    my ( $class, $action ) = @_;

    if ( $action ) {
        my $action_param = $action->param('domain');
        return $action_param if defined( $action_param );
    }

    if ( CTX && CTX->controller && CTX->controller->initial_action ) {
        my $action_param = CTX->controller->initial_action->param('domain');
        return $action_param if defined( $action_param );
    }

    return undef;
}

sub domain_id_for_group_id {
    my ( $class, $group_id ) = @_;

    my $domains = CTX->lookup_action('dicole_domains')->execute( get_group_domains => {
        group_id => $group_id
    } );

    return $domains->[0];
}

sub guess_current_settings_tool {
    my ( $class, $passed, $action, $no_domain_ok ) = @_;

    my $did = $class->guess_current_id( $passed, $action, 0 );
    my $settings_tool_name = $did ? 'domain_user_manager_' . $did : 'user_manager';

    return $settings_tool_name;
}

sub setting {
    my ( $class, $domain_or_id, $attribute ) = @_;

    my $tool = $class->guess_current_settings_tool( $domain_or_id );

    return Dicole::Settings->fetch_single_setting(
        tool => $tool,
        attribute => $attribute,
    );
}

sub settings {
    my ( $class, $domain_or_id ) = @_;

    my $tool = $class->guess_current_settings_tool( $domain_or_id );

    return Dicole::Settings->new_fetched_from_params(
        tool => $tool,
    );   
}

sub resolve_facebook_connect_settings {
    my ( $self, $domain_or_id ) =  @_;

    return ( undef, undef, 1 ) if CTX->server_config->{dicole}{facebook_connect_disabled} || $self->setting( $domain_or_id, 'facebook_connect_disabled' );

    my $disabled = CTX->server_config->{dicole}{facebook_connect_default_disabled};
    if ( $disabled ) {
        $disabled = $self->setting( $domain_or_id, 'facebook_connect_enabled' ) ? 0 : 1;
    }

    return ( undef, undef, 1 ) if $disabled;

    my $id = $self->setting( $domain_or_id, 'facebook_connect_app_id' ) || CTX->server_config->{dicole}{facebook_connect_app_id};
    my $secret = $self->setting( $domain_or_id, 'facebook_connect_app_secret' ) || CTX->server_config->{dicole}{facebook_connect_app_secret};

    $disabled = 1 unless $id && $secret;

    return ( $id, $secret, $disabled );
}

1;
