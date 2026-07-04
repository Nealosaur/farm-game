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
	assert_eq(layer.get_cell_source_id(Vector2i(1, 0)), built.ids["tile_grass"])
	assert_eq(layer.get_cell_source_id(Vector2i(1, 1)), built.ids["tile_water"])
	assert_eq(layer.get_cell_source_id(Vector2i(2, 1)), built.ids["tile_path"])


func test_solid_tiles_have_collision() -> void:
	var built := MapBuilder.build_tileset()
	var src := built.tileset.get_source(built.ids["tile_wall"]) as TileSetAtlasSource
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	assert_gt(td.get_collision_polygons_count(0), 0)
	var grass_src := built.tileset.get_source(built.ids["tile_grass"]) as TileSetAtlasSource
	assert_eq(grass_src.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0), 0)
