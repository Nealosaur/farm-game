class_name VictorySequence
extends Node
## Scene-local victory flow for dungeon_3: on EventBus.boss_defeated, freeze
## gameplay briefly (Clock.paused), toast the vanquish + vertical-slice-complete
## messages, flash the screen, then resume. GameState.flags["boss_defeated"]
## (set by SlimeKing before this signal fires) means the flag is already true
## by the time this runs, so a reload never re-triggers this node's own
## listener (a fresh dungeon_3 load skips spawning the boss entirely, so
## boss_defeated never fires again) — belt-and-suspenders _fired guard below
## covers the same-scene double-emit case defensively.

const FREEZE_DURATION := 1.5
const FLASH_COLOR := Color(0.95, 1.0, 0.85)
const FLASH_DURATION := 0.2

var _fired := false


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	if _fired:
		return
	_fired = true
	_run_sequence()


func _run_sequence() -> void:
	Clock.paused = true
	EventBus.toast_requested.emit("The Slime King is vanquished!")
	await get_tree().create_timer(0.05).timeout
	EventBus.toast_requested.emit("You've conquered the dungeon! (Vertical slice complete)")

	await _flash()
	await get_tree().create_timer(FREEZE_DURATION).timeout
	Clock.paused = false


func _flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99
	var rect := ColorRect.new()
	rect.color = FLASH_COLOR
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	add_child(layer)

	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, FLASH_DURATION)
	tween.tween_property(rect, "modulate:a", 0.0, FLASH_DURATION)
	await tween.finished
	layer.queue_free()
