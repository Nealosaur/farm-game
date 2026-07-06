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


func test_player_died_emits_once_when_already_dead() -> void:
	watch_signals(EventBus)
	GameState.take_damage(GameState.max_hp)
	GameState.take_damage(10)
	assert_signal_emit_count(EventBus, "player_died", 1)


func test_try_spend_rp_fails_when_empty() -> void:
	GameState.rp = 0
	assert_false(GameState.try_spend_rp(10))
	assert_eq(GameState.hp, GameState.max_hp)


func test_try_spend_rp_shortfall_drains_hp() -> void:
	GameState.rp = 5
	assert_true(GameState.try_spend_rp(30))
	assert_eq(GameState.rp, 0)
	assert_eq(GameState.hp, GameState.max_hp - 25)


func test_multi_level_up_single_call() -> void:
	GameState.add_xp(70)
	assert_eq(GameState.level, 3)
	assert_eq(GameState.xp, 15)


func test_heal_clamps_to_max_hp() -> void:
	GameState.hp = 1
	GameState.heal(9999)
	assert_eq(GameState.hp, GameState.max_hp)


func test_restore_rp_clamps_to_max_rp() -> void:
	GameState.rp = 0
	GameState.restore_rp(9999)
	assert_eq(GameState.rp, GameState.max_rp)


func test_flags_are_copied_not_aliased() -> void:
	GameState.flags["met_mayor"] = true
	var d := GameState.to_dict()
	GameState.flags["extra"] = true
	assert_false(d["flags"].has("extra"))
	var src := {"flags": {"a": 1}}
	GameState.from_dict(src)
	src["flags"]["b"] = 2
	assert_false(GameState.flags.has("b"))


func test_sleep_restore_normal_vs_collapse() -> void:
	GameState.hp = 1
	GameState.rp = 0
	GameState.sleep_restore(false)
	assert_eq(GameState.hp, GameState.max_hp)
	assert_eq(GameState.rp, GameState.max_rp)
	GameState.rp = 0
	GameState.sleep_restore(true)
	assert_eq(GameState.rp, roundi(GameState.max_rp / 2.0))


# ---- Craft Stride 1: buff food ----

func test_effective_attack_with_no_buff_equals_base_attack() -> void:
	assert_eq(GameState.effective_attack(), GameState.attack)


func test_set_temp_attack_adds_to_effective_attack() -> void:
	GameState.set_temp_attack(2)
	assert_eq(GameState.temp_attack, 2)
	assert_eq(GameState.effective_attack(), GameState.attack + 2)


func test_set_temp_attack_replaces_not_stacks() -> void:
	GameState.set_temp_attack(2)
	GameState.set_temp_attack(5)
	assert_eq(GameState.temp_attack, 5, "second buff should REPLACE, not add to, the first")
	assert_eq(GameState.effective_attack(), GameState.attack + 5)


func test_clear_temp_attack_resets_to_zero() -> void:
	GameState.set_temp_attack(2)
	GameState.clear_temp_attack()
	assert_eq(GameState.temp_attack, 0)
	assert_eq(GameState.effective_attack(), GameState.attack)


func test_sleep_restore_clears_temp_attack_normal_sleep() -> void:
	GameState.set_temp_attack(2)
	GameState.sleep_restore(false)
	assert_eq(GameState.temp_attack, 0)


func test_sleep_restore_clears_temp_attack_on_collapse() -> void:
	GameState.set_temp_attack(2)
	GameState.sleep_restore(true)
	assert_eq(GameState.temp_attack, 0, "collapse must clear the buff same as normal sleep")


func test_reset_new_game_clears_temp_attack() -> void:
	GameState.set_temp_attack(2)
	GameState.reset_new_game()
	assert_eq(GameState.temp_attack, 0)


func test_set_temp_attack_emits_stats_changed() -> void:
	watch_signals(EventBus)
	GameState.set_temp_attack(2)
	assert_signal_emitted(EventBus, "stats_changed")
