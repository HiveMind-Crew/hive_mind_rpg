#!/usr/bin/env bash
# Opt-in deployment of .playtest-build/web to a PRIVATE preview endpoint.
#
# This script fails closed: it does nothing unless every required environment
# variable is set, and it never embeds credentials or defaults to a public
# target. See docs/web_playtest.md for the launch/revoke procedure.
#
# Required environment:
#   WEB_PLAYTEST_DEPLOY_CMD      command that uploads .playtest-build/web (e.g. a
#                                wrangler/rclone/rsync invocation you control)
#   WEB_PLAYTEST_CONFIRM_PRIVATE must be exactly "yes" — your confirmation
#                                that the target requires authentication and
#                                is NOT publicly reachable
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/.playtest-build/web"

refuse() { echo "deploy: refusing — $*" >&2; exit 1; }

[[ -f "$OUT_DIR/index.html" ]] || refuse "no bundle at $OUT_DIR; run tools/build_web.sh first"
[[ -n "${WEB_PLAYTEST_DEPLOY_CMD:-}" ]] \
    || refuse "WEB_PLAYTEST_DEPLOY_CMD is not set. No default deploy target exists on purpose."
[[ "${WEB_PLAYTEST_CONFIRM_PRIVATE:-}" == "yes" ]] \
    || refuse "WEB_PLAYTEST_CONFIRM_PRIVATE=yes is required to confirm the target is authenticated/private."

"$REPO_ROOT/tools/smoke_check_web.sh"

echo "deploy: uploading $OUT_DIR via WEB_PLAYTEST_DEPLOY_CMD"
( cd "$OUT_DIR" && eval "$WEB_PLAYTEST_DEPLOY_CMD" )
echo "deploy: done. Verify the URL is gated by authentication before sharing it."
