extends GutTest
## World Stride A farm rules: season-gated planting, wilt at the season
## rollover, regrowing crops, rain's water_all, and the stored-blob statics
## DayFlow uses when the farm scene isn't loaded.

var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	Clock.day = 10  # mid-spring: no season boundary in sight
	Clock.weather = "clear"
	grid = FarmGrid.new()
	grid.tillable = Rect2i(0, 0, 10, 10)
	add_child_autofree(grid)


func after_each() -> void:
	Clock.day = 1
	SaveManager.world.erase("farm_grid")


# ---- season-gated planting ----

func test_pumpkin_refuses_to_plant_in_spring() -> void:
	var c := Vector2i(1, 1)
	grid.till(c)
	assert_false(grid.plant(c, "pumpkin"), "pumpkin is fall-only now")
	assert_eq(grid.plots[c].crop_id, "", "failed plant must leave the plot empty")


func test_pumpkin_plants_fine_in_fall() -> void:
	Clock.day = 57  # Fall 1
	var c := Vector2i(1, 1)
	grid.till(c)
	assert_true(grid.plant(c, "pumpkin"))
	assert_eq(grid.plots[c].crop_id, "pumpkin")


func test_summer_crops_gate_on_summer() -> void:
	var c := Vector2i(2, 2)
	grid.till(c)
	assert_false(grid.plant(c, "tomato"), "tomato refuses in spring")
	Clock.day = 29  # Summer 1
	assert_true(grid.plant(c, "tomato"))


# ---- wilt at the season rollover ----

func test_out_of_season_crop_wilts_when_season_turns() -> void:
	# Turnip planted on Spring 28, unharvested -> gone on waking Summer 1,
	# plot still tilled. advance_day is called with Clock.day already on the
	# new day, matching Clock.end_day()'s increment-then-emit order.
	Clock.day = 28
	var c := Vector2i(3, 3)
	grid.till(c)
	grid.plant(c, "turnip")
	grid.water(c)
	Clock.day = 29
	var wilted := grid.advance_day()
	assert_eq(wilted, 1, "one crop wilted")
	assert_eq(grid.last_wilt_count, 1, "tally kept for DayFlow's toast")
	assert_eq(grid.plots[c].crop_id, "", "crop cleared")
	assert_true(grid.plots[c].tilled, "plot stays tilled")
	assert_false(grid.plots[c].regrown)


func test_in_season_crop_survives_the_rollover() -> void:
	Clock.day = 28
	var c := Vector2i(4, 4)
	grid.till(c)
	# Tomato is summer-only: plant it ON the boundary by faking a summer day,
	# then cross into Summer 1 — it must survive (its season is arriving).
	Clock.day = 29
	grid.plant(c, "tomato")
	grid.water(c)
	Clock.day = 29  # already summer; simulate the Spring->Summer wake
	var wilted := grid.advance_day()
	assert_eq(wilted, 0)
	assert_eq(grid.plots[c].crop_id, "tomato")


func test_no_wilt_on_ordinary_days() -> void:
	var c := Vector2i(5, 5)
	grid.till(c)
	grid.plant(c, "turnip")
	Clock.day = 11  # Spring 10 -> Spring 11, no boundary
	assert_eq(grid.advance_day(), 0)
	assert_eq(grid.plots[c].crop_id, "turnip")


# ---- regrow ----

