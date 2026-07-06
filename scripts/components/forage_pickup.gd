class_name ForagePickup
extends Area2D
## A single daily forage spawn (World Stride C): small Area2D, interact() adds
## `item_id` to Inventory and records itself taken in the map's Forage blob.
## Inventory-full (Inventory.add_item returns > 0 leftover) leaves the pickup
## in place with a toast, matching the contract's "stays" wording — the node
## does NOT free itself in that case, so the player can drop something and
## come back same day.
##
## Map scripts build one of these per rolled cell (see riverwoods.gd/beach.gd)
## and are responsible for NOT building one at all for cells already marked
## taken in today's Forage blob (so a picked spawn doesn't reappear on map
## rebuild the same day).

const SIZE := Vector2(12, 12)

var map_id := ""
var item_id := ""
var cell := Vector2i.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0


func interact(_player: Node) -> void:
	var data := ItemDB.get_item(item_id)
	if data == null:
		push_warning("ForagePickup: unknown item id " + item_id)
		return
	var leftover := Inventory.add_item(item_id, 1)
	if leftover > 0:
		EventBus.toast_requested.emit("Inventory full")
		return
	var blob: Dictionary = SaveManager.world.get("forage", {})
	var map_blob: Dictionary = Forage.ensure_day(blob.get(map_id, {}), Clock.day)
	map_blob = Forage.record_taken(map_blob, cell)
	blob[map_id] = map_blob
	SaveManager.world["forage"] = blob
	EventBus.toast_requested.emit("Picked up " + data.display_name)
	queue_free()


static func make(map_id_: String, item_id_: String, cell_: Vector2i) -> ForagePickup:
	var pickup := ForagePickup.new()
	pickup.name = "Forage_%s_%d_%d" % [item_id_, cell_.x, cell_.y]
	pickup.map_id = map_id_
	pickup.item_id = item_id_
	pickup.cell = cell_
	pickup.position = MapBuilder.cell_center(cell_)
	var sprite := Sprite2D.new()
	var icon_path := "res://assets/placeholder/item_%s.png" % item_id_
	if ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	pickup.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	col.shape = shape
	pickup.add_child(col)
	return pickup
