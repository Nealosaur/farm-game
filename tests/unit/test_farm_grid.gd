extends GutTest

var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	# World Stride A: pin a mid-spring day so planting/advance_day tests below
	# never land on a season-rollover day by accident (leaked Clock.day from
	# another test file could otherwise wilt a freshly-planted spring crop
	# mid-test — turnip/carrot are spring-only).
	Clock.day = 10
	grid = FarmGrid.new()
	grid.tillable = Rect2i(0, 0, 10, 10)
	add_child_autofree(grid)


func test_till_only_inside_tillable_area() -> void:
	assert_true(grid.till(Vector2i(2, 2)))
	assert_false(grid.till(Vector2i(2, 2)))     # already tilled
	assert_false(grid.till(Vector2i(50, 50)))   # outside


func test_water_requires_tilled() -> void:
	assert_false(grid.water(Vector2i(3, 3)))
	grid.till(Vector2i(3, 3))
	assert_true(grid.water(Vector2i(3, 3)))
	assert_false(grid.water(Vector2i(3, 3)))    # already watered


func test_plant_requires_tilled_and_empty() -> void:
	assert_false(grid.plant(Vector2i(4, 4), "turnip"))
	grid.till(Vector2i(4, 4))
	assert_true(grid.plant(Vector2i(4, 4), "turnip"))
	assert_false(grid.plant(Vector2i(4, 4), "turnip"))  # occupied
	assert_false(grid.plant(Vector2i(5, 5), "nonsense_crop"))


func test_turnip_grows_in_three_watered_days() -> void:
	var c := Vector2i(1, 1)
	grid.till(c)
	grid.plant(c, "turnip")   # stage_days [1,1,1] -> ripe at stage 3
	for day in 3:
		assert_false(grid.is_ripe(c))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))


func test_unwatered_crop_does_not_grow() -> void:
	var c := Vector2i(1, 2)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.advance_day()
	assert_eq(grid.plots[c].stage, 0)


func test_multi_day_stages_carrot() -> void:
	var c := Vector2i(2, 1)
	grid.till(c)
	grid.plant(c, "carrot")   # stage_days [1,2,2] -> 5 watered days
	for day in 5:
		assert_false(grid.is_ripe(c))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))


func test_watered_flag_resets_each_day() -> void:
	var c := Vector2i(3, 1)
	grid.till(c)
	grid.water(c)
	grid.advance_day()
	assert_false(grid.plots[c].watered)


func test_harvest_cycle() -> void:
	var c := Vector2i(6, 6)
	grid.till(c)
	grid.plant(c, "turnip")
	assert_eq(grid.peek_harvest(c), "")
	for day in 3:
		grid.water(c)
		grid.advance_day()
	assert_eq(grid.peek_harvest(c), "turnip")
	grid.clear_crop(c)
	assert_eq(grid.peek_harvest(c), "")
	assert_true(grid.plots[c].tilled)           # soil stays tilled
	assert_true(grid.plant(c, "turnip"))        # replantable


func test_serialization_round_trip() -> void:
	# Uses strawberry, not pumpkin (World Stride A moved pumpkin to fall-only)
	# — this test's intent is proving crop_id/days_in_stage/watered round-trip
	# correctly, which strawberry demonstrates equally well without needing to
	# drive Clock.day into fall (and risk an unrelated season-wilt tick).
	# Strawberry's stage_days [2,2,3] (like pumpkin's old [2,3,3]) has a
	# stage-0 threshold > 1, so one watered day leaves it mid-stage-0
	# (days_in_stage 1) rather than immediately advancing to stage 1 — carrot
	# and turnip both have a 1-day stage 0, which would advance same-day.
	grid.till(Vector2i(1, 1))
	grid.plant(Vector2i(1, 1), "strawberry")
	grid.water(Vector2i(1, 1))
	grid.advance_day()
	var data := grid.to_dict()
	var grid2 := FarmGrid.new()
	grid2.tillable = grid.tillable
	add_child_autofree(grid2)
	grid2.from_dict(data)
	assert_eq(grid2.plots[Vector2i(1, 1)].crop_id, "strawberry")
	assert_eq(grid2.plots[Vector2i(1, 1)].days_in_stage, 1)
	assert_false(grid2.plots[Vector2i(1, 1)].watered)


func test_grows_on_day_passed_signal() -> void:
	var c := Vector2i(7, 7)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.water(c)
	EventBus.day_passed.emit(2)
	assert_eq(grid.plots[c].stage, 1)


func test_ripe_crop_stops_counting_days() -> void:
	var c := Vector2i(8, 8)
	grid.till(c)
	grid.plant(c, "turnip")
	for day in 3:
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))
	grid.water(c)
	grid.advance_day()
	assert_eq(grid.plots[c].stage, 3)
	assert_eq(grid.plots[c].days_in_stage, 0)


func test_advance_stored_day_grows_saved_blob_without_live_grid() -> void:
	# DayFlow's away-from-farm night: no FarmGrid alive, growth applied
	# straight to the world blob. Turnip stage_days [1,1,1] -> one watered
	# night moves stage 0 -> 1 and clears the watered flag.
	SaveManager.world["farm_grid"] = {
		"5,5": {"tilled": true, "watered": true, "crop_id": "turnip",
			"stage": 0, "days_in_stage": 0},
		"6,5": {"tilled": true, "watered": false, "crop_id": "turnip",
			"stage": 0, "days_in_stage": 0},
	}
	FarmGrid.advance_stored_day()
	var watered_plot: Dictionary = SaveManager.world["farm_grid"]["5,5"]
	assert_eq(watered_plot["stage"], 1, "watered crop grew overnight")
	assert_false(watered_plot["watered"], "watered flag resets for the new day")
	var dry_plot: Dictionary = SaveManager.world["farm_grid"]["6,5"]
	assert_eq(dry_plot["stage"], 0, "unwatered crop did not grow")
	SaveManager.world.erase("farm_grid")


func test_exit_tree_stores_blob_per_world_contract() -> void:
	# Leaving the farm scene (portal to the dungeon) must persist the
	# morning's field work — the world-data contract's store-on-exit rule.
	var g := FarmGrid.new()
	g.tillable = Rect2i(0, 0, 10, 10)
	add_child(g)
	g.till(Vector2i(2, 2))
	g.free()   # triggers _exit_tree -> store()
	var blob: Dictionary = SaveManager.world.get("farm_grid", {})
	assert_true(blob.has("2,2"), "grid stored its plots on scene exit")
	SaveManager.world.erase("farm_grid")

# World Stride A: season-gated planting, wilt, regrow, and water_all coverage
# lives in tests/unit/test_seasons_farm.gd (a dedicated file, matching this
# project's convention of splitting out a stride's new behavior rather than
# growing this file further — see test_day_tint.gd vs test_auto_instance_scenes.gd
# for the same pattern).
