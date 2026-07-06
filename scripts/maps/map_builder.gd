class_name MapBuilder
extends RefCounted
## Builds a TileSet at runtime from placeholder PNGs and fills TileMapLayers
## from ASCII rows. When real tilesets arrive, this is replaced by authored
## TileSet resources — map layouts stay the same.

const TILE := 16

const TILE_TEXTURES := {
	"tile_grass": "res://assets/placeholder/tile_grass.png",
	"tile_grass_dark": "res://assets/placeholder/tile_grass_dark.png",
	"tile_soil_tilled": "res://assets/placeholder/tile_soil_tilled.png",
	"tile_soil_watered": "res://assets/placeholder/tile_soil_watered.png",
	"tile_stone_floor": "res://assets/placeholder/tile_stone_floor.png",
	"tile_wall": "res://assets/placeholder/tile_wall.png",
	"tile_water": "res://assets/placeholder/tile_water.png",
	"tile_path": "res://assets/placeholder/tile_path.png",
	"tile_sand": "res://assets/placeholder/tile_sand.png",
}

const SOLID := ["tile_wall", "tile_water"]

const CHAR_TILES := {
	"G": "tile_grass",
	"D": "tile_grass_dark",
	"S": "tile_stone_floor",
	"W": "tile_wall",
	"~": "tile_water",
	"P": "tile_path",
	"A": "tile_sand",
}


static func build_tileset() -> Dictionary:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var ids := {}
	for tile_name: String in TILE_TEXTURES:
		var src := TileSetAtlasSource.new()
		src.texture = load(TILE_TEXTURES[tile_name])
		src.texture_region_size = Vector2i(TILE, TILE)
		# ORDER MATTERS: the source must be added to the TileSet BEFORE
		# create_tile(), or TileData won't see the physics layer and
		# add_collision_polygon errors with "physics.size() = 0" (Godot 4.6).
		ids[tile_name] = ts.add_source(src)
		src.create_tile(Vector2i.ZERO)
		if tile_name in SOLID:
			var td := src.get_tile_data(Vector2i.ZERO, 0)
			td.add_collision_polygon(0)
			var h := TILE / 2.0
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
			]))
	return {"tileset": ts, "ids": ids}


static func fill_layer(layer: TileMapLayer, rows: PackedStringArray, ids: Dictionary) -> void:
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			if CHAR_TILES.has(ch):
				layer.set_cell(Vector2i(x, y), ids[CHAR_TILES[ch]], Vector2i.ZERO)


static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i((pos / float(TILE)).floor())


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE / 2.0, TILE / 2.0)


static func solid_rect_for(center_px: Vector2, size_px: Vector2) -> Rect2i:
	## Alive Stride 1: converts a StaticBody2D-style centered collision box
	## (position in PIXELS, RectangleShape2D.size in PIXELS) into the Rect2i
	## of grid CELLS it overlaps — used by map scripts to feed PathGrid.build()
	## the same prop footprints (house/counter/hut/boat-shed/notice-board)
	## their own _add_props() already gives real collision to, so pathfinding
	## routes around exactly what the player's body already collides with.
	var top_left := center_px - size_px / 2.0
	var bottom_right := center_px + size_px / 2.0
	var start := cell_of(top_left)
	# Subtract an epsilon before flooring the far edge so an exact multiple of
	# TILE (e.g. a 32px-wide box starting on a tile boundary) doesn't pull in
	# one extra empty cell past the box's true edge.
	var end := cell_of(bottom_right - Vector2(0.01, 0.01))
	return Rect2i(start, end - start + Vector2i.ONE)
