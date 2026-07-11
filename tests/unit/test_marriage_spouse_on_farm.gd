extends GutTest
## Marriage M3 (spouse-on-farm): the post-wedding content stride.
##
## Covers, per the contract:
##  1. Spouse farm schedule (married spouse resolves to farm cells, not
##     town; unmarried unaffected) — pure NPCRegistry level.
##  2. Farm queries the registry + the spouse actually spawns on the farm
##     scene — real farm.tscn instantiation.
##  3. Spouse dialog tier wins over KINDRED (and over dating) when married —
##     pure DialogResolver level.
##  4. Morning-help determinism + waters-only-unwatered + off-farm path +
##     ~rate — DayFlow level, mirrors test_day_flow_barn_watering.gd's shape.
##  5. 14-heart trigger fires once at L14 with the right candidate's text.
##  6. Marry-ends-other-dating: mechanism (already covered by
##     test_romance_chain.gd) + the new toast wording, pinned here.

const _DIALOG_SCRIPTS := {
	"rosa": "res://data/dialog/rosa.gd",
	"willow": "res://data/dialog/willow.gd",
	"bram": "res://data/dialog/bram.gd",
	"sten": "res://data/dialog/sten.gd",
	"garrick": "res://data/dialog/garrick.gd",
}


func before_each() -> void:
	Clock.paused = true
	Clock.weather = "clear"
	Clock.day = 85  # Winter 1 — 0% rain chance (Clock.RAIN_CHANCE[3]), same trick
	# test_day_flow_barn_watering.gd uses to keep end_day() tests from flaking
	# on an unseeded rain reroll.
	GameState.flags = {}
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")


func after_each() -> void:
	Clock.paused = false
	Clock.weather = "clear"
	Clock.day = 1
	Clock.minutes = Clock.DAY_START_MINUTES
	GameState.flags = {}
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")


func _data(npc_id: String) -> Dictionary:
	var script: GDScript = load(_DIALOG_SCRIPTS[npc_id])
	return script.DATA


## ---- 1. pure NPCRegistry: spouse farm schedule ----

func test_married_spouse_resolves_to_farm_every_block() -> void:
	var data := RosaData.build()
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	for block: String in NPCRegistry.BLOCKS:
		var hour := _hour_for_block(block)
		assert_eq(NPCRegistry.map_for(data, hour, false, false), "farm",
			"married spouse must resolve to the farm map on block %s" % block)
		assert_true(NPCRegistry.is_present(data, hour, false, false),
			"married spouse must be present (not absent) on block %s" % block)


func test_married_spouse_farm_schedule_beats_rain_and_ordinary_schedule() -> void:
	var data := RosaData.build()  # her ordinary/rain schedule both target "town"
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	# Rain would normally override the ordinary schedule (see NPCRegistry's
	# precedence doc) — married-spouse-farm must win over BOTH.
	assert_eq(NPCRegistry.map_for(data, 10, true, false), "farm",
		"the farm schedule must beat rain_schedule for a married spouse")


func test_unmarried_candidate_is_unaffected_by_the_spouse_schedule() -> void:
	var data := RosaData.build()
	Romance._state = {"rosa": {"dating": true, "married": false}}
	Romance._spouse = ""
	assert_eq(NPCRegistry.map_for(data, 10, false, false), "town",
		"an unmarried (even if dating) candidate keeps their ordinary town schedule")


func test_dating_someone_else_does_not_leak_the_farm_schedule() -> void:
	var rosa_data := RosaData.build()
	Romance._state = {"willow": {"dating": true, "married": true}}
	Romance._spouse = "willow"
	assert_eq(NPCRegistry.map_for(rosa_data, 10, false, false), "town",
		"only the ACTUAL spouse gets the farm schedule, not every dating/married entry")


