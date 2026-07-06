extends Node
## Per-NPC bond state (World Stride B). Points, tiers, talk/gift daily gates,
## decay, heart-event/perk gates, and per-NPC/per-tier dialog-pool shown-index
## tracking all live here so npc.gd and DialogResolver stay thin callers.
##
## Points: 0-1000 (documented range; nothing currently pushes past 1000 —
## the L8 perk and L10 tier are both reachable at exactly 1000). Level is
## points/100, i.e. 0..10. Tier bands (bible): STRANGER L0-1, ACQUAINT L2-3,
## FRIEND L4-6, CLOSE L7-9, KINDRED L10.
##
## Blob shape — SaveManager.world["relationships"] (documented in
## save_manager.gd's sanctioned-keys contract too):
##   { npc_id: {
##       "points": int,
##       "talked_day": int,     # absolute Clock.day of last talk() success, -1 = never
##       "gifted_day": int,     # absolute Clock.day of last successful gift(), -1 = never
##       "events_seen": [String, ...],     # heart-event ids marked seen ("l3"/"l7")
##       "perks_given": [String, ...],     # perk ids marked given ("l5"/"l8")
##       "shown_lines": { tier_name: [int, ...] },  # no-repeat-until-exhausted indices
##   } }
## All reads MUST int()/String() coerce — JSON round-trips ints as floats and
## this blob persists via SaveManager.world like every other world blob.
##
## Tier "never regress" rule (decay floor): decaying can drop points within a
## tier but never below that tier's base points value (see TIER_BASE_POINTS),
## so a player who reached FRIEND (400+) never decays back to ACQUAINT.

const MAX_POINTS := 1000
## No hard floor is specified by the bible for gift/heart-event penalties
## (only decay has a documented floor, and only at L2+). A generous negative
## bound just prevents runaway underflow from repeated disliked gifts/
## dismissive heart-event choices; STRANGER (L0) already covers all of
## [MIN_POINTS, 99] so nothing player-visible depends on the exact bound.
const MIN_POINTS := -1000
const TALK_GAIN := 15
const FESTIVAL_TALK_BONUS := 30
const GIFT_LOVED := 80
const GIFT_LIKED := 45
const GIFT_NEUTRAL := 20
const GIFT_DISLIKED := -20
const BIRTHDAY_GIFT_MULT := 8
const HEART_EVENT_DELTA := 30
const DECAY_AMOUNT := 2
const DECAY_MIN_LEVEL := 2  # decay only applies at L2+ (bible: "only at L2+")

const TIER_STRANGER := "STRANGER"
const TIER_ACQUAINT := "ACQUAINT"
const TIER_FRIEND := "FRIEND"
const TIER_CLOSE := "CLOSE"
const TIER_KINDRED := "KINDRED"

## Level (0..10) -> tier name. Index by clampi(level, 0, 10).
const TIER_BY_LEVEL := [
	TIER_STRANGER, TIER_STRANGER,          # L0-1
	TIER_ACQUAINT, TIER_ACQUAINT,          # L2-3
	TIER_FRIEND, TIER_FRIEND, TIER_FRIEND, # L4-6
	TIER_CLOSE, TIER_CLOSE, TIER_CLOSE,    # L7-9
	TIER_KINDRED,                          # L10
]

## Tier name -> lowest level in that tier -> lowest points in that tier
## (decay floor). Points per level are a flat 100, so this is level*100.
const TIER_MIN_LEVEL := {
	TIER_STRANGER: 0,
	TIER_ACQUAINT: 2,
	TIER_FRIEND: 4,
	TIER_CLOSE: 7,
	TIER_KINDRED: 10,
}

var _state := {}  # npc_id -> state dict (mirrors SaveManager.world["relationships"][npc_id])


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)


## ---- persistence ----

func restore() -> void:
	## Call after SaveManager.load_game()/new_game() (world blob contract —
	## no signal fires on load, callers sequence it like Clock.restore_calendar()).
	var blob: Dictionary = SaveManager.world.get("relationships", {})
	_state = {}
	for npc_id: String in blob:
		_state[npc_id] = _coerce_state(blob[npc_id])
	SaveManager.world["relationships"] = _state


func _persist() -> void:
	SaveManager.world["relationships"] = _state


