extends GutTest

const TEST_PATH := "user://test_save.json"


func before_each() -> void:
	SaveManager.save_path = TEST_PATH
	SaveManager.new_game()


func after_each() -> void:
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_new_game_starting_kit() -> void:
	assert_eq(GameState.gold, 500)
	assert_eq(Inventory.count_of("hoe"), 1)
	assert_eq(Inventory.count_of("watering_can"), 1)
	assert_eq(Inventory.count_of("wooden_sword"), 1)
	assert_eq(Inventory.count_of("turnip_seeds"), 5)
	assert_eq(Clock.day, 1)


func test_round_trip() -> void:
	GameState.gold = 1234
	Clock.day = 7
	Inventory.add_item("carrot", 3)
	SaveManager.world["farm_grid"] = {"0,0": {"tilled": true}}
	assert_true(SaveManager.save_game())
	SaveManager.new_game()
	assert_eq(GameState.gold, 500)
	assert_true(SaveManager.load_game())
	assert_eq(GameState.gold, 1234)
	assert_eq(Clock.day, 7)
	assert_eq(Inventory.count_of("carrot"), 3)
	assert_true(SaveManager.world.has("farm_grid"))


func test_corrupt_file_returns_false() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("this is not json{{{")
	f.close()
	assert_false(SaveManager.load_game())


func test_missing_keys_use_defaults() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"save_version": 1, "day": 3}')
	f.close()
	assert_true(SaveManager.load_game())
	assert_eq(Clock.day, 3)
	assert_eq(GameState.gold, GameState.STARTING_GOLD)


func test_no_file_returns_false() -> void:
	assert_false(SaveManager.load_game())
	assert_false(SaveManager.has_save())


func test_version_mismatch_warns_but_loads() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"save_version": 99, "day": 4}')
	f.close()
	assert_true(SaveManager.load_game())
	assert_eq(Clock.day, 4)
