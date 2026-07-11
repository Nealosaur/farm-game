extends Node
## Marriage M1: dating/engagement/marriage state layered on TOP of
## Relationships (bond points/levels stay owned there — see relationships.gd's
## MAX_POINTS/spouse-cap-lift doc). A separate autoload rather than folding
## into Relationships because the two are genuinely different lifecycles: a
## bond LEVEL can rise/decay every day for any of the 8 NPCs, while
## dating/engaged/married is a one-way relationship ratchet that only applies
## to the 5 romanceable candidates and touches ItemDB/EventBus/GameState in
## ways Relationships' existing doc/tests never needed to.
##
## Roster (docs/design/marriage.md §1, CONFIRMED): Rosa, Willow, Bram, Sten,
## Garrick are romanceable. Marta/Alden/Finn stay platonic. Documented choice:
## a `const ROMANCEABLE_IDS` set here (NOT an `romanceable: bool` field on
## NPCData) — the roster is a fixed, small, game-design-owned list that has
## nothing to do with an individual NPC's schedule/gift data, so keeping it as
## one lookup table in the system that actually gates on it (this file) avoids
## scattering "am I romanceable" bookkeeping across 8 separate data resources.
##
## Blob shape — SaveManager.world["romance"] (documented in save_manager.gd's
## sanctioned-keys contract too):
##   { npc_id: {"dating": bool, "married": bool}, "spouse": String }
## "spouse" is a RESERVED key inside the same dict, not a per-candidate entry —
## safe because every real npc_id (NPCFactory.ALL_IDS) is lowercase and none of
## them is literally "spouse". Holds the current spouse's npc_id, or "" if
## unmarried. Kept inside the SAME top-level blob (rather than a second
## "world[spouse]" key) so the whole romance picture round-trips as one unit.
## All reads MUST int()/bool() coerce per npc_id entry — JSON round-trips
## bools fine in Godot's JSON but every other world blob in this codebase
## coerces defensively (see relationships.gd's own doc), so this one does too
## for consistency and because a hand-edited/older save could have drifted.
##
## Engagement (not yet a spouse, but pendant-proposal accepted): tracked as a
## GameState.flags entry, NOT in this blob — "engaged_to": String flag +
## "wedding_day": int flag (the day the wedding should fire, i.e. the very
## next day-rollover after the proposal was accepted). GameState.flags already
## round-trips via GameState.to_dict()/from_dict() (see save_manager.gd), so
## engagement doesn't need its own world-blob entry, mirroring how "intro_done"
## already lives there instead of growing a dedicated save key.
##
## Marrying ends other dating (documented, bible §2 "One spouse at a time."):
## marry(id) sets every OTHER dating candidate's "dating" back to false and
## applies a small bond ding (see END_OTHER_DATING_BOND_DING) — the actual
## in-voice reaction LINE is an M2/M3 hook (per-character content), not
## authored here; this system only guarantees the flag flip + bond happens.

const ROMANCEABLE_IDS: Array[String] = ["rosa", "willow", "bram", "sten", "garrick"]

## Bouquet gift gate (bible §2: "give to a candidate at L8+ to start dating").
const DATING_MIN_LEVEL := 8
## Pendant gift gate (bible §2: "dating at L10 -> triggers the proposal").
const PROPOSAL_MIN_LEVEL := 10

## Bible §2: "Marrying ends other dating (...) a small bond ding". No exact
## number specified — chosen small relative to HEART_EVENT_DELTA (30) so it
## reads as a wince, not a punishment; documented here since it's this
## system's own constant, not Relationships'.
const END_OTHER_DATING_BOND_DING := -20

var _state := {}   # npc_id -> {"dating": bool, "married": bool}, mirrors world["romance"]
var _spouse := ""  # "" = unmarried


func _ready() -> void:
	pass  # no EventBus listeners needed yet — every mutation here is player-driven


## ---- persistence ----

func restore() -> void:
	## Call after SaveManager.load_game()/new_game(), same sequencing rule as
	## Relationships.restore()/Quests.restore() (no signal fires on load).
	var blob: Dictionary = SaveManager.world.get("romance", {})
	_state = {}
	_spouse = String(blob.get("spouse", ""))
	for npc_id: String in blob:
		if npc_id == "spouse":
			continue
		_state[npc_id] = _coerce_entry(blob[npc_id])
	_persist()


func _persist() -> void:
	var out := {}
	for npc_id: String in _state:
		out[npc_id] = _state[npc_id]
	out["spouse"] = _spouse
	SaveManager.world["romance"] = out


