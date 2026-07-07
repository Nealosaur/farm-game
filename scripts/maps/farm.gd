extends Node2D
## The farm map. World is built in code from MapBuilder + placeholder props.

const WIDTH := 44
const HEIGHT := 26
const TILLABLE := Rect2i(24, 10, 14, 10)
const BED_CELL := Vector2i(8, 6)
const BIN_CELL := Vector2i(11, 7)
const HOUSE_CELL := Vector2i(4, 4)      # top-left cell of 3x3 house footprint
## Craft Stride 1: kitchen prop, beside the house on its west side — clear of
## the house's own solid footprint (_solid_prop_rects()), the path row (y=7),
## and every other prop/portal cell on this map.
const KITCHEN_CELL := Vector2i(2, 5)
const SPAWN_CELL := Vector2i(9, 9)      # legacy default, kept as SPAWNS["default"]

## Named spawn support (Plan: dungeon+portal system). SceneChanger.spawn_name
## is looked up here after the world is built; unknown/missing names fall back
## to "default". "from_dungeon" sits just off the dungeon portal cell (41, 12)
## so returning players don't land back on its trigger area. "from_town" is
## the same idea for the west-edge town portal (1, 7). "from_riverwoods"
## (World Stride C) is the same idea for the new south-edge riverwoods portal.
const SPAWNS := {
	"default": Vector2i(9, 9),
	"wake": Vector2i(8, 8),
	"from_dungeon": Vector2i(39, 12),
	"from_town": Vector2i(4, 7),
	"from_riverwoods": Vector2i(17, 22),
}

const DUNGEON_PORTAL_CELL := Vector2i(41, 12)
const TOWN_PORTAL_CELL := Vector2i(1, 7)
const RIVERWOODS_PORTAL_CELL := Vector2i(17, 24)

## Garrick's farm-side Delve entrance cell (World Stride C): his morning
## schedule blocks place him here (see data/npcs/garrick.gd's per-block
## {"map": "farm", ...} override) — a few cells short of the dungeon portal
## itself so he isn't standing on its trigger area.
const GARRICK_DELVE_CELL := Vector2i(38, 12)

## Day-1 opening (World Stride D): Alden stands "near the player, in the
## walking path" per the bible — a few cells south-east of SPAWNS["wake"]
## (8,8), on the open path row (y=7) so the player naturally walks past him
## leaving the house.
const ALDEN_INTRO_CELL := Vector2i(10, 7)

## Craft Stride 3 (Taming): barn + fenced pen, north of the tillable field
## (bible: "small fenced pen + barn prop... north of the field"). TILLABLE is
## Rect2i(24,10,14,10) (x:24-37, y:10-19); the pen sits directly above it at
## y:2-6 — clear of the house/kitchen (x:2-6), the west path row (y=7, x:1-14
## only), and every portal/NPC cell on this map. PEN_RECT is the WALKABLE
## interior (fence sits on its border, one cell wide, via _pen_fence_cells());
## PEN_ENTRANCE_CELL is the single south-wall gap the player walks through.
const PEN_RECT := Rect2i(25, 2, 8, 5)  # interior cells x:25-32, y:2-6
const PEN_ENTRANCE_CELL := Vector2i(28, 6)  # gap in the south fence wall
const BARN_CELL := Vector2i(27, 3)  # top-left cell of the 2x2-cell (32x24px) barn footprint

var grid: FarmGrid
var player: Player
var garrick: NPC
var alden_intro: Area2D  # World Stride D day-1 opening; null after day 1 (or once intro_done)
var path_grid: PathGrid  # Alive Stride 1: walkable-grid for NPC pathfinding, read via the "map_root" group
var barn_slimes: Array[BarnSlime] = []  # Craft Stride 3: live pettable slimes rendered from world["taming"].barn
var _last_block := ""


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

	# V3: sparse scatter decoration (tufts/flowers/pebbles) — sits above Ground,
	# below Soil/World, so it never affects collision/pathfinding and is never
	# y-sorted against the player. See _decoration_avoid_rects() for what's
	# excluded (tillable field, house/barn/pen, portals, spawn cells).
	add_child(MapDecoration.build_layer(built.tileset, ids,
		MapSceneHelper.decoration_candidate_cells(_layout(), _decoration_avoid_rects()), 0))

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

	path_grid = PathGrid.build(_layout(), _solid_prop_rects())
	_add_props(world)
	_add_garrick(world)
	_add_alden_intro(world)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(SPAWNS, "default"))
	world.add_child(player)
	# (Plan 1's TEMP farm slimes are gone — combat lives in the dungeon now,
	# entered via the east stairs below.)

	_add_dungeon_portal(world)
	_add_town_portal(world)
	_add_riverwoods_portal(world)

	var cam := CameraShake.new()
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
		"res://scripts/components/day_tint.gd",
		"res://scripts/components/night_vignette.gd",  # V3: pairs with DayTint's curve, see its class doc
		"res://scripts/ui/hud.gd",
		"res://scripts/ui/inventory_screen.gd",
		"res://scripts/ui/dialog_box.gd",
		"res://scripts/ui/shop_screen.gd",
		"res://scripts/ui/cooking_screen.gd",
		"res://scripts/ui/journal.gd",
		"res://scripts/components/day_flow.gd",
		"res://scripts/ui/pause_menu.gd",
		"res://scripts/util/debug_keys.gd",
	]:
		if ResourceLoader.exists(extra):
			var node: Node = (load(extra) as GDScript).new()
			add_child(node)

	_last_block = NPCRegistry.block_for(Clock.hour())
	if garrick != null:
		garrick.refresh_schedule("farm")
	if alden_intro != null:
		alden_intro.refresh_for_block()
	EventBus.time_ticked.connect(_on_time_ticked)


