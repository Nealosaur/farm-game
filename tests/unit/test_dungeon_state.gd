extends GutTest
## Pure dict logic for the daily dungeon respawn ledger (DungeonState).
## No scene tree, no autoload state — the blob goes in and comes out.


func test_ensure_day_initializes_empty_blob() -> void:
	var blob := DungeonState.ensure_day({}, 3)
	assert_eq(blob["day"], 3)
	assert_eq(blob["killed"], {})


func test_record_kill_and_is_killed() -> void:
	var blob := DungeonState.ensure_day({}, 1)
	blob = DungeonState.record_kill(blob, "dungeon_1", 2)
	assert_true(DungeonState.is_killed(blob, "dungeon_1", 2))
	assert_false(DungeonState.is_killed(blob, "dungeon_1", 0), "other index untouched")
	assert_false(DungeonState.is_killed(blob, "dungeon_2", 2), "other floor untouched")


func test_record_kill_is_idempotent() -> void:
	var blob := DungeonState.ensure_day({}, 1)
	blob = DungeonState.record_kill(blob, "dungeon_1", 4)
	blob = DungeonState.record_kill(blob, "dungeon_1", 4)
	assert_eq((blob["killed"]["dungeon_1"] as Array).size(), 1)


func test_record_kill_does_not_mutate_input() -> void:
	var original := DungeonState.ensure_day({}, 1)
	DungeonState.record_kill(original, "dungeon_1", 0)
	assert_false(DungeonState.is_killed(original, "dungeon_1", 0),
		"record_kill returns a new blob; input stays pristine")


func test_same_day_ensure_keeps_kills() -> void:
	var blob := DungeonState.ensure_day({}, 5)
	blob = DungeonState.record_kill(blob, "dungeon_1", 1)
	blob = DungeonState.ensure_day(blob, 5)
	assert_true(DungeonState.is_killed(blob, "dungeon_1", 1),
		"re-entering a floor the same day keeps enemies dead")


func test_new_day_ensure_resets_kills() -> void:
	var blob := DungeonState.ensure_day({}, 5)
	blob = DungeonState.record_kill(blob, "dungeon_1", 1)
	blob = DungeonState.record_kill(blob, "dungeon_2", 0)
	blob = DungeonState.ensure_day(blob, 6)
	assert_eq(blob["day"], 6)
	assert_false(DungeonState.is_killed(blob, "dungeon_1", 1), "fresh day, all respawn")
	assert_false(DungeonState.is_killed(blob, "dungeon_2", 0))


func test_survives_json_round_trip() -> void:
	# SaveManager persists world as JSON; ints come back as floats. The
	# ledger must still match kills and recognize the same day afterwards.
	var blob := DungeonState.record_kill(DungeonState.ensure_day({}, 2), "dungeon_1", 3)
	var round_tripped: Dictionary = JSON.parse_string(JSON.stringify(blob))
	assert_true(DungeonState.is_killed(round_tripped, "dungeon_1", 3))
	var ensured := DungeonState.ensure_day(round_tripped, 2)
	assert_true(DungeonState.is_killed(ensured, "dungeon_1", 3),
		"same-day ensure after JSON round-trip must keep kills")
	var next_day := DungeonState.ensure_day(round_tripped, 3)
	assert_false(DungeonState.is_killed(next_day, "dungeon_1", 3))
