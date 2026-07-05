class_name ArenaGate
extends Area2D
## Detects the player crossing into the boss arena and seals the entrance
## corridor behind them for the duration of the fight (a StaticBody2D
## blocker spanning the gate cells), using ArenaSeal for the sealed/unsealed
## decision logic. Unseals on boss death or player collapse/death; scene-local
## to dungeon_3 (rebuilt fresh each floor load, so a respawned visit after a
## collapse always starts unsealed even if the boss is still alive).

var seal_state := ArenaSeal.new()
var _blocker: StaticBody2D


func setup(gate_cells: Array) -> void:
	## gate_cells: Array[Vector2i] of the corridor cells to block once sealed.
	collision_layer = 0
	collision_mask = Layers.bit(Layers.PLAYER_BODY)
	body_entered.connect(_on_body_entered)

	_blocker = StaticBody2D.new()
	_blocker.name = "ArenaBlocker"
	_blocker.collision_layer = Layers.bit(Layers.WORLD)
	_blocker.collision_mask = 0
	for cell: Vector2i in gate_cells:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(MapBuilder.TILE, MapBuilder.TILE)
		shape.shape = rect
		shape.position = MapBuilder.cell_center(cell)
		_blocker.add_child(shape)
	add_child(_blocker)
	_blocker.visible = false
	_set_blocker_active(false)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	if seal_state.player_entered_arena():
		_set_blocker_active(true)
		EventBus.toast_requested.emit("The ground rumbles...")


func on_boss_defeated() -> void:
	seal_state.boss_defeated()
	_set_blocker_active(false)


func on_player_collapsed() -> void:
	seal_state.player_collapsed()
	_set_blocker_active(false)


func _set_blocker_active(on: bool) -> void:
	if _blocker == null:
		return
	_blocker.visible = on
	for child in _blocker.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", not on)
