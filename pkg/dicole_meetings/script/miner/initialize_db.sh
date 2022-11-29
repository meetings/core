#!/bin/bash

GATEWAY=${1:-gateway.dicole.com}

cd $(perl -MCwd=abs_path -E 'abs_path(shift) =~/(.*miner)/; say $1' $(dirname "$0"))

mysql -e "DROP DATABASE IF EXISTS crmjournal";
ssh -F /root/.ssh/config_stat -p 20159 $GATEWAY :| pv -qL1m | unxz | mysql
mysql -e "FLUSH PRIVILEGES";
mysql -e "GRANT ALL ON miner_data.* TO miner@'%' IDENTIFIED BY 'miner'";
mysql -e "FLUSH PRIVILEGES";

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/push_scheduling_statistics_to_google.script

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/clean_irrelevant.script --parameters=131

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_notes.script --parameters=131
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_notes.script --parameters=131,fill

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,user

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,0 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,1 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,2 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,3 &
wait
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,4 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,5 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,6 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,7 &
wait
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,8 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,9 &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,a &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,b &
wait
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,c &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,d &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,e &
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,events_event,,f &
wait

/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,,,,2
/usr/local/bin/oi2_manage dicole_script --website_dir=/usr/local/dcp/ --script=oi2_scripts/create_and_fill_extras.script --parameters=131,fill,,,,3

./create_miner_db.pl crmjournal

./publish_stats_after_building.sh
