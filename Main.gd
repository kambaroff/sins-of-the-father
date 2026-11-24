# Headless driver: auto-plays a dynasty and prints the whole loop to the Output console.
# This proves the engine end-to-end BEFORE any UI exists. Replace with a real UI scene later.
extends Node

const UPBRINGING_HAND := 4   # reign-hand at which the auto-player invests in the heir

var player: AutoPlayer

func _ready() -> void:
	randomize()
	GameState.log_line.connect(func(t): print("      ", t))

	var style: String = "balanced"
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--style="):
			style = String(arg).trim_prefix("--style=")
	player = AutoPlayer.new(style)

	var founder := Ruler.new()
	founder.name = "Béla I"
	founder.skills["martial"] = 2
	GameState.new_game(founder)
	DoomManager.start("steppe_horde")

	print("\n========  SINS OF THE FATHER — engine test  ========")
	print("Style: %s  |  Founder: %s  |  Doom: %s\n" % [style, founder.describe(), DoomManager.doom.get("title", "?")])
	_run()

func _run() -> void:
	var reign_hands := 0
	while true:
		var hand := EventEngine.deal_hand()
		print("[%s Y%d · hand %d]" % [GameState.season(), GameState.year, GameState.hand_counter])
		for ev in hand:
			var choices: Array = ev.get("choices", [])
			var available: Array = []
			for c in choices:
				if EventEngine.choice_available(c as Dictionary):
					available.append(c)
			if available.is_empty():
				continue
			var pick := player.choose(available)
			EventEngine.resolve(ev, pick)
			print("   %-26s -> %s" % [ev.get("title", "?"), pick.get("text", "")])
		var m = GameState.meters
		print("   [ T%d  U%d  F%d ]   doom %d/10\n" % [m.treasury, m.unrest, m.faith, DoomManager.doom.get("track", 0)])

		if GameState.season_idx == 3:   # winter: invest before upkeep drains the surplus
			_maybe_prepare()

		GameState.advance()

		var lose := GameState.check_lose()
		if lose != "":
			print(">>> The reign of %s ends in %s.\n" % [GameState.ruler.name, lose.to_upper()])
			break

		if GameState.season_idx == 0:               # a new year turned
			DoomManager.tick()
			player.adjust_military()

		if DoomManager.arrived():
			if _reckoning() == "PUPPET / END":
				break
			continue   # survived: era escalates behind the breather (CR-18)

		if GameState.hand_counter >= 120:   # safety: no infinite dynasties in CI
			print(">>> The chronicler's hand cramps. Ending the test at hand %d." % GameState.hand_counter)
			break

		if GameState.reign_hands == UPBRINGING_HAND:
			_maybe_raise_heir()

		if GameState.ruler_should_die():
			_succeed()

	get_tree().quit()   # clean exit so `godot --headless` terminates (for /playtest)

# Winter: spend what the coming upkeep can spare on the Doom (persists to heirs).
func _maybe_prepare() -> void:
	var n := player.invest_budget()
	if n > 0:
		GameState.apply({"treasury": -2 * n})
		var kind := player.prep_kind()
		DoomManager.add_prep(kind, n)
		GameState.log_line.emit("Invested in the %s (prep +%d)" % [kind, n])

func _maybe_raise_heir() -> void:
	for id in player.upbringing_prefs():
		if Succession.choose_upbringing(id):
			return

func _succeed() -> void:
	var parent: Ruler = GameState.ruler
	var axis := player.lesson_axis(parent)
	var heir: Ruler = Succession.succeed(axis)
	print("======  %s dies (lesson: %s). %s takes the throne.  ======" % [parent.name, axis if axis != "" else "none", heir.name])
	print("        heir: %s  upbringing: %s\n" % [heir.describe(), heir.upbringing if heir.upbringing != "" else "none"])

func _reckoning() -> String:
	var rd := DoomManager.readiness()
	var sev := DoomManager.severity()
	print("############  THE RECKONING — %s  ############" % DoomManager.doom.get("title", "?"))
	print("   readiness %d  vs  severity %d   (ancestral sins +%d)" % [rd, sev, Chronicle.doom_severity_bonus()])
	var outcome := DoomManager.resolve_reckoning()
	print("   OUTCOME: %s" % outcome)
	if outcome != "PUPPET / END":
		print("   era %d begins: %s (breather %d yr)\n" % [GameState.era, DoomManager.doom.get("title", "?"), DoomManager.breather_years])
		return outcome
	print("\n--- Chronicle of Sins ---")
	for e in Chronicle.entries:
		if int(e.get("doom_mod", 0)) != 0:
			print("   %s: %s  (Doom +%d)" % [e.ruler, e.act, e.doom_mod])
	print("\n========  END OF TEST  ========")
	return outcome
