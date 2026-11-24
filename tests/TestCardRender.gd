# Headless render check for the EventCard UI (CR presentation). Verifies that the
# scroll-wrapped card actually instantiates, resolves its @onready nodes, and renders
# every option button for a four-choice event (the Bandit Champion, whose 4th option
# used to fall off-screen). Also spot-checks the readable-icon preview.
extends Node

func _ready() -> void:
	var founder := Ruler.new()
	founder.skills["martial"] = 1
	GameState.new_game(founder)          # gives us a ruler, meters, trade routes, etc.
	DoomManager.start("steppe_horde")     # so prep/doom previews have context

	var card: EventCard = load("res://ui/EventCard.tscn").instantiate()
	add_child(card)                       # resolves @onready $Scroll/VBox/... paths

	var ev: Dictionary = ContentDB.event_by_id("the_bandit_champion")
	card.show_event(ev, "random")

	var buttons: int = card.choices_box.get_child_count()
	var title_ok: bool = card.title_label.text == String(ev.get("title", ""))
	var expected: int = (ev.get("choices", []) as Array).size()
	# Confirm the readable-preview path runs without error and produces text on button 0.
	var first_btn: Button = card.choices_box.get_child(0) as Button
	var preview_ok: bool = first_btn != null and first_btn.text.length() > 0

	var ok: bool = (buttons == expected) and title_ok and preview_ok
	print("[TEST] CARD RENDER %s — %d/%d option buttons, title=%s, preview=%s" % [
		"PASS" if ok else "FAIL", buttons, expected, title_ok, preview_ok])
	get_tree().quit()
