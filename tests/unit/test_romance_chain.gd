extends GutTest
## Marriage M1 E2E (Rosa pilot) + M2 (all 5 candidates): the full romance
## chain through the REAL town.tscn — bouquet (L8+) -> dating -> bond to L10
## -> pendant -> PROPOSE DSL scene -> accept -> engaged -> next day-rollover
## town entry -> WEDDING DSL scene -> married + spouse set + cap lift to L14.
## Mirrors test_bench_chain.gd's structure (instantiate the real town.tscn so
## EventDirector/RomanceEvents/EventRunner all run exactly as they would in
## play, including the temp-spawn/live-NPC actor resolution the wedding's
## crowd gathering needs).
##
## M2: the Rosa-specific helpers below (_arm_rosa_dating_at_l10,
## _give_pendant_to_rosa) stay in place unchanged (existing tests reference
## them by name) but are now thin wrappers around the generic
## _arm_dating_at_l10(candidate_id)/_give_pendant(town, candidate_id)
## versions, which test_all_five_candidates_run_the_full_bouquet_to_wedding_
## chain loops over ALL 5 romanceable ids — the SAME mechanism Rosa's pilot
## chain already exercised, just parametric now.

const TOWN_SCENE := "res://scenes/maps/town.tscn"
const ALL_CANDIDATES := ["rosa", "willow", "bram", "sten", "garrick"]
const _DIALOG_SCRIPTS := {
	"rosa": "res://data/dialog/rosa.gd",
	"willow": "res://data/dialog/willow.gd",
	"bram": "res://data/dialog/bram.gd",
	"sten": "res://data/dialog/sten.gd",
	"garrick": "res://data/dialog/garrick.gd",
}


func before_each() -> void:
	Clock.paused = true
	Clock.weather = "clear"  # pin against cross-file leaks (see test_event_runner.gd's before_each doc)
	Clock.day = 1
	Clock.minutes = 10 * 60  # 9-12 block
	GameState.flags = {}
	Inventory.reset()
	Relationships._state = {}
	SaveManager.world.erase("relationships")
	SaveManager.world.erase("events_seen")
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
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
	Romance._state = {}
	Romance._spouse = ""
	SaveManager.world.erase("romance")
	SceneChanger.spawn_name = "default"


func _make_town() -> Node2D:
	return (load(TOWN_SCENE) as PackedScene).instantiate()


func _find_running_runner(town: Node2D) -> EventRunner:
	## Both the pendant->propose scene AND the wedding scene are spawned
	## directly under town (the "map_root" group node) by RomanceEvents,
	## NOT nested under town.event_director like the authored garrick_sten_
	## bench/sten_fang_steel scenes are — see romance_events.gd's
	## play_proposal()/play_wedding_if_due() doc.
	for child in town.get_children():
		if child is EventRunner:
			return child
	return null


func _drive_scene_to_completion(town: Node2D, choice_index: int = -1) -> void:
	## Same bounded-iteration driver as test_bench_chain.gd's
	## _run_bench_scene_to_completion — pumps frame-driven wait/move commands
	## via simulate() and advances the DialogBox for every `speak` line.
	## `choice_index` (if >= 0) presses that button the FIRST time a choice
	## prompt appears (the proposal's accept/decline question) — every
	## subsequent choice prompt (there is none today) would fall through to
	## the loop's normal dialog._advance() pump.
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	assert_not_null(dialog, "town.gd must auto-instance a DialogBox")
	var runner := _find_running_runner(town)
	assert_not_null(runner, "precondition: an EventRunner must be playing")
	var choice_used := choice_index < 0
	for i in 300:
		if not is_instance_valid(runner) or not GameFlow.cutscene_active:
			break
		if dialog.is_open() and dialog._showing_choices and not choice_used:
			choice_used = true
			(dialog.choice_box.get_child(choice_index) as Button).pressed.emit()
			await wait_process_frames(1)
		elif dialog.is_open():
			dialog._advance()
			await wait_process_frames(1)
		else:
			simulate(runner, 5, 0.1)
			await wait_process_frames(1)
	await wait_process_frames(2)


