class_name NPCRegistry
extends RefCounted
## Central "who is where, right now" lookup (World Stride B contract).
## Pure static logic over NPCData — no autoload/scene-tree access — so it's
## independently testable; map scenes call block_for()/cell_for() at build
## time and again whenever EventBus.time_ticked crosses a block boundary
## (see npc.gd._on_time_ticked).
##
## Blocks (bible, fixed): 6-9, 9-12, 12-17, 17-20, 20-2. Bounds are
## HALF-OPEN [start, end) in Clock hours, except the last block which wraps
## past midnight (20:00 up to but not including 2:00 the next calendar day —
## Clock's day runs 6:00-26:00, i.e. hour() never actually reaches 2 before
## end_day() rolls the date, but the block is named "20-2" per the bible and
## covers every hour from 20 through Clock's day-end).
##
## Standard this phase (bible): "block-teleport is the accepted standard" —
## NPCs jump straight to their new block's cell with no walking animation.
## Maps re-query on every block CHANGE, not every tick (see npc.gd).
##
## Alive Stride 1 adds WALKING on top of block-teleport (see npc.gd's walk
## controller) — cell RESOLUTION here is unchanged; only how an NPC gets to
## the resolved cell differs (walk vs. teleport) at the call site.
##
## Schedule key priority (Alive Stride 1 extension, data-compatible): a
## per-NPC schedule Dictionary MAY now carry extra top-level keys beyond the
## plain block table, checked for the CURRENT block in this order:
##   festival_cell (handled separately, above all of this) >
##   married-to-player farm schedule (Marriage M3, see below) >
##   rain_schedule (existing) >
##   "<season>_weekend" (season name lowercase, e.g. "winter_weekend") >
##   "weekend" >
##   "<season>" (e.g. "winter") >
##   schedule (default, existing)
## Every extra key is a block-keyed Dictionary with the SAME shape as
## `schedule` (block -> Vector2i or {"map","cell"}) and is entirely OPTIONAL —
## an NPCData with none of them set (every NPC shipped before this stride)
## resolves EXACTLY as before: rain_schedule then schedule. A season/weekend
## table need not cover every block; a block missing from it falls back
## further down the SAME priority chain (e.g. a "winter" table with only the
## 6-9 block set still falls back to `schedule` for 9-12 onward), not
## straight to `schedule` — see _raw_entry's ordered lookup below.
##
## Marriage M3 (docs/design/marriage.md §3: "spouse lives on the farm... gets
## a farm-map schedule... leaves their old town job"): once
## Romance.is_married_to(npc.id) is true, EVERY block for that NPC resolves to
## SPOUSE_FARM_SCHEDULE below instead of consulting rain/weekend/season/
## ordinary `schedule` at all — the spouse's whole former town routine is
## vacated while married (documented, bible-accepted: "acceptable this
## phase"). This is ONE generic template shared by all 5 candidates (bible:
## "keep it generic... per-spouse flavor cell optional") rather than a
## per-candidate table, since nothing about WHERE a spouse stands needs to
## vary by voice — their DIALOG does (see dialog_resolver.gd's spouse tier).
## Checked ahead of rain_schedule (a rainy day doesn't send your spouse back
## to their old town job) but still BELOW festival_cell (a spouse still
## attends the plaza festival like every other NPC, via their own
## festival_cell — Romance doesn't touch that).
##
## Weekend rule (bible: "day%7>=5", adapted for 1-based day_of_season): the
## 28-day month is 4 weeks of 7; days 6 and 7 of each week are the weekend.
## Concretely: (day_of_season - 1) % 7 in {5, 6} -> day_of_season in
## {6, 7, 13, 14, 21, 22, 28} (day 28's (28-1)%7 == 6, so the month's last
## day is a weekend day, not a stray 8th day). See is_weekend().

const BLOCK_6_9 := "6-9"
const BLOCK_9_12 := "9-12"
const BLOCK_12_17 := "12-17"
const BLOCK_17_20 := "17-20"
const BLOCK_20_2 := "20-2"

const BLOCKS := [BLOCK_6_9, BLOCK_9_12, BLOCK_12_17, BLOCK_17_20, BLOCK_20_2]

