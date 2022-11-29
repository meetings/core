package OpenInteract2::Action::DicoleDomains;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Net::Subnets;

use Dicole::Utils::SQL;

use constant DEFAULT_LOGO_URL => '/images/theme/default/navigation/logo.gif';

our $VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

=pod

=head2 domain_default_language( )

Get domain default language used for guests if set.

=cut

sub domain_default_language {
    my ( $self ) = @_;
    my $lang;
    eval { $lang = $self->_get_domain_object->default_language; };
    return $lang;
}

=pod

=head2 domain_default_timezone( )

Get domain default timezone used for guests if set.

=cut

sub domain_default_timezone {
    my ( $self ) = @_;
    my $lang;
    eval { $lang = $self->_get_domain_object->default_timezone; };
    return $lang;
}

=pod

=head2 url_after_logout( )

Get url after logout it set.

=cut

sub url_after_logout {
    my ( $self ) = @_;
    my $url;
    eval { $url = $self->_get_domain_object->url_after_logout; };
    return $url;
}

=pod

=head2 domain_custom_navigation( )

Custom navigation action if set.

=cut

sub domain_custom_navigation {
    my ( $self ) = @_;
    my $a;
    eval {
        my $d = $self->_get_domain_object;
        $a = CTX->lookup_action( $d->navi_action ) if $d->navi_action;
    };
    return $a;
}

=pod

=head2 domain_custom_new_user_actions( )

Custom new user actions action if set.

=cut

sub domain_custom_new_user_actions {
    my ( $self ) = @_;
    my $a;
    eval {
        my $d = $self->_get_domain_object;
        $a = CTX->lookup_action( $d->new_user_action ) if $d->new_user_action;
    };
    return $a;
}

=pod

=head2 domain_admin_email( )

Get domain administrator email address.

=cut

sub domain_admin_email {
    my ( $self ) = @_;

    my $domain_admin_email;
    eval {
        my $d = $self->_get_domain_object;
        my $s = eval {
            my $d_str = "domain_user_manager_$d->{domain_id}";
            my $data = Dicole::Generictool::Data->new;
            $data->object( CTX->lookup_object('dicole_tool_settings') );
            $data->query_params( {
                select => [ 'value' ],
                from   => [ 'dicole_tool_settings' ],
                where  => 'dicole_tool_settings.tool = ? AND dicole_tool_settings.attribute = ?',
                value  => [ $d_str, 'domain_admin_email' ] } );
            $data->data_group;
            if ($data->data->[0]) {
                $domain_admin_email = $data->data->[0]->{value};
            }
        };
    };

    return $domain_admin_email;
}

=pod

=head2 user_registration_enabled ( )

Check wether user registration is enabled for domain.

=cut

sub user_registration_enabled {
    my ( $self ) = @_;

    my $user_registration_enabled = 0;
    eval {
        my $d = $self->_get_domain_object;
        my $s = eval {
            my $d_str = "domain_user_manager_$d->{domain_id}";
            my $data = Dicole::Generictool::Data->new;
            $data->object( CTX->lookup_object('dicole_tool_settings') );
            $data->query_params( {
                select => [ 'value' ],
                from   => [ 'dicole_tool_settings' ],
                where  => 'dicole_tool_settings.tool = ? AND dicole_tool_settings.attribute = ?',
                value  => [ $d_str, 'account_registration_enabled' ] } );
            $data->data_group;
            if ($data->data->[0]) {
                $user_registration_enabled = $data->data->[0]->{value};
            }
        };
    };
    return $user_registration_enabled;
}

=pod

=head2 user_registration_default_disabled ( )

Return true if new accounts for domain are to be disabled; false otherwise (the default).

=cut

sub user_registration_default_disabled {
    my ( $self ) = @_;

    my $user_registration_default_disabled = 0;
    eval {
        my $d = $self->_get_domain_object;
        my $s = eval {
            my $d_str = "domain_user_manager_$d->{domain_id}";
            my $data = Dicole::Generictool::Data->new;
            $data->object( CTX->lookup_object('dicole_tool_settings') );
            $data->query_params( {
                select => [ 'value' ],
                from   => [ 'dicole_tool_settings' ],
                where  => 'dicole_tool_settings.tool = ? AND dicole_tool_settings.attribute = ?',
                value  => [ $d_str, 'account_registration_default_disabled' ] } );
            $data->data_group;
            if ($data->data->[0]) {
                $user_registration_default_disabled = $data->data->[0]->{value};
            }
        };
    };
    return $user_registration_default_disabled;;
}

