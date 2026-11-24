# Deals the three-card season hand and applies a chosen option.
extends Node

var _seen_this_reign: Dictionary = {}   # event ids already dealt this reign (no repeats)
var _recent: Array[String] = []         # last few event ids — never repeated back-to-back
var _plot_is_consequence: bool = false  # did this hand's plot card come from the flag queue?
const RECENT_CAP := 6

# A fresh reign clears the "already seen" set, so a new ruler can meet any event.
func new_reign() -> void:
	_seen_this_reign.clear()
	_recent.clear()

# Returns the season's three cards. A fired consequence (or reign-threat) leads the
# hand so cause-and-effect reads in order; otherwise the season sets the scene first.
func deal_hand() -> Array:
	var seasonal := _pick("seasonal")
	var plot := _pick_plot()
	var random := _pick("random")
	if _plot_is_consequence:
		return [plot, seasonal, random]
	return [seasonal, plot, random]

func _pick(slot: String) -> Dictionary:
	var ev := _draw(ContentDB.by_slot(slot))
	if ev.is_empty():
		ev = _draw(ContentDB.events)
	return ev

# Plot slot is fed by the consequence queue; falls back to a plot/random draw.
func _pick_plot() -> Dictionary:
	_plot_is_consequence = false
	var due := Chronicle.pop_due(GameState.hand_counter)
	if not due.is_empty():
		# Fire one flag per hand; re-queue the rest so simultaneous
		# consequences (e.g. two betrayals in one unpaid year) aren't lost.
		for i in range(1, due.size()):
			Chronicle.schedule(due[i] as Dictionary)
		var ev := ContentDB.event_by_id(String(due[0].get("event_id", "")))
		if not ev.is_empty():
			_seen_this_reign[String(ev.get("id", ""))] = true   # don't also draw it randomly
			_mark_recent(String(ev.get("id", "")))
			_plot_is_consequence = true
			return ev
	var pool := ContentDB.by_slot("plot")
	if pool.is_empty():
		pool = ContentDB.by_slot("random")
	return _draw(pool)

# Draw a random event from a pool, skipping ones already seen this reign and ones
# whose prerequisites aren't met. If a long reign exhausts the pool, relax the
# no-repeat rule — but never repeat one of the last few cards (that's what let a
# single event, e.g. Your Brother's Ambition, fire three times in one reign).
func _draw(pool: Array) -> Dictionary:
	var fresh: Array = []
	for e in pool:
		var d: Dictionary = e as Dictionary
		if _seen_this_reign.has(String(d.get("id", ""))):
			continue
		if not _event_available(d):
			continue
		fresh.append(d)
	if fresh.is_empty():   # pool exhausted this reign: allow repeats, but not recent ones
		for e in pool:
			var d2: Dictionary = e as Dictionary
			if _recent.has(String(d2.get("id", ""))):
				continue
			if _event_available(d2):
				fresh.append(d2)
	if fresh.is_empty():   # utterly exhausted: anything still valid, recency be damned
		for e in pool:
			if _event_available(e as Dictionary):
				fresh.append(e)
	if fresh.is_empty():
		return {}
	var chosen: Dictionary = fresh.pick_random() as Dictionary
	_seen_this_reign[String(chosen.get("id", ""))] = true
	_mark_recent(String(chosen.get("id", "")))
	return chosen

# Remember the last few cards shown so no event recurs back-to-back, even once the
# reign's pool has been exhausted and repeats are allowed again.
func _mark_recent(id: String) -> void:
	if id == "":
		return
	_recent.append(id)
	while _recent.size() > RECENT_CAP:
		_recent.pop_front()

