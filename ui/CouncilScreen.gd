# Council & military management overlay: hire/dismiss advisors, invest in their LEVEL
# (more skill lent, for more upkeep), and raise or disband the standing army to
# control its cost. A modal shown on top of ReignScreen.
extends Control
class_name CouncilScreen

signal closed

@onready var rows_box: VBoxContainer = $Panel/VBox/Rows
@onready var upkeep_label: Label = $Panel/VBox/UpkeepLabel
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	Council.council_changed.connect(_refresh)
	back_button.pressed.connect(_on_back_pressed)
	_refresh()

func _refresh() -> void:
	for child in rows_box.get_children():
		rows_box.remove_child(child)   # immediate: queue_free alone doubles rows for a frame
		child.queue_free()

	for def in ContentDB.advisors:
		rows_box.add_child(_advisor_row(def as Dictionary))

	rows_box.add_child(_section("— THE ARMY —"))
	rows_box.add_child(_army_row())

	var advisor_up: int = Council.total_upkeep()
	var army_up: int = GameState.MIL_COST[GameState.military_level]
	upkeep_label.text = "Yearly upkeep:  court 1  ·  council %d  ·  army %d   =   %d coin/year\nReshuffles take effect next season — a new hire cannot unlock the card already before you." % [
		advisor_up, army_up, 1 + advisor_up + army_up]

func _advisor_row(d: Dictionary) -> HBoxContainer:
	var id: String = String(d.get("id", ""))
	var skill: String = String(d.get("skill", "")).capitalize()
	var row := HBoxContainer.new()
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if Council.is_seated(id):
		var lvl: int = Council.level_of(id)
		var loy: int = int(Council.loyalty.get(id, 0))
		label.text = "%s  ·  Lv %d (+%d %s)  ·  %d coin/yr  ·  %s" % [
			String(d.get("name", id)), lvl, lvl, skill,
			int(d.get("upkeep", 0)) + lvl - 1, "♥".repeat(loy) + "♡".repeat(4 - loy)]
		if lvl < Council.MAX_LEVEL:
			row.add_child(_btn("Promote ▲", _on_promote.bind(id)))
		if lvl > 1:
			row.add_child(_btn("Demote ▼", _on_demote.bind(id)))
		row.add_child(_btn("Dismiss", _on_dismiss.bind(id)))
	else:
		label.text = "%s  ·  — vacant —  ·  lends %s  ·  hire for %d coin/yr" % [
			String(d.get("name", id)), skill, int(d.get("upkeep", 0))]
		row.add_child(_btn("Hire", _on_hire.bind(id)))
	return row

func _army_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lvl: int = GameState.military_level
	label.text = "%s  ·  Defense %d  ·  %d coin/yr" % [
		GameState.MIL_NAMES[lvl], GameState.MIL_DEFENSE[lvl], GameState.MIL_COST[lvl]]
	row.add_child(label)
	if lvl < GameState.MIL_COST.size() - 1:
		row.add_child(_btn("Raise ▲", _on_raise_army))
	if lvl > 0:
		row.add_child(_btn("Disband ▼", _on_lower_army))
	return row

func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

func _on_hire(id: String) -> void:
	Council.hire(id)

func _on_dismiss(id: String) -> void:
	Council.dismiss(id)

func _on_promote(id: String) -> void:
	Council.promote(id)

func _on_demote(id: String) -> void:
	Council.demote(id)

func _on_raise_army() -> void:
	GameState.set_military(GameState.military_level + 1)
	_refresh()

func _on_lower_army() -> void:
	GameState.set_military(GameState.military_level - 1)
	_refresh()

func _on_back_pressed() -> void:
	hide()
	closed.emit()
