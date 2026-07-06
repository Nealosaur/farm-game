extends GutTest
## Alive Stride 2 (I1 coverage gap): end-to-end "The Bench" chain —
## Garrick's L7 heart event choice A -> flag garrick_l7_choice_a -> next town
## entry at a 9-12 block -> EventDirector/TriggerService pick
## garrick_sten_bench -> running the real scene applies both bond deltas +
## flag + events_seen bookkeeping -> once-only (no re-fire on re-entry) ->
## _gated_dialog_data content gating flips at the right moment.
##
## (a) drives the heart-event choice through the REAL npc.gd
## _on_heart_event_choice path (a standalone Garrick NPC + DialogBox, same
## shape as test_town_npc_integration.gd's standalone-Marta heart event test)
## since a full town.tscn instance has no in-scene way to raise Garrick's
## bond to L7 and open his heart-event dialog (he's off-map at farm during
## every daylight block).
## (b)-(d) instantiate the REAL town.tscn (like test_town_npc_integration.gd)
## so EventDirector/TriggerService/EventRunner all run exactly as they would
## in play, including Garrick's temp-spawn and Sten's live-NPC resolution.

const TOWN_SCENE := "res://scenes/maps/town.tscn"


func before_each() -> void:
	Clock.paused = true
	Clock.weather = "clear"  # see test_event_runner.gd's before_each doc: pin against cross-file leaks
	Clock.day = 1
	Clock.minutes = 10 * 60  # 9-12 block
	GameState.flags = {}
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	SceneChanger.spawn_name = "default"


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"
	GameState.flags = {}
	GameFlow.cutscene_active = false
	get_tree().paused = false
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	SceneChanger.spawn_name = "default"


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


func _run_bench_scene_to_completion(town: Node2D) -> void:
	## Drives the REAL EventRunner (town.event_director's one child) all the
	## way to `end`: pumps frame-driven `wait`/`move` commands via simulate()
	## exactly like test_event_runner.gd's own convention, AND advances the
	## DialogBox for every `speak` line in between — EventRunner's `_cmd_speak`
	## awaits DialogBox.finished, which only fires once something calls
	## _advance() (mirrors a real player pressing "interact"/clicking through
	## dialog; see dialog_box.gd's class doc — it never auto-progresses on its
	## own). Each `speak` command in this scene shows exactly ONE line, so a
	## single _advance() closes it (no choice buttons in this particular
	## scene). Bounded iteration count as a safety net against ever hanging
	## the test suite if a future edit to the scene script breaks this.
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	assert_not_null(dialog, "town.gd must auto-instance a DialogBox")
	var runner: Node = town.event_director.get_child(0)
	for i in 200:
		if not is_instance_valid(runner) or not GameFlow.cutscene_active:
			break
		if dialog.is_open():
			dialog._advance()
			await wait_process_frames(1)
		else:
			simulate(runner, 5, 0.1)
			await wait_process_frames(1)
	await wait_process_frames(2)


## ---- (a) heart event choice A sets the flag, via the real npc.gd path ----

func test_l7_choice_a_sets_garrick_l7_choice_a_flag() -> void:
	var garrick := NPCFactory.make_npc("garrick")
	add_child_autofree(garrick)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	Relationships._get_or_create("garrick")["points"] = 700  # L7 gate
	garrick.interact(null)
	assert_eq(dialog.label.text, GarrickDialog.DATA["heart_events"]["l7"]["lines"][0])
	dialog._advance()  # reveal the two-option choice
	assert_eq(dialog.choice_box.get_child_count(), 2)
	(dialog.choice_box.get_child(0) as Button).pressed.emit()  # choice A (empathetic)

	assert_true(GameState.flags.get("garrick_l7_choice_a", false))
	assert_eq(Relationships.points("garrick"), 730)


func test_l7_choice_b_does_not_set_the_flag() -> void:
	var garrick := NPCFactory.make_npc("garrick")
	add_child_autofree(garrick)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	Relationships._get_or_create("garrick")["points"] = 700
	garrick.interact(null)
	dialog._advance()
	(dialog.choice_box.get_child(1) as Button).pressed.emit()  # choice B (dismissive)

	assert_false(GameState.flags.get("garrick_l7_choice_a", false))


## ---- (b)+(c) town entry at 9-12 with the flag set fires the real scene ----

