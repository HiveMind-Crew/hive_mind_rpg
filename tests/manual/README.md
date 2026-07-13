# Manual gameplay directors

These scenes drive the game through authored input actions and public gameplay APIs. They are intended for repeatable Movie Maker evidence, not unit-test coverage.

## Combat feedback capture

`combat_feedback_gameplay_director.tscn` runs a goal-driven combat sequence: approach and dash, melee, reposition, relic attack, allow an enemy hit, show invulnerability feedback, and finish the enemy. The overlay identifies each phase and reports live health and distance.

Set `HIVE_MIND_CAPTURE_DIR` to choose where the four evidence screenshots are written. If it is unset, captures go to `user://combat_feedback_gameplay`.

From PowerShell:

```powershell
$env:HIVE_MIND_CAPTURE_DIR = "C:\path\to\capture"
godot --path . --fixed-fps 60 --write-movie "$env:HIVE_MIND_CAPTURE_DIR\combat_feedback.avi" --quit-after 1200 res://tests/manual/combat_feedback_gameplay_director.tscn
```

The director quits after the victory hold or after its safety frame limit. Run it with a normal renderer because screenshot capture waits for `RenderingServer.frame_post_draw`.
