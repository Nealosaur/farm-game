extends State
## FEEL Stride 1: velocity ramps toward input*SPEED (see Player.approach_velocity)
## instead of snapping — walking now has a brief accel wind-up, and releasing
## input decelerates (still inside Move) before handing off to Idle once
## velocity has actually settled to zero, so the stop reads as a glide-to-
## halt rather than an instant snap.

const STOP_EPSILON := 1.0  # px/s — below this, treat velocity as "settled" for the Idle handoff

@onready var player: Player = owner


func enter() -> void:
	player.play_anim("walk")


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
	if dir == Vector2.ZERO and player.velocity.length() <= STOP_EPSILON:
		player.velocity = Vector2.ZERO
		machine.transition("Idle")


func update(_delta: float) -> void:
	if GameFlow.cutscene_active:
		return
	if Input.is_action_just_pressed("dodge"):
		player.try_dodge()
	elif Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