func test_married_spouse_still_attends_the_festival() -> void:
	## Bible: festival_cell still wins over the spouse-farm schedule — a
	## spouse attends the plaza festival like every other NPC.
	var data := RosaData.build()
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	assert_eq(NPCRegistry.map_for(data, 10, false, true), NPCRegistry.FESTIVAL_MAP,
		"festival_cell must still beat the married-spouse farm schedule")
	assert_eq(NPCRegistry.cell_for(data, 10, false, true), RosaData.CELL_FESTIVAL)


func _hour_for_block(block: String) -> int:
	match block:
		NPCRegistry.BLOCK_6_9: return 7
		NPCRegistry.BLOCK_9_12: return 10
		NPCRegistry.BLOCK_12_17: return 13
		NPCRegistry.BLOCK_17_20: return 18
		_: return 21


## ---- 2. real farm.tscn: farm queries the registry, spouse spawns ----

func test_married_spouse_spawns_on_the_real_farm_scene() -> void:
	Romance._state = {"willow": {"dating": true, "married": true}}
	Romance._spouse = "willow"
	Clock.minutes = 10 * 60  # 9-12 block
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_true(farm.npcs.has("willow"), "farm.gd must build an NPC instance for the married spouse")
	var willow: NPC = farm.npcs["willow"]
	assert_true(willow.visible, "the spouse must be visible on the farm this block")


func test_unmarried_npc_never_spawns_on_the_farm() -> void:
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_false(farm.npcs.has("willow"), "no marriage -> Willow never gets a farm instance")
	assert_false(farm.npcs.has("rosa"))
	assert_false(farm.npcs.has("bram"))
	assert_false(farm.npcs.has("sten"))


func test_garrick_as_spouse_keeps_a_single_instance_not_a_duplicate() -> void:
	## Garrick already gets a dedicated always-on instance (his farm-side
	## Delve-entrance morning appearance, pre-dating marriage) — if he's the
	## spouse, _add_registry_npcs() must skip him so farm.gd never builds a
	## SECOND live Garrick NPC node.
	Romance._state = {"garrick": {"dating": true, "married": true}}
	Romance._spouse = "garrick"
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_false(farm.npcs.has("garrick"), "Garrick must not get a second registry-driven instance")


func test_marrying_sten_keeps_the_forge_reachable_on_the_farm() -> void:
	## Milestone-review CRITICAL regression guard: marrying Sten vacates the
	## town smithy (he moves to the farm), so the forge UI MUST exist on the
	## farm or his "Forge" option dead-ends — silently killing all tool-tier
	## upgrades / Fangsteel / iridium for the rest of the save.
	Romance._state = {"sten": {"dating": true, "married": true}}
	Romance._spouse = "sten"
	Clock.minutes = 10 * 60  # 9-12: a smithy block, so his "Forge" option is live
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	assert_true(farm.npcs.has("sten"), "Sten spouse spawns on the farm")
	assert_not_null(farm.get_tree().get_first_node_in_group("forge_screen"),
		"the forge UI must be instanced on the farm so a Sten spouse can forge at home")
	assert_not_null(farm.garrick, "Garrick's own dedicated instance must still exist")
	var garrick_count := 0
	for child in farm.find_children("*", "NPC", true, false):
		var npc := child as NPC
		if npc.npc_data != null and npc.npc_data.id == "garrick":
			garrick_count += 1
	assert_eq(garrick_count, 1, "exactly one Garrick NPC node must exist on the farm")


func test_spouse_relocates_on_block_change_on_the_real_farm_scene() -> void:
	Romance._state = {"bram": {"dating": true, "married": true}}
	Romance._spouse = "bram"
	Clock.minutes = 7 * 60  # 6-9 block -> kitchen-adjacent cell
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	var bram: NPC = farm.npcs["bram"]
	var morning_cell := NPCRegistry.SPOUSE_FARM_SCHEDULE[NPCRegistry.BLOCK_6_9]["cell"]
	assert_eq(bram.position, MapBuilder.cell_center(morning_cell))

	Clock.minutes = 13 * 60  # 12-17 block -> field-edge cell
	farm._on_time_ticked(Clock.hour(), Clock.minute())
	await wait_process_frames(1)
	var afternoon_cell := NPCRegistry.SPOUSE_FARM_SCHEDULE[NPCRegistry.BLOCK_12_17]["cell"]
	assert_eq(bram._current_cell, afternoon_cell, "the spouse's logical cell must update on block change")


