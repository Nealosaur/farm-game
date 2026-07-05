class_name NPC
extends Area2D
## Interactable NPC framework (World Stride B). One scene per NPC id, driven
## entirely by data: `npc_data` (schedule/gifts/birthday) + `dialog_data`
## (the MartaDialog.DATA shape — tier pools, seasonal, rain, heart events).
##
## interact(player) flow:
##   1. Heart-event gate: Relationships.pending_event(npc_id) != "" ->
##      play the gated heart-event script (multi-line + ONE two-option
##      choice, ±30 bond) via DialogBox.show_choices(), then mark_event_seen.
##      This SKIPS the normal talk/resolver line entirely for this interact
##      (bible: heart events "auto-play on next talk" — they replace it).
##   2. Otherwise: resolve today's line via DialogResolver.pick(), apply
##      Relationships.talk() if this is the first talk today (+15, no
##      change if already talked), then offer contextual choices:
##        - "Give <item>" if the player's selected hotbar item is giftable
##          (not a ToolData) and today's gift isn't used up yet.
##        - "Browse the store" — Marta only (has_shop == true), shop hours only.
##        - "Leave" — always present, closes with no further effect.
##      Picking "Give <item>" shows the gift reaction line as a FOLLOW-UP
##      dialog (a second DialogBox.show_lines call after the first closes),
##      then removes the item and applies Relationships.gift().
##
## Visibility/position: schedule-driven via NPCRegistry.cell_for(). The map
## scene repositions/hides this node itself (see town.gd) whenever a block
## boundary is crossed; refresh_schedule() is the pure "where should I be
## right now" query this node exposes for that caller to use — it does NOT
## listen to EventBus.time_ticked itself, matching the bible's "maps ask the
## registry" phrasing (one listener per map, not one per NPC instance).

signal gift_given(npc_id: String, item_id: String, reaction: String)

const RP := preload("res://scripts/npcs/npc_registry.gd")

var npc_data: NPCData
var dialog_data: Dictionary = {}
var has_shop := false  # Marta-only: offers "Browse the store" during shop hours
var sprite: Sprite2D

## Set by the caller right before a "Give X" choice resolves, so
## _on_choice_made can look the item back up without re-deriving it from
## Inventory state that may have changed by the time the signal fires.
var _gift_item_id := ""
var _heart_event_id := ""
var _rng := RandomNumberGenerator.new()
## Snapshot of the choice labels/player offered by the CURRENT show_choices()
## call, read back by _on_talk_choice (the button index alone doesn't say
## which action it was — "Give X" only appears when giftable, so its index
## isn't fixed).
var _choice_labels: Array[String] = []
var _choice_player: Node


func _ready() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D


func interact(player: Node) -> void:
	if npc_data == null:
		return
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog == null or dialog.is_open():
		return

	var pending := Relationships.pending_event(npc_data.id)
	if pending != "":
		_play_heart_event(dialog, pending)
		return

	_play_talk(dialog, player)


## ---- heart events ----

func _play_heart_event(dialog: DialogBox, event_key: String) -> void:
	var event: Dictionary = dialog_data.get("heart_events", {}).get(event_key, {})
	if event.is_empty():
		return
	_heart_event_id = event_key
	var lines: Array[String] = []
	for line: String in event.get("lines", []):
		lines.append(line)
	var choices: Array[String] = [
		String(event.get("choice_a", "...")),
		String(event.get("choice_b", "...")),
	]
	if not dialog.choice_made.is_connected(_on_heart_event_choice):
		dialog.choice_made.connect(_on_heart_event_choice, CONNECT_ONE_SHOT)
	dialog.show_choices(lines, choices)


func _on_heart_event_choice(index: int) -> void:
	var event: Dictionary = dialog_data.get("heart_events", {}).get(_heart_event_id, {})
	var empathetic := index == 0
	Relationships.apply_heart_event_choice(npc_data.id, empathetic)
	Relationships.mark_event_seen(npc_data.id, _heart_event_id)
	var response := String(event.get("response_a" if empathetic else "response_b", ""))
	if response != "":
		var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
		if dialog != null:
			var lines: Array[String] = [response]
			dialog.show_lines(lines)
	_heart_event_id = ""


## ---- ordinary talk + choices ----

