# hive_mind_rpg

A top-down real-time action RPG built with Godot 4.x and GDScript.

## Running tests

The test suite uses [GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1),
which is vendored under `addons/gut/` with its MIT license.

From the repository root, run all tests with a Godot 4.x executable available
as `godot`:

```sh
godot --headless -d -s --path "$PWD" addons/gut/gut_cmdln.gd
```

On systems where the executable has another name or location, replace `godot`
with that path. For example, a standard macOS application install can be run
with `/Applications/Godot.app/Contents/MacOS/Godot`.

GUT reads `.gutconfig.json`, discovers `test_*.gd` scripts under `tests/` and
its subdirectories, and exits with a non-zero status when a test fails.
