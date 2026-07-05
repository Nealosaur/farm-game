extends GutTest


func test_cell_of_maps_positions() -> void:
	assert_eq(MapBuilder.cell_of(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(MapBuilder.cell_of(Vector2(15.9, 15.9)), Vector2i(0, 0))
	assert_eq(MapBuilder.cell_of(Vector2(16, 16)), Vector2i(1, 1))
	assert_eq(MapBuilder.cell_of(Vector2(-0.1, 5)), Vector2i(-1, 0))


func test_facing_from_input_prefers_dominant_axis() -> void:
	assert_eq(Player.facing_from(Vector2(1, 0.2)), Vector2i.RIGHT)
	assert_eq(Player.facing_from(Vector2(-0.9, 0.3)), Vector2i.LEFT)
	assert_eq(Player.facing_from(Vector2(0.2, 1)), Vector2i.DOWN)
	assert_eq(Player.facing_from(Vector2(0.1, -0.8)), Vector2i.UP)


func test_facing_name() -> void:
	assert_eq(Player.facing_to_name(Vector2i.DOWN), "down")
	assert_eq(Player.facing_to_name(Vector2i.UP), "up")
	assert_eq(Player.facing_to_name(Vector2i.LEFT), "left")
	assert_eq(Player.facing_to_name(Vector2i.RIGHT), "right")


func test_player_scene_targets_cell_in_front() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.global_position = Vector2(40, 40)  # cell (2,2)
	player.facing = Vector2i.RIGHT
	assert_eq(player.target_cell(), Vector2i(3, 2))
	player.facing = Vector2i.UP
	assert_eq(player.target_cell(), Vector2i(2, 1))


func test_facing_indicator_repositions_to_the_facing_edge() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)

	player.update_facing(Vector2.DOWN)
	var down_pos: Vector2 = player._facing_indicator.position
	player.update_facing(Vector2.UP)
	var up_pos: Vector2 = player._facing_indicator.position
	player.update_facing(Vector2.LEFT)
	var left_pos: Vector2 = player._facing_indicator.position
	player.update_facing(Vector2.RIGHT)
	var right_pos: Vector2 = player._facing_indicator.position

	assert_true(down_pos.y > up_pos.y, "down-facing indicator should sit lower than up-facing")
	assert_true(right_pos.x > left_pos.x, "right-facing indicator should sit further right than left-facing")


func test_facing_indicator_defaults_to_down_on_ready() -> void:
	var player: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(player)
	assert_eq(player.facing, Vector2i.DOWN)
	assert_almost_eq(player._facing_indicator.position.y, Player.SPRITE_BOTTOM - Player.FACING_INDICATOR_INSET - Player.FACING_INDICATOR_SIZE.y / 2.0, 0.01)
