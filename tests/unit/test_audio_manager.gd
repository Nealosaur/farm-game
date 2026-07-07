extends GutTest
## FEEL Stride 5: AudioManager autoload — resolves every wired SFX id to a
## real stream, play() round-robins the pooled AudioStreamPlayers without
## crashing on an unknown id, and the gameplay event hooks actually call it.


func test_every_wired_sfx_id_resolves_to_a_stream() -> void:
	for id in AudioManager.SFX_IDS:
		assert_not_null(AudioManager.resolve(id), "missing stream for id '%s'" % id)


func test_unknown_id_resolves_to_null() -> void:
	assert_null(AudioManager.resolve("not_a_real_sfx_id"))


func test_play_unknown_id_does_not_crash() -> void:
	for p in AudioManager._players:
		p.stop()
	AudioManager.play("not_a_real_sfx_id")  # should push_warning, not error/crash
	assert_false(_any_pooled_player_playing(), "an unknown id must not start any pooled player")


func test_play_known_id_starts_a_pooled_player() -> void:
	AudioManager.play("footstep")
	var any_playing := false
	for p in AudioManager._players:
		if p.playing:
			any_playing = true
			break
	assert_true(any_playing, "play() should start one of the pooled AudioStreamPlayers")


func test_play_round_robins_across_pool() -> void:
	var seen := {}
	for i in AudioManager.POOL_SIZE:
		AudioManager.play("footstep")
		seen[AudioManager._next_player] = true
	# After POOL_SIZE plays the round-robin index should have cycled through
	# more than a single player (not stuck reusing index 0 every time).
	assert_true(seen.size() > 1 or AudioManager.POOL_SIZE == 1)


func test_master_volume_is_modest() -> void:
	for p in AudioManager._players:
		assert_true(p.volume_db <= 0.0, "SFX pool should not be boosted above unity gain")


## ---- gameplay hooks ----

func test_footstep_cadence_plays_sound() -> void:
	GameState.reset_new_game()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	AudioManager.play("footstep")  # warm a player so `playing` toggles are observable
	for p in AudioManager._players:
		p.stop()
	Input.action_press("move_right")
	player.machine.transition("Move")
	var move = player.machine.current
	for i in 60:
		move.physics_update(0.016)
	Input.action_release("move_right")
	var any_playing := false
	for p in AudioManager._players:
		if p.playing:
			any_playing = true
	assert_true(any_playing, "sustained movement should have played at least one footstep")


func test_till_water_plant_harvest_play_sfx() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	Clock.paused = true
	Clock.day = 10
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(200, 200)
	player.facing = Vector2i.DOWN
	var grid := FarmGrid.new()
	grid.tillable = Rect2i(-100, -100, 200, 200)
	add_child_autofree(grid)

	for p in AudioManager._players:
		p.stop()
	Inventory.add_item("hoe")
	_select(player, "hoe")
	player.try_use_selected()
	assert_true(_any_pooled_player_playing(), "till should play a sound")

	for p in AudioManager._players:
		p.stop()
	Inventory.add_item("watering_can")
	_select(player, "watering_can")
	player.try_use_selected()
	assert_true(_any_pooled_player_playing(), "watering should play a sound")

	for p in AudioManager._players:
		p.stop()
	Inventory.add_item("turnip_seeds")
	_select(player, "turnip_seeds")
	player.try_use_selected()
	assert_true(_any_pooled_player_playing(), "planting should play a sound")

	for p in AudioManager._players:
		p.stop()
	var cell := player.target_cell()
	var crop := ItemDB.get_crop("turnip")
	grid.plots[cell]["stage"] = crop.stage_days.size()
	player.try_interact()
	assert_true(_any_pooled_player_playing(), "harvest should play a sound")


func test_swing_and_landed_hit_and_death_play_sfx() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.facing = Vector2i.RIGHT
	Inventory.add_item("wooden_sword")
	_select(player, "wooden_sword")

	for p in AudioManager._players:
		p.stop()
	player.try_use_selected()
	assert_true(_any_pooled_player_playing(), "swing should play a sound")

	var enemy: Enemy = (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate()
	enemy.enemy_id = "slime"
	add_child_autofree(enemy)
	for p in AudioManager._players:
		p.stop()
	enemy._on_hurtbox_hit_taken(1, Vector2(5, 0))
	assert_true(_any_pooled_player_playing(), "a landed hit should play a sound")

	for p in AudioManager._players:
		p.stop()
	enemy.health.take_damage(9999)
	assert_true(_any_pooled_player_playing(), "enemy death should play a sound")


func test_level_up_plays_sfx() -> void:
	GameState.reset_new_game()
	for p in AudioManager._players:
		p.stop()
	GameState.add_xp(GameState.xp_to_next())
	assert_true(_any_pooled_player_playing(), "leveling up should play a sound")


func test_bond_gain_plays_sfx_but_bond_loss_does_not() -> void:
	for p in AudioManager._players:
		p.stop()
	Relationships._add_points("marta", 15)
	assert_true(_any_pooled_player_playing(), "a bond GAIN should play the bond-up chime")

	for p in AudioManager._players:
		p.stop()
	Relationships._add_points("marta", -20)
	assert_false(_any_pooled_player_playing(), "a bond LOSS should stay silent")


func _any_pooled_player_playing() -> bool:
	for p in AudioManager._players:
		if p.playing:
			return true
	return false


func _select(player: Player, id: String) -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s != null and s.id == id:
			Inventory.select_hotbar(i)
			return
	fail_test("item not on hotbar: " + id)
