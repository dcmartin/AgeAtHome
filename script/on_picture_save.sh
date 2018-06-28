#!/bin/bash

# DEBUG=true
# VERBOSE=true

###
### dateutils REQUIRED
###

if [ -e /usr/bin/dateutils.dconv ]; then
   dateconv="/usr/bin/dateutils.dconv"
elif [ -e /usr/local/bin/dateconv ]; then
   dateconv="/usr/local/bin/dateconv"
else
  echo "No date converter; install dateutils" >&2
  exit 1
fi

if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- BEGIN: $*" $(date) >&2; fi

# get arguments
EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3
MOTION_MIDX=$4
MOTION_MIDY=$5
MOTION_WIDTH=$6
MOTION_HEIGHT=$7

if [ -z "${IMAGE_FILE}" ]; then
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- no image file ($*)" $(date) >&2; fi
  exit
else
  # drop prefix path
  IMAGE_ID=`echo "${IMAGE_FILE##*/}"`
  # drop extension
  IMAGE_ID=`echo "${IMAGE_ID%.*}"`
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- event ${EVENT}; at (${MOTION_MIDX},${MOTION_MIDY},${MOTION_WIDTH},${MOTION_HEIGHT}); in ${IMAGE_ID}" $(date) >&2; fi
fi

##
## POST IMAGE 
##
if [ -n "${MQTT_ON}" ] && [ -s "${IMAGE_FILE}" ] && [ -n "${MQTT_HOST}" ]; then
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MQTT post to host $MQTT_HOST on topic image/${AAH_LOCATION}" >&2; fi
  mosquitto_pub -i "${DEVICE_NAME}" -h "${MQTT_HOST}" -t 'image/'"${AAH_LOCATION}" -f "${IMAGE_FILE}"
fi

##
## PROCESS MOTION_INTERVAL
##

