# CR-13/14/15/18 verification, headless:
#   godot --headless --path . tests/TestDoom.tscn
# Track rises · severity reads the Chronicle (capped +4) · readiness counts Defense
# only for military Dooms · prep flows from event choices · surviving opens the next
# era behind a recovery breather that halts the track.
extends Node

func _ready() -> void:
	var founder := Ruler.new()
	founder.name = "Test King"
	GameState.new_game(founder)

	_test_severity_reads_chronicle()
	_test_readiness_typing()
	_test_prep_from_event_choice()
	_test_reckoning_bands()
	_test_survive_starts_breather_era()
	_test_end_is_end()
	print("[TEST] CR-13/14/15/18 PASS — the Doom is verified")
	get_tree().quit()

# CR-15: ancestral sins feed severity, capped at +4 (locked).
func _test_severity_reads_chronicle() -> void:
	DoomManager.start("steppe_horde")
	assert(DoomManager.severity() == 6, "base severity 6")
	Chronicle.record("Ancestor", "burned the steppe envoy", "grudge", 3)
	Chronicle.record("Ancestor", "poisoned the wells", "grudge", 3)
	assert(Chronicle.doom_severity_bonus() == 4, "sin bonus capped at +4")
	assert(DoomManager.severity() == 10, "severity = base + capped sins")
	print("[TEST] CR-15: severity 6 -> 10 via Chronicle, cap holds")

# Locked rule: Defense counts 1:1 vs military Dooms, 0 vs plague/social.
func _test_readiness_typing() -> void:
	GameState.military_level = 2   # Defense 4
	DoomManager.start("steppe_horde")
	DoomManager.add_prep("walls", 2)
	assert(DoomManager.readiness() == 6, "military doom: walls 2 + defense 4")
	DoomManager.start("black_death")
	DoomManager.add_prep("walls", 2)
	assert(DoomManager.readiness() == 2, "plague doom: defense counts 0")
	print("[TEST] readiness typing: horde 6 vs plague 2 from identical realm")

# CR-14 source: an event choice with "prep" invests in the Doom.
func _test_prep_from_event_choice() -> void:
	DoomManager.start("steppe_horde")
	var ev: Dictionary = ContentDB.event_by_id("muster_the_levies")
	var choice: Dictionary = (ev.get("choices", []) as Array)[1] as Dictionary   # "Let the Marshal handle it"
	EventEngine.resolve(ev, choice)
	assert(int(DoomManager.doom["prep"]["host"]) == 1, "muster raised the host")
	print("[TEST] CR-14: event choice -> prep host +1")

# Locked bands: >=sev SURVIVE · >=sev-3 BATTERED · else END.
func _test_reckoning_bands() -> void:
	Chronicle.reset()
	DoomManager.start("steppe_horde")   # base 6
	GameState.military_level = 0
	DoomManager.add_prep("walls", 6)
	assert(DoomManager.reckon() == "SURVIVE", "6 vs 6 survives")
	DoomManager.start("steppe_horde")
	DoomManager.add_prep("walls", 3)
	assert(DoomManager.reckon() == "BATTERED", "3 vs 6 battered")
	DoomManager.start("steppe_horde")
	assert(DoomManager.reckon() == "PUPPET / END", "0 vs 6 ends the line")
	print("[TEST] reckoning bands hold at 6/3/0 readiness vs severity 6")

# CR-18: surviving opens the next era — escalated, prep kept, track frozen a while.
func _test_survive_starts_breather_era() -> void:
	Chronicle.reset()
	GameState.era = 1
	DoomManager.start("steppe_horde")
	DoomManager.add_prep("walls", 6)
	DoomManager.doom["track"] = 10
	var outcome := DoomManager.resolve_reckoning()
	assert(outcome == "SURVIVE", "prepared line survives")
	assert(GameState.era == 2, "era escalates")
	assert(String(DoomManager.doom["id"]) == "black_death", "catalog rotates to the plague")
	assert(int(DoomManager.doom["base"]) == 8, "escalation: base 7 + (era-1)")
	assert(int(DoomManager.doom["prep"]["walls"]) == 6, "walls survive the horde")
	assert(int(DoomManager.doom["track"]) == 0, "new track starts at 0")
	assert(DoomManager.breather_years == 4, "breather window set")
	var i := 0
	while i < 4:
		DoomManager.tick()
		i += 1
	assert(int(DoomManager.doom["track"]) == 0, "track frozen through the breather")
	DoomManager.tick()
	assert(int(DoomManager.doom["track"]) == 1, "then it climbs again")
	assert(_chronicle_has("reckoning: SURVIVE"), "the Reckoning is written into the Chronicle")
	print("[TEST] CR-18: survive -> era 2 black death (base 8), 4-yr breather, prep kept")

func _test_end_is_end() -> void:
	Chronicle.reset()
	GameState.era = 1
	DoomManager.start("steppe_horde")
	DoomManager.doom["track"] = 10
	var outcome := DoomManager.resolve_reckoning()
	assert(outcome == "PUPPET / END", "unprepared line falls")
	assert(GameState.era == 1, "no era escalation on END")
	assert(String(DoomManager.doom["id"]) == "steppe_horde", "no next doom on END")
	print("[TEST] END is END: no escalation past the fall")

func _chronicle_has(consequence: String) -> bool:
	for e in Chronicle.entries:
		if String(e.get("consequence", "")) == consequence:
			return true
	return false
