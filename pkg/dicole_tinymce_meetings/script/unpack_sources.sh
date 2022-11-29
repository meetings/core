#!/bin/bash
rm -Rf src
mkdir src
cd src
# Skip version 4.0.12 because it breaks Safari Copy & Paste
curl http://download.moxiecode.com/tinymce/tinymce_4.1.7.zip > source.zip
unzip source.zip

cd tinymce/js/tinymce
for LANG in "en_GB" "fi" "nl" "sv_SE" "fr_FR"
do
    curl http://www.tinymce.com/i18n/download.php?download=$LANG > $LANG.zip
    unzip $LANG.zip
    rm $LANG.zip
done
