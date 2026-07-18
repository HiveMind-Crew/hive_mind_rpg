# AGENTS.md — AI Agent Collaboration Guide

This file is read by AI coding agents (Claude Code, Copilot, Cursor, etc.) at the start of every session. Humans should read it too. Its job: make every agent produce code that looks like it came from the same team.

---

## 1. Project Overview

- **Project:** hive_mind_rpg — a 2D RPG built in **Godot 4.7 stable** with **GDScript**
- **Design source of truth:** `DESIGN.md`. If a task conflicts with DESIGN.md, stop and flag it — don't silently improvise design changes.
- **Repo:** https://github.com/HiveMind-Crew/hive_mind_rpg

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

- **Godot 4.7 stable syntax only** (no Godot 3 patterns — e.g., use `@export`, `@onready`, typed signals). Godot 4.6 and earlier are unsupported.
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
- **Global time scale:** only `TimeScaleManager` writes `Engine.time_scale`; pause, cinematic, accessibility, and combat systems call its base-scale/modifier API instead.

## 5. Scene Architecture

- Every scene is self-contained and runnable on its own where possible (press F6 to test).
- Root node of a scene gets the script; the script's `class_name` matches the scene's purpose.
- Shared state lives in autoload singletons (`scripts/autoload/`) — keep these few and documented in section 9.
- Content (items, enemies, dialogue) is **data-driven** via custom Resources in `data/`, not hardcoded in scripts.

## 6. Issue Priorities and Relationships

Every bug fix, feature, enhancement, infrastructure change, and design decision starts with a focused GitHub Issue. Apply one or more system labels (`system:player`, `system:combat`, `system:ui`, `system:world`, `system:data`, `docs`) and, when gameplay priority applies, exactly one priority label.

| Priority | Meaning | Use when |
|---|---|---|
| `P0` | Vertical-slice blocker | Required to make the v1 core loop playable, testable, or shippable, or directly blocks another P0 system. |
| `P1` | Important follow-up | Materially improves the slice, usability, presentation, reliability, or development workflow without blocking the core loop. |
| `P2` | Optional slice content/polish | Valuable flavor, polish, or secondary functionality that can be omitted without invalidating the slice. |
| `P3` | Backlog/post-slice | Experiments, future scope, optimizations, and work intentionally deferred until after the slice. |

Infrastructure and decision Issues may use `infra` or `decision` without a gameplay priority when P0–P3 does not meaningfully apply. Do not label convenience work P0 merely because another Issue mentions it.

### Blocker relationships

- Use GitHub's native **Blocked by** / **Blocking** relationships for actual execution prerequisites. Markdown references alone do not create a dependency.
- If A must finish before B, set **B blocked by A**; GitHub should show the reciprocal **A blocking B** relationship.
- Use a plain `Related: #123` reference for useful context that does not prevent parallel work.
- Do not make an umbrella Issue block independent child Issues that can proceed in parallel.
- Before claiming work, verify every native blocker. A closed blocker is satisfied; an open blocker means the dependent Issue is not ready.
- Keep dependency prose and native relationships consistent. Remove or correct stale, reversed, self-referential, and circular edges.
- If the prerequisite is questionable or requires design judgment, discuss it in the Issue before changing the native relationship.

## 7. Mandatory Issue-to-Merge Workflow

Use this lifecycle for every upcoming bug fix, feature, or enhancement:

1. **Create the Issue.** Describe the goal, acceptance criteria, expected files/scenes, manual test path, and known dependencies before implementation begins.
2. **Label and relate it.** Apply system/type labels, the appropriate P0–P3 label when applicable, and native blocker relationships using section 6.
3. **Claim it.** Assign yourself and comment the expected files/scenes and intended branch. If another claim overlaps, coordinate in the Issue before editing.
4. **Create a scoped branch from current `main`.** Use `feature/<short-desc>`, `fix/<short-desc>`, or `docs/<short-desc>`. Never implement directly on `main`.
5. **Implement only the claimed change.** Add tests, update relevant documentation, and open follow-up Issues instead of silently expanding scope.
6. **Validate.** Run focused tests, the full suite, and relevant manual Godot checks. Leave the project green.
7. **Open a PR that closes the Issue.** Include `Closes #123`, what changed and why, manual test steps, automated results, authorship, and any files touched outside the claimed module.
8. **Obtain an independent review.** A separate agent/session reviews design alignment, scope, typing, tests, scene ownership, regressions, and dependency readiness. The implementation session must not self-approve.
9. **Merge only after approval and green checks.** Then verify the PR is merged and its Issue is closed.

