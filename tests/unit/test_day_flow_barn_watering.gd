extends GutTest
## Craft Stride 3 (Taming — morning help): DayFlow's on-farm wiring for barn
## slime watering — seeded-by-day determinism (covered at the pure FarmGrid
## level in test_morning_watering.gd), one barn slime = 8 cells, two slimes =
## 16, no barn = no extra watering, runs before the rain check, toast
## wording. Mirrors test_farm_integration.gd's own farm-scene-instantiation
## shape.
##
## Deliberately its OWN file (not sharing test_morning_watering.gd's
## before_each): that file's before_each() creates a bare FarmGrid node that
## stays alive (and in the "farm_grid" group) for the duration of each of
## its tests — if these DayFlow tests ran in the same file/group timeline,
## get_first_node_in_group("farm_grid") inside DayFlow.end_day() could grab
## that stray node instead of the real farm scene's grid.
##
## NOT covered here (documented tradeoff, same as test_dungeon_integration.gd
## and test_morning_watering.gd's own note): the off-farm/stored-blob branch,
## since it hands off to SceneChanger.swap_scene_while_black() ->
## change_scene_to_file(), which would tear down this running test scene.

func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_day_flow_barn_watering.json"
	SaveManager.new_game()
	# Winter has a 0% rain chance (Clock.RAIN_CHANCE[3]) — every test in this
	# file that calls flow.end_day() triggers Clock.end_day()'s own weather
	# reroll (real, unseeded RNG; can't be forced deterministically through
	# the public API), so pinning the day to Winter is what keeps the
	# "ordinary clear night" tests from flaking on whatever season Day 1
	# would otherwise roll against.
	Clock.day = 85  # Winter 1


func after_each() -> void:
	Clock.paused = false
	Clock.weather = "clear"
	Clock.day = 1
	SaveManager.world.erase("taming")
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_day_flow_barn_watering.json"):
		DirAccess.remove_absolute("user://test_day_flow_barn_watering.json")


func _make_farm() -> Node2D:
	return (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()


func test_one_barn_slime_waters_8_cells_before_sleep() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"  # isolate from the rain auto-water branch
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	for x in range(24, 34):
		farm.grid.till(Vector2i(x, 10))

	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var wet := 0
	for x in range(24, 34):
		if farm.grid.plots[Vector2i(x, 10)].watered:
			wet += 1
	assert_eq(wet, 8, "one barn slime waters exactly 8 cells")


func test_two_barn_slimes_water_16_cells() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime", "slime"]}
	for x in range(24, 38):
		for y in range(10, 12):
			farm.grid.till(Vector2i(x, y))

	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var wet := 0
	for x in range(24, 38):
		for y in range(10, 12):
			if farm.grid.plots[Vector2i(x, y)].watered:
				wet += 1
	assert_eq(wet, 16, "two barn slimes water 8 cells each")


func test_no_barn_slimes_waters_nothing_extra() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world.erase("taming")
	for x in range(24, 30):
		farm.grid.till(Vector2i(x, 10))

	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	for x in range(24, 30):
		assert_false(farm.grid.plots[Vector2i(x, 10)].watered, "no barn slimes -> no morning watering")


func test_only_unwatered_tilled_cells_are_touched() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	farm.grid.till(Vector2i(24, 10))
	farm.grid.water(Vector2i(24, 10))  # already watered before the slimes act
	farm.grid.till(Vector2i(25, 10))

	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	# Both end up watered (the already-wet one stays wet, the dry one gets
	# picked up by the slime) — the real assertion is that water_random_
	# unwatered's "unwatered-only" pool selection ran without erroring, which
	# the pure-grid tests already pin at the unit level; this just confirms
	# the on-farm wiring doesn't skip a cell that was dry going in.
	assert_true(farm.grid.plots[Vector2i(25, 10)].watered)


func test_slime_watering_runs_before_the_rain_check_in_source_order() -> void:
	## Bible: "runs before the rain check". Clock.end_day() re-rolls today's
	## weather with the real (unseeded) RNG, so forcing Clock.weather="rain"
	## right before calling flow.end_day() gets silently overwritten by that
	## roll — there is no way to force a real rain day deterministically
	## through the public Clock API. Ordering is instead pinned as a static
	## source-order guard (same technique as the off-farm-branch guard
	## below): _barn_slime_water(grid) must appear BEFORE the
	## "if Clock.is_raining():" check inside end_day()'s on-farm branch.
	var src := FileAccess.get_file_as_string("res://scripts/components/day_flow.gd")
	var slime_call_pos := src.find("slime_watered = _barn_slime_water(grid)")
	var rain_check_pos := src.find("if Clock.is_raining():\n\t\t\tgrid.water_all()")
	assert_gt(slime_call_pos, -1, "expected on-farm slime-watering call not found")
	assert_gt(rain_check_pos, -1, "expected on-farm rain-check branch not found")
	assert_lt(slime_call_pos, rain_check_pos,
		"barn slime watering must run before the rain check on the on-farm path")


func test_slime_toast_appears_on_an_ordinary_clear_night_regardless_of_rain_wording() -> void:
	## Functional companion to the source-order guard above: on a plain
	## (non-rain) night the slime toast must appear on its own, independent
	## of whatever the rain toast does — already covered by
	## test_toast_wording_matches_the_bible below, this just also confirms
	## the rain toast is ABSENT that night so the two toasts aren't
	## accidentally coupled.
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	farm.grid.till(Vector2i(24, 10))

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var saw_slime_toast := false
	var saw_rain_toast := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		if msg == "Your slime helped water the field.":
			saw_slime_toast = true
		if msg.begins_with("Rain overnight"):
			saw_rain_toast = true
	assert_true(saw_slime_toast, "slime toast must appear on a clear night with a barn slime")
	assert_false(saw_rain_toast, "rain toast must not appear on a night that didn't roll rain")


func test_toast_wording_matches_the_bible() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	farm.grid.till(Vector2i(24, 10))

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var saw_it := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		if get_signal_parameters(EventBus, "toast_requested", call_index)[0] == "Your slime helped water the field.":
			saw_it = true
	assert_true(saw_it)


func test_no_toast_when_no_barn_slimes() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"
	SaveManager.world.erase("taming")

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		assert_ne(get_signal_parameters(EventBus, "toast_requested", call_index)[0],
			"Your slime helped water the field.", "no barn slimes must never show the helper toast")


# ---- off-farm/stored path: documented as a static-guard, same rationale as
# test_morning_watering.gd's own note ----

func test_day_flow_source_calls_the_stored_watering_helper_in_the_off_farm_branch() -> void:
	## Cheap static guard against silent drift: if a future edit removes the
	## _barn_slime_water_stored() call from the off-farm branch, this fails
	## loudly instead of the gap only surfacing in manual play-testing (the
	## real end-to-end path can't run headless — see class doc above).
	## Anchored on FarmGrid.advance_stored_day() (the line right before it in
	## that branch, per day_flow.gd's own source) rather than a bare "else:"
	## split, since the class doc's prose also contains the substring "else:"
	## (a false split point that would grab the WRONG branch's body).
	var src := FileAccess.get_file_as_string("res://scripts/components/day_flow.gd")
	var anchor := src.find("wilted = FarmGrid.advance_stored_day()")
	assert_gt(anchor, -1, "expected anchor line not found — day_flow.gd's off-farm branch shape changed")
	var off_farm_branch := src.substr(anchor, 400)
	assert_true(off_farm_branch.contains("_barn_slime_water_stored()"),
		"the away-from-farm branch must call the stored-blob morning-watering helper")
