extends GutTest
## Cheap correctness net over the hand-tuned floor configs: layouts are
## rectangular with real floor, and every spawn/portal/enemy cell lands on
## walkable stone — with spawn cells OFF portal tiles (anti-bounce rule 1,
## see portal.gd). Config methods are pure const reads, so floor scripts are
## instanced without entering the tree.

const FLOOR_SCRIPTS := [
	"res://scripts/maps/dungeon_1.gd",
	"res://scripts/maps/dungeon_2.gd",
	"res://scripts/maps/dungeon_3.gd",
]


func _floor_instance(path: String) -> DungeonFloor:
	return (load(path) as GDScript).new() as DungeonFloor


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


func test_layouts_are_rectangular_with_floor() -> void:
	for path: String in FLOOR_SCRIPTS:
		var f := _floor_instance(path)
		var rows := f._layout()
		assert_gt(rows.size(), 0, path + ": has rows")
		var width := rows[0].length()
		var stone := 0
		for row in rows:
			assert_eq(row.length(), width, path + ": rows must be rectangular")
			stone += row.count("S")
		assert_gt(stone, 0, path + ": needs at least one stone floor tile")
		f.free()


func test_floor_keys_are_unique_and_set() -> void:
	var seen := {}
	for path: String in FLOOR_SCRIPTS:
		var f := _floor_instance(path)
		var key := f._floor_key()
		assert_ne(key, "", path + ": floor key set")
		assert_ne(key, "dungeon_?", path + ": floor key overridden from base")
		assert_false(seen.has(key), path + ": floor key unique (kill ledger keys on it)")
		seen[key] = true
		f.free()


func test_spawn_cells_walkable_and_off_portal_tiles() -> void:
	for path: String in FLOOR_SCRIPTS:
		var f := _floor_instance(path)
		var rows := f._layout()
		var spawns := f._spawns()
		assert_true(spawns.has("default"), path + ": needs a default spawn")
		assert_true(spawns.has("entrance"), path + ": needs an entrance spawn")
		for spawn_name: String in spawns:
			var cell: Vector2i = spawns[spawn_name]
			assert_eq(_char_at(rows, cell), "S",
				"%s spawn '%s' at %s must be walkable" % [path, spawn_name, cell])
			for p: Dictionary in f._portals():
				assert_ne(cell, p["cell"],
					"%s spawn '%s' must not sit on portal tile %s" % [path, spawn_name, p["cell"]])
		f.free()


func test_portal_cells_walkable_and_targets_exist() -> void:
	for path: String in FLOOR_SCRIPTS:
		var f := _floor_instance(path)
		var rows := f._layout()
		for p: Dictionary in f._portals():
			assert_eq(_char_at(rows, p["cell"]), "S",
				"%s portal at %s must be walkable" % [path, p["cell"]])
			assert_true(ResourceLoader.exists(p["target_scene"]),
				"%s portal target scene missing: %s" % [path, p["target_scene"]])
			assert_true(ResourceLoader.exists(p["sprite"]),
				"%s portal sprite missing: %s" % [path, p["sprite"]])
		f.free()


func test_enemy_spawn_cells_walkable() -> void:
	for path: String in FLOOR_SCRIPTS:
		var f := _floor_instance(path)
		var rows := f._layout()
		for cfg: Dictionary in f._enemy_spawns():
			assert_eq(_char_at(rows, cfg["cell"]), "S",
				"%s enemy '%s' at %s must be walkable" % [path, cfg["id"], cfg["cell"]])
			assert_not_null(ItemDB.get_enemy(cfg["id"]),
				"%s enemy id '%s' must exist in ItemDB" % [path, cfg["id"]])
		f.free()


func test_floor3_boss_room_is_reserved_and_empty() -> void:
	var f := _floor_instance("res://scripts/maps/dungeon_3.gd")
	var rows := f._layout()
	assert_eq(_char_at(rows, f.BOSS_CELL), "S", "BOSS_CELL must be walkable")
	# Find the room rect containing BOSS_CELL and require no enemy inside it.
	var boss_rect := Rect2i()
	for r: Rect2i in f.FLOOR_RECTS:
		if r.has_point(f.BOSS_CELL):
			boss_rect = r
			break
	assert_gt(boss_rect.size.x * boss_rect.size.y, 80,
		"boss room should be a big open area")
	for cfg: Dictionary in f._enemy_spawns():
		assert_false(boss_rect.has_point(cfg["cell"]),
			"boss room must stay empty this stride (found %s at %s)" % [cfg["id"], cfg["cell"]])
	assert_eq(f._portals().size(), 1, "floor 3 has stairs up only — run seals at the boss room")
	f.free()


func test_farm_spawns_walkable_and_off_dungeon_portal() -> void:
	var farm: Node2D = (load("res://scripts/maps/farm.gd") as GDScript).new()
	var rows: PackedStringArray = farm._layout()
	for spawn_name: String in farm.SPAWNS:
		var cell: Vector2i = farm.SPAWNS[spawn_name]
		var ch := _char_at(rows, cell)
		assert_true(ch == "G" or ch == "D" or ch == "P",
			"farm spawn '%s' at %s must be walkable ground (got '%s')" % [spawn_name, cell, ch])
		assert_ne(cell, farm.DUNGEON_PORTAL_CELL,
			"farm spawn '%s' must not sit on the dungeon portal tile" % spawn_name)
	var portal_ch := _char_at(rows, farm.DUNGEON_PORTAL_CELL)
	assert_true(portal_ch == "G" or portal_ch == "D" or portal_ch == "P",
		"farm dungeon portal tile must be walkable")
	farm.free()
