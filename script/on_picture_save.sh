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

# proceed if VISUAL_OFF is zero length or undefined
if [ -z "${VISUAL_OFF}" ] && [ -n "${VISUAL_USERNAME}" ] && [ -n "${VISUAL_PASSWORD}" ] && [ -n "${VISUAL_URL}" ]; then

    # full image
    OUTPUT="${IMAGE_FILE%.*}-visual.json"

    echo "+++ $0 PROCESSING VISUAL_INSIGHTS ${IMAGE_FILE}"
    # VisualInsights
    curl -q -s -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${OUTPUT}"
    VISUAL_OUTPUT="${OUTPUT}"
fi

#
# ALCHEMY
#

# use two API keys (morning and evening)
AMPM=`date +%p`
if [ ${AMPM} == AM ] && [ -n ${ALCHEMY_API_KEY_AM} ]; then
    ALCHEMY_API_KEY=${ALCHEMY_API_KEY_AM}
fi
if [ ${AMPM} == PM ] && [ -n ${ALCHEMY_API_KEY_PM} ]; then
    ALCHEMY_API_KEY=${ALCHEMY_API_KEY_PM}
fi

# test if OFF or unconfigured
if [ -z "${ALCHEMY_OFF}" ] && [ -n "${ALCHEMY_API_KEY}" ] && [ -n "${ALCHEMY_API_URL}" ]; then
    # full  image
    OUTPUT="${IMAGE_FILE%.*}-alchemy.json"
    
    echo "+++ $0 PROCESSING ALCHEMY ${IMAGE_FILE}"

    # Alchemy
    curl -q -s -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"
    ALCHEMY_OUTPUT="${OUTPUT}"
fi

#
# CLOUDANT
#

# Prepare output
OUTPUT="${IMAGE_FILE%.*}.json"
# test which outputs exist; merge if possible into single JSON object
if [ -n "${ALCHEMY_OUTPUT}" ]; then
    if [ -n "${VISUAL_OUTPUT}" ]; then
	# pull out alchemy (first) and visual insights (second) -- ORDER MATTERS !!
	jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
	jq -c '.images[0]' "${VISUAL_OUTPUT}" | sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
	jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"
	# remove tmp & originals
	rm "${OUTPUT}.$$" "${VISUAL_OUTPUT}" "${ALCHEMY_OUTPUT}"
    else
	mv "${ALCHEMY_OUTPUT}" "${OUTPUT}"
    fi
elif [ -n "${VISUAL_OUTPUT}" ]; then
    mv "${VISUAL_OUTPUT}" "${OUTPUT}"
else
    echo "*** ERROR: $0 - NO OUTPUT"
    OUTPUT=""
fi

if [ -n "${OUTPUT}" ]; then
    # drop prefix path
    IMAGE_ID=`echo "${OUTPUT##*/}"`
    # drop extension
    IMAGE_ID=`echo "${IMAGE_ID%.*}"`

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
fi

# DEBUG
# cat "${OUTPUT}"

# Cloudant
if [ -z "${CLOUDANT_OFF}" ] && [ -n "${OUTPUT}" ] && [ -n "${CLOUDANT_URL}" ] && [ -n "${DEVICE_NAME}" ]; then
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
