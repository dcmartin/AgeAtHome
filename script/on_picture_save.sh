#!/bin/bash

EVENT=$1

echo "$0: $*" $(date) >> LOG

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
                (( MOTION_X = ${MOTION_MIDX} - ${MOTION_WIDTH} / 2 ))
                (( MOTION_Y = ${MOTION_MIDY} - ${MOTION_HEIGHT} / 2 ))
                convert -crop "${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}" "${IMAGE_FILE}" "${IMAGE_FILE%.*}-crop.jpg"
		mv "${IMAGE_FILE}" "${IMAGE_FILE%.*}=${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}".jpg
		mv "${IMAGE_FILE%.*}-crop.jpg" "${IMAGE_FILE}"
	    fi
	fi
    fi
fi

if [ -n "${VISUAL_USERNAME}" ]; then
    if [ -n "${VISUAL_PASSWORD}" ]; then
        if [ -n "${VISUAL_URL}" ]; then
	    echo "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}"
	    curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${EVENT}-visual.json"
        fi
    fi
fi
if [ -n "${ALCHEMY_API_URL}" ]; then
    if [ -n "${ALCHEMY_API_KEY}" ]; then
	echo  "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json"
	curl -q -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${EVENT}-alchemy.json"
    fi
fi
