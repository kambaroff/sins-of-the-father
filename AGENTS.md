# AGENTS.md — Sins of the Father (Godot prototype)

Project context + the automated workflow. Codex loads this every session, so the rules below apply without you re-stating them.

## What this is

A darkly satirical medieval **dynasty roguelite** in Godot 4 (GDScript). Design is fully specified — treat these as source of truth (in `../` alongside the project):
- `Sins-of-the-Father-GDD.md` — full design.
- `Critical-Design-Requirements.md` — the non-negotiables (CR-1…CR-25) + "v1 done".
- `Godot-Build-Plan.md` — architecture, schemas, milestones.
- `§22 Locked constants` (in the GDD) — fixed values; do not renegotiate without flagging.

## The automated model workflow (so you never switch models by hand)

**Default session model = Sonnet** (set in `.Codex/settings.json`). Route automatically:

- **Delegate to the `planner` subagent (Opus)** — *without being asked* — whenever a task involves: designing a new system, a non-trivial architecture or data-model decision, a stubborn/ambiguous bug, or anything touching the locked constants. Take its plan, then implement it yourself on Sonnet.
- **Delegate to the `narrator` subagent (Fable)** — *without being asked* — whenever player-facing event text is created or changed: new events, rewrites of `title`/`body`/choice `text`, or a tone/voice review. It proposes *complete* events (text **and** mechanics together — the effects/traits are part of the joke, don't split "words" from "numbers" across two calls). Always give it: the satire compass (below), 2-3 house-style example events, the schema with value ranges, the target slot/category/season plus any mechanical constraint, and the existing event ids + one-line premises so it doesn't reconverge on the same handful of famous absurdities. Then validate its output yourself — schema shape, meter/slider/skill ranges, id uniqueness, `requires`/`flags` wiring — before committing to `data/events.json`. Don't delegate for pure effects/balance rebalancing, schema changes, or UI strings (buttons/menus/tooltips) — narrator is for voice, not numbers-only tuning.
- **Implement directly (Sonnet)** for well-specified work: writing GDScript to spec, wiring a scene to signals, boilerplate, small edits, and validating/committing the narrator's output.
- **Use the `gdscript-reviewer` subagent** before finishing any non-trivial GDScript change.
- Escalate to the planner if you attempt a fix twice and it still fails.

Net: Sonnet drives; Opus is pulled in for the hard 20% (architecture), Fable for anything a player reads as voice — both automatically.

**Satire compass** (hand this to the narrator verbatim, every time): "the joke is always on power and its excuses — never on the people who suffer."

## GDScript conventions (hard rules — learned the hard way)

- **Type everything.** Every `var`, const array, and function return gets an explicit type. Untyped `const` arrays return `Variant` and break `:=` inference (this already bit us once). Prefer `const X: Array[int] = [...]`, `var n: int = ...`, and wrap dictionary/`.get()` reads in `int(...)` / `String(...)`.
- Godot **4.x** APIs only. Use signals (`sig.emit()`), `@export`, autoloads.
- Keep logic in autoloads; UI only renders `GameState` and emits choices (thin UI, fat state).
- Content is **data-driven** — new events go in `data/events.json` (never hard-code a card).

## After any engine change

Run `/playtest` (headless auto-sim). It must reach the Reckoning or a lose condition without a parse/runtime error before the task is "done."

## Definition of done (per task)

Parses clean · `/playtest` runs to completion · matches the relevant CR · types are explicit · reviewed by `gdscript-reviewer` if non-trivial.
