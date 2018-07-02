#!/usr/bin/env bash

GIT_HASH="$(git rev-list -n 1 HEAD)"
PATTERN_MINOR_BRANCH='^\([0-9]\+\.[0-9]\+\)\(-dev\)\?$';
PATTERN_STABLE_VERSION='[0-9]\+\.[0-9]\+\.[0-9]\+'
PARENT_IMAGE="httpd:2.4"

reqVar () {
    : ${!1?\$${1} is not set}
}

reqVarNonEmpty () {
    : ${!1:?\$${1} is Empty}
}

toBool () {
    local BOOL=$(echo "${1}" | tr '[:upper:]' '[:lower:]');
    case ${BOOL} in
        1|yes|on|true) echo "true"; ;;
        0|no|off|false) echo "false"; ;;
        *) echo "null";
    esac;
}

isBranch () {
    reqVarNonEmpty CI_BRANCH
    [ "${CI_BRANCH}" == "${CI_TAG}" ] && echo 'false' || echo 'true';
}

isTag () {
    [ "$(isBranch)" == "false" ] && echo 'true' || echo 'false';
}

isMinorBranch () {
    reqVarNonEmpty CI_BRANCH

    local RESULT="$(echo "${CI_BRANCH}" | sed 's/'${PATTERN_MINOR_BRANCH}'//g')";
    [ -z "${RESULT}" ] && echo 'true' || echo 'false';
}

getVersions () {
    local BRANCH="${1}";
    if [ -z "${BRANCH}" ]; then
        git tag --list 'v[0-9]*' --sort '-v:refname' | trimVersionFlag | grep -i '^'${PATTERN_STABLE_VERSION}'\(-[^ ]\+\)\?$'
    else
        local BRANCH_PATTERN=$(echo "${BRANCH}" | sed 's/\./\\./g')
        git tag --list 'v[0-9]*' --sort '-v:refname' | trimVersionFlag | grep -i '^'${PATTERN_STABLE_VERSION}'\(-[^ ]\+\)\?$' | grep '^'${BRANCH_PATTERN}
    fi;
}

getStableVersions () {
    getVersions ${1} | grep -i '^'${PATTERN_STABLE_VERSION}'$'
}

trimVersionFlag () {
    sed 's/^v\(.*\)/\1/g'
}


getLatestVersion () {
    getVersions ${1} | head -n1
}

getLatestStableVersion () {
    getStableVersions ${1} | head -n 1
}

getLatestStableOrPreVersion () {
    local BRANCH="${1}";
    reqVarNonEmpty BRANCH
    LATEST_VERSION="$(getLatestStableVersion "$(toMinorDevVersion "${BRANCH}")")";
    if [ -z "${LATEST_VERSION}" ]; then
        LATEST_VERSION="$(getLatestVersion "$(toMinorDevVersion "${BRANCH}")")";
    fi;
    echo "${LATEST_VERSION}";
}

isValidSemanticVersion () {
    local VERSION="${1}";
    local RESULT="$(python -c "import semantic_version; print(semantic_version.validate('${VERSION}'))")";
    [ "${RESULT}" == "True" ] && echo "true" || echo "false";
}

isPreRelease () {
    local VERSION="${1}";
    local RESULT="$(python -c "import semantic_version; print(len(semantic_version.Version('${VERSION}').prerelease) > 0)")";
    [ "${RESULT}" == "True" ] && echo "true" || echo "false";
}

toMinorDevVersion () {
    local VERSION="${1}";
    echo "${VERSION}" | sed 's/'${PATTERN_MINOR_BRANCH}'/\1-dev/g';
}

getImageLayers () {
   local IMAGE="${1}";
   docker image inspect -f '{{range $key, $value := .RootFS.Layers}}{{printf "%s\n" $value}}{{end}}' "${IMAGE}" | head -n -1;
}

isParentImageUpgraded () {
    local IMAGE="${1}";
    local PARENT_IMAGE="${2}";

    reqVarNonEmpty IMAGE
    reqVarNonEmpty PARENT_IMAGE

    local LAYERS="$(getLayers "${IMAGE}")";
    local PARENT_LAYERS="$(getLayers "${PARENT_IMAGE}")";

    local RESULT="$(echo "${LAYERS}" | grep "$(echo "${PARENT_LAYERS}" | tail -n 1)")";
    [ -z "${RESULT}" ] && echo "true" || echo "false"
}

isImageDownloaded () {
    local IMAGE="${1}";
    docker image inspect "${IMAGE}" &>/dev/null && echo 'true' || echo 'false'
}

