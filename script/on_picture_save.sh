#!/bin/bash
echo "+++ BEGIN: $0: $*" $(date) >&2

# get arguments
EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3
MOTION_MIDX=$4
MOTION_MIDY=$5
MOTION_WIDTH=$6
MOTION_HEIGHT=$7

# calculate imagebox
if [ -n "${MOTION_MIDX}" ]; then
    if [ -n "${MOTION_MIDY}" ]; then
	if [ -n "${MOTION_WIDTH}" ]; then
	    if [ -n "${MOTION_HEIGHT}" ]; then
		# calculate X,Y start from mid-point and extant
		(( MOTION_X = ${MOTION_MIDX} - ${MOTION_WIDTH} / 2 ))
		(( MOTION_Y = ${MOTION_MIDY} - ${MOTION_HEIGHT} / 2 ))
		IMAGE_BOX="${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}"
	    fi
	fi
    fi
fi

if [ -z "${IMAGE_BOX}" ]; then
    IMAGE_BOX="640x480+0+0"
fi

#
# VISUAL RECOGNITION
#
# FACES
# curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/detect_faces?api_key=$api_key&version=2016-05-20"
# TEXT
# curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/recognize_text?api_key=$api_key&version=2016-05-20"

#
# CLASSIFICATION
#
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
    echo "+++ $0 PROCESSING visual-recognition ${VR_CLASSIFIER} ${VR_VERSION} ${VR_DATE} ${VR_URL} ${IMAGE_FILE}"
    # make the call
    curl -s -q -L \
        -F "images_file=@$IMAGE_FILE" \
	-o "${VR_OUTPUT}" \
	"$VR_URL/$VR_VERSION/classify?api_key=$VR_APIKEY&classifier_ids=$VR_CLASSIFIER&threshold=0.0&version=$VR_DATE"
    if [ -s "${VR_OUTPUT}" ]; then
	echo  "+++ $0 SUCCESS visual-recognition ${IMAGE_FILE}"
    else
	echo "+++ $0 FAILURE visual-recognition ${IMAGE_FILE}"
    fi
else
    echo "+++ $0 VISUAL-RECOGNITION - OFF"
fi

#
# Prepare output
#
OUTPUT="${IMAGE_FILE%.*}.json"
# drop prefix path
IMAGE_ID=`echo "${OUTPUT##*/}"`
# drop extension
IMAGE_ID=`echo "${IMAGE_ID%.*}"`

if [ -s "${VR_OUTPUT}" ]; then
    echo "+++ $0 PROCESSING VISUAL_RECOGNITION ${VR_OUTPUT}"
    # encode top1 across custom (iff specified above) and default classifiers; decorate with source: default, <hierarchy:default>, custom classifier_id
    jq -c \
      '[.images[0]|.classifiers[]|.classifier_id as $cid|.classes|sort_by(.score)[-1]|{text:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]|sort_by(.score)[-1]' \
      "${VR_OUTPUT}" > "${OUTPUT}.alchemy.$$"
    # process WVR into "market basket" with "name" used to indicate source (default, <custom-id> or hierarchy (from default)
    jq -c \
      '.images[0]|{image:.image,scores:[.classifiers[]|.classifier_id as $cid|.classes[]|{classifier_id:.class,name:(if .type_hierarchy == null then $cid else .type_hierarchy end),score:.score}]}' \
      "${VR_OUTPUT}" > "${OUTPUT}.visual.$$"
    # concatenate -- "alchemy" is _really_ "top1" and "visual" is _really_ the entire "set" of classifiers
    sed 's/\(.*\)/{"alchemy":\1,"visual":/' "${OUTPUT}.alchemy.$$" | paste - "${OUTPUT}.visual.$$" > "${OUTPUT}.joint.$$"
    sed 's/\(.*\)/\1}/' "${OUTPUT}.joint.$$" > "${OUTPUT}.$$"
    # cleanup
    rm -f "${OUTPUT}.alchemy.$$" "${OUTPUT}.visual.$$" "${OUTPUT}.joint.$$"
