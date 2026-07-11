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
##
## Walking (Alive Stride 1): refresh_schedule() now WALKS to the new block
## cell instead of teleporting whenever ALL of the following hold: the NPC
## was already visible/on this map, the new target is on the SAME map (no
## per-block {"map":...} crossing), and the host map's PathGrid (found via
## the "map_root" group — see _path_grid_for_map()) has a real path between
## the current and target cell. Every other case (first placement, cross-map
## target, unreachable path, no PathGrid on this map) keeps the original
## instant-teleport behavior — documented, not a bug: catching up a walk
## across a map load, or walking between two different map scenes, is out of
## this stride's scope.
##
## Walk mechanics: _process(delta) advances _walk_queue (a queue of
## cell-center world positions) at WALK_SPEED px/s, cardinal-only (the path
## itself is already cardinal since PathGrid disables diagonals), updating
## `facing` to the last nonzero movement direction. If the NEXT scheduled
## block boundary arrives while a walk is still in flight, refresh_schedule()
## SNAPS straight to the new target instead of queueing a second path on top
## of the first (documented: prevents drift/lag stacking across fast block
## changes).
##
## Idle wander: once a walk finishes (or an NPC never needed to walk this
## block), _wander_timer counts down 4-8s; on expiry there's a 60% chance to
## stroll to a random adjacent walkable cell and back (two short automatic
## walks), otherwise the timer just re-rolls. Always on (no rain/indoor
## suppression this stride — see contract).
##
## Interact pause/resume: interact() calls _pause_walk_for_dialog() up front
## (before any dialog opens), which halts _walk_queue/wander processing and
## faces the NPC at the player; the DialogBox's `finished` signal (connected
## one-shot) calls _on_dialog_finished_resume_walk() to lift the pause. The
## Area2D itself is never reparented/disabled, so its interact() monitor
## keeps working mid-walk exactly like a stationary NPC's.

signal gift_given(npc_id: String, item_id: String, reaction: String)

const RP := preload("res://scripts/npcs/npc_registry.gd")

## Same animation-name contract Player uses (SpriteSheets.build_character
## produces exactly these 12 names from char_<id>_sheet.png). NPCFactory builds
## `sprite`'s SpriteFrames from this list. "action_<dir>" is the shared
## tool-use/swing cycle (NPCs never actually play it today — no NPC tools or
## combat — but it's part of the same sheet contract every character shares).
const ANIM_NAMES := [
	"idle_down", "idle_up", "idle_left", "idle_right",
	"walk_down", "walk_up", "walk_left", "walk_right",
	"action_down", "action_up", "action_left", "action_right",
]

const WALK_SPEED := 40.0  # px/s, per contract
const WANDER_MIN_INTERVAL := 4.0
const WANDER_MAX_INTERVAL := 8.0
const WANDER_CHANCE := 0.6
const CARDINAL_DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var npc_data: NPCData
var dialog_data: Dictionary = {}
var has_shop := false  # Marta-only: offers "Browse the store" during shop hours
var has_forge := false  # Craft Stride 2, Sten-only: offers "Forge" during smithy blocks 6-17
var sprite: AnimatedSprite2D

## Set by the caller right before a "Give X" choice resolves, so
## _on_choice_made can look the item back up without re-deriving it from
## Inventory state that may have changed by the time the signal fires.
var _gift_item_id := ""
var _contest_item_id := ""  # Harvest Fair contest (World Stride D) — same "set right before, read in the deferred resolver" pattern as _gift_item_id
var _heart_event_id := ""
var _rng := RandomNumberGenerator.new()
## Snapshot of the choice labels/player offered by the CURRENT show_choices()
## call, read back by _on_talk_choice (the button index alone doesn't say
## which action it was — "Give X" only appears when giftable, so its index
## isn't fixed).
var _choice_labels: Array[String] = []
var _choice_player: Node

