extends State
## FEEL Stride 1: velocity ramps toward input*SPEED (see Player.approach_velocity)
## instead of snapping — walking now has a brief accel wind-up, and releasing
## input decelerates (still inside Move) before handing off to Idle once
## velocity has actually settled to zero, so the stop reads as a glide-to-
## halt rather than an instant snap.

const STOP_EPSILON := 1.0  # px/s — below this, treat velocity as "settled" for the Idle handoff

## FEEL Stride 3: footstep dust cadence — a dust puff spawns every
## FOOTSTEP_INTERVAL seconds of actual movement (gated on velocity, not
## elapsed state time, so a decel-to-stop doesn't rack up phantom footsteps).
const FOOTSTEP_INTERVAL := 0.28
const MOVING_SPEED_THRESHOLD := 20.0  # px/s — below this, treat as "not really walking" for dust

@onready var player: Player = owner

var _footstep_elapsed := 0.0


func enter() -> void:
	player.play_anim("walk")
	_footstep_elapsed = 0.0


func physics_update(delta: float) -> void:
	if GameFlow.cutscene_active:
		# Alive Stride 2: cutscenes/end-of-day freeze player input — stop
		# in place immediately rather than coasting on stale velocity.
		player.velocity = Vector2.ZERO
		machine.transition("Idle")
		return
	var dir := player.move_input()
	var target := dir * Player.SPEED
	if dir != Vector2.ZERO:
		player.update_facing(dir)
		player.play_anim("walk")
	player.velocity = Player.approach_velocity(player.velocity, target, Player.ACCEL, Player.FRICTION, delta)
	player.move_and_slide()
	_update_footstep_cadence(delta)
	if dir == Vector2.ZERO and player.velocity.length() <= STOP_EPSILON:
		player.velocity = Vector2.ZERO
		machine.transition("Idle")


func _update_footstep_cadence(delta: float) -> void:
	if player.velocity.length() < MOVING_SPEED_THRESHOLD:
		_footstep_elapsed = 0.0
		return
	_footstep_elapsed += delta
	if _footstep_elapsed >= FOOTSTEP_INTERVAL:
		_footstep_elapsed = 0.0
		ParticleFX.spawn_dust(player, player.global_position + Vector2(0, Player.SPRITE_BOTTOM))


func update(_delta: float) -> void:
	if GameFlow.cutscene_active:
		return
	if Input.is_action_just_pressed("dodge"):
		player.try_dodge()
	elif Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
