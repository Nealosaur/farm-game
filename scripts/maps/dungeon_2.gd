extends DungeonFloor
## Dungeon Floor 2 — mid floor. Tighter layout: smaller rooms joined by
## 1-tile corridors, mixed enemies (slimes + wisps + goblins). Stairs up to
## Floor 1, stairs down to Floor 3.

const FLOOR_KEY := "dungeon_2"
const SIZE := Vector2i(30, 20)

const FLOOR_RECTS := [
	Rect2i(2, 2, 6, 5),     # entrance room (stairs up to Floor 1)
	Rect2i(8, 4, 6, 1),     # 1-wide corridor east
	Rect2i(14, 2, 6, 5),    # north room
	Rect2i(16, 7, 1, 4),    # 1-wide corridor south
	Rect2i(13, 11, 8, 5),   # central room
	Rect2i(21, 13, 4, 1),   # 1-wide corridor east
	Rect2i(25, 11, 3, 7),   # east room (stairs down)
	Rect2i(3, 7, 1, 5),     # 1-wide corridor south from entrance
	Rect2i(2, 12, 6, 5),    # south-west room
	Rect2i(8, 14, 5, 1),    # 1-wide corridor SW room -> central room
]

# Spawn cells sit 2-3 cells off their matching portal tile (anti-bounce rule 1).
const SPAWNS := {
	"default": Vector2i(5, 5),
	"entrance": Vector2i(5, 5),      # arriving from Floor 1 (stairs up at 3,3)
	"from_below": Vector2i(26, 13),  # arriving from Floor 3 (stairs down at 26,16)
}

const PORTALS := [
	{
		"cell": Vector2i(3, 3),
		"target_scene": "res://scenes/maps/dungeon_1.tscn",
		"target_spawn": "from_below",
		"sprite": "res://assets/placeholder/prop_stairs_up.png",
		"label": "Dungeon — Floor 1",
	},
	{
		"cell": Vector2i(26, 16),
		"target_scene": "res://scenes/maps/dungeon_3.tscn",
		"target_spawn": "entrance",
		"sprite": "res://assets/placeholder/prop_stairs_down.png",
		"label": "Dungeon — Floor 3",
	},
]

const ENEMY_SPAWNS := [
	{"id": "slime", "cell": Vector2i(15, 4)},
	{"id": "slime", "cell": Vector2i(14, 12)},
	{"id": "slime", "cell": Vector2i(4, 14)},
	{"id": "wisp", "cell": Vector2i(18, 13)},
	{"id": "wisp", "cell": Vector2i(6, 15)},
	{"id": "goblin", "cell": Vector2i(19, 15)},
	{"id": "goblin", "cell": Vector2i(25, 15)},
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
