class_name Festival
extends RefCounted
## World Stride D: festival machinery layered on top of Clock.is_festival_today()
## and NPCRegistry's existing festival_cell mechanism. Pure static logic (no
## autoload/scene-tree access) — same testability bar as NPCRegistry/
## DungeonState — except where a helper explicitly needs GameState/Clock/
## SaveManager (documented per-function below, mirroring DungeonState's
## "pure dict logic, SaveManager.world is the caller's job" shape).
##
## Bible (world-bible.md "Festivals" + "Opening"): 4 festivals/year, plaza
## 10:00-18:00 EXCEPT sunfire (16:00-22:00 evening event). NPCRegistry's
## `is_festival` boolean is all-day-or-nothing once true — this file adds the
## HOUR-WINDOW nuance NPCRegistry can't express on its own: whether the
## current hour actually falls inside the active festival's window, and
## Willow's "leaves early" exception (present 10:00-15:00 only, EVERY
## festival, not just a specific one — characters.md's schedule line reads
## "leaves early..." with no festival-specific carve-out).
##
## Callers (npc.gd, town.gd) should call `is_npc_at_festival(npc_id, hour)`
## instead of the raw `Clock.is_festival_today() != ""` wherever that boolean
## used to feed NPCRegistry.cell_for()/map_for()/is_present() — see those
## call sites for the actual swap.

const NORMAL_START_HOUR := 10
const NORMAL_END_HOUR := 18       # half-open, matches NPCRegistry's block convention
const SUNFIRE_START_HOUR := 16
const SUNFIRE_END_HOUR := 22

const WILLOW_LEAVES_HOUR := 15    # bible: "leaves early... (present 10:00-15:00 only)"
const WILLOW_ID := "willow"

const ID_SOWING := "sowing"
const ID_SUNFIRE := "sunfire"
const ID_HARVEST_FAIR := "harvest_fair"
const ID_WINTER_STAR := "winter_star"

const DISPLAY_NAMES := {
	ID_SOWING: "Sowing Festival",
	ID_SUNFIRE: "Sunfire Festival",
	ID_HARVEST_FAIR: "Harvest Fair",
	ID_WINTER_STAR: "Winter Star Night",
}

## Contest tiers (Harvest Fair) — bible: ">=250 -> 1st (500g + all NPCs +50),
## >=100 -> 2nd (200g), else participation (50g)".
const CONTEST_FIRST_MIN_VALUE := 250
const CONTEST_SECOND_MIN_VALUE := 100
const CONTEST_FIRST_GOLD := 500
const CONTEST_FIRST_BOND_BONUS := 50
const CONTEST_SECOND_GOLD := 200
const CONTEST_PARTICIPATION_GOLD := 50


## ---- hour windows ----

static func hours_for(festival_id: String) -> Vector2i:
	## (start, end) half-open hour window. Non-sunfire festivals share the
	## bible's default 10:00-18:00; sunfire overrides to the evening
	## 16:00-22:00 slot.
	if festival_id == ID_SUNFIRE:
		return Vector2i(SUNFIRE_START_HOUR, SUNFIRE_END_HOUR)
	return Vector2i(NORMAL_START_HOUR, NORMAL_END_HOUR)


static func is_festival_hour(festival_id: String, hour: int) -> bool:
	if festival_id == "":
		return false
	var window := hours_for(festival_id)
	return hour >= window.x and hour < window.y


static func _willow_leaves_early(festival_id: String) -> bool:
	## Bible: "ALL 8 NPCs at assigned plaza cells 10:00-18:00 (Willow leaves
	## at 15:00; sunfire instead 16:00-22:00)" — read as two independent
	## notes on the DEFAULT (non-sunfire) window: NPCs are present 10-18, but
	## Willow specifically leaves at 15:00; sunfire is a wholly separate
	## evening window with no early-leave carve-out of its own mentioned
	## anywhere (characters.md's own Willow schedule line: "leaves early...
	## (present 10:00-15:00 only)" — a time range that only makes sense
	## against the 10-18 default, not sunfire's 16-22 evening slot).
	return festival_id != ID_SUNFIRE