func _layout() -> PackedStringArray:
	var rows := PackedStringArray()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				row += "W"
			elif y == 7 and x >= 1 and x <= 14:
				row += "P"
			elif x == RIVERWOODS_PORTAL_CELL.x and y >= RIVERWOODS_PORTAL_CELL.y and y <= HEIGHT - 2:
				row += "P"  # short path stub up from the south (riverwoods) portal
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


func _add_riverwoods_portal(world: Node2D) -> void:
	## South-edge road down to Riverwoods (World Stride C).
	var portal := Portal.make({
		"cell": RIVERWOODS_PORTAL_CELL,
		"target_scene": "res://scenes/maps/riverwoods.tscn",
		"target_spawn": "from_farm",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Riverwoods",
	})
	portal.name = "RiverwoodsPortal"
	world.add_child(portal)


func _add_garrick(world: Node2D) -> void:
	## Garrick's farm-side Delve entrance appearance (World Stride C): built
	## unconditionally (like town.gd's NPCs) and hidden/shown by
	## refresh_schedule() per the current time block — his schedule only
	## resolves to "farm" during the 6-9/9-12 blocks (see data/npcs/
	## garrick.gd's per-block map override); every other block hides him here.
	garrick = NPCFactory.make_npc("garrick")
	world.add_child(garrick)


func _add_alden_intro(world: Node2D) -> void:
	## Day-1 opening (World Stride D, see scripts/components/alden_intro.gd):
	## only ever instanced when the intro hasn't played yet AND it's still
	## day 1 — on day 2+ (or once intro_done is true) this is a no-op, so
	## every farm.gd _ready() after the intro plays builds nothing extra.
	if Clock.day != 1 or GameState.flags.get("intro_done", false):
		return
	var area := Area2D.new()
	area.name = "AldenIntro"
	area.set_script(load("res://scripts/components/alden_intro.gd"))
	area.position = MapBuilder.cell_center(ALDEN_INTRO_CELL)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(NPCFactory.REGISTRY["alden"]["sprite"])
	area.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 32)
	col.shape = shape
	area.add_child(col)
	world.add_child(area)
	alden_intro = area


func _decoration_avoid_rects() -> Array:
	## V3: cells the scatter-decoration pass must never touch — the tillable
	## field (decor would visually clash with tilled/watered soil overlay
	## tiles), every solid prop footprint (house/barn/fence), the walkable
	## pen interior (keep it clear for the barn slimes' wander area), the
	## bed/bin/kitchen interactables, both portals, Garrick's/Alden's spot,
	## and the player's own spawn cells (never obscure the tile the player
	## first appears on).
	var rects: Array = _solid_prop_rects().duplicate()
	rects.append(TILLABLE)
	rects.append(PEN_RECT)
	for cell in [BED_CELL, BIN_CELL, KITCHEN_CELL, DUNGEON_PORTAL_CELL,
			TOWN_PORTAL_CELL, RIVERWOODS_PORTAL_CELL, GARRICK_DELVE_CELL,
			ALDEN_INTRO_CELL]:
		rects.append(Rect2i(cell, Vector2i.ONE))
	for spawn_cell: Vector2i in SPAWNS.values():
		rects.append(Rect2i(spawn_cell, Vector2i.ONE))
	return rects


func _solid_prop_rects() -> Array[Rect2i]:
	## Alive Stride 1: cell footprint of the house — the only prop with real
	## (StaticBody2D) collision on this map (Bed/ShippingBin are Area2D
	## interactables, walkable like the notice board — see _make_interactable).
	## Craft Stride 3 adds the barn (also StaticBody2D, same treatment) and
	## the pen's fence-line cells (solid so the player can't clip through the
	## fence — only PEN_ENTRANCE_CELL stays open).
	var rects: Array[Rect2i] = []
	rects.append(MapBuilder.solid_rect_for(
		Vector2(HOUSE_CELL) * MapBuilder.TILE + Vector2(24, 24) + Vector2(0, 4),
		Vector2(48, 40)))
	rects.append(MapBuilder.solid_rect_for(
		Vector2(BARN_CELL) * MapBuilder.TILE + Vector2(16, 12), Vector2(32, 24)))
	for cell in _pen_fence_cells():
		rects.append(Rect2i(cell, Vector2i.ONE))
	return rects


