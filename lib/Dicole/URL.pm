package Dicole::URL;

# $Id: URL.pm,v 1.33 2010-01-14 15:28:59 amv Exp $

use base OpenInteract2::URL;

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::URL;
use URI;
use Dicole::Pathutils;
use URI::Escape;
use Dicole::Utils::Domain;

sub create {
    my ( $self, $array, $params, $anchor, $do_not_escape ) = @_;

    my $path = '/';
    if ( ref $array eq 'ARRAY' && scalar $array ) {
        $path = sprintf('/%s', join( '/', @$array ) );
    }

    $path = Dicole::Pathutils->escape_uri( $path );

    my $anc = $anchor ? '#' . URI::Escape::uri_escape( $anchor ) : '';
    
    $params ||= {};

    # NOTE: do not escape would effect only the $path so this doesnt actually do anything
    my @params = scalar( keys %$params ) ? ( $params, $do_not_escape ) : ();

    my $url = $self->SUPER::create( $path, @params ) . $anc;

    # HACK: This lets some params get passed properly without breaking everything else
    for my $param ( qw( utm_source utm_medium utm_campaign ) ) {
        if ( $params->{ $param } ) {
            $url =~ s/\&amp\;$param/\&$param/;
        }
    }

    return $url;
 }

sub create_from_parts { return from_parts( @_ ); }

sub from_parts {
    my ( $self, %parts ) = @_;

    my $p = {
        action => undef,
        task => undef,
        domain_id => undef,
        target => undef,
        additional => undef,
        group => undef,
        other => undef,
        params => {},
        anchor => undef,
        do_not_escape => undef,
        add_params => {},
        remove_params => {},

        %parts,
    };

    my $action_name = $p->{action};
    my $task = $p->{task};
    my $target_id = defined( $p->{target} ) ? $p->{target} : $p->{group};
    my $other = $p->{additional} || $p->{other} || [];
    my $domain_id = $p->{domain_id};

    $p->{params} = { %{ $p->{params} || {} }, %{ $p->{add_params} || {} } };

    for my $remove_param ( keys %{ $p->{remove_params} || {} } ) {
        delete $p->{ $remove_param };
    }
    
    my $action = CTX->lookup_action( $action_name );
    die unless $action;
    unless ( defined $task ) {
        $task = $action->param('task_default');
    }
    
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $target_id ||= 0;
    
    if ( defined( $domain_id ) ) {
        my $action = CTX->lookup_action( $action_name );
        die unless $action;

        unless ( defined $task ) {
            $task = $action->param('task_default');
        }

        my $target_type = $action->param('target_type') || '';
        my $target_group_id = $target_type eq 'group' ? $target_id : 0;
        my $target_user_id = $target_type eq 'user' ? $target_id : 0;
        my $ch = $self->alias_creation_hash;

        my $alias = '';
        my $other_aliases = $ch->{$domain_id}{$target_group_id}{$target_user_id}{$action_name}{$task};

        if ( @$other && grep( { $_ ne '' } keys( %$other_aliases ) ) ) {
            my @left = @$other;
            while ( @left ) {
                my $json = Dicole::Utils::JSON->encode( [ map { "" . $_ } @left ] );
                if ( exists $ch->{$domain_id}{$target_group_id}{$target_user_id}{$action_name}{$task}{$json} ) {
                    $alias = $ch->{$domain_id}{$target_group_id}{$target_user_id}{$action_name}{$task}{$json};
                    last;
                }
                pop @left;
            }
        }

        $alias ||= $ch->{$domain_id}{$target_group_id}{$target_user_id}{$action_name}{$task}{''} ||
            $ch->{$domain_id}{$target_group_id}{$target_user_id}{$action_name}{''}{''} ||
            $ch->{$domain_id}{$target_group_id}{$target_user_id}{''}{''}{''};
        if ( $alias ) {
            if ( $alias->action && $alias->task && $alias->additional ) {
                shift @$other for @{ Dicole::Utils::JSON->decode( $alias->additional ) };
                return $self->create( [ $alias->alias, @$other ], $p->{params}, $p->{anchor}, $p->{do_not_escape} );
            }
            elsif ( $alias->action && $alias->task ) {
                return $self->create( [ $alias->alias, @$other ], $p->{params}, $p->{anchor}, $p->{do_not_escape} );
            }
            elsif ( $alias->action ) {
                return $self->create( [ $alias->alias, $task || (), @$other ], $p->{params}, $p->{anchor}, $p->{do_not_escape} );
            }
            else {
                return $self->create( [ $alias->alias, $action_name, $task || (), @$other ], $p->{params}, $p->{anchor}, $p->{do_not_escape} );
            }
        }
    }

    die if ( $p->{force_version} && $p->{force_version} == 2 );

    my $array = [ $action_name ];
    push @$array, $task || ();

    if ( ! $other || ! @$other || $other->[0] !~ /^\d+$/ ) {
        push @$array, $target_id if $target_id;
    }
    else {
        push @$array, $target_id || 0;    
    }

    push @$array, @$other;
    return $self->create( $array, $p->{params}, $p->{anchor}, $p->{do_not_escape} );
}

