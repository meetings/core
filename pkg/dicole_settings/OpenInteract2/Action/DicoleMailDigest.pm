package OpenInteract2::Action::DicoleMailDigest;

# $Id: DicoleMailDigest.pm,v 1.21 2009-10-28 23:50:38 amv Exp $

use strict;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use DateTime::TimeZone;
use DateTime;
use MIME::Lite ();

use base qw( Dicole::Action );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.21 $ =~ /(\d+)\.(\d+)/);
my $log;

sub _send_digest {
    my ( $self ) = @_;
    
    $log ||= get_logger( LOG_APP );

    my %modes = ( daily => 1, weekly => 7, monthly => 30 );

    my $now = $self->param('now') || time;
    my $mode = $self->param('mode');
    my $user = $self->param('user');
    my $digest_sources = $self->param('digest_sources');
    my $domain = $self->param('domain');
    my $groups_by_id = $self->param('groups_by_id');

    my $port = $domain ?
        CTX->server_config->{domain_server_info}{ $domain->id }{server_port} || 443
        :
        CTX->server_config->{server_info}{server_port} || 443;
    my $protocol = 'http://';
    if ( $port == 443 ) {
        $port = undef;
        $protocol = 'https://';
    }
    elsif ( $port == 80 ) {
        $port = undef;
    }
    else {
        $port = ':' . $port;
    }
    my $host = $domain ? $protocol . $domain->domain_name . $port :
        CTX->server_config->{server_info}{server_url};

    my $notify_email = $domain ? Dicole::Utils::Mail->get_domain_notify_email( $domain->id ) : undef;

    my $um_tool = $domain ? 'domain_user_manager_' . $domain->id : 'user_manager';
    my $um_settings = Dicole::Settings->new_fetched_from_params(
        user_id => 0, group_id => 0, tool => $um_tool
    );

    undef $self->{language_handle};
    $self->language( $user->language );

    my $uid = $user->id;

    my $s = Dicole::Settings->new;
    $s->user( 1 );
    $s->user_id( $uid );
    $s->tool( 'settings_reminders' );
    $s->fetch_settings;

    # Personal stuff

    my $personal_mode = $s->setting( 0 );
    if ( $personal_mode && $personal_mode eq $mode ) {

        my $ls = $s->setting( '0_last_sent' );
        unless ( $ls ) {
            $ls = $now - ( $modes{ $mode } * 24 * 60 * 60 );
        }

        my @digests = ();
        for my $ds ( @$digest_sources ) {
            next if $ds->type ne 'user';
            eval {
                my $d = CTX->lookup_action( $ds->action )->execute( {
                    timezone => $user->timezone || 'UTC',
                    lang => $user->language,
                    user_id => $uid,
                    domain_id => $domain ? $domain->id : 0,
                    domain_host => $host,
                    start_time => $ls,
                    end_time => $now,
                    custom_init_params => {
                        target_type => 'user',
                        target_id => $uid,
                    },
                } );
                push @digests, $d if $d;
            };
            if ( $@ ) {
                get_logger(LOG_APP)->error( "Error executing " . $ds->action . ": " .$@ );
            }
        }

        my $sent = $self->_send_mail(
            \@digests, $user, undef,
            $um_settings, $domain->id, $host, $notify_email, $ls, $now
        );

        $s->setting( '0_last_sent', $now ) if $sent;
    }


    # Group stuff

    my @gids = ();
    if ( $domain ) {
        my $dgroups = CTX->lookup_object( 'dicole_domain_group' )->fetch_group( {
            from => [ 'dicole_domain_group', 'dicole_group_user' ],
            where => 'dicole_domain_group.domain_id = ?' .
                ' AND dicole_domain_group.group_id = ' .
                ' dicole_group_user.groups_id' .
                ' AND dicole_group_user.user_id = ?',
            value => [ $domain->id, $uid ],
        } ) || [];
        @gids = map { $_->group_id } @$dgroups;
    }
    else {
        my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
            from => ['dicole_groups', 'dicole_group_user' ],
            where => 'dicole_group_user.user_id = ? AND ' .
                'dicole_groups.groups_id = dicole_group_user.groups_id',
            value => [ $uid ],
        } ) || [];
        @gids = map { $_->id } @$groups;
    }

    for my $gid ( @gids ) {
        my $group_mode = $s->setting( $gid );
        next unless $group_mode;
        next unless $group_mode eq $mode;
        next unless $groups_by_id->{ $gid };

        my $ls = $s->setting( $gid . '_last_sent' );
        unless ( $ls ) {
            $ls = $now - ( $modes{ $mode } * 24 * 60 * 60 );
        }

        my @digests = ();
        for my $ds ( @$digest_sources ) {
            next if $ds->{type} ne 'group';
            eval {
                my $d = CTX->lookup_action( $ds->action )->execute( {
                    timezone => $user->timezone || 'UTC',
                    lang => $user->language,
                    user_id => $uid,
                    group_id => $gid,
                    domain_id => $domain ? $domain->id : 0,
                    domain_host => $host,
                    start_time => $ls,
                    end_time => $now,
                    custom_init_params => {
                        target_type => 'group',
                        target_id => $gid,
                    },
                } );
                push @digests, $d if $d;
            };
            if ( $@ ) {
                get_logger(LOG_APP)->error( "Error executing " . $ds->action . ": " .$@ );
            }
        }

        $self->_send_mail(
            \@digests, $user, $groups_by_id->{ $gid },
            $um_settings, $domain->id, $host, $notify_email, $ls, $now
        );

        $s->setting( $gid . '_last_sent', $now );
    }
}

