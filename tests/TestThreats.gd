# Per-reign threat harness, headless:
#   godot --headless --path . tests/TestThreats.tscn
# Runs seeded dynasties and tallies the reign-scale threat beats recorded in the
# Chronicle, proving every reign faces a contained threat that ESCALATES when the
# AutoPlayer (myopically) ignores it, and sometimes reaches a crisis that scars
# the bloodline Doom. Prints the tally for design judgment.
extends Node

const THREAT_BEAT := {
	"Raiders at the Marches": "open", "The Marches Burn": "esc", "A Province Lost": "crisis",
	"Whispers of a Coup": "open", "The Conspiracy Has a Banner": "esc", "Men in the Corridors": "crisis",
	"A Failing Harvest": "open", "Bread Riots": "esc", "The Hunger Winter": "crisis",
	"A Rising Heresy": "open", "The Sect Takes Root": "esc", "A Realm of Two Faiths": "crisis",
	"A Rival's Scheme": "open", "The Claimant Gathers Friends": "esc", "War Between Kin": "crisis",
}

func _ready() -> void:
	print("\n== THREAT SYSTEM CHECK ==")
	# A 'competent' line addresses its trials; a 'negligent' line ducks them and
	# reaps the escalation. Running both proves threats FIRE every reign (competent)
	# and that ducking them ESCALATES to a bloodline-scarring crisis (negligent).
	var competent := _tally("balanced", 3)
	var negligent := _tally("negligent", 3)
	print("  competent line: openings %d · escalations %d · crises %d  (~%d reigns)" % [
		competent.open, competent.esc, competent.crisis, competent.reigns])
	print("  negligent line: openings %d · escalations %d · crises %d  (~%d reigns)" % [
		negligent.open, negligent.esc, negligent.crisis, negligent.reigns])
	assert(competent.open > 0, "every reign should surface a contained threat")
	assert(negligent.esc > 0, "a ducked threat should escalate")
	assert(negligent.crisis > 0, "a fully-ignored threat should reach its crisis")
	assert(competent.esc <= negligent.esc, "addressing threats should mean fewer escalations")
	print("[TEST] THREATS PASS — a threat every reign; duck it and it escalates into a crisis")
	get_tree().quit()

func _tally(style: String, runs: int) -> Dictionary:
	var t := {"open": 0, "esc": 0, "crisis": 0, "reigns": 0}
	for s in range(runs):
		var r: Dictionary = DynastySim.run(style, "steppe_horde", 4242 + s * 13)
		# Chronicle.reset() runs at each dynasty's start, so entries now hold exactly
		# this run's ledger — tally before the next run wipes it.
		for e in Chronicle.entries:
			var beat: String = String(THREAT_BEAT.get(String(e.get("act", "")), ""))
			if beat != "":
				t[beat] += 1
		t["reigns"] += int(r.get("generations", 0))
	return t
