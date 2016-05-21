#!/bin/csh -f
echo "+++ BEGIN: $0 $* ($$)" `date` >& /dev/stderr
# timing directions
set INTERVAL = 15
set TTL = 1800
set SECONDS = `date +%s`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`
set PERIOD = `echo $SECONDS \/ $INTERVAL \* $INTERVAL | bc`

#
if ($?DEVICE_NAME == 0) then
    echo "+++ STATUS: $0 ($$)" `date` "no DEVICE_NAME specified" >& /dev/stderr
    setenv DEVICE_NAME "rough-fog"
endif

set WWW="http://www.dcmartin.com/CGI"
set APP="aah"
set API="stats"
set DIR="/var/lib/motion"

#
# CLI arguments
#
set SEQNO = $argv[1]
set YEAR = $argv[2]
set MONTH = $argv[3]
set DAY = $argv[4]
set HOUR = $argv[5]
set MINUTE = $argv[6]
set SECOND = $argv[7]

if (-e /tmp/$0:t.$PERIOD) then
    echo "*** TOO SOON ***"
else
    rm -f /tmp/$0:t.*
    touch /tmp/$0:t.$PERIOD
endif


set EVENT_ID = ( `echo "$YEAR $MONTH $DAY $HOUR $MINUTE $SECOND $SEQNO" | awk '{ printf("%04d%02d%02d%02d%02d%02d-%02d", $1, $2, $3, $4, $5, $6, $7) }'` )

set EVENT = ( `ls -1t "$DIR/$EVENT_ID"-*.json` )

echo "+++ STATUS: $0 ($$)" `date` "EVENT_ID: $EVENT_ID events = $EVENT" >& /dev/stderr

if ($#EVENT > 0) then
    set EVENT = $EVENT[1]
else
    echo "*** ERROR: $0" `date` "NO EVENT ($EVENT)" >& /dev/stderr
    exit
endif

set INDEX = `echo "$YEAR" "$MONTH" "$DAY" "$HOUR" "$MINUTE" "$SECOND" | \
    gawk -v interval="$INTERVAL" '{ m=$4*60+$5; m/=interval; \
    	t=mktime(sprintf("%4d %2d %2d %2d %2d %2d", $1, $2, $3, $4, $5, $6)); \
	printf "{ \"interval\":\"%d\",\"AMPM\":\"%s\",\"week\":\"%d\",\"day\":\"%s\" }", \
	    m, \
	    strftime("%p",t),\
	    strftime("%U",t),\
	    strftime("%w",t) }'`

echo "+++ STATUS: $0 ($$)" `date` "$INDEX" >& /dev/stderr

# get event time series
set interval = `echo "$INDEX" | jq '.interval' | sed 's/"//g'`
set ampm = `echo "$INDEX" | jq '.AMPM' | sed 's/"//g'`
set week = `echo "$INDEX" | jq '.week' | sed 's/"//g'`
set day = `echo "$INDEX" | jq '.day' | sed 's/"//g'`

#
# get prior events
#

echo "+++ STATUS: $0 ($$)" `date` "EVENT = $EVENT" >& /dev/stderr

set PRIOR_ID = ( `echo "$YEAR $MONTH $DAY $HOUR" | awk '{ printf("%04d%02d%02d%02d", $1, $2, $3, $4) }'` )

set PRIOR = ( `ls -1t "$DIR/$PRIOR_ID"*.json | sed "s|$DIR/\(.*\)-.*-.*.json|\1|" | sort -n` )

echo "+++ STATUS: $0 ($$)" `date` "THIS HOUR = $#PRIOR ( $PRIOR )" >& /dev/stderr

@ count = 0
set prior = ()
set eic = ()
foreach k ( $PRIOR )
   set json = $DIR/$k-*-*.json
   set h = `jq '.hour' $json | sed 's/"//g'`
   set m = `jq '.minute' $json | sed 's/"//g'`
   set t = `echo "($h*60+$m)/15" | bc`
   set d = `echo $MINUTE - $m | bc`

   if ($t == $interval && $d > 0) then
       echo " $json [$t $h $m]($d)"

       set l = $DIR/$DEVICE_NAME-$k-*-*.json
       if ($#l > 1) then
	   set prior = ( $prior $json )
	   set eic = ( $eic $l )
       endif

       @ count++
   endif
end

echo "+++ STATUS: $0 ($$)" `date` "THIS INTERVAL = $#prior ( $prior )" >& /dev/stderr

set class = `jq -c '.alchemy.text' $EVENT | sed 's/"//g'`
@ e = 1
foreach t ( $prior )
    set tc = `jq -c '.alchemy.text' $t | sed 's/"//g'`

    if ($tc == $class) then
	echo `jq '.alchemy.score' $t | sed 's/"//g'` >>! "/tmp/$0.$$"
	set dow = `jq '.day' $eic[$e] | sed 's/"//g'`
	set int = `jq '.interval' $eic[$e] | sed 's/"//g'`
	if ($int != $interval) then
	    echo "ERROR - mismatch interval ($int != $interval)"
	    exit
	endif

    endif
    @ e++
end
if (-e "/tmp/$0.$$") then
    set cstats  = `awk 'BEGIN { c=0; s=0; m=0; vs=0; v=0 } { c++; s+=$1; m=s/c; vs+=($1-m)^2; v=vs/c } END { sd=sqrt(v); printf("%d %f %f",c,m,sd) }' "/tmp/$0.$$"`
    rm "/tmp/$0.$$"

    set models = ( `ls -1t $DIR/$DEVICE_NAME-$class.*.json | sed "s|$DIR/$DEVICE_NAME-$class\.\(.*\).*\.json|\1|" | sort -nr` )
    if ($#models > 0) then
	set model =  $DIR/$DEVICE_NAME-$class.$models[1].json
	set mstats = `jq '.days[].intervals['$interval'].count' $model | sed 's/"//g' | awk 'BEGIN { c=0; s=0; m=0; v=0; vs=0 } { c++; s+=$1; m=s/c; vs+=($1-m)^2; v=vs/c } END { sd=sqrt(v); printf("%d %f %f",c,m,sd) }'`
	set count = `jq '.days['$dow'].intervals['$interval'].count'  $model | sed 's/"//g'`
	set mean = `jq '.days['$dow'].intervals['$interval'].mean' $model | sed 's/"//g'`
	set stdev = `jq '.days['$dow'].intervals['$interval'].stdev' $model | sed 's/"//g'`

	# echo $model
	echo "*** MODEL: $0 " `date` day=$dow interval=$interval \( $cstats \) $count \( $mstats \) $mean $stdev >& /dev/stderr
    else
	echo "*** NO MODEL: $models" >& /dev/stderr
    endif
endif
# jq -c '.' $eic

#
# get classifiers & scores
#
set ACLASSES =( `jq '.alchemy|.text' "$EVENT" | sed 's/"//g'` )
set VCLASSES = ( `jq '.visual.scores[]|.name' "$EVENT" | sed 's/"//g'` )
set ASCORES = ( `jq '.alchemy|.score' "$EVENT" | sed 's/"//g'` )
set VSCORES = ( `jq '.visual.scores[]|.score' "$EVENT" | sed 's/"//g'` )

#
# get classifier statistics
#

# all classifiers and scores
set CLASSES = ( $ACLASSES $VCLASSES )
set SCORES = ( $ASCORES $VSCORES )

# define ENTITY in context (to model)
set EIC = "$DIR/$DEVICE_NAME-$EVENT_ID-EIC.json"

# define entity time-series (from EVENT)
echo '{ "event":"'$EVENT_ID'","week":"'$week'","AMPM":"'$ampm'","day":"'$day'","interval":"'$interval'","classifiers":[' >! "$EIC"

echo "+++ STATUS: $0 ($$)" `date` "$CLASSES" >& /dev/stderr

@ i = 0
foreach CLASS ( $CLASSES )
    if ($CLASS == "NO_TAGS") continue;
    if ($CLASS == \"\") continue;

    @ i++
    if ($i > 1) echo ',' >> "$EIC"
    # if environment variable is specified
    if ($?MINIMUM_CLASSIFIER_SCORE) then
	set TF = `echo "$SCORES[$i] < $MINIMUM_CLASSIFIER_SCORE" | bc`

	if ($TF) then
	    echo "+++ STATUS: $0 ($$)" `date` "$CLASS under minimum score ($SCORES[$i])" >& /dev/stderr
	    continue;
	endif
    endif

    # get statistical model for this classifier
    set MODEL = "$DIR/$DEVICE_NAME-$CLASS.$DATE.json"
    if ( ! -e "$MODEL" ) then
	# find old statistical models
	set OLD_MODEL = `ls -1t "$DIR/$DEVICE_NAME-$CLASS".*.json`
	# retrieve new/updated statistical model
	( curl -o "$MODEL.$$" -s -L "$WWW/aah-stats.cgi?db=$DEVICE_NAME&id=$CLASS" ; mv "$MODEL.$$" "$MODEL" ) &
	# if there are no old models
	if ( $#OLD_MODEL == 0 ) then
	    echo "+++ STATUS: $0 ($$)" `date` "waiting on $MODEL" >& /dev/stderr
	    while ( ! -e "$MODEL" )
		sleep 5
	    end
	    set err = `jq '.error' "$MODEL" | sed 's/"//g'`
	    if ($err != "null") then
		rm -f "$MODEL"
	    endif
	else
	    # use newest old model
	    set MODEL = "$OLD_MODEL[1]"
	    # remove oldest model
	    if ($#OLD_MODEL > 1) then
		echo "+++ STATUS: $0 ($$)" `date` "removing $OLD_MODEL[2-]" >& /dev/stderr
		rm -f $OLD_MODEL[2-]
	    endif
	endif
    endif
    if (! -e "$MODEL" ) then
	echo "+++ STATUS: $0 ($$)" `date` "NO $MODEL" >& /dev/stderr
	continue
    endif

    set CLASS_COUNTS = "$DIR/$DEVICE_NAME-$CLASS-counts.$DATE.json"
    if (! -e "$CLASS_COUNTS") then
	set OLDCLASS_COUNTS = `ls -1t $DIR/$DEVICE_NAME-$CLASS-counts.*.json`
	rm -f "$OLDCLASS_COUNTS"
	# get counts for all days and all intervals
	jq -c '.days[].intervals[].count' "$MODEL" | sed 's/"//g' | gawk 'BEGIN { t = 0; c = 0; s = 0 } { t++; if ($1 > 0) { c++; s += $1; m = s/c; vs += ($1 - m)^2; v=vs/c} } END { sd = sqrt(v/c); printf "{\"count\":\"%d\",\"non-zero\":\"%d\",\"sum\":\"%d\",\"mean\":\"%f\",\"stdev\":\"%f\"}\n", t, c, s, m, sd  }' > "$CLASS_COUNTS"

	echo "+++ STATUS: $0 ($$)" `date` `jq . $CLASS_COUNTS` >& /dev/stderr
    endif

    # get entity time-series context (n.b. number of weeks)

    echo -n '{ "class":"'$CLASS'",' >> "$EIC"
    echo -n '"score":"'$SCORES[$i]'",' >> "$EIC"
    echo -n '"model":' `jq '.days['$day'].intervals['$interval']' "$MODEL"` ',' >> "$EIC"
    echo -n '"weeks":' `jq '.days['$day'].weeks' "$MODEL"` ',' >> "$EIC"
    echo -n '"nweek":' `jq '.days['$day'].nweek' "$MODEL"` ',' >> "$EIC"
    echo -n '"intervals":' `jq '.' "$CLASS_COUNTS"` >> "$EIC"
    echo -n '}' >> "$EIC"
end
echo ']}' >> "$EIC"

jq -c . "$EIC"

#
# test condtionals
#
@ i = 1
foreach CLASS ( $CLASSES )
    @ i++
end

set seconds = `date +%s`
set elapsed = ( `echo "$seconds - $SECONDS" | bc` )
echo "+++ END: $0 ($$)" `date` " elapsed $elapsed " $EIC >& /dev/stderr
