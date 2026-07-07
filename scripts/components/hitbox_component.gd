class_name HitboxComponent
extends Area2D
## "This thing hurts what it touches." Owner sets damage/knockback_force before
## activating; HurtboxComponent on the other side reads them via area_entered.

@export var damage: int = 1
@export var knockback_force: float = 120.0
## FEEL Stride 2: marks this hitbox as a HEAVY hit for hit-stop purposes (the
## boss slam's AoE hitbox sets this true; the player's sword hitbox and every
## enemy's ordinary contact hitbox leave it false). HurtboxComponent forwards
## this through hit_taken so the receiving side can decide whether landing
## this specific hit should trigger HitStop.trigger() — kept as an explicit
## flag rather than inferred from knockback_force/damage magnitude so the
## rule stays simple and doesn't silently change if those numbers are retuned.
@export var is_heavy: bool = false


func set_active(on: bool) -> void:
	set_deferred("monitoring", on)
	set_deferred("monitorable", on)
