---
description: Convert Decision Deck entries into events.json in the locked schema.
---

Convert the decision-deck content I point you at ($ARGUMENTS, or the Decision-Deck files if none given) into entries appended to `data/events.json`.

Rules:
- Match the locked event schema exactly: `id` (snake_case), `slot` (seasonal|plot|random), `category` (court|economy|faith|war|folk), `season` (spring|summer|autumn|winter|any), `title`, `body`, `choices[]`.
- Each choice: `text`, `effects` (treasury/unrest/faith deltas), optional `traits` (slider or skill nudges), optional `flags` (scheduled consequences), optional `doom_mod`, optional `requires`.
- Keep sliders in [-3,3] intent and skill names to cunning/charm/martial/stewardship.
- Preserve the satirical voice; keep `body` to 1–2 punchy sentences.
- Honour the content quota (≥⅓ history-based, ≥⅓ with a skill-keyed option, balanced poles).
- After appending, run `/playtest` to confirm the JSON parses and the pools still deal.
