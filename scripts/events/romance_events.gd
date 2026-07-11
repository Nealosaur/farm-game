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
## Placeholder lines (M1): every candidate shares ONE generic line per beat
## until M2 authors verbatim per-character text in characters.md. Looked up
## by candidate_id first (Rosa's M1-pilot lines are placeholder-but-real per
## the contract, not yet the shared generic — kept distinct here so swapping
## in her REAL verbatim text later, or any other candidate's, is a one-entry
## dict edit, never a script-structure change).

const _GENERIC_REACTS := "...You're serious. Give me a second — okay. Okay. Ask me properly."
const _GENERIC_ACCEPT := "Yes. Absolutely, unquestionably yes."
const _GENERIC_DECLINE := "...Not yet. Ask me again sometime — I'm not saying no, I'm saying not YET."
const _GENERIC_VOW := "I don't have fancy words. Just — I pick you. Every day, I'd pick you."

const _PROPOSAL_REACTS_BY_ID := {
	"rosa": "You're— oh. Oh, love. Hang on, let me put this tray down before I drop it.",
}
const _PROPOSAL_ACCEPT_BY_ID := {
	"rosa": "Yes. Ask a room full of strangers to feel like family every night and then ask ME that? Yes.",
}
const _PROPOSAL_DECLINE_BY_ID := {
	"rosa": "...Not yet, love. Ask me again — I mean that, I'm not just being kind.",
}
const _VOW_BY_ID := {
	"rosa": "Mother's rule was no one leaves sad. I'm amending it: no one leaves sad, and YOU don't leave. Ever.",
}


static func proposal_reacts_line(candidate_id: String) -> String:
	return String(_PROPOSAL_REACTS_BY_ID.get(candidate_id, _GENERIC_REACTS))


static func proposal_accept_line(candidate_id: String) -> String:
	return String(_PROPOSAL_ACCEPT_BY_ID.get(candidate_id, _GENERIC_ACCEPT))


static func proposal_decline_line(candidate_id: String) -> String:
	return String(_PROPOSAL_DECLINE_BY_ID.get(candidate_id, _GENERIC_DECLINE))


static func vow_line(candidate_id: String) -> String:
	return String(_VOW_BY_ID.get(candidate_id, _GENERIC_VOW))


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
