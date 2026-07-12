# hive_mind_rpg

A top-down real-time action RPG built with Godot 4.7 stable and GDScript.

## Supported engine

The project targets Godot 4.7 stable. Godot 4.6 and earlier are not supported.
Keep local editor, headless test, and CI versions aligned with 4.7 stable.

## Controls

- Move: WASD or left stick/D-pad
- Dash: Space or gamepad south button
- Melee attack: J or gamepad west button
- Relic energy bolt: K or gamepad north button

## Running tests

The test suite uses [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1),
which is vendored under `addons/gut/` with its MIT license.

From the repository root, run all tests with the Godot 4.7 stable executable
as `godot`. On a fresh clone (or whenever assets changed), import resources
once first, then run the suite:

```sh
godot --headless --path "$PWD" --import
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd
```

On systems where the executable has another name or location, replace `godot`
with that path. The executable must report version 4.7 stable. For example, a
standard macOS application install can be run with
`/Applications/Godot.app/Contents/MacOS/Godot`.

GUT reads `.gutconfig.json`, discovers `test_*.gd` scripts under `tests/` and
its subdirectories, and exits with a non-zero status when a test fails.
