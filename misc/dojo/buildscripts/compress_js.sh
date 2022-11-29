#!/bin/bash

# Compresses all *.uncompressed.js files to *.compressed.js files in the
# current directory
# -- Sakari

JAVA="/usr/bin/java"
RHINO="/usr/local/bin/custom_rhino.jar"

if [ ! -x $JAVA ] || [ ! -e $RHINO ]; then
	echo "Java or Rhino not found, aborting.."
	exit
fi

for file in *.uncompressed.js; do
	input="$file"
	compressed=${input/.uncompressed/}
	if [ -e $compressed ]; then
		echo "File $compressed already exists, not overwriting (perhaps rename to .uncompressed.js ?)"
	else
		echo -n "Compressing $input to $compressed .."
		$JAVA -jar $RHINO -c $input > $compressed
		echo -n ". done"
		echo
	fi
done
