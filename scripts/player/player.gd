class_name Player
extends CharacterBody2D
## Farm player. Origin = feet. States: Idle, Move, UseTool, Swing, Dodge, Hurt.
## Player has no HealthComponent — GameState owns player HP.

const SPEED := 80.0
const ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"use_down", "use_up", "use_left", "use_right",
]

## Facing indicator: a small darker rect that hugs whichever edge of the
## sprite's bounding box faces the player's current direction — the cheapest
## legible "which way am I facing" read without new art. Sprite bounding box
## in Player-local space: offset (0, -12), size (16, 32) -> x in [-8, 8],
## y in [-28, 4]. Repositioned (not re-parented/rotated) in update_facing().
const FACING_INDICATOR_SIZE := Vector2(4, 3)
const FACING_INDICATOR_INSET := 2.0  # pulled in from the sprite edge, not flush
const SPRITE_HALF_WIDTH := 8.0
const SPRITE_TOP := -28.0
const SPRITE_BOTTOM := 4.0
const SPRITE_CENTER_Y := -12.0

var facing := Vector2i.DOWN

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var machine: StateMachine = $StateMachine
@onready var interact_zone: Area2D = $InteractZone
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var sword_hitbox: HitboxComponent = $SwordHitbox

var _facing_indicator: ColorRect


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

	collision_layer = Layers.bit(Layers.PLAYER_BODY)
	collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.ENEMY_BODY)

	(hurtbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((hurtbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(12, 10)
	hurtbox.position = Vector2(0, -6)
	hurtbox.collision_layer = Layers.bit(Layers.PLAYER_HURTBOX)
	hurtbox.collision_mask = Layers.bit(Layers.ENEMY_HITBOX)
	hurtbox.hit_taken.connect(_on_hurtbox_hit_taken)

	(sword_hitbox.get_node("Shape") as CollisionShape2D).shape = RectangleShape2D.new()
	((sword_hitbox.get_node("Shape") as CollisionShape2D).shape as RectangleShape2D).size = Vector2(16, 16)
	sword_hitbox.collision_layer = Layers.bit(Layers.PLAYER_HITBOX)
	sword_hitbox.collision_mask = Layers.bit(Layers.ENEMY_HURTBOX)
	sword_hitbox.set_active(false)

	_facing_indicator = ColorRect.new()
	_facing_indicator.color = Color("b08050").darkened(0.4)
	_facing_indicator.size = FACING_INDICATOR_SIZE
	_facing_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_facing_indicator)
	_position_facing_indicator()


func _on_hurtbox_hit_taken(damage: int, knockback: Vector2) -> void:
	GameState.take_damage(damage)
	EventBus.camera_shake.emit(CameraShake.DEFAULT_STRENGTH)
	var hurt := machine.get_node_or_null("Hurt") as PlayerHurt
	if hurt != null:
		hurt.incoming_knockback = knockback
	machine.transition("Hurt")


func try_dodge() -> void:
	var dodge := machine.get_node_or_null("Dodge") as PlayerDodge
	if dodge == null:
		return
	if not GameState.try_spend_rp(PlayerDodge.RP_COST):
		return  # try_spend_rp fails silently (no cost) when RP is fully empty
	machine.transition("Dodge")


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
		_position_facing_indicator()


func _position_facing_indicator() -> void:
	if _facing_indicator == null:
		return
	var half := FACING_INDICATOR_SIZE / 2.0
	var center := Vector2.ZERO
	match facing:
		Vector2i.UP:
			center = Vector2(0, SPRITE_TOP + FACING_INDICATOR_INSET)
		Vector2i.DOWN:
			center = Vector2(0, SPRITE_BOTTOM - FACING_INDICATOR_INSET)
		Vector2i.LEFT:
			center = Vector2(-SPRITE_HALF_WIDTH + FACING_INDICATOR_INSET, SPRITE_CENTER_Y)
		Vector2i.RIGHT:
			center = Vector2(SPRITE_HALF_WIDTH - FACING_INDICATOR_INSET, SPRITE_CENTER_Y)
	_facing_indicator.position = center - half


func cell() -> Vector2i:
	return MapBuilder.cell_of(global_position)


func target_cell() -> Vector2i:
	return cell() + facing


func play_anim(prefix: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return  # StateMachine child _ready() can fire before our own _ready() sets frames.
	sprite.play(prefix + "_" + facing_name())


func _farm_grid() -> FarmGrid:
	return get_tree().get_first_node_in_group("farm_grid") as FarmGrid


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
			# Craft Stride 2: water_width > 1 (Copper Watering Can) also waters
			# the flanking cells perpendicular to facing — RP is still spent
			# exactly ONCE per swing, on success of ANY cell (see
			# FarmGrid.water_wide()'s doc).
			if grid != null and grid.water_wide(target_cell(), facing, tool_data.water_width):
				GameState.spend_rp(tool_data.rp_cost)
				machine.transition("UseTool")
		ToolData.ToolType.SWORD:
			var swing := machine.get_node_or_null("Swing") as PlayerSwing
			if swing == null:
				return
			if machine.current == swing:
				swing.buffer_next()
			else:
				GameState.spend_rp(tool_data.rp_cost)
				swing.begin_swing(tool_data)
				machine.transition("Swing")


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
	if food.attack_bonus > 0:
		GameState.set_temp_attack(food.attack_bonus)
	var msg := "Ate %s (+%d RP)" % [food.display_name, food.rp_restore]
	if food.attack_bonus > 0:
		msg += " (+%d ATK until sleep)" % food.attack_bonus
	EventBus.toast_requested.emit(msg)


func try_interact() -> void:
	var grid := _farm_grid()
	if grid != null:
		var product: String = grid.peek_harvest(target_cell())
		if product != "":
			if Inventory.add_item(product) == 0:
				# FarmGrid owns the clear-vs-regrow decision (World Stride A);
				# harvest() only commits AFTER the item fit in the inventory,
				# so a full inventory leaves the crop ripe and untouched.
				grid.harvest(target_cell())
				EventBus.toast_requested.emit("+1 " + ItemDB.get_item(product).display_name)
			else:
				EventBus.toast_requested.emit("Inventory full!")
			return
	for area in interact_zone.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)
			return
