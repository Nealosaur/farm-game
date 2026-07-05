extends GutTest
## Shopkeeper interact() gate: open hours show the dialog which then opens
## the shop; closed hours toast instead and the sprite is hidden.

var shopkeeper: Area2D
var dialog: DialogBox
var shop: ShopScreen
var _clock_minutes_before: int


func before_each() -> void:
	_clock_minutes_before = Clock.minutes
	shopkeeper = (load("res://scripts/town/shopkeeper.gd") as GDScript).new()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	shopkeeper.add_child(sprite)
	add_child_autofree(shopkeeper)

	dialog = (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	shop = (load("res://scripts/ui/shop_screen.gd") as GDScript).new() as ShopScreen
	add_child_autofree(shop)


func after_each() -> void:
	Clock.minutes = _clock_minutes_before
	get_tree().paused = false


func _set_hour(h: int) -> void:
	Clock.minutes = h * 60


func test_sprite_visible_during_open_hours() -> void:
	_set_hour(12)
	shopkeeper._refresh_visibility()
	assert_true(shopkeeper.sprite.visible)


func test_sprite_hidden_outside_open_hours() -> void:
	_set_hour(20)
	shopkeeper._refresh_visibility()
	assert_false(shopkeeper.sprite.visible)


func test_interact_outside_hours_toasts_and_does_not_open_dialog() -> void:
	_set_hour(20)
	watch_signals(EventBus)
	shopkeeper.interact(null)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["Shop's closed. (9 AM - 5 PM)"])
	assert_false(dialog.is_open())
	assert_false(shop.is_open())


func test_interact_during_hours_opens_dialog_with_greeting() -> void:
	_set_hour(10)
	shopkeeper.interact(null)
	assert_true(dialog.is_open())
	assert_false(shop.is_open(), "shop should not open until the dialog finishes")


func test_dialog_finishing_opens_shop() -> void:
	_set_hour(10)
	shopkeeper.interact(null)
	assert_true(dialog.is_open())
	# Advance through every greeting line.
	for i in shopkeeper.GREETING.size():
		dialog._advance()
	assert_false(dialog.is_open())
	assert_true(shop.is_open(), "shop should open once the greeting dialog finishes")
