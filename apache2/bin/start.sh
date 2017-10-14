#!/usr/bin/env bash

CONF=/usr/local/apache2/conf/httpd.conf
PCONF=/usr/local/apache2/conf/extra/app-php.conf
SCONF=/usr/local/apache2/conf/extra/app-ssl.conf
RPCONF=/usr/local/apache2/conf/extra/app-reverse-proxy.conf

toBool () {
    local BOOL=$(echo "${1}" | tr '[:upper:]' '[:lower:]')
    if [ "${BOOL}" == "true" ] || [ "${BOOL}" == "1" ] || [ "${BOOL}" == "yes" ] || [ "${BOOL}" == "y" ]; then
        echo "true"
    else
        echo "false"
    fi
}

if [ $(toBool "${SRV_PHP}") == "false" ]; then
    sed -i 's/^#*\(\s*Include conf\/extra\/app-php.conf\)/#\1/g' ${CONF}
else
    sed -i 's/#\(\s*Include conf\/extra\/app-php.conf\)/\1/g' ${CONF}
fi

if [ "${SRV_PHP_HOST}" == "" ]; then
    sed -i 's#fcgi://\(.*\):9000#fcgi://php:9000#g' ${PCONF}
else
    sed -i 's#fcgi://\(.*\):9000#fcgi://'${SRV_PHP_HOST}':9000#g' ${PCONF}
fi

if [ "${SRV_PHP_PORT}" == "" ]; then
    sed -i 's#fcgi://\(.*\):(\d+)#fcgi://\1:9000#g' ${PCONF}
else
    sed -i 's#fcgi://\(.*\):9000#fcgi://\1:'${SRV_PHP_PORT}'#g' ${PCONF}
fi


if [ $(toBool "${SRV_SSL}") == "false" ]; then
    sed -i 's/^#*\(\s*Include conf\/extra\/app-ssl.conf\)/#\1/g' ${CONF}
else
    if [ $(toBool "${SRV_LETSENCRYPT}") == "true" ]; then
        if [ "${CERT_NAME}" == "" ]; then
            if [ "${SRV_NAME}" != "" ]; then
                CERT_NAME="${SRV_NAME}"
            elif [ "${VIRTUAL_HOST}" != "" ]; then
                CERT_NAME="${VIRTUAL_HOST}"
            fi
        fi;
        if [ "${CERT_NAME}" == "" ]; then
            >&2 echo "There is no valid CERT_NAME"
            exit 1;
        fi
        if [ "${SRV_CERT}" == "" ]; then
            SRV_CERT="/etc/letsencrypt/live/${CERT_NAME}/fullchain.pem";
        fi;
        if [ "${SRV_CERT_KEY}" == "" ]; then
            SRV_CERT_KEY="/etc/letsencrypt/live/${CERT_NAME}/privkey.pem"
        fi;
    fi

    if [ "${SRV_CERT}" == "" ]; then
        SRV_CERT="/usr/local/apache2/ssl.crt";
    fi

    if [ "${SRV_CERT_KEY}" == "" ]; then
        SRV_CERT_KEY="/usr/local/apache2/ssl.key";
    fi

    sed -i 's#SSLCertificateFile .*#SSLCertificateFile '${SRV_CERT}'#g' ${SCONF}
    sed -i 's#SSLCertificateKeyFile .*#SSLCertificateKeyFile '${SRV_CERT_KEY}'#g' ${SCONF}

    sed -i 's/#\(\s*Include conf\/extra\/app-ssl.conf\)/\1/g' ${CONF}
fi

if [ $(toBool "${SRV_AUTH}") == "false" ]; then
    sed -i 's/^#*\(\s*Include conf\/extra\/app-httpauth.conf\)/#\1/g' ${CONF}
else
    sed -i 's/#\(\s*Include conf\/extra\/app-httpauth.conf\)/\1/g' ${CONF}
fi

if [ "${SRV_ADMIN}" == "" ]; then
    sed -i 's/ServerAdmin .*/ServerAdmin webmaster@localhost/g' ${CONF}
else
    sed -i 's/ServerAdmin .*/ServerAdmin '${SRV_ADMIN}'/g' ${CONF}
fi

if [ "${SRV_NAME}" == "" ]; then
    sed -i 's/ServerName .*/ServerName localhost.localdomain/g' ${CONF}
else
    sed -i 's/ServerName .*/ServerName '${SRV_NAME}'/g' ${CONF}
fi

if [ "${SRV_DOCROOT}" == "" ]; then
    sed -i 's#DocumentRoot .*#DocumentRoot /usr/local/apache2/htdocs#g' ${CONF}
    sed -i 's#<Directory ".*"> \#docroot#<Directory "/usr/local/apache2/htdocs"> \#docroot#g' ${CONF}
else
    sed -i 's#DocumentRoot .*#DocumentRoot '${SRV_DOCROOT}'#g' ${CONF}
    sed -i 's#<Directory ".*"> \#docroot#<Directory "'${SRV_DOCROOT}'"> \#docroot#g' ${CONF}
fi

if [ "${SRV_REVERSE_PROXY_DOMAIN}" == "" ]; then
    sed -i 's/^#*\(\s*Include conf\/extra\/app-reverse-proxy.conf\)/#\1/g' ${CONF}
else
    sed -i 's/#\(\s*Include conf\/extra\/app-reverse-proxy.conf\)/\1/g' ${CONF}
    sed -i 's/RemoteIPInternalProxy .*/RemoteIPInternalProxy '${SRV_REVERSE_PROXY_DOMAIN}'/g' ${RPCONF}
    sed -i 's/RemoteIPHeader .*/RemoteIPHeader '${SRV_REVERSE_PROXY_CLIENT_IP_HEADER}'/g' ${RPCONF}
fi

exec httpd-foreground