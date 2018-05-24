#!/usr/bin/env bash

source "$(dirname "$0")"/app-resources.sh

switchModules "${SRV_DISABLE_MODULE}" "off";
switchModules "${SRV_ENABLE_MODULE}" "on";

switchConfigs "${SRV_DISABLE_CONFIG}" "off";
switchConfigs "${SRV_ENABLE_CONFIG}" "on";

switchConfig "@php" "${SRV_PHP}";
switchConfig "@httpauth" "${SRV_AUTH}";

SRV_AUTH_BOOL="$(toBool "${SRV_AUTH}")";
if [ "${SRV_AUTH_BOOL}" == "true" ]; then
    if [ -n "${SRV_AUTH_USERS}" ]; then
        ORIG_IFS="${IFS}";
        IFS=$'\n\r';
        PASSWD_PATH="/usr/local/apache2/.htpasswd";
        if [ -f "${PASSWD_PATH}" ]; then
            truncate "${PASSWD_PATH}";
        fi;
        for LINE in ${SRV_AUTH_USERS}; do
            AUTH_USER="$(echo "${LINE}" | cut -d ' ' -f1 )";
            AUTH_PASS="$(echo "${LINE}" | cut -d ' ' -f2- )";
            htpasswd -nb "${AUTH_USER}" "${AUTH_PASS}" >> "${PASSWD_PATH}"
        done;
        IFS="${ORIG_IFS}"
    fi;
fi;

setAdminEmail "${SRV_ADMIN}";
setServerName "${SRV_NAME}";

setDocRoot "${SRV_DOCROOT}";
allowOverride "${SRV_ALLOW_OVERRIDE}";

if [ $(toBool "${SRV_SSL}") == "false" ]; then
    switchConfig "@ssl" "off";
else
    SRV_SSL_LETSENCRYPT_BOOL="$(toBool "${SRV_SSL_LETSENCRYPT}")";
    CERT_NAME="$(selectCertName)";
    if [ -z "${SRV_SSL_CERT}" ]; then
        if [ -z "${CERT_NAME}" ]; then
            >&2 echo "There is no valid CERT_NAME"
            exit 1;
        fi
        if [ "${SRV_SSL_LETSENCRYPT_BOOL}" == "true" ]; then
            SRV_SSL_CERT="/etc/letsencrypt/live/${CERT_NAME}/fullchain.pem";
        else
            SRV_SSL_CERT="/usr/local/apache2/ssl/${CERT_NAME}.crt";
        fi;
    fi;
    
    if [ -z "${SRV_SSL_KEY}" ]; then
         if [ -z "${CERT_NAME}" ]; then
            >&2 echo "There is no valid CERT_NAME"
            exit 1;
        fi
        if [ "${SRV_SSL_LETSENCRYPT_BOOL}" = "true" ]; then
            SRV_SSL_KEY="/etc/letsencrypt/live/${CERT_NAME}/privkey.pem";
        else
            SRV_SSL_KEY="/usr/local/apache2/ssl/${CERT_NAME}.key";
        fi;
    fi;
    
    sed -i 's#SSLCertificateFile .*#SSLCertificateFile '${SRV_SSL_CERT}'#g' ${SCONF}
    sed -i 's#SSLCertificateKeyFile .*#SSLCertificateKeyFile '${SRV_SSL_KEY}'#g' ${SCONF}

    SRV_SSL_AUTO_BOOL=$(toBool "${SRV_SSL_AUTO}");
    if [ "${SRV_SSL_AUTO_BOOL}" == "true" ] && [ ! -f "${SRV_SSL_CERT}" ] && [ ! -f "${SRV_SSL_KEY}" ]; then
        generateSSL "${SRV_SSL_CERT}" "${SRV_SSL_KEY}" "${SRV_NAME}";
    fi; 

    switchConfig "@ssl" "on";
fi

SRV_PROXY_PROTOCOL_BOOL="$(toBool "${SRV_PROXY_PROTOCOL}")";
if [ -z "${SRV_REVERSE_PROXY_DOMAIN}" ] && [ "${SRV_PROXY_PROTOCOL_BOOL}" != "true" ]; then
    switchConfig "@reverse-proxy" "off";
else
    switchConfig "@reverse-proxy" "on";
    if [ "${SRV_PROXY_PROTOCOL_BOOL}" == "true" ]; then
        echo "RemoteIPProxyProtocol On" >> ${RPCONF};
    elif [  -n "${SRV_REVERSE_PROXY_DOMAI}" ]; then
        echo "RemoteIPHeader ${SRV_REVERSE_PROXY_CLIENT_IP_HEADER}" >> ${RPCONF};
        echo "RemoteIPInternalProxy ${SRV_REVERSE_PROXY_DOMAIN}" >> ${RPCONF};
    fi;
fi

/usr/local/apache2/bin/before-start.sh

exec httpd-foreground