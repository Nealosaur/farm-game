extends GutTest
## World Stride C: registry placement sanity for all 8 NPCs — every
## characters.md schedule block (+ rain override + festival cell) resolves
## to a real, walkable cell on the map NPCRegistry says they're on. Mirrors
## test_town_npc_integration.gd's spot-checks for Marta, generalized across
## the roster via NPCFactory. Pure data checks (NPCRegistry.cell_for/map_for
## against each factory's build()) — no scene tree needed except for the
## "is the target map's layout actually walkable there" cross-check.

const ALL_HOURS_BY_BLOCK := {
	"6-9": 7, "9-12": 10, "12-17": 14, "17-20": 18, "20-2": 21,
}

var _map_layouts := {}  # map_id -> PackedStringArray, lazily built


func _layout_for(map_id: String) -> PackedStringArray:
	if _map_layouts.has(map_id):
		return _map_layouts[map_id]
	var script_path := "res://scripts/maps/%s.gd" % map_id
	var m: Node2D = (load(script_path) as GDScript).new()
	var rows: PackedStringArray = m._layout()
	m.free()
	_map_layouts[map_id] = rows
	return rows


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func _is_walkable(map_id: String, cell: Vector2i) -> bool:
	var ch := _char_at(_layout_for(map_id), cell)
	return ch == "G" or ch == "D" or ch == "S" or ch == "P" or ch == "A"


func test_every_npc_has_a_walkable_cell_for_every_schedule_block() -> void:
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		for block: String in NPCRegistry.BLOCKS:
			var hour: int = ALL_HOURS_BY_BLOCK[block]
			if not NPCRegistry.is_present(data, hour, false, false):
				continue  # some NPCs have no entry for some blocks — nothing to check
			var cell := NPCRegistry.cell_for(data, hour, false, false)
			var map_id := NPCRegistry.map_for(data, hour, false, false)
			assert_true(_is_walkable(map_id, cell),
				"%s block %s: cell %s on map '%s' must be walkable" % [npc_id, block, cell, map_id])


func test_every_npc_has_a_walkable_cell_for_every_rain_override() -> void:
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		for block: String in NPCRegistry.BLOCKS:
			var hour: int = ALL_HOURS_BY_BLOCK[block]
			if not NPCRegistry.is_present(data, hour, true, false):
				continue
			var cell := NPCRegistry.cell_for(data, hour, true, false)
			var map_id := NPCRegistry.map_for(data, hour, true, false)
			assert_true(_is_walkable(map_id, cell),
				"%s rain block %s: cell %s on map '%s' must be walkable" % [npc_id, block, cell, map_id])


func test_every_npc_festival_cell_is_walkable_on_town() -> void:
	## Every NPC's festival_cell is documented as a town-plaza location
	## (bible: festivals happen "on the plaza"). Willow's festival cell is
	## also on town per her characters.md entry ("plaza, at the very edge").
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		if data.festival_cell == Vector2i(-1, -1):
			continue
		assert_true(_is_walkable("town", data.festival_cell),
			"%s festival cell %s must be walkable on town" % [npc_id, data.festival_cell])


func test_every_npc_registered_in_npc_factory_matches_journal_roster() -> void:
	## NPCFactory.ALL_IDS and Journal.NPCS must agree on the roster (8 ids) —
	## a mismatch would mean the SOCIAL tab silently omits (or duplicates) an
	## NPC that map scenes still instance.
	assert_eq(NPCFactory.ALL_IDS.size(), 8, "eight registered NPCs total")
	var journal_ids: Array[String] = []
	for path: String in Journal.NPCS:
		var factory: GDScript = load(path)
		var data: NPCData = factory.build()
		journal_ids.append(data.id)
	for npc_id: String in NPCFactory.ALL_IDS:
		assert_true(npc_id in journal_ids, "%s must be registered in Journal.NPCS" % npc_id)
	assert_eq(journal_ids.size(), NPCFactory.ALL_IDS.size(), "Journal roster size must match NPCFactory")


