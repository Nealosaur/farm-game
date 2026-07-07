extends GutTest
## FEEL Stride 2: HitStop autoload — brief Engine.time_scale dip on a landed
## hit, always restored, never stuck. Restores real time_scale to 1.0 after
## every test regardless of what a test left it at, since Engine.time_scale
## is genuinely global (not reset between tests by GUT).


func after_each() -> void:
	Engine.time_scale = 1.0
	HitStop._active = false
	HitStop._token += 1  # invalidate any in-flight real-time restore timer from this test


func test_trigger_dips_time_scale() -> void:
	HitStop.trigger(0.05, 0.02)
	assert_eq(Engine.time_scale, 0.02)
	assert_true(HitStop.is_active())


func test_time_scale_restores_after_window() -> void:
	HitStop.trigger(0.05, 0.02)
	await wait_seconds(0.08)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(HitStop.is_active())


func test_retrigger_while_active_extends_window_and_still_restores() -> void:
	HitStop.trigger(0.05, 0.02)
	await wait_seconds(0.02)
	HitStop.trigger(0.05, 0.02)  # re-arm partway through the first window
	assert_eq(Engine.time_scale, 0.02)
	await wait_seconds(0.08)
	assert_eq(Engine.time_scale, 1.0, )
	assert_false(HitStop.is_active())


func test_ready_defensively_resets_time_scale() -> void:
	Engine.time_scale = 0.3
	HitStop._ready()
	assert_eq(Engine.time_scale, 1.0)


func test_exit_tree_restores_time_scale() -> void:
	HitStop.trigger(5.0, 0.02)  # a long window that would still be active
	HitStop._exit_tree()
	assert_eq(Engine.time_scale, 1.0)


## ---- wired hooks: enemy hurtbox (landed player sword hit) ----

func test_enemy_hit_taken_triggers_hit_stop() -> void:
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	enemy._on_hurtbox_hit_taken(1, Vector2(5, 0))
	assert_true(HitStop.is_active())


## ---- wired hooks: player hurtbox (boss slam only, not ordinary contact) ----

func test_player_heavy_hit_triggers_hit_stop() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player._on_hurtbox_hit_taken(5, Vector2(10, 0), true)
	assert_true(HitStop.is_active())


func test_player_ordinary_hit_does_not_trigger_hit_stop() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player._on_hurtbox_hit_taken(5, Vector2(10, 0))  # is_heavy defaults false
	assert_false(HitStop.is_active())


func test_boss_slam_hitbox_is_marked_heavy() -> void:
	var boss: SlimeKing = (load("res://scenes/enemies/slime_king.tscn") as PackedScene).instantiate()
	boss.enemy_id = "slime_king"
	add_child_autofree(boss)
	var slam := boss.machine.get_node("Slam") as BossSlam
	boss.machine.transition("Slam")
	slam.physics_update(BossSlam.TELEGRAPH_DURATION + 0.01)
	assert_true(slam._slam_hitbox.is_heavy)
