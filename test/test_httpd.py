from test.definitions.containers import HttpdContainer


def httpd_fixture(name, *params):
    c = HttpdContainer(name, *params)
    return c.pytest_fixture(name)


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


def test_ssl(httpd_ssl):
    httpd = httpd_ssl

    output = httpd.exec_conf_check('conf/httpd.conf', '^Include conf/custom-extra/ssl\.conf')
    assert len(output) == 1

    assert httpd.exec_file_exists('ssl/custom.key')
    assert httpd.exec_file_exists('ssl/custom.crt')


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