func _arm_dating_at_l10(candidate_id: String) -> void:
	Relationships._get_or_create(candidate_id)["points"] = 1000  # L10
	Relationships.mark_event_seen(candidate_id, "l3")
	Relationships.mark_event_seen(candidate_id, "l7")
	# M2: every candidate now has REAL l8/l10 heart-event scenes — mark them
	# seen so this chain test isolates the pendant->propose trigger it's
	# actually about, not the heart-event gate (which would otherwise
	# intercept interact() before the "Give Pendant" choice is ever offered).
	Relationships.mark_event_seen(candidate_id, "l8")
	Relationships.mark_event_seen(candidate_id, "l10")
	Romance.start_dating(candidate_id)
	assert_true(Romance.is_dating(candidate_id), "precondition: dating before the pendant")


func _arm_rosa_dating_at_l10(_town: Node2D) -> void:
	_arm_dating_at_l10("rosa")


func _give_pendant(town: Node2D, candidate_id: String) -> void:
	Inventory.add_item("pendant")
	Inventory.select_hotbar(0)
	var target: NPC = town.npcs[candidate_id]
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	target.interact(town.player)
	for i in 10:
		if dialog._showing_choices or not dialog.is_open():
			break
		dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var idx := labels.find("Give Pendant")
	assert_true(idx >= 0, "precondition: Give Pendant choice must be offered")
	(dialog.choice_box.get_child(idx) as Button).pressed.emit()
	await wait_process_frames(2)


func _give_pendant_to_rosa(town: Node2D) -> void:
	await _give_pendant(town, "rosa")


## ---- the full pilot chain ----

func test_full_rosa_pilot_chain_bouquet_to_married() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	# ---- bouquet -> dating (L8+) ----
	Relationships._get_or_create("rosa")["points"] = 800  # L8
	Relationships.mark_event_seen("rosa", "l3")
	Relationships.mark_event_seen("rosa", "l7")
	Relationships.mark_event_seen("rosa", "l8")  # isolate the bouquet flow from Rosa's real l8 heart-event
	Inventory.add_item("bouquet")
	Inventory.select_hotbar(0)
	var rosa: NPC = town.npcs["rosa"]
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	rosa.interact(town.player)
	for i in 10:
		if dialog._showing_choices or not dialog.is_open():
			break
		dialog._advance()
	var labels: Array[String] = []
	for child in dialog.choice_box.get_children():
		labels.append((child as Button).text)
	var bouquet_idx := labels.find("Give Bouquet")
	assert_true(bouquet_idx >= 0, "precondition: Give Bouquet choice offered")
	(dialog.choice_box.get_child(bouquet_idx) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(Romance.is_dating("rosa"), "bouquet at L8 must start dating")
	if dialog.is_open():
		dialog._advance()  # close the reaction line

	# ---- bond up to L10 ----
	Relationships._get_or_create("rosa")["points"] = 1000
	Relationships.mark_event_seen("rosa", "l10")  # isolate the pendant flow from Rosa's real l10 heart-event
	assert_eq(Relationships.level("rosa"), 10)

	# ---- pendant -> proposal scene ----
	await _give_pendant_to_rosa(town)
	assert_true(GameFlow.cutscene_active, "the proposal scene must be playing")
	assert_eq(Inventory.count_of("pendant"), 0, "pendant is spent presenting the proposal")

	# ---- accept (question choice index 0) -> engaged ----
	await _drive_scene_to_completion(town, 0)
	assert_true(Romance.is_engaged(), "accepting must set the engagement")
	assert_eq(Romance.engaged_to(), "rosa")
	assert_false(GameFlow.cutscene_active, "the proposal scene must have ended")

	# ---- next day-rollover -> wedding fires on town entry/block-change ----
	# A real player's "day passes" always crosses AT LEAST one block boundary
	# (sleep -> wake resets to DAY_START_MINUTES, a fresh 6-9 block) before
	# ever landing back in a 9-12 block, so town.gd's own _on_time_ticked
	# always sees a block change on the actual next real entry. This test
	# advances Clock.day directly without a real sleep/rollover, so it calls
	# the SAME check the map itself would run on that block-change tick
	# (town.gd's private _check_wedding(), see its class doc) directly,
	# rather than relying on _on_time_ticked's block-diff guard to happen to
	# see a change from ITS OWN last-seen values.
	Clock.day += 1
	Clock.minutes = 10 * 60  # 9-12 block
	var wedding_started: bool = town.call("_check_wedding")
	assert_true(wedding_started, "the wedding scene must be playing the day the wedding is due")
	await wait_process_frames(2)
	assert_true(GameFlow.cutscene_active, "the wedding scene must be playing the day the wedding is due")

	var spouse_bond_before := Relationships.points("rosa")
	await _drive_scene_to_completion(town)

	# ---- married + spouse + cap lift ----
	assert_true(Romance.is_married_to("rosa"), "the wedding must finalize the marriage")
	assert_eq(Romance.spouse(), "rosa")
	assert_false(Romance.is_engaged(), "engagement must be cleared once married")
	assert_eq(Relationships.max_points_for("rosa"), 1400, "spouse cap lift must be live immediately")
	assert_eq(Relationships.max_level_for("rosa"), 14)
	assert_true(Relationships.points("rosa") >= spouse_bond_before, "the ceremony must not have DECREASED bond")

	# The wedding must not re-fire on a later re-check (Romance.is_wedding_due()
	# is false once engagement is cleared, same "once-only" spirit as
	# TriggerService's authored scenes).
	Clock.day += 1
	var wedding_restarted: bool = town.call("_check_wedding")
	assert_false(wedding_restarted, "no second wedding must fire")
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active, "no second wedding must fire")


