# Throwaway CR-12 verification: starve the council -> loyalty decays -> betrayal
# fires -> betrayal event arrives via the plot slot next hand. Run headless:
#   godot --headless --path . tests/TestBetrayal.tscn
extends Node

func _ready() -> void:
	var founder := Ruler.new()
	founder.name = "Test King"
	GameState.new_game(founder)

	print("[TEST] seated: ", Council.seated)
	assert(Council.seated.size() == 3, "default council should seat 3")
	print("[TEST] upkeep total: ", Council.total_upkeep())

	# Starve: force treasury to 0 and pay upkeep twice (loyalty 2 -> 1 -> 0 -> betray)
	GameState.meters["treasury"] = 0
	GameState.pay_upkeep()
	print("[TEST] after 1st unpaid year, marshal loyalty = ", int(Council.loyalty.get("marshal", -1)))
	assert(int(Council.loyalty.get("marshal", -1)) == 1, "loyalty should drop to 1")

	GameState.meters["treasury"] = 0
	GameState.pay_upkeep()
	print("[TEST] after 2nd unpaid year, seated = ", Council.seated)
	assert(Council.seated.is_empty(), "all three should betray at loyalty 0")
	assert(Chronicle.flag_queue.size() == 3, "3 betrayal events queued, got %d" % Chronicle.flag_queue.size())

	# All three flags are due next hand; the fix must fire one per hand, losing none.
	GameState.hand_counter += 1
	var fired: Array[String] = []
	for i in range(3):
		var ev := EventEngine._pick_plot()
		fired.append(String(ev.get("id", "?")))
		GameState.hand_counter += 1
	print("[TEST] betrayal events fired over 3 hands: ", fired)
	for id in ["marshal_defects", "steward_defects", "priest_defects"]:
		assert(fired.has(id), "missing betrayal event: " + id)
	assert(Chronicle.flag_queue.is_empty(), "queue should be drained")

	# Chronicle recorded the treacheries (feeds Doom severity, CR-15 tie-in)
	var betrayal_entries := 0
	for e in Chronicle.entries:
		if String(e.get("consequence", "")) == "defection":
			betrayal_entries += 1
	assert(betrayal_entries == 3, "3 defections should be in the Chronicle")
	print("[TEST] Chronicle defection entries: ", betrayal_entries, "  doom bonus: ", Chronicle.doom_severity_bonus())

	print("[TEST] CR-12 PASS — neglect -> betrayal -> queued consequence, none lost")
	get_tree().quit()
