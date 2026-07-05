extends GutTest
## Town layout sanity, mirroring test_dungeon_floors.gd's checks for the
## dungeon floors and farm: layout is rectangular with real floor, spawns are
## walkable and off the portal tile, the portal cell is walkable and its
## target scene/sprite exist. town.gd is a plain Node2D (not a DungeonFloor
## subclass, like farm.gd), so these are read directly off the script.


func _town_instance() -> Node2D:
	return (load("res://scripts/maps/town.gd") as GDScript).new()


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func test_layout_is_rectangular_with_floor() -> void:
	var t := _town_instance()
	var rows: PackedStringArray = t._layout()
	assert_gt(rows.size(), 0, "town has rows")
	var width := rows[0].length()
	var walkable := 0
	for row in rows:
		assert_eq(row.length(), width, "town rows must be rectangular")
		walkable += row.count("S") + row.count("P") + row.count("G")
	assert_gt(walkable, 0, "town needs walkable tiles")
	t.free()


func test_spawns_walkable_and_off_portal_tile() -> void:
	var t := _town_instance()
	var rows: PackedStringArray = t._layout()
	assert_true(t.SPAWNS.has("default"), "town needs a default spawn")
	assert_true(t.SPAWNS.has("entrance"), "town needs an entrance spawn")
	for spawn_name: String in t.SPAWNS:
		var cell: Vector2i = t.SPAWNS[spawn_name]
		var ch := _char_at(rows, cell)
		assert_true(ch == "S" or ch == "P" or ch == "G",
			"town spawn '%s' at %s must be walkable (got '%s')" % [spawn_name, cell, ch])
		assert_ne(cell, t.FARM_PORTAL_CELL,
			"town spawn '%s' must not sit on the farm portal tile" % spawn_name)
	t.free()


func test_farm_portal_cell_walkable_and_target_exists() -> void:
	var t := _town_instance()
	var rows: PackedStringArray = t._layout()
	var ch := _char_at(rows, t.FARM_PORTAL_CELL)
	assert_true(ch == "S" or ch == "P" or ch == "G", "farm portal tile must be walkable")
	assert_true(ResourceLoader.exists("res://scenes/maps/farm.tscn"))
	t.free()


func test_shop_fixtures_sit_on_stone_floor() -> void:
	var t := _town_instance()
	var rows: PackedStringArray = t._layout()
	assert_eq(_char_at(rows, t.COUNTER_CELL), "S", "counter must sit on stone floor")
	assert_eq(_char_at(rows, t.SHOPKEEPER_CELL), "S", "shopkeeper must stand on stone floor")
	t.free()


func test_farm_has_matching_west_portal_back_to_town() -> void:
	var farm: Node2D = (load("res://scripts/maps/farm.gd") as GDScript).new()
	assert_true(farm.SPAWNS.has("from_town"), "farm needs a 'from_town' spawn for the return trip")
	var rows: PackedStringArray = farm._layout()
	var cell: Vector2i = farm.TOWN_PORTAL_CELL
	var ch := _char_at(rows, cell)
	assert_true(ch == "G" or ch == "D" or ch == "P", "farm town-portal tile must be walkable")
	var from_town_cell: Vector2i = farm.SPAWNS["from_town"]
	assert_ne(from_town_cell, cell, "'from_town' spawn must not sit on the town portal tile")
	farm.free()
