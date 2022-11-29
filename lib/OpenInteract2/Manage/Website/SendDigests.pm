package OpenInteract2::Manage::Website::SendDigests;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

use MIME::Lite ();

sub get_name {
    return 'send_digests';
}

sub get_brief_description {
    return "Sends digests of group and personal actions by mail";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        mode => {
            description => 'What kind of mails to send: daily, weekly, monthly',
            is_required => 'yes',
        },
        only_user => {
            description => 'Send notifications only for user with specified id',
            is_required => 'no',
        },
    };
}

sub run_task {
    my ( $self ) = @_;

    my $smtp_host = OpenInteract2::Util->_get_smtp_host( {} );
    MIME::Lite->send( 'smtp', $smtp_host, Timeout => 10 );

    my $now = time;

    my $mode = $self->param( 'mode' );
    my %modes = ( daily => 1, weekly => 7, monthly => 30 );

    return unless grep { $_ eq $mode } ( keys %modes );

    my $digest_sources = CTX->lookup_object( 'digest_source' )->fetch_group( {
        order => 'ordering desc',
    }) || [];

    my $domains;
    if ( eval { CTX->lookup_action('dicole_domains') } ) {
        $domains = eval { CTX->lookup_object( 'dicole_domain' )->fetch_group({}) };
    }
    $domains ||= [ 0 ];
    
    for my $domain ( @$domains ) {
        next if Dicole::Utils::Domain->setting( $domain->id, 'disable_digests' );
        my $no_groups_json = Dicole::Utils::Domain->setting( $domain->id, 'disable_digests_for_groups' );
        my $no_groups = $no_groups_json ? eval { Dicole::Utils::JSON->decode( $no_groups_json ) } || [] : [];

        my $where = $domain ? 'dicole_domain_user.domain_id = ?' .
                ' AND sys_user.user_id = dicole_domain_user.user_id' : '1=1';
        my $value = $domain ? [ $domain->id ] : [];

        if ( my $uid = $self->param('only_user') ) {
            $where .= ' AND sys_user.user_id = ?';
            push @$value, $uid;
        }

        my $users = CTX->lookup_object( 'user' )->fetch_group( {
            from => $domain ? [ 'sys_user', 'dicole_domain_user' ] : [ 'sys_user' ],
            where => $where,
            value => $value,
        } ) || [];

        my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
            from => $domain ? [ 'dicole_groups', 'dicole_domain_group' ] : [ 'dicole_groups' ],
            where => $domain ? 'dicole_domain_group.domain_id = ?' .
                ' AND dicole_groups.groups_id = dicole_domain_group.group_id' : '1=1',
            value => $domain ? [ $domain->id ] : [],
        } ) || [];

        my %groups_by_id = map { $_->id => $_ } @$groups;
        delete $groups_by_id{ $_ } for @$no_groups;

        for my $user ( @$users ) {
            $self->notify_observers(
                progress => 'Processing ' . $user->login_name .
                    ' for ' . ( $domain ? $domain->domain_name : 'the whole system' ),
            );
            eval {
                CTX->{current_domain} = $domain;
                CTX->{current_domain_id} = $domain->id;
                CTX->lookup_action('send_mail_digest')->execute( {
                    now => $now,
                    mode => $mode,
                    user => $user,
                    domain => $domain,
                    digest_sources => $digest_sources,
                    groups_by_id => \%groups_by_id,
                } );
            };
            if ( my $error = $@ ) {
                $error = 'Error for uid ' . $user->id . ' @ ' .
                    ( $domain ? $domain->domain_name : 'localhost' ) .
                    ": '" . $error . "'";
                CTX->get_logger( LOG_APP )->error( $error );
                $self->notify_observers( progress => $error );
            }
        }
    }
}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
