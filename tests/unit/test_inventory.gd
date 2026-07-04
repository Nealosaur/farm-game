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


func test_slots_are_copied_not_aliased() -> void:
	var empty_snapshot := Inventory.to_dict()
	Inventory.add_item("turnip", 5)
	var leaked := 0
	for s in empty_snapshot.slots:
		if s != null:
			leaked += 1
	assert_eq(leaked, 0)  # array copy: new slot must not appear in old snapshot
	var snapshot := Inventory.to_dict()
	Inventory.add_item("turnip", 5)
	assert_eq(snapshot.slots[0].count, 5)  # deep copy: in-place count mutation must not leak
	# Reverse direction: mutating the source after from_dict must not change Inventory.
	var src := {"selected": 1, "slots": [{"id": "turnip", "count": 7}]}
	Inventory.from_dict(src)
	src.slots[0].count = 999
	assert_eq(Inventory.count_of("turnip"), 7)


func test_from_dict_skips_malformed_entries() -> void:
	Inventory.from_dict({"selected": 0, "slots": [{"id": "turnip"}, {"id": "turnip", "count": 3}, "garbage", null]})
	assert_null(Inventory.slots[0])  # entry without "count" is skipped, not crashed on
	assert_eq(Inventory.count_of("turnip"), 3)


func test_get_selected_item_data() -> void:
	assert_null(Inventory.get_selected_item_data())  # empty slot -> null
	Inventory.add_item("hoe")
	var data := Inventory.get_selected_item_data()
	assert_not_null(data)
	assert_true(data is ToolData)
	assert_eq(data.id, "hoe")
