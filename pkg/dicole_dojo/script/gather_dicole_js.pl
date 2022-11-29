#!/usr/bin/perl

my $files = `find .. -type f | grep html/js`;
for my $file ( split( "\n", $files ) ) {
    next unless $file =~ /^\.\.\/\w+\/html\/js\/dicole\//;
    next if $file =~ /^\.\.\/dicole_dojo\//;
    my $target = $file;
    $target =~ s/^\.\.\/\w+\/html\/js\/dicole/dicole/;
    my ($dir) = $target =~ /^(.*)\//;
    system "mkdir", "-p", "build/$dir";
#    print "mkdir", "-p", "build/$dir" . $/;
    system "cp", $file, "build/$target";
#    print "cp", $file, "build/$target" . $/;
}
