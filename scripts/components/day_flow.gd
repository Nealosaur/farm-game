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
##
## Marriage M3 (bible §3: "each morning a chance the spouse waters a few crop
## cells OR leaves a dish/gift"): once Romance.spouse() != "", a ~50% chance
## per day (seeded by Clock.day, see _SPOUSE_HELP_CHANCE_SEED_OFFSET) picks
## ONE of two cozy beats: water _SPOUSE_HELP_WATER_COUNT random unwatered
## tilled cells (reusing FarmGrid.water_random_unwatered()/_stored(), same
## on-farm-vs-off-farm split as the barn slimes' own morning-help below), or
## drop one dish from _SPOUSE_GIFT_DISH_IDS straight into the player's
## inventory. Both branches are deterministic per day (seeded RNG, no
## Clock-time/real-random dependence) so a replayed/re-simulated day always
## produces the identical outcome — same testability contract as the barn
## slimes'. Runs BEFORE the barn-slime check and the rain check (ordering
## doesn't matter between spouse-help and barn-help since they're additive,
## independent toasts; kept first here simply because marriage content reads
## first in this file's toast list).

const FARM_SCENE := "res://scenes/maps/farm.tscn"

## Farm wake cell comes from the farm's own SPAWNS table instead of the old
## hardcoded (8, 8) — same cell today, but now single-sourced.
const FarmScript := preload("res://scripts/maps/farm.gd")

## Marriage M3 (spouse morning-help): distinct seed offsets from the barn
## slimes' own `Clock.day * 1000 + i` scheme so the two systems' random draws
## never accidentally correlate (not a correctness requirement — collision
## would still be deterministic — just keeps the two features' outcomes
## independent of each other's internal seeding choice).
const _SPOUSE_HELP_CHANCE_SEED_OFFSET := 7919      # decide: does help happen at all today
const _SPOUSE_HELP_KIND_SEED_OFFSET := 7927        # decide: water vs. gift
const _SPOUSE_HELP_ITEM_SEED_OFFSET := 7933         # decide: which dish
const _SPOUSE_HELP_WATER_SEED_OFFSET := 7937        # which cells get watered
const _SPOUSE_HELP_CHANCE := 0.5                    # bible: "a chance (~50%)"
const _SPOUSE_HELP_WATER_COUNT := 5                 # bible: "waters a few (~5)"
## Bible: "leaves a small gift/dish" — drawn from the already-shipped cooked
## dishes (Craft Stride 1, tools/gen_content.gd's `_dish()` entries) rather
## than inventing a new item, since a home-cooked dish is exactly the "made
## you something" flavor the spouse dialog pool already promises.
const _SPOUSE_GIFT_DISH_IDS := ["carrot_soup", "berry_jam", "pumpkin_pie", "forest_stew", "miners_meal"]

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
	# FEEL Stride 5: the gentle sleep chime only fits a VOLUNTARY sleep, not a
	# collapse (curfew/death) — those are already communicated as a harsher
	# beat via the "You collapsed..." toast below.
	if not collapsed:
		AudioManager.play("sleep")
	# Alive Stride 2: gates player input for the WHOLE end-of-day sequence —
	# fixes the long-standing debt where Clock.paused stopped time/crops but
	# Player.Idle/Move still polled input during the fade (see GameFlow's
	# class doc). Cleared on every return path below (both the on-farm and
	# away-from-farm branches).
	GameFlow.cutscene_active = true
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
	var slime_watered := 0
	var spouse_help := _resolve_spouse_help()  # Marriage M3: decide BEFORE touching the grid (on-farm/off-farm branches both need the same decision)
	if grid != null:
		# day_passed already grew + season-wilted the live grid; read the tally.
		wilted = grid.last_wilt_count
		if spouse_help["kind"] == "water":
			grid.water_random_unwatered(_SPOUSE_HELP_WATER_COUNT, Clock.day + _SPOUSE_HELP_WATER_SEED_OFFSET)
		# Craft Stride 3 (Taming — morning help): each barn slime waters 8
		# random unwatered tilled cells, seeded by Clock.day for determinism,
		# BEFORE the rain check (bible ordering). Works on-farm here; the
		# else branch below mirrors it for the off-farm/stored-blob path —
		# both read the SAME barn count so waking off-farm gets identical
		# morning help to waking on it.
		slime_watered = _barn_slime_water(grid)
		if Clock.is_raining():
			grid.water_all()  # rain day: wake to a fully watered field
		grid.store()
	else:
		# Farm scene not loaded (slept/collapsed elsewhere): the day_passed
		# from Clock.end_day() had no live FarmGrid listener, so advance the
		# saved blob directly — crops must never miss a growth night (nor a
		# season-boundary wilt, nor an overnight rain watering, nor the barn
		# slimes' morning watering — same stored-blob pattern as those two).
		wilted = FarmGrid.advance_stored_day()
		if spouse_help["kind"] == "water":
			FarmGrid.water_random_unwatered_stored(_SPOUSE_HELP_WATER_COUNT, Clock.day + _SPOUSE_HELP_WATER_SEED_OFFSET)
		slime_watered = _barn_slime_water_stored()
		if Clock.is_raining():
			FarmGrid.water_all_stored()
	if spouse_help["kind"] == "gift":
		Inventory.add_item(String(spouse_help["item_id"]), 1)
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
	var spouse_toast := _spouse_help_toast_text(spouse_help)
	if spouse_toast != "":
		toasts.append(spouse_toast)
	if slime_watered > 0:
		# One combined toast regardless of barn size (bible: "once per slime
		# or combined — your call"; combined reads cleaner than a toast per
		# slime when the pen holds 2). Shown even on a rain day: it's true
		# that the slimes helped BEFORE the rain took over, factual either way.
		toasts.append("Your slime helped water the field.")
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
		GameFlow.cutscene_active = false
		_busy = false
	else:
		# Away from the farm: finish our own state, then hand off the swap
		# (see class doc — we die at the swap, so no awaits after this).
		Clock.paused = false
		GameFlow.cutscene_active = false
		_busy = false
		SceneChanger.swap_scene_while_black(FARM_SCENE, "wake", toasts)


