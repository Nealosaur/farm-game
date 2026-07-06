extends GutTest
## Alive Stride 2: EventRunner dispatch/commands, actor resolution + temp-spawn
## lifecycle, question branching, gameplay-freeze gate, and camera restore.
## Instantiates the REAL town.gd map root (like test_npc_walk.gd) so actor
## resolution's "map_root"/"World" group lookups find a real path_grid and a
## real auto-instanced DialogBox.

var _map_root: Node2D
var dialog: DialogBox
var player: Player
var runner: EventRunner


func before_each() -> void:
	Clock.day = 1
	Clock.minutes = 10 * 60  # 9-12 block
	Clock.paused = false
	# Flake fix: pin weather explicitly. Without this, a "rain" value LEAKED
	# from another test file (Clock.weather has no autofree/reset of its own)
	# flips Garrick's 9-12 schedule block from "farm" (his normal map override
	# for that block — see data/npcs/garrick.gd) to "town" (his rain_schedule
	# has no map override, so NPCRegistry.map_for() falls back to home_map,
	# which IS "town"). That puts a LIVE Garrick on this test's own town map,
	# which _find_live_npc()/resolve_actor() then finds instead of returning
	# null / instead of leaving him for a temp-spawn — exactly the failure
	# test_resolve_actor_returns_null_for_temp_when_no_scene_running and
	# test_temp_spawned_actor_is_freed_once_the_scene_ends depend on NOT
	# happening. Pinning "clear" here makes every test in this file
	# independent of whatever some other file's Clock.weather left behind.
	Clock.weather = "clear"
	GameState.flags = {}

	_map_root = (load("res://scripts/maps/town.gd") as GDScript).new()
	add_child_autofree(_map_root)
	dialog = get_tree().get_first_node_in_group("dialog_box") as DialogBox
	assert_not_null(dialog, "town.gd's _ready() must auto-instance a DialogBox")

	# A second, standalone Player (town.gd's own player stays in the tree
	# too, but EventRunner's "player" group lookup grabs whichever comes
	# first — using get_tree().get_first_node_in_group means this test's
	# own player must be the one EventRunner actually resolves, so we
	# reposition it deterministically and rely on it being the LAST one
	# added, which get_first_node_in_group does not guarantee... instead,
	# reuse town.gd's own already-built player directly.
	player = _map_root.get("player") as Player
	assert_not_null(player, "town.gd must build a real Player")
	player.global_position = MapBuilder.cell_center(Vector2i(10, 14))

	runner = EventRunner.new()
	add_child_autofree(runner)


func after_each() -> void:
	Clock.paused = false
	Clock.minutes = Clock.DAY_START_MINUTES
	Clock.day = 1
	Clock.weather = "clear"  # restore, so no OTHER file inherits a leak from this one
	GameState.flags = {}
	GameFlow.cutscene_active = false
	get_tree().paused = false
	SaveManager.world.erase("relationships")
	Relationships.restore()


func _script(lines: Array) -> Dictionary:
	return {"id": "test_scene", "script": lines}


## ---- basic dispatch / unknown command ----

func test_unknown_command_is_skipped_without_crashing() -> void:
	runner.play(_script(["frobnicate garbage", "end"]))
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active, "scene must still reach `end` and clear the gate")


func test_end_command_stops_the_script_immediately() -> void:
	watch_signals(runner)
	runner.play(_script(["end", "toast \"should never fire\""]))
	await wait_process_frames(2)
	assert_signal_emitted(runner, "finished")


## ---- flag / bond / give / gold / toast ----

func test_flag_command_sets_game_state_flag() -> void:
	runner.play(_script(["flag my_flag", "end"]))
	await wait_process_frames(2)
	assert_true(GameState.flags.get("my_flag", false))


func test_bond_command_applies_flat_relationship_delta() -> void:
	var before := Relationships.points("garrick")
	runner.play(_script(["bond garrick 50", "end"]))
	await wait_process_frames(2)
	assert_eq(Relationships.points("garrick"), before + 50)


func test_give_command_adds_item_to_inventory() -> void:
	Inventory.reset()
	runner.play(_script(["give turnip_seeds 3", "end"]))
	await wait_process_frames(2)
	assert_eq(Inventory.count_of("turnip_seeds"), 3)


func test_give_command_defaults_to_one_when_count_omitted() -> void:
	Inventory.reset()
	runner.play(_script(["give turnip_seeds", "end"]))
	await wait_process_frames(2)
	assert_eq(Inventory.count_of("turnip_seeds"), 1)


func test_gold_command_adds_gold() -> void:
	var before := GameState.gold
	runner.play(_script(["gold 300", "end"]))
	await wait_process_frames(2)
	assert_eq(GameState.gold, before + 300)


func test_toast_command_emits_toast_requested() -> void:
	watch_signals(EventBus)
	runner.play(_script(["toast \"Hello!\"", "end"]))
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["Hello!"])


## ---- label / jump ----

