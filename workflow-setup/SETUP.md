# Automated workflow — one-time setup

These files configure Claude Code so you **never switch models by hand**: the session runs on Sonnet, and Opus is pulled in automatically via the `planner` subagent for design/architecture/hard bugs.

## Move the files into place

From this `workflow-setup/` folder, place them like so (create the folders if needed):

| This file | Move to |
|---|---|
| `planner.agent.md` | `.claude/agents/planner.md` |
| `gdscript-reviewer.agent.md` | `.claude/agents/gdscript-reviewer.md` |
| `playtest.command.md` | `.claude/commands/playtest.md` |
| `deck-to-json.command.md` | `.claude/commands/deck-to-json.md` |
| `settings.json` | `.claude/settings.json` |

`CLAUDE.md` is already at the project root — leave it there.

(I couldn't write into `.claude/` directly from the assistant session — it's a protected path — hence this move step.)

## How it behaves after setup

- Open the `godot-prototype` folder in **Claude Code**. It loads `CLAUDE.md`, the two subagents, the commands, and `settings.json` automatically.
- Default model is **Sonnet**. When a task needs deep planning, Claude delegates to the **`planner` (Opus)** subagent on its own, gets a plan, and implements it on Sonnet. You don't touch the model picker.
- `/playtest` runs the headless sim and reports errors; `/deck-to-json` converts deck content into `events.json`.
- Non-trivial GDScript gets a pass from `gdscript-reviewer` before it's "done".

## Verify it works

1. In Claude Code: `/agents` should list `planner` and `gdscript-reviewer`.
2. `/playtest` should run the sim (needs the Godot 4 binary on PATH, or edit the command to the full path).
3. Ask for a design change ("add the recovery-breather system") and confirm it consults the planner before coding.

## Optional: fully auto-run the playtest (hook)

If you want the sim to run automatically after edits instead of via `/playtest`, add a `hooks` block to `.claude/settings.json` (a `Stop` or `PostToolUse` hook running `godot --headless --path .`). Check the current Claude Code hooks schema in the docs before adding it — the format is worth getting exactly right, and running the full sim on every edit can be noisy, so `Stop` (end of a turn) is usually the better trigger.

## Pairs with the Godot MCP

With a Godot MCP server connected (see `../Dev-Workflow.md`), the same Claude Code session can also read your live scene tree and editor errors — so the loop closes end to end: plan (Opus) → code (Sonnet) → run/inspect (MCP) → review → done, no model-switching.
