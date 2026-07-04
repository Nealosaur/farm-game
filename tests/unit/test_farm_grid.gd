extends GutTest

var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
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
	grid.till(Vector2i(1, 1))
	grid.plant(Vector2i(1, 1), "pumpkin")
	grid.water(Vector2i(1, 1))
	grid.advance_day()
	var data := grid.to_dict()
	var grid2 := FarmGrid.new()
	grid2.tillable = grid.tillable
	add_child_autofree(grid2)
	grid2.from_dict(data)
	assert_eq(grid2.plots[Vector2i(1, 1)].crop_id, "pumpkin")
	assert_eq(grid2.plots[Vector2i(1, 1)].days_in_stage, 1)
	assert_false(grid2.plots[Vector2i(1, 1)].watered)


func test_grows_on_day_passed_signal() -> void:
	var c := Vector2i(7, 7)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.water(c)
	EventBus.day_passed.emit(2)
	assert_eq(grid.plots[c].stage, 1)
