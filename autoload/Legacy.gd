# Cross-run meta-progression (GDD 'meta carrots'): a dynasty's triumphs outlive it.
# When a line ends, its achievements bank to disk; the NEXT dynasty starts with a
# capped Founder's Boon and inherits the standing institutions its ancestors built.
# This is the roguelite 'one more run' engine — permanent build-up across dynasties.
extends Node

const SAVE_PATH := "user://legacy.json"
const BOON_CAP := 3   # starting-treasury boon never exceeds this (guard vs power creep)

var dynasties: int = 0
var total_reckonings: int = 0
var institutions_ever: Dictionary = {}   # id -> true

func _ready() -> void:
	load_from_disk()

# Wipe recorded history — used to ISOLATE balance sims so each run starts from a
# clean slate rather than inheriting the previous run's legacy.
func reset() -> void:
	dynasties = 0
	total_reckonings = 0
	institutions_ever = {}

func remember_institution(id: String) -> void:
	institutions_ever[id] = true

func remembered_institutions() -> Array:
	return institutions_ever.keys()

# The Founder's Boon: hard-won past reckonings give a new line a small head start.
func founder_boon_treasury() -> int:
	return mini(BOON_CAP, total_reckonings / 3)

# Bank a finished dynasty's achievements for its successors. `persist` writes to
# disk (real game); sims pass false so a matrix never pollutes the player's save.
func record_dynasty(generations: int, reckonings: int, persist: bool = true) -> void:
	dynasties += 1
	total_reckonings += reckonings
	if persist:
		save_to_disk()

func save_to_disk() -> void:
	var data := {
		"dynasties": dynasties,
		"total_reckonings": total_reckonings,
		"institutions_ever": institutions_ever.keys(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var txt: String = FileAccess.get_file_as_string(SAVE_PATH)
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	dynasties = int((data as Dictionary).get("dynasties", 0))
	total_reckonings = int((data as Dictionary).get("total_reckonings", 0))
	institutions_ever = {}
	for id in ((data as Dictionary).get("institutions_ever", []) as Array):
		institutions_ever[String(id)] = true
