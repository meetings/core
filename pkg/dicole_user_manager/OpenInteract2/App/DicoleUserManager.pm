package OpenInteract2::App::DicoleUserManager;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::DicoleUserManager::VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::DicoleUserManager::EXPORT  = qw( install );

sub get_brick_name {
    return 'dicole_user_manager';
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

OpenInteract2::App::DicoleUserManager - This application will do everything!

=head1 NAME

dicole_user_manager - This package will do everything!

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 OBJECTS

No objects created by this package.

=head1 ACTIONS

No actions defined in this package.

=head1 RULESETS

No rulesets defined in this package.

=head1 BUGS 

None known.

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

Who AmI E<lt>me@whoami.comE<gt>


=cut
