class_name TriggerService
extends RefCounted
## Alive Stride 2: pure precondition evaluation + "which scene (if any) should
## fire right now" lookup for authored EventScript data files. Kept a plain
## RefCounted/static-method utility (like NPCRegistry/DialogResolver) so the
## precondition matrix is unit-testable with zero scene-tree/autoload
## dependency beyond the read-only Clock/GameState/Relationships queries the
## contract's own precondition keys need.
##
## Supported precondition keys (all optional; an empty preconditions dict
## always passes):
##   "flag_set": String        — GameState.flags[key] must be true
##   "flag_absent": String     — GameState.flags must NOT have this key true
##   "min_hearts": {"npc": String, "level": int} — Relationships.level(npc) >= level
##   "season": int              — Clock.season() must equal this
##   "day_range": [int, int]    — Clock.day_of_season() in [min, max] inclusive
##   "block/hours": String OR Array — NPCRegistry.block_for(Clock.hour())
##                                 equals this (contract's "block/hours" key
##                                 name, kept verbatim rather than renamed to
##                                 "block"). Craft Stride 2: an Array value
##                                 means "any of these blocks" — "Fang Steel"
##                                 spans 6-12, i.e. TWO registry blocks.
##   "map": String               — current map id (caller supplies, since this
##                                  file has no scene-tree access of its own)
##   "has_item": String          — Inventory.count_of(id) >= 1 (Craft Stride 2:
##                                  "Fang Steel" requires the steel_sword in
##                                  the player's inventory)
##   "next_day_after_flag": String — passes only when Clock.day is STRICTLY
##                                  GREATER than the day the named flag was
##                                  set. The flag-setter records that day as a
##                                  companion "<flag>_day" int flag (see
##                                  npc.gd's _on_heart_event_choice) — int()
##                                  coercion on read per the JSON-float
##                                  gotcha. A missing day record reads as 0,
##                                  i.e. passes from day 1 on (documented:
##                                  kinder to pre-record saves than locking
##                                  the scene out forever).
##
## Once-per-day-per-id gate: `has_fired_today(seen, id)` / callers mark a
## fired id into world["events_seen"] (see save_manager.gd's sanctioned-keys
## doc) as "<id>@<day>" so both "already played, ever" (for one-time-only
## scenes like the day-1 intro or The Bench) and "already played today" (for
## repeatable-but-daily-capped scenes, none shipped yet but supported) can be
## expressed by whether the caller checks the whole entry or a day-suffixed
## one. This stride's own two scenes (intro_alden, garrick_sten_bench) are
## BOTH one-time-forever, so they store the bare id with no day suffix and
## check for its bare presence — see mark_seen_forever()/seen_forever().
##
## "at most one scene per day per id" (contract): enforced by
## fires_at_most_once_per_day() — a caller (a map's _ready()/block-change
## hook) should check this before invoking a scene a second time in the same
## day even if its other preconditions still hold.


static func evaluate(preconditions: Dictionary, current_map: String = "") -> bool:
	if preconditions.has("flag_set"):
		if not bool(GameState.flags.get(String(preconditions["flag_set"]), false)):
			return false
	if preconditions.has("flag_absent"):
		if bool(GameState.flags.get(String(preconditions["flag_absent"]), false)):
			return false
	if preconditions.has("min_hearts"):
		var mh: Dictionary = preconditions["min_hearts"]
		var npc_id := String(mh.get("npc", ""))
		var min_level := int(mh.get("level", 0))
		if Relationships.level(npc_id) < min_level:
			return false
	if preconditions.has("season"):
		if Clock.season() != int(preconditions["season"]):
			return false
	if preconditions.has("day_range"):
		var range_arr: Array = preconditions["day_range"]
		if range_arr.size() == 2:
			var d := Clock.day_of_season()
			if d < int(range_arr[0]) or d > int(range_arr[1]):
				return false
	if preconditions.has("block/hours"):
		var want = preconditions["block/hours"]
		var current_block := NPCRegistry.block_for(Clock.hour())
		if want is Array:
			if not (current_block in want):
				return false
		elif current_block != String(want):
			return false
	if preconditions.has("map") and current_map != "":
		if String(preconditions["map"]) != current_map:
			return false
	if preconditions.has("has_item"):
		if Inventory.count_of(String(preconditions["has_item"])) < 1:
			return false
	if preconditions.has("next_day_after_flag"):
		var flag_name := String(preconditions["next_day_after_flag"])
		var set_day := int(GameState.flags.get(flag_name + "_day", 0))
		if Clock.day <= set_day:
			return false
	return true


## ---- events_seen bookkeeping (world["events_seen"], see save_manager.gd) ----

static func seen_forever(seen_blob: Dictionary, event_id: String) -> bool:
	return bool(seen_blob.get(event_id, false))


static func mark_seen_forever(seen_blob: Dictionary, event_id: String) -> Dictionary:
	var out := seen_blob.duplicate()
	out[event_id] = true
	return out


static func seen_today(seen_blob: Dictionary, event_id: String, day: int) -> bool:
	return int(seen_blob.get(event_id, -1)) == day


static func mark_seen_today(seen_blob: Dictionary, event_id: String, day: int) -> Dictionary:
	var out := seen_blob.duplicate()
	out[event_id] = day
	return out


## ---- "at most one scene per day" (across ALL event ids, not just one) ----

static func fires_at_most_once_per_day(seen_blob: Dictionary, day: int) -> bool:
	## True when NO event has already been recorded as fired THIS SPECIFIC
	## day (checked via the "<id>@fired_day" companion key every successful
	## fire writes alongside its own forever/daily marker — see
	## mark_any_fired_today()). Callers check this before invoking a NEW
	## scene, even one whose own preconditions independently still hold.
	return int(seen_blob.get("_any_fired_day", -1)) != day


static func mark_any_fired_today(seen_blob: Dictionary, day: int) -> Dictionary:
	var out := seen_blob.duplicate()
	out["_any_fired_day"] = day
	return out


## ---- selecting which scene should fire ----

static func pick_scene(candidates: Array[Dictionary], seen_blob: Dictionary, day: int, current_map: String = "") -> Dictionary:
	## Returns the first candidate scene DATA dict (in list order) whose
	## preconditions pass, that hasn't already been seen forever, and that
	## respects the "at most one scene per day" global cap — or {} if none
	## qualify. Deterministic (first-match, not random) so authored scene
	## priority is just list order.
	if not fires_at_most_once_per_day(seen_blob, day):
		return {}
	for scene_data: Dictionary in candidates:
		var event_id := String(scene_data.get("id", ""))
		if event_id == "" or seen_forever(seen_blob, event_id):
			continue
		var preconditions: Dictionary = scene_data.get("preconditions", {})
		if evaluate(preconditions, current_map):
			return scene_data
	return {}
