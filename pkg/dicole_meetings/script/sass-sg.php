#!/usr/bin/php-cgi -qC
<?php

/**
* SASS Sprite Generator
* Takes a folder of images and combines them to one sprite and generates SASS-mixins containing bg-positions
* & proper dimensions for the sprite. Places the sprite image and mixin file to preset locations. Optionally
* uses pngcrush to reduce file size.
*/

/**
* Setup for the script
*/

// Source image folder
$path = '/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/images/meetings/sprite_images/';

// Location for the generated sprite
$final_sprite_location = '/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/images/meetings/sass_sprite.png';

// Location for the generated mixin file
$sass_mixin_file = '/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/scss/_sprite.scss';

// Accepted filetypes
$filetypes = array('png','gif','jpg','jpeg');

// Padding between images
$padding = 2;

// Add random string to image name eg. sprite.png?v=141
$random_str = '?v='.rand(0,100);


if (!is_dir($path)) {
  die("\nFubard.\n");
}

/**
* Find images in current dir
*/
$images = array();
if ($dir_handle = opendir($path)) {
    while (($file = readdir($dir_handle)) !== false) {
        if($file == '' || $file == '.' || $file == '..') continue;
        $ext = strtolower(substr($file, strrpos($file, '.')+1));
        //$basename = basename($file, '.'.$ext);

        if (in_git($path.$file, $argv) && in_array($ext, $filetypes) && $file != 'sprite.png' && $file != 'sprite_crushed.png') {
            $images[$file] = getimagesize($path .'/'. $file);
        }
    }

    closedir($dir_handle);
    unset($dir_handle, $file, $ext, $basename); // free memory
}

if (count($images) === 0) {
  die("No images in folder!\n");
}

/**
* Loop trough the images, calculate positions, create SASS markup
*/
$x = 0;
$y = 0;
$sass = '';
$images_positioned = array();
foreach ($images as $file_name => $fd) {

    $important = '';
    if($file_name == 'calendar.png') $important = ' !important';

    // Create sass TODO: parametrisize
    $sass .= '@mixin sprite_'.substr($file_name, 0, -strlen(strrchr($file_name, '.'))).'(){
            width:'.$fd[0].'px;
            height:'.$fd[1].'px;
            background:url("/images/meetings/sass_sprite.png'.$random_str.'") 0px -'.$y.'px no-repeat'.$important.';
            }'."\n";

    // Add image to current y coord
    $images_positioned[$file_name] = array('x' => 0, 'y' => $y, 'width' => $fd[0], 'height' => $fd[1], 'extension' => strtolower(substr($file_name, strrpos($file_name, '.')+1)));

    // Increment y
    $y = $y + $fd[1] + $padding;

    // Keep largest width
    if($fd[0] > $x){
        $x = $fd[0];
    }
}

//var_dump($images_positioned);
//echo "\n\n";

/**
* Save SCSS
*/
$sass_file = fopen($sass_mixin_file, 'w') or die("can't open file");
fwrite($sass_file, $sass);
fclose($sass_file);

/**
* Create the image
*/
echo "\nCombining images...";
create_image($images_positioned, $path, $x, $y); // save sprites
echo " DONE.";

/**
* Crush the png
*/
if( isset($argv[1]) ){
echo "\nCrushing png...";
$cmd = 'pngcrush -rem alla -brute -reduce '.$path.'/sprite.png '.$path.'/sprite_crushed.png';
exec($cmd);
echo " DONE.";

echo "\nMoving to final destination...";
$cmd2 = 'rm '.$path.'/sprite.png && mv '.$path.'/sprite_crushed.png '.$final_sprite_location;
exec($cmd2);
echo " DONE.";
}
else{
$cmd = 'mv '.$path.'/sprite.png '.$final_sprite_location;
exec($cmd);
}

die("\nAll done.\n"); // end


/**
* Save a sprite image.
*
* @param Array $imgs
* Image list.
* @param String $filename
* Sprite file name.
*/
function create_image($imgs, $path, $x, $y) {
  if (!$x || !$y) return; // abort if image dimensions are invalid

  // create new [blank] image
  $im = imagecreatetruecolor($x, $y)
    or die("Cannot Initialize new GD image stream");


  // apply PNG 24-bit transparency to background
  $transparency = imagecolorallocatealpha($im, 0, 0, 0, 127);
  imagealphablending($im, FALSE);
  imagefilledrectangle($im, 0, 0, $x, $y, $transparency);
  imagealphablending($im, TRUE);
  imagesavealpha($im, TRUE);

  // overlay all source image onto single destination sprite image
  foreach ($imgs as $file => $img) {
    if (isset($img['extension'], $img['x'], $img['y'], $img['width'], $img['height'])) {
      image_overlay(
        $im,
        $path.'/'.$file,
        $img['extension'],
        $img['x'], // dst_x
        $img['y'], // dst_y
        0, // src_x
        0, // src_y
        $img['width'], // : $img['width'], // dst_w
        $img['height'], // : $img['height'], // dst_h
        $img['width'], // src_w
        $img['height'] // src_h
      );
    }
  }

  // save sprite image prefix as PNG
  image_gd_close($im, $path.'/sprite.png', 'png');
  imagedestroy($im); // free memory
}

/**
* Overlay a source image on a destination image at a given location.
*/
function image_overlay(&$dst_im, $src_path, $src_ext, $dst_x, $dst_y, $src_x, $src_y, $dst_w, $dst_h, $src_w, $src_h) {
  $src_im = image_gd_open($src_path, $src_ext); // load source image
  imagecopyresampled($dst_im, $src_im, $dst_x, $dst_y, $src_x, $src_y, $dst_w, $dst_h, $src_w, $src_h); // overlay source image on destination image
  imagedestroy($src_im); // free memory
}


/**
* GD helper function to create an image resource from a file.
*/
function image_gd_open($file, $extension) {
  $extension = str_replace('jpg', 'jpeg', $extension);
  $open_func = 'imageCreateFrom'. $extension;
  if (!function_exists($open_func)) {
    return FALSE;
  }
  return $open_func($file);
}


/**
* GD helper to write an image resource to a destination file.
*/
function image_gd_close($res, $destination, $extension) {
  $extension = str_replace('jpg', 'jpeg', $extension);
  $close_func = 'image'. $extension;
  if (!function_exists($close_func)) {
    return FALSE;
  }
  if ($extension == 'jpeg') {
    return $close_func($res, $destination, 100);
  }
  else {
    return $close_func($res, $destination);
  }
}

/**
 * Function to check if file is is tracked by git
 */
function in_git($file, $argv){
    if( isset($argv[1]) && $argv[1] == '-u' ){
        $output = shell_exec('git status -s '.$file);
        if($output != '' && strpos($output,'??') == 0){
            return false;
        }
        else{
            return true;
        }
    }
    return true;
}
