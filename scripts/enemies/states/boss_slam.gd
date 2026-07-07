class_name BossSlam
extends State
## Slam attack: TELEGRAPH_DURATION scale-pulse + darker tint (boss stops
## moving), then an AoE ring HitboxComponent (RADIUS around the boss) active
## for ACTIVE_DURATION dealing data.damage with heavy knockback — reuses the
## existing Hitbox/Hurtbox overlap + iframe pipeline (same layers/mask as the
## boss's normal contact Hitbox) instead of a bespoke damage path. Visual is a
## SlamRing (circle outline) that expands during telegraph and holds during
## the active window. Returns to Pursue and resets the slam cooldown.

const TELEGRAPH_DURATION := 0.6
const ACTIVE_DURATION := 0.3
const RADIUS := 36.0
const KNOCKBACK := 220.0
const TELEGRAPH_TINT := Color(0.5, 0.6, 1.3)

@onready var boss: SlimeKing = owner

var _elapsed := 0.0
var _active := false
var _ring: SlamRing
var _slam_hitbox: HitboxComponent


func enter() -> void:
	_elapsed = 0.0
	_active = false
	boss.velocity = Vector2.ZERO
	boss.sprite.modulate = TELEGRAPH_TINT
	boss.sprite.play("idle")

	var base_scale: Vector2 = boss.sprite.scale
	var tween := boss.create_tween()
	tween.set_loops()
	tween.tween_property(boss.sprite, "scale", base_scale * 1.15, TELEGRAPH_DURATION * 0.5)
	tween.tween_property(boss.sprite, "scale", base_scale, TELEGRAPH_DURATION * 0.5)

	_ring = SlamRing.new()
	_ring.radius = 4.0
	boss.add_child(_ring)
	var ring_tween := boss.create_tween()
	ring_tween.tween_property(_ring, "radius", RADIUS, TELEGRAPH_DURATION)


func exit() -> void:
	boss.sprite.modulate = Color.WHITE
	boss.sprite.scale = Vector2.ONE
	if is_instance_valid(_ring):
		_ring.queue_free()
	_ring = null
	if is_instance_valid(_slam_hitbox):
		_slam_hitbox.queue_free()
	_slam_hitbox = null


func physics_update(delta: float) -> void:
	boss.velocity = Vector2.ZERO
	boss.move_and_slide()
	_elapsed += delta

	if not _active and _elapsed >= TELEGRAPH_DURATION:
		_active = true
		_spawn_slam_hitbox()

	if _active and _elapsed >= TELEGRAPH_DURATION + ACTIVE_DURATION:
		machine.transition("Pursue")


func _spawn_slam_hitbox() -> void:
	# FEEL Stride 4: medium shake on the slam LANDING (this is the AoE going
	# live, not the earlier telegraph) — test_boss_slam.gd's
	# test_entering_slam_does_not_shake_yet already pins that ordering.
	EventBus.camera_shake.emit(CameraShake.MEDIUM_STRENGTH)
	_slam_hitbox = HitboxComponent.new()
	_slam_hitbox.damage = boss.data.damage
	_slam_hitbox.knockback_force = KNOCKBACK
	_slam_hitbox.is_heavy = true  # FEEL Stride 2: hit-stop + medium shake on landing
	_slam_hitbox.collision_layer = Layers.bit(Layers.ENEMY_HITBOX)
	_slam_hitbox.collision_mask = Layers.bit(Layers.PLAYER_HURTBOX)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	_slam_hitbox.add_child(shape)
	boss.add_child(_slam_hitbox)
	_slam_hitbox.set_active(true)
