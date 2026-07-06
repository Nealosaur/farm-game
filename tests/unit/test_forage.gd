extends GutTest
## World Stride C: Forage (scripts/util/forage.gd) pure-logic coverage —
## determinism, taken-persistence, day-reroll, and the winter item-pool
## swap — plus ForagePickup's inventory-full behavior (component-level,
## no scene tree needed beyond a single node).

const RIVERWOODS_CANDIDATES := [
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
	Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3),
]


func after_each() -> void:
	SaveManager.world.erase("forage")


## ---- determinism ----

func test_spawn_cells_deterministic_for_same_seed() -> void:
	var seed_value := Forage.map_seed("riverwoods", 5)
	var a := Forage.spawn_cells(RIVERWOODS_CANDIDATES, seed_value)
	var b := Forage.spawn_cells(RIVERWOODS_CANDIDATES, seed_value)
	assert_eq(a, b, "same seed must yield the same cells in the same order")


func test_spawn_cells_count_within_2_to_4() -> void:
	for day in range(1, 20):
		var seed_value := Forage.map_seed("riverwoods", day)
		var cells := Forage.spawn_cells(RIVERWOODS_CANDIDATES, seed_value)
		assert_true(cells.size() >= Forage.MIN_SPAWNS and cells.size() <= Forage.MAX_SPAWNS,
			"day %d: spawn count %d must be within [%d, %d]" % [day, cells.size(), Forage.MIN_SPAWNS, Forage.MAX_SPAWNS])


func test_different_maps_same_day_do_not_roll_identical_seeds() -> void:
	var riverwoods_seed := Forage.map_seed("riverwoods", 3)
	var beach_seed := Forage.map_seed("beach", 3)
	assert_ne(riverwoods_seed, beach_seed, "different maps must get different seeds on the same day")


func test_different_days_roll_different_seeds() -> void:
	var day1 := Forage.map_seed("riverwoods", 1)
	var day2 := Forage.map_seed("riverwoods", 2)
	assert_ne(day1, day2)


## ---- taken persistence ----

func test_record_taken_marks_cell_and_is_idempotent() -> void:
	var blob := Forage.ensure_day({}, 1)
	assert_false(Forage.is_taken(blob, Vector2i(3, 3)))
	blob = Forage.record_taken(blob, Vector2i(3, 3))
	assert_true(Forage.is_taken(blob, Vector2i(3, 3)))
	# Recording the same cell twice doesn't duplicate the ledger entry.
	blob = Forage.record_taken(blob, Vector2i(3, 3))
	var taken: Array = blob["taken"]
	assert_eq(taken.count(Forage.cell_key(Vector2i(3, 3))), 1)


func test_record_taken_does_not_mutate_input_blob() -> void:
	var original := Forage.ensure_day({}, 1)
	var updated := Forage.record_taken(original, Vector2i(1, 1))
	assert_false(Forage.is_taken(original, Vector2i(1, 1)), "input blob must be left untouched (pure function)")
	assert_true(Forage.is_taken(updated, Vector2i(1, 1)))


func test_is_taken_survives_json_style_string_keys() -> void:
	## Blob round-trips through JSON (SaveManager) — taken cells are stored as
	## "x,y" strings (see cell_key()), which already avoids the int/float
	## comparison gotcha DungeonState has to guard against explicitly.
	var blob := {"day": 1, "taken": ["3,3"]}
	assert_true(Forage.is_taken(blob, Vector2i(3, 3)))
	assert_false(Forage.is_taken(blob, Vector2i(3, 4)))


## ---- day reroll ----

func test_ensure_day_resets_taken_on_new_day() -> void:
	var blob := Forage.ensure_day({}, 1)
	blob = Forage.record_taken(blob, Vector2i(2, 2))
	assert_true(Forage.is_taken(blob, Vector2i(2, 2)))
	var next_day_blob := Forage.ensure_day(blob, 2)
	assert_false(Forage.is_taken(next_day_blob, Vector2i(2, 2)), "a new day must reroll (clear) the taken ledger")
	assert_eq(int(next_day_blob["day"]), 2)


