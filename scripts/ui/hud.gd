class_name Hud
extends CanvasLayer
## HP/RP bars, gold, clock, hotbar, toasts. Pure EventBus consumer.

var hp_bar: ProgressBar
var rp_bar: ProgressBar
var gold_label: Label
var clock_label: Label
var day_label: Label
var toast_label: Label
var slot_panels: Array[Panel] = []
var slot_icons: Array[TextureRect] = []
var slot_counts: Array[Label] = []

var _toast_queue: PackedStringArray = []
var _toast_busy := false


func _ready() -> void:
	layer = 10
	add_to_group("hud")

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := VBoxContainer.new()
	top_left.position = Vector2(8, 8)
	root.add_child(top_left)
	hp_bar = _bar(Color("c03030"))
	rp_bar = _bar(Color("30a060"))
	top_left.add_child(hp_bar)
	top_left.add_child(rp_bar)

	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-120, 8)
	top_right.custom_minimum_size = Vector2(112, 0)
	root.add_child(top_right)
	day_label = Label.new()
	clock_label = Label.new()
	gold_label = Label.new()
	for l in [day_label, clock_label, gold_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		top_right.add_child(l)

	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position = Vector2(-Inventory.HOTBAR * 22 / 2.0, -30)
	root.add_child(hotbar)
	for i in Inventory.HOTBAR:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(20, 20)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		panel.add_child(icon)
		var count := Label.new()
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.position = Vector2(-12, -12)
		count.add_theme_font_size_override("font_size", 8)
		panel.add_child(count)
		hotbar.add_child(panel)
		slot_panels.append(panel)
		slot_icons.append(icon)
		slot_counts.append(count)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-100, 40)
	toast_label.custom_minimum_size = Vector2(200, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	# Named methods only — lambda connections would outlive this node when the
	# scene is freed (see FarmGrid note) and crash on later emissions.
	EventBus.stats_changed.connect(_refresh_stats)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.inventory_changed.connect(_refresh_hotbar)
	EventBus.hotbar_selection_changed.connect(_on_hotbar_selection)
	EventBus.toast_requested.connect(toast)
	_refresh_stats()
	_refresh_clock()
	_refresh_hotbar()


func _on_money_changed(_gold) -> void:
	_refresh_stats()


func _on_time_ticked(_h, _m) -> void:
	_refresh_clock()


func _on_day_passed(_d) -> void:
	_refresh_clock()


func _on_hotbar_selection(_i) -> void:
	_refresh_hotbar()


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(90, 10)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _refresh_stats() -> void:
	hp_bar.max_value = GameState.max_hp
	hp_bar.value = GameState.hp
	rp_bar.max_value = GameState.max_rp
	rp_bar.value = GameState.rp
	gold_label.text = "%dg" % GameState.gold


func _refresh_clock() -> void:
	clock_label.text = Clock.time_string()
	day_label.text = Clock.date_string()  # "Spring 12, Yr 1" (World Stride A)


func _refresh_hotbar() -> void:
	for i in Inventory.HOTBAR:
		var s = Inventory.slots[i]
		if s == null:
			slot_icons[i].texture = null
			slot_counts[i].text = ""
		else:
			var item := ItemDB.get_item(s.id)
			slot_icons[i].texture = item.icon if item != null else null
			slot_counts[i].text = str(s.count) if s.count > 1 else ""
		slot_panels[i].modulate = Color(1.4, 1.4, 0.9) if i == Inventory.selected else Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	for i in Inventory.HOTBAR:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotbar(i)
			return
	if event.is_action_pressed("hotbar_next"):
		Inventory.select_hotbar((Inventory.selected + 1) % Inventory.HOTBAR)
	elif event.is_action_pressed("hotbar_prev"):
		Inventory.select_hotbar((Inventory.selected - 1 + Inventory.HOTBAR) % Inventory.HOTBAR)


func toast(message: String) -> void:
	_toast_queue.append(message)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	toast_label.text = _toast_queue[0]
	_toast_queue.remove_at(0)
	var t := create_tween()
	t.tween_property(toast_label, "modulate:a", 1.0, 0.15)
	t.tween_interval(1.4)
	t.tween_property(toast_label, "modulate:a", 0.0, 0.3)
	t.tween_callback(_next_toast)
