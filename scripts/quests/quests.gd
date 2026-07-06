extends Node
## World Stride D: quest lifecycle over SaveManager.world["quests"]. An
## autoload (like Relationships) rather than a static class, because quest
## state needs the same "restore after new_game()/load_game(), persist on
## every mutation" shape Relationships already established — and because
## EventBus.quest_updated needs a single owner to emit it consistently.
##
## Blob shape — SaveManager.world["quests"] (documented in save_manager.gd's
## sanctioned-keys contract too):
##   { quest_id: { "state": "active"|"done", ...progress-specific keys } }
## All reads MUST int()/String() coerce — JSON round-trips ints as floats,
## same established gotcha every other world blob follows.
##
## Quest ids + progress shape (bible §Opening, characters.md Garrick QUESTS):
##   "new_roots"  — {"state", "met": [npc_id, ...]}. Granted by Alden's Day-1
##                  intro. Auto-checks the FIRST-EVER talk with each of the 8
##                  registered NPCs (NPCFactory.ALL_IDS) via record_talk().
##                  Completes when all 8 are met. Hand-in: next Alden talk
##                  after completion -> 300g + 5 turnip_seeds.
##   "prove_it"   — {"state"}. Granted on first-ever Garrick talk (any level).
##                  Completes on entering dungeon_2 (record_floor_entered()).
##                  Hand-in: next Garrick talk after completion -> 200g.
##   "king_below" — {"state"}. Granted at prove_it's hand-in. Completes on
##                  GameState.flags["boss_defeated"] (if already true when
##                  granted, completes INSTANTLY — see grant_king_below()).
##                  Hand-in: next Garrick talk after completion -> 500g, with
##                  the special "already met the King" line if the flag was
##                  already true at grant time (characters.md's verbatim
##                  "Heard the King's already met you..." line).
##
## Emits EventBus.quest_updated(quest_id) on every grant/progress/complete/
## hand-in mutation — same "autoload emits through the shared bus, not its
## own signal" convention Relationships follows (relationship_changed lives
## on EventBus too), so the HUD toast wiring only ever listens in one place.
##
## npc.gd is the only scene-tree caller (see its quest-hook methods) — this
## autoload itself never touches DialogBox/Inventory directly except via the
## same Inventory/GameState autoloads Relationships' perk-grant path already
## uses (see grant rewards below), keeping this testable headless like every
## other autoload in the project.

const ID_NEW_ROOTS := "new_roots"
const ID_PROVE_IT := "prove_it"
const ID_KING_BELOW := "king_below"

const STATE_ACTIVE := "active"
const STATE_DONE := "done"

## All 8 registered NPC ids "New Roots" tracks meeting. Matches
## NPCFactory.ALL_IDS but declared as its own const (not a NPCFactory
## reference) so this file has zero scene-tree/class dependency beyond
## GameState/Inventory/EventBus, same testability bar as Relationships.
const NEW_ROOTS_NPCS := ["marta", "sten", "bram", "rosa", "alden", "finn", "willow", "garrick"]

var _quests := {}  # quest_id -> state dict, mirrors SaveManager.world["quests"]


func _ready() -> void:
	EventBus.boss_defeated.connect(check_boss_defeated)


## ---- persistence ----

func restore() -> void:
	## Call after SaveManager.load_game()/new_game() (world blob contract —
	## no signal fires on load, callers sequence it like Relationships.restore()).
	var blob: Dictionary = SaveManager.world.get("quests", {})
	_quests = {}
	for quest_id: String in blob:
		_quests[quest_id] = _coerce_state(blob[quest_id])
	SaveManager.world["quests"] = _quests


func _persist() -> void:
	SaveManager.world["quests"] = _quests


static func _coerce_state(raw: Dictionary) -> Dictionary:
	var met_raw: Array = raw.get("met", [])
	var met: Array = []
	for v in met_raw:
		met.append(String(v))
	return {
		"state": String(raw.get("state", STATE_ACTIVE)),
		"met": met,
		"already_met_king": bool(raw.get("already_met_king", false)),
	}


## ---- queries ----

func has_quest(quest_id: String) -> bool:
	return _quests.has(quest_id)


func state(quest_id: String) -> String:
	return String(_quests.get(quest_id, {}).get("state", ""))


func is_active(quest_id: String) -> bool:
	return state(quest_id) == STATE_ACTIVE


func is_done(quest_id: String) -> bool:
	return state(quest_id) == STATE_DONE


func met_npcs(quest_id: String) -> Array:
	var out: Array = []
	for v in _quests.get(quest_id, {}).get("met", []):
		out.append(String(v))
	return out


## ---- grants ----

func _grant(quest_id: String, extra: Dictionary = {}) -> void:
	if has_quest(quest_id):
		return  # already granted (active or done) — never re-grant
	var state_dict := _coerce_state({})
	for k: String in extra:
		state_dict[k] = extra[k]
	_quests[quest_id] = state_dict
	_persist()
	EventBus.quest_updated.emit(quest_id)


func grant_new_roots() -> void:
	_grant(ID_NEW_ROOTS, {"met": []})


func grant_prove_it() -> void:
	_grant(ID_PROVE_IT)