func test_strawberry_regrows_after_harvest() -> void:
	# stage_days [2,2,3] = 7 watered days to first ripen; regrow_days 3.
	var c := Vector2i(6, 6)
	grid.till(c)
	grid.plant(c, "strawberry")
	for day in 7:
		assert_false(grid.is_ripe(c), "not ripe before watered day %d" % (day + 1))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c))
	assert_eq(grid.peek_harvest(c), "strawberry")

	# First pick: crop STAYS, held at the final growth stage on the regrow clock.
	assert_eq(grid.harvest(c), "strawberry")
	assert_eq(grid.plots[c].crop_id, "strawberry", "regrowing crop survives its harvest")
	assert_true(grid.plots[c].regrown)
	assert_eq(grid.plots[c].stage, 2, "held at stage_days.size() - 1")
	assert_eq(grid.plots[c].days_in_stage, 0)
	assert_false(grid.is_ripe(c))

	# 3 watered days later it is ripe again and pickable again.
	for day in 3:
		assert_false(grid.is_ripe(c))
		grid.water(c)
		grid.advance_day()
	assert_true(grid.is_ripe(c), "re-ripened after regrow_days watered days")
	assert_eq(grid.harvest(c), "strawberry", "second pick delivers again")
	assert_eq(grid.plots[c].crop_id, "strawberry", "and it keeps regrowing")


func test_single_harvest_crop_still_clears() -> void:
	var c := Vector2i(7, 7)
	grid.till(c)
	grid.plant(c, "turnip")
	for day in 3:
		grid.water(c)
		grid.advance_day()
	assert_eq(grid.harvest(c), "turnip")
	assert_eq(grid.plots[c].crop_id, "", "regrow_days 0 -> cleared on harvest")
	assert_true(grid.plots[c].tilled)


func test_harvest_of_unripe_crop_is_a_noop() -> void:
	var c := Vector2i(8, 8)
	grid.till(c)
	grid.plant(c, "turnip")
	assert_eq(grid.harvest(c), "")
	assert_eq(grid.plots[c].crop_id, "turnip", "unripe crop untouched")


func test_regrown_flag_survives_serialization_with_json_floats() -> void:
	# from_dict must coerce regrown (bool) and the numeric fields (JSON
	# floats) — simulate a parsed-JSON plot dict directly.
	var grid2 := FarmGrid.new()
	grid2.tillable = Rect2i(0, 0, 10, 10)
	add_child_autofree(grid2)
	grid2.from_dict({"2,2": {"tilled": true, "watered": false,
		"crop_id": "strawberry", "stage": 2.0, "days_in_stage": 1.0,
		"regrown": true}})
	var p: Dictionary = grid2.plots[Vector2i(2, 2)]
	assert_true(p.regrown)
	assert_eq(p.stage, 2)
	assert_eq(typeof(p.stage), TYPE_INT)
	assert_eq(typeof(p.days_in_stage), TYPE_INT)


# ---- rain: water_all ----

func test_water_all_waters_every_tilled_plot() -> void:
	grid.till(Vector2i(1, 5))
	grid.till(Vector2i(2, 5))
	grid.till(Vector2i(3, 5))
	grid.water(Vector2i(1, 5))  # already wet — not double-counted
	var newly := grid.water_all()
	assert_eq(newly, 2, "two dry plots got rain")
	for x in [1, 2, 3]:
		assert_true(grid.plots[Vector2i(x, 5)].watered)


# ---- stored-blob statics (DayFlow's away-from-farm night) ----

func test_advance_stored_day_wilts_and_reports() -> void:
	# Sleeping in the dungeon across the Spring->Summer boundary must wilt
	# the saved blob exactly like a live grid would, and report the count.
	Clock.day = 29
	SaveManager.world["farm_grid"] = {
		"5,5": {"tilled": true, "watered": true, "crop_id": "turnip",
			"stage": 1, "days_in_stage": 0, "regrown": false},
	}
	var wilted := FarmGrid.advance_stored_day()
	assert_eq(wilted, 1)
	var plot: Dictionary = SaveManager.world["farm_grid"]["5,5"]
	assert_eq(plot["crop_id"], "", "stored crop wilted")
	assert_true(bool(plot["tilled"]), "stored plot stays tilled")


func test_water_all_stored_waters_the_blob() -> void:
	SaveManager.world["farm_grid"] = {
		"5,5": {"tilled": true, "watered": false, "crop_id": "",
			"stage": 0, "days_in_stage": 0, "regrown": false},
	}
	FarmGrid.water_all_stored()
	assert_true(bool(SaveManager.world["farm_grid"]["5,5"]["watered"]))
