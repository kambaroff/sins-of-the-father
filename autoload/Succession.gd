# Death -> Succession: the three-layer inheritance (CR-1, CR-6, CR-7b).
# Layer 1 (passive): heir gets half of every slider and skill (CR-6).
# Layer 2 (active):  the upbringing chosen during the parent's reign (CR-7b).
# Layer 3 (deathbed): one chosen axis passes at FULL value, not half.
# Doom-prep (DoomManager) and live flags (Chronicle.flag_queue) persist untouched.
extends Node

signal succession_done(heir: Ruler)

const DYNASTY_NAMES: Array[String] = ["Géza", "Koloman", "András", "László", "Salamon", "Vazul", "Álmos"]

var heir_upbringing: String = ""   # "" until the parent invests in one (CR-7b's real trade-off)

# Pay coin now to shape the heir. Returns false if unknown id or unaffordable.
func choose_upbringing(id: String) -> bool:
	var def: Dictionary = ContentDB.upbringing_by_id(id)
	if def.is_empty():
		return false
	var cost: int = int(def.get("cost", 0))
	if int(GameState.meters["treasury"]) < cost:
		return false
	GameState.apply({"treasury": -cost})
	heir_upbringing = id
	GameState.log_line.emit("The heir is %s (−%d coin)." % [String(def.get("name", id)).to_lower(), cost])
	return true

# Layer 1 — passive inheritance: half sliders + half skills (Cunning included).
func inherit(parent: Ruler) -> Ruler:
	var heir: Ruler = Ruler.new()
	heir.name = _heir_name()
	for k in parent.sliders.keys():
		heir.sliders[k] = int(int(parent.sliders[k]) / 2.0)
	for k in parent.skills.keys():
		heir.skills[k] = int(int(parent.skills[k]) / 2.0)
	return heir

# Layer 2 — upbringing nudges + skill + origin advisor.
func apply_upbringing(heir: Ruler, id: String) -> void:
	var def: Dictionary = ContentDB.upbringing_by_id(id)
	if def.is_empty():
		return
	heir.upbringing = id
	heir.origin_advisor = String(def.get("origin_advisor", ""))
	var sliders: Dictionary = def.get("sliders", {}) as Dictionary
	for k in sliders.keys():
		if heir.sliders.has(k):
			heir.sliders[k] = clampi(int(heir.sliders[k]) + int(sliders[k]), -3, 3)
	var skills: Dictionary = def.get("skills", {}) as Dictionary
	for k in skills.keys():
		if heir.skills.has(k):
			heir.skills[k] = clampi(int(heir.skills[k]) + int(skills[k]), 0, 3)

# Layer 3 — deathbed lesson: the chosen axis passes whole.
func apply_deathbed_lesson(heir: Ruler, parent: Ruler, axis: String) -> void:
	if parent.sliders.has(axis):
		heir.sliders[axis] = int(parent.sliders[axis])
	elif parent.skills.has(axis):
		heir.skills[axis] = int(parent.skills[axis])

# Full succession: build the heir, install them, seat the origin advisor.
func succeed(lesson_axis: String) -> Ruler:
	var parent: Ruler = GameState.ruler
	var heir: Ruler = inherit(parent)
	if heir_upbringing != "":
		apply_upbringing(heir, heir_upbringing)
	if lesson_axis != "":
		apply_deathbed_lesson(heir, parent, lesson_axis)
	var schooling: int = InstitutionManager.heir_skill_bonus()   # the University educates the heir
	if schooling > 0:
		_boost_best_skill(heir, schooling)
	heir_upbringing = ""
	GameState.install_heir(heir)
	if heir.origin_advisor != "" and not Council.is_seated(heir.origin_advisor):
		Council.hire(heir.origin_advisor)
		GameState.log_line.emit("%s takes a council seat — the heir's old guardian." % String(Council.def_of(heir.origin_advisor).get("name", heir.origin_advisor)))
	Chronicle.record(parent.name, "died; the crown passes to " + heir.name, "succession", 0)
	succession_done.emit(heir)
	return heir

# A University schools the heir: raise their strongest aptitude (specialisation).
func _boost_best_skill(heir: Ruler, amount: int) -> void:
	var best_k: String = ""
	var best_v: int = -1
	for k in heir.skills.keys():
		if int(heir.skills[k]) > best_v:
			best_v = int(heir.skills[k])
			best_k = String(k)
	if best_k != "":
		heir.skills[best_k] = clampi(int(heir.skills[best_k]) + amount, 0, 3)

func _heir_name() -> String:
	var base: String = DYNASTY_NAMES[(GameState.generation - 1) % DYNASTY_NAMES.size()]
	var cycle: int = floori(float(GameState.generation - 1) / float(DYNASTY_NAMES.size()))
	return "%s %s" % [base, _roman(1 + cycle)]

func _roman(n: int) -> String:
	var numerals: Array[String] = ["I", "II", "III", "IV", "V"]
	return numerals[clampi(n - 1, 0, numerals.size() - 1)]
