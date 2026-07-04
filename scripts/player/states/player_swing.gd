class_name PlayerSwing
extends State
## Basic 3-hit combo. begin_swing() is called by Player BEFORE the state
## machine transitions in (mirrors PlayerDodge's pre-seeded direction pattern);
## it computes damage/knockback for the swing about to play. Pressing use_item
## again while swinging buffers the next hit in the chain (max 3); the third
## swing gets +50% knockback. Chain resets to 1 if MAX_GAP passes with no swing.

const STATE_DURATION := 0.25
const HITBOX_ACTIVE := 0.15
const MAX_CHAIN := 3
const MAX_GAP := 0.5
const THIRD_HIT_KNOCKBACK_MULT := 1.5

@onready var player: Player = owner

var _elapsed := 0.0
var _hitbox_on := false
var _buffered := false
var _chain := 0
var _time_since_last_swing := MAX_GAP + 1.0
var _pending_damage := 0
var _pending_knockback := 0.0
var _base_knockback: float = -1.0  # captured once from the export default


func _process(delta: float) -> void:
	# Tracked independent of being the active state so MAX_GAP works even
	# while Idle/Move are current.
	_time_since_last_swing += delta


func begin_swing(tool_data: ToolData) -> void:
	if _base_knockback < 0.0:
		_base_knockback = player.sword_hitbox.knockback_force
	if _time_since_last_swing > MAX_GAP:
		_chain = 0
	_chain = mini(_chain + 1, MAX_CHAIN)
	_time_since_last_swing = 0.0
	_pending_damage = GameState.attack + tool_data.damage
	_pending_knockback = _base_knockback
	if _chain == MAX_CHAIN:
		_pending_knockback *= THIRD_HIT_KNOCKBACK_MULT


func buffer_next() -> void:
	_buffered = true


func enter() -> void:
	_elapsed = 0.0
	_hitbox_on = false
	_buffered = false
	player.velocity = Vector2.ZERO
	player.play_anim("use")
	player.sword_hitbox.position = Vector2(player.facing) * 14.0
	player.sword_hitbox.damage = _pending_damage
	player.sword_hitbox.knockback_force = _pending_knockback
	player.sword_hitbox.set_active(true)
	_hitbox_on = true


func exit() -> void:
	if _hitbox_on:
		player.sword_hitbox.set_active(false)
		_hitbox_on = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	if _hitbox_on and _elapsed >= HITBOX_ACTIVE:
		player.sword_hitbox.set_active(false)
		_hitbox_on = false
	if _elapsed >= STATE_DURATION:
		if _buffered and _chain < MAX_CHAIN:
			var tool_data := Inventory.get_selected_item_data() as ToolData
			if tool_data != null:
				begin_swing(tool_data)
				enter()
				return
		machine.transition("Idle")
