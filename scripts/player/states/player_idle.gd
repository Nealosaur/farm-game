extends State

@onready var player: Player = owner


func enter() -> void:
	player.velocity = Vector2.ZERO
	player.play_anim("idle")


func update(_delta: float) -> void:
	if GameFlow.cutscene_active:
		return  # Alive Stride 2: cutscenes/end-of-day freeze player input
	if Input.is_action_just_pressed("dodge"):
		player.try_dodge()
	elif Input.is_action_just_pressed("use_item"):
		player.try_use_selected()
	elif Input.is_action_just_pressed("interact"):
		player.try_interact()
	elif player.move_input() != Vector2.ZERO:
		machine.transition("Move")
