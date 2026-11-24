# CR-16 harness, headless:
#   godot --headless --path . tests/TestPlaystyles.tscn
# Runs seeded dynasties for Saint and Tyrant against every Doom and asserts the
# two playstyles PLAY differently (traits, prep mix) — plus prints the outcome
# matrix for design judgment. "Both can survive any Doom" is the tuning target;
# divergence is the milestone-9 acceptance.
extends Node

const RUNS_PER_CELL := 4

func _ready() -> void:
	var styles: Array[String] = ["saint", "tyrant"]
	var dooms: Array[String] = ["steppe_horde", "black_death", "peasants_revolt"]
	var profile: Dictionary = {}   # style -> aggregated numbers

	print("\n== CR-16 MATRIX (%d runs/cell) ==" % RUNS_PER_CELL)
	for style in styles:
		var agg := {"kindness": 0, "walls_host": 0, "tribute": 0, "nomad_pact": 0, "survivals": 0, "gens": 0, "sins": 0, "runs": 0}
		for doom_id in dooms:
			var cell: Array[String] = []
			for i in RUNS_PER_CELL:
				var r: Dictionary = DynastySim.run(style, doom_id, hash(style + doom_id) + i * 7919)
				var outcomes: Array = r.get("outcomes", [])
				cell.append(_cell_mark(outcomes, String(r.get("end", ""))))
				agg["kindness"] += int((r.sliders as Dictionary).get("temperament", 0)) + int((r.sliders as Dictionary).get("purse", 0))
				agg["walls_host"] += int((r.prep as Dictionary).get("walls", 0)) + int((r.prep as Dictionary).get("host", 0))
				agg["tribute"] += int((r.prep as Dictionary).get("tribute", 0))
				agg["nomad_pact"] += int((r.prep as Dictionary).get("nomad_pact", 0))
				agg["gens"] += int(r.get("generations", 0))
				agg["sins"] += int(r.get("sins", 0))
				agg["runs"] += 1
				for o in outcomes:
					if String(o) != "PUPPET / END":
						agg["survivals"] += 1
			print("  %-8s vs %-16s : %s" % [style, doom_id, " ".join(cell)])
		profile[style] = agg
		print("  %-8s profile: kindness %+d · nomad_pact %d · tribute %d · walls+host %d · sins %d · generations %d · reckonings survived %d" % [
			style, agg["kindness"], agg["nomad_pact"], agg["tribute"], agg["walls_host"], agg["sins"], agg["gens"], agg["survivals"]])

	var saint: Dictionary = profile["saint"]
	var tyrant: Dictionary = profile["tyrant"]
	# The steppe divergence (CR-16, folded in): mercy allies with the refugees and
	# survives via the nomad pact; cruelty seizes their wealth and buys the horde off
	# with tribute. Both must beat the Reckoning — walls never do (weight 0).
	assert(int(saint["kindness"]) > int(tyrant["kindness"]), "the saint's line ends kinder than the tyrant's")
	assert(int(saint["nomad_pact"]) > int(tyrant["nomad_pact"]), "mercy allies with the refugees (nomad pact)")
	assert(int(tyrant["tribute"]) > int(saint["tribute"]), "cruelty buys the horde off with plundered coin (tribute)")
	assert(int(saint["survivals"]) > 0 and int(tyrant["survivals"]) > 0, "both playstyles survive Reckonings")
	print("[TEST] CR-16 PASS — mercy allies, cruelty pays; the paths diverge and both survive")
	get_tree().quit()

# S/B/X per reckoning faced, or the mundane end.
func _cell_mark(outcomes: Array, end_cause: String) -> String:
	if outcomes.is_empty():
		return "·" + end_cause.substr(0, 4)
	var marks := ""
	for o in outcomes:
		match String(o):
			"SURVIVE": marks += "S"
			"BATTERED": marks += "B"
			_: marks += "X"
	return marks
