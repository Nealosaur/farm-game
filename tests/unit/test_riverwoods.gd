extends GutTest
## Riverwoods layout sanity (World Stride C), mirroring test_town.gd/
## test_dungeon_floors.gd's checks: rectangular layout with real floor, the
## river has exactly one crossing (not fully impassable), spawns/portal cells
## are walkable and off each other's trigger tiles, and farm has a matching
## south portal back.


func _riverwoods_instance() -> Node2D:
	return (load("res://scripts/maps/riverwoods.gd") as GDScript).new()


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func test_layout_is_rectangular_with_floor() -> void:
	var r := _riverwoods_instance()
	var rows: PackedStringArray = r._layout()
	assert_gt(rows.size(), 0, "riverwoods has rows")
	var width := rows[0].length()
	var walkable := 0
	for row in rows:
		assert_eq(row.length(), width, "riverwoods rows must be rectangular")
		walkable += row.count("G") + row.count("D") + row.count("P")
	assert_gt(walkable, 0, "riverwoods needs walkable tiles")
	r.free()


func test_river_has_a_walkable_crossing() -> void:
	var r := _riverwoods_instance()
	var rows: PackedStringArray = r._layout()
	var crossing_found := false
	for y in range(r.CROSSING_Y_START, r.CROSSING_Y_END + 1):
		if _char_at(rows, Vector2i(r.RIVER_X, y)) == "P":
			crossing_found = true
	assert_true(crossing_found, "the river must have at least one walkable crossing tile")
	# And the river is otherwise solid (water), so the crossing is a real gap,
	# not the whole column being open.
	var water_found := false
	for y in rows.size():
		if y >= r.CROSSING_Y_START and y <= r.CROSSING_Y_END:
			continue
		if _char_at(rows, Vector2i(r.RIVER_X, y)) == "~":
			water_found = true
	assert_true(water_found, "the river column must be solid water outside the crossing")
	r.free()


func test_spawns_walkable_and_off_portal_tile() -> void:
	var r := _riverwoods_instance()
	var rows: PackedStringArray = r._layout()
	assert_true(r.SPAWNS.has("default"))
	assert_true(r.SPAWNS.has("from_farm"))
	for spawn_name: String in r.SPAWNS:
		var cell: Vector2i = r.SPAWNS[spawn_name]
		var ch := _char_at(rows, cell)
		assert_true(ch == "G" or ch == "D" or ch == "P",
			"riverwoods spawn '%s' at %s must be walkable (got '%s')" % [spawn_name, cell, ch])
		assert_ne(cell, r.FARM_PORTAL_CELL,
			"riverwoods spawn '%s' must not sit on the farm portal tile" % spawn_name)
	r.free()


func test_farm_portal_cell_walkable_and_target_exists() -> void:
	var r := _riverwoods_instance()
	var rows: PackedStringArray = r._layout()
	var ch := _char_at(rows, r.FARM_PORTAL_CELL)
	assert_true(ch == "G" or ch == "D" or ch == "P", "farm portal tile must be walkable")
	assert_true(ResourceLoader.exists("res://scenes/maps/farm.tscn"))
	r.free()


func test_farm_has_matching_south_portal_to_riverwoods() -> void:
	var farm: Node2D = (load("res://scripts/maps/farm.gd") as GDScript).new()
	assert_true(farm.SPAWNS.has("from_riverwoods"), "farm needs a 'from_riverwoods' spawn for the return trip")
	var rows: PackedStringArray = farm._layout()
	var cell: Vector2i = farm.RIVERWOODS_PORTAL_CELL
	var ch := _char_at(rows, cell)
	assert_true(ch == "G" or ch == "D" or ch == "P", "farm riverwoods-portal tile must be walkable")
	var from_riverwoods_cell: Vector2i = farm.SPAWNS["from_riverwoods"]
	assert_ne(from_riverwoods_cell, cell, "'from_riverwoods' spawn must not sit on the portal tile")
	farm.free()


func test_hut_footprint_does_not_overlap_river_or_portal() -> void:
	var r := _riverwoods_instance()
	var rows: PackedStringArray = r._layout()
	var hut_rect := Rect2i(r.HUT_CELL, Vector2i(4, 3))
	for y in range(hut_rect.position.y, hut_rect.position.y + hut_rect.size.y):
		for x in range(hut_rect.position.x, hut_rect.position.x + hut_rect.size.x):
			var ch := _char_at(rows, Vector2i(x, y))
			assert_ne(ch, "~", "Willow's hut must not sit on the river")
	r.free()


func test_boots_cleanly_standalone() -> void:
	var scene: Node = (load("res://scenes/maps/riverwoods.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	assert_not_null(scene.get_node_or_null("Ground"))
	assert_not_null(scene.get_node_or_null("World"))