func test_shopkeeping_npcs_are_placed_inside_their_own_building_on_town() -> void:
	## Generic walkability (any G/D/S/P/A tile) isn't enough to catch an NPC
	## whose cell is walkable but sits in the WRONG building (e.g. a stale
	## cell left over from an earlier town.gd layout revision) — cross-check
	## against town.gd's own Rect2i building footprints directly.
	var town: Node2D = (load("res://scripts/maps/town.gd") as GDScript).new()
	var checks := [
		["marta", NPCRegistry.BLOCK_9_12, town.STORE_FLOOR],
		["sten", NPCRegistry.BLOCK_9_12, town.SMITHY_FLOOR],
		["bram", NPCRegistry.BLOCK_9_12, town.CLINIC_FLOOR],
	]
	for check: Array in checks:
		var npc_id: String = check[0]
		var block: String = check[1]
		var rect: Rect2i = check[2]
		var data := NPCFactory.build_data(npc_id)
		var cell: Vector2i = data.schedule[block]
		assert_true(rect.has_point(cell),
			"%s's %s cell %s must sit inside its building footprint %s" % [npc_id, block, cell, rect])
	town.free()


func test_garrick_farm_morning_blocks_resolve_to_farm_map() -> void:
	var data := NPCFactory.build_data("garrick")
	assert_eq(NPCRegistry.map_for(data, 7, false, false), "farm", "Garrick's 6-9 block is on the farm")
	assert_eq(NPCRegistry.map_for(data, 10, false, false), "farm", "Garrick's 9-12 block is on the farm")
	assert_eq(NPCRegistry.map_for(data, 14, false, false), "town", "Garrick's 12-17 block is in town")


func test_garrick_rain_moves_morning_blocks_to_saloon_in_town() -> void:
	var data := NPCFactory.build_data("garrick")
	assert_eq(NPCRegistry.map_for(data, 7, true, false), "town", "rain moves Garrick's morning block to town")
	assert_eq(NPCRegistry.cell_for(data, 7, true, false), GarrickData.CELL_SALOON)


func test_finn_beach_day_blocks_and_town_evening_blocks() -> void:
	var data := NPCFactory.build_data("finn")
	assert_eq(NPCRegistry.map_for(data, 7, false, false), "beach", "Finn's 6-9 block is on the beach")
	assert_eq(NPCRegistry.map_for(data, 10, false, false), "beach", "Finn's 9-12 block is on the beach")
	assert_eq(NPCRegistry.map_for(data, 18, false, false), "town", "Finn's 17-20 block is in town")
	assert_eq(NPCRegistry.map_for(data, 21, false, false), "town", "Finn's 20-2 block is in town")


func test_finn_rain_shelters_at_saloon_corner_only_for_the_afternoon_block() -> void:
	var data := NPCFactory.build_data("finn")
	assert_eq(NPCRegistry.cell_for(data, 14, true, false), FinnData.CELL_SALOON_CORNER)
	assert_eq(NPCRegistry.map_for(data, 14, true, false), "town", "rain shelter is in town, not the beach")
	# Morning/evening blocks are untouched by rain (bible: only 12-17 changes).
	assert_eq(NPCRegistry.map_for(data, 7, true, false), "beach")
	assert_eq(NPCRegistry.cell_for(data, 18, true, false), FinnData.CELL_PLAZA_FOUNTAIN)


func test_willow_home_map_is_riverwoods_for_every_ordinary_block() -> void:
	var data := NPCFactory.build_data("willow")
	for block: String in NPCRegistry.BLOCKS:
		var hour: int = ALL_HOURS_BY_BLOCK[block]
		assert_eq(NPCRegistry.map_for(data, hour, false, false), "riverwoods",
			"Willow's %s block must be on riverwoods" % block)


## ---- Alive Stride 1: walk-target footprint checks ----

## Two DOCUMENTED exceptions (see town.gd/riverwoods.gd's _solid_prop_rects
## doc notes): each building's own schedule cell doubles as that same prop's
## collision footprint, so those two specific (npc_id, cell) pairs are
## EXPECTED to sit inside a solid_prop_rects footprint — every OTHER cell for
## that same NPC (e.g. Marta's plaza bench, Willow's riverbank) must not.
const _DOCUMENTED_FOOTPRINT_QUIRKS := [
	["marta", "town", Vector2i(8, 13)],        # MartaData.CELL_COUNTER == town.gd SHOPKEEPER_CELL, inside the counter's footprint
	["willow", "riverwoods", Vector2i(6, 5)],  # WillowData.CELL_HUT == riverwoods.gd HUT_CELL, inside the hut's own footprint
]

