extends GutTest
## Title screen: Continue gating, New Game overwrite-confirm arming, and the
## corrupt-save Continue fallback (must not crash, must fall back to
## new-game-equivalent state).
##
## NOT covered headless (documented tradeoff, matches test_portal.gd /
## test_dungeon_integration.gd convention): the actual scene travel
## (SceneChanger.travel / swap_scene_while_black -> change_scene_to_file)
## would tear down GUT's own scene mid-run. Every test that presses a button
## which triggers a travel therefore arms SceneChanger._traveling = true
## first so the travel calls no-op (same "simulate a travel in flight" guard
## test_portal.gd uses) — only the pre-travel DECISION logic (save state,
## confirm-arming, corrupt-save fallback) is asserted here.

var title: Title


func before_each() -> void:
	SaveManager.delete_save()
	title = (load("res://scripts/main/title.gd") as GDScript).new() as Title
	add_child_autofree(title)
	SceneChanger._traveling = true  # block real scene swaps for the whole test


func after_each() -> void:
	SaveManager.delete_save()
	SceneChanger._traveling = false


func test_continue_disabled_when_no_save() -> void:
	assert_false(Title.continue_allowed())
	assert_true(title.continue_btn.disabled)


func test_continue_enabled_when_save_exists() -> void:
	SaveManager.new_game()
	SaveManager.save_game()
	assert_true(Title.continue_allowed())


func test_new_game_press_without_existing_save_does_not_arm_confirm() -> void:
	assert_false(SaveManager.has_save())
	title._on_new_game_pressed()
	assert_false(title._confirm_armed)
	assert_eq(title.new_game_btn.text, "New Game")


func test_new_game_press_with_existing_save_arms_confirm_and_does_not_overwrite_yet() -> void:
	SaveManager.new_game()
	SaveManager.save_game()
	GameState.gold = 12345
	title._on_new_game_pressed()
	assert_true(title._confirm_armed)
	assert_eq(title.new_game_btn.text, "Click again to overwrite")
	assert_eq(GameState.gold, 12345, "first click must not have reset state yet")


func test_second_new_game_press_confirms_and_resets() -> void:
	SaveManager.new_game()
	SaveManager.save_game()
	GameState.gold = 12345
	title._on_new_game_pressed()
	title._on_new_game_pressed()
	assert_false(title._confirm_armed)
	assert_eq(GameState.gold, GameState.STARTING_GOLD)


func test_confirm_disarms_after_window_expires() -> void:
	SaveManager.new_game()
	SaveManager.save_game()
	title._on_new_game_pressed()
	assert_true(title._confirm_armed)
	title._on_confirm_window_expired()
	assert_false(title._confirm_armed)
	assert_eq(title.new_game_btn.text, "New Game")


func test_boss_defeated_flag_survives_save_and_title_continue() -> void:
	## The vertical-slice victory flag (GameState.flags["boss_defeated"], set
	## by SlimeKing before EventBus.boss_defeated fires) must still be true
	## after: save -> return to title -> press Continue. GameState.to_dict()/
	## from_dict() already round-trip `flags` generically; this pins the
	## specific flag the title flow depends on end to end.
	SaveManager.new_game()
	GameState.flags["boss_defeated"] = true
	SaveManager.save_game()

	GameState.flags = {}  # simulate a fresh process before Continue is pressed
	title._on_continue_pressed()
	assert_true(GameState.flags.get("boss_defeated", false),
		"boss_defeated flag must survive a save/Continue round trip")


func test_continue_with_corrupt_save_falls_back_without_crashing() -> void:
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{ not valid json ]")
	f.close()
	assert_true(SaveManager.has_save())

	# Continue must not crash on a corrupt file, and must leave the game in a
	# fresh-new-game-equivalent state (SaveManager.new_game() was called).
	GameState.gold = 999999
	title._on_continue_pressed()
	assert_eq(GameState.gold, GameState.STARTING_GOLD, "corrupt-save Continue should behave like New Game")
