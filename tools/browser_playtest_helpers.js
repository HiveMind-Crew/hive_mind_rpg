// Browser playtest input helpers for the exported Web build.
//
// Godot Web reads real DOM KeyboardEvents on the <canvas>. Synthetic events
// dispatched here drive the game reliably; a keydown with no keyup is treated
// as a held key (that is how sustained movement works). This exists because an
// automated agent's "native" key presses do not always reach the Godot canvas,
// and because acceleration-based movement needs keys *held*, not tapped.
//
// USAGE (in the browser pane's JS console / javascript_tool):
//   1. Paste this whole file once to install `window.HM`.
//   2. Then call, e.g.:
//        HM.hold('right', 1500)          // walk right for 1.5s (auto-releases)
//        HM.hold(['up','right'], 800)    // diagonal
//        HM.tap('interact')              // press E once
//        HM.tap('melee'); HM.tap('relic')
//        HM.releaseAll()                 // panic release of every held key
//
// Movement uses acceleration + friction, so short taps barely move the player;
// prefer HM.hold(...) with a duration. The player is fast — for fine alignment
// to an interactable, hold ~0.3–0.5s at a time and screenshot between nudges.
//
// Keep the action->code map in sync with project.godot [input] if bindings
// change. Codes are DOM `KeyboardEvent.code` / `.keyCode`.
(function () {
  const KEYS = {
    // action name -> { code, keyCode }
    up:       { code: 'KeyW', keyCode: 87 },   // move_up
    down:     { code: 'KeyS', keyCode: 83 },   // move_down
    left:     { code: 'KeyA', keyCode: 65 },   // move_left
    right:    { code: 'KeyD', keyCode: 68 },   // move_right
    dash:     { code: 'Space', keyCode: 32 },  // dash
    melee:    { code: 'KeyJ', keyCode: 74 },   // attack_melee
    relic:    { code: 'KeyK', keyCode: 75 },   // ability_relic
    utility:  { code: 'KeyQ', keyCode: 81 },   // ability_utility (Fold Step)
    interact: { code: 'KeyE', keyCode: 69 },   // interact
    pause:    { code: 'Escape', keyCode: 27 }, // pause (NOTE: browsers often
                                               // swallow Escape before Godot)
  };

  function canvas() {
    return document.getElementById('canvas') || document.querySelector('canvas');
  }

  function resolve(name) {
    const k = KEYS[name];
    if (!k) throw new Error('Unknown action: ' + name + ' (have: ' + Object.keys(KEYS).join(', ') + ')');
    return k;
  }

  function names(a) { return Array.isArray(a) ? a : [a]; }

  function dispatch(type, name) {
    const k = resolve(name);
    const c = canvas();
    if (!c) throw new Error('No <canvas> found; is the game loaded?');
    c.dispatchEvent(new KeyboardEvent(type, {
      key: k.code.replace('Key', '').toLowerCase(),
      code: k.code, keyCode: k.keyCode, which: k.keyCode,
      bubbles: true, cancelable: true,
    }));
  }

  const held = new Set();

  function down(action) { for (const n of names(action)) { dispatch('keydown', n); held.add(n); } }
  function up(action)   { for (const n of names(action)) { dispatch('keyup', n);   held.delete(n); } }

  // Tap: keydown + keyup after `ms` (default 60ms) — for one-shot actions
  // (interact, melee, relic, dash). Returns a Promise that resolves on release.
  function tap(action, ms = 60) {
    down(action);
    return new Promise((r) => setTimeout(() => { up(action); r(); }, ms));
  }

  // Hold: keydown, then auto-keyup after `ms`. For movement. `action` may be a
  // single name or an array (diagonals). Returns a Promise resolving on release.
  function hold(action, ms) {
    down(action);
    return new Promise((r) => setTimeout(() => { up(action); r(); }, ms));
  }

  function releaseAll() { for (const n of Array.from(held)) up(n); }

  window.HM = {
    KEYS, canvas, down, up, tap, hold, releaseAll,
    held: () => Array.from(held),
  };
  return 'HM installed: HM.hold(action, ms), HM.tap(action), HM.down/up(action), HM.releaseAll(). Actions: ' + Object.keys(KEYS).join(', ');
})();
