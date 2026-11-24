# 📜 The Chronicle of Sins — the readable ledger (CR-15, CR-21).
# Answers "why is our Doom this bad?" with receipts: every doom-feeding act, every
# lifecycle beat, and every live ⏳ flag with its countdown. Never hidden math.
extends Control
class_name ChronicleScreen

signal closed

# Lifecycle consequences always shown even with doom_mod 0.
const LIFECYCLE: Array[String] = ["succession", "founding", "defection", "grudge"]

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var math_label: Label = $Panel/VBox/MathLabel
@onready var rows_box: VBoxContainer = $Panel/VBox/Scroll/Rows
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)
	if visible:   # instantiated visible (no hide->show edge): refresh now
		_refresh()

func _on_visibility_changed() -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	title_label.text = "📜 CHRONICLE OF THE HOUSE OF %s — generation %d, era %d" % [
		GameState.house.to_upper(), GameState.generation, GameState.era]
	var bonus: int = Chronicle.doom_severity_bonus()
	math_label.text = "%s: base severity %d + ancestral sins %d = %d   vs   preparation %d" % [
		String(DoomManager.doom.get("title", "no doom")),
		int(DoomManager.doom.get("base", 0)), bonus, DoomManager.severity(), DoomManager.readiness()]
	for child in rows_box.get_children():
		rows_box.remove_child(child)
		child.queue_free()
	# The reign's real story: every consequential act, grouped under the ruler who made
	# it. Pure-flavour picks (no effect at all) are the only thing left out.
	var shown: int = 0
	var last_ruler: String = ""
	for e in Chronicle.entries:
		var entry: Dictionary = e as Dictionary
		var mod: int = int(entry.get("doom_mod", 0))
		var consequence: String = String(entry.get("consequence", ""))
		if mod == 0 and not _is_lifecycle(consequence) and not bool(entry.get("notable", false)):
			continue
		var ruler_name: String = String(entry.get("ruler", "?"))
		if ruler_name != last_ruler:
			_add_header("— %s —" % ruler_name)
			last_ruler = ruler_name
		_add_row(_entry_text(entry, mod, consequence))
		shown += 1
	if shown == 0:
		_add_row("The parchment is clean. It will not stay that way.")
	for f in Chronicle.flag_queue:
		var flag: Dictionary = f as Dictionary
		var in_hands: int = int(flag.get("fire_at_hand", 0)) - GameState.hand_counter
		_add_row("⏳ LIVE: \"%s\" — resolves in %d hand%s" % [String(flag.get("id", "?")), maxi(in_hands, 0), "" if in_hands == 1 else "s"])

func _entry_text(entry: Dictionary, mod: int, consequence: String) -> String:
	# Ruler is now shown as a group header, so each line is just the act and its upshot.
	var line: String = "  • %s" % String(entry.get("act", "?"))
	if mod > 0:
		line += "   → Doom +%d ⚠" % mod
	elif consequence.begins_with("reckoning"):
		line += "   → %s" % consequence.trim_prefix("reckoning: ")
	elif consequence != "":
		line += "   → %s" % _pretty_consequence(consequence)
	return line

# Turn lifecycle code-words into readable upshots; ordinary acts already store the
# choice's own wording as the consequence, so those pass through untouched.
func _pretty_consequence(consequence: String) -> String:
	match consequence:
		"founding": return "the house is founded"
		"succession": return "the crown passes"
		"defection": return "a minister turns traitor"
		"grudge": return "a grudge is sown"
	return consequence

func _add_header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.5, 0.38, 0.12))
	rows_box.add_child(l)

func _is_lifecycle(consequence: String) -> bool:
	if consequence.begins_with("reckoning"):
		return true
	return LIFECYCLE.has(consequence)

func _add_row(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows_box.add_child(l)

func _on_back_pressed() -> void:
	hide()
	closed.emit()