static func _coerce_state(raw: Dictionary) -> Dictionary:
	## JSON float-coercion safe (established gotcha) — every int field is
	## int()'d, every array/dict copied fresh so callers never alias the save blob.
	var events_seen: Array = raw.get("events_seen", [])
	var perks_given: Array = raw.get("perks_given", [])
	var shown_raw: Dictionary = raw.get("shown_lines", {})
	var shown_lines := {}
	for tier: String in shown_raw:
		var idx_list: Array = shown_raw[tier]
		var coerced: Array = []
		for v in idx_list:
			coerced.append(int(v))
		shown_lines[tier] = coerced
	return {
		"points": int(raw.get("points", 0)),
		"talked_day": int(raw.get("talked_day", -1)),
		"gifted_day": int(raw.get("gifted_day", -1)),
		"events_seen": events_seen.duplicate(),
		"perks_given": perks_given.duplicate(),
		"shown_lines": shown_lines,
	}


func _get_or_create(npc_id: String) -> Dictionary:
	if not _state.has(npc_id):
		_state[npc_id] = _coerce_state({})
	return _state[npc_id]


## ---- level / tier ----

func points(npc_id: String) -> int:
	return int(_get_or_create(npc_id).get("points", 0))


func level(npc_id: String) -> int:
	return level_for_points(points(npc_id))


static func level_for_points(pts: int) -> int:
	@warning_ignore("integer_division")
	return clampi(pts / 100, 0, 10)


func tier_name(npc_id: String) -> String:
	return tier_name_for_level(level(npc_id))


static func tier_name_for_level(lvl: int) -> String:
	return TIER_BY_LEVEL[clampi(lvl, 0, 10)]


static func tier_base_points(tier: String) -> int:
	return int(TIER_MIN_LEVEL.get(tier, 0)) * 100


func _add_points(npc_id: String, delta: int) -> void:
	var state := _get_or_create(npc_id)
	state["points"] = clampi(int(state.get("points", 0)) + delta, MIN_POINTS, MAX_POINTS)
	_persist()
	EventBus.relationship_changed.emit(npc_id)


## ---- talk ----

func has_talked_today(npc_id: String) -> bool:
	return int(_get_or_create(npc_id).get("talked_day", -1)) == Clock.day


func talk(npc_id: String) -> bool:
	## +15 once/day; +30 extra on a festival day. Returns false (no change) if
	## already talked today.
	if has_talked_today(npc_id):
		return false
	var state := _get_or_create(npc_id)
	state["talked_day"] = Clock.day
	var gain := TALK_GAIN
	if Clock.is_festival_today() != "":
		gain += FESTIVAL_TALK_BONUS
	_add_points(npc_id, gain)
	return true


## ---- gift ----

func has_gifted_today(npc_id: String) -> bool:
	return int(_get_or_create(npc_id).get("gifted_day", -1)) == Clock.day


func gift_reaction(npc_id: String, item_id: String, npc_data: NPCData) -> String:
	## Pure preview (no state mutation) of what gift(npc_id, item_id, npc_data)
	## would return, used by npc.gd to build the choice/response text before
	## committing. "already" if today's gift is used up.
	if has_gifted_today(npc_id):
		return "already"
	return _reaction_for(npc_id, item_id, npc_data)


static func _reaction_for(npc_id: String, item_id: String, npc_data: NPCData) -> String:
	## Winter Star (World Stride D): gifting the seeded secret-gift target
	## reacts as "loved" regardless of the actual item (bible: "loved
	## reaction regardless of item") — checked FIRST, ahead of the ordinary
	## loved/liked/disliked/category resolution below.
	var forced := WinterStar.forced_reaction(npc_id)
	if forced != "":
		return forced
	if npc_data == null:
		return "neutral"
	if item_id in npc_data.loved_items:
		return "loved"
	if item_id in npc_data.disliked_items:
		return "disliked"
	if item_id in npc_data.liked_items:
		return "liked"
	if NPCData.matches_any_category(item_id, npc_data.liked_categories):
		return "liked"
	return "neutral"


func gift(npc_id: String, item_id: String, npc_data: NPCData) -> String:
	## Applies the gift: once/day, +80/+45/+20/-20 by reaction, x8 on the
	## NPC's birthday (bible: "Birthday ×8"; applied to loved/liked/neutral
	## AND disliked alike — a birthday dud still stings x8). Does NOT touch
	## the caller's inventory; npc.gd removes the item itself. World Stride D:
	## also x5 (on top of any birthday x8) when gifting today's Winter Star
	## secret-gift target (bible: "x5 bond" — the two multipliers compose;
	## nothing in the bible says Winter Star ever falls on a birthday, but
	## composing rather than picking one is the least-surprising rule if it
	## ever does).
	if has_gifted_today(npc_id):
		return "already"
	var reaction := _reaction_for(npc_id, item_id, npc_data)
	var delta := _delta_for_reaction(reaction)
	if npc_data != null and NPCData.is_birthday_today(npc_data):
		delta *= BIRTHDAY_GIFT_MULT
	delta *= WinterStar.gift_bond_multiplier(npc_id)
	var state := _get_or_create(npc_id)
	state["gifted_day"] = Clock.day
	_add_points(npc_id, delta)
	return reaction


