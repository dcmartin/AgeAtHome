#!/bin/csh -fb
set file = $1
set class = $2
set crop = $3

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
  @ w = $xywh[3] / 2
  @ h = $xywh[4] / 2
  @ x = `/bin/echo "$w $xywh[1] - 112" | /usr/bin/bc`
  @ y = `/bin/echo "$h $xywh[2] - 112" | /usr/bin/bc`

  if ($x < 0) set x = 0
  if ($y < 0) set y = 0
  set w = `/bin/echo "$x + 224" | /usr/bin/bc`
  set h = `/bin/echo "$y + 224" | /usr/bin/bc`
  if ($w > 640) then
    @ x -= ( $w - 640 )
    @ w = 640
  endif
  if ($h > 480) then
    @ y -= ( $h - 480 )
    @ h = 480
  endif
  set rect = ( $x $y $w $h )
else
  set rect = ( 0 0 224 224 )
endif

if ($?IMAGE_ANNOTATE_TEXT) then
  if ($?IMAGE_ANNOTATE_FONT == 0) then
    set fonts = ( `convert -list font | awk -F': ' '/glyphs/ { print $2 }' | sort | uniq` )
    if ($#fonts == 0) then
      echo "$0 $$ -- found no fonts using convert(1) to list fonts" >&! /dev/console
      set fonts = ( `fc-list | awk -F: '{ print $1 }' | sort | uniq` )
      if ($#fonts == 0) then
        echo "$0 $$ -- found no fonts using fc-list(1) to list fonts" >&! /dev/console
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
      "$out"
  endif
else
  /usr/bin/convert "$file" -fill none -stroke white -strokewidth 3 -draw "rectangle $rect" "$out"
endif

if (-s "$out") then
  echo "$0 ($$) -- OUTPUT SUCCESSFUL FONT ($?font) $class" >&! /dev/console
  /bin/dd if="$out"
  /bin/rm -f "$out"
  exit 0
else
  echo "$0 ($$) -- OUTPUT FAILURE $*" >&! /dev/console
  /bin/dd if="$file"
  exit 1
endif
