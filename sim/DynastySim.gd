# Quiet, seeded dynasty simulation for balance harnesses (CR-16).
# Runs one full dynasty with an AutoPlayer personality and returns a summary dict.
# Main.tscn stays the verbose flavor driver; this one is for matrices.
class_name DynastySim
extends RefCounted

const UPBRINGING_HAND := 4
const MAX_HANDS := 120

# Returns {outcomes: Array[String], end: String, generations: int, years: int,
#          prep: Dictionary, sliders: Dictionary, sins: int}
static func run(style: String, doom_id: String, rng_seed: int, carry_legacy: bool = false) -> Dictionary:
	seed(rng_seed)
	if not carry_legacy:
		Legacy.reset()   # isolate balance sims — each run starts from a clean history
	var player := AutoPlayer.new(style)
	var founder := Ruler.new()
	founder.name = "Founder"
	founder.skills["martial"] = 1
	GameState.new_game(founder)
	DoomManager.start(doom_id)
	Succession.apply_upbringing(founder, player.upbringing_prefs()[0])
	if founder.origin_advisor != "" and not Council.is_seated(founder.origin_advisor):
		Council.hire(founder.origin_advisor)

	var outcomes: Array[String] = []
	var end_cause: String = ""
	while true:
		var hand: Array = EventEngine.deal_hand()
		for ev in hand:
			var available: Array = []
			for c in (ev.get("choices", []) as Array):
				if EventEngine.choice_available(c as Dictionary):
					available.append(c)
			if available.is_empty():
				continue
			EventEngine.resolve(ev, player.choose(available))

		# Winter: spend the autumn surplus on the Doom before upkeep drains it.
		if GameState.season_idx == 3:
			var n: int = player.invest_budget()
			if n > 0:
				GameState.apply({"treasury": -2 * n})
				DoomManager.add_prep(player.prep_kind(), n)

		GameState.advance()

		end_cause = GameState.check_lose()
		if end_cause != "":
			break

		if GameState.season_idx == 0:
			DoomManager.tick()
			player.adjust_military()

		if DoomManager.arrived():
			var outcome := DoomManager.resolve_reckoning()
			outcomes.append(outcome)
			if outcome == "PUPPET / END":
				end_cause = "the reckoning"
				break
			continue

		if GameState.hand_counter >= MAX_HANDS:
			end_cause = "retired"
			break

		if GameState.reign_hands == UPBRINGING_HAND:
			for id in player.upbringing_prefs():
				if Succession.choose_upbringing(id):
					break

		if GameState.ruler_should_die():
			Succession.succeed(player.lesson_axis(GameState.ruler))

	# Bank this dynasty's achievements so a carrying successor can inherit them
	# (persist=false: sims must never write to the player's real legacy save).
	Legacy.record_dynasty(GameState.generation, GameState.reckonings_survived, false)
	return {
		"outcomes": outcomes,
		"end": end_cause,
		"generations": GameState.generation,
		"years": GameState.year,
		"prep": (DoomManager.doom.get("prep", {}) as Dictionary).duplicate(),
		"sliders": GameState.ruler.sliders.duplicate(),
		"sins": Chronicle.doom_severity_bonus(),
		"trade_open": TradeManager.open_routes().size(),
		"trade_income": TradeManager.trade_income(),
		"institutions": InstitutionManager.standing().size(),
		"legacy_reckonings": Legacy.total_reckonings,
		"boon": Legacy.founder_boon_treasury(),
	}