else
    echo "+++ $0 NO OUTPUT"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
    echo "}}" >> "${OUTPUT}.$$"
fi

# create (and validate) output
jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"

# debug
jq -c '.' "${OUTPUT}"

# remove tmp & originals
rm -f "${OUTPUT}.$$" "${VR_OUTPUT}"

#
# add date and time
#
if [ -s "${OUTPUT}" ]; then
    # add datetime and bounding box information
    if [ -n "${IMAGE_ID}" ] && [ -n "${IMAGE_BOX}" ]; then
	DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*/\1/"`
	YEAR=`echo "${DATE_TIME}" | sed "s/^\(....\).*/\1/"`
	MONTH=`echo "${DATE_TIME}" | sed "s/^....\(..\).*/\1/"`
	DAY=`echo "${DATE_TIME}" | sed "s/^......\(..\).*/\1/"`
	HOUR=`echo "${DATE_TIME}" | sed "s/^........\(..\).*/\1/"`
	MINUTE=`echo "${DATE_TIME}" | sed "s/^..........\(..\).*/\1/"`
	SECOND=`echo "${DATE_TIME}" | sed "s/^............\(..\).*/\1/"`

	cat "${OUTPUT}" | \
	    sed 's/^{/{"year":"YEAR","month":"MONTH","day":"DAY","hour":"HOUR","minute":"MINUTE","second":"SECOND","imagebox":"IMAGE_BOX",/' | \
	    sed "s/YEAR/${YEAR}/" | \
	    sed "s/MONTH/${MONTH}/" | \
	    sed "s/DAY/${DAY}/" | \
	    sed "s/HOUR/${HOUR}/" | \
	    sed "s/MINUTE/${MINUTE}/" | \
	    sed "s/SECOND/${SECOND}/" | \
	    sed "s/DAY/${DAY}/" | \
	    sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
	mv /tmp/OUTPUT.$$ "${OUTPUT}"
    fi
else
    echo "*** ERROR: $0 - NO OUTPUT"
    exit
fi

#
# CLOUDANT
#

if [ -z "${CLOUDANT_OFF}" ] && [ -s "${OUTPUT}" ] && [ -n "${CLOUDANT_URL}" ] && [ -n "${DEVICE_NAME}" ]; then
    DEVICE_DB=`curl -q -s -X GET "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.db_name'`
    if [ "${DEVICE_DB}" == "null" ]; then
	# create DB
	DEVICE_DB=`curl -q -s -X PUT "${CLOUDANT_URL}/${DEVICE_NAME}" | jq '.ok'`
	# test for success
	if [ "${DEVICE_DB}" != "true" ]; then
	    # failure
	    CLOUDANT_OFF=TRUE
        fi
    fi
    if [ -z "${CLOUDANT_OFF}" ]; then
	curl -q -s -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
    fi
fi

# make a noise
if [ -z "${TALKTOME_OFF}" ] && [ -s "${OUTPUT}" ] && [ -n "${WATSON_TTS_URL}" ] && [ -n "${WATSON_TTS_CREDS}" ]; then
    WHAT=`jq -j '.alchemy.text' "${OUTPUT}"`
    if [ -z "${WHAT_TO_SAY}" ]; then
	SPEAK="I just saw ${WHAT}"
    else
	SPEAK="${WHAT_TO_SAY} ${WHAT}"
    fi
    if [ -z "${WHAT}" ]; then
	curl -s -q -L -X POST \
	  --header "Content-Type: application/json" \
	  --header "Accept: audio/wav" \
	  --data '{"text":"'"${SPEAK}"'"}' \
	  "https://${WATSON_TTS_CREDS}@${WATSON_TTS_URL}?voice=en-US_MichaelVoice" --output "${WHAT}"
    fi
    play "${WHAT}"
fi

echo "+++ END: $0: $*" $(date) >&2
