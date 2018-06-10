#!/usr/bin/env bash

GIT_HASH="$(git rev-list -n 1 HEAD)"
PATTERN_MINOR_BRANCH='^\([0-9]\+\.[0-9]\+\)\(-dev\)\?$';
PATTERN_STABLE_VERSION='[0-9]\+\.[0-9]\+\.[0-9]\+'

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

toMinorVersion () {
    local VERSION="${1}";
    echo "${VERSION}" | sed 's/'${PATTERN_MINOR_BRANCH}'/\1-dev/g';
}

dcdCommandGen () {
    reqVarNonEmpty VERSION
    reqVarNonEmpty CI_IMAGE_NAME

    local DRY_RUN=$([ "${CI_DRY_RUN}" == "y" ] && echo '--dry-run');

    if [ "$(isValidSemanticVersion "${VERSION}")" == "true" ]; then
        # pre-release versions cannot get latest and major.minor.patch tags.
        local ATTR_SEMVER=$([ "$(isPreRelease "${VERSION}")" == "true" ] || echo '--version-semver');
        echo dcd ${DRY_RUN} --version "${VERSION}" ${ATTR_SEMVER} "${CI_IMAGE_NAME}";
        echo dcd ${DRY_RUN} --version "${GIT_HASH}" "${CI_IMAGE_NAME}"
    elif [ "$(isMinorBranch "${VERSION}")" == "true" ]; then
        echo dcd ${DRY_RUN} --version $(toMinorVersion "${VERSION}") "${CI_IMAGE_NAME}";
        echo dcd ${DRY_RUN} --version "${GIT_HASH}" "${CI_IMAGE_NAME}"
    fi;
}

# we cannot use dcd --version and set the tag of the built image other than latest
# (must not push latest without set the exact semantic version as latest)
prepareDCDLatestCommandGen () {
    reqVarNonEmpty CI_BRANCH
    reqVarNonEmpty CI_IMAGE_NAME

    if [ "${CI_BRANCH}" == "master" ]; then
        local LATEST_VERSION="$(getLatestStableVersion)";
        reqVarNonEmpty LATEST_VERSION
        echo docker pull "${CI_IMAGE_NAME}:${LATEST_VERSION}"
        echo docker tag "${CI_IMAGE_NAME}:${LATEST_VERSION}" "${CI_IMAGE_NAME}:latest"
    else
        echo docker tag "${CI_IMAGE_NAME}:${GIT_HASH}" "${CI_IMAGE_NAME}:latest"
    fi;
}

