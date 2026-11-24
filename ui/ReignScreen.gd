# Player-driven reign loop: renders GameState live, deals the season hand one card
# at a time, and calls EventEngine on each choice. Thin UI, fat state (see CLAUDE.md).
extends Control
class_name ReignScreen

var _hand: Array[Dictionary] = []
var _card_idx: int = 0
var _game_over: bool = false

@onready var treasury_bar: MeterBar = $Root/Meters/TreasuryBar
@onready var unrest_bar: MeterBar = $Root/Meters/UnrestBar
@onready var faith_bar: MeterBar = $Root/Meters/FaithBar
@onready var dynasty_title: Label = $Root/DynastyTitle
@onready var season_label: Label = $Root/Header/SeasonLabel
@onready var hand_progress: Label = $Root/HandProgress
@onready var card: EventCard = $Root/Card
@onready var log_label: Label = $Root/LogLabel
@onready var status_overlay: Label = $Root/StatusOverlay
@onready var council_button: Button = $Root/Header/CouncilButton
@onready var chronicle_button: Button = $Root/Header/ChronicleButton
@onready var council_screen: CouncilScreen = $Council
@onready var succession_screen: SuccessionScreen = $Succession
@onready var chronicle_screen: ChronicleScreen = $ChronicleView
@onready var summary_screen: SummaryScreen = $Summary
@onready var doom_label: Label = $Root/DoomLabel
@onready var character_label: Label = $Root/CharacterLabel
@onready var threat_label: Label = $Root/ThreatLabel
@onready var trade_label: Label = $Root/TradeLabel
@onready var legacy_label: Label = $Root/LegacyLabel
@onready var budget_label: Label = $Root/BudgetLabel
@onready var budget_button: Button = $Root/Header/BudgetButton
@onready var reckoning_box: VBoxContainer = $Root/ReckoningBox
@onready var reckoning_label: Label = $Root/ReckoningBox/ReckoningLabel
@onready var reckoning_button: Button = $Root/ReckoningBox/ReckoningButton
@onready var root: Control = $Root

func _ready() -> void:
	randomize()
	# Resolution adaptability: canvas_items+expand (project.godot) scales the whole UI
	# to any desktop window; guard a legible floor so text never shrinks to mush.
	get_window().min_size = Vector2i(800, 600)
	GameState.meters_changed.connect(_refresh_meters)
	GameState.log_line.connect(_on_log)
	GameState.reign_lost.connect(_on_reign_lost)
	DoomManager.doom_changed.connect(_refresh_doom)
	ThreatManager.threat_changed.connect(_refresh_threat)
	TradeManager.trade_changed.connect(_refresh_trade)
	InstitutionManager.institutions_changed.connect(_refresh_legacy)
	TradeManager.trade_changed.connect(_refresh_budget)
	InstitutionManager.institutions_changed.connect(_refresh_budget)
	Council.council_changed.connect(_refresh_budget)
	# NOTE: council changes deliberately do NOT re-evaluate the open card. Hiring an
	# advisor can no longer unlock the choice in front of you — a reshuffle only shapes
	# future hands. (Closes the "hire-to-pass-this-check" exploit; see CouncilScreen.)
	card.choice_made.connect(_on_choice_made)
	council_button.pressed.connect(_on_council_pressed)
	budget_button.pressed.connect(_on_budget_pressed)
	chronicle_button.pressed.connect(func() -> void: chronicle_screen.show())
	succession_screen.throne_taken.connect(_on_throne_taken)
	reckoning_button.pressed.connect(_on_reckoning_continue)
	summary_screen.continue_pressed.connect(func() -> void: get_tree().reload_current_scene())
	status_overlay.hide()
	# Optional reference rows start collapsed; their refreshers reveal them when populated.
	for lbl in [threat_label, trade_label, legacy_label, log_label]:
		lbl.visible = false
	council_screen.hide()
	chronicle_screen.hide()
	summary_screen.hide()
	reckoning_box.hide()
	# Overlays fully occlude the reign UI (no bleed-through) by hiding $Root while open.
	for ov in [council_screen, chronicle_screen, succession_screen, summary_screen]:
		ov.visibility_changed.connect(_sync_root_visibility)
	# CR-24: the game OPENS on the succession screen — never a blank slate.
	succession_screen.open_for_founder()

func _sync_root_visibility() -> void:
	root.visible = not (council_screen.visible or chronicle_screen.visible or succession_screen.visible or summary_screen.visible)

func _on_council_pressed() -> void:
	council_screen.show()

func _on_throne_taken() -> void:
	_refresh_meters()
	_refresh_header()
	_refresh_dynasty_title()
	_refresh_character()
	if GameState.generation == 1 and GameState.hand_counter == 0:
		_deal_opening()
	else:
		_deal_next_hand()

# A curated first card so the founder's opening isn't a random draw (playtest fix).
func _deal_opening() -> void:
	var opening: Dictionary = ContentDB.event_by_id("coronation")
	if opening.is_empty() or (opening.get("choices", []) as Array).is_empty():
		_deal_next_hand()
		return
	_hand.assign([opening])
	_card_idx = 0
	_refresh_header()
	_show_current_card()

