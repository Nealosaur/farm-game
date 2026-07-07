extends GutTest
## FEEL Stride 1: acceleration/friction ramp math (Player.approach_velocity)
## and the PlayerMove state's use of it. Pure-math cases don't need a live
## scene tree; the state-machine cases instantiate the real player scene like
## test_player_dodge.gd/test_player_combat.gd do.

var player: Player


func before_each() -> void:
	GameState.reset_new_game()
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)


## ---- pure ramp math ----

func test_approach_velocity_ramps_up_toward_target_not_instant() -> void:
	var v := Player.approach_velocity(Vector2.ZERO, Vector2(Player.SPEED, 0), Player.ACCEL, Player.FRICTION, 0.016)
	assert_true(v.x > 0.0, "should have moved toward target")
	assert_true(v.x < Player.SPEED, "should NOT reach top speed in a single 16ms frame")


func test_approach_velocity_reaches_top_speed_given_enough_time() -> void:
	var v := Vector2.ZERO
	var target := Vector2(Player.SPEED, 0)
	for i in 300:
		v = Player.approach_velocity(v, target, Player.ACCEL, Player.FRICTION, 0.016)
	assert_almost_eq(v.x, Player.SPEED, 0.01)


func test_approach_velocity_never_overshoots_target_speed() -> void:
	var v := Vector2.ZERO
	var target := Vector2(Player.SPEED, 0)
	for i in 300:
		v = Player.approach_velocity(v, target, Player.ACCEL, Player.FRICTION, 0.016)
		assert_true(v.length() <= Player.SPEED + 0.001, "velocity must never exceed SPEED")


func test_approach_velocity_decelerates_to_zero_on_release() -> void:
	var v := Vector2(Player.SPEED, 0)
	for i in 300:
		v = Player.approach_velocity(v, Vector2.ZERO, Player.ACCEL, Player.FRICTION, 0.016)
	assert_almost_eq(v.x, 0.0, 0.01)


func test_approach_velocity_decel_never_overshoots_past_zero() -> void:
	var v := Vector2(Player.SPEED, 0)
	for i in 300:
		v = Player.approach_velocity(v, Vector2.ZERO, Player.ACCEL, Player.FRICTION, 0.016)
		assert_true(v.length() >= -0.001, "deceleration must never flip sign / overshoot past zero")


func test_approach_velocity_large_delta_clamps_exactly_to_target() -> void:
	# A pathological huge delta (e.g. a hitch) must still land exactly ON the
	# target, never past it — move_toward's own clamp guarantees this.
	var v := Player.approach_velocity(Vector2.ZERO, Vector2(Player.SPEED, 0), Player.ACCEL, Player.FRICTION, 10.0)
	assert_eq(v, Vector2(Player.SPEED, 0))


## ---- PlayerMove state integration ----

func test_move_state_ramps_velocity_not_instant_snap() -> void:
	Input.action_press("move_right")
	player.machine.transition("Move")
	player.machine.current.physics_update(0.016)
	assert_true(player.velocity.length() < Player.SPEED, "one physics frame should not reach top speed")
	Input.action_release("move_right")


func test_move_state_reaches_top_speed_after_sustained_input() -> void:
	Input.action_press("move_right")
	player.machine.transition("Move")
	for i in 300:
		player.machine.current.physics_update(0.016)
	assert_almost_eq(player.velocity.x, Player.SPEED, 0.5)
	Input.action_release("move_right")


func test_move_state_decelerates_then_hands_off_to_idle_on_release() -> void:
	Input.action_press("move_right")
	player.machine.transition("Move")
	for i in 10:
		player.machine.current.physics_update(0.016)
	assert_true(player.velocity.length() > 0.0, "should have built up some velocity")
	Input.action_release("move_right")
	# Immediately after release, still decelerating (not yet snapped to Idle).
	player.machine.current.physics_update(0.016)
	if player.machine.current.name == "Move":
		assert_true(player.velocity.length() > 0.0, "should still be coasting down right after release")
	# Enough frames later, velocity has settled and Move handed off to Idle.
	for i in 300:
		if player.machine.current.name != "Move":
			break
		player.machine.current.physics_update(0.016)
	assert_eq(player.machine.current.name, "Idle")
	assert_eq(player.velocity, Vector2.ZERO)
