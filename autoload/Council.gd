# Runtime advisor state: who's seated, their LEVEL (1..MAX, each level +1 upkeep and
# +1 to the skill they lend), their loyalty (0..4), and betrayal on neglect.
extends Node

signal council_changed

const MAX_LEVEL := 3

var loyalty: Dictionary = {}         # advisor_id: String -> loyalty: int (0..4)
var levels: Dictionary = {}          # advisor_id: String -> level: int (1..MAX_LEVEL)
var seated: Array[String] = []       # currently seated advisor ids

func reset() -> void:
	loyalty = {}
	levels = {}
	seated = []
	seed_default()

func seed_default() -> void:
	for def in ContentDB.advisors:
		var d: Dictionary = def as Dictionary
		if bool(d.get("default_seat", false)):
			hire(String(d.get("id", "")))

func hire(advisor_id: String) -> bool:
	if is_seated(advisor_id):
		return false
	var def: Dictionary = def_of(advisor_id)
	if def.is_empty():
		return false
	seated.append(advisor_id)
	loyalty[advisor_id] = int(def.get("start_loyalty", 2))
	levels[advisor_id] = 1
	council_changed.emit()
	return true

# Firing a minister is never free. The court resents a purge — and resents losing a
# TRUSTED one more sharply — so a dismissal costs unrest now and leaves a grudge in
# the Chronicle. (A hollowed-out council also festers year on year; see governance_unrest.)
func dismiss(advisor_id: String) -> void:
	if not is_seated(advisor_id):
		return
	var def: Dictionary = def_of(advisor_id)
	var advisor_name: String = String(def.get("name", advisor_id))
	var was_trusted: bool = int(loyalty.get(advisor_id, 0)) >= 3
	seated.erase(advisor_id)
	loyalty.erase(advisor_id)
	levels.erase(advisor_id)
	var bump: int = 2 if was_trusted else 1
	if GameState.ruler != null:
		GameState.apply({"unrest": bump})
		Chronicle.record(GameState.ruler.name, "dismissed " + advisor_name, "grudge", 0)
		GameState.log_line.emit("%s is cast out and leaves the court resentful (+%d unrest)." % [advisor_name, bump])
	council_changed.emit()

# A realm needs officers. An empty or barely-staffed council drifts into corruption
# and lawlessness — unrest festers each year until the seats are filled again.
func governance_unrest() -> int:
	var n: int = seated.size()
	if n == 0:
		return 2
	if n == 1:
		return 1
	return 0

func is_seated(advisor_id: String) -> bool:
	return seated.has(advisor_id)

func def_of(advisor_id: String) -> Dictionary:
	return ContentDB.advisor_by_id(advisor_id)

# Level 1 by default; 0 means not seated.
func level_of(advisor_id: String) -> int:
	return int(levels.get(advisor_id, 1)) if is_seated(advisor_id) else 0

# Invest in an advisor: a higher level lends a bigger skill bonus but costs +1 upkeep.
func promote(advisor_id: String) -> void:
	if is_seated(advisor_id) and level_of(advisor_id) < MAX_LEVEL:
		levels[advisor_id] = level_of(advisor_id) + 1
		council_changed.emit()

func demote(advisor_id: String) -> void:
	if is_seated(advisor_id) and level_of(advisor_id) > 1:
		levels[advisor_id] = level_of(advisor_id) - 1
		council_changed.emit()

# Base upkeep + (level - 1): a level-3 seat costs 3 coin/year.
func total_upkeep() -> int:
	var total: int = 0
	for id in seated:
		total += int(def_of(id).get("upkeep", 0)) + (level_of(id) - 1)
	return total

# The skill an advisor lends is boosted by their level: a level-2 Marshal grants +2
# effective Martial to gated choices (so investing in a seat genuinely pays off).
func advisor_skill_bonus(skill: String) -> int:
	var best: int = 0
	for id in seated:
		if String(def_of(id).get("skill", "")) == skill:
			best = maxi(best, level_of(id))
	return best

func has_skill_advisor(skill: String) -> bool:
	return advisor_skill_bonus(skill) > 0

func adjust_loyalty(advisor_id: String, delta: int) -> void:
	if not is_seated(advisor_id):
		return
	var v: int = clampi(int(loyalty.get(advisor_id, 0)) + delta, 0, 4)
	loyalty[advisor_id] = v
	council_changed.emit()
	if v <= 0:
		_betray(advisor_id)

func _betray(advisor_id: String) -> void:
	var def: Dictionary = def_of(advisor_id)
	if def.is_empty():
		return
	var betrayal_event: String = String(def.get("betrayal_event", ""))
	var doom_mod: int = int(def.get("betrayal_doom_mod", 0))
	var advisor_name: String = String(def.get("name", advisor_id))
	if is_seated(advisor_id):
		seated.erase(advisor_id)
	loyalty.erase(advisor_id)
	levels.erase(advisor_id)
	if betrayal_event != "":
		Chronicle.schedule({
			"id": "betrayal_" + advisor_id,
			"event_id": betrayal_event,
			"fire_at_hand": GameState.hand_counter + 1,
		})
	Chronicle.record(GameState.ruler.name, advisor_name + " betrayed the crown", "defection", doom_mod)
	GameState.log_line.emit("%s has betrayed you!" % advisor_name)
	council_changed.emit()
