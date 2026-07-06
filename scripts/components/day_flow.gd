class_name DayFlow
extends Node
## Owns the end-of-day sequence: fade, shipping payout, day rollover,
## restore, autosave, reposition, fade back. Triggered by bed (sleep),
## curfew (2 AM), or player death (RP drain in Plan 2).
## ACCEPTED TRADEOFF: the game saves ONLY here (sleep/collapse) — quitting
## mid-day loses that day's progress, genre-standard for Stardew-likes.
##
## WORKS FROM ANY SCENE (dungeon floors included) since the portal stride:
## the whole rollover happens while the screen is dark, and only then do we
## decide how to come back up:
##  - On the farm (FarmGrid present): reposition the player at the farm's
##    "wake" spawn and fade back in — the original flow.
##  - Anywhere else: this node is a child of the current scene and dies at a
##    scene swap, so any code we awaited after the swap would never resume.
##    We therefore finish ALL our own state changes (including unpausing the
##    Clock — it starts ~a fade-length early, under one game minute at 0.7s
##    per minute, accepted), then hand the tail (swap to farm at "wake",
##    toasts, fade-in) to SceneChanger.swap_scene_while_black(), which runs
##    on the autoload and survives the swap. No double-fade: swap_* skips
##    fade_to_black because we already own the blackout.
## Crop continuity away from the farm: Clock.end_day() emits day_passed, but
## if no FarmGrid is alive nothing advances the crops — so we advance the
## stored blob directly via FarmGrid.advance_stored_day() before saving.

const FARM_SCENE := "res://scenes/maps/farm.tscn"

## Farm wake cell comes from the farm's own SPAWNS table instead of the old
## hardcoded (8, 8) — same cell today, but now single-sourced.
const FarmScript := preload("res://scripts/maps/farm.gd")

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

	Clock.end_day()  # increments day, rolls the new day's weather, emits day_passed
	GameState.sleep_restore(collapsed)

	var grid := get_tree().get_first_node_in_group("farm_grid") as FarmGrid
	var wilted := 0
	if grid != null:
		# day_passed already grew + season-wilted the live grid; read the tally.
		wilted = grid.last_wilt_count
		if Clock.is_raining():
			grid.water_all()  # rain day: wake to a fully watered field
		grid.store()
	else:
		# Farm scene not loaded (slept/collapsed elsewhere): the day_passed
		# from Clock.end_day() had no live FarmGrid listener, so advance the
		# saved blob directly — crops must never miss a growth night (nor a
		# season-boundary wilt, nor an overnight rain watering).
		wilted = FarmGrid.advance_stored_day()
		if Clock.is_raining():
			FarmGrid.water_all_stored()
	SaveManager.save_game()

	var toasts := PackedStringArray()
	if collapsed:
		toasts.append("You collapsed... %s" % Clock.date_string())
	else:
		toasts.append(Clock.date_string())
	if earned > 0:
		toasts.append("Shipped goods: +%dg" % earned)
	if wilted > 0:
		toasts.append("The season turned — %d crops wilted." % wilted)
	if Clock.is_raining():
		toasts.append("Rain overnight — the field is watered.")
	var festival_id := Clock.is_festival_today()
	if festival_id != "":
		toasts.append(Festival.wake_toast_text(festival_id))
	if festival_id == Festival.ID_WINTER_STAR:
		toasts.append(WinterStar.journal_text())

	if grid != null:
		# Original on-farm flow: reposition, fade in, toast, unpause.
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			player.global_position = MapBuilder.cell_center(FarmScript.SPAWNS["wake"])
		await SceneChanger.fade_from_black()
		for msg in toasts:
			EventBus.toast_requested.emit(msg)
		Clock.paused = false
		_busy = false
	else:
		# Away from the farm: finish our own state, then hand off the swap
		# (see class doc — we die at the swap, so no awaits after this).
		Clock.paused = false
		_busy = false
		SceneChanger.swap_scene_while_black(FARM_SCENE, "wake", toasts)
