class_name EnemyWindup
extends State
## Goblin-only telegraph: stop moving, tint red, for DURATION, then Lunge.

const DURATION := 0.4
const TELEGRAPH_TINT := Color(1.6, 0.5, 0.5)

@onready var enemy: Enemy = owner

var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	enemy.velocity = Vector2.ZERO
	enemy.sprite.modulate = TELEGRAPH_TINT
	enemy.sprite.play("idle")


func exit() -> void:
	enemy.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	enemy.move_and_slide()
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition("Lunge")
