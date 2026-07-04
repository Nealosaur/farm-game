extends GutTest


func before_each() -> void:
	GameState.reset_new_game()


func test_new_game_defaults() -> void:
	assert_eq(GameState.gold, 500)
	assert_eq(GameState.level, 1)
	assert_eq(GameState.hp, GameState.max_hp)
	assert_eq(GameState.rp, GameState.max_rp)


func test_spend_rp_normal() -> void:
	GameState.spend_rp(30)
	assert_eq(GameState.rp, GameState.max_rp - 30)
	assert_eq(GameState.hp, GameState.max_hp)


func test_spend_rp_drains_hp_when_short() -> void:
	GameState.rp = 10
	GameState.spend_rp(30)
	assert_eq(GameState.rp, 0)
	assert_eq(GameState.hp, GameState.max_hp - 20)


func test_level_up_applies_bonuses() -> void:
	var old_max_hp := GameState.max_hp
	GameState.add_xp(GameState.xp_to_next() + 5)
	assert_eq(GameState.level, 2)
	assert_eq(GameState.xp, 5)
	assert_eq(GameState.max_hp, old_max_hp + GameState.HP_PER_LEVEL)
	assert_eq(GameState.attack, GameState.BASE_ATTACK + GameState.ATTACK_PER_LEVEL)


func test_try_spend_gold() -> void:
	assert_true(GameState.try_spend_gold(200))
	assert_eq(GameState.gold, 300)
	assert_false(GameState.try_spend_gold(9999))
	assert_eq(GameState.gold, 300)


func test_player_died_signal_at_zero_hp() -> void:
	watch_signals(EventBus)
	GameState.take_damage(GameState.max_hp)
	assert_eq(GameState.hp, 0)
	assert_signal_emitted(EventBus, "player_died")


func test_sleep_restore_normal_vs_collapse() -> void:
	GameState.hp = 1
	GameState.rp = 0
	GameState.sleep_restore(false)
	assert_eq(GameState.hp, GameState.max_hp)
	assert_eq(GameState.rp, GameState.max_rp)
	GameState.rp = 0
	GameState.sleep_restore(true)
	assert_eq(GameState.rp, roundi(GameState.max_rp / 2.0))
