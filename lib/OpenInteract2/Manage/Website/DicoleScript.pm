package OpenInteract2::Manage::Website::DicoleScript;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Dicole::Security qw( :target );
use Data::Dumper;

sub get_name {
    return 'dicole_script';
}

sub get_brief_description {
    return "Execute a custom Dicole script in website context";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        script => {
       		description => 'Script to execute',
        	is_required => 'yes',
    	},
        parameters => {
        	description => 'Parameters to script',
        	is_required => 'no',
		is_multivalued => 'yes',
    	},
    };
}

sub validate_param {
    my ( $self, $name, $value ) = @_;
    if ( $name eq 'script' ) {
        unless ( $value and -f $value ) {
            return "Must be a valid filename";
        }
    }
    return $self->SUPER::validate_param( $name, $value );
}

sub run_task {

    my ( $self ) = @_;

    my $script = $self->param( 'script' );

    unless ( -e $script ) {
        $self->_add_status( {
            is_ok   => 'no',
            message => "Script [$script] not found!"
        } );
    }
    else {
        unless ( my $return = do $script ) {
            die "couldn't parse $script: $@" if $@;
            die "couldn't do $script: $!" unless defined $return;
            die "couldn't run $script" unless $return;
        }
        else {
            my @params = ();
            if ( ref( $self->param( 'parameters' ) ) eq 'ARRAY' ) {
                @params = @{ $self->param( 'parameters' ) };
            }
            elsif ( defined $self->param( 'parameters' ) ) {
                push @params, $self->param( 'parameters' );
            }
            execute( $self, @params );
        }
    }
}

sub d {
    print Data::Dumper::Dumper( @_ );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
