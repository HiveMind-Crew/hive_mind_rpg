# Private web playtest builds

Reproducible Godot 4.7 Web exports for browser playtests, so testers do not
need a desktop Godot install. Infrastructure only (issue #102): the build
runs whatever `run/main_scene` in `project.godot` currently provides.

## Prerequisites

- Godot **4.7 stable** binary (any 4.7-stable build; set `GODOT=` if it is
  not on your `PATH` as `godot`).
- Official 4.7 **export templates**. Download
  `Godot_v4.7-stable_export_templates.tpz` from the
  [4.7-stable archive page](https://godotengine.org/download/archive/4.7-stable/),
  unzip it, and move the *contents* of its inner `templates/` directory into
  `~/.local/share/godot/export_templates/4.7.stable/`. Godot expects e.g.
  `.../4.7.stable/web_nothreads_release.zip` directly — leaving the nested
  `templates/` folder in place is a common mistake and Godot will not find
  the files. `tools/build_web.sh` checks this and prints the fix.

## Build

```sh
GODOT=/path/to/Godot_v4.7-stable_linux.x86_64 tools/build_web.sh
```

This re-imports resources (safe on a clean checkout), exports the committed
`Web` preset from `export_presets.cfg` as a **release, no-threads** build to
`.playtest-build/web/` (git-ignored, never committed), and runs the smoke check. The
preset excludes `tests/` and vendored GUT tooling from the shipped pack. Godot
still places required converted runtime resources under `.godot/exported/`
inside the pack; those are not the ignored editor cache.

`tools/smoke_check_web.sh` can also be run on its own: it validates that
`index.html` / `index.js` / `index.wasm` / `index.pck` exist, have correct
magic bytes, and are fetchable with the right MIME types from a throwaway
local server.

## Play locally

```sh
python3 tools/serve_web.py        # http://127.0.0.1:8765/
```

The server binds to loopback only. Do not open `index.html` from `file://`;
browsers block wasm/fetch there.

### Manual browser/controller test steps

1. Open the URL in Chrome/Edge or Firefox (current release).
2. Click the canvas once to grant input + audio focus.
3. Keyboard: move with WASD, dash with Space, melee with J, relic bolt with
   K, interact with E, pause with Esc.
4. Controller: connect a gamepad, then **press any button on it** — the
   browser Gamepad API only exposes a pad after a button press. Verify left
   stick/D-pad movement and the dash/attack/relic face buttons.
5. Confirm the configured main scene loads and no errors appear in the
   browser devtools console.

## Known limitations

- **No-threads build**: the preset exports with `variant/thread_support=false`
  so the bundle runs on any static host without cross-origin-isolation
  (COOP/COEP) headers. Trade-off: audio runs on the main thread fallback and
  may crackle under load. If a host can send COOP/COEP headers, thread
  support can be enabled in the preset later.
- **Browsers**: current Chrome/Edge/Firefox on desktop are the test targets.
  Safari generally works but has the weakest wasm/audio behavior; mobile
  browsers are untested and out of scope for playtests.
- **Controllers**: support depends on the browser's Gamepad API; pads appear
  only after a button press inside the page, and mappings can differ from
  desktop Godot.
- **Saves**: `SaveManager` writes to `user://`, which the Web build maps to
  browser IndexedDB. Saves are per-browser/per-origin and are lost if site
  data is cleared. No save data leaves the tester's machine.
- Performance is below a native build; do not use web playtests to judge
  frame timing.

## Deploy, launch, revoke (private only)

**Policy: no public, unauthenticated deployment.** The playtest bundle may
only be uploaded to an endpoint gated by authentication (for example
Cloudflare Pages behind Cloudflare Access, or a static host behind SSO/basic
auth). There is deliberately no default target, no committed credentials,
and nothing deploys from CI.

- **Launch**: build, then run `tools/deploy_web.sh`. It fails closed unless
  you set `WEB_PLAYTEST_DEPLOY_CMD` (the upload command for your gated
  target, credentials supplied via your own environment/secret store) and
  `WEB_PLAYTEST_CONFIRM_PRIVATE=yes` (your confirmation the target requires
  auth). It re-runs the smoke check before uploading. Share the URL and
  access grants only with playtesters.
- **Verify**: after upload, open the URL in a private window and confirm you
  are challenged for authentication before any game file loads.
- **Revoke**: remove the testers' access grants (or rotate the shared
  credential), then delete the deployment/files from the host so the bundle
  is gone, not merely unlinked. Deleting the deployment is the backstop —
  do it whenever a playtest round ends.

The exported bundle contains no editor tooling and no debug endpoints; it is
a release-mode export of the game only.
