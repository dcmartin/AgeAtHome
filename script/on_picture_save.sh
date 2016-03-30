#!/bin/bash
echo "$0: $*" $(date) >&2

# get arguments
EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3
MOTION_MIDX=$4
MOTION_MIDY=$5
MOTION_WIDTH=$6
MOTION_HEIGHT=$7

if [ -n "${MOTION_MIDX}" ]; then
    if [ -n "${MOTION_MIDY}" ]; then
	if [ -n "${MOTION_WIDTH}" ]; then
	    if [ -n "${MOTION_HEIGHT}" ]; then
		# calculate X,Y start from mid-point and extant
		(( MOTION_X = ${MOTION_MIDX} - ${MOTION_WIDTH} / 2 ))
		(( MOTION_Y = ${MOTION_MIDY} - ${MOTION_HEIGHT} / 2 ))
		IMAGE_BOX="${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}"
		# proceed if CROP_OFF is zero length or undefined
		if [ -z "${CROP_OFF}" ]; then
		    IMAGE_CROP="${IMAGE_FILE%.*}:${IMAGE_BOX}".jpg
		    convert -crop "${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}" "${IMAGE_FILE}" "${IMAGE_CROP}"
		fi
	    fi
	fi
    fi
fi

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

# proceed if VISUAL_OFF is zero length or undefined
if [ -z "${VISUAL_OFF}" ]; then
    if [ -n "${VISUAL_USERNAME}" ] && [ -n "${VISUAL_PASSWORD}" ] && [ -n "${VISUAL_URL}" ]; then
	if [ -z "${CROP_OFF}" ]; then
	    # cropped image
	    OUTPUT="${IMAGE_CROP%.*}-visual.json"
	    # drop prefix path
	    IMAGE_ID=`echo "${OUTPUT##*/}"`
	    # drop extension
	    IMAGE_ID=`echo "${IMAGE_ID%.*}"`

	    # VisualInsights
	    curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_CROP}" "${VISUAL_URL}" > "${OUTPUT}"

	    # add date and time information
	    if [ -n "${IMAGE_ID}" ]; then
		DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*-.*/\1/"`
		cat "${OUTPUT}" | sed 's/^{/{ "datetime": "DATE_TIME",/' | sed "s/DATE_TIME/${DATE_TIME}/" > /tmp/OUTPUT.$$
		mv /tmp/OUTPUT.$$ "${OUTPUT}"
	    fi

	    # Cloudant
	    if [ -n "${CLOUDANT_URL}" ] && [ -n ${DEVICE_NAME} ]; then
		curl -q -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}-visual" -d "@${OUTPUT}"
	    fi
	fi

	# full image
	OUTPUT="${IMAGE_FILE%.*}-visual.json"
	# drop prefix path
	IMAGE_ID=`echo "${OUTPUT##*/}"`
	# drop extension
	IMAGE_ID=`echo "${IMAGE_ID%.*}"`

	# VisualInsights
	curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${OUTPUT}"

	# add date and time information
	if [ -n "${IMAGE_ID}" ]; then
	    DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*-.*/\1/"`
	    cat "${OUTPUT}" | sed 's/^{/{ "datetime": "DATE_TIME",/' | sed "s/DATE_TIME/${DATE_TIME}/" > /tmp/OUTPUT.$$
	    mv /tmp/OUTPUT.$$ "${OUTPUT}"
	fi
	# add bounding box to JSON
	if [ -n "${IMAGE_BOX}" ]; then
	    cat "${OUTPUT}" | sed 's/^{/{ "imagebox": "IMAGE_BOX",/' | sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
	    mv /tmp/OUTPUT.$$ "${OUTPUT}"
	fi

	# Cloudant
	if [ -n ${CLOUDANT_URL} ] && [ -n ${DEVICE_NAME} ]; then
	    curl -q -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
	fi
    fi
fi

# test if OFF 
if [ -z "${ALCHEMY_OFF}" ]; then

    # use two API keys (morning and evening)
    AMPM=`date +%p`
    if [ ${AMPM} == AM ] && [ -n ${ALCHEMY_API_KEY_AM} ]; then
	ALCHEMY_API_KEY=${ALCHEMY_API_KEY_AM}
    fi
    if [ ${AMPM} == PM ] && [ -n ${ALCHEMY_API_KEY_PM} ]; then
	ALCHEMY_API_KEY=${ALCHEMY_API_KEY_PM}
    fi

    # check if configured
    if [ -n "${ALCHEMY_API_KEY}" ] && [ -n "${ALCHEMY_API_URL}" ]; then
	if [ -z "${CROP_OFF}" ]; then
	    # cropped image
	    OUTPUT="${IMAGE_CROP%.*}-alchemy.json"
	    # drop prefix path
	    IMAGE_ID=`echo "${OUTPUT##*/}"`
	    # drop extension
	    IMAGE_ID=`echo "${IMAGE_ID%.*}"`

	    # Alchemy
	    curl -q -X POST --data-binary "@${IMAGE_CROP}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"

	    # add date and time information
	    if [ -n "${IMAGE_ID}" ]; then
		DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*-.*/\1/"`
		cat "${OUTPUT}" | sed 's/^{/{ "datetime": "DATE_TIME",/' | sed "s/DATE_TIME/${DATE_TIME}/" > /tmp/OUTPUT.$$
		mv /tmp/OUTPUT.$$ "${OUTPUT}"
	    fi

	    # Cloudant
	    if [ -n "${CLOUDANT_URL}" ] && [ -n ${DEVICE_NAME} ]; then
		curl -q -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
	    fi
	fi

	# full  image
	OUTPUT="${IMAGE_FILE%.*}-alchemy.json"
	# drop prefix path
	IMAGE_ID=`echo "${OUTPUT##*/}"`
	# drop extension
	IMAGE_ID=`echo "${IMAGE_ID%.*}"`

	# Alchemy
	curl -q -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${OUTPUT}"

	# add date and time information
	if [ -n "${IMAGE_ID}" ]; then
	    DATE_TIME=`echo "${IMAGE_ID}" | sed "s/\(.*\)-.*-.*-.*/\1/"`
	    cat "${OUTPUT}" | sed 's/^{/{ "datetime": "DATE_TIME",/' | sed "s/DATE_TIME/${DATE_TIME}/" > /tmp/OUTPUT.$$
	    mv /tmp/OUTPUT.$$ "${OUTPUT}"
	fi
	# add bounding box to JSON
	if [ -n "${IMAGE_BOX}" ]; then
	    cat "${OUTPUT}" | sed 's/^{/{ "imagebox": "IMAGE_BOX",/' | sed "s/IMAGE_BOX/${IMAGE_BOX}/" > /tmp/OUTPUT.$$
	    mv /tmp/OUTPUT.$$ "${OUTPUT}"
	fi

	# Cloudant
	if [ -n ${CLOUDANT_URL} ] && [ -n ${DEVICE_NAME} ]; then
	    curl -q -H "Content-type: application/json" -X PUT "$CLOUDANT_URL/${DEVICE_NAME}/${IMAGE_ID}" -d "@${OUTPUT}"
	fi
    fi
fi
