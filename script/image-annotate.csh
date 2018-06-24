#!/bin/tcsh -b
set file = $1
set class = $2
set crop = $3

setenv DEBUG true
setenv VERBOSE true

if ($?CAMERA_IMAGE_WIDTH == 0) setenv CAMERA_IMAGE_WIDTH 640
if ($?CAMERA_IMAGE_HEIGHT == 0) setenv CAMERA_IMAGE_HEIGHT 480
if ($?MODEL_IMAGE_WIDTH == 0) setenv MODEL_IMAGE_WIDTH 224
if ($?MODEL_IMAGE_HEIGHT == 0) setenv MODEL_IMAGE_HEIGHT 224
if ($?CAMERA_MODEL_TRANSFORM == 0) setenv CAMERA_MODEL_TRANSFORM "CROP"

if (! -e "$file") then
  if ($?VERBOSE) echo "$0:t $$ -- files does not exist: $file" >&! /dev/stderr
  exit(1) 
else
  if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- START" >&! /dev/stderr
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


set xywh = ( `echo "$crop" | sed "s/\(.*\)x\(.*\)\([+-]\)\(.*\)\([+-]\)\(.*\)/\3\4 \5\6 \1 \2/"` )
if ($?xywh == 0) then
  if ($?DEBUG) echo "$0:t $$ -- $file:t:r -- BAD CROP ($crop)" >&! /dev/stderr
  exit(1)
