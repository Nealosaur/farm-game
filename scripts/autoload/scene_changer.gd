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


func is_busy() -> bool:
	## Other transition owners (e.g. DayFlow) must check this before fading,
	## so overlapping transitions don't stomp each other's fade state.
	return _traveling


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
	# Release before fade-in: worst-case wedge window ends at the scene swap.
	_traveling = false
	await fade_from_black()


func swap_scene_while_black(scene_path: String, spawn: String, toasts: PackedStringArray = PackedStringArray()) -> void:
	## For flows that have ALREADY faded the screen to black themselves and
	## must swap scenes before fading back — DayFlow's sleep/collapse away
	## from the farm. Mirrors travel() minus the fade_to_black, and without
	## double-guarding against the caller (the caller owns the blackout and
	## checked is_busy before starting its sequence).
	## Deliberately a coroutine on this autoload: the caller (DayFlow) is a
	## child of the outgoing scene and is freed at the swap — anything IT
	## awaited after change_scene_to_file would silently never resume. The
	## caller finishes all its own state changes first, then invokes this
	## fire-and-forget. Toasts are emitted after the swap + one frame so the
	## incoming scene's HUD exists to display them.
	if _traveling:
		return
	_traveling = true
	spawn_name = spawn
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	_traveling = false
	for msg in toasts:
		EventBus.toast_requested.emit(msg)
	await fade_from_black()
