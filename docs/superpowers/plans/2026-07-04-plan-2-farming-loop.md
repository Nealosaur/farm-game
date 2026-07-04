# farm-rpg Plan 2: Farming Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fully playable farm day loop — walk the farm, till/plant/water with hotbar tools, crops grow overnight, harvest, ship, eat, sleep, autosave — with HUD and inventory screen.

**Architecture:** Code-built world (runtime TileSet + procedural layout, like the placeholder philosophy from Plan 1). Logic/rendering split: `FarmGrid` (pure state + rules, heavily unit-tested) vs `FarmRenderer` (TileMapLayer + sprites). Player is a CharacterBody2D with a generic node-based StateMachine (Idle/Move/UseTool — Plan 3 adds combat states). UI (HUD, inventory screen) is built in code, listening only to EventBus signals.

**Tech Stack:** Godot 4.6.3 (GDScript, GL Compatibility), GUT 9.6.0, existing Plan 1 autoloads (EventBus, Clock, GameState, ItemDB, Inventory, SaveManager, SceneChanger).

**Spec:** `docs/superpowers/specs/2026-07-04-farm-rpg-vertical-slice-design.md` (§4 player, §6 farming, §7 time, §9 UI, §10 architecture)
**This is Plan 2 of 4.** Plan 3 = Combat & Dungeon, Plan 4 = Town & Game Shell.

---

## Environment

```bash
export GODOT="/c/Users/Forrest/Tools/Godot/Godot_v4.6.3-stable_win64_console.exe"
cd /c/Users/Forrest/Desktop/farm-rpg
```

- Suite: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd` (42 tests green at start).
- Re-import after adding files that later steps `load()`: `"$GODOT" --headless --path . --import`
- Work on branch `plan-2-farming-loop` (create from master at start).
- GDScript: TABS, typed where practical. GUT gotchas: `push_error` and engine-ERROR prints fail tests (use `push_warning`; use instance `JSON.new().parse()` — already done in Plan 1).
- Coordinate convention: 16 px tiles; a world position maps to cell `Vector2i((pos / 16.0).floor())`. The player origin is at their feet.

## File Structure (new in Plan 2)

```
scenes/
├── main/boot.tscn                 # new main scene: load-or-new-game → farm
├── maps/farm.tscn                 # Node2D + farm.gd (world built in code)
├── player/player.tscn             # CharacterBody2D + states
└── ui/                            # (all UI built in code; no .tscn needed)
scripts/
├── components/state.gd            # base State
├── components/state_machine.gd    # generic FSM (player now, enemies in Plan 3)
├── components/day_flow.gd         # sleep / curfew / death → day rollover + autosave
├── farm/farm_grid.gd              # plot state + rules + (de)serialization  [logic only]
├── farm/farm_renderer.gd          # soil tiles + crop sprites               [render only]
├── farm/shipping.gd               # static payout math
├── farm/shipping_bin.gd           # interactable Area2D
├── farm/bed.gd                    # interactable Area2D
├── maps/map_builder.gd            # runtime TileSet + ASCII layout fill
├── maps/farm.gd                   # builds the farm world, wires everything
├── main/boot.gd                   # load_game() or new_game(), travel to farm
├── player/player.gd               # movement, facing, tool use, interact
├── player/states/player_idle.gd
├── player/states/player_move.gd
├── player/states/player_use_tool.gd
├── ui/hud.gd                      # bars, clock, gold, hotbar, toasts (CanvasLayer)
├── ui/inventory_screen.gd         # Tab grid, click-click swap (CanvasLayer)
└── util/placeholder_frames.gd     # SpriteFrames from a single placeholder PNG
└── util/debug_keys.gd             # F1/F2/F4 dev-build helpers (F3 stub)
tests/unit/
├── test_foundation_touchups.gd    # Clock reset, Inventory.swap
├── test_components.gd             # StateMachine, PlaceholderFrames
├── test_map_builder.gd
├── test_player_math.gd
├── test_farm_grid.gd              # the big one
├── test_shipping.gd
└── test_farm_integration.gd       # boots farm.tscn headless, plays a mini-day
```

Modified: `scripts/autoload/clock.gd`, `scripts/autoload/save_manager.gd`, `scripts/autoload/scene_changer.gd`, `scripts/autoload/event_bus.gd`, `scripts/autoload/inventory.gd`, `project.godot` (main scene).

---

### Task 1: Foundation Touch-ups (handoff fixes Plan 2 depends on)

**Files:**
- Modify: `scripts/autoload/clock.gd` (add reset_day_timers)
- Modify: `scripts/autoload/save_manager.gd` (call it in new_game/load_game)
- Modify: `scripts/autoload/event_bus.gd` (add toast_requested)
- Modify: `scripts/autoload/scene_changer.gd` (fade helpers + reentrancy guard)
- Modify: `scripts/autoload/inventory.gd` (add swap)
- Test: `tests/unit/test_foundation_touchups.gd`

- [ ] **Step 1: Create the branch**

```bash
git checkout -b plan-2-farming-loop
```

- [ ] **Step 2: Write the failing test `tests/unit/test_foundation_touchups.gd`**

```gdscript
extends GutTest


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_touchups.json"
	SaveManager.new_game()


func after_each() -> void:
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_touchups.json"):
		DirAccess.remove_absolute("user://test_touchups.json")


func test_new_game_resets_curfew_latch() -> void:
	Clock.advance_minutes(Clock.DAY_END_MINUTES - Clock.DAY_START_MINUTES)
	assert_true(Clock._curfew_fired)
	SaveManager.new_game()
	assert_false(Clock._curfew_fired)
	watch_signals(EventBus)
	Clock.advance_minutes(Clock.DAY_END_MINUTES - Clock.DAY_START_MINUTES)
	assert_signal_emit_count(EventBus, "curfew_reached", 1)


func test_load_game_resets_curfew_latch() -> void:
	Clock.advance_minutes(Clock.DAY_END_MINUTES - Clock.DAY_START_MINUTES)
	assert_true(SaveManager.save_game())
	assert_true(SaveManager.load_game())
	assert_false(Clock._curfew_fired)


func test_inventory_swap() -> void:
	Inventory.reset()
	Inventory.add_item("turnip", 10)   # slot 0
	Inventory.add_item("hoe")          # slot 1
	Inventory.swap(0, 5)
	assert_null(Inventory.slots[0])
	assert_eq(Inventory.slots[5].id, "turnip")
	Inventory.swap(1, 5)
	assert_eq(Inventory.slots[1].id, "turnip")
	assert_eq(Inventory.slots[5].id, "hoe")


