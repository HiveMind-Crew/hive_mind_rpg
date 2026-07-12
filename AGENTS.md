# AGENTS.md — AI Agent Collaboration Guide

This file is read by AI coding agents (Claude Code, Copilot, Cursor, etc.) at the start of every session. Humans should read it too. Its job: make every agent produce code that looks like it came from the same team.

---

## 1. Project Overview

- **Project:** hive_mind_rpg — a 2D RPG built in **Godot 4.x** with **GDScript**
- **Design source of truth:** `DESIGN.md`. If a task conflicts with DESIGN.md, stop and flag it — don't silently improvise design changes.
- **Repo:** https://github.com/MeanGreen256/hive_mind_rpg

## 2. Golden Rules for Agents

1. **Read `DESIGN.md` before writing gameplay code.** Features must serve a design pillar.
2. **Small, scoped changes.** One feature/fix per branch. Don't refactor unrelated code "while you're at it."
3. **Never commit directly to `main`.** All work goes through feature branches + pull requests.
4. **Don't touch files outside your task's module** without flagging it in the PR description.
5. **Leave the build green.** The project must open and run in Godot after your change.
6. **Update docs with code.** If you change a system's behavior, update DESIGN.md and any relevant section here in the same PR.
7. **When uncertain, ask.** Open a GitHub Issue or leave a `# QUESTION(agent):` comment rather than guessing on design decisions.

## 3. Repository Structure

```
hive_mind_rpg/
├── project.godot
├── DESIGN.md            # Game design doc (source of truth)
├── AGENTS.md            # This file
├── README.md
├── scenes/              # .tscn files, one folder per domain
│   ├── player/
│   ├── enemies/
│   ├── ui/
│   ├── world/           # levels, tilemaps
│   └── main/            # main scene, game manager
├── scripts/             # .gd files mirroring scenes/ structure
│   ├── autoload/        # singletons (GameState, AudioManager, etc.)
│   └── resources/       # custom Resource class definitions
├── data/                # .tres content files (items, enemies, dialogue)
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── tests/               # GUT unit tests
```

## 4. GDScript Conventions

- **Godot 4.x syntax only** (no Godot 3 patterns — e.g., use `@export`, `@onready`, typed signals).
- **Static typing everywhere:** `var health: int = 10`, `func take_damage(amount: int) -> void:`
- **Naming:**
  - Files/folders: `snake_case` (`player_controller.gd`)
  - Classes: `PascalCase` with `class_name` (`class_name PlayerController`)
  - Constants: `SCREAMING_SNAKE_CASE`
  - Signals: past tense (`health_changed`, `enemy_died`)
  - Private members: leading underscore (`_current_state`)
- **One class per file.** File name matches class name.
- **Signals up, calls down:** parents call methods on children; children emit signals to parents. Never reach up the tree with `get_parent()`.
- **Prefer composition** (child nodes, components) over deep inheritance.
- **No magic numbers** — use `@export` vars or constants.
- **Comment the why, not the what.**

## 5. Scene Architecture

- Every scene is self-contained and runnable on its own where possible (press F6 to test).
- Root node of a scene gets the script; the script's `class_name` matches the scene's purpose.
- Shared state lives in autoload singletons (`scripts/autoload/`) — keep these few and documented in section 9.
- Content (items, enemies, dialogue) is **data-driven** via custom Resources in `data/`, not hardcoded in scripts.

## 6. Git Workflow

- **Branch naming:** `feature/<short-desc>`, `fix/<short-desc>`, `docs/<short-desc>`
  - e.g., `feature/player-movement`, `fix/inventory-crash`
- **Commit messages:** imperative mood, scoped prefix:
  - `player: add dash ability with cooldown`
  - `ui: fix health bar not updating on heal`
- **PRs must include:**
  1. What changed and why (link the GitHub Issue)
  2. How to test it manually in the editor
  3. Which agent/human authored it (e.g., `Author: Claude Code session w/ @MeanGreen256`)
- **Merge conflicts on `.tscn`/`.tres` files are painful.** Avoid two people/agents editing the same scene simultaneously — claim scenes via Issues (see section 7).

## 7. Task Claiming (avoiding agent collisions)

1. All work is tracked as **GitHub Issues** with labels: `system:player`, `system:combat`, `system:ui`, `system:world`, `system:data`, `docs`.
2. Before starting, an agent/human **assigns themselves the Issue** and comments which files/scenes they expect to touch.
3. If your task needs a file someone else has claimed, coordinate in the Issue thread first.
4. Close the Issue via the PR (`Closes #12`).

## 8. Testing & Definition of Done

A task is done when:
- [ ] Project opens in Godot with no errors or warnings introduced
- [ ] The feature works as described in the Issue (include repro steps in PR)
- [ ] New logic-heavy code has GUT tests in `tests/` (pure logic: required; node-heavy code: best effort)
- [ ] Static typing passes (no untyped new code)
- [ ] DESIGN.md / AGENTS.md updated if behavior or conventions changed

## 9. Autoload Registry

Keep this table current. Agents: do NOT add autoloads without updating this table in the same PR.

| Autoload | File | Purpose |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Owns skill points, unlocked skills, and respec state. |

## 10. Current Module Owners

Update as people/agents claim domains. "Owner" = first reviewer for that area, not sole author.

| Module | Owner |
|---|---|
| Player & movement | `[unclaimed]` |
| Combat | `[unclaimed]` |
| World / levels | `[unclaimed]` |
| UI / menus | `[unclaimed]` |
| Data / content | `[unclaimed]` |
| Narrative / dialogue | `[unclaimed]` |

## 11. Things Agents Must Never Do

- Force-push to `main` or rewrite shared history
- Delete or regenerate `project.godot` wholesale
- Commit binary asset changes without noting the source/license in the PR
- Introduce paid plugins or assets without team sign-off
- Change engine version without a dedicated Issue + team agreement