func test_wedding_ends_other_dating_with_a_bond_ding() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	_arm_rosa_dating_at_l10(town)
	Relationships._get_or_create("willow")["points"] = 800
	Romance.start_dating("willow")
	assert_true(Romance.is_dating("willow"), "precondition: also dating Willow")
	var willow_bond_before := Relationships.points("willow")

	await _give_pendant_to_rosa(town)
	await _drive_scene_to_completion(town, 0)  # accept
	assert_true(Romance.is_engaged())

	Clock.day += 1
	Clock.minutes = 10 * 60
	var wedding_started: bool = town.call("_check_wedding")
	assert_true(wedding_started, "precondition: the wedding must start")
	await wait_process_frames(2)
	await _drive_scene_to_completion(town)

	assert_true(Romance.is_married_to("rosa"))
	assert_false(Romance.is_dating("willow"), "marrying Rosa must end the Willow dating")
	assert_eq(Relationships.points("willow"), willow_bond_before + Romance.END_OTHER_DATING_BOND_DING)


func test_proposal_decline_leaves_dating_intact_and_no_engagement() -> void:
	var town: Node2D = _make_town()
	add_child_autofree(town)
	await wait_process_frames(2)

	_arm_rosa_dating_at_l10(town)
	await _give_pendant_to_rosa(town)
	assert_true(GameFlow.cutscene_active)

	await _drive_scene_to_completion(town, 1)  # decline (choice_b)

	assert_false(Romance.is_engaged(), "declining must not set the engagement")
	assert_true(Romance.is_dating("rosa"), "declining must not end the existing dating")
	assert_false(Romance.is_married_to("rosa"))
	assert_false(GameFlow.cutscene_active, "the proposal scene must have ended")


## ---- guard: proposal/wedding are cutscenes; the EventRunner._exit_tree() ----
## ---- backstop restores the gate/Clock even if torn down mid-scene ----