func _deal_next_hand() -> void:
	if _game_over:
		return
	_hand.assign(EventEngine.deal_hand())
	_card_idx = 0
	_refresh_header()
	_show_current_card()

func _show_current_card() -> void:
	while _card_idx < _hand.size() and (_hand[_card_idx].get("choices", []) as Array).is_empty():
		_card_idx += 1
	if _card_idx >= _hand.size():
		_end_hand()
		return
	var event: Dictionary = _hand[_card_idx]
	var slot: String = String(event.get("slot", ""))
	card.show_event(event, slot)
	_refresh_progress()

func _on_choice_made(choice: Dictionary) -> void:
	if _game_over:
		return
	# Re-check at the moment of the click: a council reshuffle mid-hand must not let a
	# now-unqualified (or newly-qualified) option through. The card is dealt with the
	# council you had when it appeared.
	if not EventEngine.choice_available(choice):
		return
	var event: Dictionary = _hand[_card_idx]
	EventEngine.resolve(event, choice)
	_refresh_character()   # a choice may have shifted the ruler's character
	_card_idx += 1
	if _card_idx < _hand.size():
		_show_current_card()
	else:
		_end_hand()

# Council changed mid-card (e.g. you just hired the Wren) — re-render the open card
# so a now-satisfied requirement unlocks its option immediately, no stale [locked].
func _reeval_card() -> void:
	if _game_over or _hand.is_empty() or _card_idx < 0 or _card_idx >= _hand.size():
		return
	var event: Dictionary = _hand[_card_idx]
	if not (event.get("choices", []) as Array).is_empty():
		card.show_event(event, String(event.get("slot", "")))

func _end_hand() -> void:
	GameState.advance()
	_refresh_header()
	if GameState.check_and_signal_lose():
		return
	if GameState.season_idx == 0:
		DoomManager.tick()
	# The Reckoning arrives before anything else matters (CR-13/14/18).
	if DoomManager.arrived():
		_on_reckoning_arrived()
		return
	# Natural death: the reign clock (12–18 hands) runs out -> the crown passes (CR-1).
	if GameState.ruler_should_die():
		succession_screen.open_for_succession(GameState.ruler)
		return
	_deal_next_hand()

func _on_reckoning_arrived() -> void:
	var title: String = String(DoomManager.doom.get("title", "?"))
	var rd: int = DoomManager.readiness()
	var sev: int = DoomManager.severity()
	var odds: String = DoomManager.reckon_flavor()   # read BEFORE resolve mutates the doom
	var outcome: String = DoomManager.resolve_reckoning()
	card.hide()
	reckoning_label.text = "THE RECKONING — %s\n%s\nreadiness %d vs severity %d (ancestral sins +%d)\n\n%s" \
		% [title, odds, rd, sev, Chronicle.doom_severity_bonus(), outcome]
	if outcome == "PUPPET / END":
		reckoning_button.text = "Read the saga ▸"
		_game_over = true
	else:
		reckoning_button.text = "Rebuild ▸"
	reckoning_box.show()

func _on_reckoning_continue() -> void:
	reckoning_box.hide()
	if _game_over:
		summary_screen.open("the reckoning")
		return
	card.show()
	_deal_next_hand()

func _refresh_meters() -> void:
	treasury_bar.set_value(int(GameState.meters["treasury"]))
	unrest_bar.set_value(int(GameState.meters["unrest"]))
	faith_bar.set_value(int(GameState.meters["faith"]))
	_refresh_doom()
	_refresh_budget()

# CR-20: the Doom is never off-screen. Show the OUTCOME the player cares about —
# the Reckoning band if it struck now — plus readiness/need, colour-coded. (This
# also explains why sheltering refugees leaps readiness: the pact counts triple.)
func _refresh_doom() -> void:
	if DoomManager.doom.is_empty():
		doom_label.text = ""
		return
	var track: int = int(DoomManager.doom.get("track", 0))
	var bar: String = "▓".repeat(track) + "░".repeat(10 - track)
	var band: String = DoomManager.reckon()
	var odds: String = DoomManager.reckon_flavor()
	var breather: String = (" · breather %dyr" % DoomManager.breather_years) if DoomManager.breather_years > 0 else ""
	doom_label.text = "☠ %s  %s %d/10   ·   should it come now — Odds: %s  (ready %d / need %d)%s" % [
		String(DoomManager.doom.get("title", "?")), bar, track, odds,
		DoomManager.readiness(), DoomManager.severity(), breather]
	doom_label.modulate = _band_color(band)

func _band_color(band: String) -> Color:
	match band:
		"SURVIVE":
			return Color(0.16, 0.42, 0.16)   # ink-green, legible on parchment
		"BATTERED":
			return Color(0.55, 0.4, 0.06)     # amber
	return Color(0.62, 0.13, 0.1)             # ember-red

var _budget_open: bool = false

