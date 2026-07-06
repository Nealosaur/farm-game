extends Node2D
## The town map: "Emberhollow" (World Stride C expansion). Code-built like
## farm.gd/dungeon_floor.gd: a stone-path plaza at the center with five
## buildings around it (General Store west, Clinic + Smithy east, Saloon
## south, Mayor's house north) plus a notice board on the plaza itself.
##
## Not a DungeonFloor subclass — town has no enemies/kill-ledger and (like
## farm.gd) owns its own prop placement, so it follows farm.gd's shape
## instead: a plain Node2D that builds Ground/World/Camera/UI itself.
##
## NPC placement: every registered NPC (see NPCFactory.ALL_IDS) that has ANY
## schedule block on "town" this hour is built here via NPCFactory.make_npc()
## and repositioned/hidden by NPC.refresh_schedule() — same block-teleport
## contract as World Stride B's Marta-only version, generalized to all 8.
## Garrick's morning blocks live on farm's map (per-block map override in his
## schedule) so he's simply invisible here during those hours, not absent
## from the town scene tree (matches Marta's original "always instanced,
## sometimes hidden" pattern — cheaper than tearing down/rebuilding nodes on
## every block change).
##
## World Stride C also adds the south portal to the Beach ("Graywater
## Shore") — the existing west portal back to the farm is UNCHANGED (same
## cell/spawn contract Stride B shipped, per the stride's explicit
## "existing farm portal kept working" requirement).

const WIDTH := 44
const HEIGHT := 30

## Plaza: the big open stone-floor festival ground at the center of town.
const PLAZA := Rect2i(16, 10, 12, 8)

## Building floor patches (stone 'S'), one per building. Each just needs to
## be big enough to host its counter/prop + the NPC(s) who work there.
const STORE_FLOOR := Rect2i(4, 11, 6, 6)      # General Store (Marta), west side
const CLINIC_FLOOR := Rect2i(31, 8, 6, 5)     # Clinic (Doc Bram), east side (north)
const SMITHY_FLOOR := Rect2i(31, 16, 6, 5)    # Smithy (Sten), east side (south)
const SALOON_FLOOR := Rect2i(17, 21, 8, 5)    # Saloon "The Ember" (Rosa), south of plaza
const MAYOR_FLOOR := Rect2i(18, 3, 6, 5)      # Mayor's house (Alden), north of plaza

## Roads: a main east-west spine (also carries the farm portal on the west
## edge) and a north-south spine crossing through the plaza connecting the
## mayor's house (north) to the saloon (south).
const MAIN_ROAD_Y := 14
const CROSS_ROAD_X := 21

const COUNTER_CELL := Vector2i(7, 13)         # store counter
const SHOPKEEPER_CELL := Vector2i(8, 13)      # Marta's counter spot (matches MartaData)
const NOTICE_BOARD_CELL := Vector2i(19, 11)   # plaza, near the mayor-side edge
const HOUSE_DECOR_CELL := Vector2i(3, 24)     # single decorative house, south-west grass

## "from_farm" sits just off the west portal cell so returning players don't
## land back on its trigger area (anti-bounce rule 1, see portal.gd).
## "from_beach" is the equivalent offset for the new south portal.
const SPAWNS := {
	"default": Vector2i(4, 14),
	"entrance": Vector2i(4, 14),
	"from_farm": Vector2i(4, 14),
	"from_beach": Vector2i(21, 25),
}

const FARM_PORTAL_CELL := Vector2i(1, 14)
const BEACH_PORTAL_CELL := Vector2i(21, 28)