const SEASON_KEYS := ["spring", "summer", "fall", "winter"]  # matches Clock.SEASON_NAMES order, lowercased


static func block_for(hour: int) -> String:
	if hour >= 6 and hour < 9:
		return BLOCK_6_9
	if hour >= 9 and hour < 12:
		return BLOCK_9_12
	if hour >= 12 and hour < 17:
		return BLOCK_12_17
	if hour >= 17 and hour < 20:
		return BLOCK_17_20
	return BLOCK_20_2  # 20:00 through day-end, and the pre-6AM sliver if ever queried


## Sentinel meaning "derive from Clock" for the two new optional trailing
## params cell_for/map_for/is_present/is_present_on_map now accept — every
## call site written before Alive Stride 1 passes exactly 4 positional args
## and gets IDENTICAL behavior to before (season/day_of_season are only ever
## consulted for the "<season>_weekend"/"weekend"/"<season>" keys, which no
## pre-stride NPCData populates, so a stale/wrong derived value here can
## never change any existing call site's result). Tests that DO want to
## exercise the new keys pass season/day_of_season explicitly so the
## resolution stays pure or scene-tree-free.
const _UNSET := -1


static func cell_for(npc: NPCData, hour: int, is_raining: bool, is_festival: bool,
		season: int = _UNSET, day_of_season: int = _UNSET) -> Vector2i:
	## Precedence: festival > rain > "<season>_weekend" > "weekend" >
	## "<season>" > normal block schedule (see class doc for the full Alive
	## Stride 1 key list). Returns Vector2i(-1, -1) (matching
	## NPCData.festival_cell's "unset" sentinel) only if the NPC has no
	## schedule entry at all for the resolved block — callers should treat
	## that as "NPC absent this block".
	##
	## Schedule entries may be a plain Vector2i (cell on npc.home_map) OR a
	## {"map": String, "cell": Vector2i} Dictionary (per-block map override,
	## e.g. Garrick's farm-side Delve entrance block) — this always returns
	## just the CELL half; callers that also need to know which map to check
	## use map_for() below with the same arguments.
	var raw = _raw_entry(npc, hour, is_raining, is_festival, season, day_of_season)
	if raw == null:
		return Vector2i(-1, -1)
	if raw is Dictionary:
		return raw.get("cell", Vector2i(-1, -1))
	return raw


const FESTIVAL_MAP := "town"  # World Stride D: every festival is "on the plaza" (world-bible.md) — always the town map


static func map_for(npc: NPCData, hour: int, is_raining: bool, is_festival: bool,
		season: int = _UNSET, day_of_season: int = _UNSET) -> String:
	## Which map's build() should place this NPC for the resolved block/
	## weather/festival state — npc.home_map unless the entry is a per-block
	## {"map": ..., "cell": ...} override (see cell_for's doc), OR a plain
	## festival_cell hit (World Stride D: the plaza is ALWAYS on the town
	## map, regardless of the NPC's normal home_map — Willow's home_map is
	## "riverwoods", but her festival_cell places her on town's plaza like
	## every other NPC, not in the riverwoods).
	if is_festival and npc.festival_cell != Vector2i(-1, -1):
		return FESTIVAL_MAP
	var raw = _raw_entry(npc, hour, is_raining, is_festival, season, day_of_season)
	if raw is Dictionary:
		return String(raw.get("map", npc.home_map))
	return npc.home_map


static func is_present(npc: NPCData, hour: int, is_raining: bool, is_festival: bool,
		season: int = _UNSET, day_of_season: int = _UNSET) -> bool:
	return cell_for(npc, hour, is_raining, is_festival, season, day_of_season) != Vector2i(-1, -1)


static func is_present_on_map(npc: NPCData, map_id: String, hour: int, is_raining: bool, is_festival: bool,
		season: int = _UNSET, day_of_season: int = _UNSET) -> bool:
	## Convenience for map scripts: is this NPC BOTH present this block AND
	## located on `map_id` specifically? Lets a map (e.g. farm.gd) query the
	## full registry without accidentally placing an NPC who belongs
	## elsewhere this block.
	if not is_present(npc, hour, is_raining, is_festival, season, day_of_season):
		return false
	return map_for(npc, hour, is_raining, is_festival, season, day_of_season) == map_id


