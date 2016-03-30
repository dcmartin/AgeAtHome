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


# proceed if VISUAL_OFF is zero length or undefined
if [ -z "${VISUAL_OFF}" ] && [ -n "${VISUAL_USERNAME}" ] && [ -n "${VISUAL_PASSWORD}" ] && [ -n "${VISUAL_URL}" ]; then

    # full image
    OUTPUT="${IMAGE_FILE%.*}-visual.json"

    # VisualInsights
    curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${OUTPUT}"

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

    # Alchemy
    curl -q -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"

    ALCHEMY_OUTPUT="${OUTPUT}"
fi

#
# CLOUDANT
#

# check for CLOUDANT db
if [ -z ${CLOUDANT_OFF} ] && [ -n "${CLOUDANT_URL}" ] && [ -n ${DEVICE_NAME} ]; then
    DEVICE_DB=`curl -q -X GET "${CLOUDANT_URL}/_all_dbs" | egrep "${DEVICE_NAME}"`
    if [ -z "${DEVICE_DB}" ]; then
	DEVICE_DB=`curl -q -X PUT "${CLOUDANT_URL}/${DEVICE_NAME}" | egrep "ok"`
	if [ -z "${DEVICE_DB}" ]; then
	    # force off 
	    CLOUDANT_OFF=TRUE
        fi
    fi
    if [ -z "${CLOUDANT_OFF}" ]; then
	DEVICE_DB=`curl -q -X GET "${CLOUDANT_URL}/${DEVICE_NAME}"`
    fi
else
    # off or failure
    CLOUDANT_OFF=TRUE
fi

OUTPUT="${IMAGE_FILE%.*}.json"
if [ -n "${VISUAL_OUTPUT}" ]; then
    if [ -n "${ALCHEMY_OUTPUT}" ]; then
	# merge JSON
	jq -s . "${VISUAL_OUTPUT}" "${ALCHEMY_OUTPUT}" > "${OUTPUT}"
	rm "${VISUAL_OUTPUT}" "${ALCHEMY_OUTPUT}"
    else
        mv "${VISUAL_OUTPUT}" "${OUTPUT}"
    fi
elif [ -n "${ALCHEMY_OUTPUT}" ]; then
    mv "${ALCHEMY_OUTPUT}" "${OUTPUT}"
else
    echo "*** ERROR: $0 - NO OUTPUT"
    OUTPUT=""
fi

# debugging
echo -n "INITIAL: "; jq . "${OUTPUT}"

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

if [ -n "${OUTPUT}" ]; then
    # drop prefix path
    IMAGE_ID=`echo "${OUTPUT##*/}"`
    # drop extension
    IMAGE_ID=`echo "${IMAGE_ID%.*}"`

    # add datetime and bounding box information
    if [ -n "${IMAGE_ID}" ] && [ -n "${IMAGE_BOX}" ]; then
	DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*-.*/\1/"`
	cat "${OUTPUT}" | sed 's/^\[/[ { "datetime": "DATE_TIME", "imagebox": "IMAGE_BOX"  },/' | sed "s/DATE_TIME/${DATE_TIME}/" | sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
	mv /tmp/OUTPUT.$$ "${OUTPUT}"
    fi

    # debugging
    echo -n "AFTER SED: "; jq . "${OUTPUT}"

    # Cloudant
    if [ -z "${CLOUDANT_OFF}" ] && [ -n "${CLOUDANT_URL}" ] && [ -n "${DEVICE_NAME}" ]; then
	curl -q -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
    fi
fi

echo "+++ END: $0: $*" $(date) >&2
