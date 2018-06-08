from seaworthy.client import ContainerHttpClient as SWHttpClient


class ContainerHttpClient(SWHttpClient):
    @classmethod
    def for_container(cls, container, container_port=None, container_host=None):
        """
        :param container:
            The container to make requests against.
        :param container_port:
            The container port to make requests against. If ``None``, port 80 is used.
        :param container_host:
            The container host to make requests against. If ``None`` container IP is used.
        :returns:
            A ContainerClient object configured to make requests to the
            container.
        """
        if container_port is None:
           container_port = '80'

        if container_host is None:
            networks = container.inner().attrs.get('NetworkSettings').get('Networks')
            network_name = next(iter(networks))

            network = networks.get(network_name)
            ip = network.get('IPAddress')
            container_host = ip

        return cls(container_host, container_port)

