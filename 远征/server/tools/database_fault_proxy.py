"""Disposable loopback test proxy; pause only the fixture gateway's DB traffic.

No messages, connection bytes, credentials or payloads are inspected or logged.
The actual PostgreSQL service and every unrelated connection remain untouched.
"""
import select
import socket
import socketserver
import threading


class DatabaseFaultProxy:
    def __init__(self, target_port):
        self.target = ("127.0.0.1", target_port)
        self.enabled = True
        self.lock = threading.Lock()
        self.pairs = set()
        owner = self

        class Handler(socketserver.BaseRequestHandler):
            def handle(self):
                remote = None
                pair = None
                try:
                    with owner.lock:
                        if not owner.enabled:
                            return
                    remote = socket.create_connection(owner.target, timeout=5)
                    self.request.settimeout(5)
                    remote.settimeout(5)
                    pair = (self.request, remote)
                    with owner.lock:
                        if not owner.enabled:
                            return
                        owner.pairs.add(pair)
                    while True:
                        readable, _, _ = select.select(pair, (), (), 0.2)
                        for source in readable:
                            data = source.recv(65536)
                            if not data:
                                return
                            destination = remote if source is self.request else self.request
                            destination.sendall(data)
                except (OSError, ValueError):
                    pass
                finally:
                    if pair:
                        with owner.lock:
                            owner.pairs.discard(pair)
                    if remote:
                        remote.close()

        class Server(socketserver.ThreadingTCPServer):
            allow_reuse_address = True
            daemon_threads = True

        self.server = Server(("127.0.0.1", 0), Handler)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def pause(self):
        with self.lock:
            self.enabled = False
            pairs = list(self.pairs)
        for pair in pairs:
            for connection in pair:
                try:
                    connection.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                connection.close()

    def resume(self):
        with self.lock:
            self.enabled = True

    def close(self):
        self.pause()
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
