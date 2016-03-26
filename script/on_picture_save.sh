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

# proceed if CROP_OFF is zero length or undefined
if [ -z "${CROP_OFF}" ]; then
    if [ -n "${MOTION_MIDX}" ]; then
	if [ -n "${MOTION_MIDY}" ]; then
	    if [ -n "${MOTION_WIDTH}" ]; then
		if [ -n "${MOTION_HEIGHT}" ]; then
		    # calculate X,Y start from mid-point and extant
		    (( MOTION_X = ${MOTION_MIDX} - ${MOTION_WIDTH} / 2 ))
		    (( MOTION_Y = ${MOTION_MIDY} - ${MOTION_HEIGHT} / 2 ))
		    IMAGE_CROP="${IMAGE_FILE%.*}:${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}".jpg
		    convert -crop "${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}" "${IMAGE_FILE}" "${IMAGE_CROP}"
		fi
	    fi
	fi
    fi
fi

# proceed if VISUAL_OFF is zero length or undefined
if [ -z "${VISUAL_OFF}" ]; then
    if [ -n "${VISUAL_USERNAME}" ]; then
	if [ -n "${VISUAL_PASSWORD}" ]; then
	    if [ -n "${VISUAL_URL}" ]; then
		if [ -n "${IMAGE_CROP}" ]; then
		    curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_CROP}" "${VISUAL_URL}" > "${IMAGE_CROP%.*}-visual.json"
		fi
		curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${IMAGE_FILE%.*}-visual.json"
	    fi
	fi
    fi
fi

# proceed if ALCHEMY_OFF is zero length or undefined
if [ -z "${ALCHEMY_OFF}" ]; then
    if [ -n "${ALCHEMY_API_URL}" ]; then
        AMPM=`date +%p`
	if [ ${AMPM} == AM ] && [ -n ${ALCHEMY_API_KEY_AM} ]; then
	    ALCHEMY_API_KEY=${ALCHEMY_API_KEY_AM}
	fi
	if [ ${AMPM} == PM ] && [ -n ${ALCHEMY_API_KEY_PM} ]; then
	    ALCHEMY_API_KEY=${ALCHEMY_API_KEY_PM}
	fi
	if [ -n "${ALCHEMY_API_KEY}" ]; then
	    if [ -n "${IMAGE_CROP}" ]; then
		curl -q -X POST --data-binary "@${IMAGE_CROP}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${IMAGE_CROP%.*}-alchemy.json"
	    fi
	    curl -q -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${IMAGE_FILE%.*}-alchemy.json"
	fi
    fi
fi
