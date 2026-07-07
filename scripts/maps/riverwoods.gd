extends Node2D
## Riverwoods (World Stride C, new map): a winding forest south of the farm.
## Grass/dark-grass terrain, a river running north-south with a single
## crossing (path tiles laid across it — the river tile itself stays SOLID,
## the crossing is plain path so it doesn't block movement), Willow's hut,
## and daily forage spawns (wildroot/emberberry; winter swaps to frostcap).
##
## Built the same way as farm.gd/town.gd: a plain Node2D building
## Ground/World/Camera/UI itself, not a DungeonFloor subclass (no
## enemies/kill-ledger here — forage instead, see Forage/ForagePickup).
##
## Exit: north -> farm (farm gains a matching south portal, see farm.gd).

const WIDTH := 34
const HEIGHT := 22

## River: a vertical band with one gap (the crossing) so the map isn't split
## into two unreachable halves. Column x=20, full height except the crossing
## rows.
const RIVER_X := 20
const CROSSING_Y_START := 10
const CROSSING_Y_END := 12  # inclusive: rows 10-12 are path, not water

const HUT_CELL := Vector2i(6, 5)  # top-left of Willow's hut footprint

## "from_farm" sits just off the north portal cell so returning players don't
## land back on its trigger area (anti-bounce rule 1, see portal.gd).
const SPAWNS := {
	"default": Vector2i(17, 3),
	"entrance": Vector2i(17, 3),
	"from_farm": Vector2i(17, 3),
}

const FARM_PORTAL_CELL := Vector2i(17, 1)

## Forage pool (bible): Wildroot/Emberberry normally, Frostcap in winter (both
## outdoor forage maps share the same winter swap).
const FORAGE_NORMAL := ["wildroot", "emberberry"]
const FORAGE_WINTER := ["frostcap"]
## Distinct salt so Riverwoods and Beach don't roll identical layouts/counts
## on the same day even though both call Forage.map_seed with the same day.
const MAP_ID := "riverwoods"

var player: Player
var npcs: Dictionary = {}
var path_grid: PathGrid  # Alive Stride 1: walkable-grid for NPC pathfinding, read via the "map_root" group
var _last_block := ""
var _last_festival_phase := ""  # World Stride D: catches Willow's festival hour-window boundaries block-change alone would miss


func _ready() -> void:
	add_to_group("map_root")
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

	path_grid = PathGrid.build(_layout(), _solid_prop_rects())
	_add_props(world)
	_add_npcs(world)
	var forage_cells := _add_forage(world)

	# V3: sparse scatter decoration on grass/dark-grass, excluding the hut,
	# the farm portal, spawn cells, and whichever cells this run's forage pass
	# actually placed a pickup on (avoids stacking a flower decal directly
	# under a forage item sprite).
	add_child(MapDecoration.build_layer(built.tileset, ids,
		MapSceneHelper.decoration_candidate_cells(_layout(), _decoration_avoid_rects(forage_cells)), 2))

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)

	_add_farm_portal(world)

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
	_last_festival_phase = Festival.phase_signature(Clock.hour())
	for npc_id: String in npcs:
		(npcs[npc_id] as NPC).refresh_schedule("riverwoods")
	EventBus.time_ticked.connect(_on_time_ticked)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif x == RIVER_X and not (y >= CROSSING_Y_START and y <= CROSSING_Y_END):
				row += "~"
			elif x == RIVER_X and y >= CROSSING_Y_START and y <= CROSSING_Y_END:
				row += "P"  # the crossing
			elif y == 1 and x >= RIVER_X - 3 and x <= RIVER_X + 3:
				row += "P"  # short path stub down from the north (farm) portal
			# ~4% deterministic sparse dark-grass patches (decorative only;
			# elif order keeps them off walls/water/path), same formula shape
			# farm.gd uses for its own dark-grass scatter.
			elif (x * 7 + y * 13) % 27 == 0:
				row += "D"
			else:
				row += "G"
		rows.append(row)
	return rows