func test_inventory_swap_invalid_indices_noop() -> void:
	Inventory.reset()
	Inventory.add_item("turnip", 10)
	Inventory.swap(0, 99)
	Inventory.swap(-1, 0)
	assert_eq(Inventory.slots[0].id, "turnip")


func test_event_bus_has_toast_signal() -> void:
	assert_true(EventBus.has_signal("toast_requested"))
```

- [ ] **Step 3: Run suite — verify FAILURE** (`reset_day_timers`/`swap` nonexistent, missing signal). `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd; echo "exit: $?"` → nonzero.

- [ ] **Step 4: Implement.**

`scripts/autoload/clock.gd` — add:

```gdscript
func reset_day_timers() -> void:
	## Clears sub-day state that end_day() normally clears. Called by
	## SaveManager.new_game()/load_game() so a fresh/loaded game can't
	## inherit a fired curfew latch from the previous session.
	_accum = 0.0
	_curfew_fired = false
```

`scripts/autoload/save_manager.gd` — in `new_game()`, after `Clock.minutes = ...` add `Clock.reset_day_timers()`. In `load_game()`, after `Clock.minutes = int(...)` add `Clock.reset_day_timers()`.

`scripts/autoload/event_bus.gd` — add to the signal list:

```gdscript
signal toast_requested(message)
```

`scripts/autoload/scene_changer.gd` — replace `travel()` with guard + extracted fades:

```gdscript
var _traveling := false


func fade_to_black(duration := 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, duration)
	await t.finished


func fade_from_black(duration := 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, duration)
	await t.finished


func travel(scene_path: String, spawn: String = "default") -> void:
	if _traveling:
		return
	_traveling = true
	if not ResourceLoader.exists(scene_path):
		push_warning("SceneChanger: missing scene %s — falling back to dev room" % scene_path)
		scene_path = "res://scenes/maps/dev_room.tscn"
		spawn = "default"
	spawn_name = spawn
	await fade_to_black()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_from_black()
	_traveling = false
```

`scripts/autoload/inventory.gd` — add:

```gdscript
func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= SIZE or b >= SIZE:
		return
	var t = slots[a]
	slots[a] = slots[b]
	slots[b] = t
	EventBus.inventory_changed.emit()
```

- [ ] **Step 5: Run suite — ALL PASS** (5 new + 42 = 47), exit 0.

- [ ] **Step 6: Commit**

```bash
git add scripts tests
git commit -m "feat: foundation touch-ups — clock day-timer reset, fade helpers, travel guard, Inventory.swap, toast signal"
```

---

### Task 2: StateMachine Component + PlaceholderFrames Util

**Files:**
- Create: `scripts/components/state.gd`, `scripts/components/state_machine.gd`
- Create: `scripts/util/placeholder_frames.gd`
- Test: `tests/unit/test_components.gd`

- [ ] **Step 1: Write the failing test `tests/unit/test_components.gd`**

```gdscript
extends GutTest


class TrackState:
	extends State
	var entered := 0
	var exited := 0

	func enter() -> void:
		entered += 1

	func exit() -> void:
		exited += 1


func _make_machine() -> StateMachine:
	var root := Node.new()
	var machine := StateMachine.new()
	machine.name = "StateMachine"
	var a := TrackState.new()
	a.name = "A"
	var b := TrackState.new()
	b.name = "B"
	machine.add_child(a)
	machine.add_child(b)
	machine.initial_state = a
	root.add_child(machine)
	add_child_autofree(root)
	return machine


func test_machine_starts_in_initial_state() -> void:
	var m := _make_machine()
	assert_eq(m.current.name, "A")
	assert_eq((m.current as TrackState).entered, 1)


func test_transition_switches_and_calls_hooks() -> void:
	var m := _make_machine()
	var a := m.get_node("A") as TrackState
	m.transition("B")
	assert_eq(m.current.name, "B")
	assert_eq(a.exited, 1)
	assert_eq((m.current as TrackState).entered, 1)


func test_transition_to_unknown_state_is_safe() -> void:
	var m := _make_machine()
	m.transition("Nope")
	assert_eq(m.current.name, "A")


func test_placeholder_frames_builds_all_animations() -> void:
	var tex := load("res://assets/placeholder/char_player.png") as Texture2D
	var names := PackedStringArray(["idle_down", "walk_left", "use_up"])
	var frames := PlaceholderFrames.build(tex, names)
	for n in names:
		assert_true(frames.has_animation(n))
		assert_eq(frames.get_frame_count(n), 1)
	assert_false(frames.has_animation("default"))
```

- [ ] **Step 2: Run suite — verify FAILURE** (State/StateMachine/PlaceholderFrames not declared).

- [ ] **Step 3: Implement.**

`scripts/components/state.gd`:

```gdscript
class_name State
extends Node
## One state of a StateMachine. Subclass and override the hooks.
## `machine` is injected by StateMachine on ready.

var machine: StateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
```

`scripts/components/state_machine.gd`:

```gdscript
class_name StateMachine
extends Node
## Generic node-based FSM. Children are State nodes; transition by node name.

@export var initial_state: State

var current: State


func _ready() -> void:
	for child in get_children():
		if child is State:
			child.machine = self
	if initial_state != null:
		current = initial_state
		current.enter()


func _process(delta: float) -> void:
	if current != null:
		current.update(delta)


