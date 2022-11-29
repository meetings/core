#!/usr/bin/perl

use GD;

my $width = 122;
my $height = 122;
my $margin = 2;

my $steps = 20;

my $i = new GD::Image( $width, $height * ( $steps + 1 ) );

$i->alphaBlending(0);
$i->saveAlpha(1);
$i->interlaced('true');

my $bg = $i->colorAllocateAlpha( 0,0,0, 127 );
my $fill = $i->colorAllocateAlpha( 0,149,192, 100 );

for my $step ( 1 .. $steps ) {
    $i->filledArc(
        ( $width / 2 ) - 1,
        ( $height / 2 ) - 1 + ( $step * $height ),
        $width - $margin,
        $height - $margin,
        270,
        ( 360 / $steps * $step + 270 ) % 360,
        $fill
    );
}

binmode STDOUT;

print $i->png;

