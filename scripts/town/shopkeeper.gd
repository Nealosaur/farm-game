extends Area2D
## Interactable NPC (same shape as bed.gd/shipping_bin.gd): stands at the
## town shop counter. interact(player) checks store hours (ShopLogic.is_open)
## — open hours show a short greeting via DialogBox, then open ShopScreen
## when the dialog finishes; outside hours, a toast only.
##
## "Absent visual" outside hours: simplest option per the spec — the sprite
## is hidden (no despawn/respawn bookkeeping needed) and interact() still
## replies with the closed-hours toast so clicking the counter area isn't a
## silent dead end.

const GREETING: Array[String] = [
	"Welcome! Buy seeds, sell your harvest.",
]

var sprite: Sprite2D


func _ready() -> void:
	EventBus.time_ticked.connect(_on_time_ticked)
	EventBus.day_passed.connect(_on_day_passed)
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	_refresh_visibility()


func _on_time_ticked(_hour, _minute) -> void:
	_refresh_visibility()


func _on_day_passed(_day) -> void:
	_refresh_visibility()


func _refresh_visibility() -> void:
	if sprite != null:
		sprite.visible = ShopLogic.is_open(Clock.hour())


func interact(_player) -> void:
	if not ShopLogic.is_open(Clock.hour()):
		EventBus.toast_requested.emit("Shop's closed. (9 AM - 5 PM)")
		return
	var dialog := get_tree().get_first_node_in_group("dialog_box")
	var shop := get_tree().get_first_node_in_group("shop_screen")
	if dialog == null or shop == null:
		EventBus.toast_requested.emit("(shop UI unavailable)")
		return
	if dialog.is_open() or shop.is_open():
		return
	if not dialog.finished.is_connected(shop.open):
		dialog.finished.connect(shop.open, CONNECT_ONE_SHOT)
	dialog.show_lines(GREETING.duplicate())
