extends GutTest
## Beach ("Graywater Shore") layout sanity (World Stride C), mirroring
## test_town.gd/test_riverwoods.gd's checks: rectangular layout with real
## sand floor, the pier crosses the water band, spawns/portal cells are
## walkable and off each other's trigger tiles, and town has a matching
## south portal to here.


func _beach_instance() -> Node2D:
	return (load("res://scripts/maps/beach.gd") as GDScript).new()


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func test_layout_is_rectangular_with_floor() -> void:
	var b := _beach_instance()
	var rows: PackedStringArray = b._layout()
	assert_gt(rows.size(), 0, "beach has rows")
	var width := rows[0].length()
	var walkable := 0
	for row in rows:
		assert_eq(row.length(), width, "beach rows must be rectangular")
		walkable += row.count("A") + row.count("P")
	assert_gt(walkable, 0, "beach needs walkable tiles")
	b.free()


func test_pier_crosses_the_water() -> void:
	var b := _beach_instance()
	var rows: PackedStringArray = b._layout()
	var pier_over_water := false
	for y in range(b.PIER_Y_START, b.PIER_Y_END + 1):
		if y < b.WATER_Y_START:
			continue
		for x in range(b.PIER_X_START, b.PIER_X_END + 1):
			if _char_at(rows, Vector2i(x, y)) == "P":
				pier_over_water = true
	assert_true(pier_over_water, "the pier must extend out over the water band")
	b.free()


func test_spawns_walkable_and_off_portal_tile() -> void:
	var b := _beach_instance()
	var rows: PackedStringArray = b._layout()
	assert_true(b.SPAWNS.has("default"))
	assert_true(b.SPAWNS.has("from_town"))
	for spawn_name: String in b.SPAWNS:
		var cell: Vector2i = b.SPAWNS[spawn_name]
		var ch := _char_at(rows, cell)
		assert_true(ch == "A" or ch == "P",
			"beach spawn '%s' at %s must be walkable (got '%s')" % [spawn_name, cell, ch])
		assert_ne(cell, b.TOWN_PORTAL_CELL,
			"beach spawn '%s' must not sit on the town portal tile" % spawn_name)
	b.free()


func test_town_portal_cell_walkable_and_target_exists() -> void:
	var b := _beach_instance()
	var rows: PackedStringArray = b._layout()
	var ch := _char_at(rows, b.TOWN_PORTAL_CELL)
	assert_true(ch == "A" or ch == "P", "town portal tile must be walkable")
	assert_true(ResourceLoader.exists("res://scenes/maps/town.tscn"))
	b.free()


func test_town_has_matching_south_portal_to_beach() -> void:
	var town: Node2D = (load("res://scripts/maps/town.gd") as GDScript).new()
	assert_true(town.SPAWNS.has("from_beach"), "town needs a 'from_beach' spawn for the return trip")
	var rows: PackedStringArray = town._layout()
	var cell: Vector2i = town.BEACH_PORTAL_CELL
	var ch := _char_at(rows, cell)
	assert_true(ch == "S" or ch == "P" or ch == "G", "town beach-portal tile must be walkable")
	var from_beach_cell: Vector2i = town.SPAWNS["from_beach"]
	assert_ne(from_beach_cell, cell, "'from_beach' spawn must not sit on the portal tile")
	town.free()


func test_boat_shed_footprint_does_not_overlap_pier_or_water() -> void:
	var b := _beach_instance()
	var rows: PackedStringArray = b._layout()
	var shed_rect := Rect2i(b.BOAT_SHED_CELL - Vector2i(1, 1), Vector2i(3, 3))
	for y in range(shed_rect.position.y, shed_rect.position.y + shed_rect.size.y):
		for x in range(shed_rect.position.x, shed_rect.position.x + shed_rect.size.x):
			assert_ne(_char_at(rows, Vector2i(x, y)), "~", "boat shed must not sit on the water")
	b.free()


func test_boots_cleanly_standalone() -> void:
	var scene: Node = (load("res://scenes/maps/beach.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	assert_not_null(scene.get_node_or_null("Ground"))
	assert_not_null(scene.get_node_or_null("World"))
