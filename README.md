# hive_mind_rpg

A top-down real-time action RPG built with Godot 4.x and GDScript.

## Controls

- Move: WASD or left stick/D-pad
- Dash: Space or gamepad south button
- Melee attack: J or gamepad west button
- Relic energy bolt: K or gamepad north button

## Running tests

The test suite uses [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1),
which is vendored under `addons/gut/` with its MIT license plus two small
Godot 4.6 compatibility patches (issue #40, marked `PATCHED` in
`addons/gut/godot_singletons.gd` and `addons/gut/stub_params.gd`). Supported
pairing: Godot 4.6.x with the patched GUT 9.7.1. When upgrading the vendored
GUT, re-check whether the upstream release still needs those patches.

From the repository root, run all tests with a Godot 4.x executable available
as `godot`. On a fresh clone (or whenever assets changed), import resources
once first, then run the suite:

```sh
godot --headless --path "$PWD" --import
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd
```

On systems where the executable has another name or location, replace `godot`
with that path. For example, a standard macOS application install can be run
with `/Applications/Godot.app/Contents/MacOS/Godot`.

GUT reads `.gutconfig.json`, discovers `test_*.gd` scripts under `tests/` and
its subdirectories, and exits with a non-zero status when a test fails.
