class_name Player
extends CharacterBody2D
## Farm player. Origin = feet. States: Idle, Move, UseTool (combat in Plan 3).

const SPEED := 80.0
const ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"use_down", "use_up", "use_left", "use_right",
]

var facing := Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var machine: StateMachine = $StateMachine
@onready var interact_zone: Area2D = $InteractZone


func _ready() -> void:
	add_to_group("player")
	var tex := load("res://assets/placeholder/char_player.png") as Texture2D
	sprite.sprite_frames = PlaceholderFrames.build(tex, PackedStringArray(ANIM_NAMES))
	sprite.play("idle_down")
	($Collision as CollisionShape2D).shape = RectangleShape2D.new()
	(($Collision as CollisionShape2D).shape as RectangleShape2D).size = Vector2(10, 6)
	($Collision as CollisionShape2D).position = Vector2(0, -3)
	var zone_shape := CircleShape2D.new()
	zone_shape.radius = 10.0
	($InteractZone/ZoneShape as CollisionShape2D).shape = zone_shape
	interact_zone.position = Vector2(facing) * 12.0


static func facing_from(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i.RIGHT if dir.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if dir.y > 0 else Vector2i.UP


static func facing_to_name(f: Vector2i) -> String:
	match f:
		Vector2i.UP: return "up"
		Vector2i.LEFT: return "left"
		Vector2i.RIGHT: return "right"
		_: return "down"


func facing_name() -> String:
	return facing_to_name(facing)


func move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func update_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		facing = facing_from(dir)
		interact_zone.position = Vector2(facing) * 12.0


func cell() -> Vector2i:
	return MapBuilder.cell_of(global_position)


func target_cell() -> Vector2i:
	return cell() + facing


func play_anim(prefix: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return  # StateMachine child _ready() can fire before our own _ready() sets frames.
	sprite.play(prefix + "_" + facing_name())


func _farm_grid() -> Node:
	return get_tree().get_first_node_in_group("farm_grid")


func try_use_selected() -> void:
	var data := Inventory.get_selected_item_data()
	if data == null:
		return
	if data is ToolData:
		_use_tool(data)
	elif data is SeedData:
		_plant(data)
	elif data is FoodData:
		_eat(data)


func _use_tool(tool_data: ToolData) -> void:
	var grid := _farm_grid()
	match tool_data.tool_type:
		ToolData.ToolType.HOE:
			if grid != null and grid.till(target_cell()):
				GameState.spend_rp(tool_data.rp_cost)
				machine.transition("UseTool")
		ToolData.ToolType.WATERING_CAN:
			if grid != null and grid.water(target_cell()):
				GameState.spend_rp(tool_data.rp_cost)
				machine.transition("UseTool")
		ToolData.ToolType.SWORD:
			# Plan 2: swing costs RP and animates; hitboxes land in Plan 3.
			GameState.spend_rp(tool_data.rp_cost)
			machine.transition("UseTool")


func _plant(seed_data: SeedData) -> void:
	var grid := _farm_grid()
	if grid != null and grid.plant(target_cell(), seed_data.crop_id):
		Inventory.remove_item(seed_data.id, 1)
		machine.transition("UseTool")


func _eat(food: FoodData) -> void:
	if not Inventory.remove_item(food.id, 1):
		return
	GameState.restore_rp(food.rp_restore)
	if food.hp_restore > 0:
		GameState.heal(food.hp_restore)
	EventBus.toast_requested.emit("Ate %s (+%d RP)" % [food.display_name, food.rp_restore])


func try_interact() -> void:
	var grid := _farm_grid()
	if grid != null:
		var product: String = grid.peek_harvest(target_cell())
		if product != "":
			if Inventory.add_item(product) == 0:
				grid.clear_crop(target_cell())
				EventBus.toast_requested.emit("+1 " + ItemDB.get_item(product).display_name)
			else:
				EventBus.toast_requested.emit("Inventory full!")
			return
	for area in interact_zone.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return