static func _coerce_entry(raw: Dictionary) -> Dictionary:
	return {
		"dating": bool(raw.get("dating", false)),
		"married": bool(raw.get("married", false)),
	}


func _get_or_create(npc_id: String) -> Dictionary:
	if not _state.has(npc_id):
		_state[npc_id] = _coerce_entry({})
	return _state[npc_id]


## ---- roster ----

static func is_romanceable(npc_id: String) -> bool:
	return npc_id in ROMANCEABLE_IDS


## ---- queries ----

func is_dating(npc_id: String) -> bool:
	return bool(_get_or_create(npc_id).get("dating", false))


func is_married_to(npc_id: String) -> bool:
	return _spouse == npc_id and npc_id != ""


func spouse() -> String:
	return _spouse


func is_engaged() -> bool:
	return String(GameState.flags.get("engaged_to", "")) != ""


func engaged_to() -> String:
	return String(GameState.flags.get("engaged_to", ""))


## ---- dating ----

func start_dating(npc_id: String) -> bool:
	## Bible: bouquet at L8+ to a romanceable candidate starts dating. Returns
	## false (no-op) if the candidate isn't romanceable or the level gate
	## isn't met yet — callers (npc.gd's gift flow) check this themselves
	## before calling so they can show the right refusal line, but this method
	## re-validates so it's never possible to start dating out-of-band (tests,
	## future callers) without meeting the real gate.
	if not is_romanceable(npc_id):
		return false
	if Relationships.level(npc_id) < DATING_MIN_LEVEL:
		return false
	var state := _get_or_create(npc_id)
	state["dating"] = true
	_persist()
	return true


## ---- marriage ----

## Marriage M3 (bible §2/§5: "marrying ends other dating... a small bond ding
## + a one-line reaction — your call"): no per-character breakup speech
## exists in romance-dialog.md for this beat (every candidate's authored arc
## only ever covers THEIR OWN romance, never a scene where they're the one
## being let go for someone else) — inventing 5 unsourced voice lines would
## violate the "ship VERBATIM, don't paraphrase" rule this whole pillar
## follows. M3's call: skip a spoken line entirely and apply the mechanism +
## a single, dignified, GENERIC toast per ended candidate instead (documented
## here rather than in marry()'s own doc, since the toast is this constant's
## whole reason for existing).
const _OTHER_DATING_ENDED_TOAST := "%s heard about the wedding. Quietly, they wish you well."


func marry(npc_id: String) -> bool:
	## Sets married + spouse, ends every OTHER dating relationship (bible:
	## "One spouse at a time... a small bond ding"). Does NOT itself check
	## is_dating/level gates — the proposal/wedding DSL scenes are what gate
	## WHEN this gets called (pendant->propose->accept->next-day wedding);
	## this is the terminal "make it official" step and stays unconditional
	## so a test or a future direct-marry path isn't silently blocked.
	if not is_romanceable(npc_id):
		return false
	for other_id: String in _state.keys():
		if other_id == npc_id:
			continue
		var other: Dictionary = _state[other_id]
		if bool(other.get("dating", false)):
			other["dating"] = false
			Relationships.add_flat_bond(other_id, END_OTHER_DATING_BOND_DING)
			var other_data := NPCFactory.build_data(other_id)
			var other_name := other_data.display_name if other_data != null else other_id.capitalize()
			EventBus.toast_requested.emit(_OTHER_DATING_ENDED_TOAST % other_name)
	var state := _get_or_create(npc_id)
	state["dating"] = true
	state["married"] = true
	_spouse = npc_id
	_persist()
	# The engagement (GameState.flags engaged_to/wedding_day) is fully spent
	# the moment a marriage actually lands — clearing it HERE (rather than
	# leaving it to the wedding DSL script/caller) guarantees
	# Romance.is_wedding_due() can never re-fire a second wedding for the
	# same engagement, no matter what calls marry() (the wedding scene today,
	# a future direct-marry path, or a test).
	clear_engagement()
	return true


## ---- engagement (GameState.flags-backed, see class doc) ----

func propose_accept(npc_id: String) -> void:
	GameState.flags["engaged_to"] = npc_id
	GameState.flags["wedding_day"] = Clock.day + 1


func is_wedding_due() -> bool:
	if not is_engaged():
		return false
	return Clock.day >= int(GameState.flags.get("wedding_day", 0))


func clear_engagement() -> void:
	GameState.flags.erase("engaged_to")
	GameState.flags.erase("wedding_day")