func test_ensure_day_keeps_taken_on_same_day_reentry() -> void:
	var blob := Forage.ensure_day({}, 5)
	blob = Forage.record_taken(blob, Vector2i(2, 2))
	var same_day_blob := Forage.ensure_day(blob, 5)
	assert_true(Forage.is_taken(same_day_blob, Vector2i(2, 2)), "re-entering the same day must keep today's ledger")


func test_ensure_day_does_not_mutate_input() -> void:
	var original := {"day": 1, "taken": ["1,1"]}
	var out := Forage.ensure_day(original, 2)
	assert_eq(int(original["day"]), 1, "input dict must not be mutated")
	assert_eq(int(out["day"]), 2)


## ---- winter item-pool swap ----

func test_item_pool_for_season_uses_normal_pool_outside_winter() -> void:
	var normal := ["wildroot", "emberberry"]
	var winter := ["frostcap"]
	for season in [0, 1, 2]:  # Spring, Summer, Fall
		assert_eq(Forage.item_pool_for_season(season, normal, winter), normal)


func test_item_pool_for_season_swaps_to_winter_pool_in_winter() -> void:
	var normal := ["tideshell", "driftglass"]
	var winter := ["frostcap"]
	assert_eq(Forage.item_pool_for_season(3, normal, winter), winter)


## ---- ForagePickup: inventory-full behavior ----

var _toasted_message := ""  # member field, not a lambda-captured local — GDScript
                             # lambdas capture outer locals BY VALUE, so a bool/String
                             # local reassigned inside the lambda body would silently
                             # leave the outer scope's copy untouched.


func _on_toast_for_test(message: String) -> void:
	_toasted_message = message


func test_pickup_leaves_node_in_place_and_toasts_when_inventory_full() -> void:
	Inventory.reset()
	# Fill every slot with a maxed, non-matching stack so add_item("wildroot", 1)
	# has nowhere to go — max_stack for wildroot's FoodData is 99 (default),
	# so 30 full slots of a DIFFERENT item guarantees no merge and no free slot.
	var filler := ItemDB.get_item("turnip")
	assert_not_null(filler, "turnip must exist in ItemDB for this fixture")
	for i in Inventory.SIZE:
		Inventory.slots[i] = {"id": "turnip", "count": filler.max_stack}

	SaveManager.world.erase("forage")
	Clock.day = 1
	var pickup := ForagePickup.make("riverwoods", "wildroot", Vector2i(5, 5))
	add_child_autofree(pickup)

	_toasted_message = ""
	EventBus.toast_requested.connect(_on_toast_for_test)
	pickup.interact(null)
	EventBus.toast_requested.disconnect(_on_toast_for_test)

	assert_eq(_toasted_message, "Inventory full", "must toast 'Inventory full' when there's nowhere to put the item")
	assert_false(pickup.is_queued_for_deletion(), "pickup must stay in place when inventory is full")
	Inventory.reset()


func test_pickup_adds_item_and_records_taken_and_frees_when_room_exists() -> void:
	Inventory.reset()
	SaveManager.world.erase("forage")
	Clock.day = 7
	var pickup := ForagePickup.make("riverwoods", "wildroot", Vector2i(6, 6))
	add_child_autofree(pickup)
	pickup.interact(null)

	var found := false
	for slot in Inventory.slots:
		if slot != null and slot.id == "wildroot":
			found = true
	assert_true(found, "wildroot must land in inventory when there's room")

	var blob: Dictionary = SaveManager.world.get("forage", {})
	var map_blob: Dictionary = blob.get("riverwoods", {})
	assert_true(Forage.is_taken(map_blob, Vector2i(6, 6)), "the cell must be recorded taken")
	assert_true(pickup.is_queued_for_deletion(), "pickup must free itself after a successful pickup")
	Inventory.reset()
