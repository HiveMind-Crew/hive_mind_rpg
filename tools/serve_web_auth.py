#!/usr/bin/env python3
"""Authenticated loopback-only server for the temporary browser playtest.

Credentials are supplied only at runtime:
  WEB_PLAYTEST_USERNAME       Basic Auth username
  WEB_PLAYTEST_PASSWORD_FILE  absolute path to a mode-0600 password file

The script has no credentials or public host default. It serves the ignored
`.playtest-build/web/` bundle created by tools/build_web.sh.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hmac
import http.server
import os
import secrets
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BUNDLE_DIR = REPO_ROOT / ".playtest-build" / "web"
PASSWORD_FILE_ENV = "WEB_PLAYTEST_PASSWORD_FILE"
USERNAME_ENV = "WEB_PLAYTEST_USERNAME"
ALLOW_WEAK_PASSWORD_ENV = "WEB_PLAYTEST_ALLOW_WEAK_PASSWORD"


def _load_credentials() -> tuple[str, str]:
    username = os.environ.get(USERNAME_ENV, "")
    password_file_value = os.environ.get(PASSWORD_FILE_ENV, "")
    if not username or not password_file_value:
        raise ValueError(
            "missing WEB_PLAYTEST_USERNAME or WEB_PLAYTEST_PASSWORD_FILE; "
            "refusing to start an unauthenticated playtest"
        )

    password_file = Path(password_file_value).expanduser().resolve()
    try:
        mode = password_file.stat().st_mode & 0o777
    except FileNotFoundError as error:
        raise ValueError(f"password file does not exist: {password_file}") from error
    if mode & 0o077:
        raise ValueError(f"password file must be owner-only (0600): {password_file}")

    password = password_file.read_text(encoding="utf-8").strip()
    if len(password) < 8:
        raise ValueError("password must contain at least 8 characters")
    if len(password) < 20 and os.environ.get(ALLOW_WEAK_PASSWORD_ENV) != "yes":
        raise ValueError(
            "passwords shorter than 20 characters require "
            "WEB_PLAYTEST_ALLOW_WEAK_PASSWORD=yes"
        )
    return username, password


class AuthenticatedBundleHandler(http.server.SimpleHTTPRequestHandler):
    credentials = ""
    quiet = False

    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def log_message(self, format: str, *args: object) -> None:
        if not self.quiet:
            super().log_message(format, *args)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def _is_authenticated(self) -> bool:
        header = self.headers.get("Authorization", "")
        scheme, separator, encoded = header.partition(" ")
        if scheme.lower() != "basic" or not separator or not encoded:
            return False
        try:
            supplied = base64.b64decode(encoded, validate=True).decode("utf-8")
        except (binascii.Error, UnicodeDecodeError):
            return False
        return secrets.compare_digest(supplied, self.credentials)

    def _request_authentication(self) -> None:
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Hive Mind RPG playtest", charset="UTF-8"')
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:
        if not self._is_authenticated():
            self._request_authentication()
            return
        super().do_GET()

    def do_HEAD(self) -> None:
        if not self._is_authenticated():
            self._request_authentication()
            return
        super().do_HEAD()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=9125)
    parser.add_argument("--quiet", action="store_true")
    args = parser.parse_args()

    if args.host not in {"127.0.0.1", "::1", "localhost"}:
        print("error: authenticated playtest server must bind to loopback only", file=sys.stderr)
        return 2
    if not (BUNDLE_DIR / "index.html").is_file():
        print("error: no Web bundle; run tools/build_web.sh first", file=sys.stderr)
        return 3

    try:
        username, password = _load_credentials()
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 4

    AuthenticatedBundleHandler.credentials = f"{username}:{password}"
    AuthenticatedBundleHandler.quiet = args.quiet
    handler = lambda *handler_args, **handler_kwargs: AuthenticatedBundleHandler(
        *handler_args, directory=str(BUNDLE_DIR), **handler_kwargs
    )
    with http.server.ThreadingHTTPServer((args.host, args.port), handler) as server:
        print(f"Serving authenticated bundle on http://{args.host}:{args.port}/")
        server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