func _physics_process(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func transition(to_name: String) -> void:
	var next := get_node_or_null(NodePath(to_name)) as State
	if next == null:
		push_warning("StateMachine: unknown state " + to_name)
		return
	if current != null:
		current.exit()
	current = next
	current.enter()
```

`scripts/util/placeholder_frames.gd`:

```gdscript
class_name PlaceholderFrames
extends RefCounted
## Builds a SpriteFrames where every named animation is the same single
## placeholder frame. Real art later replaces this with authored SpriteFrames;
## animation NAMES are the stable contract (spec §12).


static func build(tex: Texture2D, names: PackedStringArray) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for n in names:
		sf.add_animation(n)
		sf.add_frame(n, tex)
		sf.set_animation_speed(n, 5.0)
	return sf
```

- [ ] **Step 4: Run suite — ALL PASS** (4 new + 47 = 51), exit 0.
- [ ] **Step 5: Commit** — `git add scripts tests && git commit -m "feat: generic StateMachine component and PlaceholderFrames util"`

---

### Task 3: MapBuilder (runtime TileSet + layout fill)

**Files:**
- Create: `scripts/maps/map_builder.gd`
- Test: `tests/unit/test_map_builder.gd`

- [ ] **Step 1: Write the failing test `tests/unit/test_map_builder.gd`**

```gdscript
extends GutTest


func test_build_tileset_returns_ids_for_all_tiles() -> void:
	var built := MapBuilder.build_tileset()
	var ts: TileSet = built.tileset
	var ids: Dictionary = built.ids
	assert_not_null(ts)
	for tile_name in MapBuilder.TILE_TEXTURES:
		assert_true(ids.has(tile_name), tile_name + " missing id")
		assert_not_null(ts.get_source(ids[tile_name]))
	assert_eq(ts.tile_size, Vector2i(16, 16))


func test_fill_layer_places_cells() -> void:
	var built := MapBuilder.build_tileset()
	var layer := TileMapLayer.new()
	layer.tile_set = built.tileset
	add_child_autofree(layer)
	var rows := PackedStringArray(["WGW", "G~P"])
	MapBuilder.fill_layer(layer, rows, built.ids)
	assert_eq(layer.get_cell_source_id(Vector2i(0, 0)), built.ids["tile_wall"])
	assert_eq(layer.get_cell_source_id(Vector2i(1, 0)), built.ids["tile_grass"])
	assert_eq(layer.get_cell_source_id(Vector2i(1, 1)), built.ids["tile_water"])
	assert_eq(layer.get_cell_source_id(Vector2i(2, 1)), built.ids["tile_path"])


func test_solid_tiles_have_collision() -> void:
	var built := MapBuilder.build_tileset()
	var src := built.tileset.get_source(built.ids["tile_wall"]) as TileSetAtlasSource
	var td := src.get_tile_data(Vector2i.ZERO, 0)
	assert_gt(td.get_collision_polygons_count(0), 0)
	var grass_src := built.tileset.get_source(built.ids["tile_grass"]) as TileSetAtlasSource
	assert_eq(grass_src.get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0), 0)
```

- [ ] **Step 2: Run suite — verify FAILURE** (MapBuilder not declared).

- [ ] **Step 3: Implement `scripts/maps/map_builder.gd`**

```gdscript
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
		src.create_tile(Vector2i.ZERO)
		if tile_name in SOLID:
			var td := src.get_tile_data(Vector2i.ZERO, 0)
			td.add_collision_polygon(0)
			var h := TILE / 2.0
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h),
			]))
		ids[tile_name] = ts.add_source(src)
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
```

- [ ] **Step 4: Run suite — ALL PASS** (3 new + 51 = 54), exit 0.
- [ ] **Step 5: Commit** — `git add scripts tests && git commit -m "feat: MapBuilder — runtime TileSet and ASCII layout fill"`

---

### Task 4: Player Scene (movement, facing, states)

**Files:**
- Create: `scripts/player/player.gd`, `scripts/player/states/player_idle.gd`, `player_move.gd`, `player_use_tool.gd`
- Create: `scenes/player/player.tscn`
- Test: `tests/unit/test_player_math.gd`

- [ ] **Step 1: Write the failing test `tests/unit/test_player_math.gd`**

```gdscript
extends GutTest


