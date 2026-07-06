extends GutTest
## Alive Stride 1: PathGrid pathfinding sanity, both as pure unit logic and
## against the REAL town/riverwoods map layouts + prop footprints (mirrors
## test_town.gd's "load the script directly, no scene tree" convention).

func _town() -> Node2D:
	return (load("res://scripts/maps/town.gd") as GDScript).new()


func _riverwoods() -> Node2D:
	return (load("res://scripts/maps/riverwoods.gd") as GDScript).new()


## ---- pure unit logic ----

func test_find_path_routes_around_a_wall() -> void:
	var layout := PackedStringArray(["WWWWW", "WGGGW", "WGWGW", "WGGGW", "WWWWW"])
	var grid := PathGrid.build(layout)
	var path := grid.find_path(Vector2i(1, 1), Vector2i(3, 3))
	assert_false(path.is_empty(), "a path must exist around the single-wall obstacle")
	for cell: Vector2 in path:
		assert_false(Vector2i(cell) == Vector2i(2, 2), "path must never cross the solid wall cell")


func test_find_path_same_cell_returns_single_point() -> void:
	var layout := PackedStringArray(["WWW", "WGW", "WWW"])
	var grid := PathGrid.build(layout)
	var path := grid.find_path(Vector2i(1, 1), Vector2i(1, 1))
	assert_eq(path.size(), 1)
	assert_eq(Vector2i(path[0]), Vector2i(1, 1))


func test_find_path_to_solid_cell_is_empty() -> void:
	var layout := PackedStringArray(["WWW", "WGW", "WWW"])
	var grid := PathGrid.build(layout)
	assert_true(grid.find_path(Vector2i(1, 1), Vector2i(0, 0)).is_empty(), "wall target must be unreachable")


func test_find_path_from_solid_cell_is_empty() -> void:
	var layout := PackedStringArray(["WWW", "WGW", "WWW"])
	var grid := PathGrid.build(layout)
	assert_true(grid.find_path(Vector2i(0, 0), Vector2i(1, 1)).is_empty(), "wall origin must be unreachable")


func test_solid_rects_block_pathing_even_over_a_walkable_tile() -> void:
	var layout := PackedStringArray(["WWWWW", "WGGGW", "WGGGW", "WGGGW", "WGGGW", "WWWWW"])
	# A prop wall down the middle column, rows 1-2 only — row 3 stays open as
	# a gap so the far side is still reachable (a FULL-height wall would make
	# the split map genuinely disjoint, which isn't what this test is about).
	var solid_rects: Array[Rect2i] = [Rect2i(2, 1, 1, 2)]
	var grid := PathGrid.build(layout, solid_rects)
	assert_false(grid.is_walkable(Vector2i(2, 1)), "a solid_rects cell must be non-walkable even though its tile is 'G'")
	var path := grid.find_path(Vector2i(1, 1), Vector2i(3, 1))
	assert_false(path.is_empty(), "still reachable around the prop rect via the row-3 gap")
	for cell: Vector2 in path:
		var c := Vector2i(cell)
		assert_false(c.x == 2 and c.y >= 1 and c.y <= 2,
			"path must avoid every cell in the prop's solid_rects footprint")


func test_diagonal_movement_is_never_used() -> void:
	## Every step in a returned path must be purely cardinal (exactly one of
	## dx/dy is +-1, the other 0) — proves DIAGONAL_MODE_NEVER is honored.
	var layout := PackedStringArray(["WWWWWW", "WGGGGW", "WGGGGW", "WGGGGW", "WWWWWW"])
	var grid := PathGrid.build(layout)
	var path := grid.find_path(Vector2i(1, 1), Vector2i(4, 3))
	assert_false(path.is_empty())
	for i in range(path.size() - 1):
		var a := Vector2i(path[i])
		var b := Vector2i(path[i + 1])
		var delta := b - a
		var manhattan := absi(delta.x) + absi(delta.y)
		assert_eq(manhattan, 1, "step from %s to %s must be a single cardinal move" % [a, b])


## ---- against the real town map ----

