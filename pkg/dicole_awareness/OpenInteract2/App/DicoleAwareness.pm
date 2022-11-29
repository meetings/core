package OpenInteract2::App::DicoleAwareness;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::DicoleAwareness::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::DicoleAwareness::EXPORT  = qw( install );

my $NAME = 'dicole_awareness';

sub new {
    return OpenInteract2::App->new( $NAME );
}

sub get_brick {
    require OpenInteract2::Brick;
    return OpenInteract2::Brick->new( $NAME );
}

sub get_brick_name {
    return $NAME;
}

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

OpenInteract2::App->register_factory_type( $NAME => __PACKAGE__ );

1;

__END__

=pod

=head1 NAME

OpenInteract2::App::DicoleAwareness - This application will do everything!



=cut

