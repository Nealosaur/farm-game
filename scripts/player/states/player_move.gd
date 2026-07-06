extends State

@onready var player: Player = owner


func enter() -> void:
	player.play_anim("walk")


func physics_update(_delta: float) -> void:
	if GameFlow.cutscene_active:
		# Alive Stride 2: cutscenes/end-of-day freeze player input — stop
		# in place immediately rather than coasting on stale velocity.
		player.velocity = Vector2.ZERO
		machine.transition("Idle")
		return
	var dir := player.move_input()
	if dir == Vector2.ZERO:
		machine.transition("Idle")
		return
	player.update_facing(dir)
	player.play_anim("walk")
	player.velocity = dir * Player.SPEED
	player.move_and_slide()


func update(_delta: float) -> void:
	if GameFlow.cutscene_active:
		return
	if Input.is_action_just_pressed("dodge"):
		player.try_dodge()
	elif Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
