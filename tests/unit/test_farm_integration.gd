extends GutTest

var farm: Node2D
var player: Player
var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_integration.json"
	SaveManager.new_game()
	farm = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	player = farm.player
	grid = farm.grid


func after_each() -> void:
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_integration.json"):
		DirAccess.remove_absolute("user://test_integration.json")


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _stand_targeting(cell: Vector2i) -> void:
	player.global_position = MapBuilder.cell_center(cell + Vector2i.LEFT)
	player.facing = Vector2i.RIGHT


func test_full_farming_chain_through_player() -> void:
	var c := Vector2i(26, 12)   # inside TILLABLE Rect2i(24,10,14,10)
	_stand_targeting(c)

	_select("hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots.has(c), "hoe should till the target cell")
	assert_eq(GameState.rp, rp_before - 4, "hoe costs 4 RP")

	_select("turnip_seeds")
	var seeds_before := Inventory.count_of("turnip_seeds")
	player.try_use_selected()
	assert_eq(grid.plots[c].crop_id, "turnip")
	assert_eq(Inventory.count_of("turnip_seeds"), seeds_before - 1)

	_select("watering_can")
	player.try_use_selected()
	assert_true(grid.plots[c].watered)

	for day in 3:
		grid.water(c)
		Clock.end_day()
	assert_true(grid.is_ripe(c))

	player.try_interact()
	assert_eq(Inventory.count_of("turnip"), 1)
	assert_eq(grid.plots[c].crop_id, "")


func test_tilling_outside_field_fails_and_costs_nothing() -> void:
	_stand_targeting(Vector2i(3, 3))   # outside TILLABLE
	_select("hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_false(grid.plots.has(Vector2i(3, 3)))
	assert_eq(GameState.rp, rp_before)


func test_eating_restores_rp() -> void:
	Inventory.add_item("turnip", 1)
	GameState.rp = 10
	_select("turnip")
	player.try_use_selected()
	assert_eq(GameState.rp, 40)   # +30 from turnip
	assert_eq(Inventory.count_of("turnip"), 0)


func test_day_flow_rollover_pays_shipping_and_saves() -> void:
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	assert_not_null(flow, "DayFlow should be in the farm scene")
	SaveManager.world["shipping_bin"] = {"turnip": 2}   # 2*45 = 90g
	var gold_before := GameState.gold
	var day_before := Clock.day
	GameState.rp = 5
	await flow.end_day(false)
	assert_eq(GameState.gold, gold_before + 90)
	assert_eq(Clock.day, day_before + 1)
	assert_eq(GameState.rp, GameState.max_rp)           # normal sleep = full RP
	assert_true(SaveManager.world["shipping_bin"].is_empty(), "bin must be cleared after payout")
	assert_true(SaveManager.has_save())                 # autosaved


func test_collapse_halves_rp() -> void:
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(true)
	assert_eq(GameState.rp, roundi(GameState.max_rp / 2.0))
