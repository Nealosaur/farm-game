class_name FarmRenderer
extends Node2D
## Renders FarmGrid state: soil overlay tiles + one crop sprite per plot.

var grid: FarmGrid
var soil_layer: TileMapLayer
var ids: Dictionary

var _crop_sprites := {}


func setup(p_grid: FarmGrid, p_soil: TileMapLayer, p_ids: Dictionary) -> void:
	grid = p_grid
	soil_layer = p_soil
	ids = p_ids
	grid.plot_changed.connect(_refresh_cell)
	for cell: Vector2i in grid.plots:
		_refresh_cell(cell)


func _refresh_cell(cell: Vector2i) -> void:
	var p = grid.plots.get(cell)
	if p == null:
		soil_layer.erase_cell(cell)
	else:
		var tile := "tile_soil_watered" if p.watered else "tile_soil_tilled"
		soil_layer.set_cell(cell, ids[tile], Vector2i.ZERO)
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if p == null or p.crop_id == "":
		if sprite != null:
			sprite.queue_free()
			_crop_sprites.erase(cell)
		return
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.position = MapBuilder.cell_center(cell)
		add_child(sprite)
		_crop_sprites[cell] = sprite
	var crop := ItemDB.get_crop(p.crop_id)
	var stage_index: int = mini(p.stage, crop.stage_days.size())
	sprite.texture = load("res://assets/placeholder/crop_%s_%d.png" % [p.crop_id, stage_index])
