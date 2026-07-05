extends GutTest
## Headless integration for dungeon floor 1: enemies spawn per config minus
## today's kills; a kill via HealthComponent lands in the world blob; a
## rebuilt floor omits that spawn index; a new day respawns everyone.
##
## NOT covered headless (documented tradeoff): actual portal travel and
## DayFlow's away-from-farm hand-off — both run change_scene_to_file, which
## would tear down GUT's own scene mid-run. Their guard/branch logic is
## unit-tested (test_portal.gd, DungeonState tests, FarmGrid
## advance_stored_day test); the full loop is exercised in play via the
## farm stairs and F3.

const FLOOR_SCENE := "res://scenes/maps/dungeon_1.tscn"
const FLOOR_ENEMY_COUNT := 5   # dungeon_1.gd ENEMY_SPAWNS size


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_dungeon.json"
	SaveManager.new_game()
	SceneChanger.spawn_name = "entrance"


func after_each() -> void:
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_dungeon.json"):
		DirAccess.remove_absolute("user://test_dungeon.json")


func _make_floor() -> Node2D:
	var f: Node2D = (load(FLOOR_SCENE) as PackedScene).instantiate()
	return f


func _floor_enemies(floor_node: Node) -> Array:
	var out := []
	for child in floor_node.get_node("World").get_children():
		if child is Enemy:
			out.append(child)
	return out


func _floor_player(floor_node: Node) -> Player:
	for child in floor_node.get_node("World").get_children():
		if child is Player:
			return child
	return null


func test_floor_spawns_enemies_and_player_per_config() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(_floor_enemies(f).size(), FLOOR_ENEMY_COUNT)
	var player := _floor_player(f)
	assert_not_null(player)
	assert_eq(player.global_position, MapBuilder.cell_center(Vector2i(5, 4)),
		"player lands at the 'entrance' spawn cell")
	assert_eq(int(SaveManager.world["dungeon_state"]["day"]), Clock.day,
		"floor load stamps the ledger with today")


func test_kill_records_in_blob_and_absent_on_same_day_reload() -> void:
	var f1 := _make_floor()
	add_child(f1)
	await wait_process_frames(2)
	var victim: Enemy = _floor_enemies(f1)[0]
	victim.health.take_damage(9999)
	await wait_process_frames(1)

	var blob: Dictionary = SaveManager.world.get("dungeon_state", {})
	assert_true(DungeonState.is_killed(blob, "dungeon_1", 0),
		"death must be recorded under this floor's key + spawn index")
	assert_eq((blob["killed"]["dungeon_1"] as Array).size(), 1)

	f1.free()
	var f2 := _make_floor()
	add_child_autofree(f2)
	await wait_process_frames(2)
	assert_eq(_floor_enemies(f2).size(), FLOOR_ENEMY_COUNT - 1,
		"killed enemy must not respawn when re-entering the same day")


func test_seeded_same_day_kills_reduce_spawns() -> void:
	SaveManager.world["dungeon_state"] = {
		"day": Clock.day,
		"killed": {"dungeon_1": [1, 3]},
	}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(_floor_enemies(f).size(), FLOOR_ENEMY_COUNT - 2)


func test_new_day_respawns_everyone() -> void:
	SaveManager.world["dungeon_state"] = {
		"day": Clock.day - 1,   # yesterday's ledger
		"killed": {"dungeon_1": [0, 1, 2, 3, 4]},
	}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(_floor_enemies(f).size(), FLOOR_ENEMY_COUNT,
		"a new day resets the ledger — everything respawns")
	assert_eq(int(SaveManager.world["dungeon_state"]["day"]), Clock.day)


func test_other_floor_kills_do_not_affect_floor_one() -> void:
	SaveManager.world["dungeon_state"] = {
		"day": Clock.day,
		"killed": {"dungeon_2": [0, 1, 2]},
	}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(_floor_enemies(f).size(), FLOOR_ENEMY_COUNT,
		"the ledger is keyed per floor")