sub _send_mail {
    my ( $self, $digests, $user, $group, $um_settings, $did, $dn, $from, $ls, $now ) = @_;

    return if ! scalar ( @$digests );

    my $url = $dn;
    $url =~ s/^https?\:\/\///;

    my $subject = $group ?
        $self->_msg( 'Digest for [_1] ([_2])', $group->name, $url ) :
        $self->_msg( 'Digest for personal feed reader ([_1])', $url );

    my $settings_addr = $dn . Dicole::URL->create_from_parts(
        action => 'global_settings',
        task => 'reminders',
        target => $group ? $group->id : 0,
        additional => [ $user->id ],
    );

    my $last_date = Dicole::DateTime->long_datetime_format(
        $ls, $user->timezone, $self->language
    );
    my $current_date = Dicole::DateTime->long_datetime_format(
        $now, $user->timezone, $user->language
    );

    my $group_name = $group ? $group->name : undef;
    my $group_addr = $group ? $dn . Dicole::URL->create_from_parts(
        action => 'groups',
        task => 'starting_page',
        target => $group->id,
    ) : undef;
    my $personal_addr = $group ? $dn . Dicole::URL->create_from_parts(
        action => 'personal_feed_reader',
        task => 'feeds',
        target => $user->id,
    ) : undef;

    my $text_params = {
        tool_digests => $digests,
        group_name => $group_name,
        last_date => $last_date,
        current_date => $current_date,
        settings_addr => $settings_addr,
    };
    my $text_template = $um_settings->setting('custom_text_mail_digest_template') ||
        'dicole_settings::dicole_text_mail_digest';
    $text_template .= $user->language eq 'en' ? '' : '_' . $user->language;
    my $text = $self->generate_content( $text_params, { name => $text_template } );

    my $html_params = {
        tool_digests => $digests,
        group_name => $group_name,
        group_addr => $group_addr,
        personal_addr => $personal_addr,
        last_date => $last_date,
        current_date => $current_date,
        settings_addr => $settings_addr,
    };
    my $html_template = $um_settings->setting('custom_html_mail_digest_template') ||
        'dicole_settings::dicole_html_mail_digest';
    $html_template .= $user->language eq 'en' ? '' : '_' . $user->language;
    my $html = $self->generate_content( $html_params, { name => $html_template } );

    Dicole::Utils::Mail->send_to_user(
        text => $text,
        html => $html,
        user => $user,
        subject => $subject,
        domain_id => $did,
        $from ? ( from => $from ) : (),
    );
}

1;


__END__

