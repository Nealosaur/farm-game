extends GutTest
## DEPTH stride: MineFloor generation determinism, floor-type variety, depth
## scaling, and the descend/ascend flow. Mirrors test_dungeon_floors.gd's
## "instance the script directly, call config methods" pattern for the pure
## generation checks, and test_dungeon_integration.gd's "add_child_autofree +
## wait_process_frames" pattern for the scene-tree integration checks.

const FLOOR_SCENE := "res://scenes/maps/mine_floor.tscn"


func before_each() -> void:
	Clock.paused = true
	SaveManager.save_path = "user://test_mine.json"
	SaveManager.new_game()
	SceneChanger.spawn_name = "entrance"


func after_each() -> void:
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	if FileAccess.file_exists("user://test_mine.json"):
		DirAccess.remove_absolute("user://test_mine.json")


func _char_at(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size():
		return ""
	var row := rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return ""
	return row[cell.x]


## ---- pure generation determinism (no scene tree needed) ----

func test_same_seed_and_depth_produces_identical_layout() -> void:
	var rects_a := MineFloor._generate_rects(42, 3)
	var rects_b := MineFloor._generate_rects(42, 3)
	assert_eq(rects_a, rects_b)


func test_different_depth_produces_different_layout() -> void:
	var rects_a := MineFloor._generate_rects(42, 3)
	var rects_b := MineFloor._generate_rects(42, 4)
	assert_ne(rects_a, rects_b)


func test_different_run_seed_produces_different_layout() -> void:
	var rects_a := MineFloor._generate_rects(42, 3)
	var rects_b := MineFloor._generate_rects(99, 3)
	assert_ne(rects_a, rects_b)


func test_generated_layout_is_rectangular_with_walkable_floor() -> void:
	for depth in [1, 5, 12]:
		var rects := MineFloor._generate_rects(7, depth)
		var rows := DungeonFloor.carve_layout(MineFloor.SIZE, rects)
		assert_gt(rows.size(), 0)
		var width := rows[0].length()
		var stone := 0
		for row in rows:
			assert_eq(row.length(), width, "rows must be rectangular at depth %d" % depth)
			stone += row.count("S")
		assert_gt(stone, 0, "needs walkable floor at depth %d" % depth)


func test_entrance_and_ascend_cell_always_walkable() -> void:
	for depth in [1, 2, 8]:
		var rects := MineFloor._generate_rects(7, depth)
		var rows := DungeonFloor.carve_layout(MineFloor.SIZE, rects)
		assert_eq(_char_at(rows, MineFloor.ENTRANCE_CELL), "S", "depth %d entrance" % depth)
		assert_eq(_char_at(rows, MineFloor.ASCEND_CELL), "S", "depth %d ascend stairs" % depth)
		# The descend cell must also be walkable, or the player could be trapped
		# with no way deeper (milestone-review coverage gap).
		assert_eq(_char_at(rows, MineFloor._descend_cell(rects)), "S",
			"depth %d descend stairs must be on walkable floor" % depth)


## ---- floor-type variety + enemy spawn generation ----

func test_enemy_spawns_deterministic_for_same_seed_and_depth() -> void:
	var rects := MineFloor._generate_rects(11, 3)
	var type := MineState.roll_floor_type(11, 3)
	var a := MineFloor._generate_enemy_spawns(11, 3, type, rects)
	var b := MineFloor._generate_enemy_spawns(11, 3, type, rects)
	assert_eq(a, b)


func test_enemy_spawns_are_on_walkable_cells_and_valid_ids() -> void:
	var rects := MineFloor._generate_rects(11, 5)
	var type := MineState.roll_floor_type(11, 5)
	var rows := DungeonFloor.carve_layout(MineFloor.SIZE, rects)
	for cfg: Dictionary in MineFloor._generate_enemy_spawns(11, 5, type, rects):
		assert_eq(_char_at(rows, cfg["cell"]), "S")
		assert_not_null(ItemDB.get_enemy(cfg["id"]), "enemy id '%s' must exist in ItemDB" % cfg["id"])


func test_monster_dense_floor_spawns_more_than_normal_at_same_depth() -> void:
	# Scan for a seed where depth 4's roll lands on MONSTER_DENSE, and a base
	# count comparison against the plain density formula.
	var rects := MineFloor._generate_rects(11, 4)
	var dense_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.MONSTER_DENSE, rects).size()
	var normal_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.NORMAL, rects).size()
	assert_gt(dense_count, normal_count)


