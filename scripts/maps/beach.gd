extends Node2D
## Graywater Shore (World Stride C, new map): the beach south of town. Sand
## ground, a pier reaching out over the water, Finn's boat shed (flavor-toast
## interact — no shop/inventory effect this stride, matching the bible's
## "flavor-only" prop convention like farm/bed.gd's placeholder), and daily
## forage spawns (tideshell/driftglass; winter swaps to frostcap).
##
## Built the same way as farm.gd/town.gd/riverwoods.gd: a plain Node2D
## building Ground/World/Camera/UI itself.
##
## Exit: north -> town (town's south portal, see town.gd's BEACH_PORTAL_CELL).

const WIDTH := 34
const HEIGHT := 18

## Pier: a horizontal path strip of sand/path tiles reaching from the beach
## out over the water band at the bottom of the map (the water itself is
## SOLID; the pier tiles crossing it are plain path, same "bridge over
## water" convention riverwoods.gd's river crossing uses).
const WATER_Y_START := 13
const PIER_X_START := 14
const PIER_X_END := 19
const PIER_Y_START := 10
const PIER_Y_END := 16

const BOAT_SHED_CELL := Vector2i(24, 11)

## "from_town" sits just off the north portal cell so returning players don't
## land back on its trigger area (anti-bounce rule 1, see portal.gd).
const SPAWNS := {
	"default": Vector2i(16, 3),
	"entrance": Vector2i(16, 3),
	"from_town": Vector2i(16, 3),
}

const TOWN_PORTAL_CELL := Vector2i(16, 1)

## Forage pool (bible): Tideshell/Driftglass normally, Frostcap in winter
## (both outdoor forage maps share the same winter swap).
const FORAGE_NORMAL := ["tideshell", "driftglass"]
const FORAGE_WINTER := ["frostcap"]
const MAP_ID := "beach"

var player: Player
var npcs: Dictionary = {}
var _last_block := ""


func _ready() -> void:
	var built := MapBuilder.build_tileset()
	var ids: Dictionary = built.ids

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = built.tileset
	add_child(ground)
	MapBuilder.fill_layer(ground, _layout(), ids)
	MapSceneHelper.attach_season_palette(self, ground)  # outdoor: seasonal recolor

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	_add_props(world)
	_add_npcs(world)
	_add_forage(world)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)

	_add_town_portal(world)

	var cam := CameraShake.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = WIDTH * MapBuilder.TILE
	cam.limit_bottom = HEIGHT * MapBuilder.TILE
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

	MapSceneHelper.instance_ui_and_flow_layer(self)

	_last_block = NPCRegistry.block_for(Clock.hour())
	for npc_id: String in npcs:
		(npcs[npc_id] as NPC).refresh_schedule("beach")
	EventBus.time_ticked.connect(_on_time_ticked)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var on_pier := x >= PIER_X_START and x <= PIER_X_END \
					and y >= PIER_Y_START and y <= PIER_Y_END
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif on_pier:
				row += "P"
			elif y >= WATER_Y_START:
				row += "~"
			elif y == 1 and x >= TOWN_PORTAL_CELL.x - 3 and x <= TOWN_PORTAL_CELL.x + 3:
				row += "P"  # short path stub down from the north (town) portal
			else:
				row += "A"  # sand
		rows.append(row)
	return rows


func _add_town_portal(world: Node2D) -> void:
	var portal := Portal.make({
		"cell": TOWN_PORTAL_CELL,
		"target_scene": "res://scenes/maps/town.tscn",
		"target_spawn": "from_beach",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Town",
	})
	portal.name = "TownPortal"
	world.add_child(portal)


func _add_props(world: Node2D) -> void:
	var shed := Area2D.new()
	shed.name = "BoatShed"
	shed.set_script(load("res://scripts/components/boat_shed.gd"))
	shed.position = MapBuilder.cell_center(BOAT_SHED_CELL)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/placeholder/prop_boat_shed.png")
	shed.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 16)
	col.shape = shape
	shed.add_child(col)
	world.add_child(shed)


func _add_npcs(world: Node2D) -> void:
	## No NPC has home_map == "beach" (Finn's home_map is "town" — his beach
	## presence is per-block map overrides, see data/npcs/finn.gd). Beach
	## therefore builds NPCs the same way town.gd does: any id with a
	## schedule slot resolving here THIS or ANY hour gets instanced and
	## hidden/shown by refresh_schedule().
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		if not _has_any_beach_slot(data):
			continue
		var npc := NPCFactory.make_npc(npc_id)
		npcs[npc_id] = npc
		world.add_child(npc)


func _has_any_beach_slot(data: NPCData) -> bool:
	if data.home_map == MAP_ID:
		return true
	for block: String in NPCRegistry.BLOCKS:
		if NPCRegistry.map_for(data, _hour_for_block(block), false, false) == MAP_ID:
			return true
	return false


func _hour_for_block(block: String) -> int:
	match block:
		NPCRegistry.BLOCK_6_9: return 7
		NPCRegistry.BLOCK_9_12: return 10
		NPCRegistry.BLOCK_12_17: return 13
		NPCRegistry.BLOCK_17_20: return 18
		_: return 21


func _add_forage(world: Node2D) -> void:
	var pool := Forage.item_pool_for_season(Clock.season(), FORAGE_NORMAL, FORAGE_WINTER)
	if pool.is_empty():
		return
	var blob: Dictionary = SaveManager.world.get("forage", {})
	var map_blob := Forage.ensure_day(blob.get(MAP_ID, {}), Clock.day)
	blob[MAP_ID] = map_blob
	SaveManager.world["forage"] = blob

	var candidates := _forage_candidate_cells()
	var seed_value := Forage.map_seed(MAP_ID, Clock.day)
	var cells := Forage.spawn_cells(candidates, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x5bd1e995  # distinct stream from the cell-shuffle RNG, still deterministic
	for cell: Vector2i in cells:
		if Forage.is_taken(map_blob, cell):
			continue
		var item_id: String = pool[rng.randi() % pool.size()]
		world.add_child(ForagePickup.make(MAP_ID, item_id, cell))


func _forage_candidate_cells() -> Array:
	## Walkable sand cells only ('A'), excluding the pier/water/portal/spawn/
	## boat-shed footprint.
	var rows := _layout()
	var out: Array = []
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			if ch != "A":
				continue
			if cell == SPAWNS["default"] or cell == TOWN_PORTAL_CELL:
				continue
			var shed_rect := Rect2i(BOAT_SHED_CELL - Vector2i(1, 1), Vector2i(3, 3))
			if shed_rect.has_point(cell):
				continue
			out.append(cell)
	return out


func _on_time_ticked(_hour, _minute) -> void:
	var block := NPCRegistry.block_for(Clock.hour())
	if block != _last_block:
		_last_block = block
		for npc_id: String in npcs:
			(npcs[npc_id] as NPC).refresh_schedule("beach")
