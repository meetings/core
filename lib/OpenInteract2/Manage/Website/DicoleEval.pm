package OpenInteract2::Manage::Website::DicoleEval;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Dicole::Security qw( :target );
use Data::Dumper;

sub get_name {
    return 'dicole_eval';
}

sub get_brief_description {
    return "Execute a custom code snippet in website context";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        code => {
       		description => 'String to eval',
        	is_required => 'yes',
    	},
    };
}

sub run_task {

    my ( $self ) = @_;

    my $code = $self->param( 'code' );

    eval "$code";
    
    if ( $@ ) {
        $self->_add_status( {
            is_ok   => 'no',
            message => "Error in eval: $@"
        } );
    }
}

sub d {
    print Data::Dumper::Dumper( @_ );
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
