extends GutTest
## World Stride D: Day-1 opening headless integration — mirrors
## test_garrick_farm_integration.gd's shape. Confirms the real farm.tscn
## spawns Alden's intro interactable on a fresh Day 1, that interacting plays
## the verbatim intro and grants New Roots, that he disappears afterward,
## and that an old save (pre-Stride-D, no intro_done flag) past day 1 treats
## the intro as already done.
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
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("quests")
	Quests._quests = {}
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_day_one.json"):
		DirAccess.remove_absolute("user://test_day_one.json")


func _make_farm() -> Node2D:
	return (load(FARM_SCENE) as PackedScene).instantiate()


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
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, AldenDialog.DATA["intro"]["lines"][0])


func test_completing_alden_intro_grants_new_roots_and_sets_flag() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	assert_false(dialog.is_open(), "intro dialog must close after its final line")
	assert_true(GameState.flags.get("intro_done", false))
	assert_true(Quests.is_active(Quests.ID_NEW_ROOTS))


func test_alden_intro_hides_itself_once_played() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	assert_false(farm.alden_intro.visible)


func test_alden_intro_quest_toast_fires_on_completion() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	watch_signals(EventBus)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	farm.alden_intro.interact(farm.player)
	var line_count: int = AldenDialog.DATA["intro"]["lines"].size()
	for i in line_count:
		dialog._advance()
	assert_signal_emitted_with_parameters(EventBus, "quest_updated", [Quests.ID_NEW_ROOTS])


func test_alden_intro_despawns_at_afternoon_block_change() -> void:
	var farm: Node2D = _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_true(farm.alden_intro.visible)
	Clock.minutes = 14 * 60  # 12-17 block: normal schedule takes over
	EventBus.time_ticked.emit(Clock.hour(), Clock.minute())
	assert_false(farm.alden_intro.visible, "Alden's intro appearance must not persist past the morning blocks")


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
