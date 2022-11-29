#!/bin/bash
mkdir -p src
cd src
if [ ! -d current ]
then
  wget 'http://download.dojotoolkit.org/release-1.6.0/dojo-release-1.6.0-src.tar.gz'
  tar zxf dojo-release-1.6.0-src.tar.gz
  rm dojo-release-1.6.0-src.tar.gz
  ln -s dojo-release-1.6.0-src current
fi
