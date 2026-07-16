# Agent playtesting guide

How an AI agent (or human) runs, tests, and *drives* this game. Three tiers,
cheapest first. Use the lowest tier that answers your question; only reach for
the browser when you need to see or feel something the headless tiers can't.

Prereqs: Godot **4.7 stable** on `PATH` as `godot` (macOS app: use the full
`/Applications/Godot.app/Contents/MacOS/Godot`). The Web tier also needs the
official 4.7 export templates — see [web_playtest.md](web_playtest.md).

---

## Tier 1 — Headless logic + simulated input (default; fast, deterministic)

The GUT suite runs headless and can drive **real input actions** frame-by-frame
via `GutInputSender` (see `tests/world/test_respawn_control_lockout.gd` for a
worked example). This is where regression coverage belongs.

```sh
godot --headless --path "$PWD" --import                              # once, or after assets change
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd         # whole suite
# One file / one test:
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gtest=res://tests/ui/test_skill_tree_screen.gd
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gselect=test_my_case
```

**Throwaway probe pattern.** To measure something (a layout size, a computed
value) without a browser, drop a temporary `test_zzz_*.gd` in `tests/…`, print
with `gut.p("PROBE ...")`, run it, read the number, then delete the file **and
its `.gd.uid` sidecar** (an orphaned sidecar fails the metadata-policy test).
This is how the skill-screen overflow was measured (columns needed 1562px at a
640-wide base). Always end with `git status --porcelain` clean.

**Boot smoke test** (surfaces autoload / script errors without a display):

```sh
godot --headless --path "$PWD"        # Ctrl-C after a few seconds; watch for SCRIPT ERROR
```

---

## Tier 2 — Isolate a scene

Most scenes are self-contained and F6-runnable. To boot straight into one scene
in a Web build (e.g. to screenshot the skill screen without walking there),
**temporarily** point the main scene at it, rebuild, then revert:

```sh
cp project.godot /tmp/project.godot.bak
sed -i '' 's|run/main_scene="res://scenes/main/main.tscn"|run/main_scene="res://scenes/ui/skill_tree_screen.tscn"|' project.godot
bash tools/build_web.sh
# ...inspect in the browser...
cp /tmp/project.godot.bak project.godot && rm /tmp/project.godot.bak   # ALWAYS revert
```

The skill screen grants debug points when it is the current scene, so it comes
up interactive.

---

## Tier 3 — Play it in a browser (visual / feel verification)

For anything the headless tiers can't judge — actual movement feel, framing,
visuals, "does it fit the screen."

```sh
bash tools/build_web.sh            # export + smoke check to .playtest-build/web/
python3 tools/serve_web.py         # http://127.0.0.1:8765/  (loopback only)
```

Open `http://127.0.0.1:8765/index.html` in the browser pane and **click the
canvas once** to grant input + audio focus.

### Driving input

Native/agent key presses do **not** reliably reach the Godot canvas, and
acceleration-based movement needs keys *held*. Use the JS input helper: paste
[`tools/browser_playtest_helpers.js`](../tools/browser_playtest_helpers.js) once
to install `window.HM`, then:

```js
HM.hold('right', 1500)         // walk right 1.5s (auto-releases)
HM.hold(['up','right'], 800)   // diagonal
HM.tap('interact')             // E — open a station / gate when standing on it
HM.tap('melee'); HM.tap('relic')
HM.releaseAll()                // if anything sticks
```

Actions: `up down left right dash melee relic utility interact pause`
(mapped to the `project.godot` `[input]` bindings — keep them in sync).

### Gotchas (learned the hard way)

- **The player is fast.** For fine alignment to an interactable, `HM.hold(dir,
  300–500)` at a time and screenshot between nudges; long holds overshoot.
  Interactables only fire `interact` when you're overlapping them (watch for the
  `[E] …` prompt to appear, *then* tap `interact`).
- **Escape is swallowed by the browser**, so `HM.tap('pause')` usually won't
  open the pause menu in-browser — verify pause via Tier 1 instead.
- **Canvas can render small / top-left-anchored at larger window sizes** — a
  Web-shell scaling quirk, tracked in issue #125, *not* a game bug. Smaller
  browser viewports render larger/more readable; the geometric truth is better
  confirmed with a Tier-1 probe than by eyeballing a tiny canvas.
- **Reading game state from JS isn't wired up.** Godot doesn't expose node state
  to the page, so you can't query the player's position from the browser. For
  deterministic behavior checks (position, health, state machine), use Tier 1.
- **`.wasm`/`.pck` MIME + COOP/COEP** are handled by `serve_web.py`; don't open
  `index.html` over `file://`.

---

## Where things live

| Thing | Path |
|---|---|
| Web build script | `tools/build_web.sh` |
| Local server | `tools/serve_web.py` |
| Browser input helper | `tools/browser_playtest_helpers.js` |
| Web build/deploy details | `docs/web_playtest.md` |
| Input bindings | `project.godot` `[input]` |
| GUT config | `.gutconfig.json` |
