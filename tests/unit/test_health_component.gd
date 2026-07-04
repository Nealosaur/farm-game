extends GutTest

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	health.max_hp = 20
	add_child_autofree(health)


func test_take_damage_clamps_at_zero() -> void:
	health.take_damage(999)
	assert_eq(health.hp, 0)


func test_heal_clamps_to_max_hp() -> void:
	health.hp = 5
	health.heal(999)
	assert_eq(health.hp, health.max_hp)


func test_died_emits_once_on_alive_to_dead_transition() -> void:
	watch_signals(health)
	health.take_damage(20)
	assert_signal_emitted(health, "died")
	assert_signal_emit_count(health, "died", 1)
	health.take_damage(5)
	assert_signal_emit_count(health, "died", 1)


func test_damaged_emits_before_died() -> void:
	watch_signals(health)
	health.take_damage(20)
	assert_signal_emitted(health, "damaged")
	assert_signal_emitted(health, "died")


func test_is_alive() -> void:
	assert_true(health.is_alive())
	health.take_damage(20)
	assert_false(health.is_alive())


func test_revive_then_die_re_emits_died() -> void:
	watch_signals(health)
	health.take_damage(20)
	assert_signal_emit_count(health, "died", 1)
	health.heal(20)
	assert_true(health.is_alive())
	health.take_damage(20)
	assert_signal_emit_count(health, "died", 2)


func test_take_damage_zero_or_negative_is_noop() -> void:
	watch_signals(health)
	health.take_damage(0)
	health.take_damage(-5)
	assert_eq(health.hp, health.max_hp)
	assert_signal_not_emitted(health, "damaged")
