# The ledger of consequential acts + the flag queue that feeds future Plot events.
extends Node

var entries: Array = []       # {ruler, act, consequence, doom_mod}
var flag_queue: Array = []    # {id, fire_at_hand, event_id, ...}

func reset() -> void:
	entries.clear()
	flag_queue.clear()

func record(ruler_name: String, act: String, consequence: String, doom_mod: int = 0, notable: bool = false) -> void:
	entries.append({
		"ruler": ruler_name,
		"act": act,
		"consequence": consequence,
		"doom_mod": doom_mod,
		"notable": notable,
		"generation": GameState.generation,
	})

func schedule(flag: Dictionary) -> void:
	flag_queue.append(flag)

# Drop any pending reign-threat flags — called when a new reign begins so each
# ruler faces exactly one contained threat, never their predecessor's leftovers.
func clear_threat_flags() -> void:
	var keep: Array = []
	for f in flag_queue:
		if not String((f as Dictionary).get("id", "")).begins_with("threat_"):
			keep.append(f)
	flag_queue = keep

# Returns (and removes) flags due at or before the given hand.
func pop_due(hand: int) -> Array:
	var due: Array = []
	var keep: Array = []
	for f in flag_queue:
		if int(f.get("fire_at_hand", 1 << 30)) <= hand:
			due.append(f)
		else:
			keep.append(f)
	flag_queue = keep
	return due

# Ancestral sins that worsen the Doom, capped at +4 (locked in the 10-run audit).
func doom_severity_bonus() -> int:
	var b := 0
	for e in entries:
		b += int(e.get("doom_mod", 0))
	return clampi(b, 0, 4)
