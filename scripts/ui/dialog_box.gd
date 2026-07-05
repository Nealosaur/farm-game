class_name DialogBox
extends CanvasLayer
## Reusable bottom-panel dialog. show_lines(lines) displays lines one at a
## time; "interact"/"use_item" input or a click on the panel advances; the
## final advance closes the box and emits `finished`.
##
## Choice-row extension (World Stride B): show_choices(lines, choices) plays
## `lines` exactly like show_lines(), then — instead of closing on the final
## advance — shows one button per `choices` entry (mouse-only, matches
## ShopScreen's row-button convention). Picking a button emits
## `choice_made(index)`, THEN closes (emits `finished`) — connect to
## choice_made if the caller needs to know WHICH option was picked, or to
## `finished` if it just needs to know the box closed.
##
## Pause convention (matches InventoryScreen/menus): the tree pauses while a
## dialog is open, this node keeps processing via PROCESS_MODE_ALWAYS.
##
## Queue-safe policy (documented, not auto-obvious): while a dialog is
## already open, a new show_lines()/show_choices() call is IGNORED (not
## queued/appended). Rationale — dialogs here are short NPC greetings
## triggered by a single interact() call; there's no scenario yet where two
## callers legitimately queue lines back-to-back, and silently dropping
## avoids a caller having to await a signal just to know it's safe to call
## again. Callers that must chain dialog -> action (e.g. shopkeeper opening
## the shop after its lines) should connect to `finished` instead of calling
## show_lines again anyway.

signal finished
signal choice_made(index: int)

var label: Label
var hint_label: Label
var choice_box: VBoxContainer
var _lines: Array[String] = []
var _index := -1
var _choices: Array[String] = []
var _showing_choices := false


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

	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(12, 40)
	choice_box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(choice_box)


func is_open() -> bool:
	return visible


func show_lines(lines: Array[String]) -> void:
	if is_open():
		return  # queue-safe policy: ignore while already open (see class doc)
	if lines.is_empty():
		return
	_lines = lines
	_choices = []
	_index = 0
	visible = true
	get_tree().paused = true
	_refresh()


func show_choices(lines: Array[String], choices: Array[String]) -> void:
	if is_open():
		return  # queue-safe policy (see class doc)
	if lines.is_empty() or choices.is_empty():
		return
	_lines = lines
	_choices = choices
	_index = 0
	visible = true
	get_tree().paused = true
	_refresh()


func _advance() -> void:
	if not is_open() or _showing_choices:
		return
	_index += 1
	if _index >= _lines.size():
		if _choices.is_empty():
			_close()
		else:
			_show_choice_buttons()
	else:
		_refresh()


func _refresh() -> void:
	label.text = _lines[_index]
	hint_label.visible = true


func _show_choice_buttons() -> void:
	_showing_choices = true
	hint_label.visible = false
	label.text = ""
	for i in _choices.size():
		var btn := Button.new()
		btn.text = _choices[i]
		btn.pressed.connect(_on_choice_pressed.bind(i))
		choice_box.add_child(btn)


func _on_choice_pressed(index: int) -> void:
	choice_made.emit(index)
	_close()


func _clear_choice_buttons() -> void:
	# queue_free, NOT free: this runs from _close(), which _on_choice_pressed
	# calls synchronously from inside a button's own `pressed` signal
	# emission — freeing the emitting button immediately would hit Godot's
	# "attempted to free a locked object (calling or emitting)" guard.
	for child in choice_box.get_children():
		choice_box.remove_child(child)
		child.queue_free()


func _close() -> void:
	visible = false
	get_tree().paused = false
	_clear_choice_buttons()
	_lines = []
	_choices = []
	_index = -1
	_showing_choices = false
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or _showing_choices:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("use_item"):
		_advance()
		get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
