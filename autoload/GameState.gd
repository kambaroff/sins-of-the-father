# Single source of truth: meters, current ruler, the hand-counter pacing clock, upkeep.
extends Node

signal meters_changed
signal log_line(text: String)
signal reign_lost(cause: String)

const SEASONS: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
const MIL_COST: Array[int] = [0, 2, 4, 6]      # None / Garrison / Standing Army / Grand Host
const MIL_DEFENSE: Array[int] = [0, 2, 4, 6]
const MIL_NAMES: Array[String] = ["No standing army", "Garrison", "Standing Army", "Grand Host"]
const BASE_INCOME: int = 3                     # the realm's annual tax — restores economic margin (balance tuning)

var meters: Dictionary = {"treasury": 5, "unrest": 3, "faith": 5}
var ruler: Ruler
var house: String = "Béla"        # the dynasty's name — set by the founder, persists for the line
var hand_counter := 0           # THE pacing unit (not a calendar) — locked
var year := 1
var season_idx := 0
var military_level := 1
var era := 1
var generation := 1             # which ruler of the line this is
var reckonings_survived := 0    # this dynasty's beaten Reckonings — banked to Legacy at its end
var reign_hands := 0            # hands served by the current ruler
var death_at_hand := 14         # rolled 12..18 per reign (locked pacing)

func new_game(founder: Ruler) -> void:
	ruler = founder
	meters = {"treasury": 5, "unrest": 3, "faith": 5}
	hand_counter = 0
	year = 1
	season_idx = 0
	era = 1
	generation = 1
	reign_hands = 0
	military_level = 1
	reckonings_survived = 0
	roll_reign_length()
	Chronicle.reset()
	Council.reset()
	TradeManager.reset()          # a new dynasty starts with no routes; they're built up
	InstitutionManager.reset()    # ...but inherits the standing works its ancestors founded
	meters["treasury"] = clampi(int(meters["treasury"]) + Legacy.founder_boon_treasury(), 0, 10)
	Succession.heir_upbringing = ""
	EventEngine.new_reign()       # fresh event deck (no stale repeats)
	meters_changed.emit()
	ThreatManager.begin_reign()   # the founder's reign gets its own contained threat

func roll_reign_length() -> void:
	death_at_hand = randi_range(12, 18)

func ruler_should_die() -> bool:
	return reign_hands >= death_at_hand

# Succession install: new ruler, fresh reign clock, new-reign grace (locked: -2 unrest).
# Doom-prep, Chronicle, flags, and the Council all persist — that IS the game.
func install_heir(heir: Ruler) -> void:
	ruler = heir
	generation += 1
	reign_hands = 0
	roll_reign_length()
	meters["unrest"] = clampi(int(meters["unrest"]) - 2, 0, 10)
	log_line.emit("The realm grants %s a moment of grace (−2 unrest)." % heir.name)
	EventEngine.new_reign()       # each heir starts with a fresh event deck
	meters_changed.emit()
	ThreatManager.begin_reign()   # each heir inherits the throne — and a fresh crisis

func season() -> String:
	return SEASONS[season_idx]

func apply(effects: Dictionary) -> void:
	for k in effects.keys():
		if meters.has(k):
			var before: int = int(meters[k])
			var after: int = clampi(before + int(effects[k]), 0, 10)
			meters[k] = after
			if before < 10 and after >= 10:
				_meter_maxed(String(k))
	meters_changed.emit()

# Reaching a cap should pay off, not be silently wasted (playtest fix).
func _meter_maxed(meter: String) -> void:
	match meter:
		"faith":
			meters["unrest"] = clampi(int(meters["unrest"]) - 2, 0, 10)
			log_line.emit("The Church proclaims you blessed — the faithful are pacified (−2 unrest).")
		"treasury":
			DoomManager.add_prep("war_chest", 1)
			meters["treasury"] = clampi(int(meters["treasury"]) - 2, 0, 10)
			log_line.emit("Your overflowing coffers are banked into the war-chest (Doom prep +1).")

