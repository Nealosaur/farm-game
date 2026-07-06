class_name EventRunner
extends Node
## Alive Stride 2: executes one parsed EventScript against the live scene
## tree. One EventRunner instance per playing scene; TriggerService (or a
## direct interact() hook, e.g. the migrated day-1 intro) adds it as a child
## of the current map root and calls play().
##
## Dispatch: each command name maps to a `_cmd_<name>` method on this class,
## looked up via has_method()/call() (Stardew's reflection idea, expressed the
## Godot-idiomatic way — no shared code with any existing interpreter).
## Unknown commands push_warning() and are skipped; a script can never crash
## the game, only under-perform its author's intent.
##
## Gameplay freeze: sets GameFlow.cutscene_active = true for the FULL
## duration of play() (cleared at every return path in _end_scene()) —
## Player.Idle/Move skip input polling while this is true (see their
## update()/physics_update() guards), and Clock.paused mirrors it too so time
## doesn't advance mid-scene. Camera is restored to its prior parent/position
## when the script ends (either via `end` or running off the last line).
##
## Frame-driven, NOT timer/signal-driven, for `wait` and `move` (Alive Stride
## 1's NPC walk controller is the template): both commands advance internal
## countdown/queue state in _process(delta) and resolve a pending Signal once
## done, exactly like NPC's own _walk_queue/_process. This is deliberate for
## testability — GUT's simulate(obj, times, delta) drives _process() directly
## without real engine frames or real wall-clock time (see test_npc_walk.gd's
## existing convention), so the SAME test helper drives an EventRunner's
## walk/wait exactly like it drives an NPC's. `speak`/`question` await
## DialogBox's own `finished` signal instead — already event-driven and
## already exercised the same way by every existing dialog test (advance via
## dialog._advance() / button presses), so no extra plumbing is needed there.
##
## Actor resolution: `resolve_actor(id)` first looks for a live NPC already on
## the current map (by npc_data.id, searched under the "map_root" group's
## World child), and falls back to SPAWNING a temporary instance (via
## NPCFactory) at an offscreen edge cell if none is present — needed for
## scenes whose actor doesn't keep a normal schedule slot on this map at this
## hour (Garrick's reconciliation entrance, Alden's day-1 intro cameo).
## Temp-spawned actors are tracked in `_temp_actors` and queue_free()'d when
## the script ends, regardless of how it ends (end/last-line/error skip).
## "player" is never resolved this way — it's looked up once via the
## "player" group and cached directly.
##
## Camera: `camera <target>` retargets the SAME Camera2D the player already
## carries (CameraShake, a child of Player — see farm.gd/town.gd) by
## reparenting it to the target actor for the duration of the shot, then
## `_restore_camera()` reparents it back to the player at end-of-script. This
## avoids needing a second camera node or any special-case "which camera is
## active" bookkeeping — Camera2D.make_current() stays untouched since only
## one Camera2D ever exists in these scenes.

signal finished
signal _command_done  # internal: _process-driven commands (wait/move) resolve their await through this

const NPCFactoryScript := preload("res://scripts/npcs/npc_factory.gd")
const EventScriptClass := preload("res://scripts/events/event_script.gd")

const WALK_SPEED := 40.0  # matches NPC.WALK_SPEED — a shared "cutscene walk" pace
const OFFSCREEN_SPAWN_CELL := Vector2i(-5, -5)  # temp-actor spawn: off any real map layout
const ARRIVE_EPSILON := 0.5  # px; snap-to-target threshold, matches NPC's own walker feel

var _commands: Array[Dictionary] = []
var _labels: Dictionary = {}  # label name -> command index
var _pc := 0
var _running := false
var _jumped := false
var _busy_command := ""  # empty when idle between commands; set while a _process-driven command is in flight

var _actors: Dictionary = {}       # actor id ("player" or npc_id) -> Node2D
var _temp_actors: Array[Node2D] = []  # spawned-for-this-scene actors, freed at end
var _player: Node2D
var _camera: Camera2D
var _camera_original_parent: Node
var _camera_original_position: Vector2
var _clock_was_paused := false
var _question_result := -1
var _dialog: DialogBox

## ---- `wait` state (frame-driven; see class doc) ----
var _wait_seconds_left := 0.0

## ---- `move` state (frame-driven; see class doc) ----
var _walk_actor: Node2D
var _walk_queue: Array[Vector2] = []