static func is_weekend(day_of_season: int) -> bool:
	## Bible: "weekend (day%7>=5)", adapted for Clock.day_of_season()'s
	## 1-based counting: the 28-day month is 4 weeks of 7; days 6 and 7 of
	## each week are the weekend. (day_of_season - 1) % 7 in {5, 6} ->
	## day_of_season in {6, 7, 13, 14, 21, 22, 28} for a 28-day month.
	var zero_based := (day_of_season - 1) % 7
	return zero_based == 5 or zero_based == 6


## Marriage M3: kitchen/porch/field-edge cells on the FARM map, one entry per
## block — reused verbatim for whichever of the 5 candidates is currently
## Romance.spouse() (bible: "keep it generic... any of the 5 spouses uses the
## same farm schedule template"). Cells chosen clear of every solid prop/
## portal/interactable rect on farm.gd (house x:4-6,y:4-6; kitchen (2,5); bed
## (8,6); bin (11,7); barn/pen x:25-33,y:1-7; TILLABLE x:24-37,y:10-19) — see
## farm.gd's own layout constants. Morning: kitchen-adjacent (near the stove);
## midday: porch (the path row right in front of the house, where the player
## naturally walks past); afternoon: field-edge (just outside the tillable
## rect's west border, a companionable "watching you farm" spot); evening/
## night: back to the porch/kitchen area, settling in for the night.
const SPOUSE_FARM_SCHEDULE := {
	BLOCK_6_9: {"map": "farm", "cell": Vector2i(3, 6)},    # kitchen-adjacent
	BLOCK_9_12: {"map": "farm", "cell": Vector2i(5, 7)},   # porch
	BLOCK_12_17: {"map": "farm", "cell": Vector2i(23, 12)}, # field-edge
	BLOCK_17_20: {"map": "farm", "cell": Vector2i(5, 7)},  # porch
	BLOCK_20_2: {"map": "farm", "cell": Vector2i(7, 6)},   # near the house, settled in for the night
}


static func _raw_entry(npc: NPCData, hour: int, is_raining: bool, is_festival: bool,
		season: int = _UNSET, day_of_season: int = _UNSET) -> Variant:
	if is_festival and npc.festival_cell != Vector2i(-1, -1):
		return npc.festival_cell
	var block := block_for(hour)
	if Romance.is_married_to(npc.id):
		# Marriage M3: while married, the spouse's ENTIRE schedule (every
		# block, every day) resolves to the shared farm template — no rain/
		# weekend/season table or their old `schedule` is consulted at all
		# (bible: "leaves their old town job's schedule... acceptable this
		# phase"). Returns null (absent) only if SPOUSE_FARM_SCHEDULE itself
		# is missing an entry for this block, which shouldn't happen since it
		# covers all 5 blocks — kept as a `.get()` rather than direct index
		# for defensive symmetry with every other lookup in this function.
		return SPOUSE_FARM_SCHEDULE.get(block, null)
	if is_raining and npc.rain_schedule.has(block):
		return npc.rain_schedule[block]

	var resolved_season := Clock.season() if season == _UNSET else season
	var resolved_day := Clock.day_of_season() if day_of_season == _UNSET else day_of_season
	var season_key: String = SEASON_KEYS[resolved_season] if resolved_season >= 0 and resolved_season < SEASON_KEYS.size() else ""

	if is_weekend(resolved_day) and season_key != "":
		var seasonal_weekend_key := "%s_weekend" % season_key
		var seasonal_weekend: Dictionary = npc.extra_schedules.get(seasonal_weekend_key, {})
		if seasonal_weekend.has(block):
			return seasonal_weekend[block]
	if is_weekend(resolved_day) and npc.extra_schedules.get("weekend", {}).has(block):
		return npc.extra_schedules["weekend"][block]
	if season_key != "" and npc.extra_schedules.get(season_key, {}).has(block):
		return npc.extra_schedules[season_key][block]

	if npc.schedule.has(block):
		return npc.schedule[block]
	return null
