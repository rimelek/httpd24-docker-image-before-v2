#!/usr/bin/env bash

if [ -n "${TRAVIS_TAG}" ]; then
    # for easier local test
    TRAVIS_BRANCH="${TRAVIS_TAG}";
fi;

if [ -z "${HTTPD_IMAGE_NAME}" ]; then
    >&2 echo "Missing variable: HTTPD_IMAGE_NAME";
    exit 1
fi;

if [ -z "${TRAVIS_BRANCH}" ]; then
    >&2 echo "Missing variable: TRAVIS_BRANCH";
    exit 1
fi;

# remove first character if that is "v"
VERSION=$(echo "${TRAVIS_BRANCH}" | sed 's/^v\(.*\)$/\1/g')
VALID_SEMANTIC_VERSION=$(python -c "import semantic_version; print(semantic_version.validate('${VERSION}'))");
GIT_HASH="$(git rev-list -n 1 HEAD)";
LATEST_VERSION="";

if [ "${TRAVIS_BRANCH}" == "master" ]; then
    LATEST_VERSION=$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort '-v:refname' | head -n1 | sed 's/^v\(.*\)/\1/g');
    if [ -z "${LATEST_VERSION}" ]; then
        >&2 echo "Cannot detect latest version";
        exit 1;
    fi;
    docker pull "${HTTPD_IMAGE_NAME}:${LATEST_VERSION}" || exit $?
    docker tag "${HTTPD_IMAGE_NAME}:${LATEST_VERSION}" "latest"
else
    # we cannot use dcd --version and set the tag of the built image other than latest
    # (must not push latest without set the exact semantic version as latest)
    docker tag "${HTTPD_IMAGE_NAME}:${GIT_HASH}" "latest"
fi;

DEPLOY_DEBUG="";
DEPLOY_PRINT=""
while getopts ":d" arg; do
    case ${arg} in
        d) DEPLOY_DEBUG="y"; ;;
    esac;
done;

dcdCommandGen () {
    DRY_RUN=$([ "${DEPLOY_DEBUG}" == "y" ] && echo '--dry-run');

    if [ "${VALID_SEMANTIC_VERSION}" == "True" ]; then
        PRE_RELEASE=$(python -c "import semantic_version; print(len(semantic_version.Version('${VERSION}').prerelease) > 0)");
        if [ "${PRE_RELEASE}" == "True" ]; then
            # pre-release versions cannot get latest and major.minor.patch tags.
            echo dcd ${DRY_RUN}  --version "${VERSION}" "${HTTPD_IMAGE_NAME}"
        else
            echo dcd ${DRY_RUN} --version "${VERSION}" --version-semver "${HTTPD_IMAGE_NAME}";
        fi;
        echo dcd ${DRY_RUN} --version "${GIT_HASH}" "${HTTPD_IMAGE_NAME}"
    else
        VERSION_DEV_PATTERN='^\([0-9]\+\.[0-9]\+\)\(-dev\)\?$';
        NOT_MATCHED="$(echo "${VERSION}" | sed 's/'${VERSION_DEV_PATTERN}'//g')";
        CONVERTED_VERSION="$(echo "${VERSION}" | sed 's/'${VERSION_DEV_PATTERN}'/\1/g')-dev";
        if [ -z "${NOT_MATCHED}" ]; then
            echo dcd ${DRY_RUN} --version "${CONVERTED_VERSION}" "${HTTPD_IMAGE_NAME}";
            echo dcd ${DRY_RUN} --version "${GIT_HASH}" "${HTTPD_IMAGE_NAME}"
        fi;
    fi;
}

if [ "${TRAVIS_BRANCH}" == "master" ]; then
    COMMAND='git push "'${HTTPD_IMAGE_NAME}':latest"'
    echo ${COMMAND}
    if [ "${DEPLOY_DEBUG}" != "y" ]; then
        eval "${COMMAND}";
    fi;
else
    DCD_COMMAND="$(dcdCommandGen)";

    echo "DCD COMMAND:"
    echo "${DCD_COMMAND}";

    if [ -n "${DCD_COMMAND}" ]; then
        eval "${DCD_COMMAND}";
    fi;
fi;