sub create_from_current {
    my ( $self, %parts ) = @_;
    
    return $self->create_from_action( from_action => CTX->controller->initial_action, %parts );
}

sub create_full_from_current {
    my ( $self, %parts ) = @_;
    
    return $self->create_full_from_action( from_action => CTX->controller->initial_action, %parts );
}

sub create_from_action {
    my ( $self, %parts ) = @_;

    my $ap = $self->get_parts_from_action( $parts{from_action} );

    return $self->from_parts( %$ap, %parts );
}

sub create_full_from_action {
    my ( $self, %parts ) = @_;

    my $ap = $self->get_full_parts_from_action( $parts{from_action} );

    return $self->from_parts( %$ap, %parts );
}

sub strip_auth_from_current {
    my ( $self ) = @_;

    return $self->strip_param_from_current( 'dic' );
}

sub strip_param_from_current {
    my ( $self, $param ) = @_;

    my $ap = $self->get_full_parts_from_action( CTX->controller->initial_action );
    delete $ap->{params}->{ $param };

    return $self->from_parts( %$ap );
}

sub get_parts_from_action {
    my ( $self, $action ) = @_;

    return {} if ! $action;

    return {
        action => $action->name,
        task => $action->task,
        target => $action->param('target_id') || 0,
        additional => scalar( $action->param('target_additional') ),
        domain_id => scalar( $action->param('domain_id') ),

         # THESE ARE FOR COMPATIBILITY:
        group => $action->param('target_id') || 0,
        other => scalar( $action->param('target_additional') ),
    }
}

sub get_full_parts_from_action {
    my ( $self, $action ) = @_;
    
    return {} if ! $action;
    
    my $parts = $self->get_parts_from_action( $action );
    
    $parts->{params} = $action->param('url_params');
    $parts->{anchor} = $action->param('url_anchor');
    return $parts;
}

