package OpenInteract2::App::DicoleNavigation;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::DicoleNavigation::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::DicoleNavigation::EXPORT  = qw( install );

sub get_brick_name {
    return 'dicole_navigation';
}

# Not a method, just an exported sub
sub install {
    my ( $website_dir ) = @_;
    my $manage = OpenInteract2::Manage->new( 'install_package' );
    $manage->param( website_dir   => $website_dir );
    $manage->param( package_class => __PACKAGE__ );
    return $manage->execute;
}

__END__

=pod

=head1 NAME

OpenInteract2::App::DicoleNavigation - This application will do everything!



=cut
