package OpenInteract2::Manage::Website::ReInstallPackage;

# $Id: ReInstallPackage.pm,v 1.4 2009-01-07 14:42:32 amv Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup;
use File::Spec;

$OpenInteract2::Manage::Website::ReInstallPackage::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'reinstall_package';
}

sub get_brief_description {
    return "This script runs check_package, export_package, remove_package,".
            "install_package, install_sql and register_tool. Afterwards".
            "removes the exported package. Must be run in packages directory. ";
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
    $self->_setup_context( { skip => 'activate spops' } );
}

sub run_task {
    my ( $self ) = @_;
    
    die "Doesn't seem like a package directory...\n" if !-f 'package.conf';
    my $zip;

    ## Do only the first package listed..
    $self->param('package', shift @{ $self->param('package') } );

#    my $check = OpenInteract2::Manage->new( 'check_package' );
    my $export = OpenInteract2::Manage->new( 'export_package' );
    my $remove = OpenInteract2::Manage->new( 'remove_package' );
    my $install = OpenInteract2::Manage->new( 'install_package' );
    my $sql = OpenInteract2::Manage->new( 'install_sql' );
    my $tool = OpenInteract2::Manage->new( 'register_tool' );

    foreach ( $remove, $install, $sql, $tool ) {
        $_->param_copy_from( $self );
    }

#    $check->execute;
#        $self->_add_status( $check->get_status );

    $export->execute;
        $self->_add_status( $export->get_status );

    $zip = `ls | grep '.zip'`;
    chomp $zip;
    die "no package file created :(" if !$zip;

    $remove->execute;
    system( 'rm -Rf ' . $self->param('website_dir') . '/pkg/' . $self->param('package') . "-*" );
        $self->_add_status( $remove->get_status );

    $install->param('package_file', "$zip");
    $install->execute;
    system( 'rm -Rf ' . $zip );
        $self->_add_status( $install->get_status );

    $sql->execute;
        $self->_add_status( $sql->get_status );
    
    $tool->execute;
        $self->_add_status( $tool->get_status );
    
    if ( $@ ) {
        $self->_add_status_head( { is_ok   => 'no',
                                   message => "Something failed: $@" });

        system( 'rm -Rf ' . $zip );

        oi_error $@;
    }
    $self->_add_status_head( { is_ok   => 'yes',
                               message => 'Package reinstall succesfull' } );
}



OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

