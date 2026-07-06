extends GutTest
## Craft Stride 3 (Taming — morning help): FarmGrid.water_random_unwatered()/
## _stored() pure-grid coverage (mirrors test_seasons_farm.gd's own
## water_all()/water_all_stored() test shape). DayFlow's on-farm/off-farm
## wiring (seeded-by-day, before-rain ordering, toast wording) lives in
## test_day_flow_barn_watering.gd instead — kept in a SEPARATE file so that
## file's farm-scene tests never race this file's before_each()'s own bare
## FarmGrid node, which stays alive (in the "farm_grid" group) until this
## test ends and would otherwise shadow the farm scene's real grid in any
## get_first_node_in_group("farm_grid") lookup.

var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	Clock.day = 10
	Clock.weather = "clear"
	grid = FarmGrid.new()
	grid.tillable = Rect2i(0, 0, 10, 10)
	add_child_autofree(grid)


func after_each() -> void:
	Clock.day = 1
	Clock.weather = "clear"
	SaveManager.world.erase("farm_grid")
	SaveManager.world.erase("taming")


# ---- pure FarmGrid.water_random_unwatered ----

func test_waters_exactly_count_cells_when_enough_unwatered_exist() -> void:
	for x in 10:
		grid.till(Vector2i(x, 0))
	var watered := grid.water_random_unwatered(8, 42)
	assert_eq(watered, 8)
	var wet := 0
	for x in 10:
		if grid.plots[Vector2i(x, 0)].watered:
			wet += 1
	assert_eq(wet, 8)


func test_never_waters_more_than_available_unwatered_cells() -> void:
	for x in 3:
		grid.till(Vector2i(x, 0))
	var watered := grid.water_random_unwatered(8, 42)
	assert_eq(watered, 3, "only 3 tilled cells exist — can't water 8")


func test_never_rewaters_an_already_watered_cell() -> void:
	grid.till(Vector2i(0, 0))
	grid.water(Vector2i(0, 0))
	grid.till(Vector2i(1, 0))
	var watered := grid.water_random_unwatered(8, 42)
	assert_eq(watered, 1, "only the one still-dry cell can be newly watered")
	assert_true(grid.plots[Vector2i(1, 0)].watered)


func test_zero_unwatered_cells_waters_nothing() -> void:
	assert_eq(grid.water_random_unwatered(8, 42), 0)


func test_same_seed_picks_the_same_cells_deterministically() -> void:
	var grid1 := FarmGrid.new()
	grid1.tillable = Rect2i(0, 0, 20, 10)
	add_child_autofree(grid1)
	var grid2 := FarmGrid.new()
	grid2.tillable = Rect2i(0, 0, 20, 10)
	add_child_autofree(grid2)
	for x in 20:
		grid1.till(Vector2i(x, 0))
		grid2.till(Vector2i(x, 0))

	grid1.water_random_unwatered(8, 123)
	grid2.water_random_unwatered(8, 123)
	for x in 20:
		var c := Vector2i(x, 0)
		assert_eq(grid1.plots[c].watered, grid2.plots[c].watered,
			"same seed must water the identical set of cells")


func test_different_seeds_can_pick_different_cells() -> void:
	## Not a hard guarantee for every possible seed pair, but true for this
	## fixed pair — documents that the seed actually drives the pick (a
	## constant/no-op RNG would fail this).
	var grid1 := FarmGrid.new()
	grid1.tillable = Rect2i(0, 0, 20, 10)
	add_child_autofree(grid1)
	var grid2 := FarmGrid.new()
	grid2.tillable = Rect2i(0, 0, 20, 10)
	add_child_autofree(grid2)
	for x in 20:
		grid1.till(Vector2i(x, 0))
		grid2.till(Vector2i(x, 0))

	grid1.water_random_unwatered(8, 1)
	grid2.water_random_unwatered(8, 999)
	var same := true
	for x in 20:
		var c := Vector2i(x, 0)
		if grid1.plots[c].watered != grid2.plots[c].watered:
			same = false
	assert_false(same, "different seeds should (for this pair) pick a different set")


# ---- stored-blob companion ----

func test_water_random_unwatered_stored_waters_the_blob() -> void:
	SaveManager.world["farm_grid"] = {
		"1,1": {"tilled": true, "watered": false, "crop_id": "", "stage": 0, "days_in_stage": 0, "regrown": false},
		"2,2": {"tilled": true, "watered": false, "crop_id": "", "stage": 0, "days_in_stage": 0, "regrown": false},
	}
	var watered := FarmGrid.water_random_unwatered_stored(8, 5)
	assert_eq(watered, 2)
	assert_true(bool(SaveManager.world["farm_grid"]["1,1"]["watered"]))
	assert_true(bool(SaveManager.world["farm_grid"]["2,2"]["watered"]))
