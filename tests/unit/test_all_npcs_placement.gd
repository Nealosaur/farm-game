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
