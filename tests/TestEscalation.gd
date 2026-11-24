# Doom-escalation harness, headless:
#   godot --headless --path . tests/TestEscalation.tscn
# Proves the tuning goal: because carried prep DECAYS a quarter each era while base
# severity climbs forever, even a dynasty that invests the maximum every single era
# eventually meets a Reckoning it cannot out-prepare. No stockpiling to immortality.
extends Node

func _ready() -> void:
	print("\n== DOOM ESCALATION CHECK ==")
	var founder := Ruler.new()
	founder.name = "Test"
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")
	var invest := 3   # a strong dynasty's sustained per-era prep investment
	var fell_at := 0
	var survived := 0
	for era in range(1, 41):
		DoomManager.add_prep("host", invest)
		DoomManager.doom["track"] = 10
		var band: String = DoomManager.reckon()
		var rd: int = DoomManager.readiness()
		var sev: int = DoomManager.severity()
		if band == "PUPPET / END":
			fell_at = era
			print("  era %2d: readiness %d vs severity %d  ->  FALLS" % [era, rd, sev])
			break
		survived += 1
		if era <= 3 or era % 5 == 0:
			print("  era %2d: readiness %d vs severity %d  ->  %s" % [era, rd, sev, band])
		DoomManager.resolve_reckoning()   # decays carried prep, raises base, rotates the doom
	assert(fell_at > 0, "a max-investing dynasty must EVENTUALLY fall")
	print("  investing +%d prep/era: survived %d Reckonings, then fell at era %d" % [invest, survived, fell_at])
	print("[TEST] ESCALATION PASS — prep decays, severity climbs; no line is immortal")
	get_tree().quit()
