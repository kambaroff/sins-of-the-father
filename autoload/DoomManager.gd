# The bloodline-scale Doom: a rising track, persistent preparation, and the Reckoning.
extends Node

signal doom_changed

const ERA_CATALOG: Array[String] = ["steppe_horde", "black_death", "peasants_revolt"]
const BREATHER_YEARS := 4   # ≈ one reign of lower pressure after surviving (CR-18)

var doom := {}              # {id, type, base, track, prep:{...}}
var breather_years := 0     # while > 0, the track does not climb — the rebuild window

func start(doom_id: String) -> void:
	for d in ContentDB.dooms:
		if d.get("id", "") == doom_id:
			doom = d.duplicate(true)
			doom["track"] = 0
			doom["prep"] = {"walls": 0, "war_chest": 0, "host": 0, "tribute": 0, "nomad_pact": 0}
			breather_years = 0   # fresh doom, fresh clock (era rollover re-sets it after)
			# The steppe horde cannot be walled out — only out-known. A splinter band
			# fleeing the Horde seeks refuge; how you treat them decides the Reckoning.
			if doom_id == "steppe_horde":
				Chronicle.schedule({"id": "steppe_refugees", "event_id": "steppe_refugees_arrive", "fire_at_hand": GameState.hand_counter + 2})
			doom_changed.emit()
			return
	push_warning("Unknown doom: " + doom_id)

func tick() -> void:
	if doom.is_empty():
		return
	if breather_years > 0:               # CR-18: reward the win before raising stakes
		breather_years -= 1
		doom_changed.emit()
		return
	doom["track"] = mini(int(doom["track"]) + 1, 10)
	doom_changed.emit()

func add_prep(kind: String, amount: int) -> void:
	if doom.is_empty():
		return
	doom["prep"][kind] = int(doom["prep"].get(kind, 0)) + amount
	doom_changed.emit()

func severity() -> int:
	return int(doom.get("base", 6)) + Chronicle.doom_severity_bonus()

func readiness() -> int:
	# Prep counts by DOOM-SPECIFIC weight (default 1). Walls are worthless against
	# the steppe horde (weight 0); the nomad pact is decisive (weight 3).
	var weights: Dictionary = doom.get("prep_weights", {}) as Dictionary
	var prep: Dictionary = doom.get("prep", {}) as Dictionary
	var r := 0
	for kind in prep.keys():
		r += int(prep[kind]) * int(weights.get(kind, 1))
	# Locked rule: standing Defense counts for a MILITARY Doom only.
	if doom.get("type", "") == "military":
		r += GameState.defense() * int(weights.get("defense", 1))
	return r

func arrived() -> bool:
	return not doom.is_empty() and int(doom["track"]) >= 10

# Pure read: the outcome band if the Reckoning happened now (locked bands).
func reckon() -> String:
	var sev := severity()
	var rd := readiness()
	if rd >= sev:
		return "SURVIVE"
	if rd >= sev - 3:
		return "BATTERED"
	return "PUPPET / END"

# The same read dressed in a herald's tongue: the odds the court would whisper if the
# Doom broke now. Backend keeps the raw ready/need; the front shows this. Bands align
# with reckon() — SURVIVE (margin >= 0), BATTERED (>= -3), else END.
func reckon_flavor() -> String:
	var margin := readiness() - severity()
	if margin >= 4:
		return "a triumph already sung"
	if margin >= 2:
		return "the day would be ours"
	if margin >= 0:
		return "a near thing, but the line holds"
	if margin >= -1:
		return "a bloody, doubtful hour"
	if margin >= -3:
		return "a battering the house survives"
	if margin >= -5:
		return "a shameful rout"
	return "the ruin of the house"

# The Reckoning actually happens: record it, then either the line ends or the
# next era opens behind a rebuild window (CR-18 — never stack catastrophes).
func resolve_reckoning() -> String:
	var outcome := reckon()
	Chronicle.record(GameState.ruler.name, "faced %s" % String(doom.get("title", "?")), "reckoning: " + outcome, 0)
	if outcome != "PUPPET / END":
		GameState.reckonings_survived += 1   # banked to Legacy when the dynasty ends
		GameState.era += 1
		_start_next_era_doom()
		breather_years = BREATHER_YEARS   # after start(), which zeroes it
	return outcome

# Rotate the catalog; escalate base severity by era. The bloodline keeps its
# physical preparations — but between catastrophes readiness DECAYS (walls crumble,
# war-chests are spent, alliances lapse). Base severity climbs forever while carried
# prep cannot, so no line can stockpile its way to immortality — every dynasty is
# eventually met by a Reckoning it cannot out-prepare.
func _start_next_era_doom() -> void:
	var idx: int = ERA_CATALOG.find(String(doom.get("id", "")))
	var next_id: String = ERA_CATALOG[(idx + 1) % ERA_CATALOG.size()]
	var kept_prep: Dictionary = (doom.get("prep", {}) as Dictionary).duplicate()
	for k in kept_prep.keys():
		kept_prep[k] = int(kept_prep[k]) * 3 / 4   # a quarter of readiness erodes each era
	start(next_id)
	doom["base"] = int(doom["base"]) + (GameState.era - 1)
	doom["prep"] = kept_prep
	GameState.log_line.emit("A new dread stirs: %s (era %d)." % [String(doom.get("title", "?")), GameState.era])
	doom_changed.emit()
