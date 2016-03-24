#!/bin/bash

set -e

EVENT=$1
IMAGE_FILE=$2
IMAGE_TYPE=$3

TIMESTAMP=$(date)
END_TIME=$(date +"%s")
START_TIME=$(cat ${EVENT}-start-time.log)
DURATION=$((${END_TIME}-${START_TIME}))

if [ -n "${VISUAL_USERNAME}" ]; then
    if [ -n "${VISUAL_PASSWORD}" ]; then
        if [ -n "${VISUAL_URL}" ]; then
	    curl -u "${VISUAL_USERNAME}":"${VISUAL_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VISUAL_URL}" > "${EVENT}.json"
        fi
    fi
fi

