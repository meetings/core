package OpenInteract2::Manage::Website::UnRegisterTool;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use File::Spec;
use Data::Dumper;

sub get_name {
    return 'unregister_tool';
}

sub get_brief_description {
    return "Removes packages tool data from websites database";
}

sub get_parameters {

    my ( $self ) = @_;
    return {
        website_dir => $self->_get_website_dir_param,
        package     => $self->_get_package_param,
    };
}
sub setup_task {

    my ( $self ) = @_;
    $self->_setup_context();
}

sub run_task {

    my ( $self ) = @_;

    my $repository = CTX->repository;

    foreach my $package_name ( @{ $self->param( 'package' ) } ) {

        my $package = $repository->fetch_package( $package_name );
        
        $self->_unregisterer( 'tool', $package_name, 'toolid' );
        $self->_unregisterer( 'navigation_item', $package_name, 'navid' );
    }
    
}

sub _unregisterer {
    my ($self, $object, $package, $id) = @_;
    
    my $itemclass = CTX->lookup_object( $object );

    my $items = $itemclass->fetch_group(
        { where => 'package = ?', value => [ $package ] }
    );
    
    foreach my $item ( @$items ) {
    
        my $navid = $item->{$id};
        
        $item->remove;

        print "Unregistered: $object $navid..\n";
    }
}
    


OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
