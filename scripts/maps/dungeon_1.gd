extends DungeonFloor
## Dungeon Floor 1 — intro floor. Wide rooms, forgiving corridors, slimes
## only. Stairs up return to the farm; stairs down lead to Floor 2.

const FLOOR_KEY := "dungeon_1"
const SIZE := Vector2i(30, 20)

# Deterministic hand-placed rooms/corridors (see DungeonFloor.carve_layout).
const FLOOR_RECTS := [
	Rect2i(2, 2, 8, 7),     # entrance room (stairs up to farm)
	Rect2i(10, 5, 8, 2),    # east corridor
	Rect2i(18, 2, 10, 8),   # north-east room
	Rect2i(22, 10, 2, 4),   # corridor down to south room
	Rect2i(14, 14, 14, 4),  # south room (stairs down)
	Rect2i(4, 9, 2, 5),     # corridor down from entrance
	Rect2i(2, 14, 10, 4),   # south-west room
	Rect2i(12, 15, 2, 2),   # link corridor SW room -> south room
]

# Spawn cells sit 2 cells off their matching portal tile (anti-bounce rule 1).
const SPAWNS := {
	"default": Vector2i(5, 4),
	"entrance": Vector2i(5, 4),      # arriving from the farm (stairs up at 3,3)
	"from_below": Vector2i(24, 16),  # arriving from Floor 2 (stairs down at 26,16)
}

const PORTALS := [
	{
		"cell": Vector2i(3, 3),
		"target_scene": "res://scenes/maps/farm.tscn",
		"target_spawn": "from_dungeon",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Back to the farm",
	},
	{
		"cell": Vector2i(26, 16),
		"target_scene": "res://scenes/maps/dungeon_2.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Dungeon — Floor 2",
	},
]

const ENEMY_SPAWNS := [
	{"id": "slime", "cell": Vector2i(20, 5)},
	{"id": "slime", "cell": Vector2i(25, 7)},
	{"id": "slime", "cell": Vector2i(6, 15)},
	{"id": "slime", "cell": Vector2i(9, 16)},
	{"id": "slime", "cell": Vector2i(17, 15)},
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
