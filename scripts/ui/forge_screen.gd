class_name ForgeScreen
extends CanvasLayer
## Sten's smithy Forge UI (Craft Stride 2), opened via NPC.gd's "Forge"
## dialog choice. Tree-paused while open (menu convention — see ShopScreen/
## CookingScreen). Esc ("pause") or Tab ("inventory") closes it.
##
## Data comes from ForgeLogic (visible_upgrades/can_afford/upgrade) so this
## stays a thin display over the testable helper (mirrors CookingScreen's
## shape exactly) — zero code change needed when ForgeLogic.UPGRADES grows.

var upgrade_list: VBoxContainer
var _rows: Dictionary = {}  # upgrade id -> row Control, for targeted refresh


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("forge_screen")
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -130)
	panel.size = Vector2(320, 260)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(8, 8)
	vbox.size = Vector2(304, 244)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Forge"
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 200)
	vbox.add_child(scroll)

	upgrade_list = VBoxContainer.new()
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(upgrade_list)

	var hint_label := Label.new()
	hint_label.text = "Esc/Tab: close"
	hint_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint_label)

	EventBus.inventory_changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	if is_open():
		return
	visible = true
	get_tree().paused = true
	_build_rows()


func close() -> void:
	if not is_open():
		return
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


func _on_inventory_changed() -> void:
	if is_open():
		_refresh_rows()


func _build_rows() -> void:
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.free()
	_rows = {}
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		var row := _make_row(upgrade)
		upgrade_list.add_child(row)
		_rows[upgrade["id"]] = row
	_refresh_rows()


func _make_row(upgrade: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.name = "Row_" + String(upgrade["id"])

	var header := HBoxContainer.new()
	header.name = "Header"
	box.add_child(header)

	var result := ItemDB.get_item(String(upgrade["result_id"]))
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = result.display_name if result != null else String(upgrade["result_id"])
	name_label.custom_minimum_size = Vector2(140, 0)
	header.add_child(name_label)

	var forge_btn := Button.new()
	forge_btn.name = "ForgeButton"
	forge_btn.text = "Forge"
	forge_btn.pressed.connect(_on_forge_pressed.bind(String(upgrade["id"])))
	header.add_child(forge_btn)

	var cost_label := RichTextLabel.new()
	cost_label.name = "CostLabel"
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.scroll_active = false
	cost_label.add_theme_font_size_override("normal_font_size", 10)
	box.add_child(cost_label)

	return box


func _refresh_rows() -> void:
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		var id := String(upgrade["id"])
		var row: VBoxContainer = _rows.get(id)
		if row == null:
			continue
		var forge_btn := row.get_node("Header/ForgeButton") as Button
		forge_btn.disabled = not ForgeLogic.can_afford(upgrade)
		var cost_label := row.get_node("CostLabel") as RichTextLabel
		cost_label.text = _cost_bbcode(upgrade)


func _cost_bbcode(upgrade: Dictionary) -> String:
	## have/need counts colored per-requirement (old tool, each material, and
	## gold) — same "green if enough, red if short" convention as
	## CookingScreen._ingredients_bbcode().
	var parts := PackedStringArray()
	var old_tool := String(upgrade.get("old_tool", ""))
	if old_tool != "":
		var tool_item := ItemDB.get_item(old_tool)
		var label := tool_item.display_name if tool_item != null else old_tool
		var have := Inventory.count_of(old_tool)
		var color := "80e080" if have >= 1 else "e08080"
		parts.append("%s [color=#%s]%d/1[/color]" % [label, color, have])
	var materials: Dictionary = upgrade.get("materials", {})
	var ids := materials.keys()
	ids.sort()
	for item_id: String in ids:
		var need: int = int(materials[item_id])
		var have := Inventory.count_of(item_id)
		var item := ItemDB.get_item(item_id)
		var label := item.display_name if item != null else item_id
		var color := "80e080" if have >= need else "e08080"
		parts.append("%s [color=#%s]%d/%d[/color]" % [label, color, have, need])
	var gold_cost := int(upgrade.get("gold", 0))
	var gold_color := "80e080" if GameState.gold >= gold_cost else "e08080"
	parts.append("[color=#%s]%dg[/color]" % [gold_color, gold_cost])
	return "Needs: " + ", ".join(parts)


func _on_forge_pressed(upgrade_id: String) -> void:
	var upgrade := ForgeLogic.get_upgrade(upgrade_id)
	var result := ForgeLogic.upgrade(upgrade_id)
	match result:
		ForgeLogic.Result.OK:
			var data := ItemDB.get_item(String(upgrade.get("result_id", "")))
			EventBus.toast_requested.emit("Forged %s" % (data.display_name if data != null else upgrade_id))
		ForgeLogic.Result.MISSING_OLD_TOOL:
			EventBus.toast_requested.emit("Missing the tool to upgrade")
		ForgeLogic.Result.MISSING_MATERIALS:
			EventBus.toast_requested.emit("Missing materials")
		ForgeLogic.Result.INSUFFICIENT_GOLD:
			EventBus.toast_requested.emit("Not enough gold")
		ForgeLogic.Result.HIDDEN:
			EventBus.toast_requested.emit("Not available yet")
	_build_rows()
