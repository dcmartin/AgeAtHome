#!/bin/csh -fb
set file = $1
set class = $2
set crop = $3

if ($?CAMERA_IMAGE_WIDTH == 0) setenv CAMERA_IMAGE_WIDTH 640
if ($?CAMERA_IMAGE_HEIGHT == 0) setenv CAMERA_IMAGE_HEIGHT 480
if ($?MODEL_IMAGE_WIDTH == 0) setenv MODEL_IMAGE_WIDTH 224
if ($?MODEL_IMAGE_HEIGHT == 0) setenv MODEL_IMAGE_HEIGHT 224

if (! -e "$file") then
  /bin/echo "$0 $$ -- NO FILE ($file)" >&! /dev/console
  exit(1) 
endif

switch ($file:e)
    case "jpeg": # 224x224 image
	set csize = "200x20"
	set psize = "18"
      breaksw
    case "jpg": # 640x480 image
    default:
      set csize = "600x40"
      set psize = "48"
      breaksw
endsw

set out = "$file:r.$$.$file:e"
set xywh = ( `/bin/echo "$crop" | /bin/sed "s/\(.*\)x\(.*\)\([+-]\)\(.*\)\([+-]\)\(.*\)/\3\4 \5\6 \1 \2/"` )

if ($file:e == "jpg") then

  set x = ( `/bin/echo "$xywh[1]"` )
  if ($?x == 0) set x = 0
  if ($x < 0) set x = 0
  set y = ( `/bin/echo "$xywh[2]"` )
  if ($?y == 0) set y = 0
  if ($y < 0) set y = 0
  set w = ( `/bin/echo "$xywh[3]"` )
  if ($?w == 0) set w = 640
  if ($w <= 0) set w = 640
  set h = ( `/bin/echo "$xywh[4]"` )
  if ($?h == 0) set h = 480
  if ($h <= 0) set h = 480

  @ cx = $x + ( $w / 2 ) - ( $MODEL_IMAGE_WIDTH / 2 )
  @ cy = $y + ( $h / 2 ) - ( $MODEL_IMAGE_HEIGHT / 2 )
  if ($cx < 0) @ cx = 0
  if ($cy < 0) @ cy = 0
  if ($cx + $MODEL_IMAGE_WIDTH > $CAMERA_IMAGE_WIDTH) @ cx = $CAMERA_IMAGE_WIDTH - $MODEL_IMAGE_WIDTH
  if ($cy + $MODEL_IMAGE_HEIGHT > $CAMERA_IMAGE_HEIGHT) @ cy = $CAMERA_IMAGE_HEIGHT - $MODEL_IMAGE_HEIGHT

  set rect = ( $cx $cy $MODEL_IMAGE_WIDTH $MODEL_IMAGE_HEIGHT )
  set xform = "$MODEL_IMAGE_WIDTH"x"$MODEL_IMAGE_HEIGHT"+"$cx"+"$cy"
else
  set rect = ( 0 0  $MODEL_IMAGE_WIDTH $MODEL_IMAGE_HEIGHT )
  set xform = "$MODEL_IMAGE_WIDTH"x"$MODEL_IMAGE_HEIGHT"+"0"+"0"
endif

if ($file:e == "jpg" && $?CAMERA_MODEL_TRANSFORM) then
  switch ($CAMERA_MODEL_TRANSFORM)
    case "RESIZE":
       breaksw
    case "CROP":
      /usr/local/bin/convert \
	 -crop "$xform" "$file" \
	 -gravity center \
	 -background gray \
	 "$file:r.jpeg"
    breaksw
  endsw
endif

if ($?IMAGE_ANNOTATE_TEXT) then
  if ($?IMAGE_ANNOTATE_FONT == 0) then
    set fonts = ( `convert -list font | awk -F': ' '/glyphs/ { print $2 }' | sort | uniq` )
    if ($#fonts == 0) then
      /bin/echo "$0 $$ -- found no fonts using convert(1) to list fonts" >&! /dev/console
      set fonts = ( `fc-list | awk -F: '{ print $1 }' | sort | uniq` )
      if ($#fonts == 0) then
        /bin/echo "$0 $$ -- found no fonts using fc-list(1) to list fonts" >&! /dev/console
      endif 
    endif
    # use the first font
    if ($#fonts) set font = $fonts[1]
  else
    set font = "$IMAGE_ANNOTATE_FONT"
  endif
  if ($?font) then
    # attempt to write the "$class" annotation
    /usr/bin/convert \
      -font "$font" \
      -pointsize "$psize" -size "$csize" xc:none -gravity center -stroke black -strokewidth 2 -annotate 0 "$class" \
      -background none -shadow "100x3+0+0" +repage -stroke none -fill white -annotate 0 "$class" \
      "$file" \
      +swap -gravity south -geometry +0-3 -composite -fill none -stroke white -strokewidth 3 -draw "rectangle $rect" \
      "$out" >&! /dev/console
  endif
endif

if (! -e "$out") then
  /bin/echo "$0 $$ -- trying to convert $file into $out" >&! /dev/console
  /usr/bin/convert "$file" -fill none -stroke white -strokewidth 3 -draw "rectangle $rect" "$out" >&! /dev/console
endif

if (-e "$out") then
  /bin/echo "$0 ($$) -- OUTPUT SUCCESSFUL $out ($class $rect)" >&! /dev/console
  /bin/dd if="$out"
  /bin/rm -f "$out"
  exit 0
else if (-e "$file") then
  /bin/echo "$0 ($$) -- OUTPUT FAILURE $out (returning $file)" >&! /dev/console
  /bin/dd if="$file"
  /bin/rm -f "$out"
  exit 1
else  if (! -e "$file") then
  /bin/echo "$0 ($$) -- NO INPUT ($file)" >&! /dev/console
  /bin/rm -f "$out"
  exit 1
endif
