#!/usr/bin/perl

if ( ! -d 'script' ) {
die "Must be run in dicole_meetings package root directory";
}

system "php script/sass-sg.php -u";

# If the sprite did not change, do not change the scss numbers either
if ( ! `git status -s html/images/meetings/sass_sprite.png` ) {
    system "git checkout html/scss/_sprite.scss";
}
