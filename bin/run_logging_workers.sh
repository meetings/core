#!/bin/bash
# Usage:
#   run_logging_workers.sh <group> [runtime]
# Where:
#   group   is one of work_on_ag OR work_on_bg OR work_on_fg
#   runtime is optional execution time in seconds

set -e
FIFO=`mktemp --dry-run`
mkfifo $FIFO
(logger -t worker -p local7.info <$FIFO &)
exec 2>$FIFO
exec >$FIFO
rm $FIFO

if [ -z "$1" ]; then
    echo error: group parameter missing
    exit 1
fi

GROUP=$1
RUNTIME=${2:-1200}

DOMAIN=$(d lc meetings_domain)
WEBDIR=$(d lc website_dir)

echo "Starting dcp workers with domain $DOMAIN and dir $WEBDIR (path $PATH)"

timeout -k 10 $[$RUNTIME+100] oi2_manage dicole_eval --website=$WEBDIR --code='CTX->lookup_action("meetings_worker")->e( '$GROUP' => { run_for_seconds => '$RUNTIME', domain_id => '$DOMAIN' } )'
