extends GutTest
## Craft Stride 1: CookingScreen — open/close pause behavior, recipe rows
## reflect CookingLogic (thin-UI contract), Cook button enabled iff
## ingredients present, and Esc/Tab closes.

var screen: CookingScreen


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	screen = (load("res://scripts/ui/cooking_screen.gd") as GDScript).new() as CookingScreen
	add_child_autofree(screen)


func after_each() -> void:
	get_tree().paused = false


func test_open_pauses_tree() -> void:
	screen.open()
	assert_true(screen.is_open())
	assert_true(get_tree().paused)


func test_close_unpauses_tree() -> void:
	screen.open()
	screen.close()
	assert_false(screen.is_open())
	assert_false(get_tree().paused)


func test_recipe_rows_match_all_recipes() -> void:
	screen.open()
	assert_eq(screen.recipe_list.get_child_count(), CookingLogic.all_recipes().size())
	assert_eq(screen.recipe_list.get_child_count(), 8)


func test_cook_button_disabled_when_missing_ingredients() -> void:
	screen.open()
	# UI skin pass: row is now a PanelContainer (carries the slot ninepatch
	# background) wrapping an inner "VBox" so Header/IngredientsLabel can
	# still stack vertically — see cooking_screen.gd's _make_row() comment.
	var row := screen.recipe_list.get_node("Row_roast_turnip")
	var btn := row.get_node("VBox/Header/CookButton") as Button
	assert_true(btn.disabled)


func test_cook_button_enabled_when_ingredients_present() -> void:
	Inventory.add_item("turnip", 2)
	screen.open()
	var row := screen.recipe_list.get_node("Row_roast_turnip")
	var btn := row.get_node("VBox/Header/CookButton") as Button
	assert_false(btn.disabled)


func test_cooking_consumes_ingredients_and_adds_dish() -> void:
	Inventory.add_item("turnip", 2)
	screen.open()
	screen._on_cook_pressed("roast_turnip")
	assert_eq(Inventory.count_of("turnip"), 0)
	assert_eq(Inventory.count_of("roast_turnip"), 1)


func test_cooking_refreshes_button_state_after_consuming() -> void:
	Inventory.add_item("turnip", 2)
	screen.open()
	screen._on_cook_pressed("roast_turnip")
	var row := screen.recipe_list.get_node("Row_roast_turnip")
	var btn := row.get_node("VBox/Header/CookButton") as Button
	assert_true(btn.disabled, "ingredients now gone, button should re-disable")


func test_pause_action_closes_cooking_screen() -> void:
	screen.open()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_false(screen.is_open())


func test_inventory_action_closes_cooking_screen() -> void:
	screen.open()
	var ev := InputEventAction.new()
	ev.action = "inventory"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_false(screen.is_open())