## ---- Marriage M3: spouse morning-help ----

func _resolve_spouse_help() -> Dictionary:
	## Pure decision step (no grid/inventory side effects here — callers apply
	## the result themselves, once per on-farm/off-farm branch, since only ONE
	## of those branches ever actually runs for a given end_day() call).
	## Returns {"kind": "none"/"water"/"gift", "item_id": String, "spouse_id": String}.
	## Deterministic per Clock.day: three seeded rolls (chance, kind, item) so
	## a replayed day always reproduces the identical decision, same
	## testability contract as the barn slimes' own seeding.
	var spouse_id := Romance.spouse()
	if spouse_id == "":
		return {"kind": "none", "item_id": "", "spouse_id": ""}
	var chance_rng := RandomNumberGenerator.new()
	chance_rng.seed = Clock.day + _SPOUSE_HELP_CHANCE_SEED_OFFSET
	if chance_rng.randf() >= _SPOUSE_HELP_CHANCE:
		return {"kind": "none", "item_id": "", "spouse_id": spouse_id}
	var kind_rng := RandomNumberGenerator.new()
	kind_rng.seed = Clock.day + _SPOUSE_HELP_KIND_SEED_OFFSET
	var kind := "water" if kind_rng.randf() < 0.5 else "gift"
	var item_id := ""
	if kind == "gift":
		var item_rng := RandomNumberGenerator.new()
		item_rng.seed = Clock.day + _SPOUSE_HELP_ITEM_SEED_OFFSET
		item_id = _SPOUSE_GIFT_DISH_IDS[item_rng.randi() % _SPOUSE_GIFT_DISH_IDS.size()]
	return {"kind": kind, "item_id": item_id, "spouse_id": spouse_id}


func _spouse_help_toast_text(spouse_help: Dictionary) -> String:
	var kind := String(spouse_help.get("kind", "none"))
	if kind == "none":
		return ""
	var spouse_id := String(spouse_help.get("spouse_id", ""))
	var spouse_data := NPCFactory.build_data(spouse_id)
	var spouse_name := spouse_data.display_name if spouse_data != null else spouse_id.capitalize()
	if kind == "water":
		return "%s watered part of the field." % spouse_name
	var item := ItemDB.get_item(String(spouse_help.get("item_id", "")))
	var item_name := item.display_name if item != null else String(spouse_help.get("item_id", ""))
	return "%s left you %s." % [spouse_name, item_name]


const _WATER_PER_SLIME := 8  # bible: "each barn slime waters 8 random unwatered tilled cells"


func _barn_slime_water(grid: FarmGrid) -> int:
	## On-farm path: waters _WATER_PER_SLIME cells per barn slime directly on
	## the live grid. Seeded by Clock.day ONLY (not per-slime) so the total
	## pick is deterministic per day regardless of barn size — two slimes
	## each get their own water_random_unwatered() call (so the second
	## slime's 8 picks are drawn from whatever the first slime's call left
	## unwatered), but both calls share the day's seed plus an index offset
	## so re-running the same day never reshuffles the result.
	var barn_size := Taming.barn_count(SaveManager.world)
	if barn_size == 0:
		return 0
	var total := 0
	for i in barn_size:
		total += grid.water_random_unwatered(_WATER_PER_SLIME, Clock.day * 1000 + i)
	return total


func _barn_slime_water_stored() -> int:
	## Off-farm path companion (see class doc's "works when waking off-farm
	## too" requirement) — same seeding rule, applied straight to the saved
	## blob, mirroring how advance_stored_day()/water_all_stored() already
	## handle the away-from-farm case.
	var barn_size := Taming.barn_count(SaveManager.world)
	if barn_size == 0:
		return 0
	var total := 0
	for i in barn_size:
		total += FarmGrid.water_random_unwatered_stored(_WATER_PER_SLIME, Clock.day * 1000 + i)
	return total
