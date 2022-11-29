#!/bin/bash
# update.sh, 2014-03-07 / Meetin.gs

set -e
set -u

. $DEPLOYDIR/githupdate.sh

git_upgrade && [ "$FORCE" != "yes" ] && {
    echo "[update] Quitting"
    exit 0
}

. $DEPLOYDIR/service.sh

upgrade_service "update" && echo "[update] Done"
