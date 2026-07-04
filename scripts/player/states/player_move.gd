extends State

@onready var player: Player = owner


func enter() -> void:
	player.play_anim("walk")


func physics_update(_delta: float) -> void:
	var dir := player.move_input()
	if dir == Vector2.ZERO:
		machine.transition("Idle")
		return
	player.update_facing(dir)
	player.play_anim("walk")
	player.velocity = dir * Player.SPEED
	player.move_and_slide()


func update(_delta: float) -> void:
	if Input.is_action_just_pressed("dodge"):
		player.try_dodge()
	elif Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
