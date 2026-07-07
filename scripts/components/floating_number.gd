class_name FloatingNumber
extends RefCounted
## FEEL Stride 6: a small Label that rises and fades — used for bond-gain
## numbers ("+15"/"+80") and optional damage-dealt numbers. Self-freeing, like
## ParticleFX's one-shot spawns: a tween drives position + alpha, then queue_frees.
##
## Spawned as a Label directly under a CanvasLayer (NOT under the world node
## the event happened on) so it draws in SCREEN space at a projected position
## — using a Node2D parent would inherit that node's local transform/rotation/
## scale, which a plain UI Label was never designed to survive. spawn() takes
## the CanvasLayer to attach under plus the WORLD position to project from a
## Camera2D, mirroring how HUD-style overlays are normally anchored to a
## world-space point in this engine.

const RISE_PX := 18.0
const DURATION := 0.7

const BOND_COLOR := Color("7ad1ff")     # cool blue — matches the bond-up chime's "friendly" read
const DAMAGE_COLOR := Color("ff8a5c")   # warm orange-red — reads as combat, distinct from bond


static func spawn(layer: CanvasLayer, world_pos: Vector2, text: String, color: Color) -> Label:
	if layer == null or not is_instance_valid(layer):
		return null
	var viewport := layer.get_viewport()
	if viewport == null:
		return null
	var cam := viewport.get_camera_2d()
	var screen_pos: Vector2 = world_pos
	if cam != null:
		# Project world -> screen the same way Camera2D itself does: offset by
		# the camera's own position (canvas_items stretch mode + this game's
		# fixed viewport means no additional zoom/rotation math is needed).
		screen_pos = world_pos - cam.get_screen_center_position() + viewport.get_visible_rect().size / 2.0

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 2)
	label.position = screen_pos + Vector2(-8, -10)
	label.z_index = 100
	layer.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - RISE_PX, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)
	tween.set_parallel(false)
	var id := label.get_instance_id()
	tween.tween_callback(func() -> void:
		if is_instance_id_valid(id):
			(instance_from_id(id) as Node).queue_free()
	)
	return label
