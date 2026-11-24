# The Crown Passes — succession / character creation overlay (CR-1, CR-6, CR-7b, CR-24).
# Founder mode: game start; pick an origin, take the throne — never a blank slate.
# Succession mode: shows exactly what the heir inherits (sliders, skills, prep, live
# flags), lets the dying ruler pick the deathbed lesson, and — if no upbringing was
# invested during the reign — a cheap origin fallback.
extends Control
class_name SuccessionScreen

signal throne_taken

const POLES: Dictionary = {
	"temperament": ["Cruel", "Merciful"],
	"purse": ["Greedy", "Charitable"],
	"bearing": ["Proud", "Humble"],
	"trust": ["Paranoid", "Trusting"],
	"faith": ["Zealous", "Worldly"],
	"vengefulness": ["Vengeful", "Forgiving"],
	"temperance": ["Hedonist", "Ascetic"],
	"valor": ["Craven", "Brave"],
	"wrath": ["Wrathful", "Calm"],
	"appetite": ["Lustful", "Chaste"],
}

var _is_founder: bool = true
var _parent: Ruler = null
var _lesson_axis: String = ""
var _origin_id: String = ""
var _origin_locked: bool = false

@onready var title_label: Label = $Panel/Scroll/VBox/TitleLabel
@onready var inherit_label: Label = $Panel/Scroll/VBox/InheritLabel
@onready var name_header: Label = $Panel/Scroll/VBox/NameHeader
@onready var name_input: LineEdit = $Panel/Scroll/VBox/NameInput
@onready var house_input: LineEdit = $Panel/Scroll/VBox/HouseInput
@onready var lesson_header: Label = $Panel/Scroll/VBox/LessonHeader
@onready var lesson_box: VBoxContainer = $Panel/Scroll/VBox/LessonBox
@onready var origin_header: Label = $Panel/Scroll/VBox/OriginHeader
@onready var origin_box: VBoxContainer = $Panel/Scroll/VBox/OriginBox
@onready var take_button: Button = $Panel/Scroll/VBox/TakeButton

func _ready() -> void:
	take_button.pressed.connect(_on_take_pressed)

func open_for_founder() -> void:
	_is_founder = true
	_parent = null
	_lesson_axis = ""
	_origin_locked = false
	title_label.text = "A CROWN IS SEIZED — choose your origin"
	inherit_label.text = "You inherit nothing but ambition. What you were before the throne decides who stands beside it."
	name_header.show()
	name_input.show()
	house_input.show()
	lesson_header.hide()
	_clear(lesson_box)
	_build_origin_options(true)
	take_button.text = "Seize the throne ▸"
	show()

func open_for_succession(parent: Ruler) -> void:
	_is_founder = false
	_parent = parent
	_lesson_axis = ""
	_origin_id = ""
	title_label.text = "THE CROWN PASSES — %s is dying" % parent.name
	inherit_label.text = _inheritance_preview(parent)
	name_header.hide()   # the heir keeps the house; naming is the founder's alone
	name_input.hide()
	house_input.hide()
	lesson_header.show()
	_build_lesson_options(parent)
	# Every ruler chooses an upbringing (per UI-Design.md), heir included.
	origin_header.show()
	_build_origin_options(true)
	take_button.text = "Take the throne ▸"
	show()

# --- preview ------------------------------------------------------------

func _inheritance_preview(parent: Ruler) -> String:
	var heir: Ruler = Succession.inherit(parent)   # pure preview; not installed
	var lines: Array[String] = ["INHERITED (half of %s):" % parent.name]
	for axis in heir.sliders.keys():
		var v: int = int(heir.sliders[axis])
		if v != 0 or int(parent.sliders[axis]) != 0:
			lines.append("  %s %s" % [_axis_title(String(axis)), _slider_text(String(axis), v)])
	var skill_bits: Array[String] = []
	for s in heir.skills.keys():
		if int(heir.skills[s]) > 0:
			skill_bits.append("%s %s" % [String(s), "●".repeat(int(heir.skills[s]))])
	if not skill_bits.is_empty():
		lines.append("  Skills: " + ", ".join(skill_bits))
	var prep: Dictionary = DoomManager.doom.get("prep", {}) as Dictionary
	var prep_bits: Array[String] = []
	for k in prep.keys():
		if int(prep[k]) > 0:
			prep_bits.append("%s %s" % [String(k), "▓".repeat(mini(int(prep[k]), 6))])
	lines.append("  Doom-prep: " + (" · ".join(prep_bits) if not prep_bits.is_empty() else "none — the line was not ready"))
	var flag_bits: Array[String] = []
	for f in Chronicle.flag_queue:
		flag_bits.append(String((f as Dictionary).get("id", "?")))
	if not flag_bits.is_empty():
		lines.append("  ⏳ Live flags: " + ", ".join(flag_bits))
	return "\n".join(lines)

func _slider_text(axis: String, v: int) -> String:
	var poles: Array = POLES.get(axis, ["-", "+"]) as Array
	var pos: int = clampi(v, -3, 3) + 3   # 0..6
	var track: String = ""
	for i in 7:
		track += "◆" if i == pos else "─"
	return "%s ◀%s▶ %s" % [String(poles[0]), track, String(poles[1])]