func advance() -> void:
	hand_counter += 1
	reign_hands += 1
	season_idx += 1
	if season_idx >= SEASONS.size():
		season_idx = 0
		year += 1
		pay_upkeep()

# A content realm pays its taxes gladly; a restless one bleeds coin on garrisons
# and bribes. This makes LOW unrest an active goal, not just "stay under 10".
func unrest_modifier() -> int:
	var u: int = int(meters["unrest"])
	if u <= 2:
		return 1     # content realm: +1 income
	if u >= 7:
		return -1    # restless realm: −1 to the year's balance
	return 0

# The year's full ledger — income sources, upkeep sources, and the net. One source
# of truth for both pay_upkeep and the Budget panel (so the player can see it).
func yearly_budget() -> Dictionary:
	var order: int = unrest_modifier()
	var trade: int = TradeManager.trade_income()
	var mint: int = InstitutionManager.income_bonus()
	var court: int = 1
	var mil: int = MIL_COST[military_level]
	var council: int = Council.total_upkeep()
	var works: int = InstitutionManager.upkeep()
	var income: int = BASE_INCOME + trade + mint + maxi(order, 0)
	var upkeep: int = court + mil + council + works + maxi(-order, 0)
	return {
		"taxes": BASE_INCOME, "trade": trade, "mint": mint, "order": order,
		"court": court, "military": mil, "council": council, "works": works,
		"income": income, "upkeep": upkeep, "net": income - upkeep,
	}

func pay_upkeep() -> void:
	var b: Dictionary = yearly_budget()
	var net: int = int(b["net"])
	var before: int = int(meters["treasury"])
	meters["treasury"] = clampi(before + net, 0, 10)
	var extra_str: String = ""
	if int(b["trade"]) > 0:
		extra_str += " · trade +%d" % int(b["trade"])
	if int(b["mint"]) > 0:
		extra_str += " · mint +%d" % int(b["mint"])
	if int(b["order"]) != 0:
		extra_str += " · %s %+d" % ["content" if int(b["order"]) > 0 else "unrest", int(b["order"])]
	log_line.emit("Income +%d%s · upkeep −%d (net %+d)" % [BASE_INCOME, extra_str, int(b["upkeep"]), net])
	if before + net < 0:
		for id in Council.seated.duplicate():
			Council.adjust_loyalty(id, -1)
		log_line.emit("The treasury couldn't cover its debts — the council grows resentful.")
	var ungoverned: int = Council.governance_unrest()   # a hollowed-out council festers
	if ungoverned > 0:
		meters["unrest"] = clampi(int(meters["unrest"]) + ungoverned, 0, 10)
		log_line.emit("The realm drifts, poorly governed — unrest festers (+%d)." % ungoverned)
	var relief: int = InstitutionManager.yearly_unrest_relief()   # e.g. the Cathedral calms the realm
	if relief > 0:
		meters["unrest"] = clampi(int(meters["unrest"]) - relief, 0, 10)
	TradeManager.tick_year()   # severed routes heal one year after this year's reckoning
	meters_changed.emit()

func defense() -> int:
	return MIL_DEFENSE[military_level]

# Player control over the standing army: raise it for Defense, disband it to stop
# paying its upkeep. (Defense counts only against military Dooms.)
func set_military(level: int) -> void:
	military_level = clampi(level, 0, MIL_COST.size() - 1)
	meters_changed.emit()

func check_lose() -> String:
	if meters["treasury"] <= 0: return "bankruptcy"
	if meters["unrest"] >= 10: return "revolt"
	if meters["faith"] <= 0: return "deposition"
	return ""

func check_and_signal_lose() -> bool:
	var cause: String = check_lose()
	if cause != "":
		reign_lost.emit(cause)
		return true
	return false
