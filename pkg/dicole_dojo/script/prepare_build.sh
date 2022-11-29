#!/bin/bash

rm -Rf build
mkdir -p build
rsync -a src/current/ build/
script/gather_dicole_js.pl
cp -R data/override_files/* build/
script/create_profile.pl > build/util/buildscripts/profiles/dicole.profile.js