## ---- walk state (Alive Stride 1) ----
var facing := Vector2.DOWN           # last nonzero movement direction; drives sprite flip/tint
var _host_map_id := ""               # last host_map_id passed to refresh_schedule(), for wander's PathGrid lookup
var _current_cell := Vector2i(-1, -1)  # cell this NPC currently occupies (or is walking toward as its logical slot)
var _walk_queue: Array[Vector2] = []   # remaining cell-center world positions to walk through, in order
var _walking := false
var _just_stopped_walking := false  # one-shot flag: next _process() plays idle_<facing>
var _paused_for_dialog := false
var _wander_timer := 0.0
var _wander_home_cell := Vector2i(-1, -1)  # cell to return to after a wander stroll
var _wandering_out := false           # true while walking OUT to a wander cell, false while walking back
var _dialog_finished_connected := false


func _ready() -> void:
	sprite = get_node_or_null("Sprite2D") as AnimatedSprite2D
	_wander_timer = _rng.randf_range(WANDER_MIN_INTERVAL, WANDER_MAX_INTERVAL)
	# FEEL Stride 6: lets the floating bond-number feedback find "the live NPC
	# node for this npc_id" from EventBus.relationship_changed's npc_id alone
	# (NPCs are built purely in code — no per-NPC scene — so a group lookup
	# by npc_data.id, done lazily in BondNumberDisplay, is the simplest way in).
	add_to_group("npc")


func _process(delta: float) -> void:
	if npc_data == null or not visible or _paused_for_dialog:
		return
	if _walking:
		_advance_walk(delta)
		return
	if _just_stopped_walking:
		_just_stopped_walking = false
		_play_anim("idle")
	_update_wander(delta)


func _facing_name() -> String:
	if facing == Vector2.UP:
		return "up"
	if facing == Vector2.LEFT:
		return "left"
	if facing == Vector2.RIGHT:
		return "right"
	return "down"


func _play_anim(prefix: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim_name := prefix + "_" + _facing_name()
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)


func interact(player: Node) -> void:
	if npc_data == null:
		return
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog == null or dialog.is_open():
		return

	_pause_walk_for_dialog(player)

	var pending := Relationships.pending_event(npc_data.id)
	if pending != "" and _has_heart_event_data(pending):
		_play_heart_event(dialog, pending)
		return

	_play_talk(dialog, player)


## ---- heart events ----

func _has_heart_event_data(event_key: String) -> bool:
	## Marriage M1: Relationships.pending_event() gates l8/l10 on LEVEL +
	## ROSTER alone (see its own doc) — it has no visibility into which of the
	## 5 romanceable candidates actually has l8/l10 CONTENT authored yet (only
	## Rosa does, as the M1 pilot; Willow/Bram/Sten/Garrick's l8/l10 scenes
	## are M2 work). Without this check, a non-pilot candidate reaching L8
	## would hit interact() -> pending_event() returns "l8" ->
	## _play_heart_event() finds an empty dict -> returns with NO dialog at
	## all, a silent soft-lock on every future interact (talk/gift/perk all
	## skipped). Falling through to ordinary _play_talk() instead means an
	## un-authored candidate just talks normally until M2 fills the scene in —
	## same graceful-degradation spirit as DialogResolver's own "no lines for
	## this tier -> fall back to STRANGER" rule.
	return not dialog_data.get("heart_events", {}).get(event_key, {}).is_empty()


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


## Alive Stride 2 / Craft Stride 2: heart-event choices that ALSO set a world
## flag on top of the ordinary bond delta — the wire that arms a scripted
## follow-on scene's trigger precondition. Table-driven (npc_id -> {event_key
## -> flag}) so Sten's L7 wiring is the IDENTICAL mechanism as Garrick's, not
## a copy-pasted second `if` — see garrick_sten_bench.gd's precondition doc
## for Garrick's entry and sten_fang_steel.gd's for Sten's. Only fires on the
## EMPATHETIC choice (index 0 / choice_a), same as Garrick's.
const _HEART_EVENT_CHOICE_A_FLAGS := {
	"garrick": {"l7": "garrick_l7_choice_a"},
	"sten": {"l7": "sten_l7_choice_a"},
}


