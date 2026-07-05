class_name BossHurt
extends State
## Same knockback+stun as EnemyHurt, but returns to Pursue instead of Wander
## (the boss has no Wander state — it's always actively fighting).

const DURATION := 0.15

@onready var boss: SlimeKing = owner

var incoming_knockback := Vector2.ZERO
var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	boss.velocity = incoming_knockback
	boss.sprite.play("hurt")


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	boss.velocity = incoming_knockback.lerp(Vector2.ZERO, t)
	boss.move_and_slide()
	if _elapsed >= DURATION:
		machine.transition("Pursue")
