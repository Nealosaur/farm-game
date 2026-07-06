extends GutTest
## Craft Stride 2 E2E: the "Fang Steel" chain — Sten's L7 heart event choice A
## -> flag sten_l7_choice_a (+ its "_day" record) -> NEXT-day town entry at a
## 6-12 block with the steel_sword in inventory -> EventDirector/TriggerService
## pick sten_fang_steel -> running the real scene applies bond +50 + flag
## sten_masterwork_done + events_seen bookkeeping -> the Fangsteel Blade
## recipe becomes visible in ForgeLogic/ForgeScreen -> once-only. Mirrors
## test_bench_chain.gd's structure exactly (see its class doc for why (a)
## uses a standalone NPC and the rest instantiate the REAL town.tscn).
##
## Also covers the "Forge" dialog-choice wiring (Sten-only, smithy blocks
## 6-17) since it's this stride's other Sten-interact surface.

const TOWN_SCENE := "res://scenes/maps/town.tscn"


func before_each() -> void:
	Clock.paused = true
	Clock.weather = "clear"  # pin against cross-file leaks (see test_event_runner.gd)
	Clock.day = 2            # the flag day is pinned to 1 by _arm_the_scene -> "next day" passes
	Clock.minutes = 10 * 60  # 9-12 block, inside the scene's 6-12 window
	GameState.flags = {}
	Inventory.reset()
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
	Inventory.reset()
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	SceneChanger.spawn_name = "default"


func _arm_the_scene() -> void:
	## State exactly as the real wiring leaves it: choice A taken on day 1
	## (flag + day record — see npc.gd's _on_heart_event_choice), steel sword
	## forged and carried, and before_each already pinned "today" to day 2.
	GameState.flags["sten_l7_choice_a"] = true
	GameState.flags["sten_l7_choice_a_day"] = 1
	Inventory.add_item("steel_sword", 1)


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


func _run_scene_to_completion(town: Node2D) -> void:
	## Same driver as test_bench_chain.gd's: advance the DialogBox for every
	## `speak`, pump frame-driven `wait` commands via simulate(), bounded as a
	## hang safety net.
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


## ---- (a) heart event choice A sets the flag + day record, real npc.gd path ----

func test_l7_choice_a_sets_sten_flag_and_day_record() -> void:
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	Relationships._get_or_create("sten")["points"] = 700  # L7 gate
	sten.interact(null)
	assert_eq(dialog.label.text, StenDialog.DATA["heart_events"]["l7"]["lines"][0])
	dialog._advance()  # reveal the two-option choice
	assert_eq(dialog.choice_box.get_child_count(), 2)
	(dialog.choice_box.get_child(0) as Button).pressed.emit()  # choice A (empathetic)

	assert_true(GameState.flags.get("sten_l7_choice_a", false))
	assert_eq(int(GameState.flags.get("sten_l7_choice_a_day", -1)), Clock.day,
		"the day record arms the scene's next-day gate")
	assert_eq(Relationships.points("sten"), 730)


func test_l7_choice_b_does_not_set_the_flag() -> void:
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	Relationships._get_or_create("sten")["points"] = 700
	sten.interact(null)
	dialog._advance()
	(dialog.choice_box.get_child(1) as Button).pressed.emit()  # choice B (dismissive)

	assert_false(GameState.flags.get("sten_l7_choice_a", false))


## ---- (b) armed town entry fires the real scene and applies effects ----

func test_next_day_town_entry_fires_fang_steel_and_applies_effects() -> void:
	_arm_the_scene()
	watch_signals(EventBus)
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)  # town._ready() already ran event_director.check()
	assert_true(GameFlow.cutscene_active, "the scene must be playing on entry")

	var sten_before := Relationships.points("sten")
	await _run_scene_to_completion(town)

	assert_eq(Relationships.points("sten"), sten_before + 50, "Fang Steel must apply +50 sten")
	assert_true(GameState.flags.get("sten_masterwork_done", false))
	assert_signal_emitted_with_parameters(EventBus, "toast_requested",
		["Forging unlocked: Fangsteel Blade"])

	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	assert_true(TriggerService.seen_forever(seen, "sten_fang_steel"), "events_seen must record the scene")
	assert_eq(int(seen.get("_any_fired_day", -1)), Clock.day)

	# The whole point of the scene: the recipe is now live.
	var visible_ids: Array[String] = []
	for upgrade: Dictionary in ForgeLogic.visible_upgrades():
		visible_ids.append(String(upgrade["id"]))
	assert_true("fangsteel_blade" in visible_ids, "the scene must un-hide the fangsteel recipe")

	# And the town's own auto-instanced ForgeScreen shows it as a row.
	var forge := get_tree().get_first_node_in_group("forge_screen") as ForgeScreen
	assert_not_null(forge, "town.gd must auto-instance a ForgeScreen (MapSceneHelper)")
	forge.open()
	assert_not_null(forge.upgrade_list.get_node_or_null("Row_fangsteel_blade"),
		"ForgeScreen must list the unlocked recipe")
	forge.close()


