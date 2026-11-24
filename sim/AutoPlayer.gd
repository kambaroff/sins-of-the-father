# A scripted player with a personality (CR-16 harness). The Saint shelters the
# steppe refugees and survives via the nomad pact; the Tyrant seizes their wealth
# and buys the horde off with tribute (or a host). Both must be *viable*, not identical.
class_name AutoPlayer
extends RefCounted

var style: String = "balanced"   # "balanced" | "saint" | "tyrant"

func _init(style_id: String = "balanced") -> void:
	style = style_id

# Pick a choice from the available list, by style-weighted score.
func choose(choices: Array) -> Dictionary:
	var best: Dictionary = choices[0]
	var best_score: int = -9999
	for c in choices:
		var choice: Dictionary = c as Dictionary
		var score: int = _score(choice)
		if score > best_score:
			best_score = score
			best = choice
	return best

func _score(choice: Dictionary) -> int:
	var e: Dictionary = EventEngine.modified_effects(choice)   # score the real (trait-adjusted) cost
	var t: Dictionary = choice.get("traits", {}) as Dictionary
	var treasury: int = int(e.get("treasury", 0))
	var unrest: int = int(e.get("unrest", 0))
	var faith: int = int(e.get("faith", 0))
	var kindness: int = int(t.get("temperament", 0)) + int(t.get("purse", 0))
	# Cap-awareness: gains past the clamp are worthless — never pay coin for
	# faith the altar can't hold (the eternal-tithing bankruptcy).
	if int(GameState.meters.faith) >= 9 and faith > 0:
		faith = 0
	if int(GameState.meters.treasury) >= 10 and treasury > 0:
		treasury = 0
	if int(GameState.meters.unrest) <= 1 and unrest < 0:
		unrest = 0
	# All styles share the solvent core (treasury x2 — upkeep is the metronome;
	# this exact profile survives to Reckonings). Personality is flavor on top.
	var score: int = treasury * 2 + faith - unrest
	match style:
		"saint":
			score += faith + kindness            # mercy as tiebreak, not martyrdom
		"tyrant":
			score += treasury - kindness - unrest  # squeeze harder, crush dissent
	# Emergency floors apply to everyone: protect whichever meter is dying. Faith
	# gets a wider, harder floor — it is the slow-bleed axis (a tyrant can be rich
	# and calm yet still be deposed at faith 0), so defend it earlier and stronger.
	if int(GameState.meters.treasury) < 3:
		score += treasury * 3
	if int(GameState.meters.faith) < 4:
		score += faith * 5
	if int(GameState.meters.unrest) > 7:
		score -= unrest * 3
	# Value prep by its effectiveness against THIS doom — walls are worthless vs the
	# horde (weight 0), the nomad pact decisive (weight 3). Lets the exploit path
	# (windfall -> tribute/host) score as a real survival route, not a dead end.
	var prep: Dictionary = choice.get("prep", {}) as Dictionary
	if not prep.is_empty():
		var weights: Dictionary = DoomManager.doom.get("prep_weights", {}) as Dictionary
		for kind in prep.keys():
			score += int(prep[kind]) * int(weights.get(kind, 1)) * 2
	# Foresight: a festering reign-threat costs far more later (a crisis that scars
	# the Doom) than addressing it now. A competent ruler pays to resolve the trial
	# rather than let it escalate. The "negligent" probe style inverts this to force
	# the escalation path for testing (see TestThreats).
	for f in (choice.get("flags", []) as Array):
		if String((f as Dictionary).get("id", "")).begins_with("threat_"):
			score += (4 if style == "negligent" else -4)
	# Trade foresight: a chartered route pays its income every year for the rest of
	# the line — worth far more than its one-time cost. And don't willingly sever a
	# working route (an embargo you could have rerouted around instead).
	var trade: Dictionary = choice.get("trade", {}) as Dictionary
	if trade.has("open"):
		score += int(TradeManager.route_by_id(String(trade["open"])).get("income", 2)) * 4
	if trade.has("disrupt") and not TradeManager.open_routes().is_empty():
		score -= 6
	# Legacy foresight: a standing institution is a permanent passive for the rest of
	# the line (and every line after) — well worth its one-time cost when coin allows.
	if String(choice.get("found_institution", "")) != "":
		score += 14
	return score

# Yearly surplus investment: what this personality builds against the Doom.
func prep_kind() -> String:
	match style:
		"saint":
			return "tribute"      # pay the danger to go away; alms as armor
		"tyrant":
			return "host"
	return "host"

# Winter investment, decided BEFORE upkeep: how many prep points (2 coin each)
# can we buy and still cover the year's bill? (Treasury caps at 10 and upkeep is
# 6-8, so post-upkeep surplus can never fund prep — it must be spent pre-upkeep.)
func invest_budget() -> int:
	var upkeep: int = 1 + GameState.MIL_COST[GameState.military_level] + Council.total_upkeep()
	var spare: int = int(GameState.meters.treasury) - upkeep - 2   # keep 2 coin alive after the bill
	return clampi(floori(spare / 2.0), 0, 2)

# How this personality raises the heir (first affordable wins).
func upbringing_prefs() -> Array[String]:
	match style:
		"saint":
			return ["abbey", "scholars", "court_indulged"]
		"tyrant":
			return ["war_camp", "spymaster_ward", "court_indulged"]
	return ["war_camp", "abbey", "court_indulged"]

# Deathbed lesson: pass the strongest slider whole — what they lived is what they teach.
func lesson_axis(parent: Ruler) -> String:
	var best_axis: String = ""
	var best_mag: int = 0
	for k in parent.sliders.keys():
		var mag: int = absi(int(parent.sliders[k]))
		if mag > best_mag:
			best_mag = mag
			best_axis = String(k)
	return best_axis

# Military policy at year turn: tyrant escalates when rich; saint stays lean.
func adjust_military() -> void:
	var t: int = int(GameState.meters.treasury)
	match style:
		"tyrant":
			if t >= 8 and GameState.military_level < 2:
				GameState.military_level = 2
		"saint":
			if GameState.military_level > 1:
				GameState.military_level = 1
