#!/usr/bin/env python3
"""Serve the Godot web export (build/web) for local testing.

    python tools/serve_web.py            # http://localhost:8060 (this machine only)
    python tools/serve_web.py --lan      # also reachable from a phone on the same Wi-Fi
    python tools/serve_web.py --port 9000 --dir build/web

Sends no-cache headers (so a re-export is picked up on reload), the right MIME
types for .wasm/.pck, and COOP/COEP headers so threaded builds also work.
"""
import argparse
import functools
import http.server
import os
import socket


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def lan_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("10.255.255.255", 1))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    p = argparse.ArgumentParser()
    p.add_argument("--port", type=int, default=8060)
    p.add_argument("--dir", default=os.path.join(root, "build", "web"))
    p.add_argument("--lan", action="store_true", help="bind to all interfaces")
    a = p.parse_args()

    if not os.path.isfile(os.path.join(a.dir, "index.html")):
        raise SystemExit(f"No index.html in {a.dir} - export the 'Web' preset first.")

    host = "0.0.0.0" if a.lan else "127.0.0.1"
    handler = functools.partial(Handler, directory=a.dir)
    with http.server.ThreadingHTTPServer((host, a.port), handler) as httpd:
        print(f"Serving {a.dir}")
        print(f"  http://localhost:{a.port}")
        if a.lan:
            print(f"  http://{lan_ip()}:{a.port}  (phone on same network)")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
