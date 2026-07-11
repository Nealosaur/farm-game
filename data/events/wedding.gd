class_name WeddingEvent
extends RefCounted
## Marriage M1: the GENERIC wedding cutscene. Parametric over the engaged
## candidate's id (read from Romance.engaged_to() by the caller — see
## romance_events.gd's play_wedding_if_due()), same "bake the id into the
## script array at build time" mechanism as propose.gd.
##
## Staging (bible §2: "reuse the festival crowd override — all NPCs
## present"): the REAL festival crowd mechanism (Festival.is_npc_at_festival
## + each NPC's festival_cell) only activates on an actual calendar festival
## day, which a wedding day generally isn't — so rather than fake the
## calendar, this scene reuses the UNDERLYING machinery the festival crowd
## relies on: EventRunner.resolve_actor()'s existing "find the live NPC, or
## temp-spawn one if it's not on this map/hour" fallback (see event_runner.gd's
## class doc) is used to gather EVERY registered NPC (NPCFactory.ALL_IDS) at a
## distinct plaza cell via `move <id> <x> <y> teleport`, spouse included at
## plaza center — visually identical to a festival gathering without needing
## Clock.is_festival_today() to actually be true today.
##
## Ceremony: a parametric vow exchange (names the spouse via actor-by-id, per
## the contract's "DSL supports actor by id"), then `marry <id>` (sets
## married+spouse+cap-lift via Romance.marry() — see event_runner.gd's
## _cmd_marry), a toast, and `end`. Per-spouse vow line: RomanceEvents.vow_line()
## (Rosa's is placeholder-but-real per the M1 pilot contract; M2 authors the
## other 4 verbatim).
##
## Guard: this is a cutscene like any other DSL scene (GameFlow.cutscene_active
## set for the whole play() duration; EventRunner._exit_tree()'s backstop
## covers an interrupted teardown) — nothing extra needed here.

## Plaza cells (town.gd's PLAZA = Rect2i(16,10,12,8), i.e. x:16-27, y:10-17) —
## one distinct cell per registered NPC, ringed around the center, plus the
## spouse's own cell at dead center next to the player.
const _GUEST_CELLS := {
	"marta": Vector2i(17, 11), "sten": Vector2i(26, 11), "bram": Vector2i(17, 16),
	"rosa": Vector2i(26, 16), "alden": Vector2i(21, 10), "finn": Vector2i(22, 17),
	"willow": Vector2i(18, 13), "garrick": Vector2i(25, 13),
}
const _SPOUSE_CELL := Vector2i(21, 13)
const _PLAYER_CELL := Vector2i(22, 13)


static func data(candidate_id: String) -> Dictionary:
	var script: Array[String] = []
	# Gather every OTHER registered NPC as "crowd" first (spouse gets their
	# own dedicated cell + staging below, so skip them here to avoid a
	# double-move on the same actor).
	for npc_id: String in NPCFactory.ALL_IDS:
		if npc_id == candidate_id:
			continue
		var cell: Vector2i = _GUEST_CELLS.get(npc_id, Vector2i(20, 12))
		script.append("move %s %d %d teleport" % [npc_id, cell.x, cell.y])
	script.append("move %s %d %d teleport" % [candidate_id, _SPOUSE_CELL.x, _SPOUSE_CELL.y])
	script.append("move player %d %d teleport" % [_PLAYER_CELL.x, _PLAYER_CELL.y])
	script.append("camera %s" % candidate_id)
	script.append("face %s player" % candidate_id)
	script.append("face player actor:%s" % candidate_id)
	script.append_array([
		"speak alden \"We are gathered — as we always gather, plaza and all — for a wedding.\"",
		"wait 1.0",
		"speak %s \"%s\"" % [candidate_id, RomanceEvents.vow_line(candidate_id)],
		"wait 1.0",
		"marry %s" % candidate_id,
		"toast \"Married! %s moves in with you.\"" % _display_name(candidate_id),
		"end",
	])
	return {"id": "wedding_" + candidate_id, "script": script}


static func _display_name(candidate_id: String) -> String:
	var data := NPCFactory.build_data(candidate_id)
	return data.display_name if data != null else candidate_id.capitalize()
