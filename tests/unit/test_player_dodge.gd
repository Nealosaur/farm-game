extends GutTest

var player: Player


func before_each() -> void:
	GameState.reset_new_game()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)


func test_dodge_spends_rp_and_transitions() -> void:
	var rp_before := GameState.rp
	player.try_dodge()
	assert_eq(GameState.rp, rp_before - PlayerDodge.RP_COST)
	assert_eq(player.machine.current.name, "Dodge")


func test_dodge_fails_silently_when_rp_is_zero() -> void:
	GameState.rp = 0
	player.try_dodge()
	assert_eq(GameState.rp, 0)
	assert_eq(player.machine.current.name, "Idle")


func test_dodge_triggers_hurtbox_iframes() -> void:
	player.try_dodge()
	assert_true(player.hurtbox.is_invincible())


func test_dodge_uses_facing_when_stationary() -> void:
	player.facing = Vector2i.UP
	player.try_dodge()
	var dodge := player.machine.get_node("Dodge") as PlayerDodge
	assert_eq(dodge._dir, Vector2(Vector2i.UP))


func test_dodge_shortfall_still_drains_hp_but_allows_dodge() -> void:
	GameState.rp = 1
	player.try_dodge()
	assert_eq(GameState.rp, 0)
	assert_eq(GameState.hp, GameState.max_hp - (PlayerDodge.RP_COST - 1))
	assert_eq(player.machine.current.name, "Dodge")
