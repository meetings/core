#!/bin/bash

cd build/util/buildscripts
./build.sh profile=dicole action=release optimize=shrinksafe.keepLines cssOptimize=comments.keepLines mini=true
cd ../../..
rm -Rf html/js
mkdir html/js
rm -Rf html/js/*
cp -R build/release/dojo/* html/js/
rm -Rf html/js/util
rm -Rf html/js/dicole
rm html/js/dojo/build.txt
