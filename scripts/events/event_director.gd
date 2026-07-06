class_name EventDirector
extends Node
## Alive Stride 2: generic "check TriggerService candidates on map entry and
## block change, fire whichever qualifies" glue — the piece that lets a map
## script (town.gd's own _ready()/_on_time_ticked(), matching every other
## per-map EventBus.time_ticked hook already in this codebase) opt into
## authored EventScript scenes without hand-rolling its own trigger plumbing
## the way the day-1 intro's dedicated Area2D still does (that one has its
## own bespoke lifecycle — see alden_intro.gd's class doc for why it stays
## separate: it is ALSO the on-screen interactable trigger the player walks
## up to, not just a background check).
##
## A map adds ONE EventDirector child, gives it its list of candidate scene
## DATA dicts (in priority order) via `candidates`, and calls check() both
## once at _ready() and again every time its own block-change hook fires.
## check() no-ops immediately if a scene is already playing (never stacks
## two EventRunners) or if TriggerService.pick_scene() finds nothing eligible.
##
## world["events_seen"] bookkeeping (see save_manager.gd's sanctioned-keys
## doc) is owned HERE, not by TriggerService itself (TriggerService is a
## pure/stateless utility with no autoload access) — check()/_on_scene_finished()
## read and write SaveManager.world["events_seen"] directly, the same
## "scene reads/writes world.get(key, default) around a stateless helper"
## shape Festival/Forage already establish elsewhere in this codebase.

signal scene_played(event_id: String)

var candidates: Array[Dictionary] = []
var current_map_id := ""
var _playing := false
var _runner: EventRunner


func check() -> void:
	if _playing:
		return
	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	var scene_data := TriggerService.pick_scene(candidates, seen, Clock.day, current_map_id)
	if scene_data.is_empty():
		return
	_play_scene(scene_data)


func _play_scene(scene_data: Dictionary) -> void:
	_playing = true
	_runner = EventRunner.new()
	add_child(_runner)
	_runner.finished.connect(_on_scene_finished.bind(scene_data), CONNECT_ONE_SHOT)
	_runner.play(scene_data)


func _on_scene_finished(scene_data: Dictionary) -> void:
	var event_id := String(scene_data.get("id", ""))
	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	seen = TriggerService.mark_seen_forever(seen, event_id)
	seen = TriggerService.mark_any_fired_today(seen, Clock.day)
	SaveManager.world["events_seen"] = seen
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
	_runner = null
	_playing = false
	scene_played.emit(event_id)