func test_proposal_scene_teardown_mid_play_restores_cutscene_gate_and_clock() -> void:
	## Marriage M1's parametric propose.gd scene runs through the SAME
	## EventRunner every authored DSL scene does (see romance_events.gd's
	## play_proposal()), so it inherits _exit_tree()'s "Quit to Title mid-
	## scene" backstop for free — this test pins that down explicitly for a
	## romance scene rather than trusting it by inference. Mirrors
	## test_event_runner.gd's own test_runner_freed_mid_scene_restores_gate_
	## and_clock, but drives the REAL ProposeEvent.data() script instead of a
	## synthetic one. A real DialogBox is required so the scene's first
	## `speak` command actually holds (awaiting DialogBox.finished) instead of
	## racing through to `end` in the same frame with no dialog box to await.
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)
	var temp_node := Node.new()
	add_child_autofree(temp_node)
	var doomed_runner := EventRunner.new()
	temp_node.add_child(doomed_runner)
	Clock.paused = false
	doomed_runner.play(ProposeEvent.data("rosa"))
	await wait_process_frames(1)
	assert_true(GameFlow.cutscene_active, "precondition: the proposal scene is mid-play")
	assert_true(Clock.paused, "precondition: the proposal scene has frozen the clock")
	temp_node.free()  # tears down the runner WITHOUT _end_scene() ever running
	await wait_process_frames(1)
	assert_false(GameFlow.cutscene_active, "_exit_tree() backstop must clear the stuck gate")
	assert_false(Clock.paused, "_exit_tree() backstop must restore Clock.paused")


func test_wedding_scene_teardown_mid_play_restores_cutscene_gate_and_clock() -> void:
	var dialog := (load("res://scripts/ui/dialog_box.gd") as GDScript).new() as DialogBox
	add_child_autofree(dialog)
	var temp_node := Node.new()
	add_child_autofree(temp_node)
	var doomed_runner := EventRunner.new()
	temp_node.add_child(doomed_runner)
	Clock.paused = false
	doomed_runner.play(WeddingEvent.data("rosa"))
	await wait_process_frames(1)
	assert_true(GameFlow.cutscene_active, "precondition: the wedding scene is mid-play")
	assert_true(Clock.paused, "precondition: the wedding scene has frozen the clock")
	temp_node.free()
	await wait_process_frames(1)
	assert_false(GameFlow.cutscene_active, "_exit_tree() backstop must clear the stuck gate")
	assert_false(Clock.paused, "_exit_tree() backstop must restore Clock.paused")


## ---- Marriage M2: all 5 candidates run the SAME chain with THEIR voice ----

