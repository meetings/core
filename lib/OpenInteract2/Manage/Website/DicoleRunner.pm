package OpenInteract2::Manage::Website::DicoleRunner;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

sub get_name {
    return 'dicole_runner';
}

sub get_brief_description {
    return "Execute code with certain intervals or if SIGALRM is signalled.";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        code => {
            description => 'String to eval',
            is_required => 'yes',
        },
        interval => {
            description => 'automatically execute the code again if the execution is not running and given number of milliseconds has passed since last code execution start. defaults to 60000.',
            is_required => 'no',
        },
        limit => {
            description => 'exit after given number of runs. runs forever unless speficied.',
            is_required => 'no',
        },
    };
}

my $alarm = 0;
$SIG{ALRM} = sub { $alarm = 1; };

sub run_task {
    my ( $self ) = @_;

    my $code = $self->param( 'code' );
    my $limit = $self->param( 'limit' );
    my $interval = $self->param( 'interval' ) || 60000;
    my $second_interval = $interval / 1000;

    my $count = 0;
    my $previous = 0;
    my $usleeptime = 0;
    while ( 1 ) {
        $previous = Time::HiRes::time();

        eval "$code";
        if ( $@ ) {
            get_logger(LOG_APP)->error( "Error in eval: $@ (while running $code)" );
        }

        $count++;
        last if $limit && $count > $limit - 1;

        $usleeptime = ( $previous + $second_interval - Time::HiRes::time() ) * 1000000;
        unless ( $alarm || $usleeptime <= 0 ) {
            Time::HiRes::ualarm( $usleeptime );
            sleep(1) while ! $alarm;
        }
        $alarm = 0;
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
