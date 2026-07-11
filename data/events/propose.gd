class_name ProposeEvent
extends RefCounted
## Marriage M1: the GENERIC proposal cutscene. Parametric over `candidate_id`
## (Rosa is the M1 pilot; Willow/Bram/Sten/Garrick reuse this SAME scene the
## moment M2 authors their own accept/decline lines — no new scene needed per
## candidate). Unlike garrick_sten_bench.gd/sten_fang_steel.gd (fixed actor
## ids baked into a `const DATA` dict, picked up by TriggerService/
## EventDirector on a map's own block-change check), this scene is triggered
## DIRECTLY from the gift flow the instant a dating-at-L10 candidate is handed
## a pendant (see npc.gd's _resolve_pendant_proposal()) — there is no
## precondition matrix to satisfy and no "which scene fires today" pick,
## so `data()` returns a script_data dict built fresh per call, with every
## command string carrying the candidate's id substituted in directly
## (the DSL itself has no variable interpolation — this is the "runtime
## param" mechanism the contract calls for: bake the id into the script
## array at BUILD time, once, right before EventRunner.play() reads it).
##
## Flow (bible §2): candidate reacts -> player confirms via a `question`
## command -> accept sets the engaged flag (Romance.propose_accept(), fired
## by the `engage` command — see event_runner.gd) + schedules the wedding for
## the NEXT day-rollover (Romance handles the "+1 day" arithmetic itself) ->
## decline just closes out, no state change, pendant already spent (npc.gd
## already removed it from inventory before calling play_proposal() — this
## scene's OWN preconditions are trivial by construction: the gift flow that
## invokes it already re-validated dating+L10 immediately beforehand).
##
## M1 uses a GENERIC placeholder line for every candidate (the "reacts" beat
## and both accept/decline responses) — M2 authors each candidate's verbatim
## accept/decline text per the bible's "characters.md, VERBATIM" rule. The
## line text itself is looked up from RomanceEvents.PROPOSAL_LINES (keyed by
## candidate_id, falling back to a shared generic placeholder) so swapping in
## real text later is a one-line data change, not a script edit.
##
## Cutscene guard: play() itself sets GameFlow.cutscene_active = true for its
## whole duration (see EventRunner.play()'s own doc) and the class's
## _exit_tree() backstop already restores it/Clock.paused on a scene-tree
## teardown mid-play — nothing extra needed here.


static func data(candidate_id: String) -> Dictionary:
	var reacts_line := RomanceEvents.proposal_reacts_line(candidate_id)
	var accept_line := RomanceEvents.proposal_accept_line(candidate_id)
	var decline_line := RomanceEvents.proposal_decline_line(candidate_id)
	return {
		"id": "propose_" + candidate_id,
		"script": [
			"camera %s" % candidate_id,
			"face %s player" % candidate_id,
			"speak %s \"%s\"" % [candidate_id, reacts_line],
			"question \"Well?\" accept \"I do. Marry me.\" decline \"...Not yet.\"",
			"label decline",
			"speak %s \"%s\"" % [candidate_id, decline_line],
			"jump finish",
			"label accept",
			"speak %s \"%s\"" % [candidate_id, accept_line],
			"engage %s" % candidate_id,
			"toast \"Engaged! The wedding is tomorrow.\"",
			"label finish",
			"end",
		],
	}
