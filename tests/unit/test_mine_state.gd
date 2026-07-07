extends GutTest
## Pure dict logic for the mine's per-run descent ledger (MineState). Mirrors
## test_dungeon_state.gd's shape — no scene tree, no autoload state.


func test_ensure_run_initializes_fresh_blob() -> void:
	var blob := MineState.ensure_run({}, 42)
	assert_eq(int(blob["run_seed"]), 42)
	assert_eq(int(blob["depth"]), MineState.ENTRY_DEPTH)
	assert_eq(int(blob["deepest"]), 0)
	assert_eq(blob["killed"], {})


func test_ensure_run_same_seed_keeps_depth_and_kills() -> void:
	var blob := MineState.ensure_run({}, 7)
	blob = MineState.record_depth(blob, 3)
	blob = MineState.record_kill(blob, 3, 1)
	blob = MineState.ensure_run(blob, 7)
	assert_eq(int(blob["depth"]), 3, "same run_seed must not reset depth")
	assert_true(MineState.is_killed(blob, 3, 1), "same run_seed must not reset kills")


func test_ensure_run_new_seed_resets_depth_and_kills_but_keeps_deepest() -> void:
	var blob := MineState.ensure_run({}, 7)
	blob = MineState.record_depth(blob, 5)
	blob = MineState.record_kill(blob, 5, 0)
	blob = MineState.ensure_run(blob, 99)  # fresh dive: different seed
	assert_eq(int(blob["run_seed"]), 99)
	assert_eq(int(blob["depth"]), MineState.ENTRY_DEPTH, "fresh dive resets to depth 1")
	assert_false(MineState.is_killed(blob, 5, 0), "fresh dive clears the kill ledger")
	assert_eq(int(blob["deepest"]), 5, "deepest is a permanent high-water mark")


func test_record_depth_bumps_deepest_only_on_new_high_water_mark() -> void:
	var blob := MineState.ensure_run({}, 1)
	blob = MineState.record_depth(blob, 4)
	assert_eq(int(blob["deepest"]), 4)
	blob = MineState.record_depth(blob, 2)  # ascend back up
	assert_eq(int(blob["depth"]), 2)
	assert_eq(int(blob["deepest"]), 4, "ascending must not lower the high-water mark")
	blob = MineState.record_depth(blob, 6)
	assert_eq(int(blob["deepest"]), 6)


func test_record_kill_and_is_killed_per_depth() -> void:
	var blob := MineState.ensure_run({}, 1)
	blob = MineState.record_kill(blob, 2, 3)
	assert_true(MineState.is_killed(blob, 2, 3))
	assert_false(MineState.is_killed(blob, 2, 0), "other index untouched")
	assert_false(MineState.is_killed(blob, 3, 3), "other depth untouched")


func test_record_kill_is_idempotent() -> void:
	var blob := MineState.ensure_run({}, 1)
	blob = MineState.record_kill(blob, 2, 3)
	blob = MineState.record_kill(blob, 2, 3)
	assert_eq((blob["killed"]["2"] as Array).size(), 1)


func test_record_kill_does_not_mutate_input() -> void:
	var original := MineState.ensure_run({}, 1)
	MineState.record_kill(original, 2, 0)
	assert_false(MineState.is_killed(original, 2, 0),
		"record_kill returns a new blob; input stays pristine")


func test_survives_json_round_trip() -> void:
	var blob := MineState.record_kill(MineState.ensure_run({}, 5), 2, 3)
	blob = MineState.record_depth(blob, 2)
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(blob))
	assert_true(MineState.is_killed(round_tripped, 2, 3))
	var ensured := MineState.ensure_run(round_tripped, 5)
	assert_true(MineState.is_killed(ensured, 2, 3),
		"same-seed ensure after JSON round-trip must keep kills")
	var fresh := MineState.ensure_run(round_tripped, 999)
	assert_false(MineState.is_killed(fresh, 2, 3))


## ---- mix_seed determinism ----

func test_mix_seed_deterministic_for_same_inputs() -> void:
	assert_eq(MineState.mix_seed(10, 3), MineState.mix_seed(10, 3))


func test_mix_seed_differs_across_depth() -> void:
	assert_ne(MineState.mix_seed(10, 3), MineState.mix_seed(10, 4))


func test_mix_seed_differs_across_run_seed() -> void:
	assert_ne(MineState.mix_seed(10, 3), MineState.mix_seed(11, 3))


## ---- floor-type roll ----

func test_roll_floor_type_deterministic() -> void:
	var a := MineState.roll_floor_type(10, 3)
	var b := MineState.roll_floor_type(10, 3)
	assert_eq(a, b)


func test_roll_floor_type_distribution_covers_all_types() -> void:
	# Roll a wide spread of depths for a fixed run_seed and confirm every
	# FloorType shows up at least once — a crude but effective check that
	# the weighted table isn't secretly always-NORMAL or missing a branch.
	var seen := {}
	for depth in range(1, 200):
		seen[MineState.roll_floor_type(1234, depth)] = true
	assert_true(seen.has(MineState.FloorType.NORMAL))
	assert_true(seen.has(MineState.FloorType.MONSTER_DENSE))
	assert_true(seen.has(MineState.FloorType.TREASURE))
	assert_true(seen.has(MineState.FloorType.QUIET))


func test_roll_floor_type_names_are_set() -> void:
	for t in [MineState.FloorType.NORMAL, MineState.FloorType.MONSTER_DENSE,
			MineState.FloorType.TREASURE, MineState.FloorType.QUIET]:
		assert_ne(MineState.floor_type_name(t), "")


## ---- depth scaling ----

func test_enemy_density_increases_with_depth_and_caps() -> void:
	assert_eq(MineState.enemy_density_for(1, 4), 4)
	assert_eq(MineState.enemy_density_for(4, 4), 5)
	assert_eq(MineState.enemy_density_for(7, 4), 6)
	assert_eq(MineState.enemy_density_for(1000, 4), 10, "capped at base+6")


func test_loot_chance_bonus_increases_with_depth_and_caps() -> void:
	assert_eq(MineState.loot_chance_bonus(1), 0.0)
	assert_almost_eq(MineState.loot_chance_bonus(6), 0.1, 0.001)
	assert_eq(MineState.loot_chance_bonus(1000), 0.3, "capped at 0.3")