## ---- 3. pure DialogResolver: spouse tier wins over KINDRED/dating ----

func test_spouse_line_wins_over_kindred_tier_pool() -> void:
	var data := _data("rosa")
	var context := {
		"tier": "KINDRED", "season": 0, "is_raining": false, "is_festival": false,
		"festival_id": "", "is_birthday": false, "is_dating": true, "is_spouse": true,
		"shown_indices": [], "rng": null,
	}
	var result := DialogResolver.pick(data, context)
	assert_eq(result["source"], "spouse")
	assert_true(result["text"] in data["spouse_lines"])


func test_spouse_line_wins_over_dating_line() -> void:
	var data := _data("willow")
	var context := {
		"tier": "KINDRED", "season": 0, "is_raining": false, "is_festival": false,
		"festival_id": "", "is_birthday": false, "is_dating": true, "is_spouse": true,
		"shown_indices": [], "rng": null,
	}
	var result := DialogResolver.pick(data, context)
	assert_eq(result["source"], "spouse")
	assert_false(result["text"] in data["dating_lines"])


func test_spouse_line_still_loses_to_birthday_and_seasonal() -> void:
	var data := _data("bram")
	var context := {
		"tier": "KINDRED", "season": 0, "is_raining": false, "is_festival": false,
		"festival_id": "", "is_birthday": true, "is_dating": true, "is_spouse": true,
		"shown_indices": [], "rng": null,
	}
	var result := DialogResolver.pick(data, context)
	assert_eq(result["source"], "birthday", "special-occasion lines still beat the spouse pool")


func test_every_candidate_has_a_non_empty_spouse_pool() -> void:
	for npc_id: String in _DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var lines: Array = data.get("spouse_lines", [])
		assert_gt(lines.size(), 0, "%s: spouse_lines must be authored" % npc_id)
		for line: String in lines:
			assert_ne(line, "", "%s: spouse_lines must not contain an empty string" % npc_id)


func test_npc_resolver_context_reports_is_spouse_only_for_the_real_spouse() -> void:
	Romance._state = {"sten": {"dating": true, "married": true}}
	Romance._spouse = "sten"
	var npc := NPCFactory.make_npc("sten")
	add_child_autofree(npc)
	var context: Dictionary = npc.call("_resolver_context")
	assert_true(context["is_spouse"])

	var other := NPCFactory.make_npc("garrick")
	add_child_autofree(other)
	var other_context: Dictionary = other.call("_resolver_context")
	assert_false(other_context["is_spouse"])


## ---- 4. DayFlow: spouse morning-help ----

func test_spouse_help_never_fires_when_unmarried() -> void:
	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	for x in range(24, 30):
		farm.grid.till(Vector2i(x, 10))

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		assert_false(msg.contains("watered part of the field") or msg.contains("left you"),
			"no spouse -> no spouse morning-help toast")


func test_spouse_help_decision_is_deterministic_per_day() -> void:
	## Pure decision-level determinism check (no scene needed): the same
	## Clock.day must always produce the identical {kind, item_id} result.
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	var flow := DayFlow.new()
	Clock.day = 200
	var first: Dictionary = flow.call("_resolve_spouse_help")
	var second: Dictionary = flow.call("_resolve_spouse_help")
	assert_eq(first["kind"], second["kind"])
	assert_eq(first["item_id"], second["item_id"])
	flow.free()


func test_spouse_help_fires_at_roughly_the_documented_rate() -> void:
	## Sweeps a wide range of days and confirms the "none" rate lands near 50%
	## (bible: "a chance (~50%)") — a loose statistical guard, not an exact
	## pin, since the seeded RNG's distribution isn't hand-verified bit-for-bit
	## here (that's covered implicitly by every other test in this block
	## exercising real outcomes).
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	var flow := DayFlow.new()
	var none_count := 0
	var total := 400
	for d in range(1, total + 1):
		Clock.day = d
		var result: Dictionary = flow.call("_resolve_spouse_help")
		if result["kind"] == "none":
			none_count += 1
	flow.free()
	var rate := float(none_count) / float(total)
	assert_between(rate, 0.35, 0.65, "the no-help rate should land near 50%% across many days")


