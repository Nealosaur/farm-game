extends Node
## Single-slot JSON save. Forward compatible: every read uses .get() defaults,
## so old saves survive new keys. Never crashes on a bad file.

const SAVE_VERSION := 1

var save_path := "user://save1.json"
## World-data contract (Plan 2+): scenes WRITE SaveManager.world[key] just before
## save_game() fires (and on scene exit); scenes READ world.get(key, default) in
## _ready(). No signal is emitted on load — callers must sequence scene loads
## AFTER load_game()/new_game() completes.
## Sanctioned keys:
##   "farm_grid"     — FarmGrid.to_dict() (cell "x,y" -> plot dict)
##   "shipping_bin"  — item_id -> count, cleared at each day rollover
##   "dungeon_state" — {"day": int, "killed": {floor_key: [spawn_index, ...]}}
##                     daily dungeon respawn ledger; shape + rules live in
##                     DungeonState (scripts/util/dungeon_state.gd)
##   "calendar"      — {"weather": "clear"|"rain", "rolled_day": int}
##                     today's weather, written by Clock.roll_weather() and
##                     read back via Clock.restore_calendar() on load (int()
##                     on rolled_day — JSON floats gotcha). Season/day-of-
##                     season/year are NOT stored: derived from Clock.day.
##   "relationships" — npc_id -> {points:int, talked_day:int, gifted_day:int,
##                     events_seen:[String], perks_given:[String],
##                     shown_lines:{tier_name:[int]}}. Owned by the
##                     Relationships autoload; call Relationships.restore()
##                     after new_game()/load_game() (no signal fires on load —
##                     same sequencing rule as Clock.restore_calendar()). All
##                     ints/arrays are coerced on read (JSON floats gotcha).
##   "forage"        — map_id -> {"day": int, "taken": ["x,y", ...]}. Daily
##                     forage-spawn ledger (Riverwoods/Beach), shape + rules
##                     live in Forage (scripts/util/forage.gd) — same
##                     ensure_day()-before-query pattern as "dungeon_state".
##                     int()/String() coerced on read like every other blob.
##   "quests"        — quest_id -> {"state": "active"|"done", "met":
##                     [String], "already_met_king": bool}. Owned by the
##                     Quests autoload (scripts/quests/quests.gd); call
##                     Quests.restore() after new_game()/load_game() (no
##                     signal fires on load — same sequencing rule as
##                     Clock.restore_calendar()/Relationships.restore()).
##   "festival"      — {"decor_day": int, "contest_year": int}. Owned by the
##                     Festival helper (scripts/world/festival.gd): tracks
##                     which day the plaza decor was last applied (so it can
##                     be cleared the following day) and the last year the
##                     Harvest Fair contest was entered (once-per-year gate).
##                     int() coerced on read like every other blob.
##   "intro"         — {"done": bool}. Owned by GameState.flags in practice
##                     (see GameState.flags["intro_done"] — flags already
##                     round-trips via GameState.to_dict()/from_dict(), so
##                     Day-1 intro state does NOT need its own top-level
##                     world key; this entry documents that choice so a
##                     future reader doesn't go looking for a "world.intro"
##                     key that was never created).
var world := {}  # map-owned persistent blobs (farm grid etc.), set by scenes


func new_game() -> void:
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.reset_day_timers()
	world = {}
	# Day 1 needs weather before the farm builds (rain tint/auto-water read it).
	# Must come after world = {} — the roll writes world["calendar"].
	Clock.roll_weather()
	GameState.reset_new_game()
	Inventory.reset()
	Inventory.add_item("hoe")
	Inventory.add_item("watering_can")
	Inventory.add_item("wooden_sword")
	Inventory.add_item("turnip_seeds", 5)
	Relationships.restore()  # empty world["relationships"] -> fresh state for every NPC
	Quests.restore()  # empty world["quests"] -> no quests granted yet (fresh Day 1)


func save_game() -> bool:
	var data := {
		"save_version": SAVE_VERSION,
		"day": Clock.day,
		"minutes": Clock.minutes,
		"state": GameState.to_dict(),
		"inventory": Inventory.to_dict(),
		"world": world,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write " + save_path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> bool:
	if not has_save():
		return false
	var json := JSON.new()
	var parse_err := json.parse(FileAccess.get_file_as_string(save_path))
	if parse_err != OK:
		push_warning("SaveManager: corrupt save file")
		return false
	var data = json.get_data()
	if data == null or typeof(data) != TYPE_DICTIONARY:
		push_warning("SaveManager: corrupt save file")
		return false
	var version := int(data.get("save_version", 0))
	if version != SAVE_VERSION:
		push_warning("SaveManager: save version %d != expected %d — loading with defaults for missing fields" % [version, SAVE_VERSION])
	Clock.day = int(data.get("day", 1))
	Clock.minutes = int(data.get("minutes", Clock.DAY_START_MINUTES))
	Clock.reset_day_timers()
	GameState.from_dict(data.get("state", {}))
	Inventory.from_dict(data.get("inventory", {}))
	world = data.get("world", {})
	Clock.restore_calendar()  # weather back from world["calendar"] (or defaults)
	Relationships.restore()  # bond state back from world["relationships"] (or defaults)
	Quests.restore()  # quest state back from world["quests"] (or defaults)
	_migrate_intro_flag()
	return true


func _migrate_intro_flag() -> void:
	## World Stride D: saves from before the Day-1 opening existed have no
	## "intro_done" flag at all. Bible-documented migration choice: treat the
	## intro as already done for any such save PAST day 1 (a returning player
	## should never have Alden's intro ambush them retroactively on the farm);
	## only a save that's somehow still ON day 1 with the flag missing (e.g.
	## a same-session Continue immediately after a pre-Stride-D new_game())
	## is left to actually play the intro.
	if GameState.flags.has("intro_done"):
		return
	GameState.flags["intro_done"] = Clock.day > 1


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)