## ---- (c) negative gates: each missing precondition keeps the scene shut ----

func test_scene_does_not_fire_without_the_flag() -> void:
	Inventory.add_item("steel_sword", 1)  # sword but no flag
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active)
	assert_false(GameState.flags.get("sten_masterwork_done", false))


func test_scene_does_not_fire_without_the_steel_sword() -> void:
	GameState.flags["sten_l7_choice_a"] = true
	GameState.flags["sten_l7_choice_a_day"] = 1
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active, "has_item steel_sword must gate the scene")


func test_scene_does_not_fire_on_the_same_day_as_the_flag() -> void:
	## "Come back tomorrow. Bring fang steel." — the L7 event can play during
	## the very smithy blocks the scene fires in, so same-day must refuse.
	GameState.flags["sten_l7_choice_a"] = true
	GameState.flags["sten_l7_choice_a_day"] = Clock.day  # set TODAY
	Inventory.add_item("steel_sword", 1)
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active, "same-day must refuse (next_day_after_flag)")

	# The next day, the same standing check fires it.
	Clock.day += 1
	town.event_director.check()
	await wait_process_frames(2)
	assert_true(GameFlow.cutscene_active, "the day after, the scene must fire")


func test_scene_does_not_fire_outside_blocks_6_to_12() -> void:
	_arm_the_scene()
	Clock.minutes = 13 * 60  # 12-17 block — Sten's at the smithy but the scene window is closed
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active)


## ---- (d) once-only ----

func test_scene_never_refires_on_re_check_same_day() -> void:
	_arm_the_scene()
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	await _run_scene_to_completion(town)
	assert_true(GameState.flags.get("sten_masterwork_done", false), "precondition: scene already fired once")

	var sten_after_first := Relationships.points("sten")
	town.event_director.check()
	await wait_process_frames(2)
	assert_eq(Relationships.points("sten"), sten_after_first, "must not re-apply the bond delta")


func test_scene_never_refires_on_a_later_day_either() -> void:
	_arm_the_scene()
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)
	await _run_scene_to_completion(town)

	Clock.day += 1
	watch_signals(town.event_director)
	town.event_director.check()
	await wait_process_frames(2)
	assert_signal_emit_count(town.event_director, "scene_played", 0,
		"a one-time-forever scene must stay gone on later days too")


## ---- (f) "Forge" dialog choice wiring (Sten-only, smithy blocks 6-17) ----

func test_sten_offers_forge_choice_during_smithy_blocks() -> void:
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	sten.interact(null)  # hour 10 from before_each -> 9-12 block, forge open
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_true("Forge" in labels, "smithy block 9-12 must offer the Forge choice")


func test_sten_does_not_offer_forge_choice_in_the_evening() -> void:
	Clock.minutes = 20 * 60  # 20-2 block: forge closed
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	sten.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_false("Forge" in labels)


func test_picking_forge_opens_the_forge_screen() -> void:
	var sten := NPCFactory.make_npc("sten")
	add_child_autofree(sten)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)
	var forge := (load("res://scripts/ui/forge_screen.gd") as GDScript).new() as ForgeScreen
	add_child_autofree(forge)

	sten.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var idx := labels.find("Forge")
	assert_true(idx >= 0, "precondition: Forge choice offered")
	(dialog.choice_box.get_child(idx) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(forge.is_open())


func test_marta_never_offers_forge_choice() -> void:
	## has_forge is Sten-only in NPCFactory.REGISTRY — Marta (or anyone else)
	## must not grow a Forge choice from this stride.
	var marta := NPCFactory.make_npc("marta")
	add_child_autofree(marta)
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)

	marta.interact(null)
	dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	assert_false("Forge" in labels)
