package OpenInteract2::Action::DicoleEmailsCommon;

use strict;
use warnings;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Digest::SHA              qw( sha256_base64 );
use JSON                     qw();

my $json = JSON->new->canonical(1);

our %dispatch = (
    m1 => 'meetings_email_dispatch',
    m2 => 'meetings_email_scheduling_answer',
    m3 => 'meetings_email_agenda_reply',
    m4 => 'meetings_email_action_points_reply',
);

# by default user id can be found as the second parameter
# (index = 1) but for some aliases the index is different
# index of should -1 means that general key is used instead
our %user_id_index = (
    m1 => 2,
);

our %rdispatch = reverse %dispatch;

sub _dispatch { $dispatch{$_[1]} }
sub _rdispatch { $rdispatch{$_[1]} }
sub _user_id_index{ $user_id_index{$_[1]} || 0 }

# legacy but used for legacy checks in dispatch
sub _get_hash {
    my ($self, $params, $legacy ) = @_;

    return lc( substr( $self->_get_full_hash( $params, $legacy ), 0, $legacy ? 10 : 12 ) );
}

# legacy but used for legacy checks in dispatch
sub _get_full_hash {
    my ( $self, $params, $legacy ) = @_;

    my $data = $json->encode($params);

    my $sha = sha256_base64( join "-", $data, CTX->server_config->{dicole}{email_secret} );

    return $sha if $legacy;

    $sha =~ s/\//_/g;

    return $sha;
}

sub _get_user_hash {
    my ( $self, $alias, $params, $user ) = @_;

    if ( ! $user ) {
        my $user_id_index = $self->_user_id_index( $alias );
        my $user_id = ( $user_id_index > -1 ) ? $params->[ $user_id_index ] : 0;
        $user = $user_id ? eval { Dicole::Utils::User->ensure_object( $user_id ) } : undef;
    }

    my $data = $json->encode($params);

    my $secret = $user ?
        Dicole::Utils::User->authorization_key_invalidation_secret( $user ) :
        CTX->server_config->{dicole}{email_secret};

    my $sha = sha256_base64( join "-", $data, $secret );

    $sha =~ s/\//_/g;
    return lc( substr( $sha, 0, 12 ) );
}

sub _fetch_shortened_params {
    my ( $self, $local ) = @_;

    my $array = CTX->lookup_object('emails_dispatch')->fetch_group({
        where => 'dispatch_key = ?',
        value => [lc $local]
    }) || [];

    return @$array;
}

sub _store_shortened_params {
    my ( $self, $action, $params ) = @_;

    my $data = {
        action => $action,
        params => $params
    };
    my $json_data = $json->encode($data);
    my $hash = $self->_get_full_hash($data);

    my $dispatch  = CTX->lookup_object('emails_dispatch')->fetch_group({
        where => 'data_hash = ?',
        value => [$hash]
    }) || [];

    return $dispatch->[0]{dispatch_key} if $dispatch->[0];

    my $key = $self->_generate_new_key;

    my $new_dispatch = CTX->lookup_object('emails_dispatch')->new({
        dispatch_key => $key,
        data_hash    => $hash,
        data         => $json_data
    });

    $new_dispatch->save;

    return $key;
}

sub _generate_new_key {
    my ($self, $length) = @_;

    $length ||= 6;

    my @chars = split //, "abcefghjkmnpqrtx346789";
    my $key;

    while (1) {
        $key = join "", map { $chars[rand @chars] } 1 .. $length;

        my $existing = CTX->lookup_object('emails_dispatch')->fetch_group({
            where => 'dispatch_key = ?',
            value => [ $key ]
        });

        last unless @$existing;
    }

    return $key;
}

1;
