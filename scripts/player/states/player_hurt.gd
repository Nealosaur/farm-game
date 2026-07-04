class_name PlayerHurt
extends State
## Brief stun after taking a hit. Knockback velocity decays via lerp over the
## stun window, then returns to Idle. Player.hurtbox sets incoming_knockback
## before transitioning here.

const DURATION := 0.2

@onready var player: Player = owner

var incoming_knockback := Vector2.ZERO
var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = incoming_knockback
	player.play_anim("idle")


func physics_update(delta: float) -> void:
	_elapsed += delta
	var t: float = clampf(_elapsed / DURATION, 0.0, 1.0)
	player.velocity = incoming_knockback.lerp(Vector2.ZERO, t)
	player.move_and_slide()
	if _elapsed >= DURATION:
		machine.transition("Idle")