func test_cell_of_maps_positions() -> void:
	assert_eq(MapBuilder.cell_of(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(MapBuilder.cell_of(Vector2(15.9, 15.9)), Vector2i(0, 0))
	assert_eq(MapBuilder.cell_of(Vector2(16, 16)), Vector2i(1, 1))
	assert_eq(MapBuilder.cell_of(Vector2(-0.1, 5)), Vector2i(-1, 0))


func test_facing_from_input_prefers_dominant_axis() -> void:
	assert_eq(Player.facing_from(Vector2(1, 0.2)), Vector2i.RIGHT)
	assert_eq(Player.facing_from(Vector2(-0.9, 0.3)), Vector2i.LEFT)
	assert_eq(Player.facing_from(Vector2(0.2, 1)), Vector2i.DOWN)
	assert_eq(Player.facing_from(Vector2(0.1, -0.8)), Vector2i.UP)


func test_facing_name() -> void:
	assert_eq(Player.facing_to_name(Vector2i.DOWN), "down")
	assert_eq(Player.facing_to_name(Vector2i.UP), "up")
	assert_eq(Player.facing_to_name(Vector2i.LEFT), "left")
	assert_eq(Player.facing_to_name(Vector2i.RIGHT), "right")


func test_player_scene_targets_cell_in_front() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(40, 40)  # cell (2,2)
	player.facing = Vector2i.RIGHT
	assert_eq(player.target_cell(), Vector2i(3, 2))
	player.facing = Vector2i.UP
	assert_eq(player.target_cell(), Vector2i(2, 1))
```

- [ ] **Step 2: Run suite — verify FAILURE** (Player not declared / scene missing).

- [ ] **Step 3: Implement.**

`scripts/player/player.gd`:

```gdscript
class_name Player
extends CharacterBody2D
## Farm player. Origin = feet. States: Idle, Move, UseTool (combat in Plan 3).

const SPEED := 80.0
const ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"use_down", "use_up", "use_left", "use_right",
]

var facing := Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var machine: StateMachine = $StateMachine
@onready var interact_zone: Area2D = $InteractZone


func _ready() -> void:
	add_to_group("player")
	var tex := load("res://assets/placeholder/char_player.png") as Texture2D
	sprite.sprite_frames = PlaceholderFrames.build(tex, PackedStringArray(ANIM_NAMES))
	sprite.play("idle_down")


static func facing_from(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i.RIGHT if dir.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if dir.y > 0 else Vector2i.UP


static func facing_to_name(f: Vector2i) -> String:
	match f:
		Vector2i.UP: return "up"
		Vector2i.LEFT: return "left"
		Vector2i.RIGHT: return "right"
		_: return "down"


func facing_name() -> String:
	return facing_to_name(facing)


func move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func update_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		facing = facing_from(dir)
		interact_zone.position = Vector2(facing) * 12.0


func cell() -> Vector2i:
	return MapBuilder.cell_of(global_position)


func target_cell() -> Vector2i:
	return cell() + facing


func play_anim(prefix: String) -> void:
	sprite.play(prefix + "_" + facing_name())


func _farm_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group("farm_grid") as FarmGrid


func try_use_selected() -> void:
	var data := Inventory.get_selected_item_data()
	if data == null:
		return
	if data is ToolData:
		_use_tool(data)
	elif data is SeedData:
		_plant(data)
	elif data is FoodData:
		_eat(data)


func _use_tool(tool_data: ToolData) -> void:
	var grid := _farm_grid()
	match tool_data.tool_type:
		ToolData.ToolType.HOE:
			if grid != null and grid.till(target_cell()):
				GameState.spend_rp(tool_data.rp_cost)
				machine.transition("UseTool")
		ToolData.ToolType.WATERING_CAN:
			if grid != null and grid.water(target_cell()):
				GameState.spend_rp(tool_data.rp_cost)
				machine.transition("UseTool")
		ToolData.ToolType.SWORD:
			# Plan 2: swing costs RP and animates; hitboxes land in Plan 3.
			GameState.spend_rp(tool_data.rp_cost)
			machine.transition("UseTool")


func _plant(seed_data: SeedData) -> void:
	var grid := _farm_grid()
	if grid != null and grid.plant(target_cell(), seed_data.crop_id):
		Inventory.remove_item(seed_data.id, 1)
		machine.transition("UseTool")


func _eat(food: FoodData) -> void:
	if not Inventory.remove_item(food.id, 1):
		return
	GameState.restore_rp(food.rp_restore)
	if food.hp_restore > 0:
		GameState.heal(food.hp_restore)
	EventBus.toast_requested.emit("Ate %s (+%d RP)" % [food.display_name, food.rp_restore])


func try_interact() -> void:
	var grid := _farm_grid()
	if grid != null:
		var product := grid.peek_harvest(target_cell())
		if product != "":
			if Inventory.add_item(product) == 0:
				grid.clear_crop(target_cell())
				EventBus.toast_requested.emit("+1 " + ItemDB.get_item(product).display_name)
			else:
				EventBus.toast_requested.emit("Inventory full!")
			return
	for area in interact_zone.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return
```

`scripts/player/states/player_idle.gd`:

```gdscript
extends State

@onready var player: Player = owner


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
	elif player.move_input() != Vector2.ZERO:
		machine.transition("Move")
```

`scripts/player/states/player_move.gd`:

```gdscript
extends State

@onready var player: Player = owner


func enter() -> void:
	player.play_anim("walk")


func physics_update(_delta: float) -> void:
	var dir := player.move_input()
	if dir == Vector2.ZERO:
		machine.transition("Idle")
		return
	player.update_facing(dir)
	player.play_anim("walk")
	player.velocity = dir * Player.SPEED
	player.move_and_slide()


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
```

`scripts/player/states/player_use_tool.gd`:

```gdscript
extends State
## Brief action lock while a tool animation plays.

const DURATION := 0.25

@onready var player: Player = owner

var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.play_anim("use")


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition("Idle")
```

`scenes/player/player.tscn`:

```ini
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/player/player.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/state_machine.gd" id="2"]
[ext_resource type="Script" path="res://scripts/player/states/player_idle.gd" id="3"]
[ext_resource type="Script" path="res://scripts/player/states/player_move.gd" id="4"]
[ext_resource type="Script" path="res://scripts/player/states/player_use_tool.gd" id="5"]

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1")

[node name="Sprite" type="AnimatedSprite2D" parent="."]
offset = Vector2(0, -12)

[node name="Collision" type="CollisionShape2D" parent="."]

[node name="InteractZone" type="Area2D" parent="."]
position = Vector2(0, 12)
monitorable = false

[node name="ZoneShape" type="CollisionShape2D" parent="InteractZone"]

[node name="StateMachine" type="Node" parent="." node_paths=PackedStringArray("initial_state")]
script = ExtResource("2")
initial_state = NodePath("Idle")

[node name="Idle" type="Node" parent="StateMachine"]
script = ExtResource("3")

[node name="Move" type="Node" parent="StateMachine"]
script = ExtResource("4")

[node name="UseTool" type="Node" parent="StateMachine"]
script = ExtResource("5")
```

Then add shapes in code (shapes in .tscn text need sub-resources; do it in `player.gd _ready` instead — append after `sprite.play("idle_down")`):

```gdscript
	($Collision as CollisionShape2D).shape = RectangleShape2D.new()
	(($Collision as CollisionShape2D).shape as RectangleShape2D).size = Vector2(10, 6)
	($Collision as CollisionShape2D).position = Vector2(0, -3)
	var zone_shape := CircleShape2D.new()
	zone_shape.radius = 10.0
	($InteractZone/ZoneShape as CollisionShape2D).shape = zone_shape
	interact_zone.position = Vector2(facing) * 12.0
```

- [ ] **Step 4: Import, run suite — ALL PASS** (4 new + 54 = 58), exit 0. (`test_player_scene_targets_cell_in_front` instantiates the scene; FarmGrid isn't declared yet — `_farm_grid()` references the `FarmGrid` type. To keep this task self-contained, `player.gd` may temporarily use `-> Node` as the return type of `_farm_grid()` and cast later; **preferred**: implement Task 5's `farm_grid.gd` class first if the analyzer blocks. Report which you did.)
- [ ] **Step 5: Commit** — `git add scripts scenes tests && git commit -m "feat: player with FSM movement, facing, tool-use and interact plumbing"`

---

### Task 5: FarmGrid (logic + serialization)

**Files:**
- Create: `scripts/farm/farm_grid.gd`
- Test: `tests/unit/test_farm_grid.gd`

- [ ] **Step 1: Write the failing test `tests/unit/test_farm_grid.gd`**

```gdscript
extends GutTest

var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	grid = FarmGrid.new()
	grid.tillable = Rect2i(0, 0, 10, 10)
	add_child_autofree(grid)


func test_till_only_inside_tillable_area() -> void:
	assert_true(grid.till(Vector2i(2, 2)))
	assert_false(grid.till(Vector2i(2, 2)))     # already tilled
	assert_false(grid.till(Vector2i(50, 50)))   # outside


func test_water_requires_tilled() -> void:
	assert_false(grid.water(Vector2i(3, 3)))
	grid.till(Vector2i(3, 3))
	assert_true(grid.water(Vector2i(3, 3)))
	assert_false(grid.water(Vector2i(3, 3)))    # already watered


func test_plant_requires_tilled_and_empty() -> void:
	assert_false(grid.plant(Vector2i(4, 4), "turnip"))
	grid.till(Vector2i(4, 4))
	assert_true(grid.plant(Vector2i(4, 4), "turnip"))
	assert_false(grid.plant(Vector2i(4, 4), "turnip"))  # occupied
	assert_false(grid.plant(Vector2i(5, 5), "nonsense_crop"))


func test_turnip_grows_in_three_watered_days() -> void:
	var c := Vector2i(1, 1)
	grid.till(c)
	grid.plant(c, "turnip")   # stage_days [1,1,1] -> ripe at stage 3
	for day in 3:
		assert_false(grid.is_ripe(c))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))


func test_unwatered_crop_does_not_grow() -> void:
	var c := Vector2i(1, 2)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.advance_day()
	assert_eq(grid.plots[c].stage, 0)


func test_multi_day_stages_carrot() -> void:
	var c := Vector2i(2, 1)
	grid.till(c)
	grid.plant(c, "carrot")   # stage_days [1,2,2] -> 5 watered days
	for day in 5:
		assert_false(grid.is_ripe(c))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))


