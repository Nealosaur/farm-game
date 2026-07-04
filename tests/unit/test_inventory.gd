extends GutTest


func before_each() -> void:
	Inventory.reset()


func test_add_stacks_within_max() -> void:
	assert_eq(Inventory.add_item("turnip", 60), 0)
	assert_eq(Inventory.add_item("turnip", 60), 0)
	assert_eq(Inventory.count_of("turnip"), 120)
	var used := 0
	for s in Inventory.slots:
		if s != null:
			used += 1
	assert_eq(used, 2)  # 99 + 21


func test_add_returns_leftover_when_full() -> void:
	assert_eq(Inventory.add_item("turnip", 99 * Inventory.SIZE), 0)
	assert_eq(Inventory.add_item("turnip", 5), 5)


func test_tools_occupy_one_slot_each() -> void:
	Inventory.add_item("hoe")
	Inventory.add_item("hoe")
	var used := 0
	for s in Inventory.slots:
		if s != null:
			used += 1
	assert_eq(used, 2)


func test_remove_across_stacks() -> void:
	Inventory.add_item("turnip", 120)
	assert_true(Inventory.remove_item("turnip", 100))
	assert_eq(Inventory.count_of("turnip"), 20)


func test_remove_insufficient_fails_without_partial() -> void:
	Inventory.add_item("turnip", 10)
	assert_false(Inventory.remove_item("turnip", 20))
	assert_eq(Inventory.count_of("turnip"), 10)


func test_unknown_item_rejected() -> void:
	assert_eq(Inventory.add_item("nonsense", 3), 3)


func test_hotbar_selection_clamped() -> void:
	Inventory.select_hotbar(99)
	assert_eq(Inventory.selected, Inventory.HOTBAR - 1)
