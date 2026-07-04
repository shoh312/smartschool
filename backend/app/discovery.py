"""Lets the Flutter app find this backend automatically on the local network.

The phone/PC's LAN IP changes every time it joins a different Wi-Fi (a recurring
pain point), so instead of the client hardcoding an IP, it broadcasts a UDP
"who's out there" packet and this responder replies with the API port. The
client then talks to whichever address the reply actually came from.
"""

import asyncio
import socket

DISCOVERY_PORT = 8734
MAGIC_REQUEST = b"SMARTSCHOOL_DISCOVER_V1"
MAGIC_RESPONSE_PREFIX = b"SMARTSCHOOL_HERE:"


class _DiscoveryProtocol(asyncio.DatagramProtocol):
    def __init__(self, api_port: int):
        self.api_port = api_port
        self.transport: asyncio.DatagramTransport | None = None

    def connection_made(self, transport: asyncio.BaseTransport) -> None:
        self.transport = transport  # type: ignore[assignment]

    def datagram_received(self, data: bytes, addr: tuple[str, int]) -> None:
        if data.strip() != MAGIC_REQUEST or self.transport is None:
            return
        response = MAGIC_RESPONSE_PREFIX + str(self.api_port).encode()
        self.transport.sendto(response, addr)


async def start_discovery_responder(api_port: int = 8000) -> None:
    loop = asyncio.get_running_loop()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", DISCOVERY_PORT))
    sock.setblocking(False)

    await loop.create_datagram_endpoint(
        lambda: _DiscoveryProtocol(api_port),
        sock=sock,
    )
