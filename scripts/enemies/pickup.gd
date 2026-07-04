class_name Pickup
extends Area2D
## A dropped material item. Drifts toward the player when within DRIFT_RANGE,
## collected on touch (adds to Inventory + toast), despawns after LIFETIME.

const DRIFT_RANGE := 24.0
const DRIFT_SPEED := 60.0
const LIFETIME := 60.0
const COLLECT_RANGE := 6.0

@export var item_id: String = ""

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	add_to_group("pickup")
	if item_id != "":
		var data := ItemDB.get_item(item_id)
		if data != null:
			sprite.texture = data.icon
	collision_layer = 0
	collision_mask = 0
	get_tree().create_timer(LIFETIME).timeout.connect(_on_lifetime_expired)


func _on_lifetime_expired() -> void:
	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	if dist <= COLLECT_RANGE:
		_collect()
		return
	if dist <= DRIFT_RANGE:
		global_position += to_player.normalized() * DRIFT_SPEED * delta


func _collect() -> void:
	if item_id != "":
		Inventory.add_item(item_id)
		var data := ItemDB.get_item(item_id)
		EventBus.toast_requested.emit("+1 " + (data.display_name if data != null else item_id))
	queue_free()