func test_spouse_help_kind_is_either_water_or_gift_never_both_or_neither_when_active() -> void:
	Romance._state = {"willow": {"dating": true, "married": true}}
	Romance._spouse = "willow"
	var flow := DayFlow.new()
	var saw_water := false
	var saw_gift := false
	for d in range(1, 200):
		Clock.day = d
		var result: Dictionary = flow.call("_resolve_spouse_help")
		if result["kind"] == "water":
			saw_water = true
		elif result["kind"] == "gift":
			saw_gift = true
			assert_true(String(result["item_id"]) != "", "a gift outcome must always carry an item id")
	flow.free()
	assert_true(saw_water, "across 200 days, the water outcome must occur at least once")
	assert_true(saw_gift, "across 200 days, the gift outcome must occur at least once")


func test_spouse_help_waters_at_most_the_documented_count_on_the_real_farm() -> void:
	## Finds a day whose decision is "water" (deterministic per day; scanned
	## rather than hand-picked so this stays correct if the seed constants
	## ever change). NOTE: Clock.end_day()'s day_passed -> FarmGrid.advance_day()
	## resets EVERY tilled cell's `watered` flag to false as part of the
	## ordinary night-growth step (same behavior the barn-slime tests already
	## rely on — see test_only_unwatered_tilled_cells_are_touched's own doc) —
	## so "only unwatered cells get touched" is actually a same-morning
	## property: at most _SPOUSE_HELP_WATER_COUNT cells end up watered out of
	## a larger tilled pool, never more.
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	var probe := DayFlow.new()
	var water_day := -1
	# Search only within a Winter span (Clock.RAIN_CHANCE[3] == 0.0) so the
	# eventual end_day() call below can never roll real rain regardless of
	# which day satisfies "water" first — a day found outside Winter would
	# otherwise risk the rain-auto-water branch also firing and confounding
	# the exact-count assertion below.
	for d in range(85, 113):  # Winter: days 85-112 (DAYS_PER_SEASON == 28, 4 seasons)
		Clock.day = d
		var result: Dictionary = probe.call("_resolve_spouse_help")
		if result["kind"] == "water":
			water_day = d
			break
	probe.free()
	assert_gt(water_day, -1, "precondition: at least one Winter day must roll 'water'")
	Clock.day = water_day - 1  # end_day() will increment to water_day

	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	Clock.weather = "clear"  # isolate from the rain auto-water branch (Clock.end_day() re-rolls weather)
	for x in range(24, 34):  # 10 tilled cells — more than _SPOUSE_HELP_WATER_COUNT (5)
		farm.grid.till(Vector2i(x, 10))

	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var watered_count := 0
	for x in range(24, 34):
		if farm.grid.plots[Vector2i(x, 10)].watered:
			watered_count += 1
	assert_eq(watered_count, DayFlow._SPOUSE_HELP_WATER_COUNT,
		"the spouse must water exactly the documented count out of a larger unwatered pool")


func test_spouse_help_works_off_farm_stored_path() -> void:
	## Mirrors test_day_flow_barn_watering.gd's own documented tradeoff: the
	## true off-farm branch hands off to SceneChanger.swap_scene_while_black()
	## and can't run headless end-to-end, so this pins the SOURCE calls the
	## same static-guard way that file does for the barn slimes.
	var src := FileAccess.get_file_as_string("res://scripts/components/day_flow.gd")
	var anchor := src.find("wilted = FarmGrid.advance_stored_day()")
	assert_gt(anchor, -1, "expected anchor line not found — day_flow.gd's off-farm branch shape changed")
	var off_farm_branch := src.substr(anchor, 400)
	assert_true(off_farm_branch.contains("water_random_unwatered_stored"),
		"the away-from-farm branch must call the stored-blob spouse-help watering path")