func test_treasure_floor_spawns_fewer_enemies_than_normal() -> void:
	var rects := MineFloor._generate_rects(11, 4)
	var treasure_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.TREASURE, rects).size()
	var normal_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.NORMAL, rects).size()
	assert_lt(treasure_count, normal_count)


func test_quiet_floor_spawns_fewer_enemies_than_normal() -> void:
	var rects := MineFloor._generate_rects(11, 4)
	var quiet_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.QUIET, rects).size()
	var normal_count := MineFloor._generate_enemy_spawns(
		11, 4, MineState.FloorType.NORMAL, rects).size()
	assert_lt(quiet_count, normal_count)


func test_enemy_density_scales_with_depth() -> void:
	var shallow_rects := MineFloor._generate_rects(3, 1)
	var deep_rects := MineFloor._generate_rects(3, 10)
	var shallow := MineFloor._generate_enemy_spawns(3, 1, MineState.FloorType.NORMAL, shallow_rects).size()
	var deep := MineFloor._generate_enemy_spawns(3, 10, MineState.FloorType.NORMAL, deep_rects).size()
	assert_gte(deep, shallow, "deeper floors should never have fewer enemies at the same floor type")


## ---- scene-tree integration: depth counter + descend/ascend flow ----

func _make_floor() -> Node2D:
	return (load(FLOOR_SCENE) as PackedScene).instantiate()