func _axis_title(axis: String) -> String:
	return axis.capitalize().rpad(13)

# --- option builders ----------------------------------------------------

func _build_lesson_options(parent: Ruler) -> void:
	_clear(lesson_box)
	var group := ButtonGroup.new()
	_add_lesson_button("Teach nothing — let the child find their own way", "", group, true)
	for axis in parent.sliders.keys():
		var v: int = int(parent.sliders[axis])
		if v != 0:
			var pole: String = String((POLES[axis] as Array)[0 if v < 0 else 1])
			_add_lesson_button("\"%s\" — pass %s whole (%+d)" % [_lesson_quote(String(axis), v), pole, v], String(axis), group, false)
	for skill in parent.skills.keys():
		if int(parent.skills[skill]) >= 2:
			_add_lesson_button("Drill the heir in %s (pass %d whole)" % [String(skill), int(parent.skills[skill])], String(skill), group, false)

func _add_lesson_button(text: String, axis: String, group: ButtonGroup, pressed: bool) -> void:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.pressed.connect(func() -> void: _lesson_axis = axis)
	lesson_box.add_child(b)

func _lesson_quote(axis: String, v: int) -> String:
	match axis:
		"temperament": return "Mercy is expensive" if v < 0 else "A fed peasant plows"
		"purse": return "Coin solves everything" if v < 0 else "Give, and be loved"
		"bearing": return "Never kneel" if v < 0 else "Pride buries kings"
		"trust": return "Everyone lies" if v < 0 else "Alone, you are nothing"
		"faith": return "God watches everything" if v < 0 else "Heaven can wait"
		"vengefulness": return "Forget nothing" if v < 0 else "Grudges are heavy"
		"temperance": return "Take your pleasures now" if v < 0 else "Deny the flesh"
		"valor": return "A live coward outlasts a dead hero" if v < 0 else "Fear is a peasant's luxury"
		"wrath": return "Answer every slight" if v < 0 else "A cool head keeps its crown"
		"appetite": return "Want everything" if v < 0 else "Master your hungers"
	return "Remember your father"

func _build_origin_options(selectable: bool) -> void:
	_clear(origin_box)
	origin_header.text = "YOUR BACKGROUND (sets your origin advisor):" if _is_founder else "HOW THE HEIR WAS RAISED (sets the origin advisor):"
	if not selectable:
		return
	var group := ButtonGroup.new()
	var first: bool = true
	for u in ContentDB.upbringings:
		var d: Dictionary = u as Dictionary
		var id: String = String(d.get("id", ""))
		var cost: int = int(d.get("cost", 0))
		var advisor: String = String(d.get("origin_advisor", ""))
		var advisor_name: String = String(ContentDB.advisor_by_id(advisor).get("name", "no one"))
		var b := Button.new()
		var cost_str: String = ("  (−%d coin)" % cost) if cost > 0 else "  (free)"
		b.text = "%s → %s%s\n      grants: %s" % [String(d.get("name", id)), advisor_name, cost_str, _upbringing_grants(d)]
		b.toggle_mode = true
		b.button_group = group
		if first:
			b.button_pressed = true
			_origin_id = id
			first = false
		b.pressed.connect(func() -> void: _origin_id = id)
		origin_box.add_child(b)

# Spell out what an upbringing actually confers: the skill AND the trait lean, so
# a player never discovers "Greedy" only after choosing the counting-house.
func _upbringing_grants(d: Dictionary) -> String:
	var bits: Array[String] = []
	for sk in (d.get("skills", {}) as Dictionary).keys():
		bits.append("%s +%d" % [String(sk).capitalize(), int(d["skills"][sk])])
	for sl in (d.get("sliders", {}) as Dictionary).keys():
		var v: int = int(d["sliders"][sl])
		if POLES.has(sl):
			bits.append(String((POLES[sl] as Array)[1 if v > 0 else 0]))
		else:
			bits.append("%s %+d" % [String(sl), v])
	return ", ".join(bits) if not bits.is_empty() else "nothing but a name"

func _clear(box: VBoxContainer) -> void:
	# remove_child + queue_free: queue_free alone leaves children in the tree
	# until frame end, doubling rows on same-frame rebuilds.
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

# --- confirm ------------------------------------------------------------

func _on_take_pressed() -> void:
	if _is_founder:
		_take_as_founder()
	else:
		_take_as_heir()
	hide()
	throne_taken.emit()

func _take_as_founder() -> void:
	var founder := Ruler.new()
	var chosen_name: String = name_input.text.strip_edges()
	var chosen_house: String = house_input.text.strip_edges()
	founder.name = chosen_name if chosen_name != "" else "Béla I"
	GameState.house = chosen_house if chosen_house != "" else "Béla"
	founder.skills["martial"] = 1
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")
	Succession.apply_upbringing(founder, _origin_id)   # origin = the founder's own past
	if founder.origin_advisor != "" and not Council.is_seated(founder.origin_advisor):
		Council.hire(founder.origin_advisor)
	Chronicle.record(founder.name, "seized the crown", "founding", 0)

func _take_as_heir() -> void:
	if _origin_id != "":
		Succession.choose_upbringing(_origin_id)   # every heir gets an upbringing (UI-Design.md)
	Succession.succeed(_lesson_axis)
