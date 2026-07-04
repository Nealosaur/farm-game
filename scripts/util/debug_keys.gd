extends Node
## Dev-build-only debug hotkeys (spec §14). F3 teleport lands in Plan 3.


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_gold"):
		GameState.add_gold(1000)
		EventBus.toast_requested.emit("+1000g (debug)")
	elif event.is_action_pressed("debug_skip_day"):
		var flow := get_tree().get_first_node_in_group("day_flow")
		if flow != null:
			flow.sleep()
	elif event.is_action_pressed("debug_refill"):
		GameState.heal(GameState.max_hp)
		GameState.restore_rp(GameState.max_rp)
		EventBus.toast_requested.emit("HP/RP refilled (debug)")
	elif event.is_action_pressed("debug_teleport"):
		EventBus.toast_requested.emit("Dungeon arrives in Plan 3")
