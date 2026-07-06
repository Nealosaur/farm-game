extends GutTest
## Craft Stride 2: copper watering can — flanking-cell geometry (perpendicular
## to facing), wide watering through the REAL player use-tool path (RP charged
## exactly once per swing), field-edge partial application, and the ordinary
## width-1 can staying unaffected. Farm-scene fixture mirrors
## test_farm_integration.gd; Clock day/weather pinned per the fixture
## convention (a leaked rain value would only matter overnight, but pin it
## anyway so nothing in this file depends on another file's leftovers).

var farm: Node2D
var player: Player
var grid: FarmGrid


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_watering_width.json"
	SaveManager.new_game()
	Clock.day = 10  # mid-spring: no season-rollover wilt surprises (see test_farm_grid.gd)
	Clock.weather = "clear"
	farm = (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	player = farm.player
	grid = farm.grid
	Inventory.add_item("copper_can", 1)  # slot 4: hoe/can/sword/seeds are 0-3 (SaveManager.new_game)


func after_each() -> void:
	Clock.day = 1
	Clock.weather = "clear"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_watering_width.json"):
		DirAccess.remove_absolute("user://test_watering_width.json")


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _stand_targeting(cell: Vector2i, facing: Vector2i) -> void:
	## Puts the player one cell BEHIND `cell` along `facing`, so target_cell()
	## resolves to `cell` (generalizes test_farm_integration.gd's right-only
	## helper to all four directions).
	player.global_position = MapBuilder.cell_center(cell - facing)
	player.facing = facing


## ---- pure flank geometry (static, no scene state) ----

func test_flanking_cells_facing_up_flanks_left_and_right() -> void:
	var c := Vector2i(5, 5)
	var cells := FarmGrid.flanking_cells(c, Vector2i.UP, 3)
	assert_eq(cells.size(), 3)
	assert_true(c in cells)
	assert_true(c + Vector2i.LEFT in cells)
	assert_true(c + Vector2i.RIGHT in cells)


func test_flanking_cells_facing_down_flanks_left_and_right() -> void:
	var c := Vector2i(5, 5)
	var cells := FarmGrid.flanking_cells(c, Vector2i.DOWN, 3)
	assert_true(c + Vector2i.LEFT in cells)
	assert_true(c + Vector2i.RIGHT in cells)


func test_flanking_cells_facing_left_flanks_up_and_down() -> void:
	var c := Vector2i(5, 5)
	var cells := FarmGrid.flanking_cells(c, Vector2i.LEFT, 3)
	assert_eq(cells.size(), 3)
	assert_true(c + Vector2i.UP in cells)
	assert_true(c + Vector2i.DOWN in cells)


func test_flanking_cells_facing_right_flanks_up_and_down() -> void:
	var c := Vector2i(5, 5)
	var cells := FarmGrid.flanking_cells(c, Vector2i.RIGHT, 3)
	assert_true(c + Vector2i.UP in cells)
	assert_true(c + Vector2i.DOWN in cells)


func test_flanking_cells_width_one_is_just_the_target() -> void:
	var c := Vector2i(5, 5)
	var cells := FarmGrid.flanking_cells(c, Vector2i.UP, 1)
	assert_eq(cells, [c] as Array[Vector2i])


func test_flanking_cells_generic_width_five() -> void:
	## water_width is a GENERIC field, not hardcoded to 3 — a future wider
	## can just works (see tool_data.gd's field doc).
	var cells := FarmGrid.flanking_cells(Vector2i(5, 5), Vector2i.RIGHT, 5)
	assert_eq(cells.size(), 5)
	assert_true(Vector2i(5, 3) in cells)
	assert_true(Vector2i(5, 7) in cells)


## ---- copper can through the real player path ----
## Farm TILLABLE is Rect2i(24, 10, 14, 10) — all target cells below sit
## comfortably inside it unless a test is explicitly about the field edge.

func test_copper_can_facing_right_waters_target_plus_vertical_flanks() -> void:
	var c := Vector2i(26, 12)
	for cell: Vector2i in [c, c + Vector2i.UP, c + Vector2i.DOWN]:
		grid.till(cell)
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_can")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots[c].watered)
	assert_true(grid.plots[c + Vector2i.UP].watered, "facing right must flank up")
	assert_true(grid.plots[c + Vector2i.DOWN].watered, "facing right must flank down")
	assert_eq(GameState.rp, rp_before - 3, "one swing = ONE rp_cost 3 charge, never per-cell")


func test_copper_can_facing_up_waters_target_plus_horizontal_flanks() -> void:
	var c := Vector2i(30, 15)
	for cell: Vector2i in [c, c + Vector2i.LEFT, c + Vector2i.RIGHT]:
		grid.till(cell)
	_stand_targeting(c, Vector2i.UP)
	_select("copper_can")
	player.try_use_selected()
	assert_true(grid.plots[c].watered)
	assert_true(grid.plots[c + Vector2i.LEFT].watered, "facing up must flank left")
	assert_true(grid.plots[c + Vector2i.RIGHT].watered, "facing up must flank right")


func test_copper_can_facing_down_waters_target_plus_horizontal_flanks() -> void:
	var c := Vector2i(30, 15)
	for cell: Vector2i in [c, c + Vector2i.LEFT, c + Vector2i.RIGHT]:
		grid.till(cell)
	_stand_targeting(c, Vector2i.DOWN)
	_select("copper_can")
	player.try_use_selected()
	assert_true(grid.plots[c + Vector2i.LEFT].watered, "facing down must flank left")
	assert_true(grid.plots[c + Vector2i.RIGHT].watered, "facing down must flank right")


func test_copper_can_edge_partial_waters_what_it_can_single_rp_charge() -> void:
	## One flank untilled (stand-in for "off the edge of the field" — an
	## untilled cell and an out-of-bounds cell fail the same water() gate):
	## the swing still waters the target + the other flank, and still charges
	## RP exactly once.
	var c := Vector2i(26, 12)
	grid.till(c)
	grid.till(c + Vector2i.DOWN)  # up flank deliberately NOT tilled
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_can")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots[c].watered)
	assert_true(grid.plots[c + Vector2i.DOWN].watered)
	assert_false(grid.plots.has(c + Vector2i.UP), "untilled flank stays untouched")
	assert_eq(GameState.rp, rp_before - 3, "partial application still charges exactly one swing")


func test_copper_can_true_field_edge_row_partial() -> void:
	## Literal edge-of-field: target on the TOP tillable row (y=10) facing
	## right — the up flank (y=9) is OUTSIDE Rect2i(24,10,14,10) and can't
	## even be tilled; the swing waters the two in-bounds cells.
	var c := Vector2i(26, 10)
	grid.till(c)
	grid.till(c + Vector2i.DOWN)
	assert_false(grid.till(c + Vector2i.UP), "precondition: y=9 is outside the tillable field")
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_can")
	player.try_use_selected()
	assert_true(grid.plots[c].watered)
	assert_true(grid.plots[c + Vector2i.DOWN].watered)


func test_copper_can_charges_nothing_when_no_cell_waterable() -> void:
	var c := Vector2i(26, 12)
	for cell: Vector2i in [c, c + Vector2i.UP, c + Vector2i.DOWN]:
		grid.till(cell)
		grid.water(cell)  # everything already watered
	_stand_targeting(c, Vector2i.RIGHT)
	_select("copper_can")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_eq(GameState.rp, rp_before, "an all-watered swing must not spend RP")


func test_ordinary_watering_can_still_waters_only_the_target() -> void:
	var c := Vector2i(26, 12)
	for cell: Vector2i in [c, c + Vector2i.UP, c + Vector2i.DOWN]:
		grid.till(cell)
	_stand_targeting(c, Vector2i.RIGHT)
	_select("watering_can")
	var rp_before := GameState.rp
	player.try_use_selected()
	assert_true(grid.plots[c].watered)
	assert_false(grid.plots[c + Vector2i.UP].watered, "width-1 can must not gain flanks")
	assert_false(grid.plots[c + Vector2i.DOWN].watered)
	assert_eq(GameState.rp, rp_before - 2, "ordinary can still costs its own rp_cost 2")
