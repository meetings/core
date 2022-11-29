#!/usr/bin/env php

<?php
// Generate theme files
$themes = array('main','blue', 'pink_red', 'grey', 'brown', 'turquoise', 'green', 'purple', 'darkblue', 's2m', 'tnw', 'kpn');
$scss_path = "/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/scss/";
$css_path = "/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/css/meetings/";
$defaults = 'defaults';
$extra_files = array('tinymce', 'datepicker_mtn', 'add2home');
echo "Generating theme files...\n";
foreach($themes as $theme){
    if(file_exists($scss_path.$theme.'.scss')){
        // Echo for Anttis sanitys sake
        echo 'Building ' . $theme . " theme...\n";

        // Create temp file
        $temp_file = $theme.'_temp.scss';
        $fh = fopen($scss_path.$temp_file, 'w') or die("can't open file");

        // Write data
        $fcontent = '@import "'.$defaults.'","'.$theme.'"';
        if($theme == 'main') $fcontent .= ',"meetings"';
        else $fcontent .= ',"buttons"';

        fwrite($fh, $fcontent);
        fclose($fh);

        // Run SASS
        $output_fn = $css_path.$theme;
        $output_fn .= '.css';
        $cmd = "sass --style compressed $scss_path"."$temp_file $output_fn";
        exec($cmd);

        // Delete temp file
        unlink($scss_path.$temp_file);
    }
}
echo " DONE\n";
echo 'Generating extra files...';
// Generate extrafiles
foreach($extra_files as $file){
    $cmd = "sass --style compressed ".$scss_path.$file.".scss ".$css_path.$file.".css";
    exec($cmd);
}
echo " DONE\n";
echo "All done.\n";

?>
