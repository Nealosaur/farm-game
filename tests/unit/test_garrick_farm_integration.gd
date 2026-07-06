extends GutTest
## World Stride C: Garrick-on-farm headless integration — mirrors
## test_town_npc_integration.gd's shape but for the farm scene's morning-only
## NPC appearance. Confirms the real farm.tscn instances Garrick, places him
## at the Delve-entrance cell during his 6-9/9-12 blocks, and hides him
## outside those blocks (his afternoon/evening/night schedule lives on town,
## which this scene never builds).
##
## NOT covered headless (same documented tradeoff as test_dungeon_integration/
## test_town_npc_integration): actual portal travel.

const FARM_SCENE := "res://scenes/maps/farm.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.world.erase("relationships")
	SaveManager.save_path = "user://test_garrick_farm.json"
	SaveManager.new_game()
	Clock.weather = "clear"  # Garrick's rain override moves him to town; force clear for the normal-schedule assertions
	Clock.day = 1
	Clock.minutes = 7 * 60  # 7 AM: farm-side Delve entrance block (6-9)
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	SaveManager.world.erase("relationships")
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_garrick_farm.json"):
		DirAccess.remove_absolute("user://test_garrick_farm.json")


func _make_farm() -> Node2D:
	return (load(FARM_SCENE) as PackedScene).instantiate()


func test_farm_boots_with_garrick_placed_at_delve_entrance_during_morning_block() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_not_null(farm.garrick)
	assert_true(farm.garrick.visible)
	assert_eq(farm.garrick.position, MapBuilder.cell_center(GarrickData.CELL_FARM_DELVE_ENTRANCE))


func test_garrick_hides_on_farm_once_the_afternoon_block_starts() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.minutes = 14 * 60  # 12-17 block: Garrick moves to town's saloon
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(farm.garrick.visible, "Garrick must be hidden on the farm once his schedule moves him to town")


func test_garrick_reappears_on_farm_the_next_morning_block() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.minutes = 14 * 60
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(farm.garrick.visible)
	Clock.minutes = 10 * 60  # back to a 9-12 block (still a farm-side block for Garrick)
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_true(farm.garrick.visible)
	assert_eq(farm.garrick.position, MapBuilder.cell_center(GarrickData.CELL_FARM_DELVE_ENTRANCE))


func test_garrick_rain_override_hides_him_on_farm_even_during_morning_block() -> void:
	## Rain is rolled once per day (Clock.roll_weather()), never mid-block —
	## so the realistic way this state occurs is "it was already raining when
	## the 9-12 block starts", i.e. a block CHANGE with rain already set, same
	## as test_town_npc_integration.gd's rain test drives Marta's equivalent
	## check. (Maps re-query on block-change only, per the bible's documented
	## "block-teleport" contract — rain flipping mid-block with no block
	## change is not a supported trigger for ANY NPC, Garrick included.)
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "rain"
	Clock.minutes = 10 * 60  # still a farm-side block (9-12) normally, but rain overrides it to town
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(farm.garrick.visible, "rain moves Garrick's morning block to town's saloon, not the farm")


func test_talking_to_garrick_on_the_farm_grants_bond_once_per_day() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	assert_not_null(dialog, "farm must auto-instance a DialogBox")

	farm.garrick.interact(farm.player)
	assert_eq(Relationships.points("garrick"), 15)

	dialog._advance()
	if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
		var last := dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button
		last.pressed.emit()
	await wait_process_frames(2)

	farm.garrick.interact(farm.player)
	assert_eq(Relationships.points("garrick"), 15, "same-day second talk must not add points again")
	# This interact() opened a second dialog (a talk still shows a line even
	# when talk() itself no-ops) that would otherwise leak get_tree().paused
	# = true past this test — every later test in the suite that relies on
	# real frame/timer processing (wait_seconds, etc.) would then hang
	# forever waiting on a permanently-paused tree. Close it synchronously
	# (no await — the tree may still be paused right now, so anything that
	# depends on frame processing would itself hang) before the test ends.
	if dialog.is_open():
		dialog._advance()
		if dialog.is_open() and dialog.choice_box.get_child_count() > 0:
			(dialog.choice_box.get_child(dialog.choice_box.get_child_count() - 1) as Button).pressed.emit()
	assert_false(get_tree().paused, "no test may leave the SceneTree paused for the next test")