func test_spouse_help_toast_wording_water() -> void:
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	var probe := DayFlow.new()
	var water_day := -1
	for d in range(1, 200):
		Clock.day = d
		var result: Dictionary = probe.call("_resolve_spouse_help")
		if result["kind"] == "water":
			water_day = d
			break
	probe.free()
	assert_gt(water_day, -1, "precondition: at least one day must roll 'water'")
	Clock.day = water_day - 1

	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)
	farm.grid.till(Vector2i(24, 10))

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	await flow.end_day(false)

	var saw_it := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		if msg == "Rosa watered part of the field.":
			saw_it = true
	assert_true(saw_it, "the water-outcome toast must use the spouse's display name")


func test_spouse_help_toast_wording_gift_adds_item_to_inventory() -> void:
	Romance._state = {"sten": {"dating": true, "married": true}}
	Romance._spouse = "sten"
	var probe := DayFlow.new()
	var gift_day := -1
	for d in range(1, 200):
		Clock.day = d
		var result: Dictionary = probe.call("_resolve_spouse_help")
		if result["kind"] == "gift":
			gift_day = d
			break
	probe.free()
	assert_gt(gift_day, -1, "precondition: at least one day must roll 'gift'")
	Clock.day = gift_day - 1

	var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
	add_child_autofree(farm)
	await wait_process_frames(2)

	watch_signals(EventBus)
	var flow = farm.get_tree().get_first_node_in_group("day_flow")
	var before_counts := {}
	for item_id: String in DayFlow._SPOUSE_GIFT_DISH_IDS:
		before_counts[item_id] = Inventory.count_of(item_id)
	await flow.end_day(false)

	var gained_something := false
	for item_id: String in DayFlow._SPOUSE_GIFT_DISH_IDS:
		if Inventory.count_of(item_id) > int(before_counts[item_id]):
			gained_something = true
	assert_true(gained_something, "the gift outcome must add exactly one dish to the inventory")

	var saw_toast := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		if msg.begins_with("Sten left you "):
			saw_toast = true
	assert_true(saw_toast, "the gift-outcome toast must use the spouse's display name")


## ---- 5. 14-heart capstone trigger ----

func test_pending_event_returns_l14_only_for_a_married_spouse_at_max_level() -> void:
	Romance._state = {"garrick": {"dating": true, "married": true}}
	Romance._spouse = "garrick"
	Relationships._get_or_create("garrick")["points"] = 1400  # L14
	assert_eq(Relationships.pending_event("garrick"), "l14")


func test_pending_event_never_returns_l14_for_a_non_spouse() -> void:
	## Structurally impossible in real play (max_level_for caps a non-spouse at
	## L10/1000), but hand-set here to prove the gate is an EXPLICIT
	## is_married_to() check, not an accidental side effect of the level cap.
	Relationships._get_or_create("garrick")["points"] = 1400
	assert_ne(Relationships.pending_event("garrick"), "l14", "a non-spouse must never surface the l14 capstone")


func test_pending_event_l14_is_not_returned_once_marked_seen() -> void:
	Romance._state = {"garrick": {"dating": true, "married": true}}
	Romance._spouse = "garrick"
	Relationships._get_or_create("garrick")["points"] = 1400
	Relationships.mark_event_seen("garrick", "l14")
	assert_ne(Relationships.pending_event("garrick"), "l14")


