rm -Rf html/js/tinymce_meetings
cp -R src/tinymce/js/tinymce html/js/tinymce_meetings

cd html/js/tinymce_meetings/
mv plugins plugins_original
mkdir plugins
for PLUGIN in "paste" "autolink"
do
    mv plugins_original/$PLUGIN plugins/$PLUGIN
done
rm -Rf plugins_original

cd langs
rm readme.md
mv en_GB.js en.js
mv sv_SE.js sv.js
mv fr_FR.js fr.js
cd ..

