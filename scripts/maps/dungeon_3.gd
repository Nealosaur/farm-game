extends DungeonFloor
## Dungeon Floor 3 — deepest floor for this stride. A guard room of goblins
## and wisps protects a BOSS ROOM holding the Slime King. Only stairs up here
## — the boss room seals the run for the duration of the fight, so the way
## out is back the way you came (or collapsing at 2 AM, which DayFlow now
## handles from any scene).
##
## Boss stride wiring (all scene-local per spec):
##  - Boss spawns at BOSS_CELL on load ONLY if GameState.flags["boss_defeated"]
##    is not already true (permanent kill, tracked outside the daily
##    DungeonState ledger — see SlimeKing class doc).
##  - ArenaGate seals ARENA_GATE_CELLS (the corridor into the boss room) the
##    moment the player crosses into the boss room rect, and unseals on boss
##    death or player collapse. Seal state is scene-local (fresh ArenaGate
##    per load), so a respawned visit after a collapse is always unsealed.
##  - BossHealthBar (HUD-level CanvasLayer) tracks the boss's HealthComponent
##    while it's alive on this floor.
##  - VictorySequence listens for EventBus.boss_defeated and runs the freeze/
##    toast/flash flow, independent of whether GameState.flags already latched
##    (a fresh load after the boss is dead never spawns it, so the signal
##    can't refire from this floor again).

const FLOOR_KEY := "dungeon_3"
const SIZE := Vector2i(34, 22)

## Where the boss stands when spawned. Keep inside the boss room rect below.
const BOSS_CELL := Vector2i(27, 10)

## DEPTH stride: the "deep delve" ladder down into the procedural mine, only
## reachable once the boss is defeated (GameState.flags["boss_defeated"]) —
## carved into the entrance room, away from ASCEND (3,10) and DEFAULT (5,11)
## so it never collides with those tiles (layout sanity test enforces this
## the same way it does for every other portal on this floor).
const MINE_ENTRANCE_CELL := Vector2i(6, 9)

## The corridor cells connecting the guard room to the boss room — sealed by
## ArenaGate once the player crosses in, for the duration of the fight.
const ARENA_GATE_CELLS := [Vector2i(20, 10), Vector2i(20, 11)]

## Boss room rect (must match the rect containing BOSS_CELL in FLOOR_RECTS).
## The ArenaGate trigger area covers this rect's entrance edge.
const ARENA_TRIGGER_RECT := Rect2i(22, 4, 2, 14)

const FLOOR_RECTS := [
	Rect2i(2, 8, 6, 6),      # entrance room (stairs up to Floor 2)
	Rect2i(8, 10, 4, 2),     # corridor east
	Rect2i(12, 6, 8, 10),    # guard room
	Rect2i(20, 10, 2, 2),    # corridor into the boss room (ARENA_GATE_CELLS)
	Rect2i(22, 4, 10, 14),   # BOSS ROOM — Slime King spawns at BOSS_CELL
]

# Spawn cell sits 2 cells off the stairs-up tile (anti-bounce rule 1).
const SPAWNS := {
	"default": Vector2i(5, 11),
	"entrance": Vector2i(5, 11),  # arriving from Floor 2 (stairs up at 3,10)
	"from_below": Vector2i(5, 8),  # arriving back from the mine (ascend from depth 1)
}

const PORTALS := [
	{
		"cell": Vector2i(3, 10),
		"target_scene": "res://scenes/maps/dungeon_2.tscn",
		"target_spawn": "from_below",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Dungeon — Floor 2",
	},
	# No stairs down: the boss room seals the run this stride.
]

# Guard room only — nothing spawns in the boss room.
const ENEMY_SPAWNS := [
	{"id": "goblin", "cell": Vector2i(14, 8)},
	{"id": "goblin", "cell": Vector2i(17, 12)},
	{"id": "goblin", "cell": Vector2i(14, 14)},
	{"id": "wisp", "cell": Vector2i(18, 7)},
	{"id": "wisp", "cell": Vector2i(13, 11)},
]


func _floor_key() -> String:
	return FLOOR_KEY


func _layout() -> PackedStringArray:
	return carve_layout(SIZE, FLOOR_RECTS)


func _spawns() -> Dictionary:
	return SPAWNS


func _portals() -> Array:
	return PORTALS


func _enemy_spawns() -> Array:
	return ENEMY_SPAWNS


var _boss: SlimeKing
var _arena_gate: ArenaGate
var _health_bar: BossHealthBar


func _ready() -> void:
	super._ready()

	var world := get_node("World") as Node2D

	EventBus.player_died.connect(_on_player_died)

	if not GameState.flags.get("boss_defeated", false):
		# Gate only exists while the boss lives — a beaten arena never
		# re-seals (post-victory re-entry softlock, milestone review fix).
		_arena_gate = ArenaGate.new()
		_arena_gate.name = "ArenaGate"
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# Trigger area in pixels: top-left of the tile rect to bottom-right,
		# positioned at its center (Area2D/CollisionShape2D convention).
		var top_left := Vector2(ARENA_TRIGGER_RECT.position) * MapBuilder.TILE
		var size_px := Vector2(ARENA_TRIGGER_RECT.size) * MapBuilder.TILE
		rect.size = size_px
		shape.shape = rect
		shape.position = top_left + size_px / 2.0
		_arena_gate.add_child(shape)
		world.add_child(_arena_gate)
		_arena_gate.setup(ARENA_GATE_CELLS)

		_boss = SlimeKing.spawn_boss(BOSS_CELL, world)
		_health_bar = BossHealthBar.new()
		add_child(_health_bar)
		_health_bar.track(_boss)
	else:
		# DEPTH stride: the deep-delve ladder only appears once the boss is
		# beaten (matches the design doc's "a deep delve ladder on floor 3
		# after the boss" placement) — carved into the entrance room, see
		# MINE_ENTRANCE_CELL's doc.
		_add_mine_entrance(world)

	var victory := VictorySequence.new()
	victory.name = "VictorySequence"
	add_child(victory)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _add_mine_entrance(world: Node2D) -> void:
	var portal := Portal.make({
		"cell": MINE_ENTRANCE_CELL,
		"target_scene": "res://scenes/maps/mine_floor.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Deep Delve",
	})
	portal.name = "MineEntrancePortal"
	# Every fresh entry from Floor 3 starts a NEW dive (bible: "new seed each
	# fresh dive") — reroll run_seed from an engine-random source ONLY here
	# (the one place a dive begins); every subsequent depth transition inside
	# the mine reuses the same run_seed via MineFloor._write_depth().
	portal.pre_travel = _start_new_dive
	world.add_child(portal)


func _start_new_dive() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var blob := MineState.ensure_run(SaveManager.world.get("mine", {}), rng.randi())
	SaveManager.world["mine"] = blob


func _on_boss_defeated() -> void:
	if _arena_gate != null:
		_arena_gate.on_boss_defeated()


func _on_player_died() -> void:
	if _arena_gate != null:
		_arena_gate.on_player_collapsed()
