#!/usr/bin/env bash

set -o xtrace -o errexit

trap 'RET=$? &&  [ -n "${CONTAINER_NAMES}" ] && docker rm -f ${CONTAINER_NAMES} && exit ${RET};' EXIT;

source "test-resources.sh";

dRun '-d -e "SRV_REVERSE_PROXY_DOMAIN=localhost"' httpdtest itsziget/httpd24:2.0-dev
dWaitForHTTPD httpdtest
dGrep httpdtest /usr/local/apache2/conf/httpd.conf "^Include conf/custom-extra/reverse-proxy";
dGrep httpdtest conf/custom-extra/reverse-proxy.conf '^RemoteIPInternalProxy localhost'
dGrep httpdtest conf/custom-extra/reverse-proxy.conf '^RemoteIPHeader X-Forwarded-For'
dRm httpdtest

dRun '-d -e "SRV_REVERSE_PROXY_DOMAIN=10.1.0.0/16"' httpdtest itsziget/httpd24:2.0-dev
dWaitForHTTPD httpdtest
dGrep httpdtest conf/httpd.conf "^Include conf/custom-extra/reverse-proxy.conf";


dGrep httpdtest conf/custom-extra/reverse-proxy.conf '^RemoteIPInternalProxy 10\.1\.0\.0/16'
dGrep httpdtest conf/custom-extra/reverse-proxy.conf '^RemoteIPHeader X-Forwarded-For'
dRm httpdtest


dRun '-d -e SRV_REVERSE_PROXY_DOMAIN="localhost" -e SRV_SSL=true -e SRV_SSL_AUTO=true -e SRV_SSL_NAME=ssl' httpdtest itsziget/httpd24:2.0-dev
dWaitForHTTPD httpdtest 2
dGrep httpdtest conf/httpd.conf "^Include $(getConfigPath "@ssl")";
dFileCheck httpdtest /usr/local/apache2/ssl/ssl.key
dFileCheck httpdtest /usr/local/apache2/ssl/ssl.crt

dRm httpdtest