static func phase_signature(hour: int) -> String:
	## A cheap "has anything about festival placement changed" fingerprint for
	## maps' time-ticked handlers to compare tick-to-tick, IN ADDITION to
	## their existing block-boundary check — festival hour boundaries
	## (10:00/18:00, sunfire's 16:00/22:00, Willow's 15:00 early-leave) don't
	## all land on NPCRegistry block boundaries (12:00/17:00), so relying on
	## block-change alone would miss them (e.g. Willow must vanish from the
	## plaza at 15:00, mid-block). Two different (festival_id, in-window,
	## willow-present) tuples never collide on the same string by construction.
	var festival_id := Clock.is_festival_today()
	var in_window := is_festival_hour(festival_id, hour)
	var willow_present := in_window and not (_willow_leaves_early(festival_id) and hour >= WILLOW_LEAVES_HOUR)
	return "%s|%s|%s" % [festival_id, in_window, willow_present]


static func is_npc_at_festival(npc_id: String, hour: int) -> bool:
	## The single query npc.gd/town.gd should use in place of the raw
	## `Clock.is_festival_today() != ""` boolean wherever it used to gate
	## NPCRegistry's festival placement. Folds in BOTH the hour-window check
	## and Willow's early-leave exception so every caller gets both nuances
	## automatically instead of re-deriving them ad hoc.
	var festival_id := Clock.is_festival_today()
	if not is_festival_hour(festival_id, hour):
		return false
	if npc_id == WILLOW_ID and _willow_leaves_early(festival_id) and hour >= WILLOW_LEAVES_HOUR:
		return false
	return true


## ---- notice board ----

static func next_festival_info(from_day: int) -> Dictionary:
	## {"id": String, "season": int, "day_of_season": int, "days_away": int}
	## for the soonest festival ON OR AFTER `from_day` (today counts as
	## "next" if it's a festival day itself — the notice board still names
	## it, per the bible's "always, not just festival days" wording, which
	## implies the board keeps working even ON the festival day). Searches
	## up to one full year + today ahead so it always finds one (there are
	## always exactly 4/year).
	for offset in (Clock.DAYS_PER_YEAR + 1):
		var day := from_day + offset
		var season := Clock.season_of_day(day)
		@warning_ignore("integer_division")
		var day_of_season := ((day - 1) % Clock.DAYS_PER_SEASON) + 1
		var by_day: Dictionary = Clock.FESTIVALS.get(season, {})
		if by_day.has(day_of_season):
			return {
				"id": String(by_day[day_of_season]),
				"season": season,
				"day_of_season": day_of_season,
				"days_away": offset,
			}
	return {}  # unreachable given FESTIVALS always has 4 entries/year, kept non-crashing


static func notice_board_text(from_day: int) -> String:
	## Bible: "notice board text = next festival name+date (always, not just
	## festival days)". "<Name> — <Season> <day>" reads naturally whether
	## it's today ("...Spring 14") or weeks out.
	var info := next_festival_info(from_day)
	if info.is_empty():
		return "Nothing posted yet."
	var name := String(DISPLAY_NAMES.get(info["id"], info["id"]))
	var season_name: String = Clock.SEASON_NAMES[int(info["season"])]
	return "%s — %s %d." % [name, season_name, int(info["day_of_season"])]


static func wake_toast_text(festival_id: String) -> String:
	## Bible: wake toast "The Sowing Festival is today! The plaza,
	## 10:00-18:00." (sunfire uses its own evening window in the message).
	var name := String(DISPLAY_NAMES.get(festival_id, festival_id))
	var window := hours_for(festival_id)
	return "The %s is today! The plaza, %02d:00-%02d:00." % [name, window.x, window.y]


