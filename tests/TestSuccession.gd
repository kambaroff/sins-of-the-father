# CR-1 / CR-6 / CR-7b verification, headless:
#   godot --headless --path . tests/TestSuccession.tscn
# CR-6:  heirs of different parents start measurably different; prep + flags persist.
# CR-7b: the SAME parent raised two ways yields measurably different heirs + origin advisor.
extends Node

func _ready() -> void:
	_test_passive_inheritance_differs()
	_test_upbringing_counters_bloodline()
	_test_deathbed_lesson_full_pass()
	_test_full_succession_persists_state()
	print("[TEST] CR-1/CR-6/CR-7b PASS — succession verified")
	get_tree().quit()

func _make_parent(temperament: int, cunning: int) -> Ruler:
	var p := Ruler.new()
	p.name = "Parent"
	p.sliders["temperament"] = temperament
	p.skills["cunning"] = cunning
	return p

# CR-6: two heirs from different parents are measurably different.
func _test_passive_inheritance_differs() -> void:
	var cruel := Succession.inherit(_make_parent(-3, 2))
	var kind := Succession.inherit(_make_parent(3, 0))
	assert(int(cruel.sliders["temperament"]) == -1, "half of -3 should be -1")
	assert(int(kind.sliders["temperament"]) == 1, "half of 3 should be 1")
	assert(int(cruel.skills["cunning"]) == 1 and int(kind.skills["cunning"]) == 0, "cunning halves too")
	print("[TEST] CR-6 passive: cruel-line heir t=%d vs kind-line heir t=%d" % [int(cruel.sliders["temperament"]), int(kind.sliders["temperament"])])

# CR-7b: same parent, two upbringings -> measurably different heirs.
func _test_upbringing_counters_bloodline() -> void:
	var parent := _make_parent(-3, 0)          # a cruel king
	var to_abbey := Succession.inherit(parent)
	Succession.apply_upbringing(to_abbey, "abbey")
	var to_war := Succession.inherit(parent)
	Succession.apply_upbringing(to_war, "war_camp")
	assert(int(to_abbey.sliders["temperament"]) == 0, "abbey counters the cruel line (-1 +1 = 0)")
	assert(int(to_war.sliders["temperament"]) == -1 and int(to_war.skills["martial"]) == 1, "war-camp keeps the edge, grows martial")
	assert(to_abbey.origin_advisor == "priest" and to_war.origin_advisor == "marshal", "upbringing sets origin advisor")
	print("[TEST] CR-7b upbringing: abbey heir t=%d vs war-camp heir t=%d mar=%d" % [int(to_abbey.sliders["temperament"]), int(to_war.sliders["temperament"]), int(to_war.skills["martial"])])

# Deathbed lesson: chosen axis passes at full value.
func _test_deathbed_lesson_full_pass() -> void:
	var parent := _make_parent(-3, 3)
	var heir := Succession.inherit(parent)
	Succession.apply_deathbed_lesson(heir, parent, "temperament")
	assert(int(heir.sliders["temperament"]) == -3, "lesson passes the whole slider")
	Succession.apply_deathbed_lesson(heir, parent, "cunning")
	assert(int(heir.skills["cunning"]) == 3, "lesson works on skills too")
	print("[TEST] deathbed lesson: full-value pass confirmed")

# CR-1 + persistence: full succession keeps prep, flags, Chronicle; installs heir + advisor.
func _test_full_succession_persists_state() -> void:
	var founder := _make_parent(-2, 1)
	founder.name = "Founder"
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")
	DoomManager.add_prep("walls", 3)
	Chronicle.schedule({"id": "khans_grudge", "event_id": "steppe_envoy", "fire_at_hand": 99})
	Chronicle.record("Founder", "burned the envoy's yurt", "grudge", 2)
	GameState.meters["treasury"] = 5
	GameState.meters["unrest"] = 5

	assert(Succession.choose_upbringing("spymaster_ward"), "can afford ward of the spymaster")
	assert(int(GameState.meters["treasury"]) == 3, "upbringing cost coin")

	var gen_before: int = GameState.generation
	var heir := Succession.succeed("temperament")

	assert(GameState.ruler == heir and GameState.generation == gen_before + 1, "heir installed, generation advanced")
	assert(GameState.reign_hands == 0 and GameState.death_at_hand >= 12 and GameState.death_at_hand <= 18, "fresh reign clock in the locked 12..18 band")
	assert(int(GameState.meters["unrest"]) == 3, "new-reign grace applied (-2 unrest)")
	assert(int(DoomManager.doom["prep"]["walls"]) == 3, "Doom-prep persists across succession (CR-14 tie-in)")
	assert(_flag_alive("khans_grudge"), "live flags persist to the heir")
	assert(Chronicle.doom_severity_bonus() >= 2, "ancestral sins persist in the Chronicle")
	assert(heir.upbringing == "spymaster_ward" and int(heir.skills["cunning"]) >= 1, "upbringing applied")
	assert(int(heir.sliders["temperament"]) == -2, "deathbed lesson passed the cruelty whole")
	assert(Council.is_seated("spymaster"), "origin advisor takes a council seat")
	assert(Succession.heir_upbringing == "", "upbringing choice resets for the new reign")
	print("[TEST] CR-1 full succession: %s inherits prep+flags+sins, %s seated" % [heir.name, heir.origin_advisor])

func _flag_alive(id: String) -> bool:
	for f in Chronicle.flag_queue:
		if String((f as Dictionary).get("id", "")) == id:
			return true
	return false
