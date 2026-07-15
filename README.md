# hive_mind_rpg

A top-down real-time action RPG built with Godot 4.7 stable and GDScript.

## Supported engine

The project targets Godot 4.7 stable. Godot 4.6 and earlier are not supported.
Keep local editor, headless test, and CI versions aligned with 4.7 stable.

## Build and run

### Prerequisites

- [Godot 4.x](https://godotengine.org/download/) with the matching export templates if you plan to create a distributable build.
- A local clone of this repository. The project has no additional runtime dependencies; GUT is vendored under `addons/gut/` for tests.

### Run from the editor

1. Open the repository in the Godot editor:

   ```sh
   godot --editor --path "$PWD"
   ```

2. Press **F6** to run the current scene or **F5** to run the project from its configured main scene.

If `godot` is not on your `PATH`, replace it with the executable's full path. For example, on macOS:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --editor --path "$PWD"
```

### Run from the command line

From the repository root, launch the game with:

```sh
godot --path "$PWD"
```

To verify that Godot can import and load the project without opening the editor UI:

```sh
godot --headless --editor --path "$PWD" --quit
```

### Export a distributable build

This repository does not currently include `export_presets.cfg`, so create an export preset once in the editor under **Project > Export**. Install the required export templates, choose a platform, and save the preset. Then export it from the repository root with:

```sh
mkdir -p build
godot --headless --path "$PWD" --export-release "Preset Name" build/game
```

Replace `Preset Name` with the name shown in the Export dialog and choose the platform's expected output filename (for example, `build/game.exe` on Windows or `build/game.app` for a macOS application export).

## Controls

- Move: WASD or left stick/D-pad
- Dash: Space or gamepad south button
- Melee attack: J or gamepad west button
- Relic energy bolt: K or gamepad north button
- Fold Step: Q or gamepad left shoulder (after unlocking it)

## Web playtest builds

`tools/build_web.sh` produces a private browser playtest build from the
committed Web export preset; see [docs/web_playtest.md](docs/web_playtest.md)
for the build, smoke-check, and private deploy/launch/revoke procedure.

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
