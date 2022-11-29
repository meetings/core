package OpenInteract2::Manage::Website::InstallDicolePackage;

# $Id: InstallDicolePackage.pm,v 1.9 2009-01-07 14:42:32 amv Exp $

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::Setup;
use File::Spec;
use Cwd qw( cwd );

$OpenInteract2::Manage::Website::InstallDicolePackage::VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub get_name {
    return 'install_dicole_package';
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
        install_sql => {
            description => 'Wether to install packages sql',
            is_required => 'no',
        },
        show_status => {
            description => 'Wether to show status messages',
            is_required => 'no',
        },
    };
}

sub setup_task {
    my ( $self ) = @_;
    $self->_setup_context( { skip => 'activate spops' } );
}

sub run_task {
    my ( $self ) = @_;

    my $package_param = $self->param('package');
    my @package_names = ( ref $package_param eq 'ARRAY' )
            ? @{ $package_param } : ( $package_param );

    my $src_root = cwd();


    # Check that given parameters are valid and remove those that aren't

    my @do_packages = ();
    my %package_dir = ();
    for my $package_name ( @package_names ) {
        my $dir = File::Spec->catdir( $src_root, 'pkg', $package_name );
        if ( !-d $dir ) {
            $self->notify_observers( progress => "Skipping: $package_name (no such directory)" );
        }
        elsif ( !-f File::Spec->catfile( $dir, 'package.ini' ) ) {
            $self->notify_observers( progress => "Skipping: $package_name (doesn't seem like a package)" );
        }
        else {
            push @do_packages, $package_name;
            $package_dir{ $package_name } = $dir;
        }
    }

    my %dirty_packages = ();
    my %package_zip = ();

    # Export all the packages

    for my $package_name ( @do_packages ) {
        next if $dirty_packages{ $package_name };
        chdir( $package_dir{ $package_name} );
        system( "rm -Rf $package_name-" . '*.zip' );
        
        my $manage = OpenInteract2::Manage->new( 'export_package' );

        $manage->execute;
        
        $self->_add_status( $manage->get_status ) if $self->param('show_status') ||
            [$manage->get_status]->[0]{is_ok} eq 'no';
        
        if ( [$manage->get_status]->[0]{is_ok} eq 'yes' ) {
            $package_zip{ $package_name } = [$manage->get_status]->[0]{filename};
            $self->notify_observers( progress => "Package exported: $package_name" );
        }
        else {
            $dirty_packages{ $package_name }++;
            $self->notify_observers( progress => "Package export failed: $package_name" );
        }
    }

    chdir( $src_root );

    # Remove old packages from the website. Also remove the files
    # since we probably insert the same version.

    for my $package_name ( @do_packages ) {
        next if $dirty_packages{ $package_name };
        next if ! eval { CTX->repository->fetch_package( $package_name ) };
         
        my $manage = OpenInteract2::Manage->new( 'remove_package' );

        $manage->param('website_dir', $self->param('website_dir') );
        $manage->param('package', $package_name );
        $manage->execute;

        $self->_add_status( $manage->get_status ) if $self->param('show_status') ||
            [$manage->get_status]->[0]{is_ok} eq 'no';

        system( 'rm -Rf ' . $self->param('website_dir') . '/pkg/' . $package_name . "-*" );
        system( 'rm -Rf ' . $self->param('website_dir') . '/conf/' . $package_name . "/" );

        $self->notify_observers( progress => "Old package removed: $package_name" );
    }

    # Install exported packages
    
    for my $package_name ( @do_packages ) {
        next if $dirty_packages{ $package_name };
       
        my $manage = OpenInteract2::Manage->new( 'install_package' );

        $manage->param('website_dir', $self->param('website_dir') );
        $manage->param('package_file', $package_zip{ $package_name } );
        $manage->execute;

        $self->_add_status( $manage->get_status ) if $self->param('show_status') ||
            [$manage->get_status]->[0]{is_ok} eq 'no';
        
        if ( [$manage->get_status]->[0]{is_ok} eq 'yes' ) {
            $self->notify_observers( progress => "Package installed to website: $package_name" );
        }
        else {
            $dirty_packages{ $package_name }++;
            $self->notify_observers( progress => "Package install failed: $package_name" );
        }

        system( 'rm -Rf ' . $package_zip{ $package_name } );
    }

    # Install sql for installed packages if requested

    if ( $self->param('install_sql') ) {
        for my $package_name ( @do_packages ) {
            next if $dirty_packages{ $package_name };
       
            my $manage = OpenInteract2::Manage->new( 'install_sql' );

            $manage->param('website_dir', $self->param('website_dir') );
            $manage->param('package', $package_name );
            $manage->execute;

            $self->_add_status( $manage->get_status ) if $self->param('show_status') ||
                [$manage->get_status]->[0]{is_ok} eq 'no';

            $self->notify_observers( progress => "Sql installed for package: $package_name" );
        }
   }

    # Reinitiate context since new stuff might be available
    OpenInteract2::Context::_initialize_singleton();
    $self->_setup_context();

    # Register tools for packages

    for my $package_name ( @do_packages ) {
        next if $dirty_packages{ $package_name };
       
        my $manage = OpenInteract2::Manage->new( 'register_tool' );

        $manage->param('website_dir', $self->param('website_dir') );
        $manage->param('package', $package_name );

        eval { $manage->execute; };

        if ( my $error = $@ ) {
            $self->notify_observers( progress => "Could not register tool for: $package_name ! $error" );
        }
        else {
            $self->_add_status( $manage->get_status ) if $self->param('show_status') ||
                [$manage->get_status]->[0]{is_ok} eq 'no';

            $self->notify_observers( progress => "Tools registered for package: $package_name" );
        }
    }

}



OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;

__END__

