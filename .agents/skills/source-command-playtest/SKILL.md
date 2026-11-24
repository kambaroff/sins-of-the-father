---
name: "source-command-playtest"
description: "Run the headless auto-sim and report the outcome (parse errors, the loop, the Reckoning)."
---

# source-command-playtest

Use this skill when the user asks to run the migrated source command `playtest`.

## Command Template

Run the headless playtest and report the result.

Steps:
1. Run: `godot --headless --path . Main.tscn`  (use the full path to the Godot 4 binary if it isn't on PATH). `Main.tscn` is the dedicated headless auto-sim driver — pass it explicitly since `project.godot`'s `run/main_scene` now points at the interactive `ReignScreen.tscn`, which has no headless auto-play path.
2. Read the output.
3. Report: did it parse and run to a Reckoning or a lose condition? Paste any parse/runtime error verbatim, name the file and line, and propose the fix.
4. If it errored, fix it (typing the offending variable / casting the Variant read), then run again until it completes cleanly.

The task is only "done" when the sim reaches the Reckoning or a lose condition with no errors.
