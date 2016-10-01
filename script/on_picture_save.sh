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

# proceed if VR_OFF is zero length or undefined
if [ -z "${VR_OFF}" ] && [ -n "${VR_APIKEY}" ] && [ -n "${VR_VERSION}" ] && [ -n "${VR_DATE}" ] && [ -n "${VR_URL}" ]; then

    # create OUTPUT JSON filename
    OUTPUT="${IMAGE_FILE%.*}-vr.json"

    echo "+++ $0 PROCESSING visual-recognition ${IMAGE_FILE}"

    echo "+++ $0 CLASSIFIERS +++"
    curl -s -q -L -o "${OUTPUT}" -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/$VR_VERSION/classify?api_key=$VR_APIKEY&classifier_ids=default&owners=IBM&threshold=0.000001&version=$VR_DATE"
    # echo "+++ FACES +++"
    # curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/detect_faces?api_key=$api_key&version=2016-05-20"
    # echo "+++ TEXT +++"
    # curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/recognize_text?api_key=$api_key&version=2016-05-20"

    if [ -s "${OUTPUT}" ]; then
	STATUS=(jq '.status' "${OUTPUT}")
	echo  "+++ $0 SUCCESS visual-recognition ${IMAGE_FILE}"
	VR_OUTPUT="${OUTPUT}"
    fi
    if [ -z "${VR_OUTPUT}" ]; then
	echo "+++ $0 FAILURE visual-recognition ${IMAGE_FILE}"
	echo '{"custom_classes":0,"images":[{"classifiers":[{"classes":[{"class":"FAIL","score":0,"type_hierarchy":"FAIL"}],"classifier_id":"default","name":"default"}],"image":"'"${IMAGE_FILE%.*}"'"}],"images_processed":0}' >! "${OUTPUT}"
    fi
fi
if [ -z "${VR_OUTPUT} ]; then
    echo "+++ $0 OFF visual-recognition"
    echo '{"custom_classes":0,"images":[{"classifiers":[{"classes":[{"class":"NA","score":0,"type_hierarchy":"NA"}],"classifier_id":"default","name":"default"}],"image":"'"${IMAGE_FILE%.*}"'"}],"images_processed":0}' >! "${OUTPUT}"
    VR_OUPUT="${OUTPUT}"
fi


# proceed if VI_OFF is zero length or undefined
if [ -z "${VI_OFF}" ] && [ -n "${VI_USERNAME}" ] && [ -n "${VI_PASSWORD}" ] && [ -n "${VI_URL}" ]; then

    # full image
    OUTPUT="${IMAGE_FILE%.*}-visual.json"

    echo "+++ $0 PROCESSING visual-insights ${IMAGE_FILE}"

    # VisualInsights
    curl -q -s -L -u "${VI_USERNAME}":"${VI_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VI_URL}" > "${OUTPUT}"
    if [ -s "${OUTPUT}" ]; then
	echo "+++ $0 SUCCESS visual-insights ${IMAGE_FILE}"
	VI_OUTPUT="${OUTPUT}"
    else
	echo "+++ $0 FAILURE visual-insights ${IMAGE_FILE}"
	echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"FAIL","name":"FAIL","score":0}]' >> "${OUTPUT}"
	VI_OUTPUT="${OUTPUT}"
    fi
else
    echo "+++ $0 OFF visual-insights"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}"
    VI_OUTPUT="${OUTPUT}"
fi

#
# ALCHEMY
#
# echo "+++ ALCHEMY_OFF " [ -z "${ALCHEMY_OFF}" "ALCHEMY_API_KEY = " [ -n "${ALCHEMY_API_KEY}" ] "ALCHEMY_API_URL = " [ -n "${ALCHEMY_API_URL}" ]
# test if not OFF or not configured
if [ -z "${ALCHEMY_OFF}" ] && [ -n "${ALCHEMY_API_KEY}" ] && [ -n "${ALCHEMY_API_URL}" ]; then

    # full  image
    OUTPUT="${IMAGE_FILE%.*}-alchemy.json"
    
    echo "+++ $0 PROCESSING ALCHEMY ${IMAGE_FILE}"

    # ALCHEMY CLASSIFY
    curl -q -s -L -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}/image/ImageGetRankedImageKeywords?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"
    if [ -s "${OUTPUT}" ]; then
	# echo -n "+++ ALCHEMY == "; jq -c '.' "${OUTPUT}"
	ALCHEMY_OUTPUT="${OUTPUT}"
    else
	echo "+++ $0 FAILURE ALCHEMY ${IMAGE_FILE}"
	echo '{"status":"FAIL","usage":"","NOTICE":"","url":"'"${IMAGE_FILE%.*}"'","totalTransactions":"","imageKeywords":[{"text":"FAIL","score":""}]}
	ALCHEMY_OUPUT="${OUTPUT}"
    fi
    # ALCHEMY FACES
    # curl -q -s -L -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}/image/ImageGetRankedImageFaceTags?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"
else
if [ -z "${ALCHEMY_OUTPUT} ]; then
    echo "+++ $0 OFF alchemy"
    echo '{"status":"NA","usage":"","NOTICE":"","url":"'"${IMAGE_FILE%.*}"'","totalTransactions":"","imageKeywords":[{"text":"NA","score":""}]}
    ALCHEMY_OUPUT="${OUTPUT}"
fi

#
# Prepare output
#
OUTPUT="${IMAGE_FILE%.*}.json"
# drop prefix path
IMAGE_ID=`echo "${OUTPUT##*/}"`
# drop extension
IMAGE_ID=`echo "${IMAGE_ID%.*}"`

if [ -z "${VI_OUTPUT}" ] && [ -z "${ALCHEMY_OUTPUT}" ]; then
    echo "+++ $0 NEITHER"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
elif [ -z "${ALCHEMY_OUTPUT}" ]; then
    echo "+++ $0 VI_INSIGHTS ONLY"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    jq -c '.images[1]' "${VI_OUTPUT}" | sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
elif [ -z "${VI_OUTPUT}" ]; then
    echo "+++ $0 ALCHEMY ONLY"
    jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
else
    echo "+++ $0 BOTH"
    # order matters
    jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
    jq -c '.images[0]' "${VI_OUTPUT}" | sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
fi

echo "}}" >> "${OUTPUT}.$$"

# create (and validate) output
jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"

# remove tmp & originals
rm -f "${OUTPUT}.$$" "${VI_OUTPUT}" "${ALCHEMY_OUTPUT}"

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
	# WEEKDAY=`date -d @"${MONTH}${DAY}${HOUR}${MINUTE}${YEAR}.${SECOND}" "+%A"`
	# EPOCH=`date -d @"${MONTH}${DAY}${HOUR}${MINUTE}${YEAR}.${SECOND}" "+%s"`
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

echo "+++ END: $0: $*" $(date) >&2
