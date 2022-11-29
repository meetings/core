package OpenInteract2::Manage::Website::BackupDatabase;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use DateTime;

sub get_name {
    return 'backup_database';
}

sub get_brief_description {
    return "Backup database datasource to a file";
}

sub _get_datasource_param {
    return {
        description => 'Datasource name. The default is "main"',
        is_required => 'no',
    };
}

sub _get_database_command {
    return {
        description => 'Command to pass for the database backup client',
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
    $self->_setup_context;
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
            message => 'Dumping database to a file...'
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
	my $date = DateTime->now->ymd;
	my $filename = "${database}-${date}.sqldump.gz";
        my $command = "mysqldump $host --password=$password --user=$username "
            . "--all -c --add-drop-table --quick";
        $command .= $self->param( 'command' ) . " $database | gzip -9 -c > $filename";
	chmod( 0600, $filename );
        system( $command );
    }
    else {
        $self->_add_status( {
            is_ok   => 'no',
            message => 'Only MySQL datasources are supported at the moment!'
        } );
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