var player: Player
var npcs: Dictionary = {}  # npc_id -> NPC node, for every id with a town schedule slot
var marta: NPC  # kept as a named alias (World Stride B call sites / tests reference town.marta)
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

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)

	_add_farm_portal(world)
	_add_beach_portal(world)

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
		(npcs[npc_id] as NPC).refresh_schedule("town")
	EventBus.time_ticked.connect(_on_time_ticked)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif PLAZA.has_point(cell) or STORE_FLOOR.has_point(cell) \
					or CLINIC_FLOOR.has_point(cell) or SMITHY_FLOOR.has_point(cell) \
					or SALOON_FLOOR.has_point(cell) or MAYOR_FLOOR.has_point(cell):
				row += "S"
			elif y == MAIN_ROAD_Y and x >= 1 and x <= WIDTH - 2:
				row += "P"  # main east-west road: farm gate -> plaza -> east side
			elif x == CROSS_ROAD_X and y >= 2 and y <= HEIGHT - 2:
				row += "P"  # north-south cross street: mayor's house -> plaza -> saloon -> beach gate
			else:
				row += "G"
		rows.append(row)
	return rows


func _add_farm_portal(world: Node2D) -> void:
	## West-edge road back to the farm. Mirrors farm.gd's TownPortal: arm
	## delay + the offset "from_farm" spawn on the farm side prevent bounce.
	## UNCHANGED behavior from World Stride B — only the cell moved to match
	## the new, wider layout's road row.
	var portal := Portal.make({
		"cell": FARM_PORTAL_CELL,
		"target_scene": "res://scenes/maps/farm.tscn",
		"target_spawn": "from_town",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Farm",
	})
	portal.name = "FarmPortal"
	world.add_child(portal)


func _add_beach_portal(world: Node2D) -> void:
	## South-edge road down to Graywater Shore (World Stride C).
	var portal := Portal.make({
		"cell": BEACH_PORTAL_CELL,
		"target_scene": "res://scenes/maps/beach.tscn",
		"target_spawn": "from_town",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Beach",
	})
	portal.name = "BeachPortal"
	world.add_child(portal)


func _add_props(world: Node2D) -> void:
	world.add_child(_make_house(HOUSE_DECOR_CELL))

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

	world.add_child(_make_notice_board())


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
	house_col.position = Vector2(0, 4)
	house_col.shape = house_shape
	house.add_child(house_col)
	return house


func _make_notice_board() -> Area2D:
	## Interactable prop_sign on the plaza. Bible: "shows next festival + any
	## active quest hints" — World Stride D scope for real content; this
	## stride's contract is the flavor-toast stub: "Nothing posted yet."
	var board := Area2D.new()
	board.name = "NoticeBoard"
	board.set_script(load("res://scripts/components/notice_board.gd"))
	board.position = MapBuilder.cell_center(NOTICE_BOARD_CELL)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/placeholder/prop_sign.png")
	board.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 24)
	col.shape = shape
	board.add_child(col)
	return board


func _add_npcs(world: Node2D) -> void:
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		if not _has_any_town_slot(data):
			continue
		var npc := NPCFactory.make_npc(npc_id)
		npcs[npc_id] = npc
		world.add_child(npc)
	marta = npcs.get("marta")


func _has_any_town_slot(data: NPCData) -> bool:
	## An NPC is worth instancing on the town scene if ANY schedule/rain/
	## festival entry places them here — either because home_map == "town"
	## (the common case) or because a per-block {"map": "town", ...} override
	## exists (none currently do; kept for symmetry with farm.gd's Garrick
	## check). Garrick's home_map is "town" (evenings/saloon), so he still
	## qualifies even though his morning blocks override to "farm".
	if data.home_map == "town":
		return true
	for block: String in NPCRegistry.BLOCKS:
		if NPCRegistry.map_for(data, _hour_for_block(block), false, false) == "town":
			return true
	return false


func _hour_for_block(block: String) -> int:
	## Any hour that resolves back to `block` via NPCRegistry.block_for() —
	## used only by _has_any_town_slot's static "does this NPC ever appear
	## here" check, never for actual placement.
	match block:
		NPCRegistry.BLOCK_6_9: return 7
		NPCRegistry.BLOCK_9_12: return 10
		NPCRegistry.BLOCK_12_17: return 13
		NPCRegistry.BLOCK_17_20: return 18
		_: return 21


func _on_time_ticked(_hour, _minute) -> void:
	var block := NPCRegistry.block_for(Clock.hour())
	if block != _last_block:
		_last_block = block
		for npc_id: String in npcs:
			(npcs[npc_id] as NPC).refresh_schedule("town")
