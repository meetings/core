package OpenInteract2::Action::DicoleEventSourceJSON;

use strict;

use base qw( OpenInteract2::Action::DicoleEventSourceCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Security qw( :check );

sub fetch {
    my ( $self ) = @_;

    return { error => {  code => 301, message => "Invalid credentials" } } unless $self->_check_secret_ok;

    if ( CTX->request->param('gateway') ) {
        my $gateways = CTX->lookup_object('event_source_gateway')->fetch_group( {
            where => 'gateway = ?',
            value => [ CTX->request->param('gateway') ],
        } ) || [];

        my $gateway = shift @$gateways;
        if ( ! $gateway ) {
            $gateway = CTX->lookup_object('event_source_gateway')->new;
            $gateway->gateway( CTX->request->param('gateway') );
            $gateway->last_update( time );
            $gateway->save;
        }
        elsif ($gateway->last_update < time - 60) {
            $_->remove for @$gateways;
            $gateway->last_update( time );
            $gateway->save;
        }
    }

    my $after = CTX->request->param('after') // -1;
    my $before = CTX->request->param('before') // -1;
    my $amount = CTX->request->param('amount') // 100;
    my $safety = 5;

    $before = time + $safety if $before < 0;

    my $events = CTX->lookup_object('event_source_event')->fetch_group( {
        where => 'updated > ? AND updated < ?',
        value => [ $after, $before ],
        order => 'updated desc',
        limit => $amount + 1,
    } );

    my $extra_event = ( scalar( @$events) > $amount ) ? pop @$events : ();

    if ( $extra_event ) {
        $after = $extra_event->updated;
    }

    $before = time - $safety if $before > time - $safety;

    my $params = {
        after => $after,
        before => $before,
        events => [ map { {
            version => $_->version,
            id => $_->id,
            updated => $_->updated,
            timestamp => $_->timestamp,
            topics => $self->_form_event_topics( $_ ),
            security => $self->_form_event_secure( $_ ),
            data => Dicole::Utils::JSON->decode( $_->payload ),
        } } @$events ],
    };

    return { result => $params };
}

sub _check_secret_ok {
    my ( $self ) = @_;

    return ( CTX->request->param('secret') eq CTX->server_config->{dicole}{event_source_sync_secret} ) ? 1 : 0;
}

sub authenticate {
    my ( $self ) = @_;

    my ( $token, $domain_name ) = split /:/, CTX->request->param('token'), 2;
    $domain_name ||= CTX->request->param('domain');

    return { error => { code => 300, message => 'Unspecified domain' } } unless $domain_name;

    my $domain_object = CTX->lookup_action('domains_api')->execute(
        get_domain_object => { domain_name => $domain_name }
    );

    return { error => { code => 301, message => 'Invalid domain' } } unless $domain_object;

    my $domain_id = $domain_object->id;

    my $user = undef;
    my $secure = 0;

    if ( $token ne 'anonymous' ) {
        my ( $token_uid, $token_secure, $token_domain, $token_time ) = Dicole::Utils::User->resolve_identification_key( $token );

        if ( $token_uid ) {
            $user = eval { Dicole::Utils::User->ensure_object( $token_uid ) };
        }

        return { error => { code => 305, message => 'Invalid auth token' } } unless $user && $domain_id == $token_domain && $token_time > ( time - 60 );

        $secure = $token_secure;
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

    # TODO: meetings m: and sm: rights
    push @rights, ( map { 'g::' . $_ } @$gids );
    push( @rights, ( map { 'sg::' . $_ } @$gids ) ) if $secure;
    push @rights, 'p';

    return { result => {
        invalidate_on => [ $user ? ( 'ud:' . $user->id . ':' . $domain_id, 'd:' . $domain_id, 'all' ) : ( 'd:' . $domain_id, 'all' ) ],
        security => \@rights,
    } };
}

1;
