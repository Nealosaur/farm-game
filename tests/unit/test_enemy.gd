extends GutTest

var enemy: Enemy


func _make_enemy(id: String, seed_value: int = 1) -> Enemy:
	var e: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = seed_value
	e.enemy_id = id
	add_child_autofree(e)
	return e


func test_setup_from_item_db_sets_hp_damage_from_data() -> void:
	enemy = _make_enemy("slime")
	var data := ItemDB.get_enemy("slime")
	assert_eq(enemy.health.max_hp, data.max_hp)
	assert_eq(enemy.health.hp, data.max_hp)
	assert_eq(enemy.hitbox.damage, data.damage)
	assert_not_null(enemy.sprite.sprite_frames)
	assert_true(enemy.sprite.sprite_frames.has_animation("idle"))


func test_setup_resolves_sprite_by_id_convention() -> void:
	enemy = _make_enemy("goblin")
	assert_not_null(enemy.sprite.sprite_frames)
	assert_true(enemy.data == ItemDB.get_enemy("goblin"))


func test_killing_enemy_emits_enemy_died_and_awards_gold_and_xp() -> void:
	enemy = _make_enemy("slime", 42)
	watch_signals(EventBus)
	var gold_before := GameState.gold
	var xp_before := GameState.xp
	enemy.health.take_damage(9999)
	assert_signal_emitted(EventBus, "enemy_died")
	var params = get_signal_parameters(EventBus, "enemy_died")
	assert_eq(params[0], enemy.data)

	var data := ItemDB.get_enemy("slime")
	var gold_gained: int = GameState.gold - gold_before
	assert_true(gold_gained >= data.gold_min and gold_gained <= data.gold_max,
		"gold gained %d should be within [%d, %d]" % [gold_gained, data.gold_min, data.gold_max])
	assert_eq(GameState.xp - xp_before, data.xp)


func test_death_transitions_to_dead_state_and_disables_hitbox() -> void:
	enemy = _make_enemy("slime")
	enemy.health.take_damage(9999)
	assert_eq(enemy.machine.current.name, "Dead")
	assert_eq(enemy.collision_layer, 0)


func test_death_emits_camera_shake() -> void:
	enemy = _make_enemy("slime")
	watch_signals(EventBus)
	enemy.health.take_damage(9999)
	assert_signal_emitted(EventBus, "camera_shake")


func test_hurtbox_hit_applies_damage_without_killing() -> void:
	enemy = _make_enemy("slime")
	var hp_before := enemy.health.hp
	enemy._on_hurtbox_hit_taken(3, Vector2(5, 0))
	assert_eq(enemy.health.hp, hp_before - 3)
	assert_eq(enemy.machine.current.name, "Hurt")


## ---- LOOK V2: real sheet-sliced idle/hurt/die animation ----

func test_wander_state_plays_idle_animation() -> void:
	enemy = _make_enemy("slime")
	assert_eq(enemy.machine.current.name, "Wander")
	assert_eq(enemy.sprite.animation, "idle")


func test_hurt_state_plays_hurt_animation() -> void:
	enemy = _make_enemy("slime")
	enemy._on_hurtbox_hit_taken(1, Vector2(5, 0))
	assert_eq(enemy.machine.current.name, "Hurt")
	assert_eq(enemy.sprite.animation, "hurt")


func test_dead_state_plays_die_animation() -> void:
	enemy = _make_enemy("slime")
	enemy.health.take_damage(9999)
	assert_eq(enemy.machine.current.name, "Dead")
	assert_eq(enemy.sprite.animation, "die")


func test_goblin_sheet_slices_correctly_at_its_own_frame_size() -> void:
	enemy = _make_enemy("goblin")
	assert_true(enemy.sprite.sprite_frames.has_animation("idle"))
	assert_eq(enemy.sprite.sprite_frames.get_frame_count("idle"), 2)


func test_enemy_has_ground_shadow_node() -> void:
	enemy = _make_enemy("slime")
	var shadow := enemy.get_node_or_null("GroundShadow")
	assert_not_null(shadow, "Enemy should have a GroundShadow child node")
	assert_true(shadow is Polygon2D)
