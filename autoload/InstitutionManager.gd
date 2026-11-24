# Standing institutions (GDD 'meta carrots'): expensive strong-reign works — a
# Mint, a Cathedral, a University — each granting a PERMANENT passive to every
# future heir. They persist across reigns like Doom-prep, and across DYNASTIES via
# Legacy: the works your ancestors raised still stand when a new line takes power.
# Data-driven: institutions.json holds cost + a generic effect dict the loop reads.
extends Node

signal institutions_changed

var founded: Array = []   # institution ids standing THIS dynasty

# A fresh dynasty inherits every institution its ancestors ever built (Legacy).
func reset() -> void:
	founded = []
	for id in Legacy.remembered_institutions():
		if not founded.has(String(id)):
			founded.append(String(id))
	institutions_changed.emit()

func found(id: String) -> void:
	if founded.has(id) or ContentDB.institution_by_id(id).is_empty():
		return
	founded.append(id)
	Legacy.remember_institution(id)   # your descendants will inherit it
	GameState.log_line.emit("A lasting work is founded: %s." % name_of(id))
	institutions_changed.emit()

func has(id: String) -> bool:
	return founded.has(id)

func name_of(id: String) -> String:
	return String(ContentDB.institution_by_id(id).get("name", id))

func _sum_effect(key: String) -> int:
	var t := 0
	for id in founded:
		t += int((ContentDB.institution_by_id(id).get("effect", {}) as Dictionary).get(key, 0))
	return t

# Passive hooks the game loop reads each at its own moment.
func income_bonus() -> int:
	return _sum_effect("income")            # added to annual income (pay_upkeep)

func yearly_unrest_relief() -> int:
	return _sum_effect("unrest_relief")     # eased each year (pay_upkeep)

func heir_skill_bonus() -> int:
	return _sum_effect("heir_skill")        # added to the heir's best skill (succession)

# Standing works cost coin to keep (GDD: wealth carries cost — no money-faucet).
func upkeep() -> int:
	var t := 0
	for id in founded:
		t += int(ContentDB.institution_by_id(id).get("upkeep", 0))
	return t

func standing() -> Array:
	return founded.duplicate()