func _on_heart_event_choice(index: int) -> void:
	var event: Dictionary = dialog_data.get("heart_events", {}).get(_heart_event_id, {})
	var empathetic := index == 0
	Relationships.apply_heart_event_choice(npc_data.id, empathetic)
	Relationships.mark_event_seen(npc_data.id, _heart_event_id)
	if empathetic:
		var flag_key := String(_HEART_EVENT_CHOICE_A_FLAGS.get(npc_data.id, {}).get(_heart_event_id, ""))
		if flag_key != "":
			GameState.flags[flag_key] = true
			# Companion day record ("<flag>_day"): lets a follow-on scene gate
			# on "next day or later" via TriggerService's next_day_after_flag
			# precondition ("Fang Steel" needs it — Sten's L7 event can happen
			# during the very smithy blocks the scene fires in, so unlike The
			# Bench the next-day rule can't be left implicit). Recorded for
			# BOTH table entries so the mechanism stays uniform; The Bench
			# simply never reads Garrick's.
			GameState.flags[flag_key + "_day"] = Clock.day
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
	var effective_data := _gated_dialog_data()
	var result := DialogResolver.pick(effective_data, context)
	if String(result.get("source", "")) == "tier_pool":
		Relationships.mark_line_shown(npc_data.id, context["tier"], int(result["pool_index"]))
	Relationships.talk(npc_data.id)  # no-ops (returns false) if already talked today
	Quests.record_talk(npc_data.id)  # New Roots progress (no-ops off-quest/already-met)

	var lines: Array[String] = []
	var quest_lines := _quest_hand_in_lines_if_any()
	lines.append_array(quest_lines)
	var winter_star_line := _winter_star_plaza_gift_line_if_any()
	if winter_star_line != "":
		lines.append(winter_star_line)
	var perk_line := _grant_pending_perk_if_any()
	if perk_line != "":
		lines.append(perk_line)
	lines.append(String(result["text"]))
	var choices := _build_choices(player)
	if choices.is_empty():
		dialog.show_lines(lines)
		return
	if not dialog.choice_made.is_connected(_on_talk_choice):
		dialog.choice_made.connect(_on_talk_choice, CONNECT_ONE_SHOT)
	_choice_labels = choices
	_choice_player = player
	dialog.show_choices(lines, choices)


## ---- post-scene content gating (Alive Stride 2, "The Bench") ----

## Verbatim lines that only appear once flag "garrick_sten_reconciled" is
## true — see data/events/garrick_sten_bench.gd's class doc. Declared here
## (not in each NPC's own dialog DATA file) so the gate logic lives in ONE
## place: dialog DATA stays pure data, and a future third gated line doesn't
## need its own bespoke filtering method.
const _RECONCILED_GATED_LINES := {
	"garrick": {
		"tier": "KINDRED",
		"line": "I told Sten his steel saved my life for ten years before the day it didn't. Took me twenty years and one farmer to say it. He heard me out. So. That happened.",
	},
	"sten": {
		"tier": "CLOSE",
		"line": "Garrick's back at the bench. Hands me things wrong. It's good.",
	},
}

## Craft Stride 3 (Taming): Willow's barn-gated line, same shallow-filter
## mechanism as _RECONCILED_GATED_LINES above but keyed on a WORLD STATE
## condition (world["taming"].barn non-empty) instead of a GameState.flags
## boolean — see _barn_non_empty() below. Kept as its own table/gate rather
## than folded into _RECONCILED_GATED_LINES so that table's "flag name ->
## bool" shape doesn't need to grow a second, different kind of condition.
const _BARN_GATED_LINES := {
	"willow": {
		"tier": "CLOSE",
		"line": "You kept one. The woods sorted you into \"safe\" years ago. Now the slimes have too.",
	},
}


func _gated_dialog_data() -> Dictionary:
	## Returns `dialog_data` unchanged for every NPC/tier that has no gated
	## line at all, or a SHALLOW COPY with just that one tier's pool filtered
	## when a gate applies and its condition isn't met yet — never mutates
	## the shared `const DATA` dict itself (every NPC instance built from the
	## same data/dialog/<id>.gd file points at the SAME Dictionary object).
	var out := dialog_data
	var reconciled_gate: Dictionary = _RECONCILED_GATED_LINES.get(npc_data.id, {})
	if not reconciled_gate.is_empty() and not bool(GameState.flags.get("garrick_sten_reconciled", false)):
		out = _filter_gated_line(out, reconciled_gate)
	var barn_gate: Dictionary = _BARN_GATED_LINES.get(npc_data.id, {})
	if not barn_gate.is_empty() and not _barn_non_empty():
		out = _filter_gated_line(out, barn_gate)
	return out