# Event-level prerequisites: an event can require a seated advisor or a live flag,
# so advisor-flavoured or consequence events never fire out of context.
func _event_available(e: Dictionary) -> bool:
	var req: Dictionary = e.get("requires", {}) as Dictionary
	if req.is_empty():
		return true
	if req.has("advisor") and not Council.is_seated(String(req["advisor"])):
		return false
	if req.has("flag") and not _flag_live(String(req["flag"])):
		return false
	# A founding event vanishes once its work already stands (no re-chartering a
	# University that's already built); "founded" gates the opposite way.
	if req.has("not_founded") and InstitutionManager.has(String(req["not_founded"])):
		return false
	if req.has("founded") and not InstitutionManager.has(String(req["founded"])):
		return false
	return true

func resolve(event: Dictionary, choice: Dictionary) -> void:
	GameState.apply(modified_effects(choice))
	_apply_traits(choice.get("traits", {}))
	_schedule_flags(choice.get("flags", []))
	_apply_loyalty(choice.get("loyalty", {}))
	_apply_prep(choice.get("prep", {}))
	_apply_trade(choice.get("trade", {}))
	_apply_institution(String(choice.get("found_institution", "")))
	Chronicle.record(
		GameState.ruler.name,
		String(event.get("title", "")),
		String(choice.get("text", "")),
		int(choice.get("doom_mod", 0)),
		_is_notable(choice)
	)

# A choice worth writing into the Chronicle: it moved a meter, bent the ruler's
# character, sowed a consequence, prepared for the Doom, or founded a work. Pure
# flavour picks (no effect at all) stay out of the ledger.
func _is_notable(choice: Dictionary) -> bool:
	if int(choice.get("doom_mod", 0)) != 0:
		return true
	if String(choice.get("found_institution", "")) != "":
		return true
	for key in ["effects", "traits", "flags", "prep", "trade", "loyalty"]:
		var v: Variant = choice.get(key, null)
		if v is Dictionary and not (v as Dictionary).is_empty():
			return true
		if v is Array and not (v as Array).is_empty():
			return true
	return false

# --- Trait-cost: an in-character choice is cheaper, an out-of-character one costlier.
# The swing scales with how EXTREME the ruler's relevant trait is — subtle at a lean
# (|slider| 1-2 -> ±1), dramatic near-maxed (|slider| 3 -> ±2). Costs only (downsides),
# across treasury/unrest/faith. Auto-derived from the choice's own trait nudges, plus
# an optional explicit "scaled_by" (same shape as traits) for choices that don't nudge. ---

# How aligned is this choice with who the ruler is? >0 in-character, <0 against.
func cost_alignment(choice: Dictionary) -> int:
	if GameState.ruler == null:
		return 0
	var dirs: Dictionary = {}
	for axis in (choice.get("traits", {}) as Dictionary).keys():
		dirs[axis] = signi(int(choice["traits"][axis]))
	for axis in (choice.get("scaled_by", {}) as Dictionary).keys():
		dirs[axis] = signi(int(choice["scaled_by"][axis]))
	var align: int = 0
	for axis in dirs.keys():
		if GameState.ruler.sliders.has(axis):
			align += int(dirs[axis]) * int(GameState.ruler.sliders[axis])
	return align

# The shift applied to each cost: negative = cheaper (aligned), positive = costlier.
func cost_shift(choice: Dictionary) -> int:
	var a: int = cost_alignment(choice)
	if a == 0:
		return 0
	var amt: int = 2 if absi(a) >= 3 else 1     # dramatic when the trait is near-maxed
	return -amt if a > 0 else amt

# The choice's effects after the trait-cost modifier — previewed AND applied, so what
# the player sees is what they get.
func modified_effects(choice: Dictionary) -> Dictionary:
	var e: Dictionary = (choice.get("effects", {}) as Dictionary).duplicate()
	var shift: int = cost_shift(choice)
	if shift == 0:
		return e
	for meter in ["treasury", "unrest", "faith"]:
		if not e.has(meter):
			continue
		var v: int = int(e[meter])
		var is_cost: bool = (v > 0) if meter == "unrest" else (v < 0)   # the downside side
		if not is_cost:
			continue
		if shift < 0:   # aligned: ease the cost toward zero (never flip into a reward)
			v = maxi(0, v - absi(shift)) if v > 0 else mini(0, v + absi(shift))
		else:            # opposed: deepen the cost
			v = (v + shift) if v > 0 else (v - shift)
		e[meter] = v
	return e