func _play_talk(dialog: DialogBox, player: Node) -> void:
	var context := _resolver_context()
	var result := DialogResolver.pick(dialog_data, context)
	if String(result.get("source", "")) == "tier_pool":
		Relationships.mark_line_shown(npc_data.id, context["tier"], int(result["pool_index"]))
	Relationships.talk(npc_data.id)  # no-ops (returns false) if already talked today

	var lines: Array[String] = [String(result["text"])]
	var choices := _build_choices(player)
	if choices.is_empty():
		dialog.show_lines(lines)
		return
	if not dialog.choice_made.is_connected(_on_talk_choice):
		dialog.choice_made.connect(_on_talk_choice, CONNECT_ONE_SHOT)
	_choice_labels = choices
	_choice_player = player
	dialog.show_choices(lines, choices)


func _resolver_context() -> Dictionary:
	_rng.randomize()
	return {
		"tier": Relationships.tier_name(npc_data.id),
		"season": Clock.season(),
		"is_raining": Clock.is_raining(),
		"is_festival": Clock.is_festival_today() != "",
		"is_birthday": NPCData.is_birthday_today(npc_data),
		"shown_indices": Relationships.shown_indices(npc_data.id, Relationships.tier_name(npc_data.id)),
		"rng": _rng,
	}


func _build_choices(player: Node) -> Array[String]:
	var choices: Array[String] = []
	var gift_item := _giftable_selected_item(player)
	if gift_item != "" and not Relationships.has_gifted_today(npc_data.id):
		choices.append("Give " + ItemDB.get_item(gift_item).display_name)
	if has_shop and ShopLogic.is_open(Clock.hour()):
		choices.append("Browse the store")
	choices.append("Leave")
	return choices


func _giftable_selected_item(_player: Node) -> String:
	## `_player` is currently unused — gifting reads the CURRENT hotbar
	## selection off the Inventory autoload (same source player.gd's
	## try_use_selected() reads from), not anything player-instance-specific.
	## Kept as a parameter since interact(player) naturally has it in hand
	## and a future per-player inventory split shouldn't change this call site.
	var data := Inventory.get_selected_item_data()
	if data == null:
		return ""
	if data is ToolData:
		return ""  # tools are equipment, not giftable (bible: held item that's "not a ToolData")
	var slot = Inventory.get_selected()
	if slot == null:
		return ""
	return String(slot.id)


func _on_talk_choice(index: int) -> void:
	if index < 0 or index >= _choice_labels.size():
		return
	var label := _choice_labels[index]
	if label.begins_with("Give "):
		_gift_item_id = _giftable_selected_item(_choice_player)
		_resolve_gift.call_deferred()
	elif label == "Browse the store":
		_open_shop.call_deferred()
	# "Leave" (or anything else): no further action.
	_choice_labels = []
	_choice_player = null


func _resolve_gift() -> void:
	if _gift_item_id == "":
		return
	var reaction := Relationships.gift(npc_data.id, _gift_item_id, npc_data)
	if reaction == "already":
		return  # gift already used today between the choice showing and resolving
	Inventory.remove_item(_gift_item_id, 1)
	var reactions: Dictionary = dialog_data.get("gift_reactions", {})
	var line := String(reactions.get(reaction, "Thank you."))
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog != null and not dialog.is_open():
		var lines: Array[String] = [line]
		dialog.show_lines(lines)
	gift_given.emit(npc_data.id, _gift_item_id, reaction)
	_gift_item_id = ""


func _open_shop() -> void:
	var shop := get_tree().get_first_node_in_group("shop_screen") as ShopScreen
	if shop == null or shop.is_open():
		return
	shop.discount = shop_discount()
	shop.open()


## ---- Marta discount (World Stride B) ----

func shop_discount() -> float:
	if not has_shop:
		return 1.0
	var lvl := Relationships.level(npc_data.id)
	if lvl >= 7:
		return 0.90
	if lvl >= 4:
		return 0.95
	return 1.0


## ---- schedule ----

func refresh_schedule() -> void:
	## Repositions/hides this NPC per NPCRegistry.cell_for() for the current
	## hour/weather/festival state. Call at map build AND whenever the host
	## map detects a block boundary crossing (see town.gd).
	if npc_data == null:
		return
	var cell := RP.cell_for(npc_data, Clock.hour(), Clock.is_raining(), Clock.is_festival_today() != "")
	if cell == Vector2i(-1, -1):
		visible = false
		return
	visible = true
	position = MapBuilder.cell_center(cell)
