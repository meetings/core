script/prepare_build.sh
cd build
ant
cd ..
rm -Rf html/js/tiny_mce
cp -R build/jscripts/tiny_mce html/js/

cd html/js/tiny_mce/plugins
rm -Rf tabfocus spellchecker pagebreak compat2x safari bbcode template xhtmlxtras nonbreaking visualchars media style layer fullpage noneditable
rm -Rf directionality fullscreen contextmenu searchreplace save print preview insertdatetime iespell example emotions
rm -Rf advlink advimage advhr advlist autoresize legacyoutput wordcount
cd ..
rm -Rf classes

