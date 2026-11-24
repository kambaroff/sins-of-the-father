# CR-15/CR-21 verification, headless:
#   godot --headless --path . tests/TestChronicle.tscn
# The Chronicle screen shows every doom-feeding act with its +N, lifecycle beats,
# and live flags with countdowns — and hides the noise. Never hidden math.
extends Node

func _ready() -> void:
	var founder := Ruler.new()
	founder.name = "Founder"
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")

	Chronicle.record("Founder", "insulted the steppe envoy", "grudge", 2)
	Chronicle.record("Founder", "taxed beards and windows", "")           # noise: no mod
	Chronicle.record("Founder", "died; the crown passes to Géza I", "succession", 0)
	Chronicle.schedule({"id": "khans_grudge", "event_id": "steppe_envoy", "fire_at_hand": GameState.hand_counter + 5})

	var screen: ChronicleScreen = (load("res://ui/ChronicleScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	screen.show()   # triggers refresh via visibility_changed

	var texts: Array[String] = []
	for row in screen.rows_box.get_children():
		texts.append((row as Label).text)
	print("[TEST] rows:")
	for t in texts:
		print("   ", t)

	assert(_any(texts, "insulted the steppe envoy") and _any(texts, "Doom +2 ⚠"), "sin shown with its price")
	assert(not _any(texts, "taxed beards"), "zero-mod noise hidden")
	assert(_any(texts, "crown passes"), "lifecycle beats shown")
	assert(_any(texts, "khans_grudge") and _any(texts, "5 hands"), "live flag with countdown")
	assert(screen.math_label.text.contains("6 + ancestral sins 2 = 8"), "severity math legible: " + screen.math_label.text)

	# EventCard telegraphs flags (CR-21): a choice carrying flags gets the hourglass.
	var card: EventCard = (load("res://ui/EventCard.tscn") as PackedScene).instantiate()
	add_child(card)
	card.show_event({
		"title": "T", "body": "B", "category": "war",
		"choices": [
			{"text": "Risky", "effects": {}, "flags": [{"id": "later", "event_id": "x", "in_hands": 3}]},
			{"text": "Safe", "effects": {}},
		],
	}, "plot")
	var risky: Button = card.choices_box.get_child(0) as Button
	var safe: Button = card.choices_box.get_child(1) as Button
	assert(risky.text.contains("⏳"), "flagged choice telegraphed")
	assert(not safe.text.contains("⏳"), "safe choice unmarked")
	print("[TEST] EventCard: ⏳ on flagged choice only")

	print("[TEST] CR-15/CR-21 PASS — the Chronicle is readable, consequences telegraphed")
	get_tree().quit()

func _any(texts: Array[String], needle: String) -> bool:
	for t in texts:
		if t.contains(needle):
			return true
	return false
