#!/usr/bin/perl
if ( ! `ps axu |grep -E '[X]vfb'` ) {
    `rm -Rf /tmp/.X100-lock` if -e '/tmp/.X100-lock';
    `nohup Xvfb :100 -ac -nolisten tcp -screen 0 1024x768x24 > /dev/null 2>&1 &`;
    sleep 6;
}

