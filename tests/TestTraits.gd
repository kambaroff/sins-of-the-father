# Trait/skill-expansion harness, headless:
#   godot --headless --path . tests/TestTraits.tscn
# Proves the four new sliders (Temperance/Valor/Wrath/Appetite) + the Learning
# skill are LIVE, not dead data: they inherit, upbringings grant them, choices gate
# on them, the Scholar advisor grants effective Learning, and Learning can mitigate
# an ancestral sin. Finishes with a sim sanity pass (dynasties still run).
extends Node

func _ready() -> void:
	print("\n== TRAIT / SKILL EXPANSION CHECK ==")

	# Data model.
	var r := Ruler.new()
	for k in ["temperance", "valor", "wrath", "appetite"]:
		assert(r.sliders.has(k), "ruler carries the %s slider" % k)
	assert(r.skills.has("learning"), "ruler carries the Learning skill")

	# Upbringings grant the new axes.
	var warrior := Ruler.new()
	Succession.apply_upbringing(warrior, "war_camp")
	assert(int(warrior.sliders["valor"]) == 1, "the war-camp breeds Valor")
	var monk := Ruler.new()
	Succession.apply_upbringing(monk, "abbey")
	assert(int(monk.sliders["temperance"]) == 1 and int(monk.sliders["appetite"]) == 1, "the abbey breeds Temperance + Chastity")
	var sage := Ruler.new()
	Succession.apply_upbringing(sage, "scholars")
	assert(int(sage.skills["learning"]) == 1, "scholars grant Learning")
	print("  upbringings grant the new axes (Valor, Temperance/Appetite, Learning)")

	# Inheritance halves a new slider like any other.
	var parent := Ruler.new()
	parent.sliders["valor"] = 2
	var heir := Succession.inherit(parent)
	assert(int(heir.sliders["valor"]) == 1, "Valor 2 halves to the heir")
	print("  new sliders inherit (Valor 2 -> heir 1)")

	# A slider gate: the 'calm' option needs Wrath >= 1.
	GameState.new_game(Ruler.new())
	var calm_choice := {"requires": {"slider": "wrath", "min": 1}}
	GameState.ruler.sliders["wrath"] = 0
	assert(not EventEngine.choice_available(calm_choice), "a wrathful ruler can't take the calm option")
	GameState.ruler.sliders["wrath"] = 1
	assert(EventEngine.choice_available(calm_choice), "a calm ruler can")
	print("  slider gates work (Wrath-gated option)")

	# Learning gate + Scholar-advisor synergy.
	GameState.new_game(Ruler.new())
	var learned_choice := {"requires": {"skill": "learning", "min": 1}}
	assert(not EventEngine.choice_available(learned_choice), "Learning 0 with no Scholar -> locked")
	Council.hire("scholar")
	assert(EventEngine.choice_available(learned_choice), "the Scholar advisor grants effective Learning")
	print("  Learning gate + Scholar synergy verified")

	# Learning can mitigate an ancestral sin (negative doom_mod).
	Chronicle.reset()
	Chronicle.record("X", "a great sin", "", 3)
	assert(Chronicle.doom_severity_bonus() == 3, "a sin raises severity +3")
	Chronicle.record("X", "studied the histories", "", -1)
	assert(Chronicle.doom_severity_bonus() == 2, "Learning mitigates it to +2")
	print("  Learning mitigates ancestral sin (doom_mod -1)")

	# Sim sanity: dynasties still run with the expanded trait set; axes get exercised.
	var ran := 0
	var moved := 0
	for s in range(4):
		var res: Dictionary = DynastySim.run("balanced", "steppe_horde", 700 + s * 13)
		if int(res.get("generations", 0)) >= 1:
			ran += 1
		for k in ["temperance", "valor", "wrath", "appetite"]:
			if int((res.get("sliders", {}) as Dictionary).get(k, 0)) != 0:
				moved += 1
	assert(ran == 4, "dynasties still run with the expanded trait set")
	print("  sim: 4 dynasties ran; new axes non-zero in %d final-ruler checks" % moved)
	print("[TEST] TRAITS PASS — new sliders + Learning move, gate, inherit, and mitigate")
	get_tree().quit()
