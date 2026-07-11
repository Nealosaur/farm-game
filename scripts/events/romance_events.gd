class_name RomanceEvents
extends RefCounted
## Marriage M1: small glue helpers shared by the parametric propose/wedding
## DSL scenes (data/events/propose.gd, data/events/wedding.gd) and their
## npc.gd trigger points (_resolve_pendant_proposal, day-rollover wedding
## check). Kept as its own file (not folded into Romance the autoload)
## because this is scene-tree-adjacent glue — spawning an EventRunner,
## picking placeholder-vs-authored line text — not save-state ownership,
## which stays Romance's job alone.
##
## Marriage M2: every candidate now has AUTHORED VERBATIM text from
## docs/design/romance-dialog.md for all four beats (proposal reacts/accept/
## decline, vow) — the M1 generic placeholder fallback stays below only as a
## defensive default for a hypothetical future candidate id that hasn't been
## authored yet (roster is fixed at 5 today, so it should never actually be
## read, but keeps this function total instead of crashing on a bad id).
##
## romance-dialog.md ships ONE "PROPOSAL reaction" line per candidate (no
## separate accept/decline split) — that authored line IS the accept-path
## reaction (it always reads as an enthusiastic yes, matching propose.gd's
## `speak` beat immediately before the DSL's own generic "I do. Marry me."
## question prompt). The DECLINE beat has no per-candidate authored line in
## the source doc (every candidate's arc assumes the player already at L10 +
## dating + presenting a pendant says yes) — kept on the shared generic decline
## line for all 5, documented here rather than inventing un-sourced voice text.

const _GENERIC_REACTS := "...You're serious. Give me a second — okay. Okay. Ask me properly."
const _GENERIC_ACCEPT := "Yes. Absolutely, unquestionably yes."
const _GENERIC_DECLINE := "...Not yet. Ask me again sometime — I'm not saying no, I'm saying not YET."
const _GENERIC_VOW := "I don't have fancy words. Just — I pick you. Every day, I'd pick you."

## "reacts" is the beat spoken BEFORE the DSL's generic accept/decline
## question prompt — romance-dialog.md's authored PROPOSAL reaction lines
## read as the full in-the-moment reaction (excitement through to the yes),
## so they're used as the reacts line, with the doc's same text repeated as
## the accept line (the scene's accept beat is what actually finalizes it —
## repeating the authored yes there keeps the emotional beat intact instead
## of introducing an unsourced second line).
const _PROPOSAL_REACTS_BY_ID := {
	"rosa": "You brought the pendant. To ME. The organizer never gets organized FOR — I'm going to marry you SO hard, love. Yes. Loud yes. Every yes.",
	"willow": "A pendant. Given with hands, from the ground of your choosing. That's the whole ceremony, and the forest is my witness. Yes. The quietest, surest yes I own.",
	"bram": "A pendant. In a doctor's hands. I have delivered a hundred hard verdicts in this room and never once a joyful one — so let me: yes. Prognosis excellent. Lifelong.",
	"sten": "Pendant. In my forge. ...Right. Yes. Only word I've got and I mean it harder than I've meant anything I've hammered. Yes. Come here.",
	"garrick": "A pendant. From you. Ha— the King below, the floors, the twenty years, and THIS is the thing that finally gets my nerve to stand still. Yes. Grinning yes. Don't you dare tell Sten I teared up.",
}
const _PROPOSAL_ACCEPT_BY_ID := {
	"rosa": "You brought the pendant. To ME. The organizer never gets organized FOR — I'm going to marry you SO hard, love. Yes. Loud yes. Every yes.",
	"willow": "A pendant. Given with hands, from the ground of your choosing. That's the whole ceremony, and the forest is my witness. Yes. The quietest, surest yes I own.",
	"bram": "A pendant. In a doctor's hands. I have delivered a hundred hard verdicts in this room and never once a joyful one — so let me: yes. Prognosis excellent. Lifelong.",
	"sten": "Pendant. In my forge. ...Right. Yes. Only word I've got and I mean it harder than I've meant anything I've hammered. Yes. Come here.",
	"garrick": "A pendant. From you. Ha— the King below, the floors, the twenty years, and THIS is the thing that finally gets my nerve to stand still. Yes. Grinning yes. Don't you dare tell Sten I teared up.",
}
const _PROPOSAL_DECLINE_BY_ID := {
	"rosa": "...Not yet, love. Ask me again — I mean that, I'm not just being kind.",
}
const _VOW_BY_ID := {
	"rosa": "Rule holds — no one leaves sad. Least of all me. I've got my one, and the whole plaza to prove it.",
	"willow": "The woods count you as weather now — reliable, returning. So do I. Kin of this ground. Mine to grow beside.",
	"bram": "I left a city to matter to no one. Worst plan of my career. You're my someone. I intend to be very, very careful with you — forever.",
	"sten": "Blades I've made that I trust: three. People: one. You carry the blade. I carry you. Straight, and forever, and I'll not say it softer than that in front of a crowd — but I mean it soft.",
	"garrick": "To floors below and a friend above — I found the above. I'm done descending. Whatever's left of this old adventurer, it's yours, and it's staying put.",
}

