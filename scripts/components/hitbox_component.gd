class_name HitboxComponent
extends Area2D
## "This thing hurts what it touches." Owner sets damage/knockback_force before
## activating; HurtboxComponent on the other side reads them via area_entered.

@export var damage: int = 1
@export var knockback_force: float = 120.0


func set_active(on: bool) -> void:
	set_deferred("monitoring", on)
	set_deferred("monitorable", on)
