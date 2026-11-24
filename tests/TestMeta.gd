# Meta-progression harness, headless:
#   godot --headless --path . tests/TestMeta.tscn
# Part 1: institution passives compute correctly. Part 2 (deterministic): a new
# dynasty inherits the works its ancestors built plus a capped Founder's Boon.
# Part 3: across carrying dynasties the AI founds works and legacy accrues.
extends Node

func _ready() -> void:
	print("\n== META-PROGRESSION CHECK ==")

	# Part 1 — institution passives.
	Legacy.reset()
	var founder := Ruler.new()
	founder.name = "Test"
	GameState.new_game(founder)
	assert(InstitutionManager.standing().is_empty(), "a virgin legacy carries no works")
	assert(int(GameState.meters.treasury) == 5, "no Founder's Boon without past reckonings")
	InstitutionManager.found("royal_mint")
	InstitutionManager.found("cathedral")
	InstitutionManager.found("university")
	assert(InstitutionManager.income_bonus() == 2, "the Mint adds +2 income")
	assert(InstitutionManager.upkeep() == 3, "three works cost +3 upkeep/yr (no faucet)")
	assert(InstitutionManager.yearly_unrest_relief() == 1, "the Cathedral eases +1 unrest/yr")
	assert(InstitutionManager.heir_skill_bonus() == 1, "the University schools heirs +1 skill")
	print("  passives verified: Mint income, Cathedral relief, University schooling")

	# Part 2 — cross-run carry (deterministic): a new line inherits works + a capped boon.
	Legacy.reset()
	Legacy.total_reckonings = 12                 # a storied past
	Legacy.remember_institution("university")
	var successor := Ruler.new()
	successor.name = "Successor"
	GameState.new_game(successor)
	assert(int(GameState.meters.treasury) == 5 + 3, "Founder's Boon capped at +3 (treasury 8)")
	assert(InstitutionManager.has("university"), "the University our ancestors built still stands")
	assert(InstitutionManager.heir_skill_bonus() == 1, "the inherited University still schools heirs")
	print("  cross-run carry verified: new line starts +3 coin with the inherited University")

	# Part 3 — sim: the AI founds works when wealthy; legacy accrues across dynasties.
	Legacy.reset()
	var built := 0
	for s in range(4):
		var r: Dictionary = DynastySim.run("balanced", "steppe_horde", 5150 + s * 17, true)  # carry legacy
		built += int(r.get("institutions", 0))
		print("  dynasty %d: %d works standing, boon +%d, legacy reckonings %d (end: %s)" % [
			s, int(r.get("institutions", 0)), int(r.get("boon", 0)),
			int(r.get("legacy_reckonings", 0)), String(r.get("end", ""))])
	assert(built > 0, "a wealthy AI founds standing works")
	print("[TEST] META PASS — institutions grant passives; legacy carries works + boon across dynasties")
	get_tree().quit()