=pod

=head2 check_ip_address_restriction( )

Return true if domain has been restricted by IP addresses; false otherwise.

=cut

sub check_ip_address_restriction {
    my ( $self ) = @_;

    my $data = Dicole::Generictool::Data->new;
    eval {
        my $d = $self->_get_domain_object;
        my $d_str = "domain_user_manager_$d->{domain_id}";
        $data->object( CTX->lookup_object('dicole_tool_settings') );
        $data->query_params( {
           where  => 'tool = ? AND ( attribute = ? OR attribute = ? )',
           value  => [ $d_str, 'ip_restrictions', 'ip_restrictions_list' ] } );
        $data->data_group;
    };
    return undef if $@;

    my $settings = {};
    foreach my $object ( @{ $data->data } ) {
        $settings->{$object->{attribute}} = $object->{value};
    }
    if ( $settings->{ip_restrictions} ) {
        # first gather claimed ip forward queue to an array
        # and then cycle out the first one which is not in the
        # trusted proxies list (or the last one if original source
        # is also marked as a trusted proxy ). If the trusted
        # proxies list is not an array but 1/yes, cycle to the
        # last given ip (supposedly the original one).
        my @hosts = ( CTX->request->remote_host );
        if ( CTX->request->can('forwarded_for') && CTX->request->forwarded_for ) {
            unshift @hosts, reverse( split /\s*,\s*/, CTX->request->forwarded_for );
        }
        my $host = pop @hosts;
        my $trusted = CTX->server_config->{dicole}{trusted_proxy};
        while ( scalar( @hosts ) && $trusted ) {
            if ( ref ( $trusted ) eq 'ARRAY' ) {
                if ( scalar( grep { $_ eq $host } @$trusted ) ) {
                    $host = pop @hosts;
                }
                else {
                    last;
                }
            }
            elsif ( $trusted eq '1' || $trusted eq 'yes') {
                $host = pop @hosts;
            }
            else {
                if ( $host eq $trusted ) {
                    $host = pop @hosts;
                }
                else {
                    last;
                }
            }
        }

        return undef unless $settings->{ip_restrictions_list};
        my $sn = Net::Subnets->new;
        foreach my $address ( split /((\r?\n)|\s+)/, $settings->{ip_restrictions_list} ) {
            next unless $address =~ /^\d+\.\d+\.\d+\.\d+(\/\d+)?$/;
            if ( $address =~ /\/\d+/ ) {
                $sn->subnets( [ $address ] );
                return undef if $sn->check( \$host );
            }
            return undef if $host eq $address;
        }
        return $self->_msg( 'This site has IP address restrictions and you are not allowed to access this site. Blocked IP: [_1]', $host );
    }
    else {
        return undef;
    }
}

sub users_by_group {
    my ( $self, $group_id, $domain_id ) = @_;

    # Based on group_id param, fetch users in that group for any matching domain
    # or only for a specific domain
    $group_id ||= $self->param( 'group_id' );
    $domain_id ||= $self->param( 'domain_id' );

    my $user_ids = CTX->lookup_action('groups_api')->e( member_id_list => { group_id => $group_id } );

    return $self->filter_user_id_list_to_domain_user_id_list( $user_ids, $domain_id );
}

sub users_by_user {
    my ( $self ) = @_;

    my $user_domains = $self->get_user_domains;

    return [] unless @{ $user_domains } > 0;

    my $iter = CTX->lookup_object( 'dicole_domain_user' )->fetch_iterator( {
        where => 'domain_id IN (' . ( join ',', @{ $user_domains } ) . ')'
    } );

    return $self->_user_ids_distinctively( $iter );
}

sub filter_user_id_list_to_domain_user_id_list {
    my ( $self, $list, $domain_id ) = @_;

    $list ||= $self->param('user_id_list');
    $domain_id ||= $self->param('domain_id');

    return $list unless $domain_id;

    my $links = CTX->lookup_object( 'dicole_domain_user' )->fetch_group( {
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => $list ),
        value => [ $domain_id ],
    } );

    return [ map { $_->{user_id} } @$links ];
}


