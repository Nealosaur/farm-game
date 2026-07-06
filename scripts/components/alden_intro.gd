extends Area2D
## World Stride D: Day-1 opening. Mayor Alden stands on the farm, one-time,
## any block of the morning of day 1 (bible: "Wake Day 1 -> Mayor Alden is
## standing on the farm... interact plays INTRO verbatim... grants Quest:
## New Roots"). This is a DEDICATED interactable — not the schedule-driven
## NPC scene — because the intro is a special one-shot dialog flow that
## bypasses the ordinary talk/resolver/gift machinery entirely (no bond
## points, no tier pool, nothing else Relationships/DialogResolver do
## applies to this single scripted conversation).
##
## Lifecycle: farm.gd instances this only when
## `Clock.day == 1 and not GameState.flags.get("intro_done", false)`, and
## only keeps it alive/visible for the CURRENT time block — the bible's
## "he can simply despawn from farm at block change" clause is honored by
## farm.gd's existing _on_time_ticked block-boundary hook calling
## refresh_for_block() below (mirrors NPC.refresh_schedule()'s shape without
## depending on NPCRegistry, since this isn't a registry-scheduled NPC).
##
## Interacting plays the verbatim INTRO lines, grants "New Roots"
## (EventBus.quest_updated -> HUD toast handles the "Quest updated" line),
## sets GameState.flags["intro_done"] = true, and hides itself — the
## contract's "one-time" behavior. farm.gd does not free the node (matches
## the rest of the codebase's "instance once, hide/show" NPC convention) but
## once intro_done is true this node is never instanced again on a future
## farm.gd _ready() (the day-1 gate above already prevents that on day 2+).

var _tick: Label


func _ready() -> void:
	_tick = Label.new()
	_tick.text = "!"
	_tick.position = Vector2(-4, -40)
	_tick.add_theme_font_size_override("font_size", 16)
	_tick.modulate = Color(1, 0.9, 0.2)
	add_child(_tick)


func interact(_player: Node) -> void:
	if GameState.flags.get("intro_done", false):
		return
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog == null or dialog.is_open():
		return
	var intro: Dictionary = AldenDialog.DATA.get("intro", {})
	var lines: Array[String] = []
	for line: String in intro.get("lines", []):
		lines.append(line)
	if lines.is_empty():
		return
	if not dialog.finished.is_connected(_on_intro_finished):
		dialog.finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	dialog.show_lines(lines)


func _on_intro_finished() -> void:
	GameState.flags["intro_done"] = true
	Quests.grant_new_roots()
	visible = false
	set_deferred("monitoring", false)


func refresh_for_block() -> void:
	## Hides once day 1's morning has fully passed OR once the intro has
	## already played (whichever first) — "any block that morning" is
	## interpreted as blocks 6-9/9-12 (the bible's own block table has no
	## finer granularity); by the 12-17 block the contract's "he follows his
	## normal schedule from the NEXT block" takes over, so this node should
	## no longer be interactable/visible.
	var still_morning: bool = NPCRegistry.block_for(Clock.hour()) in [NPCRegistry.BLOCK_6_9, NPCRegistry.BLOCK_9_12]
	var intro_done := bool(GameState.flags.get("intro_done", false))
	var should_show: bool = still_morning and not intro_done
	visible = should_show
	set_deferred("monitoring", should_show)
