extends Node2D
## The farm map. World is built in code from MapBuilder + placeholder props.

const WIDTH := 44
const HEIGHT := 26
const TILLABLE := Rect2i(24, 10, 14, 10)
const BED_CELL := Vector2i(8, 6)
const BIN_CELL := Vector2i(11, 7)
const HOUSE_CELL := Vector2i(4, 4)      # top-left cell of 3x3 house footprint
const SPAWN_CELL := Vector2i(9, 9)      # legacy default, kept as SPAWNS["default"]

## Named spawn support (Plan: dungeon+portal system). SceneChanger.spawn_name
## is looked up here after the world is built; unknown/missing names fall back
## to "default". "from_dungeon" sits just off the dungeon portal cell (41, 12)
## so returning players don't land back on its trigger area. "from_town" is
## the same idea for the new west-edge town portal (1, 7): offset east of it.
const SPAWNS := {
	"default": Vector2i(9, 9),
	"wake": Vector2i(8, 8),
	"from_dungeon": Vector2i(39, 12),
	"from_town": Vector2i(4, 7),
}

const DUNGEON_PORTAL_CELL := Vector2i(41, 12)
const TOWN_PORTAL_CELL := Vector2i(1, 7)

var grid: FarmGrid
var player: Player


func _ready() -> void:
	var built := MapBuilder.build_tileset()
	var ids: Dictionary = built.ids

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = built.tileset
	add_child(ground)
	MapBuilder.fill_layer(ground, _layout(), ids)

	var soil := TileMapLayer.new()
	soil.name = "Soil"
	soil.tile_set = built.tileset
	add_child(soil)

	grid = FarmGrid.new()
	grid.name = "FarmGrid"
	grid.tillable = TILLABLE
	add_child(grid)
	grid.restore()

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	var renderer := FarmRenderer.new()
	renderer.name = "FarmRenderer"
	world.add_child(renderer)
	renderer.setup(grid, soil, ids)

	_add_props(world)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)
	# (Plan 1's TEMP farm slimes are gone — combat lives in the dungeon now,
	# entered via the east stairs below.)

	_add_dungeon_portal(world)
	_add_town_portal(world)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * MapBuilder.TILE
	cam.limit_bottom = HEIGHT * MapBuilder.TILE
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

	# UI + flow layers land in Tasks 9-11; instance them if the scripts exist
	# so this file needs no edits later.
	for extra in [
		"res://scripts/ui/hud.gd",
		"res://scripts/ui/inventory_screen.gd",
		"res://scripts/ui/dialog_box.gd",
		"res://scripts/ui/shop_screen.gd",
		"res://scripts/components/day_flow.gd",
		"res://scripts/util/debug_keys.gd",
	]:
		if ResourceLoader.exists(extra):
			var node: Node = (load(extra) as GDScript).new()
			add_child(node)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif y == 7 and x >= 1 and x <= 14:
				row += "P"
			# ~3.5% deterministic sparse dark-grass patches (decorative only;
			# elif order keeps them off walls/path).
			elif (x * 7 + y * 13) % 29 == 0:
				row += "D"
			else:
				row += "G"
		rows.append(row)
	return rows


func _add_dungeon_portal(world: Node2D) -> void:
	## East-edge stairs down to dungeon floor 1. Portal's own arm-delay plus
	## the offset "from_dungeon" spawn (see SPAWNS) prevent bounce-back loops.
	var portal := Portal.make({
		"cell": DUNGEON_PORTAL_CELL,
		"target_scene": "res://scenes/maps/dungeon_1.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Dungeon — Floor 1",
	})
	portal.name = "DungeonPortal"
	world.add_child(portal)


func _add_town_portal(world: Node2D) -> void:
	## West-edge road out to town. Reuses the stairs sprite as the generic
	## "travel trigger" visual (same convention as the dungeon portal) since
	## no dedicated gate/road placeholder exists yet.
	var portal := Portal.make({
		"cell": TOWN_PORTAL_CELL,
		"target_scene": "res://scenes/maps/town.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Town",
	})
	portal.name = "TownPortal"
	world.add_child(portal)


func _add_props(world: Node2D) -> void:
	var house := StaticBody2D.new()
	house.position = Vector2(HOUSE_CELL) * MapBuilder.TILE + Vector2(24, 24)
	var house_sprite := Sprite2D.new()
	house_sprite.texture = load("res://assets/placeholder/prop_house.png")
	house.add_child(house_sprite)
	var house_col := CollisionShape2D.new()
	var house_shape := RectangleShape2D.new()
	house_shape.size = Vector2(48, 40)
	house_col.shape = house_shape
	house_col.position = Vector2(0, 4)
	house.add_child(house_col)
	world.add_child(house)

	world.add_child(_make_interactable(
		"Bed", "res://scripts/farm/bed.gd",
		"res://assets/placeholder/prop_bed.png", BED_CELL))
	world.add_child(_make_interactable(
		"ShippingBin", "res://scripts/farm/shipping_bin.gd",
		"res://assets/placeholder/prop_shipping_bin.png", BIN_CELL))


func _make_interactable(node_name: String, script_path: String, texture_path: String, cell: Vector2i) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.set_script(load(script_path))
	area.position = MapBuilder.cell_center(cell)
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	area.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	col.shape = shape
	area.add_child(col)
	return area
