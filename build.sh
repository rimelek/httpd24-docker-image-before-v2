#!/usr/bin/env bash

set -e

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

GIT_HASH="$(git rev-list -n 1 HEAD)"

VERSION_CACHE=$([ "${TRAVIS_BRANCH}" == "${TRAVIS_TAG}" ] && echo "${GIT_HASH}" || echo "${TRAVIS_BRANCH}-dev" )

docker pull "${HTTPD_IMAGE_NAME}:${VERSION_CACHE}" || true

if [ "${TRAVIS_BRANCH}" != "master" ]; then
    docker build --pull --cache-from "${HTTPD_IMAGE_NAME}:${VERSION_CACHE}" --tag "${HTTPD_IMAGE_NAME}:${GIT_HASH}" .
fi;