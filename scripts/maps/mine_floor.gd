class_name MineFloor
extends DungeonFloor
## Procedural mine floor (DEPTH stride): the "deep delve" past Dungeon Floor
## 3's boss room. ONE scene (scenes/maps/mine_floor.tscn) is reused for every
## depth — SceneChanger.travel() to the same scene path reloads it fresh
## (a new _ready()), so descending/ascending just re-enters this scene with
## SaveManager.world["mine"]["depth"] changed first.
##
## Layout/enemies/loot are generated from MineState.mix_seed(run_seed, depth)
## — deterministic per (run_seed, depth): re-entering the SAME depth on the
## SAME run always regenerates the identical floor (descend then ascend then
## descend again -> same layout), while a fresh dive (new run_seed, rolled on
## first entry from Floor 3) looks different. See MineState's class doc for
## the full contract.
##
## Structure mirrors dungeon_1/2/3.gd (carve_layout + FLOOR_RECTS), except
## the rects themselves are procedurally generated per depth instead of
## hand-authored — see _generate_rects(). Kept PLACEHOLDER-tile built (stone
## floor / wall), same MapBuilder tiles every other floor uses.
##
## Kill tracking reuses DungeonFloor's _spawn_enemies()/_on_floor_enemy_died()
## machinery by giving each depth its own _floor_key() ("mine_<depth>") so
## DungeonState's existing per-floor-key ledger just works unmodified for the
## CURRENT calendar day. MineState's OWN per-run ledger (SaveManager.world
## ["mine"]["killed"]) additionally tracks kills for descend/re-ascend within
## a single dive, independent of day rollover — see _spawn_enemies override.

const SIZE := Vector2i(30, 20)
const ENTRANCE_ROOM := Rect2i(2, 2, 6, 5)
const ENTRANCE_CELL := Vector2i(4, 4)
const ASCEND_CELL := Vector2i(3, 3)     # stairs up (to previous depth / entrance)

const BASE_ENEMY_COUNT := 4

## Monster pool by rough tier — deeper dives lean on tougher ids. Every id
## here must resolve in ItemDB (content meta test enforces this).
const ENEMY_POOL_SHALLOW := ["slime", "slime", "wisp"]
const ENEMY_POOL_MID := ["slime", "wisp", "wisp", "goblin"]
const ENEMY_POOL_DEEP := ["wisp", "goblin", "goblin"]

## Treasure-floor bonus loot pool (materials only — never tools/food, keeps
## this additive to the existing drop-table economy rather than replacing it).
const TREASURE_LOOT_POOL := ["slime_gel", "wisp_dust", "goblin_fang", "driftglass"]

var depth: int = MineState.ENTRY_DEPTH
var run_seed: int = 0
var floor_type: MineState.FloorType = MineState.FloorType.NORMAL
var _rects: Array = []


func _ready() -> void:
	add_to_group("mine_floor")  # HUD depth indicator lookup, see hud.gd
	var blob: Dictionary = SaveManager.world.get("mine", {})
	depth = int(blob.get("depth", MineState.ENTRY_DEPTH))
	if depth < MineState.ENTRY_DEPTH:
		depth = MineState.ENTRY_DEPTH
	run_seed = int(blob.get("run_seed", 0))
	floor_type = MineState.roll_floor_type(run_seed, depth)
	_rects = _generate_rects(run_seed, depth)
	super._ready()
	var world := get_node("World") as Node2D
	_add_mine_portals(world)
	_add_treasure_loot(world)
	EventBus.toast_requested.emit("Depth %d — %s" % [depth, MineState.floor_type_name(floor_type)])


func _floor_key() -> String:
	return "mine_%d" % depth


func _layout() -> PackedStringArray:
	if _rects.is_empty():
		_rects = _generate_rects(run_seed, depth)
	return carve_layout(SIZE, _rects)


func _spawns() -> Dictionary:
	return {
		"default": ENTRANCE_CELL,
		"entrance": ENTRANCE_CELL,
		"from_ascend": ENTRANCE_CELL,
	}


func _portals() -> Array:
	## Empty on purpose: ascend/descend portals need `depth` math (previous
	## depth ascends to a real scene, depth+1 for descend) that PORTALS-style
	## static config can't express, so they're built directly in _ready() via
	## _add_mine_portals() instead — see that method + _write_depth().
	return []


func _enemy_spawns() -> Array:
	if _rects.is_empty():
		_rects = _generate_rects(run_seed, depth)
	return _generate_enemy_spawns(run_seed, depth, floor_type, _rects)


## ---- procedural generation (deterministic per run_seed+depth) ----

