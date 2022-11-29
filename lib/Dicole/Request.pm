package Dicole::Request;

# $Id: Request.pm,v 1.20 2009-01-07 14:42:32 amv Exp $

use strict;
use base qw( OpenInteract2::Request Class::Accessor );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::SessionStore;
use Dicole::URL;
use Data::Dumper;
use Dicole::Utils::SPOPS;
use Dicole::Utils::Session;
    
# I think that all but url_query of the following are deprecated ;-(
# I'm not sure though ;)

__PACKAGE__->mk_accessors(
    qw/ url_query request_cache_var

        active_group target_id
        target_user target_user_id target_group
        target_group_id task_name action_name /
);

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/ );

my ( $log );

# Override session creation to use domain specific cookie
sub _create_session {
    my ( $self ) = @_;
    my $session_id = $self->cookie( Dicole::Utils::Session->cookie_name( $self ) );
    my $session_info = CTX->lookup_session_config;
    my $oi_session_class = $session_info->{class};
    my $session = $oi_session_class->create( $session_id );
    return $self->session( $session );
}

sub request_cache {
    my ( $self ) = @_;

    $self->request_cache_var( {} ) unless $self->request_cache_var;
    return $self->request_cache_var;
}

sub assign_languages {
    my ( $self, @p ) = @_;

    if ( ! $self->auth_is_logged_in && ! $self->session->{language} ) {
        eval {
            if ( my $default_lang =  CTX->lookup_action( 'domains_api' )->e( domain_default_language => {} ) ) {
                unshift @p, $default_lang;
            }
        };

        my $partner = eval { CTX->lookup_action('meetings_api')->e( get_partner_for_domain_name => {
            domain_name => $self->server_name      
        } ) };

        if ( $partner ) {
            if ( my $partner_lang = CTX->lookup_action('meetings_api')->_get_note( default_language => $partner ) ) {
                unshift @p, $partner_lang;
            }
        }
    }

    return $self->SUPER::assign_languages( @p );
}

sub assign_current_group_language {
    my ( $self, $controller ) = @_;

    return unless $controller && $controller->initial_action;

    my $group = $self->_return_url_after_login_group;
    
    $group ||= $controller->initial_action->param('target_group');

    return unless $group;

    return $self->_assign_group_language( $controller, $group );
}

sub _return_url_after_login_group {
    my ( $self ) = @_;

    my $group = undef;

    if ( my $url = $self->param('url_after_login') ) {
        if ( $url =~ /^\// ) {
            my $action = eval { OpenInteract2::ActionResolver::Dicole->resolve( undef, $url ); };
            $group = $action ? $action->param('target_group') : undef;
        }
    }

    return $group;
}

sub _assign_group_language {
    my ( $self, $controller, $group ) = @_;

    return unless $group;

    my $data = eval { Dicole::Utils::JSON->decode( $group->meta || '{}' ) } || {};

    if ( my $group_lang = $data->{language} ) {
        undef $self->{_lang_handle};

        $self->{_user_language} ||= [];
        unshift @{ $self->{_user_language} }, $group_lang;

        $controller->initial_action->language( $group_lang );
        undef $controller->initial_action->{language_handle};
    };
}

# Add dicole theme initialization
sub create_theme {
    my ( $self, @p ) = @_;

    $self->_create_cached_dicole_theme 
        unless exists $self->session->{_dicole_cache}{theme}{root};

    return $self->SUPER::create_theme( @p );
}

sub _create_cached_dicole_theme {
    my ( $self, @p ) = @_;

    my $theme_object = undef;

    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ($@) {
        $dicole_domains->task( 'get_domain_theme' );
        if ( my $forced_theme = $dicole_domains->execute ) {
            $theme_object = eval { CTX->lookup_object( 'dicole_theme' )->fetch( $forced_theme ) };
            if ( $@ || !ref( $theme_object ) ) {
                $theme_object = undef;
            }
        }
    }

    if ( !$theme_object && $self->auth_user->{dicole_theme} ) {
        my $user_theme = $self->auth_user->{dicole_theme};
        $theme_object = eval { CTX->lookup_object( 'dicole_theme' )->fetch( $user_theme ) };
        if ( $@ || !ref( $theme_object ) ) {
            $theme_object = undef;
            get_logger( LOG_ACTION )->error(
                "Unable to fetch user theme with id [$user_theme]! Falling back to default theme. $@"
            );
        }
    }
    unless ( $theme_object ) {
        $theme_object = eval { CTX->lookup_object( 'dicole_theme' )->fetch_group( {
            where => 'default_theme = ?', value => [ 1 ]
        } )->[0] };
        if ( $@ || !ref( $theme_object ) ) {
            die "Default theme not found in database!: $@";
        }
    }

    # get parent themes for theme
    $self->session->{_dicole_cache}{theme}{parents}
        = $self->_get_parent_themes( $theme_object );
    $self->session->{_dicole_cache}{theme}{root} = $theme_object;
}

