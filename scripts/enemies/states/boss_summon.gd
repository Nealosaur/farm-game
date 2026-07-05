class_name BossSummon
extends State
## Threshold-triggered summon: brief cast pose (CAST_DURATION), then spawns 2
## regular slimes at offsets +-24px via SlimeKing.spawn_minions(), then
## returns to Pursue. Entered by SlimeKing._on_damaged() when a summon
## threshold (66%/33%) is crossed.

const CAST_DURATION := 0.5
const CAST_TINT := Color(1.3, 1.0, 1.4)

@onready var boss: SlimeKing = owner

var _elapsed := 0.0
var _spawned := false


func enter() -> void:
	_elapsed = 0.0
	_spawned = false
	boss.velocity = Vector2.ZERO
	boss.sprite.modulate = CAST_TINT
	boss.sprite.play("idle")


func exit() -> void:
	boss.sprite.modulate = Color.WHITE


func physics_update(delta: float) -> void:
	boss.velocity = Vector2.ZERO
	boss.move_and_slide()
	_elapsed += delta

	if not _spawned and _elapsed >= CAST_DURATION * 0.5:
		# Spawn partway through the cast pose rather than at the very end —
		# reads as "the cast completes and minions appear" without a dead
		# frame waiting on the full pose to finish.
		_spawned = true
		var world := boss.get_parent()
		if world != null:
			boss.spawn_minions(world)

	if _elapsed >= CAST_DURATION:
		machine.transition("Pursue")
