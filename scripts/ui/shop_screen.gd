class_name ShopScreen
extends CanvasLayer
## BUY/SELL tabbed store screen, opened by shopkeeper.gd. Tree-paused while
## open (menu convention — see InventoryScreen). Esc ("pause") or Tab
## ("inventory") closes it. Mouse-only usable: rows are buttons.
##
## Data comes from ShopLogic (buyable_items/sellable_stacks) so this stays a
## thin display over the testable helper — zero code change needed when
## ItemDB data grows (new seeds/tools with buy_price > 0 just show up).
##
## Sell affordance: a normal click sells ONE from the stack; holding Shift
## while clicking sells the WHOLE stack. Documented here and via the on-screen
## hint label since the placeholder UI has no icon space to spare for a
## second button per row.

enum Tab { BUY, SELL }

const ROW_HEIGHT := 24

## Price multiplier applied to every BUY row (World Stride B: Marta's L4/L7
## shop discount composed with World Stride D's Sowing Festival stall -20%,
## see npc.gd's _open_shop()/shop_discount()). 1.0 = no discount. The caller
## (npc.gd) sets this right before calling open() and it's read back to 1.0
## by close() so a later generic shopkeeper interaction (if any) never
## inherits a stale discount.
var discount := 1.0
## World Stride D: Marta's Sowing Festival plaza stall sells ONLY in-season
## (spring) seeds — set true by npc.gd right before open() for that specific
## flow, read back to false by close() same as `discount`.
var festival_seeds_only := false
var _tab := Tab.BUY
var gold_label: Label
var hint_label: Label
var buy_tab_btn: Button
var sell_tab_btn: Button
var buy_list: VBoxContainer
var sell_list: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("shop_screen")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-140, -110)
	panel.size = Vector2(280, 220)
	panel.add_theme_stylebox_override("panel", UITheme.panel_stylebox())
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 8)
	vbox.size = Vector2(264, 204)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var tab_theme := UITheme.button_theme()

	buy_tab_btn = Button.new()
	buy_tab_btn.text = "Buy"
	buy_tab_btn.toggle_mode = true
	buy_tab_btn.theme = tab_theme
	buy_tab_btn.pressed.connect(_on_buy_tab_pressed)
	header.add_child(buy_tab_btn)

	sell_tab_btn = Button.new()
	sell_tab_btn.text = "Sell"
	sell_tab_btn.toggle_mode = true
	sell_tab_btn.theme = tab_theme
	sell_tab_btn.pressed.connect(_on_sell_tab_pressed)
	header.add_child(sell_tab_btn)

	gold_label = Label.new()
	gold_label.custom_minimum_size = Vector2(100, 0)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	header.add_child(gold_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(264, 150)
	vbox.add_child(scroll)

	buy_list = VBoxContainer.new()
	buy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buy_list)

	sell_list = VBoxContainer.new()
	sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(sell_list)

	hint_label = Label.new()
	hint_label.text = "Click: buy/sell 1   Shift+Click (Sell tab): sell whole stack   Esc/Tab: close"
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(hint_label)

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	if is_open():
		return
	visible = true
	get_tree().paused = true
	_tab = Tab.BUY
	_refresh()


func close() -> void:
	if not is_open():
		return
	visible = false
	get_tree().paused = false
	discount = 1.0
	festival_seeds_only = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


func _on_money_changed(_gold) -> void:
	if is_open():
		_refresh_gold()


func _on_inventory_changed() -> void:
	if is_open() and _tab == Tab.SELL:
		_build_sell_rows()


func _on_buy_tab_pressed() -> void:
	_tab = Tab.BUY
	_refresh()


func _on_sell_tab_pressed() -> void:
	_tab = Tab.SELL
	_refresh()


func _refresh() -> void:
	_refresh_gold()
	buy_tab_btn.button_pressed = _tab == Tab.BUY
	sell_tab_btn.button_pressed = _tab == Tab.SELL
	buy_list.visible = _tab == Tab.BUY
	sell_list.visible = _tab == Tab.SELL
	_build_buy_rows()
	_build_sell_rows()


func _refresh_gold() -> void:
	gold_label.text = "%dg" % GameState.gold


func _clear(container: Node) -> void:
	# Free immediately (not queue_free): _refresh() can run twice in the same
	# frame (e.g. open() then a tab switch), and queue_free's deferred
	# removal would leave stale rows counted alongside the freshly built ones
	# until the frame ends.
	for child in container.get_children():
		container.remove_child(child)
		child.free()


func _build_buy_rows() -> void:
	_clear(buy_list)
	for item: ItemData in ShopLogic.buyable_items():
		if festival_seeds_only and not (item is SeedData):
			continue  # Sowing Festival stall: spring seeds only, no tools/sword (World Stride D)
		var price := ShopLogic.unit_price(item.buy_price, discount)
		var row := _make_row(item.icon, "%s — %dg" % [item.display_name, price])
		row.pressed.connect(_on_buy_pressed.bind(item.id))
		buy_list.add_child(row)


func _build_sell_rows() -> void:
	_clear(sell_list)
	for entry: Dictionary in ShopLogic.sellable_stacks():
		var item := ItemDB.get_item(entry["id"])
		var row := _make_row(item.icon,
			"%s x%d — %dg ea" % [item.display_name, entry["count"], item.sell_price])
		row.pressed.connect(_on_sell_pressed.bind(item.id))
		sell_list.add_child(row)


func _make_row(icon: Texture2D, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon
	btn.custom_minimum_size = Vector2(260, ROW_HEIGHT)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.theme = UITheme.button_theme()
	return btn


func _on_buy_pressed(item_id: String) -> void:
	var result := ShopLogic.buy(item_id, 1, discount)
	match result:
		ShopLogic.Result.INSUFFICIENT_GOLD:
			EventBus.toast_requested.emit("Not enough gold")
		ShopLogic.Result.INVENTORY_FULL:
			EventBus.toast_requested.emit("Inventory full")
		ShopLogic.Result.OK:
			var data := ItemDB.get_item(item_id)
			EventBus.toast_requested.emit("Bought %s" % data.display_name)
	_refresh()


func _on_sell_pressed(item_id: String) -> void:
	var shift_held := Input.is_key_pressed(KEY_SHIFT)
	var count := 1
	if shift_held:
		count = Inventory.count_of(item_id)
	var result := ShopLogic.sell(item_id, count)
	match result:
		ShopLogic.Result.OK:
			var data := ItemDB.get_item(item_id)
			EventBus.toast_requested.emit("Sold %d× %s" % [count, data.display_name])
		ShopLogic.Result.UNSELLABLE:
			EventBus.toast_requested.emit("Can't sell that")
		ShopLogic.Result.NOTHING_TO_SELL:
			EventBus.toast_requested.emit("Nothing to sell")
	_refresh()
