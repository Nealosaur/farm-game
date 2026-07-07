extends GutTest
## Integration coverage for dungeon_3's boss-stride wiring: conditional spawn,
## boss health bar tracking, arena gate seal/unseal, and the victory sequence.
## Same headless-integration tradeoffs as test_dungeon_integration.gd (actual
## portal travel isn't exercised here) — this covers the boss-specific wiring
## dungeon_3._ready() adds on top of the base DungeonFloor flow.

const FLOOR_SCENE := "res://scenes/maps/dungeon_3.tscn"


func before_each() -> void:
	Clock.paused = true
	GameState.flags = {}
	SaveManager.save_path = "user://test_dungeon_3_boss.json"
	SaveManager.new_game()
	SceneChanger.spawn_name = "entrance"


func after_each() -> void:
	SceneChanger.spawn_name = "default"
	SaveManager.save_path = "user://save1.json"
	GameState.flags = {}
	Clock.paused = false
	if FileAccess.file_exists("user://test_dungeon_3_boss.json"):
		DirAccess.remove_absolute("user://test_dungeon_3_boss.json")


func _make_floor() -> Node2D:
	return (load(FLOOR_SCENE) as PackedScene).instantiate()


func _find_boss(floor_node: Node) -> SlimeKing:
	for child in floor_node.get_node("World").get_children():
		if child is SlimeKing:
			return child
	return null


func test_boss_spawns_when_flag_unset() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(1)
	var boss := _find_boss(f)
	assert_not_null(boss, "boss must spawn at BOSS_CELL when boss_defeated flag is unset")
	# The boss is already Pursue-chasing the player by the time this checks
	# (unlike regular enemies, it has no idle Wander state) — a distance
	# threshold, not an exact position match, confirms it spawned at the cell.
	var dist := boss.global_position.distance_to(MapBuilder.cell_center(f.BOSS_CELL))
	assert_lt(dist, 16.0, "boss should spawn at/near BOSS_CELL before it starts pursuing")


func test_boss_does_not_spawn_when_flag_set() -> void:
	GameState.flags["boss_defeated"] = true
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_null(_find_boss(f), "boss must not respawn once defeated")
	assert_null(f.get_node_or_null("World/ArenaGate"),
		"a beaten arena must never re-seal (post-victory softlock regression)")


func test_boss_health_bar_tracks_boss_and_hides_on_death() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var boss := _find_boss(f)
	assert_not_null(boss)
	assert_true(f._health_bar.visible)
	assert_almost_eq(f._health_bar.bar.max_value, float(boss.health.max_hp), 0.01)

	boss.health.take_damage(50)
	assert_almost_eq(f._health_bar.bar.value, float(boss.health.hp), 0.01)

	boss.health.take_damage(9999)
	assert_false(f._health_bar.visible, "health bar hides once the boss dies")
	# Let Dead.enter()'s add_child.call_deferred land under World (a child of
	# f) BEFORE f is autofreed at test end, so the dropped Pickup is freed
	# with the floor instead of becoming an orphan.
	await wait_physics_frames(1)


func test_arena_gate_seals_when_player_crosses_trigger_and_unseals_on_boss_death() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var boss := _find_boss(f)
	assert_not_null(boss)
	assert_false(f._arena_gate.seal_state.sealed)

	f._arena_gate._on_body_entered(_find_player(f))
	assert_true(f._arena_gate.seal_state.sealed, "crossing the arena trigger seals the gate")

	boss.health.take_damage(9999)
	assert_false(f._arena_gate.seal_state.sealed, "boss death unseals the gate")
	# See test_boss_health_bar_tracks_boss_and_hides_on_death for why this wait
	# matters: lets the dropped Pickup land under World before f autofrees.
	await wait_physics_frames(1)


func test_arena_gate_unseals_on_player_collapse() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	f._arena_gate._on_body_entered(_find_player(f))
	assert_true(f._arena_gate.seal_state.sealed)

	EventBus.player_died.emit()
	assert_false(f._arena_gate.seal_state.sealed, "player collapse unseals the gate")


func test_victory_sequence_pauses_clock_and_toasts_on_boss_defeated() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var boss := _find_boss(f)
	assert_not_null(boss)

	watch_signals(EventBus)
	Clock.paused = false
	boss.health.take_damage(9999)
	await wait_process_frames(1)

	assert_true(Clock.paused, "victory sequence freezes the clock immediately on boss_defeated")
	assert_signal_emitted(EventBus, "boss_defeated")
	var toast_count: int = get_signal_emit_count(EventBus, "toast_requested")
	assert_gt(toast_count, 0, "victory sequence queues at least one toast")

	# Let the freeze window elapse so Clock.paused is released and the test
	# doesn't leak a paused Clock into later tests. Sequence total is
	# ~0.05s (toast gap) + 0.4s (flash in/out) + 1.5s (FREEZE_DURATION);
	# pad generously since this is real wall-clock time under wait_seconds.
	await wait_seconds(2.5)
	assert_false(Clock.paused, "clock resumes after the freeze window")


func _find_player(floor_node: Node) -> Player:
	for child in floor_node.get_node("World").get_children():
		if child is Player:
			return child
	return null


## ---- DEPTH stride: deep-delve mine entrance gate ----

func test_mine_entrance_absent_while_boss_alive() -> void:
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	assert_null(f.get_node_or_null("World/MineEntrancePortal"),
		"the deep-delve ladder must not appear until the boss is beaten")


func test_mine_entrance_appears_once_boss_defeated() -> void:
	GameState.flags["boss_defeated"] = true
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var portal := f.get_node_or_null("World/MineEntrancePortal") as Portal
	assert_not_null(portal)
	assert_eq(portal.target_scene, "res://scenes/maps/mine_floor.tscn")
	assert_eq(portal.target_spawn, "entrance")
	assert_true(portal.pre_travel.is_valid())


func test_mine_entrance_starts_a_fresh_dive_each_entry() -> void:
	GameState.flags["boss_defeated"] = true
	SaveManager.world["mine"] = {"run_seed": 123, "depth": 5, "deepest": 5, "killed": {"5": [0]}}
	var f := _make_floor()
	add_child_autofree(f)
	await wait_process_frames(2)
	var portal := f.get_node_or_null("World/MineEntrancePortal") as Portal
	portal.pre_travel.call()
	var blob: Dictionary = SaveManager.world["mine"]
	assert_ne(int(blob["run_seed"]), 123, "each entry from Floor 3 rolls a NEW run_seed")
	assert_eq(int(blob["depth"]), MineState.ENTRY_DEPTH, "a fresh dive starts at depth 1")
	assert_eq(int(blob["deepest"]), 5, "deepest is a permanent record, unaffected by a fresh dive")
