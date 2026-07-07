extends GutTest
## FEEL Stride 2: HitStop autoload — brief Engine.time_scale dip on a landed
## hit, always restored, never stuck. Restores real time_scale to 1.0 after
## every test regardless of what a test left it at, since Engine.time_scale
## is genuinely global (not reset between tests by GUT).
##
## The restore countdown is driven by HitStop's own _process (real engine
## frames, not wall-clock time — see hit_stop.gd's class doc for why), so
## tests drive it by calling _process() directly rather than awaiting time.


func after_each() -> void:
	Engine.time_scale = 1.0
	HitStop._active = false
	HitStop._frames_left = 0
	HitStop.set_process(false)


func test_trigger_dips_time_scale() -> void:
	HitStop.trigger(3, 0.02)
	assert_eq(Engine.time_scale, 0.02)
	assert_true(HitStop.is_active())


func test_time_scale_restores_after_frame_window() -> void:
	HitStop.trigger(3, 0.02)
	HitStop._process(0.016)
	HitStop._process(0.016)
	assert_eq(Engine.time_scale, 0.02, "still within the 3-frame window")
	HitStop._process(0.016)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(HitStop.is_active())


func test_retrigger_while_active_extends_window_and_still_restores() -> void:
	HitStop.trigger(3, 0.02)
	HitStop._process(0.016)
	HitStop.trigger(3, 0.02)  # re-arm partway through the first window
	HitStop._process(0.016)
	HitStop._process(0.016)
	assert_eq(Engine.time_scale, 0.02, "re-armed window should still be active")
	HitStop._process(0.016)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(HitStop.is_active())


func test_ready_defensively_resets_time_scale() -> void:
	Engine.time_scale = 0.3
	HitStop._ready()
	assert_eq(Engine.time_scale, 1.0)


func test_exit_tree_restores_time_scale() -> void:
	HitStop.trigger(100, 0.02)  # a long window that would still be active
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
