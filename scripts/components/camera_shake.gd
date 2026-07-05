class_name CameraShake
extends Camera2D
## Tiny screen shake on EventBus.camera_shake(strength). Offsets this camera
## by a random tiny vector every frame while shaking, decaying linearly to
## zero over DURATION. Attach to the player's Camera2D (farm.gd/dungeon_floor.gd
## both build the camera as a child of Player) in place of a plain Camera2D.

const DEFAULT_STRENGTH := 4.0
const DURATION := 0.15

var _time_left := 0.0
var _strength := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.camera_shake.connect(_on_camera_shake)


func _on_camera_shake(strength = DEFAULT_STRENGTH) -> void:
	_strength = float(strength)
	_time_left = DURATION


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		return
	_time_left = maxf(0.0, _time_left - delta)
	var decay: float = _time_left / DURATION
	var mag: float = _strength * decay
	offset = Vector2(_rng.randf_range(-mag, mag), _rng.randf_range(-mag, mag))
