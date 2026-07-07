extends GutTest
## Milestone-review fix: InventoryScreen must NOT open over another modal that
## already holds the tree paused (opening then closing would unpause the world
## under that still-open modal). Mirrors the pause-menu gate.

var screen: InventoryScreen


func before_each() -> void:
	get_tree().paused = false
	GameFlow.cutscene_active = false
	screen = (load("res://scripts/ui/inventory_screen.gd") as GDScript).new() as InventoryScreen
	add_child_autofree(screen)


func after_each() -> void:
	get_tree().paused = false
	GameFlow.cutscene_active = false


func _press_inventory() -> void:
	var ev := InputEventAction.new()
	ev.action = "inventory"
	ev.pressed = true
	screen._unhandled_input(ev)


func test_opens_normally_when_nothing_else_is_paused() -> void:
	assert_false(screen.is_open())
	_press_inventory()
	assert_true(screen.is_open(), "inventory opens when the world is running")
	assert_true(get_tree().paused, "opening the inventory pauses the tree")


func test_closing_itself_still_works() -> void:
	_press_inventory()
	assert_true(screen.is_open())
	_press_inventory()
	assert_false(screen.is_open(), "pressing inventory again closes it")
	assert_false(get_tree().paused, "closing the inventory unpauses the tree")


func test_refuses_to_open_over_another_modal() -> void:
	# Simulate another modal (shop/fishing/etc.) already holding the tree paused.
	get_tree().paused = true
	_press_inventory()
	assert_false(screen.is_open(),
		"inventory must not open on top of a modal that already paused the tree")
	assert_true(get_tree().paused,
		"the other modal's pause is left intact (never unpaused out from under it)")


func test_refuses_to_open_mid_cutscene() -> void:
	GameFlow.cutscene_active = true
	_press_inventory()
	assert_false(screen.is_open(), "inventory must not open during a cutscene")
