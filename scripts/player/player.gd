class_name Player
extends CharacterBody2D
## Farm player. Origin = feet. States: Idle, Move, UseTool, Swing, Dodge, Hurt.
## Player has no HealthComponent — GameState owns player HP.

const SPEED := 80.0
## FEEL Stride 1 (movement weight): PlayerMove ramps velocity toward
## input*SPEED via approach_velocity() instead of snapping instantly, so
## walking has a brief wind-up/wind-down. Tuned conservatively (reaches top
## speed in ~0.1s, stops in ~0.08s) — top speed and collision behavior
## (move_and_slide) are unchanged, this only shapes the ramp.
const ACCEL := 800.0   # px/s^2 while input is held
const FRICTION := 1000.0  # px/s^2 while input is released (slightly snappier stop than accel)
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
	var single_tex := load("res://assets/placeholder/char_player.png") as Texture2D
	var sheet_tex := load("res://assets/placeholder/char_player_sheet.png") as Texture2D
	sprite.sprite_frames = SpriteSheets.build_character(sheet_tex, single_tex, PackedStringArray(ANIM_NAMES))
	sprite.play("idle_down")
	_add_ground_shadow()
	($Collision as CollisionShape2D).shape = RectangleShape2D.new()
	(($Collision as CollisionShape2D).shape as RectangleShape2D).size = Vector2(10, 6)
	($Collision as CollisionShape2D).position = Vector2(0, -3)
	var zone_shape := CircleShape2D.new()
	zone_shape.radius = 10.0
	($InteractZone/ZoneShape as CollisionShape2D).shape = zone_shape
	interact_zone.position = Vector2(facing) * 12.0
	# Craft Stride 3 (Taming): interact_zone now also needs to detect enemy
	# BODIES (Enemy is a CharacterBody2D, not an Area2D like NPCs/Bed/Kitchen)
	# so _feedable_target_in_zone() can find a live tameable enemy to feed.
	# monitorable stays false (set in the scene) — nothing needs to detect
	# the zone itself, only the reverse.
	interact_zone.collision_mask = Layers.bit(Layers.WORLD) | Layers.bit(Layers.ENEMY_BODY)

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


func _on_hurtbox_hit_taken(damage: int, knockback: Vector2, is_heavy: bool = false) -> void:
	GameState.take_damage(damage)
	# FEEL Stride 4 (screen shake retune): small shake on ordinary damage,
	# medium on a heavy hit (currently only the boss slam sets is_heavy).
	EventBus.camera_shake.emit(CameraShake.DEFAULT_STRENGTH * (1.5 if is_heavy else 1.0))
	# FEEL Stride 2: hit-stop on the boss slam landing on the player — a brief
	# global time_scale dip so the impact reads as heavy, not a tickle.
	if is_heavy:
		HitStop.trigger()
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


static func approach_velocity(current: Vector2, target: Vector2, accel: float, friction: float, delta: float) -> Vector2:
	## Pure ramp helper (FEEL Stride 1): moves `current` toward `target` at
	## `accel` px/s^2 when target is nonzero, or `friction` px/s^2 when target
	## is zero (release) — move_toward() clamps the step so it can never
	## overshoot past `target`'s magnitude (no oscillation, no exceeding SPEED).
	var rate := friction if target == Vector2.ZERO else accel
	return current.move_toward(target, rate * delta)


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


func _add_ground_shadow() -> void:
	# Player-local feet are at y=SPRITE_BOTTOM (4, see class doc consts); the
	# shadow sits a couple px below that, roughly matching the sprite's own
	# width (16px).
	GroundShadow.attach(self, Vector2(0, SPRITE_BOTTOM + 2), Vector2(14, 6))


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
		# Craft Stride 3 (Taming): feeding takes precedence over eating when a
		# live tameable enemy that wants THIS held item is in the interact
		# zone (bible: "feeding takes precedence over eating... eating still
		# works otherwise" — mirrors the gift-vs-eat resolution NPCs already
		# use: a more specific interaction wins over the generic fallback).
		var target := _feedable_target_in_zone(data.id)
		if target != null:
			_feed(target, data)
		else:
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


## ---- Taming (Craft Stride 3) ----

func _feedable_target_in_zone(held_item_id: String) -> Enemy:
	## A live, not-yet-fed, tameable enemy in the interact zone whose
	## favorite_food matches the currently held item. Returns null if none
	## (the caller falls back to ordinary eating) — mirrors NPC's giftable-
	## item lookup pattern (a specific match wins, anything else no-ops here).
	for body in interact_zone.get_overlapping_bodies():
		if body is Enemy:
			var enemy := body as Enemy
			if enemy.is_feedable() and enemy.data.favorite_food == held_item_id:
				return enemy
	return null


func _feed(target: Enemy, food: FoodData) -> void:
	## Consumes 1 of the held favorite food, makes the target passive for the
	## rest of the day, and resolves the taming threshold (Taming.record_feed)
	## on top of the ordinary feed — see Taming's class doc for the
	## fed-vs-tamed-vs-barn-full result shape. Species id is read off
	## EnemyData.id ("slime") rather than hardcoded, so a future second
	## tameable species falls out of this same call for free.
	if not Inventory.remove_item(food.id, 1):
		return
	var species_id := target.data.id
	var outcome := Taming.record_feed(SaveManager.world, species_id)
	SaveManager.world["taming"] = outcome["blob"]
	match String(outcome["result"]):
		Taming.RESULT_TAMED:
			target.feed()  # still consumed/passive-flagged, then despawns below
			target.queue_free()
			EventBus.toast_requested.emit("It follows you home.")
		Taming.RESULT_BARN_FULL:
			target.feed()
			EventBus.toast_requested.emit("Your pen is full.")
		_:
			target.feed()
			EventBus.toast_requested.emit("The slime bounces happily.")


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
