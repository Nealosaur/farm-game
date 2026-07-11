extends GutTest
## Marriage M2: romance-content completeness meta-test across all 5
## romanceable candidates — generalizes test_all_npcs_dialog_completeness.gd's
## shape/non-emptiness sweep to the romance-specific data added on top of the
## ordinary dialog DATA (dating_lines, heart_events.l8/l10, fourteen_heart)
## plus RomanceEvents' per-candidate proposal/vow lines. Guards against a
## verbatim-port slip (an empty/missing field for one candidate that the
## per-candidate E2E chain test might not otherwise catch if it only checks
## Rosa's exact strings).
##
## Per-candidate VERBATIM spot-checks (a couple of exact lines each, cross-
## checked against docs/design/romance-dialog.md character-for-character)
## live at the bottom, mirroring test_all_npcs_dialog_completeness.gd's own
## "one representative string each" convention.

const DIALOG_SCRIPTS := {
	"rosa": "res://data/dialog/rosa.gd",
	"willow": "res://data/dialog/willow.gd",
	"bram": "res://data/dialog/bram.gd",
	"sten": "res://data/dialog/sten.gd",
	"garrick": "res://data/dialog/garrick.gd",
}


func _data(npc_id: String) -> Dictionary:
	var script: GDScript = load(DIALOG_SCRIPTS[npc_id])
	return script.DATA


func test_every_candidate_has_exactly_three_dating_lines() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var lines: Array = data.get("dating_lines", [])
		assert_eq(lines.size(), 3, "%s: dating_lines must have exactly 3 authored lines" % npc_id)
		for line: String in lines:
			assert_ne(line, "", "%s: dating_lines must not contain an empty string" % npc_id)


func test_every_candidate_has_l8_and_l10_heart_events_with_full_shape() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var events: Dictionary = data.get("heart_events", {})
		for level_key in ["l8", "l10"]:
			var event: Dictionary = events.get(level_key, {})
			assert_true(event.has("id"), "%s: heart_events.%s must have an id" % [npc_id, level_key])
			assert_gt((event.get("lines", []) as Array).size(), 0,
				"%s: heart_events.%s must have at least one setup line" % [npc_id, level_key])
			for key in ["choice_a", "choice_b", "response_a", "response_b"]:
				assert_ne(String(event.get(key, "")), "",
					"%s: heart_events.%s.%s must be set" % [npc_id, level_key, key])


func test_every_candidate_has_a_non_empty_fourteen_heart_capstone() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var capstone: Dictionary = data.get("fourteen_heart", {})
		assert_true(capstone.has("id"), "%s: fourteen_heart must have an id" % npc_id)
		assert_gt((capstone.get("lines", []) as Array).size(), 0,
			"%s: fourteen_heart must have at least one line" % npc_id)


func test_every_candidate_has_proposal_and_vow_lines() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		assert_ne(RomanceEvents.proposal_reacts_line(npc_id), RomanceEvents._GENERIC_REACTS,
			"%s: proposal reacts line must be authored, not the shared generic" % npc_id)
		assert_ne(RomanceEvents.proposal_accept_line(npc_id), RomanceEvents._GENERIC_ACCEPT,
			"%s: proposal accept line must be authored, not the shared generic" % npc_id)
		assert_ne(RomanceEvents.vow_line(npc_id), RomanceEvents._GENERIC_VOW,
			"%s: vow line must be authored, not the shared generic" % npc_id)


func test_fourteen_heart_lines_accessor_matches_dialog_data() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var data := _data(npc_id)
		var capstone: Dictionary = data.get("fourteen_heart", {})
		assert_eq(RomanceEvents.fourteen_heart_id(npc_id), String(capstone.get("id", "")))
		var expected: Array = capstone.get("lines", [])
		var actual := RomanceEvents.fourteen_heart_lines(npc_id)
		assert_eq(actual.size(), expected.size(), "%s: fourteen_heart_lines() size mismatch" % npc_id)
		for i in expected.size():
			assert_eq(actual[i], expected[i], "%s: fourteen_heart_lines()[%d] mismatch" % [npc_id, i])