func test_entering_mine_floor_uses_stored_depth_and_seed() -> void:
	SaveManager.world["mine"] = {"run_seed": 55, "depth": 3, "deepest": 3, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(f.depth, 3)
	assert_eq(f.run_seed, 55)
	assert_eq(f._floor_key(), "mine_3")


func test_missing_mine_blob_defaults_to_entry_depth() -> void:
	SaveManager.world.erase("mine")
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_eq(f.depth, MineState.ENTRY_DEPTH)


func test_descend_portal_writes_depth_plus_one() -> void:
	SaveManager.world["mine"] = {"run_seed": 8, "depth": 2, "deepest": 2, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var descend := f.get_node("World/DescendPortal") as Portal
	assert_not_null(descend)
	descend.pre_travel.call()
	assert_eq(int(SaveManager.world["mine"]["depth"]), 3)
	assert_eq(int(SaveManager.world["mine"]["deepest"]), 3)


func test_ascend_portal_writes_depth_minus_one() -> void:
	SaveManager.world["mine"] = {"run_seed": 8, "depth": 4, "deepest": 4, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var ascend := f.get_node("World/AscendPortal") as Portal
	assert_not_null(ascend)
	assert_true(ascend.pre_travel.is_valid())
	ascend.pre_travel.call()
	assert_eq(int(SaveManager.world["mine"]["depth"]), 3)
	assert_eq(int(SaveManager.world["mine"]["deepest"]), 4, "ascending must not raise the high-water mark")


func test_ascend_from_depth_one_targets_dungeon_3_and_skips_depth_write() -> void:
	SaveManager.world["mine"] = {"run_seed": 8, "depth": 1, "deepest": 1, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var ascend := f.get_node("World/AscendPortal") as Portal
	assert_eq(ascend.target_scene, "res://scenes/maps/dungeon_3.tscn")
	assert_eq(ascend.target_spawn, "from_below")
	assert_false(ascend.pre_travel.is_valid(), "leaving the mine must not touch the depth blob")


func test_deepest_persists_across_a_lower_depth_reentry() -> void:
	SaveManager.world["mine"] = {"run_seed": 8, "depth": 6, "deepest": 6, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var ascend := f.get_node("World/AscendPortal") as Portal
	ascend.pre_travel.call()
	assert_eq(int(SaveManager.world["mine"]["deepest"]), 6)


func test_killed_enemy_does_not_respawn_on_same_depth_same_run_reentry() -> void:
	SaveManager.world["mine"] = {"run_seed": 21, "depth": 2, "deepest": 2, "killed": {}}
	var f1 := _make_floor()
	add_child(f1)
	await wait_process_frames(2)
	var enemies := []
	for child in f1.get_node("World").get_children():
		if child is Enemy:
			enemies.append(child)
	assert_gt(enemies.size(), 0)
	var victim: Enemy = enemies[0]
	victim.health.take_damage(9999)
	await wait_process_frames(1)
	assert_true(MineState.is_killed(SaveManager.world["mine"], 2, 0),
		"the killed enemy is recorded in the per-depth ledger")
	f1.free()

	var f2 := _make_floor()
	add_child_autofree(f2)
	await wait_process_frames(2)
	var enemies2 := []
	for child in f2.get_node("World").get_children():
		if child is Enemy:
			enemies2.append(child)
	assert_eq(enemies2.size(), enemies.size() - 1,
		"killed enemy must stay dead on same-run, same-depth reentry")


func test_fresh_dive_reset_respawns_everyone_at_same_depth() -> void:
	# Same run_seed both times (so the generated layout/roster at depth 2 is
	# IDENTICAL — this isolates the kill-ledger reset from floor-type/count
	# variance across different seeds, which a raw enemy-count comparison
	# across DIFFERENT seeds can't safely assume).
	var full_roster_size := MineFloor._generate_enemy_spawns(
		21, 2, MineState.roll_floor_type(21, 2), MineFloor._generate_rects(21, 2)).size()

	SaveManager.world["mine"] = {"run_seed": 21, "depth": 2, "deepest": 2,
		"killed": {"2": [0]}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var enemies1 := []
	for child in f.get_node("World").get_children():
		if child is Enemy:
			enemies1.append(child)
	assert_eq(enemies1.size(), full_roster_size - 1,
		"precondition: index 0 stays dead this run")
	f.free()

	# A fresh dive on the SAME run_seed's depth-2 layout (isolating the
	# kill-ledger reset itself — MineState.ensure_run() with a NEW seed
	# clearing "killed" is already covered at the pure-logic level in
	# test_mine_state.gd) must not inherit the OLD dive's kill ledger.
	SaveManager.world["mine"] = {"run_seed": 21, "depth": 2, "deepest": 2, "killed": {}}
	var f2 := _make_floor()
	add_child_autofree(f2)
	await wait_process_frames(2)
	var enemies2 := []
	for child in f2.get_node("World").get_children():
		if child is Enemy:
			enemies2.append(child)
	assert_eq(enemies2.size(), full_roster_size,
		"a fresh dive's same depth must spawn the full roster again")


func test_treasure_floor_scatters_bonus_pickups() -> void:
	# Scan for a run_seed/depth combo that rolls TREASURE (deterministic
	# search, not random — same reasoning as the floor-type distribution test).
	var found_depth := -1
	var seed_used := 4242
	for depth in range(1, 60):
		if MineState.roll_floor_type(seed_used, depth) == MineState.FloorType.TREASURE:
			found_depth = depth
			break
	assert_gt(found_depth, 0, "test setup: expected a TREASURE roll within 60 depths")
	SaveManager.world["mine"] = {"run_seed": seed_used, "depth": found_depth, "deepest": found_depth, "killed": {}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var pickups := []
	for child in f.get_node("World").get_children():
		if child is Pickup:
			pickups.append(child)
	assert_gt(pickups.size(), 0, "treasure floor must scatter bonus pickups")
