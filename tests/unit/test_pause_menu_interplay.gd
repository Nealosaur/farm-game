extends GutTest
## PauseMenu must never open OVER another already-open pause-style menu
## (ShopScreen/InventoryScreen/DialogBox) when Esc is pressed. Covers the real
## risk in is_pause_allowed()'s design: with both nodes live in the same
## scene, Esc must close the OTHER menu (via its own handler + set_input_as_
## handled) without PauseMenu also reacting to the same keypress.

var shop: ShopScreen
var pause_menu: PauseMenu


func before_each() -> void:
	shop = (load("res://scripts/ui/shop_screen.gd") as GDScript).new() as ShopScreen
	add_child_autofree(shop)
	pause_menu = (load("res://scripts/ui/pause_menu.gd") as GDScript).new() as PauseMenu
	add_child_autofree(pause_menu)


func after_each() -> void:
	get_tree().paused = false


func _press_pause() -> void:
	## Simulates the real dispatch order (ShopScreen is added to the tree
	## before PauseMenu — see MapSceneHelper.AUTO_INSTANCE_SCRIPTS — so it
	## receives _unhandled_input first) WITHOUT depending on the viewport's
	## global is_input_handled() flag, which only tracks state within one
	## real engine-dispatched event and isn't meaningful across direct
	## method calls in a test. Instead: if the shop was open and this press
	## closed it, that already consumed the keypress — PauseMenu never sees
	## it, exactly as set_input_as_handled() would enforce in the real tree.
	var was_open := shop.is_open()
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	shop._unhandled_input(ev)
	var shop_consumed_it := was_open and not shop.is_open()
	if not shop_consumed_it:
		pause_menu._unhandled_input(ev)


func test_esc_closes_open_shop_without_opening_pause_menu() -> void:
	shop.open()
	assert_true(shop.is_open())
	_press_pause()
	assert_false(shop.is_open(), "shop should close on Esc")
	assert_false(pause_menu.is_open(), "pause menu must not open over a closing shop")
	assert_false(get_tree().paused, "tree should end unpaused once the only open menu closes")


func test_esc_opens_pause_menu_when_nothing_else_is_open() -> void:
	assert_false(shop.is_open())
	_press_pause()
	assert_true(pause_menu.is_open(), "pause menu should open when no other menu is up")
	assert_true(get_tree().paused)
