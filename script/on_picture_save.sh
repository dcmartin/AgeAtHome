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

#
# VISUAL RECOGNITION
#
# FACES
# curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/detect_faces?api_key=$api_key&version=2016-05-20"
# TEXT
# curl -L -o /tmp/$0:t.$$.json -X POST -F "images_file=@$IMAGE_FILE" -H "Accept-Language: en" "$TU/v3/recognize_text?api_key=$api_key&version=2016-05-20"

#
# CLASSIFICATION
#
# {
#   "custom_classes": 0,
#   "images": [
#     {
#       "classifiers": [
#         {
#           "classes": [
#             {
#               "class": "people",
#               "score": 0.310026,
#               "type_hierarchy": "/people"
#             },
#             {
#               "class": "street",
#               "score": 0.28905,
#               "type_hierarchy": "/places/street"
#             }
#           ],
#           "classifier_id": "default",
#           "name": "default"
#         }
#       ],
#       "image": "20160821203750-3027-00.jpg"
#     }
#   ],
#   "images_processed": 1
# }
# 

# create VR_OUTPUT JSON filename
VR_OUTPUT="${IMAGE_FILE%.*}-vr.json"
# proceed if VR_OFF is zero length or undefined
if [ -z "${VR_OFF}" ] && [ -n "${VR_APIKEY}" ] && [ -n "${VR_VERSION}" ] && [ -n "${VR_DATE}" ] && [ -n "${VR_URL}" ]; then
    echo "+++ $0 PROCESSING visual-recognition ${VR_VERSION} ${VR_DATE} ${VR_URL} ${IMAGE_FILE}"
    if [ -z "${VR_CLASSIFIER}" ]; then
	VR_CLASSIFIER="default"
    fi
    curl -L \
        -F "images_file=@$IMAGE_FILE" \
	-o "${VR_OUTPUT}" \
	"$VR_URL/$VR_VERSION/classify?api_key=$VR_APIKEY&classifier_ids=$VR_CLASSIFIER&threshold=0.000001&version=$VR_DATE"
       # -f -s -q \
    if [ -s "${VR_OUTPUT}" ]; then
	echo  "+++ $0 SUCCESS visual-recognition ${IMAGE_FILE}"
	jq -c '.' "${VR_OUTPUT}"
    else
	echo "+++ $0 FAILURE visual-recognition ${IMAGE_FILE}"
    fi
else
    echo "+++ $0 VISUAL-RECOGNITION - OFF"
fi

#
# VISUAL INSIGHTS
#

# set VI_OUTPUT
VI_OUTPUT="${IMAGE_FILE%.*}-visual.json"
# proceed if VI_OFF is zero length or undefined
if [ -z "${VI_OFF}" ] && [ -n "${VI_USERNAME}" ] && [ -n "${VI_PASSWORD}" ] && [ -n "${VI_URL}" ]; then
    echo "+++ $0 PROCESSING visual-insights ${IMAGE_FILE}"
    # VisualInsights
    curl -q -s -L -u "${VI_USERNAME}":"${VI_PASSWORD}" -X POST -F "images_file=@${IMAGE_FILE}" "${VI_URL}" > "${VI_OUTPUT}"
    if [ -s "${VI_OUTPUT}" ]; then
	echo "+++ $0 SUCCESS visual-insights ${IMAGE_FILE}"
    else
	echo "+++ $0 FAILURE visual-insights ${IMAGE_FILE}"
    fi
else
    echo "+++ $0 VISUAL-INSIGHTS - OFF"
fi

#
# ALCHEMY
#
# FACES
# curl -q -s -L -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}/image/ImageGetRankedImageFaceTags?apikey=${ALCHEMY_API_KEY}&imagePostMode=raw&outputMode=json"
#

