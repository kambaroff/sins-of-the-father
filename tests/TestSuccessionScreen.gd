# Drives the SuccessionScreen headlessly (CR-24):
#   godot --headless --path . tests/TestSuccessionScreen.tscn
# Founder mode: open -> take throne -> game starts with origin applied.
# Succession mode: open for a dying ruler -> pick a lesson -> take throne -> heir installed.
extends Node

func _ready() -> void:
	var screen: SuccessionScreen = (load("res://ui/SuccessionScreen.tscn") as PackedScene).instantiate()
	add_child(screen)

	# --- founder mode ---
	screen.open_for_founder()
	assert(screen.visible, "screen shows on open")
	assert(screen.origin_box.get_child_count() >= 6, "founder sees every upbringing")
	screen.take_button.pressed.emit()
	assert(GameState.ruler != null and GameState.ruler.name != "", "founder installed")
	assert(GameState.ruler.origin_advisor != "", "founder origin advisor set (default pick)")
	assert(Council.is_seated(GameState.ruler.origin_advisor), "origin advisor seated")
	assert(not DoomManager.doom.is_empty(), "doom started")
	print("[TEST] founder mode: %s takes the throne, %s seated" % [GameState.ruler.name, GameState.ruler.origin_advisor])

	# --- succession mode, upbringing already invested during the reign ---
	var parent: Ruler = GameState.ruler
	parent.sliders["vengefulness"] = -3
	GameState.meters["treasury"] = 6
	assert(Succession.choose_upbringing("scholars"), "invest in the heir mid-reign")
	var gen: int = GameState.generation
	screen.open_for_succession(parent)
	assert(screen.visible, "screen shows on death")
	assert(screen.origin_box.get_child_count() == 0, "upbringing locked — no origin choices")
	assert(screen.lesson_box.get_child_count() >= 2, "lesson options offered for a vengeful parent")
	screen._lesson_axis = "vengefulness"   # simulate picking the grudge lesson
	screen.take_button.pressed.emit()
	assert(GameState.generation == gen + 1, "heir installed")
	assert(int(GameState.ruler.sliders["vengefulness"]) == -3, "lesson passed the grudge whole")
	assert(GameState.ruler.upbringing == "scholars", "invested upbringing applied")
	print("[TEST] succession mode: %s inherits the grudge (v=-3), raised by %s" % [GameState.ruler.name, GameState.ruler.upbringing])

	print("[TEST] CR-24 PASS — SuccessionScreen drives both flows")
	get_tree().quit()
