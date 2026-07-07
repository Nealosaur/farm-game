extends GutTest
## FEEL Stride 4: screen shake retune — verifies each of the four wired
## events emits camera_shake with the CORRECT RELATIVE MAGNITUDE (tiny <
## small < medium), not just that a shake fires at all (test_boss_slam.gd /
## test_enemy.gd / test_player_combat.gd already cover the "fires" half).


func test_magnitude_ordering_is_tiny_lt_small_lt_medium() -> void:
	assert_true(CameraShake.TINY_STRENGTH < CameraShake.SMALL_STRENGTH)
	assert_true(CameraShake.SMALL_STRENGTH < CameraShake.MEDIUM_STRENGTH)


func test_landed_sword_hit_emits_tiny_shake() -> void:
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	watch_signals(EventBus)
	enemy._on_hurtbox_hit_taken(1, Vector2(5, 0))
	var params = get_signal_parameters(EventBus, "camera_shake")
	assert_eq(params[0], CameraShake.TINY_STRENGTH)


func test_enemy_death_emits_tiny_shake() -> void:
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	watch_signals(EventBus)
	enemy.health.take_damage(9999)
	var params = get_signal_parameters(EventBus, "camera_shake")
	assert_eq(params[0], CameraShake.TINY_STRENGTH)


func test_player_ordinary_damage_emits_small_shake() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	watch_signals(EventBus)
	player._on_hurtbox_hit_taken(5, Vector2(10, 0))  # is_heavy defaults false
	var params = get_signal_parameters(EventBus, "camera_shake")
	assert_eq(params[0], CameraShake.SMALL_STRENGTH)


func test_player_heavy_hit_emits_medium_shake() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	watch_signals(EventBus)
	player._on_hurtbox_hit_taken(5, Vector2(10, 0), true)
	var params = get_signal_parameters(EventBus, "camera_shake")
	assert_eq(params[0], CameraShake.MEDIUM_STRENGTH)


func test_boss_slam_landing_emits_medium_shake() -> void:
	var boss: SlimeKing = (load("res://scenes/enemies/slime_king.tscn") as PackedScene).instantiate()
	boss.enemy_id = "slime_king"
	add_child_autofree(boss)
	var slam := boss.machine.get_node("Slam") as BossSlam
	boss.machine.transition("Slam")
	watch_signals(EventBus)
	slam.physics_update(BossSlam.TELEGRAPH_DURATION + 0.01)
	var params = get_signal_parameters(EventBus, "camera_shake")
	assert_eq(params[0], CameraShake.MEDIUM_STRENGTH)
