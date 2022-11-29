#!/bin/bash

wwwroot='/var/www'
rm -Rf build
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/gather_stats_to_static_files.script
mkdir -p $wwwroot/js/stats
rsync -a --delete build/ $wwwroot/js/stats/
mkdir -p $wwwroot/js/monthly_stats
rsync -a --delete build/ $wwwroot/js/monthly_stats/
rm -Rf build
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/gather_weekly_stats_to_static_files.script
mkdir -p $wwwroot/js/weekly_stats
rsync -a --delete build/ $wwwroot/js/weekly_stats/
rm -Rf build