## Marriage M2: the 14-heart capstone monologue — data-only here (M1's doc:
## "the event data lives here now so M3 can trigger it"). Looked up from each
## candidate's own dialog DATA (data/dialog/<id>.gd's "fourteen_heart" key)
## rather than duplicated in a const table here, since the full scene text is
## multi-line (a "lines" array, same shape as an ordinary heart event) and
## dialog DATA is already the single source of truth for every other piece of
## a candidate's authored voice.
const _DIALOG_SCRIPTS_BY_ID := {
	"rosa": "res://data/dialog/rosa.gd",
	"willow": "res://data/dialog/willow.gd",
	"bram": "res://data/dialog/bram.gd",
	"sten": "res://data/dialog/sten.gd",
	"garrick": "res://data/dialog/garrick.gd",
}


static func proposal_reacts_line(candidate_id: String) -> String:
	return String(_PROPOSAL_REACTS_BY_ID.get(candidate_id, _GENERIC_REACTS))


static func proposal_accept_line(candidate_id: String) -> String:
	return String(_PROPOSAL_ACCEPT_BY_ID.get(candidate_id, _GENERIC_ACCEPT))


static func proposal_decline_line(candidate_id: String) -> String:
	return String(_PROPOSAL_DECLINE_BY_ID.get(candidate_id, _GENERIC_DECLINE))


static func vow_line(candidate_id: String) -> String:
	return String(_VOW_BY_ID.get(candidate_id, _GENERIC_VOW))


## ---- 14-heart spouse capstone (data-only in M2; M3 triggers it) ----

static func fourteen_heart_lines(candidate_id: String) -> Array[String]:
	## Returns the capstone monologue's "lines" array (setup beat + the
	## authored speech), or an empty array if the candidate id isn't
	## registered/has no fourteen_heart block — mirrors npc.gd's own
	## graceful-degradation shape for un-authored content (never crashes on a
	## bad/future id; a caller just gets nothing to play).
	var script_path: String = _DIALOG_SCRIPTS_BY_ID.get(candidate_id, "")
	if script_path == "":
		return []
	var script: GDScript = load(script_path)
	var data: Dictionary = script.DATA
	var capstone: Dictionary = data.get("fourteen_heart", {})
	var out: Array[String] = []
	for line: String in capstone.get("lines", []):
		out.append(line)
	return out


static func fourteen_heart_id(candidate_id: String) -> String:
	var script_path: String = _DIALOG_SCRIPTS_BY_ID.get(candidate_id, "")
	if script_path == "":
		return ""
	var script: GDScript = load(script_path)
	var data: Dictionary = script.DATA
	var capstone: Dictionary = data.get("fourteen_heart", {})
	return String(capstone.get("id", ""))


## ---- launching the proposal scene from the gift flow ----

