class_name HurtboxComponent
extends Area2D
## "This thing gets hurt." Detects HitboxComponent overlaps and turns them into
## a single hit_taken signal, with i-frames so one swing/contact doesn't hit
## multiple times. Owner (a CanvasItem, e.g. the sprite root) blinks via
## modulate while invincible, AND flashes solid white for one short beat on
## the exact impact frame (punchier read than the blink alone — the blink
## communicates "still invincible", the flash communicates "you got hit").

signal hit_taken(damage: int, knockback: Vector2)

@export var iframe_duration: float = 0.4
const FLASH_DURATION := 0.08
const FLASH_COLOR := Color(4.0, 4.0, 4.0)  # >1 channel values blow out to white under normal modulate math

var _invincible := false
var _iframe_timer: SceneTreeTimer
var _blink_tween: Tween
var _flash_tween: Tween


func _ready() -> void:
	# Named method, not a lambda — this node can be freed and reconnecting a
	## lambda-bound signal later would crash (see project convention).
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	# Godot does not fire area_entered for areas that were ALREADY overlapping
	# at the instant monitoring/monitorable flips on (e.g. a melee hitbox that
	# activates directly on top of a stationary enemy). Poll as a safety net;
	# _invincible dedupes so this never double-hits during one active window.
	if _invincible or not monitoring:
		return
	for area in get_overlapping_areas():
		if area is HitboxComponent:
			_register_hit(area as HitboxComponent)
			return


func _on_area_entered(area: Area2D) -> void:
	if not (area is HitboxComponent):
		return
	if _invincible:
		return
	_register_hit(area as HitboxComponent)


func _register_hit(hitbox: HitboxComponent) -> void:
	var origin: Node2D = owner if owner != null else get_parent()
	var knockback := Vector2.ZERO
	if origin is Node2D:
		var from := (origin as Node2D).global_position
		var dir := from - hitbox.global_position
		if dir != Vector2.ZERO:
			knockback = dir.normalized() * hitbox.knockback_force
	hit_taken.emit(hitbox.damage, knockback)
	trigger_iframes(iframe_duration)
	_flash_white()


func is_invincible() -> bool:
	return _invincible


func trigger_iframes(duration: float) -> void:
	_invincible = true
	_start_blink()
	_iframe_timer = get_tree().create_timer(duration)
	_iframe_timer.timeout.connect(_on_iframes_expired)


func _on_iframes_expired() -> void:
	_invincible = false
	_stop_blink()


func _blink_target() -> CanvasItem:
	var node: Node = owner if owner != null else get_parent()
	return node as CanvasItem


func _start_blink() -> void:
	_stop_blink()
	var target := _blink_target()
	if target == null:
		return
	_blink_tween = target.create_tween()
	_blink_tween.set_loops()
	_blink_tween.tween_property(target, "modulate:a", 0.3, iframe_duration * 0.15)
	_blink_tween.tween_property(target, "modulate:a", 1.0, iframe_duration * 0.15)


func _stop_blink() -> void:
	if _blink_tween != null and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null
	var target := _blink_target()
	if target != null:
		target.modulate.a = 1.0


func _flash_white() -> void:
	## Pure punch: spike modulate to a blown-out white for one frame's worth
	## of time, then settle back to opaque white. Independent of the blink
	## tween (which only ever touches modulate:a) so the two don't fight —
	## this one sets the full modulate Color and always resolves to
	## Color(1,1,1,1) at the end, matching the blink's resting alpha.
	var target := _blink_target()
	if target == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	target.modulate = FLASH_COLOR
	_flash_tween = target.create_tween()
	_flash_tween.tween_property(target, "modulate", Color.WHITE, FLASH_DURATION)
