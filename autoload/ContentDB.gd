# Loads all data-driven content (events, dooms) from JSON at startup.
extends Node

var events: Array = []
var dooms: Array = []
var advisors: Array = []
var upbringings: Array = []
var threats: Array = []
var trade_routes: Array = []
var institutions: Array = []

var flag_targets: Dictionary = {}   # event ids reachable ONLY via a scheduled flag

func _ready() -> void:
	events = _load("res://data/events.json")
	dooms = _load("res://data/dooms.json")
	advisors = _load("res://data/advisors.json")
	upbringings = _load("res://data/upbringings.json")
	threats = _load("res://data/threats.json")
	trade_routes = _load("res://data/trade_routes.json")
	institutions = _load("res://data/institutions.json")
	_index_flag_targets()
	print("[ContentDB] loaded %d events, %d dooms, %d advisors, %d upbringings, %d threats, %d routes, %d institutions (%d consequence-only)" % [events.size(), dooms.size(), advisors.size(), upbringings.size(), threats.size(), trade_routes.size(), institutions.size(), flag_targets.size()])

# A consequence must never appear before its cause: any event referenced by a
# choice's flag fires ONLY via that flag (event_by_id), never a random draw.
func _index_flag_targets() -> void:
	flag_targets.clear()
	for e in events:
		for c in (e.get("choices", []) as Array):
			for f in ((c as Dictionary).get("flags", []) as Array):
				var target: String = String((f as Dictionary).get("event_id", ""))
				if target != "":
					flag_targets[target] = true

func _load(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Missing content file: " + path)
		return []
	var txt := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_ARRAY:
		push_error("Expected a JSON array: " + path)
		return []
	return data

func by_slot(slot: String) -> Array:
	var out: Array = []
	for e in events:
		if e.get("slot", "") == slot and not flag_targets.has(String(e.get("id", ""))):
			out.append(e)
	return out

func event_by_id(id: String) -> Dictionary:
	for e in events:
		if e.get("id", "") == id:
			return e
	return {}

func advisor_by_id(id: String) -> Dictionary:
	for a in advisors:
		if a.get("id", "") == id:
			return a
	return {}

func upbringing_by_id(id: String) -> Dictionary:
	for u in upbringings:
		if u.get("id", "") == id:
			return u
	return {}

func institution_by_id(id: String) -> Dictionary:
	for i in institutions:
		if i.get("id", "") == id:
			return i as Dictionary
	return {}
