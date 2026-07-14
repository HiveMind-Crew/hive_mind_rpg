#!/usr/bin/env bash
# Static smoke check for the exported Web bundle in .playtest-build/web.
# Verifies the expected artifacts exist, have sane magic bytes, and are
# servable over HTTP from a throwaway local static server.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/.playtest-build/web"

fail() { echo "smoke: FAIL — $*" >&2; exit 1; }

[[ -d "$OUT_DIR" ]] || fail "$OUT_DIR does not exist; run tools/build_web.sh first"

# Core artifacts of a Godot 4.x Web export.
for f in index.html index.js index.wasm index.pck; do
    [[ -s "$OUT_DIR/$f" ]] || fail "missing or empty artifact: $f"
done

# Magic bytes: wasm modules start with '\0asm', Godot packs with 'GDPC'.
[[ "$(head -c4 "$OUT_DIR/index.wasm" | od -An -tx1 | tr -d ' ')" == "0061736d" ]] \
    || fail "index.wasm lacks the \\0asm wasm magic"
[[ "$(head -c4 "$OUT_DIR/index.pck")" == "GDPC" ]] \
    || fail "index.pck lacks the GDPC pack magic"
grep -q "index.js" "$OUT_DIR/index.html" || fail "index.html does not reference index.js"
grep -qi "canvas" "$OUT_DIR/index.html" || fail "index.html has no canvas element"

# Release previews must not ship the test suite or vendored GUT tooling. PCK
# paths are stored as plain strings, so a binary grep is sufficient. Godot
# packages required converted resources under `.godot/exported/`; those are
# runtime artifacts, not the ignored editor cache.
for forbidden_path in 'res://tests/' 'res://addons/gut/'; do
    if grep -aFq "$forbidden_path" "$OUT_DIR/index.pck"; then
        fail "index.pck contains excluded path: $forbidden_path"
    fi
done

# Serve the bundle from a local-only static server and fetch every core file.
# Bind to a free ephemeral port so the check never collides with other
# local services (override with SMOKE_PORT if needed).
PORT="${SMOKE_PORT:-$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')}"
python3 "$REPO_ROOT/tools/serve_web.py" --port "$PORT" --quiet &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
for _ in $(seq 1 20); do
    curl -fso /dev/null "http://127.0.0.1:$PORT/index.html" && break
    sleep 0.2
done
for f in index.html index.js index.wasm index.pck; do
    code="$(curl -so /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/$f")"
    [[ "$code" == "200" ]] || fail "GET /$f returned HTTP $code"
done
wasm_type="$(curl -sI "http://127.0.0.1:$PORT/index.wasm" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print $2}')"
[[ "$wasm_type" == "application/wasm" ]] || fail "index.wasm served as '$wasm_type', expected application/wasm"

echo "smoke: OK — bundle in $OUT_DIR passed static and HTTP checks"
