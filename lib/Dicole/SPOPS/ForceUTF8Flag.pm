package Dicole::SPOPS::ForceUTF8Flag;

use strict;
use warnings;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Encode                   qw();
use Dicole::Utils::Text;
use Encode;

sub ruleset_factory {
    my ($class, $rs_table) = @_;

    #push @{ $rs_table->{pre_save_action}   }, \&turn_off_utf8_flag;
    #push @{ $rs_table->{post_save_action}  }, \&turn_on_utf8_flag;
    #push @{ $rs_table->{post_fetch_action} }, \&force_utf8_flag;

    __PACKAGE__
}

sub turn_off_utf8_flag {
    my $self = shift;

    my @fields = @{ $self->field_list };

    for (map $self->{$_}, @fields) {
        get_logger(LOG_APP)->error("pre_save: $_, utf8 flag is " . (Encode::is_utf8($_) ? "on" : "off"));
    }

    Encode::_utf8_off( $self->{$_} ) for @fields;

    1
}

sub turn_on_utf8_flag {
    my $self = shift;

    my @fields = @{ $self->field_list };

    Encode::_utf8_on( $self->{$_} ) for @fields;

    1
}

sub force_utf8_flag {
    my ($self, $p, $level) = @_;

    my @fields = @{ $self->field_list };

    for my $field (@fields) {
        next unless exists $self->{$field} and defined $self->{$field};

        my $before = $self->{$field};
        $self->{$field} = Dicole::Utils::Text->ensure_utf8( $self->{$field} );
        my $after = $self->{$field};

        my $before_is_utf8 = Encode::is_utf8($before) || 0;
        my $after_is_utf8 = Encode::is_utf8($after) || 0;

        Encode::_utf8_off($after);

        get_logger(LOG_APP)->error("Burgle: Before: $before_is_utf8, after: $after_is_utf8");
        get_logger(LOG_APP)->error("Bargle: $field = $before -> $after");
    }

    1
}

1;
