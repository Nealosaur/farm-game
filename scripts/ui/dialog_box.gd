class_name DialogBox
extends CanvasLayer
## Reusable bottom-panel dialog. show_lines(lines) displays lines one at a
## time; "interact"/"use_item" input or a click on the panel advances; the
## final advance closes the box and emits `finished`.
##
## Pause convention (matches InventoryScreen/menus): the tree pauses while a
## dialog is open, this node keeps processing via PROCESS_MODE_ALWAYS.
##
## Queue-safe policy (documented, not auto-obvious): while a dialog is
## already open, a new show_lines() call is IGNORED (not queued/appended).
## Rationale — dialogs here are short NPC greetings triggered by a single
## interact() call; there's no scenario yet where two callers legitimately
## queue lines back-to-back, and silently dropping avoids a caller having to
## await a signal just to know it's safe to call again. Callers that must
## chain dialog -> action (e.g. shopkeeper opening the shop after its lines)
## should connect to `finished` instead of calling show_lines again anyway.

signal finished

var label: Label
var hint_label: Label
var _lines: Array[String] = []
var _index := -1


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialog_box")
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_gui_input)
	add_child(root)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 16
	panel.offset_right = -16
	panel.offset_top = -84
	panel.offset_bottom = -16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	label = Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 12
	label.offset_top = 10
	label.offset_right = -12
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

	hint_label = Label.new()
	hint_label.text = "[E / click to continue]"
	hint_label.position = Vector2(12, 46)
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hint_label.add_theme_font_size_override("font_size", 10)
	panel.add_child(hint_label)


func is_open() -> bool:
	return visible


func show_lines(lines: Array[String]) -> void:
	if is_open():
		return  # queue-safe policy: ignore while already open (see class doc)
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	visible = true
	get_tree().paused = true
	_refresh()


func _advance() -> void:
	if not is_open():
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_refresh()


func _refresh() -> void:
	label.text = _lines[_index]


func _close() -> void:
	visible = false
	get_tree().paused = false
	_lines = []
	_index = -1
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("use_item"):
		_advance()
		get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
