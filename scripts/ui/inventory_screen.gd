class_name InventoryScreen
extends CanvasLayer
## Tab-toggled 3x10 grid; click one slot then another to swap/move.
## Pause convention: menus use get_tree().paused (this node keeps processing);
## Clock.paused stays reserved for scripted sequences (DayFlow).

var grid_box: GridContainer
var buttons: Array[Button] = []
var _pending := -1


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	grid_box = GridContainer.new()
	grid_box.columns = Inventory.HOTBAR
	grid_box.set_anchors_preset(Control.PRESET_CENTER)
	grid_box.position = Vector2(-Inventory.HOTBAR * 24 / 2.0, -40)
	add_child(grid_box)

	for i in Inventory.SIZE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(22, 22)
		b.expand_icon = true
		b.pressed.connect(_on_slot_pressed.bind(i))
		grid_box.add_child(b)
		buttons.append(b)

	EventBus.inventory_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()


func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	_pending = -1
	_refresh()


func _on_slot_pressed(index: int) -> void:
	if _pending < 0:
		_pending = index
	else:
		Inventory.swap(_pending, index)
		_pending = -1
	_refresh()


func _refresh() -> void:
	for i in buttons.size():
		var s = Inventory.slots[i]
		if s == null:
			buttons[i].icon = null
			buttons[i].text = ""
		else:
			var item := ItemDB.get_item(s.id)
			buttons[i].icon = item.icon if item != null else null
			buttons[i].text = str(s.count) if s.count > 1 else ""
		buttons[i].modulate = Color(1.4, 1.4, 0.9) if i == _pending else Color.WHITE
