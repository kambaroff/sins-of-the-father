# Sins of the Father — Handoff (2026-07-17)

Playtest bug-fix pass. Sixteen issues from a human playtest were fixed, the build was
machine-verified, and one sign-off item remains. This file is the pick-up point for the
next session or the next person.

## State in one line

All 9 milestones built; this fix pass closed 16 playtest issues; **7 headless test suites
green**; the only thing left is a **human editor playtest for *feel*** (mechanics/UI are
verified). Nothing is blocking.

## What was fixed (issue → fix)

**Event firing**
- *Golden Nose fired with no cause* — reworded to an ancestral grudge, so it no longer
  reads as a consequence of an event that never happened.
- *Brother's Ambition fired 3× in one reign* — `EventEngine` now keeps a recent-card
  window (`_recent`, cap 6); no event repeats back-to-back even after the pool is exhausted.
- *University event fired when already built* — founding events (University / Mint /
  Cathedral) carry an event-level `requires.not_founded` gate and disappear once built.
- *Card order* — a fired consequence / reign-threat now leads the hand.

**Council**
- *Hire-to-pass exploit* — a mid-hand hire can no longer unlock the open card; council
  reshuffles only affect future hands. Removed the council→card re-eval and added a
  click-time `choice_available` guard. Note shown on the council screen.
- *Firing had no consequence* — `Council.dismiss()` now costs unrest and records a
  "grudge"; an empty / one-seat council bleeds unrest yearly (`governance_unrest()`,
  wired into `GameState.pay_upkeep`).

**Clarity**
- *"Forgiving" option made no sense* — the embargo's retaliation choice was mistagged
  `vengefulness +1` (rendered "Forgiving" for an act of revenge). Sign corrected; the
  third option is now genuinely Forgiving.
- *"Severs a route" with no routes* — that preview only shows when a live route exists.
- *Generous/Greedy clash* — temperament's positive pole renamed **Merciful** so it no
  longer reads as the opposite of purse's Greedy/Charitable.
- *Raw constants (`war_chest`)* — shown by readable name (War-Chest, Levies, Steppe Pact…).
- *Option icons* — money/unrest/faith now match the top meters (`$` / `⚔` / `✝`); trait
  shifts are prefixed `→` so poles read as character nudges, not resources.

**Presentation & doom**
- *Bandit Champion's 4th option clipped* — the card scrolls internally; the Nuremberg
  illustration is ~2× larger (220px).
- *Doom odds* — the front shows high-medieval odds ("a triumph already sung" … "the ruin
  of the house"); `readiness`/`severity` stay on the backend (`DoomManager.reckon_flavor()`).

**Meta**
- *Names* — the founder types a ruler name and house name; the house persists across the
  dynasty and shows in the title and Chronicle (`GameState.house`).
- *Empty Chronicle* — now lists every consequential act of the reign, grouped by the ruler
  who made it, instead of only "seized the crown" / "passage of a king."

## Design decisions taken this pass (from the user)

- Council skill gate → **no mid-event hiring** (reshuffle only shapes future hands).
- Empty/undersized council → **consequences for firing** (unrest + grudge) plus a yearly
  ungoverned-realm unrest bleed.
- "Generous/Greedy" → the framing was a **label clash**, not a mechanic bug; fixed by
  renaming temperament's pole to Merciful (no trait-cost rework).

## Files touched

`autoload/EventEngine.gd`, `autoload/Chronicle.gd`, `autoload/Council.gd`,
`autoload/GameState.gd`, `autoload/DoomManager.gd`, `data/events.json`,
`ui/EventCard.gd`, `ui/EventCard.tscn`, `ui/ReignScreen.gd`, `ui/ReignScreen.tscn`,
`ui/SuccessionScreen.gd`, `ui/SuccessionScreen.tscn`, `ui/CouncilScreen.gd`,
`ui/ChronicleScreen.gd`, `resources/Ruler.gd`.
New test: `tests/TestCardRender.{gd,tscn}` (added to `run-tests.ps1`).

## Verification (2026-07-17)

- All 7 data JSON files valid (checked against the real files on the machine).
- `run-tests.ps1` — 7/7 suites PASS: TestPlaystyles, TestThreats, TestTrade, TestMeta,
  TestTraits, TestEscalation, **TestCardRender** (new: renders the Bandit Champion's 4/4
  options through the scroll-wrapped card + the icon/prep/trait preview path).
- Full game scene loads all UI + autoloads headless, exit 0, no script errors.

## How to run

Godot 4.7 exe: `C:\Godot_v4.7-stable_win64\Godot_v4.7-stable_win64.exe`
(a second copy exists at `C:\Users\Bekzat\Downloads\godot47\...`, which `run-tests.ps1` uses).

- **Play it:** launch the exe with `--path <prototype folder>` and no scene argument
  (opens on the founder screen — type your ruler and house name).
- **Regression suite:** `powershell -ExecutionPolicy Bypass -File .\run-tests.ps1`
  (prints one compact verdict line per suite; ~5s total).

## Remaining sign-off

A human editor playtest for *feel*: confirm the core fantasy lands ("my choices three
reigns ago decided this") and do a narrator pass on any new/edited event text (Golden
Nose, the embargo options). Mechanics and UI rendering are machine-verified.

## Gotchas for the next session

- The Linux/sandbox bash mount serves **stale/truncated** copies of freshly-edited large
  files — validate on Windows via desktop-commander, not sandbox bash.
- computer-use MCP **cannot attach** to a raw launched Godot exe (its resolver only matches
  installed/Start-menu apps), so screenshots of the running game aren't available — use the
  headless render test instead.
- After adding a `class_name`, run `--headless --import` or a headless parse first.
