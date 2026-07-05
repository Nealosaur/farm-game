class_name BossPursue
extends State
## Slow chase toward the player at data.speed * speed_mult (phase 2 speeds it
## up). Periodically breaks into a Slam when the player is close, on a cooldown
## that itself shortens in phase 2 (SlimeKing.slam_cooldown).

const SLAM_RANGE := 40.0

@onready var boss: SlimeKing = owner

var _slam_timer := 0.0


func enter() -> void:
	boss.sprite.play("idle")
	boss.sprite.modulate = Color.WHITE
	_slam_timer = boss.slam_cooldown


func physics_update(delta: float) -> void:
	var player := boss.player_node()
	if player == null:
		boss.velocity = Vector2.ZERO
		boss.move_and_slide()
		return

	var to_player: Vector2 = player.global_position - boss.global_position
	var dist := to_player.length()

	_slam_timer -= delta
	if _slam_timer <= 0.0 and dist <= SLAM_RANGE:
		machine.transition("Slam")
		return

	var dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.ZERO
	boss.velocity = dir * boss.data.speed * boss.speed_mult
	boss.move_and_slide()
