package OpenInteract2::Manage::Website::ConnectDatabase;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );

sub get_name {
    return 'connect_database';
}

sub get_brief_description {
    return "Connect database";
}

sub _get_datasource_param {
    return {
        description => 'Datasource name. The default is "main"',
        is_required => 'no',
    };
}

sub _get_database_command {
    return {
        description => 'Command to pass for the database client',
        is_required => 'no',
    };
}

sub get_parameters {

    my ( $self ) = @_;
    return {
        datasource  => $self->_get_datasource_param,
        command     => $self->_get_database_command,
    };
}

sub setup_task {
    my ( $self ) = @_;
    $self->_setup_context( {
        skip => [
            'read spops config',
            'read action table',
            'read packages',
            'read repository',
        ]
    } );
}

sub run_task {

    my ( $self ) = @_;

    my $datasource = $self->param( 'datasource' ) || 'main';

    my $config = CTX->lookup_datasource_config( $datasource );

    if ( !$config->{type} ) {
        $self->_add_status( {
            is_ok   => 'no',
            message => "Couldn't find configuration for datasource $datasource!"
        } );
    }
    elsif ( $config->{type} eq 'DBI' && $config->{driver_name} eq 'mysql' ) {
        $self->_add_status( {
            is_ok   => 'yes',
            message => 'Opening database connection...'
        } );

        my ( $database, $host ) = split /:/, $config->{dsn};
        my $username = $config->{username};
        my $password = $config->{password};

        $host ||= 'localhost';

        if ( $host =~ s/^mysql_socket=// ) {
            $host = '--socket=' . $host;
        }
        else {
            $host = '--host=' . $host;
        }
        
        my $command = "mysql $host --password=$password "
            . "--user=$username --database=$database ";
        $command .= $self->param( 'command' );

        system( $command );
    }
    elsif ( $config->{type} eq 'DBI' && $config->{driver_name} eq 'SQLite' ) {
        $self->_add_status( {
            is_ok   => 'yes',
            message => 'Opening database connection...'
        } );

        my ( $database ) = $config->{dsn} =~ /dbname=(.*)/;
        my $sql = $self->param( 'command' );
        $sql =~ s/\-e // if $sql;

        my $command = "sqlite3 $database $sql";
        
        system( $command );
    }
    else {
        $self->_add_status( {
            is_ok   => 'no',
            message => 'Only MySQL & SQLite datasources are supported at the moment!'
        } );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
