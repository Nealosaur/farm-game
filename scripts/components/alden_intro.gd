extends Area2D
## World Stride D: Day-1 opening. Mayor Alden's arrival, one-time, any block
## of the morning of day 1 (bible: "Wake Day 1 -> Mayor Alden is standing on
## the farm... interact plays INTRO verbatim... grants Quest: New Roots").
##
## Alive Stride 2: this node is now a THIN TRIGGER — interact() no longer
## plays the dialog itself. It hands off to an EventRunner (see
## scripts/events/event_runner.gd) running data/events/intro_alden.gd's
## script, which walks a TEMP-SPAWNED Alden actor in from the farm's west
## edge, speaks the exact same verbatim INTRO lines (now sourced from the
## script's own `speak` commands, not AldenDialog.DATA directly — though the
## text is identical, copied from the same characters.md source), and walks
## him back off toward town before despawning. The quest grant + intro_done
## flag + self-hide happen in _on_script_finished() below, same as before —
## EventRunner has no bespoke "grant a quest" command (see intro_alden.gd's
## class doc), so this call site still owns that one line, exactly as the
## pre-stride version did.
##
## Lifecycle: farm.gd instances this only when
## `Clock.day == 1 and not GameState.flags.get("intro_done", false)`, and
## only keeps it alive/visible for the CURRENT time block — refresh_for_block()
## below is unchanged from the pre-stride version.
##
## This node itself stays at ALDEN_INTRO_CELL as the interactable trigger
## marker (so the player has something concrete to walk up to and press
## interact on) — it is NOT the Alden actor seen walking during the scene;
## that's the EventRunner's own temp-spawned NPC, freed automatically when
## the script ends.

var _tick: Label
var _runner: EventRunner
var _playing := false


func _ready() -> void:
	_tick = Label.new()
	_tick.text = "!"
	_tick.position = Vector2(-4, -40)
	_tick.add_theme_font_size_override("font_size", 16)
	_tick.modulate = Color(1, 0.9, 0.2)
	add_child(_tick)


func interact(_player: Node) -> void:
	if GameState.flags.get("intro_done", false) or _playing:
		return
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog == null or dialog.is_open():
		return
	_playing = true
	_runner = EventRunner.new()
	# Added under the map root (same "map_root" group every map script joins
	# in its own _ready(), see farm.gd/town.gd) rather than get_tree()
	# .current_scene — headless tests instance farm.gd directly without ever
	# swapping it in as the tree's current_scene, so current_scene would be
	# null/wrong there; map_root is always the right node in both contexts.
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		root = get_tree().current_scene
	root.add_child(_runner)
	_runner.finished.connect(_on_script_finished, CONNECT_ONE_SHOT)
	_runner.play(IntroAldenEvent.DATA)


func _on_script_finished() -> void:
	GameState.flags["intro_done"] = true
	Quests.grant_new_roots()
	visible = false
	set_deferred("monitoring", false)
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
	_runner = null
	_playing = false


func refresh_for_block() -> void:
	## Hides once day 1's morning has fully passed OR once the intro has
	## already played (whichever first) — "any block that morning" is
	## interpreted as blocks 6-9/9-12 (the bible's own block table has no
	## finer granularity); by the 12-17 block the contract's "he follows his
	## normal schedule from the NEXT block" takes over, so this node should
	## no longer be interactable/visible.
	var still_morning: bool = NPCRegistry.block_for(Clock.hour()) in [NPCRegistry.BLOCK_6_9, NPCRegistry.BLOCK_9_12]
	var intro_done := bool(GameState.flags.get("intro_done", false))
	var should_show: bool = still_morning and not intro_done and not _playing
	visible = should_show
	set_deferred("monitoring", should_show)