func _barn_non_empty() -> bool:
	return Taming.barn_count(SaveManager.world) > 0


static func _filter_gated_line(data: Dictionary, gate: Dictionary) -> Dictionary:
	## Shared filter step: removes `gate.line` from `data.tier_pools[gate.tier]`
	## if present, returning a shallow copy (data itself untouched). Called
	## once per applicable-and-unmet gate from _gated_dialog_data() above, so
	## an NPC with gates in BOTH tables (none today) would get both filtered
	## in sequence without either mutating the shared const dialog data.
	var tier: String = gate["tier"]
	var gated_line: String = gate["line"]
	var pools: Dictionary = data.get("tier_pools", {})
	var pool: Array = pools.get(tier, [])
	if not (gated_line in pool):
		return data  # nothing to filter (defensive; shouldn't happen with real data)
	var filtered_pool: Array = pool.duplicate()
	filtered_pool.erase(gated_line)
	var filtered_pools := pools.duplicate()
	filtered_pools[tier] = filtered_pool
	var out := data.duplicate()
	out["tier_pools"] = filtered_pools
	return out


## ---- quests (World Stride D) ----

func _quest_hand_in_lines_if_any() -> Array[String]:
	## Prepended before the ordinary resolved line (same slot perk lines use —
	## a quest hand-in and a level perk never collide in practice since perks
	## gate on Relationships level and quests gate on Quests state, but if
	## both landed on the same talk the quest line takes precedence,
	## appearing first). Alden and Garrick are the only two NPCs with any
	## quest hooks (bible: New Roots hands in via Alden, Prove It/King Below
	## via Garrick) — every other NPC's id simply matches no case below and
	## this returns empty, a no-op.
	var lines: Array[String] = []
	match npc_data.id:
		"alden":
			if Quests.hand_in_new_roots():
				lines.append(String(dialog_data.get("new_roots_hand_in", "")))
		"garrick":
			_grant_and_hand_in_garrick_quests(lines)
	return lines


func _grant_and_hand_in_garrick_quests(lines: Array[String]) -> void:
	# "Prove It" grants on first-ever Garrick talk (any level) — grant_prove_it()
	# is idempotent (no-ops once already granted), so calling it every talk is safe.
	Quests.grant_prove_it()
	if Quests.hand_in_prove_it():
		# hand_in_prove_it() also grants king_below (bible: "Q3... after Q2");
		# if the boss was ALREADY defeated by this point, king_below completes
		# instantly inside that call, so the SAME talk can also hand in Q3 —
		# check immediately after, below.
		var quests_data: Dictionary = dialog_data.get("quests", {})
		lines.append(String(quests_data.get("prove_it_hand_in", "")))
	var king_result := Quests.hand_in_king_below()
	if king_result["handed_in"]:
		var quests_data: Dictionary = dialog_data.get("quests", {})
		var key := "king_below_hand_in_already_defeated" if king_result["already_met_king"] else "king_below_hand_in"
		lines.append(String(quests_data.get(key, "")))


## ---- Winter Star plaza gift (World Stride D) ----

func _winter_star_plaza_gift_line_if_any() -> String:
	## Bible: "at the plaza, one random-but-seeded NPC hands YOU a gift on
	## first talk (their loved item or gold)". receive_plaza_gift_if_due()
	## is itself the full gate (right festival, right NPC, not already
	## collected today) so this is a thin flavor-line wrapper around it.
	var result := WinterStar.receive_plaza_gift_if_due(npc_data.id)
	if not result["received"]:
		return ""
	if String(result["item_id"]) != "":
		var item := ItemDB.get_item(String(result["item_id"]))
		var item_name := item.display_name if item != null else String(result["item_id"])
		return "A Winter Star gift, just for you: %s." % item_name
	return "A Winter Star gift, just for you: %dg." % int(result["gold"])


