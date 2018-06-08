from seaworthy.definitions import ContainerDefinition
from seaworthy.logs import output_lines
from test.definitions.client import ContainerHttpClient
import os


class HttpdContainer(ContainerDefinition):
    IMAGE_REPO = os.getenv('HTTPD_IMAGE_NAME', 'localhost/httpd24')
    IMAGE_TAG = os.getenv('HTTPD_IMAGE_TAG', 'dev')
    WAIT_PATTERNS = [
        r'Command line: \'httpd -D FOREGROUND\'',
    ]
    WAIT_TIMEOUT = float(os.getenv('HTTPD_WAIT_TIMEOUT', 180.0))

    def __init__(self, name, environments, volumes={}):
        super().__init__(name, self.IMAGE_REPO + ':' + self.IMAGE_TAG, self.WAIT_PATTERNS, self.WAIT_TIMEOUT,
                         create_kwargs={'environment': environments, 'volumes': volumes})

    def exec(self, *cmd):
        return self.inner().exec_run(['bash', '-c', ' '.join(cmd)])

    def exec_conf_check(self, conf, pattern):
        return output_lines(self.exec(
            'cat', conf, '|',  'grep', '"' + pattern + '"',
        ))

    def exec_file_exists(self, file):
        output = output_lines(self.exec('[ -f ' + file + ' ] && echo 1 || 0'));
        return output[0] == '1'

    def http_client(self, port=None, host=None):
        client = ContainerHttpClient.for_container(self, container_port=port, container_host=host)
        self._http_clients.append(client)
        return client
