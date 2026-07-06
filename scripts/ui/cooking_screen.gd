class_name CookingScreen
extends CanvasLayer
## Kitchen prop's Cooking UI (Craft Stride 1), opened by kitchen.gd. Tree-
## paused while open (menu convention — see ShopScreen/InventoryScreen). Esc
## ("pause") or Tab ("inventory") closes it.
##
## Data comes from CookingLogic (all_recipes/can_cook/cook) so this stays a
## thin display over the testable helper — zero code change needed when
## ItemDB recipes grow.

var recipe_list: VBoxContainer
var _rows: Dictionary = {}  # recipe.id -> row Control, for targeted refresh


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("cooking_screen")
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
	title.text = "Cooking"
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 200)
	vbox.add_child(scroll)

	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipe_list)

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
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.free()
	_rows = {}
	for recipe: RecipeData in CookingLogic.all_recipes():
		var row := _make_row(recipe)
		recipe_list.add_child(row)
		_rows[recipe.id] = row
	_refresh_rows()


func _make_row(recipe: RecipeData) -> Control:
	var box := VBoxContainer.new()
	box.name = "Row_" + recipe.id

	var header := HBoxContainer.new()
	header.name = "Header"
	box.add_child(header)

	var result := ItemDB.get_item(recipe.result_id)
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = result.display_name if result != null else recipe.result_id
	name_label.custom_minimum_size = Vector2(110, 0)
	header.add_child(name_label)

	var effect_label := Label.new()
	effect_label.name = "EffectLabel"
	effect_label.text = _effect_summary(result as FoodData)
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.custom_minimum_size = Vector2(100, 0)
	header.add_child(effect_label)

	var cook_btn := Button.new()
	cook_btn.name = "CookButton"
	cook_btn.text = "Cook"
	cook_btn.pressed.connect(_on_cook_pressed.bind(recipe.id))
	header.add_child(cook_btn)

	var ing_label := RichTextLabel.new()
	ing_label.name = "IngredientsLabel"
	ing_label.bbcode_enabled = true
	ing_label.fit_content = true
	ing_label.scroll_active = false
	ing_label.add_theme_font_size_override("normal_font_size", 10)
	box.add_child(ing_label)

	return box


func _effect_summary(food: FoodData) -> String:
	if food == null:
		return ""
	var parts := PackedStringArray()
	if food.rp_restore > 0:
		parts.append("+%d RP" % food.rp_restore)
	if food.hp_restore > 0:
		parts.append("+%d HP" % food.hp_restore)
	if food.attack_bonus > 0:
		parts.append("+%d ATK" % food.attack_bonus)
	return ", ".join(parts)


func _refresh_rows() -> void:
	for recipe: RecipeData in CookingLogic.all_recipes():
		var row: VBoxContainer = _rows.get(recipe.id)
		if row == null:
			continue
		var cook_btn := row.get_node("Header/CookButton") as Button
		cook_btn.disabled = not CookingLogic.can_cook(recipe)
		var ing_label := row.get_node("IngredientsLabel") as RichTextLabel
		ing_label.text = _ingredients_bbcode(recipe)


func _ingredients_bbcode(recipe: RecipeData) -> String:
	## have/need counts colored per-ingredient: green when the player has
	## enough, red (the "need" color) when short (bible: "ingredients with
	## have/need counts colored").
	var parts := PackedStringArray()
	var ids := recipe.ingredients.keys()
	ids.sort()
	for item_id: String in ids:
		var need: int = int(recipe.ingredients[item_id])
		var have := Inventory.count_of(item_id)
		var item := ItemDB.get_item(item_id)
		var label := item.display_name if item != null else item_id
		var color := "80e080" if have >= need else "e08080"
		parts.append("%s [color=#%s]%d/%d[/color]" % [label, color, have, need])
	return "Needs: " + ", ".join(parts)


func _on_cook_pressed(recipe_id: String) -> void:
	var recipe := ItemDB.get_recipe(recipe_id)
	if recipe == null:
		return
	var result := CookingLogic.cook(recipe)
	match result:
		CookingLogic.Result.OK:
			var data := ItemDB.get_item(recipe.result_id)
			EventBus.toast_requested.emit("Cooked %s" % data.display_name)
		CookingLogic.Result.MISSING_INGREDIENTS:
			EventBus.toast_requested.emit("Missing ingredients")
		CookingLogic.Result.INVENTORY_FULL:
			EventBus.toast_requested.emit("Inventory full")
	_refresh_rows()
