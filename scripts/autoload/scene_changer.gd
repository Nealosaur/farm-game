extends Node
## Fade-to-black scene transitions. Maps place the player at the Marker2D
## whose name matches `spawn_name` (Plan 2 uses this).

var spawn_name := "default"
var _traveling := false

var _rect: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_rect)
	add_child(layer)


func fade_to_black(duration := 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, duration)
	await t.finished


func fade_from_black(duration := 0.25) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, duration)
	await t.finished


func travel(scene_path: String, spawn: String = "default") -> void:
	if _traveling:
		return
	_traveling = true
	if not ResourceLoader.exists(scene_path):
		push_warning("SceneChanger: missing scene %s — falling back to dev room" % scene_path)
		scene_path = "res://scenes/maps/dev_room.tscn"
		spawn = "default"
	spawn_name = spawn
	await fade_to_black()
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await fade_from_black()
	_traveling = false