func play(script_data: Dictionary) -> void:
	## script_data: {"id": String, "script": Array[String], ...}. Preconditions
	## are NOT re-checked here (TriggerService already gated the call) — this
	## is a pure "run these commands" entry point so tests can drive it
	## directly without needing a full precondition/trigger setup.
	var script: Array = script_data.get("script", [])
	_commands = EventScriptClass.parse(script)
	_index_labels()
	_pc = 0
	_running = true

	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_actors["player"] = _player
	_dialog = get_tree().get_first_node_in_group("dialog_box") as DialogBox
	_find_camera()

	GameFlow.cutscene_active = true
	_clock_was_paused = Clock.paused
	Clock.paused = true

	await _run_loop()


func _run_loop() -> void:
	while _running and _pc < _commands.size():
		var cmd_dict: Dictionary = _commands[_pc]
		_jumped = false
		await _dispatch(cmd_dict)
		if not _running:
			break
		if not _jumped:
			_pc += 1
	_end_scene()


func _index_labels() -> void:
	_labels = {}
	for i in _commands.size():
		if _commands[i]["cmd"] == "label":
			var args: Array = _commands[i]["args"]
			if not args.is_empty():
				_labels[String(args[0])] = i


func _dispatch(cmd_dict: Dictionary) -> void:
	var cmd := String(cmd_dict["cmd"])
	if cmd == "":
		return  # blank line from a malformed script entry: skip silently
	var method := "_cmd_" + cmd
	if not has_method(method):
		push_warning("EventRunner: unknown command '%s' — skipped" % cmd)
		return
	await call(method, cmd_dict["args"])


func _end_scene() -> void:
	_running = false
	_restore_camera()
	for actor in _temp_actors:
		if is_instance_valid(actor):
			actor.queue_free()
	_temp_actors = []
	# Clear the resolve cache too — it can hold the temp actors we just freed
	# (or NPCs despawned mid-scene); a stale typed return of a freed instance
	# is exactly Godot's "Trying to return a previously freed instance" error.
	_actors = {}
	Clock.paused = _clock_was_paused
	GameFlow.cutscene_active = false
	finished.emit()


func _exit_tree() -> void:
	## Soft-lock backstop (C1): if this runner is freed WHILE still `_running`
	## — the map/scene tree it lives under gets torn down mid-scene (e.g.
	## "Quit to Title" during a mid-wait/mid-move cutscene moment, before
	## _end_scene ever gets to run) — the gameplay-freeze gate and Clock.paused
	## would otherwise stay stuck true FOREVER, since _end_scene() is the only
	## place that normally clears them and it never gets called on this path.
	## Idempotent with _end_scene(): that method sets _running = false FIRST,
	## so a normal end-of-scene teardown (which frees this node afterward, e.g.
	## EventDirector's queue_free()) sees _running already false here and
	## no-ops. Deliberately minimal — no camera/temp-actor cleanup here: the
	## whole map subtree (camera, temp NPCs, everything) is being freed by the
	## SAME scene-change that is freeing this node, so there is nothing left
	## to reparent or queue_free() by the time this runs; touching those nodes
	## from _exit_tree() would risk operating on already-freed instances.
	if not _running:
		return
	_running = false
	Clock.paused = _clock_was_paused
	GameFlow.cutscene_active = false


func _process(delta: float) -> void:
	match _busy_command:
		"wait":
			_advance_wait(delta)
		"move":
			_advance_walk(delta)
		_:
			pass


## ---- actor resolution ----

func resolve_actor(actor_id: String) -> Node2D:
	if actor_id == "player":
		return _player
	if _actors.has(actor_id):
		var cached = _actors[actor_id]
		if is_instance_valid(cached):
			return cached
		_actors.erase(actor_id)  # NPC freed under us (despawn/block change)
	var found := _find_live_npc(actor_id)
	if found != null:
		_actors[actor_id] = found
		return found
	if not _running:
		# Finding live NPCs is harmless anytime, but SPAWNING a temp actor
		# outside a running scene would orphan it forever (_end_scene is the
		# only cleanup point). Post-scene resolution of a temp = null.
		return null
	var spawned := _spawn_temp_actor(actor_id)
	if spawned != null:
		_actors[actor_id] = spawned
		_temp_actors.append(spawned)
	return spawned


func _find_live_npc(npc_id: String) -> NPC:
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		return null
	for child in root.find_children("*", "NPC", true, false):
		var npc := child as NPC
		if npc != null and npc.npc_data != null and npc.npc_data.id == npc_id and npc.visible:
			return npc
	return null


