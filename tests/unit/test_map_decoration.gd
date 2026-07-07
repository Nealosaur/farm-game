extends GutTest
## LOOK V3: MapDecoration's deterministic scatter-decoration pass. Pure-logic
## coverage (no live tree needed for decorated_cells/decal_for — see class
## doc's seed rule), plus one TileMapLayer-building smoke test.


func test_decorated_cells_is_deterministic_across_calls() -> void:
	var candidates: Array = []
	for y in 20:
		for x in 20:
			candidates.append(Vector2i(x, y))
	var a := MapDecoration.decorated_cells(candidates, 5)
	var b := MapDecoration.decorated_cells(candidates, 5)
	assert_eq(a, b, "same candidates+salt must always decorate the same cells")


func test_decorated_cells_density_is_within_the_5_to_8_percent_contract() -> void:
	var candidates: Array = []
	for y in 60:
		for x in 60:
			candidates.append(Vector2i(x, y))
	var decorated := MapDecoration.decorated_cells(candidates, 0)
	var ratio := float(decorated.size()) / float(candidates.size())
	assert_between(ratio, 0.03, 0.10, "expected roughly 5-8%% of eligible cells decorated, got %f" % ratio)


func test_decorated_cells_never_exceeds_candidates() -> void:
	var candidates: Array = []
	for y in 40:
		for x in 40:
			candidates.append(Vector2i(x, y))
	var decorated := MapDecoration.decorated_cells(candidates, 0)
	assert_lte(decorated.size(), candidates.size())
	assert_gt(decorated.size(), 0, "expected at least one decorated cell in a 40x40 sample")
	for cell: Vector2i in decorated:
		assert_true(cell in candidates)


func test_different_salts_can_decorate_different_cells() -> void:
	## Not a strict requirement that EVERY cell differs, but two different
	## salts across a large sample should not produce the exact same set —
	## otherwise the salt parameter would be dead code.
	var candidates: Array = []
	for y in 30:
		for x in 30:
			candidates.append(Vector2i(x, y))
	var a := MapDecoration.decorated_cells(candidates, 0)
	var b := MapDecoration.decorated_cells(candidates, 1)
	assert_ne(a, b, "different salts should not always decorate identically")


func test_decal_for_is_deterministic_and_a_known_decal_name() -> void:
	var cell := Vector2i(7, 3)
	var name_a := MapDecoration.decal_for(cell, 0)
	var name_b := MapDecoration.decal_for(cell, 0)
	assert_eq(name_a, name_b)
	assert_true(MapDecoration.DECAL_WEIGHTS.has(name_a))


func test_build_layer_only_paints_decorated_cells() -> void:
	var built := MapBuilder.build_tileset()
	var candidates: Array = []
	for y in 16:
		for x in 16:
			candidates.append(Vector2i(x, y))
	var layer := MapDecoration.build_layer(built.tileset, built.ids, candidates, 0)
	add_child_autofree(layer)
	var decorated := MapDecoration.decorated_cells(candidates, 0)
	var painted := 0
	for cell: Vector2i in candidates:
		if layer.get_cell_source_id(cell) != -1:
			painted += 1
	assert_eq(painted, decorated.size())


func test_build_layer_respects_empty_candidates() -> void:
	var built := MapBuilder.build_tileset()
	var layer := MapDecoration.build_layer(built.tileset, built.ids, [], 0)
	add_child_autofree(layer)
	assert_eq(layer.get_used_cells().size(), 0)
