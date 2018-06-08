from test.definitions.containers import HttpdContainer
from seaworthy.definitions import ContainerDefinition
from pathlib import Path
import os


def httpd_fixture(name, *params):
    c = HttpdContainer(name, *params)
    return c.pytest_fixture(name)


def httpd_fixture_with_deps(name, dependencies, *params):
    c = HttpdContainer(name, *params)
    return c.pytest_fixture(name, dependencies=dependencies)


def test_reverse_proxy_localhost(httpd_reverse_proxy_localhost):
    httpd = httpd_reverse_proxy_localhost

    output = httpd.exec_conf_check('conf/httpd.conf', '^Include conf/custom-extra/reverse-proxy\.conf')
    assert len(output) == 1

    output = httpd.exec_conf_check('conf/custom-extra/reverse-proxy.conf', '^RemoteIPInternalProxy localhost')
    assert len(output) == 1

    output = httpd.exec_conf_check('conf/custom-extra/reverse-proxy.conf', '^RemoteIPHeader X-Forwarded-For')
    assert len(output) == 1


def test_reverse_proxy_ip(httpd_reverse_proxy_ip):
    httpd = httpd_reverse_proxy_ip

    output = httpd.exec_conf_check('conf/httpd.conf', '^Include conf/custom-extra/reverse-proxy\.conf')
    assert len(output) == 1

    output = httpd.exec_conf_check('conf/custom-extra/reverse-proxy.conf', '^RemoteIPInternalProxy 10\.1\.0\.0/16')
    assert len(output) == 1

    output = httpd.exec_conf_check('conf/custom-extra/reverse-proxy.conf', '^RemoteIPHeader X-Client-Ip')
    assert len(output) == 1


def test_proxy_protocol(httpd_proxy_protocol):
    httpd = httpd_proxy_protocol

    output = httpd.exec_conf_check('conf/custom-extra/reverse-proxy.conf', '^RemoteIPProxyProtocol On')
    assert len(output) == 1


if os.getenv('PYTEST_SKIP_SSL') != '1':
    def test_ssl(httpd_ssl):
        httpd = httpd_ssl

        output = httpd.exec_conf_check('conf/httpd.conf', '^Include conf/custom-extra/ssl\.conf')
        assert len(output) == 1

        assert httpd.exec_file_exists('ssl/custom.key')
        assert httpd.exec_file_exists('ssl/custom.crt')


def test_htaccess(httpd_htaccess):
    httpd = httpd_htaccess

    client = httpd.http_client()
    response = client.get('/welcome.html')

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Welcome here!" in response.text


def test_php(httpd_php, php_container):
    httpd = httpd_php

    client = httpd.http_client()
    response = client.get('/welcome/index.php')

    print (response.text)

    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "Welcome here!" in response.text


f1 = httpd_fixture('httpd_reverse_proxy_localhost', {
    'SRV_REVERSE_PROXY_DOMAIN': 'localhost',
})

f2 = httpd_fixture('httpd_reverse_proxy_ip', {
    'SRV_REVERSE_PROXY_DOMAIN': '10.1.0.0/16',
    'SRV_REVERSE_PROXY_CLIENT_IP_HEADER': 'X-Client-Ip'
})

f3 = httpd_fixture('httpd_proxy_protocol', {
    'SRV_PROXY_PROTOCOL': 'true',
})

f4 = httpd_fixture('httpd_ssl', {
    'SRV_SSL': 'true',
    'SRV_SSL_AUTO': 'true',
    'SRV_SSL_NAME': 'custom',
})

f5 = httpd_fixture('httpd_htaccess', {
    'SRV_ENABLE_MODULE': 'rewrite',
    'SRV_ALLOW_OVERRIDE': 'true',
    'SRV_DOCROOT': '/var/www/html'
}, {
    Path().absolute().as_posix() + '/test/www': '/var/www/html'
})

f6_php = ContainerDefinition(
    "php_for_httpd24",
    "php:7.2-fpm-alpine",
    create_kwargs={
        "volumes": {
            Path().absolute().as_posix() + '/test/www': '/var/www/html',
        }
    }).pytest_fixture("php_container")
f6 = httpd_fixture_with_deps('httpd_php', [
    'php_container',
], {
    'SRV_PHP': 'true',
    'SRV_PHP_HOST': 'php_for_httpd24',
    'SRV_DOCROOT': '/var/www/html'
}, {
    Path().absolute().as_posix() + '/test/www': '/var/www/html',
})