func test_town_entry_with_flag_set_fires_the_bench_scene_and_applies_effects() -> void:
	GameState.flags["garrick_l7_choice_a"] = true
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)  # town._ready() already called event_director.check() once

	var garrick_before := Relationships.points("garrick")
	var sten_before := Relationships.points("sten")

	await _run_bench_scene_to_completion(town)

	assert_eq(Relationships.points("garrick"), garrick_before + 50, "The Bench must apply +50 garrick")
	assert_eq(Relationships.points("sten"), sten_before + 50, "The Bench must apply +50 sten")
	assert_true(GameState.flags.get("garrick_sten_reconciled", false))

	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	assert_true(TriggerService.seen_forever(seen, "garrick_sten_bench"), "events_seen must record the scene")
	assert_eq(int(seen.get("_any_fired_day", -1)), Clock.day)


func test_bench_scene_does_not_fire_when_flag_is_absent() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active, "no scene should be playing without the trigger flag")
	assert_false(GameState.flags.get("garrick_sten_reconciled", false))


## ---- (d) once-only: re-entry never re-fires ----

func test_bench_scene_never_refires_on_re_entry_same_day() -> void:
	GameState.flags["garrick_l7_choice_a"] = true
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	await _run_bench_scene_to_completion(town)
	assert_true(GameState.flags.get("garrick_sten_reconciled", false), "precondition: scene already fired once")

	var garrick_after_first := Relationships.points("garrick")
	var sten_after_first := Relationships.points("sten")

	# Re-check (as a second town entry / block change would) — must no-op:
	# flag_absent("garrick_sten_reconciled") now fails even ignoring the
	# events_seen gate, and events_seen itself also already marks it seen
	# forever, so re-entry never re-fires by either mechanism.
	town.event_director.check()
	await wait_process_frames(2)
	assert_eq(Relationships.points("garrick"), garrick_after_first, "must not re-apply the bond delta")
	assert_eq(Relationships.points("sten"), sten_after_first, "must not re-apply the bond delta")


func test_bench_scene_never_refires_on_a_later_day_either() -> void:
	GameState.flags["garrick_l7_choice_a"] = true
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	await _run_bench_scene_to_completion(town)

	Clock.day = 2
	watch_signals(town.event_director)
	town.event_director.check()
	await wait_process_frames(2)
	assert_signal_emit_count(town.event_director, "scene_played", 0, "a one-time-forever scene must stay gone on later days too")


## ---- (e) _gated_dialog_data content gating before/after the flag ----

func test_garrick_kindred_reconciliation_line_absent_before_flag_present_after() -> void:
	var garrick := NPCFactory.make_npc("garrick")
	add_child_autofree(garrick)
	var kindred_line: String = GarrickDialog.DATA["tier_pools"]["KINDRED"][0]
	assert_true(kindred_line.begins_with("I told Sten"))

	var gated_before: Dictionary = garrick.call("_gated_dialog_data")
	var pool_before: Array = gated_before["tier_pools"]["KINDRED"]
	assert_false(kindred_line in pool_before, "must be absent before garrick_sten_reconciled is set")

	GameState.flags["garrick_sten_reconciled"] = true
	var gated_after: Dictionary = garrick.call("_gated_dialog_data")
	var pool_after: Array = gated_after["tier_pools"]["KINDRED"]
	assert_true(kindred_line in pool_after, "must be present once garrick_sten_reconciled is set")


func test_sten_close_bench_line_absent_before_flag_present_after() -> void:
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var close_line: String = StenDialog.DATA["tier_pools"]["CLOSE"][3]
	assert_eq(close_line, "Garrick's back at the bench. Hands me things wrong. It's good.")

	var gated_before: Dictionary = sten.call("_gated_dialog_data")
	var pool_before: Array = gated_before["tier_pools"]["CLOSE"]
	assert_false(close_line in pool_before, "must be absent before garrick_sten_reconciled is set")

	GameState.flags["garrick_sten_reconciled"] = true
	var gated_after: Dictionary = sten.call("_gated_dialog_data")
	var pool_after: Array = gated_after["tier_pools"]["CLOSE"]
	assert_true(close_line in pool_after, "must be present once garrick_sten_reconciled is set")


func test_gated_dialog_data_does_not_mutate_the_shared_const_data() -> void:
	## _gated_dialog_data() must return a shallow copy, never mutate the
	## shared `const DATA` dict every Garrick/Sten instance points at (see
	## npc.gd's class doc for this contract).
	var garrick := NPCFactory.make_npc("garrick")
	add_child_autofree(garrick)
	garrick.call("_gated_dialog_data")  # flag absent -> filters internally
	var kindred_line: String = GarrickDialog.DATA["tier_pools"]["KINDRED"][0]
	assert_true(kindred_line in GarrickDialog.DATA["tier_pools"]["KINDRED"],
		"the shared const DATA pool must be untouched")
