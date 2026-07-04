class_name EnemyHurt
extends State
## Knockback + brief stun after taking a hit. The blink itself is handled by
## the HurtboxComponent's i-frame flash; this state just owns the shove.

const DURATION := 0.15

@onready var enemy: Enemy = owner

var incoming_knockback := Vector2.ZERO
var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	enemy.velocity = incoming_knockback
	enemy.sprite.play("hurt")


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	enemy.velocity = incoming_knockback.lerp(Vector2.ZERO, t)
	enemy.move_and_slide()
	if _elapsed >= DURATION:
		machine.transition("Wander")