func grant_king_below() -> void:
	## Bible: "auto-completes if flag already set" — if boss_defeated is
	## already true at grant time (player somehow beat the boss before
	## finishing prove_it's hand-in — see dungeon floor ordering notes in
	## the stride report), complete this quest INSTANTLY and remember that
	## fact so Garrick's hand-in line can use the "already met the King"
	## verbatim response instead of the normal completion line.
	if has_quest(ID_KING_BELOW):
		return
	var already := bool(GameState.flags.get("boss_defeated", false))
	_grant(ID_KING_BELOW, {"already_met_king": already})
	if already:
		_complete(ID_KING_BELOW)


## ---- progress ----

func record_talk(npc_id: String) -> void:
	## Called by npc.gd on EVERY talk (mirrors Relationships.talk() being
	## called every interact — this no-ops harmlessly if new_roots isn't
	## active or the NPC is already recorded met). "FIRST-EVER talk" per the
	## bible: once an id is in `met`, later talks don't matter.
	if not is_active(ID_NEW_ROOTS):
		return
	if not (npc_id in NEW_ROOTS_NPCS):
		return
	var q: Dictionary = _quests[ID_NEW_ROOTS]
	var met: Array = q["met"]
	if npc_id in met:
		return
	met.append(npc_id)
	q["met"] = met
	_persist()
	EventBus.quest_updated.emit(ID_NEW_ROOTS)
	if met.size() >= NEW_ROOTS_NPCS.size():
		_complete(ID_NEW_ROOTS)


func record_floor_entered(floor_key: String) -> void:
	## Called on dungeon floor scene _ready() (see dungeon_floor.gd hook).
	## Bible: "completes on entering dungeon_2" — floor 3+ also satisfies it
	## (reaching floor 2 is a strict subset of reaching floor 3), matching
	## the quest's own wording ("reach Delve floor 2").
	if not is_active(ID_PROVE_IT):
		return
	if floor_key == "dungeon_2" or floor_key == "dungeon_3":
		_complete(ID_PROVE_IT)


func check_boss_defeated() -> void:
	## Called on EventBus.boss_defeated (see _ready's connection) so
	## king_below completes the moment the fight ends, not just on next talk.
	if is_active(ID_KING_BELOW) and bool(GameState.flags.get("boss_defeated", false)):
		_complete(ID_KING_BELOW)


func _complete(quest_id: String) -> void:
	if not is_active(quest_id):
		return
	_quests[quest_id]["state"] = STATE_DONE
	_persist()
	EventBus.quest_updated.emit(quest_id)


## ---- hand-in ----

func hand_in_new_roots() -> bool:
	## Alden's next talk after new_roots is done: 300g + 5 turnip_seeds,
	## "from Marta" per the bible. Returns true if a hand-in actually
	## happened (caller uses this to decide whether to show the reward line).
	if not is_done(ID_NEW_ROOTS):
		return false
	GameState.add_gold(300)
	Inventory.add_item("turnip_seeds", 5)
	_retire(ID_NEW_ROOTS)
	return true


func hand_in_prove_it() -> bool:
	if not is_done(ID_PROVE_IT):
		return false
	GameState.add_gold(200)
	_retire(ID_PROVE_IT)
	grant_king_below()
	return true


func hand_in_king_below() -> Dictionary:
	## Returns {"handed_in": bool, "already_met_king": bool} — the caller
	## (npc.gd) needs already_met_king to pick Garrick's verbatim line
	## ("Heard the King's already met you. Ha! Money's still money.")
	## vs the ordinary completion reward line.
	if not is_done(ID_KING_BELOW):
		return {"handed_in": false, "already_met_king": false}
	var already := bool(_quests[ID_KING_BELOW].get("already_met_king", false))
	GameState.add_gold(500)
	_retire(ID_KING_BELOW)
	return {"handed_in": true, "already_met_king": already}


func _retire(quest_id: String) -> void:
	## Marks a completed quest as fully handed-in by removing it from the
	## active/done tracking dict entirely — matches the bible's "state:
	## active|done" shape not needing a third "handed_in" state, since a
	## retired quest is simply absent (has_quest() becomes false, and
	## is_done()/is_active() both correctly report false for anything not
	## present per state()'s "" default).
	_quests.erase(quest_id)
	_persist()
	EventBus.quest_updated.emit(quest_id)


## ---- journal display helpers ----

func active_quest_ids() -> Array:
	var out: Array = []
	for quest_id: String in _quests:
		if is_active(quest_id):
			out.append(quest_id)
	out.sort()
	return out


func progress_text(quest_id: String) -> String:
	match quest_id:
		ID_NEW_ROOTS:
			return "Met %d/%d" % [met_npcs(ID_NEW_ROOTS).size(), NEW_ROOTS_NPCS.size()]
		ID_PROVE_IT:
			return "Floor 2: not yet"
		ID_KING_BELOW:
			return "Slime King: not yet"
		_:
			return ""


static func display_name(quest_id: String) -> String:
	match quest_id:
		ID_NEW_ROOTS:
			return "New Roots — meet everyone in Emberhollow"
		ID_PROVE_IT:
			return "Prove It — reach Delve floor 2"
		ID_KING_BELOW:
			return "The King Below — defeat the Slime King"
		_:
			return quest_id
