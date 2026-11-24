# Renders one event dict and emits the chosen option. Reused across the season hand.
extends PanelContainer
class_name EventCard

signal choice_made(choice: Dictionary)

# Match the meter icons at the top of the reign screen exactly (see MeterBar setup):
# Treasury $, Unrest ⚔, Faith ✝ — so an option's cost reads against the bar it moves.
const EFFECT_ICONS: Dictionary = {
	"treasury": "$",
	"unrest": "⚔",
	"faith": "✝",
}

# Doom preparations shown to the player in plain words, never raw data keys.
const PREP_LABELS: Dictionary = {
	"walls": "Walls",
	"war_chest": "War-Chest",
	"host": "Levies",
	"tribute": "Tribute",
	"nomad_pact": "Steppe Pact",
	"defense": "Standing Army",
}

@onready var illustration: TextureRect = $Scroll/VBox/Illustration
@onready var slot_tag: Label = $Scroll/VBox/SlotTag
@onready var category_tag: Label = $Scroll/VBox/CategoryTag
@onready var title_label: Label = $Scroll/VBox/Title
@onready var body_label: Label = $Scroll/VBox/Body
@onready var choices_box: VBoxContainer = $Scroll/VBox/Choices

func show_event(event: Dictionary, slot_label: String) -> void:
	_set_illustration(String(event.get("category", "")))
	slot_tag.text = slot_label.to_upper()
	category_tag.text = String(event.get("category", ""))
	title_label.text = String(event.get("title", ""))
	body_label.text = String(event.get("body", ""))
	for child in choices_box.get_children():
		choices_box.remove_child(child)   # immediate: queue_free alone doubles rows for a frame
		child.queue_free()
	var choices: Array = event.get("choices", []) as Array
	for c in choices:
		var choice: Dictionary = c as Dictionary
		var button := Button.new()
		var available: bool = EventEngine.choice_available(choice)
		var label: String = String(choice.get("text", "")) + "   " + _preview(choice)
		if not (choice.get("flags", []) as Array).is_empty():
			label += "  ⏳"   # CR-21: consequences are telegraphed, never hidden
		if not available:
			label += "   🔒 %s" % _lock_reason(choice)
		elif not (choice.get("requires", {}) as Dictionary).is_empty():
			var note: String = _unlock_note(choice)
			if note != "":
				label += "   ✓ %s" % note
		button.text = label
		button.disabled = not available
		# Fill the card width and wrap long option text so nothing is clipped off-screen
		# (the Bandit Champion's fourth option used to fall below the fold).
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
		if available:
			button.pressed.connect(_on_choice_pressed.bind(choice))
		choices_box.add_child(button)

func _preview(choice: Dictionary) -> String:
	var parts: Array[String] = []
	var effects: Dictionary = EventEngine.modified_effects(choice)   # show trait-adjusted costs
	for k in effects.keys():
		var delta: int = int(effects[k])
		parts.append("%s%d%s" % ["+" if delta > 0 else "", delta, String(EFFECT_ICONS.get(k, k))])
	# Trait shifts: an arrow marks a CHARACTER nudge toward a pole (→Merciful, →Vengeful),
	# so it never reads as a resource. Aptitudes (skills) aren't poles, so show them as +N.
	var traits: Dictionary = choice.get("traits", {}) as Dictionary
	for k in traits.keys():
		var d: int = int(traits[k])
		if SuccessionScreen.POLES.has(k):
			parts.append("→%s" % String((SuccessionScreen.POLES[k] as Array)[1 if d > 0 else 0]))
		else:
			parts.append("%s %s%d" % [String(k).capitalize(), "+" if d > 0 else "", d])
	var prep: Dictionary = choice.get("prep", {}) as Dictionary
	for k in prep.keys():
		parts.append("%s +%d" % [String(PREP_LABELS.get(k, String(k).capitalize())), int(prep[k])])
	var dm: int = int(choice.get("doom_mod", 0))
	if dm != 0:
		parts.append("Doom %s%d" % ["+" if dm > 0 else "", dm])
	var trade: Dictionary = choice.get("trade", {}) as Dictionary
	if trade.has("open"):
		parts.append("opens a route")
	# Only promise to sever a route if there's actually a live one to sever — otherwise
	# the effect is a no-op and the label was a lie (early game has no open routes).
	if trade.has("disrupt_route"):
		if TradeManager.is_open(String(trade["disrupt_route"])):
			parts.append("severs a route")
	elif trade.has("disrupt") and _has_live_route():
		parts.append("severs a route")
	if String(choice.get("found_institution", "")) != "":
		parts.append("founds a work")
	# Why is this cheaper or costlier? Name the trait that bent the price.
	var shift: int = EventEngine.cost_shift(choice)
	if shift != 0:
		var axis: String = _dominant_scaled_axis(choice)
		var pole: String = ""
		if axis != "" and SuccessionScreen.POLES.has(axis):
			var v: int = int(GameState.ruler.sliders.get(axis, 0))
			pole = String((SuccessionScreen.POLES[axis] as Array)[1 if v > 0 else 0])
		if shift < 0:
			parts.append("↓cheaper (%s)" % pole if pole != "" else "↓cheaper, in character")
		else:
			parts.append("↑costlier (%s)" % pole if pole != "" else "↑costlier, against type")
	return "   ".join(parts)