func _add_farm_portal(world: Node2D) -> void:
	var portal := Portal.make({
		"cell": FARM_PORTAL_CELL,
		"target_scene": "res://scenes/maps/farm.tscn",
		"target_spawn": "from_riverwoods",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Farm",
	})
	portal.name = "FarmPortal"
	world.add_child(portal)


func _solid_prop_rects() -> Array[Rect2i]:
	## Alive Stride 1: cell footprint of Willow's hut — the only prop with
	## real (StaticBody2D) collision on this map.
	var rects: Array[Rect2i] = []
	rects.append(MapBuilder.solid_rect_for(
		Vector2(HUT_CELL) * MapBuilder.TILE + Vector2(24, 24) + Vector2(0, 4),
		Vector2(48, 40)))
	return rects


func _add_props(world: Node2D) -> void:
	var hut := StaticBody2D.new()
	hut.name = "WillowHut"
	hut.position = Vector2(HUT_CELL) * MapBuilder.TILE + Vector2(24, 24)
	var hut_sprite := Sprite2D.new()
	hut_sprite.texture = load("res://assets/placeholder/prop_house.png")
	hut.add_child(hut_sprite)
	var hut_col := CollisionShape2D.new()
	var hut_shape := RectangleShape2D.new()
	hut_shape.size = Vector2(48, 40)
	hut_col.position = Vector2(0, 4)
	hut_col.shape = hut_shape
	hut.add_child(hut_col)
	world.add_child(hut)


func _add_npcs(world: Node2D) -> void:
	## Willow's home_map is "riverwoods" — she's the only NPC whose schedule
	## lives here every ordinary block, so this only needs to check her id
	## (kept as a loop over ALL_IDS for symmetry with town.gd/beach.gd, so a
	## future NPC added to this map needs no changes here).
	for npc_id: String in NPCFactory.ALL_IDS:
		var data := NPCFactory.build_data(npc_id)
		if data.home_map != MAP_ID:
			continue
		var npc := NPCFactory.make_npc(npc_id)
		npcs[npc_id] = npc
		world.add_child(npc)


func _add_forage(world: Node2D) -> Array:
	## Returns the cells this call rolled for forage (used or not — see
	## is_taken()/Forage.spawn_cells) so the V3 decoration pass can steer
	## clear of them, even ones already picked up today (a decal there would
	## imply "still forageable").
	var pool := Forage.item_pool_for_season(Clock.season(), FORAGE_NORMAL, FORAGE_WINTER)
	if pool.is_empty():
		return []
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
	return cells


func _decoration_avoid_rects(forage_cells: Array) -> Array:
	var rects: Array = _solid_prop_rects().duplicate()
	rects.append(Rect2i(FARM_PORTAL_CELL, Vector2i.ONE))
	for spawn_cell: Vector2i in SPAWNS.values():
		rects.append(Rect2i(spawn_cell, Vector2i.ONE))
	for cell: Vector2i in forage_cells:
		rects.append(Rect2i(cell, Vector2i.ONE))
	return rects


func _forage_candidate_cells() -> Array:
	## Walkable grass/dark-grass cells, excluding the river/path/portal/hut
	## footprint and a margin near the edges, so spawns never land on a
	## solid tile or block the portal/spawn/prop cells.
	var rows := _layout()
	var out: Array = []
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			if ch != "G" and ch != "D":
				continue
			if cell == SPAWNS["default"] or cell == FARM_PORTAL_CELL:
				continue
			var hut_rect := Rect2i(HUT_CELL, Vector2i(4, 3))
			if hut_rect.has_point(cell):
				continue
			out.append(cell)
	return out


func _on_time_ticked(_hour, _minute) -> void:
	var block := NPCRegistry.block_for(Clock.hour())
	var festival_phase := Festival.phase_signature(Clock.hour())
	if block != _last_block or festival_phase != _last_festival_phase:
		_last_block = block
		_last_festival_phase = festival_phase
		for npc_id: String in npcs:
			(npcs[npc_id] as NPC).refresh_schedule("riverwoods")