func _spawn_temp_actor(npc_id: String) -> NPC:
	## Lifecycle: spawned OFFSCREEN (see OFFSCREEN_SPAWN_CELL, well outside
	## every authored map's layout) so it never visibly pops in before its
	## first scripted `move`/`teleport` places it on-camera. Freed in
	## _end_scene() regardless of how the scene ends — a script that jumps
	## past its own spawn's later cleanup line still cleans up, since the
	## spawn is tracked the moment resolve_actor() creates it, not when the
	## script "would" free it.
	if not NPCFactoryScript.REGISTRY.has(npc_id):
		push_warning("EventRunner: cannot spawn unknown actor '%s'" % npc_id)
		return null
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		return null
	var world := root.get_node_or_null("World")
	var parent: Node = world if world != null else root
	var npc := NPCFactoryScript.make_npc(npc_id)
	npc.position = MapBuilder.cell_center(OFFSCREEN_SPAWN_CELL)
	parent.add_child(npc)
	return npc


## ---- camera ----

func _find_camera() -> void:
	var root := get_tree().get_first_node_in_group("map_root")
	if root != null:
		var found: Array = root.find_children("*", "Camera2D", true, false)
		if not found.is_empty():
			_camera = found[0] as Camera2D
	if _camera == null and _player != null:
		for child in _player.get_children():
			if child is Camera2D:
				_camera = child
				break
	if _camera != null:
		_camera_original_parent = _camera.get_parent()
		_camera_original_position = _camera.position


func _restore_camera() -> void:
	if _camera == null or _camera_original_parent == null:
		return
	if _camera.get_parent() != _camera_original_parent:
		_camera.get_parent().remove_child(_camera)
		_camera_original_parent.add_child(_camera)
	_camera.position = _camera_original_position
	_camera.make_current()


## ---- commands ----

func _cmd_speak(args: Array[String]) -> void:
	if args.size() < 2 or _dialog == null:
		return
	var text := args[1]
	var lines: Array[String] = [text]
	_dialog.show_lines(lines)
	await _dialog.finished


func _cmd_move(args: Array[String]) -> void:
	if args.size() < 3:
		return
	var actor := resolve_actor(args[0])
	if actor == null:
		return
	var target := Vector2i(int(args[1]), int(args[2]))
	var mode := args[3] if args.size() > 3 else "walk"
	if mode == "teleport":
		actor.position = MapBuilder.cell_center(target)
		return
	await _begin_walk(actor, target)


func _cmd_face(args: Array[String]) -> void:
	if args.size() < 2:
		return
	var actor := resolve_actor(args[0])
	if actor == null:
		return
	var direction := args[1]
	var dir_vec := _resolve_face_direction(actor, direction)
	if dir_vec == Vector2.ZERO:
		return
	_apply_facing(actor, dir_vec.normalized())


func _resolve_face_direction(actor: Node2D, direction: String) -> Vector2:
	match direction:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"player":
			if _player == null:
				return Vector2.ZERO
			return (_player.global_position - actor.global_position)
		_:
			if direction.begins_with("actor:"):
				var other := resolve_actor(direction.substr(6))
				if other == null:
					return Vector2.ZERO
				return other.global_position - actor.global_position
			return Vector2.ZERO


func _cmd_wait(args: Array[String]) -> void:
	if args.is_empty():
		return
	var seconds := float(args[0])
	if seconds <= 0.0:
		return
	_wait_seconds_left = seconds
	_busy_command = "wait"
	await wait_idle_frame_signal()


func _advance_wait(delta: float) -> void:
	_wait_seconds_left -= delta
	if _wait_seconds_left <= 0.0:
		_busy_command = ""
		_command_done.emit()


func _cmd_camera(args: Array[String]) -> void:
	if args.is_empty() or _camera == null:
		return
	var target := args[0]
	if target.find(",") != -1:
		var parts := target.split(",")
		if parts.size() == 2:
			var world_pos := Vector2(float(parts[0]), float(parts[1]))
			_retarget_camera_to_position(world_pos)
		return
	var actor := resolve_actor(target)
	if actor == null:
		return
	_retarget_camera_to_actor(actor)


func _retarget_camera_to_actor(actor: Node2D) -> void:
	if _camera.get_parent() == actor:
		return
	_camera.get_parent().remove_child(_camera)
	actor.add_child(_camera)
	_camera.position = Vector2.ZERO


func _retarget_camera_to_position(world_pos: Vector2) -> void:
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		return
	if _camera.get_parent() != root:
		_camera.get_parent().remove_child(_camera)
		root.add_child(_camera)
	_camera.position = world_pos