func _on_budget_pressed() -> void:
	_budget_open = not _budget_open
	_refresh_budget()

# The year's ledger, so bankruptcy is never a surprise: a compact net always, the
# full breakdown of income and upkeep sources when the Budget button is tapped.
func _refresh_budget() -> void:
	var b: Dictionary = GameState.yearly_budget()
	var net: int = int(b["net"])
	budget_label.modulate = Color(0.16, 0.42, 0.16) if net >= 0 else Color(0.62, 0.13, 0.1)
	if not _budget_open:
		budget_label.text = "⚖ Yearly balance: %+d coin   ·   tap Budget for detail" % net
		return
	var inc: Array[String] = ["taxes +%d" % int(b["taxes"])]
	if int(b["trade"]) > 0:
		inc.append("trade +%d" % int(b["trade"]))
	if int(b["mint"]) > 0:
		inc.append("mint +%d" % int(b["mint"]))
	if int(b["order"]) > 0:
		inc.append("content +%d" % int(b["order"]))
	var up: Array[String] = ["court −%d" % int(b["court"])]
	if int(b["military"]) > 0:
		up.append("army −%d" % int(b["military"]))
	if int(b["council"]) > 0:
		up.append("council −%d" % int(b["council"]))
	if int(b["works"]) > 0:
		up.append("works −%d" % int(b["works"]))
	if int(b["order"]) < 0:
		up.append("unrest −%d" % (-int(b["order"])))
	budget_label.text = "⚖ Income +%d  (%s)   ·   Upkeep −%d  (%s)   ·   Net %+d/yr" % [
		int(b["income"]), ", ".join(inc), int(b["upkeep"]), ", ".join(up), net]

func _refresh_threat() -> void:
	if ThreatManager.active.is_empty():
		threat_label.text = ""
	else:
		threat_label.text = "⚔ This reign's trial: %s" % String(ThreatManager.active.get("title", ""))
	threat_label.visible = threat_label.text != ""

# The current ruler's evolving character: defining (non-zero) traits and skills.
func _refresh_character() -> void:
	if GameState.ruler == null:
		character_label.text = ""
		return
	var traits: Array[String] = []
	for axis in GameState.ruler.sliders.keys():
		var v: int = int(GameState.ruler.sliders[axis])
		if v != 0:
			var poles: Array = SuccessionScreen.POLES.get(axis, ["−", "+"]) as Array
			traits.append("%s%s" % [String(poles[0 if v < 0 else 1]), "◆".repeat(absi(v))])
	var skills: Array[String] = []
	for s in GameState.ruler.skills.keys():
		var lvl: int = int(GameState.ruler.skills[s])
		if lvl > 0:
			skills.append("%s%s" % [String(s), "●".repeat(lvl)])
	var parts: Array[String] = []
	if not traits.is_empty():
		parts.append(" · ".join(traits))
	if not skills.is_empty():
		parts.append(" · ".join(skills))
	var desc: String = "   ".join(parts) if not parts.is_empty() else "as yet unwritten"
	character_label.text = "👤 %s — %s" % [GameState.ruler.name, desc]

func _refresh_trade() -> void:
	var open: Array = TradeManager.open_routes()
	if open.is_empty():
		trade_label.text = ""
		trade_label.visible = false
		return
	var parts: Array[String] = []
	for r in open:
		var name: String = String(r.get("name", "?"))
		if int(r.get("disrupted", 0)) > 0:
			parts.append("%s (severed %dyr)" % [name, int(r.get("disrupted", 0))])
		else:
			parts.append(name)
	trade_label.text = "⇄ Trade +%d/yr — %s" % [TradeManager.trade_income(), ", ".join(parts)]
	trade_label.visible = true

func _refresh_legacy() -> void:
	var works: Array = InstitutionManager.standing()
	if works.is_empty():
		legacy_label.text = ""
		legacy_label.visible = false
		return
	var names: Array[String] = []
	for id in works:
		names.append(InstitutionManager.name_of(String(id)))
	legacy_label.text = "🏛 Standing works: %s" % ", ".join(names)
	legacy_label.visible = true

func _refresh_dynasty_title() -> void:
	dynasty_title.text = "❦   HOUSE OF %s   ❦" % GameState.house.to_upper()

func _refresh_header() -> void:
	season_label.text = "%s · Year %d · hand %d" % [GameState.season(), GameState.year, GameState.hand_counter]

func _refresh_progress() -> void:
	var dots: Array[String] = []
	for i in _hand.size():
		if i < _card_idx:
			dots.append("●")
		elif i == _card_idx:
			dots.append("◉")
		else:
			dots.append("○")
	hand_progress.text = " ".join(dots)

func _on_log(text: String) -> void:
	log_label.text = String(text)
	log_label.visible = log_label.text != ""

func _on_reign_lost(cause: String) -> void:
	_game_over = true
	status_overlay.text = "The reign of %s ends in %s." % [GameState.ruler.name, cause.to_upper()]
	status_overlay.show()
	card.hide()
	summary_screen.open(cause)
