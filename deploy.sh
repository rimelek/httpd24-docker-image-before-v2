#!/usr/bin/env bash

# remove first character if that is "v"
VERSION_ORIG="${VERSION}"
VERSION=$(echo "${VERSION_ORIG}" | sed 's/^v\(.*\)$/\1/g')

VALID_VERSION=$(python -c "import semantic_version; print(semantic_version.validate('${VERSION}'))");

if [ -z "${HTTPD_IMAGE_NAME}" ]; then
    >&2 echo "Missing variable: HTTPD_IMAGE_NAME";
    exit 1
fi;

DEPLOY_DEBUG="";
while getopts ":d" arg; do
    case ${arg} in
        d) DEPLOY_DEBUG="y"; ;;
    esac;
done;

commandGen () {
    DRY_RUN=$([ "${DEPLOY_DEBUG}" == "y" ] && echo '--dry-run');
    # deploy only in case of valid semantic versions
    if [ "${VALID_VERSION}" == "True" ]; then
        PRE_RELEASE=$(python -c "import semantic_version; print(len(semantic_version.Version('${VERSION}').prerelease) > 0)");
        if [ "${PRE_RELEASE}" == "True" ]; then
            # pre-release versions cannot get latest and major.minor.patch tags.
            echo dcd --dry-run --version "${VERSION}" "${HTTPD_IMAGE_NAME}"
        else
            CURRENT_HASH="$(git rev-list -n 1 "${VERSION_ORIG}")";
            LATEST_HASH="$(git rev-list -n 1 master)";
            if [ "${LATEST_HASH}" == "${CURRENT_HASH}" ]; then
                echo dcd ${DRY_RUN} --version "${VERSION}" --version-semver --version-latest "${HTTPD_IMAGE_NAME}";
            else
                echo dcd ${DRY_RUN} --version "${VERSION}" --version-semver "${HTTPD_IMAGE_NAME}";
            fi;
        fi;
    else
        VERSION_DEV_PATTERN='^\([0-9]\+\.[0-9]\+\)\(-dev\)\?$';
        NOT_MATCHED="$(echo "${VERSION}" | sed 's/'${VERSION_DEV_PATTERN}'//g')";
        CONVERTED_VERSION="$(echo "${VERSION}" | sed 's/'${VERSION_DEV_PATTERN}'/\1/g')";
        if [ -z "${NOT_MATCHED}" ]; then
            echo dcd ${DRY_RUN} --version "${CONVERTED_VERSION}" "${HTTPD_IMAGE_NAME}";
        fi;
    fi;
}

COMMAND="$(commandGen)";

echo "DCD COMMAND:"
echo "${COMMAND}";

if [ "${DEPLOY_DEBUG}" != "y" ]; then
    if [ -n "${COMMAND}" ]; then
        eval "${COMMAND}";
    fi;
fi;