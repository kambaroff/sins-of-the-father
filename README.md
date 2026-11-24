# Sins of the Father — Godot prototype (engine core)

A player-driven ReignScreen UI (`ui/ReignScreen.tscn`) plus a headless auto-play driver (`Main.tscn`, still used by `/playtest`) that prints a whole simulated dynasty to the Output console.

## Run it

1. Install **Godot 4.3+** (standard, not .NET — this uses GDScript).
2. Open the Godot project manager → **Import** → select this folder's `project.godot` → **Open**.
3. Press **▶ Play** (F5) to launch the interactive `ReignScreen`. Click choices, watch meters update live, open the Council panel to hire/dismiss advisors.
4. To watch the old headless auto-sim instead, open `Main.tscn` and press **Play Scene** (Ctrl+Shift+F5), or run `godot --headless --path . Main.tscn`.

Either way you'll see each season's 3-card hand, the meters, the Doom track rising, upkeep (now including Council costs), deaths and successions (with new-reign grace), and finally **the Reckoning** — readiness vs severity, with the ancestral sins that worsened it printed from the Chronicle.

## What's implemented (matches the GDD/locked constants)

- **Hand-counter pacing** (not a calendar) — `GameState.hand_counter`.
- **3 meters** with lose conditions (bankruptcy / revolt / deposition).
- **Season hand of 3** (seasonal · plot · random); the **plot slot is fed by the consequence flag queue** (`Chronicle`).
- **Consequence flags** — e.g., robbing the caravan schedules `mercenaries_return` a few hands later.
- **Trait sliders + skills** nudged by choices; **inheritance** halves both on succession.
- **Yearly upkeep** (court + military level → Defense).
- **Bloodline Doom** — rising track, persistent prep, **severity = base + capped-at-4 ancestral sins**, `military` Doom counts Defense (locked rule), Reckoning bands (SURVIVE / BATTERED / PUPPET-END).
- **New-reign grace** (−2 unrest on succession).
- **Data-driven content** — all events in `data/events.json` (48), dooms in `data/dooms.json`, advisors in `data/advisors.json`. Add an event/advisor by editing JSON.
- **ReignScreen UI** — meters, one card at a time from the season hand, live effect previews, lose-condition overlay.
- **Council** — hire/dismiss advisors (Marshal/Steward/Priest default-seated, Spymaster/Scholar hireable), advisor upkeep folded into the yearly cost, loyalty (0-4) that decays on unpaid upkeep and triggers a scripted betrayal Plot event at 0.
- **`requires` gating** on choices — advisor-seated / skill-threshold (with +1 if a matching advisor is seated) / slider-range / live-flag checks, enforced by `EventEngine.choice_available()` and rendered as disabled `[locked]` buttons in the UI (and filtered out of the headless AI's options).

## Deliberately stubbed (next steps)

- **The Circling / regency**, **upbringing**, **deathbed lesson** (succession is a plain half-inheritance for now).
- **Redemption events**, **rally/comeback levers**, **recovery breather**, **escalation to a 2nd Doom**.
- **Skill × advisor effect scaling** (advisors currently only add +1 to `requires` skill checks, not to raw effect magnitudes).
- **Chronicle screen**, **Doom/Reckoning screen**, **Dynasty summary screen** — no UI yet, only the headless prints.

## File map

```
project.godot          autoloads registered here
Main.tscn / Main.gd    headless auto-sim driver (used by /playtest)
autoload/
  ContentDB.gd         loads JSON content (events, dooms, advisors)
  GameState.gd         meters, hand-counter, upkeep, lose checks
  EventEngine.gd       deals the hand, resolves a choice, requires-gating
  DoomManager.gd       track, prep, severity, reckoning
  Chronicle.gd         ledger + consequence flag queue
  Council.gd           advisor loyalty, seating, betrayal
resources/Ruler.gd     sliders + skills
ui/
  ReignScreen.tscn/.gd     the interactive main scene
  EventCard.tscn/.gd       one event card, reused per hand slot
  CouncilScreen.tscn/.gd   hire/dismiss advisors
  components/MeterBar.tscn/.gd
data/events.json       48 events (locked schema)
data/dooms.json        the three slice Dooms
data/advisors.json     5 advisors (3 default-seated, 2 hireable)
```

## Next coding session

1. Finish succession: upbringing + deathbed lesson (currently a plain half-inheritance).
2. Skill × advisor effect scaling (beyond the current `requires` +1 compensation).
3. Chronicle / Doom / Dynasty-summary screens, then the Circling.
