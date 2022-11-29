#!/bin/bash
# service.sh, 2015-04-28 / Meetin.gs

set -u

GITHASH=$(git rev-parse HEAD)

MODS=(oi2_compatibility attachment awareness base comments default_theme)
MODS+=(development dojo domains domain_user_manager emails events event_source)
MODS+=(groups localization login meetings networking presentations random)
MODS+=(reset_theme security sessions settings tag thumbnails tinymce3)
MODS+=(tinymce_meetings user_manager wiki navigation)

_configuration_override() {
    if [ -f $DEPLOYDIR/local_config_$RANK ]; then
        cat $DEPLOYDIR/local_config_$RANK > bin/local_config_override
    fi
    if [ -f $DEPLOYDIR/local_config_${RANK}_${ROLE} ]; then
        cat $DEPLOYDIR/local_config_${RANK}_${ROLE} > bin/local_config_override
    fi
}

upgrade_service() {
    echo "[$1] Overriding local configuration"
    _configuration_override

    echo "[$1] Ensuring non-ancient List::Util"
    if [ "$(perl -M'List::Util 999' 2>&1 |grep 1.2)" != "" ]; then
        cpanm List::Util
    fi

    echo "[$1] Installing SPOPS"
    cd vendor/SPOPS
    perl Makefile.PL
    make
    make install
    cd -

    echo "[$1] Installing OI2"
    cd vendor/OpenInteract
    ./build_all
    perl Makefile.PL
    make
    make install
    cd -

    echo "[$1] Building DCP"
    perl Build.PL
    ./Build install
    ./Build clean

    echo "[$1] Installing DCP modules"
    export OPENINTERACT2="/usr/local/dcp"
    /usr/local/bin/d i ${MODS[@]}

    echo "[$1] Updating static file version"
    sed -i.prev "/static_file_version/c static_file_version = $GITHASH" \
        /usr/local/dcp/conf/server.ini

    if [ "$ROLE" == "worker" ]; then
        echo "[$1] Flushing old and restarting new workers"
        ./bin/restart_domain_workers $(/usr/local/bin/d lc meetings_domain)
    fi

    if [ "$ROLE" == "http" ]; then
        echo "[$1] Flushing old and restarting new http servers"
        /usr/local/bin/d a
    fi
}
