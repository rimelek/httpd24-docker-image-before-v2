#!/usr/bin/env bash

CONF=/usr/local/apache2/conf/httpd.conf
PCONF=/usr/local/apache2/conf/extra/app-php.conf
RPCONF=/usr/local/apache2/conf/extra/app-reverse-proxy.conf

if [ "${SRV_PHP}" == "" ] || [ "${SRV_PHP}" == "0" ] \
|| [ "${SRV_PHP}" == "false" ] || [ "${SRV_PHP}" == "no" ]; then
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


if [ "${SRV_SSL}" == "" ] || [ "${SRV_SSL}" == "0" ] \
|| [ "${SRV_SSL}" == "false" ] || [ "${SRV_SSL}" == "no" ]; then
    sed -i 's/^#*\(\s*Include conf\/extra\/app-ssl.conf\)/#\1/g' ${CONF}
else
    sed -i 's/#\(\s*Include conf\/extra\/app-ssl.conf\)/\1/g' ${CONF}
fi

if [ "${SRV_AUTH}" == "" ] || [ "${SRV_AUTH}" == "0" ] \
|| [ "${SRV_AUTH}" == "false" ] || [ "${SRV_AUTH}" == "no" ]; then
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