func _pen_fence_cells() -> Array[Vector2i]:
	## Every border cell of PEN_RECT (one cell wide, around the interior),
	## excluding PEN_ENTRANCE_CELL — the single walkable gap the player enters
	## through. Interior cells themselves are left walkable (barn slimes and
	## the player, if he steps in, wander freely inside).
	var cells: Array[Vector2i] = []
	var r := PEN_RECT
	for x in range(r.position.x - 1, r.position.x + r.size.x + 1):
		for y in [r.position.y - 1, r.position.y + r.size.y]:
			var cell := Vector2i(x, y)
			if cell != PEN_ENTRANCE_CELL:
				cells.append(cell)
	for y in range(r.position.y - 1, r.position.y + r.size.y + 1):
		for x in [r.position.x - 1, r.position.x + r.size.x]:
			var cell := Vector2i(x, y)
			if cell != PEN_ENTRANCE_CELL and not (cell in cells):
				cells.append(cell)
	return cells


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
	world.add_child(_make_interactable(
		"Kitchen", "res://scripts/farm/kitchen.gd",
		"res://assets/placeholder/prop_kitchen.png", KITCHEN_CELL))

	_add_barn_and_pen(world)


func _add_barn_and_pen(world: Node2D) -> void:
	## Craft Stride 3 (Taming): barn prop (solid, StaticBody2D like the house)
	## plus a fence perimeter around PEN_RECT with a single walkable gap at
	## PEN_ENTRANCE_CELL. Fence posts are plain Sprite2D + StaticBody2D (no
	## interact()), matching the house's "just a solid prop" treatment.
	var barn := StaticBody2D.new()
	barn.name = "Barn"
	# BARN_CELL is the footprint's top-left cell; the 32x24px sprite is
	# centered like prop_house's placement convention above (top-left corner
	# in pixels + half the sprite's own width/height).
	barn.position = Vector2(BARN_CELL) * MapBuilder.TILE + Vector2(16, 12)
	var barn_sprite := Sprite2D.new()
	barn_sprite.texture = load("res://assets/placeholder/prop_barn.png")
	barn.add_child(barn_sprite)
	var barn_col := CollisionShape2D.new()
	var barn_shape := RectangleShape2D.new()
	barn_shape.size = Vector2(32, 24)
	barn_col.shape = barn_shape
	barn.add_child(barn_col)
	world.add_child(barn)

	for cell in _pen_fence_cells():
		var post := StaticBody2D.new()
		post.position = MapBuilder.cell_center(cell)
		var post_sprite := Sprite2D.new()
		post_sprite.texture = load("res://assets/placeholder/prop_fence.png")
		post.add_child(post_sprite)
		var post_col := CollisionShape2D.new()
		var post_shape := RectangleShape2D.new()
		post_shape.size = Vector2(16, 16)
		post_col.shape = post_shape
		post.add_child(post_col)
		world.add_child(post)

	_spawn_barn_slimes(world)


func _spawn_barn_slimes(world: Node2D) -> void:
	## Renders one BarnSlime per entry in world["taming"].barn — called at
	## map build (fresh farm.gd _ready()) so a load/scene-swap always matches
	## the persisted roster. barn_slimes is cleared/rebuilt each call so a
	## future re-render (e.g. after a same-scene tame) can call this again
	## without leaking duplicate nodes — no caller does that yet (taming only
	## ever happens in the dungeon, a different scene), but it's a cheap
	## safety property to keep.
	barn_slimes.clear()
	var blob := Taming.read(SaveManager.world)
	var barn: Array = blob.get("barn", [])
	for i in barn.size():
		var slime := BarnSlime.new()
		slime.name = "BarnSlime%d" % i
		slime.setup(PEN_RECT)
		# Spread starting positions across the pen interior so two slimes
		# don't spawn stacked on the exact same cell.
		var start_cell := PEN_RECT.position + Vector2i(1 + i * 2, 1)
		slime.position = MapBuilder.cell_center(start_cell)
		world.add_child(slime)
		barn_slimes.append(slime)


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


func _on_time_ticked(_hour, _minute) -> void:
	var block := NPCRegistry.block_for(Clock.hour())
	if block != _last_block:
		_last_block = block
		if garrick != null:
			garrick.refresh_schedule("farm")
		if alden_intro != null:
			alden_intro.refresh_for_block()
