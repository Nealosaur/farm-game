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
