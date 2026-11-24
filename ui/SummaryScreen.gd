# THE SAGA — the shareable dynasty summary, shown at any end (milestone 9, P5).
# "Look what my bloodline became": reigns, defining trait, dooms faced, greatest sin.
extends Control
class_name SummaryScreen

signal continue_pressed

const POLE_NAMES: Dictionary = {
	"temperament": ["CRUEL", "GENEROUS"],
	"purse": ["GREEDY", "CHARITABLE"],
	"bearing": ["PROUD", "HUMBLE"],
	"trust": ["PARANOID", "TRUSTING"],
	"faith": ["ZEALOUS", "WORLDLY"],
	"vengefulness": ["VENGEFUL", "FORGIVING"],
	"temperance": ["HEDONIST", "ASCETIC"],
	"valor": ["CRAVEN", "BRAVE"],
	"wrath": ["WRATHFUL", "CALM"],
	"appetite": ["LUSTFUL", "CHASTE"],
}

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var body_label: Label = $Panel/VBox/BodyLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())

func open(cause: String) -> void:
	title_label.text = "THE SAGA OF THE HOUSE — %d reign%s · %d years" % [
		GameState.generation, "" if GameState.generation == 1 else "s", GameState.year]
	var lines: Array[String] = []
	lines.append("▸ The line ends in: %s" % cause.to_upper())
	lines.append("▸ Defining trait: %s" % _defining_trait())
	for outcome in _reckonings():
		lines.append("▸ %s" % outcome)
	var sin := _greatest_sin()
	if sin != "":
		lines.append("▸ Greatest sin: %s" % sin)
	lines.append("▸ Ancestral sins carried: +%d severity" % Chronicle.doom_severity_bonus())
	var works: Array = InstitutionManager.standing()
	if not works.is_empty():
		var names: Array[String] = []
		for id in works:
			names.append(InstitutionManager.name_of(String(id)))
		lines.append("▸ Works that will outlast the line: %s" % ", ".join(names))
	# Bank this dynasty's triumphs to disk — the next line inherits them (meta-progression).
	Legacy.record_dynasty(GameState.generation, GameState.reckonings_survived, true)
	lines.append("▸ Your successors will start with a Founder's Boon of +%d coin." % Legacy.founder_boon_treasury())
	body_label.text = "\n".join(lines)
	show()

func _defining_trait() -> String:
	var best_axis: String = ""
	var best_v: int = 0
	for k in GameState.ruler.sliders.keys():
		var v: int = int(GameState.ruler.sliders[k])
		if absi(v) > absi(best_v):
			best_v = v
			best_axis = String(k)
	if best_axis == "":
		return "unremarkable (history forgets the mild)"
	var pole: String = String((POLE_NAMES[best_axis] as Array)[0 if best_v < 0 else 1])
	return "%s %s" % [pole, "◆".repeat(absi(best_v))]

func _reckonings() -> Array[String]:
	var out: Array[String] = []
	for e in Chronicle.entries:
		var entry: Dictionary = e as Dictionary
		var consequence: String = String(entry.get("consequence", ""))
		if consequence.begins_with("reckoning: "):
			var band: String = consequence.trim_prefix("reckoning: ")
			var verb: String = "Survived" if band == "SURVIVE" else ("Weathered, barely" if band == "BATTERED" else "Fell to")
			out.append("%s: %s" % [verb, String(entry.get("act", "?")).trim_prefix("faced ")])
	return out

func _greatest_sin() -> String:
	var best: Dictionary = {}
	var best_mod: int = 0
	for e in Chronicle.entries:
		var entry: Dictionary = e as Dictionary
		if int(entry.get("doom_mod", 0)) > best_mod:
			best_mod = int(entry.get("doom_mod", 0))
			best = entry
	if best.is_empty():
		return ""
	return "%s — \"%s\" (Doom +%d)" % [String(best.get("ruler", "?")), String(best.get("act", "?")), best_mod]
