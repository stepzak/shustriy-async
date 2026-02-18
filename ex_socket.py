import socket
from src.event_loop import EventLoop

def echo_server(loop):
    server = socket.socket()
    server.setblocking(False)
    server.bind(('localhost', 8080))
    server.listen(2048)

    def handle_client(client):
        try:
            while True:
                data = yield loop.sock_recv(client, 1024)
                if not data:
                    break
                yield loop.sock_send(client, data)
        except OSError as e:
            print(f"Disconnect: {e}")
        except Exception as e:
            print(e)
        finally:
            client.close()
    def accept_loop():
        print("Accept loop")
        while True:
            try:
                client, addr = yield loop.sock_accept(server)
                print(f"New connect: {addr}")
                loop.create_task(handle_client(client))
            except OSError as e:
                print(f"Connecttion error: {e}")
                continue

            except Exception as e:
                print(e)
                break

    loop.create_task(accept_loop())
    loop.run()

if __name__ == '__main__':
    loop = EventLoop()
    echo_server(loop)