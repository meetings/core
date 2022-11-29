#!/bin/sh
# init.sh, 2014-02-03 / Meetin.gs

set -e
set -u

echo "[init] Initializing submodules"
git submodule update --init
