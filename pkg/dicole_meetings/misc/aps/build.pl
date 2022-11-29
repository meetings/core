#!/usr/bin/perl

my $list = '<?xml version="1.0"?><files xmlns="http://apstandard.com/ns/1">';
my @files = ('APP-META.xml', 'license.txt');
push @files, split /\n/, `find scripts | tail -n +2`;
push @files, split /\n/, `find images | tail -n +2`;

for my $file ( @files ) {
    my $size = `du -b $file | cut -f1`;
    my $sha = `sha256sum $file |cut -f1 -d' '`;
    chomp $size;
    chomp $sha;
    $list .= '<file name="'.$file.'" size="'.$size.'" sha256="'.$sha.'"/>';
}

$list .= '</files>';

open F, '>APP-LIST.xml';
print F $list;
close F;

system qw( rm -fR build );
system qw( mkdir -p build );
system qw( zip build/meetin.gs.app.zip APP-LIST.xml ), @files;
system qw( mono bin/apslint.exe build/meetin.gs.app.zip );


