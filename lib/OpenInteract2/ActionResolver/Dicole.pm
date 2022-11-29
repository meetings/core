package OpenInteract2::ActionResolver::Dicole;

# $Id: Dicole.pm,v 1.22 2009-08-31 02:22:08 amv Exp $

use strict;
use base qw( OpenInteract2::ActionResolver Dicole::RuntimeLogger );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use URI;
use URI::URL;

$OpenInteract2::ActionResolver::Dicole::VERSION  = sprintf("%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/);

my ( $log );

sub get_name  { return 'dicole_actionresolver'; }

sub get_order { return -100000; } # _try_ to use this as primary resolver

sub resolve {
    my ( $self, $request, $url ) = @_;

    $log ||= get_logger(LOG_APP);

    $log->debug("Resolving '$url'...");
    
    Dicole::URL->validate_alias_caches;
    
    my $uri_path = URI->new($url)->path;

    my %added_override_params = ();

    if ( $request && ( $uri_path eq '/' or $uri_path eq '' ) ) {
        if (my $cookie_value = $request->cookie('override_path')) {
            my ($timestamp, $override_path) = $cookie_value =~ /^(\d+)(.*)$/;
            if ($timestamp >= time - 10) {
                my $full_url = URI::URL->new( $override_path );

                my %query = $full_url->query_form;
                for my $key ( keys %query ) {
                    $request->param( $key => $query{ $key } );
                    $added_override_params{ $key } = $query{ $key };
                }

                $url = $full_url->path;
            }
        }
        else {
            $url = '/login/';
        }
    }

    my $paths = Dicole::URL->get_path_array( $url );
    
    my $resolved = {};
    
    $log->debug("Looking up domain");

    my $domain = eval { CTX->lookup_action('domains_api')->e( get_current_domain => {} ) };

    if ( $domain ) {
        $log->debug("Got domain '" . $domain->domain_name . "'");
        $resolved->{domain} = $domain;
        $resolved->{domain_id} = $domain->id;
        $resolved->{domain_name} = $domain->domain_name;

        if ( $request && $request->server_name ne $domain->domain_name ) {
            my $partner = eval { CTX->lookup_action('meetings_api')->e( get_partner_for_domain_name => {
                domain_name => $request->server_name      
            } ) };

            if ( $partner ) {
                $resolved->{partner} = $partner;
                $resolved->{partner_id} = $partner->{id};
                $resolved->{partner_domain_alias} = $partner->{domain_alias};
            }
        }
    }
    else {
        $log->debug("No domain");
        $resolved->{domain_id} = 0;
    }

    eval {
        my @suspects = @$paths;
        
        my $s_alias = shift @suspects;
        my $s_action = shift @suspects;
        my $s_task = shift @suspects;
        my @s_additional = @suspects;
        
        unless ($s_alias) {
            local $" = "/";
            $log->error("No alias found from @$paths");
            die;
        }
        
        my $rh = Dicole::URL->alias_resolving_hash;
        my $alias = $rh->{ $resolved->{domain_id} }{ $s_alias };
        
        if ($alias) {
            $log->debug("Found alias " . $alias->action);
        } else {
            die;
        }
        
        if( $alias->action && $alias->task ) {
            $log->debug("Using alias action and task...");
            $resolved->{action} = CTX->lookup_action( $alias->action, { REQUEST_URL => $url } );
            $resolved->{task} = $alias->task;
            unshift @s_additional, $s_task if defined( $s_task );
            unshift @s_additional, $s_action if defined( $s_action );
        }
        elsif ( $alias->action ) {
            $log->debug("Using alias action...");
            $resolved->{action} = CTX->lookup_action( $alias->action, { REQUEST_URL => $url } );
            unshift @s_additional, $s_task if defined( $s_task );
            $s_task = $s_action;
            if ( $s_task =~ /^\d+$/ ) {
                unshift @s_additional, $s_task;
                undef $s_task;
            }
            $resolved->{task} = $s_task;
        }
        elsif ( $s_action ) {
            $log->debug("Using s_action...");
            $resolved->{action} = CTX->lookup_action( $s_action, { REQUEST_URL => $url } );
            # ^^ might die
            $log->debug("Resolved action to " . $resolved->{action}->name);
            if ( $s_task =~ /^\d+$/ ) {
                unshift @s_additional, $s_task;
                undef $s_task;
            }
            $resolved->{task} = $s_task;
        }
        else {
            if ( $alias->group_id ) {
                $resolved->{action} = CTX->lookup_action( 'groups', { REQUEST_URL => $url } );
                $resolved->{task} = 'starting_page';
            }
            elsif( $alias->user_id ) {
                $resolved->{action} = CTX->lookup_action( 'personalsummary', { REQUEST_URL => $url } );
                $resolved->{task} = 'summary';
            }
            else {
                $resolved->{action} = CTX->lookup_action( 'groups', { REQUEST_URL => $url } );
                $resolved->{task} = 'list';
            }
        }

        if ($resolved->{action}) {
            $log->debug("Resolved '$url' to action " . $resolved->{action}->name);
        } else {
            $log->error("Failed to resolve action");
            die;
        }

        my $tt = $resolved->{action}->param('target_type');
        if ( $tt eq 'group' ) {
            $resolved->{target} = $alias->group_id;
        }
        elsif ( $tt eq 'user' ) {
            $resolved->{target} = $alias->user_id;
        }
        else {
            $resolved->{target} = 0;
        }

        if ( $alias->additional ) {
            unshift @s_additional, @{ Dicole::Utils::JSON->decode( $alias->additional ) };
        }

        $resolved->{target_additional} = \@s_additional;
        $resolved->{url_version} = 2;
    };
    # try the old fashioned way if the new failed
    if ( $@ ) {
        $log->debug("Falling back to old method for resolving action: $@");

        my @suspects = @$paths;
        
        my $s_action = shift @suspects;
        my $s_task = shift @suspects;
        my $s_target = shift @suspects;
        my @s_additional = @suspects;
        
        # task can not be numerical, use default task instead
        if ( defined( $s_task ) && $s_task =~ /^\d+$/ ) {
            unshift @s_additional, $s_target;
            $s_target = $s_task;
            undef $s_task;
        }
        # target must be numerical, use no target otherwise
        elsif ( defined( $s_target ) &&  $s_target !~ /^\d+$/ ) {
            unshift @s_additional, $s_target;
            undef $s_target;
        }
        
        my $action = $s_action ?
            eval { CTX->lookup_action( $s_action, { REQUEST_URL => $url } ) }
            :
            CTX->lookup_action_not_found->clone;
        
        if ( $@ ) {
            $action = CTX->lookup_action_not_found->clone;
        }
        
        $resolved->{action} = $action;
        $resolved->{target} = $s_target;
        $resolved->{task} = $s_task;
        $resolved->{target_additional} = \@s_additional;
        $resolved->{url_version} = 1;
    }
    
    my $action = $resolved->{action};
    $action->task( $resolved->{task} );

    my $t = $action->task;
    $t =~ s/[\n\r]//;
    $t =~ s/sh\+ow/show/;

    if ( $action->name eq 'meetings_raw' && $t =~ /\.xml$/ ) {
        $t =~ s/\.xml//;
    }

    $action->task( $t );

    $log->debug("Action task is '$t'");
    
    $action->param( 'url_version', $resolved->{url_version} );
    
    $action->param( 'domain', $resolved->{domain} );
    $action->param( 'domain_id', $resolved->{domain_id} );
    $action->param( 'domain_name', $resolved->{domain_name} );

    $action->param( 'partner', $resolved->{partner} );
    $action->param( 'partner_id', $resolved->{partner_id} );
    $action->param( 'partner_domain_alias', $resolved->{partner_domain_alias} );

    $action->param( 'target_additional', $resolved->{target_additional} );
    $action->target_additional( $resolved->{target_additional} );
    
    my $tt = $action->param('target_type');
    $log->debug("Target type is '$tt'") if $tt;
    my $target = $resolved->{target} || 0;
    if ( $tt eq 'group' && ( ( ! $target ) || Dicole::Utils::Domain->domain_id_for_group_id( $target ) == $resolved->{domain_id} ) ) {
        $action->param( 'target_id', $target );
        $action->target_id( $target );
        $action->param( 'target_group_id', $target );
        $action->target_group_id( $target );

        if ( $target ) {
            my $group = CTX->lookup_object( 'groups' )->fetch( $target );
            $action->param( 'target_group', $group );
            $action->target_group( $group );
        }
    }
    elsif ( $tt eq 'user' ) {
        $action->param( 'target_id', $target );
        $action->target_id( $target );
        $action->param( 'target_user_id', $target );
        $action->target_user_id( $target );

        my $user = CTX->lookup_object( 'user' )->fetch( $target, { skip_security => 1 } );
        $action->param( 'target_user', $user );
        $action->target_user( $user );
    }
    else {
        $action->param( 'target_id', $target );
        $action->target_id( $target );
    }

    $self->assign_url_additional_to_params( $action );
    
    if ( $request ) {
        $log->debug("We have a request");

        my $url_params = {};

        if ( $request->can( 'apache' ) && $request->apache ) {
            my @params = $request->apache->param;
            my %query_params = map { $_ => $request->apache->param( $_ ) } @params;
            $url_params = \%query_params;
        }
        elsif ( $request->can('cgi') and $request->cgi ) {
            $url_params = scalar $request->cgi->Vars;
        }

        for my $key ( keys %added_override_params ) {
            $url_params->{ $key } = $added_override_params{ $key };
        }

        $action->param( 'url_params', $url_params );
        
        # TODO: url_anchor
        # $action->param( 'url_anchor', $anchor );
        
        $log->debug("Setting language");

        # set action language
        for my $lang ( $request->language ) {
            next if !$lang;
            $action->language( $lang );
            last;
        }

        $log->debug("Set language");

        # for compatibility
        $request->action_name( $action->name );
        $request->task_name( $action->task );
        
        # for compatifility (?)
        $self->assign_action_targets_to_request( $action, $request );
    
        # for OI2's needs ?
        $self->assign_additional_params_from_url(
            $request, @{ scalar( $action->param( 'target_additional' ) ) }
        );

        $log->debug("Finished setting up request");
    }

    return $action;

}

sub assign_url_additional_to_params {
    my ( $self, $action ) = @_;

    my @url_params = $action->_get_url_additional_names( 1 );
    if ( scalar @url_params ) {
        my @url_values = @{ scalar( $action->param('target_additional') ) };
        my $param_count = 0;
        foreach my $value ( @url_values ) {
            next unless ( $url_params[ $param_count ] );
            $action->param( $url_params[ $param_count ], $value );
            $param_count++;
        }
    }
}

sub assign_action_targets_to_request {
    my ( $self, $action, $request ) = @_;

    $request->target_id( $action->target_id );
    $request->target_user_id( $action->target_user_id );
    $request->target_group_id( $action->target_group_id );

    $request->target_user( $action->target_user );
    $request->target_group( $action->target_group );

    # compatibility
    $request->active_group( $action->target_id );
}

OpenInteract2::ActionResolver->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

=head1 NAME

OpenInteract2::ActionResolver::NameAndTask - Create an action from the URL's initial path and optional task

=head1 SYNOPSIS

 # create the 'news' action
 http://.../news/
 
 # create the 'news' action and assign 'display' task
 http://.../news/display/
 
 # same as above, but assigning '63783' as the first
 # 'param_url_additional()' request property
 http://.../news/display/63783/

=head1 DESCRIPTION

This is the most often used action resolver in OpenInteract2

=head1 OBJECT METHODS

B<resolve( $request, $url )>

Creates the action given the initial item in the URL's path. If the
action named there isn't available we just return undef and let
someone else handle it.

Additionally, if the URL's path contains additional items we use the
first of those for the action's task.

=head1 SEE ALSO

L<OpenInteract2::ActionResolver>

=head1 COPYRIGHT

Copyright (c) 2005 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>
