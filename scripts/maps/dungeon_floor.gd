class_name DungeonFloor
extends Node2D
## Shared base for dungeon floor scenes. Builds a stone-floor/wall world in
## code (same pattern as farm.gd, dungeon-flavored: no tillable, no props),
## places portals + player + camera, and spawns enemies with daily kill
## persistence via DungeonState (SaveManager.world["dungeon_state"]).
##
## Per-floor config comes from overridden virtual methods (_floor_key,
## _layout, _spawns, _portals, _enemy_spawns) so floor scripts stay tiny
## const-driven declarations. Layouts are deterministic: carve_layout()
## turns fixed room/corridor Rect2i lists into ASCII rows ('S' floor inside
## rects, 'W' wall everywhere else).
##
## Kill tracking is keyed BY FLOOR INSTANCE: each spawned enemy's own
## HealthComponent.died is connected (bound with its spawn_index) to this
## node. EventBus.enemy_died is deliberately NOT used here — it fires for
## ANY enemy anywhere (including the future boss), so it can't attribute a
## death to a floor/spawn slot. The bound connection targets this node, so
## Godot auto-disconnects it when the floor is freed (project convention:
## no lambdas that outlive their scene).
##
## The UI/flow layer (HUD, InventoryScreen, DayFlow, debug keys) reuses
## farm.gd's auto-instance loop, extracted into MapSceneHelper rather than
## copied per floor — farm.gd keeps its original inline copy untouched.


func _ready() -> void:
	# World Stride A: dungeon floors are "indoors" — the dungeon_map group
	# tells DayTint to skip the rain tint, and no SeasonPalette is attached
	# here so seasonal ground recolor never applies underground. Group must
	# be set BEFORE instance_ui_and_flow_layer() so DayTint._ready() sees it.
	add_to_group("dungeon_map")
	var rows := _layout()
	var width := 0 if rows.is_empty() else rows[0].length()
	var height := rows.size()

	var built := MapBuilder.build_tileset()
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = built.tileset
	add_child(ground)
	MapBuilder.fill_layer(ground, rows, built.ids)

	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	for cfg: Dictionary in _portals():
		var portal := Portal.make(cfg)
		world.add_child(portal)

	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.global_position = MapBuilder.cell_center(
		MapSceneHelper.spawn_cell(_spawns(), "entrance"))
	world.add_child(player)

	var cam := CameraShake.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = width * MapBuilder.TILE
	cam.limit_bottom = height * MapBuilder.TILE
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

	_spawn_enemies(world)

	MapSceneHelper.instance_ui_and_flow_layer(self)


# ---- per-floor config (override in floor scripts) ----

func _floor_key() -> String:
	return "dungeon_?"


func _layout() -> PackedStringArray:
	return PackedStringArray()


func _spawns() -> Dictionary:
	return {}


func _portals() -> Array:
	return []


func _enemy_spawns() -> Array:
	return []


# ---- enemies + daily kill persistence ----

func _spawn_enemies(world: Node2D) -> void:
	var blob := DungeonState.ensure_day(
		SaveManager.world.get("dungeon_state", {}), Clock.day)
	SaveManager.world["dungeon_state"] = blob
	var configs := _enemy_spawns()
	for i in configs.size():
		if DungeonState.is_killed(blob, _floor_key(), i):
			continue  # killed earlier today — respawns tomorrow
		var enemy := Enemy.spawn_enemy(configs[i]["id"], configs[i]["cell"], world)
		enemy.health.died.connect(_on_floor_enemy_died.bind(i))


func _on_floor_enemy_died(spawn_index: int) -> void:
	var blob := DungeonState.ensure_day(
		SaveManager.world.get("dungeon_state", {}), Clock.day)
	blob = DungeonState.record_kill(blob, _floor_key(), spawn_index)
	SaveManager.world["dungeon_state"] = blob


# ---- deterministic layout carving ----

static func carve_layout(size: Vector2i, floor_rects: Array) -> PackedStringArray:
	## All-wall grid with 'S' stone floor carved inside each Rect2i (rooms and
	## corridors alike). Purely deterministic — same rects, same layout.
	var rows := PackedStringArray()
	for y in size.y:
		var row := ""
		for x in size.x:
			row += "S" if _in_any(Vector2i(x, y), floor_rects) else "W"
		rows.append(row)
	return rows


static func _in_any(cell: Vector2i, rects: Array) -> bool:
	for r: Rect2i in rects:
		if r.has_point(cell):
			return true
	return false