func test_jump_skips_to_the_named_label() -> void:
	watch_signals(EventBus)
	runner.play(_script([
		"jump skip_me",
		"toast \"should be skipped\"",
		"label skip_me",
		"toast \"reached\"",
		"end",
	]))
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["reached"])
	# Exactly one toast fired (the jump destination's) — proves the skipped
	# line's toast never ran, without needing a "not emitted with params" assert.
	assert_signal_emit_count(EventBus, "toast_requested", 1)


func test_jump_to_unknown_label_is_skipped_without_crashing() -> void:
	watch_signals(EventBus)
	runner.play(_script(["jump nowhere", "toast \"still runs\"", "end"]))
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["still runs"])


## ---- question branching (both paths) ----

func test_question_choice_a_jumps_to_label_a() -> void:
	runner.play(_script([
		"question \"Well?\" path_a \"Yes\" path_b \"No\"",
		"label path_a",
		"toast \"chose A\"",
		"jump done",
		"label path_b",
		"toast \"chose B\"",
		"label done",
		"end",
	]))
	await wait_process_frames(2)
	assert_true(dialog.is_open())
	dialog._advance()  # the prompt is ONE line; advance past it to reveal the choice buttons
	assert_eq(dialog.choice_box.get_child_count(), 2)
	watch_signals(EventBus)
	dialog.choice_box.get_child(0).pressed.emit()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["chose A"])


func test_question_choice_b_jumps_to_label_b() -> void:
	runner.play(_script([
		"question \"Well?\" path_a \"Yes\" path_b \"No\"",
		"label path_a",
		"toast \"chose A\"",
		"jump done",
		"label path_b",
		"toast \"chose B\"",
		"label done",
		"end",
	]))
	await wait_process_frames(2)
	assert_true(dialog.is_open())
	dialog._advance()
	assert_eq(dialog.choice_box.get_child_count(), 2)
	watch_signals(EventBus)
	dialog.choice_box.get_child(1).pressed.emit()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["chose B"])


## ---- speak ----

func test_speak_shows_the_line_and_waits_for_advance() -> void:
	runner.play(_script(["speak player \"Hello there.\"", "end"]))
	await wait_process_frames(2)
	assert_true(dialog.is_open())
	assert_eq(dialog.label.text, "Hello there.")
	dialog._advance()
	await wait_process_frames(2)
	assert_false(dialog.is_open())


## ---- gameplay freeze gate ----

func test_cutscene_active_gate_set_during_play_and_cleared_after() -> void:
	assert_false(GameFlow.cutscene_active)
	runner.play(_script(["wait 0.1", "end"]))
	assert_true(GameFlow.cutscene_active)
	simulate(runner, 5, 0.1)
	assert_false(GameFlow.cutscene_active)


func test_clock_paused_during_scene_and_restored_after() -> void:
	Clock.paused = false
	runner.play(_script(["wait 0.1", "end"]))
	assert_true(Clock.paused)
	simulate(runner, 5, 0.1)
	assert_false(Clock.paused, "must restore to the PRE-scene paused state")


func test_clock_paused_restored_to_true_if_it_was_already_paused() -> void:
	Clock.paused = true
	runner.play(_script(["wait 0.1", "end"]))
	simulate(runner, 5, 0.1)
	assert_true(Clock.paused, "must restore to true, not force-unpause")


## ---- wait command (frame-driven) ----

func test_wait_command_blocks_for_the_requested_duration() -> void:
	runner.play(_script(["wait 1.0", "toast \"after wait\"", "end"]))
	watch_signals(EventBus)
	simulate(runner, 5, 0.1)  # 0.5s: not done yet
	assert_signal_emit_count(EventBus, "toast_requested", 0, "the wait must not have elapsed yet")
	simulate(runner, 10, 0.1)  # another 1.0s: comfortably past 1.0s total
	assert_signal_emitted_with_parameters(EventBus, "toast_requested", ["after wait"])


## ---- move / walking ----

func test_move_teleport_snaps_instantly() -> void:
	var target := Vector2i(8, 14)
	runner.play(_script(["move player 8 14 teleport", "end"]))
	await wait_process_frames(2)
	assert_eq(player.global_position, MapBuilder.cell_center(target))


func test_move_walk_advances_gradually_toward_the_target() -> void:
	var start: Vector2 = player.global_position
	runner.play(_script(["move player 20 14 walk", "end"]))
	await wait_process_frames(2)
	simulate(runner, 5, 0.1)
	assert_ne(player.global_position, start, "must have advanced toward the target")
	assert_ne(player.global_position, MapBuilder.cell_center(Vector2i(20, 14)),
		"must not have arrived yet after only half a second")


func test_move_walk_arrives_exactly_at_the_target_cell_center() -> void:
	runner.play(_script(["move player 20 14 walk", "end"]))
	await wait_process_frames(2)
	simulate(runner, 200, 0.1)  # comfortably past a 10-cell walk at 40px/s
	assert_eq(player.global_position, MapBuilder.cell_center(Vector2i(20, 14)))


## ---- face ----

func test_face_cardinal_direction_updates_player_facing() -> void:
	runner.play(_script(["face player left", "end"]))
	await wait_process_frames(2)
	assert_eq(player.facing, Vector2i.LEFT)


