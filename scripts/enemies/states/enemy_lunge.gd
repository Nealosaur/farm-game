class_name EnemyLunge
extends State
## Goblin-only dash attack: 2x speed toward the player's position at lunge
## start, for DURATION. Damage stays the same as contact (kept simple per
## spec); the existing always-on Hitbox already covers the hit.

const DURATION := 0.2
const SPEED_MULT := 2.0

@onready var enemy: Enemy = owner

var _elapsed := 0.0
var _dir := Vector2.ZERO


func enter() -> void:
	_elapsed = 0.0
	var player := enemy.player_node()
	if player != null:
		var to_player: Vector2 = player.global_position - enemy.global_position
		_dir = to_player.normalized() if to_player != Vector2.ZERO else Vector2.DOWN
	else:
		_dir = Vector2.DOWN
	enemy.sprite.play("idle")


func physics_update(delta: float) -> void:
	enemy.velocity = _dir * enemy.data.speed * SPEED_MULT
	enemy.move_and_slide()
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition("Chase")
