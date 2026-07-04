class_name EnemyChase
extends State
## Chases the player at data.speed while within range; deaggroes back to
## Wander past DEAGGRO_RANGE. Wisps add a perpendicular sine wobble to their
## approach. Goblins telegraph a lunge when they close to melee range.

const WOBBLE_FREQUENCY := 6.0
const WOBBLE_AMPLITUDE := 24.0
const GOBLIN_WINDUP_RANGE := 24.0

@onready var enemy: Enemy = owner

var _wobble_t := 0.0


func enter() -> void:
	enemy.sprite.play("idle")
	_wobble_t = 0.0


func physics_update(delta: float) -> void:
	var player := enemy.player_node()
	if player == null:
		machine.transition("Wander")
		return

	var to_player := player.global_position - enemy.global_position
	var dist := to_player.length()
	if dist > Enemy.DEAGGRO_RANGE:
		machine.transition("Wander")
		return

	if enemy.is_goblin and dist <= GOBLIN_WINDUP_RANGE and machine.has_node("Windup"):
		machine.transition("Windup")
		return

	var dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.ZERO
	if enemy.is_wisp:
		_wobble_t += delta
		var perp := Vector2(-dir.y, dir.x)
		dir += perp * sin(_wobble_t * WOBBLE_FREQUENCY) * (WOBBLE_AMPLITUDE / 100.0)
		dir = dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO

	enemy.velocity = dir * enemy.data.speed
	enemy.move_and_slide()
