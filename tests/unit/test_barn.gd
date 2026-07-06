extends GutTest
## Craft Stride 3 (Taming): barn/pen farm integration — population render on
## load, pettable interact, wander stays within the pen bounds, fence/barn
## solidity (no combat on the farm — BarnSlime has no hitbox/hurtbox/health
## at all, so there is nothing to fight even if you tried).

func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_barn.json"
	SaveManager.new_game()


func after_each() -> void:
	Clock.paused = false
	SaveManager.world.erase("taming")
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_barn.json"):
		DirAccess.remove_absolute("user://test_barn.json")


func _make_farm() -> Node2D:
	return (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()


# ---- population render on farm load ----

func test_empty_barn_renders_no_slimes() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_eq(farm.barn_slimes.size(), 0)


func test_one_tamed_slime_renders_one_barn_slime() -> void:
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_eq(farm.barn_slimes.size(), 1)
	assert_true(farm.barn_slimes[0] is BarnSlime)


func test_two_tamed_slimes_render_two_barn_slimes_at_distinct_cells() -> void:
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime", "slime"]}
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_eq(farm.barn_slimes.size(), 2)
	assert_ne(farm.barn_slimes[0].position, farm.barn_slimes[1].position,
		"two barn slimes must not spawn stacked on the same cell")


func test_barn_slimes_spawn_inside_the_pen_interior() -> void:
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime", "slime"]}
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	for slime: BarnSlime in farm.barn_slimes:
		var cell := MapBuilder.cell_of(slime.position)
		assert_true(farm.PEN_RECT.has_point(cell),
			"barn slime at %s must be inside PEN_RECT %s" % [cell, farm.PEN_RECT])


# ---- pettable interact ----

func test_petting_a_barn_slime_shows_the_bible_toast() -> void:
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var slime: BarnSlime = farm.barn_slimes[0]
	watch_signals(EventBus)
	slime.interact(farm.player)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["Squish. It seems content."])


# ---- wander stays within pen bounds ----

func test_barn_slime_wander_never_leaves_the_pen_rect() -> void:
	var slime := BarnSlime.new()
	add_child_autofree(slime)
	var rect := Rect2i(25, 2, 8, 5)
	slime.setup(rect)
	slime.position = MapBuilder.cell_center(rect.position)
	# Force a direction pointed straight out of the pen and simulate many
	# frames — _clamp_to_pen() must keep it inside no matter how long it runs.
	slime._dir = Vector2(-1, -1)
	for i in 200:
		slime._process(0.1)
	var cell := MapBuilder.cell_of(slime.position)
	assert_true(rect.has_point(cell), "wander must never carry the slime outside PEN_RECT")


func test_barn_slime_does_nothing_before_setup() -> void:
	## pen_rect defaults to Rect2i() (size ZERO) until setup() runs —
	## _process() must no-op rather than divide/clamp against a zero rect.
	var slime := BarnSlime.new()
	add_child_autofree(slime)
	var pos_before := slime.position
	slime._process(0.5)
	assert_eq(slime.position, pos_before)


# ---- no combat on the farm ----

func test_barn_slime_has_no_combat_components() -> void:
	## Bible: "no combat interactions on the farm" — BarnSlime is a plain
	## Area2D (like Bed/Kitchen), never an Enemy, so it structurally cannot
	## be fought: no HealthComponent, no Hurtbox/Hitbox children at all.
	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var slime: BarnSlime = farm.barn_slimes[0]
	assert_null(slime.get_node_or_null("HealthComponent"))
	assert_null(slime.get_node_or_null("Hurtbox"))
	assert_null(slime.get_node_or_null("Hitbox"))


# ---- pen fence + barn solidity ----

func test_pen_fence_cells_are_solid_except_the_entrance() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var solid_rects: Array[Rect2i] = farm._solid_prop_rects()
	for cell: Vector2i in farm._pen_fence_cells():
		var covered := false
		for r in solid_rects:
			if r.has_point(cell):
				covered = true
				break
		assert_true(covered, "fence cell %s must be solid" % cell)
	# The entrance itself must NOT be covered by any solid rect.
	var entrance_covered := false
	for r in solid_rects:
		if r.has_point(farm.PEN_ENTRANCE_CELL):
			entrance_covered = true
	assert_false(entrance_covered, "PEN_ENTRANCE_CELL must stay walkable")


func test_pen_interior_cells_are_not_solid() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var solid_rects: Array[Rect2i] = farm._solid_prop_rects()
	var r: Rect2i = farm.PEN_RECT
	for x in range(r.position.x, r.position.x + r.size.x):
		for y in range(r.position.y, r.position.y + r.size.y):
			var cell := Vector2i(x, y)
			if farm.BARN_CELL.x <= cell.x and cell.x < farm.BARN_CELL.x + 2 \
					and farm.BARN_CELL.y <= cell.y and cell.y < farm.BARN_CELL.y + 2:
				continue  # the barn prop itself is legitimately solid
			var covered := false
			for rect in solid_rects:
				if rect.has_point(cell):
					covered = true
					break
			assert_false(covered, "pen interior cell %s must stay walkable" % cell)


func test_path_grid_treats_the_entrance_as_walkable() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_true(farm.path_grid.is_walkable(farm.PEN_ENTRANCE_CELL))


func test_path_grid_treats_fence_cells_as_solid() -> void:
	var farm := _make_farm()
	add_child_autofree(farm)
	await wait_process_frames(2)
	for cell: Vector2i in farm._pen_fence_cells():
		assert_false(farm.path_grid.is_walkable(cell), "fence cell %s must block pathing" % cell)
