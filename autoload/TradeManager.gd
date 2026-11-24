# The trade network (GDD's 'staged for later' economy layer): persistent routes
# that yield SEASONAL, DISRUPTABLE income once opened — never a flat faucet.
# Opening a route is a coin investment competing with Doom-prep and virtue; a raid,
# a horde, or a plague can sever it for years. Stewardship and the Steward advisor
# sweeten the take, but the bonus is capped (GDD economy guard). Data-driven:
# routes live in trade_routes.json; choices open/sever them via EventEngine.
extends Node

signal trade_changed

const STEWARD_BONUS_CAP := 2   # cap the Stewardship income bonus (no money-faucet)

var routes: Array = []   # [{id, name, income, open, disrupted}]

func reset() -> void:
	routes = []
	for r in ContentDB.trade_routes:
		var def: Dictionary = r as Dictionary
		routes.append({
			"id": String(def.get("id", "")),
			"name": String(def.get("name", "?")),
			"income": int(def.get("income", 2)),
			"open": false,
			"disrupted": 0,   # years remaining severed
		})
	trade_changed.emit()

func route_by_id(id: String) -> Dictionary:
	for r in routes:
		if String(r.get("id", "")) == id:
			return r as Dictionary
	return {}

func is_open(id: String) -> bool:
	var r := route_by_id(id)
	return not r.is_empty() and bool(r.get("open", false))

func open_route(id: String) -> void:
	var r := route_by_id(id)
	if not r.is_empty() and not bool(r.get("open", false)):
		r["open"] = true
		GameState.log_line.emit("A new trade route opens: %s." % String(r.get("name", "?")))
		trade_changed.emit()

# Sever a specific route, or (id == "") a random working one, for `years`.
func disrupt(id: String, years: int) -> void:
	var r := route_by_id(id) if id != "" else _random_active()
	if r.is_empty():
		return
	r["disrupted"] = maxi(int(r.get("disrupted", 0)), years)
	GameState.log_line.emit("Trade along %s is severed." % String(r.get("name", "?")))
	trade_changed.emit()

func _random_active() -> Dictionary:
	var live: Array = []
	for r in routes:
		if bool(r.get("open", false)) and int(r.get("disrupted", 0)) <= 0:
			live.append(r)
	return (live.pick_random() as Dictionary) if not live.is_empty() else {}

# Coin this year from open, undisrupted routes + the capped Stewardship/Steward bonus.
func trade_income() -> int:
	var base := 0
	for r in routes:
		if bool(r.get("open", false)) and int(r.get("disrupted", 0)) <= 0:
			base += int(r.get("income", 0))
	if base <= 0:
		return 0   # no bonus without a working route — Stewardship needs trade to steward
	return base + _steward_bonus()

func _steward_bonus() -> int:
	var b := 0
	if GameState.ruler != null:
		b += int(GameState.ruler.skills.get("stewardship", 0))
	b += Council.advisor_skill_bonus("stewardship")   # scales with the Steward's level
	return mini(b, STEWARD_BONUS_CAP)

# Year-turn: severed routes heal by one year.
func tick_year() -> void:
	var changed := false
	for r in routes:
		if int(r.get("disrupted", 0)) > 0:
			r["disrupted"] = int(r["disrupted"]) - 1
			changed = true
	if changed:
		trade_changed.emit()

func open_routes() -> Array:
	var out: Array = []
	for r in routes:
		if bool(r.get("open", false)):
			out.append(r)
	return out
