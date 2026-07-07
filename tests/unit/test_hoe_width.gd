extends GutTest
## DEPTH stride: tiered hoe (Copper/Golden Hoe) — till_wide()'s flanking-cell
## geometry reuses FarmGrid.flanking_cells() (already covered generically by
## test_watering_width.gd's pure-geometry tests), so this file focuses on the
## till-specific real-path integration: wide tilling through player.gd,
## RP charged exactly once per swing, field-edge partial application, and the
## ordinary width-1 hoe staying unaffected. Mirrors test_watering_width.gd's
## fixture/shape exactly.

var farm: Node2D
var player: Player
var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_hoe_width.json"
	SaveManager.new_game()
	Clock.day = 10  # mid-spring: no season-rollover wilt surprises
	Clock.weather = "clear"
	farm = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	player = farm.player
	grid = farm.grid
	Inventory.add_item("copper_hoe", 1)
	Inventory.add_item("golden_hoe", 1)


func after_each() -> void:
	Clock.day = 1
	Clock.weather = "clear"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_hoe_width.json"):
		DirAccess.remove_absolute("user://test_hoe_width.json")


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


## Farm TILLABLE is Rect2i(24, 10, 14, 10) — target cells below sit
## comfortably inside it unless a test is explicitly about the field edge.

func test_copper_hoe_facing_right_tills_target_plus_vertical_flanks() -> void:
	var c := Vector2i(26, 12)
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots.has(c))
	assert_true(grid.plots.has(c + Vector2i.UP), "facing right must flank up")
	assert_true(grid.plots.has(c + Vector2i.DOWN), "facing right must flank down")
	assert_eq(GameState.rp, rp_before - 4, "one swing = ONE rp_cost 4 charge, never per-cell")


func test_copper_hoe_facing_up_tills_target_plus_horizontal_flanks() -> void:
	var c := Vector2i(30, 15)
	_stand_targeting(c, Vector2i.UP)
	_select("copper_hoe")
	player.try_use_selected()
	assert_true(grid.plots.has(c))
	assert_true(grid.plots.has(c + Vector2i.LEFT), "facing up must flank left")
	assert_true(grid.plots.has(c + Vector2i.RIGHT), "facing up must flank right")


func test_golden_hoe_tills_five_cells_across() -> void:
	var c := Vector2i(30, 15)
	_stand_targeting(c, Vector2i.UP)
	_select("golden_hoe")
	player.try_use_selected()
	var tilled := 0
	for cell: Vector2i in [c, c + Vector2i.LEFT, c + Vector2i.RIGHT,
			c + Vector2i.LEFT * 2, c + Vector2i.RIGHT * 2]:
		if grid.plots.has(cell):
			tilled += 1
	assert_eq(tilled, 5, "golden hoe (till_width 5) must till the full 5-cell row")


func test_hoe_edge_partial_tills_what_it_can_single_rp_charge() -> void:
	## One flank out of bounds: the swing still tills the target + the
	## in-bounds flank, and still charges RP exactly once.
	var c := Vector2i(26, 10)  # top tillable row (y=10)
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots.has(c))
	assert_true(grid.plots.has(c + Vector2i.DOWN))
	assert_false(grid.plots.has(c + Vector2i.UP), "y=9 is outside the tillable field")
	assert_eq(GameState.rp, rp_before - 4, "partial application still charges exactly one swing")


func test_ordinary_hoe_still_tills_only_the_target() -> void:
	var c := Vector2i(26, 12)
	_stand_targeting(c, Vector2i.RIGHT)
	_select("hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots.has(c))
	assert_false(grid.plots.has(c + Vector2i.UP), "width-1 hoe must not gain flanks")
	assert_false(grid.plots.has(c + Vector2i.DOWN))
	assert_eq(GameState.rp, rp_before - 4, "ordinary hoe still costs its own rp_cost 4")


func test_hoe_charges_nothing_when_no_cell_tillable() -> void:
	var c := Vector2i(26, 12)
	for cell: Vector2i in [c, c + Vector2i.UP, c + Vector2i.DOWN]:
		grid.till(cell)  # everything already tilled
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_hoe")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_eq(GameState.rp, rp_before, "an all-tilled swing must not spend RP")