“Separate agent/session” means the implementation and review happen in distinct sessions with independent review context, even when one human coordinates both. Integration sandboxes may combine branches locally for testing, but must never be submitted as a bundled feature PR.

### Git and PR conventions

- **Commit messages:** use imperative mood with a scoped prefix, such as `player: add dash cooldown` or `ui: fix health bar healing update`.
- Stage only claimed files. Do not bundle unrelated Issues into one branch or PR.
- Merge conflicts on `.tscn` and `.tres` files are painful; never edit a claimed scene/resource without coordination in the Issue.
- PR descriptions must identify the author, for example: `Author: Codex session w/ @MeanGreen256`.

### Lifecycle examples

- **Feature:** Create “Add pause menu,” label it `system:ui` + `P0`, set it blocked by the playable startup Issue if return-to-hub integration requires that flow, claim `scenes/ui/pause_menu.tscn`, implement on `feature/pause-menu`, test, and open a PR with `Closes #69` for independent review.
- **Bug fix:** Create “Health bar does not update after healing,” label it `bug` + `system:ui` + the appropriate priority, record any real blocker, claim the HUD script/test, implement on `fix/health-bar-heal`, add a regression test, and open a focused closing PR.

## 8. Testing & Definition of Done

**How to run, isolate, and playtest:** see [`docs/agent_playtesting.md`](docs/agent_playtesting.md) — the three verification tiers (headless GUT + simulated input, single-scene isolation, and Web-build browser playtest), the headless probe pattern, and the browser input helper (`tools/browser_playtest_helpers.js`). Reach for the browser only when a change needs visual/feel verification the headless suite can't give; prefer GUT for anything deterministic.

A task is done when:
- [ ] Project opens in Godot with no errors or warnings introduced
- [ ] The feature works as described in the Issue (include repro steps in PR)
- [ ] New logic-heavy code has GUT tests in `tests/` (pure logic: required; node-heavy code: best effort)
- [ ] Static typing passes (no untyped new code)
- [ ] DESIGN.md / AGENTS.md updated if behavior or conventions changed
- [ ] New `.gd` scripts and imported assets are committed with their `.uid` / `.import` sidecars (section 12)

## 9. Autoload Registry

Keep this table current. Agents: do NOT add autoloads without updating this table in the same PR.

| Autoload | File | Purpose |
|---|---|---|
| `GameState` | `scripts/autoload/game_state.gd` | Owns skill points, unlocked skills, and respec state. |
| `TimeScaleManager` | `scripts/autoload/time_scale_manager.gd` | Coordinates base time scale and temporary modifiers so combat hitstop composes with pause, cinematic, and accessibility systems. |
| `SaveManager` | `scripts/autoload/save_manager.gd` | Persists progression + last checkpoint to JSON in `user://`; loads on launch, saves on checkpoint & quit. |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Plays the ambient loop and pooled combat SFX (placeholder pass, issue #25); asset licenses logged in `assets/audio/LICENSES.md`. |

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

## 12. Godot Metadata Policy (`.uid` / `.import`)

All Godot-generated per-file metadata is versioned; only the editor cache is ignored (issue #81):

- **Track** every `*.uid` sidecar (e.g. `player_controller.gd.uid`). Stable UIDs keep scene/resource references working across clones and renames.
- **Track** every `*.import` file next to imported assets (PNG, SVG, TTF, WAV, …). They pin import settings so all contributors get identical resources.
- **Ignore** only editor/user caches — `.godot/` (already in `.gitignore`). Never commit anything from `.godot/`.

When you add a `.gd` script or an importable asset, let Godot generate its sidecar and commit both files in the same PR. When you delete or rename a file, move/delete its sidecar with it.

**Verification** (also the acceptance check for metadata PRs) — run a headless import with the supported Godot 4.7 binary and confirm the worktree stays clean:

```sh
godot --headless --path . --import
git status --porcelain   # must print nothing
```

`tests/test_godot_metadata_policy.gd` enforces the static half of this policy (missing `.gd.uid` sidecars, missing `.import` files, orphaned sidecars, duplicate UIDs) as part of the normal GUT suite.
