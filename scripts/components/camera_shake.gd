class_name CameraShake
extends Camera2D
## Tiny screen shake on EventBus.camera_shake(strength). Offsets this camera
## by a random tiny vector every frame while shaking, decaying linearly to
## zero over DURATION. Attach to the player's Camera2D (farm.gd/dungeon_floor.gd
## both build the camera as a child of Player) in place of a plain Camera2D.
##
## FEEL Stride 1: also owns a subtle look-ahead — `offset` leans a few px
## toward the player's current facing/velocity, smoothed toward its target
## each frame (separate from the shake math below, and from Camera2D's own
## built-in position_smoothing which the caller enables on the node itself
## for the camera's WORLD position lag). Shake and look-ahead are summed into
## the same `offset` property (Camera2D only exposes one), computed fresh
## every frame so neither one can leave a stale contribution behind.

const DEFAULT_STRENGTH := 4.0
const DURATION := 0.15

## Position smoothing speed (Camera2D.position_smoothing_speed) tuned for this
## game's small 640x360 viewport — Godot's default (5.0) reads sluggish at
## this zoom; higher values track the player more snugly while still
## smoothing out the per-pixel jitter of tile-stepped movement. Map builders
## enable position_smoothing_enabled themselves (unchanged); this constant is
## applied here in _ready() so every camera site gets the same tuned value
## without repeating the number at each of the five call sites.
const POSITION_SMOOTHING_SPEED := 12.0

## Look-ahead tuning: small and slow so it reads as a gentle lean, never a
## snap — LOOK_AHEAD_MAX is in pixels, LOOK_AHEAD_LERP is a per-second smoothing
## factor consumed via 1.0 - exp(-rate*delta) (frame-rate independent).
const LOOK_AHEAD_MAX := 10.0
const LOOK_AHEAD_LERP := 6.0

var _time_left := 0.0
var _strength := 0.0
var _rng := RandomNumberGenerator.new()
var _look_ahead := Vector2.ZERO


func _ready() -> void:
	EventBus.camera_shake.connect(_on_camera_shake)
	if position_smoothing_enabled:
		position_smoothing_speed = POSITION_SMOOTHING_SPEED


func _on_camera_shake(strength = DEFAULT_STRENGTH) -> void:
	_strength = float(strength)
	_time_left = DURATION


func _process(delta: float) -> void:
	_update_look_ahead(delta)
	var shake := Vector2.ZERO
	if _time_left > 0.0:
		_time_left = maxf(0.0, _time_left - delta)
		var decay: float = _time_left / DURATION
		var mag: float = _strength * decay
		shake = Vector2(_rng.randf_range(-mag, mag), _rng.randf_range(-mag, mag))
	offset = _look_ahead + shake


func _update_look_ahead(delta: float) -> void:
	var target := Vector2.ZERO
	var player := get_parent() as Player
	if player != null:
		# Facing direction leant into gently; velocity (if moving) sharpens the
		# lean toward the direction of actual travel — both cases fall out of
		# the same "unit direction * LOOK_AHEAD_MAX" formula.
		var dir := Vector2(player.facing)
		if player.velocity.length() > 1.0:
			dir = player.velocity.normalized()
		target = dir * LOOK_AHEAD_MAX
	var t: float = 1.0 - exp(-LOOK_AHEAD_LERP * delta)
	_look_ahead = _look_ahead.lerp(target, t)
