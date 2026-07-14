#!/usr/bin/env bash
# Reproducible Godot 4.7 Web export of the project's configured main scene.
# Usage: tools/build_web.sh
# Override the engine binary with GODOT=/path/to/godot (must be 4.7 stable).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
PRESET="Web"
OUT_DIR="$REPO_ROOT/.playtest-build/web"

# The project supports only Godot 4.7 stable (see README). Refuse anything else
# so exports stay byte-comparable across machines.
VERSION="$("$GODOT" --version | head -n1)"
case "$VERSION" in
    4.7.stable*) ;;
    *)
        echo "error: '$GODOT' reports version '$VERSION'; Godot 4.7 stable is required." >&2
        echo "hint: set GODOT=/path/to/Godot_v4.7-stable_linux.x86_64" >&2
        exit 1
        ;;
esac

# The Web export needs the official 4.7 export templates installed. Godot
# looks for the files directly under export_templates/4.7.stable/ — the
# templates .tpz archive contains a nested templates/ directory whose
# *contents* must be placed there (a common mis-extraction leaves them in
# export_templates/4.7.stable/templates/ where Godot cannot find them).
TEMPLATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.stable"
if [[ ! -f "$TEMPLATE_DIR/web_nothreads_release.zip" ]]; then
    echo "error: Web export template not found at $TEMPLATE_DIR/web_nothreads_release.zip" >&2
    echo "Install the official templates:" >&2
    echo "  1. Download Godot_v4.7-stable_export_templates.tpz from https://godotengine.org/download/archive/4.7-stable/" >&2
    echo "  2. unzip Godot_v4.7-stable_export_templates.tpz" >&2
    echo "  3. mkdir -p '$TEMPLATE_DIR' && mv templates/* '$TEMPLATE_DIR/'" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

# Re-import first so a clean checkout exports correctly, then export the
# release build. --export-release builds run/main_scene from project.godot;
# no scene override is applied.
"$GODOT" --headless --path "$REPO_ROOT" --import
"$GODOT" --headless --path "$REPO_ROOT" --export-release "$PRESET" "$OUT_DIR/index.html"

echo "Web export written to $OUT_DIR"
"$REPO_ROOT/tools/smoke_check_web.sh"
