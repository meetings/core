package OpenInteract2::Action::DicoleEventSourceJSONAPI;

use strict;

use base qw( OpenInteract2::Action::DicoleEventSourceCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Security qw( :check );

sub testpush {
    my ( $self ) = @_;

    return { result => {}};
}

# Deprecated
sub subscribe {
    my ( $self ) = @_;

    return { error => {  code => 101, message => "Invalid secret" } } unless $self->_check_secret_ok;

    my $gw = $self->param('gateway');
    die unless $gw;

    my $sub = CTX->lookup_object('event_source_sync_subscription')->new;

    $sub->gateway( $gw );
    $sub->last_update_date( 0 );
    $sub->next_update_date( 0 );
    $sub->last_confirmed_event( 0 );

    my $session_key = $self->_create_random_session_key;
    my $failsafe = 0;

    while ( $failsafe < 1000 && $self->_get_subscription_for_key( $session_key ) ) {
        $session_key = $self->_create_random_session_key;
        $failsafe++;
    }

    if ( $failsafe > 999 ) {
        get_loogger(LOG_APP)->error("Could not create unique subscription key.. check your algorithm");
        return { error => "Could not create unique subscription key" };
    }

    $sub->session_key( $session_key );
    $sub->save;

    return { result => {
        session => $session_key,
    } };
}

sub _check_secret_ok {
    my ( $self ) = @_;

    return ( $self->param('secret') eq CTX->server_config->{dicole}{event_source_sync_secret} ) ? 1 : 0;
}

sub _create_random_session_key {
    return SPOPS::Utility->generate_random_code( 12 );
}

sub _get_subscription_for_key {
    my ( $self, $key ) = @_;
    my $sub = CTX->lookup_object('event_source_sync_subscription')->fetch_group({
        where => 'session_key = ?',
        value => [ $key ],
    }) || [];

    return shift @$sub;
}

# Deprecated
sub resubscribe {
    my ( $self ) = @_;

    return { error => {  code => 201, message => "Invalid secret" } } unless $self->_check_secret_ok;

    my $sub = $self->_get_subscription_for_key( $self->param('session') );

    return { error => { code => 202, message => "Session does not exist" } } unless $sub;

    my $gw = CTX->request->param('gateway');

    if ( $gw ) {
        $sub->gateway( $gw );
        $sub->error_count( 0 );
        $sub->save;
    }

    return { result => {
        session => $sub->session_key,
    } };
}

sub authenticate {
    my ( $self ) = @_;

    if ( $self->param('token') =~ /:/ ) {
        my ( $domain, $token ) = split /:/, $self->param('token'), 2;
        $self->param('auth_domain', $domain );
        $self->param('token', $token );
    }

    $self->param('auth_domain', $self->param('domain') ) if ! $self->param('auth_domain');

    return { error => { code => 301, message => 'Invalid domain' } } unless $self->param( "auth_domain" );

    my $domain_object = CTX->lookup_action('domains_api')->execute(
        get_domain_object => { domain_name => $self->param( "auth_domain" ) }
    );

    return { error => { code => 301, message => 'Invalid domain' } } unless $domain_object;

    my $domain_id = $domain_object->id;

    my $user = undef;

    if ( $self->param('token') ) {
        if ( $self->param('token') ne 'anonymous' ) {
            $user =  Dicole::Utils::User->fetch_by_authorization_key_in_domain(
                $self->param('token'), $domain_id
            );
            return { error => { code => 305, message => 'Invalid auth token' } } unless $user;
        }
    }
    else {
        $user = Dicole::Utils::User->fetch_user_by_login_and_pass_in_domain(
            $self->param('username'),  $self->param('password'), $domain_id
        );

        return { error => { code => 304, message => 'Invalid password' } } unless $user;
    }

    my $sec = $user ? Dicole::Security->new( $user->id ) : Dicole::Security->new( 0, 'global' );
    my $rights = $sec->rights_lookup_tree;
    my $levels = Dicole::Security->security_levels_by_id;

    my @rights = ();

    for my $level_id ( keys %$rights ) {
        my $level = $levels->{ $level_id };
        next if ! $level || $level->{target_type} eq Dicole::Security->TARGET_USER ||
            $level->{target_type} eq Dicole::Security->TARGET_OBJECT;
        my $targets = $rights->{ $level_id };
        if ( $targets ) {
            for my $target ( keys %$targets ) {
                push @rights, join( ":", ( $level->{stamp}, $domain_id, $target ) )
                    if $targets->{$target} == CHECK_YES();
            }
        }
    }
    
    my $gids = eval { CTX->lookup_action('groups_api')->e( groups_ids_with_user_as_member => {
        user_id => $user->id,
        domain_id => $domain_id,
    } ) } || [];

    push @rights, ( map { 'g::' . $_ } @$gids );

    return { result => {
        security => \@rights,
    } };
}

# Deprecated
sub passthrough {
    my ( $self ) = @_;

    return { error => { code => 401, message => 'Invalid domain' } } unless $self->param( "auth_domain" );

    my $domain_object = CTX->lookup_action('domains_api')->execute(
        get_domain_object => { domain_name => $self->param( "auth_domain" ) }
    );

    return { error => { code => 401, message => 'Invalid domain' } } unless $domain_object;

    my $domain_id = $domain_object->id;

    my $user = undef;

    if ( $self->param('token') ) {
        $user = Dicole::Utils::User->fetch_by_authorization_key_in_domain(
            $self->param('token'), $domain_id
        );
        return { error => { code => 405, message => 'Invalid auth token' } } unless $user;
    }
    else {
        $user = Dicole::Utils::User->fetch_user_by_login_and_pass_in_domain(
            $self->param('username'),  $self->param('password'), $domain_id
        );

        return { error => { code => 404, message => 'Invalid password' } } unless $user;
    }

    my $method = $self->param( "method" );
    return { error => { code => 406, message => 'Invalid method' } } unless $method;
    return { error => { code => 406, message => 'Invalid method' } } if $method =~ /^_/;

    my $pt_action = CTX->lookup_action('event_source_passthrough');
    return { error => { code => 406, message => 'Invalid method' } } unless $pt_action->can( $method );

    my $params = $self->param( "params" ) || {};
    $params = {} if ref( $params ) ne 'HASH';
    $params->{auth_domain_id} = $domain_id;
    $params->{auth_user} = $user;

    my $result = eval { $pt_action->execute( $method, $params )  };
    if ( $@ ) {
        return { error => { code => 400, message => $@ } };
    }
    return { result => $result };
}

1;
