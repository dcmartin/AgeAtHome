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
		IMAGE_CROP="${IMAGE_FILE%.*}=${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}".jpg
		echo convert -crop "${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}" "${IMAGE_FILE}" "${IMAGE_CROP}"
                convert -crop "${MOTION_WIDTH}x${MOTION_HEIGHT}+${MOTION_X}+${MOTION_Y}" "${IMAGE_FILE}" "${IMAGE_CROP}"
	    fi
	fi
    fi
fi

if [ -n "${VISUAL_USERNAME}" ]; then
    if [ -n "${VISUAL_PASSWORD}" ]; then
        if [ -n "${VISUAL_URL}" ]; then
	    if [ -n "${IMAGE_CROP}" ]; then
		curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_CROP}" "${VISUAL_URL}" > "${EVENT}-crop-visual.json"
	    fi
	    curl -q -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${EVENT}-full-visual.json"
        fi
    fi
fi
if [ -n "${ALCHEMY_API_URL}" ]; then
    if [ -n "${ALCHEMY_API_KEY}" ]; then
        if [ -n "${IMAGE_CROP}" ]; then
	    curl -q -X POST --data-binary "@${IMAGE_CROP}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${EVENT}-crop-alchemy.json"
	fi
	curl -q -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${EVENT}-full-alchemy.json"
    fi
fi