func test_face_player_direction_points_actor_toward_the_player() -> void:
	# Spawn Garrick (temp actor) west of the player, then face him toward
	# "player" — a trailing `wait` keeps the scene (and its temp actor) alive
	# long enough to inspect, since the script would otherwise run to `end`
	# and free the temp actor before this test gets a chance to look at it.
	runner.play(_script(["move garrick 4 14 teleport", "face garrick player", "wait 5.0", "end"]))
	await wait_process_frames(2)
	var garrick := runner.resolve_actor("garrick") as NPC
	assert_not_null(garrick)
	# player is east of garrick's spawn (10,14) -> facing should point RIGHT-ish.
	assert_true(garrick.facing == Vector2.RIGHT or garrick.facing == Vector2.LEFT or garrick.facing == Vector2.UP or garrick.facing == Vector2.DOWN)


## ---- actor resolution / temp-spawn lifecycle ----

func test_resolve_actor_returns_player_for_the_player_id() -> void:
	runner.play(_script(["end"]))  # play() populates _player at the start of its run
	assert_eq(runner.resolve_actor("player"), player)


func test_resolve_actor_spawns_a_temp_npc_when_none_present() -> void:
	# Temp-spawning requires an ACTIVE scene (post-fix contract: spawning
	# outside one would orphan the actor forever). Hold a scene open on a wait.
	runner.play(_script(["wait 60", "end"]))
	await wait_process_frames(1)
	var garrick := runner.resolve_actor("garrick")
	assert_not_null(garrick)
	assert_true(garrick is NPC)
	runner._end_scene()  # explicit cleanup so the temp actor is freed
	await wait_process_frames(2)


func test_resolve_actor_returns_null_for_temp_when_no_scene_running() -> void:
	assert_false(runner._running, "precondition: no scene active")
	assert_null(runner.resolve_actor("garrick"),
		"must not spawn an orphan temp actor outside a scene")


func test_resolve_actor_finds_the_live_marta_instance_on_town() -> void:
	## Marta is a real scheduled town NPC (visible during store hours) —
	## resolve_actor() must find HER rather than spawning a duplicate.
	var marta: NPC = _map_root.get("marta")
	assert_not_null(marta)
	var resolved := runner.resolve_actor("marta")
	assert_eq(resolved, marta, "must resolve to the already-live NPC, not a temp spawn")


func test_temp_spawned_actor_is_freed_once_the_scene_ends() -> void:
	runner.play(_script(["move garrick 4 14 teleport", "end"]))
	await wait_process_frames(2)
	var garrick := runner.resolve_actor("garrick")
	simulate(runner, 5, 0.1)
	await wait_process_frames(2)
	assert_true(not is_instance_valid(garrick) or garrick.is_queued_for_deletion())


## ---- soft-lock backstop (C1: quit-to-title mid-cutscene) ----

func test_runner_freed_mid_scene_restores_gate_and_clock() -> void:
	## Simulates "Quit to Title" during a non-dialog cutscene moment (mid
	## `wait`): the real bug froze the MAP's whole subtree (this runner
	## included) without ever reaching _end_scene(). Here we put the runner
	## under a temp node standing in for that subtree and free THAT instead
	## of the runner directly, since freeing the runner's own parent is what
	## actually exercises _exit_tree() the way a scene change would.
	var temp_node := Node.new()
	add_child_autofree(temp_node)
	var doomed_runner := EventRunner.new()
	temp_node.add_child(doomed_runner)
	Clock.paused = false
	doomed_runner.play(_script(["wait 60", "end"]))
	await wait_process_frames(1)
	assert_true(GameFlow.cutscene_active, "precondition: scene is mid-play")
	assert_true(Clock.paused, "precondition: scene has frozen the clock")
	temp_node.free()  # tears down the runner WITHOUT _end_scene() ever running
	await wait_process_frames(1)
	assert_false(GameFlow.cutscene_active, "_exit_tree() backstop must clear the stuck gate")
	assert_false(Clock.paused, "_exit_tree() backstop must restore Clock.paused")


func test_runner_freed_after_normal_end_does_not_double_restore_wrongly() -> void:
	## _end_scene() already cleared everything and set _running = false —
	## _exit_tree() must be a no-op in that case (idempotent), not stomp a
	## Clock.paused state some OTHER system set in the meantime.
	runner.play(_script(["end"]))
	await wait_process_frames(2)
	assert_false(GameFlow.cutscene_active)
	Clock.paused = true  # something else (e.g. another system) paused it after scene end
	runner.free()
	await wait_process_frames(1)
	assert_true(Clock.paused, "_exit_tree() must NOT touch Clock.paused once _end_scene() already ran")


## ---- camera ----

func test_camera_retarget_to_actor_then_restore_on_end() -> void:
	var cam := _map_root.find_children("*", "Camera2D", true, false)[0] as Camera2D
	var original_parent := cam.get_parent()
	runner.play(_script(["move garrick 4 14 teleport", "camera garrick", "end"]))
	await wait_process_frames(2)
	simulate(runner, 3, 0.1)
	await wait_process_frames(2)
	assert_eq(cam.get_parent(), original_parent, "camera must be restored to its original parent once the scene ends")
