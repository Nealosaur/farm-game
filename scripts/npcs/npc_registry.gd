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

const BLOCK_6_9 := "6-9"
const BLOCK_9_12 := "9-12"
const BLOCK_12_17 := "12-17"
const BLOCK_17_20 := "17-20"
const BLOCK_20_2 := "20-2"

const BLOCKS := [BLOCK_6_9, BLOCK_9_12, BLOCK_12_17, BLOCK_17_20, BLOCK_20_2]


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


static func cell_for(npc: NPCData, hour: int, is_raining: bool, is_festival: bool) -> Vector2i:
	## Precedence: festival > rain > normal block schedule. Returns
	## Vector2i(-1, -1) (matching NPCData.festival_cell's "unset" sentinel)
	## only if the NPC has no schedule entry at all for the resolved block —
	## callers should treat that as "NPC absent this block".
	##
	## Schedule entries may be a plain Vector2i (cell on npc.home_map) OR a
	## {"map": String, "cell": Vector2i} Dictionary (per-block map override,
	## e.g. Garrick's farm-side Delve entrance block) — this always returns
	## just the CELL half; callers that also need to know which map to check
	## use map_for() below with the same arguments.
	var raw = _raw_entry(npc, hour, is_raining, is_festival)
	if raw == null:
		return Vector2i(-1, -1)
	if raw is Dictionary:
		return raw.get("cell", Vector2i(-1, -1))
	return raw


static func map_for(npc: NPCData, hour: int, is_raining: bool, is_festival: bool) -> String:
	## Which map's build() should place this NPC for the resolved block/
	## weather/festival state — npc.home_map unless the entry is a per-block
	## {"map": ..., "cell": ...} override (see cell_for's doc).
	var raw = _raw_entry(npc, hour, is_raining, is_festival)
	if raw is Dictionary:
		return String(raw.get("map", npc.home_map))
	return npc.home_map


static func is_present(npc: NPCData, hour: int, is_raining: bool, is_festival: bool) -> bool:
	return cell_for(npc, hour, is_raining, is_festival) != Vector2i(-1, -1)


static func is_present_on_map(npc: NPCData, map_id: String, hour: int, is_raining: bool, is_festival: bool) -> bool:
	## Convenience for map scripts: is this NPC BOTH present this block AND
	## located on `map_id` specifically? Lets a map (e.g. farm.gd) query the
	## full registry without accidentally placing an NPC who belongs
	## elsewhere this block.
	if not is_present(npc, hour, is_raining, is_festival):
		return false
	return map_for(npc, hour, is_raining, is_festival) == map_id


static func _raw_entry(npc: NPCData, hour: int, is_raining: bool, is_festival: bool) -> Variant:
	if is_festival and npc.festival_cell != Vector2i(-1, -1):
		return npc.festival_cell
	var block := block_for(hour)
	if is_raining and npc.rain_schedule.has(block):
		return npc.rain_schedule[block]
	if npc.schedule.has(block):
		return npc.schedule[block]
	return null