## ---- plaza decor ----

static func decor_cells_for(festival_id: String) -> Array:
	## Reversible plaza-decor accent cells (bible: "colored tile accents...
	## simple, reversible at day end"). Returns an empty array for "no
	## festival"/unknown ids. Cells are relative to town.gd's PLAZA rect
	## (Rect2i(16,10,12,8)) — callers translate as needed; kept as plain
	## Vector2i offsets here so this file has zero town.gd dependency.
	match festival_id:
		ID_SOWING, ID_HARVEST_FAIR, ID_WINTER_STAR:
			# A simple accent ring around the plaza center (21,13-14) — same
			# handful of cells reused for the three non-sunfire festivals
			# (sowing/harvest/winter star don't call for distinct decor props
			# in the bible beyond "colored tile accents").
			return [Vector2i(20, 13), Vector2i(22, 13), Vector2i(20, 14), Vector2i(22, 14)]
		ID_SUNFIRE:
			# Bonfire decor at plaza center (bible: "Rosa's bonfire (decor)").
			return [Vector2i(21, 13), Vector2i(21, 14)]
		_:
			return []


## ---- Marta's shop-during-festival gate ----

static func shop_closed_for_festival(hour: int) -> bool:
	## Bible: "Marta's store choice omitted during festival hours (she's at
	## the plaza)". Uses the SAME hour-window is_npc_at_festival() would
	## apply to her (no Willow-style early-leave exception for Marta).
	return is_npc_at_festival("marta", hour)


## ---- Harvest Fair contest ----

static func contest_tier(sell_price: int) -> String:
	## "1st"/"2nd"/"participation" per the bible's value thresholds.
	if sell_price >= CONTEST_FIRST_MIN_VALUE:
		return "1st"
	if sell_price >= CONTEST_SECOND_MIN_VALUE:
		return "2nd"
	return "participation"


static func contest_gold_for_tier(tier: String) -> int:
	match tier:
		"1st": return CONTEST_FIRST_GOLD
		"2nd": return CONTEST_SECOND_GOLD
		_: return CONTEST_PARTICIPATION_GOLD


static func has_entered_contest_this_year(blob: Dictionary, year: int) -> bool:
	return int(blob.get("contest_year", -1)) == year


static func record_contest_entry(blob: Dictionary, year: int) -> Dictionary:
	var out := blob.duplicate(true)
	out["contest_year"] = year
	return out


## ---- Winter Star secret-gift assignment ----

static func winter_star_target(year: int, npc_ids: Array) -> String:
	## Deterministic pick seeded by year (bible: "assign secret-gift target =
	## deterministic pick seeded by year (document)"). A plain modulo over
	## the SORTED npc id list keeps this reproducible across a save's
	## lifetime (same year always resolves to the same NPC) without needing
	## to persist the pick itself — the journal/gift-check can recompute it
	## from `year` alone every time.
	if npc_ids.is_empty():
		return ""
	var sorted_ids: Array = npc_ids.duplicate()
	sorted_ids.sort()
	var idx: int = year % sorted_ids.size()
	return String(sorted_ids[idx])


static func winter_star_plaza_gifter(year: int, npc_ids: Array) -> String:
	## The NPC who hands the PLAYER a gift at the plaza — bible: "one
	## random-but-seeded NPC" distinct from the secret-gift TARGET (giving
	## the same NPC both roles would mean gifting yourself), so this offsets
	## the target's index by 1 (mod list size) for a different, still
	## deterministic pick.
	if npc_ids.is_empty():
		return ""
	var sorted_ids: Array = npc_ids.duplicate()
	sorted_ids.sort()
	if sorted_ids.size() == 1:
		return String(sorted_ids[0])
	var target := winter_star_target(year, npc_ids)
	var target_idx := sorted_ids.find(target)
	var gifter_idx := (target_idx + 1) % sorted_ids.size()
	return String(sorted_ids[gifter_idx])