sub users_by_domain {
    my ( $self, $domain_id ) = @_;

    # default to current domain
    $domain_id ||= $self->param('domain_id');
    $domain_id ||= $self->get_current_domain->{domain_id};

    my $dus = CTX->lookup_object( 'dicole_domain_user' )->fetch_group( {
        where => 'domain_id = ?',
        value => [ $domain_id ]
    } );

    my %ids_found = map { $_->{user_id} => 1 } @$dus;

    return [ keys %ids_found ];
}

sub add_domain_group {
    my ( $self, $domain_id ) = @_;

    $domain_id ||= $self->param('domain_id');
    $domain_id ||= $self->_get_domain_object->id;

    my $domain_group = CTX->lookup_object( 'dicole_domain_group' )->new;
    $domain_group->{domain_id} = $domain_id;
    $domain_group->{group_id} = $self->param( 'group_id' );
    $domain_group->save;

    return 1;
}

sub add_user_to_domain {
    my ( $self ) = @_;

    my $domain = $self->_get_domain_object;

    my $domain_user = CTX->lookup_object( 'dicole_domain_user' )->new;
    $domain_user->{domain_id} = $domain->id;
    $domain_user->{user_id} = $self->param('user_id');
    $domain_user->save;

    return 1;
}

sub remove_user_from_domain {
    my ( $self, $user_id, $domain_id ) = @_;

    $user_id ||= $self->param('user_id');
    $domain_id ||= $self->param('domain_id');
    $domain_id ||= $self->get_current_domain->{domain_id};
    scalar($domain_id) || ($domain_id = $domain_id->{domain_id});

    # we need user_id & domain_id
    $user_id || return undef;
    $domain_id || return undef;

    # remove user from domain's groups
    my $domain_gids = $self->groups_by_domain( $domain_id );
    for my $group_id ( @$domain_gids ) {
        if ( Dicole::Utils::User->belongs_to_group( $user_id, $group_id ) ) {
            CTX->lookup_action('groups_api')->e( remove_user_from_group => {
                user_id => $user_id,
                group_id => $group_id,
            } );
        }
    }

    my $user = Dicole::Utils::User->ensure_object( $user_id );
    my $notes = Dicole::Utils::User->notes_data( $user );
    $notes->{$domain_id}{user_removed_date} ||= [];
    push @{ $notes->{$domain_id}{user_removed_date} }, time();
    Dicole::Utils::User->set_notes_data( $user, $notes );


    # remove user from domain
    eval {
        my $domain_user = CTX->lookup_object( 'dicole_domain_user' )->fetch_group({
            where => 'domain_id = ? AND user_id = ?',
            value => [ $domain_id, $user_id ],
        })->[0];
        $domain_user->remove;
    };

    if ($@) {
        # XXX: logging code
        return undef;
    }

    return $user_id; # id of removed user
}

sub groups_by_user {
    my ( $self ) = @_;

    my $user_domains = $self->get_user_domains;

    return [] unless @{ $user_domains } > 0;

    my $domains = CTX->lookup_object( 'dicole_domain_group' )->fetch_group( {
        where => Dicole::Utils::SQL->column_in( 'domain_id', $user_domains ),
    } ) || [];

    my %groups = ();
    $groups{ $_->{group_id} } = () for @$domains;

    return [ keys %groups ];
}

sub groups_by_domain {
    my ( $self, $domain_id ) = @_;

    $domain_id ||= $self->param('domain_id');
    $domain_id ||= $self->_get_domain_object->id;

    my $groups = CTX->lookup_object( 'dicole_domain_group' )->fetch_group( {
        where => 'domain_id = ?',
        value => [ $domain_id ]
    } ) || [];

    my @domain_groups =  map { $_->{group_id} } @$groups;

    return \@domain_groups;
}

sub login_user_in_domain {
    my ( $self ) = @_;
    my $domain = $self->_get_domain_object;
    my $user_domains = $self->get_user_domains;
    unless ( ( grep { $_ == $domain->id } @{ $user_domains } ) > 0 ) {
        my @domains;
        foreach my $user_domain ( @{ $user_domains } ) {
            my $user_domain_object = CTX->lookup_object( 'dicole_domain' )->fetch( $user_domain );
            push @domains, $user_domain_object->{domain_name};
        }
        my $domains_text = join ', ', @domains;
        return $self->_msg( 'You are not allowed to login from this domain. Please try one of the following domains: [_1]', $domains_text );
    }
    return undef;
}