## ---- level perks (World Stride C) ----

func _grant_pending_perk_if_any() -> String:
	## "on talk with pending_perk after greeting — short in-voice line +
	## grant" (stride contract): checked every ordinary talk (heart events
	## already short-circuit interact() before this is ever reached, so a
	## perk and a heart event never fire on the same interaction). Returns
	## the perk's flavor line to prepend before the day's ordinary resolved
	## line, or "" if nothing is pending. Applies the grant (items/gold/
	## max_hp) and marks it given immediately — this is a simple one-shot
	## handout, not a choice, so there's nothing to defer to a follow-up
	## signal the way gifting/heart-events do.
	var perk_id := Relationships.pending_perk(npc_data.id)
	if perk_id == "":
		return ""
	var perk: Dictionary = dialog_data.get("perks", {}).get(perk_id, {})
	if perk.is_empty():
		return ""
	Relationships.mark_perk_given(npc_data.id, perk_id)
	var items: Dictionary = perk.get("items", {})
	for item_id: String in items:
		Inventory.add_item(item_id, int(items[item_id]))
	var gold := int(perk.get("gold", 0))
	if gold > 0:
		GameState.add_gold(gold)
	var max_hp_bonus := int(perk.get("max_hp", 0))
	if max_hp_bonus > 0:
		GameState.max_hp += max_hp_bonus
		GameState.hp += max_hp_bonus  # the bonus is immediately usable, not just headroom
		EventBus.stats_changed.emit()
	return String(perk.get("line", ""))


func _resolver_context() -> Dictionary:
	_rng.randomize()
	return {
		"tier": Relationships.tier_name(npc_data.id),
		"season": Clock.season(),
		"is_raining": Clock.is_raining(),
		"is_festival": Festival.is_npc_at_festival(npc_data.id, Clock.hour()),
		"festival_id": Clock.is_festival_today(),
		"is_birthday": NPCData.is_birthday_today(npc_data),
		"shown_indices": Relationships.shown_indices(npc_data.id, Relationships.tier_name(npc_data.id)),
		"rng": _rng,
	}


func _build_choices(player: Node) -> Array[String]:
	var choices: Array[String] = []
	var gift_item := _giftable_selected_item(player)
	if gift_item != "" and not Relationships.has_gifted_today(npc_data.id):
		choices.append("Give " + ItemDB.get_item(gift_item).display_name)
	if has_shop and ShopLogic.is_open(Clock.hour()) and not Festival.shop_closed_for_festival(Clock.hour()):
		choices.append("Browse the store")
	if _sowing_stall_available():
		choices.append("Festival stall")
	if _forge_available():
		choices.append("Forge")
	var contest_item := _contest_eligible_selected_item()
	if contest_item != "":
		choices.append("Enter the contest with " + ItemDB.get_item(contest_item).display_name)
	choices.append("Leave")
	return choices


## ---- Forge (Craft Stride 2, Sten only) ----

const _FORGE_BLOCKS := [RP.BLOCK_6_9, RP.BLOCK_9_12, RP.BLOCK_12_17]  # bible: "smithy blocks (6-17)"


func _forge_available() -> bool:
	## Bible: "Sten dialog choice 'Forge' during smithy blocks (6-17)" —
	## template is Marta's has_shop/"Browse the store" gate (see _build_choices
	## above), generalized to Sten's three daytime blocks instead of a hard
	## hour range, so it stays correct if NPCRegistry's block boundaries ever
	## shift.
	if not has_forge:
		return false
	return RP.block_for(Clock.hour()) in _FORGE_BLOCKS


func _open_forge() -> void:
	var forge := get_tree().get_first_node_in_group("forge_screen") as ForgeScreen
	if forge == null or forge.is_open():
		return
	forge.open()


## ---- Sowing Festival stall (World Stride D, Marta only) ----

