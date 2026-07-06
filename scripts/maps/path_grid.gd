class_name PathGrid
extends RefCounted
## Alive Stride 1: walkable-grid pathfinding service, one instance per map.
##
## Wraps an AStarGrid2D sized to the map's own tile dimensions. A cell is
## SOLID (non-walkable) if either:
##   - its Ground-layer tile is one of MapBuilder.SOLID ("tile_wall",
##     "tile_water"), read directly off the built PackedStringArray layout
##     via MapBuilder.CHAR_TILES (no live TileMapLayer query needed — every
##     map already derives its Ground layer from exactly this same
##     PackedStringArray, see town.gd/farm.gd/etc.'s _layout()), OR
##   - it falls inside a caller-supplied building/prop footprint Rect2i
##     (e.g. town.gd's STORE_FLOOR interior counter, dungeon walls) — this
##     stride only feeds it the same building Rect2i's the placement tests
##     already cross-check NPC cells against (see
##     tests/unit/test_all_npcs_placement.gd), not every static prop; a
##     precise per-prop collision scan is future work if it's ever needed.
##
## Diagonal movement is OFF (DIAGONAL_MODE_NEVER) — matches the rest of the
## game's cardinal-only movement (Player, enemies).
##
## Pure enough to unit-test headless: build() takes a PackedStringArray
## layout + an optional list of solid Rect2i footprints, no scene tree
## required.

var _astar: AStarGrid2D
var width: int
var height: int


static func build(layout: PackedStringArray, solid_rects: Array[Rect2i] = []) -> PathGrid:
	var grid := PathGrid.new()
	var h := layout.size()
	var w := 0 if h == 0 else layout[0].length()
	grid.width = w
	grid.height = h

	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(MapBuilder.TILE, MapBuilder.TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	for y in h:
		var row := layout[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var ch := row[x]
			var tile_name: String = MapBuilder.CHAR_TILES.get(ch, "")
			var solid := tile_name in MapBuilder.SOLID
			if not solid:
				for rect: Rect2i in solid_rects:
					if rect.has_point(cell):
						solid = true
						break
			astar.set_point_solid(cell, solid)

	grid._astar = astar
	return grid


func is_walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return not _astar.is_point_solid(cell)


func find_path(from_cell: Vector2i, to_cell: Vector2i) -> PackedVector2Array:
	## Returns cell coordinates (NOT world/pixel positions) from from_cell to
	## to_cell inclusive, or an empty array if either endpoint is out of
	## bounds/solid or no path exists. AStarGrid2D.get_id_path returns
	## Vector2i already, matching the "cell coords" contract.
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return PackedVector2Array()
	if from_cell == to_cell:
		var single := PackedVector2Array()
		single.append(Vector2(from_cell))
		return single
	var id_path := _astar.get_id_path(from_cell, to_cell)
	if id_path.is_empty():
		return PackedVector2Array()
	var out := PackedVector2Array()
	for cell: Vector2i in id_path:
		out.append(Vector2(cell))
	return out
