package OpenInteract2::Manage::Website::RegisterExternal;

use strict;
use base qw( OpenInteract2::Manage::Website Dicole::Registerer );
use OpenInteract2::Context   qw( CTX );
use File::Spec;

sub get_name {
    return 'register_external';
}

sub get_brief_description {
    return "Registers packages external tool data into websites database";
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

        die "Couldn't find package $package_name: $!" if !$package;

        my $toolini = File::Spec->catfile(
            CTX->repository->full_config_dir, $package_name, 'tool.ini'
        );

        next if !-f $toolini;

        my $config = OpenInteract2::Config::Ini->new({ filename => $toolini });

    # Add specific parameter hash to external parameters
    while ( my ( $key, $value ) = each %{ $config->{external} } ) {
        if ( $value->{parameters} && exists $config->{parameters} ) {
            $value->{parameters} = $config->{parameters}
                ->{ $value->{parameters} };
        }
    }

        $self->register(
            object_name => 'externalsource',
            items => $config->{external},
            defaults => {
                name => 'none',
                url => 'http://www.dicole.com/',
                navid => 'none',
                request => 'get',
                users_ids => '',
                groups_ids => '',
                parameters => '',
                external_type => 1,
                custom_fields => '',
                custom_obj_id => '',
                custom_object => '',
                custom_where => '',
                secure => '',
                modified => 0,
            },
            id_fields => [ 'name' ],
            csv_fields => {
                groups_ids => 'normal',
                users_ids => 'normal',
                secure => 'normal',
                custom_fields => 'normal',
                parameters => 'binary'
            },
            package => $package_name,
        );
    }

}


OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