sub get_path_array {
    my ( $self, $url ) = @_;

    # Hack: get rid of GET parameters and anchor
    $url =~ s/[\#\?].*$//;
    $url =~ s{/+}{/}g;

    # Convert %?? to correct characters
    $url = URI::Escape::uri_unescape( $url );

    my @parts = split '/', $url;

    shift @parts if $url =~ /^\//;

    return \@parts;
}

sub get_server_url {
    my ( $self, $port, $force_request_port_sniffing ) = @_;

    $port = $self->get_server_port( $port, $force_request_port_sniffing );

    return $self->_get_domain_url( CTX->request->server_name, $port );
}

sub get_server_port {
    my ( $self, $port, $force_request_port_sniffing ) = @_;

    if ( CTX->controller && CTX->controller->initial_action ) {
        my $id = CTX->controller->initial_action->param('domain_id');
        $port ||= CTX->server_config->{domain_server_info}{ $id }{server_port} if $id;
    }

    # This is basically the only way if we are behind an ssl wrapper..
    $port ||= CTX->server_config->{server_info}{server_port};

    if ( ! $port || $force_request_port_sniffing ) {
        if ( CTX->server_config->{server_info}{use_apache_x_forwarded_proto} ) {
            my $proto = eval { CTX->request->cgi->http('X-Forwarded-Proto') };

            if ( $proto ) {
                $port = 443 if lc( $proto ) eq 'https';
                $port = 80 if lc( $proto ) eq 'http';
            }
        }
        else {
            eval {
                $port = CTX->request->server_port;
            };
        }
    }

    return $port;
}

sub get_domain_url {
    my ( $self, $domain_id, $port, $force_request_port_sniffing ) = @_;

    unless ( $domain_id ) {
        return $self->get_server_url( $port, $force_request_port_sniffing );
    }

    $port ||= CTX->server_config->{domain_server_info}{ $domain_id }{server_port};
    $port ||= CTX->server_config->{server_info}{server_port};

    if ( CTX->controller && CTX->controller->initial_action ) {
        my $domain = CTX->controller->initial_action->param('domain');
        if ( $domain && $domain->id == $domain_id ) {
            return $self->_get_domain_url( $domain->domain_name, $port );
        }
    }

    my $domain_name = $self->_resolve_domain_name_from_cache( $domain_id );

    return $self->_get_domain_url( $domain_name, $port );
}

sub get_domain_name_url {
    my ( $self, $domain_name, $port ) = @_;

    return $self->_get_domain_url( $domain_name, $port );
}

sub _get_domain_url {
    my ( $self, $domain_name, $port ) = @_;

    $port ||= 80;

    my $protocol = 'http://';
    if ( $port == 443 ) {
        $port = undef;
        $protocol = 'https://';
    }
    elsif ( $port == 80 ) {
        $port = undef;
    }
    else {
        $port = ':' . $port;
    }
    return $protocol . $domain_name . $port;
}

sub _resolve_domain_name_from_cache {
    my ( $self, $domain_id ) = @_;

    # invalidate cache each 100 seconds
    my $timestamp_separator = time() / 100;
    my $cache = CTX->{temporary_domain_name_cache}{ $timestamp_separator };
    CTX->{temporary_domain_name_cache} = {} unless $cache;

    my $name = $cache->{ $domain_id };

    # try twice just for kicks because the default sucks ;)
    $name ||= eval { CTX->lookup_object('dicole_domain')->fetch( $domain_id )->domain_name };
    $name ||= eval { CTX->lookup_object('dicole_domain')->fetch( $domain_id )->domain_name };

    $name ||= CTX->server_config->{server_info}{server_name};

    return CTX->{temporary_domain_name_cache}{ $timestamp_separator }{ $domain_id } = $name;
}

sub validate_alias_caches {
    my ( $self ) = @_;

    my $cache = $self->_get_cached_alias_hashes;
    return unless $cache;
    
    my $aliases = CTX->lookup_object('url_alias')->fetch_group( {
        order => 'creation_date desc, alias_id desc',
        limit => 1,
    } ) || [];
    my $last_alias = shift @$aliases;
    my $last_timestamp = $last_alias ? join( ":", ( $last_alias->creation_date, $last_alias->alias_id ) ) : '';
    
    unless ( $last_timestamp eq $cache->{timestamp} ) {
        $self->_invalidate_cached_alias_hashes;
    }
}

sub alias_creation_hash {
    my ( $self ) = @_;
    
    return $self->alias_hashes->{creation};
}

sub alias_resolving_hash {
    my ( $self ) = @_;
    
    return $self->alias_hashes->{resolving};
}

sub alias_hashes {
    my ( $self ) = @_;

    my $cache = $self->_get_cached_alias_hashes;
    
    return $cache if $cache;
    
    $cache = $self->_fetch_alias_hashes;
    
    $self->_set_cached_alias_hashes( $cache );
    
    return $cache;
}

sub _invalidate_cached_alias_hashes {
    my ( $self ) = @_;
    
    CTX->{temporary_alias_cache} = undef;
}

sub _get_cached_alias_hashes {
    my ( $self ) = @_;
    return CTX->{temporary_alias_cache};
}

sub _set_cached_alias_hashes {
    my ( $self, $hashes ) = @_;
    CTX->{temporary_alias_cache} = $hashes;
}

sub _fetch_alias_hashes {
    my ( $self ) = @_;

    my $aliases = CTX->lookup_object('url_alias')->fetch_group( {
        order => 'creation_date asc, alias_id asc',
    } ) || [];

    my %creation_hash = ();
    my %resolving_hash = ();

    for my $alias ( @$aliases ) {
        if ( $alias->action && $alias->task && $alias->additional ) {
            $creation_hash{ $alias->domain_id }{ $alias->group_id }{ $alias->user_id }{ $alias->action }{ $alias->task }{ $alias->additional } = $alias;
        }
        elsif ( $alias->action && $alias->task ) {
            $creation_hash{ $alias->domain_id }{ $alias->group_id }{ $alias->user_id }{ $alias->action }{ $alias->task }{''} = $alias;
        }
        elsif ( $alias->action ) {
            $creation_hash{ $alias->domain_id }{ $alias->group_id }{ $alias->user_id }{ $alias->action }{''}{''} = $alias;
        }
        else {
            $creation_hash{ $alias->domain_id }{ $alias->group_id }{ $alias->user_id }{''}{''}{''} = $alias;
        }
        $resolving_hash{ $alias->domain_id }{ $alias->alias } = $alias;
    }
    
    my $last_alias = $aliases->[-1];
    my $last_timestamp = $last_alias ? join( ":", ( $last_alias->creation_date, $last_alias->alias_id ) ) : '';
    
    return {
        timestamp => $last_timestamp,
        creation => \%creation_hash,
        resolving => \%resolving_hash,
    };
}

sub create_alias {
    my ( $self, $params ) = @_;

    $params->{domain_id} ||= 0;
    $params->{group_id} ||= 0;
    $params->{user_id} ||= 0;
    $params->{action} ||= '';
    $params->{task} ||= '';
    my $string = $params->{from_string};

    my $rh = $self->alias_resolving_hash;

    my $try = 1;
    my $old_renewed = 0;
    my $alias = $self->_create_alias_from_string( $string );
    my $ao;

    while ( $ao = $rh->{ $params->{domain_id} }{ $alias } ) {
        my $match = 1;
        for my $key ( qw(
            group_id
            user_id
            action
            task
        ) ) {
            $match = 0 unless (
                ( ! $ao->{$key} && ! $params->{$key} )
                ||
                ( $ao->{$key} && $params->{$key} && $ao->{$key} eq $params->{$key} )
            );
        }

        if ( $match ) {
            $ao->creation_date( time );
            $ao->save;
            last;
        }
        else {
            $ao = undef;
            $try++;
            $alias = $self->_create_alias_from_string( $string ) . '-' . $try;
        }
    }

    unless ( $ao ) {
        $ao = CTX->lookup_object('url_alias')->new;
        $ao->domain_id( $params->{domain_id} );
        $ao->user_id( $params->{user_id} );
        $ao->group_id( $params->{group_id} );
        $ao->creation_date( time );
        $ao->action( $params->{action} );
        $ao->task( $params->{task} );
        $ao->additional( ( ref( $params->{additional} ) eq 'ARRAY' ) ? Dicole::Utils::JSON->encode( $params->{additional} ) : '' ); 
        $ao->alias( $alias );
        $ao->save;
    }

    return $ao;
}

sub _create_alias_from_string {
    my ( $self, $string ) = @_;
    
    return Dicole::Utils::Text->utf8_to_url_readable( $string );
}

1;