func _sowing_stall_available() -> bool:
	## Bible: "Marta plaza stall: DialogBox choice 'Festival stall' -> ShopScreen
	## with spring seeds at additional 20% off". Marta-only, sowing-only,
	## during festival hours only (her ordinary "Browse the store" choice is
	## already omitted then via Festival.shop_closed_for_festival()).
	if not has_shop:
		return false
	if Clock.is_festival_today() != Festival.ID_SOWING:
		return false
	return Festival.is_npc_at_festival(npc_data.id, Clock.hour())


const SOWING_STALL_DISCOUNT := 0.8  # bible: "additional 20% off"


func _open_sowing_stall() -> void:
	## Composes with Marta's ordinary friendship discount (World Stride B:
	## L4 5%/L7 10%) by MULTIPLYING the two multipliers, then rounding down
	## ONCE at the final unit price (ShopLogic.unit_price already floors) —
	## e.g. an L7 100g seed: 100 * 0.90 * 0.80 = 72.0 -> 72g, not two separate
	## floor operations that could floor-then-floor to a different result.
	var shop := get_tree().get_first_node_in_group("shop_screen") as ShopScreen
	if shop == null or shop.is_open():
		return
	shop.discount = shop_discount() * SOWING_STALL_DISCOUNT
	shop.festival_seeds_only = true
	shop.open()


## ---- Harvest Fair contest (World Stride D) ----

func _contest_eligible_selected_item() -> String:
	## Bible: "interact with Alden during festival with a crop item SELECTED
	## on hotbar -> choice 'Enter the contest with <item>'... once per year".
	## Alden-only, harvest_fair-only, during festival hours, item must be a
	## crop PRODUCE (not a seed/tool), and the player must not have already
	## entered this year.
	if npc_data.id != "alden":
		return ""
	if Clock.is_festival_today() != Festival.ID_HARVEST_FAIR:
		return ""
	if not Festival.is_npc_at_festival(npc_data.id, Clock.hour()):
		return ""
	var blob: Dictionary = SaveManager.world.get("festival", {})
	if Festival.has_entered_contest_this_year(blob, Clock.year()):
		return ""
	var slot = Inventory.get_selected()
	if slot == null:
		return ""
	var item_id := String(slot.id)
	if not NPCData.matches_any_category(item_id, [NPCData.ANY_CROP_CATEGORY]):
		return ""
	return item_id


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
	elif label == "Festival stall":
		_open_sowing_stall.call_deferred()
	elif label == "Forge":
		_open_forge.call_deferred()
	elif label.begins_with("Enter the contest with "):
		_contest_item_id = _contest_eligible_selected_item()
		_resolve_contest.call_deferred()
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


func _resolve_contest() -> void:
	## Judges by ItemData.sell_price (bible): >=250 -> 1st (500g + ALL 8 NPCs
	## +50 bond), >=100 -> 2nd (200g), else participation (50g). Consumes the
	## entered item; once per YEAR (guarded again here in case the year
	## rolled over between the choice showing and resolving, however
	## unlikely — same defensive re-check _resolve_gift's "already" guard
	## follows for gifting).
	if _contest_item_id == "":
		return
	var blob: Dictionary = SaveManager.world.get("festival", {})
	if Festival.has_entered_contest_this_year(blob, Clock.year()):
		_contest_item_id = ""
		return
	var item := ItemDB.get_item(_contest_item_id)
	if item == null:
		_contest_item_id = ""
		return
	var tier := Festival.contest_tier(item.sell_price)
	var gold := Festival.contest_gold_for_tier(tier)
	Inventory.remove_item(_contest_item_id, 1)
	GameState.add_gold(gold)
	SaveManager.world["festival"] = Festival.record_contest_entry(blob, Clock.year())
	if tier == "1st":
		for npc_id: String in NPCFactory.ALL_IDS:
			Relationships.add_flat_bond(npc_id, Festival.CONTEST_FIRST_BOND_BONUS)
	var line := _contest_result_line(tier, gold)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog != null and not dialog.is_open():
		var lines: Array[String] = [line]
		dialog.show_lines(lines)
	_contest_item_id = ""


