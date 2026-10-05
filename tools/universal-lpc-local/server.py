"""Local launcher and on-demand cache for the official Universal LPC build."""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit, unquote, quote
from urllib.request import Request, urlopen
import mimetypes
import os
import threading
import json
import re

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / 'cache'
ORIGIN = 'https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/'
locks = {}
guard = threading.Lock()
EXPORTS = ROOT.parents[1] / '远征' / 'image' / 'role_lpc'

class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/__local/export' or self.headers.get('Origin') != 'http://127.0.0.1:18764':
            self.send_error(403)
            return
        role = self.headers.get('X-Role', '')
        name = unquote(self.headers.get('X-Filename', ''))
        size = int(self.headers.get('Content-Length', '0'))
        if role not in ('zs', 'ck', 'fs', 'fz') or not re.fullmatch(r'[A-Za-z0-9_.-]+', name) or not (0 < size <= 15000000):
            self.send_error(400)
            return
        folder = EXPORTS / role
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / name
        target.write_bytes(self.rfile.read(size))
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'saved': name, 'bytes': size}).encode())

    def do_GET(self):
        path = unquote(urlsplit(self.path).path).lstrip('/') or 'index.html'
        if path == '__local/export-bridge.js':
            data = (ROOT / 'export-bridge.js').read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if '..' in Path(path).parts or '\\' in path or ':' in path:
            self.send_error(400)
            return
        target = (CACHE / path).resolve()
        if not target.is_relative_to(CACHE.resolve()):
            self.send_error(400)
            return
        with guard:
            lock = locks.setdefault(path, threading.Lock())
        try:
            with lock:
                if not target.exists():
                    request = Request(ORIGIN + quote(path, safe='/'), headers={'User-Agent': 'Universal-LPC-local-cache/1.0'})
                    with urlopen(request, timeout=60) as response:
                        data = response.read()
                    target.parent.mkdir(parents=True, exist_ok=True)
                    temp = target.with_name(target.name + '.part')
                    temp.write_bytes(data)
                    os.replace(temp, target)
                data = target.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mimetypes.guess_type(path)[0] or 'application/octet-stream')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as exc:
            print(f'Failed to cache {path}: {exc}', flush=True)
            self.send_error(502, 'Official asset could not be downloaded; try again with network access.')

if __name__ == '__main__':
    CACHE.mkdir(exist_ok=True)
    if not (CACHE / 'index.html').exists():
        (CACHE / 'index.html').write_bytes((ROOT / 'index.html').read_bytes())
    print('Universal LPC: http://127.0.0.1:18764/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 18764), Handler).serve_forever()
