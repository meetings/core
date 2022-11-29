package Dicole::Task;

use base 'Class::Accessor';

=pod

=head1 NAME

Dicole task superclass

=head1 SYNOPSIS

 use base qw( Dicole::Task );

=head1 DESCRIPTION

A base class for reusable tasks. Subclasses must implement execute().

=cut

Dicole::Task->mk_accessors( qw(
    action
) );

sub new {
    my ($class, $action, $p) = @_;
    
    my $self = bless {}, $class;

    $self->action( $action );
    
    for my $key ( keys %$p ) {
        next unless $self->can( $key );
        eval '$self->' . $key . '($p->{$key})';
    }
    
    return $self;
}

sub execute { die 'Dicole::Task subclass must implement execute()' }

1;
