# This OpenInteract2 file was generated
#   by:    /usr/local/bin/oi2_manage create_package --package=dicole_attachment
#   on:    Thu May 22 01:53:17 2008
#   from:  App.pm
#   using: OpenInteract2 version 1.99_07

package OpenInteract2::App::DicoleAttachment;

use strict;
use base qw( Exporter OpenInteract2::App );
use OpenInteract2::Manage;

$OpenInteract2::App::DicoleAttachment::VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);
@OpenInteract2::App::DicoleAttachment::EXPORT  = qw( install );

my $NAME = 'dicole_attachment';

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

OpenInteract2::App::DicoleAttachment - This application will do everything!

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ACTIONS

=head1 OBJECTS

=head1 AUTHORS

Who AmI E<lt>me@whoami.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2008 Who AmI. All rights reserved.

=cut
