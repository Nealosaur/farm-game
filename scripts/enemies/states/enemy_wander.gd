class_name EnemyWander
extends State
## Idle drift: pick a random direction every 1-2s at 0.4x speed, staying near
## spawn_position within LEASH. Aggroes into Chase when the player enters range.

const SPEED_MULT := 0.4
const LEASH := 48.0
const MIN_INTERVAL := 1.0
const MAX_INTERVAL := 2.0

@onready var enemy: Enemy = owner

var _dir := Vector2.ZERO
var _timer := 0.0


func enter() -> void:
	enemy.velocity = Vector2.ZERO
	enemy.sprite.play("idle")
	_pick_new_direction()


func _pick_new_direction() -> void:
	_timer = enemy.rng.randf_range(MIN_INTERVAL, MAX_INTERVAL)
	var angle := enemy.rng.randf_range(0.0, TAU)
	_dir = Vector2.RIGHT.rotated(angle)


func physics_update(delta: float) -> void:
	var player := enemy.player_node()
	if player != null and enemy.global_position.distance_to(player.global_position) <= Enemy.AGGRO_RANGE:
		machine.transition("Chase")
		return

	_timer -= delta
	if _timer <= 0.0:
		_pick_new_direction()

	var to_spawn := enemy.spawn_position - enemy.global_position
	var vel := _dir
	if to_spawn.length() > LEASH:
		vel = to_spawn.normalized()  # pulled back toward the leash center
	enemy.velocity = vel * enemy.data.speed * SPEED_MULT
	enemy.move_and_slide()
