package OpenInteract2::SessionManager::Dicole;

use warnings;
use strict;

use base qw(OpenInteract2::SessionManager);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw(CTX DEPLOY_URL);
use Storable                 qw(freeze thaw);
use Digest::MD5 ();
use Dicole::URL ();
use Dicole::Utils::Session;

use constant FETCH_TRIES => 5;

sub create {
    my ($class, $session_id) = @_;

    my $session_payload;

    if ($session_id) {
        my $session = $class->_fetch_session($session_id);

        if ( $session && $session->payload =~ /\$VAR1/ ) {
            $session_payload = eval "my " . $session->payload;
            $session_payload->{session_object} = $session;
        }
        elsif ( $session ) {
            eval {
                $Storable::canonical = 1;
                $session_payload = thaw $session->{payload};
                $session_payload->{session_object} = $session;
            };
        }
    }

    $session_payload ||= $class->_create_session_payload;

    return $session_payload;
}

sub _fetch_session {
    my ($class, $session_id) = @_;

    return unless $session_id;

    get_logger(LOG_SESSION)->info("Fetching session '$session_id'");

    for (1 .. FETCH_TRIES) {
        my $sessions = CTX->lookup_object('sessions')->fetch_group({
            where => 'uid = ?',
            value => [ $session_id ]
        });

        my $found = shift @$sessions;

        $_->remove for @$sessions;

        return $found if $found;
    }

    return;
}

sub _create_session_payload {
    my ($class, $session_id) = @_;

    return {
        is_new     => 1,
        session_id => ($session_id || $class->_generate_id),
        suid       => $class->_generate_id
    };
}

sub _generate_id { 
    substr Digest::MD5::md5_hex(Digest::MD5::md5_hex(time . {} . rand() . $$)), 0, 32 
}

sub save {
    my ($class, $session_payload) = @_;

    return 1 unless ref $session_payload;
    return 1 unless $session_payload->{user_id} || $session_payload->{_oi_cache}{user};

    my $is_new = delete $session_payload->{is_new};

    my $session_id = $session_payload->{session_id} || '';
    my $session = delete $session_payload->{session_object};

    $session ||= $class->_fetch_session($session_id) unless $is_new;
    $session = $class->_create_session if $is_new || ! $session;

    $session_payload->{session_id} = $session->{uid} if $session_id ne $session->{uid};

    my $frozen_payload = Data::Dumper->new([$session_payload])->Indent(0)->Dump;

    if (CTX->request->{__logged_in_with_dic}) {
        $session_payload->{suid} ||= $class->_generate_id;
    }

    if ( ( $frozen_payload || '' ) ne ( $session->payload || '' ) ) {
        $session->timestamp( time );
        $session->payload( $frozen_payload );
        $session->save;
        get_logger(LOG_SESSION)->info( "Saved session payload: $session->{uid}" );
    }
    elsif ( time > $session->timestamp + 24*60*60 ) {
        my $latest_session = $class->_fetch_session($session_id);
        if ( $latest_session->timestamp == $session->timestamp ) {
            $session->timestamp( time );
            $session->save;
            get_logger(LOG_SESSION)->info( "Updated session timestamp: $session->{uid}" );
        }
    }
    else {
        get_logger(LOG_SESSION)->info( "Skipped saving session: $session->{uid}" );
    }

    my $expiration = $class->_get_expiration( $session );

    if ( $session_id ne $session->{uid} ) {
        $class->_create_session_cookie(
            uid        => $session->{uid},
            expiration => $expiration
        );

        $class->_create_secure_session_cookie_if_connection_is_secure(
            suid       => $session_payload->{suid},
            expiration => $expiration
        );
    } elsif (CTX->request->{__logged_in_with_dic}) {
        $class->_create_secure_session_cookie_if_connection_is_secure(
            suid       => $session_payload->{suid},
            expiration => $expiration
        );
    }

}

sub _create_session_cookie {
    my ($class, %p) = @_;

    OpenInteract2::Cookie->create({
        name    => Dicole::Utils::Session->cookie_name,
        value   => $p{uid},
        path    => DEPLOY_URL,
        expires => $p{expiration},
        HEADER  => 'yes'
    });
}

sub _create_secure_session_cookie_if_connection_is_secure {
    my ($class, %p) = @_;

    if (Dicole::URL->get_server_port == 443) {
        OpenInteract2::Cookie->create({
            name     => Dicole::Utils::Session->secure_cookie_name,
            value    => $p{suid},
            path     => DEPLOY_URL,
            expires  => $p{expiration},
            secure   => 1,
            httponly => 1,
            HEADER   => 'yes'
        });
    }
}

sub _create_session {
    my ($class, $session_id) = @_;

    $session_id ||= $class->_generate_id;

    get_logger->info("Creating session '$session_id'");

    return CTX->lookup_object('sessions')->new({ uid => $session_id });
}

sub delete_session {
    my ($class, $session_data) = @_;

    get_logger(LOG_SESSION)->info("Deleting session '$session_data->{session_id}'");

    my $session = $class->_fetch_session($session_data->{session_id});

    return unless $session;

    get_logger(LOG_SESSION)->info("Found session to delete");

    $session->remove;

    delete $session_data->{$_} for keys %$session_data;
}

sub _validate_config {
    my ($class, $session_config) = @_;
}

1;