# Is there an open, working route a "disrupt" could actually sever right now?
func _has_live_route() -> bool:
	for r in TradeManager.open_routes():
		if int((r as Dictionary).get("disrupted", 0)) <= 0:
			return true
	return false

# Which trait axis most drives this choice's price shift (for the note).
func _dominant_scaled_axis(choice: Dictionary) -> String:
	if GameState.ruler == null:
		return ""
	var dirs: Dictionary = {}
	for a in (choice.get("traits", {}) as Dictionary).keys():
		dirs[a] = signi(int(choice["traits"][a]))
	for a in (choice.get("scaled_by", {}) as Dictionary).keys():
		dirs[a] = signi(int(choice["scaled_by"][a]))
	var best: String = ""
	var best_mag: int = 0
	for a in dirs.keys():
		if GameState.ruler.sliders.has(a):
			var contrib: int = absi(int(dirs[a]) * int(GameState.ruler.sliders[a]))
			if contrib > best_mag:
				best_mag = contrib
				best = String(a)
	return best

# Why is this option AVAILABLE when it's gated? Name the skill/advisor/trait that
# earned it, so the council and the ruler's aptitudes feel used, not abstract.
func _unlock_note(choice: Dictionary) -> String:
	var req: Dictionary = choice.get("requires", {}) as Dictionary
	if req.has("advisor"):
		return "via " + String(ContentDB.advisor_by_id(String(req["advisor"])).get("name", req["advisor"]))
	if req.has("skill"):
		return "%s %d" % [String(req["skill"]).capitalize(), int(req.get("min", 1))]
	if req.has("military"):
		return "your army"
	if req.has("slider"):
		var poles: Array = SuccessionScreen.POLES.get(String(req["slider"]), ["", ""]) as Array
		if req.has("min"):
			return String(poles[1])
		if req.has("max"):
			return String(poles[0])
	return ""

# Why is this option unavailable? Name the single missing requirement.
func _lock_reason(choice: Dictionary) -> String:
	var req: Dictionary = choice.get("requires", {}) as Dictionary
	if req.has("advisor"):
		return "needs " + String(ContentDB.advisor_by_id(String(req["advisor"])).get("name", req["advisor"]))
	if req.has("skill"):
		return "needs %s %d" % [String(req["skill"]).capitalize(), int(req.get("min", 1))]
	if req.has("military"):
		return "needs a standing army"
	if req.has("slider"):
		var axis: String = String(req["slider"])
		var poles: Array = SuccessionScreen.POLES.get(axis, ["", ""]) as Array
		if req.has("min"):
			return "needs " + String(poles[1])
		if req.has("max"):
			return "needs " + String(poles[0])
	if req.has("treasury_min"):
		return "needs %d coin" % int(req["treasury_min"])
	if req.has("not_founded"):
		return "already built"
	if req.has("flag"):
		return "needs an earlier choice"
	return "locked"

func _on_choice_pressed(choice: Dictionary) -> void:
	choice_made.emit(choice)

# Woodcut plate: prefer a category-specific plate, fall back to the default, hide if
# no art is installed yet. (Drop files into res://ui/art/ — see fetch-art.ps1.)
func _set_illustration(category: String) -> void:
	for path in ["res://ui/art/%s.png" % category, "res://ui/art/%s.jpg" % category, "res://ui/art/default.png", "res://ui/art/default.jpg"]:
		if ResourceLoader.exists(path):
			illustration.texture = load(path)
			illustration.visible = true
			return
	illustration.visible = false
