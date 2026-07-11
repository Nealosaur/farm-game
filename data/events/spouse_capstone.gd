class_name SpouseCapstoneEvent
extends RefCounted
## Marriage M2: the GENERIC 14-heart spouse capstone cutscene. Parametric over
## `spouse_id`, same "bake the id into the script array at build time"
## mechanism as propose.gd/wedding.gd — one scene definition, reused for
## whichever of the 5 candidates is actually married.
##
## M2 SCOPE: this file exists so the capstone's DATA (romance-dialog.md's
## authored 14-HEART scene per candidate, stored in each candidate's
## data/dialog/<id>.gd under "fourteen_heart") has a ready-made DSL consumer —
## per the contract, "the event data lives here now so M3 can trigger it."
## M2 does NOT wire the trigger itself (no L14 pending_event slot, no
## day/level gate, no call site) — that's explicitly M3's job once
## spouse-on-farm scheduling exists and there's a real farm-porch/kitchen
## staging moment to fire this from. Calling data() today and playing it
## through EventRunner already works end-to-end (see
## test_romance_content_completeness.gd's smoke coverage), it's just nothing
## calls it yet.
##
## Staging: romance-dialog.md's 14-heart scenes are all a single farm-set
## monologue (porch/kitchen/clearing, no player choice) — simpler than
## propose.gd's question/branch shape, closer to intro_alden.gd's plain
## speak-then-end shape. `camera`/`face` frame the spouse before the line;
## no `move`/teleport staging is baked in here since M3 owns the actual
## farm-schedule positions this will play from (a farm map's own schedule
## already places the spouse somewhere sensible by then).


static func data(spouse_id: String) -> Dictionary:
	var lines := RomanceEvents.fourteen_heart_lines(spouse_id)
	var script: Array[String] = [
		"camera %s" % spouse_id,
		"face %s player" % spouse_id,
		"face player actor:%s" % spouse_id,
	]
	for line: String in lines:
		script.append("speak %s \"%s\"" % [spouse_id, line])
	script.append("end")
	return {
		"id": "fourteen_heart_" + spouse_id,
		"script": script,
	}