func test_watered_flag_resets_each_day() -> void:
	var c := Vector2i(3, 1)
	grid.till(c)
	grid.water(c)
	grid.advance_day()
	assert_false(grid.plots[c].watered)


func test_harvest_cycle() -> void:
	var c := Vector2i(6, 6)
	grid.till(c)
	grid.plant(c, "turnip")
	assert_eq(grid.peek_harvest(c), "")
	for day in 3:
		grid.water(c)
		grid.advance_day()
	assert_eq(grid.peek_harvest(c), "turnip")
	grid.clear_crop(c)
	assert_eq(grid.peek_harvest(c), "")
	assert_true(grid.plots[c].tilled)           # soil stays tilled
	assert_true(grid.plant(c, "turnip"))        # replantable


func test_serialization_round_trip() -> void:
	grid.till(Vector2i(1, 1))
	grid.plant(Vector2i(1, 1), "pumpkin")
	grid.water(Vector2i(1, 1))
	grid.advance_day()
	var data := grid.to_dict()
	var grid2 := FarmGrid.new()
	grid2.tillable = grid.tillable
	add_child_autofree(grid2)
	grid2.from_dict(data)
	assert_eq(grid2.plots[Vector2i(1, 1)].crop_id, "pumpkin")
	assert_eq(grid2.plots[Vector2i(1, 1)].days_in_stage, 1)
	assert_false(grid2.plots[Vector2i(1, 1)].watered)


func test_grows_on_day_passed_signal() -> void:
	var c := Vector2i(7, 7)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.water(c)
	EventBus.day_passed.emit(2)
	assert_eq(grid.plots[c].stage, 1)
```

- [ ] **Step 2: Run suite — verify FAILURE** (FarmGrid not declared).

- [ ] **Step 3: Implement `scripts/farm/farm_grid.gd`**

```gdscript
class_name FarmGrid
extends Node
## Farm plot state and rules. Logic only — rendering is FarmRenderer's job.
## Serializes into SaveManager.world["farm_grid"] per the world-data contract.

signal plot_changed(cell: Vector2i)

@export var tillable := Rect2i(0, 0, 0, 0)

## cell -> {tilled: bool, watered: bool, crop_id: String, stage: int, days_in_stage: int}
var plots := {}


func _ready() -> void:
	add_to_group("farm_grid")
	# Named method, NOT a lambda: method connections are auto-disconnected
	# when this node is freed; lambda connections would outlive it and crash.
	EventBus.day_passed.connect(_on_day_passed)


func _on_day_passed(_day) -> void:
	advance_day()


func till(cell: Vector2i) -> bool:
	if not tillable.has_point(cell) or plots.has(cell):
		return false
	plots[cell] = {"tilled": true, "watered": false, "crop_id": "", "stage": 0, "days_in_stage": 0}
	plot_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	var p = plots.get(cell)
	if p == null or p.watered:
		return false
	p.watered = true
	plot_changed.emit(cell)
	return true


func plant(cell: Vector2i, crop_id: String) -> bool:
	var p = plots.get(cell)
	if p == null or p.crop_id != "" or ItemDB.get_crop(crop_id) == null:
		return false
	p.crop_id = crop_id
	p.stage = 0
	p.days_in_stage = 0
	plot_changed.emit(cell)
	return true


func is_ripe(cell: Vector2i) -> bool:
	var p = plots.get(cell)
	if p == null or p.crop_id == "":
		return false
	var crop := ItemDB.get_crop(p.crop_id)
	return p.stage >= crop.stage_days.size()


func peek_harvest(cell: Vector2i) -> String:
	if not is_ripe(cell):
		return ""
	return ItemDB.get_crop(plots[cell].crop_id).product_id


func clear_crop(cell: Vector2i) -> void:
	var p = plots.get(cell)
	if p == null:
		return
	p.crop_id = ""
	p.stage = 0
	p.days_in_stage = 0
	plot_changed.emit(cell)


func advance_day() -> void:
	for cell: Vector2i in plots:
		var p = plots[cell]
		if p.crop_id != "" and p.watered:
			var crop := ItemDB.get_crop(p.crop_id)
			if p.stage < crop.stage_days.size():
				p.days_in_stage += 1
				if p.days_in_stage >= crop.stage_days[p.stage]:
					p.stage += 1
					p.days_in_stage = 0
		p.watered = false
		plot_changed.emit(cell)


func to_dict() -> Dictionary:
	var out := {}
	for cell: Vector2i in plots:
		out["%d,%d" % [cell.x, cell.y]] = plots[cell].duplicate(true)
	return out


func from_dict(d: Dictionary) -> void:
	plots = {}
	for key: String in d:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		var raw: Dictionary = d[key]
		plots[cell] = {
			"tilled": bool(raw.get("tilled", true)),
			"watered": bool(raw.get("watered", false)),
			"crop_id": String(raw.get("crop_id", "")),
			"stage": int(raw.get("stage", 0)),
			"days_in_stage": int(raw.get("days_in_stage", 0)),
		}
		plot_changed.emit(cell)


func store() -> void:
	SaveManager.world["farm_grid"] = to_dict()


func restore() -> void:
	from_dict(SaveManager.world.get("farm_grid", {}))
```

- [ ] **Step 4: Run suite — ALL PASS** (10 new + 58 = 68), exit 0. If Task 4 used the `-> Node` workaround for `_farm_grid()`, restore the typed `-> FarmGrid` version now and re-run.
- [ ] **Step 5: Commit** — `git add scripts tests && git commit -m "feat: FarmGrid plot rules, growth, and world-blob serialization"`

---

### Task 6: Farm Map Scene + Boot Flow

**Files:**
- Create: `scripts/maps/farm.gd`, `scenes/maps/farm.tscn`
- Create: `scripts/farm/farm_renderer.gd`
- Create: `scripts/farm/bed.gd`, `scripts/farm/shipping_bin.gd` (stubs used fully in Tasks 8/11)
- Create: `scripts/main/boot.gd`, `scenes/main/boot.tscn`
- Modify: `project.godot` (main scene → boot.tscn)

- [ ] **Step 1: Implement `scripts/farm/farm_renderer.gd`**

```gdscript
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
```

- [ ] **Step 2: Implement `scripts/farm/bed.gd` and `scripts/farm/shipping_bin.gd`**

`scripts/farm/bed.gd`:

```gdscript
extends Area2D
## Interactable: sleeping ends the day (DayFlow arrives in Task 11).


func interact(_player: Player) -> void:
	var flow := get_tree().get_first_node_in_group("day_flow")
	if flow != null:
		flow.sleep()
	else:
		EventBus.toast_requested.emit("(sleep flow arrives in Task 11)")
