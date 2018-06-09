#!/usr/bin/env bash

set -e

PROJECT_ROOT=$(dirname "$(dirname "$(realpath -s "$0")")");
cd "${PROJECT_ROOT}"

GIT_HASH=""

source "${PROJECT_ROOT}/ci/resources.sh"

CI_DRY_RUN="";
CI_BRANCH="";
CI_TAG=""
CI_IMAGE_NAME=""

while getopts ":t:b:i:dh" opt; do
    case ${opt} in
        d) CI_DRY_RUN="y"; ;;
        t) CI_TAG="${OPTARG}"; ;;
        b) CI_BRANCH="${OPTARG}"; ;;
        i) CI_IMAGE_NAME="${OPTARG}"; ;;
        h)
            echo "Usage: $0 [-d] [-t <string>] [-b <string>] [-i <string>] [-h]";
            echo "Options:"
            echo -e "\t-d\t\tJust print commands without running them";
            echo -e "\t-t <string>\tGit commit tag if the build was triggered by tag. Do not use it anyway!";
            echo -e "\t-b <string>\tGit branch if the build was triggered by branch. If \"-t\" was given too, \"-b\" will always be ignored!";
            echo -e "\t-i <string>\tDocker image name without version tag.";
            echo -e "\t-h\t\tShows this help message";
            exit 0;
            ;;
        *)
            >&2 echo "Invalid option: -${OPTARG}. Use \"-h\" to get help."
            exit 1;
            ;;
    esac;
done;
shift $((OPTIND-1))

[ -n "${CI_TAG}" ] && CI_BRANCH="${CI_TAG}"; # for easier local test

reqVarNonEmpty CI_IMAGE_NAME
reqVarNonEmpty CI_BRANCH
reqVarNonEmpty GIT_HASH

VERSION_CACHE=$([ "$(isBranch)" == "true" ] && echo "${CI_BRANCH}-dev" || echo "${GIT_HASH}")


COMMAND='docker pull "'${CI_IMAGE_NAME}:${VERSION_CACHE}'" || true'
echo ${COMMAND}
[ "${CI_DRY_RUN}" != "y" ] && eval "${COMMAND}"

if [ "${CI_BRANCH}" != "master" ]; then
    COMMAND='docker build --pull --cache-from "'${CI_IMAGE_NAME}:${VERSION_CACHE}'" --tag "'${CI_IMAGE_NAME}:${GIT_HASH}'" .'
    echo ${COMMAND}
    [ "${CI_DRY_RUN}" != "y" ] && eval "${CI_DRY_RUN}"
fi;
