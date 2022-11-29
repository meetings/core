#!/bin/bash
rm -Rf src/tinymce
unzip data/tinymce_3* -d src/
unzip -o data/tinymce_lang* -d src/tinymce/jscripts/tiny_mce/
