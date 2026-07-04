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
