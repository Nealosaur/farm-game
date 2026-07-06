extends GutTest
## Craft Stride 1: Kitchen prop headless integration — mirrors
## test_farm_integration.gd's shape. Confirms the real farm.tscn places a
## Kitchen prop beside the house and that interacting with it opens the
## CookingScreen (which the farm's UI-instancing loop should have built).

const FarmScript := preload("res://scripts/maps/farm.gd")

var farm: Node2D
var player: Player


func before_each() -> void:
	Clock.paused = true
	Clock.weather = "clear"
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	GameState.reset_new_game()
	Inventory.reset()
	SaveManager.save_path = "user://test_kitchen.json"
	SaveManager.new_game()
	farm = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	player = farm.player


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.weather = "clear"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_kitchen.json"):
		DirAccess.remove_absolute("user://test_kitchen.json")


func _kitchen() -> Node:
	return farm.get_node("World/Kitchen")


func test_kitchen_prop_present_on_farm() -> void:
	assert_not_null(_kitchen(), "farm.tscn should build a Kitchen prop")


func test_kitchen_prop_placed_beside_the_house() -> void:
	var kitchen := _kitchen()
	assert_eq(kitchen.position, MapBuilder.cell_center(FarmScript.KITCHEN_CELL))


func test_cooking_screen_present_on_farm() -> void:
	var screen := get_tree().get_first_node_in_group("cooking_screen")
	assert_not_null(screen, "farm.tscn should instance a CookingScreen (UI loop)")


func test_interacting_with_kitchen_opens_cooking_screen() -> void:
	var screen := get_tree().get_first_node_in_group("cooking_screen") as CookingScreen
	assert_false(screen.is_open())
	_kitchen().interact(player)
	assert_true(screen.is_open())


func test_interacting_twice_does_not_double_open_or_error() -> void:
	var screen := get_tree().get_first_node_in_group("cooking_screen") as CookingScreen
	_kitchen().interact(player)
	_kitchen().interact(player)
	assert_true(screen.is_open())
	get_tree().paused = false
