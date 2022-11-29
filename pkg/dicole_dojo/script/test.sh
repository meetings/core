#!/bin/bash

script/prepare_build.sh
cd build/util/doh/
./runner.sh testModule=dicole.tests.$1