static func _generate_rects(seed_run: int, at_depth: int) -> Array:
	## A simple deterministic room-and-corridor carve: a fixed entrance room
	## (top-left, matches ENTRANCE_ROOM/ASCEND_CELL/ENTRANCE_CELL every depth
	## so spawn/portal placement never has to be regenerated), plus 3-5
	## additional rooms scattered across the grid and linked with straight
	## corridors back toward the entrance — enough variety to look "different
	## per depth" while staying trivially walkable (every room connects,
	## directly or transitively, to the entrance).
	var rng := RandomNumberGenerator.new()
	rng.seed = MineState.mix_seed(seed_run, at_depth)
	var rects: Array = [ENTRANCE_ROOM]
	var room_count := 3 + rng.randi() % 3  # 3-5 extra rooms
	var anchors: Array = [ENTRANCE_ROOM]
	for i in room_count:
		var w := 4 + rng.randi() % 5
		var h := 3 + rng.randi() % 4
		var max_x: int = maxi(1, SIZE.x - w - 1)
		var max_y: int = maxi(1, SIZE.y - h - 1)
		var x := 1 + rng.randi() % max_x
		var y := 1 + rng.randi() % max_y
		var room := Rect2i(x, y, w, h)
		rects.append(room)
		# Corridor from this room's center back to a random EARLIER anchor
		# (always at least the entrance) — guarantees connectivity without
		# needing a real pathfinding carve.
		var anchor: Rect2i = anchors[rng.randi() % anchors.size()]
		rects.append_array(_corridor_between(room.get_center(), anchor.get_center()))
		anchors.append(room)
	return rects


static func _corridor_between(a: Vector2i, b: Vector2i) -> Array:
	## L-shaped 1-wide corridor (horizontal leg then vertical leg), each leg
	## expressed as a thin Rect2i so carve_layout's existing has_point() scan
	## handles it with no new logic.
	var out: Array = []
	var min_x: int = mini(a.x, b.x)
	var max_x: int = maxi(a.x, b.x)
	out.append(Rect2i(min_x, a.y, max_x - min_x + 1, 1))
	var min_y: int = mini(a.y, b.y)
	var max_y: int = maxi(a.y, b.y)
	out.append(Rect2i(b.x, min_y, 1, max_y - min_y + 1))
	return out


static func _pool_for_depth(at_depth: int) -> Array:
	if at_depth <= 3:
		return ENEMY_POOL_SHALLOW
	elif at_depth <= 7:
		return ENEMY_POOL_MID
	return ENEMY_POOL_DEEP


static func _generate_enemy_spawns(seed_run: int, at_depth: int, type: MineState.FloorType, rects: Array) -> Array:
	## Quiet floors spawn far fewer enemies (bible: "quiet"); monster-dense
	## floors spawn extra on top of the depth-scaled base count; treasure
	## floors spawn fewer foes (bible: "more pickups, fewer foes"). Cells are
	## picked from non-entrance room interiors so nothing spawns on top of
	## the player or the ascend stairs.
	var rng := RandomNumberGenerator.new()
	rng.seed = MineState.mix_seed(seed_run, at_depth) ^ 0x1234abcd
	var base_count := MineState.enemy_density_for(at_depth, BASE_ENEMY_COUNT)
	var count := base_count
	match type:
		MineState.FloorType.MONSTER_DENSE:
			count = base_count + 3
		MineState.FloorType.TREASURE:
			count = maxi(1, base_count - 2)
		MineState.FloorType.QUIET:
			count = maxi(1, base_count / 2)
	var candidates := _spawnable_cells(rects)
	if candidates.is_empty():
		return []
	# Deterministic shuffle (Fisher-Yates), same technique as Forage.spawn_cells.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var pool := _pool_for_depth(at_depth)
	var out: Array = []
	for i in mini(count, candidates.size()):
		var id: String = pool[rng.randi() % pool.size()]
		out.append({"id": id, "cell": candidates[i]})
	return out


static func _spawnable_cells(rects: Array) -> Array:
	var out: Array = []
	for r: Rect2i in rects:
		if r == ENTRANCE_ROOM:
			continue
		# Skip 1-wide corridor rects (either dimension == 1) — spawning an
		# enemy in a corridor is a valid gameplay choice in principle, but
		# room interiors read better and keep this simple/deterministic.
		if r.size.x <= 1 or r.size.y <= 1:
			continue
		for y in range(r.position.y + 1, r.position.y + r.size.y - 1):
			for x in range(r.position.x + 1, r.position.x + r.size.x - 1):
				out.append(Vector2i(x, y))
	return out


static func _descend_cell(rects: Array) -> Vector2i:
	## Farthest room's center from the entrance — puts the way down at the
	## opposite end of the floor from the way up, same "explore across the
	## floor" shape as the hand-authored dungeons.
	var best: Rect2i = ENTRANCE_ROOM
	var best_dist := -1.0
	for r: Rect2i in rects:
		if r.size.x <= 1 or r.size.y <= 1:
			continue  # corridor rect, not a room
		var d: float = Vector2(r.get_center()).distance_to(Vector2(ENTRANCE_ROOM.get_center()))
		if d > best_dist:
			best_dist = d
			best = r
	return best.get_center()


## ---- portals + treasure loot (need depth math, added post-super._ready()) ----

