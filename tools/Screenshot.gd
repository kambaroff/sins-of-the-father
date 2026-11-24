# Dev tool: boot a screen/state, capture the viewport to a PNG, quit.
# Run WITH rendering (NOT --headless):
#   godot --path . res://tools/Screenshot.tscn -- <mode>
# mode ∈ succession | council | chronicle | summary | coronation | faith  (default succession)
extends Node

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = String(args[0]) if args.size() > 0 else "succession"
	# Window size: default 980x780. Pass "compact" for a small cheap render, or an
	# explicit "WIDTHxHEIGHT" (e.g. 1920x1080) to verify resolution adaptability.
	var win: Vector2i = Vector2i(980, 780)
	for a in args.slice(1):
		var s: String = String(a)
		if s == "compact":
			win = Vector2i(640, 512)
		elif "x" in s:
			var p: PackedStringArray = s.split("x")
			if p.size() == 2 and p[0].is_valid_int() and p[1].is_valid_int():
				win = Vector2i(int(p[0]), int(p[1]))
	get_window().size = win
	var reign: Control = load("res://ui/ReignScreen.tscn").instantiate()
	add_child(reign)
	await get_tree().process_frame
	await get_tree().process_frame
	_setup(reign, mode)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "res://_shot_%s.png" % mode
	img.save_png(path)
	print("[Screenshot] saved ", path)
	# Dev captures must never leave a real legacy save behind (some modes end a
	# dynasty and would otherwise persist demo institutions to disk).
	Legacy.reset()
	Legacy.save_to_disk()
	get_tree().quit()

func _start_game() -> void:
	var founder := Ruler.new()
	founder.name = "Béla I"
	founder.skills["martial"] = 1
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")

func _setup(reign: Control, mode: String) -> void:
	if mode != "succession":
		reign.succession_screen.hide()
	match mode:
		"succession":
			var king := Ruler.new()
			king.name = "Casimir I"
			king.sliders["temperament"] = -2
			king.sliders["purse"] = -1
			king.sliders["vengefulness"] = -2
			king.skills["martial"] = 2
			reign.succession_screen.open_for_succession(king)
		"council":
			_start_game()
			Council.promote("marshal")     # show a leveled seat
			GameState.set_military(2)       # and a standing army
			reign.council_screen.show()
		"chronicle":
			_start_game()
			Chronicle.record("Béla I", "insulted the steppe envoy", "doom", 2)
			Chronicle.record("Béla I", "began the great walls", "prep +3", 0)
			Chronicle.record("Ilona I", "snubbed the tithe", "faith debt", 0)
			Chronicle.schedule({"id": "the khan's grudge", "event_id": "x", "fire_at_hand": 12})
			reign.chronicle_screen.show()
		"summary":
			_start_game()
			Chronicle.record("Béla I", "insulted the steppe envoy", "doom", 2)
			reign.summary_screen.open("revolt")
		"coronation":
			_start_game()
			reign._deal_opening()
		"faith":
			_start_game()
			GameState.apply({"faith": 10})
			reign._deal_next_hand()
		"threat":
			_start_game()
			ThreatManager.active = {"id": "border_raid", "title": "Raiders at the Marches"}
			reign._refresh_threat()
			reign.card.show_event(ContentDB.event_by_id("raid_opening"), "threat")
		"trade":
			_start_game()
			TradeManager.open_route("river_road")
			reign._refresh_trade()
			reign.card.show_event(ContentDB.event_by_id("silk_road_offer"), "seasonal")
		"meta":
			_start_game()
			GameState.apply({"treasury": 5})   # a wealthy reign can afford a lasting work
			# Show the University founding OFFER with nothing built yet, so the card and
			# the (empty) standing-works label can't read as a mismatch.
			reign._refresh_legacy()
			reign.card.show_event(ContentDB.event_by_id("found_university"), "seasonal")
		"character":
			_start_game()
			GameState.ruler.name = "Béla I"
			GameState.ruler.sliders["temperament"] = -3   # maxed cruel -> dramatic trait-cost swing
			GameState.ruler.sliders["valor"] = 1           # brave
			GameState.ruler.sliders["wrath"] = -1          # wrathful
			GameState.ruler.skills["martial"] = 2
			GameState.ruler.skills["learning"] = 1
			reign._refresh_character()
			reign.card.show_event(ContentDB.event_by_id("the_lepers_at_the_gate"), "random")
		"saga":
			# The end-of-dynasty payoff: a storied line that founded works and beat
			# Reckonings, and the Founder's Boon its successors will inherit.
			_start_game()
			Legacy.reset()
			Legacy.total_reckonings = 6
			GameState.generation = 6
			GameState.year = 84
			GameState.reckonings_survived = 3
			GameState.ruler.name = "András III"
			GameState.ruler.sliders["temperament"] = -2
			GameState.ruler.sliders["vengefulness"] = -2
			InstitutionManager.found("royal_mint")
			InstitutionManager.found("university")
			Chronicle.record("Géza I", "faced The Steppe Horde", "reckoning: SURVIVE", 0)
			Chronicle.record("László II", "faced The Black Death", "reckoning: BATTERED", 0)
			Chronicle.record("András III", "sold the steppe refugees to slavers", "doom", 2)
			reign.summary_screen.open("the reckoning")
		_:
			pass