func test_town_store_to_plaza_is_reachable() -> void:
	var t := _town()
	var grid := PathGrid.build(t._layout(), t._solid_prop_rects())
	# Sten's smithy -> saloon transition (no solid-prop overlap, see
	# town.gd's _solid_prop_rects doc note re: Marta's counter quirk).
	var path := grid.find_path(StenData.CELL_SMITHY, StenData.CELL_SALOON)
	assert_false(path.is_empty(), "Sten's smithy->saloon path must exist on the real town layout")
	t.free()


func test_town_path_avoids_the_house_prop_footprint() -> void:
	var t := _town()
	var grid := PathGrid.build(t._layout(), t._solid_prop_rects())
	var house_rect := Rect2i(t.HOUSE_DECOR_CELL, Vector2i(3, 3))
	assert_false(grid.is_walkable(t.HOUSE_DECOR_CELL + Vector2i(1, 1)),
		"the house's own footprint center cell must be solid")
	var path := grid.find_path(Vector2i(3, 20), Vector2i(3, 27))
	assert_false(path.is_empty(), "a path around the house prop must still exist")
	for cell: Vector2 in path:
		assert_false(house_rect.has_point(Vector2i(cell)), "path must route around the house footprint, not through it")
	t.free()


func test_town_counter_cell_is_solid_and_unreachable_documented_quirk() -> void:
	## See town.gd's _solid_prop_rects doc: the counter's non-tile-aligned
	## collision shape spans Marta's own SHOPKEEPER_CELL, so her counter
	## cell registers solid — an explicit, documented fallback-to-teleport
	## case rather than a bug.
	var t := _town()
	var grid := PathGrid.build(t._layout(), t._solid_prop_rects())
	assert_false(grid.is_walkable(t.SHOPKEEPER_CELL))
	assert_true(grid.find_path(t.SHOPKEEPER_CELL, MartaData.CELL_PLAZA_BENCH).is_empty())
	t.free()


func test_riverwoods_river_band_is_unreachable_from_the_hut() -> void:
	## Water-locked cell example (contract): a river cell NOT on the crossing
	## rows must be unreachable from Willow's hut.
	var rw := _riverwoods()
	var grid := PathGrid.build(rw._layout(), rw._solid_prop_rects())
	var river_cell := Vector2i(rw.RIVER_X, 5)  # row 5 is outside CROSSING_Y_START(10)..CROSSING_Y_END(12)
	assert_false(grid.is_walkable(river_cell), "a non-crossing river cell must be solid water")
	var path := grid.find_path(WillowData.CELL_HUT, river_cell)
	assert_true(path.is_empty(), "the hut must not be able to path into solid water")
	rw.free()


func test_riverwoods_riverbank_to_forest_path_is_reachable() -> void:
	## Willow's 9-12 (riverbank) -> 12-17 (forest path) transition — her
	## OTHER schedule transitions involving CELL_HUT hit the same documented
	## quirk as Marta's counter (see below): CELL_HUT (6,5) IS the hut
	## footprint's own top-left corner (riverwoods.gd's HUT_CELL doubles as
	## both), so it registers solid and always falls back to teleport.
	var rw := _riverwoods()
	var grid := PathGrid.build(rw._layout(), rw._solid_prop_rects())
	var path := grid.find_path(WillowData.CELL_RIVERBANK, WillowData.CELL_FOREST_PATH)
	assert_false(path.is_empty(), "Willow's riverbank->forest-path schedule transition must be walkable")
	rw.free()


func test_riverwoods_hut_cell_is_solid_documented_quirk() -> void:
	## Same family as town's counter quirk (test_town_counter_cell_is_solid_
	## and_unreachable_documented_quirk above): Willow's CELL_HUT cell sits
	## inside her own hut's collision footprint, so any transition touching
	## it always falls back to teleport rather than walking.
	var rw := _riverwoods()
	var grid := PathGrid.build(rw._layout(), rw._solid_prop_rects())
	assert_false(grid.is_walkable(WillowData.CELL_HUT))
	assert_true(grid.find_path(WillowData.CELL_HUT, WillowData.CELL_RIVERBANK).is_empty())
	rw.free()
