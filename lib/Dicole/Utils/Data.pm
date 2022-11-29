package Dicole::Utils::Data;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use MIME::Base64;
use Digest::SHA;
use Storable;

sub signature {
    return signature_base64( @_ );
}

sub signature_base64url {
    my ( $class, $data, $seed ) = @_;

    my $signature = $class->signature_base64( $data, $seed );
    $signature =~ s/\+/\-/g;
    $signature =~ s/\//\_/g;

    return $signature;
}

sub signature_base64 {
    my ( $class, $data, $seed ) = @_;

    my $payload = [ $data, $seed || () ];

    return Digest::SHA::sha1_base64( Dicole::Utils::JSON->encode_canonical( $payload ) );
}

sub signature_hex {
    my ( $class, $data, $seed ) = @_;

    my $payload = [ $data, $seed || () ];

    return Digest::SHA::sha1_hex( Dicole::Utils::JSON->encode_canonical( $payload ) );
}

sub single_line_base64_json {
    my ( $class, $data ) = @_;

    my $json = Dicole::Utils::JSON->encode( $data );
    return MIME::Base64::encode_base64( $json, '' );
}

sub merge_notes_hashes_three_way {
    my ( $class, $new_data, $db_data, $original_data, $second_level ) = @_;

    my $merged = {};
    my $merged_keys = {}
    ;
    for my $key ( keys %$new_data, keys %$db_data ) {
        next $merged_keys->{ $key }++;

        my $value = $new_data->{ $key };

        my $new_value = $new_data->{ $key } // '';
        my $db_value = $db_data->{ $key } // '';
        my $original_value = $original_data->{ $key } // '';

        if ( $db_value ne $new_value ) {
            if ( $original_value eq $new_value ) {
                $value = $db_data->{ $key };
            }
            elsif ( ! $second_level && $key =~ /^\d+$/ && ref( $db_value ) && ref( $new_value ) ) {
                $value = $class->merge_notes_hashes_three_way( $new_value || {}, $db_value || {}, $original_value || {}, 'second_level' );
            }
        }

        if ( defined $value ) {
            $merged->{$key} = $value;
        }
    }

    return $merged;
}

sub _read_notes {
    my ($self, $object, $opt ) = @_;

    if ( ! $object ) {
        use Carp;
        eval { Carp::confess; };
        get_logger(LOG_APP)->error($@);
        die "Could not read notes from an unexisting object";
    }

    $opt ||= {};
    my $note_field = $opt->{note_field} || 'notes';

    my $notes = eval { Dicole::Utils::JSON->decode( $object->get( $note_field ) || '{}' ) };

    die "Could not parse nonempty notes. Refusing to set. Info: $@ -- " . Data::Dumper::Dumper( [ $object, $opt ] ) unless $notes;

    return $notes;
}

sub _write_notes {
    my ($self, $object, $notes, $opt) = @_;

    $opt ||= {};
    my $note_field = $opt->{note_field} || 'notes';

    $object->set( $note_field, Dicole::Utils::JSON->encode($notes) );

    $object->save unless $opt->{skip_save};
}


sub get_note {
    my ($self, $note, $object, $opt) = @_;

    return $self->_read_notes( $object, $opt )->{ $note };
}

sub set_note {
    my ($self, $note, $new_value, $object, $opt) = @_;

    my $notes = $self->_read_notes( $object, $opt );

    my $old_value = $notes->{$note};

    if ( defined( $new_value ) ) {
        $notes->{$note} = $new_value;
    }
    else {
        delete $notes->{$note};
    }

    $self->_write_notes( $object, $notes, $opt );

    return $old_value;
}

sub get_notes {
    my ($self, $object, $opt) = @_;

    return $self->_read_notes( $object, $opt );
}

sub set_notes {
    my ($self, $values, $object, $opt) = @_;

    my $notes = $self->_read_notes( $object, $opt );

    for my $note ( keys %$values ) {
        my $new_value = $values->{$note};
        if ( defined( $new_value ) ) {
            $notes->{$note} = $new_value;
        }
        else {
            delete $notes->{$note};
        }
    }

    $self->_write_notes( $object, $notes, $opt );

    return $notes;
}

1;