static func _delta_for_reaction(reaction: String) -> int:
	match reaction:
		"loved": return GIFT_LOVED
		"liked": return GIFT_LIKED
		"disliked": return GIFT_DISLIKED
		_: return GIFT_NEUTRAL


## ---- decay ----

func _on_day_passed(_day: int) -> void:
	for npc_id: String in _state.keys():
		_decay_one(npc_id)
	_persist()


func _decay_one(npc_id: String) -> void:
	## Writes state["points"] directly rather than going through _add_points
	## on purpose: decay is passive background bookkeeping, not a player
	## action, so it deliberately does NOT emit relationship_changed (which
	## would fire once per registered NPC every single day-rollover — noisy
	## for zero player-visible benefit; the Journal's SOCIAL tab reads fresh
	## values whenever it's opened anyway).
	if has_talked_today(npc_id):
		return  # talked_day was just set to the new day by a same-tick talk() — not decayed
	var state: Dictionary = _state[npc_id]
	var pts := int(state.get("points", 0))
	var lvl := level_for_points(pts)
	if lvl < DECAY_MIN_LEVEL:
		return
	var floor_pts := tier_base_points(tier_name_for_level(lvl))
	state["points"] = maxi(floor_pts, pts - DECAY_AMOUNT)


## ---- heart events ----

func pending_event(npc_id: String) -> String:
	## "l3"/"l7" when the level gate is met and not yet marked seen, else "".
	## L7 takes precedence when both somehow qualify (shouldn't happen since
	## l3 is marked seen long before L7, but keep it deterministic).
	var state := _get_or_create(npc_id)
	var seen: Array = state.get("events_seen", [])
	var lvl := level(npc_id)
	if lvl >= 7 and not ("l7" in seen):
		return "l7"
	if lvl >= 3 and not ("l3" in seen):
		return "l3"
	return ""


func mark_event_seen(npc_id: String, event_id: String) -> void:
	var state := _get_or_create(npc_id)
	var seen: Array = state.get("events_seen", [])
	if not (event_id in seen):
		seen.append(event_id)
	state["events_seen"] = seen
	_persist()


func apply_heart_event_choice(npc_id: String, empathetic: bool) -> void:
	_add_points(npc_id, HEART_EVENT_DELTA if empathetic else -HEART_EVENT_DELTA)


func add_flat_bond(npc_id: String, delta: int) -> void:
	## Public "just add points" entry point for one-off bond grants that
	## aren't a talk/gift/heart-event — World Stride D's Harvest Fair 1st-
	## place contest bonus ("all 8 NPCs +50 bond") is the first caller.
	_add_points(npc_id, delta)


## ---- perks ----

func pending_perk(npc_id: String) -> String:
	## "l5"/"l8" gate, mirrors pending_event. World C hands out the actual
	## rewards; this just gates + marks.
	var state := _get_or_create(npc_id)
	var given: Array = state.get("perks_given", [])
	var lvl := level(npc_id)
	if lvl >= 8 and not ("l8" in given):
		return "l8"
	if lvl >= 5 and not ("l5" in given):
		return "l5"
	return ""


func mark_perk_given(npc_id: String, perk_id: String) -> void:
	var state := _get_or_create(npc_id)
	var given: Array = state.get("perks_given", [])
	if not (perk_id in given):
		given.append(perk_id)
	state["perks_given"] = given
	_persist()


## ---- dialog-pool shown-index tracking (no-repeat-until-exhausted) ----

func shown_indices(npc_id: String, tier: String) -> Array:
	var state := _get_or_create(npc_id)
	var shown: Dictionary = state.get("shown_lines", {})
	var list: Array = shown.get(tier, [])
	var out: Array = []
	for v in list:
		out.append(int(v))
	return out


func mark_line_shown(npc_id: String, tier: String, index: int) -> void:
	var state := _get_or_create(npc_id)
	var shown: Dictionary = state.get("shown_lines", {})
	var list: Array = (shown.get(tier, []) as Array).duplicate()
	if not (index in list):
		list.append(index)
	shown[tier] = list
	state["shown_lines"] = shown
	_persist()


func reset_shown(npc_id: String, tier: String) -> void:
	var state := _get_or_create(npc_id)
	var shown: Dictionary = state.get("shown_lines", {})
	shown[tier] = []
	state["shown_lines"] = shown
	_persist()
