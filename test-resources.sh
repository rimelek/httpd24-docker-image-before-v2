#!/usr/bin/env bash

source "apache2/bin/app-resources.sh";

dAddCname () {
    local CONTAINER_NAME="${1}";
    if [ -z "$(echo "${CONTAINER_NAMES}" | grep "\(^\|\s\)${CONTAINER_NAME}\($|\s\)")" ]; then
        if [ -n "${CONTAINER_NAMES}" ]; then
            CONTAINER_NAME=" ${CONTAINER_NAME}";
        fi;
        CONTAINER_NAMES="${CONTAINER_NAMES}${CONTAINER_NAME}";
    fi;
};

dDelCName () {
    CONTAINER_NAMES=$(echo "${CONTAINER_NAMES}" | sed 's/\(^\|\s\+\)'"${1}"'\($\|\s\+\)/\1/g');
};

dRun () {
    local COMMAND="${1}";
    local CONTAINER_NAME="${2}";
    local IMAGE_NAME="${3}";
    local CONTAINER_COMMAND="${4}";
    
    if [ -z "${CONTAINER_COMMAND}" ]; then
        eval "docker container run ${COMMAND}" --name "${CONTAINER_NAME}" "${IMAGE_NAME}";
    else
        eval "docker container run ${COMMAND}" --name "${CONTAINER_NAME}" "${IMAGE_NAME}" "${CONTAINER_COMMAND}";
    fi;
    
    dAddCname "${CONTAINER_NAME}";
};

dRm () {
    docker rm -f ${1};
    dDelCName ${1};
};

dWaitForHTTPD () {
    local CONTAINER_NAME="${1}";
    local SLEEP_UNIT="${2}";
    if [ -z "${SLEEP_UNIT}" ]; then
       SLEEP_UNIT=1; 
    fi;
    SEC=0
    
    OPTS=$-;
    
    set +x
    while [ -z "$(docker container exec ${CONTAINER_NAME} ps -o command= -p 1 | awk '/^httpd / {print $1}')" ]; do
        echo 'WAIT FOR HTTPD: '${SEC};
        sleep ${SLEEP_UNIT};
        SEC=$((SEC + SLEEP_UNIT));
    done;
    set -${OPTS}
};

dExec () {
    local CONTAINER_NAME="${1}";
    local CONTAINER_CMD="${*:2}";
    docker container exec "${CONTAINER_NAME}" ${CONTAINER_CMD}
};

dCat () {
    local CONTAINER_NAME="${1}";
    local CONTAINER_FILE="${2}";
    dExec "${CONTAINER_NAME}" cat "${CONTAINER_FILE}";
}

dGrep () {
    local CONTAINER_NAME="${1}";
    local CONTAINER_FILE="${2}";
    local CONTAINER_PTRN="${3}";
    
    dCat "${CONTAINER_NAME}" "${CONTAINER_FILE}" | grep "${CONTAINER_PTRN}";
};

dFileCheck () {
    local CONTAINER_NAME="${1}";
    local FILE_PATH="${2}";
    local COMMAND="if [ -f ${FILE_PATH} ]; then echo 'OK'; fi;";
    if [ "$(docker container exec ${CONTAINER_NAME} bash -c "${COMMAND}")" != "OK" ] ; then
       >&2 echo "File not found: ${FILE_PATH}";
       exit 1;
    fi;
};