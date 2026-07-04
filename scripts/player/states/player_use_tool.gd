extends State
## Brief action lock while a tool animation plays.

const DURATION := 0.25

@onready var player: Player = owner

var _elapsed := 0.0


func enter() -> void:
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.play_anim("use")


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		machine.transition("Idle")