# set ALCHEMY_OUTPUT
ALCHEMY_OUTPUT="${IMAGE_FILE%.*}-alchemy.json"
# test if not OFF or not configured
if [ -z "${ALCHEMY_OFF}" ] && [ -n "${ALCHEMY_API_KEY}" ] && [ -n "${ALCHEMY_API_URL}" ]; then
    API_KEY="${ALCHEMY_API_KEY}"
    if [ $(date +%p) == "PM" ] && [ -n "${ALCHEMY_API_KEY_PM}" ]; then
	API_KEY="${ALCHEMY_API_KEY_PM}"
    fi
    echo "+++ $0 PROCESSING ALCHEMY ${IMAGE_FILE} with ${API_KEY}"
    # ALCHEMY CLASSIFY
    curl -q -s -L -X POST --data-binary "@${IMAGE_FILE}" "${ALCHEMY_API_URL}/image/ImageGetRankedImageKeywords?apikey=${API_KEY}&imagePostMode=raw&outputMode=json" > "${ALCHEMY_OUTPUT}"
    if [ -s "${ALCHEMY_OUTPUT}" ]; then
	echo "+++ SUCCESS alchemy ${IMAGE_FILE}"
    else
	echo "+++ $0 FAILURE ALCHEMY ${IMAGE_FILE}"
    fi
else
    echo "+++ $0 ALCHEMY OFF"
fi

#
# Prepare output
#
OUTPUT="${IMAGE_FILE%.*}.json"
# drop prefix path
IMAGE_ID=`echo "${OUTPUT##*/}"`
# drop extension
IMAGE_ID=`echo "${IMAGE_ID%.*}"`

if [ -s "${VI_OUTPUT}" ] && [ -s "${ALCHEMY_OUTPUT}" ]; then
    echo "+++ $0 VI and ALCHEMY"
    # order matters
    jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
    jq -c '.images[0]' "${VI_OUTPUT}" | sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
elif [ -s "${VR_OUTPUT}" ] && [ -s "${ALCHEMY_OUTPUT}" ]; then
    echo "+++ $0 VR and ALCHEMY"
    # order matters
    jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
    # make it look like VI-type output
    jq -c '.images[0]|{image:.image,scores:[.classifiers[].classes[]|{classifier_id:.class,name:.type_hierarchy,score:.score}]}' "${VR_OUTPUT}" \
	| sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
elif [ -s "${ALCHEMY_OUTPUT}" ]; then
    echo "+++ $0 ALCHEMY ONLY"
    echo `date` "$0 $$ -- " `jq -c . "${ALCHEMY_OUTPUT}"`
    jq -c '.imageKeywords[0]' "${ALCHEMY_OUTPUT}" | sed 's/\(.*\)\}/\{ "alchemy": \1 \},/' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
elif [ -s "${VR_OUTPUT}" ]; then
    echo "+++ $0 VR ONLY"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    # make it look like VI-type output
    jq -c '.images[0]|{image:.image,scores:[.classifiers[].classes[]|{classifier_id:.class,name:.type_hierarchy,score:.score}]}' "${VR_OUTPUT}" \
	| sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
elif [ -s "${VI_OUTPUT}" ]; then
    echo "+++ $0 VI_INSIGHTS ONLY"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    jq -c '.images[0]' "${VI_OUTPUT}" | sed 's/^{\(.*\)/"visual":{ \1 \}/' >> "${OUTPUT}.$$"
else
    echo "+++ $0 NEITHER"
    echo '{ "alchemy":{"text":"NO_TAGS","score":0},' > "${OUTPUT}.$$"
    echo '"visual":{"image":"'${IMAGE_ID}.jpg'","scores":[{"classifier_id":"NA","name":"NA","score":0}]' >> "${OUTPUT}.$$"
fi

echo "}}" >> "${OUTPUT}.$$"

# create (and validate) output
cat "${OUTPUT}.$$"
jq -c '.' "${OUTPUT}.$$" > "${OUTPUT}"

# remove tmp & originals
rm -f "${OUTPUT}.$$" "${VI_OUTPUT}" "${ALCHEMY_OUTPUT}" "${VR_OUTPUT}"

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
