extends GutTest
## Craft Stride 3 (Taming): Enemy.feed()/is_feedable() + the Passive FSM state
## — mirrors test_enemy.gd's own _make_enemy() helper/style.


func _make_enemy(id: String, seed_value: int = 1) -> Enemy:
	var e: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	e.rng = RandomNumberGenerator.new()
	e.rng.seed = seed_value
	e.enemy_id = id
	add_child_autofree(e)
	return e


func test_slime_data_is_tameable_with_turnip_favorite_food() -> void:
	var data := ItemDB.get_enemy("slime")
	assert_true(data.tameable)
	assert_eq(data.favorite_food, "turnip")


func test_slime_favorite_food_resolves_to_a_real_food_item() -> void:
	## Content-meta check: favorite_food must not be a dangling id — it has
	## to resolve to an actual FoodData the player can hold/select/feed.
	var data := ItemDB.get_enemy("slime")
	var food := ItemDB.get_item(data.favorite_food)
	assert_not_null(food, "slime's favorite_food '%s' must exist in ItemDB" % data.favorite_food)
	assert_true(food is FoodData, "slime's favorite_food must be a FoodData (edible/holdable)")


func test_wisp_goblin_and_boss_stay_untameable() -> void:
	assert_false(ItemDB.get_enemy("wisp").tameable)
	assert_false(ItemDB.get_enemy("goblin").tameable)
	assert_false(ItemDB.get_enemy("slime_king").tameable)


func test_is_feedable_true_for_live_untamed_tameable_enemy() -> void:
	var slime := _make_enemy("slime")
	assert_true(slime.is_feedable())


func test_is_feedable_false_for_untameable_enemy() -> void:
	var goblin := _make_enemy("goblin")
	assert_false(goblin.is_feedable())


func test_is_feedable_false_once_dead() -> void:
	var slime := _make_enemy("slime")
	slime.health.take_damage(9999)
	assert_false(slime.is_feedable())


func test_is_feedable_false_once_already_fed() -> void:
	var slime := _make_enemy("slime")
	slime.feed()
	assert_false(slime.is_feedable())


func test_feed_transitions_to_passive_state() -> void:
	var slime := _make_enemy("slime")
	slime.feed()
	assert_eq(slime.machine.current.name, "Passive")
	assert_true(slime.is_fed)


func test_feed_disables_contact_damage_hitbox() -> void:
	var slime := _make_enemy("slime")
	slime.hitbox.set_active(true)
	slime.feed()
	assert_false(slime.hitbox.monitoring)
	assert_false(slime.hitbox.monitorable)


func test_feed_on_untameable_enemy_is_a_no_op() -> void:
	var goblin := _make_enemy("goblin")
	goblin.feed()
	assert_ne(goblin.machine.current.name, "Passive")
	assert_false(goblin.is_fed)


func test_feed_twice_is_idempotent() -> void:
	var slime := _make_enemy("slime")
	slime.feed()
	slime.feed()  # must not error or re-enter Passive in a broken way
	assert_eq(slime.machine.current.name, "Passive")


func test_passive_slime_never_chases_regardless_of_player_distance() -> void:
	var slime := _make_enemy("slime")
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = slime.global_position  # touching distance
	slime.feed()
	simulate(slime, 3, 0.1)
	assert_eq(slime.machine.current.name, "Passive", "a fed slime must stay Passive, never re-aggro into Chase")


func test_passive_slime_still_killable_and_counts_as_a_kill() -> void:
	## Bible: "Fed slimes still count in the dungeon kill ledger if killed
	## (player's choice, no special casing)" — Hurtbox stays live in Passive,
	## so an ordinary hit still kills it exactly like any other enemy.
	var slime := _make_enemy("slime", 7)
	slime.feed()
	watch_signals(EventBus)
	slime.health.take_damage(9999)
	assert_signal_emitted(EventBus, "enemy_died")
	assert_eq(slime.machine.current.name, "Dead")


func test_passive_slime_hurtbox_still_monitoring() -> void:
	var slime := _make_enemy("slime")
	slime.feed()
	assert_true(slime.hurtbox.monitoring)
	assert_true(slime.hurtbox.monitorable)
