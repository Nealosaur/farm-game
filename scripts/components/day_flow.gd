class_name DayFlow
extends Node
## Owns the end-of-day sequence: fade, shipping payout, day rollover,
## restore, autosave, reposition, fade back. Triggered by bed (sleep),
## curfew (2 AM), or player death (RP drain in Plan 2).
## ACCEPTED TRADEOFF: the game saves ONLY here (sleep/collapse) — quitting
## mid-day loses that day's progress, genre-standard for Stardew-likes.

var _busy := false


func _ready() -> void:
	add_to_group("day_flow")
	# Named methods, NOT lambdas — see FarmGrid note (freed-node safety).
	EventBus.curfew_reached.connect(_on_curfew)
	EventBus.player_died.connect(_on_player_died)


func _on_curfew() -> void:
	end_day(true)


func _on_player_died() -> void:
	end_day(true)


func sleep() -> void:
	end_day(false)


func end_day(collapsed: bool) -> void:
	if _busy or SceneChanger.is_busy():
		return
	_busy = true
	Clock.paused = true
	await SceneChanger.fade_to_black()

	var bin: Dictionary = SaveManager.world.get("shipping_bin", {})
	var earned := Shipping.payout(bin)
	if earned > 0:
		GameState.add_gold(earned)
	SaveManager.world["shipping_bin"] = {}

	Clock.end_day()
	GameState.sleep_restore(collapsed)

	var grid := get_tree().get_first_node_in_group("farm_grid") as FarmGrid
	if grid != null:
		grid.store()
	SaveManager.save_game()

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.global_position = MapBuilder.cell_center(Vector2i(8, 8))

	await SceneChanger.fade_from_black()
	if collapsed:
		EventBus.toast_requested.emit("You collapsed... Day %d" % Clock.day)
	else:
		EventBus.toast_requested.emit("Day %d" % Clock.day)
	if earned > 0:
		EventBus.toast_requested.emit("Shipped goods: +%dg" % earned)
	Clock.paused = false
	_busy = false
