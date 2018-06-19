#!/bin/bash
if [ -n "${DEBUG}" ]; then echo "+++ BEGIN: $0: $*" $(date) >&2; fi

# get arguments
EVENT=$1
VIDEO_FILE=$2

# drop prefix path
VIDEO_NAME=`echo "${VIDEO_FILE##*/}"`
# drop extension
VIDEO_ID=`echo "${VIDEO_NAME%.*}"`

## mask has 'm' appended to filename
VIDEO_MASK="${VIDEO_FILE%.*}m.${VIDEO_FILE##*.}"

if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- PROCESSING ${EVENT} ${VIDEO_FILE}"; fi

##
## Prepare output
##

# post JSON message to MQTT
if [ -n "${MQTT_ON}" ] && [ -n "${MQTT_HOST}" ]; then
    if [ -z "${MQTT_TOPIC}" ]; then
        MQTT_TOPIC='movie/event/'"${AAH_LOCATION}"
    fi
    WHAT='"event":"'"${EVENT}"'","id":"'"${VIDEO_ID}"'"'
    MSG='{"device":"'"${DEVICE_NAME}"'","location":"'"${AAH_LOCATION}"'","date":'`date +%s`','"${WHAT}"'}'
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -m "${MSG}"
    if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- PUBLISHED ${MSG} to ${MQTT_TOPIC} at ${MQTT_HOST}"; fi
fi

# post H264 video to MQTT
if [ -n "${MQTT_ON}" ] && [ -n "${MQTT_HOST}" ]; then
  if [ -s "${VIDEO_FILE}" ]; then
    MQTT_TOPIC='movie/output/'"${AAH_LOCATION}"
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${VIDEO_FILE}"
    if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- PUBLISHED ${VIDEO_FILE} to ${MQTT_TOPIC} at ${MQTT_HOST}"; fi
  fi
  # post mask video
  if [ -s "${VIDEO_MASK}" ]; then
    MQTT_TOPIC='movie/mask/'"${AAH_LOCATION}"
    mosquitto_pub -i "${DEVICE_NAME}" -r -h "${MQTT_HOST}" -t "${MQTT_TOPIC}" -f "${VIDEO_MASK}"
    if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- PUBLISHED ${VIDEO_MASK} to ${MQTT_TOPIC} at ${MQTT_HOST}"; fi
  fi
fi

# curl H264 video to FTP
if [ -n "${FTP_ON}" ] && [ -n "${FTP_HOST}" ] && [ -n "${FTP_USERNAME}" ]; then
  if [ -s "${VIDEO_FILE}" ]; then
    /usr/local/bin/curl -T "${VIDEO_FILE}" "ftp://${FTP_USERNAME}:${FTP_PASSWORD}@${FTP_HOST}/NEW/"
    if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- FTP ${VIDEO_FILE} to ${FTP_HOST}"; fi
  else
    if [ -n "${DEBUG}" ]; then echo "+++ DEBUG: $0:t -- FTP failure no video file ${VIDEO_FILE}"; fi
  fi
fi

if [ -n "${DEBUG}" ]; then echo "+++ END: $0:t -- $*" $(date) >&2; fi
