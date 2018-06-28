#!/bin/tcsh -b

setenv DEBUG
setenv VERBOSE

##
## DEVICE_NAME only specified in production
##

if ($?DEVICE_NAME == 0) then
  setenv MOTION_TARGET_DIR /var/lib/motion
  setenv MOTION_INTERVAL 30
  setenv MQTT_HOST 192.168.1.40
  setenv MQTT_ON true
  setenv AAH_LOCATION test
  setenv DEVICE_NAME cold_test
endif

#
# on_event_end.sh %v %Y %m %d %H %M %S
#
# %v - Event number. An event is a series of motion detections happening with less than 'gap' seconds between them. 
# %Y - The year as a decimal number including the century. 
# %m - The month as a decimal number (range 01 to 12). 
# %d - The day of the month as a decimal number (range 01 to 31).
# %H - The hour as a decimal number using a 24-hour clock (range 00 to 23)
# %M - The minute as a decimal number (range 00 to 59). 
# %S - The second as a decimal number (range 00 to 61). 

if ($?DEBUG) echo "$0:t $$ -- START" `date` >&! /dev/stderr

###
### dateutils REQUIRED
###

if ( -e /usr/bin/dateutils.dconv ) then
   set dateconv = /usr/bin/dateutils.dconv
else if ( -e /usr/local/bin/dateconv ) then
   set dateconv = /usr/local/bin/dateconv
else
  echo "No date converter; install dateutils" &>2
  exit 1
endif

##
## PROCESS MOTION_INTERVAL
##

if ($?MOTION_TARGET_DIR && $?MOTION_INTERVAL) then
  set DIR = $MOTION_TARGET_DIR
  set jsons = ( `echo "$DIR"/*.json` )
  set jpgs = ( `echo "$DIR"/*.jpg` )

  set LAST = `echo "$jsons[$#jsons]:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
  set LAST = `$dateconv -i '%Y%m%d%H%M%S' $LAST -f "%s"`
  @ last = $LAST - $MOTION_INTERVAL

  if ($#jsons) then
    @ p = $#jsons - 1
    if ($p) then
      set PREV = `echo "$jpgs[$p]:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
      set PREV = `$dateconv -i '%Y%m%d%H%M%S' $PREV -f "%s"`
      @ DELAY = $LAST - $PREV
      if ($?VERBOSE) echo "$0:t $$ -- previous JSON is $DELAY seconds older" >& /dev/stderr
    else
      if ($?DEBUG) echo "$0:t $$ -- no previous JSON; $#jsons" >& /dev/stderr
    endif
  else
    if ($?DEBUG) echo "$0:t $$ -- zero JSON found" >& /dev/stderr
    goto done
  endif 

  @ i = $#jpgs
  set frames = ()
  while ($i)
    set NOW = `echo "$jpgs[$i]:t:r" | sed 's/\(.*\)-.*-.*/\1/'`
    set NOW = `$dateconv -i '%Y%m%d%H%M%S' $NOW -f "%s"`

    @ INTERVAL = $NOW - $LAST
    if ( $INTERVAL > $MOTION_INTERVAL) then
      # too new
      if ($?VERBOSE) echo "$0:t $$ -- $jpgs[$i] - INTERVAL $INTERVAL > $MOTION_INTERVAL; too new" >& /dev/stderr
    else if ( $INTERVAL >= 0) then
      if ($?VERBOSE) echo "$0:t $$ -- $jpgs[$i] - INTERVAL = $INTERVAL; adding frame" >& /dev/stderr
      # add frames in order since processing last to first
      set frames = ( $jpgs[$i] $frames )
    else
      if ($?VERBOSE) echo "$0:t $$ -- $jpgs[$i] - INTERVAL = $INTERVAL; breaking at $i" >& /dev/stderr
      break
    endif
    @ i--
  end
else
  if ($?DEBUG) echo "$0:t $$ -- MOTION_TARGET_DIR ($?MOTION_TARGET_DIR) || MOTION_INTERVAL ($?MOTION_INTERVAL) not defined" >& /dev/stderr
endif

###
### TEST FRAMES
###