static func play_proposal(from_node: Node, candidate_id: String) -> void:
	## Called directly from npc.gd's gift-resolution (_resolve_pendant_proposal)
	## the instant a pendant is handed to a dating-at-L10 candidate — no
	## TriggerService/EventDirector precondition matrix involved (see
	## propose.gd's class doc for why). Spawns a plain EventRunner as a child
	## of the current map root (mirrors EventDirector._play_scene()'s own
	## "add an EventRunner, play(), queue_free when finished" shape) so it
	## picks up the same "map_root"/"World" group lookups every other scene
	## depends on for actor resolution/camera.
	var parent := _scene_parent_for(from_node)
	if parent == null:
		return
	var runner := EventRunner.new()
	parent.add_child(runner)
	runner.finished.connect(runner.queue_free, CONNECT_ONE_SHOT)
	runner.play(ProposeEvent.data(candidate_id))


static func _scene_parent_for(from_node: Node) -> Node:
	## Prefers the real map root ("map_root" group — every map scene adds
	## itself to it) so EventRunner's own "map_root"/"World" group lookups
	## (actor resolution, camera, PathGrid) work exactly like every other
	## scene. Falls back to current_scene, and finally to `from_node` itself
	## (e.g. a standalone NPC in a headless unit test with no map/current_scene
	## at all — see test_romance_gift_flow.gd) so this never silently no-ops
	## just because it's called outside a real map.
	var root := from_node.get_tree().get_first_node_in_group("map_root")
	if root != null:
		return root
	if from_node.get_tree().current_scene != null:
		return from_node.get_tree().current_scene
	return from_node


## ---- Marriage M3: launching the 14-heart spouse capstone from interact() ----

static func play_spouse_capstone(from_node: Node, spouse_id: String) -> void:
	## Called from npc.gd's interact() the first time the player talks to
	## their spouse at L14 (see Relationships.pending_event()'s "l14" gate) —
	## same "spawn a plain EventRunner as a child of the map root" shape as
	## play_proposal() above, since the capstone has no TriggerService
	## precondition matrix of its own either (it's gated on relationship level
	## + marriage state, which npc.gd/Relationships already own). Marks the
	## event seen via Relationships.mark_event_seen(spouse_id, "l14") once the
	## scene finishes, so it never re-fires (mirrors EventDirector's own
	## "mark forever-seen on scene finish" shape, but through Relationships'
	## events_seen list rather than SaveManager.world["events_seen"], since
	## this is a per-NPC heart-event slot like l3/l7/l8/l10, not a map-scoped
	## authored scene).
	var parent := _scene_parent_for(from_node)
	if parent == null:
		return
	var runner := EventRunner.new()
	parent.add_child(runner)
	runner.finished.connect(runner.queue_free, CONNECT_ONE_SHOT)
	runner.finished.connect(_on_spouse_capstone_finished.bind(spouse_id), CONNECT_ONE_SHOT)
	runner.play(SpouseCapstoneEvent.data(spouse_id))


static func _on_spouse_capstone_finished(spouse_id: String) -> void:
	Relationships.mark_event_seen(spouse_id, "l14")


## ---- launching the wedding scene on the due day-rollover ----

static func play_wedding_if_due(from_node: Node) -> bool:
	## Called on town map entry/block-change (see town.gd's _add_event_director
	## wiring) — town.gd checks Romance.is_wedding_due() itself before calling
	## this (mirrors EventDirector.check()'s own "no-op if nothing qualifies"
	## shape) so this function assumes the caller already gated on it; it just
	## does the actual spawn-and-play. Returns true if it started a wedding
	## (so the caller can skip its OWN EventDirector.check() the same tick —
	## a wedding and an authored EventScript scene should never compete for
	## the same cutscene slot).
	if not Romance.is_wedding_due():
		return false
	var parent := _scene_parent_for(from_node)
	if parent == null:
		return false
	var candidate_id := Romance.engaged_to()
	var runner := EventRunner.new()
	parent.add_child(runner)
	runner.finished.connect(runner.queue_free, CONNECT_ONE_SHOT)
	runner.play(WeddingEvent.data(candidate_id))
	return true