func _add_mine_portals(world: Node2D) -> void:
	var ascend := Portal.make({
		"cell": ASCEND_CELL,
		"target_scene": "res://scenes/maps/mine_floor.tscn",
		"target_spawn": "from_ascend",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Ascend" if depth > MineState.ENTRY_DEPTH else "Back to Floor 3",
	})
	ascend.name = "AscendPortal"
	ascend.pre_travel = _write_depth.bind(depth - 1)
	if depth <= MineState.ENTRY_DEPTH:
		# Depth 1 ascends OUT of the mine entirely, back to dungeon_3's entry
		# room — a real scene swap, not a mine_floor reload.
		ascend.target_scene = "res://scenes/maps/dungeon_3.tscn"
		ascend.target_spawn = "from_below"
		ascend.pre_travel = Callable()  # leaving the mine: depth is meaningless, don't touch the blob
	world.add_child(ascend)

	var descend_cell := _descend_cell(_rects)
	var descend := Portal.make({
		"cell": descend_cell,
		"target_scene": "res://scenes/maps/mine_floor.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Descend",
	})
	descend.name = "DescendPortal"
	descend.pre_travel = _write_depth.bind(depth + 1)
	world.add_child(descend)


func _write_depth(new_depth: int) -> void:
	## pre_travel callback (bound with the target depth) — records the new
	## depth (and bumps "deepest" if applicable) into SaveManager.world
	## ["mine"] BEFORE SceneChanger.travel() reloads mine_floor.tscn, so the
	## incoming _ready() reads the right depth. run_seed is preserved as-is
	## (same dive, just moving between its depths).
	var blob := MineState.ensure_run(SaveManager.world.get("mine", {}), run_seed)
	blob = MineState.record_depth(blob, new_depth)
	SaveManager.world["mine"] = blob


func _add_treasure_loot(world: Node2D) -> void:
	## Treasure floors (bible: "more pickups") scatter a handful of bonus
	## Pickup items across non-entrance rooms, on top of the ordinary enemy
	## drop table — deterministic per (run_seed, depth), distinct RNG stream
	## from enemy spawning.
	if floor_type != MineState.FloorType.TREASURE:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = MineState.mix_seed(run_seed, depth) ^ 0x7ee7a5f
	var candidates := _spawnable_cells(_rects)
	if candidates.is_empty():
		return
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var loot_count := mini(4, candidates.size())
	if not ResourceLoader.exists("res://scenes/enemies/pickup.tscn"):
		return
	for i in loot_count:
		var item_id: String = TREASURE_LOOT_POOL[rng.randi() % TREASURE_LOOT_POOL.size()]
		var pickup: Node2D = (load("res://scenes/enemies/pickup.tscn") as PackedScene).instantiate()
		pickup.set("item_id", item_id)
		world.add_child(pickup)
		pickup.global_position = MapBuilder.cell_center(candidates[i])


## ---- kill tracking: per-run ledger on top of DungeonFloor's per-day one ----

func _spawn_enemies(world: Node2D) -> void:
	## Overrides DungeonFloor's version to ALSO gate spawns on MineState's
	## per-run ledger (killed this dive, at this depth) — not just the daily
	## DungeonState one. A mine depth is regenerated fresh every visit anyway
	## (new floor layout each descend per the determinism contract), but
	## re-ascending then re-descending to the SAME depth on the SAME run must
	## not respawn things already cleared THIS run — same day or not.
	var day_blob := DungeonState.ensure_day(
		SaveManager.world.get("dungeon_state", {}), Clock.day)
	SaveManager.world["dungeon_state"] = day_blob

	var mine_blob := MineState.ensure_run(SaveManager.world.get("mine", {}), run_seed)
	SaveManager.world["mine"] = mine_blob

	var configs := _enemy_spawns()
	for i in configs.size():
		if DungeonState.is_killed(day_blob, _floor_key(), i):
			continue
		if MineState.is_killed(mine_blob, depth, i):
			continue
		var enemy := Enemy.spawn_enemy(configs[i]["id"], configs[i]["cell"], world)
		# Deterministic gold/xp/drop rolls per (run_seed, depth, spawn index) —
		# same reasoning as MineState.mix_seed: a mine floor's enemy outcomes
		# must be reproducible for the SAME dive, distinct per spawn slot.
		enemy.rng = RandomNumberGenerator.new()
		enemy.rng.seed = MineState.mix_seed(run_seed, depth) ^ (i * 0x2545f491 + 1)
		enemy.health.died.connect(_on_mine_enemy_died.bind(i))


func _on_mine_enemy_died(spawn_index: int) -> void:
	var day_blob := DungeonState.ensure_day(
		SaveManager.world.get("dungeon_state", {}), Clock.day)
	day_blob = DungeonState.record_kill(day_blob, _floor_key(), spawn_index)
	SaveManager.world["dungeon_state"] = day_blob

	var mine_blob := MineState.ensure_run(SaveManager.world.get("mine", {}), run_seed)
	mine_blob = MineState.record_kill(mine_blob, depth, spawn_index)
	SaveManager.world["mine"] = mine_blob