func test_all_five_candidates_run_the_full_bouquet_to_wedding_chain() -> void:
	## Loops Rosa's own pilot chain (bouquet -> dating -> L10 -> pendant ->
	## propose -> accept -> engaged -> wedding -> married) across all 5
	## romanceable candidates in ONE test, through the same real town.tscn —
	## a separate town instance per candidate (rather than reusing one across
	## iterations) keeps each iteration's NPC/dialog/cutscene state isolated,
	## matching how a real player only ever runs this chain against one NPC
	## instance at a time.
	##
	## Each iteration's town is freed (not add_child_autofree'd) BEFORE the
	## next one is created: autofree only tears down at the end of the whole
	## test function, so five town instances would otherwise all be alive
	## simultaneously — every town.tscn auto-instances its own DialogBox
	## added to the "dialog_box" group (see dialog_box.gd's _ready()), and
	## get_first_node_in_group("dialog_box") would then always resolve to the
	## FIRST iteration's box, not the current candidate's.
	for candidate_id: String in ALL_CANDIDATES:
		var town: Node2D = _make_town()
		add_child(town)
		await wait_process_frames(2)

		# ---- bouquet -> dating (L8+) ----
		Relationships._get_or_create(candidate_id)["points"] = 800  # L8
		Relationships.mark_event_seen(candidate_id, "l3")
		Relationships.mark_event_seen(candidate_id, "l7")
		Relationships.mark_event_seen(candidate_id, "l8")  # isolate the bouquet flow from the real l8 heart-event
		Inventory.add_item("bouquet")
		Inventory.select_hotbar(0)
		var target: NPC = town.npcs[candidate_id]
		var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
		target.interact(town.player)
		for i in 10:
			if dialog._showing_choices or not dialog.is_open():
				break
			dialog._advance()
		var labels: Array[String] = []
		for child in dialog.choice_box.get_children():
			labels.append((child as Button).text)
		var bouquet_idx := labels.find("Give Bouquet")
		assert_true(bouquet_idx >= 0, "%s: precondition: Give Bouquet choice offered" % candidate_id)
		(dialog.choice_box.get_child(bouquet_idx) as Button).pressed.emit()
		await wait_process_frames(2)
		assert_true(Romance.is_dating(candidate_id), "%s: bouquet at L8 must start dating" % candidate_id)
		if dialog.is_open():
			dialog._advance()  # close the reaction line

		# ---- bond up to L10 ----
		Relationships._get_or_create(candidate_id)["points"] = 1000
		Relationships.mark_event_seen(candidate_id, "l10")  # isolate the pendant flow from the real l10 heart-event
		assert_eq(Relationships.level(candidate_id), 10)

		# ---- dating line surfaces on an ordinary talk while dating ----
		var dating_lines: Array = _data(candidate_id).get("dating_lines", [])
		assert_eq(dating_lines.size(), 3, "%s: must have 3 authored dating lines" % candidate_id)

		# ---- pendant -> proposal scene, in THIS candidate's authored voice ----
		await _give_pendant(town, candidate_id)
		assert_true(GameFlow.cutscene_active, "%s: the proposal scene must be playing" % candidate_id)
		assert_eq(Inventory.count_of("pendant"), 0, "%s: pendant is spent presenting the proposal" % candidate_id)

		# ---- accept (question choice index 0) -> engaged ----
		await _drive_scene_to_completion(town, 0)
		assert_true(Romance.is_engaged(), "%s: accepting must set the engagement" % candidate_id)
		assert_eq(Romance.engaged_to(), candidate_id)
		assert_false(GameFlow.cutscene_active, "%s: the proposal scene must have ended" % candidate_id)

		# ---- next day-rollover -> wedding fires on town entry/block-change ----
		Clock.day += 1
		Clock.minutes = 10 * 60  # 9-12 block
		var wedding_started: bool = town.call("_check_wedding")
		assert_true(wedding_started, "%s: the wedding scene must be playing the day the wedding is due" % candidate_id)
		await wait_process_frames(2)
		assert_true(GameFlow.cutscene_active, "%s: the wedding scene must be playing" % candidate_id)

		await _drive_scene_to_completion(town)

		# ---- married + spouse + cap lift, with THIS candidate's authored vow ----
		assert_true(Romance.is_married_to(candidate_id), "%s: the wedding must finalize the marriage" % candidate_id)
		assert_eq(Romance.spouse(), candidate_id)
		assert_false(Romance.is_engaged(), "%s: engagement must be cleared once married" % candidate_id)
		assert_eq(Relationships.max_points_for(candidate_id), 1400, "%s: spouse cap lift must be live" % candidate_id)
		assert_eq(Relationships.max_level_for(candidate_id), 14)

		# ---- the authored voice actually shipped, not the shared generic ----
		assert_ne(RomanceEvents.vow_line(candidate_id), RomanceEvents._GENERIC_VOW,
			"%s: must use its own authored vow, not the shared generic" % candidate_id)
		assert_ne(RomanceEvents.proposal_accept_line(candidate_id), RomanceEvents._GENERIC_ACCEPT,
			"%s: must use its own authored proposal reaction, not the shared generic" % candidate_id)

		# ---- clean slate for the next candidate's iteration ----
		town.free()  # see the loop's own doc: must be gone before the next town's DialogBox group lookup
		await wait_process_frames(1)
		Romance._state = {}
		Romance._spouse = ""
		SaveManager.world.erase("romance")
		Relationships._state = {}
		SaveManager.world.erase("relationships")
		SaveManager.world.erase("events_seen")
		GameState.flags = {}
		GameFlow.cutscene_active = false
		get_tree().paused = false
		Inventory.reset()
		Clock.day = 1
		Clock.minutes = Clock.DAY_START_MINUTES


func _data(npc_id: String) -> Dictionary:
	var script: GDScript = load(_DIALOG_SCRIPTS[npc_id])
	return script.DATA