```

`scripts/farm/shipping_bin.gd`:

```gdscript
extends Area2D
## Interactable: ships the whole selected stack; payout on day rollover (Task 8).


func interact(_player: Player) -> void:
	var s = Inventory.get_selected()
	if s == null:
		EventBus.toast_requested.emit("Select something to ship")
		return
	var data := ItemDB.get_item(s.id)
	if data == null or data.sell_price <= 0:
		EventBus.toast_requested.emit("Can't sell that")
		return
	var count: int = s.count
	Inventory.remove_item(s.id, count)
	var bin: Dictionary = SaveManager.world.get_or_add("shipping_bin", {})
	bin[s.id] = int(bin.get(s.id, 0)) + count
	EventBus.item_shipped.emit(s.id, count)
	EventBus.toast_requested.emit("Shipped %d× %s" % [count, data.display_name])
```

- [ ] **Step 3: Implement `scripts/maps/farm.gd`**

```gdscript
extends Node2D
## The farm map. World is built in code from MapBuilder + placeholder props.

const WIDTH := 44
const HEIGHT := 26
const TILLABLE := Rect2i(24, 10, 14, 10)
const BED_CELL := Vector2i(8, 6)
const BIN_CELL := Vector2i(11, 7)
const HOUSE_CELL := Vector2i(4, 4)      # top-left cell of 3x3 house footprint
const SPAWN_CELL := Vector2i(9, 9)

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
	player.global_position = MapBuilder.cell_center(SPAWN_CELL)
	world.add_child(player)

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
			elif y == 7 and x >= 3 and x <= 14:
				row += "P"
			elif (x * 7 + y * 13) % 29 == 0:
				row += "D"
			else:
				row += "G"
		rows.append(row)
	return rows


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
```

`scenes/maps/farm.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/maps/farm.gd" id="1"]

[node name="Farm" type="Node2D"]
script = ExtResource("1")
```

- [ ] **Step 4: Implement boot flow.**

`scripts/main/boot.gd`:

```gdscript
extends Node
## Boot: continue if a save exists, else new game, then go to the farm.
## Owns the load-failure fallback per the SaveManager contract.


func _ready() -> void:
	if not SaveManager.load_game():
		SaveManager.new_game()
	SceneChanger.travel.call_deferred("res://scenes/maps/farm.tscn", "default")
```

`scenes/main/boot.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main/boot.gd" id="1"]

[node name="Boot" type="Node"]
script = ExtResource("1")
```

`project.godot`: change `run/main_scene` to `"res://scenes/main/boot.tscn"`.

- [ ] **Step 5: Verify** — `"$GODOT" --headless --path . --import` then `"$GODOT" --headless --path . --quit-after 60; echo "exit: $?"` → exit 0, no SCRIPT ERROR (boot → fade → farm builds headless). Run suite → 68 passing still, exit 0.
- [ ] **Step 6: Commit** — `git add scripts scenes project.godot && git commit -m "feat: code-built farm map, renderer, props, and boot load-or-new flow"`

---

### Task 7: Farm Integration Test (till → plant → water → grow via player)

**Files:**
- Test: `tests/unit/test_farm_integration.gd`

- [ ] **Step 1: Write the test (this task is test-only — it validates Tasks 4-6 compose):**

```gdscript
extends GutTest

var farm: Node2D
var player: Player
var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_integration.json"
	SaveManager.new_game()
	farm = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_frames(2)
	player = farm.player
	grid = farm.grid


func after_each() -> void:
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_integration.json"):
		DirAccess.remove_absolute("user://test_integration.json")


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _stand_targeting(cell: Vector2i) -> void:
	player.global_position = MapBuilder.cell_center(cell + Vector2i.LEFT)
	player.facing = Vector2i.RIGHT


