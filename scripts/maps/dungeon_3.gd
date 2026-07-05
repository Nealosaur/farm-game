extends DungeonFloor
## Dungeon Floor 3 — deepest floor for this stride. A guard room of goblins
## and wisps protects a BIG OPEN BOSS ROOM which is deliberately left EMPTY:
## the boss (slime_king data already exists in data/enemies/) arrives next
## stride and will spawn at BOSS_CELL. Only stairs up here — the boss room
## seals the run for now, so the way out is back the way you came (or
## collapsing at 2 AM, which DayFlow now handles from any scene).

const FLOOR_KEY := "dungeon_3"
const SIZE := Vector2i(34, 22)

## Where the boss will stand when the boss stride lands. Keep inside the
## boss room rect below.
const BOSS_CELL := Vector2i(27, 10)

const FLOOR_RECTS := [
	Rect2i(2, 8, 6, 6),      # entrance room (stairs up to Floor 2)
	Rect2i(8, 10, 4, 2),     # corridor east
	Rect2i(12, 6, 8, 10),    # guard room
	Rect2i(20, 10, 2, 2),    # corridor into the boss room
	Rect2i(22, 4, 10, 14),   # BOSS ROOM — left empty on purpose (see above)
]

# Spawn cell sits 2 cells off the stairs-up tile (anti-bounce rule 1).
const SPAWNS := {
	"default": Vector2i(5, 11),
	"entrance": Vector2i(5, 11),  # arriving from Floor 2 (stairs up at 3,10)
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