sub is_domain_user {
    my $self = shift @_;
    return $self->user_belongs_to_domain( @_ );
}

sub user_belongs_to_domain {
    my ( $self, $user_id, $domain_id ) = @_;

    $user_id ||= $self->param( 'user_id' );
    $domain_id ||= $self->param( 'domain_id' ) ||
        $self->get_current_domain->{domain_id};

    my $matches = CTX->lookup_object( 'dicole_domain_user' )->fetch_group( {
        where => "user_id = ? AND domain_id = ?",
        value => [ $user_id, $domain_id ]
    } ) || [];
    
    return scalar( @$matches ) ? 1 : 0;
}

sub group_belongs_to_domain {
    my ( $self, $group_id, $domain_id ) = @_;

    $group_id ||= $self->param( 'group_id' );
    $domain_id ||= $self->param( 'domain_id' ) ||
        $self->get_current_domain->{domain_id};

    my $matches = CTX->lookup_object( 'dicole_domain_group' )->fetch_group( {
        where => "group_id = ? AND domain_id = ?",
        value => [ $group_id, $domain_id ]
    } ) || [];
    
    return scalar( @$matches ) ? 1 : 0;
}

sub is_domain_admin {
    my ( $self, $user_id, $domain_id ) = @_;

    $user_id ||= $self->param( 'user_id' );
    $domain_id ||= $self->get_current_domain->{domain_id};

    # XXX: is this proper way to execute this database query? <jani@dicole.org>
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object( 'dicole_domain_admin' ) );
    $data->query_params( {
        from  => [ qw(dicole_domain_admin) ],
        where => "dicole_domain_admin.user_id = ? AND dicole_domain_admin.domain_id = ?",
        value => [ $user_id, $domain_id ]
    } );
    $data->data_group;
    unless (defined($data->data->[0]->{domain_admin_id})) {
	# user is admin not for specified domain
	return 0;
    }  else {
	# user is admin for specified domain
	return 1;
    }
}

sub get_user_domains {
    my ( $self, $user_id ) = @_;

    $user_id ||= $self->param( 'user_id' );

    my $user_domains = CTX->lookup_object( 'dicole_domain_user' )->fetch_group( {
        where => 'user_id = ?',
        value => [ $user_id ]
    } ) || [];

    return [ map { $_->{domain_id} } @{ $user_domains } ];
}

sub get_group_domains {
    my ( $self, $group_id ) = @_;

    $group_id ||= $self->param( 'group_id' );

    my $group_domains = CTX->lookup_object( 'dicole_domain_group' )
        ->fetch_group( {
            where => 'group_id = ?',
            value => [ $group_id ]
    } ) || [];

    return [ map { $_->{domain_id} } @{ $group_domains } ];
}

sub get_domain_theme {
    my ( $self ) = @_;
    my $domain = $self->_get_domain_object;
    return $domain->{theme_id};
}

sub get_domain_logo_url {
    my $self = shift;
    my $domain_o = $self->_get_domain_object;
    $domain_o->{logo_image} ? return $domain_o->{logo_image} : return DEFAULT_LOGO_URL;
}

sub get_domain_setting {
    my ( $self ) = @_;

    my $domain = $self->get_domain_object_by_id || $self->get_domain_object;
    die unless $domain;

    my $tool = $self->param('tool') || 'domain_user_manager';
    $tool .= '_' . $domain->id;

    return Dicole::Settings->fetch_single_setting(
        tool => $tool,
        attribute => $self->param('attribute'),
        user_id => 0,
        group_id => 0,
    );
}

sub get_current_domain {
    my ( $self, $force_refetch ) = @_;

    my $domain_name = CTX->request->server_name;
    return undef unless $domain_name;

    $force_refetch = $self->param('force_refetch') unless defined $force_refetch;
    return $self->_get_domain_object( $domain_name, $force_refetch );
}