if [ -n "${MOTION_INTERVAL}" ]; then
  DIR=$(echo "${IMAGE_FILE%/*}")
  JSONS=($(echo "${DIR}"/*.json))
  JPGS=($(echo "${DIR}"/*.jpg))
  if [[ ${#JPGS[@]} -ge 2 ]]; then
    NOW=$(echo "${#JPGS[@]} - 1" | bc)
    NOW="${JPGS[${NOW}]##*/}"
    LAST=$(echo "${#JSONS[@]} - 2" | bc)
    LAST="${JSONS[${LAST}]##*/}"
    if [ -n "${LAST}" ] && [ -n "${NOW}" ]; then
      NOW=$(echo "${NOW%.*}")
      NOW=$(echo $NOW| sed 's/\(.*\)-.*-.*/\1/')
      LAST=$(echo "${LAST%.*}")
      LAST=$(echo $LAST| sed 's/\(.*\)-.*-.*/\1/')
      if [ -n "${LAST}" ] && [ -n "${NOW}" ]; then
	NOW=$($dateconv -i '%Y%m%d%H%M%S' $NOW -f "%s")
	LAST=$($dateconv -i '%Y%m%d%H%M%S' $LAST -f "%s")
	if [ -n "${LAST}" ] && [ -n "${NOW}" ]; then
	  INTERVAL=$(echo "$NOW - $LAST" | bc)
	  if [ -n "${INTERVAL}" ]; then
	    if [ $INTERVAL -le $MOTION_INTERVAL ]; then
	      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- SKIPPING ${INTERVAL} <= ${MOTION_INTERVAL}" >&2; fi
	      exit
	    else
	      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- PROCEEDING ${INTERVAL} > ${MOTION_INTERVAL}" >&2; fi
	    fi
	  else
	    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- INTERVAL not defined" >&2; fi
	  fi
	else
	  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- NOW/LAST not defined" >&2; fi
	fi
      else
	if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- NOW/LAST not defined" >&2; fi
      fi
    else
      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- NOW/LAST not defined" >&2; fi
    fi
  else
    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- nothing old" >&2; fi
  fi
else
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MOTION_INTERVAL not defined" >&2; fi
fi

##
## CALCULATE MOTION BOX
##
# X coordinate in pixels of the center point of motion. Origin is upper left corner.
# Y coordinate in pixels of the center point of motion. Origin is upper left corner and number is positive moving downwards 

MOTION_X=`echo "${MOTION_MIDX} - ( ${MOTION_WIDTH} / 2 )" | bc`
if [[ ${MOTION_X} -lt 0 ]]; then MOTION_X=0; fi
MOTION_Y=`echo "${MOTION_MIDY} - ( ${MOTION_HEIGHT} / 2 )" | bc`
if [[ ${MOTION_Y} -lt 0 ]]; then MOTION_Y=0; fi
IMAGE_BOX="${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}"

if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- EVENT: ${EVENT} BOX: ${IMAGE_BOX} X: ${MOTION_X} Y: ${MOTION_Y} W: ${MOTION_WIDTH} H: ${MOTION_HEIGHT}" >&2; fi

##
## PREPARE CLASSIFICATION OUTPUT
##

# assign output file for JSON
OUTPUT="${IMAGE_FILE%.*}.json"

##
## VISUAL RECOGNITION
##

# EXAMPLE
# {"custom_classes":8,"images":[{"classifiers":[{"classes":[{"class":"cat","score":0.0440043},{"class":"david","score":0.682563},{"class":"dog","score":0.0426537},{"class":"ellen","score":0.0450058},{"class":"hali","score":0.0435302},{"class":"ian","score":0.936221},{"class":"keli","score":0.0293902},{"class":"riley","score":0.539559}],"classifier_id":"roughfog_879989469","name":"roughfog_879989469"},{"classes":[{"class":"kitchen","score":0.63,"type_hierarchy":"/room/kitchen"},{"class":"room","score":0.68},{"class":"people","score":0.573,"type_hierarchy":"/person/people"},{"class":"person","score":0.628},{"class":"cafe","score":0.557,"type_hierarchy":"/building/restaurant/cafe"},{"class":"restaurant","score":0.56},{"class":"building","score":0.56},{"class":"computer user","score":0.556,"type_hierarchy":"/person/computer user"},{"class":"wheelhouse","score":0.554,"type_hierarchy":"/room/compartment/wheelhouse"},{"class":"compartment","score":0.554},{"class":"reddish brown color","score":0.64},{"class":"chestnut color","score":0.623}],"classifier_id":"default","name":"default"}],"image":"input.jpg"}],"images_processed":1}
#

# create VR_OUTPUT JSON filename
VR_OUTPUT="${IMAGE_FILE%.*}-vr.json"
# proceed iff all
if [ -z "${VR_OFF}" ] && [ -n "${VR_APIKEY}" ] && [ -n "${VR_VERSION}" ] && [ -n "${VR_DATE}" ] && [ -n "${VR_URL}" ]; then
    if [ -z "${VR_CLASSIFIER}" ]; then
	VR_CLASSIFIER="default"
    else
	# custom classifier goes first; top1 from first classifier is encoded as alchemy
        VR_CLASSIFIER="${VR_CLASSIFIER},default"
    fi
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- Watson Visual Recognition using classifier ${VR_CLASSIFIER}"; fi
    # make the call
    curl -s -q -f -L \
        --header "X-Watson-Learning-Opt-Out: true" \
        -F "images_file=@$IMAGE_FILE" \
	-o "${VR_OUTPUT}" \
	"$VR_URL/$VR_VERSION/classify?api_key=$VR_APIKEY&classifier_ids=$VR_CLASSIFIER&threshold=0.0&version=$VR_DATE"
    if [ -s "${VR_OUTPUT}" ]; then
	if [ -n "${VERBOSE}" ]; then echo  "${0##*/} $$ -- ${IMAGE_ID} -- SUCCESS: Watson Visual Recognition"; fi
    else
	if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- FAILURE: Watson Visual Recognition"; fi
    fi
else
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- DISABLED: Watson Visual Recognition is not enabled"; fi
fi

##
## DIGITS
##

# EXAMPLE
# {"predictions":[["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=road",90.09],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=motorcycle",9.76],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=car",0.06],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=builder",0.03],["http://www.dcmartin.com/CGI/aah-index.cgi?db=quiet-water&ext=sample&class=martin c70",0.02]]}

# create DG_OUTPUT JSON filename
DG_OUTPUT="${IMAGE_FILE%.*}-dg.json"
if [ -n "${DIGITS_SERVER_URL}" ] && [ -n "${DIGITS_JOB_ID}" ]; then
  CMD="models/images/classification/classify_one.json"
  # get inference
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- DIGITS using classifier ${DIGITS_JOB_ID}"; fi
  curl -s -q -f -L -X POST \
      -F "image_file=@$IMAGE_FILE" \
      -F "job_id=${DIGITS_JOB_ID}" \
      -o "${DG_OUTPUT}" \
      "${DIGITS_SERVER_URL}/${CMD}"
  # debug
  if [ -s "${DG_OUTPUT}" ]; then
      jq -c '.predictions[]' "${DG_OUTPUT}" \
	  | sed 's/.*http.*class=\([^"]*\)",\(.*\)\]/\1,'"$DIGITS_JOB_ID"',\2/' \
	  | sed 's/ /_/g' \
	  | awk -F, 'BEGIN { n=0 } { if (n>0) printf(","); n++; printf("{\"classifier_id\":\"%s\",\"name\":\"%s\",\"score\":%1.4f}", $1, $2, $3/100)}' > "${DG_OUTPUT}.$$"
      mv "${DG_OUTPUT}.$$" "${DG_OUTPUT}"
      if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- SUCCESS: DIGITS"; fi
  else
      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- FAILURE: DIGITS" >&2; fi
  fi
else
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- DISABLED: DIGITS" >&2; fi
fi

##
## COMBINE OUTPUT
##

if [ -s "${VR_OUTPUT}" ]; then
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- processing WVR output" >&2; fi
    # encode top1 across custom (iff specified above) and default classifiers; decorate with source: default, <hierarchy:default>, custom classifier_id
    jq -c \
      '[.images[0]|.classifiers[]|.classifier_id as $cid|.classes|sort_by(.score)[-1]|{text:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]|sort_by(.score)[-1]' \
      "${VR_OUTPUT}" > "${OUTPUT}.alchemy.$$"
    # process WVR into "market basket" with "name" used to indicate source (default, <custom-id> or hierarchy (from default)
    jq -c \
      '.images[0]|{image:.image,scores:[.classifiers[]|.classifier_id as $cid|.classes[]|{classifier_id:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]}' \
      "${VR_OUTPUT}" > "${OUTPUT}.visual.$$"

    # test if DIGITS too
    if [ -s "${DG_OUTPUT}" ]; then
	if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- joining DIGITS output" >&2; fi
	sed 's/\(.*\)/{"alchemy":\1,"visual":/' "${OUTPUT}.alchemy.$$" | paste - "${OUTPUT}.visual.$$" | sed 's/]}$/,/' | paste - "${DG_OUTPUT}" | sed 's/$/]}}/' > "${OUTPUT}.$$"
    else
	if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- processing calculating TOP1 from WVR (no DIGITS)" >&2; fi
        # concatenate -- "alchemy" is _really_ "top1" and "visual" is _really_ the entire "set" of classifiers
	sed 's/\(.*\)/{"alchemy":\1,"visual":/' "${OUTPUT}.alchemy.$$" | paste - "${OUTPUT}.visual.$$" | sed 's/]}$/]}}/' > "${OUTPUT}.$$"
    fi
    # process consolidated scores into sorted list
    if [ -s "${DG_OUTPUT}" ]; then
	if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- calculating TOP1 from WVR & DIGITS" >&2; fi
        # pick top1 across all classification results; sorted by score
        TOP1=$(jq -r '.visual.scores|sort_by(.score)[-1]|{"text":.classifier_id,"name":.name,"score":.score}' "${OUTPUT}.$$")
	# change output to indicate (potentially) new top1
	cat "${OUTPUT}.$$" | jq '.alchemy='"${TOP1}" > "$OUTPUT.$$.$$"
	if [ -s "$OUTPUT.$$.$$" ]; then
	  mv "${OUTPUT}.$$.$$" "${OUTPUT}.$$"
	fi
	rm -f "${OUTPUT}.$$.$$"
    fi
    # create (and validate) output
    jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"
    # cleanup
    rm -f "${OUTPUT}.alchemy.$$" "${OUTPUT}.visual.$$"
elif [ -s "${DG_OUTPUT}" ]; then
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- calculating TOP1 from DIGITS (no WVR)" >&2; fi
    TOP1=$(echo '[' | paste - "${DG_OUTPUT}" | sed 's/$/]/' | jq '.|sort_by(.score)[-1]|{"text":.classifier_id,"name":.name,"score":.score}')
    CLASSIFIERS=$(echo '[' | paste - "${DG_OUTPUT}" | sed 's/$/]/' | jq '.|sort_by(.score)')
    echo '{"alchemy":'"${TOP1}"',"visual":{"image":"'"${IMAGE_ID}.jpg"'","scores":{"classifiers":'"${CLASSIFIERS}"'}}}' >! "${OUTPUT}"
else
    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- ERROR: no classification output" >&2; fi
    echo '{ "alchemy":{"text":"NA","name":"NA","score":0},' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
    echo '}}' >> "${OUTPUT}"
fi
rm -f "${OUTPUT}.$$"


if [ ! -s "${OUTPUT}" ]; then
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- ERROR: no output from classification" >&2; fi
  exit
else
  # cleanup
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- classification:" $(jq -c '.' "${OUTPUT}") >&2; fi
  rm -f  "${VR_OUTPUT}" "${DG_OUTPUT}"
fi


##
## PROCESS OUTPUT
##

# add datetime and bounding box information
DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*/\1/"`
YEAR=`echo "${DATE_TIME}" | sed "s/^\(....\).*/\1/"`
MONTH=`echo "${DATE_TIME}" | sed "s/^....\(..\).*/\1/"`
DAY=`echo "${DATE_TIME}" | sed "s/^......\(..\).*/\1/"`
HOUR=`echo "${DATE_TIME}" | sed "s/^........\(..\).*/\1/"`
MINUTE=`echo "${DATE_TIME}" | sed "s/^..........\(..\).*/\1/"`
SECOND=`echo "${DATE_TIME}" | sed "s/^............\(..\).*/\1/"`
DATE=$(echo "${YEAR}/${MONTH}/${DAY} ${HOUR}:${MINUTE}:${SECOND}" | ${dateconv} -i "%Y/%M/%D %H:%M:%S" -f "%s")
SIZE=$(echo "${MOTION_WIDTH} * ${MOTION_HEIGHT}" | bc)

cat "${OUTPUT}" | \
    sed 's/^{/{"year":"YEAR","month":"MONTH","day":"DAY","hour":"HOUR","minute":"MINUTE","second":"SECOND","date":DATE,"size":SIZE,"imagebox":"IMAGE_BOX",/' | \
    sed "s/YEAR/${YEAR}/" | \
    sed "s/MONTH/${MONTH}/" | \
    sed "s/DAY/${DAY}/" | \
    sed "s/HOUR/${HOUR}/" | \
    sed "s/MINUTE/${MINUTE}/" | \
    sed "s/SECOND/${SECOND}/" | \
    sed "s/DATE/${DATE}/" | \
    sed "s/SIZE/${SIZE}/" | \
    sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
mv /tmp/OUTPUT.$$ "${OUTPUT}"

##
## CLOUDANT
##

if [ -z "${CLOUDANT_OFF}" ] && [ -s "${OUTPUT}" ] && [ -n "${CLOUDANT_URL}" ] && [ -n "${DEVICE_NAME}" ]; then
    DEVICE_DB=$(curl -q -s -f -L -X GET "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.db_name')
    if [ "${DEVICE_DB}" == "null" ]; then
        if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- creating database ${DEVICE_NAME}" >&2; fi
	SUCCESS=$(curl -q -s -f -L -X PUT "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.ok')
        if [ "${SUCCESS}" == "true" ]; then DEVICE_DB="${DEVICE_NAME}"; else DEVICE_DB=""; fi
    fi
    if [ ! -z "${DEVICE_DB}" ] && [ "${DEVICE_DB}" != "null" ]; then
      if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- database exists ${DEVICE_NAME}" >&2; fi
      SUCCESS=$(curl -q -s -f -L -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}" | jq '.ok')
      if [ "${SUCCESS}" == "true" ]; then
        if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- success posting database: ${DEVICE_NAME}" >&2; fi
      else
        if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- failure posting to database: ${DEVICE_NAME} ${SUCCESS}" >&2; fi
      fi
    else
      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- failure creating database: ${DEVICE_NAME}" >&2; fi
    fi
else
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- DISABLED: database (${DEVICE_NAME})" >&2; fi
fi


##
## get specifics from OUTPUT
##

IMAGE_BOX=$(jq -r '.imagebox' "${OUTPUT}")
CLASS=$(jq -r '.alchemy.text' "${OUTPUT}" | sed 's/ /_/g')
MODEL=$(jq -r '.alchemy.name' "${OUTPUT}" | sed 's/ /_/g')
SCORE=$(jq -r '.alchemy.score' "${OUTPUT}")
SCORES=$(jq -c '.visual.scores' "${OUTPUT}")
if [ -z "${SCORE}" ]; then SCORE='null'; fi
if [ -z "${SCORES}" ]; then SCORES='null'; fi

##
## POST to MQTT
##

if [ -n "${MQTT_ON}" ] && [ -n "${MQTT_HOST}" ] && [ -n "${CLASS}" ] && [ -n "${MODEL}" ] && [ -n "${SCORE}" ] && [ -n "${SCORES}" ]; then
  # post JSON
  WHAT='"class":"'"${CLASS}"'","model":"'"${MODEL}"'","score":'"${SCORE}"',"id":"'"${IMAGE_ID}"'","imagebox":"'"${IMAGE_BOX}"'","size":'"${SIZE}"',"scores":'"${SCORES}"
  MSG='{"device":"'"${DEVICE_NAME}"'","location":"'"${AAH_LOCATION}"'","date":'"${DATE}"','"${WHAT}"'}'
  MQTT_TOPIC='presence/'"${AAH_LOCATION}"'/'"${CLASS}"
  if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MQTT ${MSG} to ${MQTT_HOST} topic ${MQTT_TOPIC}" >&2; fi
  mosquitto_pub -i "${DEVICE_NAME}" -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -m "${MSG}"
fi

##
## ANNOTATE & CROP IMAGE
##

if image-annotate.csh "${IMAGE_FILE}" "${IMAGE_BOX}" "${CLASS}"; then
  COMPJPEG="${IMAGE_FILE%.*}".jpeg
  CROPJPEG="${IMAGE_FILE%.*}".crop.jpeg
  ANNOJPEG="${IMAGE_FILE%.*}".anno.jpeg
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- successfully composed: ${COMPJPEG}" >&2; fi
else
  if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- failure composing: ${COMPJPEG}" >&2; fi
fi

# test if annotated image created
if [ -n ${ANNOJPEG} ] && [ -s "${ANNOJPEG}" ]; then
    MQTT_TOPIC='image-annotated/'"${AAH_LOCATION}"
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MQTT ${ANNOJPEG} to ${MQTT_HOST} topic ${MQTT_TOPIC}" >&2; fi
    mosquitto_pub -i "${DEVICE_NAME}" -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${ANNOJPEG}"
else
    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- no annotated image: ${ANNOJPEG}" >&2; fi
fi

# test if cropped image created as side-effect
if [ -n ${CROPJPEG} ] && [ -s "${CROPJPEG}" ]; then
    MQTT_TOPIC='image-cropped/'"${AAH_LOCATION}"
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MQTT ${CROPJPEG} to ${MQTT_HOST} topic ${MQTT_TOPIC}" >&2; fi
    mosquitto_pub -i "${DEVICE_NAME}" -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${CROPJPEG}"
else
    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- no cropped image: ${CROPJPEG}" >&2; fi
fi

# test if composed image created as side-effect
if [ -n $COMPJPEG ] && [ -s "${COMPJPEG}" ]; then
    MQTT_TOPIC='image-composed/'"${AAH_LOCATION}"
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- MQTT ${COMPJPEG} to ${MQTT_HOST} topic ${MQTT_TOPIC}" >&2; fi
    mosquitto_pub -i "${DEVICE_NAME}" -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${COMPJPEG}"
else
    if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- no composed image" >&2; fi
fi

##
## make a noise
##
if [ -s "${OUTPUT}" ] && [ -z "${TALKTOME_OFF}" ] && [ -n "${WATSON_TTS_URL}" ] && [ -n "${WATSON_TTS_CREDS}" ]; then
    # what entity to discuss/say
    WHAT=`jq -j '.alchemy.text' "${OUTPUT}"`
    # should be a lookup aah_whatToSay(<where>,<when>,[<entity>],<whom>?)
    if [ -z "${WHAT_TO_SAY}" ]; then
	SPEAK="I just saw ${WHAT}"
    else
	SPEAK="${WHAT_TO_SAY} ${WHAT}"
    fi
    if [ ! -f "${WHAT}.wav" ]; then
	curl -s -q -f -L -X POST \
	  --header "Content-Type: application/json" \
	  --header "Accept: audio/wav" \
	  --data '{"text":"'"${SPEAK}"'"}' \
	  "https://${WATSON_TTS_CREDS}@${WATSON_TTS_URL}?voice=en-US_MichaelVoice" --output "${WHAT}.wav"
    fi
    play "${WHAT}.wav"
fi

##
## send an email
##
if [ -s "${OUTPUT}" ] && [ -n "${EMAILME_ON}" ] && [ -n "${GMAIL_ACCOUNT}" ] && [ -n "${GMAIL_CREDS}" ] && [ -n "${EMAIL_ADDRESS}" ]; then
    if [ ! -f "${WHAT}.txt" ]; then
        echo "From: ${AAH_LOCATION}" > "${WHAT}.txt"
        echo "Subject: ${WHAT}" >> "${WHAT}.txt"
    fi
    curl -v --url 'smtps://smtp.gmail.com:465' --ssl-reqd --mail-from "${GMAIL_ACCOUNT}" --mail-rcpt "${EMAIL_ADDRESS}" --upload-file "${WHAT}.txt" --user "${GMAIL_CREDS}" --insecure
    rm -f "${WHAT}.txt"
fi

##
## force image updates periodically (15 minutes; 1800 seconds)
##
if [ -n "${AAH_LAN_SERVER}" ]; then
  TTL=1800
  SECONDS=$(date "+%s")
  DATE=$(echo "${SECONDS} / ${TTL} * ${TTL}" | bc)
  OUT="/tmp/images.$DATE.json"
  if [ ! -s "${OUT}" ]; then
    if [ -n "${VERBOSE}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- updating images database ${DEVICE_NAME}" >&2; fi
    rm -f "/tmp/images".*.json
    curl -s -q -f -L "http://${AAH_LAN_SERVER}/CGI/aah-images.cgi?db=${DEVICE_NAME}&limit=1" -o "${OUT}"
    if [ -s "${OUT}" ]; then 
      if [ -n "${VERBOSE}" ]; then jq -c '.' "/tmp/images.${DATE}.json" >&2; fi
    else
      if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- ${IMAGE_ID} -- no images reported ${DEVICE_NAME}" >&2; fi
      rm -f "${OUT}"
    fi
  fi
fi

##
## ALL DONE
##
if [ -n "${DEBUG}" ]; then echo "${0##*/} $$ -- END: $*" $(date) >&2; fi
