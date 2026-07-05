extends GutTest
## Confirms the AUTO_INSTANCE_SCRIPTS additions this stride (DayTint,
## PauseMenu) don't break full in-tree instantiation of farm, dungeon_1, and
## town — each scene should boot cleanly and carry exactly one DayTint and one
## PauseMenu child alongside the existing HUD/DayFlow/debug_keys set.
## NOT covered headless: actual portal travel (see test_dungeon_integration.gd
## doc) — these tests only instantiate and inspect children, never travel.

const SCENES := [
	"res://scenes/maps/farm.tscn",
	"res://scenes/maps/dungeon_1.tscn",
	"res://scenes/maps/town.tscn",
]


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_auto_instance.json"
	SaveManager.new_game()
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_auto_instance.json"):
		DirAccess.remove_absolute("user://test_auto_instance.json")


func _has_child_of_type(root: Node, type_script) -> bool:
	for child in root.get_children():
		if is_instance_of(child, type_script):
			return true
	return false


func test_each_map_boots_with_day_tint_and_pause_menu() -> void:
	for scene_path: String in SCENES:
		var scene: Node = (load(scene_path) as PackedScene).instantiate()
		add_child_autofree(scene)
		await wait_process_frames(2)
		assert_true(_has_child_of_type(scene, DayTint), scene_path + " should have a DayTint child")
		assert_true(_has_child_of_type(scene, PauseMenu), scene_path + " should have a PauseMenu child")
		assert_true(_has_child_of_type(scene, Hud), scene_path + " should still have its HUD child")


func test_day_tint_matches_current_clock_minutes_on_boot() -> void:
	Clock.minutes = 22 * 60  # night
	var scene: Node = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	var tint: DayTint = null
	for child in scene.get_children():
		if child is DayTint:
			tint = child
	assert_not_null(tint)
	assert_eq(tint.color, DayTint.NIGHT)
	Clock.minutes = Clock.DAY_START_MINUTES