deployCommandGen () (
    local GIT_HASH="$(git rev-list -n 1 HEAD)"
    local SEMANTIC_VERSION="false"
    local CURRENT_VERSION
    local LATEST_VERSION
    local LATEST_MINOR
    local LATEST_MAJOR
    local CUSTOM_TAGS
    local IMAGE_NAME
    local IMAGE_TAG="latest"
    local OPTIND
    local OPTARG

    while getopts ":v:l:m:M:i:t:T:s" opt; do
        case ${opt} in
            v) CURRENT_VERSION="${OPTARG}"; ;;
            l) LATEST_VERSION="${OPTARG}"; ;;
            m) LATEST_MINOR="${OPTARG}"; ;;
            M) LATEST_MAJOR="${OPTARG}"; ;;
            i) IMAGE_NAME="${OPTARG}"; ;;
            t) IMAGE_TAG="${OPTARG}"; ;;
            s) SEMANTIC_VERSION="true"; ;;
            T) CUSTOM_TAGS="${CUSTOM_TAGS} ${OPTARG}"; ;;
        esac;
    done;
    shift $((OPTIND-1))

    tag    () { echo docker tag \"${IMAGE_NAME}:${IMAGE_TAG}\" \"${IMAGE_NAME}:${1}\"; }
    push   () { echo docker push \"${IMAGE_NAME}:${1}\"; }
    pushAs () { [ "${IMAGE_TAG}" != "${1}"  ] && tag "${1}"; push "${1}"; };

    local CURRENT_VALID="$(isValidSemanticVersion "${CURRENT_VERSION}")"
    local LATEST_VALID="$(isValidSemanticVersion "${LATEST_VERSION}")"
    [ -z "${IMAGE_NAME}" ] && >&2 echo "IMAGE_NAME is empty" && exit 1;
    [ "${CURRENT_VALID}" != "true" ] && >&2 echo "Invalid CURRENT_VERSION: ${CURRENT_VERSION}" && return 1;
    [ "${LATEST_VALID}" != "true" -a -n "${LATEST_VERSION}" ] && >&2 echo "Invalid LATEST_VERSION: ${LATEST_VERSION}" && return 1;

    pushAs ${CURRENT_VERSION}
    local IS_PRE_RELEASE="$(isPreRelease "${CURRENT_VERSION}")";
    if [ "${SEMANTIC_VERSION}" == "true" ]; then
        [ -z "${LATEST_MINOR}" ] && LATEST_MINOR="$(getLatestStableVersion "$(echo "${CURRENT_VERSION}" | cut -d . -f1-2)")"
        [ -z "${LATEST_MAJOR}" ] && LATEST_MAJOR="$(git tag -l "v$(echo "${CURRENT_VERSION}" | cut -d . -f1).*")"
        [ -z "${LATEST_VERSION}" ] && LATEST_VERSION="$(getLatestStableVersion)"
        [ "${LATEST_MINOR}" == "${CURRENT_VERSION}" ] && pushAs "$(echo "${CURRENT_VERSION}" | cut -d . -f1-2)"
        [ "${LATEST_MAJOR}" == "${CURRENT_VERSION}" ] && pushAs "$(echo "${CURRENT_VERSION}" | cut -d . -f1)"
        [ "${LATEST_VERSION}" == "${CURRENT_VERSION}" -a -n "${LATEST_VERSION}" ] && pushAs latest
    fi;

    pushAs ${GIT_HASH}

    for i in ${CUSTOM_TAGS}; do
        pushAs ${i}
    done;
)

dcdCommandGen () {
    reqVarNonEmpty VERSION
    reqVarNonEmpty CI_IMAGE_NAME
    reqVarNonEmpty CI_EVENT_TYPE

    if [ "${CI_EVENT_TYPE}" == "cron" ]; then
        if [ "$(isBranch)" ]; then
            reqVarNonEmpty "${CI_BRANCH}";
            if [ "$(isMinorBranch)" == "true" ]; then
                LATEST_VERSION="$(getLatestStableOrPreVersion "${CI_BRANCH}")";
                if [ "${LATEST_VERSION}" ]; then
                    docker pull "${CI_IMAGE_NAME}:${GIT_HASH}";
                    docker pull "${CI_IMAGE_NAME}:${LATEST_VERSION}";
                    if [ "$(isImageDownloaded "${CI_IMAGE_NAME}:${GIT_HASH}")" ] && [ "$(isParentImageUpgraded "${CI_IMAGE_NAME}:${GIT_HASH}" "httpd:2.4")" == "true" ]; then
                        deployCommandGen -v "${LATEST_VERSION}" -i "${CI_IMAGE_NAME}" -t "${LATEST_VERSION}"
                    fi;
                fi;
           fi;
        fi;
    else
        if [ "$(isValidSemanticVersion "${VERSION}")" == "true" ]; then
            deployCommandGen -v "${VERSION}" -i "${CI_IMAGE_NAME}";
        elif [ "$(isMinorBranch "${VERSION}")" == "true" ]; then
            deployCommandGen -v $(toMinorDevVersion "${VERSION}") -i "${CI_IMAGE_NAME}";
        fi;
    fi;

}