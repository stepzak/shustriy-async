import socket
from src.event_loop import EventLoop
import httptools

_BUFFER = bytearray(65536)
_BUFFER_MV = memoryview(_BUFFER)

def http_echo_server(loop):
    server = socket.socket()
    server.setblocking(False)
    server.bind(('localhost', 8080))
    server.listen(2048)

    def handle_client(client):
        try:
            n = yield loop.sock_recv_static(client, _BUFFER_MV)
            if n <= 0:
                return

            raw_request = _BUFFER[:n]

            body = raw_request
            response = (
                b"HTTP/1.1 200 OK\r\n"
                b"Content-Type: text/plain\r\n"
                b"Connection: close\r\n"
                b"Content-Length: " + str(len(body)).encode() + b"\r\n"
                b"\r\n"
                + body
            )
            yield loop.sock_send(client, response)
        except Exception:
            pass
        finally:
            client.close()

    def accept_loop():
        while True:
            try:
                client, addr = yield loop.sock_accept(server)
                loop.create_task(handle_client(client))
            except Exception:
                pass

    loop.create_task(accept_loop())
    loop.run()

if __name__ == '__main__':
    loop = EventLoop()
    http_echo_server(loop)