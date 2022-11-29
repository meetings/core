package Dicole::Utils::HTTP::UserAgent;

use base qw( LWP::UserAgent Class::Accessor );

Dicole::Utils::HTTP::UserAgent->mk_accessors( qw( username password ) );

sub new {
    my $class = shift @_;

    my $self = $class->SUPER::new( @_ );
    $self->timeout( 8 );
    $self->agent('libwww-perl/Dicole');
    $self->default_header('Accept-Encoding' => 'gzip');

    return $self;
}

sub get_basic_credentials {
    my $self = shift @_;

    if ( $self->username ) {
        return ( $self->username, $self->password );
    }

    return $self->SUPER::get_basic_credentials( @_ );
}

1;