func test_spouse_capstone_scene_builds_a_speak_command_per_line() -> void:
	for npc_id: String in DIALOG_SCRIPTS:
		var scene_data := SpouseCapstoneEvent.data(npc_id)
		var script: Array = scene_data["script"]
		var speak_count := 0
		for line: String in script:
			if line.begins_with("speak %s " % npc_id):
				speak_count += 1
		var expected_lines := RomanceEvents.fourteen_heart_lines(npc_id)
		assert_eq(speak_count, expected_lines.size(),
			"%s: spouse capstone scene must emit one speak command per authored line" % npc_id)
		assert_eq(script[-1], "end", "%s: spouse capstone scene must end" % npc_id)


## ---- per-candidate verbatim spot-checks (cross-checked against ----
## ---- docs/design/romance-dialog.md character-for-character) ----

func test_rosa_l8_and_l10_verbatim_spot_check() -> void:
	var data := _data("rosa")
	assert_eq(data["heart_events"]["l8"]["id"], "the_extra_chair")
	assert_eq(data["heart_events"]["l8"]["choice_a"], "\"Then I'll be the one who stays.\"")
	assert_eq(data["heart_events"]["l10"]["id"], "pouring_for_two")
	assert_true("Marry me into the dish rotation, then." in data["heart_events"]["l10"]["choice_a"])
	assert_eq(RomanceEvents.vow_line("rosa"),
		"Rule holds — no one leaves sad. Least of all me. I've got my one, and the whole plaza to prove it.")


func test_willow_l8_and_l10_verbatim_spot_check() -> void:
	var data := _data("willow")
	assert_eq(data["heart_events"]["l8"]["id"], "kin_of_this_ground")
	assert_eq(data["heart_events"]["l10"]["id"], "the_volume_of_a_voice")
	assert_eq(data["heart_events"]["l10"]["choice_a"], "\"Then grow toward me.\"")
	assert_eq(RomanceEvents.vow_line("willow"),
		"The woods count you as weather now — reliable, returning. So do I. Kin of this ground. Mine to grow beside.")


func test_bram_l8_and_l10_verbatim_spot_check() -> void:
	var data := _data("bram")
	assert_eq(data["heart_events"]["l8"]["id"], "the_chart")
	assert_eq(data["heart_events"]["l10"]["id"], "the_reason_part_two")
	assert_eq(data["heart_events"]["l10"]["choice_a"], "\"Let me matter that much anyway.\"")
	assert_eq(RomanceEvents.proposal_accept_line("bram"),
		"A pendant. In a doctor's hands. I have delivered a hundred hard verdicts in this room and never once a joyful one — so let me: yes. Prognosis excellent. Lifelong.")


func test_sten_l8_and_l10_verbatim_spot_check() -> void:
	var data := _data("sten")
	assert_eq(data["heart_events"]["l8"]["id"], "the_back_bench")
	assert_eq(data["heart_events"]["l10"]["id"], "folded_steel")
	assert_eq(data["heart_events"]["l10"]["choice_a"], "\"Then I'll answer it — bring me something to say yes to.\"")
	assert_eq(RomanceEvents.vow_line("sten"),
		"Blades I've made that I trust: three. People: one. You carry the blade. I carry you. Straight, and forever, and I'll not say it softer than that in front of a crowd — but I mean it soft.")


func test_garrick_l8_and_l10_verbatim_spot_check() -> void:
	var data := _data("garrick")
	assert_eq(data["heart_events"]["l8"]["id"], "the_tell_again")
	assert_eq(data["heart_events"]["l10"]["id"], "a_friend_above_the_floors")
	assert_eq(data["heart_events"]["l10"]["choice_a"], "\"Then stop here. With me.\"")
	assert_eq(RomanceEvents.proposal_accept_line("garrick"),
		"A pendant. From you. Ha— the King below, the floors, the twenty years, and THIS is the thing that finally gets my nerve to stand still. Yes. Grinning yes. Don't you dare tell Sten I teared up.")