if ($#frames) then
  if ($?VERBOSE) echo "$0:t $$ -- frames = $#frames"` >& /dev/stderr
else
  if ($?DEBUG) echo "$0:t $$ -- zero frames"` >& /dev/stderr
  goto done
endif

###
### PROCESS FRAMES
###

setenv TMP /tmp
setenv TMP $TMP/$0:t:r.$$
mkdir -p $TMP
onintr cleanup

set LASTJSON = $jsons[$#jsons]

if ($?DEBUG) echo "$0:t $$ -- LASTJPG = $frames[$#frames]; LASTJSON = $LASTJSON"` >& /dev/stderr

##
## VARIABLE PROCESSING
##

# fuzzy matching for comparison metric
@ fuzz = 20

# 
set blur = "0x3"

# threshold comparison
@ blur = 10
@ low = 20
@ high = 50

# frames per second
@ fps = 10

# delay (milliseconds)
set ms = `echo "$fps / 60.0 * 100.0" | bc -l`
@ ms = $ms:r

##
## MAKE AVERAGE FRAME
##
set average = $TMP/$LASTJSON:t:r-average.png
convert $frames -average $average
if ($?VERBOSE) echo "$0:t $$ -- average = $average"

## optionally make blended image
if ($?NO_BLEND_IMAGES == 0) then
  set blend = $TMP/$LASTJSON:t:r-blend.png
  convert $frames -compose blend -define 'compose:args=50' -alpha on -composite $blend
endif

##
## CALCULATE FRAME CHANGES & AVERAGE PIXEL CHANGE
##

@ t = 0
@ i = 1
set ps = ()
set diffs = ()
while ( $i <= $#frames )
    set diffs = ( $diffs $TMP/$frames[$i]:t-mask.jpg )
    # calculate difference
    set p = ( `compare -metric fuzz -fuzz "$fuzz"'%' $frames[$i] $average -compose src -highlight-color white -lowlight-color black $diffs[$#diffs] |& awk '{ print $1 }'` )
    if ($?VERBOSE) echo "$0:t $$ -- DIFF $frames[$i]:t:r; change = $p; $diffs[$#diffs]" >& /dev/stderr
    # keep track of differences
    set ps = ( $ps $p:r )
    @ t += $ps[$#ps]
    @ i++
end
# CALCULATE AVERAGE CHANGE
@ a = ( `echo "$t / $#ps" | bc` )
if ($?DEBUG) echo "$0:t $$ -- AVERAGE: ($a) @ FUZZ: $fuzz %" >& /dev/stderr

##
## COLLECT KEY FRAMES (PIXEL CHANGE > AVERAGE)
##

if ($?KEY_FRAMES) then
  set kframes = ()
  set kdiffs = ()
  @ i = 1
  while ( $i <= $#diffs )
    # keep track of frames w/ change > average
    if ($ps[$i] > $a) then
      if ($?VERBOSE) echo "$0:t $$ -- KEY $frames[$i]:t:r ($i)" >& /dev/stderr
      set kframes = ( $frames[$i] $kframes )
      set kdiffs = ( $diffs[$i] $kdiffs )
    endif
    @ i++
  end
  if ($?DEBUG) echo "$0:t $$ -- total key frames $#kframes" >& /dev/stderr
else
  set kframes = ( $frames )
  set kdiffs = ( $diffs )
endif

##
## COMPOSITE KEY FRAMES AGAINST AVERAGE USING MASK
##

set composite = $TMP/$LASTJSON:t:r-composite.jpg
if ($?NO_COMPOSITE == 0) then
  cp "$average" "$composite"
  @ i = 1
  while ( $i <= $#kframes )
    set c = $composite:r.$i.jpg
    if ($?VERBOSE) echo "$0:t $$ -- composite $kframes[$i] $composite $c" >& /dev/stderr
    composite $kframes[$i] $composite $diffs[$i] $c
    mv -f $c $composite
    @ i++
  end
  if ($?DEBUG) echo "$0:t $$ -- COMPOSITE: $composite" >& /dev/stderr
else
  if ($?VERBOSE) echo "$0:t $$ -- NO COMPOSITE" >& /dev/stderr
endif

##
## PRODUCE ANIMATED GIF of FRAMES
##

set gif = $TMP/$LASTJSON:t:r.gif
convert -loop 0 -delay $ms $kframes $gif

# optionally produce animated mask
if ($?GIF_MASK) then
  set mask = $TMP/$LASTJSON:t:r.mask.gif
  convert -loop 1 -delay $ms $kdiffs $mask
endif
rm -f $diffs

##
## POST TO MQTT
##

if ($?MQTT_ON && $?MQTT_HOST && $?AAH_LOCATION) then
  set MQTT_TOPIC = 'image-composite/'"$AAH_LOCATION"
  mosquitto_pub -i "$DEVICE_NAME" -r -h "$MQTT_HOST" -t "$MQTT_TOPIC" -f "$composite"
  set MQTT_TOPIC = 'image-animated/'"$AAH_LOCATION"
  mosquitto_pub -i "$DEVICE_NAME" -r -h "$MQTT_HOST" -t "$MQTT_TOPIC" -f "$gif"
endif

cleanup:
  rm -fr $TMP

done:
  if ($?DEBUG) echo "$0:t $$ -- FINISH" `date` >& /dev/stderr