var _map_grids := {}  # map_id -> PathGrid, lazily built (layout + solid_prop_rects)


func _grid_for(map_id: String) -> PathGrid:
	if _map_grids.has(map_id):
		return _map_grids[map_id]
	var script_path := "res://scripts/maps/%s.gd" % map_id
	var m: Node2D = (load(script_path) as GDScript).new()
	var rects: Array[Rect2i] = m._solid_prop_rects()
	var grid := PathGrid.build(m._layout(), rects)
	m.free()
	_map_grids[map_id] = grid
	return grid


func _is_documented_quirk(npc_id: String, map_id: String, cell: Vector2i) -> bool:
	for triple: Array in _DOCUMENTED_FOOTPRINT_QUIRKS:
		if triple[0] == npc_id and triple[1] == map_id and triple[2] == cell:
			return true
	return false


func test_no_npc_schedule_cell_sits_inside_a_solid_prop_footprint() -> void:
	## Extends the walkable-tile check above (test_every_npc_has_a_walkable_
	## cell_for_every_schedule_block) to also rule out the SOLID PROP
	## footprints (house/counter/hut) PathGrid marks non-walkable —
	## everything a walking NPC would actually need to path through or stand
	## on, not just the raw tile character.
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		for block: String in NPCRegistry.BLOCKS:
			var hour: int = ALL_HOURS_BY_BLOCK[block]
			if not NPCRegistry.is_present(data, hour, false, false):
				continue
			var cell := NPCRegistry.cell_for(data, hour, false, false)
			var map_id := NPCRegistry.map_for(data, hour, false, false)
			var grid := _grid_for(map_id)
			if _is_documented_quirk(npc_id, map_id, cell):
				assert_false(grid.is_walkable(cell),
					"%s's documented quirk cell %s on '%s' was expected to be solid — quirk may be stale" % [npc_id, cell, map_id])
				continue
			assert_true(grid.is_walkable(cell),
				"%s block %s: cell %s on map '%s' must not sit inside a solid prop footprint" % [npc_id, block, cell, map_id])


func test_no_npc_rain_cell_sits_inside_a_solid_prop_footprint() -> void:
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		for block: String in NPCRegistry.BLOCKS:
			var hour: int = ALL_HOURS_BY_BLOCK[block]
			if not NPCRegistry.is_present(data, hour, true, false):
				continue
			var cell := NPCRegistry.cell_for(data, hour, true, false)
			var map_id := NPCRegistry.map_for(data, hour, true, false)
			var grid := _grid_for(map_id)
			if _is_documented_quirk(npc_id, map_id, cell):
				continue
			assert_true(grid.is_walkable(cell),
				"%s rain block %s: cell %s on map '%s' must not sit inside a solid prop footprint" % [npc_id, block, cell, map_id])


func test_no_npc_festival_cell_sits_inside_a_solid_prop_footprint() -> void:
	var grid := _grid_for("town")  # every festival is on the plaza (FESTIVAL_MAP)
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		if data.festival_cell == Vector2i(-1, -1):
			continue
		assert_true(grid.is_walkable(data.festival_cell),
			"%s's festival cell %s must not sit inside a solid prop footprint on town" % [npc_id, data.festival_cell])


func test_no_npc_extra_schedule_cell_sits_inside_a_solid_prop_footprint() -> void:
	## Covers the priority-key proof entries (Sten's "winter", Finn's
	## "weekend") — every cell in every extra_schedules table must be as
	## walkable as an ordinary schedule cell. Both proof NPCs' extra cells
	## happen to live on "town"; resolved generically in case a future NPC's
	## extra table targets a different map via the {"map","cell"} shape.
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		for table_key: String in data.extra_schedules:
			var table: Dictionary = data.extra_schedules[table_key]
			for block: String in table:
				var raw = table[block]
				var cell: Vector2i = raw.get("cell", Vector2i(-1, -1)) if raw is Dictionary else raw
				var map_id: String = String(raw.get("map", data.home_map)) if raw is Dictionary else data.home_map
				var grid := _grid_for(map_id)
				if _is_documented_quirk(npc_id, map_id, cell):
					continue
				assert_true(grid.is_walkable(cell),
					"%s's extra_schedules['%s']['%s'] cell %s on '%s' must not sit inside a solid prop footprint" % [npc_id, table_key, block, cell, map_id])
