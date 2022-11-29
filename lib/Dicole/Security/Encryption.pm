package Dicole::Security::Encryption;

use strict;
use Crypt::Rijndael;
use Crypt::CBC;
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Security::Key;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

my ( $log );

=pod

=head1 NAME

Encrypt and decrypt data

=head1 SYNOPSIS

 use Dicole::Security::Encryption;
 my $enc = Dicole::Security::Encryption->new;
 $enc->use_dynamic( 1 );
 my $data = 'sdfjgksajdgsd';
 my $crypted_data = $enc->encrypt( $data );
 my $decrypted_data = $enc->decrypt( $crypted_data );

=head1 DESCRIPTION

Encrypt and decrypt data with L<Crypt::Rijndael>. Uses the AES/Rijndael
algorithm with a 256-bit key. Supports both dynamic encryption keys
(generated upon each server startup with L<Dicole::Security::Key>)
and keys specified in the I<server.ini> configuration file.

To specify a key in I<server.ini>, insert the following section into your
configuration:

 [encryption]
 key = f43aa54bc454160ccad7371daddc001a
 disable_dynamic = 0

You should enter a random key which length is 32 bytes. If I<disable_dynamic>
is true, this key will always be used instead of the dynamically generated
(good for running under CGI).

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 ACCESSORS

=head2 use_dynamic( [BOOLEAN] )

Sets/gets the use dynamic bit. If this set on, our object will use a dynamically
generated key.

=cut

Dicole::Security::Encryption->mk_accessors(
    qw( use_dynamic )
);

=pod

=head2 key( [STRING] )

Sets/gets the 256-bit key. Both I<encrypt()> and I<decrypt()> use this
accessor to retrieve the key.

If no key is specified, the key will be read from the server configuration.

If the I<use_dynamic()> accessor is true, the dynamic key will be used instead.

If server configuration specifies I<disable_dynamic>, the key from the
configuration will always be used instead of the dynamically generated.

Returns the 256-bit (32-bytes) key.

=cut

sub key {
    my ( $self, $key ) = @_;
    $log ||= get_logger( LOG_SECURITY );
    if ( $key ) {
        $self->{key} = $key;
    }
    unless ( defined $self->{key} ) {
        $self->{key} = CTX->server_config->{encryption}{key};
        if ( !$self->{key} && CTX->server_config->{encryption}{disable_dynamic} ) {
            $log->warn( "No encryption key field configured; please set ",
                     "server configuration key 'encryption.key'" );
        }
        if ( $self->use_dynamic || !$self->{key} ) {
            unless ( CTX->server_config->{encryption}{disable_dynamic} ) {
                $self->{key} = $self->get_dynamic_key;
            }
        }
    }
    return $self->{key};
}

=pod

=head1 METHODS

=head2 encrypt( STRING )

Accepts a string as a parameter which will be encrypted with
the AES algorithm and signed with a 256-bit key.

Returns the encrypted data.

=cut

sub encrypt {
    my ( $self, $data ) = @_;
    my @encrypted_data = undef;
    # encrypt data in 1024-byte chunks
    my @chunks = unpack "a1024" x ( length( $data ) / 1024 ) . "a*", $data;
    foreach my $chunk ( @chunks ) {
        last unless $chunk;
        my $cipher = Crypt::Rijndael->new(
            $self->key, Crypt::Rijndael::MODE_CBC
        );
        push @encrypted_data, $cipher->encrypt(
            Crypt::CBC::_space_padding( $chunk, 16, 'e' )
        );
    }
    return join "\0\0", @encrypted_data;
}

=pod

=head2 decrypt( DATA )

Accepts the encrypted data as a parameter and encrypts it with
the 256-bit key.

Returns the decrypted string.

=cut

sub decrypt {
    my ( $self, $data ) = @_;
    my $decrypted_data = undef;
    foreach my $chunk ( split /\0\0/, $data ) {
        next unless $chunk;
        my $cipher = Crypt::Rijndael->new(
            $self->key, Crypt::Rijndael::MODE_CBC
        );
        my $decrypted = $cipher->decrypt( $chunk );
        $decrypted = Crypt::CBC::_space_padding( $decrypted, 16, 'd' );
        $decrypted_data .= $decrypted;
    }
    return $decrypted_data;
}

=pod

=head2 get_dynamic_key()

Returns the dynamically generated key.

=cut

sub get_dynamic_key {
    my ( $self ) = @_;
    return CTX->lookup_class('security_key')->KEY;
}

1;
