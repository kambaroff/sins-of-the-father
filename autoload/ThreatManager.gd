# Reign-scale contained threats (GDD 'contained threats'): every reign gets ONE
# escalating mini-arc — a raid, a coup, a famine, a heresy, a rival's scheme —
# chosen by the realm's current weakest flank. Address it and it costs coin or
# blood now; ignore it and it worsens, culminating in a crisis that scars the
# bloodline Doom (doom_mod). The tense mini-arc beneath the one epic Reckoning.
# Data-driven: archetypes in threats.json; the 3-beat chains (opening ->
# escalation -> crisis) live in events.json and ride the existing flag/Plot queue.
extends Node

signal threat_changed

const OPENING_DELAY := 2   # hands into a reign before the threat surfaces

var active: Dictionary = {}   # {id, title} — the reign's current threat, for the UI

# Called at the start of EVERY reign (founder in new_game, each heir in install_heir).
func begin_reign() -> void:
	Chronicle.clear_threat_flags()   # one contained threat per reign — clear the last
	active = {}
	if ContentDB.threats.is_empty():
		threat_changed.emit()
		return
	var pick: Dictionary = _select_by_weakness()
	if pick.is_empty():
		threat_changed.emit()
		return
	active = {"id": String(pick.get("id", "")), "title": String(pick.get("title", "?"))}
	Chronicle.schedule({
		"id": "threat_" + String(pick.get("id", "")),
		"event_id": String(pick.get("opening_event", "")),
		"fire_at_hand": GameState.hand_counter + OPENING_DELAY,
	})
	GameState.log_line.emit("A shadow falls over the reign: %s." % active["title"])
	threat_changed.emit()

# Weighted draw: the most exposed flank is likeliest, but every archetype keeps a
# base chance so no two reigns feel scripted the same.
func _select_by_weakness() -> Dictionary:
	var pool: Array = []      # [{def, weight}]
	var total: int = 0
	for t in ContentDB.threats:
		var def: Dictionary = t as Dictionary
		var w: int = 1 + _vuln_bonus(String(def.get("vuln", "none")))
		pool.append({"def": def, "weight": w})
		total += w
	if total <= 0:
		return {}
	var roll: int = randi() % total
	for entry in pool:
		roll -= int(entry["weight"])
		if roll < 0:
			return entry["def"] as Dictionary
	return pool[0]["def"] as Dictionary

# +2 weight when the realm is exposed on that axis; 0 otherwise.
func _vuln_bonus(vuln: String) -> int:
	match vuln:
		"low_defense":
			return 2 if GameState.military_level <= 1 else 0
		"low_loyalty":
			return 2 if (_min_loyalty() <= 1 or int(GameState.ruler.sliders.get("trust", 0)) <= -1) else 0
		"low_treasury":
			return 2 if int(GameState.meters.get("treasury", 5)) <= 3 else 0
		"faith_extreme":
			var f: int = int(GameState.meters.get("faith", 5))
			return 2 if (f >= 8 or f <= 2) else 0
	return 0

func _min_loyalty() -> int:
	if Council.seated.is_empty():
		return 4
	var m: int = 99
	for id in Council.seated:
		m = mini(m, int(Council.loyalty.get(id, 2)))
	return m
