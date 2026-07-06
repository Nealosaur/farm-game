extends GutTest

var player: Player


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.RIGHT
	Inventory.add_item("wooden_sword")
	_select("wooden_sword")


func _select(id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)


func _make_dummy_enemy(pos: Vector2) -> Enemy:
	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	enemy.global_position = pos
	return enemy


func test_swing_spends_rp_and_transitions_to_swing_state() -> void:
	var rp_before := GameState.rp
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	player.try_use_selected()
	assert_eq(GameState.rp, rp_before - tool_data.rp_cost)
	assert_eq(player.machine.current.name, "Swing")


func test_swing_hitbox_deals_attack_plus_tool_damage_to_enemy_in_range() -> void:
	var enemy := _make_dummy_enemy(player.global_position + Vector2(14, 0))
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	var expected_damage: int = GameState.attack + tool_data.damage

	player.try_use_selected()
	await wait_physics_frames(6)  # set_deferred + physics overlap detection needs a few frames

	assert_eq(enemy.health.hp, enemy.health.max_hp - expected_damage)


func test_swing_hitbox_does_not_hit_enemy_out_of_range() -> void:
	var enemy := _make_dummy_enemy(player.global_position + Vector2(200, 0))
	player.try_use_selected()
	await wait_physics_frames(3)
	assert_eq(enemy.health.hp, enemy.health.max_hp)


func test_combo_buffer_chains_up_to_three_swings() -> void:
	var swing := player.machine.get_node("Swing") as PlayerSwing
	player.try_use_selected()
	assert_eq(swing._chain, 1)
	player.try_use_selected()  # buffered while still swinging
	assert_true(swing._buffered)


func test_taking_damage_emits_camera_shake() -> void:
	watch_signals(EventBus)
	player._on_hurtbox_hit_taken(5, Vector2(10, 0))
	assert_signal_emitted(EventBus, "camera_shake")


func test_third_swing_gets_boosted_knockback() -> void:
	var swing := player.machine.get_node("Swing") as PlayerSwing
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	swing.begin_swing(tool_data)  # 1
	swing.begin_swing(tool_data)  # 2
	swing.begin_swing(tool_data)  # 3
	assert_eq(swing._chain, 3)
	assert_almost_eq(swing._pending_knockback, player.sword_hitbox.knockback_force * 1.5, 0.01)


# ---- Craft Stride 1: buff food in the real swing damage path ----

func test_swing_damage_includes_temp_attack_buff() -> void:
	GameState.set_temp_attack(2)
	var enemy := _make_dummy_enemy(player.global_position + Vector2(14, 0))
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	var expected_damage: int = GameState.attack + 2 + tool_data.damage

	player.try_use_selected()
	await wait_physics_frames(6)

	assert_eq(enemy.health.hp, enemy.health.max_hp - expected_damage)


func test_swing_damage_matches_effective_attack_accessor() -> void:
	GameState.set_temp_attack(2)
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	var swing := player.machine.get_node("Swing") as PlayerSwing
	swing.begin_swing(tool_data)
	assert_eq(swing._pending_damage, GameState.effective_attack() + tool_data.damage)


func test_swing_damage_without_buff_unaffected() -> void:
	assert_eq(GameState.temp_attack, 0)
	var tool_data: ToolData = ItemDB.get_item("wooden_sword")
	var swing := player.machine.get_node("Swing") as PlayerSwing
	swing.begin_swing(tool_data)
	assert_eq(swing._pending_damage, GameState.attack + tool_data.damage)
