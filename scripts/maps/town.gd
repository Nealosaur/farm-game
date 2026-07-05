extends Node2D
## The town map. Code-built like farm.gd/dungeon_floor.gd: a stone-path
## plaza with a shop building (stone floor patch + counter + shopkeeper) and
## a couple of decorative houses. West edge portal leads back to the farm.
##
## Not a DungeonFloor subclass — town has no enemies/kill-ledger and (like
## farm.gd) owns its own prop placement, so it follows farm.gd's shape
## instead: a plain Node2D that builds Ground/World/Camera/UI itself.

const WIDTH := 30
const HEIGHT := 20

## Plaza: a wide stone-floor rectangle in the middle of town, path arms
## reaching the west edge (back to farm) and looping round to the shop.
const PLAZA := Rect2i(10, 8, 10, 6)
const SHOP_FLOOR := Rect2i(20, 6, 6, 5)   # stone patch the shop building sits on
const COUNTER_CELL := Vector2i(22, 8)
const SHOPKEEPER_CELL := Vector2i(23, 8)
const HOUSE_A_CELL := Vector2i(3, 3)      # top-left cell of 3x3 house footprint
const HOUSE_B_CELL := Vector2i(3, 13)

## "from_farm" sits just off the west portal cell (1, 10) so returning
## players don't land back on its trigger area (anti-bounce rule 1, see
## portal.gd). "default"/"entrance" share the same welcome spot near the gate.
const SPAWNS := {
	"default": Vector2i(4, 10),
	"entrance": Vector2i(4, 10),
	"from_farm": Vector2i(4, 10),
}

const FARM_PORTAL_CELL := Vector2i(1, 10)

var player: Player


func _ready() -> void:
	var built := MapBuilder.build_tileset()
	var ids: Dictionary = built.ids

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = built.tileset
	add_child(ground)
	MapBuilder.fill_layer(ground, _layout(), ids)

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	_add_props(world)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)

	_add_farm_portal(world)

	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * MapBuilder.TILE
	cam.limit_bottom = HEIGHT * MapBuilder.TILE
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

	MapSceneHelper.instance_ui_and_flow_layer(self)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif PLAZA.has_point(Vector2i(x, y)) or SHOP_FLOOR.has_point(Vector2i(x, y)):
				row += "S"
			elif y == 10 and x >= 1 and x <= 20:
				row += "P"  # main road: west gate -> plaza
			elif x == 15 and y >= 6 and y <= 13:
				row += "P"  # north-south cross street through the plaza
			else:
				row += "G"
		rows.append(row)
	return rows


func _add_farm_portal(world: Node2D) -> void:
	## West-edge road back to the farm. Mirrors farm.gd's TownPortal: arm
	## delay + the offset "from_farm" spawn on the farm side prevent bounce.
	var portal := Portal.make({
		"cell": FARM_PORTAL_CELL,
		"target_scene": "res://scenes/maps/farm.tscn",
		"target_spawn": "from_town",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Farm",
	})
	portal.name = "FarmPortal"
	world.add_child(portal)


func _add_props(world: Node2D) -> void:
	world.add_child(_make_house(HOUSE_A_CELL))
	world.add_child(_make_house(HOUSE_B_CELL))

	var counter := StaticBody2D.new()
	counter.name = "Counter"
	counter.position = MapBuilder.cell_center(COUNTER_CELL)
	var counter_sprite := Sprite2D.new()
	counter_sprite.texture = load("res://assets/placeholder/prop_counter.png")
	counter.add_child(counter_sprite)
	var counter_col := CollisionShape2D.new()
	var counter_shape := RectangleShape2D.new()
	counter_shape.size = Vector2(32, 16)
	counter_col.shape = counter_shape
	counter.add_child(counter_col)
	world.add_child(counter)

	world.add_child(_make_shopkeeper())


func _make_house(cell: Vector2i) -> StaticBody2D:
	var house := StaticBody2D.new()
	house.name = "House"
	house.position = Vector2(cell) * MapBuilder.TILE + Vector2(24, 24)
	var house_sprite := Sprite2D.new()
	house_sprite.texture = load("res://assets/placeholder/prop_house.png")
	house.add_child(house_sprite)
	var house_col := CollisionShape2D.new()
	var house_shape := RectangleShape2D.new()
	house_shape.size = Vector2(48, 40)
	house_col.shape = house_shape
	house_col.position = Vector2(0, 4)
	house.add_child(house_col)
	return house


func _make_shopkeeper() -> Area2D:
	var area := Area2D.new()
	area.name = "Shopkeeper"
	area.set_script(load("res://scripts/town/shopkeeper.gd"))
	area.position = MapBuilder.cell_center(SHOPKEEPER_CELL)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/placeholder/char_shopkeeper.png")
	area.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 32)
	col.shape = shape
	area.add_child(col)
	return area
