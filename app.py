"""Учебный HTTP-сервис без внешних Python-зависимостей."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

ROOT = Path(__file__).parent

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            body = json.dumps({'status': 'ok', 'version': (ROOT / 'VERSION').read_text().strip(), 'commit': (ROOT / 'REVISION').read_text().strip()}).encode()
            status, kind = 200, 'application/json'
        elif self.path == '/':
            body = (ROOT / 'index.html').read_bytes()
            status, kind = 200, 'text/html; charset=utf-8'
        else:
            body, status, kind = b'Not found', 404, 'text/plain'
        self.send_response(status)
        self.send_header('Content-Type', kind)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

if __name__ == '__main__':
    HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
