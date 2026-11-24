# Trade-network harness, headless:
#   godot --headless --path . tests/TestTrade.tscn
# Part 1 unit-checks TradeManager (open -> income, disrupt -> loss, heal, the capped
# Steward bonus). Part 2 runs seeded dynasties to prove the AutoPlayer actually
# builds routes when solvent, so trade is a real economic engine — not dead data.
extends Node

func _ready() -> void:
	print("\n== TRADE SYSTEM CHECK ==")
	var founder := Ruler.new()
	founder.name = "Test"
	GameState.new_game(founder)   # resets TradeManager: every route closed
	assert(TradeManager.trade_income() == 0, "no open route -> no trade income")

	TradeManager.open_route("river_road")   # income 2
	TradeManager.open_route("silk_road")    # income 3  (Steward seated by default -> +1)
	var inc_open: int = TradeManager.trade_income()
	print("  two routes open: income = %d  (river 2 + silk 3 + steward 1)" % inc_open)
	assert(inc_open == 6, "river(2)+silk(3)+steward(1) = 6")

	TradeManager.disrupt("silk_road", 2)
	var inc_dis: int = TradeManager.trade_income()
	print("  silk road severed: income = %d  (river 2 + steward 1)" % inc_dis)
	assert(inc_dis == 3, "only the river pays while silk is severed")

	TradeManager.tick_year()
	TradeManager.tick_year()
	assert(TradeManager.trade_income() == 6, "silk road heals after 2 years")

	GameState.ruler.skills["stewardship"] = 3   # skilled steward-ruler
	assert(TradeManager.trade_income() == 5 + 2, "Steward bonus is capped at 2 (base 5 + 2 = 7)")
	print("  steward bonus cap verified: income = 7 with stewardship 3 + Steward advisor")

	# Part 2 — the AI must build routes when it can afford to.
	var runs_with_trade := 0
	var total_open := 0
	for s in range(6):
		var r: Dictionary = DynastySim.run("balanced", "steppe_horde", 909 + s * 31)
		total_open += int(r.get("trade_open", 0))
		if int(r.get("trade_open", 0)) > 0:
			runs_with_trade += 1
		print("  sim run %d: %d routes open, trade +%d/yr at end (end: %s)" % [
			s, int(r.get("trade_open", 0)), int(r.get("trade_income", 0)), String(r.get("end", ""))])
	assert(runs_with_trade > 0, "a solvent AI opens trade routes")
	print("[TEST] TRADE PASS — routes open, income flows, disruption bites, steward bonus capped")
	get_tree().quit()
