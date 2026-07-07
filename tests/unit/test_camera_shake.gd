extends GutTest
## CameraShake: EventBus.camera_shake listener decays offset to zero over
## DURATION, and stays put with no active shake.

var cam: CameraShake


func before_each() -> void:
	cam = (load("res://scripts/components/camera_shake.gd") as GDScript).new() as CameraShake
	add_child_autofree(cam)


func test_no_shake_keeps_offset_zero() -> void:
	cam._process(0.016)
	assert_eq(cam.offset, Vector2.ZERO)


func test_camera_shake_signal_arms_shake() -> void:
	EventBus.camera_shake.emit(4.0)
	assert_eq(cam._time_left, CameraShake.DURATION)
	assert_eq(cam._strength, 4.0)


func test_shake_decays_to_zero_after_duration() -> void:
	cam._on_camera_shake(4.0)
	cam._process(CameraShake.DURATION + 0.01)
	assert_eq(cam._time_left, 0.0)
	cam._process(0.016)
	assert_eq(cam.offset, Vector2.ZERO)


func test_shake_offset_magnitude_shrinks_over_time() -> void:
	cam._on_camera_shake(4.0)
	cam._process(0.001)
	var early_mag: float = cam.offset.length()
	cam._process(CameraShake.DURATION * 0.9)
	var late_mag: float = cam.offset.length()
	assert_true(late_mag <= early_mag + 0.001, "shake magnitude should shrink (or stay tiny) as time elapses")


func test_default_strength_used_when_no_argument_passed() -> void:
	EventBus.camera_shake.emit()
	assert_eq(cam._strength, CameraShake.DEFAULT_STRENGTH)


## ---- FEEL Stride 1: look-ahead ----

func test_look_ahead_stays_zero_without_a_player_parent() -> void:
	# cam here is parented directly under the test node (see before_each),
	# not a Player, so _update_look_ahead's target must stay ZERO.
	cam._process(0.5)
	assert_eq(cam.offset, Vector2.ZERO)


func test_look_ahead_leans_toward_player_facing_when_stationary() -> void:
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.facing = Vector2i.RIGHT
	var cam2 := (load("res://scripts/components/camera_shake.gd") as GDScript).new() as CameraShake
	player.add_child(cam2)
	autofree(cam2)
	for i in 60:
		cam2._process(0.05)
	assert_true(cam2.offset.x > 0.0, "should lean right toward RIGHT facing")
	assert_true(cam2.offset.x <= CameraShake.LOOK_AHEAD_MAX + 0.01)


func test_look_ahead_leans_toward_velocity_direction_when_moving() -> void:
	var player: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child_autofree(player)
	player.facing = Vector2i.DOWN
	player.velocity = Vector2(-Player.SPEED, 0)  # moving left despite facing down
	var cam2 := (load("res://scripts/components/camera_shake.gd") as GDScript).new() as CameraShake
	player.add_child(cam2)
	autofree(cam2)
	for i in 60:
		cam2._process(0.05)
	assert_true(cam2.offset.x < 0.0, "velocity direction should win over stale facing")
