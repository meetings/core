#!/bin/bash
# githupdate.sh, 2013-12-09 / Meetin.gs
#
# Autodeployment script to fetch and update git repository together
# with all submodules. This script is, of course, run before new
# version is available, thus any new feature is not available.

set -u

_git_checkout() {
    # Checkout the branch matching the rank configuration.
    # If it hasn't been checked out before, make sure it
    # is tracked properly.
    #
    git show-ref -q --verify refs/heads/$RANK; EXISTS_LOCAL=$?

    if [ $EXISTS_LOCAL -eq 0 ]; then
        echo "[git] Checking out $RANK"
        git checkout $RANK
        git merge --ff-only refs/remotes/origin/$RANK
    else
        echo "[git] Creating local tracking branch for $RANK"
        git checkout -b $RANK origin/$RANK
    fi
}

git_upgrade() {
    PREVIOUS=$(git rev-parse HEAD)

    # Regardless of current state of the repository,
    # reset everything as they are in upstream.
    #
    git checkout --force master
    git clean -d --force
    git pull --all --recurse-submodules
    git submodule update
    git remote prune origin

    # If there is no remote branch for this hosts
    # rank, stay in master and be happy with it.
    #
    git show-ref -q --verify refs/remotes/origin/$RANK; EXISTS_REMOTE=$?

    if [ $EXISTS_REMOTE -eq 0 ]; then
        _git_checkout
    else
        echo "[git] No remote branch $RANK, keeping master"
    fi

    CURRENT=$(git rev-parse HEAD)
    echo " --- $PREVIOUS"
    echo " +++ $CURRENT"

    # Compare previous and current versions. This will set the return
    # value of the function to indicate, if version has changed.
    # Submodules are not checked and any changes in them will not
    # trigger upgrade.
    #
    [ "$PREVIOUS" == "$CURRENT" ]
}
