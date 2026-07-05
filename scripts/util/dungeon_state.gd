class_name DungeonState
extends RefCounted
## Pure dict logic for daily dungeon respawn / kill persistence. No scene tree,
## no autoloads touched directly by callers other than SaveManager.world.
##
## Blob shape — SaveManager.world["dungeon_state"] (see save_manager.gd contract):
##   {
##     "day": int,                       # last day this blob was touched
##     "killed": { floor_key: [spawn_index, ...] },
##   }
## `floor_key` is a String identifying a floor scene (e.g. "dungeon_1").
## `spawn_index` is that enemy's position in its floor's ENEMY_SPAWNS array.
##
## ensure_day() must be called once per floor load, BEFORE is_killed() queries,
## so a new game day clears yesterday's kills (fresh respawns) while same-day
## re-entries keep them dead.


static func ensure_day(blob: Dictionary, day: int) -> Dictionary:
	## Returns a blob guaranteed to have "day"/"killed" keys, resetting "killed"
	## when `day` has advanced past the stored day. Does not mutate `blob` in
	## place — caller re-assigns the result (keeps this a pure function).
	var out := blob.duplicate(true)
	if int(out.get("day", -1)) != day:
		out["day"] = day
		out["killed"] = {}
	elif not out.has("killed"):
		out["killed"] = {}
	return out


static func is_killed(blob: Dictionary, floor_key: String, spawn_index: int) -> bool:
	var killed: Dictionary = blob.get("killed", {})
	var list: Array = killed.get(floor_key, [])
	# int(v) compare, NOT list.has(): the blob round-trips through JSON
	# (SaveManager), which turns ints into floats — and Array.has(3) does
	# not match 3.0 in Godot 4. Caught by test_survives_json_round_trip.
	for v in list:
		if int(v) == spawn_index:
			return true
	return false


static func record_kill(blob: Dictionary, floor_key: String, spawn_index: int) -> Dictionary:
	## Returns a new blob with spawn_index recorded as killed for floor_key.
	## Idempotent: recording the same index twice doesn't duplicate it (also
	## across the JSON int->float round-trip, see is_killed).
	var out := blob.duplicate(true)
	if not out.has("killed"):
		out["killed"] = {}
	var killed: Dictionary = out["killed"]
	var list: Array = (killed.get(floor_key, []) as Array).duplicate()
	if not is_killed(out, floor_key, spawn_index):
		list.append(spawn_index)
	killed[floor_key] = list
	out["killed"] = killed
	return out