func _contest_result_line(tier: String, gold: int) -> String:
	match tier:
		"1st":
			return "First place! The whole town's talking about it. +%dg, and everyone's a little warmer to you for it." % gold
		"2nd":
			return "A solid second place. +%dg — respectable, farmer." % gold
		_:
			return "Thank you for entering. +%dg for the effort." % gold


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

func refresh_schedule(host_map_id: String = "") -> void:
	## Repositions/hides this NPC per NPCRegistry.cell_for() for the current
	## hour/weather/festival state. Call at map build AND whenever the host
	## map detects a block boundary crossing (see town.gd).
	##
	## `host_map_id` is the map SCENE this node lives in right now (e.g.
	## "town", "farm"). Defaults to npc_data.home_map for backward
	## compatibility (every World-Stride-B NPC only ever appears on their
	## home_map, so the old no-arg call sites still behave identically).
	## World Stride C NPCs that move between maps in their schedule (Garrick:
	## farm morning block, town/saloon otherwise) MUST pass the actual host
	## map id so this hides the instance on blocks that belong to the OTHER
	## map instead of showing it at a stale cell.
	##
	## Alive Stride 1: WALKS to the new cell (see class doc) when the NPC was
	## already visible/placed on this map, the target is on the SAME map, and
	## a real cardinal path exists between the current and target cell.
	## Falls back to the original instant-teleport for every other case
	## (first placement this map, cross-map target, unreachable path, or no
	## PathGrid registered for this map).
	if npc_data == null:
		return
	_host_map_id = host_map_id if host_map_id != "" else npc_data.home_map
	var map_id := _host_map_id
	var hour := Clock.hour()
	var raining := Clock.is_raining()
	var festival := Festival.is_npc_at_festival(npc_data.id, hour)
	if not RP.is_present_on_map(npc_data, map_id, hour, raining, festival):
		visible = false
		_cancel_walk()
		_current_cell = Vector2i(-1, -1)
		return

	var target_cell := RP.cell_for(npc_data, hour, raining, festival)
	var target_map := RP.map_for(npc_data, hour, raining, festival)
	var was_visible := visible
	# Contract: "if a walk is still in progress when the NEXT block boundary
	# hits, teleport-snap to the new target" — a still-in-flight walk (a
	# schedule walk OR an idle-wander stroll, both use _walking) never gets
	# to chain into a second pathfind; it's cut short and snapped instead,
	# same as any other teleport case below.
	var mid_walk := _walking
	visible = true

	if was_visible and not mid_walk and target_map == map_id and _current_cell != Vector2i(-1, -1) \
			and _current_cell != target_cell:
		if _try_start_walk(map_id, target_cell):
			return
	# Fallback: instant teleport (first placement, cross-map target,
	# unreachable path, no PathGrid on this map, already-at-target, or a
	# walk/wander was interrupted mid-flight by this very block change).
	_cancel_walk()
	_current_cell = target_cell
	position = MapBuilder.cell_center(target_cell)


func _path_grid_for_map(map_id: String) -> PathGrid:
	var root := get_tree().get_first_node_in_group("map_root")
	if root == null:
		return null
	# map scripts don't share a base class (each is a plain Node2D builder —
	# see town.gd/farm.gd/etc.), so this reads `path_grid` via Godot's
	# Object.get() property reflection rather than a static type. Also
	# guards against the group holding a DIFFERENT map than `map_id` (only
	# matters if two map roots were ever alive at once, which no scene in
	# this game does today — see class doc).
	var root_script: Script = root.get_script()
	if root_script == null:
		return null
	var script_path: String = root_script.resource_path
	if not script_path.ends_with("/%s.gd" % map_id):
		return null
	return root.get("path_grid") as PathGrid


func _try_start_walk(map_id: String, target_cell: Vector2i) -> bool:
	var grid := _path_grid_for_map(map_id)
	if grid == null:
		return false
	var path := grid.find_path(_current_cell, target_cell)
	if path.is_empty():
		return false  # unreachable (or same cell, handled by the caller's equality check)
	_walk_queue.clear()
	for cell: Vector2 in path:
		_walk_queue.append(MapBuilder.cell_center(Vector2i(cell)))
	_walk_queue.remove_at(0)  # first entry is the NPC's own current cell-center
	_current_cell = target_cell  # logical slot updates immediately; visual catches up over _process
	_walking = true
	_wandering_out = false
	return true


