#!/usr/bin/perl

my $dir = 'html/scss/';
my $from = $dir . 'icomoon.scss';
my $to = $dir . 'icomoon_ie7.scss';

my $data = `cat $from`;
my @targets = $data =~ /(\.ico\-\w+\:before[^\}]*})/gs;
my @lines = ();
for my $target ( @targets ) {
    my ( $class, $value ) = $target =~ /(\.ico\-\w+)\:.*\\e([\w\d]+)/s;
    push @lines, $class . " { *zoom: expression( this.runtimeStyle['zoom'] = '1', this.innerHTML = '&#xe". $value .";'); }\n";
}

open FILE, ">$to";
print FILE join "", @lines;
close FILE;