func test_full_farming_chain_through_player() -> void:
	var c := Vector2i(26, 12)   # inside TILLABLE Rect2i(24,10,14,10)
	_stand_targeting(c)

	_select("hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots.has(c), "hoe should till the target cell")
	assert_eq(GameState.rp, rp_before - 4, "hoe costs 4 RP")

	_select("turnip_seeds")
	var seeds_before := Inventory.count_of("turnip_seeds")
	player.try_use_selected()
	assert_eq(grid.plots[c].crop_id, "turnip")
	assert_eq(Inventory.count_of("turnip_seeds"), seeds_before - 1)

	_select("watering_can")
	player.try_use_selected()
	assert_true(grid.plots[c].watered)

	for day in 3:
		grid.water(c)
		Clock.end_day()
	assert_true(grid.is_ripe(c))

	player.try_interact()
	assert_eq(Inventory.count_of("turnip"), 1)
	assert_eq(grid.plots[c].crop_id, "")


func test_tilling_outside_field_fails_and_costs_nothing() -> void:
	_stand_targeting(Vector2i(3, 3))   # outside TILLABLE
	_select("hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_false(grid.plots.has(Vector2i(3, 3)))
	assert_eq(GameState.rp, rp_before)


func test_eating_restores_rp() -> void:
	Inventory.add_item("turnip", 1)
	GameState.rp = 10
	_select("turnip")
	player.try_use_selected()
	assert_eq(GameState.rp, 40)   # +30 from turnip
	assert_eq(Inventory.count_of("turnip"), 0)
```

- [ ] **Step 2: Run suite — ALL PASS** (3 new + 68 = 71), exit 0. (If `_select` fails: starting kit puts hoe/can/sword/seeds in the first slots — hotbar is slots 0-9, so they're all reachable.)
- [ ] **Step 3: Commit** — `git add tests && git commit -m "test: farm integration — full till/plant/water/grow/harvest chain via player"`

---

### Task 8: Shipping Payout

**Files:**
- Create: `scripts/farm/shipping.gd`
- Test: `tests/unit/test_shipping.gd`

- [ ] **Step 1: Write the failing test `tests/unit/test_shipping.gd`**

```gdscript
extends GutTest


func test_payout_sums_sell_prices() -> void:
	var bin := {"turnip": 3, "carrot": 2}          # 3*45 + 2*105 = 345
	assert_eq(Shipping.payout(bin), 345)


func test_payout_ignores_unknown_and_unsellable() -> void:
	assert_eq(Shipping.payout({"nonsense": 5}), 0)
	assert_eq(Shipping.payout({}), 0)


func test_bin_interact_ships_selected_stack() -> void:
	SaveManager.world.erase("shipping_bin")
	Inventory.reset()
	Inventory.add_item("turnip", 7)
	Inventory.select_hotbar(0)
	var bin_area := (load("res://scripts/farm/shipping_bin.gd") as GDScript).new()
	add_child_autofree(bin_area)
	bin_area.interact(null)
	assert_eq(Inventory.count_of("turnip"), 0)
	assert_eq(SaveManager.world["shipping_bin"]["turnip"], 7)
	assert_eq(Shipping.payout(SaveManager.world["shipping_bin"]), 7 * 45)
```

- [ ] **Step 2: Run suite — verify FAILURE** (Shipping not declared).

- [ ] **Step 3: Implement `scripts/farm/shipping.gd`**

```gdscript
class_name Shipping
extends RefCounted
## Overnight shipping payout math. The bin dict lives in
## SaveManager.world["shipping_bin"] as {item_id: count}.


static func payout(bin: Dictionary) -> int:
	var total := 0
	for id: String in bin:
		var item := ItemDB.get_item(id)
		if item != null and item.sell_price > 0:
			total += item.sell_price * int(bin[id])
	return total
```

Also relax `shipping_bin.gd`'s `interact` signature so the test can pass null: change `func interact(_player: Player) -> void:` to `func interact(_player) -> void:` (bed.gd too, for consistency).

- [ ] **Step 4: Run suite — ALL PASS** (3 new + 71 = 74), exit 0.
- [ ] **Step 5: Commit** — `git add scripts tests && git commit -m "feat: shipping payout math and bin shipping"`

---

### Task 9: HUD

**Files:**
- Create: `scripts/ui/hud.gd` (CanvasLayer, UI built in code)

- [ ] **Step 1: Implement `scripts/ui/hud.gd`**

```gdscript
class_name Hud
extends CanvasLayer
## HP/RP bars, gold, clock, hotbar, toasts. Pure EventBus consumer.

var hp_bar: ProgressBar
var rp_bar: ProgressBar
var gold_label: Label
var clock_label: Label
var day_label: Label
var toast_label: Label
var slot_panels: Array[Panel] = []
var slot_icons: Array[TextureRect] = []
var slot_counts: Array[Label] = []

var _toast_queue: PackedStringArray = []
var _toast_busy := false


func _ready() -> void:
	layer = 10
	add_to_group("hud")

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(8, 8)
	root.add_child(top_left)
	hp_bar = _bar(Color("c03030"))
	rp_bar = _bar(Color("30a060"))
	top_left.add_child(hp_bar)
	top_left.add_child(rp_bar)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-120, 8)
	top_right.custom_minimum_size = Vector2(112, 0)
	root.add_child(top_right)
	day_label = Label.new()
	clock_label = Label.new()
	gold_label = Label.new()
	for l in [day_label, clock_label, gold_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_right.add_child(l)

	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position = Vector2(-Inventory.HOTBAR * 22 / 2.0, -30)
	root.add_child(hotbar)
	for i in Inventory.HOTBAR:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(20, 20)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		panel.add_child(icon)
		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.position = Vector2(-12, -12)
		count.add_theme_font_size_override("font_size", 8)
		panel.add_child(count)
		hotbar.add_child(panel)
		slot_panels.append(panel)
		slot_icons.append(icon)
		slot_counts.append(count)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-100, 40)
	toast_label.custom_minimum_size = Vector2(200, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	# Named methods only — lambda connections would outlive this node when the
	# scene is freed (see FarmGrid note) and crash on later emissions.
	EventBus.stats_changed.connect(_refresh_stats)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.inventory_changed.connect(_refresh_hotbar)
	EventBus.hotbar_selection_changed.connect(_on_hotbar_selection)
	EventBus.toast_requested.connect(toast)
	_refresh_stats()
	_refresh_clock()
	_refresh_hotbar()


func _on_money_changed(_gold) -> void:
	_refresh_stats()


func _on_time_ticked(_h, _m) -> void:
	_refresh_clock()


func _on_day_passed(_d) -> void:
	_refresh_clock()


func _on_hotbar_selection(_i) -> void:
	_refresh_hotbar()


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(90, 10)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _refresh_stats() -> void:
	hp_bar.max_value = GameState.max_hp
	hp_bar.value = GameState.hp
	rp_bar.max_value = GameState.max_rp
	rp_bar.value = GameState.rp
	gold_label.text = "%dg" % GameState.gold


func _refresh_clock() -> void:
	clock_label.text = Clock.time_string()
	day_label.text = "Day %d" % Clock.day


func _refresh_hotbar() -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s == null:
			slot_icons[i].texture = null
			slot_counts[i].text = ""
		else:
			var item := ItemDB.get_item(s.id)
			slot_icons[i].texture = item.icon if item != null else null
			slot_counts[i].text = str(s.count) if s.count > 1 else ""
		slot_panels[i].modulate = Color(1.4, 1.4, 0.9) if i == Inventory.selected else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.HOTBAR:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotbar(i)
			return
	if event.is_action_pressed("hotbar_next"):
		Inventory.select_hotbar((Inventory.selected + 1) % Inventory.HOTBAR)
	elif event.is_action_pressed("hotbar_prev"):
		Inventory.select_hotbar((Inventory.selected - 1 + Inventory.HOTBAR) % Inventory.HOTBAR)


func toast(message: String) -> void:
	_toast_queue.append(message)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	toast_label.text = _toast_queue[0]
	_toast_queue.remove_at(0)
	var t := create_tween()
	t.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	t.tween_interval(1.4)
	t.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	t.tween_callback(_next_toast)
```

(`farm.gd` from Task 6 already auto-instances this script when the file exists — no farm.gd edit needed.)

- [ ] **Step 2: Verify** — import, boot headless (`--quit-after 60`) exit 0 no SCRIPT ERROR; suite still green (74).
- [ ] **Step 3: Commit** — `git add scripts && git commit -m "feat: HUD — bars, clock, gold, hotbar, toast queue"`

---

### Task 10: Inventory Screen

**Files:**
- Create: `scripts/ui/inventory_screen.gd`

- [ ] **Step 1: Implement `scripts/ui/inventory_screen.gd`**

```gdscript
class_name InventoryScreen
extends CanvasLayer
## Tab-toggled 3x10 grid; click one slot then another to swap/move.
## Pause convention: menus use get_tree().paused (this node keeps processing);
## Clock.paused stays reserved for scripted sequences (DayFlow).

var grid_box: GridContainer
var buttons: Array[Button] = []
var _pending := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	grid_box = GridContainer.new()
	grid_box.columns = Inventory.HOTBAR
	grid_box.set_anchors_preset(Control.PRESET_CENTER)
	grid_box.position = Vector2(-Inventory.HOTBAR * 24 / 2.0, -40)
	add_child(grid_box)

	for i in Inventory.SIZE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(22, 22)
		b.expand_icon = true
		b.pressed.connect(_on_slot_pressed.bind(i))
		grid_box.add_child(b)
		buttons.append(b)

	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	_pending = -1
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if _pending < 0:
		_pending = index
	else:
		Inventory.swap(_pending, index)
		_pending = -1
	_refresh()


func _refresh() -> void:
	for i in buttons.size():
		var s = Inventory.slots[i]
		if s == null:
			buttons[i].icon = null
			buttons[i].text = ""
		else:
			var item := ItemDB.get_item(s.id)
			buttons[i].icon = item.icon if item != null else null
			buttons[i].text = str(s.count) if s.count > 1 else ""
		buttons[i].modulate = Color(1.4, 1.4, 0.9) if i == _pending else Color.WHITE
```

- [ ] **Step 2: Verify** — boot headless exit 0; suite green (74). Note: `get_tree().paused` pauses the player and Clock (both PROCESS_MODE_INHERIT) — that's the intended menu-pause path.
- [ ] **Step 3: Commit** — `git add scripts && git commit -m "feat: inventory screen with click-swap and tree-pause convention"`

---

### Task 11: DayFlow (sleep/curfew/collapse), Debug Keys, Final Integration

**Files:**
- Create: `scripts/components/day_flow.gd`
- Create: `scripts/util/debug_keys.gd`
- Test: extend `tests/unit/test_farm_integration.gd`

- [ ] **Step 1: Add the failing test to `tests/unit/test_farm_integration.gd`:**

```gdscript
func test_day_flow_rollover_pays_shipping_and_saves() -> void:
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	assert_not_null(flow, "DayFlow should be in the farm scene")
	SaveManager.world["shipping_bin"] = {"turnip": 2}   # 2*45 = 90g
	var gold_before := GameState.gold
	var day_before := Clock.day
	GameState.rp = 5
	await flow.end_day(false)
	assert_eq(GameState.gold, gold_before + 90)
	assert_eq(Clock.day, day_before + 1)
	assert_eq(GameState.rp, GameState.max_rp)           # normal sleep = full RP
	assert_false(SaveManager.world.has("shipping_bin") and not SaveManager.world["shipping_bin"].is_empty())
	assert_true(SaveManager.has_save())                 # autosaved


func test_collapse_halves_rp() -> void:
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(true)
	assert_eq(GameState.rp, roundi(GameState.max_rp / 2.0))
```

- [ ] **Step 2: Run suite — verify FAILURE** (no node in group day_flow / no end_day).

- [ ] **Step 3: Implement `scripts/components/day_flow.gd`**

```gdscript
class_name DayFlow
extends Node
## Owns the end-of-day sequence: fade, shipping payout, day rollover,
## restore, autosave, reposition, fade back. Triggered by bed (sleep),
## curfew (2 AM), or player death (RP drain in Plan 2).

var _busy := false


func _ready() -> void:
	add_to_group("day_flow")
	# Named methods, NOT lambdas — see FarmGrid note (freed-node safety).
	EventBus.curfew_reached.connect(_on_curfew)
	EventBus.player_died.connect(_on_player_died)


func _on_curfew() -> void:
	end_day(true)


func _on_player_died() -> void:
	end_day(true)


func sleep() -> void:
	end_day(false)


func end_day(collapsed: bool) -> void:
	if _busy:
		return
	_busy = true
	Clock.paused = true
	await SceneChanger.fade_to_black()

	var bin: Dictionary = SaveManager.world.get("shipping_bin", {})
	var earned := Shipping.payout(bin)
	if earned > 0:
		GameState.add_gold(earned)
	SaveManager.world["shipping_bin"] = {}

	Clock.end_day()
	GameState.sleep_restore(collapsed)

	var grid := get_tree().get_first_node_in_group("farm_grid") as FarmGrid
	if grid != null:
		grid.store()
	SaveManager.save_game()

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.global_position = MapBuilder.cell_center(Vector2i(8, 8))

	await SceneChanger.fade_from_black()
	if collapsed:
		EventBus.toast_requested.emit("You collapsed... Day %d" % Clock.day)
	else:
		EventBus.toast_requested.emit("Day %d" % Clock.day)
	if earned > 0:
		EventBus.toast_requested.emit("Shipped goods: +%dg" % earned)
	Clock.paused = false
	_busy = false
```

- [ ] **Step 4: Implement `scripts/util/debug_keys.gd`**

```gdscript
extends Node
## Dev-build-only debug hotkeys (spec §14). F3 teleport lands in Plan 3.


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_gold"):
		GameState.add_gold(1000)
		EventBus.toast_requested.emit("+1000g (debug)")
	elif event.is_action_pressed("debug_skip_day"):
		var flow := get_tree().get_first_node_in_group("day_flow")
		if flow != null:
			flow.sleep()
	elif event.is_action_pressed("debug_refill"):
		GameState.heal(GameState.max_hp)
		GameState.restore_rp(GameState.max_rp)
		EventBus.toast_requested.emit("HP/RP refilled (debug)")
	elif event.is_action_pressed("debug_teleport"):
		EventBus.toast_requested.emit("Dungeon arrives in Plan 3")
```

- [ ] **Step 5: Run suite — ALL PASS** (2 new + 74 = 76), exit 0. Boot headless `--quit-after 120` → exit 0, no SCRIPT ERROR.

- [ ] **Step 6: Manual playtest checklist** (run windowed: `"$GODOT" --path . &` — Forrest or a screenshot pass verifies):
  - Walk with WASD; facing changes; camera follows within map bounds.
  - 1-0 keys + mouse wheel select hotbar; HUD highlights selection.
  - Hoe tills only field cells; can waters (tile darkens); seeds plant; crop sprite appears and changes color after watered sleeps.
  - E harvests ripe crop; E on bin ships selected stack; E on bed sleeps (fade, Day+1, gold toast if shipped).
  - Eating a turnip restores RP; RP empties → actions drain HP; HP 0 or 2 AM → collapse (half RP).
  - Tab opens inventory (game pauses), click-click moves stacks, Tab closes.
  - F1/F2/F4 work in dev build; quit + relaunch continues the same day/farm.

- [ ] **Step 7: Commit** — `git add scripts tests && git commit -m "feat: DayFlow sleep/collapse cycle, debug keys, integration coverage"`

---

## Done Criteria (Plan 2)

- Suite: 76 tests green headless, exit 0.
- `--quit-after 120` boots via boot.tscn → farm with zero script errors.
- The full farm day loop is playable end-to-end per the manual checklist.
- FarmGrid state survives save/load (autosave on sleep; boot continues the save).
- Plan 3 can start: StateMachine, player FSM, MapBuilder, and DayFlow are reusable for dungeon/combat; sword already spends RP through the same path combat will use.
