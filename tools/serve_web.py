#!/usr/bin/env python3
"""Local-only static server for the exported Web bundle.

Serves .playtest-build/web on 127.0.0.1 with the correct wasm MIME type and the
cross-origin-isolation headers Godot Web builds may need (harmless for the
current no-threads build, required if thread support is ever enabled).
This is a playtest convenience, not a deployment mechanism: it binds to
loopback only unless --host is passed explicitly.
"""
import argparse
import http.server
from pathlib import Path

BUILD_DIR = Path(__file__).resolve().parent.parent / ".playtest-build" / "web"


class BundleHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    quiet = False

    def log_message(self, fmt: str, *args) -> None:
        if not self.quiet:
            super().log_message(fmt, *args)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if not (BUILD_DIR / "index.html").exists():
        raise SystemExit(f"error: no bundle at {BUILD_DIR}; run tools/build_web.sh first")

    BundleHandler.quiet = args.quiet
    handler = lambda *a, **kw: BundleHandler(*a, directory=str(BUILD_DIR), **kw)
    with http.server.ThreadingHTTPServer((args.host, args.port), handler) as httpd:
        if not args.quiet:
            print(f"Serving {BUILD_DIR} at http://{args.host}:{args.port}/ (Ctrl+C to stop)")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
