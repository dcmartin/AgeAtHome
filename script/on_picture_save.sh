#!/bin/bash

set -e

EVENT=$1

echo "SAVE: ${EVENT}" $(date +"%s") >> LOG

IMAGE_FILE=$2
IMAGE_TYPE=$3

if [ -n "${VISUAL_USERNAME}" ]; then
    if [ -n "${VISUAL_PASSWORD}" ]; then
        if [ -n "${VISUAL_URL}" ]; then
	    curl -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${EVENT}-visual.json"
        fi
    fi
fi
if [ -n "${ALCHEMY_API_URL}" ]; then
    if [ -n "${ALCHEMY_API_KEY}" ]; then
	curl -X POST --data-binary "@${IMAGE}" "${ALCHEMY_API_URL}?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json" > "${EVENT}-alchemy.json"
    fi
fi
