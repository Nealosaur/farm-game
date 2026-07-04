class_name PlayerDodge
extends State
## Space ("dodge" action) dash. Only reachable from Idle/Move (wired at the
## call site, not enforced here). Costs 3 RP via try_spend_rp — silently does
## nothing if RP is fully empty. Dashes at 3x SPEED in the current move
## direction (or facing if stationary) for DURATION, granting i-frames.

const DURATION := 0.25
const SPEED_MULT := 3.0
const RP_COST := 3

@onready var player: Player = owner

var _elapsed := 0.0
var _dir := Vector2.ZERO


func enter() -> void:
	_elapsed = 0.0
	var input_dir := player.move_input()
	_dir = input_dir.normalized() if input_dir != Vector2.ZERO else Vector2(player.facing)
	player.hurtbox.trigger_iframes(0.4)
	player.play_anim("walk")


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.velocity = _dir * Player.SPEED * SPEED_MULT
	player.move_and_slide()
	if _elapsed >= DURATION:
		machine.transition("Idle")
