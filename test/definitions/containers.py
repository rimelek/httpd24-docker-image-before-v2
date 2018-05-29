from seaworthy.definitions import ContainerDefinition
from seaworthy.logs import output_lines


class HttpdContainer(ContainerDefinition):
    IMAGE = 'itsziget/httpd24:2.0-dev'
    WAIT_PATTERNS = [
        r'Command line: \'httpd -D FOREGROUND\'',
    ]
    WAIT_TIMEOUT = 180.0

    def __init__(self, name, environments):
        super().__init__(name, self.IMAGE, self.WAIT_PATTERNS, self.WAIT_TIMEOUT,
                         create_kwargs={'environment': environments})

    def exec(self, *cmd):
        return self.inner().exec_run(['bash', '-c', ' '.join(cmd)])

    def exec_conf_check(self, conf, pattern):
        return output_lines(self.exec(
            'cat', conf, '|',  'grep', '"' + pattern + '"',
        ))

    def exec_file_exists(self, file):
        output = output_lines(self.exec('[ -f ' + file + ' ] && echo 1 || 0'));
        return output[0] == '1'
