class_name SlamRing
extends Node2D
## Placeholder-grade AoE telegraph/impact visual: a plain circle outline drawn
## with _draw(), expanding via `radius` (tweened by BossSlam). No art asset —
## a Polygon2D/ColorRect equivalent done in code so it scales smoothly.

var radius: float = 4.0
var ring_color: Color = Color(0.7, 1.0, 0.6, 0.8)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ring_color, 3.0, true)