else if ($#xywh != 4) then
  if ($?DEBUG) echo "$0:t $$ -- $file:t:r -- INVALID CROP ($crop) ($xywh)" >&! /dev/stderr
  exit(1)
else
  if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- GOOD CROP ($crop) ($xywh)" >&! /dev/stderr
endif


###
### process full frame
###

if ($file:e == "jpg") then

  ## parse imagebox
  set x = `echo "0 $xywh[1]" | bc`
  if ($?x == 0) @ x = 0
  if ($#x == 0) @ x = 0
  if ($x < 0 || $x > $CAMERA_IMAGE_WIDTH) @ x = 0
  set y = `echo "0 $xywh[2]" | bc`
  if ($?y == 0) @ y = 0
  if ($#y == 0) @ y = 0
  if ($y < 0 || $y > $CAMERA_IMAGE_HEIGHT) @ y = 0
  set w = $xywh[3]
  if ($?w == 0) @ w = $CAMERA_IMAGE_WIDTH
  if ($w <= 0 || $w > $CAMERA_IMAGE_WIDTH) @ w = $CAMERA_IMAGE_WIDTH
  set h = $xywh[4]
  if ($?h == 0) @ h = $CAMERA_IMAGE_HEIGHT
  if ($h <= 0 || $h > $CAMERA_IMAGE_HEIGHT) @ h = $CAMERA_IMAGE_HEIGHT
  ## calculate extant
  @ ew = $x + $w
  @ eh = $y + $h
  set target = ( $x $y $ew $eh )
  ## calculate centroid of movement
  @ cx = `echo "$x + ( $w / 2 )" | bc`
  @ cy = $y + ( $h / 2 )

  if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- bounding box (x=$x y=$y w=$w h=$h); target (ex=$ew ey=$eh) centroid (x=$cx y=$cy)" >&! /dev/stderr

  ## calculate cropped area 
  @ sx = $cx - ( $MODEL_IMAGE_WIDTH / 2 )
  if ($sx < 0) @ sx = 0
  @ sy = $cy - ( $MODEL_IMAGE_HEIGHT / 2 )
  if ($sy < 0) @ sy = 0
  # adjust for scale
  @ sw = $MODEL_IMAGE_WIDTH
  @ sh = $MODEL_IMAGE_HEIGHT
  # adjust if past edge
  if ($sx + $sw > $CAMERA_IMAGE_WIDTH) @ sx = $CAMERA_IMAGE_WIDTH - $sw
  if ($sy + $sh > $CAMERA_IMAGE_HEIGHT) @ sy = $CAMERA_IMAGE_HEIGHT - $sh

  if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- cropped image (x=$sx y=$sy w=$sw h=$sh)" >&! /dev/stderr

  # cropped rectangle of MODEL_IMAGE_WIDTH x MODEL_IMAGE_HEIGHT
  @ rw = $sx + $sw
  @ rh = $sy + $sh
  set rect = ( $sx $sy $rw $rh )

  set xform = "$sw"x"$sh"+"$sx"+"$sy"

  if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- Rect ($rect) Xform ($xform)" >&! /dev/stderr

  ##
  ## transform image into cropped form
  ##
  if ($?CAMERA_MODEL_TRANSFORM) then
    switch ($CAMERA_MODEL_TRANSFORM)
      case "RESIZE":
        if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- UNIMPLEMENTED: CAMERA_MODEL_TRANSFORM=$CAMERA_MODEL_TRANSFORM" >&! /dev/stderr
        breaksw
      case "CROP":
        if ($?VERBOSE) echo "$0:t $$ -- $file:t:r -- transforming using $CAMERA_MODEL_TRANSFORM" >&! /dev/stderr
        set cropped = "$file:r.$xform.jpeg"
        convert \
 	  -crop "$xform" "$file" \
	  -gravity center \
	  -background gray \
          "$cropped"
        if (! -s "$cropped") then
          if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- failed to crop image" >&! /dev/stderr
        else
          set random = "$cropped:r.random.jpeg"
          convert -size "$CAMERA_IMAGE_WIDTH"'x'"$CAMERA_IMAGE_HEIGHT" 'xc:' '+noise' Random "$random"
          if (! -e "$random") then
            if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- failed to create random background $random" >&! /dev/stderr
          else
            set composed = "$file:r.jpeg"
            composite -compose src -geometry +"$sx"+"$sy" "$cropped" "$random" "$composed"
            if (! -s "$composed") then
              if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- failed to compose cropped on random" >&! /dev/stderr
              rm -f "$composed"
              unset composed
            else
              if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- successfully composed cropped image and random background" >&! /dev/stderr
            endif
            /bin/rm -f "$random" # "$cropped"
          endif
        endif
        breaksw
      default:
        if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- invalid CAMERA_MODEL_TRANSFORM ($CAMERA_MODEL_TRANSFORM)" >&! /dev/stderr
        breaksw
    endsw
  else
    if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- undefined: CAMERA_MODEL_TRANSFORM" >&! /dev/stderr
  endif
else
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- not a full frame image ($file:e)" >&! /dev/stderr
endif

##
## annotate image with text label
##
if ($?IMAGE_ANNOTATE_TEXT) then
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- annotating image (IMAGE_ANNOTATE_TEXT=$IMAGE_ANNOTATE_TEXT)" >&! /dev/stderr
  if ($?IMAGE_ANNOTATE_FONT == 0) then
    set fonts = ( `convert -list font | awk -F': ' '/glyphs/ { print $2 }' | sort | uniq` )
    if ($#fonts == 0) then
      if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- no fonts found using convert to list fonts" >&! /dev/stderr
      set fonts = ( `fc-list | awk -F: '{ print $1 }' | sort | uniq` )
      if ($#fonts == 0) then
        if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- no fonts found using fc-list to list fonts" >&! /dev/stderr
      endif 
    endif
    # use the first font
    if ($#fonts) set font = $fonts[1]
  else
    if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- using font $IMAGE_ANNOTATE_FONT from environment (IMAGE_ANNOTATE_FONT)" >&! /dev/stderr
    set font = "$IMAGE_ANNOTATE_FONT"
  endif
  if ($?font) then
    ## define output
    set annotated = "$file:r.$$.anno.jpeg"
    # attempt to write the "$class" annotation and outline imagebox in white
    convert \
      -font "$font" \
      -pointsize "$psize" -size "$csize" xc:none -gravity center -stroke black -strokewidth 2 -annotate 0 "$class" \
      -background none -shadow "100x3+0+0" +repage -stroke none -fill white -annotate 0 "$class" \
      "$file" \
      +swap -gravity south -geometry +0-3 -composite -fill none -stroke white -strokewidth 3 -draw "rectangle $rect" \
      "$annotated" >&! /dev/stderr
  else
    if ($?DEBUG) echo "$0:t $$ -- $file:r:t -- no fonts found; image annotation disabled" >&! /dev/stderr
  endif
else
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- image annotation disabled (IMAGE_ANNOTATE_TEXT=$IMAGE_ANNOTATE_TEXT)" >&! /dev/stderr
endif

##
## draw a rectangle around the target (MODEL_IMAGE_WIDTH x MODEL_IMAGE_WIDTH) in red
##
if (-e "$annotated") then
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- trying to convert $file into $annotated" >&! /dev/stderr
  convert "$annotated" -fill none -stroke red -strokewidth 3 -draw "rectangle $target" "$annotated.$$" >&! /dev/stderr
  mv "$annotated.$$" "$annotated"
else
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- failed to convert $file into $annotated" >&! /dev/stderr
endif

output:

if (-e "$annotated") then
  if ($?VERBOSE) echo "$0:t $$ -- $file:r:t -- OUTPUT SUCCESSFUL $annotated ($class $rect)" >&! /dev/stderr
  /bin/dd if="$annotated" of=/dev/stdout >& /dev/null
  /bin/rm -f "$annotated"
  exit 0
else
  if ($?DEBUG) echo "$0:t ($$) -- $file:r:t -- FAILURE" >&! /dev/stderr
  /bin/rm -f "$annotated"
  exit 1
endif