sub get_domain_object_by_id {
    my ( $self, $domain_id, $force_refetch ) = @_;

    $force_refetch = $self->param('force_refetch') unless defined $force_refetch;

    return $self->_get_domain_object_by_id( $domain_id || $self->param('domain_id'), $force_refetch );
}

sub get_domain_object {
    my ( $self, $domain_name, $force_refetch ) = @_;

    $force_refetch = $self->param('force_refetch') unless defined $force_refetch;

    return $self->_get_domain_object( $domain_name || $self->param('domain_name'), $force_refetch );
}

sub _get_domain_object {
    my ( $self, $domain_name, $force_refetch ) = @_;

    my $domain = undef;
    $domain_name ||= CTX->request ? CTX->request->server_name : '';
    $domain_name = lc $domain_name;

    $domain_name =~ s/\-(staging|beta)\././;
    $domain_name =~ s/^(staging|beta)\.//;

    unless ( $force_refetch ) {
        $domain ||= $self->param('domain_object');
        $domain ||= ( CTX->request && $self->param('domain_id') ) ?
            CTX->request->request_cache->{domains}->{by_id}->{ $self->param('domain_id') } : undef;
        $domain ||= ( CTX->request && $domain_name ) ?
            CTX->request->request_cache->{domains}->{by_name}->{ $domain_name } : undef;
    }

    if ( ! $domain && ! $self->param('domain_id') ) {
        my $partner = eval { CTX->lookup_action('meetings_api')->e( get_partner_for_domain_name => {
            domain_name => $domain_name,
        } ) };

        $self->param( 'domain_id', $partner->{domain_id} ) if $partner;

        unless ( $force_refetch ) {
            $domain ||= ( CTX->request && $self->param('domain_id') ) ?
                CTX->request->request_cache->{domains}->{by_id}->{ $self->param('domain_id') } : undef;
        }
    }

    if ( ! $domain ) {
        my $id = $self->param('domain_id');
        $id ||= $self->param('domain_object') ? $self->param('domain_object')->id : undef;

        $domain = CTX->lookup_object( 'dicole_domain' )->fetch( $id ) if $id;

        if ( ! $domain ) {
            my $domains = CTX->lookup_object( 'dicole_domain' )->fetch_group( {
                where => 'domain_name = ?',
                value => [ $domain_name ]
            } ) || [];

            $domain = shift @$domains;
        }
    }

    return unless $domain;

    if ( CTX->request ) {
        CTX->request->request_cache->{domains}->{by_id}->{ $domain->id } = $domain;
        CTX->request->request_cache->{domains}->{by_name}->{ $domain->domain_name } = $domain;
    }
 
    return $domain;
}

sub _get_domain_object_by_id {
    my ( $self, $domain_id, $force_refetch ) = @_;

    return undef unless $domain_id;

    unless ( $force_refetch ) {
        if ( CTX->controller && CTX->controller->initial_action ) {
            return CTX->controller->initial_action->param('domain') if
                $domain_id eq CTX->controller->initial_action->param('domain_id');
        }
    }

    return CTX->lookup_object( 'dicole_domain' )->fetch( $domain_id );
}

sub check_if_domain_invalid {
    my ( $self ) = @_;
    $self->_get_domain_object
        ? return 0
        : return $self->_msg( 'Domain not yet configured.' );
}

sub _user_ids_distinctively {
    my ( $self, $iter ) = @_;
    my @domain_users;
    my %lookup = ();
    while ( $iter->has_next ) {
        my $domain_user = $iter->get_next;
        next if $lookup{ $domain_user->{user_id} }++;
        push @domain_users, $domain_user->{user_id};
    }
    return \@domain_users;
}

sub verify_matching_domain {
    my ( $self ) = @_;
    my $a = $self->param('a');
    my $b = $self->param('b');

    my @contenders = ();
    for my $params ( $a, $b ) {
        return 0 unless ref($params) eq 'HASH';
        if ( $params->{user} ) {
            push @contenders, $self->get_user_domains( $params->{user} );
        }
        elsif ( $params->{group} ) {
            push @contenders, $self->get_group_domains( $params->{group} );
        }
        else {
            return 0;
        }
    }

    my %check = map { $_ => 1 } @{ $contenders[1] };
    for ( @{ $contenders[0] } ) {
        return 1 if $check{ $_ };
    }

    return 0;
}

1;