# True if this choice's `requires` gate (advisor/skill/slider/flag) is satisfied.
func choice_available(choice: Dictionary) -> bool:
	var req: Dictionary = choice.get("requires", {}) as Dictionary
	if req.is_empty():
		return true
	if req.has("advisor") and not Council.is_seated(String(req["advisor"])):
		return false
	if req.has("skill"):
		var skill_name: String = String(req["skill"])
		var min_skill: int = int(req.get("min", 0))
		var effective: int = int(GameState.ruler.skills.get(skill_name, 0))
		effective += Council.advisor_skill_bonus(skill_name)   # a leveled advisor lends more
		if effective < min_skill:
			return false
	if req.has("military") and GameState.military_level < int(req["military"]):
		return false
	if req.has("trade_closed") and TradeManager.is_open(String(req["trade_closed"])):
		return false   # a route-opening offer vanishes once that route already runs
	if req.has("treasury_min") and int(GameState.meters.treasury) < int(req["treasury_min"]):
		return false   # only a wealthy realm can fund a lasting work
	if req.has("not_founded") and InstitutionManager.has(String(req["not_founded"])):
		return false   # can't found what already stands
	if req.has("slider"):
		var slider_name: String = String(req["slider"])
		var value: int = int(GameState.ruler.sliders.get(slider_name, 0))
		if req.has("min") and value < int(req["min"]):
			return false
		if req.has("max") and value > int(req["max"]):
			return false
	if req.has("flag") and not _flag_live(String(req["flag"])):
		return false
	return true

func _flag_live(flag_id: String) -> bool:
	for f in Chronicle.flag_queue:
		if String((f as Dictionary).get("id", "")) == flag_id:
			return true
	return false

# Choices can invest in Doom preparation: "prep": {"host": 1} (CR-14 source).
func _apply_prep(prep: Dictionary) -> void:
	for k in prep.keys():
		DoomManager.add_prep(String(k), int(prep[k]))

# Choices can shape the trade network: "trade": {"open": "silk_road"} opens a route;
# "trade": {"disrupt": 2} severs a random working route for N years; "disrupt_route"
# severs a named one. This is how caravans, raids, and embargoes touch the economy.
func _apply_trade(trade: Dictionary) -> void:
	if trade.is_empty():
		return
	if trade.has("open"):
		TradeManager.open_route(String(trade["open"]))
	if trade.has("disrupt_route"):
		TradeManager.disrupt(String(trade["disrupt_route"]), int(trade.get("disrupt", 2)))
	elif trade.has("disrupt"):
		TradeManager.disrupt("", int(trade["disrupt"]))

# A choice can found a standing institution ("found_institution": "university").
func _apply_institution(id: String) -> void:
	if id != "":
		InstitutionManager.found(id)

func _apply_loyalty(loyalty: Dictionary) -> void:
	for id in loyalty.keys():
		var advisor_id: String = String(id)
		if Council.is_seated(advisor_id):
			Council.adjust_loyalty(advisor_id, int(loyalty[id]))

func _apply_traits(traits: Dictionary) -> void:
	for k in traits.keys():
		var d := int(traits[k])
		if GameState.ruler.sliders.has(k):
			GameState.ruler.sliders[k] = clampi(GameState.ruler.sliders[k] + d, -3, 3)
		elif GameState.ruler.skills.has(k):
			GameState.ruler.skills[k] = clampi(GameState.ruler.skills[k] + d, 0, 3)

func _schedule_flags(flags: Array) -> void:
	for f in flags:
		var flag: Dictionary = (f as Dictionary).duplicate()
		flag["fire_at_hand"] = GameState.hand_counter + int(flag.get("in_hands", 4))
		Chronicle.schedule(flag)