sub _get_parent_themes {
    my ( $self, $theme_object ) = @_;

    $theme_object || return []; # XXX: or undef?

    if ( $theme_object->{parent_theme} ) {
        my @parent_themes;
        my $scan_parent = 1;
        my $parent_theme_id = $theme_object->{parent_theme};
        until ( $scan_parent == 0 ) {
            my $parent_object = eval { CTX->lookup_object( 'dicole_theme' )->fetch_group( {
                where => 'ident = ?', value => [ $parent_theme_id ], limit => 1
            } )->[0] };
            if ( $@ ) {
                get_logger( LOG_ACTION )->error( sprintf(
                   'Unable to retrieve theme with ident [%s]: %s', $parent_theme_id, $@
                ) );
                $scan_parent = 1;
            }
            else {
                unshift @parent_themes, $parent_object;
                if ( $parent_object->{parent_theme} ) {
                    $parent_theme_id = $parent_object->{parent_theme};
                }
                else {
                    $scan_parent = 0;
                }
            }
        }
        return \@parent_themes;
    } else {
        return [];
    }
}

## EXTRA ACCESSORS

# takes url_query as a parameter

sub assign_url_query {
    my ( $self, $query ) = @_;
    $log ||= get_logger( LOG_REQUEST );
   $log->is_info &&
        $log->info( "Setting URL query parameters '" . Dumper( $query ) . "'" );
    $self->url_query( $query );
}

sub sessionstore {
    my ( $self, $value ) = @_;

    if ( defined $value ) {
        $self->{sessionstore} = $value;
    }
    elsif ( ! $self->{sessionstore} ) {
        $self->{sessionstore} = Dicole::SessionStore->new( $self->session );
    }

    return $self->{sessionstore};
}

sub auth_user_groups_ids {
    my ( $self, $new ) = @_;

    if ( defined $new ) {
        $self->{auth_user_groups_ids} = $new;
    }
    elsif ( ref ( $self->{auth_user_groups_ids} ) ne 'ARRAY' ) {

        my $user_groups = SPOPS::SQLInterface->db_select( {
                select => [ 'groups_id' ],
                from   => [ 'dicole_group_user' ],
                where  => 'user_id = ?',
                value  => [ $self->auth_user_id ],
                db     => CTX->datasource( CTX->lookup_system_datasource_name ),
                return => 'hash',
        } ) || [];

        my @ids = map { $_->{groups_id} } @$user_groups;

        $self->{auth_user_groups_ids} = \@ids;
    }


    return $self->{auth_user_groups_ids};
}

sub auth_user_groups {
    my ( $self, $new ) = @_;

    if ( defined $new ) {
        $self->{auth_user_groups} = $new;
    }
    elsif ( ref ( $self->{auth_user_groups} ) ne 'ARRAY' ) {
        $self->{auth_user_groups} = Dicole::Utils::SPOPS->fetch_objects(
            object_name => 'groups', ids => $self->auth_user_groups_ids
        );
    }

    return $self->{auth_user_groups};
}

sub auth_user_groups_by_id {
    my ( $self, $new ) = @_;

    if ( defined $new ) {
        $self->{auth_user_groups_by_id} = $new;
    }
    elsif ( ref( $self->{auth_user_groups_by_id} ) ne 'HASH' ) {

        my %by_id = map { $_->id => $_ } @{ $self->auth_user_groups };

        $self->{auth_user_groups_by_id} = \%by_id;
    }

    return $self->{auth_user_groups_by_id};
}

sub clear_auth_user_groups {
    my ( $self ) = @_;

    undef $self->{auth_user_groups_by_id};
    undef $self->{auth_user_groups};
    undef $self->{auth_user_groups_ids};
}

1;

