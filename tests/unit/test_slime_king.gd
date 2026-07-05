extends GutTest
## Boss setup, threshold summons, phase change, and permanent-death-flag
## behavior for SlimeKing (dungeon_3 boss). Uses direct HealthComponent
## damage (not hurtbox overlap) to drive thresholds deterministically, same
## pattern as test_health_component.gd.

var boss: SlimeKing


func before_each() -> void:
	GameState.flags = {}
	boss = (load("res://scenes/enemies/slime_king.tscn") as PackedScene).instantiate()
	boss.enemy_id = "slime_king"
	add_child_autofree(boss)


func _dmg_to_fraction(frac: float) -> int:
	## Damage needed to bring the boss from its CURRENT hp down to frac*max_hp.
	var target_hp := int(boss.health.max_hp * frac)
	return boss.health.hp - target_hp


func test_setup_from_item_db_sets_hp_from_data() -> void:
	var data := ItemDB.get_enemy("slime_king")
	assert_eq(boss.health.max_hp, data.max_hp)
	assert_eq(boss.health.hp, data.max_hp)
	assert_eq(boss.data, data)


func test_boss_is_not_registered_in_dungeon_state_ledger() -> void:
	## The boss has no spawn_index / DungeonFloor kill-ledger binding at all —
	## SlimeKing.spawn_boss() (used by dungeon_3) never calls
	## health.died.connect(_on_floor_enemy_died...) the way DungeonFloor's own
	## ENEMY_SPAWNS loop does. Confirm the ledger tolerates a ledger-less kill:
	## recording nothing for this boss must not raise or corrupt the blob.
	var blob := DungeonState.ensure_day({}, 1)
	assert_false(DungeonState.is_killed(blob, "dungeon_3", 0),
		"boss death must never be represented as a dungeon_3 spawn_index kill")
	boss.health.take_damage(9999)
	# Still nothing recorded under any floor key for this boss.
	assert_eq((blob.get("killed", {}) as Dictionary).size(), 0)


func test_summon_triggers_once_at_66_percent() -> void:
	watch_signals(boss)
	boss.health.take_damage(_dmg_to_fraction(0.65))
	assert_signal_emit_count(boss, "summon_triggered", 1)
	assert_eq(boss.summon_count, 1)


func test_summon_triggers_second_time_at_33_percent() -> void:
	watch_signals(boss)
	boss.health.take_damage(_dmg_to_fraction(0.65))
	boss.health.take_damage(_dmg_to_fraction(0.32))
	assert_signal_emit_count(boss, "summon_triggered", 2)
	assert_eq(boss.summon_count, 2)


func test_summon_never_triggers_a_third_time() -> void:
	watch_signals(boss)
	boss.health.take_damage(_dmg_to_fraction(0.65))
	boss.health.take_damage(_dmg_to_fraction(0.32))
	# Drive further down (but not to 0) — no third summon should fire.
	boss.health.take_damage(boss.health.hp - 1)
	assert_signal_emit_count(boss, "summon_triggered", 2)
	assert_eq(boss.summon_count, 2)


func test_phase_change_at_33_percent_speeds_up_and_shortens_slam_cooldown() -> void:
	assert_false(boss.phase2)
	assert_eq(boss.slam_cooldown, SlimeKing.SLAM_COOLDOWN_NORMAL)
	assert_eq(boss.speed_mult, 1.0)

	boss.health.take_damage(_dmg_to_fraction(0.32))

	assert_true(boss.phase2)
	assert_eq(boss.slam_cooldown, SlimeKing.SLAM_COOLDOWN_PHASE2)
	assert_almost_eq(boss.speed_mult, SlimeKing.PHASE2_SPEED_MULT, 0.001)


func test_phase_change_does_not_fire_before_33_percent() -> void:
	boss.health.take_damage(_dmg_to_fraction(0.40))
	assert_false(boss.phase2)
	assert_eq(boss.slam_cooldown, SlimeKing.SLAM_COOLDOWN_NORMAL)


func test_phase_change_only_fires_once() -> void:
	watch_signals(boss)
	boss.health.take_damage(_dmg_to_fraction(0.32))
	assert_signal_emit_count(boss, "phase_changed", 1)
	boss.health.take_damage(boss.health.hp - 1)
	assert_signal_emit_count(boss, "phase_changed", 1)


func test_death_sets_boss_defeated_flag_and_emits_signal_once() -> void:
	watch_signals(EventBus)
	assert_false(GameState.flags.get("boss_defeated", false))
	boss.health.take_damage(9999)
	assert_true(GameState.flags.get("boss_defeated", false))
	assert_signal_emit_count(EventBus, "boss_defeated", 1)
	assert_signal_emitted(EventBus, "enemy_died")


func test_death_transitions_to_dead_state() -> void:
	boss.health.take_damage(9999)
	assert_eq(boss.machine.current.name, "Dead")


func test_death_grants_guaranteed_slime_gel_x3() -> void:
	## 2 land straight in inventory (SlimeKing._on_died); the 3rd is the
	## normal Dead-state world Pickup (drop_chance 1.0 in slime_king.tres),
	## which is guaranteed to spawn but requires walking over it — count both
	## so the assertion reflects the true guaranteed total of 3. The boss is
	## reparented under a scratch container first so the Pickup spawned by
	## Dead.enter() (a child of enemy.get_parent()) can be counted without
	## picking up Pickups left behind by other tests in this same script.
	Inventory.reset()
	var scratch := Node.new()
	add_child_autofree(scratch)
	boss.get_parent().remove_child(boss)
	scratch.add_child(boss)

	boss.health.take_damage(9999)
	await wait_physics_frames(2)  # Dead.enter()'s add_child.call_deferred for the pickup

	var pickup_count := 0
	for child in scratch.get_children():
		if child is Pickup and (child as Pickup).item_id == "slime_gel":
			pickup_count += 1
	assert_eq(Inventory.count_of("slime_gel") + pickup_count, 3)


func test_reload_after_flag_set_spawns_no_boss() -> void:
	## dungeon_3._ready() only calls SlimeKing.spawn_boss() when the flag is
	## unset; simulate the flag already being latched from a prior kill and
	## confirm a fresh floor load has no boss node under World.
	GameState.flags["boss_defeated"] = true
	SaveManager.save_path = "user://test_boss_reload.json"
	Clock.paused = true
	SceneChanger.spawn_name = "entrance"

	var floor: Node2D = (load("res://scenes/maps/dungeon_3.tscn") as PackedScene).instantiate()
	add_child_autofree(floor)
	await wait_process_frames(2)

	var world := floor.get_node("World")
	var found_boss := false
	for child in world.get_children():
		if child is SlimeKing:
			found_boss = true
	assert_false(found_boss, "boss must not respawn once boss_defeated flag is set")

	SceneChanger.spawn_name = "default"
	GameState.flags.erase("boss_defeated")