func _cmd_question(args: Array[String]) -> void:
	if args.size() < 5 or _dialog == null:
		return
	var prompt := args[0]
	var label_a := args[1]
	var text_a := args[2]
	var label_b := args[3]
	var text_b := args[4]
	var lines: Array[String] = [prompt]
	var choices: Array[String] = [text_a, text_b]
	_question_result = -1
	if not _dialog.choice_made.is_connected(_on_question_choice):
		_dialog.choice_made.connect(_on_question_choice, CONNECT_ONE_SHOT)
	_dialog.show_choices(lines, choices)
	await _dialog.finished
	var target_label := label_a if _question_result == 0 else label_b
	if _labels.has(target_label):
		_pc = _labels[target_label]
		_jumped = true


func _on_question_choice(index: int) -> void:
	_question_result = index


func _cmd_label(_args: Array[String]) -> void:
	pass  # no-op marker; _index_labels() already recorded its position


func _cmd_jump(args: Array[String]) -> void:
	if args.is_empty():
		return
	var target_label := args[0]
	if _labels.has(target_label):
		_pc = _labels[target_label]
		_jumped = true
	else:
		push_warning("EventRunner: jump to unknown label '%s' — ignored" % target_label)


func _cmd_bond(args: Array[String]) -> void:
	if args.size() < 2:
		return
	var npc_id := args[0]
	var delta := int(args[1])
	Relationships.add_flat_bond(npc_id, delta)


func _cmd_give(args: Array[String]) -> void:
	if args.is_empty():
		return
	var item_id := args[0]
	var count := int(args[1]) if args.size() > 1 else 1
	Inventory.add_item(item_id, count)


func _cmd_gold(args: Array[String]) -> void:
	if args.is_empty():
		return
	GameState.add_gold(int(args[0]))


func _cmd_flag(args: Array[String]) -> void:
	if args.is_empty():
		return
	GameState.flags[args[0]] = true


func _cmd_toast(args: Array[String]) -> void:
	if args.is_empty():
		return
	EventBus.toast_requested.emit(args[0])


func _cmd_end(_args: Array[String]) -> void:
	_running = false


## ---- walking (shared by `move` for both NPC actors and the player) ----

func wait_idle_frame_signal() -> void:
	await _command_done


func _begin_walk(actor: Node2D, target_cell: Vector2i) -> void:
	var grid := _path_grid_for_current_map()
	var start_cell := MapBuilder.cell_of(actor.global_position)
	var path: PackedVector2Array = PackedVector2Array()
	if grid != null:
		path = grid.find_path(start_cell, target_cell)
	if path.is_empty():
		# Unreachable/no grid: fall back to an instant snap rather than hang
		# the script forever (documented — mirrors NPC.refresh_schedule()'s
		# own teleport fallback for the same class of failure).
		actor.position = MapBuilder.cell_center(target_cell)
		return
	_walk_queue = []
	for cell: Vector2 in path:
		_walk_queue.append(MapBuilder.cell_center(Vector2i(cell)))
	if not _walk_queue.is_empty():
		_walk_queue.remove_at(0)  # first entry is the actor's own current cell-center
	if _walk_queue.is_empty():
		return  # already at target
	_walk_actor = actor
	_busy_command = "move"
	await wait_idle_frame_signal()


func _advance_walk(delta: float) -> void:
	if _walk_actor == null or not is_instance_valid(_walk_actor) or _walk_queue.is_empty():
		_busy_command = ""
		_walk_actor = null
		_command_done.emit()
		return
	var dest: Vector2 = _walk_queue[0]
	var to_dest := dest - _walk_actor.global_position
	var dist := to_dest.length()
	var step := WALK_SPEED * delta
	if dist <= maxf(step, ARRIVE_EPSILON):
		_walk_actor.global_position = dest
		_walk_queue.remove_at(0)
	else:
		var dir := to_dest / dist
		_apply_facing(_walk_actor, dir)
		_walk_actor.global_position += dir * step
	if _walk_queue.is_empty():
		_busy_command = ""
		_walk_actor = null
		_command_done.emit()


func _apply_facing(actor: Node2D, dir: Vector2) -> void:
	if actor.has_method("_update_facing"):
		actor.call("_update_facing", dir)
		return
	if actor.has_method("update_facing"):
		actor.call("update_facing", dir)


func _path_grid_for_current_map() -> PathGrid:
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		return null
	return root.get("path_grid") as PathGrid
