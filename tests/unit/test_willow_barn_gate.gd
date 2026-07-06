extends GutTest
## Craft Stride 3 (Taming): Willow's barn-gated CLOSE line — same
## _gated_dialog_data() content-gating mechanism as test_bench_chain.gd's
## Garrick/Sten reconciliation tests (part e there), but gated on a WORLD
## STATE condition (world["taming"].barn non-empty) instead of a
## GameState.flags boolean.

func before_each() -> void:
	SaveManager.world.erase("taming")


func after_each() -> void:
	SaveManager.world.erase("taming")


func test_barn_gated_line_absent_before_any_tamed_slime() -> void:
	var willow := NPCFactory.make_npc("willow")
	add_child_autofree(willow)
	var gated_line: String = WillowDialog.DATA["tier_pools"]["CLOSE"][3]
	assert_eq(gated_line, "You kept one. The woods sorted you into \"safe\" years ago. Now the slimes have too.")

	var gated: Dictionary = willow.call("_gated_dialog_data")
	var pool: Array = gated["tier_pools"]["CLOSE"]
	assert_false(gated_line in pool, "must be absent before any slime is tamed")


func test_barn_gated_line_present_once_barn_is_non_empty() -> void:
	var willow := NPCFactory.make_npc("willow")
	add_child_autofree(willow)
	var gated_line: String = WillowDialog.DATA["tier_pools"]["CLOSE"][3]

	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	var gated: Dictionary = willow.call("_gated_dialog_data")
	var pool: Array = gated["tier_pools"]["CLOSE"]
	assert_true(gated_line in pool, "must be present once world[\"taming\"].barn is non-empty")


func test_barn_gate_does_not_mutate_the_shared_const_data() -> void:
	## Same non-mutation contract as _RECONCILED_GATED_LINES — every Willow
	## instance shares the SAME DialogResolver.DATA dict.
	var willow := NPCFactory.make_npc("willow")
	add_child_autofree(willow)
	willow.call("_gated_dialog_data")  # barn empty -> filters internally
	var gated_line: String = WillowDialog.DATA["tier_pools"]["CLOSE"][3]
	assert_true(gated_line in WillowDialog.DATA["tier_pools"]["CLOSE"],
		"the shared const DATA pool must be untouched")


func test_barn_gate_is_specific_to_willow_not_other_npcs() -> void:
	## _BARN_GATED_LINES only has a "willow" entry — every other NPC's
	## _gated_dialog_data() must be a complete no-op for this gate (their own
	## dialog_data is returned unchanged with respect to it).
	var marta := NPCFactory.make_npc("marta")
	add_child_autofree(marta)
	var gated: Dictionary = marta.call("_gated_dialog_data")
	assert_eq(gated, marta.dialog_data, "an NPC with no barn gate must get dialog_data back unchanged")


func test_barn_emptied_again_after_being_non_empty_re_hides_the_line() -> void:
	## Not a persistence rule the bible specifies either way, but documents
	## the gate's actual behavior: it's a live world-state read each call, not
	## a one-time-unlocked flag — if the barn were ever emptied (no such
	## mechanic exists yet) the line would go back to hidden.
	var willow := NPCFactory.make_npc("willow")
	add_child_autofree(willow)
	var gated_line: String = WillowDialog.DATA["tier_pools"]["CLOSE"][3]

	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": ["slime"]}
	assert_true(gated_line in (willow.call("_gated_dialog_data")["tier_pools"]["CLOSE"] as Array))

	SaveManager.world["taming"] = {"slime_feeds": 0, "barn": []}
	assert_false(gated_line in (willow.call("_gated_dialog_data")["tier_pools"]["CLOSE"] as Array))
