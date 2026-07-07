extends GutTest
## Craft Stride 2: ForgeScreen — open/close pause behavior, upgrade rows
## reflect ForgeLogic (thin-UI contract) including the hidden-fangsteel gate,
## Forge button enabled iff affordable, forging consumes+grants, and Esc/Tab
## closes. Mirrors test_cooking_screen.gd's structure.

var screen: ForgeScreen


func before_each() -> void:
	GameState.reset_new_game()
	Inventory.reset()
	GameState.flags = {}
	screen = (load("res://scripts/ui/forge_screen.gd") as GDScript).new() as ForgeScreen
	add_child_autofree(screen)


func after_each() -> void:
	GameState.flags = {}
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


func test_rows_match_visible_upgrades_and_hide_fangsteel() -> void:
	screen.open()
	assert_eq(screen.upgrade_list.get_child_count(), ForgeLogic.visible_upgrades().size())
	assert_eq(screen.upgrade_list.get_child_count(), 2, "steel + copper only before the scene")
	assert_null(screen.upgrade_list.get_node_or_null("Row_fangsteel_blade"))


func test_fangsteel_row_appears_once_masterwork_flag_set() -> void:
	GameState.flags["sten_masterwork_done"] = true
	screen.open()
	assert_eq(screen.upgrade_list.get_child_count(), 3)
	assert_not_null(screen.upgrade_list.get_node_or_null("Row_fangsteel_blade"))


func test_forge_button_disabled_when_unaffordable() -> void:
	screen.open()
	var row := screen.upgrade_list.get_node("Row_steel_sword")
	# UI skin pass: row is now a PanelContainer (carries the slot ninepatch
	# background) wrapping an inner "VBox" — see forge_screen.gd's _make_row().
	var btn := row.get_node("VBox/Header/ForgeButton") as Button
	assert_true(btn.disabled)


func test_forge_button_enabled_when_everything_present() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800
	screen.open()
	var row := screen.upgrade_list.get_node("Row_steel_sword")
	# UI skin pass: row is now a PanelContainer (carries the slot ninepatch
	# background) wrapping an inner "VBox" — see forge_screen.gd's _make_row().
	var btn := row.get_node("VBox/Header/ForgeButton") as Button
	assert_false(btn.disabled)


func test_forging_consumes_and_grants_through_the_screen() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800
	screen.open()
	screen._on_forge_pressed("steel_sword")
	assert_eq(Inventory.count_of("iron_sword"), 0)
	assert_eq(Inventory.count_of("goblin_fang"), 0)
	assert_eq(GameState.gold, 0)
	assert_eq(Inventory.count_of("steel_sword"), 1)


func test_forging_refreshes_button_state_after_consuming() -> void:
	Inventory.add_item("iron_sword", 1)
	Inventory.add_item("goblin_fang", 3)
	GameState.gold = 800
	screen.open()
	screen._on_forge_pressed("steel_sword")
	var row := screen.upgrade_list.get_node("Row_steel_sword")
	# UI skin pass: row is now a PanelContainer (carries the slot ninepatch
	# background) wrapping an inner "VBox" — see forge_screen.gd's _make_row().
	var btn := row.get_node("VBox/Header/ForgeButton") as Button
	assert_true(btn.disabled, "materials now gone, button should re-disable")


func test_pause_action_closes_forge_screen() -> void:
	screen.open()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_false(screen.is_open())


func test_inventory_action_closes_forge_screen() -> void:
	screen.open()
	var ev := InputEventAction.new()
	ev.action = "inventory"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_false(screen.is_open())
