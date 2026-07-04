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
}

const SOLID := ["tile_wall", "tile_water"]

const CHAR_TILES := {
	"G": "tile_grass",
	"D": "tile_grass_dark",
	"S": "tile_stone_floor",
	"W": "tile_wall",
	"~": "tile_water",
	"P": "tile_path",
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
