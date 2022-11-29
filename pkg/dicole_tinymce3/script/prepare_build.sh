rm -Rf build
mkdir -p build
cp -R src/tinymce/* build/
cp -R data/extra_plugins/* build/jscripts/tiny_mce/plugins/
cp -R data/override_files/* build/
