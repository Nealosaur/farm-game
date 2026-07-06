extends GutTest
## World Stride D: Day-1 opening headless integration — mirrors
## test_garrick_farm_integration.gd's shape. Confirms the real farm.tscn
## spawns Alden's intro trigger on a fresh Day 1, that interacting starts the
## EventRunner-driven script (Alive Stride 2 migration — see
## data/events/intro_alden.gd), that the verbatim intro lines still play and
## grant New Roots, that he disappears afterward, and that an old save
## (pre-Stride-D, no intro_done flag) past day 1 treats the intro as already
## done.
##
## Alive Stride 2 note: interacting with the trigger no longer opens the
## dialog on the SAME frame — Alden now walks in first (see
## data/events/intro_alden.gd's script: teleport to the west edge, walk to
## the meet cell, THEN speak). Tests that need the dialog open drive the
## EventRunner's frame-based walk forward first via simulate() (same
## convention test_npc_walk.gd already established for NPC's own walk
## controller), then assert on the dialog.
##
## NOT covered headless (same documented tradeoff as
## test_garrick_farm_integration/test_town_npc_integration): actual portal
## travel between scenes.

const FARM_SCENE := "res://scenes/maps/farm.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	SaveManager.save_path = "user://test_day_one.json"
	SaveManager.new_game()
	Clock.weather = "clear"
	Clock.day = 1
	Clock.minutes = 7 * 60  # 7 AM: still "morning" per alden_intro's block gate
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	GameState.flags = {}
	GameFlow.cutscene_active = false
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	Quests._quests = {}
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_day_one.json"):
		DirAccess.remove_absolute("user://test_day_one.json")


func _make_farm() -> Node2D:
	return (load(FARM_SCENE) as PackedScene).instantiate()


func _runner_for(farm: Node2D) -> EventRunner:
	## Alive Stride 2: interact() hands off to a freshly-added EventRunner
	## child of the current scene root — found the same way DialogBox/etc.
	## are found elsewhere in this suite, via get_tree() lookups, except
	## EventRunner has no group of its own, so this walks farm's children.
	for child in farm.get_children():
		if child is EventRunner:
			return child
	return null


func _advance_walk_in(farm: Node2D) -> EventRunner:
	## Drives the EventRunner's frame-based walk-in (teleport to the west
	## edge is instant; the walk to the meet cell is not) far enough that
	## Alden has arrived and his first `speak` line is showing.
	var runner := _runner_for(farm)
	assert_not_null(runner, "interact() must add an EventRunner to the scene")
	simulate(runner, 200, 0.1)  # 20 simulated seconds — comfortably past an 8-cell walk at 40px/s
	return runner


func test_farm_boots_with_alden_intro_present_on_day_one() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_not_null(farm.alden_intro)
	assert_true(farm.alden_intro.visible)
	assert_eq(farm.alden_intro.position, MapBuilder.cell_center(farm.ALDEN_INTRO_CELL))


func test_alden_intro_not_spawned_when_flag_already_done() -> void:
	GameState.flags["intro_done"] = true
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_null(farm.alden_intro)


func test_alden_intro_not_spawned_on_day_two() -> void:
	Clock.day = 2
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_null(farm.alden_intro)


func test_interacting_with_alden_intro_plays_verbatim_lines() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	_advance_walk_in(farm)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, AldenDialog.DATA["intro"]["lines"][0])


func test_completing_alden_intro_grants_new_roots_and_sets_flag() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	_advance_walk_in(farm)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	# The script still has a walk-off + `end` after the last speak line;
	# advance frames until the runner actually finishes.
	var runner := _runner_for(farm)
	simulate(runner, 200, 0.1)
	assert_true(GameState.flags.get("intro_done", false))
	assert_true(Quests.is_active(Quests.ID_NEW_ROOTS))


func test_alden_intro_hides_itself_once_played() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	_advance_walk_in(farm)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	var runner := _runner_for(farm)
	simulate(runner, 200, 0.1)
	assert_false(farm.alden_intro.visible)


func test_alden_intro_quest_toast_fires_on_completion() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	watch_signals(EventBus)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	_advance_walk_in(farm)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	var runner := _runner_for(farm)
	simulate(runner, 200, 0.1)
	assert_signal_emitted_with_parameters(EventBus, "quest_updated", [Quests.ID_NEW_ROOTS])


func test_alden_intro_despawns_at_afternoon_block_change() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_true(farm.alden_intro.visible)
	Clock.minutes = 14 * 60  # 12-17 block: normal schedule takes over
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(farm.alden_intro.visible, "Alden's intro appearance must not persist past the morning blocks")


func test_alden_intro_gates_player_input_via_game_flow_while_playing() -> void:
	## Alive Stride 2: the runner must set GameFlow.cutscene_active for the
	## duration of the scripted scene (the same gate DayFlow's end_day() now
	## uses) and clear it once the scene ends.
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active)
	farm.alden_intro.interact(farm.player)
	assert_true(GameFlow.cutscene_active, "cutscene gate must be set as soon as the scene starts")
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	_advance_walk_in(farm)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	var runner := _runner_for(farm)
	simulate(runner, 200, 0.1)
	assert_false(GameFlow.cutscene_active, "cutscene gate must clear once the scene ends")


# ---- old-save migration ----

func test_old_save_missing_intro_flag_and_past_day_one_treats_intro_as_done() -> void:
	# Simulate a pre-Stride-D save: write a save file with no "state.flags"
	# intro_done key at all, on a day > 1.
	Clock.day = 5
	SaveManager.save_game()
	GameState.flags = {}  # wipe in-memory so load_game() must repopulate it
	assert_true(SaveManager.load_game())
	assert_true(GameState.flags.get("intro_done", false),
		"a returning save past day 1 must not replay the day-1 intro")


func test_old_save_still_on_day_one_missing_flag_leaves_intro_available() -> void:
	Clock.day = 1
	SaveManager.save_game()
	GameState.flags = {}
	assert_true(SaveManager.load_game())
	assert_false(GameState.flags.get("intro_done", false),
		"a same-session day-1 save must still let the intro play")
