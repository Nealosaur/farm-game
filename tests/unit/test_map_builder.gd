extends GutTest


func test_build_tileset_returns_ids_for_all_tiles() -> void:
	var built := MapBuilder.build_tileset()
	var ts: TileSet = built.tileset
	var ids: Dictionary = built.ids
	assert_not_null(ts)
	for tile_name in MapBuilder.TILE_TEXTURES:
		assert_true(ids.has(tile_name), tile_name + " missing id")
		assert_not_null(ts.get_source(ids[tile_name]))
	assert_eq(ts.tile_size, Vector2i(16, 16))


func test_fill_layer_places_cells() -> void:
	var built := MapBuilder.build_tileset()
	var layer := TileMapLayer.new()
	layer.tile_set = built.tileset
	add_child_autofree(layer)
	var rows := PackedStringArray(["WGW", "G~P"])
	MapBuilder.fill_layer(layer, rows, built.ids)
	assert_eq(layer.get_cell_source_id(Vector2i(0, 0)), built.ids["tile_wall"])
	# V3: tile_grass now has cosmetic variants (MapBuilder.VARIANTS), so a
	# grass cell's source id is whichever variant_for() deterministically
	# picks for THIS cell, not necessarily the plain base id — assert via the
	# same helper the map builder uses, rather than assuming index 0.
	assert_eq(layer.get_cell_source_id(Vector2i(1, 0)),
		MapBuilder.variant_for("tile_grass", Vector2i(1, 0), built.ids))
	assert_eq(layer.get_cell_source_id(Vector2i(1, 1)), built.ids["tile_water"])
	# tile_path has no registered variants (see MapBuilder.VARIANTS), so it
	# still always resolves to the plain base id.
	assert_eq(layer.get_cell_source_id(Vector2i(2, 1)), built.ids["tile_path"])


## ---- DEPTH stride: is_water_at (fishing's "facing water" gate) ----

func test_is_water_at_true_for_water_tile() -> void:
	var built := MapBuilder.build_tileset()
	var layer := TileMapLayer.new()
	layer.tile_set = built.tileset
	add_child_autofree(layer)
	MapBuilder.fill_layer(layer, PackedStringArray(["G~"]), built.ids)
	assert_true(MapBuilder.is_water_at(layer, Vector2i(1, 0)))


func test_is_water_at_false_for_non_water_tile() -> void:
	var built := MapBuilder.build_tileset()
	var layer := TileMapLayer.new()
	layer.tile_set = built.tileset
	add_child_autofree(layer)
	MapBuilder.fill_layer(layer, PackedStringArray(["G~"]), built.ids)
	assert_false(MapBuilder.is_water_at(layer, Vector2i(0, 0)))


func test_is_water_at_false_for_unset_cell() -> void:
	var built := MapBuilder.build_tileset()
	var layer := TileMapLayer.new()
	layer.tile_set = built.tileset
	add_child_autofree(layer)
	assert_false(MapBuilder.is_water_at(layer, Vector2i(99, 99)), "no cell placed here at all")


func test_is_water_at_false_for_null_ground() -> void:
	assert_false(MapBuilder.is_water_at(null, Vector2i(0, 0)))


func test_solid_tiles_have_collision() -> void:
	var built := MapBuilder.build_tileset()
	var src := built.tileset.get_source(built.ids["tile_wall"]) as TileSetAtlasSource
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	assert_gt(td.get_collision_polygons_count(0), 0)
	var grass_src := built.tileset.get_source(built.ids["tile_grass"]) as TileSetAtlasSource
	assert_eq(grass_src.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0), 0)


## ---- V3: tile variety (variant_for) ----

func test_variant_for_is_deterministic_across_calls() -> void:
	var built := MapBuilder.build_tileset()
	var a := MapBuilder.variant_for("tile_grass", Vector2i(5, 9), built.ids)
	var b := MapBuilder.variant_for("tile_grass", Vector2i(5, 9), built.ids)
	assert_eq(a, b, "same (base, cell) must always resolve to the same source id")


func test_variant_for_differs_across_some_cells() -> void:
	## Not EVERY cell needs to differ, but a grass field with real variety
	## must produce more than one distinct id across many cells — otherwise
	## the "variant" pool is dead code.
	var built := MapBuilder.build_tileset()
	var seen := {}
	for y in 12:
		for x in 12:
			seen[MapBuilder.variant_for("tile_grass", Vector2i(x, y), built.ids)] = true
	assert_gt(seen.size(), 1, "expected more than one grass variant across a 12x12 sample")


func test_variant_for_falls_back_to_base_when_no_variants_registered() -> void:
	var built := MapBuilder.build_tileset()
	# tile_path has no MapBuilder.VARIANTS entry — always the plain base id.
	for y in 5:
		for x in 5:
			assert_eq(MapBuilder.variant_for("tile_path", Vector2i(x, y), built.ids),
				built.ids["tile_path"])


func test_variants_share_base_solidity() -> void:
	## Contract: variant tiles are a pure re-skin — same collision as their
	## base. tile_grass variants must stay non-solid (grass is walkable).
	var built := MapBuilder.build_tileset()
	var variant_ids: Array = built.ids["__variants__"]["tile_grass"]
	assert_gt(variant_ids.size(), 0, "expected at least one grass variant registered")
	for id: int in variant_ids:
		var src := built.tileset.get_source(id) as TileSetAtlasSource
		var td := src.get_tile_data(Vector2i.ZERO, 0)
		assert_eq(td.get_collision_polygons_count(0), 0, "grass variant must stay non-solid")
