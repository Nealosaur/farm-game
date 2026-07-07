extends GutTest
## DEPTH stride: fishing end-to-end through the real player/map path.
## MapBuilder.is_water_at() against a real built Ground layer, player.gd's
## rod-use gating (must face water + hold a FISHING_ROD), and FishingScreen's
## cast -> bite -> catch/fail flow including species delivery into the
## real Inventory. Mirrors test_watering_width.gd's "load the real map scene,
## drive the real player" fixture shape.

var riverwoods: Node2D
var player: Player
var screen: FishingScreen


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_fishing.json"
	SaveManager.new_game()
	Inventory.add_item("fishing_rod", 1)
	riverwoods = (load("res://scenes/maps/riverwoods.tscn") as PackedScene).instantiate()
	add_child_autofree(riverwoods)
	await wait_process_frames(2)
	player = riverwoods.player
	screen = get_tree().get_first_node_in_group("fishing_screen")


func after_each() -> void:
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_fishing.json"):
		DirAccess.remove_absolute("user://test_fishing.json")


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _stand_targeting(cell: Vector2i, facing: Vector2i) -> void:
	player.global_position = MapBuilder.cell_center(cell - facing)
	player.facing = facing


## ---- MapBuilder.is_water_at against a real built map ----

func test_is_water_at_true_on_river_tile() -> void:
	var ground := riverwoods.get_node("Ground") as TileMapLayer
	assert_true(MapBuilder.is_water_at(ground, Vector2i(riverwoods.RIVER_X, 5)))


func test_is_water_at_false_on_grass_tile() -> void:
	var ground := riverwoods.get_node("Ground") as TileMapLayer
	assert_false(MapBuilder.is_water_at(ground, Vector2i(5, 5)))


func test_is_water_at_false_on_the_crossing() -> void:
	var ground := riverwoods.get_node("Ground") as TileMapLayer
	assert_false(MapBuilder.is_water_at(ground, Vector2i(riverwoods.RIVER_X, riverwoods.CROSSING_Y_START + 1)))


## ---- player.gd rod-use gating ----

func test_using_rod_facing_water_opens_fishing_screen() -> void:
	_stand_targeting(Vector2i(riverwoods.RIVER_X, 5), Vector2i.RIGHT)
	_select("fishing_rod")
	player.try_use_selected()
	assert_true(screen.is_open(), "casting while facing water must open the fishing screen")


func test_using_rod_not_facing_water_does_not_open_screen() -> void:
	_stand_targeting(Vector2i(5, 5), Vector2i.RIGHT)  # plain grass, not water
	_select("fishing_rod")
	player.try_use_selected()
	assert_false(screen.is_open(), "casting away from water must not open the fishing screen")


func test_using_rod_pauses_tree_while_open() -> void:
	_stand_targeting(Vector2i(riverwoods.RIVER_X, 5), Vector2i.RIGHT)
	_select("fishing_rod")
	player.try_use_selected()
	assert_true(get_tree().paused)
	screen._close()  # manual teardown so this test doesn't leak a paused tree
	assert_false(get_tree().paused)


## ---- FishingScreen cast -> bite -> resolve flow ----

func test_start_cast_shows_casting_status_immediately() -> void:
	screen.start_cast(FishingLogic.WATER_RIVER)
	assert_true(screen.is_open())
	assert_eq(screen._phase, "casting")
	screen._close()


func test_bite_arrives_and_transitions_to_biting_phase() -> void:
	screen.start_cast(FishingLogic.WATER_RIVER)
	# Force the bite immediately rather than waiting real wall-clock seconds
	# for FishingLogic's randomized 0.6-1.6s delay — same "drive the callback
	# directly" approach test_mine_floor.gd uses for portal pre_travel.
	screen._on_bite()
	assert_eq(screen._phase, "biting")
	screen._close()


func test_successful_catch_grants_a_river_species_item() -> void:
	screen.start_cast(FishingLogic.WATER_RIVER)
	screen._on_bite()
	# Force the marker to a known position inside the zone so the outcome is
	# deterministic rather than depending on real per-frame timing.
	screen._elapsed = 0.0  # marker_position(0) == 0.0
	screen._zone = Vector2(-0.05, 0.05)  # zone that safely contains 0.0
	var before_total := 0
	for id: String in FishingLogic.RIVER_POOL:
		before_total += Inventory.count_of(id)
	screen._resolve_catch()
	var after_total := 0
	for id: String in FishingLogic.RIVER_POOL:
		after_total += Inventory.count_of(id)
	assert_eq(after_total, before_total + 1, "a successful catch must grant exactly one river fish item")
	assert_false(screen.is_open(), "screen closes after resolving")


func test_failed_catch_grants_nothing() -> void:
	screen.start_cast(FishingLogic.WATER_RIVER)
	screen._on_bite()
	screen._elapsed = 0.0
	screen._zone = Vector2(0.8, 0.95)  # zone that excludes marker position 0.0
	var before_total := 0
	for id: String in FishingLogic.RIVER_POOL:
		before_total += Inventory.count_of(id)
	screen._resolve_catch()
	var after_total := 0
	for id: String in FishingLogic.RIVER_POOL:
		after_total += Inventory.count_of(id)
	assert_eq(after_total, before_total, "a failed catch must grant nothing")
	assert_false(screen.is_open(), "screen closes after resolving even on failure")


func test_sea_water_body_grants_a_sea_species() -> void:
	screen.start_cast(FishingLogic.WATER_SEA)
	screen._on_bite()
	screen._elapsed = 0.0
	screen._zone = Vector2(-0.05, 0.05)
	screen._resolve_catch()
	var sea_total := 0
	for id: String in FishingLogic.SEA_POOL:
		sea_total += Inventory.count_of(id)
	assert_eq(sea_total, 1, "casting in a 'sea' water body must grant a sea species, not a river one")
