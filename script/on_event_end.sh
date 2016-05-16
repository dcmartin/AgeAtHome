#!/bin/tcsh
set WWW="http://www.dcmartin.com/CGI"
set APP="aah"
set API="stats"
set DIR="/var/lib/motion"

echo "+++ BEGIN: $0 $*" `date` >& /dev/stderr

if (! $?DEVICE_NAME) then
    echo "+++ STATUS: $0" `date` "no DEVICE_NAME specified">& /dev/stderr
endif

#
# timing directions
#
set INTERVAL=15
set TTL = 1800
set SECONDS = `date +%s`
set DATE = `echo $SECONDS \/ $TTL \* $TTL | bc`

#
# CLI arguments
#
set EVENT_ID = $argv[1]
set YEAR = $argv[2]
set MONTH = $argv[3]
set DAY = $argv[4]
set HOUR = $argv[5]
set MINUTE = $argv[6]
set SECOND = $argv[7]

set EVENT = "$DIR/$EVENT_ID.json"

set INDEX = `echo "$YEAR" "$MONTH" "$DAY" "$HOUR" "$MINUTE" "$SECOND" | \
    gawk -v interval="$INTERVAL" '{ m=$4*60+$5; m/=interval; \
    	t=mktime(sprintf("%4d %2d %2d %2d %2d %2d", $1, $2, $3, $4, $5, $6)); \
	printf "{ \"interval\":\"%d\",\"AMPM\":\"%s\",\"week\":\"%d\",\"day\":\"%s\" }", \
	    m, \
	    strftime("%p",t),\
	    strftime("%U",t),\
	    strftime("%w",t) }'`

echo "+++ STATUS: $0" `date` "$INDEX" >& /dev/stderr

# get event time series
set interval = `echo "$INDEX" | jq '.interval' | sed 's/"//g'`
set ampm = `echo "$INDEX" | jq '.AMPM' | sed 's/"//g'`
set week = `echo "$INDEX" | jq '.week' | sed 's/"//g'`
set day = `echo "$INDEX" | jq '.day' | sed 's/"//g'`

#
# get last X intervals velocity and acceleration
#

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
	    echo "+++ STATUS: $0" `date` "$CLASS under minimum score ($SCORES[$i])" >& /dev/stderr
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
	    echo "+++ STATUS: $0" `date` "waiting on $MODEL" >& /dev/stderr
	    while ( ! -e "$MODEL" )
		sleep 5
	    end
	else
	    # use newest old model
	    set MODEL = "$OLD_MODEL[1]"
	    # remove oldest model
	    if ($#OLD_MODEL > 1) then
		echo "+++ STATUS: $0" `date` "removing $OLD_MODEL[2-]" >& /dev/stderr
		rm -f $OLD_MODEL[2-]
	    endif
	endif
    endif
    if (! -e "$MODEL" ) then
	echo "+++ STATUS: $0" `date` "NO $MODEL" >& /dev/stderr
	exit
    endif

    set CLASS_COUNTS = "$DIR/$DEVICE_NAME-$CLASS-counts.$DATE.json"
    if (! -e "$CLASS_COUNTS") then
	set OLDCLASS_COUNTS = `ls -1t $DIR/$DEVICE_NAME-$CLASS-counts.*.json`
	rm -f "$OLDCLASS_COUNTS"
	# get counts for all days and all intervals
	jq -c '.days[].intervals[].count' "$MODEL" | sed 's/"//g' | gawk 'BEGIN { t = 0; c = 0; s = 0 } { t++; if ($1 > 0) { c++; s += $1; m = s/c; vs += ($1 - m)^2; v=vs/c} } END { sd = sqrt(v/c); printf "{\"count\":\"%d\",\"non-zero\":\"%d\",\"sum\":\"%d\",\"mean\":\"%f\",\"stdev\":\"%f\"}\n", t, c, s, m, sd  }' > "$CLASS_COUNTS"

	echo "+++ STATUS: $0" `date` `jq . $CLASS_COUNTS` >& /dev/stderr
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

cat "$EIC"

#
# test condtionals
#
@ i = 1
foreach CLASS ( $CLASSES )
    @ i++
end

echo "+++ END: $0" `date` $EIC >& /dev/stderr