func test_capstone_trigger_fires_once_with_the_right_candidates_text() -> void:
	for candidate_id: String in _DIALOG_SCRIPTS:
		Romance._state = {candidate_id: {"dating": true, "married": true}}
		Romance._spouse = candidate_id
		Relationships._state = {}
		Relationships._get_or_create(candidate_id)["points"] = 1400  # L14
		Relationships.mark_event_seen(candidate_id, "l3")
		Relationships.mark_event_seen(candidate_id, "l7")
		Relationships.mark_event_seen(candidate_id, "l8")
		Relationships.mark_event_seen(candidate_id, "l10")

		var farm := (load("res://scenes/maps/farm.tscn") as PackedScene).instantiate()
		add_child(farm)
		await wait_process_frames(2)

		assert_eq(Relationships.pending_event(candidate_id), "l14",
			"%s: precondition: the capstone must be pending" % candidate_id)

		var target: NPC = farm.npcs[candidate_id] if farm.npcs.has(candidate_id) else farm.garrick
		var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
		assert_not_null(dialog, "%s: farm.gd must auto-instance a DialogBox" % candidate_id)
		target.interact(farm.player)
		await wait_process_frames(1)
		assert_true(GameFlow.cutscene_active, "%s: the capstone scene must be playing" % candidate_id)

		# Drive the scene to completion (plain speak/end script, no choices).
		var runner: EventRunner = null
		for child in farm.get_children():
			if child is EventRunner:
				runner = child
		assert_not_null(runner, "%s: an EventRunner must be playing the capstone" % candidate_id)
		for i in 200:
			if not is_instance_valid(runner) or not GameFlow.cutscene_active:
				break
			if dialog.is_open():
				dialog._advance()
				await wait_process_frames(1)
			else:
				await wait_process_frames(1)
		await wait_process_frames(2)

		assert_false(GameFlow.cutscene_active, "%s: the capstone scene must have ended" % candidate_id)
		assert_true("l14" in Relationships._get_or_create(candidate_id).get("events_seen", []),
			"%s: l14 must be marked seen once the capstone finishes" % candidate_id)
		assert_eq(Relationships.pending_event(candidate_id), "",
			"%s: the capstone must not be pending again after it plays" % candidate_id)

		# The scene actually spoke THIS candidate's authored fourteen_heart
		# text, not some other candidate's or a generic placeholder.
		var expected_lines := RomanceEvents.fourteen_heart_lines(candidate_id)
		assert_gt(expected_lines.size(), 0, "%s: precondition: authored capstone lines must exist" % candidate_id)

		farm.free()
		await wait_process_frames(1)
		GameFlow.cutscene_active = false
		Clock.paused = false
		Relationships._state = {}
		SaveManager.world.erase("relationships")
		SaveManager.world.erase("events_seen")
		Romance._state = {}
		Romance._spouse = ""
		SaveManager.world.erase("romance")


func test_capstone_does_not_fire_before_l14() -> void:
	Romance._state = {"rosa": {"dating": true, "married": true}}
	Romance._spouse = "rosa"
	Relationships._get_or_create("rosa")["points"] = 1000  # L10, not yet L14
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")
	Relationships.mark_event_seen("rosa", "l10")
	assert_eq(Relationships.pending_event("rosa"), "", "no capstone before L14 is actually reached")


## ---- 6. marry-ends-other-dating: mechanism + toast wording ----

func test_marry_ends_other_dating_and_toasts_the_ended_candidate() -> void:
	Romance._state = {
		"rosa": {"dating": true, "married": false},
		"willow": {"dating": true, "married": false},
	}
	watch_signals(EventBus)
	Romance.marry("rosa")

	assert_true(Romance.is_married_to("rosa"))
	assert_false(Romance.is_dating("willow"), "marrying rosa must end the willow dating")

	var saw_it := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		if msg == "Willow heard about the wedding. Quietly, they wish you well.":
			saw_it = true
	assert_true(saw_it, "the ended-dating toast must name the correct candidate")


func test_marry_with_no_other_dating_emits_no_ended_dating_toast() -> void:
	Romance._state = {"rosa": {"dating": true, "married": false}}
	watch_signals(EventBus)
	Romance.marry("rosa")

	var saw_ended_dating_toast := false
	for call_index in get_signal_emit_count(EventBus, "toast_requested"):
		var msg: String = get_signal_parameters(EventBus, "toast_requested", call_index)[0]
		if msg.contains("heard about the wedding"):
			saw_ended_dating_toast = true
	assert_false(saw_ended_dating_toast, "no other dating candidate -> no ended-dating toast")