func _cancel_walk() -> void:
	_walking = false
	_walk_queue.clear()


func _advance_walk(delta: float) -> void:
	if _walk_queue.is_empty():
		_walking = false
		_just_stopped_walking = true  # picked up next _process(): plays idle_<facing>
		if not _wandering_out:
			_wander_timer = _rng.randf_range(WANDER_MIN_INTERVAL, WANDER_MAX_INTERVAL)
		else:
			_finish_wander_leg()
		return
	var dest: Vector2 = _walk_queue[0]
	var to_dest := dest - position
	var dist := to_dest.length()
	var step := WALK_SPEED * delta
	if dist <= step:
		position = dest
		_walk_queue.remove_at(0)
		if to_dest.length() > 0.01:
			_update_facing(to_dest)
	else:
		var dir := to_dest / dist
		_update_facing(dir)
		position += dir * step


func _update_facing(dir: Vector2) -> void:
	# Cardinal-only (matches the path itself): snap to whichever axis
	# dominates rather than storing a diagonal-looking vector.
	if absf(dir.x) > absf(dir.y):
		facing = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if dir.y > 0 else Vector2.UP
	# LOOK V2: char_<id>_sheet.png authors LEFT and RIGHT as distinct side
	# profiles (see tools/gen_placeholders.gd / SpriteSheets doc), not a
	# mirror pair — flip_h stays false so walk_right isn't double-mirrored.
	_play_anim("walk")


## Turns to face `dir` WITHOUT implying movement (e.g. facing the player on
## interact while paused for dialog) — same cardinal snap as _update_facing,
## but plays idle_<facing> instead of walk_<facing>.
func _face_direction_idle(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		facing = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		facing = Vector2.DOWN if dir.y > 0 else Vector2.UP
	_play_anim("idle")


## ---- idle wander (Alive Stride 1) ----

func _update_wander(delta: float) -> void:
	if _current_cell == Vector2i(-1, -1):
		return
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = _rng.randf_range(WANDER_MIN_INTERVAL, WANDER_MAX_INTERVAL)
	if _rng.randf() >= WANDER_CHANCE:
		return  # 60% chance per contract; the other 40% just re-rolls the timer
	_start_wander_stroll()


func _start_wander_stroll() -> void:
	var grid := _path_grid_for_map(_host_map_id)
	if grid == null:
		return
	var candidates: Array[Vector2i] = []
	for dir: Vector2i in CARDINAL_DIRS:
		var cell := _current_cell + dir
		if grid.is_walkable(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return
	_wander_home_cell = _current_cell
	var wander_cell: Vector2i = candidates[_rng.randi() % candidates.size()]
	_walk_queue = [MapBuilder.cell_center(wander_cell)]
	_walking = true
	_wandering_out = true


func _finish_wander_leg() -> void:
	if _wandering_out:
		# Walked out; now walk back home. _current_cell stays at the wander
		# cell only for the instant between legs (never observable by
		# schedule resolution, which only runs on block change).
		_wandering_out = false
		_walk_queue = [MapBuilder.cell_center(_wander_home_cell)]
		_walking = true
	else:
		_wander_timer = _rng.randf_range(WANDER_MIN_INTERVAL, WANDER_MAX_INTERVAL)


## ---- interact pause/resume (Alive Stride 1) ----

func _pause_walk_for_dialog(player: Node) -> void:
	_paused_for_dialog = true
	if player is Node2D:
		_face_direction_idle((player as Node2D).global_position - global_position)
	var dialog := get_tree().get_first_node_in_group("dialog_box") as DialogBox
	if dialog != null and not _dialog_finished_connected:
		dialog.finished.connect(_on_dialog_finished_resume_walk, CONNECT_ONE_SHOT)
		_dialog_finished_connected = true


func _on_dialog_finished_resume_walk() -> void:
	_dialog_finished_connected = false
	_paused_for_dialog = false
